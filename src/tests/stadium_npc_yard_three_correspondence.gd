class_name StadiumNpcYardThreeCorrespondence
extends RefCounted
## Strict detached correspondence oracle. Authority comes from no method in this class.
## Compare actual resources and execution policies, not supplied signatures or record metadata.
# gdlint: disable=max-returns


static func matches(actual: StadiumNpcYardV1, source: StadiumPropertyGeometry) -> bool:
	if actual == null or source == null or actual.get_script() != StadiumNpcYardV1 \
		or source.get_script() != StadiumPropertyGeometry or actual.tier != "backyard" \
		or actual.field == null or source.field == null \
		or actual.field.get_script() != FieldDefinition or source.field.get_script() != FieldDefinition \
		or actual.field == source.field or not _policies(actual, source, true):
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if typeof(actual.field.get(key)) != typeof(source.field.get(key)) \
			or actual.field.get(key) != source.field.get(key):
			return false
	var definition: Dictionary = StadiumNpcYardThreeCandidateV1.definition()
	if actual.objects.size() != 8 or source.objects.size() != 8 \
		or not actual.route_obstacles().is_empty() or not source.route_obstacles().is_empty():
		return false
	for row: Dictionary in definition.instances:
		var model: Node3D = actual.objects.get(row.instance)
		var reference: Node3D = source.objects.get("npc-candidate:AY-03:" + row.site)
		if not is_instance_valid(model) or not is_instance_valid(reference) \
			or model.get_parent() != actual or reference.get_parent() != source \
			or model.get_meta("npc_instance", "") != row.instance \
			or model.get_meta("npc_site", "") != row.site \
			or model.get_meta("npc_host", "") != row.host \
			or model.get_meta("stadium_item", "") != row.item \
			or StadiumYardVenueStudy.components(model.transform) != row.transform:
			return false
		for body: StaticBody3D in model.get_node("Collision").get_children():
			if body.get_meta("npc_instance", "") != row.instance \
				or body.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL":
				return false
		if row.item == "ST-037":
			var beam: SpotLight3D = model.get_node_or_null("FieldLight")
			var other: SpotLight3D = reference.get_node_or_null("FieldLight")
			if beam == null or other == null or beam.visible \
				or model.get_node("Visual/LampLens").material_override.emission_enabled \
				or var_to_bytes(StadiumNpcRetainedGeometry._stored(beam)) != var_to_bytes(
					StadiumNpcRetainedGeometry._stored(other)):
				return false
	if not _identities(actual, actual):
		return false
	return var_to_bytes(_snapshot(actual, true)) == var_to_bytes(_snapshot(source, true))


static func _identities(node: Node, root: StadiumNpcYardV1) -> bool:
	for key: String in ["owned_copy", "candidate_instance", "candidate_site", "candidate_host",
		"candidate_venue", "stadium_snapshot"]:
		if node.has_meta(key):
			return false
	if node.has_meta("npc_instance"):
		var identity: Variant = node.get_meta("npc_instance")
		if not identity is String or not root.objects.has(identity):
			return false
		var owner: Node = root.objects[identity]
		if node != owner and (node.get_parent() != owner.get_node("Collision") \
			or not node is StaticBody3D):
			return false
		if node != owner and (node.has_meta("npc_host") or node.has_meta("npc_site")):
			return false
	elif node.has_meta("npc_host") or node.has_meta("npc_site"):
		return false
	for child: Node in node.get_children():
		if not _identities(child, root):
			return false
	return true


static func _policies(actual: Node, source: Node, root: bool = false) -> bool:
	if actual.get_child_count() != source.get_child_count() \
		or actual.process_mode != source.process_mode:
		return false
	if not root:
		if actual.name == &"BoundaryGraph" and actual.get_parent() is StadiumNpcYardV1:
			if actual.get_script() != StadiumNpcYardBoundaryV1 \
				or source.get_script() != StadiumBoundaryPrototype:
				return false
		elif actual.get_script() != source.get_script():
			return false
	if actual is CollisionObject3D and (not source is CollisionObject3D \
		or actual.disable_mode != source.disable_mode):
		return false
	for node: Node in [actual, source]:
		for property: Dictionary in node.get_property_list():
			if property.name == "script" or int(property.usage) & PROPERTY_USAGE_STORAGE == 0:
				continue
			if not _resource_policies(node.get(property.name), []):
				return false
	for index in range(actual.get_child_count()):
		if not _policies(actual.get_child(index), source.get_child(index)):
			return false
	return true


static func _snapshot(node: Node, root: bool = false) -> Dictionary:
	var result: Dictionary = StadiumNpcRetainedGeometry._geometry(node)
	# Exact identity domains and script roles are checked above before comparison.
	# Remove only these explicit domain differences; geometry/materials/collision stay byte-exact.
	if root:
		result.name = "AY03CorrespondenceRoot"
		result.script = "<verified-root-role>"
	elif node.name == &"BoundaryGraph" and node.get_parent().name in [
		"AY03Revision1Correspondence", "AY03Candidate"]:
		result.script = "<verified-boundary-role>"
	for key: String in ["npc_instance", "npc_site", "npc_host"]:
		result.erase(key)
	result.children = []
	for child: Node in node.get_children():
		result.children.append(_snapshot(child))
	return result


static func _resource_policies(value: Variant, seen: Array[int]) -> bool:
	# The shared geometry serializer predates resource-script identity. Every actual
	# mesh/material/shape/texture in this finite source is scriptless; same-valued scripts fail.
	if value is Resource:
		if value.get_script() != null:
			return false
		if seen.has(value.get_instance_id()):
			return true
		seen.append(value.get_instance_id())
		for property: Dictionary in value.get_property_list():
			if property.name == "script" or int(property.usage) & PROPERTY_USAGE_STORAGE == 0:
				continue
			if not _resource_policies(value.get(property.name), seen):
				return false
	elif value is Array:
		for item: Variant in value:
			if not _resource_policies(item, seen):
				return false
	elif value is Dictionary:
		for item: Variant in value.values():
			if not _resource_policies(item, seen):
				return false
	return true

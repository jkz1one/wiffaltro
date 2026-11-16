class_name StadiumNpcYardTwoCorrespondence
extends RefCounted
## Strict admission-only comparison of actual stored properties, resources and execution modes.
## No receiver/camera/fixture installer, gameplay callback or production authority is exposed.
# gdlint: disable=max-returns

const SOURCE_PREFIX: String = "npc-candidate:AY-02:"
const DOMAIN_META: Array[String] = ["npc_instance", "npc_site", "npc_host",
	"npc_correspondence_only", "candidate_instance", "candidate_site", "candidate_host",
	"candidate_venue", "property_signature", "owned_copy"]


static func matches(actual: StadiumNpcYardTwoV1, source: StadiumYardTwoProperty) -> bool:
	if actual == null or source == null or actual.get_script() != StadiumNpcYardTwoV1 \
		or source.get_script() != StadiumYardTwoProperty or actual.tier != "backyard" \
		or source.tier != "backyard" or actual.transform != Transform3D.IDENTITY \
		or source.transform != Transform3D.IDENTITY or actual.field == null or source.field == null \
		or actual.field.get_script() != FieldDefinition or source.field.get_script() != FieldDefinition \
		or actual.field == source.field or actual.objects.size() != 4 or source.objects.size() != 4:
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if typeof(actual.field.get(key)) != typeof(source.field.get(key)) \
			or actual.field.get(key) != source.field.get(key):
			return false
	if actual.get_meta("npc_correspondence_only", null) != true \
		or JSON.stringify(source.get_meta("candidate_venue", {}), "", true, true) != JSON.stringify(
			StadiumNpcYardTwoContractV1.canonical(), "", true, true):
		return false
	var rows: Dictionary = {}
	for original: Dictionary in StadiumNpcYardTwoContractV1.canonical().items:
		rows[original.site] = original
	for row: Dictionary in StadiumNpcYardTwoCandidateV1.definition().instances:
		var model: Node3D = actual.objects.get(row.instance)
		var identity: String = SOURCE_PREFIX + row.site
		var reference: Node3D = source.objects.get(identity)
		if not is_instance_valid(model) or not is_instance_valid(reference) \
			or model.get_parent() != actual or reference.get_parent() != source \
			or model.get_meta("npc_instance", "") != row.instance \
			or model.get_meta("npc_site", "") != row.site \
			or model.get_meta("npc_host", "") != row.host \
			or model.get_meta("stadium_item", "") != row.item \
			or StadiumYardVenueStudy.components(model.transform) != row.transform \
			or reference.get_meta("candidate_instance", "") != identity \
			or reference.get_meta("candidate_site", "") != row.site \
			or reference.get_meta("candidate_host", "") != row.host \
			or reference.get_meta("owned_copy", "") != identity or not source.model_intact(identity):
			return false
		var collision: Node = model.get_node_or_null("Collision")
		if collision == null or collision.get_child_count() != reference.get_node(
			"Collision").get_child_count():
			return false
		for index in range(collision.get_child_count()):
			var body: Node = collision.get_child(index)
			var original: Node = reference.get_node("Collision").get_child(index)
			if not body is StaticBody3D or body.get_meta("npc_instance", "") != row.instance \
				or body.get_meta("surface_role", "") != rows[row.site].role \
				or source.contact_identity(original).is_empty():
				return false
	if not _identities(actual, actual) or not _policies(actual, source, true):
		return false
	return var_to_bytes(snapshot(actual, true)) == var_to_bytes(snapshot(source, true))


static func _identities(node: Node, root: StadiumNpcYardTwoV1) -> bool:
	for key: String in ["owned_copy", "candidate_instance", "candidate_site", "candidate_host",
		"candidate_venue", "stadium_snapshot", "stadium_property", "property_signature"]:
		if node.has_meta(key):
			return false
	if node is Light3D:
		return false
	if node != root and node.has_meta("npc_correspondence_only"):
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
		or actual.process_mode != source.process_mode \
		or actual.is_processing() != source.is_processing() \
		or actual.is_physics_processing() != source.is_physics_processing():
		return false
	if not root:
		if actual.name == &"BoundaryGraph" and actual.get_parent() is StadiumNpcYardTwoV1:
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
			if not StadiumNpcYardThreeCorrespondence._resource_policies(node.get(property.name), []):
				return false
	for index in range(actual.get_child_count()):
		if not _policies(actual.get_child(index), source.get_child(index)):
			return false
	return true


static func snapshot(node: Node, root: bool = false) -> Dictionary:
	var result: Dictionary = {
		"class": node.get_class(),
		"name": "<root>" if root else "" if String(node.name).begins_with("@") else String(node.name),
		"properties": StadiumNpcRetainedGeometry._stored(node), "metadata": {}, "children": []
	}
	# Root/boundary scripts and exact identity-domain differences are verified before comparison.
	# Resource script identities are checked recursively. The geometry serializer skips them.
	if node is Node3D:
		result.properties.transform = _canonical_transform(node.transform)
	if node is MeshInstance3D:
		result["mesh_arrays"] = StadiumNpcRetainedGeometry._mesh(node.mesh)
	if node is MultiMeshInstance3D and node.multimesh != null:
		result["multimesh_arrays"] = StadiumNpcRetainedGeometry._mesh(node.multimesh.mesh)
	for key: StringName in node.get_meta_list():
		if String(key) not in DOMAIN_META:
			result.metadata[String(key)] = StadiumNpcRetainedGeometry._content(node.get_meta(key))
	for child: Node in node.get_children():
		result.children.append(snapshot(child))
	return result


static func _canonical_transform(value: Transform3D) -> Transform3D:
	# Scene signed zero is the sole normalization. Every nonzero float32 bit is preserved.
	var result: Transform3D = value
	for column in range(3):
		var vector: Vector3 = result.basis[column]
		for component in range(3):
			if vector[component] == 0.0:
				vector[component] = 0.0
		result.basis[column] = vector
	for component in range(3):
		if result.origin[component] == 0.0:
			result.origin[component] = 0.0
	return result

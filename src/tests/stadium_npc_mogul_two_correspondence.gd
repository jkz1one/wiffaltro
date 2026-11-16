class_name StadiumNpcMogulTwoCorrespondence
extends RefCounted
## Admission-only exact actual-node oracle. No production, camera or environment authority.
## All stored node/resource values, full mesh arrays and execution modes are inspected.
## No dynamic receiver, score, material or geometric tolerance applies to detached construction.
# gdlint: disable=max-returns

const SOURCE_PREFIX: String = "npc-candidate:AM-02:left-loft-v1:"
const DOMAIN_META: Array[String] = [
	"npc_instance", "npc_site", "npc_host", "npc_correspondence_only",
	"candidate_site", "candidate_instance", "candidate_host", "candidate_model_version",
	"candidate_venue", "property_signature"
]


static func matches(actual: StadiumNpcMogulTwoV1, source: StadiumPropertyGeometry) -> bool:
	if actual == null or source == null or actual.get_script() != StadiumNpcMogulTwoV1 \
		or source.get_script() != StadiumPropertyGeometry or actual.tier != "mogul" \
		or source.tier != "mogul" or actual.transform != Transform3D.IDENTITY \
		or source.transform != Transform3D.IDENTITY or actual.field == null or source.field == null \
		or actual.field.get_script() != FieldDefinition or source.field.get_script() != FieldDefinition \
		or actual.field == source.field or actual.objects.size() != 91 or source.objects.size() != 91:
		return false
	for key: String in StadiumNpcMogulTwoV1.FIELD:
		if typeof(actual.field.get(key)) != typeof(source.field.get(key)) \
			or actual.field.get(key) != source.field.get(key):
			return false
	for row: Dictionary in StadiumNpcMogulTwoCandidateV1.definition().instances:
		var model: Node3D = actual.objects.get(row.instance)
		var reference: Node3D = source.objects.get(SOURCE_PREFIX + row.site)
		if not is_instance_valid(model) or not is_instance_valid(reference) \
			or not actual.is_ancestor_of(model) or not source.is_ancestor_of(reference) \
			or actual.get_path_to(model.get_parent()) != source.get_path_to(reference.get_parent()) \
			or model.get_meta("npc_instance", "") != row.instance \
			or model.get_meta("npc_site", "") != row.site \
			or model.get_meta("npc_host", "") != "field" \
			or model.get_meta("stadium_item", "") != row.item \
			or components(relative(model, actual)) != row.transform:
			return false
		var collision: Node = model.get_node_or_null("Collision")
		if collision != null:
			for body: StaticBody3D in collision.get_children():
				if body.get_meta("npc_instance", "") != row.instance:
					return false
	if not _supports(actual, source) or not _boundary_bindings(actual, source) \
		or not _identities(actual, actual) or not _policies(actual, source, true):
		return false
	return var_to_bytes(snapshot(actual, true)) == var_to_bytes(snapshot(source, true))


static func _supports(actual: StadiumNpcMogulTwoV1, source: StadiumPropertyGeometry) -> bool:
	for root: Node3D in [actual, source]:
		var prefix: String = "npc:AM-02:r1:" if root == actual else SOURCE_PREFIX
		var objects: Dictionary = actual.objects if root == actual else source.objects
		for row: Dictionary in StadiumNpcMogulTwoContractV1.payload().items:
			var model: Node3D = objects.get(prefix + row.site)
			if model == null:
				return false
			for role: String in ["lower", "concourse", "upper"]:
				var key: String = role + "_instance"
				if row.support.has(role):
					var site: String = String(row.support[role]).trim_prefix(SOURCE_PREFIX)
					var host: Node3D = objects.get(prefix + site)
					if host == null or not model.has_meta(key) \
						or typeof(model.get_meta(key)) != TYPE_INT \
						or model.get_meta(key) != host.get_instance_id():
						return false
				elif model.has_meta(key):
					return false
			for child: Node in model.find_children("*", "", true, false):
				for key: String in ["lower_instance", "concourse_instance", "upper_instance"]:
					if child.has_meta(key):
						return false
	return true


static func _boundary_bindings(
	actual: StadiumNpcMogulTwoV1, source: StadiumPropertyGeometry
) -> bool:
	var boundary: StadiumNpcMogulTwoBoundaryV1 = actual.get_node_or_null("ClubBoundary")
	var original: StadiumClubBoundaryStudy = source.get_node_or_null("ClubBoundary")
	if boundary == null or original == null or boundary.graph == null \
		or boundary.graph.get_script() != StadiumNpcMogulTwoGraphV1 \
		or boundary.graph._shape != "straight" \
		or boundary.graph.signature() != StadiumNpcMogulTwoCandidateV1.definition().graph.sha256 \
		or boundary.items.size() != 63 or boundary.bodies.size() != original.bodies.size():
		return false
	for index in range(63):
		var model: Node3D = boundary.items[index]
		if not is_instance_valid(model) or not boundary.is_ancestor_of(model) \
			or actual.objects.get(model.get_meta("npc_instance", "")) != model \
			or _indices(model, boundary) != _indices(original.items[index], original):
			return false
	for index in range(boundary.bodies.size()):
		var body: StaticBody3D = boundary.bodies[index]
		if not is_instance_valid(body) or not boundary.is_ancestor_of(body) \
			or _indices(body, boundary) != _indices(original.bodies[index], original):
			return false
	return true


static func _indices(node: Node, root: Node) -> Array[int]:
	# Engine-generated duplicate names contain instance IDs. Exact indexed hierarchy is stable;
	# explicit authored names are separately retained by the node snapshot.
	var result: Array[int] = []
	while node != null and node != root:
		result.push_front(node.get_index())
		node = node.get_parent()
	return result


static func _identities(node: Node, root: StadiumNpcMogulTwoV1) -> bool:
	for key: String in ["owned_copy", "candidate_instance", "candidate_site", "candidate_host",
		"candidate_venue", "stadium_snapshot", "stadium_property", "property_signature"]:
		if node.has_meta(key):
			return false
	if node is Light3D:
		return false
	if not node.has_meta("npc_site"):
		for key: String in ["lower_instance", "concourse_instance", "upper_instance"]:
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
		or actual.process_mode != source.process_mode \
		or actual.is_processing() != source.is_processing() \
		or actual.is_physics_processing() != source.is_physics_processing():
		return false
	if not root:
		if actual.name == &"ClubBoundary" and actual.get_parent() is StadiumNpcMogulTwoV1:
			if actual.get_script() != StadiumNpcMogulTwoBoundaryV1 \
				or source.get_script() != StadiumMogulTwoBoundary:
				return false
		elif actual.name == &"ScoreDisplay":
			if actual.get_script() != StadiumNpcClubDisplayV1 \
				or source.get_script() != StadiumScoreboardDisplay \
				or actual._match != null or source._match != null:
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
		"properties": StadiumNpcRetainedGeometry._stored(node),
		"metadata": {}, "children": []
	}
	# Script identity is checked by _policies before explicit role differences are omitted.
	# Only signed zero in scene transforms is canonical; every nonzero float32 bit survives.
	if node is Node3D:
		result.properties.transform = canonical_transform(node.transform)
	if node is MeshInstance3D:
		result["mesh_arrays"] = StadiumNpcRetainedGeometry._mesh(node.mesh)
	if node is MultiMeshInstance3D and node.multimesh != null:
		result["multimesh_arrays"] = StadiumNpcRetainedGeometry._mesh(node.multimesh.mesh)
	for key: StringName in node.get_meta_list():
		if String(key) in ["lower_instance", "concourse_instance", "upper_instance"]:
			result.metadata[String(key)] = "<verified-local-support>"
		elif String(key) not in DOMAIN_META:
			result.metadata[String(key)] = StadiumNpcRetainedGeometry._content(node.get_meta(key))
	for child: Node in node.get_children():
		result.children.append(snapshot(child))
	return result


static func canonical_transform(value: Transform3D) -> Transform3D:
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


static func relative(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			result = parent.transform * result
		parent = parent.get_parent()
	return result


static func components(value: Transform3D) -> Array:
	var result: Array = []
	for vector: Vector3 in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result

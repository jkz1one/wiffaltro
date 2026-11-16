class_name StadiumNpcYardTwoLiveScanOracle
extends RefCounted
## Immutable independent reference snapshots plus current live content/policy/identity joins.
# gdlint: disable=max-returns


static func expected(configured: bool) -> StadiumNpcYardTwoV1:
	var result: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.build()
	for identity: String in result.objects:
		var model: Node3D = result.objects[identity]
		model.set_meta("owned_copy", identity)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.set_meta("owned_copy", identity)
	if configured:
		var chair: Node3D = result.objects[StadiumNpcYardTwoV1.PREFIX + "RECEIVER-PRIMARY"]
		chair.process_mode = Node.PROCESS_MODE_PAUSABLE
		for body: StaticBody3D in chair.get_node("Collision").get_children():
			body.collision_layer |= StadiumPitchReceiver.LAYER
	return result


static func build_reference() -> Dictionary:
	# One independently constructed authority per property lifetime, never a live snapshot.
	# Only immutable scalar/String values and recursively read-only dictionaries escape.
	var root: StadiumNpcYardTwoV1 = expected(false)
	var chair: Node3D = root.objects[StadiumNpcYardTwoV1.PREFIX + "RECEIVER-PRIMARY"]
	var fields: Dictionary = {}
	for key: String in StadiumNpcYardV1.FIELD:
		fields[key] = root.field.get(key)
	fields.make_read_only()
	var result: Dictionary = {"plain": _reference_snapshot(root, chair), "field": fields}
	chair.process_mode = Node.PROCESS_MODE_PAUSABLE
	for body: StaticBody3D in chair.get_node("Collision").get_children():
		body.collision_layer |= StadiumPitchReceiver.LAYER
	result["configured"] = _reference_snapshot(root, chair)
	result.make_read_only()
	root.free()
	return result


static func _reference_snapshot(root: Node3D, chair: Node3D) -> Dictionary:
	var geometry: Dictionary = StadiumNpcRetainedGeometry._geometry(root)
	var policies: Array = []
	var valid: bool = _policy_data(root, policies)
	var result: Dictionary = {"geometry": var_to_bytes(geometry).hex_encode(),
		"policies": var_to_bytes(policies).hex_encode(), "valid": valid,
		"chair": var_to_bytes(geometry.children[chair.get_index()]).hex_encode(),
		"chair_index": chair.get_index()}
	result.make_read_only()
	return result


static func same(property: StadiumNpcYardTwoPropertyV1) -> bool:
	if not is_instance_valid(property.construction):
		return false
	var frozen: Dictionary = property._geometry_reference
	var reference_data: Dictionary = frozen.configured if property.receiver_configured \
		else frozen.plain
	var policies: Array = []
	if not reference_data.valid or not _policy_data(property.construction, policies) \
		or var_to_bytes(policies).hex_encode() != reference_data.policies:
		return false
	var actual: Dictionary = StadiumNpcRetainedGeometry._geometry(property.construction)
	var baseline_chair: Dictionary = bytes_to_var(reference_data.chair.hex_decode())
	var expected_chair: Dictionary = baseline_chair.duplicate(true)
	if not _owned_chair(property, expected_chair) \
		or var_to_bytes(actual.children[reference_data.chair_index]) != var_to_bytes(expected_chair):
		return false
	# Replace only a fully compared live subtree with its independent canonical baseline.
	actual.children[reference_data.chair_index] = baseline_chair
	if var_to_bytes(actual).hex_encode() != reference_data.geometry:
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if typeof(property.field.get(key)) != typeof(frozen.field[key]) \
			or property.field.get(key) != frozen.field[key]:
			return false
	return property.field.id == frozen.field.id \
		and property.field.display_name == frozen.field.display_name


static func _policy_data(node: Node, result: Array) -> bool:
	# Same live script/policy/resource traversal as the original two-tree join. The independent
	# reference side was traversed once before its immutable serialization and destruction.
	var script: Script = node.get_script()
	result.append([script.get_instance_id() if script != null else 0, node.get_child_count(),
		node.process_mode, node.process_priority, node.process_physics_priority,
		node.disable_mode if node is CollisionObject3D else null,
		var_to_bytes(StadiumNpcRetainedGeometry._stored(node)) if node is Light3D else null])
	for item: Dictionary in node.get_property_list():
		if item.name == "script" or int(item.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		if not StadiumNpcYardThreeInstalledGeometryV1._resources(node.get(item.name), []):
			return false
	for child: Node in node.get_children():
		if not _policy_data(child, result):
			return false
	return true


static func _owned_chair(property: StadiumNpcYardTwoPropertyV1, geometry: Dictionary) -> bool:
	# Tiny ephemeral oracle: no meshes, shapes, collision, cached mutable nodes or live values.
	# The unchanged owned style and rock methods execute on independent rest-pose data.
	var probe: Node3D = Node3D.new()
	probe.set_meta("stadium_item", geometry.stadium_item)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	visual.transform = geometry.children[0].transform
	visual.visible = geometry.children[0].visible
	probe.add_child(visual)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.material_override = StandardMaterial3D.new()
	visual.add_child(mesh)
	var receiver: StadiumNpcYardTwoReceiverV1 = property._owned_receiver()
	var allowed: bool = property.copy_owned_style(probe)
	if property.receiver_configured:
		allowed = allowed and is_instance_valid(receiver) and receiver.copy_owned_rock(probe)
	if allowed:
		geometry.children[0].transform = visual.transform
		geometry.children[0].visible = visual.visible
		if probe.has_meta("receiver_render_state"):
			for part: Dictionary in geometry.children[0].children:
				var material: Dictionary = part.material_override.properties
				var color: Color = material.albedo_color
				color.a = mesh.material_override.albedo_color.a
				material.albedo_color = color
				material.transparency = mesh.material_override.transparency
				part.cast_shadow = mesh.cast_shadow
	probe.free()
	return allowed


static func identities(root: Node) -> Array:
	var result: Array = []
	_collect(root, result)
	return result


static func _collect(node: Node, result: Array) -> void:
	result.append([node, node.get_parent(), node.get_script()])
	for item: Dictionary in node.get_property_list():
		if item.name == "script" or int(item.usage) & PROPERTY_USAGE_STORAGE == 0:
			continue
		_resources(node.get(item.name), result, [])
	for child: Node in node.get_children():
		_collect(child, result)


static func _resources(value: Variant, result: Array, seen: Array[int]) -> void:
	if value is Resource:
		result.append([value, value.get_script()])
		if seen.has(value.get_instance_id()):
			return
		seen.append(value.get_instance_id())
		for item: Dictionary in value.get_property_list():
			if item.name != "script" and int(item.usage) & PROPERTY_USAGE_STORAGE != 0:
				_resources(value.get(item.name), result, seen)
	elif value is Array:
		for item: Variant in value:
			_resources(item, result, seen)
	elif value is Dictionary:
		for item: Variant in value.values():
			_resources(item, result, seen)

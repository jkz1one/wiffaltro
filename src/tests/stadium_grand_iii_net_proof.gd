extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"
## Complete-venue witness: unchanged ST073 geometry plus exact ClubBoundary contact binding.


func _init_net_witness() -> bool:
	if not super._init_net_witness():
		return false
	# The actual installed assembly deliberately adds the contact-query layer32.
	# Normalize only the independent witness to the literal installed contract;
	# never alter actual geometry/collision or accept both standalone and installed masks.
	for id: String in StadiumReceiverNetModels.PANELS:
		var body: StaticBody3D = _net_witness.get_node("Collision/" + id)
		body.collision_layer = 33
		body.set_meta("club_surface", id)
		body.set_meta("surface_priority", 450)
		body.set_meta("surface_kind", "receiver")
	return true


func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
	var body: StaticBody3D = hit.get("collider") as StaticBody3D
	if body == null:
		return false
	var id: String = str(body.get_meta("surface_id", ""))
	if (
		not CS.meta_matches(body, "surface_id", id)
		or not CS.meta_matches(body, "club_surface", id)
		or not CS.meta_matches(body, "surface_priority", 450)
		or not CS.meta_matches(body, "surface_kind", "receiver")
		or not CS.meta_matches(body, "ball_surface", &"stadium_receiver_net_candidate")
	):
		return false
	return super._verified_panel(hit, net)


func audit_installed(net: Node3D) -> bool:
	for id: String in StadiumReceiverNetModels.PANELS:
		var body: StaticBody3D = net.get_node_or_null("Collision/" + id)
		var hit: Dictionary = {"collider": body, "shape": 0}
		if not _verified_panel(hit, net):
			print("GRAND_III_NET_WITNESS_MISMATCH ", diagnostic(net, id))
			_check(false, "complete-venue authentic panel witness setup rejects: " + id)
			return false
	# Controls prove that installed metadata and exact layer33 are necessary,
	# not labels that could excuse an arbitrary collider or primitive.
	var body: StaticBody3D = net.get_node("Collision/ST073_CENTER_NET")
	var hit: Dictionary = {"collider": body, "shape": 0}
	body.collision_layer = 1
	_check(
		not _verified_panel(hit, net), "standalone collision layer cannot impersonate installed net"
	)
	body.collision_layer = 33
	body.set_meta("surface_priority", 451)
	_check(not _verified_panel(hit, net), "wrong actual receiver priority rejects complete witness")
	body.set_meta("surface_priority", 450)
	_check(_verified_panel(hit, net), "exact installed contact binding restores canonical witness")
	_diagnostic_controls(net)
	return _failures == 0


func diagnostic(net: Node3D, id: String) -> Dictionary:
	var body: StaticBody3D = net.get_node_or_null("Collision/" + id)
	var reference: StaticBody3D = _net_witness.get_node_or_null("Collision/" + id)
	var mesh: MeshInstance3D = net.get_node_or_null("Visual/" + id)
	var expected: MeshInstance3D = _net_witness.get_node_or_null("Visual/" + id)
	var result: Dictionary = {
		"panel": id,
		"net_pose": net.global_transform,
		"body": _body_state(body),
		"expected_body": _body_state(reference),
		"mesh": _mesh_state(mesh),
		"expected_mesh": _mesh_state(expected)
	}
	if (
		mesh != null
		and expected != null
		and mesh.mesh is ArrayMesh
		and mesh.mesh.get_surface_count() == 1
		and expected.mesh is ArrayMesh
		and expected.mesh.get_surface_count() == 1
	):
		var actual_arrays: Array = mesh.mesh.surface_get_arrays(0)
		var expected_arrays: Array = expected.mesh.surface_get_arrays(0)
		var differences: Array = []
		for slot in range(actual_arrays.size()):
			if not CS.same_value(actual_arrays[slot], expected_arrays[slot]):
				differences.append(slot)
		result["different_array_slots"] = differences
		result["rest_equal"] = (
			mesh.has_meta("rest_vertices")
			and expected.has_meta("rest_vertices")
			and CS.same_value(mesh.get_meta("rest_vertices"), expected.get_meta("rest_vertices"))
		)
		result["render_state_equal"] = CS._render_state(mesh, expected)
	return result


func _body_state(body: StaticBody3D) -> Dictionary:
	if body == null:
		return {"missing": true}
	var state: Dictionary = {
		"pose": body.transform,
		"layer": body.collision_layer,
		"mask": body.collision_mask,
		"mode": body.process_mode,
		"disable_mode": body.disable_mode,
		"top_level": body.top_level,
		"script": body.get_script(),
		"children": body.get_child_count()
	}
	for key: String in [
		"surface_id",
		"surface_role",
		"ball_surface",
		"club_surface",
		"surface_priority",
		"surface_kind"
	]:
		state[key] = body.get_meta(key) if body.has_meta(key) else {"missing": true}
	if body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D:
		var shape: CollisionShape3D = body.get_child(0)
		if shape.shape == null:
			state["shape"] = {"missing": true}
			return state
		state["shape"] = {
			"class": shape.shape.get_class(),
			"pose": shape.transform,
			"margin": shape.shape.margin,
			"disabled": shape.disabled,
			"size": shape.shape.size if shape.shape is BoxShape3D else Vector3.ZERO
		}
	return state


func _mesh_state(mesh: MeshInstance3D) -> Dictionary:
	if mesh == null or mesh.mesh == null:
		return {"missing": true}
	if mesh.mesh.get_surface_count() == 0:
		return {"mesh_class": mesh.mesh.get_class(), "surfaces": 0}
	return {
		"mesh_class": mesh.mesh.get_class(),
		"surfaces": mesh.mesh.get_surface_count(),
		"primitive":
		(
			(mesh.mesh as ArrayMesh).surface_get_primitive_type(0)
			if mesh.mesh is ArrayMesh
			else "unsupported-mesh-class"
		),
		"arrays_sha256": var_to_bytes(mesh.mesh.surface_get_arrays(0)).hex_encode().sha256_text(),
		"pose": mesh.transform,
		"world_pose": mesh.global_transform if mesh.is_inside_tree() else {"detached": true},
		"visible": mesh.is_visible_in_tree(),
		"processing": mesh.can_process(),
		"transparency": mesh.transparency,
		"layers": mesh.layers,
		"shadows": mesh.cast_shadow,
		"panel_width":
		mesh.get_meta("panel_width") if mesh.has_meta("panel_width") else {"missing": true},
		"rest_present": mesh.has_meta("rest_vertices"),
		"rest_sha256":
		(
			var_to_bytes(mesh.get_meta("rest_vertices")).hex_encode().sha256_text()
			if mesh.has_meta("rest_vertices")
			else ""
		),
		"material": _material_state(mesh.material_override),
		"overlay": _material_state(mesh.material_overlay)
	}


func _material_state(material: Material) -> Dictionary:
	if material == null:
		return {"null": true}
	var state: Dictionary = {"class": material.get_class()}
	for row: Dictionary in material.get_property_list():
		var key: String = row.name
		if int(row.usage) & PROPERTY_USAGE_STORAGE and not key.begins_with("resource_"):
			var value: Variant = material.get(key)
			state[key] = value.get_class() if value is Resource else value
	return state


func _diagnostic_controls(net: Node3D) -> void:
	var id: String = "ST073_CENTER_NET"
	var body: StaticBody3D = net.get_node("Collision/" + id)
	var mesh: MeshInstance3D = net.get_node("Visual/" + id)
	var hit: Dictionary = {"collider": body, "shape": 0}
	var original: Mesh = mesh.mesh
	var club_surface: Variant = body.get_meta("club_surface")
	body.remove_meta("club_surface")
	var missing_body: Dictionary = diagnostic(net, id)
	_check(
		(
			not _verified_panel(hit, net)
			and CS.same_value(missing_body.body.club_surface, {"missing": true})
		),
		"missing body metadata produces bounded diagnostics and rejects without unsafe reads"
	)
	body.set_meta("club_surface", club_surface)
	var rest: Variant = mesh.get_meta("rest_vertices")
	mesh.remove_meta("rest_vertices")
	var missing_rest: Dictionary = diagnostic(net, id)
	_check(
		(
			not _verified_panel(hit, net)
			and not missing_rest.rest_equal
			and not missing_rest.mesh.rest_present
			and missing_rest.mesh.rest_sha256.is_empty()
		),
		"missing triangle-rest metadata is diagnosed safely and never accepted"
	)
	mesh.set_meta("rest_vertices", rest)
	mesh.mesh = QuadMesh.new()
	var quad: Dictionary = diagnostic(net, id)
	_check(
		(
			not _verified_panel(hit, net)
			and CS.same_value(quad.mesh.primitive, "unsupported-mesh-class")
		),
		"opaque non-ArrayMesh is rejected and diagnosed without ArrayMesh-only API calls"
	)
	mesh.mesh = ArrayMesh.new()
	var empty: Dictionary = diagnostic(net, id)
	_check(
		not _verified_panel(hit, net) and empty.mesh.surfaces == 0,
		"empty ArrayMesh rejects and diagnoses without reading absent surface zero"
	)
	mesh.mesh = original
	_check(
		_verified_panel(hit, net),
		"all malformed diagnostic controls restore exact genuine mesh and metadata"
	)

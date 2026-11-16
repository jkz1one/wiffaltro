extends RefCounted
## Native-only engine lifecycle controls, separate from genuine controller visibility evidence.

const Presentation = preload("res://src/tests/stadium_mogul_two_source_presentation.gd")


class RejectionProbe:
	extends Node
	var failures: int = 0

	func _check(condition: bool, _message: String) -> void:
		if not condition:
			failures += 1


static func run(owner: Node) -> void:
	owner._check(
		DisplayServer.get_name() != "headless", "surface lifecycle requires native renderer"
	)
	if DisplayServer.get_name() == "headless":
		return
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = "IsolatedImmediateMeshLifecycleControl"
	node.visible = false
	owner.add_child(node)
	var original: ImmediateMesh = ImmediateMesh.new()
	node.mesh = original
	var empty: Dictionary = _capture(owner, node)
	owner._check(
		empty.mesh.surface_count == 0 and empty.surface_overrides.is_empty(),
		"same-resource lifecycle begins with zero surfaces and zero raw slots"
	)
	original.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	original.surface_set_color(Color(1, 0.96, 0.76, 0.22))
	for point: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.UP]:
		original.surface_add_vertex(point)
	original.surface_end()
	var expected: StandardMaterial3D = StandardMaterial3D.new()
	var altered: StandardMaterial3D = StandardMaterial3D.new()
	node.set_surface_override_material(0, expected)
	var populated: Dictionary = _capture(owner, node)
	owner._check(
		(
			node.mesh == original
			and populated.mesh.surface_count == 1
			and populated.surface_overrides == [expected]
			and populated.active_surface_overrides == [expected]
		),
		"same ImmediateMesh populates one surface with exact active override identity"
	)
	node.set_surface_override_material(0, altered)
	owner._check(
		not Presentation._effective_materials_equal(node, populated),
		"deliberately altered populated override is rejected by the restoration proof"
	)
	Presentation._apply_mesh(owner, node, populated, false)
	owner._check(
		Presentation._effective_materials_equal(node, populated) and node.mesh == original,
		"populated source release restores its exact override and original resource"
	)
	node.set_surface_override_material(0, null)
	original.clear_surfaces()
	var cleared: Dictionary = _capture(owner, node)
	owner._check(
		(
			node.mesh == original
			and original.get_surface_count() == 0
			and node.get_surface_override_material_count() == 1
			and cleared.surface_overrides.size() == 1
			and cleared.surface_overrides[0] == null
			and cleared.active_surface_overrides.is_empty()
			and cleared.override_slot_policy == "empty-ImmediateMesh-single-null-slot-normalized"
		),
		"same-resource empty-populated-empty reproduces the frozen-engine dormant null slot"
	)
	var typed_null: Material = null
	var typed_slots: Array[Material] = [typed_null]
	var typed_record: Dictionary = cleared.duplicate(true)
	typed_record.surface_overrides = typed_slots
	owner._check(
		Presentation._override_record_valid(typed_record),
		"explicit dormant-slot contract accepts one typed Material null"
	)
	var raw_before: Array = cleared.surface_overrides.duplicate()
	for row: Dictionary in [empty, populated, cleared]:
		Presentation._apply_mesh(owner, node, row, true)
		owner._check(
			(
				node.mesh is ArrayMesh
				and node.mesh != original
				and Presentation._geometry_equal(node.mesh, row.mesh)
				and Presentation._effective_materials_equal(node, row)
				and original.get_surface_count() == 0
			),
			"archived lifecycle copy restores exact geometry/materials without mutating source"
		)
	Presentation._apply_mesh(owner, node, cleared, false)
	owner._check(
		(
			node.mesh == original
			and original.get_surface_count() == 0
			and node.get_surface_override_material_count() == 0
			and cleared.surface_overrides == raw_before
			and Presentation._effective_materials_equal(node, cleared)
		),
		"release preserves original empty resource, effective state and raw historical bookkeeping"
	)
	_negative_records(owner, node, cleared, populated, altered)
	Presentation._apply_mesh(owner, node, populated, true)
	var copy: ArrayMesh = node.mesh as ArrayMesh
	copy.surface_set_material(0, altered)
	owner._check(
		not Presentation._geometry_equal(copy, populated.mesh),
		"changed populated surface material is rejected by exact geometry proof"
	)
	Presentation._apply_mesh(owner, node, cleared, false)
	owner._check(node.mesh == original, "negative geometry control releases original resource")
	print(
		"MOGUL_TWO_SURFACE_LIFECYCLE_CONTROL empty=0 populated=1 cleared=0 raw_slots=1",
		" normalized_slots=",
		node.get_surface_override_material_count(),
		" original_identity=",
		node.mesh == original,
		" negative_controls=8"
	)
	await RenderingServer.frame_post_draw
	node.queue_free()
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	owner._check(not is_instance_valid(node), "isolated lifecycle control drains native ownership")


static func _capture(owner: Node, node: MeshInstance3D) -> Dictionary:
	var state: Dictionary = {"materials": {}, "errors": [], "renderer_omissions": []}
	var result: Dictionary = Presentation._mesh_instance(node, state)
	owner._check(
		state.errors.is_empty() and state.renderer_omissions.is_empty(),
		"native lifecycle capture is complete and preserves raw surface-slot metadata"
	)
	return result


static func _negative_records(
	owner: Node, node: MeshInstance3D, cleared: Dictionary, populated: Dictionary, altered: Material
) -> void:
	var malformed: Array[Dictionary] = []
	var row: Dictionary = cleared.duplicate(true)
	row.surface_overrides = [altered]
	malformed.append(row)
	row = cleared.duplicate(true)
	row.surface_overrides = [null, null]
	malformed.append(row)
	row = cleared.duplicate(true)
	row.mesh.source = ArrayMesh.new()
	row.mesh.source_class = "ArrayMesh"
	malformed.append(row)
	row = populated.duplicate(true)
	row.surface_overrides = []
	row.active_surface_overrides = []
	malformed.append(row)
	row = populated.duplicate(true)
	row.surface_overrides.append(null)
	malformed.append(row)
	row = populated.duplicate(true)
	row.override_slot_policy = "empty-ImmediateMesh-single-null-slot-normalized"
	malformed.append(row)
	var original: Mesh = node.mesh
	for bad: Dictionary in malformed:
		owner._check(
			not Presentation._override_record_valid(bad),
			"non-null/multiple dormant, foreign mesh, and nonempty slot mismatches fail closed"
		)
		var probe: RejectionProbe = RejectionProbe.new()
		Presentation._apply_mesh(probe, node, bad, true)
		owner._check(
			(
				probe.failures == 1
				and node.mesh == original
				and Presentation._geometry_equal(node.mesh, cleared.mesh)
				and Presentation._effective_materials_equal(node, cleared)
			),
			"invalid override record is rejected before any destination state mutation"
		)
		probe.free()

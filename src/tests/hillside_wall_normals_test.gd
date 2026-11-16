extends Node
## Native resource comparison only. No game, physical-contact or rendered acceptance claim.
# gdlint: disable=max-returns

const PREREQUISITE = preload("res://src/tests/stadium_hillside_public_prerequisite_test.gd")
const SOURCE: String = "res://src/presentation/stadium/stadium_hillside_public_boundary_source.gd"
const OLD_SHA: String = "09c87aaf5f1eac86199fdf748db65dfd671cef1ab4a5cd760e4634095d53992c"
const ADDED_LINE: String = "\tsurface.set_smooth_group(-1)\n"
const EXPECTED_CHECKS: int = 20
const MAX_TRIANGLES: int = 4096
const COMPARISONS: Array[String] = ["shape_points", "vertex_index", "other_arrays", "bounds",
	"transforms", "materials", "metadata", "finite_flat", "canonical", "outward",
	"changed", "negative_old", "negative_mutation"]

var _checks: int = 0
var _failures: int = 0
var _triangles: int = 0
var _body_rows: Array[Dictionary] = []


func _ready() -> void:
	var code: String = FileAccess.get_file_as_string(SOURCE)
	_check(code.count(ADDED_LINE) == 1, "exactly one public flat-normal declaration")
	_check(code.replace(ADDED_LINE, "").sha256_text() == OLD_SHA,
		"removing only that line restores the exact accepted public source")
	var source: StadiumHillsidePublicBoundarySource = StadiumHillsidePublicBoundarySource.new()
	var built: bool = source.build()
	_check(built, "actual public boundary builds with the exact production script")
	if not built:
		source.free()
		_finish()
		return
	var graph: StadiumHillsidePublicBoundary = StadiumHillsidePublicBoundary.create_hillside()
	_check(source.graph.get_script() == StadiumHillsidePublicBoundary
		and source.graph.signature() == graph.signature()
		and source.graph.segments() == graph.segments()
		and source.graph.polygon() == graph.polygon(), "unchanged canonical graph")
	var retained: Node = PREREQUISITE.new()
	_check(retained._boundary_geometry_exact(source), "accepted prerequisite exact geometry oracle")
	retained.free()
	var totals: Dictionary = {}
	for key: String in COMPARISONS:
		totals[key] = true
	var expected_ids: Array[String] = []
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		if rows[index].role.begins_with("DUGOUT"):
			continue
		expected_ids.append(rows[index].id)
		var body: StaticBody3D = source.get_node_or_null(rows[index].id) as StaticBody3D
		var result: Dictionary = _compare_body(source, body, graph, rows[index], index, rows.size())
		for key: String in COMPARISONS:
			totals[key] = bool(totals[key]) and bool(result.get(key, false))
		_body_rows.append({"id": rows[index].id, "comparisons": result})
	for key: String in COMPARISONS:
		_check(totals[key], key)
	var actual_ids: Array[String] = []
	for body: StaticBody3D in source.bodies:
		actual_ids.append(String(body.name))
	_check(actual_ids == expected_ids and actual_ids.size() == 10
		and source.slice_count > 0 and source.slice_count <= StadiumHillsideBoundaryBody.MAX_SLICES
		and _triangles > 0 and _triangles <= MAX_TRIANGLES,
		"ten retained non-dugout segments and bounded complete triangle coverage")
	source.free()
	_check(_checks == EXPECTED_CHECKS - 1, "fixed assertion inventory")
	_finish()


func _compare_body(source: StadiumHillsidePublicBoundarySource, body: StaticBody3D,
	graph: StadiumHillsidePublicBoundary, row: Dictionary, index: int, count: int) -> Dictionary:
	if body == null or body.get_parent() != source:
		return {}
	var visual: MeshInstance3D = body.get_node_or_null("TerrainConformedPanels") as MeshInstance3D
	if visual == null or not visual.mesh is ArrayMesh or visual.mesh.get_surface_count() != 1:
		return {}
	var old: Dictionary = _old_geometry(graph, row, index, count)
	var actual: Array = visual.mesh.surface_get_arrays(0)
	var previous: Array = old.mesh.surface_get_arrays(0)
	if actual.size() != Mesh.ARRAY_MAX or previous.size() != Mesh.ARRAY_MAX:
		return {}
	var vertices: PackedVector3Array = actual[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = actual[Mesh.ARRAY_NORMAL]
	var old_normals: PackedVector3Array = previous[Mesh.ARRAY_NORMAL]
	if not actual[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
		return {}
	var tangents: PackedFloat32Array = actual[Mesh.ARRAY_TANGENT]
	if vertices.is_empty() or vertices.size() % 3 != 0 or vertices.size() / 3 > MAX_TRIANGLES \
		or normals.size() != vertices.size() or old_normals.size() != vertices.size() \
		or not _empty_index(actual[Mesh.ARRAY_INDEX]) or not _empty_index(previous[Mesh.ARRAY_INDEX]):
		return {}
	_triangles += vertices.size() / 3
	var result: Dictionary = {}
	result.vertex_index = vertices == previous[Mesh.ARRAY_VERTEX] \
		and actual[Mesh.ARRAY_INDEX] == previous[Mesh.ARRAY_INDEX]
	result.other_arrays = true
	for slot in range(Mesh.ARRAY_MAX):
		if slot not in [Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT] \
			and actual[slot] != previous[slot]:
			result.other_arrays = false
	result.bounds = visual.mesh.get_aabb() == old.mesh.get_aabb()
	result.transforms = source.transform == Transform3D.IDENTITY \
		and body.transform == Transform3D.IDENTITY and visual.transform == Transform3D.IDENTITY
	var shapes: Array[CollisionShape3D] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	result.shape_points = shapes.size() == old.points.size()
	for shape_index in range(shapes.size()):
		var shape_node: CollisionShape3D = shapes[shape_index]
		result.transforms = result.transforms and shape_node.transform == Transform3D.IDENTITY
		if shape_index >= old.points.size() or not shape_node.shape is ConvexPolygonShape3D \
			or shape_node.disabled or shape_node.shape.margin != 0.0 \
			or shape_node.shape.points != old.points[shape_index]:
			result.shape_points = false
	result.materials = _same_material(visual.material_override, row.role)
	result.metadata = body.collision_layer == (1 | StadiumHillsidePublicBoundarySource.QUERY_MASK) \
		and body.collision_mask == 2 and body.get_meta("boundary_segment", "") == row.id \
		and body.get_meta("ball_surface", "") == &"stadium_boundary" \
		and body.get_meta("club_surface", "") == row.id \
		and body.get_meta("surface_role", "") == row.role \
		and body.get_meta("surface_priority", -1) == row.priority \
		and body.get_meta("surface_kind", "") == "boundary"
	result.finite_flat = _flat(normals) and _finite_tangents(tangents, vertices.size())
	var canonical: Dictionary = _canonical_triangle_channels(vertices)
	result.canonical = normals == canonical.normals and tangents == canonical.tangents
	result.outward = _outward(vertices, normals, old.points)
	result.changed = normals != old_normals
	result.negative_old = old_normals != canonical.normals and not _flat(old_normals)
	var mutation: PackedVector3Array = normals.duplicate()
	mutation[0] = -mutation[0]
	var tangent_mutation: PackedFloat32Array = tangents.duplicate()
	if tangent_mutation.is_empty():
		return {}
	tangent_mutation[0] += 1.0
	result.negative_mutation = mutation != canonical.normals and not _flat(mutation) \
		and tangent_mutation != canonical.tangents
	return result


func _old_geometry(graph: StadiumHillsidePublicBoundary, row: Dictionary,
	index: int, count: int) -> Dictionary:
	# Exact old _slab geometry algorithm, without its node creation or new smoothing declaration.
	var corners: PackedVector2Array = [row.a, row.b,
		graph.outer_vertex((index + 1) % count), graph.outer_vertex(index)]
	var parts: Array[PackedVector2Array] = StadiumHillsideBoundaryBody._split_at_knots(corners)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var all_points: Array[PackedVector3Array] = []
	for part: PackedVector2Array in parts:
		var points: PackedVector3Array = []
		for lift: float in [0.0, float(row.height)]:
			for corner: Vector2 in part:
				var support: float = StadiumHillsideTerrain.support_height(corner, "hill")
				points.append(Vector3(corner.x, support + lift, corner.y))
		all_points.append(points)
		StadiumHillsideBoundaryBody._add_prism(surface, points, part.size())
	surface.generate_normals()
	return {"mesh": surface.commit(), "points": all_points}


func _canonical_triangle_channels(vertices: PackedVector3Array) -> Dictionary:
	# One isolated triangle cannot average across any neighboring face or internal cap.
	# Committing each probe uses native normal storage and normal-derived fallback tangents.
	var result: Dictionary = {"normals": PackedVector3Array(), "tangents": PackedFloat32Array()}
	for offset in range(0, vertices.size(), 3):
		var triangle: SurfaceTool = SurfaceTool.new()
		triangle.begin(Mesh.PRIMITIVE_TRIANGLES)
		triangle.set_smooth_group(-1)
		for corner in range(3):
			triangle.add_vertex(vertices[offset + corner])
		triangle.generate_normals()
		var arrays: Array = triangle.commit().surface_get_arrays(0)
		result.normals.append_array(arrays[Mesh.ARRAY_NORMAL])
		result.tangents.append_array(arrays[Mesh.ARRAY_TANGENT])
	return result


func _finite_tangents(tangents: PackedFloat32Array, vertices: int) -> bool:
	if vertices <= 0 or tangents.size() != vertices * 4:
		return false
	for value: float in tangents:
		if not is_finite(value):
			return false
	return true


func _flat(normals: PackedVector3Array) -> bool:
	if normals.is_empty() or normals.size() % 3 != 0:
		return false
	for offset in range(0, normals.size(), 3):
		if not normals[offset].is_finite() or normals[offset] == Vector3.ZERO \
			or normals[offset] != normals[offset + 1] or normals[offset] != normals[offset + 2]:
			return false
	return true


func _outward(vertices: PackedVector3Array, normals: PackedVector3Array,
	parts: Array[PackedVector3Array]) -> bool:
	var offset: int = 0
	for points: PackedVector3Array in parts:
		var center: Vector3 = Vector3.ZERO
		for point: Vector3 in points:
			center += point
		center /= points.size()
		var face_count: int = 4 * (points.size() >> 1) - 4
		for face in range(face_count):
			if offset + 2 >= vertices.size():
				return false
			var midpoint: Vector3 = (vertices[offset] + vertices[offset + 1]
				+ vertices[offset + 2]) / 3.0
			if normals[offset].dot(midpoint - center) <= 0.0:
				return false
			offset += 3
	return offset == vertices.size()


func _same_material(actual: Material, role: String) -> bool:
	if not actual is StandardMaterial3D:
		return false
	var expected: StandardMaterial3D = StandardMaterial3D.new()
	expected.albedo_color = Color("507f96") if role == "BACK_WALL_TERMINAL" else Color("897756")
	expected.roughness = 0.9
	expected.cull_mode = BaseMaterial3D.CULL_DISABLED
	for property: Dictionary in expected.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			if actual.get(property.name) != expected.get(property.name):
				return false
	return true


func _empty_index(value: Variant) -> bool:
	return value == null or (value is PackedInt32Array and value.is_empty())


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("HILLSIDE_WALL_NORMALS: " + label)


func _finish() -> void:
	if _checks != EXPECTED_CHECKS:
		_failures += 1
		push_error("HILLSIDE_WALL_NORMALS: assertion inventory differs")
	for row: Dictionary in _body_rows:
		print("HILLSIDE_WALL_NORMALS_BODY " + JSON.stringify(row, "", true, true))
	print("HILLSIDE_WALL_NORMALS_PROOF " + JSON.stringify({"checks": _checks,
		"failures": _failures, "bodies": _body_rows.size(), "triangles": _triangles,
		"maximum_triangles": MAX_TRIANGLES, "production_change": "one-public-smoothing-line",
		"native_resource_comparison_only": true, "rendered_acceptance": false,
		"physical_contacts": 0, "ordinary_plays": 0, "games": 0}, "", true, true))
	print("HILLSIDE_WALL_NORMALS checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

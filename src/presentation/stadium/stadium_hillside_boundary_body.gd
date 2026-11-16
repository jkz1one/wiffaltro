class_name StadiumHillsideBoundaryBody
extends StadiumRecipeBoundaryBody
## Private Working same-XZ perimeter. Shared ordinary bind/contact batch stays inherited.
## Each closed slice is planar over one retained terrain interval; panels use its exact points.

const MAX_SLICES: int = 256
var last_error: String = "A private build and retained terrain validation are required."
var _profile: String = ""
var _built_graph: StadiumHillsideBoundary
var _built_signature: String = ""
var _terrain_signature: String = ""
var _segment_ids: Array[String] = []
var _body_child_counts: Array[int] = []
var _materials: Array[StandardMaterial3D] = []
var _invalidated: bool = false
var _bodies: Array[StaticBody3D] = []
var _shapes: Array[CollisionShape3D] = []
var _shape_resources: Array[ConvexPolygonShape3D] = []
var _shape_body_indices: Array[int] = []
var _visuals: Array[MeshInstance3D] = []
var _mesh_resources: Array[ArrayMesh] = []
var _bounds: Array[AABB] = []
var _terrain: Node3D
var _terrain_body: StaticBody3D
var _terrain_shape_node: CollisionShape3D
var _terrain_shape: ConcavePolygonShape3D


func build(_recipe: String = "straight", _material_id: String = "ST-024") -> bool:
	last_error = "Use the explicit private build_hillside API."
	return false


func build_owned(_walls: Dictionary, _stock: StadiumStock) -> bool:
	last_error = "The private Hillside perimeter has no owned or public installation."
	return false


func build_hillside(profile: String = "hill", material_id: String = "ST-024") -> bool:
	if get_child_count() != 0 or _built_graph != null or get_script() != StadiumHillsideBoundaryBody \
		or not StadiumHillsideTerrain.PROFILES.has(profile) or material_id != "ST-024" \
		or transform != Transform3D.IDENTITY:
		last_error = "An empty identity-transform private body and retained ST-024 are required."
		return false
	_profile = profile
	_built_graph = StadiumHillsideBoundary.create_hillside(profile)
	graph = _built_graph
	_built_signature = graph.signature()
	_terrain_signature = StadiumHillsideTerrain.signature(profile)
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var corners: PackedVector2Array = [row.a, row.b,
			graph.outer_vertex((index + 1) % rows.size()), graph.outer_vertex(index)]
		var parts: Array[PackedVector2Array] = _split_at_knots(corners)
		if parts.is_empty() or _shapes.size() + parts.size() > MAX_SLICES:
			_invalidate()
			last_error = "The bounded retained-knot tessellation could not be built."
			return false
		var body: StaticBody3D = StaticBody3D.new()
		body.name = row.id
		body.collision_layer = 1
		body.collision_mask = 2
		body.set_meta("boundary_segment", row.id)
		body.set_meta("ball_surface", &"stadium_boundary")
		var surface: SurfaceTool = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: PackedVector2Array in parts:
			var points: PackedVector3Array = _prism_points(part, float(row.height))
			if points.is_empty():
				body.free()
				_invalidate()
				last_error = "A wall slice left the retained terrain support bounds."
				return false
			var shape_node: CollisionShape3D = CollisionShape3D.new()
			shape_node.name = "TerrainSlice%03d" % _shapes.size()
			var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
			shape.margin = 0.0
			shape.points = points
			shape_node.shape = shape
			body.add_child(shape_node)
			_shapes.append(shape_node)
			_shape_resources.append(shape)
			_shape_body_indices.append(index)
			shape.changed.connect(_invalidate)
			var box: AABB = AABB(points[0], Vector3.ZERO)
			for point_value: Vector3 in points:
				box = box.expand(point_value)
			_bounds.append(box)
			_add_prism(surface, points, part.size())
		surface.generate_normals()
		var mesh: ArrayMesh = surface.commit()
		var visual: MeshInstance3D = MeshInstance3D.new()
		visual.name = "TerrainConformedPanels"
		visual.mesh = mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color("507f96") if row.role == "BACK_WALL_TERMINAL" \
			else Color("897756")
		material.roughness = 0.9
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		visual.material_override = material
		body.add_child(visual)
		add_child(body)
		_bodies.append(body)
		_segment_ids.append(row.id)
		_body_child_counts.append(body.get_child_count())
		_materials.append(material)
		_visuals.append(visual)
		_mesh_resources.append(mesh)
		mesh.changed.connect(_invalidate)
		material.changed.connect(_invalidate)
	set_meta("production_ready", false)
	set_meta("terrain_profile", profile)
	set_meta("perimeter_signature", _built_signature)
	last_error = ""
	return true


func retained_valid(terrain: Node3D) -> bool:
	if _invalidated or _built_graph == null or graph != _built_graph \
		or get_script() != StadiumHillsideBoundaryBody or not is_inside_tree() \
		or is_queued_for_deletion() or not visible or global_transform != Transform3D.IDENTITY \
		or graph.get_script() != StadiumHillsideBoundary or graph._shape != "deeper_center" \
		or _built_graph.terrain_profile != _profile or get_child_count() != _bodies.size() \
		or not is_instance_valid(terrain) or not terrain.is_inside_tree() \
		or terrain.is_queued_for_deletion() or terrain.global_transform != Transform3D.IDENTITY \
		or terrain.get_world_3d() != get_world_3d() \
		or terrain.get_meta("terrain_profile", "") != _profile \
		or terrain.get_meta("terrain_signature", "") != _terrain_signature:
		return false
	if _terrain == null and not _capture_terrain(terrain):
		return false
	if terrain != _terrain or not _terrain_structure_valid():
		return false
	# Identity/transform checks only. Never extract full geometry on the hot path.
	for index in range(_bodies.size()):
		var body: StaticBody3D = _bodies[index]
		var visual: MeshInstance3D = _visuals[index]
		if not is_instance_valid(body) or body.is_queued_for_deletion() \
			or body.get_parent() != self or not body.visible or body.transform != Transform3D.IDENTITY \
			or body.collision_layer != 1 or body.collision_mask != 2 \
			or body.get_child_count() != _body_child_counts[index] \
			or body.get_meta("boundary_segment", "") != _segment_ids[index] \
			or body.get_meta("ball_surface", "") != &"stadium_boundary" \
			or not is_instance_valid(visual) or visual.is_queued_for_deletion() \
			or visual.get_parent() != body or visual.transform != Transform3D.IDENTITY \
			or not visual.visible or visual.mesh != _mesh_resources[index] \
			or visual.material_override != _materials[index]:
			return false
	for index in range(_shapes.size()):
		var shape_node: CollisionShape3D = _shapes[index]
		if not is_instance_valid(shape_node) or shape_node.is_queued_for_deletion() \
			or shape_node.get_parent() != _bodies[_shape_body_indices[index]] \
			or shape_node.transform != Transform3D.IDENTITY or shape_node.disabled \
			or shape_node.shape != _shape_resources[index]:
			return false
	return true


func _capture_terrain(terrain: Node3D) -> bool:
	# Cold exact geometry check, once. Resource mutation is latched by changed below.
	var terrain_body: StaticBody3D = terrain.get_node_or_null("TerrainCollision") as StaticBody3D
	var terrain_node: CollisionShape3D = terrain.get_node_or_null(
		"TerrainCollision/ClosedTerrainShape") as CollisionShape3D
	if terrain_body == null or terrain_node == null:
		return false
	var terrain_shape: ConcavePolygonShape3D = terrain_node.shape as ConcavePolygonShape3D
	if terrain_shape == null \
		or terrain_shape.get_faces() != StadiumHillsideTerrainModels.geometry(_profile).faces:
		return false
	_terrain = terrain
	_terrain_body = terrain_body
	_terrain_shape_node = terrain_node
	_terrain_shape = terrain_shape
	_terrain_shape.changed.connect(_invalidate)
	_terrain.tree_exiting.connect(_invalidate)
	_terrain_body.tree_exiting.connect(_invalidate)
	_terrain_shape_node.tree_exiting.connect(_invalidate)
	return true


func _terrain_structure_valid() -> bool:
	if not is_instance_valid(_terrain_body) or _terrain_body.is_queued_for_deletion() \
		or _terrain.get_node_or_null("TerrainCollision") != _terrain_body \
		or _terrain_body.transform != Transform3D.IDENTITY \
		or _terrain_body.get_meta("ball_surface", "") != StadiumHillsideTerrainModels.SURFACE \
		or _terrain_body.get_meta("terrain_profile", "") != _profile \
		or not is_instance_valid(_terrain_shape_node) or _terrain_shape_node.is_queued_for_deletion() \
		or _terrain_body.get_node_or_null("ClosedTerrainShape") != _terrain_shape_node \
		or _terrain_shape_node.disabled or _terrain_shape_node.transform != Transform3D.IDENTITY \
		or _terrain_shape_node.shape != _terrain_shape or _terrain_shape == null \
		or _terrain_shape.margin != 0.0 or _terrain_shape.backface_collision:
		return false
	var required: int = 1 | StadiumHillsideTerrainModels.QUERY_LAYER
	return (_terrain_body.collision_layer & required) == required \
		and (_terrain_body.collision_mask & 2) == 2


func visibility_bounds() -> Array[AABB]:
	return _bounds.duplicate()


func geometry_report() -> Dictionary:
	return {"status": "WORKING_PRIVATE_NATIVE_UNQUALIFIED", "segments": _bodies.size(),
		"slices": _shapes.size(), "maximum_slices": MAX_SLICES, "profile": _profile,
		"xz": "unchanged-deeper-center", "max_legal_center_z": 26.0,
		"max_defender_center_z": 26.0 - StadiumRecipeBoundary.DEFENDER_RADIUS,
		"analytic_support_error_m": 0.0, "native_support_error_status": "unmeasured",
		"design_error_bound_m": StadiumHillsideTerrain.MAX_LINEAR_ERROR,
		"height_definition": "vertical-sampled-support-plus-retained-relative-height",
		"visual": "same-slice-points-as-collision", "production_ready": false}


func _invalidate() -> void:
	_invalidated = true
	last_error = "The retained perimeter or terrain changed; build a fresh private boundary."


func _prism_points(corners: PackedVector2Array, height: float) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for lift: float in [0.0, height]:
		for corner: Vector2 in corners:
			var support: float = StadiumHillsideTerrain.support_height(corner, _profile)
			if not is_finite(support):
				return []
			result.append(Vector3(corner.x, support + lift, corner.y))
	return result


static func _split_at_knots(corners: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var low: float = corners[0].y
	var high: float = low
	for corner: Vector2 in corners:
		low = minf(low, corner.y)
		high = maxf(high, corner.y)
	var cuts: PackedFloat64Array = [low]
	for knot: float in StadiumHillsideTerrain.knots():
		if knot > low and knot < high:
			cuts.append(knot)
	cuts.append(high)
	for index in range(cuts.size() - 1):
		var part: PackedVector2Array = _clip_z(_clip_z(corners, cuts[index], true),
			cuts[index + 1], false)
		if part.size() >= 3:
			result.append(part)
	return result


static func _clip_z(corners: PackedVector2Array, z: float, above: bool) -> PackedVector2Array:
	var result: PackedVector2Array = []
	if corners.is_empty():
		return result
	var previous: Vector2 = corners[-1]
	var previous_inside: bool = previous.y >= z if above else previous.y <= z
	for current: Vector2 in corners:
		var current_inside: bool = current.y >= z if above else current.y <= z
		if current_inside != previous_inside:
			var weight: float = (z - previous.y) / (current.y - previous.y)
			var at: Vector2 = previous.lerp(current, weight)
			at.y = z
			_append_unique(result, at)
		if current_inside:
			_append_unique(result, current)
		previous = current
		previous_inside = current_inside
	if result.size() > 1 and result[0].distance_squared_to(result[-1]) <= 0.000000000001:
		result.remove_at(result.size() - 1)
	return result


static func _append_unique(points: PackedVector2Array, at: Vector2) -> void:
	if points.is_empty() or points[-1].distance_squared_to(at) > 0.000000000001:
		points.append(at)


static func _add_prism(surface: SurfaceTool, points: PackedVector3Array, count: int) -> void:
	# Double-sided panels deliberately retain exactly the physical convex-prism vertices.
	for index in range(1, count - 1):
		_triangle(surface, points[0], points[index], points[index + 1])
		_triangle(surface, points[count], points[count + index + 1], points[count + index])
	for index in range(count):
		var next: int = (index + 1) % count
		_triangle(surface, points[index], points[count + next], points[next])
		_triangle(surface, points[index], points[count + index], points[count + next])


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

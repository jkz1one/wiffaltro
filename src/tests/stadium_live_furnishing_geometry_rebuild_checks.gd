class_name StadiumLiveFurnishingGeometryRebuildChecks
extends RefCounted
## Shared geometry support only, not a second runner. Native checks run in the caller.
## Successful path: 3 + 2*(1+16) + 5 beach + 12 tub + 8 wobble = 62 checks.

const M = preload("res://src/presentation/stadium/stadium_live_furnishing_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const ITEMS: Array[String] = ["ST-002", "ST-007"]
const COMMON_CHECKS: int = 16
const BEACH_CHECKS: int = 5
const TUB_CHECKS: int = 12
const WOBBLE_CHECKS: int = 8
const EXPECTED_CHECKS: int = 62
const EPS: float = 0.0002


static func expected_checks() -> int:
	return 3 + ITEMS.size() * (1 + COMMON_CHECKS) + BEACH_CHECKS + TUB_CHECKS + WOBBLE_CHECKS


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "LiveFurnishingGeometryProbe"
	parent.add_child(probe)
	probe.position = Vector3(1800, 0, 0)
	_emit(
		check,
		M.VERSION == 1 and M.ITEMS == ITEMS and expected_checks() == EXPECTED_CHECKS,
		"one exact two-item family and source-derived successful-path check budget"
	)
	_emit(
		check,
		(
			M.create("ST-006") == null
			and M.create("") == null
			and M.envelope("ST-006") == AABB()
			and M.reservation("ST-006") == AABB()
			and M.surfaces("ST-006").is_empty()
		),
		"the separate ST-006 family is never substituted"
	)
	_emit(
		check,
		(
			(
				FileAccess.get_sha256(
					"res://src/presentation/stadium/stadium_ground_props_models.gd"
				)
				== "126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4"
			)
			and (
				FileAccess.get_sha256("res://src/presentation/stadium/stadium_starter_models.gd")
				== "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
			)
		),
		"existing ground-prop and starter factories stay byte-exact"
	)
	for item: String in ITEMS:
		var model: Node3D = M.create(item, true)
		_emit(check, model != null, "complete live furnishing creates", {"item": item})
		if model == null:
			continue
		probe.add_child(model)
		await _common(probe, model, item, check)
		if item == "ST-002":
			_beach(model, check)
			_wobble(model, check)
		else:
			await _tub(model, check)
		model.free()
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"LIVE_FURNISHING_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _common(probe: Node3D, model: Node3D, item: String, check: Callable) -> void:
	var visual: Node3D = model.get_node("Visual")
	var collision: Node3D = model.get_node("Collision")
	_emit(
		check,
		(
			model.transform == Transform3D.IDENTITY
			and visual.transform == Transform3D.IDENTITY
			and collision.transform == Transform3D.IDENTITY
			and model.get_child_count() == (3 if item == "ST-007" else 2)
		),
		"identity visual and physical branches have no hidden placement offset",
		{"item": item}
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == item
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("live_furnishing")
			and not model.get_meta("scenery_only")
		),
		"exact live identity is carried by the root",
		{"item": item}
	)
	var visible_box: AABB = (
		AABB(Vector3(-0.4, 0, -0.4), Vector3(0.8, 0.8, 0.8))
		if item == "ST-002"
		else AABB(Vector3(-1.3, 0, -1.3), Vector3(2.6, 1, 2.6))
	)
	var reserve: AABB = (
		AABB(Vector3(-1, 0, -1), Vector3(2, 1.5, 2))
		if item == "ST-002"
		else AABB(Vector3(-1.75, 0, -1.75), Vector3(3.5, 1.5, 3.5))
	)
	_emit(
		check,
		(
			M.envelope(item) == visible_box
			and M.reservation(item) == reserve
			and model.get_meta("envelope") == visible_box
			and model.get_meta("reservation") == reserve
		),
		"visible dimensions and reserved clearance remain separate exact quantities",
		{"item": item}
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		str(scan.failure).is_empty() and scan.types == ["ArrayMesh"] and int(scan.vertices) > 500,
		"every actual mesh array and vertex normal validates",
		{"item": item, "scan": scan}
	)
	_emit(
		check,
		_winding(model) and SCAN._appearance_failure(model).is_empty(),
		"all real triangles face their declared unit normals with plain opaque materials",
		{"item": item}
	)
	var points: PackedVector3Array = _points(model)
	var actual: AABB = SCAN._bounds(points)
	_emit(
		check,
		(
			actual.position.is_equal_approx(visible_box.position)
			and actual.size.is_equal_approx(visible_box.size)
		),
		"complete actual art reaches the authored dimensions rather than a tiny proxy",
		{"item": item, "actual": str(actual)}
	)
	_emit(
		check,
		reserve.grow(EPS).encloses(actual),
		"every visible vertex fits the full reservation",
		{"item": item}
	)
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	var body: StaticBody3D = bodies[0] as StaticBody3D if bodies.size() == 1 else null
	_emit(
		check,
		(
			body != null
			and str(body.name) == M.surfaces(item)[0]
			and body.get_parent() == collision
			and body.get_meta("stadium_item") == item
			and body.get_meta("surface_id") == str(body.name)
			and body.get_meta("surface_role") == "LIVE_RICOCHET"
			and body.collision_layer == 1
			and body.collision_mask == 0
			and body.constant_linear_velocity == Vector3.ZERO
			and body.constant_angular_velocity == Vector3.ZERO
		),
		"one fixed named live body owns only its exact item",
		{"item": item}
	)
	_emit(
		check,
		_physical_points_valid(model, visible_box),
		"all actual convex shapes have zero margin and occupy the visible solid bounds",
		{"item": item}
	)
	var scenery: Node3D = M.create(item, false)
	probe.add_child(scenery)
	_emit(
		check,
		_visual_signature(model) == _visual_signature(scenery),
		"live and scenery copies have byte-identical visible meshes poses and materials",
		{"item": item}
	)
	_emit(
		check,
		(
			scenery.get_node("Collision").get_child_count() == 0
			and scenery.find_children("*", "CollisionObject3D", true, false).is_empty()
			and scenery.find_children("*", "CollisionShape3D", true, false).is_empty()
			and not scenery.has_node("WaterVolume")
			and _no_live_metadata(scenery)
		),
		"scenery has no physical body, scoring carrier or live surface metadata",
		{"item": item}
	)
	var second: Node3D = M.create(item, true)
	probe.add_child(second)
	_emit(
		check,
		_independent(model, second) and _independent(model, scenery),
		"all mesh material and shape resources are independent between copies",
		{"item": item}
	)
	var before: String = _visual_signature(model)
	var physical_before: PackedByteArray = var_to_bytes(_physical_state(model))
	_emit(
		check,
		(
			before == _visual_signature(second)
			and physical_before == var_to_bytes(_physical_state(second))
		),
		"fresh copies reproduce actual visible and physical resources deterministically",
		{"item": item}
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		(
			_visual_signature(model) == before
			and var_to_bytes(_physical_state(model)) == physical_before
			and _visual_signature(second) != before
		),
		"destructive mutation cannot alter another owned copy",
		{"item": item}
	)
	second.free()
	var fresh: Node3D = M.create(item, true)
	probe.add_child(fresh)
	_emit(
		check,
		(
			_visual_signature(fresh) == before
			and var_to_bytes(_physical_state(fresh)) == physical_before
		),
		"factory regeneration remains unchanged after foreign copy mutation",
		{"item": item}
	)
	fresh.free()
	scenery.free()
	await probe.get_tree().process_frame
	_emit(
		check,
		(
			_visual_signature(model) == before
			and var_to_bytes(_physical_state(model)) == physical_before
		),
		"an idle rendered frame moves no furnishing or physical shape",
		{"item": item}
	)


static func _beach(model: Node3D, check: Callable) -> void:
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	_emit(
		check,
		(
			meshes.size() == 9
			and SCAN._members(model, "BeachPanel").size() == 6
			and model.has_node("Visual/BallPivot/BeachNorthPatch")
			and model.has_node("Visual/BallPivot/BeachSouthPatch")
		),
		"beach ball has six stitched-color panels and both polar patches"
	)
	var colors: Dictionary = {}
	for mesh: MeshInstance3D in SCAN._members(model, "BeachPanel"):
		colors[mesh.material_override.albedo_color.to_html()] = true
	_emit(
		check,
		colors.size() == 4,
		"three colored longitudinal panels alternate with warm white panels"
	)
	var valve: MeshInstance3D = model.get_node("Visual/BallPivot/BeachValve")
	var valve_points: PackedVector3Array = valve.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_emit(
		check,
		(
			valve_points.size() == 144
			and SCAN._bounds(valve_points).position.y > 0.396
			and (
				valve.material_override.albedo_color
				!= model.get_node("Visual/BallPivot/BeachNorthPatch").material_override.albedo_color
			)
		),
		"small inset valve is real bounded cap geometry with distinct material"
	)
	var expected: PackedVector3Array = M.beach_points()
	var actual: PackedVector3Array = model.get_node("Collision/BEACH_BALL/RestSphere").shape.points
	var seen: Dictionary = {}
	var on_surface: bool = true
	for point: Vector3 in _points(model):
		var local: Vector3 = point - M.BEACH_CENTER
		on_surface = (
			on_surface
			and absf(local.length() - M.BEACH_RADIUS) < EPS
			and _has_point(expected, local)
		)
		seen[_point_key(local)] = true
	_emit(
		check,
		actual == expected and on_surface and seen.size() == expected.size(),
		"all panel vertices and the fixed convex hull share the exact same closed rest sphere"
	)
	_emit(
		check,
		(
			model.get_node("Collision/BEACH_BALL").position == M.BEACH_CENTER
			and model.get_node("Collision/BEACH_BALL/RestSphere").transform == Transform3D.IDENTITY
			and model.get_node("Visual/BallPivot").position == M.BEACH_CENTER
		),
		"physical and visual sphere centers begin at the same fixed ground-supported point"
	)


static func _tub(model: Node3D, check: Callable) -> void:
	var body: StaticBody3D = model.get_node("Collision/HOT_TUB_SHELL")
	_emit(
		check,
		(
			model.find_children("*", "MeshInstance3D", true, false).size() == 72
			and SCAN._members(model, "TubWoodStave").size() == 64
			and SCAN._members(model, "TubRetainingBand").size() == 2
		),
		"complete tub includes sixty-four individually colored wood staves and two retaining bands"
	)
	_emit(
		check,
		body.transform == Transform3D.IDENTITY and body.get_child_count() == 65,
		"one tub shell body owns sixty-four hollow segments and one shallow basin floor"
	)
	var segments_match: bool = true
	for index in range(M.TUB_SEGMENTS):
		var shape: CollisionShape3D = body.get_node("AnnularSegment%02d" % index)
		segments_match = (
			segments_match
			and shape.shape.points == M.tub_segment_points(index)
			and shape.shape.points[1] == M.tub_segment_points(index + 1)[0]
		)
	_emit(
		check,
		segments_match,
		"every actual annular collider uses the shared polygon and closes exactly at its neighbor"
	)
	_emit(
		check,
		(
			body.get_node("BasinFloor").shape.points == M.tub_floor_points()
			and (
				SCAN._bounds(body.get_node("BasinFloor").shape.points).end.y
				== PackedFloat32Array([M.TUB_FLOOR])[0]
			)
		),
		"solid interior floor is only eight centimetres deep and cannot become an aperture lid"
	)
	_emit(
		check,
		_tub_visible_surfaces(model),
		"all shell art lies on the actual hull faces or the shallow floor, without a proxy cylinder"
	)
	var water: MeshInstance3D = model.get_node("Visual/TubWater")
	var water_points: PackedVector3Array = water.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var exact_water: bool = water_points.size() == M.TUB_SEGMENTS * 3
	for point: Vector3 in water_points:
		exact_water = (
			exact_water
			and absf(point.y - M.TUB_WATER) < EPS
			and (
				Vector2(point.x, point.z).length() < EPS
				or _has_polygon_point(M.water_polygon(), Vector2(point.x, point.z))
			)
		)
	_emit(
		check,
		(
			exact_water
			and water.transform == Transform3D.IDENTITY
			and water.get_meta("aperture_id") == M.TUB_WATER_ID
		),
		"visible water is exactly the sixty-four-sided inner aperture at the approved height"
	)
	var volume: Node3D = model.get_node("WaterVolume")
	_emit(
		check,
		(
			volume.get_class() == "Node3D"
			and volume.transform == Transform3D.IDENTITY
			and volume.get_child_count() == 0
			and volume.get_meta("volume_id") == "ST007_WATER_VOLUME_v1"
			and volume.get_meta("floor") == 0.08
			and volume.get_meta("height") == 0.78
			and volume.get_meta("polygon") == M.water_polygon()
		),
		"water descriptor is exact nonphysical data with no Area3D or hidden sensor"
	)
	var colors: Dictionary = {}
	for mesh: MeshInstance3D in SCAN._members(model, "TubWoodStave"):
		colors[mesh.material_override.albedo_color.to_html()] = true
	_emit(
		check,
		(
			colors.size() == 4
			and model.has_node("Visual/TubInnerLiner")
			and model.has_node("Visual/TubContinuousRim")
			and model.has_node("Visual/TubBasinFloor")
		),
		"wood variation, pale liner, continuous rim and basin are separate real anatomy"
	)
	_emit(
		check,
		(
			M.water_polygon().size() == 64
			and M.water_polygon() == M.tub_polygon(1.05)
			and M.tub_point(1.05, 0.78, 64) == M.tub_point(1.05, 0.78, 0)
		),
		"analytic aperture and visual seam use exactly the same polygon rather than a circumscribed disk"
	)
	await model.get_tree().physics_frame
	await model.get_tree().physics_frame
	var center_ray: Dictionary = _ray(model, Vector3(0, 1.5, 0), Vector3(0, 0.2, 0))
	_emit(
		check,
		center_ray.is_empty(),
		"actual native ray enters open water without striking an invented solid lid",
		{"hit": str(center_ray)}
	)
	var rim_ray: Dictionary = _ray(model, Vector3(1.18, 1.5, 0), Vector3(1.18, 0.4, 0))
	_emit(
		check,
		rim_ray.get("collider") == body and absf(model.to_local(rim_ray.position).y - 1.0) < 0.003,
		"actual native rim ray hits the same shell body at the visible one-metre rim",
		{"hit": str(rim_ray)}
	)
	var floor_ray: Dictionary = _ray(model, Vector3(0, 0.5, 0), Vector3(0, -0.2, 0))
	_emit(
		check,
		(
			floor_ray.get("collider") == body
			and absf(model.to_local(floor_ray.position).y - 0.08) < 0.003
		),
		"actual native interior ray reaches the visible shallow basin floor",
		{"hit": str(floor_ray)}
	)


static func _wobble(model: Node3D, check: Callable) -> void:
	var pivot: StadiumLiveFurnishingWobble = model.get_node("Visual/BallPivot")
	var physical: PackedByteArray = var_to_bytes(_physical_state(model))
	var root_pose: Transform3D = model.transform
	_emit(
		check,
		pivot.basis == Basis.IDENTITY and not pivot.is_processing(),
		"beach presentation is still before a real contact trigger"
	)
	M.contact_wobble(model, M.BEACH_CENTER + Vector3.RIGHT)
	_emit(
		check,
		pivot.is_processing() and pivot.position == M.BEACH_CENTER,
		"contact starts bounded visual-only wobble at the fixed center"
	)
	var bounded: bool = true
	var fixed: bool = true
	var moved: bool = false
	for step in range(33):
		pivot.apply_elapsed(pivot.DURATION * step / 32.0)
		moved = moved or pivot.basis != Basis.IDENTITY
		fixed = (
			fixed
			and model.transform == root_pose
			and pivot.position == M.BEACH_CENTER
			and var_to_bytes(_physical_state(model)) == physical
		)
		for point: Vector3 in _points(model):
			bounded = (
				bounded
				and (point - M.BEACH_CENTER).length() <= 0.40001
				and M.envelope("ST-002").grow(EPS).has_point(point)
			)
	_emit(
		check, moved, "contact produces an actual visible orientation and soft-compression response"
	)
	_emit(
		check,
		bounded,
		"every animated valve and panel vertex stays inside the declared rest-sphere footprint"
	)
	_emit(
		check,
		fixed,
		"every sampled root center and collider remains byte-exact during visual response"
	)
	_emit(
		check,
		(
			pivot.basis == Basis.IDENTITY
			and pivot.position == M.BEACH_CENTER
			and not pivot.is_processing()
		),
		"short response ends at the exact rest transform and stops processing"
	)
	M.wobble(model)
	pivot.apply_elapsed(0.10)
	var first: Basis = pivot.basis
	M.wobble(model)
	pivot.apply_elapsed(0.10)
	_emit(
		check,
		pivot.basis == first,
		"repeated same contact and elapsed time reproduce the same visual pose"
	)
	pivot.apply_elapsed(pivot.DURATION)
	var scenery: Node3D = M.create("ST-002", false)
	var before: String = _visual_signature(scenery)
	M.wobble(scenery)
	M.contact_wobble(model, Vector3.INF)
	_emit(
		check,
		(
			_visual_signature(scenery) == before
			and not scenery.get_node("Visual/BallPivot").is_processing()
			and pivot.basis == Basis.IDENTITY
			and not pivot.is_processing()
		),
		"scenery and nonfinite contact inputs cannot start ambient or physical motion"
	)
	scenery.free()


static func _ray(model: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.to_global(from), model.to_global(to), 1
	)
	return model.get_world_3d().direct_space_state.intersect_ray(query)


static func _local_pose(root: Node3D, node: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var current: Node = node.get_parent()
	while current != root and current is Node3D:
		result = (current as Node3D).transform * result
		current = current.get_parent()
	return result


static func _points(root: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var pose: Transform3D = _local_pose(root, mesh)
		for surface in range(mesh.mesh.get_surface_count()):
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				result.append(pose * point)
	return result


static func _visual_signature(root: Node3D) -> String:
	var state: Array = []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.material_override
		var row: Array = [
			str(mesh.name),
			_local_pose(root, mesh),
			material.albedo_color,
			material.roughness,
			material.transparency,
			material.shading_mode,
			mesh.mesh.get_surface_count()
		]
		for surface in range(mesh.mesh.get_surface_count()):
			row.append(mesh.mesh.surface_get_arrays(surface))
		state.append(row)
	return var_to_bytes(state).hex_encode().sha256_text()


static func _physical_state(root: Node3D) -> Array:
	var result: Array = []
	for body: StaticBody3D in root.find_children("*", "StaticBody3D", true, false):
		result.append(
			[
				str(body.name),
				_local_pose(root, body),
				body.collision_layer,
				body.collision_mask,
				body.constant_linear_velocity,
				body.constant_angular_velocity,
				body.get_meta("surface_id"),
				body.get_meta("surface_role")
			]
		)
		for shape: CollisionShape3D in body.get_children():
			result.append(
				[
					str(shape.name),
					shape.transform,
					shape.disabled,
					shape.shape.margin,
					shape.shape.points
				]
			)
	return result


static func _physical_points_valid(root: Node3D, envelope: AABB) -> bool:
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		if (
			not shape.shape is ConvexPolygonShape3D
			or shape.disabled
			or shape.shape.margin != 0.0
			or shape.transform != Transform3D.IDENTITY
			or shape.shape.points.size() < 8
		):
			return false
		for point: Vector3 in shape.shape.points:
			if (
				not point.is_finite()
				or not envelope.grow(EPS).has_point(_local_pose(root, shape) * point)
			):
				return false
	return true


static func _winding(root: Node3D) -> bool:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in range(mesh.mesh.get_surface_count()):
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in range(0, points.size(), 3):
				var cross_value: Vector3 = -(points[index + 1] - points[index]).cross(
					points[index + 2] - points[index]
				)
				if (
					cross_value.length_squared() < 0.000000000001
					or cross_value.dot(normals[index]) <= 0
				):
					return false
	return true


static func _resources(root: Node3D) -> Array[Resource]:
	var result: Array[Resource] = SCAN._resources(root)
	for shape: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		result.append(shape.shape)
	return result


static func _independent(first: Node3D, second: Node3D) -> bool:
	var original: Array[Resource] = _resources(first)
	var seen: Array[Resource] = []
	for resource: Resource in _resources(second):
		if resource == null or original.has(resource) or seen.has(resource):
			return false
		seen.append(resource)
	return true


static func _no_live_metadata(root: Node) -> bool:
	if root.has_meta("surface_role") or root.has_meta("surface_id") or root.has_meta("volume_id"):
		return false
	for child: Node in root.get_children():
		if not _no_live_metadata(child):
			return false
	return true


static func _point_key(point: Vector3) -> String:
	return (
		"%d:%d:%d" % [roundi(point.x * 100000), roundi(point.y * 100000), roundi(point.z * 100000)]
	)


static func _has_point(points: PackedVector3Array, target: Vector3) -> bool:
	for point: Vector3 in points:
		if point.distance_to(target) < EPS:
			return true
	return false


static func _has_polygon_point(points: PackedVector2Array, target: Vector2) -> bool:
	for point: Vector2 in points:
		if point.distance_to(target) < EPS:
			return true
	return false


static func _tub_visible_surfaces(root: Node3D) -> bool:
	var outer: PackedVector2Array = M.tub_polygon(M.TUB_OUTER)
	var inner: PackedVector2Array = M.water_polygon()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name) == "TubWater":
			continue
		for point: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var xz: Vector2 = Vector2(point.x, point.z)
			var outer_edge: bool = _has_polygon_point(outer, xz)
			var inner_edge: bool = _has_polygon_point(inner, xz)
			var disk_center: bool = (
				xz.length() < EPS and (absf(point.y) < EPS or absf(point.y - M.TUB_FLOOR) < EPS)
			)
			if (
				not (outer_edge or inner_edge or disk_center)
				or point.y < -EPS
				or point.y > M.TUB_TOP + EPS
			):
				return false
	return true

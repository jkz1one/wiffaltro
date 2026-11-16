class_name StadiumMoldedSeatGeometryRebuildChecks
extends RefCounted
## Finite native geometry support for the shared fixture, never another runner.
## Successful path: 1 + 6 foreign IDs + 2*4 frozen + 2*(1+13) + 8 + 12 + 4*3 = 75.

const M = preload("res://src/presentation/stadium/stadium_molded_seat_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 13
const SEAT_CHECKS: int = 8
const PAD_CHECKS: int = 12
const EXPECTED_CHECKS: int = 75
const FOREIGN: Array[String] = ["ST-003", "ST-079", "ST-080", "ST-027", "ST-052", ""]
const PIVOTS: Array[Vector3] = [
	Vector3(-29.5, 0.15, 20.8),
	Vector3(-28.5, 0.15, 20.8),
	Vector3(-27.5, 0.15, 20.8),
	Vector3(-26.5, 0.15, 20.8)
]
const FROZEN: Dictionary = {
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_seating_models.gd": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb",
	"stadium_bleacher_models.gd": "040edd83c323dc009cfa68d9a8fccfea7ac775dcb05097992cf816187a15c07c"
}


static func expected_checks() -> int:
	return (
		1
		+ FOREIGN.size()
		+ 2 * FROZEN.size()
		+ 2 * (1 + COMMON_CHECKS)
		+ SEAT_CHECKS
		+ PAD_CHECKS
		+ PIVOTS.size() * 3
	)


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "MoldedSeatGeometryProbe"
	probe.position = Vector3(1800, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-051"
			and expected_checks() == EXPECTED_CHECKS
			and M.ENVELOPE == AABB(Vector3(-0.25, 0, -0.275), Vector3(0.5, 0.85, 0.55))
		),
		"one exact ST-051 factory and reachable geometry check budget"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			foreign == null,
			"foreign chairs, bundled seats and unknown IDs cannot substitute",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	var seat: Node3D = M.create()
	_emit(check, seat != null, "one standalone molded seat creates without an audience")
	if seat != null:
		probe.add_child(seat)
		await _common(probe, seat, false, check)
		await _seat(seat, check)
		seat.free()
	var pad: Node3D = M.create_pad()
	_emit(check, pad != null, "fixed infrastructure creates independently of paid seat ownership")
	if pad != null:
		probe.add_child(pad)
		await _common(probe, pad, true, check)
		await _pad(pad, check)
		_sockets(probe, pad, check)
		pad.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"MOLDED_SEAT_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"old chair, bleacher and primitive factories remain byte exact",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, infrastructure: bool, check: Callable) -> void:
	var visual: Node3D = model.get_node("Visual")
	var collision: Node3D = model.get_node("Collision")
	var bounds: AABB = M.INFRASTRUCTURE_BOUNDS if infrastructure else M.ENVELOPE
	var count: int = 3 if infrastructure else 15
	var label: String = "pad" if infrastructure else "seat"
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and visual.transform == Transform3D.IDENTITY
			and collision.transform == Transform3D.IDENTITY
		),
		"assembly has exactly two identity branches and a ground-space pivot",
		{"model": label}
	)
	_emit(
		check,
		(
			model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("static_geometry")
			and _static_unit_scale(model)
		),
		"every actual node is static, finite, visible and unit scale without scripts or audience effects",
		{"model": label}
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		str(scan.failure).is_empty() and scan.types == ["ArrayMesh"] and scan.meshes == count,
		"all native mesh vertices normals indices and exact member count validate",
		{"model": label, "scan": scan}
	)
	_emit(
		check,
		_convex_faces(model),
		"every indexed visible triangle winds outward on its exact physical convex hull",
		{"model": label}
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 3,
		"plain opaque geometry retains readable plastic, metal or ground materials",
		{"model": label}
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		_same_box(actual, bounds),
		"full actual geometry reaches its exact authored extent without scaling",
		{"model": label, "actual": str(actual)}
	)
	_emit(
		check,
		_physical_match(model, count, bounds),
		(
			"every physical hull has exact visible vertices apart from the declared two-millimetre "
			+ "approach top, with zero collision margin"
		),
		{"model": label}
	)
	_emit(
		check,
		_roles(model, infrastructure),
		"fixed ground and decorative seat carry only their bounded physical roles",
		{"model": label}
	)
	var second: Node3D = M.create_pad() if infrastructure else M.create()
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"every mesh material and shape is independent between copies",
		{"model": label}
	)
	var before: String = _signature(model)
	_emit(
		check,
		_signature(second) == before,
		"fresh copies reproduce exact visible and physical arrays",
		{"model": label}
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		_signature(model) == before and _signature(second) != before,
		"destructive native resource and pose mutation cannot alter another copy",
		{"model": label}
	)
	second.free()
	var fresh: Node3D = M.create_pad() if infrastructure else M.create()
	_emit(
		check,
		_signature(fresh) == before,
		"regeneration is deterministic after foreign copy mutation",
		{"model": label}
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		_signature(model) == before,
		"an idle rendered frame leaves all geometry and collision unchanged",
		{"model": label}
	)
	print(
		(
			"MOLDED_SEAT_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"model": label,
					"meshes": scan.meshes,
					"vertices": scan.vertices,
					"bounds": str(actual),
					"physical_hulls": count,
					"unit_scale": true
				},
				"",
				true,
				true
			)
		)
	)


static func _seat(model: Node3D, check: Callable) -> void:
	_emit(
		check,
		(
			SCAN._members(model, "MoldedShell").size() == 8
			and SCAN._members(model, "AnchorBolt").size() == 4
			and model.has_node("Visual/BasePlate")
			and model.has_node("Visual/Pedestal")
			and model.has_node("Visual/PanBracket")
		),
		"complete stadium seat has a curved eight-section shell, pedestal, base, bracket and four bolts"
	)
	var continuous: bool = true
	for index in range(7):
		var a: PackedVector3Array = _hull(model, "MoldedShell%02d" % index)
		var b: PackedVector3Array = _hull(model, "MoldedShell%02d" % (index + 1))
		for corner in range(4):
			continuous = continuous and a[corner + 4].is_equal_approx(b[corner])
	_emit(check, continuous, "all actual molded sections share exact joining faces without gaps")
	var base: AABB = _member(model, "BasePlate")
	var pedestal: AABB = _member(model, "Pedestal")
	var bracket: AABB = _member(model, "PanBracket")
	_emit(
		check,
		_same_box(base, AABB(Vector3(-0.16, 0, -0.125), Vector3(0.32, 0.025, 0.28))),
		"the physical metal base actually rests on local y zero"
	)
	_emit(
		check,
		(
			absf(base.end.y - pedestal.position.y) < EPS
			and pedestal.grow(EPS).intersects(bracket)
			and bracket.intersects(_member(model, "MoldedShell02"))
		),
		"actual base, pedestal, bracket and seat shell form one supported assembly"
	)
	var bolts: bool = true
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			var bolt: AABB = _member(model, "AnchorBolt%d_%d" % [side, end])
			bolts = (
				bolts
				and bolt.get_center().is_equal_approx(
					Vector3(side * 0.12, 0.035, 0.015 + end * 0.09)
				)
				and absf(bolt.position.y - base.end.y) < EPS
				and bolt.size.is_equal_approx(Vector3(0.024, 0.02, 0.024))
			)
	_emit(
		check,
		bolts,
		"four distinct real bolt heads bear on the base plate at the approved ground pivot"
	)
	_emit(
		check,
		(
			absf(_member(model, "MoldedShell00").position.z + 0.275) < EPS
			and absf(_member(model, "MoldedShell07").end.y - 0.85) < EPS
			and _member(model, "MoldedShell05").position.z > 0.21
			and model.get_meta("facing") == Vector3.FORWARD
		),
		"actual pan extends toward local minus Z and the tall back remains behind it"
	)
	await model.get_tree().physics_frame
	await model.get_tree().physics_frame
	var pan: Dictionary = _ray(model, Vector3(0, 1, -0.1), Vector3(0, 0.1, -0.1))
	var back: Dictionary = _ray(model, Vector3(0, 0.65, -0.5), Vector3(0, 0.65, 0.5))
	_emit(
		check,
		(
			_hit_height(model, pan, 0.4222222222)
			and not back.is_empty()
			and str(back.collider.name) == "MoldedShell05"
			and absf(model.to_local(back.position).z - 0.22) < 0.003
		),
		"native rays hit the real contoured pan and field-facing backrest",
		{"pan": str(pan), "back": str(back)}
	)
	_emit(
		check,
		(
			model.find_children("*Crowd*", "", true, false).is_empty()
			and not model.get_meta("represented_audience", true)
			and model.get_meta("represented_seats") == 1
			and _ray(model, Vector3(0, 0.2, -0.5), Vector3(0, 0.2, -0.1)).is_empty()
		),
		"one paid seat contains no audience and no invisible solid filling its open front"
	)


static func _pad(model: Node3D, check: Callable) -> void:
	_emit(
		check,
		(
			model.get_meta("map_infrastructure", false)
			and not model.get_meta("paid_copy", true)
			and not model.get_meta("free_seats", true)
			and not model.has_meta("stadium_item")
			and not model.has_meta("owned_copy")
		),
		"fixed pad is identified as map infrastructure without a saleable copy or seat identity"
	)
	_emit(
		check,
		_same_box(_member(model, "FixedPad"), AABB(Vector3(-31, 0, 19), Vector3(6, 0.15, 3))),
		"actual pad preserves all four approved horizontal edges and the fifteen-centimetre top"
	)
	_emit(
		check,
		_same_box(
			_member(model, "LocalApproach"), AABB(Vector3(-29, -0.04, 15), Vector3(2, 0.04, 2))
		),
		"actual local approach is two metres wide, ends at z seventeen and is flush with ground"
	)
	var ramp: PackedVector3Array = _hull(model, "LocalRamp")
	_emit(
		check,
		(
			ramp.size() == 6
			and _same_box(
				_member(model, "LocalRamp"), AABB(Vector3(-29, 0, 17), Vector3(2, 0.15, 2))
			)
		),
		"the real triangular wedge occupies only the approved two-by-two-metre ramp rectangle"
	)
	var arrays: Array = model.get_node("Visual/LocalRamp").mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var expected_normal: Vector3 = _stored_normal(Vector3(0, 1, -0.075).normalized())
	var slope_ok: bool = true
	var top_count: int = 0
	for index in range(vertices.size()):
		if normals[index].y > 0.5:
			top_count += 1
			slope_ok = (
				slope_ok
				and absf(vertices[index].y - 0.075 * (vertices[index].z - 17)) < EPS
				and normals[index] == expected_normal
			)
	_emit(
		check,
		slope_ok and top_count >= 4,
		"every real sloping top vertex and normal follows y=.075*(z-17)"
	)
	var seams: bool = true
	for x: float in [-29.0, -27.0]:
		seams = (
			seams
			and POINTS._has_point(ramp, Vector3(x, 0, 17))
			and POINTS._has_point(ramp, Vector3(x, 0.15, 19))
		)
	_emit(
		check,
		(
			seams
			and absf(_member(model, "FixedPad").end.y - 0.15) < EPS
			and absf(_member(model, "LocalApproach").end.y) < EPS
		),
		"both actual ramp endpoints join approach and pad at identical heights"
	)
	_emit(
		check,
		(
			model.get_meta("socket_pivots") == PIVOTS
			and model.get_meta("represented_seats") == 0
			and model.find_children("*MoldedShell*", "", true, false).is_empty()
			and model.get_node("Visual").get_child_count() == 3
		),
		"all four empty sockets are data only and the empty pad renders exactly zero seats"
	)
	_emit(
		check,
		(
			model.get_meta("local_approach_only", false)
			and not model.get_meta("connected_pedestrian_route", true)
			and model.find_children("*", "Area3D", true, false).is_empty()
			and model.find_children("*", "NavigationRegion3D", true, false).is_empty()
		),
		"local approach adds no pedestrian graph, crowd sensor or accessibility claim"
	)
	await model.get_tree().physics_frame
	await model.get_tree().physics_frame
	_emit(
		check,
		_hit_height(model, _ray(model, Vector3(-30, 1, 21), Vector3(-30, -1, 21)), 0.15),
		"native ground ray hits the actual fifteen-centimetre pad top"
	)
	_emit(
		check,
		_hit_height(model, _ray(model, Vector3(-28, 1, 18), Vector3(-28, -1, 18)), 0.075),
		"native ground ray hits the actual ramp midpoint at seven-and-a-half centimetres"
	)
	_emit(
		check,
		(
			_hit_height(model, _ray(model, Vector3(-28, 1, 16), Vector3(-28, -1, 16)), 0.0)
			and _hit_height(
				model, _ray(model, Vector3(-28, 1, 17.001), Vector3(-28, -1, 17.001)), 0.000075
			)
			and _hit_height(
				model, _ray(model, Vector3(-28, 1, 18.999), Vector3(-28, -1, 18.999)), 0.149925
			)
		),
		"native rays verify the ground approach and both near-endpoint ramp heights"
	)
	_emit(
		check,
		(
			_ray(model, Vector3(-29.02, 1, 18), Vector3(-29.02, -1, 18)).is_empty()
			and _ray(model, Vector3(-26.98, 1, 18), Vector3(-26.98, -1, 18)).is_empty()
			and _ray(model, Vector3(-24.98, 1, 21), Vector3(-24.98, -1, 21)).is_empty()
		),
		"native outside-edge rays reject an invisible widened ramp or pad"
	)
	print(
		(
			"MOLDED_SEAT_RAMP_MEASUREMENT "
			+ JSON.stringify(
				{
					"ramp_points": str(ramp),
					"approach_top": 0.0,
					"ramp_top_start": 0.0,
					"ramp_top_end": 0.15,
					"pad_top": 0.15,
					"empty_socket_count": PIVOTS.size(),
					"rendered_seats": 0
				},
				"",
				true,
				true
			)
		)
	)


static func _sockets(probe: Node3D, pad: Node3D, check: Callable) -> void:
	for pivot: Vector3 in PIVOTS:
		var empty: Dictionary = _ray(pad, pivot + Vector3.UP, pivot - Vector3.UP)
		_emit(
			check,
			_hit_height(pad, empty, 0.15) and str(empty.collider.name) == "FixedPad",
			"each unoccupied socket has actual pad ground and no free seat collider",
			{"pivot": str(pivot)}
		)
		var seat: Node3D = M.create()
		probe.add_child(seat)
		seat.position = pivot
		var local: AABB = SCAN._bounds(POINTS._points(seat))
		var placed: AABB = seat.transform * local
		_emit(
			check,
			(
				seat.basis == Basis.IDENTITY
				and _static_unit_scale(seat)
				and placed.size.is_equal_approx(Vector3(0.50, 0.85, 0.55))
				and absf(placed.position.y - 0.15) < EPS
				and absf(placed.end.y - 1.0) < EPS
			),
			"full-scale seat keeps the exact world pivot, minus-Z facing and one-metre world top",
			{"pivot": str(pivot), "bounds": str(placed)}
		)
		_emit(
			check,
			(
				placed.position.x >= -31
				and placed.end.x <= -25
				and placed.position.z >= 20.0
				and placed.end.z <= 22
				and absf(placed.position.z - 20.525) < EPS
				and absf(placed.end.z - 21.075) < EPS
			),
			"all actual seat vertices fit the pad while preserving the entire front circulation strip",
			{"pivot": str(pivot)}
		)
		seat.free()


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _member(model: Node3D, id: String) -> AABB:
	return SCAN._bounds(_hull(model, id))


static func _hull(model: Node3D, id: String) -> PackedVector3Array:
	return model.get_node("Collision/" + id + "/Solid").shape.points


static func _signature(model: Node3D) -> String:
	return (
		POINTS._visual_signature(model)
		+ var_to_bytes(POINTS._physical_state(model)).hex_encode().sha256_text()
	)


static func _static_unit_scale(root: Node3D) -> bool:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node.get_class() not in ["Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D"]
			or node.get_script() != null
			or node.is_processing()
			or node.is_physics_processing()
		):
			return false
		if (
			node is Node3D
			and (
				not node.visible
				or node.top_level
				or not node.position.is_finite()
				or node.basis != Basis.IDENTITY
				or node.scale != Vector3.ONE
			)
		):
			return false
	return true


static func _physical_match(model: Node3D, expected: int, envelope: AABB) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != expected
		or model.find_children("*", "CollisionShape3D", true, false).size() != expected
	):
		return false
	for body: StaticBody3D in bodies:
		if (
			body.get_parent() != model.get_node("Collision")
			or body.get_child_count() != 1
			or body.transform != Transform3D.IDENTITY
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.constant_linear_velocity != Vector3.ZERO
			or body.constant_angular_velocity != Vector3.ZERO
		):
			return false
		var shape: CollisionShape3D = body.get_child(0)
		if (
			not shape.shape is ConvexPolygonShape3D
			or shape.disabled
			or shape.shape.margin != 0
			or shape.transform != Transform3D.IDENTITY
		):
			return false
		var hull: PackedVector3Array = shape.shape.points
		var mesh: MeshInstance3D = model.get_node("Visual/" + str(body.name))
		var visible: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		if str(body.name) == "LocalApproach":
			var top_count: int = 0
			var expected_top: float = Vector3(0, 0.002, 0).y
			if M.APPROACH_VISUAL_RISE != 0.002:
				return false
			for index in range(visible.size()):
				if visible[index].y == expected_top:
					top_count += 1
					visible[index].y = 0.0
				elif visible[index].y != Vector3(0, -0.04, 0).y:
					return false
			if top_count < 4:
				return false
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not envelope.grow(EPS).has_point(point)
				or not POINTS._has_point(visible, point)
			):
				return false
		for point: Vector3 in visible:
			if not POINTS._has_point(hull, point):
				return false
	return true


static func _convex_faces(model: Node3D) -> bool:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var hull: PackedVector3Array = _hull(model, str(mesh.name))
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for index in range(0, indices.size(), 3):
			var a: Vector3 = vertices[indices[index]]
			var b: Vector3 = vertices[indices[index + 1]]
			var c: Vector3 = vertices[indices[index + 2]]
			var cross_value: Vector3 = -(b - a).cross(c - a)
			var normal: Vector3 = normals[indices[index]]
			if cross_value.length_squared() < 1e-12 or cross_value.normalized().dot(normal) < 0.999:
				return false
			for point: Vector3 in hull:
				if normal.dot(point - a) > EPS:
					return false
	return true


static func _roles(model: Node3D, infrastructure: bool) -> bool:
	for node: Node in model.find_children("*", "", true, false):
		if (
			node.has_meta("owned_copy")
			or node.has_meta("volume_id")
			or node.has_meta("target_points")
			or node.has_meta("water_scoring")
			or node.has_meta("live_furnishing")
		):
			return false
		if node is StaticBody3D:
			if node.get_meta("surface_id", "") != str(node.name):
				return false
			if infrastructure:
				if (
					node.get_meta("ball_surface") != &"ground"
					or node.get_meta("surface_role") != "GROUND"
					or not node.get_meta("map_infrastructure", false)
					or node.has_meta("stadium_item")
				):
					return false
			elif (
				node.get_meta("stadium_item") != "ST-051"
				or node.get_meta("ball_surface") != &"stadium_scenery"
				or node.get_meta("surface_role") != "DECORATIVE_AFTER_TERMINAL"
			):
				return false
	return true


static func _stored_normal(analytic: Vector3) -> Vector3:
	# Preserve the independent analytic slope while matching native mesh encoding.
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex: Vector3 in [Vector3.ZERO, Vector3.RIGHT, Vector3.BACK]:
		surface.set_normal(analytic)
		surface.add_vertex(vertex)
	surface.index()
	var mesh: ArrayMesh = surface.commit()
	var stored: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	return stored[0]


static func _ray(model: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.to_global(from), model.to_global(to), 1
	)
	return model.get_world_3d().direct_space_state.intersect_ray(query)


static func _hit_height(model: Node3D, hit: Dictionary, height: float) -> bool:
	return (
		not hit.is_empty()
		and model.is_ancestor_of(hit.collider)
		and absf(model.to_local(hit.position).y - height) < 0.003
	)

extends Node3D
## Focused headless model/real-physics proof. No screenshot or visual acceptance is
## claimed. Settling, baseball outcomes and ownership are tested by their runtimes.

const M = preload("res://src/presentation/stadium/stadium_junk_car_models.gd")
const RADIUS: float = 0.0365
const EPS: float = 0.0002
var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_contract()
	var model: Node3D = M.create()
	add_child(model)
	_geometry(model)
	_traps()
	await get_tree().physics_frame
	await get_tree().physics_frame
	await _physics(model)
	model.free()
	print(
		(
			"ST005_MODEL_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"renderer_acceptance": "not_run_headless",
					"scope": "model_geometry_and_native_physics"
				}
			)
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _contract() -> void:
	_check(
		M.VERSION == 1 and M.ITEM == "ST-005" and M.ITEMS == ["ST-005"] and M.LIVE_UNITS == 4,
		"exact ST005 model identity and four-unit live contract"
	)
	_check(
		(
			M.create("ST-006") == null
			and M.create("") == null
			and M.envelope("ST-006") == AABB()
			and M.reservation("") == AABB()
			and M.surfaces("ST-007").is_empty()
		),
		"no sibling model substitution"
	)
	_check(
		(
			M.envelope() == AABB(Vector3(-0.85, 0, -1.9), Vector3(1.7, 1.4, 3.8))
			and M.reservation() == AABB(Vector3(-1.15, 0, -2.2), Vector3(2.3, 1.8, 4.4))
		),
		"visible compact-car dimensions remain separate from reserved clearance"
	)
	_check(M.surfaces() == ["JUNK_CAR_BODY"], "one closed-car live contact surface")


func _geometry(model: Node3D) -> void:
	_check(
		(
			model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
			and model.get_child_count() == 3
		),
		"model branches have no hidden offset"
	)
	_check(
		(
			model.get_meta("stadium_item") == M.ITEM
			and model.get_meta("geometry_version") == M.VERSION
			and model.get_meta("model_version") == M.VERSION
			and model.get_meta("live_furnishing")
			and not model.get_meta("scenery_only")
			and model.get_meta("envelope") == M.envelope()
			and model.get_meta("reservation") == M.reservation()
		),
		"model root carries explicit exact geometry identity"
	)
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	_check(
		meshes.size() == 77,
		"all original body, damaged hood, closed windows, tires, hubs and rust details exist"
	)
	var bounds: AABB = AABB()
	var first: bool = true
	var valid: bool = true
	var winding: bool = true
	var vertices: int = 0
	var colors: Dictionary = {}
	for mesh: MeshInstance3D in meshes:
		valid = (
			valid
			and mesh.mesh is ArrayMesh
			and mesh.mesh.get_surface_count() == 1
			and mesh.transform == Transform3D.IDENTITY
			and mesh.material_override is StandardMaterial3D
		)
		var material: StandardMaterial3D = mesh.material_override
		valid = (
			valid
			and material.albedo_color.a == 1
			and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			and material.roughness > 0.8
			and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL
		)
		colors[material.albedo_color.to_html()] = true
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		valid = (
			valid
			and points.size() > 2
			and points.size() % 3 == 0
			and points.size() == normals.size()
		)
		vertices += points.size()
		for index in range(points.size()):
			valid = (
				valid
				and points[index].is_finite()
				and normals[index].is_finite()
				and absf(normals[index].length() - 1.0) < EPS
			)
			bounds = AABB(points[index], Vector3.ZERO) if first else bounds.expand(points[index])
			first = false
		for index in range(0, points.size(), 3):
			var normal: Vector3 = -(points[index + 1] - points[index]).cross(
				points[index + 2] - points[index]
			)
			winding = (
				winding
				and normal.length_squared() > 1e-12
				and normal.normalized().dot(normals[index]) > 0.9999
			)
	print(
		(
			"ST005_MODEL_GEOMETRY "
			+ JSON.stringify(
				{
					"meshes": meshes.size(),
					"vertices": vertices,
					"colors": colors.size(),
					"visible_bounds": str(bounds)
				}
			)
		)
	)
	_check(
		valid and vertices > 2000 and colors.size() >= 15,
		"every actual original ArrayMesh vertex, opaque material and normal validates"
	)
	_check(winding, "all actual triangles use outward declared winding without degenerate faces")
	_check(
		(
			bounds.position.is_equal_approx(M.envelope().position)
			and bounds.size.is_equal_approx(M.envelope().size)
		),
		"actual visible car spans the entire authored 1.70 by 1.40 by 3.80 metre envelope"
	)
	_check(
		M.reservation().grow(EPS).encloses(bounds),
		"every visible vertex is within reserved clearance"
	)
	var body: StaticBody3D = model.get_node("Collision/JUNK_CAR_BODY")
	_check(
		(
			body.collision_layer == 1
			and body.collision_mask == 0
			and body.get_child_count() == 15
			and body.get_meta("stadium_item") == M.ITEM
			and body.get_meta("surface_id") == M.SURFACE
			and body.get_meta("surface_role") == "LIVE_RICOCHET"
			and body.transform == Transform3D.IDENTITY
		),
		"one stationary body owns fifteen separately authored silhouette solids"
	)
	var exact: bool = true
	for collider: CollisionShape3D in body.get_children():
		exact = (
			exact
			and collider.shape is ConvexPolygonShape3D
			and collider.shape.margin == 0.0
			and collider.transform == Transform3D.IDENTITY
			and not collider.disabled
		)
		var visual: MeshInstance3D = model.get_node("Visual/" + str(collider.name))
		var actual: PackedVector3Array = visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in collider.shape.points:
			exact = exact and _has_point(actual, point) and M.envelope().grow(EPS).has_point(point)
		for point: Vector3 in actual:
			exact = exact and _has_point(collider.shape.points, point)
	_check(exact, "every physical convex vertex is an actual visible solid vertex and vice versa")
	var carrier: Node3D = model.get_node("UnderbodyTrap")
	_check(
		(
			carrier.get_class() == "Node3D"
			and carrier.get_child_count() == 0
			and carrier.transform == Transform3D.IDENTITY
			and carrier.get_meta("volume_id") == M.TRAP_ID
			and carrier.get_meta("polygon") == M.trap_polygon()
			and carrier.get_meta("floor") == M.TRAP_FLOOR
			and carrier.get_meta("height") == M.TRAP_HEIGHT
			and carrier.get_meta("apertures") == M.trap_apertures()
		),
		"live trap carrier stores only the exact authored cavity and side apertures"
	)
	var second: Node3D = M.create()
	var scenery: Node3D = M.create(M.ITEM, false)
	add_child(second)
	add_child(scenery)
	var before: PackedByteArray = _visual_signature(model)
	_check(
		before == _visual_signature(second) and before == _visual_signature(scenery),
		"regenerated live and scenery art are byte-identical"
	)
	_check(
		(
			scenery.get_child_count() == 2
			and scenery.get_node("Collision").get_child_count() == 0
			and scenery.find_children("*", "CollisionObject3D", true, false).is_empty()
			and scenery.find_children("*", "CollisionShape3D", true, false).is_empty()
			and not scenery.has_node("UnderbodyTrap")
			and scenery.get_meta("scenery_only")
			and not scenery.get_meta("live_furnishing")
		),
		"scenery copy contains no physical collision or live trap carrier"
	)
	_check(
		_independent(model, second) and _independent(model, scenery),
		"owned copies share no mesh, material or shape resources"
	)
	second.get_node("Visual/ClosedLowerBody").material_override.albedo_color = Color.MAGENTA
	second.get_node("Collision/JUNK_CAR_BODY/ClosedLowerBody").shape.points = PackedVector3Array(
		[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	)
	_check(
		(
			_visual_signature(model) == before
			and _visual_signature(second) != before
			and body.get_node("ClosedLowerBody").shape.points.size() == 16
		),
		"mutation of a foreign copy cannot change the retained car"
	)
	second.free()
	scenery.free()
	var fresh: Node3D = M.create()
	add_child(fresh)
	_check(
		_visual_signature(fresh) == before,
		"factory regeneration is unchanged by previous resource mutation"
	)
	fresh.free()


func _traps() -> void:
	_check(
		M.trap_polygon().size() == 4 and M.trap_apertures().size() == 2,
		"only two explicitly authored side mouths can admit a trap candidate"
	)
	for side: float in [-1.0, 1.0]:
		var a: Vector3 = Vector3(side * 1.2, RADIUS, 0)
		var b: Vector3 = Vector3(0, RADIUS, 0)
		var entry: Dictionary = M.trap_entry_local(a, b, RADIUS)
		_check(
			(
				not entry.is_empty()
				and entry.volume_id == M.TRAP_ID
				and entry.aperture == ("UNDERBODY_LEFT" if side < 0 else "UNDERBODY_RIGHT")
				and entry.fraction > 0
				and entry.fraction < 1
				and entry.position.distance_to(a.lerp(b, entry.fraction)) < EPS
				and absf(absf(entry.position.x) - (M.TRAP_HALF_WIDTH - RADIUS - M.EPS)) < EPS
			),
			"inward side roller admits only after the complete sphere crosses the exact plane"
		)
		_check(
			M.trap_entry_local(b, a, RADIUS).is_empty(),
			"outward cavity motion cannot count as entry"
		)
	_check(
		M.trap_contains_local(Vector3(0, RADIUS, 0), RADIUS),
		"ground-tangent ball fits real free underbody cavity"
	)
	_check(
		M.trap_contains_local(Vector3(0.50, 0.12, 0.60), RADIUS),
		"off-centre sphere wholly contained in cavity"
	)
	_check(
		not M.trap_contains_local(Vector3(0, RADIUS - 0.001, 0), RADIUS),
		"below-ground sphere is not a genuine cavity occupant"
	)
	_check(
		not M.trap_contains_local(Vector3(0, M.TRAP_HEIGHT - RADIUS, 0), RADIUS),
		"ceiling tangency cannot arm a trap"
	)
	_check(
		not M.trap_contains_local(Vector3(M.TRAP_HALF_WIDTH - RADIUS, RADIUS, 0), RADIUS),
		"side edge tangency cannot arm a trap"
	)
	_check(
		not M.trap_contains_local(Vector3(0, RADIUS, M.TRAP_HALF_LENGTH - RADIUS), RADIUS),
		"axle edge tangency cannot arm a trap"
	)
	var rejects: Array[Array] = [
		[Vector3(0, 2, 0), Vector3(0, RADIUS, 0), RADIUS],
		[Vector3(0, RADIUS, -2), Vector3(0, RADIUS, 0), RADIUS],
		[Vector3(-1.2, 0.6, 0), Vector3(0, 0.6, 0), RADIUS],
		[Vector3(-1.2, RADIUS, 0.8), Vector3(0, RADIUS, 0.8), RADIUS],
		[
			Vector3(-1.2, RADIUS, M.TRAP_HALF_LENGTH - RADIUS),
			Vector3(0, RADIUS, M.TRAP_HALF_LENGTH - RADIUS),
			RADIUS
		],
		[Vector3(-1.2, M.TRAP_HEIGHT - RADIUS, 0), Vector3(0, M.TRAP_HEIGHT - RADIUS, 0), RADIUS],
		[Vector3(-1.2, RADIUS - 0.001, 0), Vector3(0, RADIUS - 0.001, 0), RADIUS],
		[Vector3(-1.2, RADIUS, 0), Vector3(-0.63, RADIUS, 0), RADIUS],
		[Vector3(0, RADIUS, 0), Vector3(0.1, RADIUS, 0), RADIUS],
		[Vector3(-1.2, RADIUS, 0), Vector3(0, RADIUS, 0), 0.2],
		[Vector3(-1.2, RADIUS, 0), Vector3(0, RADIUS, 0), 0.0],
		[Vector3(-1.2, RADIUS, 0), Vector3(0, RADIUS, 0), NAN],
		[Vector3(INF, RADIUS, 0), Vector3(0, RADIUS, 0), RADIUS],
		[Vector3(-3.0e38, RADIUS, 0), Vector3(3.0e38, RADIUS, 0), RADIUS]
	]
	for index in range(rejects.size()):
		var row: Array = rejects[index]
		_check(
			M.trap_entry_local(row[0], row[1], row[2]).is_empty(),
			(
				"non-aperture, body overlap, partial sphere, initial overlap or invalid entry rejected %d"
				% index
			)
		)
	var fast: Dictionary = M.trap_entry_local(Vector3(-2, RADIUS, 0), Vector3(2, RADIUS, 0), RADIUS)
	_check(
		(
			not fast.is_empty()
			and not M.trap_contains_local(Vector3(2, RADIUS, 0), RADIUS)
			and not fast.has("role")
			and not fast.has("terminal")
		),
		"fast pass-through is geometric admission, never an automatic terminal result"
	)


func _physics(model: Node3D) -> void:
	var cases: Array[Array] = [
		[
			Vector3(-1.2, RADIUS, 0),
			Vector3(0, RADIUS, 0),
			false,
			"rolling side entry remains physically open"
		],
		[
			Vector3(1.2, RADIUS, 0),
			Vector3(0, RADIUS, 0),
			false,
			"opposite rolling side entry remains physically open"
		],
		[
			Vector3(-1.2, RADIUS, 0),
			Vector3(1.2, RADIUS, 0),
			false,
			"unsettled through-ball remains physically live"
		],
		[
			Vector3(-1.2, 0.5, 0),
			Vector3(0, 0.5, 0),
			true,
			"closed door body remains a real ricochet surface"
		],
		[Vector3(0, 2, 0), Vector3(0, 0.8, 0), true, "closed cabin roof cannot be an aperture"],
		[
			Vector3(0, 1.5, -2),
			Vector3(0, 1.5, 2),
			false,
			"above-roof travel is not blocked by reservation box"
		],
		[
			Vector3(0.82, 1.15, -2),
			Vector3(0.82, 1.15, 2),
			false,
			"beside tapered cabin is clear despite being in broad envelope"
		],
		[
			Vector3(0, RADIUS, -2),
			Vector3(0, RADIUS, 0),
			true,
			"grounded front axle closes longitudinal underbody path"
		],
		[
			Vector3(0, RADIUS, 2),
			Vector3(0, RADIUS, 0),
			true,
			"grounded rear axle closes longitudinal underbody path"
		],
		[
			Vector3(-1.2, 0.15, -1.18),
			Vector3(0, 0.15, -1.18),
			true,
			"flattened front tire has true silhouette collision"
		],
		[
			Vector3(1.2, 0.15, 1.18),
			Vector3(0, 0.15, 1.18),
			true,
			"flattened rear tire has true silhouette collision"
		],
		[
			Vector3(-1.2, M.TRAP_HEIGHT - RADIUS - 0.005, 0),
			Vector3(0, M.TRAP_HEIGHT - RADIUS - 0.005, 0),
			false,
			"sphere fits immediately below actual underside"
		],
		[
			Vector3(-1.2, M.TRAP_HEIGHT - RADIUS + 0.005, 0),
			Vector3(0, M.TRAP_HEIGHT - RADIUS + 0.005, 0),
			true,
			"sphere grazing actual underside ricochets instead of entering"
		]
	]
	for row: Array in cases:
		_check(_blocked(row[0], row[1], RADIUS) == row[2], row[3])
	var all_clear: bool = true
	for x: float in [-0.60, 0.0, 0.60]:
		for z: float in [-0.67, 0.0, 0.67]:
			for y: float in [RADIUS, 0.12, 0.23]:
				var point: Vector3 = Vector3(x, y, z)
				all_clear = (
					all_clear
					and M.trap_contains_local(point, RADIUS)
					and not _blocked(point, point, RADIUS)
				)
	_check(all_clear, "27 full-sphere cavity witnesses are genuinely outside every physical solid")
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(-0.18, 1.0, -1.26), Vector3(-0.18, 0.69, -1.26), 1
	)
	var dent: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_check(
		not dent.is_empty() and absf(dent.position.y - 0.714) < 0.002,
		"real dented hood collision follows depression rather than an invisible flat roof"
	)
	for quarter in range(4):
		model.transform = Transform3D(Basis(Vector3.UP, PI / 2 * quarter), Vector3(5, 0, 6))
		await get_tree().physics_frame
		await get_tree().physics_frame
		var inverse: Transform3D = model.global_transform.affine_inverse()
		var from: Vector3 = model.global_transform * Vector3(-1.2, RADIUS, 0)
		var to: Vector3 = model.global_transform * Vector3(0, RADIUS, 0)
		_check(
			(
				not M.trap_entry_local(inverse * from, inverse * to, RADIUS).is_empty()
				and not _blocked(from, to, RADIUS)
			),
			"actual sphere fits the same aperture after rigid quarter-turn %d" % quarter
		)
		_check(
			_blocked(
				model.global_transform * Vector3(-1.2, 0.5, 0),
				model.global_transform * Vector3(0, 0.5, 0),
				RADIUS
			),
			"actual closed body retains silhouette collision after rigid quarter-turn %d" % quarter
		)


func _blocked(from: Vector3, to: Vector3, radius: float) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = radius
	query.shape.margin = 0.0
	query.margin = 0.0
	query.collision_mask = 1
	query.transform.origin = from
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return true
	query.motion = to - from
	var result: PackedFloat32Array = space.cast_motion(query)
	return result.size() != 2 or result[0] < 1


func _visual_signature(model: Node3D) -> PackedByteArray:
	var rows: Array = []
	for mesh: MeshInstance3D in model.get_node("Visual").get_children():
		rows.append(
			[
				str(mesh.name),
				mesh.transform,
				mesh.mesh.surface_get_arrays(0),
				mesh.material_override.albedo_color,
				mesh.material_override.roughness
			]
		)
	return var_to_bytes(rows)


func _independent(first: Node3D, second: Node3D) -> bool:
	for mesh: MeshInstance3D in first.get_node("Visual").get_children():
		var other: MeshInstance3D = second.get_node("Visual/" + str(mesh.name))
		if mesh.mesh == other.mesh or mesh.material_override == other.material_override:
			return false
	if second.has_node("Collision/JUNK_CAR_BODY"):
		for shape: CollisionShape3D in first.get_node("Collision/JUNK_CAR_BODY").get_children():
			if shape.shape == second.get_node("Collision/JUNK_CAR_BODY/" + str(shape.name)).shape:
				return false
	return true


func _has_point(points: PackedVector3Array, desired: Vector3) -> bool:
	for point: Vector3 in points:
		if point.distance_to(desired) < EPS:
			return true
	return false


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("ST005 model: " + message)

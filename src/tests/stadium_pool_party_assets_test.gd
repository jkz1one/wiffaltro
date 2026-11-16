extends Node3D
## Private model/interface qualification only; no runtime water, routes, game or fixture tests.

var _failures: int = 0
var _checks: int = 0
var _models: Array[Node3D] = []


func _ready() -> void:
	_contracts()
	_timber()
	_pool()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_physics_queries()
	for model: Node3D in _models:
		model.queue_free()
	await get_tree().physics_frame
	await get_tree().process_frame
	print(
		(
			"POOL_PARTY_ASSETS_MODEL_INTERFACE checks=%d failures=%d source=%s"
			% [_checks, _failures, StadiumPoolPartyAssetIntegrity.source_sha256()]
		)
	)
	print(
		"Runtime water awards, sphere sweeps, routing, native readability and finals are UNQUALIFIED."
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _contracts() -> void:
	_check(
		StadiumPoolPartyAssetIntegrity.source_sha256().length() == 64, "complete source identity"
	)
	_check(StadiumTimberDugoutContract.ENVELOPE.size == Vector3(6, 1.30, 2.65), "timber envelope")
	for left: bool in [false, true]:
		var pose: Transform3D = StadiumTimberDugoutContract.placement(left)
		_check(StadiumPoolPartyAssetIntegrity.rigid(pose), "positive unit handed timber placement")
		_check(
			StadiumTimberDugoutContract.panels(left).size() == 16, "sixteen remaining side panels"
		)
		for x: float in [-3.0, -1.0, 1.0, 3.0]:
			for depth: float in [0.0, 2.4, 2.65]:
				var expected: Vector3 = StadiumDugoutRecipe.rail_point(
					13 + (x if left else -x), depth, left
				)
				_check(
					(pose * Vector3(x, 0, depth)).distance_to(expected) < 0.00001,
					"both-handed exact shared rail placement"
				)
		var record: Dictionary = StadiumTimberDugoutContract.interface(left)
		for surface: Dictionary in record.front_surfaces:
			var center: Vector3 = pose * surface.local_bounds.get_center()
			var s: float = (Vector2(absf(center.x), center.z) - Vector2(8, -6)).dot(
				Vector2(16, 29.4).normalized()
			)
			_check(
				is_equal_approx(s, (surface.rail_interval.x + surface.rail_interval.y) / 2),
				"named barrier binds to correct handed rail interval"
			)
		_check(
			not record.interior_navigable and not record.roof and not record.tunnel_host,
			"no roof, tunnel or navigation shortcut"
		)
	for s: float in [10.0, 12.0, 14.0, 16.0]:
		_check(
			StadiumTimberDugoutContract.front_region(s, 1.20) == "DUGOUT_FACE_LIVE",
			"closed solid front/seam ownership"
		)
		_check(
			StadiumTimberDugoutContract.front_region(s, 1.20001) == "SIDE_EXIT_DEAD",
			"above front cap has side-exit interface"
		)
	for s: float in [12.00001, 13.0, 13.99999]:
		_check(
			StadiumTimberDugoutContract.front_region(s, 1.30) == "DUGOUT_OPENING_DEAD",
			"entry includes its 1.30 metre interface cap"
		)
		_check(
			StadiumTimberDugoutContract.front_region(s, 1.30001) == "DUGOUT_EXTERIOR_DEAD",
			"above 1.30 is exterior, never an invisible roof"
		)
	for point: Vector2 in [Vector2(9.99, 1), Vector2(16.01, 1), Vector2(13, -0.01)]:
		_check(
			StadiumTimberDugoutContract.front_region(point.x, point.y).is_empty(),
			"outside interface"
		)
	_check(
		StadiumTimberDugoutContract.front_region(NAN, 1).is_empty(), "nonfinite interface rejected"
	)
	var site: Dictionary = StadiumPoolContract.live_site()
	_check(site.placement == Transform3D(Basis.IDENTITY, Vector3(12, 0, 18)), "exact OL-R pose")
	_check(
		site.capacity_units_future_adapter == 4 and site.reservation_radius == 3.0,
		"capacity and placement are future adapter contracts"
	)
	_check(
		not site.physics_qualified and not site.geometry.water_award_active,
		"no false physics/water qualification"
	)
	_check(StadiumPoolContract.geometry("LIVE").is_empty(), "unknown role rejected")
	_check(StadiumPoolModels.create("LIVE") == null, "unknown role cannot instantiate")


func _timber() -> void:
	for left: bool in [false, true]:
		var model: Node3D = StadiumTimberDugoutModels.create()
		model.transform = StadiumTimberDugoutContract.placement(left)
		add_child(model)
		_models.append(model)
		var record: Dictionary = StadiumTimberDugoutContract.interface(left)
		_check(
			StadiumTimberDugoutContract.valid_binding(model, left, record), "exact timber binding"
		)
		_check(
			not StadiumTimberDugoutContract.valid_binding(model, not left, record), "misbound hand"
		)
		_check(
			StadiumTimberDugoutContract.ENVELOPE.grow(0.000001).encloses(_bounds(model)),
			"every timber mesh in complete envelope"
		)
		for body: StaticBody3D in model.get_node("Collision").get_children():
			var shape: CollisionShape3D = body.get_node("Shape")
			_check(
				shape.shape is BoxShape3D and shape.shape.margin == 0,
				"exact primitive timber shape"
			)
			_check(body.transform.basis == Basis.IDENTITY, "positive unscaled furniture transform")
			var box: AABB = AABB(body.position - shape.shape.size / 2, shape.shape.size)
			_check(
				StadiumTimberDugoutContract.ENVELOPE.grow(0.000001).encloses(box),
				"collider envelope"
			)
			_check(
				not box.intersects(
					AABB(Vector3(-0.999, 0.001, -0.001), Vector3(1.998, 1.298, 0.17))
				),
				"no solid spanning opening"
			)
		var original: Transform3D = model.transform
		model.scale *= 1.01
		_check(
			not StadiumTimberDugoutContract.valid_binding(model, left, record),
			"scaled timber rejected"
		)
		model.transform = original
		var barrier: StaticBody3D = model.get_node("Collision/FrontBarrier1")
		barrier.set_meta("surface_role", "DUGOUT_OPENING_DEAD")
		_check(
			not StadiumTimberDugoutContract.valid_binding(model, left, record),
			"misbound timber surface"
		)
		barrier.set_meta("surface_role", "DUGOUT_FACE_LIVE")
		var saved_height: Variant = record.entry_height
		record.entry_height = 2.4
		_check(
			not StadiumTimberDugoutContract.valid_binding(model, left, record),
			"concrete aperture rejected"
		)
		record.entry_height = saved_height
		_check(
			StadiumTimberDugoutContract.valid_binding(model, left, record),
			"timber controls restore"
		)


func _pool() -> void:
	var live: Node3D = StadiumPoolModels.create(StadiumPoolContract.LIVE)
	live.transform = StadiumPoolContract.placement()
	add_child(live)
	_models.append(live)
	var scenery: Node3D = StadiumPoolModels.create(StadiumPoolContract.SCENERY)
	scenery.position = Vector3(-12, 0, 18)
	add_child(scenery)
	_models.append(scenery)
	var record: Dictionary = StadiumPoolContract.geometry(StadiumPoolContract.LIVE)
	_check(_valid_pool(live, record), "exact pool live geometry binding")
	_check(
		StadiumPoolContract.valid_binding(
			scenery,
			StadiumPoolContract.SCENERY,
			scenery.transform,
			StadiumPoolContract.geometry(StadiumPoolContract.SCENERY)
		),
		"same scenery geometry"
	)
	_check(
		not scenery.has_node(StadiumPoolContract.WATER_VOLUME_ID),
		"scenery has no named rule volume"
	)
	_check(not _valid_pool(scenery, record), "scenery cannot impersonate live binding")
	_check(
		(
			StadiumPoolPartyAssetIntegrity.snapshot(live.get_node("Visual"))
			== StadiumPoolPartyAssetIntegrity.snapshot(scenery.get_node("Visual"))
		),
		"same ST-006 art in both roles"
	)
	for node: MeshInstance3D in live.get_node("Visual").get_children():
		for surface: int in range(node.mesh.get_surface_count()):
			var vertices: PackedVector3Array = node.mesh.surface_get_arrays(surface)[
				Mesh.ARRAY_VERTEX
			]
			for vertex: Vector3 in vertices:
				var at: Vector3 = node.transform * vertex
				_check(
					(
						Vector2(at.x, at.z).length() <= 2.500001
						and at.y >= -0.000001
						and at.y <= 1.500001
					),
					"complete visible radius and height"
				)
	_annular_faces(live)
	var volume: Area3D = live.get_node(StadiumPoolContract.WATER_VOLUME_ID)
	var water_shape: CylinderShape3D = volume.get_node("WaterGeometry").shape
	_check(
		(
			volume.position == Vector3(0, 0.525, 0)
			and is_equal_approx(water_shape.radius, 1.95)
			and is_equal_approx(water_shape.height, 1.05)
		),
		"stable named exact water volume"
	)
	_check(
		(
			volume.collision_layer == 0
			and volume.collision_mask == 0
			and not volume.monitoring
			and not volume.monitorable
			and not volume.get_meta("water_award_active")
		),
		"inert geometry-only volume"
	)
	var water_mesh: ArrayMesh = live.get_node("Visual/WaterVisual").mesh
	var water_arrays: Array = water_mesh.surface_get_arrays(0)
	var water_vertices: PackedVector3Array = water_arrays[Mesh.ARRAY_VERTEX]
	var water_normals: PackedVector3Array = water_arrays[Mesh.ARRAY_NORMAL]
	for index: int in range(0, water_vertices.size(), 3):
		var direction: Vector3 = (water_vertices[index + 1] - water_vertices[index]).cross(
			water_vertices[index + 2] - water_vertices[index]
		)
		_check(
			direction.y < 0 and water_normals[index].y > 0,
			"water fan clockwise front and upward shading normal"
		)
	_pool_tamper(live, record)


func _annular_faces(model: Node3D) -> void:
	for id: String in StadiumPoolContract.SURFACES:
		var faces: PackedVector3Array = StadiumPoolContract.faces(id)
		_check(faces.size() == 128 * 6, "exact indexed ring tessellation")
		var mesh: ArrayMesh = model.get_node("Visual/" + id).mesh
		var shape: ConcavePolygonShape3D = model.get_node("Collision/" + id + "/Shape").shape
		_check(
			mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == faces and shape.get_faces() == faces,
			"exact mesh and collider triangle correspondence"
		)
		for index: int in range(0, faces.size(), 3):
			var middle: Vector3 = (faces[index] + faces[index + 1] + faces[index + 2]) / 3
			var normal: Vector3 = -(faces[index + 1] - faces[index]).cross(
				faces[index + 2] - faces[index]
			)
			_check(normal.length() > 0.000001, "nondegenerate wall triangle")
			if id == "POOL_OUTER_WALL":
				_check(normal.dot(Vector3(middle.x, 0, middle.z)) > 0, "outward outer wall winding")
			elif id == "POOL_INNER_WALL":
				_check(normal.dot(Vector3(middle.x, 0, middle.z)) < 0, "inward inner wall winding")
			else:
				_check(normal.y > 0 if id == "POOL_RIM" else normal.y < 0, "annular cap winding")
		for vertex: Vector3 in faces:
			var radius: float = Vector2(vertex.x, vertex.z).length()
			_check(
				absf(radius - 1.95) < 0.000001 or absf(radius - 2.10) < 0.000001,
				"annular vertices never form a filled interior cylinder"
			)
		_check(shape.backface_collision and shape.margin == 0, "closed shell query policy")
	var ladder: CollisionShape3D = model.get_node("Collision/POOL_LADDER/Shape")
	_check(ladder.shape.size == Vector3(0.35, 1.45, 0.70), "closed ladder proxy exact dimensions")
	_check(
		model.get_node("Collision/POOL_LADDER").position.is_equal_approx(Vector3(2.275, 0.725, 0)),
		"ladder exact +X pose"
	)


func _pool_tamper(model: Node3D, record: Dictionary) -> void:
	var prior_parent_pose: Transform3D = transform
	position.x += 0.25
	_check(not _valid_pool(model, record), "moved ancestor invalidates exact world site")
	transform = prior_parent_pose
	var internal_body: StaticBody3D = StaticBody3D.new()
	internal_body.name = "HiddenSolid"
	model.add_child(internal_body, false, Node.INTERNAL_MODE_BACK)
	_check(not _valid_pool(model, record), "internal solid cannot evade exact-tree check")
	model.remove_child(internal_body)
	internal_body.free()
	var original: Transform3D = model.transform
	model.scale = Vector3(1.01, 1, 1)
	_check(not _valid_pool(model, record), "scaled pool rejected")
	model.transform = original
	model.position.x += 0.01
	_check(not _valid_pool(model, record), "shifted pool rejected")
	model.transform = original
	model.rotation.y = PI / 2
	_check(not _valid_pool(model, record), "wrong ladder orientation rejected")
	model.transform = original
	var mesh: MeshInstance3D = model.get_node("Visual/POOL_OUTER_WALL")
	var saved_mesh: Mesh = mesh.mesh
	mesh.mesh = CylinderMesh.new()
	_check(not _valid_pool(model, record), "filled solid cylinder substitution rejected")
	mesh.mesh = saved_mesh
	var shape: CollisionShape3D = model.get_node("Collision/POOL_RIM/Shape")
	var saved_shape: Shape3D = shape.shape
	shape.shape = CylinderShape3D.new()
	_check(not _valid_pool(model, record), "giant reservation collider rejected")
	shape.shape = saved_shape
	var body: StaticBody3D = model.get_node("Collision/POOL_RIM")
	body.set_meta("surface_id", "POOL_WATER")
	_check(not _valid_pool(model, record), "misbound rim identity rejected")
	body.set_meta("surface_id", "POOL_RIM")
	var color: Color = mesh.material_override.albedo_color
	mesh.material_override.albedo_color = Color.MAGENTA
	_check(not _valid_pool(model, record), "unbound material change rejected")
	mesh.material_override.albedo_color = color
	var water: CylinderShape3D = (
		model.get_node(StadiumPoolContract.WATER_VOLUME_ID + "/WaterGeometry").shape
	)
	water.radius += 0.01
	_check(not _valid_pool(model, record), "moved rule volume geometry rejected")
	water.radius = 1.95
	var source: String = record.source_sha256
	record.source_sha256 = "0".repeat(64)
	_check(not _valid_pool(model, record), "stale source rejected")
	record.source_sha256 = source
	_check(_valid_pool(model, record), "all pool controls restore exact tree")


func _valid_pool(model: Node3D, record: Dictionary) -> bool:
	return StadiumPoolContract.valid_binding(
		model, StadiumPoolContract.LIVE, StadiumPoolContract.placement(), record
	)


func _physics_queries() -> void:
	var pool: Node3D = _models[2]
	_check(
		_surface(_ray(pool, Vector3(0, 0.5, 3), Vector3(0, 0.5, 0))) == "POOL_OUTER_WALL",
		"engine outer wall query"
	)
	_check(
		_surface(_ray(pool, Vector3(0, 0.5, 0), Vector3(0, 0.5, 3))) == "POOL_INNER_WALL",
		"engine hollow inner wall query"
	)
	_check(
		_surface(_ray(pool, Vector3(0, 2, 2.025), Vector3(0, 0.8, 2.025))) == "POOL_RIM",
		"engine rim query"
	)
	_check(_ray(pool, Vector3(0, 2, 0), Vector3(0, -0.2, 0)).is_empty(), "no filled central solid")
	_check(
		_surface(_ray(pool, Vector3(3, 0.8, 0), Vector3(2.2, 0.8, 0))) == "POOL_LADDER",
		"engine closed ladder query"
	)
	for index: int in [0, 1]:
		var timber: Node3D = _models[index]
		_check(
			_ray(timber, Vector3(0, 1.29, -0.5), Vector3(0, 1.29, 0.4)).is_empty(),
			"real open 1.30 metre timber entry"
		)
		_check(
			_ray(timber, Vector3(0, 3, 1), Vector3(0, 0.01, 1)).is_empty(),
			"no invisible timber roof"
		)
		_check(
			(
				_surface(_ray(timber, Vector3(2, 1.19, -0.5), Vector3(2, 1.19, 0.4)))
				== "FrontBarrier1"
			),
			"live front face remains solid"
		)
		_check(
			_ray(timber, Vector3(2, 1.21, -0.5), Vector3(2, 1.21, 0.4)).is_empty(),
			"above-front side exit"
		)
		_check(
			(
				_surface(_ray(timber, Vector3(1.02, 0.7, -0.5), Vector3(1.02, 0.7, 0.4)))
				== "FrontBarrier1"
			),
			"jamb exists beside open aperture"
		)


func _ray(model: Node3D, start: Vector3, end: Vector3) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(
			model.global_transform * start, model.global_transform * end, 1
		)
	)


func _surface(hit: Dictionary) -> String:
	return "" if hit.is_empty() else String(hit.collider.get_meta("surface_id", ""))


func _bounds(model: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for mesh: MeshInstance3D in model.get_node("Visual").get_children():
		var box: AABB = mesh.transform * mesh.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

extends Node3D
## Geometry-only candidate checks, with native daylight inspection. Never qualifies night.

const Models = preload("res://src/presentation/stadium/stadium_premium_light_tower_models.gd")
const Sites = preload("res://src/presentation/stadium/stadium_premium_light_tower_sites.gd")
const Contract = preload("res://src/tests/stadium_premium_light_tower_contract.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")

var _failures: int = 0
var _capture_dir: String = ""
var _native: NativeCapture
var _towers: Array[Node3D] = []
var _camera: Camera3D


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	await _transformed_hosts()
	_check(Models.create("FREE-AIM") == null, "unnamed aim profiles fail closed")
	_check(Sites.SITES.size() == 4 and Sites.TARGETS.size() == 4, "exactly four fixed sites")
	var exact_sites: Array[Vector3] = [Vector3(-46, 0, -22), Vector3(46, 0, -22),
		Vector3(-46, 0, 50), Vector3(46, 0, 50)]
	var exact_targets: Array[Vector3] = [Vector3(-8, 1.5, 12), Vector3(8, 1.5, 12),
		Vector3(-8, 1.5, 18), Vector3(8, 1.5, 18)]
	var ids: Array[String] = ["PLIGHT-HL", "PLIGHT-HR",
		"PLIGHT-OL", "PLIGHT-OR"]
	for index in range(4):
		_check(Sites.SITES[ids[index]] == exact_sites[index]
			and Sites.TARGETS[ids[index]] == exact_targets[index], "literal CM fixed site and target")
	for site: String in Sites.SITES:
		var tower: Node3D = Models.create()
		add_child(tower)
		_check(Sites.place(tower, site), "named fixed-site placement")
		_check(tower.position == Sites.SITES[site]
			and tower.get_meta("reference_target") == Sites.TARGETS[site]
			and tower.get_meta("candidate_preset") == "LIGHT-MOGUL-4X076-v1"
			and tower.get_meta("aim_profile") == "MOGUL4-PREMIUM", "exact placement metadata")
		_towers.append(tower)
		_geometry(tower)
		_check(Contract.valid(tower), "independent exact authored geometry/material/collider contract")
		_reservations(tower)
		var before: Transform3D = tower.transform
		var rays: Array = tower.get_meta("candidate_head_rays").duplicate(true)
		_check(not Sites.place(tower, "PLIGHT-UNKNOWN"), "unknown site rejected")
		_check(not Sites.place(tower, site, "FREE-AIM"), "arbitrary profile rejected")
		_check(tower.transform == before and tower.get_meta("candidate_head_rays") == rays,
			"rejected placement cannot alter geometry or dormant aims")
		_check(Sites.place(tower, site) and tower.transform == before
			and tower.get_meta("candidate_head_rays") == rays, "named transforms repeat exactly")
	_negative_controls()
	_site_conflicts()
	await get_tree().physics_frame
	await get_tree().physics_frame
	for tower: Node3D in _towers:
		_collision_rays(tower)
	_setup_inspection()
	await _views()
	_check(_native._failures == 0, "native handshake has no hidden failures")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	for tower: Node3D in _towers:
		tower.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("stadium premium light tower: PASS (Working geometry, four fixed sites, dormant aims)")
	get_tree().quit(0 if _failures == 0 else 1)


func _transformed_hosts() -> void:
	# Reject invalid assembly transforms before entering the physics/render world.
	# Scaling a live cylinder first would already ask Jolt to build an invalid shape.
	var host: Node3D = Node3D.new()
	var parent: Node3D = Node3D.new()
	host.add_child(parent)
	var tower: Node3D = Models.create()
	parent.add_child(tower)
	_check(Sites.place(tower, "PLIGHT-HL"), "identity ancestor chain accepts field-frame placement")
	var before: Transform3D = tower.transform
	var rays: Array = tower.get_meta("candidate_head_rays").duplicate(true)
	for pose: Transform3D in [Transform3D(Basis.IDENTITY, Vector3.ONE),
		Transform3D(Basis(Vector3.UP, 0.3), Vector3.ZERO),
		Transform3D(Basis.IDENTITY.scaled(Vector3(2, 1, 1)), Vector3.ZERO)]:
		for direct: bool in [false, true]:
			host.transform = Transform3D.IDENTITY if direct else pose
			parent.transform = pose if direct else Transform3D.IDENTITY
			_check(not Sites.place(tower, "PLIGHT-HR"),
				"translated, rotated or scaled parents and ancestors fail closed")
			_check(tower.transform == before and tower.get_meta("candidate_head_rays") == rays,
				"rejected host cannot rewrite fixed-site pose or dormant field-frame rays")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	host.free()
	await get_tree().process_frame


func _geometry(tower: Node3D) -> void:
	var points: PackedVector3Array = _vertices(tower.get_node("Visual"), tower)
	_check(points.size() > 500, "checks actual generated mesh vertices")
	var highest: float = 0
	for point: Vector3 in points:
		highest = maxf(highest, point.y)
		_check(point.y >= -0.0001 and point.y <= Models.HEIGHT + 0.0001
			and Vector2(point.x, point.z).length() <= Models.ENVELOPE_RADIUS + 0.0001,
			"every authored vertex fits the cylindrical reservation")
		var world: Vector3 = tower.transform * point
		_check(absf(world.x) <= 52 and world.z >= -30 and world.z <= 58,
			"actual rotated model remains inside Mogul property")
	_check(highest > 18 and highest < 18.2, "concrete stylized height, not reservation filler")
	var heads: Array = tower.get_meta("candidate_head_rays")
	_check(heads.size() == 8, "eight dormant head rays")
	for index in range(8):
		var head: Node3D = tower.get_node("Visual/Head%d" % index)
		_check(head.get_child_count() == 2 and head.get_node("Housing").visible
			and head.get_node("Lens").visible, "eight distinct visible housings and lenses")
		var ray: Dictionary = heads[index]
		var origin: Vector3 = tower.transform * head.transform * Vector3(0, 0, 0.154)
		_check(origin.is_equal_approx(ray.origin), "dormant origin matches actual lens face")
		var direction: Vector3 = (tower.get_meta("reference_target") - origin).normalized()
		_check(direction.is_equal_approx(ray.direction)
			and (head.global_basis * Vector3.BACK).is_equal_approx(direction),
			"named head transform and dormant ray point to the exact reference")
		_check(ray.id == "HEAD-%d" % (index + 1), "exact stable head identity")
		_check(ray.keys().size() == 3, "no invented cone, intensity or shadow certification")
		if index > 0:
			_check(origin.distance_to(heads[index - 1].origin) > 0.55, "separate visible heads")
		var stem: MeshInstance3D = tower.get_node("Visual/HeadStem%d" % index)
		var row: int = 1 if index >= 4 else 0
		_check(_part_bounds(tower, "HeadStem%d" % index).intersects(
			_part_bounds(tower, "Crossbar%d" % row)), "actual stem intersects its crossbar")
		_check(_part_bounds(tower, "HeadStem%d" % index).has_point(head.position),
			"stem contains actual housing center, proving physical support")
		_check(stem.position.x == head.position.x
			and stem.position.y + stem.mesh.size.y / 2.0 >= head.position.y,
			"each head rests on its crossbar stem")
	_check(_count_lights(tower) == 0 and not tower.get_meta("night_qualified")
		and tower.get_meta("obstacle_units") == 0, "geometry grants no light or obstacle authority")
	var bodies: Node3D = tower.get_node("Collision")
	_check(bodies.get_child_count() == 3, "only visible footing, base plate and narrow mast collide")
	for body: StaticBody3D in bodies.get_children():
		var visual: MeshInstance3D = tower.get_node("Visual/" + str(body.name))
		var shape: Shape3D = body.get_child(0).shape
		_check(body.transform == visual.transform and not body.has_meta("ball_surface")
			and body.get_meta("surface_role") == Models.ROLE, "collision is scenery, no ball-result tag")
		if shape is BoxShape3D:
			_check(shape.size == visual.mesh.size, "box collision exactly matches visible solid")
		else:
			_check(shape is CylinderShape3D and shape.radius == visual.mesh.top_radius
				and shape.radius == visual.mesh.bottom_radius and shape.height == visual.mesh.height,
				"pole collider follows the actual narrow cylindrical mesh")
	_check(tower.get_node("Visual/Mast").position.y - 17.1 / 2.0 <= 0.46,
		"mast physically meets plate")
	for row in range(2):
		_check(_part_bounds(tower, "Crossbar%d" % row).intersects(_part_bounds(tower, "Mast")),
			"each actual crossbar physically meets mast")
	for height: float in [0.9, 8.8, 16.9]:
		var bracket: AABB = _part_bounds(tower, "LadderBracket%d" % int(height * 10))
		_check(bracket.intersects(_part_bounds(tower, "Mast")),
			"each actual ladder bracket intersects the mast bounds")
		# The bracket spans the mast centerline, not merely a corner of its AABB.
		_check(bracket.has_point(Vector3(0, height, 0)),
			"each bracket reaches the cylindrical mast centerline")
		for side: int in [-1, 1]:
			_check(bracket.intersects(_part_bounds(tower, "LadderRail%d" % side)),
				"each actual bracket intersects both ladder rails")
	for rung in range(56):
		var bounds: AABB = _part_bounds(tower, "LadderRung%02d" % rung)
		for side: int in [-1, 1]:
			_check(bounds.intersects(_part_bounds(tower, "LadderRail%d" % side)),
				"every actual rung intersects both supported ladder rails")


func _part_bounds(tower: Node3D, part: String) -> AABB:
	var mesh: MeshInstance3D = tower.get_node("Visual/" + part)
	return mesh.transform * mesh.get_aabb()


func _vertices(node: Node3D, relative: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				result.append(relative.global_transform.affine_inverse() * node.global_transform * point)
	for child: Node in node.get_children():
		if child is Node3D:
			result.append_array(_vertices(child, relative))
	return result


func _count_lights(node: Node) -> int:
	var count: int = 1 if node is Light3D else 0
	for child: Node in node.get_children():
		count += _count_lights(child)
	return count


func _reservations(tower: Node3D) -> void:
	var center: Vector2 = Vector2(tower.position.x, tower.position.z)
	_check(center.length() - Models.ENVELOPE_RADIUS > 28,
		"separate from entire lower-bowl and future concourse disk r18..28")
	_check(absf(center.x) - Models.ENVELOPE_RADIUS > 43,
		"beyond play, practice x=-31, right score/landmark x=43 and central entry")
	for other: Vector3 in Sites.SITES.values():
		if other == tower.position:
			continue
		_check(tower.position.distance_to(other) > 2 * Models.ENVELOPE_RADIUS,
			"complete four-site reservations do not overlap")
	_check(Models.GROUND_RADIUS < Models.ENVELOPE_RADIUS
		and sqrt(0.55 * 0.55 * 2) < Models.GROUND_RADIUS, "actual footing fits ground reservation")


func _collision_rays(tower: Node3D) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for offset: float in [0.0, 0.7]:
		var start: Vector3 = tower.transform * Vector3(offset, 2, -1)
		var end: Vector3 = tower.transform * Vector3(offset, 2, 1)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(start, end, 1))
		_check((not hit.is_empty()) == is_zero_approx(offset),
			"real ray hits pole but passes through empty reserved volume")
	var low: Vector3 = tower.transform * Vector3(0.35, 0.15, -1)
	var high: Vector3 = tower.transform * Vector3(0.35, 0.15, 1)
	_check(not space.intersect_ray(PhysicsRayQueryParameters3D.create(low, high, 1)).is_empty(),
		"real ray sees the visible footing width")


func _setup_inspection() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("90acbe")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	_camera = Camera3D.new()
	_camera.far = 500
	_camera.current = true
	add_child(_camera)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(104, 0.1, 88)
	ground.mesh = mesh
	ground.position = Vector3(0, -0.05, 14)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("527152")
	ground.material_override = material
	add_child(ground)


func _views() -> void:
	var director: MatchCameraDirector = MatchCameraDirector.new()
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "actual native window/readback size handshake")
		_check(_native._expected_content_size(extent) == (
			Vector2i(1280, 720) if extent.x == 1280 else Vector2i(700, 393)),
			"actual content assertion is 1280x720 or 700x393")
		for left: bool in [false, true]:
			director.set_batter_handedness(left)
			for shot in range(MatchCameraDirector.Shot.size()):
				director.set_shot(shot as MatchCameraDirector.Shot)
				director.snap(_camera, Vector3(0, 1.05, 8))
				for tower: Node3D in _towers:
					_check(Vector2(_camera.position.x - tower.position.x,
						_camera.position.z - tower.position.z).length() > Models.ENVELOPE_RADIUS,
						"all normal cameras remain clear of tower envelopes")
		_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		_camera.fov = 75
		_camera.position = Vector3(92, 70, -102)
		_camera.look_at(Vector3(0, 5, 14))
		await _capture("premium-light-four-site-daylight-overview")
		var tower: Node3D = _towers[0]
		# Face the lenses from below their center along the authored downward aim.
		# Explicitly establish projection and settle the transform before measuring it.
		_camera.fov = 55
		_camera.position = tower.transform * Vector3(0, 16.05, 4.5)
		_camera.look_at(tower.transform * Vector3(0, 17.45, 0))
		_camera.force_update_transform()
		await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		for index in range(8):
			var head: Node3D = tower.get_node("Visual/Head%d" % index)
			_check(not _camera.is_position_behind(head.global_position), "head in front of review camera")
			var a: Vector2 = _camera.unproject_position(head.to_global(Vector3(-0.235, 0, 0.154)))
			var b: Vector2 = _camera.unproject_position(head.to_global(Vector3(0.235, 0, 0.154)))
			var viewport_size: Vector2 = get_viewport().get_visible_rect().size
			var pixel_scale: float = float(_native._expected_content_size(extent).x) / viewport_size.x
			print("PREMIUM_LIGHT_LENS_PIXELS content=", _native._expected_content_size(extent),
				" head=", index, " width=", a.distance_to(b) * pixel_scale)
			_check(a.distance_to(b) * pixel_scale > 12,
				"eight individual lens widths exceed 12 actual content pixels")
			for point: Vector3 in _vertices(head, head):
				var projected: Vector2 = _camera.unproject_position(head.to_global(point))
				_check(Rect2(Vector2.ZERO, viewport_size).grow(-4).has_point(projected),
					"all actual head vertices remain inside the detail camera frame")
		await _capture("premium-light-lenses-daylight-detail")
		_camera.fov = 75
		_camera.position = tower.transform * Vector3(8, 10, 22)
		_camera.look_at(tower.transform * Vector3(0, 9, 0))
		await _capture("premium-light-supported-assembly-daylight")


func _capture(label: String) -> void:
	_check(await _native.capture(_capture_dir, label), "native actual-size daylight capture")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("PREMIUM_LIGHT_TOWER: " + message)


func _negative_controls() -> void:
	# Detached controls never send malformed or scaled shapes to the physics server.
	var tower: Node3D = Models.create()
	_check(Contract.valid(tower), "unplaced complete tower satisfies independent literals")
	var head: Node3D = tower.get_node("Visual/Head0")
	var head_pose: Transform3D = head.transform
	head.rotate_object_local(Vector3.BACK, 0.2)
	_check(not Contract.valid(tower), "rolled housing rejected despite unchanged forward aim")
	head.transform = head_pose
	_participation_controls(tower)
	_tree_controls(tower)
	_exact_scalar_controls(tower)
	var lens: MeshInstance3D = tower.get_node("Visual/Head0/Lens")
	lens.visible = false
	_check(not Contract.valid(tower), "hidden lens rejected")
	lens.visible = true
	var material: StandardMaterial3D = lens.material_override
	material.emission_enabled = true
	_check(not Contract.valid(tower), "unrequested luminous material rejected")
	material.emission_enabled = false
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_check(not Contract.valid(tower), "transparent lens rejected")
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	var mesh: Mesh = lens.mesh
	lens.mesh = SphereMesh.new()
	_check(not Contract.valid(tower), "wrong primitive rejected despite plausible name")
	lens.mesh = mesh
	var old_size: Vector3 = lens.mesh.size
	lens.mesh.size.x += 0.01
	_check(not Contract.valid(tower), "changed actual lens dimensions rejected")
	lens.mesh.size = old_size
	var bracket: Node3D = tower.get_node("Visual/LadderBracket88")
	var original: Transform3D = bracket.transform
	bracket.position.z -= 0.5
	_check(not Contract.valid(tower), "floating ladder bracket rejected")
	bracket.transform = original
	var collider: CollisionShape3D = tower.get_node("Collision/Mast").get_child(0)
	collider.disabled = true
	_check(not Contract.valid(tower), "disabled narrow mast collider rejected")
	collider.disabled = false
	var body: StaticBody3D = tower.get_node("Collision/Mast")
	body.collision_layer = 0
	_check(not Contract.valid(tower), "wrong collision layers rejected")
	body.collision_layer = 1
	var light: OmniLight3D = OmniLight3D.new()
	tower.add_child(light)
	_check(not Contract.valid(tower), "unrequested active light rejected")
	tower.remove_child(light)
	light.free()
	_check(Contract.valid(tower), "all controls restore exact original model")
	tower.free()


func _site_conflicts() -> void:
	var host: Node3D = Node3D.new()
	var first: Node3D = Models.create()
	var second: Node3D = Models.create()
	host.add_child(first)
	host.add_child(second)
	_check(Sites.place(first, "PLIGHT-HL"), "first exact premium copy occupies fixed site")
	var original: Transform3D = second.transform
	var rays: Array = second.get_meta("candidate_head_rays").duplicate(true)
	_check(not Sites.place(second, "PLIGHT-HL"), "duplicate copy cannot occupy same site")
	_check(second.transform == original and second.get_meta("candidate_head_rays") == rays,
		"duplicate rejection is atomic")
	first.free()
	var standard: Node3D = StadiumFourHeadTowerModels.create()
	host.add_child(standard)
	_check(StadiumFourHeadTowerSites.place(standard, "MLIGHT-HL"), "authentic standard occupies site")
	_check(not Sites.place(second, "PLIGHT-HL"), "premium cannot overlap authentic ST-038")
	_check(second.transform == original and second.get_meta("candidate_head_rays") == rays,
		"standard collision rejection preserves candidate")
	_check(not Sites.place(second, "PLIGHT-ML") and not Sites.place(second, "MLIGHT-HL"),
		"premium cannot invent middle sites or accept standard site IDs")
	_check(Sites.place(second, "PLIGHT-HR"), "separate unoccupied premium site remains valid")
	host.free()


func _exact_scalar_controls(tower: Node3D) -> void:
	var mast: CylinderMesh = tower.get_node("Visual/Mast").mesh
	var shape: CylinderShape3D = tower.get_node("Collision/Mast").get_child(0).shape
	var material: StandardMaterial3D = tower.get_node("Visual/Head0/Lens").material_override
	for object: Object in [mast, shape, material]:
		var properties: Array[String] = []
		properties.assign(["roughness"] if object == material else ["height"])
		if object == mast:
			properties.append_array(["top_radius", "bottom_radius"])
		elif object == shape:
			properties.append("radius")
		for property: String in properties:
			var original: float = object.get(property)
			for step: int in [-1, 1]:
				_scalar_mutation(tower, object, property, original, step)
				object.set(property, original)
				_check(float(object.get(property)) == original,
					"restoration installs the exact original property value")
				_check(Contract.valid(tower), "exact property restoration accepted")


func _tree_controls(tower: Node3D) -> void:
	for path: String in ["Visual", "Collision", "Visual/Mast", "Visual/Head0",
		"Visual/Head0/Lens", "Collision/Mast"]:
		var node: Node3D = tower.get_node(path)
		var original: Transform3D = node.transform
		node.top_level = true
		_check(not Contract.valid(tower), "detached top-level branch rejected")
		node.top_level = false
		node.transform = original
		_check(Contract.valid(tower), "exact hierarchy restoration accepted")
	var collider: CollisionShape3D = tower.get_node("Collision/Mast").get_child(0)
	var collider_pose: Transform3D = collider.transform
	collider.top_level = true
	_check(not Contract.valid(tower), "detached collider frame rejected")
	collider.top_level = false
	collider.transform = collider_pose
	var lens: MeshInstance3D = tower.get_node("Visual/Head0/Lens")
	var extra: StaticBody3D = StaticBody3D.new()
	var extra_shape: CollisionShape3D = CollisionShape3D.new()
	extra_shape.shape = BoxShape3D.new()
	extra.add_child(extra_shape)
	lens.add_child(extra)
	_check(not Contract.valid(tower), "extra collider hidden under mesh leaf rejected")
	lens.remove_child(extra)
	extra.free()
	var material: StandardMaterial3D = lens.material_override
	material.grow = true
	material.grow_amount = 2.0
	_check(not Contract.valid(tower), "GPU-expanded lens rejected despite unchanged raw vertices")
	material.grow = false
	_check(not Contract.valid(tower), "dormant unauthorized grow amount rejected")
	material.grow_amount = 0.0
	_check(Contract.valid(tower), "tree and material controls restore exact model")


func _participation_controls(tower: Node3D) -> void:
	for path: String in ["Collision", "Collision/Mast"]:
		var node: Node = tower.get_node(path)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_check(not Contract.valid(tower), "disabled collider branch rejected")
		node.process_mode = Node.PROCESS_MODE_INHERIT
	var body: StaticBody3D = tower.get_node("Collision/Mast")
	body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	_check(not Contract.valid(tower), "noncanonical collision disable behavior rejected")
	body.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE
	for part: String in ["Footing", "BasePlate", "Mast"]:
		var shape: Shape3D = tower.get_node("Collision/" + part).get_child(0).shape
		var original: float = shape.margin
		shape.margin = 0.2
		_check(not Contract.valid(tower), "expanded collision margin rejected")
		shape.margin = original
	var parent: Node3D = Node3D.new()
	parent.add_child(tower)
	parent.process_mode = Node.PROCESS_MODE_DISABLED
	_check(not Contract.valid(tower), "inherited disabled host rejected")
	parent.process_mode = Node.PROCESS_MODE_INHERIT
	_check(Contract.valid(tower), "canonical detached inherited processing accepted")
	parent.remove_child(tower)
	parent.free()
	_check(Contract.valid(tower), "all participation controls restore exact original")


func _scalar_mutation(tower: Node3D, object: Object, property: String,
	original: float, step: int) -> void:
	var bytes: PackedByteArray = PackedFloat32Array([original]).to_byte_array()
	var original_bits: int = bytes.decode_u32(0)
	bytes.encode_u32(0, original_bits + step)
	var requested: float = bytes.decode_float(0)
	object.set(property, requested)
	var observed: float = object.get(property)
	_scalar_diagnostic(object, property, step, original, requested, observed)
	if observed == original:
		# CylinderMesh setters coalesce adjacent values using is_equal_approx.
		# A no-op is not an installed mutation and cannot prove rejection.
		_check(object is CylinderMesh, "only documented mesh setters coalesce adjacent values")
		_check(Contract.valid(tower), "coalesced setter leaves exact canonical geometry accepted")
		bytes.encode_u32(0, original_bits + step * 4096)
		requested = bytes.decode_float(0)
		object.set(property, requested)
		observed = object.get(property)
		_scalar_diagnostic(object, property, step * 4096, original, requested, observed)
	var installed: bool = observed == requested and observed != original
	_check(installed, "requested representable mutation must be independently read back exactly")
	if installed:
		_check(not Contract.valid(tower), "actual installed noncanonical float32 property rejected")


func _scalar_diagnostic(object: Object, property: String, ulps: int,
	original: float, requested: float, observed: float) -> void:
	var original_bits: int = PackedFloat32Array([original]).to_byte_array().decode_u32(0)
	var requested_bits: int = PackedFloat32Array([requested]).to_byte_array().decode_u32(0)
	var observed_bits: int = PackedFloat32Array([observed]).to_byte_array().decode_u32(0)
	print("PREMIUM_SCALAR ", object.get_class(), ".", property, " ulps=", ulps,
		" original=%.17f requested=%.17f observed=%.17f" % [original, requested, observed],
		" bits(original/requested/observed)=%08x/%08x/%08x" % [
			original_bits, requested_bits, observed_bits])

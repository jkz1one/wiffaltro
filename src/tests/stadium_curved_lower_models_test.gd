extends Node3D
## Isolated Working model qualification; no ownership, NPC registry or night certificate.

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var _failures: int = 0
var _native: NativeCapture
var _camera: Camera3D


func _ready() -> void:
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	var net: Node3D = StadiumReceiverNetModels.create()
	add_child(net)
	_check(StadiumReceiverNetModels.VERSION == 2, "test uses corrected receiver model v2")
	_actual_net_clearance(net)
	var roots: Array[Node3D] = []
	for site: String in StadiumCurvedLowerSites.SITES:
		_check(StadiumCurvedLowerSites.fits(site, "mogul")
			and not StadiumCurvedLowerSites.fits(site, "club"), "Mogul-only authored ground site")
		var root: Node3D = StadiumCurvedLowerModels.create()
		add_child(root)
		root.transform = StadiumCurvedLowerSites.pose(site)
		roots.append(root)
		_check(root.position == Vector3.ZERO and is_equal_approx(root.basis.determinant(), 1),
			"home-centered, ground-placed rigid orientation")
		_check(root.get_meta("represented_seats") == 36, "bounded art crowd, not inventory copies")
		for phase: float in [-PI / 2, 0, PI / 2]:
			StadiumCurvedLowerModels.animate_crowd(root, phase)
			_test_points(root)
		_ground_and_ends(root)
		StadiumCurvedLowerModels.animate_crowd(root, 0)
	_check(not StadiumCurvedLowerSites.fits("BOWL-06", "mogul"), "only five semantic sites")
	# Whole polygons and their collision convex hulls stay within disjoint convex sectors.
	# At r18 the 0.6-degree omitted seam supplies >18cm between neighboring complete ends.
	_check(2 * 18 * sin(deg_to_rad(0.3)) > 0.18, "positive finished standalone neighbor gap")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for root: Node3D in roots:
		_sightlines(root, net)
	await _sightline_controls(net)
	for side: int in [-1, 1]:
		var pole: Node3D = net.get_node("Visual/ST073_POLE%d" % side)
		var angle: float = fposmod(rad_to_deg(atan2(pole.position.x, pole.position.z)), 360)
		_check(absf(angle - (120.96376 if side == 1 else 239.03624)) < 0.001,
			"corrected poles are in outer empty Grand I sectors, never archived 135/225")
	# All-five orientation qualification above; preview is deliberately only Grand I's three copies.
	for index in [0, 4]:
		roots[index].queue_free()
	await get_tree().process_frame
	_setup_view()
	await _capture("ST-081-grand-I-overview", Vector3(35, 29, 23), Vector3(0, 2, -12), 54)
	roots[1].visible = false
	roots[3].visible = false
	await _capture("ST-081-standalone-front", Vector3(12, 13, -6), Vector3(0, 2.2, -21), 17)
	await _capture("ST-081-standalone-rear", Vector3(-12, 11, -34), Vector3(0, 2.2, -21), 17)
	_check(_native._failures == 0, "native handshake failures propagate")
	for root: Node3D in roots:
		if is_instance_valid(root):
			root.queue_free()
	net.queue_free()
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro curved lower models passed: five 30-degree sites, occupied bounds, clearance.")
	get_tree().quit(0 if _failures == 0 else 1)


func _actual_net_clearance(net: Node3D) -> void:
	for id: String in StadiumReceiverNetModels.PANELS:
		var mesh: MeshInstance3D = net.get_node("Visual/" + id)
		var impact: Vector3 = mesh.transform * Vector3(0, 3.375, 0)
		_check(StadiumReceiverNetModels.flex(net, id, 0.275, impact), "test peak actual net flex")
	for mesh: MeshInstance3D in net.find_children("*", "MeshInstance3D", true, false):
		var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point: Vector3 in points:
			var world: Vector3 = mesh.global_transform * point
			_check(Vector2(world.x, world.z).length() < 7.5,
				"actual v2 poles/anchors/lines/flex retain >10.5m radial bowl clearance")
	for shape: CollisionShape3D in net.find_children("*", "CollisionShape3D", true, false):
		var debug: Mesh = shape.shape.get_debug_mesh()
		for surface in range(debug.get_surface_count()):
			var points: PackedVector3Array = debug.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in points:
				var world: Vector3 = shape.global_transform * point
				_check(Vector2(world.x, world.z).length() < 7.5,
					"actual receiver collision is radially separated from full bowl")


func _test_points(root: Node3D) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var pose: Transform3D = root.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for point: Vector3 in vertices:
				_point(root, pose * point)
	for collision: CollisionShape3D in root.find_children("*", "CollisionShape3D", true, false):
		_check(collision.shape is ConvexPolygonShape3D, "exact faceted wedge collision")
		var inverse: Transform3D = root.global_transform.affine_inverse()
		var pose: Transform3D = inverse * collision.global_transform
		var points: PackedVector3Array = collision.shape.points
		for point: Vector3 in points:
			_point(root, pose * point)
		_check(collision.shape.margin == 0, "proxy does not inflate past miter boundaries")


func _point(root: Node3D, point: Vector3) -> void:
	_check(StadiumCurvedLowerSites.contains_local(point),
		"actual mesh/head/animation/proxy inside sector")
	var world: Vector3 = root.global_transform * point
	_check(not StadiumReceiverNetModels.ENVELOPE.grow(0.25).has_point(world),
		"actual occupied bowl is outside corrected complete net/pole/flex envelope")
	_check(Vector2(world.x, world.z).length() < 25,
		"no geometry grants reserved r25..28 concourse")


func _ground_and_ends(root: Node3D) -> void:
	for row in range(StadiumCurvedLowerModels.ROWS):
		var mesh: MeshInstance3D = root.get_node("Visual/SolidTerrace%d" % row)
		_check(is_zero_approx(mesh.get_aabb().position.y), "every terrace is supported to ground")
		for side: int in [-1, 1]:
			_check(root.has_node("Visual/FinishedEnd%d_%d" % [row, side])
				and root.has_node("Collision/FinishedEnd%d_%d" % [row, side]),
				"both exposed ends are complete independent of neighbor ownership")


func _sightlines(root: Node3D, net: Node3D) -> void:
	for anchor: Node3D in root.get_node("Visual").get_children():
		if not anchor.has_meta("rest_position"):
			continue
		var eye: Vector3 = anchor.global_position + Vector3.UP * 0.57
		_check(_sightline_clear(eye, Vector3(0, 1, 8), net),
			"eye-to-pitch ray traverses only verified net panels and rejects all opaque solids")
	# Protected near-field batting corridors on both sides stay clear of all stand geometry.
	for side: int in [-1, 1]:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(side * 1.2, 1.6, -1), Vector3(0, 1.1, 9), 1)
		_check(get_world_3d().direct_space_state.intersect_ray(query).is_empty(),
			"both batting-side pitch corridors clear actual bowl collision")


func _sightline_clear(from: Vector3, to: Vector3, net: Node3D) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	var excluded: Array[RID] = []
	# Repeat the entire original segment, excluding only each verified panel body.
	# Do not advance the origin: a farther or coincident opaque member must still block.
	for layer in range(StadiumReceiverNetModels.PANELS.size() + 1):
		query.exclude = excluded
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return true
		if not _verified_panel(hit, net):
			return false
		var body: StaticBody3D = hit.collider
		if body.get_rid() in excluded:
			return false
		excluded.append(body.get_rid())
	return false


func _verified_panel(hit: Dictionary, net: Node3D) -> bool:
	var body: StaticBody3D = hit.collider as StaticBody3D
	if body == null or hit.shape != 0:
		return false
	var id: String = body.get_meta("surface_id", "")
	if not StadiumReceiverNetModels.PANELS.has(id):
		return false
	# Metadata alone never establishes transparency. Require the original actual v2
	# body's identity, its one thin panel shape and matching strand-grid visual.
	if body != net.get_node("Collision/" + id) or body.get_child_count() != 1:
		return false
	var shape: CollisionShape3D = body.get_child(0)
	var mesh: MeshInstance3D = net.get_node("Visual/" + id)
	return shape.shape is BoxShape3D and is_equal_approx(shape.shape.size.z, 0.006) \
		and mesh.has_meta("rest_vertices") and mesh.has_meta("panel_width") \
		and is_equal_approx(shape.shape.size.x, mesh.get_meta("panel_width")) \
		and body.get_meta("surface_role", "") == "RECEIVER_CONTAINMENT_FOUL"


func _sightline_controls(net: Node3D) -> void:
	var behind: Vector3 = Vector3(0, 3, -6)
	var ahead: Vector3 = Vector3(0, 3, 0)
	_check(_sightline_clear(behind, ahead, net), "actual center mesh panel transmits sightline")
	_check(_sightline_clear(Vector3(-6, 3, -3.5), Vector3(6, 3, -3.5), net),
		"ray traverses both actual wing panels instead of accepting only the first hit")
	for side: int in [-1, 1]:
		_check(not _sightline_clear(Vector3(side * 4.5, 3, -4),
			Vector3(side * 4.5, 3, -1), net), "actual opaque ST073 pole rejects ray")
		_check(not _sightline_clear(Vector3(side * 4.72, 0.12, -4),
			Vector3(side * 4.72, 0.12, -2), net), "actual opaque ST073 anchor rejects ray")
	_check(not _sightline_clear(Vector3(0, 6.5, -6), Vector3(0, 6.5, -3), net),
		"opaque net edge cable is not an exempt transparent panel")
	var blocker: Node3D = Node3D.new()
	blocker.name = "SightlineOpaqueControl"
	blocker.set_meta("stadium_item", "ST-073")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		blocker.add_child(child)
	add_child(blocker)
	# Real opaque shape with spoofed item AND surface labels behind the authentic panel.
	StadiumSeatingModels._box(blocker, "ST073_CENTER_NET", Vector3(0, 3, -3.5),
		Vector3(0.5, 0.5, 0.5), Color.RED)
	var body: StaticBody3D = blocker.get_node("Collision/ST073_CENTER_NET")
	body.set_meta("surface_role", "RECEIVER_CONTAINMENT_FOUL")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(behind, ahead, 1)
	var first: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	_check(not first.is_empty() and _verified_panel(first, net),
		"layered control really hits authentic transparent panel before farther opaque blocker")
	_check(not _sightline_clear(behind, ahead, net),
		"farther opaque blocker cannot hide behind an accepted transparent panel")
	_check(not _sightline_clear(Vector3(-6, 3, -3.5), Vector3(6, 3, -3.5), net),
		"opaque blocker between two actual transparent panels rejects complete segment")
	blocker.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(_sightline_clear(behind, ahead, net), "control removal restores authentic panel-only ray")


func _setup_view() -> void:
	# Diagnostic ground only, outside the purchased model and its occupied bounds.
	var ground: BoxMesh = BoxMesh.new()
	ground.size = Vector3(70, 0.2, 65)
	StadiumSeatingModels._mesh(self, "StudyGround", ground, Vector3(0, -0.1, -10),
		Color("415e44"))
	StadiumWallRenderQuality.attach(self)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("263b37")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b6ccbe")
	environment.environment.ambient_light_energy = 0.7
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -32, 0)
	add_child(light)
	_camera = Camera3D.new()
	add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true


func _capture(label: String, eye: Vector3, target: Vector3, size_value: float) -> void:
	if StadiumAssetCapture.directory().is_empty() or DisplayServer.get_name() == "headless":
		return
	_camera.position = eye
	_camera.look_at(target)
	_camera.size = size_value
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "native window resize acknowledged")
		_check(await _native.capture(StadiumAssetCapture.directory(), label),
			"actual 1280x720 / 700x393 content readback with eight-frame draw wait")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

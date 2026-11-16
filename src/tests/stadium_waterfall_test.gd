extends Node3D
## Static ST-046 authoring candidate. Native review is deliberately separate from night.

const Models = preload("res://src/presentation/stadium/stadium_waterfall_models.gd")
const Sites = preload("res://src/presentation/stadium/stadium_waterfall_sites.gd")
const Contract = preload("res://src/tests/stadium_waterfall_contract.gd")
const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")

var _failures: int = 0
var _capture_dir: String = ""
var _native: NativeCapture
var _camera: Camera3D
var _waterfall: Node3D


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_waterfall = Models.create()
	add_child(_waterfall)
	_check(Sites.place(_waterfall), "authentic complete assembly installs in exact site")
	_check(_waterfall.transform == Transform3D(Basis.IDENTITY, Vector3(36.5, 0, 44)),
		"literal landmark center and identity facing")
	_check(Contract.valid(_waterfall), "independently specified complete geometry and material tree")
	_geometry()
	_mutations()
	_hosts()
	_conflicts()
	_setup_inspection()
	await _views()
	_check(_native._failures == 0, "native handshake has no hidden failures")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("stadium waterfall: PASS (Working static ST-046, bounded LANDMARK-A, no water physics)")
	get_tree().quit(0 if _failures == 0 else 1)


func _geometry() -> void:
	var total: int = 0
	var combined: AABB
	for child: MeshInstance3D in _waterfall.get_children():
		var bounds: AABB = child.transform * child.mesh.get_aabb()
		combined = bounds if total == 0 else combined.merge(bounds)
		var arrays: Array = child.mesh.surface_get_arrays(0)
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var point: Vector3 = child.transform * vertex
			total += 1
			_check(point.x >= -4.20001 and point.x <= 4.20001
				and point.z >= -1.90001 and point.z <= 1.90001
				and point.y >= -0.00001 and point.y <= 3.80001,
				"every generated vertex fits the Working visible envelope")
			var world: Vector3 = _waterfall.transform * point
			_check(world.x >= 30 and world.x <= 43 and world.z >= 39 and world.z <= 49
				and world.y >= -0.00001 and world.y <= 4,
				"every actual vertex inside literal BQ reservation")
			_check(world.z > 34 and world.x > 30,
				"water/rock assembly clears SCORE-LARGE-A z29..34 and central backdrop")
	_check(total == 504, "all twenty-one box meshes contribute their twenty-four vertices")
	_check(combined.position.is_equal_approx(Vector3(-4.2, 0, -1.9))
		and combined.size.is_equal_approx(Vector3(8.4, 3.8, 3.8)), "actual visible maximum size")
	# Exact supporting pairs, independently chosen from the construction.
	for pair: Array in [["BasinFront", "BasinFloor"], ["BasinLeft", "BasinFloor"],
		["BasinRight", "BasinFloor"], ["BasinBack", "BasinFloor"],
		["RockLower", "BasinFloor"], ["RockMiddle", "RockLower"],
		["RockCrownLeft", "RockMiddle"], ["RockCrownRight", "RockMiddle"],
		["RockShoulderLeft", "RockLower"], ["RockShoulderRight", "RockLower"],
		["SpillLip", "RockCrownRight"], ["CatchLedge", "RockMiddle"],
		["UpperWater", "SpillLip"], ["UpperWater", "CatchLedge"],
		["LowerWater", "CatchLedge"], ["LowerWater", "Pool"], ["Foam", "Pool"]]:
		_check(_touch(_bounds(pair[0]), _bounds(pair[1])), "actual support/contact %s" % str(pair))
	for id: String in ["Pool", "UpperWater", "LowerWater", "Foam",
		"UpperRillA", "UpperRillB", "LowerRillA", "LowerRillB"]:
		var bounds: AABB = _bounds(id)
		_check(bounds.position.x >= -3.90001 and bounds.end.x <= 3.90001
			and bounds.position.z >= -1.60001 and bounds.end.z <= 1.60001
			and bounds.position.y >= 0.2, "water inside the basin's horizontal interior")
	_check(_waterfall.get_meta("obstacle_units") == 0
		and not _waterfall.get_meta("night_qualified"), "no gameplay or night entitlement")


func _mutations() -> void:
	# Read every installed property before testing rejection; setters may coalesce deltas.
	for part: MeshInstance3D in _waterfall.get_children():
		var original: Transform3D = part.transform
		for delta: Vector3 in [Vector3(0.001, 0, 0), Vector3(0, 0.001, 0), Vector3(0, 0, 0.001)]:
			part.position += delta
			_check(part.transform != original, "transform mutation installed")
			_reject("displaced support/mesh")
			part.transform = original
		part.basis = Basis(Vector3.UP, 0.1)
		_check(part.transform != original, "rotation mutation installed")
		_reject("rotated geometry")
		part.transform = original
		part.scale = Vector3(1, 1.1, 1)
		_check(part.transform != original, "scale mutation installed")
		_reject("scaled geometry")
		part.transform = original
		var size: Vector3 = part.mesh.size
		part.mesh.size += Vector3(0.01, 0, 0)
		_check(part.mesh.size != size, "mesh size mutation installed")
		_reject("mesh enlargement")
		part.mesh.size = size
		part.visible = false
		_check(not part.visible, "hidden property installed")
		_reject("hidden geometry")
		part.visible = true
		part.mesh.flip_faces = true
		_check(part.mesh.flip_faces, "face flip installed")
		_reject("inverted face topology")
		part.mesh.flip_faces = false
		var material: StandardMaterial3D = part.material_override
		var color: Color = material.albedo_color
		material.albedo_color = Color.MAGENTA
		_check(material.albedo_color != color, "material color mutation installed")
		_reject("wrong material")
		material.albedo_color = color
		var rough: float = material.roughness
		material.roughness = 0.25
		_check(material.roughness != rough, "roughness mutation installed")
		_reject("wrong roughness")
		material.roughness = rough
		material.emission_enabled = true
		_check(material.emission_enabled, "emission property installed")
		_reject("emissive scenery")
		material.emission_enabled = false
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"transparency property installed")
		_reject("transparent substituted water")
		material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_check(material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED,
			"billboard GPU transform mutation installed")
		_reject("camera-facing GPU geometry")
		material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		material.no_depth_test = true
		_check(material.no_depth_test, "depth-test bypass installed")
		_reject("depth-test bypass")
		material.no_depth_test = false
		part.extra_cull_margin = 2.0
		_check(part.extra_cull_margin == 2.0, "extra culling margin installed")
		_reject("changed instance culling bounds")
		part.extra_cull_margin = 0.0
		material.grow = true
		_check(material.grow, "material grow mutation installed")
		_reject("grown silhouette")
		material.grow = false
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "cull mutation installed")
		_reject("changed face visibility")
		material.cull_mode = BaseMaterial3D.CULL_BACK
		part.material_overlay = StandardMaterial3D.new()
		_check(part.material_overlay != null, "material overlay installed")
		_reject("unapproved overlay")
		part.material_overlay = null
		part.layers = 2
		_check(part.layers == 2, "render layer mutation installed")
		_reject("wrong render layer")
		part.layers = 1
		_check(Contract.valid(_waterfall) and Models.valid(_waterfall),
			"exact restoration after mutations")
	for key: String in ["stadium_item", "working_geometry_only", "geometry_version",
		"obstacle_units", "night_qualified"]:
		var original: Variant = _waterfall.get_meta(key)
		for wrong: Variant in [[], {}, 0.5, null]:
			if wrong == null:
				_waterfall.remove_meta(key)
				_check(not _waterfall.has_meta(key), "missing root metadata installed")
			else:
				_waterfall.set_meta(key, wrong)
				_check(typeof(_waterfall.get_meta(key)) == typeof(wrong),
					"wrong metadata type actually installed")
			var before: Transform3D = _waterfall.transform
			_check(not Sites.place(_waterfall) and _waterfall.transform == before,
				"malformed root metadata rejects atomically without invalid comparison")
			_waterfall.set_meta(key, original)
			_check(Sites.place(_waterfall), "metadata restoration accepts")
	var collider: StaticBody3D = StaticBody3D.new()
	_waterfall.add_child(collider)
	_check(collider.get_parent() == _waterfall, "extra collider installed")
	_reject("unapproved collider even without a shape")
	_waterfall.remove_child(collider)
	collider.free()
	var script: GDScript = GDScript.new()
	script.source_code = "extends MeshInstance3D\n"
	_check(script.reload() == OK, "negative-control script compiles")
	var node: MeshInstance3D = _waterfall.get_node("Pool")
	node.set_script(script)
	_check(node.get_script() == script, "script mutation installed")
	_reject("script attached to water")
	node.set_script(null)
	_check(Contract.valid(_waterfall) and Sites.place(_waterfall), "all negative controls restore")


func _reject(label: String) -> void:
	var original: Transform3D = _waterfall.transform
	_check(not Contract.valid(_waterfall), "independent contract rejects " + label)
	_check(not Sites.place(_waterfall), "site admission rejects " + label)
	_check(_waterfall.transform == original, "rejection is atomic " + label)


func _hosts() -> void:
	var host: Node3D = Node3D.new()
	var nested: Node3D = Node3D.new()
	host.add_child(nested)
	var model: Node3D = Models.create()
	nested.add_child(model)
	_check(Sites.place(model), "identity detached host chain allowed")
	var original: Transform3D = model.transform
	for target: Node3D in [host, nested]:
		for pose: Transform3D in [Transform3D(Basis.IDENTITY, Vector3.ONE),
			Transform3D(Basis(Vector3.UP, 0.2), Vector3.ZERO),
			Transform3D(Basis.IDENTITY.scaled(Vector3(2, 1, 1)), Vector3.ZERO)]:
			target.transform = pose
			_check(target.transform != Transform3D.IDENTITY, "host pose mutation installed")
			_check(not Sites.place(model) and model.transform == original,
				"transformed ancestor rejected atomically")
			target.transform = Transform3D.IDENTITY
		target.visible = false
		_check(not target.visible and not Sites.place(model), "hidden host rejected")
		target.visible = true
		target.process_mode = Node.PROCESS_MODE_DISABLED
		_check(target.process_mode == Node.PROCESS_MODE_DISABLED and not Sites.place(model),
			"disabled host rejected")
		target.process_mode = Node.PROCESS_MODE_INHERIT
	_check(Sites.place(model), "host restoration accepts")
	_check(not Sites.place(model, "ODDITY-PLAZA") and not Sites.place(model, "TREEHOUSE-A"),
		"waterfall exclusive to primary major landmark")
	host.free()


func _conflicts() -> void:
	var duplicate: Node3D = Models.create()
	add_child(duplicate)
	_check(not Sites.place(duplicate), "one attraction per reservation")
	duplicate.free()
	var impostor: Node3D = Node3D.new()
	impostor.set_meta("stadium_item", "ST-046")
	impostor.set_meta("working_geometry_only", true)
	add_child(impostor)
	_check(not Sites.place(impostor), "metadata-only impostor fails closed")
	impostor.free()
	var blocker: MeshInstance3D = MeshInstance3D.new()
	blocker.mesh = BoxMesh.new()
	blocker.position = Vector3(36, 1, 44)
	add_child(blocker)
	_check(not Sites.place(_waterfall), "unlabelled actual geometry intrusion rejected")
	blocker.position = Vector3(36, 1, 31)
	_check(Sites.place(_waterfall), "separate literal video-board reservation does not conflict")
	blocker.set_meta("site", "LANDMARK-A")
	_check(not Sites.place(_waterfall), "marked competing occupant rejected regardless of location")
	blocker.free()
	_check(Sites.place(_waterfall), "conflict removal restores admission")
	var wrapper: Node3D = Node3D.new()
	wrapper.position = Vector3(100, 0, 0)
	add_child(wrapper)
	var top_mesh: MeshInstance3D = MeshInstance3D.new()
	top_mesh.mesh = BoxMesh.new()
	wrapper.add_child(top_mesh)
	top_mesh.top_level = true
	top_mesh.transform = Transform3D(Basis.IDENTITY, Vector3(36, 1, 44))
	top_mesh.force_update_transform()
	_check(top_mesh.top_level and top_mesh.global_transform == top_mesh.transform
		and top_mesh.global_position == Vector3(36, 1, 44),
		"top-level foreign mesh is actually inside despite translated wrapper")
	var before: Transform3D = _waterfall.transform
	_check(not Sites.place(_waterfall) and _waterfall.transform == before,
		"top-level foreign occupancy rejects atomically")
	top_mesh.top_level = false
	top_mesh.transform = Transform3D(Basis.IDENTITY, Vector3(36, 1, 44))
	top_mesh.force_update_transform()
	_check(not top_mesh.top_level and top_mesh.global_position == Vector3(136, 1, 44)
		and top_mesh.global_transform == wrapper.global_transform * top_mesh.transform,
		"restored inherited transform actually moves foreign mesh outside")
	_check(Sites.place(_waterfall), "restored ordinary far branch accepts")
	wrapper.free()
	_check(Sites.place(_waterfall), "foreign branch removal restores admission")


func _bounds(id: String) -> AABB:
	var node: MeshInstance3D = _waterfall.get_node(id)
	return node.transform * node.mesh.get_aabb()


func _touch(a: AABB, b: AABB) -> bool:
	return a.grow(0.00001).intersects(b.grow(0.00001))


func _setup_inspection() -> void:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("91b4bd")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	add_child(light)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.fov = 52
	add_child(_camera)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(26, 0.1, 24)
	ground.mesh = mesh
	ground.position = Vector3(36.5, -0.05, 44)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("58774e")
	ground.material_override = material
	add_child(ground)


func _views() -> void:
	for extent: Vector2i in [Vector2i(1280, 720), Vector2i(700, 400)]:
		_check(await _native.resize(extent), "actual native window/readback size handshake")
		for rear: bool in [false, true]:
			_camera.position = Vector3(45, 7.5, 54 if rear else 31)
			_camera.look_at(Vector3(36.5, 1.7, 44))
			_camera.force_update_transform()
			await get_tree().process_frame
			for part: MeshInstance3D in _waterfall.get_children():
				for point: Vector3 in part.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					var world: Vector3 = part.to_global(point)
					_check(not _camera.is_position_behind(world), "actual model vertex ahead of camera")
					_check(get_viewport().get_visible_rect().grow(-8).has_point(
						_camera.unproject_position(world)), "complete assembly fits native review frame")
			_check(await _native.capture(_capture_dir,
				"waterfall-supported-rear" if rear else "waterfall-bounded-basin-front"),
				"native daylight image capture")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("stadium waterfall: " + message)

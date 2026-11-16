extends "res://src/tests/stadium_surface_night_preview_test.gd"
## Shared rebuild view/check selector. Synthetic loadouts and funding; zero games.

var _images: Array[String] = []
var _pairs: Dictionary = {}
var _phase: String = "entry"
var _view: SubViewport


func _ready() -> void:
	pass


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"shared equipment qualification requires rendering and a bounded output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		BatSwingRegressionTest.run(self, _check)
		await _bats()
		await _balls()
		await _player_views()
		await _flags()
	_check(
		(
			_images
			== [
				"bat-lineup.png",
				"ball-shells.png",
				"day-equipped-player.png",
				"night-pitched-ball.png",
				"owned-flags.png"
			]
		),
		"exact five originals and no extra image matrix"
	)
	var result: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"pairs": _pairs,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_loadouts": true,
		"earned_career_claim": false,
		"live_game_claim": false
	}
	var payload: String = JSON.stringify(result, "", true, true)
	_check(payload.to_utf8_buffer().size() <= 131072, "finite shared optical and source operands")
	result.checks = _checks
	result.failures = _failures
	var file: FileAccess = FileAccess.open(
		directory.path_join("equipment-rebuild.json"), FileAccess.WRITE
	)
	if file == null:
		_check(false, "shared evidence file opens")
	else:
		file.store_string(JSON.stringify(result, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "shared evidence is fully written")
		file.close()
	print(
		(
			"EQUIPMENT_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func run_bats(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"bat-only preview requires rendering and a bounded output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		BatSwingRegressionTest.run(self, _check)
		_bat_loadout_mapping()
		await _bats(true)
	_check(
		_images == ["bat-lineup.png"], "exactly one all-twelve original; no other scenes or games"
	)
	var result: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"pairs": {},
		"games": 0,
		"synthetic_funding": false,
		"synthetic_loadouts": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"capture_scope": "bat-art-preview",
		"preview_only_concepts": ["Liberty", "Warhawk"]
	}
	var payload: String = JSON.stringify(result, "", true, true)
	_check(payload.to_utf8_buffer().size() <= 131072, "finite bat-only source and optical operands")
	result.checks = _checks
	result.failures = _failures
	var file: FileAccess = FileAccess.open(
		directory.path_join("equipment-rebuild.json"), FileAccess.WRITE
	)
	if file == null:
		_check(false, "bat-only evidence file opens")
	else:
		file.store_string(JSON.stringify(result, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "bat-only evidence is fully written")
		file.close()
	print(
		(
			"EQUIPMENT_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=false"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func run_bat_closeups(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"bat closeups require rendering and a bounded output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		await _bat_closeups()
	_check(
		_images == ["bat-art-closeups.png"],
		"one original containing Alley Bat, Gap Finder and Moonshot"
	)
	var result: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"pairs": {},
		"games": 0,
		"synthetic_funding": false,
		"synthetic_loadouts": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"capture_scope": "bat-art-closeups",
		"preview_only_concepts": []
	}
	var payload: String = JSON.stringify(result, "", true, true)
	_check(payload.to_utf8_buffer().size() <= 131072, "finite bat closeup evidence")
	result.checks = _checks
	result.failures = _failures
	var file: FileAccess = FileAccess.open(
		directory.path_join("equipment-rebuild.json"), FileAccess.WRITE
	)
	if file == null:
		_check(false, "bat closeup evidence file opens")
	else:
		file.store_string(JSON.stringify(result, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "bat closeup evidence is fully written")
		file.close()
	print(
		(
			"EQUIPMENT_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=false"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _bat_closeups() -> void:
	_phase = "bat-art-closeups"
	var root: Node3D = _world()
	_studio(root, Vector3(0, 0, 4), Vector3(0, 0, 0), 0.84)
	var ids: Array[String] = ["A02", "BAT-ALY-02", "BAT-POW-03"]
	var labels: Array[String] = ["ALLEY BAT", "GAP FINDER", "MOONSHOT"]
	for index: int in range(ids.size()):
		var id: String = ids[index]
		var bat: BatActor = BatActor.new()
		root.add_child(bat)
		bat.set_process(false)
		bat.set_cosmetic(id)
		var visual: MeshInstance3D = bat.get_node("SwingPivot/BatAxis/BatVisual")
		_check(
			(
				bat.cosmetic_id == id
				and visual.get_meta("cosmetic_id") == id
				and visual.find_children("*", "CollisionObject3D", true, false).is_empty()
			),
			"actual existing cosmetic identity and no collider " + id
		)
		bat.position = Vector3(-0.47, 0.30 - float(index) * 0.30, 0)
		bat._pivot.transform = Transform3D.IDENTITY
		bat._bat_axis.transform = Transform3D.IDENTITY
		bat.rotation.z = -PI * 0.5
		_label(root, labels[index], Vector2(100, 20 + 257 * index), 19)
	var alley_svg: String = BatActor._paint_svg("A02")
	_check(
		(
			alley_svg.contains('data-alley-finish="subtle-copper-gradient"')
			and alley_svg.contains('stop-color="#bd642e"')
			and alley_svg.contains('stop-color="#ae5530"')
			and not alley_svg.contains("data-alley-emblem")
			and not alley_svg.contains("<circle")
			and not alley_svg.contains("<ellipse")
			and alley_svg.contains('stroke="#e8bb75"')
		),
		"Alley retains its copper grid with a subtle redder/darker gradient and no decal"
	)
	var gap_svg: String = BatActor._paint_svg("BAT-ALY-02")
	_check(
		(
			gap_svg.contains('fill="#163449"')
			and gap_svg.contains('fill="#55ed73"')
			and gap_svg.contains('stroke="#78ff80"')
			and gap_svg.contains('stroke="#4dc571"')
			and gap_svg.count('data-baseball-diamond="infield"') == 2
			and gap_svg.count('data-gap-target="outfield"') == 2
		),
		"cybergreen accents retain the navy base, two radar diamonds and outfield targets"
	)
	_check(
		(
			gap_svg.count('data-gap-emblem="satellite"') == 2
			and gap_svg.count('data-gap-body="wiffle-ball"') == 2
			and gap_svg.count('data-wiffle-slots="upper-hemisphere"') == 2
			and gap_svg.count("data-wiffle-slot=") == 6
			and gap_svg.count('transform="translate(0 0) scale(0.5)"') == 2
			and gap_svg.count("M0-8V-18M-6-22Q0-14 6-22M-5-28Q0-31 5-28") == 2
		),
		(
			"both satellite center bodies carry three upper slots and a solid lower half, with "
			+ "original little dishes above"
		)
	)
	await _capture("bat-art-closeups.png")
	await _close_view()


func _bat_loadout_mapping() -> void:
	_phase = "bat-loadout-mapping"
	# Detached real presentation adapter: no lab startup, pitch, season, shop or save.
	var lab: PitchBatLab = PitchBatLab.new()
	var original: PlayerDefinition = ContentDB.get_player(PitchBatLab.DEBUG_PLAYER_ID)
	var original_gear: Dictionary = original.season_gear.duplicate(true)
	var definitions: Array[PlayerDefinition] = []
	for index in range(4):
		definitions.append(original.duplicate(true) as PlayerDefinition)
	lab._match_state = MatchState.create(
		TeamMatchState.create("Preview away", definitions),
		TeamMatchState.create("Preview home", definitions)
	)
	lab._match_mode = true
	lab._batter_avatar = PlayerAvatar.new()
	add_child(lab._batter_avatar)
	lab._batter_avatar.set_process(false)
	lab._bat_actor = BatActor.new()
	add_child(lab._bat_actor)
	lab._bat_actor.set_process(false)
	var ids: Array[String] = BatActor.cosmetic_ids()
	ids.append_array(["PREVIEW-LIBERTY", "PREVIEW-WARHAWK"])
	for id: String in ids:
		var expected: String = "" if id.begins_with("PREVIEW-") else id
		lab._match_state.batter().definition.season_gear = {"bat": id}
		PitchBatLabPresentation.sync_players(lab)
		var sync_exact: bool = lab._bat_actor.cosmetic_id == expected
		PitchBatLabPresentation.play_batter_swing(lab, ContentDB.get_swing(&"swing.contact"))
		_check(
			sync_exact and lab._bat_actor.cosmetic_id == expected and lab._bat_actor._swinging,
			"ordinary sync and swing map only real equipment; concept keys fall back " + id
		)
	_check(
		original.season_gear == original_gear,
		"all mapping diagnostics leave the authored player pristine"
	)
	lab._bat_actor.free()
	lab._batter_avatar.free()
	lab.free()


func _check(ok: bool, message: String) -> void:
	if not ok:
		print("EQUIPMENT_FAILURE " + JSON.stringify({"phase": _phase, "message": message}))
	super._check(ok, message)


func _world() -> Node3D:
	_view = SubViewport.new()
	_view.size = SIZE
	_view.own_world_3d = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var root: Node3D = Node3D.new()
	_view.add_child(root)
	return root


func _studio(root: Node3D, eye: Vector3, target: Vector3, size: float) -> Camera3D:
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("16232e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("e2e8ee")
	environment.environment.ambient_light_energy = 0.55
	root.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 0.9
	root.add_child(light)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.position = eye
	camera.look_at(target)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.make_current()
	return camera


func _label(root: Node, text: String, position: Vector2, font_size: int = 22) -> void:
	var label: Label = Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	root.add_child(label)


func _capture(name: String, expected_size: Vector2i = SIZE) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _view.get_texture().get_image()
	_check(
		not image.is_empty() and image.get_size() == expected_size,
		"exact native image %dx%d " % [expected_size.x, expected_size.y] + name
	)
	if not image.is_empty():
		_check(
			image.save_png(_capture_dir.path_join(name)) == OK, "original native PNG saved " + name
		)
		_images.append(name)


func _close_view() -> void:
	_view.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_view = null


func _bats(include_previews: bool = false) -> void:
	_phase = "bat-lineup"
	var root: Node3D = _world()
	if include_previews:
		_view.size = Vector2i(1920, 1080)
	var camera: Camera3D = _studio(
		root, Vector3(0, 1.1, 4), Vector3(0, 1.1, 0), 3.4 if include_previews else 3.0
	)
	var ids: Array[String] = BatActor.cosmetic_ids()
	_check(
		(
			ids
			== [
				"",
				"BAT-CON-01",
				"BAT-CON-02",
				"BAT-CON-03",
				"BAT-POW-01",
				"BAT-POW-02",
				"BAT-POW-03",
				"A02",
				"BAT-ALY-02",
				"BAT-ALY-03"
			]
		),
		"nine existing equipped identities plus the default; no new SKU"
	)
	if include_previews:
		ids.append_array(["PREVIEW-LIBERTY", "PREVIEW-WARHAWK"])
	var columns: int = 6 if include_previews else 5
	var identities: Array[int] = []
	var captions: Array[Dictionary] = []
	for index in range(ids.size()):
		var bat: BatActor = BatActor.new()
		root.add_child(bat)
		bat.set_process(false)
		bat.set_cosmetic(ids[index])
		var visual: Node3D = bat.get_node("SwingPivot/BatAxis/BatVisual")
		var equipped_id: String = "" if ids[index].begins_with("PREVIEW-") else ids[index]
		_check(
			(
				bat.cosmetic_id == equipped_id
				and visual.get_meta("cosmetic_id") == equipped_id
				and visual.find_children("*", "CollisionObject3D", true, false).is_empty()
				and visual.find_children("*", "CollisionShape3D", true, false).is_empty()
			),
			"current cosmetic is exact and adds no contact body " + ids[index]
		)
		identities.append(visual.get_instance_id())
		var preview_only: bool = ids[index].begins_with("PREVIEW-")
		if preview_only:
			# Explicit studio-only resources. The actor's actual equipped ID stays empty.
			var preview_image: Image = Image.new()
			var preview_error: Error = preview_image.load_svg_from_string(
				BatActor._paint_svg(ids[index])
			)
			_check(
				(
					preview_error == OK
					and bat.cosmetic_id.is_empty()
					and SeasonGearCatalog.item(ids[index]).is_empty()
				),
				"concept art has no equipment identity " + ids[index]
			)
			if preview_error == OK:
				preview_image.generate_mipmaps()
				var preview_material: StandardMaterial3D = (
					visual.material_override.duplicate() as StandardMaterial3D
				)
				preview_material.albedo_texture = ImageTexture.create_from_image(preview_image)
				visual.material_override = preview_material
				visual.mesh = BatActor._cosmetic_mesh(ids[index])
				visual.set_meta("preview_only", true)
		var column_spacing: float = 0.9 if include_previews else 0.75
		var row_height: float = (
			(1.28 if index < columns else -0.12)
			if include_previews
			else (1.2 if index < columns else -0.2)
		)
		bat.position = Vector3(
			(index % columns - float(columns - 1) / 2.0) * column_spacing, row_height, 0
		)
		bat._pivot.transform = Transform3D.IDENTITY
		bat._bat_axis.transform = Transform3D.IDENTITY
		var title: String = (
			"Yellow plastic"
			if ids[index].is_empty()
			else str(SeasonGearCatalog.item(ids[index]).get("name", ""))
		)
		if preview_only:
			title = "Liberty" if ids[index] == "PREVIEW-LIBERTY" else "Warhawk"
		captions.append({"visual": visual, "title": title.replace(" Bat", "")})
	# Project after the private camera/viewport has applied its actual display extent.
	await get_tree().process_frame
	for caption: Dictionary in captions:
		var visual: MeshInstance3D = caption.visual
		var tip: Vector3 = visual.to_global(Vector3(0, visual.mesh.get_aabb().end.y, 0))
		var label: Label = Label.new()
		label.text = caption.title
		label.position = (
			camera.unproject_position(tip)
			- (Vector2(110, 64) if include_previews else Vector2(70, 28))
		)
		label.size = Vector2(220, 56) if include_previews else Vector2(140, 20)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 24 if include_previews else 16)
		root.add_child(label)
	_check(
		identities.size() == (12 if include_previews else 10) and not identities.has(0),
		"all requested appearances are independently instantiated"
	)
	if include_previews:
		_check(
			(
				BatActor._cosmetic_mesh("BAT-POW-02").get_aabb().size.x
				> BatActor._cosmetic_mesh("BAT-POW-01").get_aabb().size.x
			),
			"Loaded has an actual wider end-weighted silhouette rather than a paint-only change"
		)
	var probe: BatActor = BatActor.new()
	root.add_child(probe)
	probe.set_process(false)
	probe.set_aim_pose(Vector2(0.3, -0.2))
	probe.play_swing(ContentDB.get_swing(&"swing.contact"))
	probe._process(0.05)
	var pose: Transform3D = probe._pivot.transform
	var elapsed: float = probe._swing_elapsed
	probe.set_cosmetic("BAT-POW-03")
	_check(
		probe._pivot.transform == pose and probe._swing_elapsed == elapsed and probe._swinging,
		"changing current art cannot reset the authored swing or aim"
	)
	probe.set_cosmetic("unknown-equipment")
	_check(
		probe.cosmetic_id.is_empty(),
		"unknown cosmetic identity uses yellow default without a new item"
	)
	probe.free()
	var heading: String = (
		"ALL BATS"
		if include_previews
		else "EQUIPMENT STUDY | Existing IDs, unchanged stats | Synthetic display"
	)
	_label(
		root,
		heading,
		Vector2(40, 30) if include_previews else Vector2(28, 24),
		30 if include_previews else 22
	)
	await _capture("bat-lineup.png", _view.size)
	await _close_view()


func _surface_hit(mesh: Mesh, direction: Vector3) -> bool:
	var triangles: PackedVector3Array = mesh.get_faces()
	# The engine's fixed determinant epsilon requires a well-scaled diagnostic space.
	# Uniformly scale actual vertices and this same segment; geometry/topology are unchanged.
	var inverse_radius: float = 1.0 / (mesh.get_aabb().size.x * 0.5)
	var begin: Vector3 = direction * 0.080 * inverse_radius
	var end: Vector3 = direction * 0.065 * inverse_radius
	for offset in range(0, triangles.size(), 3):
		if (
			Geometry3D.segment_intersects_triangle(
				begin,
				end,
				triangles[offset] * inverse_radius,
				triangles[offset + 1] * inverse_radius,
				triangles[offset + 2] * inverse_radius
			)
			!= null
		):
			return true
	return false


func _balls() -> void:
	_phase = "ball-shells"
	var root: Node3D = _world()
	var camera: Camera3D = _studio(root, Vector3(0, 0.015, 1), Vector3.ZERO, 0.43)
	var actor: PitchFlightActor = PitchFlightActor.new()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.visible = true
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	root.add_child(ball)
	var reverse: BattedBallBody = BattedBallBody.new()
	reverse.freeze = true
	root.add_child(reverse)
	var visual: WiffleBallVisual = actor.get_node("DebugBall")
	var body_visual: WiffleBallVisual = ball.get_child(1)
	var shape: SphereShape3D = ball.get_child(0).shape
	var reference_shape: SphereShape3D = SphereShape3D.new()
	reference_shape.radius = 0.0365
	var reference_body: RigidBody3D = RigidBody3D.new()
	reference_body.mass = 0.020
	var reference_material: PhysicsMaterial = PhysicsMaterial.new()
	reference_material.bounce = 0.52
	reference_material.friction = 0.42
	_check(
		(
			visual.authored_mesh()
			and body_visual.authored_mesh()
			and visual.mesh.get_aabb().size.x * 0.5 == PackedFloat32Array([0.075])[0]
			and body_visual.mesh.get_aabb().size.x * 0.5 == PackedFloat32Array([0.075])[0]
		),
		"pitched and batted visuals retain the exact native outer radius"
	)
	_check(
		(
			ball.radius_m == 0.0365
			and ball.mass == reference_body.mass
			and shape.radius == reference_shape.radius
			and ball.hole_axis_ball_local == Vector3.RIGHT
			and ball.physics_material_override.bounce == reference_material.bounce
			and ball.physics_material_override.friction == reference_material.friction
			and ball.collision_layer == 2
			and ball.collision_mask == 1
			and ball.continuous_cd
		),
		"cosmetic shell preserves physical radius mass bounce friction masks and continuous contact"
	)
	reference_body.free()
	var open_slots: int = 0
	var intact_reverse: int = 0
	for slot in range(8):
		var phi: float = TAU * slot / 8.0
		var direction: Vector3 = Vector3(cos(0.84), sin(0.84) * cos(phi), sin(0.84) * sin(phi))
		if not _surface_hit(visual.mesh, direction):
			open_slots += 1
		if _surface_hit(visual.mesh, -direction):
			intact_reverse += 1
	print("EQUIPMENT_SHELL_OPERANDS slots=%d intact_reverse=%d" % [open_slots, intact_reverse])
	_check(
		open_slots == 8 and intact_reverse == 8,
		"actual mesh triangles have eight open slots and an intact opposite hemisphere"
	)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3.ZERO
	launch.velocity = Vector3(3, 4, 5)
	launch.angular_velocity = Vector3(1, 2, 3)
	launch.orientation = Quaternion(Vector3.UP, 0.25)
	ball.launch(launch)
	_check(
		(
			ball.global_position == launch.position
			and ball.linear_velocity == launch.velocity
			and ball.angular_velocity == launch.angular_velocity
			and ball.basis == Basis(launch.orientation)
		),
		"ordinary launch retains exact position velocity spin and orientation"
	)
	ball.freeze = true
	ball.linear_velocity = Vector3.ZERO
	ball.angular_velocity = Vector3.ZERO
	var original: Material = visual.material_override
	var original_mesh: Mesh = visual.mesh
	StadiumNightBallStyle.apply(actor)
	var working: Material = visual.material_override
	_check(
		(
			working is ShaderMaterial
			and working.shader.code == StadiumNightBallStyle.SOURCE
			and working.get_shader_parameter("ball_color") == WiffleBallVisual.WHITE
			and visual.mesh == original_mesh
			and visual.authored_mesh()
		),
		"ordinary Night rim uses the real shell and captured white material"
	)
	StadiumNightBallStyle.apply(actor)
	_check(
		(
			visual.material_override == working
			and StadiumNightBallStyle.restore(actor)
			and visual.material_override == original
			and visual.mesh == original_mesh
			and visual.authored_mesh()
		),
		"Night apply is idempotent and restores the exact original"
	)
	StadiumNightBallStyle.apply(actor)
	var foreign: StandardMaterial3D = StandardMaterial3D.new()
	visual.material_override = foreign
	_check(
		not StadiumNightBallStyle.restore(actor) and visual.material_override == foreign,
		"Night cleanup refuses a foreign replacement without writing it"
	)
	visual.material_override = working  # Fixture cleanup does not claim a successful restore.
	visual.material_override = original
	# Exercise the retained three-pixel contract on this real authored shell and the legacy sphere.
	var readability: StadiumNpcRetainedBallReadability = StadiumNpcRetainedBallReadability.new()
	var body_transform: Transform3D = ball.transform
	var visual_transform: Transform3D = body_visual.transform
	var shell: Mesh = body_visual.mesh
	var shape_radius: float = shape.radius
	camera.size = 100.0
	readability.update(ball, camera, true)
	var first: Dictionary = readability.diagnostics()
	print("EQUIPMENT_READABILITY_OPERANDS " + JSON.stringify(first))
	_check(
		(
			first.base_diameter_px < 3.0
			and first.effective_diameter_px >= 3.0
			and body_visual.authored_mesh()
			and body_visual.mesh == shell
			and ball.transform == body_transform
			and shape.radius == shape_radius
			and ball.linear_velocity == Vector3.ZERO
			and ball.angular_velocity == Vector3.ZERO
		),
		"authored shell retains the unchanged native three-pixel floor without physical mutation"
	)
	var scaled_transform: Transform3D = body_visual.transform
	readability.update(ball, camera, true)
	var repeated: bool = body_visual.transform == scaled_transform
	readability.restore_all()
	_check(
		repeated and body_visual.transform == visual_transform and body_visual.mesh == shell,
		"retained shell sizing is idempotent and restores the exact visual transform"
	)
	var legacy: BattedBallBody = BattedBallBody.new()
	legacy.freeze = true
	root.add_child(legacy)
	legacy.get_child(1).free()
	var legacy_visual: MeshInstance3D = MeshInstance3D.new()
	var legacy_mesh: SphereMesh = SphereMesh.new()
	legacy_mesh.radius = 0.075
	legacy_mesh.height = 0.15
	legacy_visual.mesh = legacy_mesh
	legacy.add_child(legacy_visual)
	var legacy_transform: Transform3D = legacy_visual.transform
	readability.update(legacy, camera, true)
	var legacy_diameter: float = readability.diagnostics().effective_diameter_px
	readability.restore_all()
	_check(
		(
			legacy_diameter >= 3.0
			and legacy_visual.transform == legacy_transform
			and legacy_visual.mesh == legacy_mesh
		),
		"legacy sphere retains the same floor and exact restoration"
	)
	legacy.free()
	camera.size = 0.43
	actor.position.x = -0.24
	reverse.position.x = 0.24
	actor.rotation.y = -PI / 2
	ball.rotation.y = -PI / 2
	reverse.rotation.y = PI / 2
	_label(
		root,
		"BALL STUDY | Pitched / Batted / Intact reverse | Ordinary visual radius",
		Vector2(24, 24),
		21
	)
	await _capture("ball-shells.png")
	await _close_view()


func _player_views() -> void:
	_phase = "owned-day-night-player"
	var save_path: String = SeasonSave.path
	var save_error: String = SeasonSave.last_error
	SeasonSave.path = "user://equipment-rebuild-%d.json" % OS.get_process_id()
	var setup: Node = load("res://src/tests/stadium_surface_night_gameplay_a_test.gd").new()
	var completed: SeasonState = setup._funding()
	_check(completed != null, "existing explicitly synthetic closed funding setup succeeds")
	if completed == null:
		setup.free()
		SeasonSave.path = save_path
		SeasonSave.last_error = save_error
		return
	var paid: ClubAssetLedger = setup._purchases(completed)
	_checks += setup._checks
	_failures += setup._failures
	if paid == null:
		setup.free()
		SeasonSave.path = save_path
		SeasonSave.last_error = save_error
		return
	var root: Node3D = _world()
	var app: SeasonApp = SeasonApp.new()
	root.add_child(app)
	app.set_process(false)
	var day_points: Dictionary = {}
	for profile: String in ["day", "night"]:
		app.season = completed
		app.begin_surface_time_season(profile, 101, 0)
		var season: SeasonState = app.season
		var drafted: bool = season != null and season != completed and setup._time_draft(season)
		_check(drafted, "ordinary named profile and valid round0 checkpoint " + profile)
		if not drafted:
			break
		var home: Dictionary = setup._first_home(season)
		season.round_index = int(home.round)  # Diagnostic cursor only: never settled/saved.
		app._fixture_id = int(home.id)
		app._open_match(season.make_match(), true, true, PitchBatLab.FIELD_ID)
		var lab: PitchBatLab = app.lab
		var installed: bool = (
			is_instance_valid(lab)
			and StadiumSurfaceNightRuntime.installed_bound(lab, lab._match_state.stadium)
		)
		_check(installed, "actual current profile uses its ordinary paid property owner " + profile)
		if not installed:
			break
		setup._pause(lab)
		lab.process_mode = Node.PROCESS_MODE_DISABLED
		lab._status_label.visible = false
		var player: PlayerMatchState = lab._match_state.batter()
		var original_definition: PlayerDefinition = player.definition
		var original_gear: Dictionary = original_definition.season_gear.duplicate(true)
		player.definition = original_definition.duplicate(true)
		player.definition.season_gear = original_definition.season_gear.duplicate(true)
		player.definition.season_gear["bat"] = "BAT-CON-03"  # Optical equipped-copy diagnostic only.
		PitchBatLabPresentation.sync_players(lab)
		_check(
			(
				lab._bat_actor.cosmetic_id == "BAT-CON-03"
				and original_definition.season_gear == original_gear
			),
			"ordinary player sync reads the current green paddle loadout " + profile
		)
		var actor: PitchFlightActor = PitchFlightActor.new()
		lab.add_child(actor)
		actor.set_physics_process(false)
		actor.visible = true
		actor.position = Vector3(0, 1.05, 1)
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		ball.visible = false
		var director: MatchCameraDirector = lab._camera_director
		director.clear_presentation_motion()
		director.set_shot(MatchCameraDirector.Shot.PITCHING)
		director.snap(lab._camera)
		if profile == "night":
			StadiumNightBallStyle.apply(actor)
		var pitch: Dictionary = await _contrast(lab._camera, actor)
		if profile == "day":
			day_points.pitch = pitch.difference
		else:
			var threshold: float = maxf(0.03, float(day_points.pitch) * 0.65)
			_check(
				pitch.difference >= threshold,
				"Night pitched shell retains the existing paired contrast threshold"
			)
			_pairs.pitch = {
				"day": day_points.pitch,
				"night": pitch.difference,
				"threshold": threshold,
				"night_operands": pitch.operands
			}
			await _capture("night-pitched-ball.png")
		actor.visible = false
		_pose(lab, ball)
		var ground: Dictionary = await _contrast(lab._camera, ball)
		if profile == "day":
			day_points.ground = ground.difference
			ball.visible = false
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.snap(lab._camera)
			await _capture("day-equipped-player.png")
		else:
			var threshold: float = maxf(0.03, float(day_points.ground) * 0.65)
			_check(
				ground.difference >= threshold,
				"Night batted shell retains the existing plate-ground contrast threshold"
			)
			_pairs.ground = {
				"day": day_points.ground,
				"night": ground.difference,
				"threshold": threshold,
				"night_operands": ground.operands
			}
		player.definition = original_definition
		PitchBatLabPresentation.sync_players(lab)
		app._close_match()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	if is_instance_valid(app.lab):
		app._close_match()
	await _close_view()
	setup.free()
	SeasonSave.path = save_path
	SeasonSave.last_error = save_error


func _flags() -> void:
	_phase = "owned-flag-field"
	var root: Node3D = _world()
	var stock: StadiumStock = StadiumStock.new_club()
	var quote: Dictionary = StadiumFlagItems.quote(
		stock, "ST-043", 2, "rebuild-flags", {"seasons": 2, "wins": 5}
	)
	_check(quote.ok, "existing paid quote supplies two synthetic authoring flag copies")
	if not quote.ok:
		await _close_view()
		return
	stock = StadiumStock.from_data(quote.state)
	var layout: Dictionary = StadiumFlagItems.upgrade(
		StadiumStarterLayout.empty(),
		StadiumSurfaceProgression.initial(StadiumSurfaceProgression.LEGACY_ORIGIN)
	)
	layout.flags = [
		{"copy": "purchase:rebuild-flags:0", "site": "FLAG-GROUND-L"},
		{"copy": "purchase:rebuild-flags:1", "site": "FLAG-GROUND-R"}
	]
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	root.add_child(property)
	var built: bool = property.build("backyard", layout, stock)
	_check(
		built and StadiumBoundaryRuntime.assemble(property) != null,
		"unchanged owned flag property and complete playing boundary build"
	)
	if not built:
		await _close_view()
		return
	var camera: Camera3D = _studio(root, Vector3(0, 2.45, 16.9), Vector3(0, 1.05, 0), 32)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	var director: MatchCameraDirector = MatchCameraDirector.new()
	director.set_shot(MatchCameraDirector.Shot.PITCHING)
	director.snap(camera)
	for index in range(2):
		var copy: String = "purchase:rebuild-flags:%d" % index
		var model: StadiumFlagModels = property.objects[copy]
		_check(
			(
				model.get_meta("owned_copy") == copy
				and model._intact()
				and model.position == Vector3(-12 if index == 0 else 12, 0, -8)
				and not camera.is_position_behind(model.global_position + Vector3(0, 3, 0))
			),
			"unchanged exact owned flag and pole are in front of the ordinary pitching view"
		)
	_label(
		root,
		"OWNED FLAGS | Two paid outside-play copies | Synthetic placement review",
		Vector2(24, 24),
		21
	)
	await _capture("owned-flags.png")
	await _close_view()

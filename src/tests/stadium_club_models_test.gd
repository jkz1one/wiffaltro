extends "res://src/tests/stadium_seating_test.gd"
## Measured club displays with held pitch-window numbers; authoring stock is synthetic.

var _flag_only: bool = false
var _flag_checks: int = 0
var _flag_models: int = 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--mounted-display-close-views"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_mounted_display_close_views.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--mounted-display-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_mounted_display_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--player-tunnel-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_player_tunnel_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--wall-top-terrace-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = (
			load("res://src/tests/stadium_wall_top_terrace_rebuild_checks.gd").new()
		)
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--rising-apple-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_rising_apple_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--outfield-bleacher-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = (
			load("res://src/tests/stadium_outfield_bleacher_rebuild_checks.gd").new()
		)
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	await _club_landmark_routes()


func _club_landmark_routes() -> void:
	if OS.get_cmdline_user_args().has("--landmark-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_landmark_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--treehouse-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_treehouse_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--practice-facility-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = (
			load("res://src/tests/stadium_practice_facility_rebuild_checks.gd").new()
		)
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--ground-box-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_ground_box_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--molded-seat-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_molded_seat_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--small-yard-scenery-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = (
			load("res://src/tests/stadium_small_yard_scenery_rebuild_checks.gd").new()
		)
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	await _club_furnishing_routes()


func _club_furnishing_routes() -> void:
	if OS.get_cmdline_user_args().has("--live-furnishing-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_live_furnishing_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--landscape-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_landscape_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--floodlight-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_floodlight_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--receiver-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_receiver_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--boundary-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_boundary_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--facility-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_facility_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	await _club_roof_routes()


func _club_roof_routes() -> void:
	if OS.get_cmdline_user_args().has("--roof-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_roof_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--straight-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_straight_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--ground-props-rebuild"):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/stadium_ground_props_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if (
		OS.get_cmdline_user_args().has("--equipment-rebuild")
		or OS.get_cmdline_user_args().has("--bat-art-preview")
		or OS.get_cmdline_user_args().has("--bat-art-closeups")
	):
		var directory: String = ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--ui-capture-dir="):
				directory = argument.trim_prefix("--ui-capture-dir=")
		var helper: Node3D = load("res://src/tests/equipment_visual_rebuild_checks.gd").new()
		add_child(helper)
		var result: Dictionary
		if OS.get_cmdline_user_args().has("--bat-art-closeups"):
			result = await helper.run_bat_closeups(directory)
		elif OS.get_cmdline_user_args().has("--bat-art-preview"):
			result = await helper.run_bats(directory)
		else:
			result = await helper.run(directory)
		helper.queue_free()
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(0 if result.failures == 0 else 1)
		return
	if OS.get_cmdline_user_args().has("--club-flag"):
		_flag_only = true
		await _flag_contract()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	var stock: StadiumStock = StadiumStock.new_club()
	for item: String in ["ST-039", "ST-041"]:
		var quote: Dictionary = stock.quote(item, 1, {"seasons": 4, "wins": 10}, item)
		_check(quote.ok, "explicit authoring-only display receipt")
		stock = StadiumStock.from_data(quote.state)
	var rows: Array = [
		{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"},
		{"copy": "purchase:ST-041:0", "site": "SIGN-GROUND-L"}
	]
	var checked: Dictionary = StadiumClubSites.validate(rows, stock)
	_check(checked.ok, "exact independent scoreboard and ground-sign sites")
	var bad: Array = rows.duplicate(true)
	bad[1].copy = "starter-v1:ST-079"
	_check(not StadiumClubSites.validate(bad, stock).ok, "no other chair or item can become a sign")
	bad = rows.duplicate(true)
	bad.append({"copy": "purchase:ST-041:0", "site": "SIGN-GROUND-R"})
	_check(not StadiumClubSites.validate(bad, stock).ok, "one sign cannot populate both sides")
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(
		property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"unchanged reference property"
	)
	_check(StadiumBoundaryRuntime.assemble(property) != null, "actual complete field boundary")
	var objects: Dictionary = {}
	for row: Dictionary in checked.placements:
		var model: Node3D = StadiumClubModels.create(row.item)
		property.add_child(model)
		_check(
			StadiumClubSites.envelope(row.item).grow(0.001).encloses(_bounds(model, model)),
			"actual occupied model fits its complete authored envelope"
		)
		model.position = row.position
		model.rotation_degrees.y = row.yaw
		objects[row.item] = model
		for body: Node in model.get_node("Collision").get_children():
			_check(
				body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL",
				"all named display surfaces are outside-play only"
			)
	var display: StadiumScoreboardDisplay = objects["ST-039"].get_node("Visual/ScoreDisplay")
	_score_contract(display)
	await _bound_score(display)
	await _score_visibility(display)
	for item: String in objects:
		print("CLUB_BOUNDS ", item, " ", _visible_bounds(objects[item]))
		for label: Label3D in objects[item].find_children("*", "Label3D", true, false):
			print("CLUB_FONT ", item, " ", label.text, " ", label.position, " ", label.get_aabb())
		_check(
			StadiumClubSites.envelope(item).grow(0.001).encloses(_visible_bounds(objects[item])),
			"all visible geometry, including actual font bounds, fits the item envelope"
		)
	await _terminal_scoreboard(objects["ST-039"])
	await _capture_displays(property, objects)
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro club display checks passed: measured sites and stable pitch-window scores."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _score_contract(display: StadiumScoreboardDisplay) -> void:
	var first: Dictionary = {"inning": 2, "home": 3, "away": 1}
	var second: Dictionary = {"inning": 3, "home": 5, "away": 2}
	_check(display.present(first, false) and display.shown == first, "between-play score update")
	_check(
		display.present(second, true) and display.shown == first, "pitch window holds prior numbers"
	)
	_check(
		display.present(second, false) and display.shown == second, "new numbers appear after play"
	)
	_check(
		(
			not display.present({"inning": 3, "home": true, "away": 2}, false)
			and display.shown == second
		),
		"malformed score never replaces the visible board"
	)
	_check(
		display.present({"inning": 9999, "home": 9999, "away": 9999}, false),
		"bounded large scores do not invent truncation or awards"
	)
	_check(display.present(second, false), "restore readable review score")


func _bound_score(display: StadiumScoreboardDisplay) -> void:
	var state: MatchState = MatchState.new()
	state.home_team = TeamMatchState.new()
	state.away_team = TeamMatchState.new()
	state.inning = 3
	state.home_team.runs = 7
	state.away_team.runs = 2
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	display.bind_match(state)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(display.shown.home == 5, "real match phase holds board through an actionable pitch")
	state.phase = MatchState.Phase.PLAY_DEAD
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		display.shown.home == 7 and state.home_team.runs == 7 and state.inning == 3,
		"read-only match binding updates between plays without changing score"
	)
	display.bind_match(null)
	display.present({"inning": 3, "home": 5, "away": 2}, false)


func _score_visibility(display: StadiumScoreboardDisplay) -> void:
	display.present({"inning": 9999, "home": 9999, "away": 9999}, false)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	var director: MatchCameraDirector = MatchCameraDirector.new()
	for side in [-1, 1]:
		director.set_batter_handedness(side < 0)
		var camera: Vector3 = director._desired_transform(Vector3.ZERO, 0).origin
		for label: Label3D in display._labels.values():
			var bounds: AABB = label.get_aabb()
			for index in range(8):
				var target: Vector3 = label.global_transform * bounds.get_endpoint(index)
				var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
					camera, target, 1
				)
				_check(
					get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),
					"actual four-digit font bounds clear the back wall from both batting cameras"
				)
	display.present({"inning": 3, "home": 5, "away": 2}, false)
	await get_tree().process_frame


func _visible_bounds(root: Node3D) -> AABB:
	var result: AABB
	var first: bool = true
	for node: VisualInstance3D in root.find_children("*", "VisualInstance3D", true, false):
		var box: AABB = (
			root.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		)
		result = box if first else result.merge(box)
		first = false
	return result


func _terminal_scoreboard(model: Node3D) -> void:
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	var contacts: Array[bool] = []
	ball.body_entered.connect(
		func(body: Node) -> void:
			if model.is_ancestor_of(body):
				contacts.append(resolver.state.dead)
				StadiumSurfaceRules.apply(
					resolver,
					body.get_meta("surface_role", ""),
					"purchase:ST-039:0",
					ball.global_position
				)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(-20, 4.4, 20)
	launch.velocity = Vector3(0, 0, 20)
	ball.launch(launch)
	var previous: Vector3 = launch.position
	for frame in range(120):
		await get_tree().physics_frame
		StadiumBoundaryObserver.observe(resolver, previous, ball.global_position)
		previous = ball.global_position
		if not contacts.is_empty():
			break
	_check(
		not contacts.is_empty() and contacts[0],
		"actual ball reaches scoreboard only after clearing the terminal back boundary"
	)
	_check(
		_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.HOME_RUN,
		"after-terminal scoreboard rebound cannot create another result"
	)
	ball.queue_free()
	await get_tree().physics_frame


func _capture_displays(property: Node3D, objects: Dictionary) -> void:
	if _capture_dir.is_empty():
		return
	_check(DisplayServer.get_name() != "headless", "display review needs native rendering")
	if DisplayServer.get_name() == "headless":
		return
	get_window().size = Vector2i(1280, 720)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("13251e")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5ddca")
	environment.environment.ambient_light_energy = 0.55
	property.add_child(environment)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 0.75
	property.add_child(light)
	var camera: Camera3D = Camera3D.new()
	property.add_child(camera)
	camera.make_current()
	var label: Label = Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 25)
	property.add_child(label)
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for item: String in objects:
		var object: Node3D = objects[item]
		var target: Vector3 = object.position + Vector3(0, 2.1 if item == "ST-039" else 1.1, 0)
		camera.position = target + (Vector3(2, 1.2, -5) if item == "ST-039" else Vector3(3, 1.0, 4))
		camera.look_at(target)
		label.text = "CLUB DISPLAY • " + StadiumCatalog.item(item).name
		await _capture_one(item)


func _capture_one(item: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check(
		(
			get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(item + ".png"))
			== OK
		),
		"native display image saved"
	)


func _check(ok: bool, message: String) -> void:
	if _flag_only:
		_flag_checks += 1
	super._check(ok, message)


func _flag_contract() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var quote: Dictionary = StadiumFlagItems.quote(
		stock, "ST-043", 2, "flag-model", {"seasons": 2, "wins": 5}
	)
	_check(
		quote.ok and quote.blueprint_cost == 190 and quote.copy_cost == 110,
		"explicit synthetic authoring receipt buys one flag blueprint and two copies"
	)
	if not quote.ok:
		await _flag_finish()
		return
	stock = StadiumStock.from_data(quote.state)
	var layout: Dictionary = StadiumFlagItems.upgrade(
		StadiumStarterLayout.empty(),
		StadiumSurfaceProgression.initial(StadiumSurfaceProgression.LEGACY_ORIGIN)
	)
	layout.flags = [
		{"copy": "purchase:flag-model:0", "site": "FLAG-GROUND-L"},
		{"copy": "purchase:flag-model:1", "site": "FLAG-GROUND-R"}
	]
	var checked: Dictionary = StadiumFlagItems.validate(layout, stock, "backyard")
	_check(
		checked.ok and StadiumFlagItems.validate_rows(layout.flags, stock, "backyard").ok,
		"two exact flag copies validate at their own outside-play sites"
	)
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	var built: bool = checked.ok and property.build("backyard", layout, stock)
	_check(built, "ordinary property builder installs the closed flag layout")
	if not built:
		property.free()
		await _flag_finish()
		return
	_check(
		(
			property.get_meta("property_signature") == StadiumFlagItems.geometry("backyard", layout)
			and property.route_obstacles().is_empty()
		),
		"installed property binds flag geometry without adding outside-play flags to live routes"
	)
	await get_tree().process_frame
	await get_tree().process_frame
	var issued: Array[WeakRef] = []
	for index in range(2):
		var copy: String = "purchase:flag-model:%d" % index
		var model: StadiumFlagModels = property.objects.get(copy) as StadiumFlagModels
		_check(
			(
				model != null
				and model.get_script() == StadiumFlagModels
				and model.get_meta("stadium_item") == "ST-043"
				and model.get_meta("owned_copy") == copy
				and model.position == Vector3(-12 if index == 0 else 12, 0, -8)
				and model.rotation == Vector3.ZERO
			),
			"each authored flag is the exact owned model at its fixed handed site"
		)
		if model == null:
			property.free()
			await _flag_finish()
			return
		_flag_models += 1
		issued.append(weakref(model))
		_check(
			StadiumFlagModels.ENVELOPE.grow(0.001).encloses(_visible_bounds(model)),
			"actual flag geometry and native font bounds fit the complete motion envelope"
		)
		var pole: MeshInstance3D = model.get_node("Visual/Pole")
		var pole_shape: CylinderShape3D = model.get_node("Collision/Pole").get_child(0).shape
		_check(
			(
				pole.mesh is CylinderMesh
				and pole.mesh.height == 3.5
				and pole.mesh.top_radius == PackedFloat32Array([0.04])[0]
				and pole.mesh.bottom_radius == PackedFloat32Array([0.04])[0]
				and pole_shape.height == 3.5
				and pole_shape.radius == PackedFloat32Array([0.04])[0]
			),
			"native pole mesh and cylinder retain their authored dimensions"
		)
		var decorative: bool = model.get_node("Collision").get_child_count() == 2
		for body: Node in model.get_node("Collision").get_children():
			decorative = (
				decorative
				and body is StaticBody3D
				and body.get_meta("owned_copy") == copy
				and body.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"
				and body.get_meta("ball_surface") == &"stadium_scenery"
				and not body.has_meta("wall_cap_height")
			)
		_check(
			decorative,
			"flag footing and pole remain decorative without foul-pole scoring authority"
		)
		_check(
			(
				model._cloth_mesh.size == Vector2(1, 0.65)
				and model._cloth_mesh.subdivide_width == 16
				and model._cloth_mesh.subdivide_depth == 2
				and model._cloth.position == Vector3(0.58, 2.925, 0)
				and (
					model._cloth.custom_aabb
					== AABB(Vector3(-0.5, -0.325, -0.06), Vector3(1, 0.65, 0.12))
				)
				and model._cloth_shader.code == StadiumFlagModels.CLOTH_SHADER
				and model._intact()
			),
			"noncolliding cloth has a pinned edge and the bounded authored shader envelope"
		)
		var brand: Label3D = model.get_node("Visual/ClubBrand")
		_check(
			brand.text == "YARD CLUB\nWIFFALTRO" and brand.position.z > StadiumFlagModels.WAVE_M,
			"current club branding stays readable in front of the entire cloth sweep"
		)
		var state: MatchState = MatchState.new()
		# Detached real lab exercises the production binding predicates without a game/startup.
		var lab: PitchBatLab = PitchBatLab.new()
		lab._match_state = state
		lab._pitch_actor = PitchFlightActor.new()
		lab.add_child(lab._pitch_actor)
		lab.set_meta("stadium_property", property)
		model.bind_match(state, lab)
		model._process(0.1)
		var phase: float = model._phase
		_check(
			(
				phase > 0
				and phase < TAU
				and model._cloth_material.get_shader_parameter("wave_phase") == phase
			),
			"read-only between-play driver advances its slow bounded cloth phase"
		)
		state.phase = MatchState.Phase.PITCH_IN_FLIGHT
		model._process(0.1)
		_check(
			(
				model._phase == phase
				and model._cloth_material.get_shader_parameter("wave_phase") == phase
			),
			"actionable pitch holds the exact cloth phase"
		)
		state.phase = MatchState.Phase.BALL_IN_PLAY
		model._process(0.1)
		_check(model._phase == phase, "live batted play also holds the cloth")
		state.phase = MatchState.Phase.PLAY_DEAD
		model._process(0.1)
		_check(
			(
				model._phase > phase
				and state.inning == 1
				and state.outs == 0
				and state.phase == MatchState.Phase.PLAY_DEAD
			),
			"dead-ball cloth resumes without changing match state"
		)
		phase = model._phase
		model._process(NAN)
		var held_invalid_delta: bool = model._phase == phase
		var issued_flag: Dictionary = {}
		for captured_copy: String in property.objects:
			var captured_model: Node3D = property.objects[captured_copy]
			if captured_model.get_meta("stadium_item") == "ST-043":
				issued_flag[captured_copy] = {
					"node": captured_model,
					"pose": captured_model.transform,
					"site": captured_model.get_meta("site")
				}
		var captured_attachment: bool = StadiumPropertyRuntime._issued_flags_intact(
			lab, state, property, issued_flag
		)
		lab._match_state = MatchState.new()
		model._process(0.1)
		var held_replaced_state: bool = (
			model._phase == phase
			and not StadiumPropertyRuntime._issued_flags_intact(lab, state, property, issued_flag)
		)
		lab._match_state = state
		lab.remove_meta("stadium_property")
		model._process(0.1)
		var held_missing_property: bool = (
			model._phase == phase
			and not StadiumPropertyRuntime._issued_flags_intact(
				lab, state, property, issued_flag, true
			)
		)
		var foreign_property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		lab.set_meta("stadium_property", foreign_property)
		model._process(0.1)
		var held_replaced_property: bool = (
			model._phase == phase
			and not StadiumPropertyRuntime._issued_flags_intact(lab, state, property, issued_flag)
		)
		lab.set_meta("stadium_property", property)
		foreign_property.free()
		var foreign_model: Node3D = Node3D.new()
		property.objects[copy] = foreign_model
		model._process(0.1)
		var held_replaced_model: bool = (
			model._phase == phase
			and not StadiumPropertyRuntime._issued_flags_intact(lab, state, property, issued_flag)
		)
		property.objects[copy] = model
		foreign_model.free()
		var attachment: Dictionary = {
			"host": self,
			"host_parent": get_parent(),
			"host_pose": transform,
			"host_world": global_transform,
			"property_pose": property.transform,
			"attached": true
		}
		var property_pose: Transform3D = property.transform
		property.position.x += 1
		model._process(0.1)
		var held_property_pose: bool = (
			model._phase == phase
			and not StadiumPropertyRuntime._issued_flags_intact(
				lab, state, property, issued_flag, true, attachment
			)
		)
		property.transform = property_pose
		var foreign_host: Node3D = Node3D.new()
		add_child(foreign_host)
		property.reparent(foreign_host)
		model._process(0.1)
		var held_property_host: bool = (
			model._phase == phase
			and not StadiumPropertyRuntime._issued_flags_intact(
				lab, state, property, issued_flag, true, attachment
			)
		)
		property.reparent(self)
		property.transform = property_pose
		foreign_host.free()
		_check(
			(
				captured_attachment
				and held_invalid_delta
				and held_replaced_state
				and held_missing_property
				and held_replaced_property
				and held_replaced_model
				and held_property_pose
				and held_property_host
				and lab._match_state == state
				and lab.get_meta("stadium_property") == property
			),
			(
				"invalid delta and missing/replaced captured lab state/property refuse without "
				+ "presentation writes"
			)
		)
		var original: ShaderMaterial = model._cloth_material
		var foreign: ShaderMaterial = original.duplicate(true)
		model._cloth.material_override = foreign
		model._process(0.1)
		var held_material: bool = (
			model._phase == phase
			and foreign.get_shader_parameter("wave_phase") == phase
			and model._cloth.material_override == foreign
		)
		model._cloth.material_override = original
		var cloth_size: Vector2 = model._cloth_mesh.size
		model._cloth_mesh.size = Vector2(2, 2)
		model._process(0.1)
		var held_size: bool = model._phase == phase
		model._cloth_mesh.size = cloth_size
		var cloth_pose: Transform3D = model._cloth.transform
		model._cloth.position.x += 1
		model._process(0.1)
		var held_cloth_pose: bool = model._phase == phase
		model._cloth.transform = cloth_pose
		var cloth_box: AABB = model._cloth.custom_aabb
		model._cloth.custom_aabb = AABB(Vector3.ZERO, Vector3.ONE)
		model._process(0.1)
		var held_box: bool = model._phase == phase
		model._cloth.custom_aabb = cloth_box
		var model_pose: Transform3D = model.transform
		model.position.x += 1
		model._process(0.1)
		var held_model_pose: bool = model._phase == phase
		model.transform = model_pose
		_check(
			(
				held_material
				and held_size
				and held_cloth_pose
				and held_box
				and held_model_pose
				and model._intact()
			),
			"foreign material and in-place cloth/root geometry changes refuse without presentation writes"
		)
		model.bind_match(null)
		model._process(0.1)
		_check(
			model._phase == phase and model._intact(),
			"unbinding stops presentation with original resource values intact"
		)
		lab.free()
	property.free()
	await get_tree().process_frame
	_check(
		issued.size() == 2 and issued[0].get_ref() == null and issued[1].get_ref() == null,
		"both exact property-owned flag models are disposed"
	)
	await _flag_finish()


func _flag_finish() -> void:
	print(
		(
			"STADIUM_CLUB_FLAG_MODEL checks=%d failures=%d models=%d games=0 synthetic_history=true"
			% [_flag_checks, _failures, _flag_models]
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

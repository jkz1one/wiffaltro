extends Node

var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PitchBatLabSettings.path = "user://feedback-settings-test-%d.cfg" % OS.get_process_id()
	_test_cadence()
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._record_export.path = "user://feedback-test-%d.json" % OS.get_process_id()
	lab._match_state.top_half = false
	lab._awaiting_batter_confirm = false
	lab._apply_defensive_assignment()
	lab._apply_role_camera()
	lab._refresh_config()
	await _test_ui(lab)
	_test_pitcher_boundaries(lab)
	var path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(PitchBatLabSettings.path)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro playtest feedback checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_cadence() -> void:
	var shortest: float = INF
	var longest: float = 0.0
	for cadence_seed in range(100):
		var cadence: AtBatCadenceController = AtBatCadenceController.new()
		cadence.begin_delivery(cadence_seed)
		var replay: AtBatCadenceController = AtBatCadenceController.new()
		replay.begin_delivery(cadence_seed)
		_check(cadence.active_delivery_seconds == replay.active_delivery_seconds,
			"cadence must remain reproducible from its seed")
		shortest = minf(shortest, cadence.active_set_seconds)
		longest = maxf(longest, cadence.active_set_seconds)
		_check(cadence.active_windup_seconds >= cadence.MIN_DELIVERY_SECONDS
			and cadence.active_windup_seconds <= cadence.MAX_DELIVERY_SECONDS,
			"quiet setup variation must preserve smooth windup bounds")
		_check(cadence.advance(cadence.active_set_seconds * 0.5) == cadence.Event.NONE
			and cadence.delivery_progress() == 0.0 and cadence.delivery_cue() == "PITCHER SET",
			"quiet set must hold the pose and never release the pitch")
		cadence.advance(cadence.active_set_seconds * 0.5 + cadence.active_windup_seconds * 0.5)
		_check(is_equal_approx(cadence.delivery_progress(), 0.5),
			"windup must interpolate independently of setup length")
	_check(longest - shortest > 0.8, "seeded pre-windup holds need perceptible variety")


func _test_ui(lab: PitchBatLab) -> void:
	var picker: PitchPicker = lab._pitch_picker
	_check(picker.visible, "pitch selection must be visible on defense")
	_check(not "STA" in lab._scorebug._pitcher.text,
		"defensive scorebox must hand condition information to pitch panel")
	_check(is_equal_approx(picker._stamina.value,
		lab._match_state.pitcher().stamina_percent() * 100.0), "pitch panel stamina must agree")
	picker._buttons[1].pressed.emit()
	_check(lab._selected_pitch_index == 1 and picker._buttons[1].button_pressed,
		"pitch button must select the actual repertoire entry")
	PitchBatLabFeelSupport.begin_pitch_release(lab)
	picker._select(0)
	_check(lab._selected_pitch_index == 1, "selection must lock during delivery")
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	var release: InputEventKey = InputEventKey.new()
	release.keycode = KEY_SPACE
	release.pressed = false
	lab._input(release)
	_check(not lab._release_controller.active, "GUI-handled releases must cancel paused delivery")
	lab._toggle_display_menu()
	_check(lab._pause_menu.visible and lab._display_menu_panel.visible and get_tree().paused,
		"settings must be nested inside frozen pause")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(lab._pause_menu.get_global_rect()),
		"settings controls must fit the paused viewport")
	lab._toggle_sky_backdrop()
	lab._cycle_hud_anchor()
	lab._sky_backdrop_enabled = true
	lab._hud_anchor_index = 0
	PitchBatLabSettings.restore(lab)
	_check(not lab._sky_backdrop_enabled and lab._hud_anchor_index == 1,
		"display preferences must survive a settings reload")
	_check(lab._world_environment.environment.background_mode == Environment.BG_COLOR
		and lab._world_environment.environment.background_color.g
		> lab._world_environment.environment.background_color.b, "alternate backdrop must be green")
	lab._toggle_sky_backdrop()
	PitchBatLabFeelSupport.toggle_debug_pause(lab)
	_check(not lab._display_menu_open and not lab._pause_menu.visible,
		"resume must dismiss settings and pause together")
	for anchor in range(3):
		lab._hud_anchor_index = anchor
		PitchBatLabPresentation.apply_hud_anchor(lab)
		lab._refresh_config()
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not picker.get_global_rect().intersects(lab._scorebug.get_global_rect()),
			"pitch panel must clear every scorebox position")
		_check(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(picker.get_global_rect()),
			"pitch panel must fit the game viewport")
		for button in picker._buttons:
			if button.visible:
				_check(picker.get_global_rect().encloses(button.get_global_rect()),
					"all available pitches must fit inside the panel")
	var geometry: StarterFieldLabGeometry = lab.get_node("StarterFieldGeometry")
	var zone: MeshInstance3D = geometry.get_node("ZoneLeft")
	geometry.set_batting_view(false)
	_check(zone.material_override.albedo_color.a == 1.0, "pitching zone must remain unchanged")
	geometry.set_batting_view(true)
	_check(zone.material_override.albedo_color.a < 0.5, "batting zone must be less obstructive")
	lab._match_state.top_half = true
	lab._refresh_config()
	_check(not picker.visible, "pitch selector must hide while batting")


func _test_pitcher_boundaries(lab: PitchBatLab) -> void:
	lab._match_mode = false
	lab.set_process(false)
	lab.set_physics_process(false)
	for scenario in ["crossing", "double", "stopped", "far"]:
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 0.04, lab._field_definition.safe_hit_z_m + 0.2)
		launch.velocity = Vector3(0, 0, 1)
		lab._start_ball_in_play(launch)
		lab._batted_ball.freeze = true
		var state: BallPlayState = lab._ball_play_resolver.state
		state.has_grounded = scenario != "airborne"
		state.elapsed_seconds = 0.3
		if scenario in ["airborne", "far"]:
			lab._batted_ball.position = Vector3(0, 0.04, 9 if scenario == "airborne" else 4)
			PitchBatLabDefenseSupport.advance_pitcher(lab, 0.5)
			_check(lab._pitcher_marker.position == lab.MOUND_ORIGIN,
				"pitcher must not charge airborne or distant balls")
		else:
			var resolved: Array[BallPlayOutcome] = []
			lab._ball_play_resolver.play_resolved.connect(
				func(outcome: BallPlayOutcome) -> void: resolved.append(outcome), CONNECT_ONE_SHOT)
			lab._pitcher_marker.position = Vector3(0, 0, launch.position.z)
			if scenario == "double":
				state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
			elif scenario == "stopped":
				lab._batted_ball.linear_velocity = Vector3.ZERO
			PitchBatLabDefenseSupport.try_pitcher(lab,
				Vector3(0, 0.04, lab._field_definition.safe_hit_z_m - 0.2), launch.position)
			_check(state.dead and state.result_floor >= BallPlayState.ResultFloor.SINGLE,
				"remote control must preserve the crossing floor in the same frame")
			_check(resolved.size() == 1, "remote control must resolve once")
			if resolved.size() == 1:
				var expected: BallPlayOutcome.Result = BallPlayOutcome.Result.DOUBLE if (
					scenario == "double") else BallPlayOutcome.Result.SINGLE
				_check(resolved[0].result == expected, "remote/stopped control must preserve safe floor")
		lab._cleanup_batted_ball()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

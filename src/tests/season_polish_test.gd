extends Node

var _failures: int = 0
var _save_path: String
var _settings_path: String


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_path = "user://season-polish-%d.json" % OS.get_process_id()
	_settings_path = "user://season-polish-%d.cfg" % OS.get_process_id()
	SeasonSave.path = _save_path
	PitchBatLabSettings.path = _settings_path
	await _test_settings_and_navigation()
	await _test_save_retry()
	await _test_match_pause_and_ai()
	await _test_release_over_ui()
	_test_camera_inspection()
	for path in [_save_path, _settings_path]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix):
				DirAccess.remove_absolute(path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro season polish checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _test_settings_and_navigation() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.menu.show_settings()
	await _frames(3)
	var settings: GameSettingsPanel = app.menu._body.get_child(0)
	settings.anchor_button.pressed.emit()
	settings.backdrop_button.pressed.emit()
	settings.volume_slider.value = 35
	settings.mute_button.pressed.emit()
	var values: Dictionary = PitchBatLabSettings.read_values()
	_check(
		values.anchor == 1 and not values.sky and values.muted and values.volume == 0.35,
		"home settings persist the full selection"
	)
	# A failed replacement must leave the previous readable file intact.
	PitchBatLabSettings.path = "user://missing-polish-directory/settings.cfg"
	settings.volume_slider.value = 50
	_check(
		settings._status.visible and settings._retry.visible,
		"failed settings writes expose a retry action"
	)
	PitchBatLabSettings.path = _settings_path
	_check(
		PitchBatLabSettings.read_values().volume == 0.35,
		"failed settings write does not destroy the previous settings"
	)
	settings._retry.pressed.emit()
	_check(
		PitchBatLabSettings.read_values().volume == 0.5 and not settings._retry.visible,
		"settings retry saves the current selection and clears feedback"
	)
	app.menu._unhandled_input(_cancel())
	_check(app.menu.page == "home", "Escape returns from settings")
	app.menu.show_controls()
	await _frames(3)
	_check(app.menu._body.get_child_count() >= 8, "home controls guide is populated")
	app.menu._unhandled_input(_cancel())
	_check(app.menu.page == "home", "Escape returns from controls")
	app.begin_season(55)
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
	app.menu.show_lineup()
	app.menu._unhandled_input(_cancel())
	_check(app.menu.page == "hub", "Escape returns from lineup to the season")
	var size_before: Vector2i = get_window().size
	var scale_before: Vector2i = get_window().content_scale_size
	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 768)]:
		get_window().size = viewport_size
		get_window().content_scale_size = viewport_size
		app.menu.show_hub()
		await _frames(4)
		var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(viewport_size))
		for button: Control in app.menu._footer.get_children():
			_check(bounds.encloses(button.get_global_rect()), "footer actions stay in viewport")
	get_window().size = size_before
	get_window().content_scale_size = scale_before
	app.play_exhibition()
	_check(
		app.lab._hud_anchor_index == 1 and not app.lab._sky_backdrop_enabled,
		"a new match uses home display settings"
	)
	_check(
		app.lab._sounds.muted and app.lab._sounds.volume == 0.5,
		"a new match uses home mute and volume settings"
	)
	app.leave_game()
	app.queue_free()
	await _frames(2)
	# Invalid individual settings are sanitized without discarding other valid values.
	var config: ConfigFile = ConfigFile.new()
	config.set_value("audio", "volume", "loud")
	config.set_value("audio", "muted", true)
	config.set_value("display", "scorebox_anchor", 99)
	config.save(_settings_path)
	values = PitchBatLabSettings.read_values()
	_check(
		values.volume == 1.0 and values.muted and values.anchor == 2,
		"malformed or out-of-range setting values recover safely"
	)
	PitchBatLabSettings.write_values({"anchor": 0, "sky": true, "muted": false, "volume": 1.0})


func _test_save_retry() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.begin_season(81)
	for pick in range(4):
		app.choose_player(app.season.offers()[0])
	app.play_season_game()
	var state: MatchState = app.lab._match_state
	state.away_team.runs = 2
	state.home_team.runs = 4
	state.phase = MatchState.Phase.GAME_END
	SeasonSave.path = "user://missing-polish-directory/season.json"
	_check(app._commit_result(), "final result records even while storage is unavailable")
	var results: int = app.season.player_results.size()
	app._commit_result()
	_check(
		app.save_pending and results == 1 and app.season.player_results.size() == 1,
		"failed checkpoint does not duplicate final results"
	)
	app.lab._match_presentation_director.mode = MatchPresentationDirector.Mode.OUTRO_HOLD
	app.finish_game()
	_check(
		app.lab == null and app.menu.page == "postgame" and app.save_pending,
		"postgame remains usable after save failure"
	)
	var retries: Array[Node] = app.menu._layout.find_children("*", "Button", true, false)
	_check(
		retries.any(func(button: Button) -> bool: return button.text == "RETRY SAVING SEASON"),
		"postgame offers an explicit retry"
	)
	app.ask_quit()
	_check(app._dialog.visible, "unsaved changes require an explicit quit decision")
	app._dialog.hide()
	SeasonSave.path = _save_path
	app.retry_save()
	var restored: SeasonState = SeasonSave.restore()
	_check(
		not app.save_pending and app.notice.is_empty() and app.menu.page == "postgame",
		"successful retry clears warning without losing the current page"
	)
	_check(
		restored != null and restored.player_results.size() == 1,
		"retry preserves the final score exactly once"
	)
	app.queue_free()
	await _frames(2)


func _test_match_pause_and_ai() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._player_home = true
	lab._record_export.path = "user://season-polish-record-%d.json" % OS.get_process_id()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabFeelSupport.begin_pitch_release(lab)
	_check(lab._release_controller.active, "focus-loss fixture has an uncommitted pitch")
	lab.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(
		lab._debug_paused and not lab._release_controller.active,
		"losing app focus pauses and cancels an uncommitted pitch"
	)
	var elapsed: float = lab._match_state.elapsed_seconds
	await _frames(5)
	lab.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(
		lab._debug_paused and lab._match_state.elapsed_seconds == elapsed,
		"returning focus waits for deliberate resume"
	)
	lab._pause_menu.open_controls()
	await _frames(3)
	_check(
		lab._pause_menu._controls.visible and not lab._pause_menu._main.visible,
		"paused controls replace the main menu without resuming"
	)
	_check(
		Rect2(0, 0, 1280, 720).encloses(lab._pause_menu.get_global_rect()),
		"paused controls fit the viewport"
	)
	PitchBatLabInput.handle(lab, _cancel())
	_check(
		lab._debug_paused and not lab._pause_menu._controls.visible,
		"Escape closes controls before resuming"
	)
	var start: InputEventJoypadButton = InputEventJoypadButton.new()
	start.button_index = JOY_BUTTON_START
	start.pressed = true
	PitchBatLabInput.handle(lab, start)
	_check(
		not lab._debug_paused and lab._throw_number == 0,
		"controller Start resumes without committing the canceled pitch"
	)
	PitchBatLabFeelSupport.begin_pitch_release(lab)
	PitchBatLabInput.handle(lab, start)
	lab.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(
		lab._debug_paused and not lab._release_controller.active,
		"focus loss also cancels a held delivery when already paused"
	)
	lab._toggle_display_menu()
	lab._pause_menu.settings.volume_slider.value = 0
	PitchBatLabInput.handle(lab, start)
	lab._sounds.play(&"contact")
	_check(
		lab._sounds.last_cue == &"" and lab._sounds.volume == 0.0,
		"zero volume stops sounds without requiring the mute toggle"
	)
	# Effective handedness drives the opponent's pull-side defense.
	lab._player_home = false
	var batter: PlayerMatchState = lab._match_state.batter()
	batter.definition = ContentDB.get_player(&"player.tess_vale")
	for appearance in range(1, 25):
		lab._match_state.plate_appearance_number = appearance
		batter.batting_hand_override = 0
		MatchLabSupport.assign_ai_fielder_anchor(lab)
		var right: int = lab._fielder_anchor_index
		batter.batting_hand_override = 1
		MatchLabSupport.assign_ai_fielder_anchor(lab)
		var left: int = lab._fielder_anchor_index
		_check(
			right / 3 == left / 3 and right % 3 + left % 3 == 2,
			"AI defense mirrors its pull side using the selected batting hand"
		)
	lab._awaiting_batter_confirm = true
	lab._match_state.between_batters = true
	var roster: MatchRosterControls = lab.find_child("RosterControls", true, false)
	roster._switch_side()
	_check(
		lab._primary_fielder.anchor_position.is_equal_approx(
			lab._field_definition.fielder_anchor(lab._fielder_anchor_index)
		),
		"switching sides updates the actual fielder anchor before delivery"
	)
	var record_path: String = lab._record_export.path
	lab.queue_free()
	await _frames(2)
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(record_path)


func _test_release_over_ui() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab._record_export.path = "user://season-polish-release-%d.json" % OS.get_process_id()
	lab._player_home = true
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	await _frames(2)
	var point: Vector2 = lab._camera.unproject_position(Vector3(0, 1.05, 0))
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	get_viewport().push_input(press, true)
	_check(lab._release_controller.active, "pointer starts a delivery outside the HUD")
	lab._release_controller.advance(PitchReleaseController.IDEAL_RELEASE_SECONDS)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = lab._display_menu_button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = release.position
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion, true)
	get_viewport().push_input(release, true)
	_check(
		not lab._release_controller.active and lab._throw_number == 1,
		"release over HUD commits once at the player's chosen time"
	)
	_check(
		is_zero_approx(lab._last_release_offset_seconds) and not lab._debug_paused,
		"HUD cannot turn a timed release into a late automatic pitch or pause"
	)
	var record_path: String = lab._record_export.path
	lab.queue_free()
	await _frames(2)
	if FileAccess.file_exists(record_path):
		DirAccess.remove_absolute(record_path)


func _test_camera_inspection() -> void:
	for defense in [false, true]:
		var camera: Camera3D = Camera3D.new()
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(camera)
		var director: MatchCameraDirector = MatchCameraDirector.new()
		director.set_shot(
			MatchCameraDirector.Shot.PITCHING if defense else MatchCameraDirector.Shot.BATTING
		)
		director.snap(camera)
		var ball: Vector3 = Vector3(0, 1, 0.28)
		director.prepare_ball_in_play(defense, ball, Vector3(0, 18, 26))
		director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
		ball = Vector3(0, 8, 12)
		director.update(camera, 0.5, true, ball)
		var before: Transform3D = camera.global_transform
		var fov: float = camera.fov
		var velocity: Vector3 = (
			director._live_coverage._velocity if defense else director._batting_coverage._velocity
		)
		director.update(camera, 0.5, true, ball, true)
		_check(camera.global_transform == before, "pause without inspection holds the actual frame")
		director.cycle_paused_view(camera)
		for frame in range(40):
			director.update(camera, 1.0 / 60.0, true, ball, true)
		_check(
			(
				(
					director._live_coverage._velocity
					if defense
					else director._batting_coverage._velocity
				)
				== velocity
			),
			"inspection never feeds stationary samples into live coverage"
		)
		director.restore_after_pause()
		var inspected: Transform3D = camera.global_transform
		_check(
			not inspected.is_equal_approx(before), "inspection fixture actually changed the view"
		)
		director.update(camera, 1.0 / 60.0, false, ball)
		_check(
			not camera.global_transform.is_equal_approx(before), "resolved frame returns smoothly"
		)
		for frame in range(60):
			director.update(camera, 1.0 / 60.0, false, ball)
		_check(
			camera.global_transform.is_equal_approx(before) and is_equal_approx(camera.fov, fov),
			"resume restores the resolved ball frame and lens, then holds them"
		)
		camera.free()


func _cancel() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	return event


func _frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

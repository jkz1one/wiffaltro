extends Node3D
## Timing08 successor: focused presentation contract. No career, scoring callback, physics step or
## save writes.


class HeadlineLab:
	extends PitchBatLab

	func _ready() -> void:
		pass

	func _exit_tree() -> void:
		pass


var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var lab: PitchBatLab
	for count: int in range(4):
		lab = _fixture(count)
		_resolve(
			lab,
			BallPlayOutcome.Result.HOME_RUN,
			"HOME RUN\nEV 80 MPH\n%d run(s) score" % (count + 1)
		)
		var expected: String = "GRAND SLAM" if count == 3 else "HOME RUN"
		_check(
			lab._hr_celebration_label.visible and lab._hr_celebration_label.text == expected,
			"authoritative pre-play runner count %d" % count
		)
		_check(
			lab._hr_celebration_label.get_theme_font_size("font_size") == 88,
			"large 1280-wide headline type"
		)
		_check(
			(
				is_equal_approx(
					lab._hr_celebration_label.position.x + lab._hr_celebration_label.size.x * 0.5,
					lab.get_viewport().get_visible_rect().size.x * 0.5
				)
				and is_equal_approx(lab._hr_celebration_label.position.y, 90.0)
			),
			"headline centered above flight corridor"
		)
		var payload: String = lab._status_label.text
		lab._match_state.bases.clear()
		PitchBatLabPresentation.refresh_event(lab)
		_check(
			lab._hr_celebration_label.text == expected,
			"advancement does not erase captured headline"
		)
		# Explicit elapsed / center alpha / corner alpha expectations, not production formulas.
		for sample: Array in [
			[0.0, 0.0, 0.0],
			[0.05, 0.15625, 0.104],
			[0.1, 0.5, 0.352],
			[0.2, 1.0, 0.896],
			[0.25, 1.0, 1.0],
			[1.4, 1.0, 1.0],
			[1.65, 0.5, 1.0],
			[1.9, 0.0, 1.0],
			[3.8, 0.0, 1.0],
			[4.1, 0.0, 0.5],
			[4.4, 0.0, 0.0],
			[5.0, 0.0, 0.0]
		]:
			var elapsed: float = sample[0]
			lab._home_run.elapsed = elapsed
			PitchBatLabPresentation.refresh_event(lab)
			_check(
				lab._hr_celebration_label.visible == (elapsed < 1.9),
				"center lifetime at %s" % elapsed
			)
			if elapsed < 1.9:
				_check(
					is_equal_approx(lab._hr_celebration_label.modulate.a, sample[1]),
					"center eased fade / hold alpha"
				)
			_check(lab._event_panel.visible == (elapsed < 4.4), "longer compact notice lifetime")
			_check(
				is_equal_approx(lab._event_panel.modulate.a, sample[2]),
				"corner eased fade / hold alpha"
			)
			_check(lab._status_label.text == payload, "full status payload unchanged")
		_dispose(lab)

	for elapsed: float in [0.1, 1.0, 1.65]:
		lab = _fixture(3)
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN\n4 run(s) score")
		lab._home_run.elapsed = elapsed
		PitchBatLabPresentation.refresh_event(lab)
		lab._home_run.cancel()
		_check(
			not lab._hr_celebration_label.visible and lab._hr_celebration_label.text.is_empty(),
			"cancel immediately clears the headline at %s" % elapsed
		)
		PitchBatLabPresentation.refresh_event(lab)
		_check(
			not lab._hr_celebration_label.visible,
			"old compact payload cannot revive canceled headline"
		)
		_dispose(lab)

	for mutation: String in ["play", "match", "ball", "camera", "status", "empty", "hidden"]:
		lab = _fixture(3)
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN\n4 run(s) score")
		lab._home_run.elapsed = 1.65
		PitchBatLabPresentation.refresh_event(lab)
		_check(
			(
				lab._hr_celebration_label.visible
				and is_equal_approx(lab._hr_celebration_label.modulate.a, 0.5)
			),
			"stale-transition setup starts during visible fade-out"
		)
		match mutation:
			"play":
				lab._ball_play_resolver.state = BallPlayState.new()
			"match":
				lab._match_state = MatchState.new()
			"ball":
				lab._batted_ball = null
			"camera":
				lab._camera_director = MatchCameraDirector.new()
			"status":
				lab._status_label.text = "DOUBLE\n4 run(s) score"
			"empty":
				lab._status_label.text = ""
			"hidden":
				lab._automation = MatchAutomation.new()
				lab._automation.presentation_enabled = false
		PitchBatLabPresentation.refresh_event(lab)
		_check(
			not lab._hr_celebration_label.visible and lab._hr_celebration_label.text.is_empty(),
			"stale or unavailable presentation clears headline: " + mutation
		)
		_dispose(lab)

	for elapsed: float in [0.1, 1.65, 4.1]:
		lab = _fixture(3)
		_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN\n4 run(s) score")
		lab._home_run.elapsed = elapsed
		PitchBatLabPresentation.refresh_event(lab)
		_resolve(lab, BallPlayOutcome.Result.DOUBLE, "DOUBLE\n4 run(s) score")
		_check(
			lab._event_panel.visible and is_equal_approx(lab._event_panel.modulate.a, 1.0),
			"ordinary status restores full opacity after HR fade at %s" % elapsed
		)
		_check(
			not lab._hr_celebration_label.visible and lab._hr_celebration_label.text.is_empty(),
			"ordinary result cannot inherit celebration label"
		)
		_dispose(lab)

	for payload: String in ["DOUBLE\n4 run(s) score", "HOME RUN\n4 run(s) score"]:
		lab = _fixture(3)
		_resolve(lab, BallPlayOutcome.Result.DOUBLE, payload)
		_check(
			not lab._hr_celebration_label.visible and lab._home_run.celebration_text.is_empty(),
			"non-HR never celebrates despite four-run or stale HR status"
		)
		_dispose(lab)

	lab = _fixture(3)
	lab._match_state.bases.clear()
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	_check(
		lab._hr_celebration_label.text == "HOME RUN", "match bases override diagnostic loaded bases"
	)
	_dispose(lab)
	lab = _fixture(0)
	lab._match_mode = false
	lab._base_state.set_debug_preset(2)
	_resolve(lab, BallPlayOutcome.Result.HOME_RUN, "HOME RUN")
	_check(
		lab._hr_celebration_label.text == "GRAND SLAM",
		"diagnostic mode uses diagnostic pre-play bases"
	)
	_dispose(lab)
	print("HR_CELEBRATION08 checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(runners: int) -> PitchBatLab:
	var lab: PitchBatLab = HeadlineLab.new()
	lab.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(lab)
	lab._match_state = MatchState.new()
	if runners > 0:
		lab._match_state.bases.first = &"runner.first"
	if runners > 1:
		lab._match_state.bases.second = &"runner.second"
	if runners > 2:
		lab._match_state.bases.third = &"runner.third"
	# Deliberately different diagnostic state proves authoritative match-mode selection.
	lab._base_state.set_debug_preset(2)
	lab._camera_director = MatchCameraDirector.new()
	lab._ball_play_resolver = BallPlayResolver.new()
	lab._ball_play_resolver.state = BallPlayState.new()
	lab._ball_play_resolver.state.dead = true
	lab._ball_play_resolver.state.result_floor = BallPlayState.ResultFloor.HOME_RUN
	var canvas: CanvasLayer = CanvasLayer.new()
	lab.add_child(canvas)
	PitchBatLabPresentation._build_event_panel(lab, canvas)
	lab._batted_ball = BattedBallBody.new()
	lab._batted_ball.freeze = true
	lab.add_child(lab._batted_ball)
	lab._batted_ball.surface_contact.connect(lab._on_batted_surface_contact)
	return lab


func _resolve(lab: PitchBatLab, result: BallPlayOutcome.Result, payload: String) -> void:
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = result
	lab._home_run.resolve_ball(lab, outcome)
	lab._status_label.text = payload
	PitchBatLabPresentation.refresh_event(lab)


func _dispose(lab: PitchBatLab) -> void:
	lab._home_run.cancel()
	lab.free()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("HR_CELEBRATION08: " + message)

extends Node

var _failures: int = 0


func _ready() -> void:
	for defender in [&"pitcher", &"primary_fielder"]:
		for grounded in [false, true]:
			for strikes in [0, 2]:
				await _short_bobble(defender, grounded, strikes)
	for grounded in [false, true]:
		for outs in [0, 2]:
			await _control(grounded, outs)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro bobble and tag rules checks passed.")
	get_tree().quit(0 if _failures == 0 else 1)


func _make_lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._record_export.path = "user://bobble-rules-%d.json" % OS.get_process_id()
	lab._match_state.bases.third = &"runner.third"
	return lab


func _short_bobble(defender: StringName, grounded: bool, strikes: int) -> void:
	var lab: PitchBatLab = _make_lab()
	lab._match_state.strikes = strikes
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 0.4, lab._field_definition.safe_hit_z_m - 0.01)
	launch.velocity = Vector3(0, 0, 20)
	lab._start_ball_in_play(launch)
	if grounded:
		lab._ball_play_resolver.record_ground_contact(Vector3(0, 0.04, 3))
	lab._apply_fielding_outcome(defender, launch.position, FieldingResolver.Outcome.BOBBLE)
	_check(lab._ball_play_resolver.state.dead and lab._batted_ball.linear_velocity == Vector3.ZERO,
		"short bobble must end the play and stop the ball without a deflection")
	await get_tree().process_frame
	_check(lab._batted_ball.freeze, "short bobble must apply the deferred physics freeze")
	_check(lab._match_state.strikes == mini(strikes + 1, 2), "bobble foul uses normal foul count")
	_check(lab._match_state.outs == 0 and lab._match_state.plate_appearance_number == 1,
		"bobble foul cannot add an Out or finish the plate appearance")
	_check(lab._match_state.bases.third == &"runner.third"
		and lab._match_state.batting_team().runs == 0, "bobble foul cannot advance or score runners")
	_check(lab._pitch_feedback.text.contains("FOUL")
		and not lab._pitch_feedback.text.contains("still live"), "bobble feedback must say foul")
	await _dispose(lab)


func _control(grounded: bool, outs: int) -> void:
	var lab: PitchBatLab = _make_lab()
	lab._match_state.outs = outs
	lab._primary_fielder.fielding_rating = 6
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	# A deep catch permits third-to-home; a short moving grounder is an Out
	# under the existing ghost-runner baseline and does not invoke tag-up.
	launch.position = Vector3(0, 0.4, 8.0 if grounded else 22.0)
	launch.velocity = Vector3(0, 0, 8)
	lab._start_ball_in_play(launch)
	if grounded:
		lab._ball_play_resolver.record_ground_contact(Vector3(0, 0.04, 3))
	lab._apply_fielding_outcome(&"primary_fielder", launch.position, FieldingResolver.Outcome.CLEAN)
	var expected_runs: int = 1 if not grounded and outs < 2 else 0
	_check(lab._match_state.away_team.runs == expected_runs,
		"only caught air ball before the third Out may score a tag-up runner")
	if grounded and outs == 0:
		_check(lab._match_state.bases.third == &"runner.third", "ordinary ground Out holds runners")
	await _dispose(lab)


func _dispose(lab: PitchBatLab) -> void:
	var path: String = lab._record_export.path
	lab.queue_free()
	await get_tree().process_frame
	DirAccess.remove_absolute(path)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

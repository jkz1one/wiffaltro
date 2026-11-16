extends Node
## Paired real games compare every report field, not merely the score.

var _failures: int = 0
var _report: Dictionary = {}
var _error: String = ""


func _ready() -> void:
	var season: SeasonState = SeasonState.create(42, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.finished.connect(func(report: Dictionary) -> void: _report = report)
	runner.failed.connect(func(reason: String) -> void: _error = reason)
	for sample in range(2):
		if sample == 1:
			for team: TeamMatchState in [source.away_team, source.home_team]:
				team.current_pitcher().stamina_remaining = team.current_pitcher().stamina_max * 0.1
				for player: PlayerMatchState in team.roster:
					player.definition = SeasonGearCatalog.equip(player.definition, {
						"bat": {"item": "BAT-CON-01"}, "ball": {"item": "BALL-HYB-01"},
						"misc": {"item": "MISC-PIT-03"}})
		var field: StringName = PitchBatLab.FIELD_ID if sample == 0 else SeasonState.AWAY_FIELD_ID
		var seed: int = 29 if sample == 0 else 47
		var baseline: Dictionary = await _play(runner, source, seed, field, true)
		var lean: Dictionary = await _play(runner, source, seed, field, false)
		_check(not baseline.is_empty() and ClubCareer.same(baseline, lean),
			"all events, elapsed time, stats, recipes and workload agree across presentation modes")
		_check(source.phase == MatchState.Phase.PRE_PITCH and source.away_team.runs == 0
			and source.home_team.runs == 0, "paired jobs leave their input untouched")
	runner.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical equivalence checks passed: four games, two exact paired reports.")
	get_tree().quit(0 if _failures == 0 else 1)


func _play(runner: PhysicalMatchRunner, source: MatchState, seed: int,
	field: StringName, presented: bool) -> Dictionary:
	_report = {}
	_error = ""
	runner.presentation_enabled = presented
	var time_scale: float = Engine.time_scale
	var tick_rate: int = Engine.physics_ticks_per_second
	var started: int = Time.get_ticks_msec()
	_check(runner.start(source, seed, field), "paired job starts")
	var lab: PitchBatLab = runner._lab
	runner.presentation_enabled = not presented
	_check(lab._automation.presentation_enabled == presented, "job snapshots diagnostic mode at start")
	var traced: bool = false
	for frame in range(150000):
		await get_tree().physics_frame
		if not runner._running:
			break
		traced = traced or not lab._trajectory_points.is_empty()
		if not presented:
			_check(lab._trajectory_points.is_empty()
				and lab._trajectory_draw.mesh.get_surface_count() == 0
				and lab._contact_vector_draw.mesh.get_surface_count() == 0
				and lab._ball_visibility._history.is_empty(), "offscreen job builds no dynamic trace meshes")
	_check(not runner._running and _error.is_empty() and PhysicalMatchReport.valid(_report),
		"paired physical job completes with valid evidence: " + _error)
	_check(Engine.time_scale == time_scale and Engine.physics_ticks_per_second == tick_rate,
		"presentation mode never changes global time or physics ticks")
	_check(traced == presented, "diagnostic mode retains actual pitch traces")
	print("PHYSICAL_EQ seed=", seed, " presented=", presented, " wall_ms=",
		Time.get_ticks_msec() - started, " pitches=", _report.get("releases", []).size())
	await get_tree().process_frame
	return _report.duplicate(true)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

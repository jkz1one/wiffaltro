extends Node

var _failures: int = 0
var _reports: Array[Dictionary] = []
var _errors: Array[String] = []
var _capture_dir: String = ""
var _report_dir: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
		if argument.begins_with("--physical-report-dir="):
			_report_dir = argument.trim_prefix("--physical-report-dir=")
	var season: SeasonState = SeasonState.create(42, false, true, true)
	for pick in range(4):
		season.choose_player(season.offers()[0])
	SeasonSave.path = "user://physical-runner-%d.json" % OS.get_process_id()
	_check(SeasonSave.save(season), "ordinary season saves before detached jobs")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var opponents: Dictionary = season.opponents.to_data()
	var state: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	state.away_team.field_supply.receipt = "field-supply:fixture29:away"
	state.gear_usage.equipped = ["historical:paid-gear"]
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	runner.finished.connect(_record_report)
	runner.failed.connect(func(reason: String) -> void: _errors.append(reason))
	_memory_isolation()
	_rejected_requests(runner, state)
	_check(runner.start(state, 29), "fresh detached AI fixture starts")
	_check(not runner.start(state, 47), "active job cannot be overwritten")
	_check(runner._viewport.find_world_3d() != get_viewport().find_world_3d(),
		"Jolt world is isolated from the user's scene")
	_check(runner._lab._match_state != state
		and runner._lab._match_state.away_team.roster[0].definition
		!= state.away_team.roster[0].definition,
		"match and authored player resources are copied")
	var played: MatchState = runner._lab._match_state
	_check(played.away_team.field_supply.receipt == state.away_team.field_supply.receipt,
		"attempt-only receipt identity survives snapshot construction")
	var lab: PitchBatLab = runner._lab
	var target: Vector2 = lab._pitch_target
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	PitchBatLabInput.handle(lab, key)
	Input.action_press(&"pitch_aim_left")
	await get_tree().process_frame
	Input.action_release(&"pitch_aim_left")
	_check(lab._pitch_target == target and lab._throw_number in [29000, 29001],
		"global held aim and restart input cannot steer a detached job")
	get_tree().paused = true
	var elapsed: float = lab._match_state.elapsed_seconds
	for frame in range(4):
		await get_tree().process_frame
	_check(lab._match_state.elapsed_seconds == elapsed, "tree pause freezes job and children")
	get_tree().paused = false
	await _complete(runner, 1)
	_check(_reports.size() == 1 and _errors.is_empty(), "first AI physical match completes once")
	_check(played.gear_usage.first_pitch == state.gear_usage.equipped
		and not state.gear_usage.started, "first actual release retains historical paid identities")
	if _reports.size() == 1:
		_audit(_reports[0])
		_tamper(_reports[0])
	_check(state.phase == MatchState.Phase.PRE_PITCH and state.sure_shot.releases.is_empty()
		and state.away_team.runs == 0 and state.home_team.runs == 0,
		"caller match remains fresh after complete job")
	# Stress carried fatigue: actual boundary substitution, no arbitrary workload reset.
	state.home_team.current_pitcher().stamina_remaining = (
		0.10 * state.home_team.current_pitcher().stamina_max)
	state.away_team.current_pitcher().stamina_remaining = (
		0.10 * state.away_team.current_pitcher().stamina_max)
	for team: TeamMatchState in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			player.definition = SeasonGearCatalog.equip(player.definition, {
				"bat": {"item": "BAT-CON-01"}, "ball": {"item": "BALL-HYB-01"},
				"misc": {"item": "MISC-PIT-03"}})
	_check(runner.start(state, 47, SeasonState.AWAY_FIELD_ID), "runner reuses after completed cleanup")
	await _complete(runner, 2)
	_check(_reports.size() == 2 and _errors.is_empty(), "equipped away-field physical match completes")
	if _reports.size() == 2:
		_audit(_reports[1])
		for index in range(2):
			var original: TeamMatchState = state.away_team if index == 0 else state.home_team
			var id: String = String(original.current_pitcher().definition.id)
			_check(_reports[1].teams[index].pitching.releases[0].player != id,
				"both clubs replace exhausted starters only at the legal pre-PA boundary")
	_check(runner.start(state, 67), "third job can start")
	runner.cancel()
	await get_tree().process_frame
	_check(_reports.size() == 2 and _errors.is_empty() and runner.get_child_count() == 0,
		"cancel discards unfinished result and frees world without success or failure")
	_check(runner.start(state, 67), "runner reuses after cancellation")
	# Force a progress failure through the actual guard, never make up a result.
	runner._progress = "%d:%d:%d" % [runner._lab._match_state.phase,
		runner._lab._match_state.plate_appearance_number, runner._lab._throw_number]
	runner._stalled = PhysicalMatchRunner.STALL_SECONDS
	await get_tree().process_frame
	_check(_reports.size() == 2 and _errors.size() == 1 and runner._lab == null,
		"progress guard reports failure and retains no partial result")
	runner.queue_free()
	await get_tree().process_frame
	_check(FileAccess.get_file_as_string(SeasonSave.path) == bytes
		and season.opponents.to_data() == opponents and SeasonSave.restore() != null,
		"completion, cancellation and failure preserve saved bytes and all club ledgers")
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro physical AI runner checks passed: two complete detached games and evidence.")
	get_tree().quit(0 if _failures == 0 else 1)


func _complete(runner: PhysicalMatchRunner, count: int) -> void:
	var captured: Array = []
	for frame in range(150000):
		await get_tree().physics_frame
		if not runner._running:
			break
		var state: MatchState = runner._lab._match_state
		if (not _capture_dir.is_empty() and state.phase == MatchState.Phase.BALL_IN_PLAY
			and not captured.has(state.top_half)):
			captured.append(state.top_half)
			await _capture_play(runner, count)
	_check(not runner._running, "AI game finishes within bounded simulation frames")
	await get_tree().process_frame
	_check(runner.get_child_count() == 0, "finished job releases all viewport children")
	if _reports.size() == count:
		print("PHYSICAL_AI seed=", _reports[-1].seed, " score=", _reports[-1].away_runs,
			":", _reports[-1].home_runs, " pitches=", _reports[-1].releases.size(),
			" simulated_seconds=", _reports[-1].elapsed)


func _audit(report: Dictionary) -> void:
	_check(PhysicalMatchReport.valid(report), "live evidence validates")
	var decoded: Variant = JSON.parse_string(JSON.stringify(report, "", true, true))
	_check(PhysicalMatchReport.valid(decoded) and ClubCareer.same(report, decoded),
		"report survives JSON round-trip with exact evidence")
	for team: Dictionary in report.teams:
		var reads: int = 0
		var contacts: int = 0
		for play: Dictionary in report.plays:
			if team.roster.has(play.batter):
				reads += 1 if play.read else 0
				contacts += 1 if play.exit_speed > 0.0 else 0
		_check(reads > 0 and contacts > 0, "both offenses use bounded reads and physical contact")
		for id: String in team.roster:
			var work: Dictionary = team.workload[id]
			_check(is_equal_approx(work.remaining, maxf(0.0, work.initial - work.paid)),
				"uneventful fixtures retain exactly their actual paid workload")


func _tamper(report: Dictionary) -> void:
	for field: String in ["version", "seed", "away_runs", "home_runs"]:
		var changed: Dictionary = report.duplicate(true)
		changed[field] = -1
		_check(not PhysicalMatchReport.valid(changed), "reject invalid report field: " + field)
	for patch: Dictionary in [{"player": "foreign"}, {"recipe": "unknown"},
		{"paid": -0.1}, {"pa": 0}, {"half": 9999}, {"extra": true}]:
		var changed: Dictionary = report.duplicate(true)
		changed.releases[0].merge(patch, true)
		_check(not PhysicalMatchReport.valid(changed), "reject altered release evidence")
	var changed: Dictionary = report.duplicate(true)
	changed.releases = JSON.parse_string(JSON.stringify(changed.releases))
	changed.releases[0] = 12
	_check(not PhysicalMatchReport.valid(changed), "reject malformed release without runtime errors")
	changed = report.duplicate(true)
	changed.teams[0].stances[0].pa += 1
	_check(not PhysicalMatchReport.valid(changed), "reject missing/duplicate appearance")
	changed = report.duplicate(true)
	var id: String = changed.teams[0].roster[0]
	changed.teams[0].batting[id][0] = (
		"out" if changed.teams[0].batting[id][0] == "walk" else "walk")
	_check(not PhysicalMatchReport.valid(changed), "batting outcomes must reconcile with statistics")
	changed = report.duplicate(true)
	changed.teams[0].workload[changed.teams[0].roster[0]].paid += 10.0
	_check(not PhysicalMatchReport.valid(changed), "aggregate cost must match paid releases")
	changed = report.duplicate(true)
	changed.plays[0].batter = report.teams[1].roster[0]
	_check(not PhysicalMatchReport.valid(changed), "physical play must belong to committed appearance")


func _rejected_requests(runner: PhysicalMatchRunner, state: MatchState) -> void:
	_check(not runner.start(null, 1) and not runner.start(state, -1)
		and not runner.start(state, 1, &"missing.field"), "invalid start is side-effect free")
	var invalid: MatchState = PhysicalMatchRequest.capture(state)
	invalid.record_ball()
	_check(not runner.start(invalid, 1), "partially played match cannot be resubmitted as fresh")
	invalid = PhysicalMatchRequest.capture(state)
	invalid.home_team.roster[0].definition.id = invalid.away_team.roster[0].definition.id
	_check(not runner.start(invalid, 1), "overlapping player identities cannot merge statistics")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _record_report(report: Dictionary) -> void:
	_reports.append(report)
	if _report_dir.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(_report_dir)
	var file: FileAccess = FileAccess.open(
		_report_dir.path_join("physical-ai-%d.json" % int(report.seed)), FileAccess.WRITE)
	_check(file != null, "verification report can be written")
	if file != null:
		file.store_string(JSON.stringify(report, "", true, true))
		file.close()


func _capture_play(runner: PhysicalMatchRunner, count: int) -> void:
	var viewport: SubViewport = runner._viewport
	var half: String = "away" if runner._lab._match_state.top_half else "home"
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	var path: String = _capture_dir.path_join("physical-ai-%d-%s.png" % [count, half])
	_check(viewport.get_texture().get_image().save_png(path) == OK, "real AI field capture")
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _memory_isolation() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = MatchState.new()
	lab._automation = MatchAutomation.new()
	lab._automation.approaches = [BatterApproachModel.new(), BatterApproachModel.new()]
	lab._automation.select_offense(lab)
	var away: BatterApproachModel = lab._batter_approach
	away.recent_locations.append(2)
	away.previous_speed = 30.0
	lab._match_state.top_half = false
	lab._automation.select_offense(lab)
	_check(lab._batter_approach != away and lab._batter_approach.recent_locations.is_empty(),
		"one club cannot inherit the other club's pitch observations")
	lab._match_state.top_half = true
	lab._automation.select_offense(lab)
	lab._batter_approach.begin_plate_appearance(10)
	_check(lab._batter_approach == away and away.recent_locations == [2]
		and away.previous_speed == 30.0, "lineup observations survive its own intervening defense")
	lab.free()

extends "res://src/tests/stadium_mounted_scoreboard_season_test.gd"
## Actual normal human-home game, original outro, pending checkpoint and once-only settlement.


const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var _native: NativeCapture


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	SeasonSave.path = "user://mounted-scoreboard-visible-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://mounted-scoreboard-visible-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_prepare_season()
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	var fixture: Dictionary = _app.season.pending_fixture()
	_check(fixture.away == 0, "real scheduled away round precedes the first mounted home")
	var report: Dictionary = await _human_report(_app.season, fixture)
	if report.is_empty():
		get_tree().quit(1)
		return
	_app.round_ui.begin([fixture.id, report.away_runs, report.home_runs,
		report.performance, [], [], {}, [], [], {}, {}, [], _opponent_row(report, fixture), [], ""])
	await _wait_round()
	_audit_season()
	fixture = _app.season.pending_fixture()
	_check(fixture.home == 0 and _app.season.player_results.size() == 1,
		"actual physical away round earns the next normal human-home fixture")
	var held: Dictionary = SeasonSave.snapshot(_app.season)
	var state: MatchState = _app.season.make_match()
	_fixture_guards(state, fixture)
	_check(ClubCareer.same(held, SeasonSave.snapshot(_app.season)),
		"wrong fixture, seed and entry-only startup cannot change paid season state")
	_prior_results = 1
	_check(await _native.resize(Vector2i(700, 400)), "actual small managed window is acknowledged")
	_app.play_season_game()
	_check(_app.lab != null and _app.lab._stadium_ledger != null
		and _app.lab._match_state.stadium.get("version") == 15,
		"ordinary Play supplies paid proof before actual managed home startup")
	if _app.lab == null:
		get_tree().quit(1)
		return
	_check(_app._played_field_matches(), "normal managed field matches exact scheduled fixture15")
	await _capture("mounted-managed-home-small")
	await _play_owned()
	await _wait_round()
	_check(_app._result_saved and _app.season.player_results.size() == 2
		and _app.season.physical.reports.size() == 4,
		"actual human home plus two ordinary opponent jobs settle together exactly once")
	_audit_season()
	var settled: Dictionary = SeasonSave.snapshot(_app.season)
	var balance: int = _app.season.career.balance()
	_app.finish_game()
	_check(SeasonSave.save(_app.season) and SeasonSave.save(_app.season)
		and ClubCareer.same(settled, SeasonSave.snapshot(_app.season))
		and balance == _app.season.career.balance(),
		"repeated Continue and persistence cannot duplicate the actual human reward")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(settled, SeasonSave.snapshot(restored)),
		"normal managed result and paid mounted home reopen with exact evidence")
	_check(await _native.resize(Vector2i(1280, 720)), "actual normal managed window restores")
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	_check(_native._failures == 0, "native managed capture handshake remains valid")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard visible passed: actual human home and atomic settlement.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture_guards(source: MatchState, fixture: Dictionary) -> void:
	_app._fixture_id = int(fixture.id)
	for change: String in ["seed", "fixture", "entry", "role", "exhibition"]:
		var bad: MatchState = PhysicalMatchRequest.capture(source)
		var player_home: bool = true
		var season_game: bool = true
		match change:
			"seed": bad.stadium.environment.seed += 1
			"fixture": bad.stadium.environment.fixture += 1
			"entry": bad.stadium = _app.season.home_property.duplicate(true)
			"role": player_home = false
			"exhibition": season_game = false
		_app._open_match(bad, player_home, season_game)
		_check(_app.lab == null, "normal season preflight rejects wrong mounted " + change)


func _check_outro_and_restart(lab: PitchBatLab) -> void:
	await get_tree().process_frame
	var state: MatchState = lab._match_state
	var fixture: Dictionary = _app.season.pending_fixture()
	var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(_app.season, fixture)
	_check(state.phase == MatchState.Phase.GAME_END and not lab._play_records.is_empty()
		and StadiumBoundaryRuntime.installed(lab, expected) and _app._played_field_matches(),
		"actual human physics finishes on the exact paid mounted world")
	var property: StadiumScoreboardPropertyGeometry = lab.get_meta("stadium_property")
	var display: StadiumScoreboardTierDisplay = property.board_display(
		expected.layout.scoreboards[0].copy)
	_check(display._match == state and display.shown.away == state.away_team.runs
		and display.shown.home == state.home_team.runs,
		"real final score automatically reaches the mounted board before settlement")
	_scoreboard.home_games += 1
	_scoreboard.played[int(fixture.id)] = {"property": StadiumLayoutSnapshot.key(expected),
		"away_runs": state.away_team.runs, "home_runs": state.home_team.runs,
		"performance": state.performance.snapshot(state)}
	var proof: ClubAssetLedger = lab._stadium_ledger
	lab._stadium_ledger = null
	_check(not _app._played_field_matches(), "human settlement refuses a missing retained proof")
	lab._stadium_ledger = proof
	await _capture("mounted-managed-final-small")
	await _ordinary_outro(lab)
	_check(not is_instance_valid(lab) or lab._stadium_ledger == null,
		"normal Continue retires the retained paid proof")


func _capture(label: String) -> void:
	_check(await _native.capture(_capture_dir, label), "managed mounted capture uses actual pixels")


func _ordinary_outro(lab: PitchBatLab) -> void:
	# This fixture requires the ordinary season outro, not a purchased Recovery scenario.
	var state: MatchState = lab._match_state
	var fixture: Dictionary = _app.season.pending_fixture()
	var opponent: TeamMatchState = state.away_team if fixture.home == 0 else state.home_team
	_check(PhysicalTacticalEvidence.human_matches(_app.season, fixture,
		SeasonOpponentTactics.evidence(state, opponent), state.performance.snapshot(state)),
		"actual managed opponent evidence binds its pregame ownership and policy")
	for frame in range(780):
		await get_tree().physics_frame
		if lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD:
			break
	_check(lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD,
		"real human fixture finishes its celebration and outro")
	var score: String = lab._match_state.score_label()
	_check(_app._result_recorded,
		"game end automatically queues evidence without granting a partial round")
	_check(_app.lab == lab and not _app.round_ui._working
		and not _app.round_ui.shade.visible
		and _app.season.player_results.size() == _prior_results,
		"completed game stays on its original outro until Continue")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and restored.physical.pending.human[0] == _app._fixture_id,
		"completed actual human evidence survives closing at the outro")
	_check(lab._match_state.score_label() == score, "checkpoint preserves final score")
	_app.finish_game()
	_check(_app.lab == null and _app.round_ui._working, "Continue begins required physical jobs")


func _wait_round() -> void:
	# Native software rendering needs wall time; game physics and evidence stay unchanged.
	var native: bool = DisplayServer.get_name() != "headless"
	var limit_ms: int = 1800000 if native else 300000
	var started: int = Time.get_ticks_msec()
	while _app.round_ui._working and Time.get_ticks_msec() - started < limit_ms:
		await get_tree().process_frame
	var elapsed_ms: int = Time.get_ticks_msec() - started
	print("MOUNTED_VISIBLE_ROUND native=", native, " elapsed_ms=", elapsed_ms,
		" limit_ms=", limit_ms, " settled=", _app.season.physical.pending.is_empty())
	_check(_app.season.physical.pending.is_empty(), "whole round finishes within benchmark window")

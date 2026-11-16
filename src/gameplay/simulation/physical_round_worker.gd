class_name PhysicalRoundWorker
extends Node
## Child entry point: reconstruct one pending fixture, run every physics step, return evidence.

var _token: String = ""
var _folder: String = ""
var _key: String = ""
var _fixture: int = -1
var _runner: PhysicalMatchRunner
var _poll: int = 0
var _finished: bool = false


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--physical-job="):
			_token = argument.trim_prefix("--physical-job=")
	_folder = PhysicalJobFiles.directory(_token)
	if _folder.is_empty():
		get_tree().quit(1)
		return
	PitchBatLabSettings.path = _folder.path_join("worker-settings.cfg")
	var input: Variant = PhysicalJobFiles.read(_folder.path_join("request.json"))
	var season: SeasonState = PhysicalRoundProcess.decode_request(input, _token)
	if season == null:
		_fail("Physical job checkpoint is invalid.")
		return
	_key = input.request
	_fixture = int(input.fixture)
	var projection: Dictionary = SeasonRoundSettlement.project(season)
	if (
		not projection.has("fixture")
		or projection.fixture.id != _fixture
		or SeasonPhysicalFixtures.request_key(projection.candidate, projection.fixture) != _key
	):
		_fail("Physical job no longer matches its committed fixture.")
		return
	var field: FieldDefinition = SeasonState.field_for_fixture(
		projection.fixture, projection.candidate
	)
	if field == null:
		_fail("The saved away venue assignment is invalid.")
		return
	_runner = PhysicalMatchRunner.new()
	add_child(_runner)
	_runner.finished.connect(_complete)
	_runner.failed.connect(_fail)
	if not _runner.start(
		SeasonPhysicalFixtures.match_for(projection.candidate, projection.fixture),
		SeasonPhysicalFixtures.seed_for(projection.candidate, projection.fixture),
		field.id,
		(
			(load("res://src/gameplay/season/dynasty_shared_time_runtime.gd").projected_ledger(season, projection.candidate, projection.fixture)
			if projection.candidate._league_home_context.get("format") in [95, 96] else StadiumSurfaceNightSnapshot.ledger(projection.candidate))
			if (StadiumSurfaceNightSnapshot.expected(projection.candidate, projection.fixture))
			else (
				(load("res://src/gameplay/season/dynasty_shared_time_runtime.gd").projected_ledger(
					season, projection.candidate, projection.fixture)
				if projection.candidate._league_home_context.get("format") in [95, 96] else
				load("res://src/gameplay/season/dynasty_league_home_runtime.gd").projected_ledger(
					season, projection.candidate, projection.fixture)
				if projection.candidate._league_home_context.get("format") in [91, 92] else
				load("res://src/gameplay/season/dynasty_standard_runtime.gd").projected_ledger(
					season, projection.candidate, projection.fixture)
					if not projection.candidate._standard_live_context.is_empty()
					else ClubPlayers.assets(projection.candidate.career))
				if (
					StadiumLowWallSnapshot.is_family(
						(
							SeasonPhysicalFixtures
							. match_for(projection.candidate, projection.fixture)
							. stadium
						)
					)
					or StadiumWaterfallAnimationSnapshot.is_family(
						(
							SeasonPhysicalFixtures
							. match_for(projection.candidate, projection.fixture)
							. stadium
						)
					)
				)
				else null
			)
		),
		{},
		projection.candidate
	):
		_fail("Physical job could not start.")


func _process(_delta: float) -> void:
	if _finished or _folder.is_empty() or Time.get_ticks_msec() - _poll < 500:
		return
	_poll = Time.get_ticks_msec()
	var heartbeat: String = _folder.path_join("heartbeat.json")
	if (
		not FileAccess.file_exists(heartbeat)
		or Time.get_unix_time_from_system() - (FileAccess.get_modified_time(heartbeat)) > 30
	):
		_fail("Physical job owner disconnected.")
		return
	if _runner != null and _runner._lab != null:
		var state: MatchState = _runner._lab._match_state
		PhysicalJobFiles.write(
			_folder.path_join("status.json"),
			{
				"token": _token,
				"inning": state.inning,
				"top": state.top_half,
				"away": state.away_team.runs,
				"home": state.home_team.runs
			}
		)


func _complete(report: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var ok: bool = PhysicalJobFiles.write(
		_folder.path_join("response.json"),
		{"version": 1, "token": _token, "request": _key, "fixture": _fixture, "report": report}
	)
	await _drain()
	get_tree().quit(0 if ok else 1)


func _fail(reason: String) -> void:
	if _finished:
		return
	_finished = true
	if _runner != null:
		_runner.cancel()
	PhysicalJobFiles.write(_folder.path_join("response.json"), {"error": reason})
	await _drain()
	get_tree().quit(1)


func _drain() -> void:
	# The independent headless process may outrun the audio mixer; retire voices on exit.
	await get_tree().process_frame
	OS.delay_msec(50)
	await get_tree().process_frame
	OS.delay_msec(50)
	await get_tree().process_frame

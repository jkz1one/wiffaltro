extends "res://src/tests/dynasty_league_home_physical_probe.gd"
## Prepared only until an exact reviewed source is qualified. No automatic profile refresh.
## Fresh owner: genuine away round0, then genuine modern home3 saved pending. Never skip games.
const Runtime = preload("res://src/gameplay/season/dynasty_league_home_runtime.gd")
var initial_owner: Dictionary = {}
var frozen_home: Dictionary = {}


func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--modern-home-run"):
		print("MODERN_HOME_PREPARED source_qualified=", StadiumNpcPublicRuntime.source_qualified(),
			" physical_games=0 owner_writes=0; explicit --modern-home-run and fresh --league-home-physical-root required")
		get_tree().quit()
		return
	# This precedes directory creation, synthetic setup, owner writes and any game.
	if not _require(StadiumNpcPublicRuntime.source_qualified(), "exact independently reviewed whole-source profile") \
		or not _require(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
			and not get_tree().paused and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics",
			"unchanged 60Hz Jolt and ordinary clock"):
		get_tree().quit(2)
		return
	var user_root: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT")
	if not _require(not user_root.is_empty() and user_root.is_absolute_path()
		and user_root == user_root.simplify_path() and OS.get_environment("XDG_DATA_HOME") == user_root
		and OS.get_user_data_dir().begins_with(user_root + "/"),
		"fresh launcher data directory inherited by normal AI workers"):
		get_tree().quit(2)
		return
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--fixed-fps"):
			_require(false, "fixed-fps clock overrides are forbidden")
			get_tree().quit(2)
			return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--league-home-physical-root="):
			var root: String = arg.trim_prefix("--league-home-physical-root=")
			if not root.is_absolute_path() or root != root.simplify_path() or DirAccess.dir_exists_absolute(root) or FileAccess.file_exists(root):
				push_error("Only a fresh canonical isolated root is permitted")
				get_tree().quit(2)
				return
			PitchBatLabSettings.path = root.path_join("isolated-settings.cfg")
	await super._ready()


func _source() -> SeasonState:
	var source: SeasonState = super._source()
	var prior: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(prior._seed, prior._credits,
		prior._progress, prior._championships).to_data()
	return source


func _play_rounds(app: SeasonApp) -> void:
	if not _require(app.season != null and Bound.modern_origin(app.season.home_property)
		and app.season._dynasty_career_session.league == _expected_league()
		and app.season._dynasty_career_session.tier == 0
		and app.season.player_results.is_empty() and app.season.physical.reports.is_empty()
		and app.season.physical.pending.is_empty(), "fresh admitted modern " + _expected_league() + " Base; no replayed games"):
		return
	initial_owner = Store.inspect(path).owner.duplicate(true)
	frozen_home = app.season.home_property.duplicate(true)
	if not _require(_paid_ledger(app.season) != null and app.round_ui.process_jobs,
		"normal selected-owner ledger and default independent AI worker transport"):
		return
	for ordinal in range(2):
		var fixture: Dictionary = app.season.pending_fixture().duplicate(true)
		if not _require(fixture.id == ordinal * 3 and (fixture.home == 0) == (ordinal == 1)
			and app.season.player_results.size() == ordinal
			and app.season.physical.reports.size() == ordinal * 2
			and app.season.physical.pending.is_empty(), "natural schedule frontier before fixture " + str(fixture.id)):
			return
		_write("before-%d.json" % fixture.id, SeasonSave.snapshot(app.season))
		app.play_season_game()
		await get_tree().process_frame
		if not _require(is_instance_valid(app.lab), "normal main starts fixture " + str(fixture.id) + ": " + app.notice):
			return
		var lab: PitchBatLab = app.lab
		var state: MatchState = lab._match_state
		if not _require(state != null and lab._managed_match, "normal managed MatchState installed"):
			return
		if ordinal == 1:
			var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(app.season, fixture)
			var paid: ClubAssetLedger = _paid_ledger(app.season)
			if not _require(state != null and state.stadium.get("version") == 9
				and ClubCareer.same(state.stadium, expected) and state.stadium.environment.mode == "day"
				and state.stadium.layout.version == 40 and state.stadium.layout.base_version == 12
				and paid != null and lab._stadium_ledger != null
				and ClubCareer.same(lab._stadium_ledger.to_data(), paid.to_data())
				and StadiumLayoutSnapshot.matches(expected, paid)
				and StadiumBoundaryRuntime.installed(lab, expected)
				and ClubCareer.same(lab.get_meta("stadium_snapshot", {}), expected),
				"actual complete modern paid day field and boundary installed through main"):
				return
			_write("home-fixture9.json", expected)
		var previous: String = ""
		var stalled: int = 0
		var finished: bool = false
		for frame in range(300000):
			await get_tree().physics_frame
			if not is_instance_valid(lab) or app.lab != lab or lab._match_state != state:
				_require(false, "managed game changed before durable human capture")
				return
			if not app.season.physical.pending.is_empty():
				finished = state.phase == MatchState.Phase.GAME_END and app._result_recorded
				break
			var progress: String = "%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
			stalled = stalled + 1 if progress == previous else 0
			previous = progress
			if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
				_require(false, "ordinary game exceeded unchanged progress or time bounds")
				return
			if frame % 10000 == 0:
				print("MODERN_HOME_PROGRESS fixture=", fixture.id, " frame=", frame, " score=", state.score_label())
		if not _require(finished and not app.round_ui._working, "one actual human game reaches durable pending"):
			return
		physical_games += 1
		var human: Array = app.season.physical.pending.human
		if not _require(LeagueHomeResult.shape(human, [], false) and human[0] == fixture.id
			and human[1] == state.away_team.runs and human[2] == state.home_team.runs
			and human[-1] == StadiumLayoutSnapshot.key(state.stadium)
			and app.season.physical.pending.reports.is_empty(), "normal composed human result matches exact played field"):
			return
		var pending: Dictionary = SeasonSave.snapshot(app.season)
		var cold: SeasonState = SeasonSave.restore()
		if not _require(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), pending),
			"actual human pending cold replay preserves full checkpoint"):
			return
		_write("human-%d.json" % fixture.id, {"human": human})
		_write("pending-%d.json" % fixture.id, pending)
		if ordinal == 1 and not _complete_home_round():
			var projected: Dictionary = SeasonRoundSettlement.project(cold)
			if not _require(projected.has("fixture") and projected.fixture.id == 4
				and projected.candidate.player_results.size() == 2,
				"played modern home replay requests natural AI fixture4 without running it"):
				return
			var owner: Dictionary = Store.inspect(path).owner
			_require(ClubCareer.same(owner.career.assets, initial_owner.career.assets)
				and ClubCareer.same(owner.dynasty, initial_owner.dynasty)
				and owner.career.settlements.size() == initial_owner.career.settlements.size()
				and ClubCareer.same(app.season.home_property, frozen_home),
				"no shared asset debit settlement Dynasty rewrite or field refresh")
			_require(physical_games == 2 and app.season.physical.reports.size() == 2
				and not app.round_ui.process_runner.running and not app.round_ui.runner._running,
				"two human games and two accepted away-round AI games; home AI not started")
			_write("modern-home-summary.json", {"checks": checks, "failures": failures,
				"human_games": physical_games, "accepted_ai_games": app.season.physical.reports.size(),
				"home_pending": true, "next_fixture": 4, "source_qualified": StadiumNpcPublicRuntime.source_qualified(),
				"engine": Engine.get_version_info(), "owner_path": path, "user_data_dir": OS.get_user_data_dir(),
				"native_visual_qualified": false, "complete_home_round": false, "full_season_qualified": false})
			return
		app.round_ui.resume()
		var published: bool = false
		for frame in range(300000):
			await get_tree().physics_frame
			if app.season.player_results.size() == ordinal + 1 and app.season.physical.pending.is_empty() and not app.round_ui._working:
				published = true
				break
			if not app.round_ui._working and not app.season.physical.pending.is_empty():
				_require(false, "round paused; preserve accepted reports: " + app.round_ui.status.text + " " + SeasonSave.last_error)
				return
		if not _require(published and app.season.physical.reports.size() == (ordinal + 1) * 2,
			"natural round publishes normal human and two AI games atomically"):
			return
		cold = SeasonSave.restore()
		if not _require(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season)),
			"published natural round cold replay exact"):
			return
		_write("published-away-round.json" if ordinal == 0 else "published-home-round.json", SeasonSave.snapshot(app.season))
	_after_rounds(app)


func _require(ok: bool, label: String) -> bool:
	check(ok, label)
	return ok


func _write(name: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(path.get_base_dir().path_join(name), FileAccess.WRITE)
	if file == null:
		_require(false, "evidence open failed: " + name + " error=" + str(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(value, "", true, true))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		_require(false, "evidence write failed: " + name + " error=" + str(error))


func _expected_league() -> String:
	return "dugout"

func _paid_ledger(season: SeasonState) -> ClubAssetLedger:
	return Runtime.paid_ledger(season)

func _complete_home_round() -> bool:
	return false

func _after_rounds(_app: SeasonApp) -> void:
	pass

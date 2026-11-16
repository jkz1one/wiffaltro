extends Node
## Fresh ordinary Choose League93, no synthetic titles or hidden Dynasty owner.
const Bound = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
var checks: int = 0
var failures: int = 0
var physical_games: int = 0
var path: String = ""
var frozen_home: Dictionary = {}
const PROFILE_PATH: String = "res://src/presentation/stadium/stadium_npc_current_source_profile.gd"
var stop_after_human: bool = false
const Journal = preload("res://src/tests/normal_league_proof_journal.gd")
var active_intent: String = ""
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("NORMAL93_PHYSICAL_CHECK ", checks, " ", ok, " ", label)
func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--normal-home-run"):
		print("NORMAL93_PREPARED physical_games=0 save_writes=0")
		get_tree().quit()
		return
	if not _require(StadiumNpcPublicRuntime.source_qualified() and OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") == "1", "independently qualified exact source and launcher execution lease"):
		get_tree().quit(2)
		return
	stop_after_human = OS.get_cmdline_user_args().has("--stop-after-human")
	if not _require(stop_after_human, "fresh proof requires explicit bounded human stop"):
		get_tree().quit(2)
		return
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--league-home-physical-root="): root = arg.trim_prefix("--league-home-physical-root=")
	var data: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT")
	if not _require(root.is_absolute_path() and root == root.simplify_path() and not DirAccess.dir_exists_absolute(root)
		and not FileAccess.file_exists(root) and data == root.get_base_dir().path_join("data") and data.is_absolute_path() and OS.get_environment("XDG_DATA_HOME") == data
		and OS.get_user_data_dir().begins_with(data + "/"), "fresh isolated save and inherited worker data root"):
		get_tree().quit(2)
		return
	for arg: String in OS.get_cmdline_args():
		if arg.begins_with("--fixed-fps"):
			get_tree().quit(2)
			return
	if not _require(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 and not get_tree().paused
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "ordinary60Hz Jolt clock"):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	path = SeasonSave.path
	PitchBatLabSettings.path = root.path_join("isolated-settings.cfg")
	await _run()
	print("NORMAL93_PHYSICAL_RESULT checks=%d failures=%d human_games=%d" % [checks, failures, physical_games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run() -> void:
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	app.child_entered_tree.connect(func(child: Node) -> void:
		if child is PitchBatLab:
			child._automation = MatchAutomation.new()
			child._automation.seed = SeasonPhysicalFixtures.seed_for(app.season, app.season.pending_fixture())
	)
	add_child(app)
	for frame in range(600):
		if not app._loading_boot: break
		await get_tree().process_frame
	if not _require(app.season == null, "genuinely fresh normal main"):
		app.free()
		return
	app.call("_show_main_leagues")
	var choice: Button = _button(app.menu, "dugout", "")
	if not _require(choice != null and not choice.disabled, "initial Dugout choice available"):
		app.free()
		return
	choice.pressed.emit()
	var start: Button = _button(app.menu, "", "START & SAVE SEASON")
	if not _require(start != null and app.menu.page == "league_career_review", "actual owned-home review"):
		app.free()
		return
	start.pressed.emit()
	if not _require(app.season != null and app.season._league_home_context.get("format") == 93, "actual normal Start and Save93"):
		app.free()
		return
	for pick in range(4): app.choose_player(app.season.offers()[0])
	var cold: SeasonState = SeasonSave.restore()
	if _require(cold != null and app.season.picks.size() == 4 and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season)), "four real draft picks and exact cold replay"):
		await _play_rounds(app)
	app.free()
func _button(node: Node, league: String, label: String) -> Button:
	if node is Button and ((not league.is_empty() and node.get_meta("league_choice", "") == league
		and node.get_meta("league_tier", -1) == 0) or (not label.is_empty() and node.text == label)): return node as Button
	for child: Node in node.get_children():
		var found: Button = _button(child, league, label)
		if found != null: return found
	return null

func _play_rounds(app: SeasonApp) -> void:
	if not _require(app.season != null and Bound.modern_origin(app.season.home_property)
		and app.season.league_rules.league == "dugout"
		and app.season.league_rules.tier == 0
		and app.season._league_home_context.get("format") == 93
		and app.season._dynasty_career_session.is_empty() and not SeasonSave.dynasty_owner_bound()
		and app.season.player_results.size() in [0, 1]
		and app.season.physical.reports.size() == app.season.player_results.size() * 2
		and app.season.physical.pending.is_empty(), "fresh admitted modern " + "Dugout" + " Base; no replayed games"):
		return
	frozen_home = app.season.home_property.duplicate(true)
	if not _require(ClubPlayers.assets(app.season.career) != null and app.round_ui.process_jobs,
		"ordinary Career27 ledger and default transport1 workers"):
		return
	for ordinal in range(app.season.player_results.size(), 2):
		var fixture: Dictionary = app.season.pending_fixture().duplicate(true)
		if not _require(fixture.id == ordinal * 3 and (fixture.home == 0) == (ordinal == 1)
			and app.season.player_results.size() == ordinal
			and app.season.physical.reports.size() == ordinal * 2
			and app.season.physical.pending.is_empty(), "natural schedule frontier before fixture " + str(fixture.id)):
			return
		if not _begin_step(app.season, "human", fixture, SeasonPhysicalFixtures.request_key(app.season, fixture)): return
		if not _write("before-%d.json" % fixture.id, SeasonSave.snapshot(app.season)): return
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
			var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
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
			if not _write("home-fixture9.json", expected): return
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
		if not _require(finished and not app.round_ui._working, "one actual human game reaches live pending; durability checked separately"):
			return
		physical_games += 1
		var human: Array = app.season.physical.pending.human
		if not _write("human-%d.json" % fixture.id, {"human": human.duplicate(true), "durable_acceptance": false}): return
		if not _require(LeagueHomeResult.shape(human, [], false) and human[0] == fixture.id
			and human[1] == state.away_team.runs and human[2] == state.home_team.runs
			and human[-1] == StadiumLayoutSnapshot.key(state.stadium)
			and app.season.physical.pending.reports.is_empty(), "normal composed human result matches exact played field"):
			return
		# Genuine completed-game evidence must survive even if save validation fails.
		var pending: Dictionary = SeasonSave.snapshot(app.season)
		if not _write("live-pending-%d.json" % fixture.id, {"snapshot": pending, "save_error": SeasonSave.last_error,
			"continue_text": app._continue.text, "notice": app.notice}): return
		var cold: SeasonState = SeasonSave.restore()
		if not _require(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), pending),
			"actual human pending cold replay preserves full checkpoint"):
			return
		if not _write("accepted-human-%d.json" % fixture.id, {"human": human, "durable_acceptance": true}): return
		if not _write("pending-%d.json" % fixture.id, pending): return
		_boundary(app.season, "human")
		return


func _require(ok: bool, label: String) -> bool:
	check(ok, label)
	return ok


func _write(name: String, value: Dictionary) -> bool:
	return _require(Journal.write_new(path.get_base_dir().path_join(name), value), "immutable verified evidence write: " + name)

func _begin_step(season: SeasonState, kind: String, fixture: Dictionary, request: String) -> bool:
	var root: String = path.get_base_dir()
	var raw: String = ("human-%d.json" if kind == "human" else "raw-ai-%d.json") % int(fixture.id)
	if not _require(kind == "publish" or not FileAccess.file_exists(root.path_join(raw)), "existing raw evidence prohibits another game"): return false
	active_intent = Journal.begin(root, "%s-%d" % [kind, int(fixture.id)], {
		"version": 1, "step": kind, "fixture": int(fixture.id), "request": request,
		"input_save_sha256": FileAccess.get_sha256(SeasonSave.path), "source_profile": FileAccess.get_sha256(PROFILE_PATH),
		"seed": season.season_seed, "home": StadiumLayoutSnapshot.key(season.home_property),
		"results": season.player_results.size(), "reports": season.physical.reports.size(),
		"pending_reports": season.physical.pending.get("reports", []).size()})
	return _require(not active_intent.is_empty(), "durable per-step intent before work; unresolved outcomes refuse")

func _boundary(season: SeasonState, kind: String) -> bool:
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave.restore()
	if not _require(not snapshot.is_empty() and cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "bounded exit has exact durable cold checkpoint"):
		return false
	var receipt: Dictionary = {"version": 1, "kind": kind, "source_profile": FileAccess.get_sha256(PROFILE_PATH),
		"save_sha256": FileAccess.get_sha256(SeasonSave.path), "seed": season.season_seed,
		"home": StadiumLayoutSnapshot.key(season.home_property), "results": season.player_results.size(),
		"reports": season.physical.reports.size(), "pending_reports": season.physical.pending.get("reports", []).size(),
		"pending": not season.physical.pending.is_empty()}
	var name: String = "boundary-%d-%d-%s.json" % [receipt.results, receipt.pending_reports, kind]
	if not _write(name, receipt): return false
	var root: String = path.get_base_dir()
	var next: String = root.path_join("resume-boundary.next.json")
	if not _require(Journal.write_new(next, receipt), "verified new boundary pointer before replacement"): return false
	if not _require(DirAccess.rename_absolute(next, root.path_join("resume-boundary.json")) == OK
		and ClubCareer.same(JSON.parse_string(FileAccess.get_file_as_string(root.path_join("resume-boundary.json"))), receipt), "boundary pointer atomically published and verified"): return false
	return _require(not active_intent.is_empty() and Journal.complete(root, active_intent, name), "intent completed only after exact durable save and receipt")

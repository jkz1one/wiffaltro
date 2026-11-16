extends "res://src/tests/normal_league_home_physical_probe.gd"
## Test-only94 sibling. Original93 runner and Journal remain unchanged.
const TimeProof = preload("res://src/tests/normal_league_time_proof.gd")
const NightResult = preload("res://src/gameplay/season/league_home_night_result.gd")
const TimeHome = preload("res://src/gameplay/season/normal_league_time_candidate.gd")
var operation: String = ""
var authority94: Dictionary = {}
var returned_report: Dictionary = {}
var worker_error: String = ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("NORMAL94_BOUNDED_CHECK ", checks, " ", ok, " ", label)

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--time94-bounded"):
		print("NORMAL94_PREPARED games=0 writes=0")
		get_tree().quit()
		return
	var root: String = ""
	var funding: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--time94-root="): root = arg.trim_prefix("--time94-root=")
		if arg.begins_with("--time94-step="): operation = arg.trim_prefix("--time94-step=")
		if arg.begins_with("--funding-input="): funding = arg.trim_prefix("--funding-input=")
	var data: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT")
	var clock_ok: bool = Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 \
		and not get_tree().paused and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
	for arg: String in OS.get_cmdline_args(): clock_ok = clock_ok and not arg.begins_with("--fixed-fps")
	if not _require(StadiumNpcPublicRuntime.source_qualified() and clock_ok
		and OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") == "1"
		and operation in ["start", "human", "ai", "publish"], "qualified source, unchanged clock, explicit bounded step and global lease"):
		get_tree().quit(2)
		return
	if not _require(root.is_absolute_path() and root == root.simplify_path()
		and data == root.get_base_dir().path_join("data") and OS.get_environment("XDG_DATA_HOME") == data
		and OS.get_user_data_dir().begins_with(data + "/"), "isolated94 save and inherited worker data"):
		get_tree().quit(2)
		return
	if operation == "start":
		if not _require(not DirAccess.dir_exists_absolute(root) and not FileAccess.file_exists(root)
			and TimeHome.ENTRY_ENABLED and funding.is_absolute_path()
			and FileAccess.get_sha256(funding) == TimeProof.FUNDING_SHA,
			"fresh root, separately activated public94 entry and exact retained synthetic paid12 input"):
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(root)
	else:
		if not _require(Journal.ready(root, true) and FileAccess.file_exists(root.path_join("season.json"))
			and not FileAccess.file_exists(root.path_join("season.json.tmp"))
			and not DirAccess.dir_exists_absolute(root.path_join("season.json.tmp"))
			and not FileAccess.file_exists(root.path_join("resume-boundary.next.json"))
			and not FileAccess.file_exists(root.path_join("season.json.dynasty-owner")),
			"completed immutable journal, no uncertain save or foreign owner"):
			get_tree().quit(2)
			return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	path = SeasonSave.path
	PitchBatLabSettings.path = root.path_join("isolated-settings.cfg")
	var cold: SeasonState = null
	if operation != "start":
		var loaded: Variant = Journal._read_json(root.path_join("authority94.json"))
		if not _require(loaded is Dictionary, "immutable94 authority JSON"):
			get_tree().quit(2)
			return
		authority94 = loaded
		cold = SeasonSave.restore()
		if not _receipt_valid(Journal._read_json(root.path_join("resume-boundary.json")), cold):
			get_tree().quit(2)
			return
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
	if operation == "start":
		await _start94(app, funding)
	elif _require(_authority_matches(app.season) and cold != null
		and ClubCareer.same(SeasonSave.snapshot(app.season), SeasonSave.snapshot(cold)),
		"main restores complete receipt-validated94 frontier, full policy, paid home and prior history"):
		await _step94(app)
	app.free()
	print("NORMAL94_BOUNDED_RESULT step=%s checks=%d failures=%d new_human_games=%d" % [operation, checks, failures, physical_games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

func _start94(app: SeasonApp, funding: String) -> void:
	if not _require(app.season == null, "no existing season overwritten by94 entry"): return
	var source: SeasonState = SeasonSave._decode(Journal._read_json(funding))
	if not _require(source != null and source.career != null and source.phase == SeasonState.Phase.COMPLETE
		and TimeHome.supported_home(StadiumLayoutSnapshot.capture(ClubPlayers.assets(source.career))),
		"retained synthetic history supplies paid12 prerequisites only"): return
	app.season = source
	app.call("_show_main_leagues")
	var choice: Button = _button(app.menu, "dugout", "")
	if not _require(choice != null and not choice.disabled, "actual Dugout/Base choice"): return
	choice.pressed.emit()
	var night: Button = _profile_button(app.menu)
	if not _require(night != null and not night.disabled, "actual activated public Night button, no direct profile bypass"): return
	night.pressed.emit()
	await get_tree().process_frame
	var candidate: SeasonState = app.league_career.candidate()
	if not _require(candidate != null and TimeHome.matches(candidate)
		and candidate._league_home_context.header.starting_profile == "night", "actual UI prepared94 Night review"): return
	if not await _screen("entry-review-night.png"): return
	if not _write("prepared94.json", SeasonSave.snapshot(candidate)): return
	authority94 = TimeProof.authority(candidate, FileAccess.get_sha256(PROFILE_PATH),
		FileAccess.get_sha256(path.get_base_dir().path_join("prepared94.json")))
	if not _require(not authority94.is_empty(), "exact immutable94 authority captures prepared input"): return
	if not _write("authority94.json", authority94): return
	active_intent = Journal.begin(path.get_base_dir(), "start-0", {
		"version": 1, "step": "start", "source_profile": authority94.source_profile,
		"funding_sha256": TimeProof.FUNDING_SHA, "authority": authority94.duplicate(true)})
	if not _require(not active_intent.is_empty(), "entry intent precedes durable season publication"): return
	var start: Button = _button(app.menu, "", "START & SAVE SEASON")
	if not _require(start != null and not start.disabled, "actual Start and Save control"): return
	start.pressed.emit()
	if not _require(app.season != source and _authority_matches(app.season), "actual player path commits ordinary94"): return
	for pick in range(4): app.choose_player(app.season.offers()[0])
	if not _require(app.season.picks.size() == 4 and _authority_matches(app.season)
		and app.season.player_results.is_empty() and app.season.physical.reports.is_empty()
		and app.season.physical.pending.is_empty(), "four real draft picks, zero fabricated physical results"): return
	if not _write("drafted94.json", SeasonSave.snapshot(app.season)): return
	if not _require(FileAccess.get_sha256(funding) == TimeProof.FUNDING_SHA, "retained source bytes unchanged"): return
	_boundary(app.season, "start")

func _profile_button(node: Node) -> Button:
	if node is Button and node.get_meta("league_starting_profile", "") == "night": return node as Button
	for child: Node in node.get_children():
		var found: Button = _profile_button(child)
		if found != null: return found
	return null

func _authority_matches(season: SeasonState) -> bool:
	return TimeProof.matches(authority94, season, FileAccess.get_sha256(PROFILE_PATH)) \
		and authority94.prepared_sha256 == FileAccess.get_sha256(path.get_base_dir().path_join("prepared94.json")) \
		and not SeasonSave.dynasty_owner_bound()

func _receipt_valid(receipt: Variant, season: SeasonState) -> bool:
	if not _require(TimeProof.boundary_shape(receipt) and _authority_matches(season), "exact94 receipt and full immutable authority"): return false
	var count: int = season.player_results.size()
	var pending: Dictionary = season.physical.pending
	return _require(receipt.source_profile == FileAccess.get_sha256(PROFILE_PATH)
		and receipt.authority_key == TimeProof.key(authority94)
		and receipt.save_sha256 == FileAccess.get_sha256(path) and receipt.seed == season.season_seed
		and receipt.home == StadiumLayoutSnapshot.key(season.home_property)
		and receipt.policy == TimeProof.key(season.owned_surface_night)
		and receipt.results == count and receipt.reports == count * 2
		and season.physical.reports.size() == count * 2 and receipt.pending == (not pending.is_empty())
		and receipt.pending_reports == pending.get("reports", []).size()
		and count in [0, 1, 2] and (count == 2 or season.pending_fixture().id == count * 3)
		and (pending.is_empty() or (count < 2 and pending.human[0] == count * 3)),
		"exact durable94 natural frontier, policy, source and file identity")

func _step94(app: SeasonApp) -> void:
	var season: SeasonState = app.season
	if not _require(TimeProof.frontier(operation, season.player_results.size(),
		not season.physical.pending.is_empty(), season.physical.pending.get("reports", []).size()),
		"one admissible human/AI/publication step; completed or wrong frontiers refuse"): return
	if operation == "human":
		await _human94(app)
		return
	var projection: Dictionary = SeasonRoundSettlement.project(season)
	if not _require(not projection.has("error"), "genuine retained pending fully validates"): return
	if operation == "publish":
		if not _require(not projection.has("fixture"), "zero-game publication only after both actual AI reports"): return
		if not _begin_step(season, "publish", season.pending_fixture(), "zero-game-publication"): return
		app.round_ui.resume()
		if _require(not app.round_ui._working and app.season.physical.pending.is_empty()
			and _authority_matches(app.season), "existing controller publishes without launching a game"):
			_boundary(app.season, "publish")
		return
	if not _require(projection.has("fixture"), "exact next unaccepted AI fixture"): return
	var fixture: Dictionary = projection.fixture
	var request: String = SeasonPhysicalFixtures.request_key(projection.candidate, fixture)
	if not _begin_step(season, "ai", fixture, request): return
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	add_child(worker)
	worker.finished.connect(func(report: Dictionary) -> void: returned_report = report.duplicate(true))
	worker.failed.connect(func(reason: String) -> void: worker_error = reason)
	if not _require(worker.start(season), "ordinary request1 starts exactly one physical AI fixture"):
		worker.free()
		return
	while worker.running: await get_tree().process_frame
	if not _require(worker_error.is_empty() and not returned_report.is_empty(), "one validated actual AI report: " + worker_error):
		worker.free()
		return
	var row: Dictionary = {"fixture": int(fixture.id), "request": request, "report": returned_report}
	if not _write("raw-ai-%d.json" % fixture.id, row):
		worker.free()
		return
	season.physical.pending.reports.append(row)
	if _require(SeasonSave.save(season), "raw AI report durably checkpoints once: " + SeasonSave.last_error):
		_boundary(season, "ai")
	worker.free()

func _human94(app: SeasonApp) -> void:
	var season: SeasonState = app.season
	var ordinal: int = season.player_results.size()
	var fixture: Dictionary = season.pending_fixture().duplicate(true)
	if not _require(fixture.id == ordinal * 3 and (fixture.home == 0) == (ordinal == 1)
		and app.round_ui.process_jobs and _authority_matches(season), "natural away0/home3, default workers and exact94 authority"): return
	if not _begin_step(season, "human", fixture, SeasonPhysicalFixtures.request_key(season, fixture)): return
	if not _write("before-%d.json" % fixture.id, SeasonSave.snapshot(season)): return
	app.play_season_game()
	await get_tree().process_frame
	if not _require(is_instance_valid(app.lab), "ordinary main installs actual94 match: " + app.notice): return
	var lab: PitchBatLab = app.lab
	var state: MatchState = lab._match_state
	if not _require(state != null and lab._managed_match, "actual managed MatchState"): return
	if ordinal == 1:
		var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
		var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
		if not _require(state.stadium.get("version") == 27 and state.stadium.environment.mode == "night"
			and ClubCareer.same(state.stadium, expected) and lab._npc_season == season
			and lab._player_home and lab._stadium_ledger != null
			and ClubCareer.same(lab._stadium_ledger.to_data(), paid.to_data())
			and StadiumSurfaceNightRuntime.current(lab) != null
			and StadiumSurfaceNightSnapshot.matches_fixture(state.stadium, season, fixture, paid)
			and StadiumBoundaryRuntime.installed(lab, expected), "actual owned Night27 runtime and complete paid boundary installed"): return
		if not _write("home-fixture27.json", expected): return
		if not await _screen("home-night27.png"): return
	var previous: String = ""
	var stalled: int = 0
	var finished: bool = false
	for frame in range(300000):
		await get_tree().physics_frame
		if not is_instance_valid(lab) or app.lab != lab or lab._match_state != state:
			_require(false, "managed game changed before raw capture")
			return
		if not season.physical.pending.is_empty():
			finished = state.phase == MatchState.Phase.GAME_END and app._result_recorded
			break
		var progress: String = "%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		stalled = stalled + 1 if progress == previous else 0
		previous = progress
		if stalled > 1800 or state.elapsed_seconds >= PhysicalMatchRunner.MAX_SECONDS:
			_require(false, "actual game exceeded unchanged time/progress bounds")
			return
		if frame % 10000 == 0: print("NORMAL94_PROGRESS fixture=", fixture.id, " frame=", frame, " score=", state.score_label())
	if not _require(finished and not app.round_ui._working, "actual human reaches terminal pending, not yet claimed durable"): return
	physical_games += 1
	var human: Array = season.physical.pending.human
	if not _write("human-%d.json" % fixture.id, {"human": human.duplicate(true), "durable_acceptance": false}): return
	if not _require((NightResult.shape(human, [], false) if ordinal == 1 else LeagueHomeResult.shape(human, [], false))
		and human[0] == fixture.id and human[1] == state.away_team.runs and human[2] == state.home_team.runs
		and human[-4 if ordinal == 1 else -1] == StadiumLayoutSnapshot.key(state.stadium)
		and season.physical.pending.reports.is_empty(), "exact actual human result tail and scores"): return
	if ordinal == 1:
		var captured: Dictionary = StadiumSurfaceNightHumanEvidence.capture(lab, season)
		if not _write("actual-night-runtime-evidence.json", captured): return
		if not _require(not captured.is_empty() and ClubCareer.same(captured, human[-1])
			and NightResult.pending_valid(season, human), "newly played94 Night evidence exactly recaptures live runtime"): return
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	if not _write("live-pending-%d.json" % fixture.id, {"snapshot": snapshot, "save_error": SeasonSave.last_error}): return
	var cold: SeasonState = SeasonSave.restore()
	if not _require(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "actual94 human pending cold replay"): return
	if not _write("accepted-human-%d.json" % fixture.id, {"human": human, "durable_acceptance": true}): return
	_boundary(season, "human")

func _begin_step(season: SeasonState, kind: String, fixture: Dictionary, request: String) -> bool:
	if not _require(_authority_matches(season) and not request.is_empty(), "full94 authority before each intent"): return false
	var root: String = path.get_base_dir()
	var raw: String = ("human-%d.json" if kind == "human" else "raw-ai-%d.json") % int(fixture.id)
	if not _require(kind == "publish" or not FileAccess.file_exists(root.path_join(raw)), "existing raw evidence prohibits another game"): return false
	active_intent = Journal.begin(root, "%s-%d" % [kind, int(fixture.id)], {
		"version": 1, "step": kind, "fixture": int(fixture.id), "request": request,
		"input_save_sha256": FileAccess.get_sha256(path), "source_profile": FileAccess.get_sha256(PROFILE_PATH),
		"authority": authority94.duplicate(true), "policy": season.owned_surface_night.duplicate(true),
		"home": season.home_property.duplicate(true), "results": season.player_results.size(),
		"reports": season.physical.reports.size(), "pending_reports": season.physical.pending.get("reports", []).size()})
	return _require(not active_intent.is_empty(), "immutable durable intent precedes one action; unknown outcome forbids retry")

func _boundary(season: SeasonState, kind: String) -> bool:
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave.restore()
	if not _require(_authority_matches(season) and cold != null and not snapshot.is_empty()
		and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "exact94 durable checkpoint before boundary completion"): return false
	var receipt: Dictionary = {"version": 1, "kind": kind, "source_profile": FileAccess.get_sha256(PROFILE_PATH),
		"authority_key": TimeProof.key(authority94), "save_sha256": FileAccess.get_sha256(path),
		"seed": season.season_seed, "home": StadiumLayoutSnapshot.key(season.home_property),
		"policy": TimeProof.key(season.owned_surface_night), "results": season.player_results.size(),
		"reports": season.physical.reports.size(), "pending_reports": season.physical.pending.get("reports", []).size(),
		"pending": not season.physical.pending.is_empty()}
	if not _require(TimeProof.boundary_shape(receipt), "exact94 boundary schema"): return false
	var name: String = "boundary-%d-%d-%s.json" % [receipt.results, receipt.pending_reports, kind]
	if not _write(name, receipt): return false
	var root: String = path.get_base_dir()
	var next: String = root.path_join("resume-boundary.next.json")
	if not _require(Journal.write_new(next, receipt), "immutable next boundary pointer"): return false
	if not _require(DirAccess.rename_absolute(next, root.path_join("resume-boundary.json")) == OK
		and ClubCareer.same(Journal._read_json(root.path_join("resume-boundary.json")), receipt), "atomic verified boundary pointer"): return false
	return _require(not active_intent.is_empty() and Journal.complete(root, active_intent, name), "intent complete only after exact durable save and receipt")

func _screen(name: String) -> bool:
	if DisplayServer.get_name() == "headless": return true
	await RenderingServer.frame_post_draw
	var target: String = path.get_base_dir().path_join(name)
	if not _require(not FileAccess.file_exists(target), "native capture is not overwritten"): return false
	return _require(get_viewport().get_texture().get_image().save_png(target) == OK, "native94 capture " + name)

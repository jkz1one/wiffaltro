extends "res://src/tests/normal_league_home_physical_probe.gd"
## Explicit95/96 sibling. Old91/92/93/94 probes and Journal are untouched.
## Every invocation makes at most one real game, or one zero-game public transition.
const Proof = preload("res://src/tests/shared_league_time_proof.gd")
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const Runtime = preload("res://src/gameplay/season/dynasty_shared_time_runtime.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const NightResult = preload("res://src/gameplay/season/league_home_night_result.gd")
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
var operation: String = ""
var format: int = 0
var input_sha: String = ""
var authority: Dictionary = {}
var step_owner: Dictionary = {}
var returned_report: Dictionary = {}
var worker_error: String = ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("SHARED_TIME_BOUNDED_CHECK ", checks, " ", ok, " ", label)

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--shared-time-bounded"):
		print("SHARED_TIME_BOUNDED_PREPARED games=0 writes=0")
		get_tree().quit()
		return
	var root: String = ""
	var funding: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-time-root="): root = arg.trim_prefix("--shared-time-root=")
		if arg.begins_with("--step="): operation = arg.trim_prefix("--step=")
		if arg.begins_with("--format="): format = int(arg.trim_prefix("--format="))
		if arg.begins_with("--funding-input="): funding = arg.trim_prefix("--funding-input=")
		if arg.begins_with("--funding-sha256="): input_sha = arg.trim_prefix("--funding-sha256=")
	if not _proof_controls():
		get_tree().quit(2)
		return
	var data: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT")
	var clock_ok: bool = Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 \
		and not get_tree().paused and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
	for arg: String in OS.get_cmdline_args(): clock_ok = clock_ok and not arg.begins_with("--fixed-fps")
	if not _require(StadiumNpcPublicRuntime.source_qualified() and clock_ok
		and OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") == "1" and format in [95, 96]
		and operation in ["enroll96", "alternate95", "resume96", "human", "ai", "publish"],
		"qualified source, ordinary clock, explicit bounded shared step and global lease"):
		get_tree().quit(2)
		return
	if not _require(root.is_absolute_path() and root == root.simplify_path()
		and data == root.get_base_dir().path_join("data") and OS.get_environment("XDG_DATA_HOME") == data
		and OS.get_user_data_dir().begins_with(data + "/") and funding.is_absolute_path()
		and Proof.digest(input_sha) and FileAccess.get_sha256(funding) == input_sha,
		"isolated save and workers, immutable retained paid input"):
		get_tree().quit(2)
		return
	if operation == "enroll96":
		if not _require(format == 96 and TimeHome.ENTRY_ENABLED
			and preload("res://src/presentation/season/main_dynasty_route.gd").ENROLLMENT_ENABLED
			and not DirAccess.dir_exists_absolute(root)
			and not FileAccess.file_exists(root), "fresh root and both separately activated main enrollment and96 entry; no private bypass"):
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(root)
	elif not _require(Journal.ready(root, true), "all previous immutable intents completed; unknown outcome halts"):
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	path = SeasonSave.path
	PitchBatLabSettings.path = root.path_join("isolated-settings.cfg")
	var cold: SeasonState = null
	if operation == "enroll96":
		active_intent = Journal.begin(root, "enroll96", {"version": 1, "step": operation,
			"source_profile": FileAccess.get_sha256(PROFILE_PATH), "input_sha256": input_sha,
			"authored_prerequisites": true, "physical_games": 0})
		if not _require(not active_intent.is_empty(), "intent before source fixture or public enrollment writes"):
			get_tree().quit(2)
			return
		var source: SeasonState = _source(funding)
		if not _require(source != null and SeasonSave.save(source), "authored unlock fixture saved with unchanged retained paid journal"):
			get_tree().quit(2)
			return
	else:
		if not _require(_clean_owner() and SeasonSave.bind_dynasty_owner(_owner_path()), "ready exact owner; no automatic intent repair"):
			get_tree().quit(2)
			return
		cold = SeasonSave.restore()
		if not _receipt_valid(Journal._read_json(root.path_join("resume-boundary.json")), cold):
			get_tree().quit(2)
			return
	# The cold inspection above temporarily selected the owner. The real main
	# must rediscover it from the retained files, not see two explicit owners.
	SeasonSave._dynasty_owner_path = ""
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
	if _require(not app._loading_boot, "actual main boot completes"):
		if operation == "enroll96":
			await _enroll(app)
		elif _require(cold != null and ClubCareer.same(SeasonSave.snapshot(app.season), SeasonSave.snapshot(cold))
			and _receipt_valid(Journal._read_json(root.path_join("resume-boundary.json")), app.season),
			"postboot full snapshot and full owner equal preboot validated frontier"):
			if operation == "alternate95": await _alternate(app)
			elif operation == "resume96": await _resume(app)
			elif _require(app.season._league_home_context.format == format, "requested route is currently selected"):
				await _step(app)
	app.free()
	_require(FileAccess.get_sha256(funding) == input_sha, "retained funding bytes unchanged")
	print("SHARED_TIME_BOUNDED_RESULT step=%s format=%d checks=%d failures=%d new_human_games=%d authored_prerequisites=true" % [operation, format, checks, failures, physical_games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

func _source(input: String) -> SeasonState:
	var source: SeasonState = SeasonSave._decode(Journal._read_json(input))
	if source == null or source.career == null: return null
	var club: ClubCareer = source.career.fork()
	if not club.close(source): return null
	var journal: Dictionary = club._assets.duplicate(true)
	if "dynasty" not in club.available_leagues():
		# Authored prerequisites only. Retain every funding row and paid event.
		var titles: ClubCareer = Fixture.prefix([{"league": "dugout", "tier": 0},
			{"league": "dugout", "tier": 1}, {"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
		if titles == null: return null
		for row: Dictionary in titles.runs:
			var copy: Dictionary = row.duplicate(true)
			copy.id = club.runs.size() + 1
			club.runs.append(copy)
	club = ClubCareer.from_data(club.to_data())
	if club == null or ClubPlayers.assets(club) == null or not ClubCareer.same(journal, club._assets): return null
	var season: SeasonState = SeasonState.create_closed_league(959601, LeagueRules.capture("dugout"), true)
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) or not club.start_league(season) \
		or not load("res://src/gameplay/season/normal_league_home.gd").prepare(season): return null
	return season

func _enroll(app: SeasonApp) -> void:
	if not _require(app.season != null and app.season._league_home_context.get("format") == 93,
		"actual main restores explicitly authored ordinary93 prerequisite fixture"): return
	for pick in range(4): app.choose_player(app.season.offers()[0])
	if not _require(app.season.picks.size() == 4 and app.season.player_results.is_empty(), "four actual ordinary draft choices; no invented games"): return
	var original: Dictionary = SeasonSave.snapshot(app.season)
	app.call("_show_main_leagues")
	var button: Button = _button(app.menu, "", "REVIEW DYNASTY ENROLLMENT")
	if not _require(button != null and not button.disabled, "actual public Dynasty enrollment control"): return
	button.pressed.emit()
	if not _select_night(app.menu): return
	var prepared: Dictionary = app.dynasty_enrollment._payload.snapshot.duplicate(true)
	if not _require(prepared.get("version") == 96 and prepared.starting_profile == "night", "actual UI prepares explicit96 Night policy"): return
	if not _write("prepared96.json", prepared) or not _write("authored-source93.json", original): return
	if not await _screen("enroll96-review.png"): return
	button = _button(app.menu, "", "START DYNASTY & ARCHIVE SOURCE")
	if not _require(button != null and not button.disabled, "actual archive and start control"): return
	button.pressed.emit()
	if not _require(app.season != null and TimeHome.matches(app.season)
		and ClubCareer.same(SeasonSave.snapshot(app.season), prepared)
		and ClubCareer.same(Journal._read_json(path), original)
		and _clean_owner(), "public96 commits prepared bytes, preserves archived ordinary source"): return
	if not _save_authority(app.season): return
	_boundary(app.season, operation)

func _select_night(node: Node) -> bool:
	var choice: OptionButton = node.find_child("SharedLeagueTime", true, false) as OptionButton
	if not _require(TimeHome.ENTRY_ENABLED and choice != null and not choice.disabled,
		"activated actual shared time chooser, never a private admission call"): return false
	choice.select(3)
	choice.item_selected.emit(3)
	return true

func _alternate_button(node: Node) -> Button:
	if node is Button and node.get_meta("owner_league", "") == "dugout" \
		and node.get_meta("owner_league_tier", -1) == 0: return node as Button
	for child: Node in node.get_children():
		var found: Button = _alternate_button(child)
		if found != null: return found
	return null

func _alternate(app: SeasonApp) -> void:
	var owner: Dictionary = _owner()
	if not _require(format == 95 and TimeHome.ENTRY_ENABLED and owner.selected == "dynasty"
		and owner.other.is_empty() and app.season.player_results.is_empty()
		and app.season.physical.pending.is_empty() and app.season.physical.reports.is_empty(),
		"95 entry only from original pristine96, no discarded progress"): return
	if not _write("paused96.json", SeasonSave.snapshot(app.season)): return
	if not _transition_intent("alternate95", owner): return
	app.call("_show_main_leagues")
	var button: Button = _alternate_button(app.menu)
	if not _require(button != null and not button.disabled, "actual Dugout/Base alternate review button"): return
	button.pressed.emit()
	if not _select_night(app._confirmation_body): return
	if not await _screen("alternate95-review.png"): return
	if not _require(app._dialog.visible, "actual95 confirmation is visible"): return
	app._dialog.confirmed.emit()
	app._dialog.hide()
	if not _require(app.season != null and app.season._league_home_context.get("format") == 95
		and _owner().selected == "other" and ClubCareer.same(_owner().dynasty, owner.dynasty), "public95 admission pauses exact96 slot"): return
	if not _write("prepared95.json", SeasonSave.snapshot(app.season)): return
	if not _save_authority(app.season): return
	for pick in range(4): app.choose_player(app.season.offers()[0])
	if not _require(app.season.picks.size() == 4 and app.season.player_results.is_empty()
		and app.season.physical.reports.is_empty(), "four actual95 draft choices; zero invented games"): return
	_boundary(app.season, operation)

func _resume(app: SeasonApp) -> void:
	var owner: Dictionary = _owner()
	if not _require(format == 96 and owner.selected == "other" and app.season.player_results.size() == 2
		and app.season.physical.reports.size() == 4 and app.season.physical.pending.is_empty(),
		"resume96 only after two genuinely published95 rounds"): return
	if not _transition_intent("resume96", owner): return
	if not _write("paused95.json", SeasonSave.snapshot(app.season)): return
	app.call("_show_main_leagues")
	var button: Button = _button(app.menu, "", "RETURN TO DYNASTY")
	if not _require(button != null and not button.disabled, "actual Return to Dynasty control"): return
	button.pressed.emit()
	if not _require(app._dialog.visible, "actual saved-season switch confirmation"): return
	app._dialog.confirmed.emit()
	app._dialog.hide()
	authority = Journal._read_json(path.get_base_dir().path_join("authority96.json"))
	if not _require(ClubCareer.same(SeasonSave.snapshot(app.season), Journal._read_json(path.get_base_dir().path_join("paused96.json")))
		and ClubCareer.same(_owner().other, owner.other) and _authority_matches(app.season),
		"actual96 continuation restores exact paused roster/header/policy/grant and preserves played95 slot"): return
	if not await _screen("resume96.png"): return
	_boundary(app.season, operation)

func _save_authority(season: SeasonState) -> bool:
	authority = Proof.authority(season, _owner(), FileAccess.get_sha256(PROFILE_PATH), input_sha,
		FileAccess.get_sha256(path), FileAccess.get_sha256(path.get_base_dir().path_join("prepared%d.json" % format)))
	if not _require(not authority.is_empty(), "immutable full session/owner/grant/home/policy/run authority"): return false
	var changed: Dictionary = authority.duplicate(true)
	changed.header.owned_surface_night.run_id += 1
	if not _require(not Proof.authority_shape(changed), "cross-run policy cannot reuse physical authority"): return false
	changed = authority.duplicate(true)
	changed.header.session.session_id += ":foreign"
	if not _require(not Proof.authority_shape(changed), "cross-session header cannot reuse physical authority"): return false
	return _write("authority%d.json" % format, authority)

func _owner_path() -> String:
	return path + ".dynasty-owner"

func _owner() -> Dictionary:
	return Store.inspect(_owner_path()).get("owner", {})

func _clean_owner() -> bool:
	for suffix: String in [".intent", ".tmp", ".intent.tmp", ".committed.tmp"]:
		if FileAccess.file_exists(_owner_path() + suffix) or DirAccess.dir_exists_absolute(_owner_path() + suffix): return false
	return Store.inspect(_owner_path()).get("status") == "ready"

func _authority_matches(season: SeasonState) -> bool:
	return _clean_owner() and Proof.matches(authority, season, _owner(), FileAccess.get_sha256(PROFILE_PATH), _owner_path()) \
		and authority.input_sha256 == input_sha and authority.original_sha256 == FileAccess.get_sha256(path) \
		and authority.admission_sha256 == FileAccess.get_sha256(path.get_base_dir().path_join("prepared%d.json" % int(authority.format))) \
		and SeasonSave._dynasty_owner_path == _owner_path()

func _receipt_valid(receipt: Variant, season: SeasonState) -> bool:
	if not _require(Proof.boundary_shape(receipt) and season != null, "strict bounded95/96 receipt schema"): return false
	var saved: Variant = Journal._read_json(path.get_base_dir().path_join("authority%d.json" % int(receipt.format)))
	if not _require(saved is Dictionary, "immutable authority exists for receipt route"): return false
	authority = saved
	if not _require(_authority_matches(season), "full shared authority matches selected cold snapshot"): return false
	var owner: Dictionary = _owner()
	var count: int = season.player_results.size()
	var pending: Dictionary = season.physical.pending
	return _require(receipt.source_profile == FileAccess.get_sha256(PROFILE_PATH)
		and receipt.authority_key == Proof.key(authority) and receipt.save_sha256 == FileAccess.get_sha256(path)
		and receipt.owner_sha256 == FileAccess.get_sha256(_owner_path())
		and receipt.mirror_sha256 == FileAccess.get_sha256(_owner_path() + ".committed")
		and receipt.owner_key == Proof.key(owner) and receipt.owner_revision == owner.revision
		and receipt.snapshot_key == Proof.key(SeasonSave.snapshot(season)) and receipt.seed == season.season_seed
		and receipt.home == StadiumLayoutSnapshot.key(season.home_property) and receipt.policy == Proof.key(season.owned_surface_night)
		and receipt.format == season._league_home_context.format and receipt.results == count
		and receipt.reports == count * 2 and season.physical.reports.size() == count * 2
		and receipt.pending == (not pending.is_empty()) and receipt.pending_reports == pending.get("reports", []).size()
		and count in [0, 1, 2] and (count == 2 or season.pending_fixture().id == count * 3)
		and (pending.is_empty() or (count < 2 and pending.human[0] == count * 3)),
		"exact natural frontier, full owner, cold snapshot, archived source, header and policy identity")
func _step(app: SeasonApp) -> void:
	if not _require(not _owner().other.is_empty() and (format == 95
		or FileAccess.file_exists(path.get_base_dir().path_join("paused95.json"))),
		"paired95/96 route exists;96 games follow actual saved-season continuation"): return
	var season: SeasonState = app.season
	if not _require(Proof.frontier(operation, season.player_results.size(),
		not season.physical.pending.is_empty(), season.physical.pending.get("reports", []).size()),
		"one admissible human/AI/publication step; completed or wrong frontiers refuse"): return
	if operation == "human":
		await _human(app)
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
	var request_probe: Dictionary = PhysicalRoundProcess.request_for(season, "shared-proof", request, int(fixture.id))
	if not _require(request_probe.get("version") == (6 if format == 96 else 5)
		and ClubCareer.same(request_probe.get("season"), SeasonSave.snapshot(season)), "exact worker5/6 transport and complete owner-selected snapshot"): return
	if not _write(_name("request-%d.json" % fixture.id), request_probe): return
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	add_child(worker)
	worker.finished.connect(func(report: Dictionary) -> void: returned_report = report.duplicate(true))
	worker.failed.connect(func(reason: String) -> void: worker_error = reason)
	if not _require(worker.start(season), "selected owner worker5/6 starts exactly one physical AI fixture"):
		worker.free()
		return
	while worker.running: await get_tree().process_frame
	if not _require(worker_error.is_empty() and not returned_report.is_empty(), "one validated actual AI report: " + worker_error):
		worker.free()
		return
	var row: Dictionary = {"fixture": int(fixture.id), "request": request, "report": returned_report}
	if not _write(_name("raw-ai-%d.json" % fixture.id), row):
		worker.free()
		return
	season.physical.pending.reports.append(row)
	if _require(SeasonSave.save(season), "raw AI report durably checkpoints once: " + SeasonSave.last_error):
		_boundary(season, "ai")
	worker.free()

func _human(app: SeasonApp) -> void:
	var season: SeasonState = app.season
	var ordinal: int = season.player_results.size()
	var fixture: Dictionary = season.pending_fixture().duplicate(true)
	if not _require(fixture.id == ordinal * 3 and (fixture.home == 0) == (ordinal == 1)
		and app.round_ui.process_jobs and _authority_matches(season), "natural away0/home3, default workers and exact95/96 authority"): return
	if not _begin_step(season, "human", fixture, SeasonPhysicalFixtures.request_key(season, fixture)): return
	if not _write(_name("before-%d.json" % fixture.id), SeasonSave.snapshot(season)): return
	app.play_season_game()
	await get_tree().process_frame
	if not _require(is_instance_valid(app.lab), "ordinary main installs actual95/96 match: " + app.notice): return
	var lab: PitchBatLab = app.lab
	var state: MatchState = lab._match_state
	if not _require(state != null and lab._managed_match, "actual managed MatchState"): return
	if ordinal == 1:
		var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
		var paid: ClubAssetLedger = Runtime.paid_ledger(season)
		if not _require(state.stadium.get("version") == 27 and state.stadium.environment.mode == "night"
			and ClubCareer.same(state.stadium, expected) and lab._npc_season == season
			and lab._player_home and paid != null and lab._stadium_ledger != null
			and ClubCareer.same(lab._stadium_ledger.to_data(), paid.to_data())
			and StadiumSurfaceNightRuntime.current(lab) != null
			and StadiumSurfaceNightSnapshot.matches_fixture(state.stadium, season, fixture, paid)
			and StadiumBoundaryRuntime.installed(lab, expected), "actual shared owned Night27 runtime and complete paid boundary installed"): return
		if not _write(_name("home-fixture27.json"), expected): return
		if not await _screen(_name("home-night27.png")): return
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
		if frame % 10000 == 0: print("SHARED_TIME_PROGRESS fixture=", fixture.id, " frame=", frame, " score=", state.score_label())
	if not _require(finished and not app.round_ui._working, "actual human reaches terminal pending, not yet claimed durable"): return
	physical_games += 1
	var human: Array = season.physical.pending.human
	if not _write(_name("human-%d.json" % fixture.id), {"human": human.duplicate(true), "durable_acceptance": false}): return
	if not _require((NightResult.shape(human, [], false) if ordinal == 1 else LeagueHomeResult.shape(human, [], false))
		and human[0] == fixture.id and human[1] == state.away_team.runs and human[2] == state.home_team.runs
		and human[-4 if ordinal == 1 else -1] == StadiumLayoutSnapshot.key(state.stadium)
		and season.physical.pending.reports.is_empty(), "exact actual shared human result tail and scores"): return
	if ordinal == 1:
		var captured: Dictionary = StadiumSurfaceNightHumanEvidence.capture(lab, season)
		if not _write(_name("actual-night-runtime-evidence.json"), captured): return
		if not _require(not captured.is_empty() and ClubCareer.same(captured, human[-1])
			and NightResult.pending_valid(season, human), "newly played95/96 Night evidence exactly recaptures live runtime"): return
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	if not _write(_name("live-pending-%d.json" % fixture.id), {"snapshot": snapshot, "save_error": SeasonSave.last_error}): return
	var cold: SeasonState = SeasonSave.restore()
	if not _require(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "actual95/96 human pending cold replay"): return
	if not _write(_name("accepted-human-%d.json" % fixture.id), {"human": human, "durable_acceptance": true}): return
	_boundary(season, "human")

func _name(name: String) -> String:
	return "time%d-%s" % [format, name]

func _transition_intent(kind: String, owner: Dictionary) -> bool:
	step_owner = owner.duplicate(true)
	active_intent = Journal.begin(path.get_base_dir(), kind, {"version": 1, "step": kind,
		"owner": step_owner, "owner_sha256": FileAccess.get_sha256(_owner_path()),
		"source_profile": FileAccess.get_sha256(PROFILE_PATH), "input_sha256": input_sha})
	return _require(not active_intent.is_empty(), "immutable intent before one public transition")

func _begin_step(season: SeasonState, kind: String, fixture: Dictionary, request: String) -> bool:
	if not _require(_authority_matches(season) and not request.is_empty(), "complete95/96 authority before intent"): return false
	var root: String = path.get_base_dir()
	var raw: String = _name(("human-%d.json" if kind == "human" else "raw-ai-%d.json") % int(fixture.id))
	if not _require(kind == "publish" or not FileAccess.file_exists(root.path_join(raw)), "existing raw evidence forbids another game"): return false
	step_owner = _owner().duplicate(true)
	active_intent = Journal.begin(root, _name("%s-%d" % [kind, int(fixture.id)]), {
		"version": 1, "step": kind, "fixture": int(fixture.id), "request": request,
		"owner": step_owner, "owner_sha256": FileAccess.get_sha256(_owner_path()),
		"input_save_sha256": FileAccess.get_sha256(path), "source_profile": FileAccess.get_sha256(PROFILE_PATH),
		"authority": authority.duplicate(true), "snapshot": SeasonSave.snapshot(season)})
	return _require(not active_intent.is_empty(), "immutable durable intent precedes one action; unknown outcome forbids retry")

func _boundary(season: SeasonState, kind: String) -> bool:
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave.restore()
	var owner: Dictionary = _owner()
	if not _require(_authority_matches(season) and cold != null and not snapshot.is_empty()
		and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "full95/96 cold replay before boundary completion"): return false
	if not step_owner.is_empty():
		if not _require(ClubCareer.same(owner.career.assets, step_owner.career.assets)
			and ClubCareer.same(owner.career.origin, step_owner.career.origin)
			and ClubCareer.same(owner.career.settlements, step_owner.career.settlements), "no second wallet, paid-history rewrite or fabricated settlement"): return false
		if kind in ["alternate95", "resume96", "human", "ai", "publish"]:
			if not _require(Proof.paused_matches(step_owner, owner, format),
				"paused counterpart full slot and admission remain byte-exact across public transitions and games"): return false
	var receipt: Dictionary = {"version": 1, "kind": kind, "format": format,
		"source_profile": FileAccess.get_sha256(PROFILE_PATH), "authority_key": Proof.key(authority),
		"save_sha256": FileAccess.get_sha256(path), "owner_sha256": FileAccess.get_sha256(_owner_path()),
		"mirror_sha256": FileAccess.get_sha256(_owner_path() + ".committed"), "owner_key": Proof.key(owner),
		"owner_revision": owner.revision, "snapshot_key": Proof.key(snapshot), "seed": season.season_seed,
		"home": StadiumLayoutSnapshot.key(season.home_property), "policy": Proof.key(season.owned_surface_night),
		"results": season.player_results.size(), "reports": season.physical.reports.size(),
		"pending_reports": season.physical.pending.get("reports", []).size(), "pending": not season.physical.pending.is_empty()}
	if not _require(Proof.boundary_shape(receipt), "strict95/96 durable boundary schema"): return false
	var stem: String = _name("boundary-%d-%d-%s" % [receipt.results, receipt.pending_reports, kind])
	if not _write(stem + "-checkpoint.json", snapshot) or not _write(stem + "-owner.json", owner) \
		or not _write(stem + ".json", receipt): return false
	var root: String = path.get_base_dir()
	var next: String = root.path_join("resume-boundary.next.json")
	if not _require(Journal.write_new(next, receipt), "new immutable boundary pointer"): return false
	if not _require(DirAccess.rename_absolute(next, root.path_join("resume-boundary.json")) == OK
		and ClubCareer.same(Journal._read_json(root.path_join("resume-boundary.json")), receipt), "atomic verified boundary pointer"): return false
	return _require(not active_intent.is_empty() and Journal.complete(root, active_intent, stem + ".json"),
		"intent completes only after exact durable owner, checkpoint, original save and receipt")

func _screen(name: String) -> bool:
	if DisplayServer.get_name() == "headless": return true
	await RenderingServer.frame_post_draw
	var target: String = path.get_base_dir().path_join(name)
	if not _require(not FileAccess.file_exists(target), "native capture is not overwritten"): return false
	return _require(get_viewport().get_texture().get_image().save_png(target) == OK, "native shared capture " + name)

func _proof_controls() -> bool:
	# Small synthetic schema/frontier controls, never admitted as played evidence.
	var receipt: Dictionary = {"version": 1, "kind": "human", "format": 95,
		"source_profile": "a".repeat(64), "authority_key": "b".repeat(64),
		"save_sha256": "c".repeat(64), "owner_sha256": "d".repeat(64),
		"mirror_sha256": "e".repeat(64), "owner_key": "f".repeat(64), "owner_revision": 1,
		"snapshot_key": "a".repeat(64), "seed": 1, "home": "b".repeat(64),
		"policy": "c".repeat(64), "results": 0, "reports": 0, "pending_reports": 0, "pending": true}
	if not _require(Proof.boundary_shape(receipt), "synthetic boundary schema control"): return false
	for field: String in ["owner_key", "policy", "snapshot_key"]:
		var bad: Dictionary = receipt.duplicate(true)
		bad.erase(field)
		if not _require(not Proof.boundary_shape(bad), "missing full authority operand refuses: " + field): return false
	var wrong: Dictionary = receipt.duplicate(true)
	wrong.reports = 2
	if not _require(not Proof.boundary_shape(wrong), "result/report frontier mismatch refuses"): return false
	wrong = receipt.duplicate(true)
	wrong["unknown"] = true
	if not _require(not Proof.boundary_shape(wrong), "unknown receipt field refuses"): return false
	var bound: Dictionary = {"path": "/proof/season.json.dynasty-owner", "revision": 3, "session_id": "session"}
	if not _require(Proof.binding_matches(bound, "/proof/season.json.dynasty-owner", 3, "session")
		and not Proof.binding_matches(bound, "/other/season.json.dynasty-owner", 3, "session"),
		"same revision/session bound to a different owner path refuses"): return false
	var pair: Dictionary = {"dynasty": {"session_id": "carried"}, "other": {"session_id": "alternate"},
		"career": {"sessions": {"carried": {"full_header": "frozen96"}, "alternate": {"full_header": "frozen95"}}}}
	for route: int in [95, 96]:
		var changed: Dictionary = pair.duplicate(true)
		var paused_id: String = "carried" if route == 95 else "alternate"
		changed.career.sessions[paused_id].full_header = "foreign"
		if not _require(Proof.paused_matches(pair, pair, route) and not Proof.paused_matches(pair, changed, route),
			"unchanged paused slot cannot hide a changed full admission during transition"): return false
	return _require(Proof.frontier("human", 0, false, 0) and Proof.frontier("ai", 0, true, 0)
		and Proof.frontier("publish", 1, true, 2) and not Proof.frontier("human", 0, true, 0)
		and not Proof.frontier("ai", 1, true, 2) and not Proof.frontier("publish", 0, true, 1)
		and not Proof.frontier("human", 2, false, 0), "bounded one-game or zero-game frontier controls")

extends Node
## Staged automated actual gameplay, NOT human visual/balance acceptance.
## Parent must own the engine AND descendants with its bounded process supervisor.
## One invocation per stage, same isolated HOME/XDG. No automatic retry of intents.
## init,human1,ai1,ai2,publish1,buy,human2,ai3,ai4,publish2
## --expanded-live-stage=STAGE --expanded-live-root=ABSOLUTE_DIR
## --expanded-live-seed=N (init only); --physical-test-retention (all stages).
## R3: up to 120s startup, 900s actual human gameplay, then the unchanged
## 780-frame outro with a separate 120s wall limit. Parent human cap: 1260s.
## R5 proposed AI budgets: startup300s, preparation180s, worker260s, save180s,
## cold replay360s; parent AI cap1440s. Human1 retains parent1260s; human2
## parent1800s/startup300s/game900s/outro180s/replay360s. Publish/buy parent1200s
## startup300s/operation480s/replay360s. Sync budgets are late acceptance checks.
## No changed clocks,
## invented midgame resume or retry of a failed root. R1/R2 evidence stays frozen.

const Journal = preload("res://src/tests/normal_league_proof_journal.gd")
const APP = preload("res://src/presentation/season/season_app.tscn")
const PROFILE = "res://src/presentation/stadium/stadium_npc_current_source_profile.gd"
const SELF = "res://src/tests/expanded_season_live_test.gd"
const STAGES = ["init", "human1", "ai1", "ai2", "publish1", "buy", "human2", "ai3", "ai4", "publish2"]
const NEW_IDS = ["pitch.submarine_two_seam", "pitch.submarine_curveball"]
const AI_STARTUP_MS: int = 300000
const AI_PREPARATION_MS: int = 180000
const AI_WORKER_MS: int = 260000
const AI_SAVE_MS: int = 180000
const AI_REPLAY_MS: int = 360000
const LATER_STARTUP_MS: int = 300000
const SHOP_PUBLISH_MS: int = 480000
const LATER_REPLAY_MS: int = 360000
const HUMAN_TWO_OUTRO_MS: int = 180000
const HUMAN_STARTUP_MS: int = 120000
const HUMAN_GAME_MS: int = 900000
const HUMAN_OUTRO_MS: int = 120000
const HUMAN_PROGRESS_MS: int = 30000
var root: String = ""
var stage: String = ""
var seed_value: int = 443
var checks: int = 0
var failures: int = 0
var began: int = 0
var app: SeasonApp
var worker: PhysicalRoundProcess
var receipt: Dictionary = {}
var returned: Dictionary = {}
var worker_error: String = ""
var captures: int = 0
var transport_captures: Array[Dictionary] = []


func check(ok: bool, label: String) -> bool:
	checks += 1
	print("EXPANDED_LIVE_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
	return ok


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--expanded-live-stage="):
			stage = arg.trim_prefix("--expanded-live-stage=")
		if arg.begins_with("--expanded-live-root="):
			root = arg.trim_prefix("--expanded-live-root=")
		if arg.begins_with("--expanded-live-seed="):
			seed_value = arg.trim_prefix("--expanded-live-seed=").to_int()
	if stage.is_empty():
		print("EXPANDED_LIVE_PREPARED no_games=true no_writes=true")
		get_tree().quit(0)
		return
	began = Time.get_ticks_msec()
	if _preflight():
		await _run()
	if is_instance_valid(worker):
		if worker.running:
			worker.cancel()
		worker.free()
	if is_instance_valid(app):
		app.free()
	print("EXPANDED_LIVE_RESULT stage=", stage, " checks=", checks, " failures=", failures,
		" wall_ms=", Time.get_ticks_msec() - began, " visual_acceptance=false")
	get_tree().quit(0 if failures == 0 else 1)


func _preflight() -> bool:
	var data: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT").trim_suffix("/")
	if not check(stage in STAGES and root.is_absolute_path() and root == root.simplify_path()
		and not data.is_empty() and data.is_absolute_path() and root.begins_with(data + "/")
		and OS.get_environment("XDG_DATA_HOME") == data
		and OS.get_user_data_dir().begins_with(data + "/")
		and OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") == "1"
		and OS.get_environment("WIFFALTRO_EXPANDED_DESCENDANTS_SUPERVISED") == "1"
		and not OS.get_cmdline_user_args().has("--physical-in-process")
		and OS.get_cmdline_user_args().has("--physical-test-retention"),
		"explicit isolated root, retained jobs, parent descendant supervision and lease"):
		return false
	var clock_ok: bool = Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0
	for arg: String in OS.get_cmdline_args():
		clock_ok = clock_ok and not arg.begins_with("--fixed-fps")
	if not check(clock_ok and not get_tree().paused
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
		and StadiumNpcPublicRuntime.source_qualified(), "ordinary clock and exact qualified source"):
		return false
	if stage == "init":
		if not check(not DirAccess.dir_exists_absolute(root) and not FileAccess.file_exists(root)
			and not FileAccess.file_exists(ExpandedSeasonUI.SAVE_PATH)
			and not FileAccess.file_exists(ExpandedSeasonUI.SAVE_PATH + ".tmp")
			and not FileAccess.file_exists(ExpandedSeasonUI.SAVE_PATH + ".bak"), "fresh test root and v6 slot"):
			return false
		return check(DirAccess.make_dir_recursive_absolute(root) == OK, "create isolated evidence root")
	var previous: String = STAGES[STAGES.find(stage) - 1]
	var value: Variant = Journal._read_json(root.path_join(previous + ".complete.json"))
	if not check(value is Dictionary, "previous stage has complete evidence"):
		return false
	receipt = value
	return check(receipt.get("stage") == previous and receipt.get("profile") == FileAccess.get_sha256(PROFILE)
		and receipt.get("test") == FileAccess.get_sha256(SELF)
		and receipt.get("catalog") == ExpandedSeasonCatalog.signature()
		and receipt.get("save") == FileAccess.get_sha256(ExpandedSeasonUI.SAVE_PATH)
		and receipt.get("prior") == FileAccess.get_sha256(root.path_join("prior.json"))
		and not FileAccess.file_exists(ExpandedSeasonUI.SAVE_PATH + ".tmp")
		and not FileAccess.file_exists(root.path_join(stage + ".intent.json")),
		"exact retained frontier; uncertain or repeated stage refuses")


func _run() -> void:
	if not check(Journal.write_new(root.path_join(stage + ".intent.json"), {
		"stage": stage, "before": receipt, "profile": FileAccess.get_sha256(PROFILE),
		"catalog": ExpandedSeasonCatalog.signature(), "test": FileAccess.get_sha256(SELF)}),
		"write immutable intent before any game or save"):
		return
	PitchBatLabSettings.path = root.path_join("settings.cfg")
	if stage == "init":
		await _initialize()
	else:
		SeasonSave.path = ExpandedSeasonUI.SAVE_PATH
		var restore_began: int = Time.get_ticks_msec()
		_ai_timing("startup_restore_started", restore_began)
		var cold: SeasonState = SeasonSave.restore()
		_ai_timing("startup_restore_finished", restore_began)
		if not check(cold != null and cold.build.pitch_catalog_expanded(), "cold v6 restore"):
			return
		app = APP.instantiate() as SeasonApp
		add_child(app)
		for _frame in range(600):
			await get_tree().process_frame
			if not app._loading_boot and app.menu != null:
				break
		if not check(app.season != null and ClubCareer.same(SeasonSave.snapshot(cold),
			SeasonSave.snapshot(app.season)), "SeasonApp restores exact checkpoint"):
			return
		_ai_timing("app_restore_verified", began)
		if stage == "human2" or stage.begins_with("publish") or stage == "buy":
			if not check(Time.get_ticks_msec() - began <= LATER_STARTUP_MS, "later-stage startup within separate300s budget"):
				return
		if stage.begins_with("human"):
			await _human()
		elif stage.begins_with("ai"):
			_ai_timing("startup_complete", began)
			if not check(Time.get_ticks_msec() - began <= AI_STARTUP_MS, "AI startup within separate budget"):
				return
			await _ai()
		elif stage.begins_with("publish") or stage == "buy":
			var operation_began: int = Time.get_ticks_msec()
			_ai_timing("shop_or_publish_started", operation_began)
			if stage == "buy":
				_buy()
			else:
				_publish()
			_ai_timing("shop_or_publish_finished", operation_began)
			check(Time.get_ticks_msec() - operation_began <= SHOP_PUBLISH_MS, "shop/publication within separate480s budget")
	if failures == 0:
		_complete()


func _initialize() -> void:
	SeasonSave.path = root.path_join("prior.json")
	var prior: SeasonState = WorkingPitchProgression.create_season(930)
	if not check(prior != null and SeasonSave.save(prior), "isolated prior club saved"):
		return
	receipt["prior"] = FileAccess.get_sha256(SeasonSave.path)
	app = APP.instantiate() as SeasonApp
	add_child(app)
	for _frame in range(600):
		await get_tree().process_frame
		if not app._loading_boot and app.menu != null:
			break
	var season: SeasonState = ExpandedSeasonProgression.create_season(seed_value)
	SeasonSave.path = ExpandedSeasonUI.SAVE_PATH
	if not check(season != null and SeasonSave.save(season), "fresh deterministic v6 season; no grants"):
		return
	SeasonSave.path = root.path_join("prior.json")
	ExpandedSeasonUI.open(app)
	if not check(app.season != null and app.season.build.pitch_catalog_expanded(), "normal existing-slot entry"):
		return
	for _pick in range(4):
		app.choose_player(app.season.offers()[0])
	check(app.season.picks.size() == 4, "four normal drafted players")
	ExpandedSeasonUI.return_to_club(app)
	check(SeasonSave.path == root.path_join("prior.json")
		and FileAccess.get_sha256(SeasonSave.path) == receipt.prior, "return preserves prior club bytes")
	ExpandedSeasonUI.open(app)
	check(app.season.build.pitch_catalog_expanded(), "reopen v6 slot")


func _human() -> void:
	var expected: int = 0 if stage == "human1" else 1
	if not check(app.season.player_results.size() == expected and app.season.physical.pending.is_empty(),
		"unplayed human frontier only"):
		return
	var match_state: MatchState = app.season.make_match()
	if not check(match_state != null and app.season.build.pitch_catalog_expanded()
		and SeasonPitchProof.enabled(app.season.build),
		"actual SeasonState.make_match with expanded Build-scoped proof"):
		return
	var home: bool = app.season.pending_fixture().home == 0
	if not _owned_starter(match_state.home_team if home else match_state.away_team):
		return
	app.play_season_game()
	for _frame in range(600):
		await get_tree().process_frame
		if app.lab != null and app.lab._match_state != null:
			break
	if not check(app.lab != null and app.lab._match_state != null, "managed SeasonApp match installed"):
		return
	var lab: PitchBatLab = app.lab
	var own: TeamMatchState = lab._match_state.home_team if lab._player_home else lab._match_state.away_team
	if not _owned_starter(own) or not check(SeasonPitchProof.accepts(app.season.build,
		lab._match_state.sure_shot.evidence_current(own)), "installed human current proof admitted by expanded Build"):
		return
	if not check(Time.get_ticks_msec() - began <= (LATER_STARTUP_MS if stage == "human2" else HUMAN_STARTUP_MS), "human startup within stage-specific budget"):
		_human_diagnostic(lab, "startup_limit", 0)
		return
	var gameplay_began: int = Time.get_ticks_msec()
	var next_progress: int = gameplay_began + HUMAN_PROGRESS_MS
	_human_diagnostic(lab, "gameplay_started", gameplay_began)
	var released: bool = false
	var previous: String = ""
	var stalled: int = 0
	while Time.get_ticks_msec() - gameplay_began < HUMAN_GAME_MS:
		await get_tree().physics_frame
		var state: MatchState = lab._match_state
		if Time.get_ticks_msec() >= next_progress:
			_human_diagnostic(lab, "progress", gameplay_began)
			next_progress = Time.get_ticks_msec() + HUMAN_PROGRESS_MS
		var own_release: Dictionary = state.pitch_ledger._pitchers.get(
			StringName(receipt.get("player", "")), {})
		if own_release.get("recipes", []).has(StringName(receipt.get("recipe", ""))):
			released = true
		if state.phase == MatchState.Phase.GAME_END:
			break
		var progress: String = "%d:%d:%d" % [state.phase, state.plate_appearance_number, lab._throw_number]
		stalled = stalled + 1 if previous == progress else 0
		previous = progress
		if stalled >= 1800:
			_human_diagnostic(lab, "stalled", gameplay_began)
			check(false, "human fixture stalled; retain unresolved intent")
			return
		if lab._player_is_batting():
			if lab._awaiting_batter_confirm and state.phase == MatchState.Phase.PRE_PITCH:
				PitchBatLabFeelSupport.confirm_batter_ready(lab)
		elif state.phase == MatchState.Phase.PRE_PITCH:
			if not lab._release_controller.active:
				if stage == "human2":
					var options: Array = lab._current_pitch_options()
					for index in range(options.size()):
						if String(options[index].id) == receipt.recipe:
							lab._pitch_picker._select(index)
				lab._pitch_target = lab.DEFAULT_TARGET
				lab._pitch_effort = 1.0
				PitchBatLabFeelSupport.begin_pitch_release(lab)
			elif lab._release_controller.elapsed_seconds >= PitchReleaseController.IDEAL_RELEASE_SECONDS:
				PitchBatLabFeelSupport.commit_pitch_release(lab)
	_human_diagnostic(lab, "game_end" if lab._match_state.phase == MatchState.Phase.GAME_END else "gameplay_limit", gameplay_began)
	if not check(lab._match_state.phase == MatchState.Phase.GAME_END,
		"actual human GAME_END within 900s gameplay bound; failed intent remains unresolved"):
		return
	if stage == "human2" and not check(released, "paid new recipe actually released through normal picker"):
		return
	# One bounded postgame window includes ordinary synchronous persistence and
	# presentation callbacks. Observations do not attribute elapsed time to save.
	var outro_began: int = Time.get_ticks_msec()
	var outro_frames: int = 0
	var outro_next_progress: int = outro_began + HUMAN_PROGRESS_MS
	var outro_milestone: String = "%s:%s:%d" % [app._result_recorded,
		not app.season.physical.pending.is_empty(), lab._match_presentation_director.mode]
	_human_diagnostic(lab, "outro_started", gameplay_began, outro_began, outro_frames)
	for _frame in range(780):
		if Time.get_ticks_msec() - outro_began >= (HUMAN_TWO_OUTRO_MS if stage == "human2" else HUMAN_OUTRO_MS):
			break
		await get_tree().physics_frame
		outro_frames += 1
		var observed: String = "%s:%s:%d" % [app._result_recorded,
			not app.season.physical.pending.is_empty(), lab._match_presentation_director.mode]
		if observed != outro_milestone or Time.get_ticks_msec() >= outro_next_progress:
			_human_diagnostic(lab, "outro_milestone" if observed != outro_milestone else "outro_progress",
				gameplay_began, outro_began, outro_frames)
			outro_milestone = observed
			outro_next_progress = Time.get_ticks_msec() + HUMAN_PROGRESS_MS
		if app._result_recorded and lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD:
			break
	_human_diagnostic(lab, "outro_terminal", gameplay_began, outro_began, outro_frames)
	check(app._result_recorded and lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD
		and not app.round_ui._working
		and app.season.player_results.size() == expected
		and not app.season.physical.pending.is_empty(), "real outro retains human evidence without partial rewards")
	check(Journal.write_new(root.path_join(stage + ".human.json"), {
		"pending": app.season.physical.pending, "paid_recipe_released": released,
		"score": lab._match_state.score_label()}), "retain genuine pending human evidence")
	# Intentionally stop at the persisted outro. Never call Continue here: one stage = one game.


func _human_diagnostic(lab: PitchBatLab, event: String, gameplay_began: int,
	outro_began: int = 0, outro_frames: int = 0) -> void:
	# Observation only. No game, proof, clock, save or authority mutation.
	var state: MatchState = lab._match_state
	var now: int = Time.get_ticks_msec()
	print("EXPANDED_LIVE_HUMAN ", JSON.stringify({
		"event": event, "stage": stage, "stage_wall_ms": now - began,
		"gameplay_wall_ms": now - gameplay_began if gameplay_began > 0 else 0,
		"phase": MatchState.Phase.keys()[state.phase], "inning": state.inning,
		"top_half": state.top_half, "outs": state.outs, "balls": state.balls,
		"strikes": state.strikes, "score": state.score_label(),
		"plate_appearance": state.plate_appearance_number, "throw_number": lab._throw_number,
		"batter_confirmation": lab._awaiting_batter_confirm,
		"release_active": lab._release_controller.active,
		"presentation_mode": lab._match_presentation_director.mode,
		"result_recorded": app._result_recorded,
		"pending_human": not app.season.physical.pending.is_empty(),
		"outro_wall_ms": now - outro_began if outro_began > 0 else 0,
		"outro_frames": outro_frames,
		"cadence_state": lab._at_bat_cadence.state if lab._at_bat_cadence != null else -1,
		"cadence_elapsed_seconds": lab._at_bat_cadence.elapsed_seconds if lab._at_bat_cadence != null else -1.0,
		"cadence_hold_seconds": lab._at_bat_cadence.active_hold_seconds if lab._at_bat_cadence != null else -1.0,
		"home_run_pending": lab._home_run.presentation_pending(lab)
	}))


func _owned_starter(team: TeamMatchState) -> bool:
	var pitcher: PlayerDefinition = team.current_pitcher().definition
	var profile: Dictionary = app.season.build.player(String(pitcher.id))
	if not check(not profile.is_empty() and pitcher.starting_pitches.size() == profile.active.size(),
		"own starter materializes exact owned repertoire size"):
		return false
	for index in range(profile.active.size()):
		var pitch: PitchDefinition = pitcher.starting_pitches[index]
		if not check(String(pitch.id) == profile.active[index]
			and pitch.mastery_level == int(profile.mastery[profile.active[index]]),
			"own starter materializes exact recipe and mastery"):
			return false
	if stage == "human2":
		return check(String(pitcher.id) == receipt.player and profile.active.has(receipt.recipe)
			and profile.mastery.get(receipt.recipe) == receipt.mastery,
			"paid player, new recipe and retained mastery are in actual human starter")
	return true


func _ai() -> void:
	var preparation_began: int = Time.get_ticks_msec()
	_ai_timing("preparation_started", preparation_began)
	var expected_round: int = 0 if stage in ["ai1", "ai2"] else 1
	var expected_reports: int = 0 if stage in ["ai1", "ai3"] else 1
	if not check(app.season.player_results.size() == expected_round
		and app.season.physical.pending.get("reports", []).size() == expected_reports,
		"one exact unaccepted worker frontier"):
		return
	var projection: Dictionary = SeasonRoundSettlement.project(app.season)
	if not check(projection.has("fixture"), "exact pending projection needs one AI fixture"):
		return
	worker = PhysicalRoundProcess.new()
	add_child(worker)
	if not check(worker.configure_physical_test(_capture), "strict retained one-worker transport; no fallback"):
		return
	worker.finished.connect(func(value: Dictionary) -> void: returned = value.duplicate(true))
	worker.failed.connect(func(reason: String) -> void: worker_error = reason)
	if not check(worker.start(app.season), "ordinary same-binary worker starts"):
		return
	if not check(worker._pid > 0 and worker.running, "actual positive worker PID; no in-process substitute"):
		return
	_ai_timing("worker_launched", preparation_began)
	if not check(Time.get_ticks_msec() - preparation_began <= AI_PREPARATION_MS,
		"AI projection and launch within separate budget"):
		worker.cancel()
		return
	var worker_began: int = Time.get_ticks_msec()
	while worker.running and Time.get_ticks_msec() - worker_began < AI_WORKER_MS:
		await get_tree().process_frame
	_ai_timing("worker_wait_complete", worker_began)
	if worker.running:
		worker.cancel()
	if not check(Time.get_ticks_msec() - worker_began <= AI_WORKER_MS
		and not returned.is_empty() and worker_error.is_empty(), "one validated worker completion within bound"):
		return
	var save_began: int = Time.get_ticks_msec()
	_ai_timing("report_checkpoint_started", save_began)
	var row: Dictionary = {"fixture": int(projection.fixture.id),
		"request": SeasonPhysicalFixtures.request_key(projection.candidate, projection.fixture), "report": returned}
	if not check(Journal.write_new(root.path_join(stage + ".report.json"), row), "retain exact validated report"):
		return
	if not _verify_transport_bytes(projection):
		return
	app.season.physical.pending.reports.append(row)
	check(SeasonSave.save(app.season), "checkpoint report without launching another game")
	_ai_timing("report_checkpoint_complete", save_began)
	check(Time.get_ticks_msec() - save_began <= AI_SAVE_MS, "AI report checkpoint within separate budget")


func _capture(context: Dictionary) -> bool:
	captures += 1
	var saved: bool = Journal.write_new(root.path_join("%s.worker-%d.json" % [stage, captures]), context)
	if saved:
		transport_captures.append(context.duplicate(true))
	return saved


func _publish() -> void:
	var projection: Dictionary = SeasonRoundSettlement.project(app.season)
	if not check(not projection.has("error") and not projection.has("fixture")
		and app.season.physical.pending.get("reports", []).size() == 2, "complete round; publication launches zero games"):
		return
	if not check(app.round_ui.configure_physical_test(_capture), "strict publication capture"):
		return
	app.round_ui.resume()
	var count: int = 1 if stage == "publish1" else 2
	check(not app.round_ui._working and not app.round_ui.process_runner.running
		and app.season.physical.pending.is_empty() and app.season.player_results.size() == count
		and app.season.results.size() == count * 3 and app.season.physical.reports.size() == count * 2,
		"atomic three-game round settlement")
	check(app.season.build._bank.view().rewards.size() == count, "human reward exactly once per earned round")
	for club: Dictionary in app.season.opponents.clubs.values():
		check(club.build._bank.view().rewards.size() == count, "opponent reward exactly once")


func _buy() -> void:
	if not check(app.season.player_results.size() == 1 and app.season.physical.pending.is_empty(),
		"first round genuinely earned before shopping"):
		return
	app.open_shop()
	var build: SeasonBuild = app.season.build
	for offer: String in build._visit.offers:
		var item: String = build._visit.offers[offer]
		var recipe: String = item.trim_prefix("lesson.")
		if recipe not in NEW_IDS:
			continue
		for target: Dictionary in build.targets(item):
			var index: int = app.season.teams[0].roster.find(target.player)
			if index < 0:
				continue
			var cash: int = build.cash()
			var command: Dictionary = {"id": "live-paid:%d" % build.revision(), "rev": build.revision(),
				"op": "buy", "offer": offer, "mode": "use", "player": target.player,
				"pitch": target.pitch, "replace": target.replace}
			if not build.preview(command).ok:
				continue
			if not check(app.commit_shop(command), "ordinary paid generated-stock purchase"):
				return
			check(app.season.build.cash() == cash - ExpandedSeasonCatalog.lesson_price(recipe), "exact cash debit")
			receipt["recipe"] = recipe
			receipt["player"] = target.player
			receipt["mastery"] = app.season.build.player(target.player).mastery[recipe]
			app.select_starter(index)
			check(app.season.build.player(target.player).active.has(recipe), "owned recipe active on next starter")
			return
	check(false, "first generated shop lacks affordable new recipe; no stock injection or grants; retain failed root")


func _complete() -> void:
	var replay_began: int = Time.get_ticks_msec()
	if stage != "init":
		_ai_timing("cold_replay_started", replay_began)
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season)),
		"cold disk replay equals every retained ledger and receipt"):
		return
	if not check(FileAccess.get_sha256(root.path_join("prior.json")) == receipt.prior, "prior club bytes unchanged"):
		return
	if receipt.has("recipe"):
		if not check(cold.build.player(receipt.player).active.has(receipt.recipe)
			and cold.build.player(receipt.player).mastery.get(receipt.recipe) == receipt.mastery,
			"paid ownership and exact mastery survive cold restore"):
			return
	if stage.begins_with("ai"):
		_ai_timing("cold_replay_verified", replay_began)
		if not check(Time.get_ticks_msec() - replay_began <= AI_REPLAY_MS, "AI cold replay within separate budget"):
			return
	if stage == "human2" or stage.begins_with("publish") or stage == "buy":
		_ai_timing("cold_replay_verified", replay_began)
		if not check(Time.get_ticks_msec() - replay_began <= LATER_REPLAY_MS, "later-stage cold replay within separate360s budget"):
			return
	var value: Dictionary = receipt.duplicate(true)
	value.merge({"stage": stage, "profile": FileAccess.get_sha256(PROFILE),
		"test": FileAccess.get_sha256(SELF), "catalog": ExpandedSeasonCatalog.signature(),
		"save": FileAccess.get_sha256(ExpandedSeasonUI.SAVE_PATH),
		"snapshot": SeasonSave.snapshot(cold), "checks": checks}, true)
	check(Journal.write_new(root.path_join(stage + ".complete.json"), value), "immutable completed-stage boundary")


func _ai_timing(event: String, phase_began: int) -> void:
	var now: int = Time.get_ticks_msec()
	print("EXPANDED_AI_DIAGNOSTIC ", JSON.stringify({"stage": stage,
		"event": event, "stage_wall_ms": now - began,
		"phase_wall_ms": now - phase_began,
		"worker_running": is_instance_valid(worker) and worker.running}))


func _transport_read(path: String) -> Variant:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_length() > 8 * 1024 * 1024:
		file.close()
		return null
	var parser: JSON = JSON.new()
	var error: Error = parser.parse(file.get_as_text())
	file.close()
	return parser.data if error == OK else null


func _verify_transport_bytes(projection: Dictionary) -> bool:
	if not check(transport_captures.size() == 2, "exactly two immutable worker captures for native transport"):
		return false
	var first: Dictionary = transport_captures[0]
	var terminal: Dictionary = transport_captures[1]
	var token: String = str(first.get("token", ""))
	var token_ok: bool = token.length() == 32
	for character: String in token:
		token_ok = token_ok and "0123456789abcdef".contains(character)
	var folder: String = OS.get_user_data_dir().path_join("physical-jobs").path_join(token)
	var request_key: String = SeasonPhysicalFixtures.request_key(projection.candidate, projection.fixture)
	if not check(token_ok and first.get("stage") == "job_started"
		and first.get("outcome") == "running" and first.get("exit_code") == -1
		and first.get("kill_error") == 0 and first.get("reason") == ""
		and terminal.get("stage") == "job_terminal" and terminal.get("outcome") == "finished"
		and terminal.get("exit_code") == 0 and terminal.get("kill_error") == 0
		and terminal.get("child_running") == false and terminal.get("reason") == ""
		and first.get("pid", 0) > 0 and terminal.get("pid") == first.pid
		and first.get("token") == token and terminal.get("token") == token
		and first.get("folder") == folder and terminal.get("folder") == folder
		and worker._folder == folder and first.get("request_key") == request_key
		and terminal.get("request_key") == request_key
		and ClubCareer.same(first.get("fixture"), projection.fixture)
		and ClubCareer.same(terminal.get("fixture"), projection.fixture),
		"native transport identities match genuine successful retained worker"):
		return false
	var response_path: String = folder.path_join("response.json")
	var request_path: String = folder.path_join("request.json")
	var report_path: String = root.path_join(stage + ".report.json")
	var response_sha: String = FileAccess.get_sha256(response_path)
	var request_sha: String = FileAccess.get_sha256(request_path)
	var report_sha: String = FileAccess.get_sha256(report_path)
	var response: Variant = _transport_read(response_path)
	var request: Variant = _transport_read(request_path)
	if not check(response is Dictionary and request is Dictionary
		and SeasonOwnership._keys(response, ["fixture", "report", "request", "token", "version"])
		and response.version == 1 and request.version == 11
		and response.fixture == int(projection.fixture.id) and request.fixture == response.fixture
		and response.token == token and request.token == token
		and response.request == request_key and request.request == request_key
		and response.report is Dictionary, "exact native response and request headers"):
		return false
	var wrapper: Dictionary = {"fixture": int(projection.fixture.id),
		"request": request_key, "report": response.report.duplicate(true)}
	var encoded: String = JSON.stringify(wrapper, "", true, true)
	var expected: PackedByteArray = encoded.to_utf8_buffer()
	var captured: PackedByteArray = FileAccess.get_file_as_bytes(report_path)
	if not check(expected == captured and encoded.sha256_text() == report_sha
		and FileAccess.get_sha256(response_path) == response_sha
		and FileAccess.get_sha256(request_path) == request_sha
		and FileAccess.get_sha256(report_path) == report_sha,
		"entire native wrapper bytes exact and immutable; no float tolerance"):
		return false
	var attestation: Dictionary = {"schema": 1, "method": "godot-native-response-wrapper-v1",
		"stage": stage, "token": token, "fixture": int(projection.fixture.id), "request": request_key,
		"request_path": request_path, "response_path": response_path, "report_path": report_path,
		"request_sha256": request_sha, "response_sha256": response_sha,
		"report_sha256": report_sha, "expected_wrapper_sha256": encoded.sha256_text(),
		"expected_bytes": expected.size(), "report_bytes": captured.size(),
		"exact_bytes_equal": true, "float_tolerance_used": false,
		"engine_version": str(Engine.get_version_info().string),
		"test_sha256": FileAccess.get_sha256(SELF)}
	return check(Journal.write_new(root.path_join(stage + ".transport.json"), attestation),
		"immutable exact native transport attestation written before pending save")

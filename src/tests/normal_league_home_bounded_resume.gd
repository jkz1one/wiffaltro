extends "res://src/tests/normal_league_home_physical_probe.gd"
## Explicit one-step continuation. No Dynasty owner and no synthesized game evidence.
var step: String = ""
var returned_report: Dictionary = {}
var worker_error: String = ""
func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--normal-home-resume"):
		print("NORMAL93_RESUME_PREPARED no_games=true no_save_writes=true")
		get_tree().quit()
		return
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--resume-root="): root = arg.trim_prefix("--resume-root=")
		if arg.begins_with("--resume-step="): step = arg.trim_prefix("--resume-step=")
	var data: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT")
	var clock_ok: bool = Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0 and not get_tree().paused \
		and ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics"
	for arg: String in OS.get_cmdline_args(): clock_ok = clock_ok and not arg.begins_with("--fixed-fps")
	if not _require(StadiumNpcPublicRuntime.source_qualified() and clock_ok and step in ["human", "ai", "publish"]
		and OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") == "1", "qualified exact source ordinary clock explicit step and launcher locks"):
		get_tree().quit(2)
		return
	if not _require(root.is_absolute_path() and root == root.simplify_path() and data == root.get_base_dir().path_join("data")
		and OS.get_environment("XDG_DATA_HOME") == data and OS.get_user_data_dir().begins_with(data + "/")
		and FileAccess.file_exists(root.path_join("season.json")) and not FileAccess.file_exists(root.path_join("season.json.tmp"))
		and not DirAccess.dir_exists_absolute(root.path_join("season.json.tmp"))
		and not FileAccess.file_exists(root.path_join("season.json.dynasty-owner")), "isolated existing ordinary save without uncertain temporary write or owner"):
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	path = SeasonSave.path
	PitchBatLabSettings.path = root.path_join("isolated-settings.cfg")
	if not _require(Journal.ready(root, true) and not FileAccess.file_exists(root.path_join("resume-boundary.next.json")), "all prior intents completed; uncertain work cannot rerun"):
		get_tree().quit(2)
		return
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(root.path_join("resume-boundary.json")))
	var cold: SeasonState = SeasonSave.restore()
	if not _receipt_valid(receipt, cold):
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
	if _require(app.season != null and ClubCareer.same(SeasonSave.snapshot(app.season), SeasonSave.snapshot(cold)), "main restores exact retained frontier"):
		await _step(app)
	app.free()
	print("NORMAL93_BOUNDED_RESULT step=%s checks=%d failures=%d new_human_games=%d" % [step, checks, failures, physical_games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

func _receipt_valid(receipt: Variant, season: SeasonState) -> bool:
	if not _require(receipt is Dictionary and SeasonOwnership._keys(receipt, ["version", "kind", "source_profile", "save_sha256", "seed", "home", "results", "reports", "pending_reports", "pending"]), "exact bounded receipt schema"): return false
	if not _require(season != null and season.career != null and season.league_career
		and season.career.current == 1 and season.career.runs.size() == 1
		and season._league_home_context.get("format") == 93 and season._dynasty_career_session.is_empty()
		and not SeasonSave.dynasty_owner_bound() and season.league_rules.league == "dugout" and season.league_rules.tier == 0
		and Bound.modern_origin(season.home_property), "existing genuine ordinary modern Dugout93 authority"): return false
	var count: int = season.player_results.size()
	var pending: Dictionary = season.physical.pending
	return _require(receipt.version == 1 and receipt.kind in ["human", "ai", "publish"]
		and receipt.source_profile == FileAccess.get_sha256(PROFILE_PATH) and receipt.save_sha256 == FileAccess.get_sha256(SeasonSave.path)
		and receipt.seed == season.season_seed and receipt.home == StadiumLayoutSnapshot.key(season.home_property)
		and count in [0, 1, 2] and receipt.results == count and receipt.reports == count * 2
		and season.physical.reports.size() == count * 2 and receipt.pending == (not pending.is_empty())
		and receipt.pending_reports == pending.get("reports", []).size()
		and (pending.is_empty() or (count < 2 and pending.human[0] == count * 3 and pending.reports.size() <= 2))
		and (count == 2 or season.pending_fixture().id == count * 3), "receipt source and save identity exact; natural frontier retained")

func _step(app: SeasonApp) -> void:
	var season: SeasonState = app.season
	if step == "human":
		if not _require(season.player_results.size() == 1 and season.physical.pending.is_empty(), "human resume allows only unplayed home3 after published away round"): return
		stop_after_human = true
		await _play_rounds(app)
		return
	if not _require(not season.physical.pending.is_empty(), "AI/publication requires already accepted human; never replays it"): return
	var projection: Dictionary = SeasonRoundSettlement.project(season)
	if not _require(not projection.has("error"), "retained genuine pending projection validates"): return
	if step == "publish":
		if not _require(not projection.has("fixture") and season.physical.pending.reports.size() == 2, "publish is zero-game complete round only"): return
		if not _begin_step(season, "publish", season.pending_fixture(), "zero-game-publication"): return
		app.round_ui.resume()
		if _require(not app.round_ui._working and app.season.physical.pending.is_empty(), "existing round controller atomically publishes without starting any worker"):
			_boundary(app.season, "publish")
		return
	if not _require(projection.has("fixture") and season.physical.pending.reports.size() < 2, "AI step selects only next unaccepted fixture"): return
	var fixture: Dictionary = projection.fixture
	var request: String = SeasonPhysicalFixtures.request_key(projection.candidate, fixture)
	if not _begin_step(season, "ai", fixture, request): return
	var worker: PhysicalRoundProcess = PhysicalRoundProcess.new()
	add_child(worker)
	worker.finished.connect(func(report: Dictionary) -> void: returned_report = report.duplicate(true))
	worker.failed.connect(func(reason: String) -> void: worker_error = reason)
	if not _require(worker.start(season), "existing ordinary transport1 starts exactly one natural AI game"):
		worker.free()
		return
	while worker.running: await get_tree().process_frame
	if not _require(worker_error.is_empty() and not returned_report.is_empty(), "one AI job completes with validated report: " + worker_error):
		worker.free()
		return
	# Retain the genuine validated worker report before any save attempt.
	var row: Dictionary = {"fixture": int(fixture.id), "request": request, "report": returned_report}
	if not _write("raw-ai-%d.json" % fixture.id, row):
		worker.free()
		return
	season.physical.pending.reports.append(row)
	if _require(SeasonSave.save(season), "exact normal pending report checkpoint saves: " + SeasonSave.last_error):
		_boundary(season, "ai")
	worker.free()

extends "res://src/tests/stadium_lighting_kit_round_reuse_test.gd"
## Test-only actual managed automatic inputs; no authored launch or score/phase edits.
## Requires separately approved long-engine slot. This source has not been run.
var _game_app: SeasonApp
var _automation: MatchAutomation
var _automation_pre_ready: bool = false
var _starts: int = 0
var _retention_dir: String = ""
var _retention_hashes: Dictionary = {}
var _retention_errors: Array[String] = []
var _result_sha: String = ""


func _configure_automation(node: Node) -> void:
	if not node is PitchBatLab:
		return
	_starts += 1
	var lab: PitchBatLab = node
	_automation_pre_ready = _starts == 1 and not lab.is_node_ready() and lab._automation == null
	if not _automation_pre_ready:
		return
	_automation = MatchAutomation.new()
	_automation.seed = SeasonPhysicalFixtures.seed_for(
		_game_app.season, _game_app.season.pending_fixture()
	)
	_automation.presentation_enabled = false
	lab._automation = _automation


func _exercise_settled(app: SeasonApp) -> void:
	_game_app = app
	var output: String = ""
	var source_manifest: String = ""
	var stop_after_checkpoint: bool = false
	var required_manifest_sha: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--full-game-output="):
			output = argument.trim_prefix("--full-game-output=")
		if argument.begins_with("--executed-source-manifest="):
			source_manifest = argument.trim_prefix("--executed-source-manifest=")
		if argument.begins_with("--executed-source-sha="):
			required_manifest_sha = argument.trim_prefix("--executed-source-sha=")
		if argument == "--stop-after-human-checkpoint":
			stop_after_checkpoint = true
	if not _check(
		(
			output.is_absolute_path()
			and not FileAccess.file_exists(output)
			and not FileAccess.file_exists(output + ".tmp")
		),
		"fresh explicit complete-game evidence output"
	):
		return
	if not _check(
		source_manifest.is_absolute_path() and FileAccess.file_exists(source_manifest),
		"explicit executed-source manifest exists"
	):
		return
	var source_manifest_sha: String = FileAccess.get_sha256(source_manifest)
	if not _check(
		required_manifest_sha.length() == 64 and source_manifest_sha == required_manifest_sha,
		"exact frozen executed-source manifest retained"
	):
		return
	_retention_dir = output + ".raw"
	if not _check(
		(
			not DirAccess.dir_exists_absolute(_retention_dir)
			and not FileAccess.file_exists(_retention_dir)
		),
		"fresh write-once raw evidence directory"
	):
		return
	if not _check(
		DirAccess.make_dir_recursive_absolute(_retention_dir) == OK,
		"create isolated raw evidence directory"
	):
		return
	if not _check(
		Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,
		"ordinary unchanged60Hz integration"
	):
		return
	await _settled_initial_snapshot(
		app, output, source_manifest, stop_after_checkpoint, source_manifest_sha
	)


func _settled_initial_snapshot(
	app: SeasonApp, output: String, source_manifest: String, stop_after_checkpoint: bool,
	source_manifest_sha: String
) -> void:
	var initial: Dictionary = SeasonSave.snapshot(app.season)
	var scheduled: Dictionary = app.season.pending_fixture().duplicate(true)
	var expected: Dictionary = StadiumLayoutSnapshot.for_fixture(app.season, scheduled)
	var request: String = StadiumSurfaceNightHumanEvidence.request_key(app.season, scheduled)
	if not _retain_bytes_once(
		"executed-source-manifest.json", FileAccess.get_file_as_bytes(source_manifest)
	):
		return
	if not _check(
		_retention_hashes["executed-source-manifest.json"] == source_manifest_sha,
		"retained manifest bytes match exact supplied digest"
	):
		return
	if not _retain_bytes_once(
		"initial-save-original.json", FileAccess.get_file_as_bytes(SeasonSave.path)
	):
		return
	if not _retain_once(
		"initial-context.json",
		{
			"schema": "kit36-terminal-retention-v1",
			"source_manifest_sha256": source_manifest_sha,
			"source_manifest_path": source_manifest,
			"fixture": scheduled,
			"request": request,
			"seed": SeasonPhysicalFixtures.seed_for(app.season, scheduled),
			"original_receipt": expected,
			"initial_save_sha256": _retention_hashes["initial-save-original.json"],
			"source_round_reuse": _reuse_result.duplicate(true),
			"input": "ordinary pre-ready MatchAutomation",
			"authentic_earned_history": false,
			"synthetic_registry": true
		}
	):
		return
	app.child_entered_tree.connect(_configure_automation)
	_stage("actual_public_play_season_game", "begin", {"request": request, "fixture": scheduled})
	app.play_season_game()
	_stage(
		"actual_public_play_season_game",
		"end",
		{"lab_created": is_instance_valid(app.lab), "notice": app.notice}
	)
	var lab: PitchBatLab = app.lab
	if not _check(
		(
			is_instance_valid(lab)
			and _automation_pre_ready
			and _starts == 1
			and lab._automation == _automation
			and lab._managed_match
			and lab._player_home
			and StadiumSurfaceNightRuntime.installed_bound(lab, expected)
		),
		"ordinary public pending-home starts exact fixture36 with pre-ready test input automation"
	):
		return
	if not _check(
		(
			ClubCareer.same(app.season.pending_fixture(), scheduled)
			and StadiumSurfaceNightHumanEvidence.request_key(app.season, scheduled) == request
			and ClubCareer.same(lab._match_state.stadium, expected)
		),
		"public pregame commit preserves exact request and complete original receipt"
	):
		return
	await _settled_checkpoint_bytes(
		app, output, stop_after_checkpoint, source_manifest_sha, initial, scheduled, expected,
		request, lab
	)


func _settled_checkpoint_bytes(
	app: SeasonApp, output: String, stop_after_checkpoint: bool, source_manifest_sha: String,
	initial: Dictionary, scheduled: Dictionary, expected: Dictionary, request: String,
	lab: PitchBatLab
) -> void:
	if not _retain_bytes_once(
		"post-pregame-save-original.json", FileAccess.get_file_as_bytes(SeasonSave.path)
	):
		return
	_stage("actual_managed_game", "begin")
	await _settled_natural_game_loop(
		app, output, stop_after_checkpoint, source_manifest_sha, initial, scheduled, expected,
		request, lab
	)


func _settled_natural_game_loop(
	app: SeasonApp, output: String, stop_after_checkpoint: bool, source_manifest_sha: String,
	initial: Dictionary, scheduled: Dictionary, expected: Dictionary, request: String,
	lab: PitchBatLab
) -> void:
	var began: int = Time.get_ticks_usec()
	var ticks: int = 0
	for frame in range(300000):
		if not is_instance_valid(lab) or app.lab != lab or lab._automation != _automation:
			_check(false, "actual original managed game disappeared before terminal play")
			return
		if lab._match_state.phase == MatchState.Phase.GAME_END:
			break
		await get_tree().physics_frame
		ticks += 1
		if frame % 120 == 0:
			print(
				"KIT_FULL_GAME36_PROGRESS ",
				JSON.stringify(
					{
						"ticks": ticks,
						"wall_ms": (Time.get_ticks_usec() - began) / 1000.0,
						"inning": lab._match_state.inning,
						"top": lab._match_state.top_half,
						"plays": lab._play_records.size(),
						"score": [lab._match_state.away_team.runs, lab._match_state.home_team.runs]
					}
				)
			)
	if not _check(
		lab._match_state.phase == MatchState.Phase.GAME_END,
		"natural complete managed game reaches terminal phase"
	):
		return
	var motion_wall_us: int = Time.get_ticks_usec() - began
	_stage(
		"actual_managed_game",
		"end",
		{
			"physics_ticks": ticks,
			"motion_wall_us": motion_wall_us,
			"plays": lab._play_records.size(),
			"score": [lab._match_state.away_team.runs, lab._match_state.home_team.runs]
		}
	)
	_new_simulated_games += 1
	# Preserve observations before any public wrapper proof can refuse or stall.
	# Raw core is diagnostic only, never substituted for a valid public report.
	_retain_once(
		"terminal-state-before-proof.json",
		{
			"natural_game_end": true,
			"phase": lab._match_state.phase,
			"physics_ticks": ticks,
			"wall_ms": (Time.get_ticks_usec() - began) / 1000.0,
			"fixture": scheduled,
			"request": request,
			"seed": _automation.seed,
			"score": [lab._match_state.away_team.runs, lab._match_state.home_team.runs],
			"play_count": lab._play_records.size(),
			"source_manifest_sha256": source_manifest_sha
		}
	)
	_retain_once("core-raw.json", PhysicalMatchReport._capture_core(lab))
	_retain_once("contacts-raw.json", PhysicalStadiumContacts.capture(lab._play_records))
	_retain_once("original-receipt-raw.json", lab._match_state.stadium)
	_retain_once(
		"current-paid-ledger-raw.json",
		lab._stadium_ledger.to_data() if lab._stadium_ledger != null else {}
	)
	if not _check(
		_retention_errors.is_empty(), "raw terminal observations preserved before public validators"
	):
		return
	_stage("public_terminal_captures", "begin")
	print(
		"KIT_FULL_GAME36_CAPTURE_BEGIN ",
		JSON.stringify({"request": request, "raw_directory": _retention_dir})
	)
	var capture_started: int = Time.get_ticks_usec()
	var report: Dictionary = PhysicalMatchReport.capture(lab)
	var report_capture_us: int = Time.get_ticks_usec() - capture_started
	_retain_once("public-report-return.json", report)  # Preserve{} as an actual refusal.
	capture_started = Time.get_ticks_usec()
	var human: Dictionary = StadiumSurfaceNightHumanEvidence.capture(lab, app.season)
	var human_capture_us: int = Time.get_ticks_usec() - capture_started
	_retain_once("public-human-return.json", human)
	_retain_once(
		"capture-timings.json", {"report_us": report_capture_us, "human_us": human_capture_us}
	)
	_stage(
		"public_terminal_captures",
		"end",
		{"report_us": report_capture_us, "human_us": human_capture_us}
	)
	print(
		"KIT_FULL_GAME36_CAPTURE_END ",
		JSON.stringify({"report_us": report_capture_us, "human_us": human_capture_us})
	)
	if not _check(
		_retention_errors.is_empty(), "all raw observations and actual capture returns retained"
	):
		return
	_stage("terminal_positive_and_negative_validation", "begin")
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	if not _check(
		(
			report.get("version") == 24
			and report.get("property", {}).get("version") == 36
			and PhysicalMatchReport.valid(report)
			and StadiumSurfaceNightReport.matches(report, expected, paid)
			and not human.is_empty()
			and StadiumSurfaceNightHumanEvidence.valid(human)
			and human.request == request
		),
		"actual complete report24/property36 and managed HumanEvidence validate"
	):
		return
	_check(
		(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true)))
			and StadiumSurfaceNightHumanEvidence.valid(
				JSON.parse_string(JSON.stringify(human, "", true, true))
			)
		),
		"complete actual evidence survives full-precision JSON replay"
	)
	var bad: Dictionary = report.duplicate(true)
	bad.property.geometry = "0".repeat(64)
	_check(
		not PhysicalMatchReport.valid(bad), "complete report rejects original geometry substitution"
	)
	bad = human.duplicate(true)
	bad.property.layout.lighting_kits[0].copy = "foreign:copy"
	_check(
		not StadiumSurfaceNightHumanEvidence.valid(bad),
		"actual human evidence rejects foreign paid kit identity"
	)
	_stage("terminal_positive_and_negative_validation", "end")
	if not failures.is_empty():
		return
	var result: Dictionary = {
		"schema": "kit-fixture36-actual-managed-round-v1",
		"initial_season": initial,
		"fixture": scheduled,
		"request": request,
		"report": report,
		"human_evidence": human,
		"source_round_reuse": _reuse_result.duplicate(true),
		"actual_managed_games": 1,
		"actual_new_offscreen_games": 0,
		"physics_ticks": ticks,
		"managed_motion_wall_ms": motion_wall_us / 1000.0,
		"observer_through_validation_wall_ms": (Time.get_ticks_usec() - began) / 1000.0,
		"input": "ordinary MatchAutomation assigned before ready; not manual human input",
		"outro_button_coverage": false,
		"offscreen_resume_mode":
		"same-session ordinary resume after separate cold-read equality proof",
		"funding": "retained synthetic41-season career; not authentic earned progression",
		"optical_qualification": false,
		"source_manifest_sha256": source_manifest_sha,
		"raw_directory": _retention_dir,
		"raw_hashes": _retention_hashes.duplicate(true)
	}
	await _settled_full_result(app, output, stop_after_checkpoint, human, result)


func _settled_full_result(
	app: SeasonApp, output: String, stop_after_checkpoint: bool, human: Dictionary,
	result: Dictionary
) -> void:
	if not _write_full_result(output, result):
		return
	# Automation intentionally skips OUTRO_HOLD. Exercise the unchanged automatic
	# SeasonApp commit path, not a fabricated finish_game button state.
	_stage("ordinary_automatic_human_commit", "begin")
	app.set_process(true)
	for frame in range(4):
		await get_tree().process_frame
		if app._result_recorded:
			break
	app.set_process(false)
	_stage(
		"ordinary_automatic_human_commit",
		"end",
		{"recorded": app._result_recorded, "notice": app.notice}
	)
	if not _check(
		(
			app._result_recorded
			and not app.season.physical.pending.is_empty()
			and app.season.physical.pending.human.size() == 18
			and ClubCareer.same(app.season.physical.pending.human[17], human)
			and StadiumSurfaceNightHumanEvidence.pending_valid(
				app.season, app.season.physical.pending.human
			)
		),
		"unchanged SeasonApp auto-commit durably queues exact actual Night evidence"
	):
		return
	if not _retain_bytes_once(
		"pending-save-original.json", FileAccess.get_file_as_bytes(SeasonSave.path)
	):
		return
	_stage("durable_human_checkpoint_cold_restore", "begin")
	var pending_cold: SeasonState = SeasonSave.restore()
	_stage("durable_human_checkpoint_cold_restore", "end", {"restored": pending_cold != null})
	if not _check(
		(
			pending_cold != null
			and ClubCareer.same(SeasonSave.snapshot(pending_cold), SeasonSave.snapshot(app.season))
			and ClubCareer.same(pending_cold.physical.pending.human[17], human)
		),
		"actual Night human checkpoint is durably cold-restored before resume"
	):
		return
	result["pending_after_actual_commit"] = SeasonSave.snapshot(app.season)
	if not _write_full_result(output, result):
		return
	await _settled_checkpoint_stop(app, output, stop_after_checkpoint, result)


func _settled_checkpoint_stop(
	app: SeasonApp, output: String, stop_after_checkpoint: bool, result: Dictionary
) -> void:
	if stop_after_checkpoint:
		result["stopped_after_ordinary_durable_human_checkpoint"] = true
		result["pending_save_sha256"] = _retention_hashes["pending-save-original.json"]
		result["raw_hashes"] = _retention_hashes.duplicate(true)
		result["checks"] = checks
		result["failures"] = failures.duplicate()
		if not _write_full_result(output, result):
			return
		return  # Observer ends only after normal commit and verified cold restore.
	app.round_ui.process_jobs = false
	_stage("two_actual_offscreen_games_and_atomic_settlement", "begin")
	app.round_ui.resume()
	for frame in range(600000):
		if app.season.physical.pending.is_empty() or not app.round_ui._working:
			break
		await get_tree().physics_frame
		if frame % 1200 == 0:
			print(
				"KIT_FULL_GAME36_OFFSCREEN ",
				frame,
				" pending_reports=",
				app.season.physical.pending.get("reports", []).size()
			)
	if not _check(
		(
			app.season.results.size() == 6
			and app.season.player_results.size() == 2
			and app.season.physical.reports.size() == 4
			and app.season.physical.pending.is_empty()
		),
		"normal two actual offscreen fixtures and atomic second-round settlement"
	):
		return
	_stage(
		"two_actual_offscreen_games_and_atomic_settlement",
		"end",
		{
			"results": app.season.results.size(),
			"pending": not app.season.physical.pending.is_empty()
		}
	)
	if not _retain_bytes_once(
		"settled-save-original.json", FileAccess.get_file_as_bytes(SeasonSave.path)
	):
		return
	_stage("final_settlement_cold_restore", "begin")
	var cold: SeasonState = SeasonSave.restore()
	_stage("final_settlement_cold_restore", "end", {"restored": cold != null})
	_check(
		(
			cold != null
			and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season))
		),
		"complete actual Night round cold-restores without result edits"
	)
	_new_simulated_games += 2
	result.actual_new_offscreen_games = 2
	result["settled_season"] = SeasonSave.snapshot(app.season)
	result["raw_hashes"] = _retention_hashes.duplicate(true)
	result["checks"] = checks
	result["failures"] = failures.duplicate()
	if not _write_full_result(output, result):
		return


func _write_full_result(path: String, result: Dictionary) -> bool:
	# Mutable stage summary is atomically replaced; raw observations stay write-once.
	var exists: bool = FileAccess.file_exists(path)
	if not _check(
		(
			(not exists and _result_sha.is_empty())
			or (
				exists and not _result_sha.is_empty() and FileAccess.get_sha256(path) == _result_sha
			)
		),
		"result summary still belongs to this observer"
	):
		return false
	var temporary: String = path + ".tmp"
	if not _check(not FileAccess.file_exists(temporary), "fresh atomic result temporary path"):
		return false
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if not _check(file != null, "retain actual stage evidence at explicit output"):
		return false
	file.store_string(JSON.stringify(result, "", true, true))
	file.flush()
	var okay: bool = file.get_error() == OK
	file.close()
	if not _check(okay, "flush actual stage evidence without error"):
		return false
	if not _check(
		DirAccess.rename_absolute(temporary, path) == OK, "atomically publish actual stage summary"
	):
		return false
	_result_sha = FileAccess.get_sha256(path)
	return _check(_result_sha.length() == 64, "retain published summary hash")


func _retain_once(name: String, value: Variant) -> bool:
	return _retain_bytes_once(name, JSON.stringify(value, "", true, true).to_utf8_buffer())


func _retain_bytes_once(name: String, bytes: PackedByteArray) -> bool:
	if bytes.is_empty():
		_retention_errors.append("Empty or failed source read for " + name)
		_check(false, _retention_errors.back())
		return false
	var path: String = _retention_dir.path_join(name)
	if FileAccess.file_exists(path):
		_retention_errors.append("Refusing to overwrite " + name)
		_check(false, _retention_errors.back())
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_retention_errors.append("Cannot write " + name + ": " + str(FileAccess.get_open_error()))
		_check(false, _retention_errors.back())
		return false
	file.store_buffer(bytes)
	file.flush()
	var okay: bool = file.get_error() == OK
	file.close()
	if not okay:
		_retention_errors.append("Write failed for " + name)
		_check(false, _retention_errors.back())
		return false
	_retention_hashes[name] = FileAccess.get_sha256(path)
	return true

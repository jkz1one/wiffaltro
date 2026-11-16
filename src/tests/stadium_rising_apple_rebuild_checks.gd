class_name StadiumRisingAppleRebuildChecks
extends "res://src/tests/stadium_rising_apple_rebuild_checks_runtime_base.gd"


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_started_us = Time.get_ticks_usec()
	var selected: String = ""
	var bootstrap_path: String = ""
	var bootstrap_sha256: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rising-apple-phase="):
			if not selected.is_empty():
				return _setup_error("duplicate phase selector")
			selected = argument.trim_prefix("--rising-apple-phase=")
		elif argument.begins_with("--rising-apple-bootstrap="):
			if not bootstrap_path.is_empty():
				return _setup_error("duplicate bootstrap path")
			bootstrap_path = argument.trim_prefix("--rising-apple-bootstrap=")
		elif argument.begins_with("--rising-apple-bootstrap-sha256="):
			if not bootstrap_sha256.is_empty():
				return _setup_error("duplicate bootstrap hash")
			bootstrap_sha256 = argument.trim_prefix("--rising-apple-bootstrap-sha256=")
	if selected not in ["1", "2"]:
		return _setup_error("explicit --rising-apple-phase=1 or 2 is required")
	if selected == "2":
		return await _run_retirement(directory, bootstrap_path, bootstrap_sha256)
	return await _apple_phase_one_checks(directory, bootstrap_path, bootstrap_sha256)


func _apple_phase_one_checks(
	directory: String, bootstrap_path: String, bootstrap_sha256: String
) -> Dictionary:
	if not bootstrap_path.is_empty() or not bootstrap_sha256.is_empty():
		return _setup_error("phase 1 cannot consume a bootstrap")
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered bounded rising apple qualification has an explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		var started: int = Time.get_ticks_usec()
		_progression()
		_phase_counts.progression = _checks - before
		_time_phase("progression", started)
		before = _checks
		started = Time.get_ticks_usec()
		_ownership()
		_phase_counts.ownership = _checks - before
		_time_phase("ownership", started)
		if not _layout.is_empty() and not _snapshot.is_empty():
			before = _checks
			started = Time.get_ticks_usec()
			_fit_and_conflicts()
			_phase_counts.fit = _checks - before
			_time_phase("fit", started)
			before = _checks
			started = Time.get_ticks_usec()
			_detached_controls()
			_phase_counts.workshop_controls = _checks - before
			_time_phase("workshop_controls", started)
			_phase = "complete-source-held-rising-apple-parent"
			started = Time.get_ticks_usec()
			var model_root: Node3D = _world()
			before = _checks
			await StadiumRisingAppleGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_check(
				_model_checks == StadiumRisingAppleGeometryRebuildChecks.expected_checks(),
				"every complete rising apple geometry assertion is reached"
			)
			await _close_view()
			_time_phase("geometry", started)
			before = _checks
			started = Time.get_ticks_usec()
			await _terrain_matrix()
			_phase_counts.terrain_support = _checks - before
			_time_phase("terrain_support", started)
			before = _checks
			started = Time.get_ticks_usec()
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
			_time_phase("runtime_and_views", started)
	_phase = "completion"
	_check(
		(
			_images
			== [
				"rising-apple-overview.png", "rising-apple-overhead.png", "rising-apple-details.png"
			]
		),
		"exactly three native 1280 by 720 originals and zero completed games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumRisingAppleGeometryRebuildChecks.expected_checks()
	)
	_time_phase("total_before_evidence", _run_started_us)
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks": expected,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"synthetic_source_performance": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"physical_performance_claim": false,
		"gameplay_bonus_claim": false,
		"night_qualification_claim": false,
		"co4_grant_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumRisingAppleGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"inherited_paid_copies": _inherited,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"purchase_receipts": _receipts,
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"progression_cases": _progress_cases,
		"fit_cases": _fit_cases,
		"support_matrix": _support_matrix,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"runtime": _runtime,
		"synthetic_metrics": StadiumCareerProgress.metrics(_progress, _progress.size()),
		"capture_layout":
		(
			"one exact paid ST-047 at exclusive LANDMARK-A; second independently paid copy stored; "
			+ "ordinary reset and directly overhead reset originals plus actual confirmed-HR raised "
			+ "detail"
		),
		"motion_rule":
		(
			"No prediction or motion during deciding pitch/flight; one confirmed HR celebration; "
			+ "pause-aware; return before next pitch; foreign mutation fails closed"
		),
		"execution_phase": 1,
		"executed_checks": PHASE1_CHECKS,
		"carried_checks": 0,
		"cumulative_checks": PHASE1_CHECKS,
		"union_expected_checks": UNION_CHECKS,
		"phase_timings_ms": _phase_timings_ms,
		"lab_setup_timings": _lab_setup_timings
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var evidence_path: String = directory.path_join("rising-apple-rebuild.json")
	var file: FileAccess = FileAccess.open(evidence_path, FileAccess.WRITE)
	_check(file != null, "combined rising apple evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phase_counts}
	_check(
		_checks + 1 == expected and _phase_counts == EXPECTED_PHASE_CHECKS,
		"every bounded fixture assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.executed_checks = _checks
		payload.cumulative_checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		var write_error: Error = file.get_error()
		file.close()
		if write_error != OK:
			return _setup_error("phase 1 evidence could not fully write")
	if _failures == 0:
		var current_context: Dictionary = _source_context()
		if current_context.is_empty():
			return _setup_error("phase 1 exact source context is unavailable")
		var bootstrap: Dictionary = {
			"version": 2,
			"kind": "rising-apple-phase1-bootstrap",
			"carried_checks": PHASE1_CHECKS,
			"union_expected_checks": UNION_CHECKS,
			"phase1_evidence_sha256": FileAccess.get_sha256(evidence_path),
			"source_context": current_context,
			"seed": SEED,
			"credits": _credits,
			"progress": _progress,
			"ledger": _paid.to_data(),
			"paid_copy_ids": _copies,
			"inherited_paid_copies": _inherited,
			"empty_layout": _empty,
			"layout": _layout,
			"snapshot": _snapshot
		}
		if not _write_bounded(directory.path_join("rising-apple-bootstrap.json"), bootstrap):
			return _setup_error("phase 1 bootstrap could not fully write within 128 KiB")
	print(
		(
			(
				"RISING_APPLE_REBUILD phase=1 executed_checks=%d carried_checks=0 "
				+ "cumulative_checks=%d union_expected_checks=306 failures=%d model_checks=%d images=%d "
				+ "games=0"
			)
			% [_checks, _checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

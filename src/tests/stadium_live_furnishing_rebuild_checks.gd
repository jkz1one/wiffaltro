extends "res://src/tests/stadium_live_furnishing_rebuild_checks_scenario_base.gd"
func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered shared qualification with explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		before = _checks
		_detached_controls()
		_phase_counts.workshop_controls = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty():
			_phase = "bounded-source-geometry"
			var root: Node3D = _world()
			before = _checks
			await StadiumLiveFurnishingGeometryRebuildChecks.run(root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumLiveFurnishingGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumLiveFurnishingGeometryRebuildChecks.expected_checks(),
				"all finite source geometry assertions are reached"
			)
			await _close_view()
			before = _checks
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["live-furnishing-overview.png", "live-furnishing-details.png"],
		"exactly two readable native originals at most 1280 by 720 and zero games"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks":
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumLiveFurnishingGeometryRebuildChecks.expected_checks(),
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumLiveFurnishingGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"base26": _base26,
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"contact_cases": _contact_cases,
		"report_provenance": _report_cases,
		"physical_traversal": _physical,
		"route_cases": _route_cases,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"water_contract":
		(
			"fair minimum Double, preserve preearned Triple; foul Foul; terminal Home Run "
			+ "unchanged and no entry"
		),
		"capture_layout":
		"one installed-property overview and two native 640x720 close-up tiles in one 1280x720 original"
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"shared structured evidence remains finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("live-furnishing-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "shared live furnishing evidence opens")
	_operands = {
		"reached": _checks + 1,
		"expected":
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumLiveFurnishingGeometryRebuildChecks.expected_checks(),
		"phases": _phase_counts
	}
	_check(
		(
			(
				_checks + 1
				== (
					EXPECTED_NON_GEOMETRY_CHECKS
					+ StadiumLiveFurnishingGeometryRebuildChecks.expected_checks()
				)
			)
			and _phase_counts.get("ownership", 0) == 99
			and _phase_counts.get("workshop_controls", 0) == 4
			and _phase_counts.get("runtime_and_views", 0) == 100
		),
		"every bounded shared fixture assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "shared evidence fully writes")
		file.close()
	print(
		(
			(
				"LIVE_FURNISHING_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

extends "res://src/tests/stadium_owned_low_wall_test.gd"


## Test-only observer. Persists untouched evidence before the runner cleans up.
class DiagnosticRunner:
	extends PhysicalMatchRunner
	var last_count: int = -1
	var captured: Array[Dictionary] = []

	func _process(delta: float) -> void:
		if _running and is_instance_valid(_lab):
			if _lab._match_state.phase == MatchState.Phase.GAME_END:
				_dump("game_end")
			elif _lab._play_records.size() != last_count:
				last_count = _lab._play_records.size()
				var core: Dictionary = PhysicalMatchReport._capture_core(_lab)
				var contacts: Array = PhysicalStadiumContacts.capture(_lab._play_records)
				if not PhysicalStadiumContacts.valid(
					contacts, core.plays, _lab._match_state.stadium
				):
					_dump("first_invalid_contacts")
					_fail("Diagnostic stopped at first invalid contact evidence.")
					return
		super._process(delta)

	func _fail(reason: String) -> void:
		if is_instance_valid(_lab):
			_dump("runner_failure: " + reason)
		super._fail(reason)

	func _dump(label: String) -> void:
		var core: Dictionary = PhysicalMatchReport._capture_core(_lab)
		var contacts: Array = PhysicalStadiumContacts.capture(_lab._play_records)
		var snapshot: Dictionary = _lab._match_state.stadium
		var property: StadiumLowWallProperty = _lab.get_meta("stadium_property")
		var boundary: StadiumLowWallBoundaryRuntime = property.get_node("BoundaryGraph")
		var direct_candidate: Dictionary = core.duplicate(true)
		direct_candidate.version = PhysicalStadiumReport.VERSION
		direct_candidate.resolver = PhysicalStadiumReport.RESOLVER
		direct_candidate["property"] = StadiumLayoutSnapshot.normalized(snapshot)
		direct_candidate["surfaces"] = contacts.duplicate(true)
		var predicates: Dictionary = {
			"label": label,
			"elapsed": _elapsed,
			"phase": _lab._match_state.phase,
			"play_count": core.plays.size(),
			"core_version": core.get("version"),
			"snapshot_valid": StadiumLayoutSnapshot.valid(snapshot),
			"core_valid": PhysicalMatchReport.valid(core),
			"contacts_valid": PhysicalStadiumContacts.valid(contacts, core.plays, snapshot),
			"property_intact": property.props_intact(),
			"deep_boundary_intact": boundary.deep_intact(),
			"installed": StadiumLowWallRuntime.installed_bound(_lab, snapshot),
			"wrapper_shape": PhysicalStadiumReport._shape(direct_candidate),
			"direct_wrapper_valid": PhysicalMatchReport.valid(direct_candidate)
		}
		var evidence: Dictionary = {
			"label": label,
			"predicates": predicates,
			"core": core,
			"contacts": contacts,
			"snapshot": snapshot,
			"ledger": _lab._stadium_ledger.to_data(),
			"public_capture": PhysicalMatchReport.capture(_lab),
			"diagnostic_only_unsubmitted_candidate": direct_candidate
		}
		captured.append(predicates)
		var file: FileAccess = FileAccess.open(
			"user://low-report-diagnostic-" + str(captured.size()) + ".json", FileAccess.WRITE
		)
		file.store_string(JSON.stringify(evidence, "", true, true))
		file.close()
		print("LOW_REPORT_DIAGNOSTIC " + JSON.stringify(predicates))


func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	if profile != "low_flanks":
		return
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.opponents._format = 13
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var state: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	state.stadium = StadiumLowWallSnapshot.fixture(StadiumLayoutSnapshot.capture(ledger), 194, 1)
	var runner: DiagnosticRunner = DiagnosticRunner.new()
	add_child(runner)
	var reports: Array[Dictionary] = []
	var errors: Array[String] = []
	runner.finished.connect(func(report: Dictionary) -> void: reports.append(report))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	check(
		runner.start(state, state.stadium.environment.seed, PitchBatLab.FIELD_ID, ledger),
		"exact diagnostic runner starts"
	)
	var limit: int = 200000 if "--diagnostic-full" in OS.get_cmdline_user_args() else 1200
	for frame in range(limit):
		await get_tree().physics_frame
		if not reports.is_empty() or not errors.is_empty():
			break
		if frame % 600 == 0:
			print(
				(
					"LOW_REPORT_DIAGNOSTIC_PROGRESS "
					+ JSON.stringify({"frames": frame, "elapsed": runner._elapsed})
				)
			)
	if is_instance_valid(runner._lab):
		runner._dump("bounded_probe_end")
	print(
		(
			"LOW_REPORT_DIAGNOSTIC_RESULT "
			+ JSON.stringify(
				{"reports": reports.size(), "errors": errors, "observations": runner.captured}
			)
		)
	)
	runner.cancel()
	runner.queue_free()
	await get_tree().process_frame

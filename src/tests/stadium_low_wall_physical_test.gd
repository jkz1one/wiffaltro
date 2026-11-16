extends "res://src/tests/stadium_owned_low_wall_test.gd"


## Actual detached AI games using exact paid fixture33, never fabricated report events.
func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.opponents._format = 13
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var entry: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	source.stadium = StadiumLowWallSnapshot.fixture(entry, 194, 1)
	var seed: int = source.stadium.environment.seed
	var runner = preload("res://src/tests/stadium_low_wall_report_retaining_runner.gd").new()
	runner.evidence_prefix = profile
	add_child(runner)
	var reports: Array[Dictionary] = []
	var errors: Array[String] = []
	runner.finished.connect(func(report: Dictionary) -> void: reports.append(report))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	check(not runner.start(source, seed), "public runner rejects missing complete paid prefix")
	check(
		not runner.start(source, seed, SeasonState.AWAY_FIELD_ID, ledger),
		"public runner rejects wrong field"
	)
	check(
		runner.start(source, seed, PitchBatLab.FIELD_ID, ledger),
		"public fixture33 runner starts " + profile
	)
	if runner._lab == null:
		runner.queue_free()
		return
	check(
		StadiumLowWallRuntime.installed_bound(runner._lab, source.stadium),
		"public runner exact full owner context"
	)
	var wall_start: int = Time.get_ticks_msec()
	for frame in range(200000):
		await get_tree().physics_frame
		if frame % 120 == 0 and is_instance_valid(runner._lab):
			print(
				(
					"LOW_PHYSICAL_PROGRESS "
					+ JSON.stringify(
						{
							"profile": profile,
							"frames": frame,
							"wall_elapsed_ms": Time.get_ticks_msec() - wall_start,
							"simulated_seconds": runner._elapsed,
							"phase": runner._lab._match_state.phase,
							"inning": runner._lab._match_state.inning,
							"top_half": runner._lab._match_state.top_half,
							"outs": runner._lab._match_state.outs,
							"plate_appearance": runner._lab._match_state.plate_appearance_number,
							"throws": runner._lab._throw_number
						}
					)
				)
			)
		if not reports.is_empty() or not errors.is_empty():
			break
	print(
		(
			"LOW_PHYSICAL_TERMINAL "
			+ JSON.stringify(
				{
					"profile": profile,
					"wall_elapsed_ms": Time.get_ticks_msec() - wall_start,
					"simulated_seconds": runner._elapsed,
					"reports": reports.size(),
					"errors": errors
				}
			)
		)
	)
	check(
		errors.is_empty() and reports.size() == 1,
		"actual complete physical game " + profile + ": " + str(errors)
	)
	if reports.size() == 1:
		var report: Dictionary = reports[0]
		check(
			(
				report.version == 9
				and report.property.version == 33
				and PhysicalMatchReport.valid(report)
			),
			"complete-boundary report binds low fixture"
		)
		check(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report, "", true, true))),
			"cold exact report replay"
		)
		check(
			PhysicalStadiumReport.matches(report, source.stadium),
			"report matches exact paid fixture"
		)
		var bad: Dictionary = report.duplicate(true)
		bad.property.wall_piece_inventory.stock.copies.erase(entry.layout.low_wall.copies[0])
		check(not PhysicalMatchReport.valid(bad), "cold report refuses missing low copy")
		var file: FileAccess = FileAccess.open(
			"user://low-wall-" + profile + "-physical-report.json", FileAccess.WRITE
		)
		file.store_string(JSON.stringify(report, "", true, true))
		file.close()
	runner.cancel()
	runner.queue_free()
	await get_tree().process_frame

extends "res://src/tests/stadium_owned_low_wall_test.gd"


## Bounded genuine fixture33 runtime measurement, not complete-game qualification.
func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.opponents._format = 13
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var source: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var entry: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	source.stadium = StadiumLowWallSnapshot.fixture(entry, 194, 1)
	var seed: int = source.stadium.environment.seed
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
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
	var started_phase: int = runner._lab._match_state.phase
	var tick_us: Array[int] = []
	for frame in range(240):
		var tick_start: int = Time.get_ticks_usec()
		await get_tree().physics_frame
		tick_us.append(Time.get_ticks_usec() - tick_start)
		if not errors.is_empty() or not reports.is_empty():
			break
	var elapsed: int = Time.get_ticks_msec() - wall_start
	tick_us.sort()
	check(
		errors.is_empty(), "genuine issued fixture tick loop has no runner failure: " + str(errors)
	)
	check(
		is_instance_valid(runner._lab) and runner._elapsed > 0.0,
		"real runner advances without forced outcomes"
	)
	if is_instance_valid(runner._lab):
		print(
			(
				"LOW_ISSUED_AGGREGATE "
				+ JSON.stringify(
					{
						"profile": profile,
						"ticks": tick_us.size(),
						"wall_elapsed_ms": elapsed,
						"median_frame_us": tick_us[tick_us.size() / 2],
						"p95_frame_us":
						tick_us[mini(tick_us.size() - 1, int(tick_us.size() * 0.95))],
						"max_frame_us": tick_us.back(),
						"simulated_seconds": runner._elapsed,
						"start_phase": started_phase,
						"end_phase": runner._lab._match_state.phase,
						"plate_appearance": runner._lab._match_state.plate_appearance_number,
						"throws": runner._lab._throw_number,
						"complete_game": not reports.is_empty()
					}
				)
			)
		)
		check(
			StadiumLowWallRuntime.installed_bound(runner._lab, source.stadium),
			"deep transition after genuine active ticks"
		)
	runner.cancel()
	runner.queue_free()
	await get_tree().process_frame

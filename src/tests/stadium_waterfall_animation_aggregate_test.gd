extends "res://src/tests/stadium_owned_waterfall_animation_test.gd"


## One genuine active fixture35 tick window. Synthetic funding, no forced outcomes.
## Staged until final46 rebase. Not a completed-game or target-hardware benchmark.
func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(216, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(
			(
				paid
				. commit(
					{
						"id": "aggregate-land-" + tier,
						"rev": paid.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": 40,
						"progress_through": 40,
						"price_version": 1
					}
				)
				. ok
			),
			"paid land " + tier
		)
	check(
		(
			paid
			. commit(
				{
					"id": "motion-water",
					"rev": paid.revision(),
					"op": "stadium_buy",
					"item": "ST-046",
					"quantity": 1,
					"price_version": 32,
					"through": 40,
					"progress_through": 40
				}
			)
			. ok
		),
		"paid exact waterfall copy"
	)
	var layout: Dictionary = StadiumWaterfallLiveItems.place(
		paid.view().stadium_draft, paid.construction(), LIVE, "WF-LIVE-LF", 0, paid.surface_owned()
	)
	layout = StadiumWaterfallAnimationLayout.select(layout, LIVE, true)
	if _apply(paid, layout, "single-live47-aggregate"):
		await _active_ticks(paid)
	print(
		(
			"WATERFALL47_AGGREGATE_RESULT "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"synthetic_funding": true,
					"complete_game_qualification": false,
					"target_hardware_qualification": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures.is_empty() else 1)


func _active_ticks(paid: ClubAssetLedger) -> void:
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.opponents._format = 13
	for pick in range(4):
		season.choose_player(season.offers()[0])
	var state: MatchState = MatchState.create(season._make_team(1), season._make_team(2))
	var snapshot: Dictionary = StadiumWaterfallAnimationSnapshot.fixture(
		StadiumLayoutSnapshot.capture(paid), 216, 1
	)
	state.stadium = snapshot
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var reports: Array[Dictionary] = []
	var errors: Array[String] = []
	runner.finished.connect(func(report: Dictionary) -> void: reports.append(report))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	check(
		not runner.start(state, int(snapshot.environment.seed)),
		"public fixture35 rejects absent paid authority"
	)
	check(
		not runner.start(state, int(snapshot.environment.seed), SeasonState.AWAY_FIELD_ID, paid),
		"public fixture35 rejects wrong field"
	)
	check(
		runner.start(state, int(snapshot.environment.seed), PitchBatLab.FIELD_ID, paid),
		"public fixture35 starts with exact paid authority"
	)
	if runner._lab == null:
		runner.queue_free()
		return
	check(
		StadiumWaterfallAnimationInstall.installed_bound(runner._lab, snapshot),
		"deep owned installation before active ticks"
	)
	var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(
		runner._lab
	)
	var start_phase: int = runner._lab._match_state.phase
	var start_us: int = Time.get_ticks_usec()
	var samples: Array[int] = []
	for tick in range(240):
		var previous_us: int = Time.get_ticks_usec()
		await get_tree().physics_frame
		samples.append(Time.get_ticks_usec() - previous_us)
		if not errors.is_empty() or not reports.is_empty():
			break
	var elapsed_us: int = Time.get_ticks_usec() - start_us
	samples.sort()
	check(errors.is_empty(), "real active runner has no failure: " + str(errors))
	check(
		is_instance_valid(runner._lab) and runner._elapsed > 0.0,
		"actual runner advances without phase or outcome injection"
	)
	if is_instance_valid(runner._lab):
		var lab: PitchBatLab = runner._lab
		print(
			(
				"WATERFALL47_ACTIVE_TICKS "
				+ JSON.stringify(
					{
						"ticks": samples.size(),
						"wall_elapsed_us": elapsed_us,
						"median_frame_us": samples[samples.size() / 2],
						"p95_frame_us":
						samples[mini(samples.size() - 1, int(samples.size() * 0.95))],
						"max_frame_us": samples.back(),
						"simulated_seconds": runner._elapsed,
						"start_phase": start_phase,
						"end_phase": lab._match_state.phase,
						"plate_appearance": lab._match_state.plate_appearance_number,
						"throws": lab._throw_number,
						"animation_phase": owner._lease.phase if owner != null else -1,
						"complete_game": not reports.is_empty()
					}
				)
			)
		)
		check(
			(
				owner != null
				and not owner.retired
				and StadiumWaterfallAnimationInstall.installed_bound(lab, snapshot)
			),
			"complete paid owner and contact authority survive actual active ticks"
		)
	runner.cancel()
	runner.queue_free()
	await get_tree().process_frame

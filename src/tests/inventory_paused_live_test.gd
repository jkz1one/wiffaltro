extends "res://src/tests/inventory_prefix_test.gd"
## Actual detached partial-PA physics. Initial paid ownership is controlled synthetic setup.
## Stops at safe settled pitch; this is not full-game settlement/save qualification.


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("dugout"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "paused physical draft")
	var source: MatchState = MatchState.create(season._make_team(1, 0), season._make_team(0, 0))
	source.league_rules = LeagueRules.capture("dugout")
	var bank: SeasonOwnership = _bank(["C03"])
	var own: TeamMatchState = source.home_team
	own.league_ownership = bank.to_data()
	own.tactics.held = SeasonTacticalCatalog.held(bank.view())
	own.field_supply.receipt = SeasonFieldGrant.receipt(0)
	own.track_bases = true
	MatchFieldSupply.sync_capacity(own, bank.view())
	for player: PlayerMatchState in own.roster:
		player.definition.season_sponsors["B01"] = true
	var receipt: String = own.tactics.held[0].id
	var opponent: Array = source.away_team.roster.map(
		func(player: PlayerMatchState) -> String: return String(player.definition.id)
	)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var errors: Array[String] = []
	var finished: Array = []
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	runner.finished.connect(func(report: Dictionary) -> void: finished.append(report))
	var started: bool = runner.start(source, 443)
	check(started, "actual partial-PA runner starts")
	var proof: Dictionary = {}
	var frames: int = 0
	var started_ms: int = Time.get_ticks_msec()
	if started:
		for frame in range(150000):
			await get_tree().physics_frame
			frames += 1
			if not errors.is_empty() or not finished.is_empty():
				break
			var lab: PitchBatLab = runner._lab
			var state: MatchState = lab._match_state
			if (
				state.phase not in [MatchState.Phase.PLAY_DEAD, MatchState.Phase.PRE_PITCH]
				or state.between_batters
				or lab._release_controller.active
			):
				continue
			lab._debug_paused = true
			proof = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
			if not proof.is_empty():
				break
			lab._debug_paused = false
	check(
		errors.is_empty() and not proof.is_empty(),
		"actual settled pitch reached safe unfinished PA: " + str(errors)
	)
	if not proof.is_empty():
		check(
			(
				proof.releases.any(
					func(row: Dictionary) -> bool: return row.pa == proof.completed + 1
				)
				and proof.base.results.size() == proof.completed
			),
			"actual current release remains explicitly unfinished"
		)
		check(
			not (
				PhysicalInventoryPaused
				. unused_receipt(
					proof, own, opponent, 0, anchor, bank.to_data(), [], 1, false, receipt
				)
				. is_empty()
			),
			"actual paused unused receipt independently authenticates"
		)
		var cold: Dictionary = JSON.parse_string(JSON.stringify(proof, "", true, true))
		check(
			not (
				PhysicalInventoryPaused
				. unused_receipt(
					cold, own, opponent, 0, anchor, bank.to_data(), [], 1, false, receipt
				)
				. is_empty()
			),
			"actual paused proof cold replay"
		)
		check(
			(
				PhysicalInventoryPrefix
				. capture(runner._lab._match_state, runner._lab._match_state.home_team, anchor)
				. is_empty()
			),
			"old completed capture still rejects unfinished actual PA"
		)
		check(
			not PhysicalMatchReport.valid(proof), "partial proof never passes full-game authority"
		)
		var bad: Dictionary = cold.duplicate(true)
		bad.releases.pop_back()
		check(
			(
				PhysicalInventoryPaused
				. unused_receipt(
					bad, own, opponent, 0, anchor, bank.to_data(), [], 1, false, receipt
				)
				. is_empty()
			),
			"omitted actual current release rejects"
		)
		print(
			"INVENTORY_PAUSED_LIVE wall_ms=",
			Time.get_ticks_msec() - started_ms,
			" physics_frames=",
			frames,
			" releases=",
			proof.releases.size(),
			" completed_pa=",
			proof.completed,
			" current=",
			proof.current,
			" held=",
			proof.held,
			" consumed=",
			proof.field_state.uses
		)
	runner.queue_free()
	await get_tree().process_frame
	print("Inventory paused live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

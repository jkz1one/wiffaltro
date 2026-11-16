extends "res://src/tests/inventory_prefix_test.gd"
## Actual detached physics, stopped after authenticated earned delivery. Paid setup is synthetic.


func _ready() -> void:
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("dugout"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "physical prefix draft")
	var source: MatchState = MatchState.create(season._make_team(1, 0), season._make_team(0, 0))
	source.league_rules = LeagueRules.capture("dugout")
	var bank: SeasonOwnership = _bank([])
	var own: TeamMatchState = source.home_team
	own.league_ownership = bank.to_data()
	own.tactics.held.clear()
	own.field_supply.receipt = SeasonFieldGrant.receipt(0)
	own.track_bases = true
	MatchFieldSupply.sync_capacity(own, bank.view())
	for player: PlayerMatchState in own.roster:
		player.definition.season_sponsors["B01"] = true
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
	check(started, "actual detached prefix runner starts")
	var proof: Dictionary = {}
	var frames: int = 0
	var started_ms: int = Time.get_ticks_msec()
	if started:
		for frame in range(150000):
			await get_tree().physics_frame
			frames += 1
			if not errors.is_empty() or not finished.is_empty():
				break
			var played: MatchState = runner._lab._match_state
			if played.home_team.field_supply.evidence().get("outcome") == "granted":
				proof = PhysicalInventoryPrefix.capture(played, played.home_team, anchor)
				if not proof.is_empty():
					break
	check(
		errors.is_empty() and not proof.is_empty(),
		"earned runtime Field grant reached before terminal game: " + str(errors)
	)
	if not proof.is_empty():
		check(
			PhysicalInventoryPrefix.matches(
				proof, own, opponent, 0, anchor, bank.to_data(), [], 1, false
			),
			"actual physical completed prefix authenticates immediate unused Field resale"
		)
		var cold: Dictionary = JSON.parse_string(JSON.stringify(proof, "", true, true))
		check(
			PhysicalInventoryPrefix.matches(
				cold, own, opponent, 0, anchor, bank.to_data(), [], 1, false
			),
			"actual earned prefix cold replay authenticates"
		)
		var bad: Dictionary = cold.duplicate(true)
		for row: Dictionary in bad.field_state.fielding:
			if row.clean:
				row.clean = false
				break
		check(
			not PhysicalInventoryPrefix.matches(
				bad, own, opponent, 0, anchor, bank.to_data(), [], 1, false
			),
			"changing actual clean-out chronology rejects earned grant"
		)
		print(
			"INVENTORY_PREFIX_LIVE wall_ms=",
			Time.get_ticks_msec() - started_ms,
			" physics_frames=",
			frames,
			" releases=",
			proof.releases.size(),
			" completed_pa=",
			proof.completed,
			" grant=",
			proof.field_state.grant,
			" clean_rows=",
			proof.field_state.fielding
		)
	runner.queue_free()
	await get_tree().process_frame
	print("Inventory prefix live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

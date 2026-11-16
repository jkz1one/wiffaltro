extends "res://src/tests/inventory_paused_test.gd"
## Authored current-context contract tests. Run only in the allocated native engine gate.


func _ready() -> void:
	var catalog: String = WorkingPitchCatalog.signature()
	check(PhysicalPitchEvidence.context_valid(""), "historical context remains explicit empty")
	check(not PhysicalPitchEvidence.context_valid(catalog + "changed"), "wrong catalog rejects")
	for id: String in WorkingPitchCatalog.ids():
		check(PhysicalPitchEvidence.recipe(id, catalog) != null, "current recipe " + id)
		check((PhysicalPitchEvidence.recipe(id) != null) ==
			(ContentDB.get_pitch(StringName(id)) != null), "exact historical lookup " + id)
		check(PhysicalPitchEvidence.recipe(id, "arbitrary") == null, "no arbitrary context " + id)
	var id: String = WorkingPitchCatalog.new_ids()[0]
	_pool_shapes(id, catalog)
	_paused_current(id, catalog)
	_prefix_current(id, catalog)
	_terminal_current(id, catalog)
	print("Current physical evidence checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _install(fixture: Dictionary, id: String) -> void:
	for team: TeamMatchState in [fixture.state.away_team, fixture.state.home_team, fixture.own]:
		for player: PlayerMatchState in team.roster:
			player.definition = player.definition.duplicate(true) as PlayerDefinition
			player.definition.starting_pitches.assign([WorkingPitchCatalog.get_recipe(id)])


func _paused_current(id: String, catalog: String) -> void:
	var fixture: Dictionary = _fixture(["C03"])
	_install(fixture, id)
	var state: MatchState = fixture.state
	state.base_flow.prepare(state)
	var lab: PitchBatLab = _lab_for(state)
	var receipt: String = state.home_team.tactics.held[0].id
	var empty: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(_current_unused(empty, fixture, receipt, catalog), "zero release current context")
	check(not _current_unused(empty, fixture, receipt, "wrong"), "zero release cannot hide wrong context")
	_release_ball(state)
	var proof: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(_current_unused(proof, fixture, receipt, catalog), "new paused recipe admitted")
	check(not _unused_paused(proof, fixture, receipt), "new paused recipe not historical")
	check(_current_unused(JSON.parse_string(JSON.stringify(proof, "", true, true)),
		fixture, receipt, catalog), "paused JSON roundtrip")
	var bad: Dictionary = proof.duplicate(true)
	bad.releases[0].recipe = "pitch.not_real"
	check(not _current_unused(bad, fixture, receipt, catalog), "unknown release rejected")
	bad = proof.duplicate(true)
	bad.performance[String(state.pitcher().definition.id)].pitches += 1
	check(not _current_unused(bad, fixture, receipt, catalog), "paid history tamper rejected")
	lab.free()


func _current_unused(proof: Dictionary, fixture: Dictionary, receipt: String, catalog: String) -> bool:
	return not PhysicalInventoryPaused.unused_receipt(proof, fixture.own, fixture.opponent,
		0, anchor, fixture.bank.to_data(), [], 1, false, receipt, catalog).is_empty()


func _prefix_current(id: String, catalog: String) -> void:
	var fixture: Dictionary = _fixture([])
	_install(fixture, id)
	for index in range(3):
		_out(fixture.state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(fixture.state,
		fixture.state.home_team, anchor)
	check(PhysicalInventoryPrefix.matches(proof, fixture.own, fixture.opponent, 0, anchor,
		fixture.bank.to_data(), [], 1, false, catalog), "earned prefix current recipe")
	check(not _matches(proof, fixture), "new prefix cannot masquerade as historical")
	check(not PhysicalInventoryPrefix.matches(proof, fixture.own, fixture.opponent, 0, anchor,
		fixture.bank.to_data(), [], 1, false, "wrong"), "prefix wrong context")
	check(PhysicalInventoryPrefix.matches(JSON.parse_string(JSON.stringify(proof, "", true, true)),
		fixture.own, fixture.opponent, 0, anchor, fixture.bank.to_data(), [], 1, false, catalog),
		"earned prefix JSON roundtrip")
	proof.field_state.grant.clear()
	check(not PhysicalInventoryPrefix.matches(proof, fixture.own, fixture.opponent, 0, anchor,
		fixture.bank.to_data(), [], 1, false, catalog), "current context does not drop grant proof")


func _terminal_current(id: String, catalog: String) -> void:
	var fixture: Dictionary = _fixture([])
	_install(fixture, id)
	var state: MatchState = fixture.state
	for half in range(9):
		for index in range(3):
			_out(state)
		state.continue_after_dead_ball()
	state.base_flow.prepare(state)
	var pitch: PitchDefinition = state.pitcher().definition.starting_pitches[0]
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	state.between_batters = false
	state.pitcher().spend_stamina(pitch.stamina_cost)
	state.note_pitch_released(pitch.id, pitch.stamina_cost)
	state.record_hit(BallPlayOutcome.Result.HOME_RUN)
	var envelope: Dictionary = _final_envelope(state)
	var performance: Dictionary = state.performance.snapshot(state)
	check(PhysicalInventoryPaused.validate_final_frontier(envelope, fixture.own, performance,
		catalog), "terminal current recipe")
	check(not PhysicalInventoryPaused.validate_final_frontier(envelope, fixture.own, performance),
		"terminal current recipe not historical")
	check(PhysicalInventoryPaused.validate_final_frontier(JSON.parse_string(JSON.stringify(
		envelope, "", true, true)), fixture.own, performance, catalog), "terminal JSON roundtrip")
	envelope.releases.pop_back()
	check(not PhysicalInventoryPaused.validate_final_frontier(envelope, fixture.own, performance,
		catalog), "terminal release omission rejected")


func _pool_shapes(id: String, catalog: String) -> void:
	# Shape-only admission is not owned-home authority: valid()/accepts() still require
	# the full base flow, pool geometry, paid ledger and exact fixture/request binding.
	var row: Dictionary = {"play": 0, "half": 0, "batter": "batter", "pitcher": "pitcher",
		"recipe": id, "contact": -1, "exit_speed": 0.0, "result": "ball",
		"balls": 0, "strikes": 0, "outs": 0, "runs": 0}
	check(StadiumPoolOwnedHumanEvidence._play_shape(row, 0, catalog), "pool new recipe shape")
	check(not StadiumPoolOwnedHumanEvidence._play_shape(row, 0), "pool historical recipe guard")
	check(not StadiumPoolOwnedHumanEvidence._play_shape(row, 0, "wrong"), "pool wrong catalog")
	check(StadiumPoolOwnedHumanEvidence._play_shape(JSON.parse_string(JSON.stringify(row)),
		0, catalog), "pool JSON shape")
	check(not StadiumPoolOwnedHumanEvidence.valid({"plays": [row]}, catalog),
		"recipe admission cannot replace owned-home proofs")
	row.recipe = "pitch.not_real"
	check(not StadiumPoolOwnedHumanEvidence._play_shape(row, 0, catalog), "pool unknown recipe")

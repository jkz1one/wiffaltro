extends "res://src/tests/inventory_prefix_test.gd"
## Controlled state/recorder diagnostic, not actual physical simulation.


func _ready() -> void:
	var fixture: Dictionary = _fixture(["C02", "C03"])
	var state: MatchState = fixture.state
	state.base_flow.prepare(state)
	var lab: PitchBatLab = _lab_for(state)
	var recovery: String = state.home_team.tactics.held[0].id
	var unused: String = state.home_team.tactics.held[1].id
	var initial: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		_unused_paused(initial, fixture, unused),
		"zero release paused boundary accepts unused paid receipt"
	)
	check(
		(
			PhysicalInventoryPrefix
			. unused_receipt(
				initial,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				fixture.bank.to_data(),
				[],
				1,
				false,
				unused
			)
			. is_empty()
		),
		"new paused header not admitted as completed v1"
	)
	# Legal switch AFTER readiness, BEFORE C02. Readiness remains pitcher0.
	check(state.home_team.select_pitcher(1), "between-batters switch after ready")
	state.pitcher().stamina_remaining -= 20.0
	fixture.own.roster[1].stamina_remaining -= 20.0
	check(
		state.home_team.tactics.activate(state, state.home_team, recovery),
		"actual successful C02 activation on switched pitcher"
	)
	var activated: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		_unused_paused(activated, fixture, unused),
		"action-time snapshot accepts switched active C02 player"
	)
	check(
		not _unused_paused(activated, fixture, recovery),
		"committed/consumed Recovery cannot sell before first pitch"
	)
	_release_ball(state)
	var proof: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		(
			not proof.is_empty()
			and proof.completed == 0
			and proof.base.results.is_empty()
			and proof.releases.size() == 1
		),
		"current release never becomes a completed result"
	)
	check(_unused_paused(proof, fixture, unused), "safe between-pitch unused copy accepted")
	check(
		_unused_paused(JSON.parse_string(JSON.stringify(proof, "", true, true)), fixture, unused),
		"cold exact paused proof"
	)
	check(
		PhysicalInventoryPaused.frontier_matches(activated, proof),
		"accepted activation frontier extends with real current release"
	)
	for key: String in ["current", "roles", "anchor", "inventory_rule", "league_rules"]:
		var bad: Dictionary = proof.duplicate(true)
		bad.erase(key)
		check(not _unused_paused(bad, fixture, unused), "paused header stripping rejects " + key)
	var bad: Dictionary = proof.duplicate(true)
	bad.roles[0].snapshot.pitcher = String(state.home_team.roster[0].definition.id)
	check(not _unused_paused(bad, fixture, unused), "wrong activation-time pitcher rejects")
	bad = proof.duplicate(true)
	bad.roles[0].release_count += 1
	check(not _unused_paused(bad, fixture, unused), "activation after release rejects")
	bad = proof.duplicate(true)
	bad.current.committed.clear()
	check(not _unused_paused(bad, fixture, unused), "omitted committed copy rejects")
	bad = proof.duplicate(true)
	bad.current.snapshot.away += 1
	check(not _unused_paused(bad, fixture, unused), "unfinished PA cannot invent a run")
	bad = proof.duplicate(true)
	bad.releases[0].player = String(state.home_team.roster[0].definition.id)
	check(not _unused_paused(bad, fixture, unused), "partial release must bind active pitcher")
	for phase: int in [
		MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY, MatchState.Phase.GAME_END
	]:
		state.phase = phase
		check(
			PhysicalInventoryPaused.capture(lab, state.home_team, anchor).is_empty(),
			"unsafe or terminal phase rejects " + str(phase)
		)
	state.phase = MatchState.Phase.PLAY_DEAD
	lab._debug_paused = false
	check(
		PhysicalInventoryPaused.capture(lab, state.home_team, anchor).is_empty(),
		"unpaused live lab rejects"
	)
	lab._debug_paused = true
	lab._release_controller.active = true
	check(
		PhysicalInventoryPaused.capture(lab, state.home_team, anchor).is_empty(),
		"active release gesture rejects"
	)
	lab._release_controller.active = false
	_release_ball(state)
	var later: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		PhysicalInventoryPaused.frontier_matches(proof, later),
		"second partial release retains first accepted frontier"
	)
	later.releases[0].recipe = "pitch.fake"
	check(
		not PhysicalInventoryPaused.frontier_matches(proof, later),
		"rewritten prior partial release rejects"
	)
	var headers: Array = [
		state.league_rules.duplicate(true),
		state.away_team.league_rules.duplicate(true),
		state.home_team.league_rules.duplicate(true),
		state.away_team.league_ownership.duplicate(true),
		state.home_team.league_ownership.duplicate(true)
	]
	state.league_rules.clear()
	state.away_team.league_rules.clear()
	state.home_team.league_rules.clear()
	state.away_team.league_ownership.clear()
	state.home_team.league_ownership.clear()
	check(
		PhysicalInventoryPaused.capture(lab, state.home_team, anchor).is_empty(),
		"strip all headers cannot launder activation recorder"
	)
	state.league_rules = headers[0]
	state.away_team.league_rules = headers[1]
	state.home_team.league_rules = headers[2]
	state.away_team.league_ownership = headers[3]
	var legacy: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(legacy.enable_league_rules(LeagueRules.capture("dugout")), "old capability fixture")
	state.home_team.league_ownership = legacy.to_data()
	check(
		PhysicalInventoryPaused.capture(lab, state.home_team, anchor).is_empty(),
		"replace with old capability cannot launder recorder"
	)
	state.home_team.league_ownership = headers[4]
	bad = proof.duplicate(true)
	bad.field_state.boundary = 0
	check(
		not _unused_paused(bad, fixture, unused),
		"unfinished PA retirement boundary cannot be relabeled completed"
	)
	bad = proof.duplicate(true)
	bad.current.balls = 3
	check(not _unused_paused(bad, fixture, unused), "count cannot exceed actual partial releases")
	bad = initial.duplicate(true)
	bad.current.strikes = 1
	check(not _unused_paused(bad, fixture, unused), "zero release cannot invent count")
	bad = proof.duplicate(true)
	bad.current.ready.pitcher = String(state.home_team.roster[2].definition.id)
	check(
		not PhysicalInventoryPaused.frontier_matches(activated, bad),
		"accepted current readiness cannot rewrite later"
	)
	bad = proof.duplicate(true)
	bad.roles[0].snapshot.pitcher = String(state.home_team.roster[2].definition.id)
	check(
		not PhysicalInventoryPaused.frontier_matches(activated, bad),
		"accepted activation role cannot rewrite later"
	)
	lab.free()
	_sure_shot_boundary()
	_opponent_advance()
	_terminal_frontier(false)
	_terminal_frontier(true)
	print("Inventory paused checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _lab_for(state: MatchState) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = state
	lab._debug_paused = true
	lab._release_controller = PitchReleaseController.new()
	return lab


func _release_ball(state: MatchState) -> void:
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	state.between_batters = false
	var pitch: PitchDefinition = state.pitcher().definition.starting_pitches[0]
	state.pitcher().spend_stamina(pitch.stamina_cost)
	state.note_pitch_released(pitch.id, pitch.stamina_cost)
	state.record_ball()


func _unused_paused(proof: Dictionary, fixture: Dictionary, receipt: String) -> bool:
	return not (
		PhysicalInventoryPaused
		. unused_receipt(
			proof,
			fixture.own,
			fixture.opponent,
			0,
			anchor,
			fixture.bank.to_data(),
			[],
			1,
			false,
			receipt
		)
		. is_empty()
	)


func _sure_shot_boundary() -> void:
	var fixture: Dictionary = _fixture(["C03"])
	var state: MatchState = fixture.state
	state.base_flow.prepare(state)
	state.pitcher().definition.season_sponsors["F08"] = true
	check(
		state.sure_shot.choose(state, state.pitcher().definition.starting_pitches[0].id),
		"actual pre-release Sure Shot commitment"
	)
	var lab: PitchBatLab = _lab_for(state)
	var receipt: String = state.home_team.tactics.held[0].id
	var proof: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		proof.field_state.boundary == 1 and _unused_paused(proof, fixture, receipt),
		"Sure Shot commitment uses active boundary without fake release"
	)
	var bad: Dictionary = proof.duplicate(true)
	bad.current.call.clear()
	check(
		not _unused_paused(bad, fixture, receipt), "stripped current Sure Shot commitment rejects"
	)
	_release_ball(state)
	var later: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		PhysicalInventoryPaused.frontier_matches(proof, later),
		"committed call retained across first release"
	)
	later.calls.clear()
	check(
		not PhysicalInventoryPaused.frontier_matches(proof, later),
		"later history cannot omit accepted call"
	)
	lab.free()


func _opponent_advance() -> void:
	var fixture: Dictionary = _fixture([SeasonTacticalCatalog.BASE, "C02", "C03"])
	var state: MatchState = fixture.state
	state.base_flow.prepare(state)
	for index in range(4):
		_release_ball(state)
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	state.base_flow.prepare(state)
	var own: TeamMatchState = state.home_team
	check(
		state.away_team.tactics.activate(
			state, state.away_team, state.away_team.tactics.held[0].id
		),
		"opponent actual Base Advance before defensive Recovery"
	)
	fixture.own.roster[0].stamina_remaining -= 20.0
	check(
		own.tactics.activate(state, own, own.tactics.held[1].id),
		"defensive Recovery after opponent occupancy change"
	)
	var lab: PitchBatLab = _lab_for(state)
	var proof: Dictionary = PhysicalInventoryPaused.capture(lab, own, anchor)
	check(
		_unused_paused(proof, fixture, own.tactics.held[-1].id),
		"post-advance action role binds validated occupancy without fake result"
	)
	lab.free()


func _terminal_frontier(supply_end: bool) -> void:
	var fixture: Dictionary = _fixture(["C02", SeasonTacticalCatalog.BASE, "C03"])
	var state: MatchState = fixture.state
	state.base_flow.prepare(state)
	state.pitcher().stamina_remaining -= 20.0
	fixture.own.roster[0].stamina_remaining -= 20.0
	check(
		state.home_team.tactics.activate(
			state, state.home_team, state.home_team.tactics.held[0].id
		),
		"terminal fixture actual opening Recovery"
	)
	var lab: PitchBatLab = _lab_for(state)
	var accepted: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
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
	state.record_hit(
		BallPlayOutcome.Result.TRIPLE if supply_end else BallPlayOutcome.Result.HOME_RUN
	)
	if supply_end:
		state.phase = MatchState.Phase.PRE_PITCH
		state.between_batters = true
		state.base_flow.prepare(state)
		var bases: Array = state.home_team.tactics.held.filter(
			func(copy: Dictionary) -> bool: return copy.item == SeasonTacticalCatalog.BASE
		)
		check(
			(
				bases.size() == 1
				and state.home_team.tactics.activate(state, state.home_team, bases[0].id)
			),
			"terminal Take a Base actual walkoff"
		)
	var envelope: Dictionary = _final_envelope(state)
	var performance: Dictionary = state.performance.snapshot(state)
	check(state.phase == MatchState.Phase.GAME_END, "terminal frontier requires actual ended state")
	check(
		PhysicalInventoryPaused.validate_final_frontier(envelope, fixture.own, performance),
		"full terminal frontier validates, extra supply ready=" + str(supply_end)
	)
	check(
		PhysicalInventoryPaused.validate_final_frontier(
			JSON.parse_string(JSON.stringify(envelope, "", true, true)), fixture.own, performance
		),
		"terminal frontier cold replay"
	)
	check(
		PhysicalInventoryPaused.frontier_matches(accepted, envelope),
		"accepted partial activation joins genuine terminal history"
	)
	var bad: Dictionary = envelope.duplicate(true)
	bad.roles[0].snapshot.pitcher = String(state.home_team.roster[1].definition.id)
	check(
		not PhysicalInventoryPaused.validate_final_frontier(bad, fixture.own, performance),
		"terminal role identity tampering rejects"
	)
	bad = envelope.duplicate(true)
	bad.releases.pop_back()
	check(
		not PhysicalInventoryPaused.validate_final_frontier(bad, fixture.own, performance),
		"terminal omitted release rejects"
	)
	check(
		PhysicalInventoryPaused.capture(lab, state.home_team, anchor).is_empty(),
		"terminal full join never authorizes paused sale capture"
	)
	lab.free()


func _final_envelope(state: MatchState) -> Dictionary:
	return {
		"version": 1,
		"rosters":
		[
			state.away_team.roster.map(
				func(player: PlayerMatchState) -> String: return String(player.definition.id)
			),
			state.home_team.roster.map(
				func(player: PlayerMatchState) -> String: return String(player.definition.id)
			)
		],
		"own_index": 1,
		"base": state.base_flow.evidence(state),
		"releases": state.sure_shot.releases.duplicate(true),
		"calls": state.sure_shot.calls.duplicate(true),
		"roles": state.home_team.inventory_actions.duplicate(true),
		"field_state": SeasonFieldSales.capture(state, state.home_team),
		"pitching": state.sure_shot.evidence(state.home_team)
	}

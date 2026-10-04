class_name OpponentRecoveryBoundaries
extends RefCounted
## Explicit seeded units for credits and a real shared Base ending, not full-match claims.


static func run(paid: Dictionary, check: Callable) -> void:
	refund(check, paid.build)
	for mode in range(3):
		terminal(check, paid, mode)


static func refund(check: Callable, build: SeasonBuild) -> void:
	var roster: Array[PlayerDefinition] = []
	for id: String in build.roster():
		roster.append(build.definition(id).duplicate(true) as PlayerDefinition)
	var team: TeamMatchState = TeamMatchState.create("Credit unit", roster)
	team.ai_recovery_pitcher = String(roster[0].id)
	roster[0].season_sponsors = {"B03": true}
	var state: MatchState = MatchState.create(TeamMatchState.create("Batting", roster), team)
	team.recovery.initialize(team)
	var current: Dictionary = {}
	for id: String in team.recovery.initial:
		current[id] = team.recovery.initial[id].initial
	var expected: Array = []
	for pa in range(1, 4):
		state.plate_appearance_number = pa
		state.pitch_ledger.clear()
		for recipe: StringName in [&"pitch.overhand_four_seam", &"pitch.riser", &"pitch.drop"]:
			state.pitcher().spend_stamina(4.0)
			state.pitch_ledger.record(state.pitcher(), recipe, 4.0)
			team.recovery.release(state, recipe, 4.0)
		state.sure_shot.strikeout(state)
		SeasonSponsorEffects.strikeout(state)
		var flow: Dictionary = team.recovery.evidence(state, team)
		check.call(PhysicalRecoveryFlow.charge(flow, pa, current, expected),
			"Strikecraft reconstructs actual first three distinct paid releases")
	var actual: Dictionary = team.recovery.evidence(state, team)
	check.call(actual.refunds.size() == 2 and ClubCareer.same(actual.refunds, expected),
		"Recovery proof preserves the two shared Strikecraft credits and club cap")
	check.call(PhysicalRecoveryFlow.near(current[String(roster[0].id)],
		state.pitcher().stamina_remaining), "credited stamina and replay finish at the same balance")


static func terminal(check: Callable, paid: Dictionary, mode: int) -> void:
	var build: SeasonBuild = paid.build
	var own: Array[PlayerDefinition] = []
	var other: Array[PlayerDefinition] = []
	for id: String in build.roster():
		own.append(build.definition(id))
	for id: String in [
		"player.dakota_wells", "player.mika_reed", "player.jamie_nash", "player.quinn_riley"
	]:
		other.append(SeasonBuild.new(9, [id]).definition(id))
	var team: TeamMatchState = TeamMatchState.create("Terminal Recovery", own)
	team.ai_heat = true
	team.ai_sponsor_choices = true
	team.ai_tactical_hitter = paid.club.roles.hitter
	team.ai_recovery_pitcher = paid.club.roles.pitcher
	team.pitcher_index = build.roster().find(paid.club.roles.pitcher)
	team.fielder_index = (team.pitcher_index + 1) % 4
	if mode == 1:
		team.tactics.held = [{"id": "boundary-recovery", "item": "C02", "paid": 4, "kind": "held"}]
	elif mode == 2:
		team.tactics.held = [
			{"id": "boundary-heat-1", "item": SeasonTacticalCatalog.HEAT, "paid": 5, "kind": "held"},
			{"id": "boundary-heat-2", "item": SeasonTacticalCatalog.HEAT, "paid": 5, "kind": "held"}
		]
	team.ai_tactical_initial.assign(team.tactics.held.duplicate(true))
	var opposition: TeamMatchState = TeamMatchState.create("Human Base", other)
	var target: String = SeasonOpponentHeat.target(opposition)
	for index in range(4):
		if String(other[index].id) == target:
			var featured: PlayerDefinition = other[index]
			other.remove_at(index)
			other.append(featured)
			break
	opposition = TeamMatchState.create("Human Base", other)
	var fresh: TeamMatchState = PhysicalMatchRequest._team(team)
	var state: MatchState = MatchState.create(team, opposition)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = state
	lab._match_mode = true
	lab._automation = MatchAutomation.new()
	var ordinal: Array[int] = [0, 0]
	for pa in range(1, 17):
		var half: int = 5 if pa == 16 else int((pa - 1) / 3)
		state.inning = half / 2 + 1
		state.top_half = half % 2 == 0
		state.plate_appearance_number = pa
		var batting: TeamMatchState = state.batting_team()
		batting.batting_index = ordinal[half % 2] % 4
		ordinal[half % 2] += 1
		SeasonOpponentChoices.prepare(lab)
		state.sides.rows.append({"pa": pa, "half": half,
			"player": String(state.batter().definition.id), "left": state.batter().bats_left()})
		state.performance.complete(state.batter().definition.id, state.pitcher().definition.id,
			"triple" if pa == 16 else "out", 0)
		var cost: float = state.pitcher().stamina_max * 0.11 if pa == 16 else 0.0
		state.pitcher().spend_stamina(cost)
		if not state.top_half:
			var recipe: StringName = state.pitcher().definition.starting_pitches[0].id
			state.sure_shot.release(state, recipe)
			team.recovery.release(state, recipe, cost)
	state.plate_appearance_number = 17
	opposition.batting_index = 3
	opposition.runs = MatchState.MERCY_RUNS - 1
	SeasonOpponentChoices.prepare(lab)
	opposition.tactics.held = [
		{"id": "boundary-base", "item": SeasonTacticalCatalog.BASE, "paid": 8, "kind": "held"}]
	state.bases.third = opposition.roster[2].definition.id
	check.call(opposition.tactics.activate(state, opposition, "boundary-base"),
		"shared human Base ends the game after defensive readiness")
	var proof: Dictionary = SeasonOpponentTactics.evidence(state, team)
	var roster: Array = own.map(func(player: PlayerDefinition) -> String: return String(player.id))
	var performance: Dictionary = state.performance.snapshot(state)
	check.call(state.phase == MatchState.Phase.GAME_END and proof.has("terminal")
		and PhysicalRecoveryEvidence.valid(proof, roster, performance, 0),
		"terminal proof reconciles empty, recovered or heated defensive readiness")
	check.call(PhysicalTacticalEvidence.matches(proof, fresh, opposition)
		and PhysicalHeatTerminal.human(proof, opposition.tactics.consumed, {"home": 0})
		and PhysicalHeatTerminal.ended(proof, 10, 0), "terminal binds the exact Base ledger and score")
	for field: String in ["ready", "cost", "base", "terminal"]:
		var bad: Dictionary = proof.duplicate(true)
		match field:
			"ready":
				bad.recovery.ready[-1].remaining -= 1.0
			"cost":
				bad.recovery.costs[-1].paid += 1.0
			"base":
				bad.terminal.advance.to = 3
			"terminal":
				bad.erase("terminal")
		check.call(not PhysicalRecoveryEvidence.valid(bad, roster, performance, 0),
			"altered terminal Recovery " + field + " rejects")
	lab.free()


static func capacity(make_build: Callable, check: Callable) -> void:
	for seed_value in range(2048):
		var build: SeasonBuild = make_build.call(seed_value)
		build.commit(SeasonOpponentPolicy.command(build, "open"))
		var offers: Array[String] = []
		for key: String in build._visit.offers:
			if build._visit.offers[key] in SeasonOpponentTactics.supported(10):
				offers.append(key)
		if offers.size() < 3 or not build._visit.offers.values().has("C02"):
			continue
		for index in range(2):
			check.call(build.commit(SeasonOpponentPolicy.command(build, "tactical_buy",
				{"offer": offers[index]})).ok, "generated mixed supplies share two paid slots")
		var before: Dictionary = build.to_data()
		check.call(not build.commit(SeasonOpponentPolicy.command(build, "tactical_buy",
			{"offer": offers[2]})).ok and ClubCareer.same(before, build.to_data()),
			"third real supply cannot overflow ownership or change stock, Cash or journal")
		check.call(SeasonOpponentTactics.useful_price(build) == 0,
			"full mixed supply bag cannot justify a tactical reroll")
		return
	check.call(false, "generated mixed Recovery capacity fixture missing")

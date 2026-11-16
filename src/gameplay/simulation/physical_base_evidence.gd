class_name PhysicalBaseEvidence
extends RefCounted
## Proof5 binds paid Base selection to actual complete occupancy and stamina chronology.
# gdlint: disable=max-returns


static func shape(row: Variant) -> bool:
	if not row is Dictionary or row.get("version") != 5 or not row.get("base") is Dictionary:
		return false
	var budget: Dictionary = row.duplicate()
	budget.version = 4
	if not PhysicalBudgetEvidence.shape(budget, 12):
		return false
	return row.initial.all(func(copy: Dictionary) -> bool: return not copy.id.is_empty())


static func valid(
	row: Variant, roster: Array, performance: Dictionary, parity: int, occupancy_checked: bool = false
) -> bool:
	return shape(row) and _valid_capacity(row, roster, performance, parity, occupancy_checked, 2)


static func league_valid(
	row: Variant, roster: Array, performance: Dictionary, parity: int,
	rules: Dictionary, ownership: Dictionary, occupancy_checked: bool = false
) -> bool:
	var wallet: Dictionary = PhysicalLeagueReport.wallet(rules, ownership)
	return not wallet.is_empty() and league_shape(row, rules, ownership) \
		and _valid_capacity(row, roster, performance, parity, occupancy_checked,
			int(wallet.capacity.held))


static func league_shape(row: Variant, rules: Dictionary, ownership: Dictionary) -> bool:
	if not row is Dictionary or row.get("version") != 5 or not row.get("base") is Dictionary:
		return false
	var budget: Dictionary = row.duplicate()
	budget.version = 4
	return PhysicalBudgetEvidence.league_shape(budget, rules, ownership) \
		and row.initial.all(func(copy: Dictionary) -> bool: return not copy.id.is_empty())


static func _valid_capacity(
	row: Dictionary, roster: Array, performance: Dictionary, parity: int,
	occupancy_checked: bool, capacity: int
) -> bool:
	if not row.get("opposition") is Dictionary \
		or not row.opposition.get("roster") is Array:
		return false
	var teams: Array = [roster, row.opposition.roster] if parity == 0 \
		else [row.opposition.roster, roster]
	if not occupancy_checked and not PhysicalBaseFlow.valid(row.base, teams, performance):
		return false
	var preempted: Variant = PhysicalBaseBag.preempted(row, parity)
	if preempted == null or not terminal(row, parity):
		return false
	var legacy: Dictionary = PhysicalBaseBag.recovery(row, true)
	if not PhysicalRecoveryEvidence._valid_capacity(
		legacy, roster, performance, parity, preempted, capacity):
		return false
	var stances: Array = row.stances + row.opposition.stances
	stances.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pa < b.pa)
	if stances.size() != row.base.results.size():
		return false
	for index in range(stances.size()):
		for key: String in ["pa", "half", "player"]:
			if stances[index][key] != row.base.results[index][key]:
				return false
	var last: Dictionary = {}
	for release: Dictionary in row.pitching:
		last[int(release.pa)] = release.player
	for result: Dictionary in row.base.results:
		if int(result.half) % 2 != parity and last.get(int(result.pa)) != result.pitcher:
			return false
	return true


static func terminal(row: Dictionary, parity: int) -> bool:
	var flow: Dictionary = row.base
	if flow.ready.size() == flow.results.size() or parity == 1:
		return not row.has("terminal")
	if not row.has("terminal") or flow.advances.is_empty():
		return false
	var advance: Dictionary = flow.advances[-1]
	return ClubCareer.same(row.terminal, {
		"pa": flow.final.pa, "half": flow.final.half, "player": flow.final.player,
		"pitcher": flow.final.pitcher, "base_receipt": advance.receipt, "advance": advance.advance})


static func matches(row: Dictionary, team: TeamMatchState, other: TeamMatchState) -> bool:
	return shape(row) and _matches(row, team, other)


static func league_matches(row: Dictionary, team: TeamMatchState, other: TeamMatchState) -> bool:
	if team == null or other == null or not team.ai_base \
		or not league_shape(row, team.league_rules, team.league_ownership) \
		or not ClubCareer.same(row.initial, team.ai_tactical_initial) \
		or not ClubCareer.same(row.budget, team.ai_budget) \
		or row.featured != team.ai_tactical_hitter \
		or row.recovery.pitcher != team.ai_recovery_pitcher \
		or row.opposition.target != SeasonOpponentHeat.target(other) \
		or row.opposition.roster != other.roster.map(
			func(player: PlayerMatchState) -> String: return String(player.definition.id)):
		return false
	var definitions: Dictionary = {}
	var refunders: Array[String] = []
	for player: PlayerMatchState in team.roster:
		var id: String = String(player.definition.id)
		definitions[id] = player.definition
		var initial: Dictionary = row.recovery.initial[id]
		if not PhysicalRecoveryFlow.near(initial.capacity, player.stamina_max) \
			or not PhysicalRecoveryFlow.near(initial.initial, player.stamina_remaining):
			return false
		if player.definition.season_sponsors.get("B03", false):
			refunders.append(id)
	if not definitions.has(row.featured) \
		or row.plan != SeasonOpponentTactics.plan(definitions[row.featured]) \
		or not ClubCareer.same(refunders, row.recovery.refunders):
		return false
	for release: Dictionary in row.pitching:
		if not definitions.has(release.player) or not definitions[release.player].starting_pitches.any(
			func(pitch: PitchDefinition) -> bool: return String(pitch.id) == release.recipe):
			return false
	return source_tags(row.base, [team, other])


static func _matches(row: Dictionary, team: TeamMatchState, other: TeamMatchState) -> bool:
	if not team.ai_base or other == null \
		or not ClubCareer.same(row.budget, team.ai_budget) \
		or not ClubCareer.same(row.initial, team.ai_tactical_initial):
		return false
	var fresh: TeamMatchState = PhysicalMatchRequest._team(team)
	if fresh == null:
		return false
	fresh.ai_base = false
	fresh.ai_budget = {}
	fresh.ai_tactical_initial = fresh.ai_tactical_initial.filter(func(copy: Dictionary) -> bool:
		return copy.item != SeasonTacticalCatalog.BASE)
	fresh.tactics.held.assign(fresh.ai_tactical_initial.duplicate(true))
	return PhysicalRecoveryEvidence.matches(PhysicalBaseBag.recovery(row), fresh, other) \
		and source_tags(row.base, [team, other])


static func source_tags(flow: Dictionary, teams: Array) -> bool:
	var definitions: Dictionary = {}
	var controlled: Array = []
	for team: TeamMatchState in teams:
		for player: PlayerMatchState in team.roster:
			var id: String = String(player.definition.id)
			definitions[id] = player.definition
			if team.ai_base:
				controlled.append(id)
	for tag: Dictionary in flow.tags:
		var result: Dictionary = flow.results[int(tag.pa) - 1]
		# Human inventory may retire a sold effect at a later safe PA boundary.
		# Only immutable automated club definitions are bound here.
		if controlled.has(tag.defender):
			var defender: PlayerDefinition = definitions[tag.defender]
			if tag.rating != defender.fielding or not PhysicalRecoveryFlow.near(
				tag.gather, SeasonSponsorEffects.gather_scale(defender)):
				return false
		if controlled.has(result.player) and not PhysicalRecoveryFlow.near(
			tag.travel, SeasonSponsorEffects.tag_scale(definitions[result.player])):
			return false
	return true


static func enriched(row: Dictionary, flow: Dictionary) -> Dictionary:
	var result: Dictionary = row.duplicate()
	result["base"] = flow
	return result


static func human(row: Dictionary, tactics: Array, human_parity: int) -> bool:
	var actual: Array = row.base.advances.filter(func(advance: Dictionary) -> bool:
		return int(advance.after.half) % 2 == human_parity)
	var expected: Array = []
	for action: Variant in tactics:
		if not action is Dictionary:
			return false
		if action.has("advance"):
			expected.append(action)
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		var base_action: Dictionary = {"receipt": actual[index].receipt,
			"player": actual[index].after.player, "pa": actual[index].after.pa,
			"swing": "", "advance": actual[index].advance}
		for key: String in base_action:
			if not ClubCareer.same(base_action[key], expected[index].get(key)):
				return false # Other human sponsor fields are validated by the shared paid ledger.
	return true


static func ended(row: Dictionary, away: int, home: int) -> bool:
	if row.get("version") != 5:
		return true
	return row.get("base") is Dictionary and row.base.get("final") is Dictionary \
		and row.base.final.get("away") == away and row.base.final.get("home") == home

class_name PhysicalLeagueReport
extends RefCounted
## Closed report27. Capacity comes from replayed ownership, never report integers.
# gdlint: disable=max-returns

const VERSION: int = 27
const RESOLVER: String = "physical-league-base-capacity-v1"


static func wallet(rules: Variant, ownership: Variant) -> Dictionary:
	var normalized: Dictionary = LeagueRules.normalized(rules)
	var bank_version: int = (
		SeasonOwnership.LEAGUE_TIER_VERSION if LeagueRules.tiered(normalized)
		else SeasonOwnership.LEAGUE_VERSION
	)
	if (
		normalized.is_empty()
		or not ownership is Dictionary
		or not SeasonOwnership._whole(
			ownership.get("version"), bank_version, bank_version
		)
	):
		return {}
	var bank: SeasonOwnership = SeasonOwnership.from_data(
		ownership, SeasonSponsorCatalog.ownership_catalog()
	)
	if (
		bank == null
		or not bank.league_rules_valid()
		or not ClubCareer.same(bank._league_rules, normalized)
	):
		return {}
	return bank.view()


static func team_valid(team: TeamMatchState) -> bool:
	if team == null or not dynasty_team_valid(team):
		return false
	var owned: Dictionary = wallet(team.league_rules, team.league_ownership)
	if owned.is_empty() or not inventory_field_valid(team, owned):
		return false
	if LeagueRules.doubleheader(team.league_rules):
		if not PhysicalWorkloadEvidence.pair_valid(team.league_pair):
			return false
		for player: PlayerMatchState in team.roster:
			if player == null or player.definition == null:
				return false
			if not PhysicalRecoveryFlow.near(
				player.stamina_remaining,
				maxf(
					0.0,
					(
						player.stamina_max
						- float(team.league_pair.debt.get(String(player.definition.id), 0.0))
					)
				)
			):
				return false
	elif not team.league_pair.is_empty():
		return false
	if LeagueRules.equipment(team.league_rules):
		var active: Dictionary = {}
		for slot: String in SeasonOwnership.GEAR_SLOTS:
			if not owned.gear[slot].is_empty():
				active[slot] = owned.gear[slot].item
		for player: PlayerMatchState in team.roster:
			if (
				player == null
				or player.definition == null
				or not ClubCareer.same(player.definition.season_gear, active)
			):
				return false
	if not team.ai_base:
		return (
			team.ai_budget.is_empty()
			and team.ai_tactical_initial.is_empty()
			and not team.ai_heat
			and team.ai_recovery_pitcher.is_empty()
			and team.ai_tactical_hitter.is_empty()
			and team.field_supply.capacity == owned.capacity.held
			and (
				team.field_supply.reserved
				== owned.held.size() - SeasonTacticalCatalog.held(owned).size()
			)
			and ClubCareer.same(team.tactics.held, SeasonTacticalCatalog.held(owned))
		)
	if (
		team.ai_recovery_pitcher.is_empty()
		or not team.ai_heat
		or team.ai_tactical_hitter.is_empty()
		or not team.ai_sponsor_choices
	):
		return false
	return PhysicalBudgetEvidence.league_shape(
		{"version": 4, "budget": team.ai_budget, "initial": team.ai_tactical_initial},
		team.league_rules,
		team.league_ownership
	)


static func capture_context_valid(state: MatchState) -> bool:
	return _capture_context_valid(state, "")


static func _capture_context_valid(state: MatchState, pitch_catalog: String) -> bool:
	if not pitch_catalog.is_empty() and (not PhysicalPitchEvidence.context_valid(pitch_catalog)
		or state == null or state.pitch_catalog != pitch_catalog):
		return false
	if state == null or state.away_team == null or state.home_team == null:
		return false
	if not pitch_catalog.is_empty() and pitch_catalog != WorkingPitchCatalog.signature() and not state.league_rules.is_empty():
		return false
	var present: bool = not state.league_rules.is_empty()
	for team: TeamMatchState in [state.away_team, state.home_team]:
		present = (
			present
			or not team.league_rules.is_empty()
			or not team.league_ownership.is_empty()
			or not team.league_pair.is_empty()
			or not team.recovery.workload_initial.is_empty()
			or not team.recovery.workload_events.is_empty()
			or not team.recovery.workload_input.is_empty()
			or not team.inventory_actions.is_empty()
			or not team.dynasty_start.is_empty()
		)
	if not present:
		return true  # Historical capture is unchanged.
	var rules: Dictionary = LeagueRules.normalized(state.league_rules)
	if rules.is_empty() or (pitch_catalog.is_empty() and not state.stadium.is_empty()):
		return false
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var owned: Dictionary = wallet(rules, team.league_ownership)
		if (
			not ClubCareer.same(team.league_rules, rules)
			or owned.is_empty()
			or not dynasty_team_valid(team)
		):
			return false
		if (
			not team.inventory_actions.is_empty()
			and owned.get("inventory_rules", "") != SeasonInventoryResale.RULE
		):
			return false
		if LeagueRules.doubleheader(rules):
			if not PhysicalWorkloadEvidence.pair_valid(team.league_pair):
				return false
		elif (
			not team.league_pair.is_empty()
			or not team.recovery.workload_initial.is_empty()
			or not team.recovery.workload_events.is_empty()
			or not team.recovery.workload_input.is_empty()
		):
			return false
	if (
		not state.away_team.dynasty_start.is_empty()
		and not state.home_team.dynasty_start.is_empty()
	):
		return false
	return true


static func wrap(body: Dictionary, state: MatchState) -> Dictionary:
	if state != null and not state.pitch_catalog.is_empty():
		return {} # Current producers must retain their Report29 catalog boundary.
	if state == null or not state.stadium.is_empty():
		return {}
	var rules: Dictionary = LeagueRules.normalized(state.league_rules)
	if rules.is_empty() or LeagueRules.doubleheader(rules):
		return {}
	var ownership: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		# The immutable initial bank, not the depleted live bag, is captured here.
		if (
			team == null
			or not ClubCareer.same(team.league_rules, rules)
			or wallet(rules, team.league_ownership).is_empty()
		):
			return {}
		ownership.append(team.league_ownership.duplicate(true))
	var result: Dictionary = {
		"version": VERSION,
		"resolver": RESOLVER,
		"league_rules": rules,
		"ownership": ownership,
		"physical": body.duplicate(true)
	}
	result.physical["league_bound"] = true
	if LeagueRules.dynasty(rules):
		if not capture_context_valid(state):
			return {}
		result["dynasty_start"] = [
			state.away_team.dynasty_start.duplicate(true),
			state.home_team.dynasty_start.duplicate(true)
		]
	return result if valid(result) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var fields: Array = ["version", "resolver", "league_rules", "ownership", "physical"]
	if LeagueRules.dynasty(value.get("league_rules")):
		fields.append("dynasty_start")
	if (
		not SeasonOwnership._keys(value, fields)
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or value.resolver != RESOLVER
		or not value.ownership is Array
		or value.ownership.size() != 2
		or not value.physical is Dictionary
	):
		return false
	var rules: Dictionary = LeagueRules.normalized(value.league_rules)
	if (
		rules.is_empty()
		or LeagueRules.doubleheader(rules)
		or not SeasonOwnership._whole(
			value.physical.get("version"),
			PhysicalMatchReport.BASE_VERSION,
			PhysicalMatchReport.BASE_VERSION
		)
	):
		return false
	for ownership: Variant in value.ownership:
		if wallet(rules, ownership).is_empty():
			return false
	if not PhysicalMatchReport._valid_core(value.physical, rules, value.ownership):
		return false
	if LeagueRules.dynasty(rules):
		if not value.dynasty_start is Array or value.dynasty_start.size() != 2:
			return false
		var carried: int = 0
		for index in range(2):
			if not _dynasty_entry_valid(
				value.dynasty_start[index],
				value.physical.teams[index].roster,
				value.physical.tactics.clubs[index]
			):
				return false
			carried += int(not value.dynasty_start[index].is_empty())
		if carried > 1:
			return false
	return true


static func core(value: Dictionary) -> Dictionary:
	return value.physical.duplicate(true) if valid(value) else {}


static func matches(value: Dictionary, state: MatchState) -> bool:
	if state != null and not state.pitch_catalog.is_empty():
		return false
	if (
		state == null
		or state.away_team == null
		or state.home_team == null
		or not state.stadium.is_empty()
		or not valid(value)
		or not ClubCareer.same(value.league_rules, state.league_rules)
	):
		return false
	return _matches_bound(value, state)


# Only a fully validated versioned wrapper may reuse immutable policy binding.
static func _matches_bound(value: Dictionary, state: MatchState) -> bool:
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	var body: Dictionary = value.physical
	if (
		not PhysicalChoiceEvidence._matches_core(body, state)
		or body.tactics.clubs != [teams[0].ai_base, teams[1].ai_base]
	):
		return false
	for index in range(2):
		var team: TeamMatchState = teams[index]
		if (
			not dynasty_team_valid(team)
			or (
				LeagueRules.dynasty(value.league_rules)
				and not ClubCareer.same(value.dynasty_start[index], team.dynasty_start)
			)
		):
			return false
		if (
			not ClubCareer.same(team.league_rules, value.league_rules)
			or not ClubCareer.same(team.league_ownership, value.ownership[index])
		):
			return false
		if (
			team.ai_base
			and not PhysicalBaseEvidence.league_matches(
				PhysicalBaseEvidence.enriched(body.tactics.teams[index], body.tactics.base),
				team,
				teams[1 - index]
			)
		):
			return false
	return true


static func inventory_field_valid(team: TeamMatchState, owned: Dictionary) -> bool:
	if owned.get("inventory_rules") != SeasonInventoryResale.RULE or team.ai_base:
		return not team.field_supply.retired
	var text: String = team.field_supply.receipt
	if (
		not text.begins_with("field-supply:")
		or not text.trim_prefix("field-supply:").is_valid_int()
	):
		return false
	var game: int = int(text.trim_prefix("field-supply:"))
	if game < 0 or game > 32 or text != SeasonFieldGrant.receipt(game):
		return false
	var retired: bool = false
	for event: Dictionary in team.league_ownership.events:
		if (
			(event.get("op") == SeasonInventoryResale.FIELD_OP and event.get("game") == game)
			or (event.get("op") == SeasonInventoryResale.SALE_OP and event.get("receipt") == text)
		):
			retired = true
	return team.field_supply.retired == retired


static func dynasty_team_valid(team: TeamMatchState) -> bool:
	if team == null:
		return false
	if not LeagueRules.dynasty(team.league_rules):
		return team.dynasty_start.is_empty()
	var ids: Array = []
	for player: PlayerMatchState in team.roster:
		if player == null or player.definition == null:
			return false
		ids.append(String(player.definition.id))
	return _dynasty_entry_valid(team.dynasty_start, ids, team.ai_base)


static func _dynasty_entry_valid(value: Variant, roster: Array, ai: bool) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true
	if ai:
		return false
	var profile: Dictionary = (
		preload("res://src/gameplay/season/dynasty_start_profile.gd").normalize(value)
	)
	if profile.is_empty():
		return false
	var expected: Array = profile.roster.duplicate()
	var actual: Array = roster.duplicate()
	expected.sort()
	actual.sort()
	return actual == expected

class_name PhysicalDoubleheaderReport
extends RefCounted
## Report28: explicit pair debt and full ordered workload for immutable-bank detached games.
## Managed human live sales use capture_human/human_matches with the replayed sale cutoff,
## not this wrapper. Automated human diagnostics with live sales must use that managed path.
# gdlint: disable=max-returns

const VERSION: int = 28
const RESOLVER: String = "physical-doubleheader-workload-v1"


static func wrap(body: Dictionary, state: MatchState) -> Dictionary:
	if state != null and not state.pitch_catalog.is_empty():
		return {} # Current producers must retain their Report29 catalog boundary.
	if state == null or not PhysicalLeagueReport.capture_context_valid(state) \
		or not LeagueRules.doubleheader(state.league_rules):
		return {}
	var result: Dictionary = {"version": VERSION, "resolver": RESOLVER,
		"league_rules": LeagueRules.normalized(state.league_rules), "ownership": [],
		"pair": [], "workload": [], "uses": [], "physical": body.duplicate(true)}
	result.physical["league_bound"] = true
	result.physical["doubleheader_bound"] = true
	for team: TeamMatchState in [state.away_team, state.home_team]:
		result.ownership.append(team.league_ownership.duplicate(true))
		result.pair.append(team.league_pair.duplicate(true))
		result.workload.append(PhysicalWorkloadEvidence.capture(state, team))
		result.uses.append(team.tactics.consumed.duplicate(true))
	return result if valid(result) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "resolver", "league_rules", "ownership", "pair", "workload", "uses", "physical"]) \
		or not SeasonOwnership._whole(value.version, VERSION, VERSION) or value.resolver != RESOLVER \
		or not LeagueRules.doubleheader(value.league_rules) or not value.physical is Dictionary:
		return false
	for key: String in ["ownership", "pair", "workload", "uses"]:
		if not value[key] is Array or value[key].size() != 2:
			return false
	var wallets: Array = []
	for index in range(2):
		var wallet: Dictionary = PhysicalLeagueReport.wallet(value.league_rules, value.ownership[index])
		if wallet.is_empty() or not PhysicalWorkloadEvidence.pair_valid(value.pair[index]) \
			or not value.uses[index] is Array or value.uses[index].size() > 64:
			return false
		wallets.append(wallet)
	if value.pair[0].game != value.pair[1].game:
		return false
	if not PhysicalMatchReport._valid_core(value.physical, value.league_rules, value.ownership, true):
		return false
	var body: Dictionary = value.physical
	for index in range(2):
		var team: Dictionary = body.teams[index]
		var proof: Variant = value.workload[index]
		if not PhysicalWorkloadEvidence.valid(proof, team.roster, body.performance,
			team.pitching, value.uses[index], wallets[index], value.pair[index], 99999):
			return false
		if body.tactics.clubs[index] and not ClubCareer.same(
			value.uses[index], body.tactics.teams[index].consumed):
			return false
		var releases: Array = []
		for event: Dictionary in proof.events:
			if int(event.half) % 2 != 1 - index:
				return false
			if event.kind == "release":
				releases.append({"pa": event.pa, "half": event.half, "player": event.player,
					"recipe": event.recipe, "paid": event.paid})
		var expected: Array = body.releases.filter(func(row: Dictionary) -> bool:
			return team.roster.has(row.player))
		if not ClubCareer.same(releases, expected):
			return false
		for id: String in team.roster:
			var workload: Dictionary = team.workload[id]
			if not PhysicalRecoveryFlow.near(proof.initial[id].capacity, workload.capacity) \
				or not PhysicalRecoveryFlow.near(proof.initial[id].initial, workload.initial) \
				or not PhysicalRecoveryFlow.near(proof.remaining[id], workload.remaining):
				return false
	return true


static func core(value: Dictionary) -> Dictionary:
	return value.physical.duplicate(true) if valid(value) else {}


static func matches(value: Dictionary, state: MatchState) -> bool:
	if state != null and not state.pitch_catalog.is_empty():
		return false
	if state == null or state.away_team == null or state.home_team == null \
		or not PhysicalLeagueReport.capture_context_valid(state) or not valid(value) \
		or not ClubCareer.same(value.league_rules, state.league_rules) \
		or not PhysicalLeagueReport._matches_bound(value, state):
		return false
	var teams: Array[TeamMatchState] = [state.away_team, state.home_team]
	for index in range(2):
		if not ClubCareer.same(value.pair[index], teams[index].league_pair) \
			or not PhysicalWorkloadEvidence.valid_for_team(value.workload[index], teams[index],
				value.physical.performance, value.physical.teams[index].pitching,
				value.uses[index], 99999):
			return false
	return true


static func human(value: Dictionary, index: int) -> Dictionary:
	if index not in [0, 1] or not valid(value):
		return {}
	return {"version": PhysicalWorkloadEvidence.VERSION, "pair": value.pair[index].duplicate(true),
		"proof": value.workload[index].duplicate(true)}

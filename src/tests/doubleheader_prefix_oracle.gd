extends RefCounted
## Closed pair fatigue is derived from the exact validated first fixture, not a mutable meter.


static func install_schedule(season: SeasonState) -> void:
	if LeagueRules.doubleheader(season.league_rules):
		season.schedule.assign(SeasonDoubleheaderRules.schedule())


static func _build(season: SeasonState, club: int) -> SeasonBuild:
	if club == 0:
		return (
			season._doubleheader_replay_build
			if season._doubleheader_replay_build != null
			else season.build
		)
	return season.opponents.clubs[str(club)].build


static func _prefix(season: SeasonState, club: int, game: int) -> Dictionary:
	var build: SeasonBuild = _build(season, club)
	if (
		build == null
		or not build.league_context_valid()
		or build._league_rules != season.league_rules
	):
		return {}
	var prefix: SeasonBuild = build
	if build._bank.view().rewards.has(str(game)):
		prefix = SeasonBuildRestore.restore(
			build.to_data(), build._seed, build._initial_roster, build._pool, build._blocked, game
		)
	if prefix == null:
		return {}
	return SeasonDoubleheaderBuild.context(prefix, game)


static func _historical_team(season: SeasonState, club: int, game: int) -> Dictionary:
	var prefix: Dictionary = _prefix(season, club, game)
	if prefix.is_empty():
		return {}
	var players: Array[PlayerDefinition] = []
	for id: String in prefix.roster:
		players.append(prefix.definitions[id])
	var team: TeamMatchState = TeamMatchState.create(season.teams[club].name, players)
	team.league_rules = season.league_rules.duplicate(true)
	team.league_ownership = prefix.ownership.duplicate(true)
	if not apply(season, club, game, team):
		return {}
	return {
		"team": team, "refund_through": prefix.refund_through, "cost_context": prefix.cost_context
	}


static func apply(season: SeasonState, club: int, game: int, team: TeamMatchState) -> bool:
	if not LeagueRules.doubleheader(season.league_rules):
		return true
	if team == null or not SeasonOwnership._whole(game, 0, 32):
		return false
	var first: int = SeasonDoubleheaderRules.first(game)
	var debt: Dictionary = {}
	if first >= 0:
		var source: Dictionary = {}
		for result: Dictionary in season.results:
			if int(result.id) == first and (result.away == club or result.home == club):
				source = result
				break
		if (
			source.is_empty()
			or not source.get("doubleheader_evidence") is Array
			or source.doubleheader_evidence.size() != 2
		):
			return false
		var historical: Dictionary = _historical_team(season, club, first)
		if historical.is_empty() or not _matches_result(source, club, historical):
			return false
		var side: int = 0 if source.away == club else 1
		var envelope: Dictionary = source.doubleheader_evidence[side]
		var paid: bool = false
		var owner: SeasonBuild = _build(season, club)
		for event: Dictionary in owner._events:
			if event.get("op") == "reward" and event.get("game") == first:
				paid = (
					ClubCareer.same(event.get("doubleheader_workload"), envelope)
					and owner._bank.view().rewards.get(str(first)) == event.get("win")
				)
				break
		if not paid:
			return false
		debt = PhysicalWorkloadEvidence.net_debt(envelope.proof, envelope.pair.debt)
	team.league_pair = {"game": game, "first": first, "debt": debt.duplicate(true)}
	for player: PlayerMatchState in team.roster:
		player.stamina_remaining = maxf(
			0.0, player.stamina_max - float(debt.get(String(player.definition.id), 0.0))
		)
	return true


static func _pitching(result: Dictionary, club: int) -> Dictionary:
	if club == 0:
		return result.get("pitching", {}).duplicate(true)
	var row: Dictionary = result.get("ai_tactics", {}).get(str(club), {})
	return {
		"releases": row.get("pitching", []),
		"strikeouts": row.get("recovery", {}).get("strikeouts", [])
	}


static func _uses(result: Dictionary, club: int) -> Array:
	return (
		result.get("tactics", []).duplicate(true)
		if club == 0
		else result.get("ai_tactics", {}).get(str(club), {}).get("consumed", []).duplicate(true)
	)


static func _matches_result(result: Dictionary, club: int, expected: Dictionary) -> bool:
	var side: int = 0 if result.away == club else 1
	var envelope: Variant = result.doubleheader_evidence[side]
	if not PhysicalWorkloadEvidence.human_matches(
		envelope,
		expected.team,
		result.get("performance", {}),
		_pitching(result, club),
		_uses(result, club),
		expected.refund_through,
		expected.cost_context
	):
		return false
	for event: Dictionary in envelope.proof.events:
		if int(event.half) % 2 != 1 - side:
			return false
	if club != 0:
		var row: Dictionary = result.get("ai_tactics", {}).get(str(club), {})
		if row.is_empty() or not row.get("recovery") is Dictionary:
			return false
		for id: String in envelope.proof.initial:
			if (
				not ClubCareer.same(envelope.proof.initial[id], row.recovery.initial.get(id, {}))
				or not PhysicalRecoveryFlow.near(
					envelope.proof.remaining[id], row.recovery.remaining.get(id, -1)
				)
			):
				return false
	return true


static func accepts(
	season: SeasonState,
	fixture: Dictionary,
	evidence: Variant,
	performance: Dictionary,
	pitching: Dictionary,
	tactics: Array,
	ai_tactics: Dictionary
) -> bool:
	if not LeagueRules.doubleheader(season.league_rules):
		return evidence == null
	if fixture.is_empty() or not evidence is Array or evidence.size() != 2:
		return false
	var opponent: int = int(fixture.away if fixture.home == 0 else fixture.home)
	var row: Dictionary = fixture.duplicate(true)
	row.performance = performance
	row.pitching = pitching
	row.tactics = tactics
	row.ai_tactics = {str(opponent): ai_tactics}
	row.doubleheader_evidence = evidence
	for club: int in [int(fixture.away), int(fixture.home)]:
		var expected: Dictionary = _historical_team(season, club, int(fixture.id))
		if expected.is_empty() or not _matches_result(row, club, expected):
			return false
	return true


static func capture(state: MatchState) -> Array:
	return [
		PhysicalWorkloadEvidence.capture_human(state, state.away_team),
		PhysicalWorkloadEvidence.capture_human(state, state.home_team)
	]


static func replay_result(
	season: SeasonState,
	result: Dictionary,
	performance: Dictionary,
	ai_tactics: Dictionary,
	replayed_tactics: Array
) -> bool:
	if (
		not result.get("doubleheader_evidence") is Array
		or season._doubleheader_replay_build == null
	):
		return false
	var full: SeasonBuild = season._doubleheader_replay_build
	var prefix: SeasonBuild = SeasonBuildRestore.restore(
		full.to_data(), full._seed, full._initial_roster, full._pool, full._blocked, int(result.id)
	)
	if prefix == null:
		return false
	var reward: Dictionary = {}
	for event: Dictionary in full._events:
		if event.get("op") == "reward" and event.get("game") == result.id:
			reward = event
			break
	if reward.is_empty():
		return false
	season.build = prefix
	return season._record_player_result(
		int(result.id),
		int(result.away_runs),
		int(result.home_runs),
		performance,
		reward.get("used_gear", []),
		reward.get("tactics", []),
		reward.get("batting", {}),
		reward.get("stances", []),
		reward.get("fielding", []),
		reward.get("pitching", {}),
		reward.get("field_supply", {}),
		reward.get("frozen", []),
		ai_tactics,
		replayed_tactics,
		"",
		null,
		null,
		null,
		result.doubleheader_evidence
	)

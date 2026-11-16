class_name SeasonOpponentBudget
extends RefCounted
## Pure committed-fixture projection; publish its exact journal with round settlement.


static func commit(build: SeasonBuild, game: int) -> bool:
	if SeasonSchoolSponsors.active(build, "E08").is_empty():
		return true # No sponsor means no grant transaction or historical eligibility.
	if build._pregames.has(str(game)):
		return true
	return build.commit(SeasonOpponentPolicy.command(build, "pregame", {"game": game})).ok


static func prepare(team: TeamMatchState, build: SeasonBuild, game: int) -> void:
	if game < 0:
		return
	var before: Array[Dictionary] = SeasonTacticalCatalog.held(build._bank.view())
	var proof: Dictionary = {"game": game, "cash": build.cash(),
		"active": not SeasonSchoolSponsors.active(build, "E08").is_empty(),
		"before": before.duplicate(true), "outcome": SeasonBudgetBites.outcome(build)}
	team.ai_budget = proof
	team.tactics.held = before
	if proof.outcome == "granted":
		var projected: SeasonBuild = build._fork()
		if not commit(projected, game):
			team.ai_budget = {}
			return
		team.tactics.held = SeasonTacticalCatalog.held(projected._bank.view())
	team.ai_tactical_initial.assign(team.tactics.held.duplicate(true))


static func reroll_useful(build: SeasonBuild, club: Dictionary) -> bool:
	var after: int = build.cash() - build.reroll_price()
	return build._market in [11, 12] and club.profile == "Distributed" and after in range(10, 15) \
		and SeasonOpponentSponsors.pool(build).has("E08") \
		and build._bank.view().sponsors.size() < (int(build._bank.view().capacity.sponsors) \
			if LeagueRules.sponsorship(build._league_rules) else 5) \
		and build._bank.view().held.size() < build._bank.view().capacity.held

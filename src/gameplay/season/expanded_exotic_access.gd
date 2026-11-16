class_name ExpandedExoticAccess
extends RefCounted
## Access is derived from exact retained evidence. It never grants a recipe or cash.


static func valid_history(value: Variant) -> bool:
	if not value is Array or not value.is_empty():
		return false
	for proof: Variant in value:
		if not ExpandedExoticEligibility.valid(proof):
			return false
	return true


static func ids(proofs: Array) -> Array[String]:
	var result: Array[String] = []
	if not valid_history(proofs):
		return result
	for proof: Dictionary in proofs:
		for id: String in ExpandedExoticEligibility.eligible_ids(proof):
			if not result.has(id):
				result.append(id)
	result.sort()
	return result


static func price(id: String) -> int:
	for name: String in ExpandedSeasonCatalog.RESERVED_EXOTICS:
		if ExpandedSeasonCatalog.RESERVED_EXOTICS[name].has(id):
			return int(ExpandedExoticEligibility.PRICES[name.to_lower()])
	return -1


static func proof_prefix(previous: Variant, next: Variant) -> bool:
	if not ExpandedExoticEligibility.valid(previous) or not ExpandedExoticEligibility.valid(next) \
		or previous.season != next.season or previous.games.size() > next.games.size():
		return false
	for index in range(previous.games.size()):
		if not ClubCareer.same(previous.games[index], next.games[index]):
			return false
	return true


static func current_matches(season: SeasonState, build: SeasonBuild = null) -> bool:
	if season == null or season.build == null or season.build._book == null \
		or (build != null and build._book == null):
		return false
	var captured: Dictionary = ExpandedExoticEligibility.capture(season)
	if captured.is_empty():
		return false
	var current: Dictionary = (season.build if build == null else build)._book._exotic_current
	return captured.games.is_empty() if current.is_empty() else ClubCareer.same(current, captured)


static func admit(season: SeasonState) -> bool:
	if season == null or season.build == null or not season.build.pitch_catalog_expanded():
		return false
	var proof: Dictionary = ExpandedExoticEligibility.capture(season)
	if proof.is_empty() or proof.games.is_empty():
		return false
	if ClubCareer.same(proof, season.build._book._exotic_current):
		return true
	return season.build.commit({"id": "exotic:%d" % int(proof.games[-1].game),
		"rev": season.build.revision(), "op": "exotic_admit", "proof": proof}).ok


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if build == null or not build.pitch_catalog_expanded() or build._market != 0 or not build._keys(command, ["proof"]) \
		or not ExpandedExoticEligibility.valid(command.get("proof")):
		return "Invalid current Exotic admission."
	var proof: Dictionary = command.proof
	if proof.season != build._book._season_key or proof.games.is_empty():
		return "Exotic admission belongs to another season."
	var games: Array = []
	for event: Dictionary in build._events:
		if event.get("op") != "reward":
			continue
		var game: Dictionary = {"id": event.game, "club_roster": build.roster_for_game(int(event.game)),
			"performance": event.get("performance"), "pitching": event.get("pitching")}
		game.club_roster.sort()
		if event.has("pitching_current"):
			game["pitching_current"] = event.pitching_current
		var row: Dictionary = ExpandedExoticEligibility._capture_game(game)
		if row.is_empty():
			return "Exotic admission requires complete settled reward evidence."
		games.append(row)
	if not ClubCareer.same(proof.games, games) or (not build._book._exotic_current.is_empty() \
		and not proof_prefix(build._book._exotic_current, proof)):
		return "Exotic admission changed settled evidence."
	build._book.retain_exotic_current(proof)
	return ""


static func finalized_candidate(build: SeasonBuild, results: Array, result: Dictionary) -> SeasonBuild:
	# Isolated proposed finalized state: failure cannot mutate caller's journal or rows.
	if build == null or not build.pitch_catalog_expanded():
		return null
	var proposed: SeasonState = SeasonState.new()
	proposed.build = build._fork()
	proposed.player_results.assign(results.duplicate(true))
	proposed.player_results.append(result.duplicate(true))
	return proposed.build if admit(proposed) else null

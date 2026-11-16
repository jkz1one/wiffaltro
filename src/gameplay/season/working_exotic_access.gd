class_name WorkingExoticAccess
extends RefCounted
## Access is derived from exact retained evidence. It never grants a recipe or cash.


static func valid_history(value: Variant) -> bool:
	if not value is Array or value.size() > ClubCareer.MAX_RUNS:
		return false
	for proof: Variant in value:
		if not WorkingExoticEligibility.valid(proof):
			return false
	return true


static func history(career: ClubCareer, before_run: int = 0) -> Array:
	var result: Array = []
	if career == null or career._pitch_catalog != WorkingPitchCatalog.signature():
		return result
	for run: Dictionary in career.runs:
		if before_run > 0 and run.id >= before_run:
			break
		var progress: Variant = run.get("player_progress")
		if WorkingPitchCareerProgress.is_current(progress) and WorkingExoticEligibility.valid(progress.get("exotic")):
			result.append(progress.exotic.duplicate(true))
	return result


static func ids(proofs: Array) -> Array[String]:
	var result: Array[String] = []
	if not valid_history(proofs):
		return result
	for proof: Dictionary in proofs:
		for id: String in WorkingExoticEligibility.eligible_ids(proof):
			if not result.has(id):
				result.append(id)
	result.sort()
	return result


static func price(id: String) -> int:
	for name: String in WorkingPitchCatalog.RESERVED_EXOTICS:
		if WorkingPitchCatalog.RESERVED_EXOTICS[name].has(id):
			return int(WorkingExoticEligibility.PRICES[name.to_lower()])
	return -1


static func prefix(previous: Variant, next: Variant) -> bool:
	if not WorkingPitchCareerProgress.is_current(previous) or not WorkingPitchCareerProgress.is_current(next):
		return false
	if not previous.get("games") is Array or not next.get("games") is Array or previous.games.size() > next.games.size():
		return false
	for index in range(previous.games.size()):
		if not ClubCareer.same(previous.games[index], next.games[index]):
			return false
	return proof_prefix(previous.get("exotic"), next.get("exotic"))


static func proof_prefix(previous: Variant, next: Variant) -> bool:
	if not WorkingExoticEligibility.valid(previous) or not WorkingExoticEligibility.valid(next) \
		or previous.season != next.season or previous.games.size() > next.games.size():
		return false
	for index in range(previous.games.size()):
		if not ClubCareer.same(previous.games[index], next.games[index]):
			return false
	return true


static func matches(career: ClubCareer, season: SeasonState) -> bool:
	return career != null and season != null and season.build != null \
		and season.build._book != null and career.current > 0 \
		and ClubCareer.same(season.build._book._exotic_start, history(career, career.current)) \
		and current_matches(season)


static func current_matches(season: SeasonState, build: SeasonBuild = null) -> bool:
	if season == null or season.build == null or season.build._book == null \
		or (build != null and build._book == null):
		return false
	var captured: Dictionary = WorkingExoticEligibility.capture(season)
	if captured.is_empty():
		return false
	var current: Dictionary = (season.build if build == null else build)._book._exotic_current
	return captured.games.is_empty() if current.is_empty() else ClubCareer.same(current, captured)


static func admit(season: SeasonState) -> bool:
	if season == null or season.build == null or not season.build.pitch_catalog_current():
		return false
	var proof: Dictionary = WorkingExoticEligibility.capture(season)
	if proof.is_empty() or proof.games.is_empty():
		return false
	if ClubCareer.same(proof, season.build._book._exotic_current):
		return true
	return season.build.commit({"id": "exotic:%d" % int(proof.games[-1].game),
		"rev": season.build.revision(), "op": "exotic_admit", "proof": proof}).ok


static func settle(build: SeasonBuild, command: Dictionary) -> String:
	if build == null or not build.pitch_catalog_current() or build._market != 0 or not build._keys(command, ["proof"]) \
		or not WorkingExoticEligibility.valid(command.get("proof")):
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
		var row: Dictionary = WorkingExoticEligibility._capture_game(game)
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
	if build == null or not build.pitch_catalog_current():
		return null
	var proposed: SeasonState = SeasonState.new()
	proposed.build = build._fork()
	proposed.player_results.assign(results.duplicate(true))
	proposed.player_results.append(result.duplicate(true))
	return proposed.build if admit(proposed) else null

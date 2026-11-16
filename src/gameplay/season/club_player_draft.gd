class_name ClubPlayerDraft
extends RefCounted
## Permanent access is frozen at season entry; new cards become eligible next season.


static func apply(season: SeasonState, owned: Array) -> bool:
	if season == null or season.phase != SeasonState.Phase.DRAFT or not season.picks.is_empty() \
		or season.build == null or season.opponents == null or season.opponents._format != 13 \
		or season.physical == null or not ClubPlayerCatalog.valid_ids(owned):
		return false
	var next_pool: Array[String] = pool(season.season_seed, owned)
	if next_pool.size() < 12 or LeagueRules.dynasty(season.league_rules):
		return false
	season.player_access.assign(owned)
	season.build._pool.assign(owned)
	season.draft_pool = next_pool
	return true


static func pool(seed_value: int, owned: Array) -> Array[String]:
	return ClubPlayerCatalog.owned_draft_pool(seed_value, owned, PitchBatLab.DEBUG_PLAYER_ID)


static func opponents(season: SeasonState) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = season.season_seed
	var original: Array[String] = ClubPlayerCatalog.draft_pool(rng, PitchBatLab.DEBUG_PLAYER_ID)
	return original.filter(func(id: String) -> bool: return not season.picks.has(id))


static func matches(season: SeasonState) -> bool:
	if season.player_access.is_empty():
		return true
	if not frozen_matches(season):
		return false
	if season.career == null:
		return not season._closed_access.is_empty() and not LeagueRules.dynasty(season.league_rules)
	var owned: Array[String] = ClubPlayers.owned(season.career)
	return season.player_access.all(func(id: String) -> bool: return owned.has(id))


static func frozen_matches(season: SeasonState) -> bool:
	return season != null and ClubPlayerCatalog.valid_ids(season.player_access) \
		and season.draft_pool == pool(season.season_seed, season.player_access)

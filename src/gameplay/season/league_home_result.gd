class_name LeagueHomeResult
extends RefCounted
## Explicit league-home composition. Historical pending/result grammars stay unchanged.
## Shape checks structure only; _record_player_result validates all physical evidence.


static func shape(human: Variant, reports: Variant, doubleheader: bool = false, owned_pool: bool = false, pitch_catalog: String = "") -> bool:
	if not human is Array or not reports is Array:
		return false
	var base_size: int = 14 if doubleheader else 13
	var tail_size: int = 3 if owned_pool else 2
	if human.size() not in [base_size + tail_size, base_size + tail_size + 1]:
		return false
	var stadium: Array = human.slice(0, 13)
	stadium.append_array(human.slice(human.size() - tail_size))
	if not SeasonRoundSettlement._shape({"human": stadium, "reports": reports}, true, true, owned_pool, false, pitch_catalog):
		return false
	var original: Dictionary = {"human": human.slice(0, base_size), "reports": reports}
	if human.size() == base_size + tail_size + 1:
		original.human.append(human[base_size])
		return SeasonRoundSettlement._inventory_shape(original, doubleheader, pitch_catalog)
	return (
		SeasonRoundSettlement._doubleheader_shape(original, pitch_catalog)
		if doubleheader else SeasonRoundSettlement._shape(original, true, false, false, false, pitch_catalog)
	)


static func record(season: SeasonState, human: Array) -> bool:
	if season != null and season._league_home_context.get("format") in [94, 95, 96] \
		and StadiumSurfaceNightSnapshot.expected(season, season.pending_fixture()):
		if not load("res://src/gameplay/season/dynasty_league_home_live.gd").matches(season):
			return false
		var operands: Array = load("res://src/gameplay/season/league_home_night_result.gd").record_operands(season, human)
		return not operands.is_empty() and season.callv("_record_player_result", operands)
	if season == null or season.league_rules.is_empty() or not season.league_live:
		return false
	var doubleheader: bool = LeagueRules.doubleheader(season.league_rules)
	var owned_pool: bool = StadiumPoolOwnedHumanEvidence.expected(season, season.pending_fixture())
	if not shape(human, [], doubleheader, owned_pool, SeasonPhysicalFixtures.catalog_for(season)):
		return false
	var base_size: int = 14 if doubleheader else 13
	var tail_size: int = 3 if owned_pool else 2
	var inventory: Variant = human[base_size] if human.size() == base_size + tail_size + 1 else null
	if inventory != null and season.inventory_rules.is_empty():
		return false
	return season._record_player_result(
		human[0], human[1], human[2], human[3], human[4], human[5], human[6],
		human[7], human[8], human[9], human[10], human[11], human[12],
		[], human[-2] if owned_pool else human[-1], human[-1] if owned_pool else null,
		null, null, human[13] if doubleheader else null, {}, inventory
	)


static func pending_valid(season: SeasonState, human: Array) -> bool:
	# Only the explicit home envelope composes Pool with League inventory/workload.
	# Ordinary Pool saves keep their historical fixed positions and validator.
	if season == null or season._league_home_context.get("format") not in [91, 92, 93, 94, 95, 96] \
		or not load("res://src/gameplay/season/dynasty_league_home_live.gd").matches(season):
		return false
	if season._league_home_context.get("format") in [94, 95, 96] and StadiumSurfaceNightSnapshot.expected(season, season.pending_fixture()):
		return load("res://src/gameplay/season/league_home_night_result.gd").pending_valid(season, human)
	var fixture: Dictionary = season.pending_fixture()
	var owned_pool: bool = StadiumPoolOwnedHumanEvidence.expected(season, fixture)
	if not shape(human, [], LeagueRules.doubleheader(season.league_rules), owned_pool,
		SeasonPhysicalFixtures.catalog_for(season)) \
		or human[0] != fixture.get("id") \
		or human[-2 if owned_pool else -1] != StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture)):
		return false
	return StadiumPoolOwnedHumanEvidence.accepts(season, fixture, human[-1] if owned_pool else null,
		int(human[1]), int(human[2]), human[3], human[12])


static func replay(
	season: SeasonState,
	full: SeasonBuild,
	result: Dictionary,
	performance: Dictionary,
	ai_tactics: Dictionary,
	replayed_tactics: Array
) -> bool:
	if season == null or season.league_rules.is_empty() or not season.league_live \
		or not result.get("property") is String:
		return false
	# These richer stadium contracts must never be silently discarded by this adapter.
	var night: bool = season._league_home_context.get("format") in [94, 95, 96] \
		and StadiumSurfaceNightSnapshot.expected(season, season.pending_fixture())
	if season._league_home_context.get("format") in [94, 95, 96] and not load(
		"res://src/gameplay/season/league_home_night_result.gd").result_keys_valid(
		result, season.pending_fixture(), LeagueRules.doubleheader(season.league_rules),
		not season.inventory_rules.is_empty(), night, SeasonPhysicalFixtures.catalog_for(season)):
		return false
	if result.has("yard_evidence") or result.has("night_evidence") != night \
		or (night and not StadiumSurfaceNightHumanEvidence.valid(result.night_evidence)):
		return false
	var owned_pool: bool = StadiumPoolOwnedHumanEvidence.expected(season, season.pending_fixture())
	if result.has("pool_evidence") != owned_pool \
		or (owned_pool and not StadiumPoolOwnedHumanEvidence.valid(result.pool_evidence,
			SeasonPhysicalFixtures.catalog_for(season))):
		return false
	for field: String in ["id", "away_runs", "home_runs"]:
		if not SeasonOwnership._whole(result.get(field), 0, 9999):
			return false
	var doubleheader: bool = LeagueRules.doubleheader(season.league_rules)
	if doubleheader:
		if not result.get("doubleheader_evidence") is Array \
			or result.doubleheader_evidence.size() != 2 \
			or full == null or season._doubleheader_replay_build != full:
			return false
	elif result.has("doubleheader_evidence"):
		return false
	var inventory: Variant = result.get("inventory_final")
	if result.has("inventory_final") and (
		season.inventory_rules.is_empty() or not inventory is Dictionary or inventory.is_empty()
	):
		return false
	var reward: Dictionary = {}
	if inventory != null or doubleheader:
		if full == null:
			return false
		for event: Dictionary in full._events:
			if event.get("op") == "reward" and event.get("game") == result.id:
				reward = event
				break
		if reward.is_empty():
			return false
	if inventory != null:
		if not ClubCareer.same(reward.get("inventory_final"), inventory):
			return false
		var prefix: SeasonBuild = SeasonBuildRestore.restore(
			full.to_data(), full._seed, full._initial_roster, full._pool, full._blocked, int(result.id)
		)
		if prefix == null:
			return false
		season.build = prefix
	return season._record_player_result(
		int(result.id), int(result.away_runs), int(result.home_runs), performance,
		reward.get("used_gear", []), reward.get("tactics", []), reward.get("batting", {}),
		reward.get("stances", []), reward.get("fielding", []), reward.get("pitching", {}),
		reward.get("field_supply", {}), reward.get("frozen", []), ai_tactics, replayed_tactics,
		result.property, result.get("pool_evidence"), null, result.get("night_evidence"), result.get("doubleheader_evidence"), {}, inventory,
		doubleheader and inventory == null
	)

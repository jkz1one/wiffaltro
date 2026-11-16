extends RefCounted
## Explicit94 Night tail composition. No independent route/save/runtime admission.
## Historical LeagueHomeResult and ordinary Night18 grammars stay unchanged.
const TAIL_SIZE: int = 5  # reserved [], property, null Pool, null Yard, exact Night


static func shape(human: Variant, reports: Variant, doubleheader: bool = false, pitch_catalog: String = "") -> bool:
	if not human is Array or not reports is Array:
		return false
	var base_size: int = 14 if doubleheader else 13
	if human.size() not in [base_size + TAIL_SIZE, base_size + TAIL_SIZE + 1]:
		return false
	var night: Array = human.slice(0, 13)
	night.append_array(human.slice(-TAIL_SIZE))
	if not SeasonRoundSettlement._night_shape({"human": night, "reports": reports}, pitch_catalog):
		return false
	var original: Dictionary = {"human": human.slice(0, base_size), "reports": reports}
	if human.size() == base_size + TAIL_SIZE + 1:
		original.human.append(human[base_size])
		return SeasonRoundSettlement._inventory_shape(original, doubleheader, pitch_catalog)
	return SeasonRoundSettlement._doubleheader_shape(original, pitch_catalog) if doubleheader \
		else SeasonRoundSettlement._shape(original, true, false, false, false, pitch_catalog)


static func pending_valid(season: SeasonState, human: Array) -> bool:
	# This proves evidence, not admission. The versioned route must first
	# validate its own complete Career27/session/lineage/policy context.
	if season == null or not StadiumSurfaceNightHumanEvidence.expected(season, season.pending_fixture()) \
		or not shape(human, [], LeagueRules.doubleheader(season.league_rules),
			SeasonPhysicalFixtures.catalog_for(season)):
		return false
	var fixture: Dictionary = season.pending_fixture()
	return human[0] == fixture.get("id") \
		and human[-4] == StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture)) \
		and StadiumSurfaceNightHumanEvidence.accepts(season, fixture, human[-1],
			int(human[1]), int(human[2]), human[3], human[12])


static func record_operands(season: SeasonState, human: Array) -> Array:
	# Return the exact existing full validator operands. Caller still needs route
	# admission and projecting=true. This helper never mutates or records a game.
	if season == null or season.league_rules.is_empty() or not season.league_live \
		or not pending_valid(season, human):
		return []
	var doubleheader: bool = LeagueRules.doubleheader(season.league_rules)
	var base_size: int = 14 if doubleheader else 13
	var inventory: Variant = human[base_size] if human.size() == base_size + TAIL_SIZE + 1 else null
	if inventory != null and season.inventory_rules.is_empty():
		return []
	var operands: Array = human.slice(0, 13)
	operands.append_array([[], human[-4], null, null, human[-1],
		human[13] if doubleheader else null, {}, inventory])
	return operands


static func result_keys_valid(result: Dictionary, fixture: Dictionary,
	doubleheader: bool, inventory: bool, night: bool, pitch_catalog: String = "") -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	# Only94 calls this during replay. Preserve original Night's strict fields,
	# adding workload/inventory solely when this exact League context enables them.
	var allowed: Array = fixture.keys() + ["away_runs", "home_runs", "property",
		"performance", "club_roster", "used_gear", "tactics", "batting", "stances",
		"fielding", "pitching", "field_supply", "frozen", "ai_tactics"]
	if not pitch_catalog.is_empty(): allowed.append("pitching_current")
	if night: allowed.append("night_evidence")
	if doubleheader: allowed.append("doubleheader_evidence")
	if inventory: allowed.append("inventory_final")
	for field: Variant in result:
		if not field is String or not allowed.has(field): return false
	return true


static func human_matches(human: Array, result: Dictionary) -> bool:
	var doubleheader: bool = result.has("doubleheader_evidence")
	if not shape(human, [], doubleheader) or result.get("id") != human[0] \
		or result.get("property") != human[-4] or not result.has("night_evidence") \
		or not ClubCareer.same(result.night_evidence, human[-1]) \
		or result.has("pool_evidence") or result.has("yard_evidence"):
		return false
	var base_size: int = 14 if doubleheader else 13
	if result.has("inventory_final") != (human.size() == base_size + TAIL_SIZE + 1):
		return false
	# Existing comparison retains score/performance/tactics, workload and inventory.
	return load("res://src/gameplay/season/dynasty_owner.gd")._human_matches(
		human.slice(0, human.size() - TAIL_SIZE), result)

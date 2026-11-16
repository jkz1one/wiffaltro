class_name ClubPlayerCatalog
extends RefCounted
## Authored Working unlock routes. User-approved structure, provisional prices/thresholds.

const ValueContract = preload("res://src/gameplay/season/club_value_contract.gd")

const VERSION: int = 1
const PRICE_VERSION: int = 1
const PRICES: Dictionary = {1: 80}
const STARTERS: Array[String] = [
	"player.ash_cole", "player.cal_mercer", "player.casey_rivers", "player.dakota_wells",
	"player.emery_lane", "player.finley_brooks", "player.frankie_bell", "player.indy_shaw",
	"player.jo_lane", "player.jules_moss", "player.mika_reed", "player.val_morgan"
]
const PACK_POOL: Array[String] = [
	"player.ari_banks", "player.dev_lin", "player.drew_sato", "player.eli_frost",
	"player.hayden_cole", "player.jamie_nash", "player.kai_soto", "player.kendall_reed",
	"player.lee_stone", "player.logan_ames", "player.marley_quinn", "player.noel_hart",
	"player.oakley_james", "player.parker_hayes", "player.reese_hart", "player.ren_ellis",
	"player.robin_sage", "player.taylor_wren"
]
# Stable metric keys are derived from validated human-club play/build history, never AI rewards.
const EARNED: Dictionary = {
	"player.alex_finch": ["mastery_max", 5, "Pitch development", "Develop any pitch to mastery 5."],
	"player.bailey_quinn": ["repertoire_max", 5, "Pitch development",
		"Have a pitcher know 5 pitches."],
	"player.gray_west": ["clean_total", 15, "Fielding", "Career: record 15 clean fielded outs."],
	"player.harper_fox": ["season_hit_types", 4, "Hitting", "Hit every hit type in one season."],
	"player.jordan_lake": ["game_homers", 3, "Hitting", "Hit 3 home runs in one game."],
	"player.kit_rowan": ["no_bat_season", 1, "Build challenge",
		"Finish a season without acquiring Bat Gear."],
	"player.morgan_pike": ["strikeouts_total", 25, "Pitching",
		"Career: record 25 pitching strikeouts."],
	"player.nico_vega": ["walkoff", 1, "Game moment", "Win with a walk-off."],
	"player.quinn_riley": ["completed_seasons", 1, "Season", "Complete your first season."],
	"player.remy_cruz": ["comeback_deficit", 3, "Game moment", "Win after trailing by 3 runs."],
	"player.riley_grant": ["season_lessons", 3, "Pitch development",
		"Learn 3 distinct new recipes in one season."],
	"player.river_blake": ["winning_hitters", 4, "Hitting", "Win with a hit from all 4 batters."],
	"player.rowan_chase": ["championships", 1, "Season", "Win a championship."],
	"player.sage_avery": ["game_sponsors", 3, "Build challenge", "Finish a game owning 3 sponsors."],
	"player.sam_park": ["shutout", 1, "Pitching", "Win without allowing a run."],
	"player.shiloh_dean": ["three_k_pitchers", 2, "Pitching", "Get 3 strikeouts with each of 2 arms."],
	"player.skyler_woods": ["season_win_streak", 5, "Season", "Win 5 games in a row in one season."],
	"player.tess_vale": ["contact_runs", 3, "Hitting", "Score 3 runs in a game without a home run."]
}


static func valid_ids(value: Variant, require_starters: bool = true) -> bool:
	if not value is Array or value.size() > SeasonPlayerCatalog.ROWS.size():
		return false
	var previous: String = ""
	for id: Variant in value:
		if not id is String or not SeasonPlayerCatalog.ROWS.has(id) or id <= previous:
			return false
		previous = id
	if require_starters:
		for id: String in STARTERS:
			if not value.has(id):
				return false
	return true


static func initial_owned() -> Array[String]:
	return STARTERS.duplicate()


static func pack_candidates(owned: Array) -> Array[String]:
	var result: Array[String] = []
	if not valid_ids(owned):
		return result
	for id: String in PACK_POOL:
		if not owned.has(id):
			result.append(id)
	return result


static func offers(owned: Array, seed_value: int, sequence: int) -> Array[String]:
	var pool: Array[String] = pack_candidates(owned)
	if seed_value < 0 or seed_value > 2147483647 or sequence < 0 or sequence > 10000:
		return []
	var keys: Dictionary = {}
	for id: String in pool:
		keys[id] = ("player-pack-v1:%d:%d:%s" % [seed_value, sequence, id]).sha256_text()
	pool.sort_custom(func(a: String, b: String) -> bool:
		return keys[a] < keys[b] if keys[a] != keys[b] else a < b)
	return pool.slice(0, mini(3, pool.size()))


static func price(version: int = PRICE_VERSION) -> int:
	return int(PRICES.get(version, -1))


static func signature() -> String:
	var rules: Dictionary = {}
	for id: String in EARNED:
		rules[id] = [EARNED[id][0], EARNED[id][1]]
	return JSON.stringify({"version": VERSION, "starters": STARTERS, "pack": PACK_POOL,
		"earned": rules}, "", true, true).sha256_text()



static func earned(metrics: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id: String in EARNED:
		var rule: Array = EARNED[id]
		if _metric(metrics, rule[0]) >= int(rule[1]):
			result.append(id)
	result.sort()
	return result


static func progress(player_id: String, metrics: Dictionary) -> Dictionary:
	if not EARNED.has(player_id):
		return {}
	var rule: Array = EARNED[player_id]
	return {"current": clampi(_metric(metrics, rule[0]), 0, int(rule[1])),
		"goal": rule[1], "family": rule[2], "requirement": rule[3]}


static func _metric(metrics: Dictionary, key: String) -> int:
	var value: Variant = metrics.get(key, 0)
	return int(value) if ValueContract.whole(value, 0, 1000000000) else 0


static func draft_pool(rng: RandomNumberGenerator, excluded: StringName,
	legacy: bool = false, legacy_ids: Array = []) -> Array[String]:
	var result: Array[String] = []
	for id: StringName in ContentDB.player_by_id:
		if id != excluded and (not legacy or String(id) in legacy_ids):
			result.append(String(id))
	result.sort()
	for index in range(result.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: String = result[index]
		result[index] = result[other]
		result[other] = held
	if not legacy:
		limit_draft_specialists(result)
	return result


static func limit_draft_specialists(pool: Array[String]) -> void:
	var special_seen: bool = false
	for index in range(12):
		if ContentDB.get_player(StringName(pool[index])).starting_pitches.size() < 4:
			continue
		if not special_seen:
			special_seen = true
			continue
		for other in range(12, pool.size()):
			if ContentDB.get_player(StringName(pool[other])).starting_pitches.size() < 4:
				var held: String = pool[index]
				pool[index] = pool[other]
				pool[other] = held
				break


static func owned_draft_pool(seed_value: int, owned: Array, excluded: StringName) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[String] = draft_pool(rng, excluded)
	result = result.filter(func(id: String) -> bool: return owned.has(id))
	if result.size() < 12:
		return []
	limit_draft_specialists(result)
	return result

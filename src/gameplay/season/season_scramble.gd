class_name SeasonScramble
extends RefCounted
## Pure, season-local permutation of the four authored player stats.
## Never applies training, changes the global catalog, or consumes global RNG.

const ValueContract = preload("res://src/gameplay/season/club_value_contract.gd")
const DOMAIN: String = "league-scramble-stat-permutation-v1"
const WORD_RANGE: int = 4294967296


static func profile(player_id: String, rules: Variant) -> Dictionary:
	return transform(SeasonPlayerCatalog.profile(player_id), rules)


static func fresh(player_id: String, stage: String, rules: Variant) -> Dictionary:
	if not SeasonPlayerCatalog.ROWS.has(player_id):
		return {}
	# Recruit additions belong to the authored vector before permutation. Base is
	# transformed separately by the same mapping; catchup remains distinct data.
	return transform(RecruitCatalog.fresh(player_id, stage), rules)


static func mapping(player_id: String, value: Variant) -> Dictionary:
	var rules: Dictionary = LeagueRules.normalized(value)
	if not LeagueRules.scramble(rules) or not SeasonPlayerCatalog.ROWS.has(player_id):
		return {}
	# Frozen algorithm, profile v1: start with source names in STATS order. For
	# i = 3, 2, 1, hash UTF-8 DOMAIN + LF + decimal root season_seed + LF + exact
	# canonical player ID + LF + decimal i + LF + decimal counter (initially 0).
	# Read the first eight SHA-256 hex digits as an unsigned big-endian 32-bit
	# word. Reject words >= 2^32 - (2^32 mod (i + 1)), incrementing counter and
	# hashing again. Swap positions i and word mod (i + 1). Each destination in
	# STATS order then reads the corresponding shuffled source. No shop seed,
	# player iteration order, language hash, or RNG state participates.
	var sources: Array[String] = SeasonPlayerCatalog.STATS.duplicate()
	var prefix: String = "%s\n%d\n%s" % [DOMAIN, int(rules.season_seed), player_id]
	for index in range(sources.size() - 1, 0, -1):
		var counter: int = 0
		var limit: int = WORD_RANGE - WORD_RANGE % (index + 1)
		var word: int = WORD_RANGE
		while word >= limit:
			word = ("%s\n%d\n%d" % [prefix, index, counter]).sha256_text().substr(0, 8).hex_to_int()
			counter += 1
		var selected: int = word % (index + 1)
		var previous: String = sources[index]
		sources[index] = sources[selected]
		sources[selected] = previous
	var result: Dictionary = {}
	for index in range(SeasonPlayerCatalog.STATS.size()):
		result[SeasonPlayerCatalog.STATS[index]] = sources[index]
	return result


static func transform(authored: Dictionary, rules: Variant) -> Dictionary:
	if not authored.get("id") is String:
		return {}
	var permutation: Dictionary = mapping(authored.id, rules)
	if permutation.is_empty():
		return {}
	for field: String in ["stats", "base"]:
		if not authored.get(field) is Dictionary or authored[field].size() != 4:
			return {}
		for stat: String in SeasonPlayerCatalog.STATS:
			if not ValueContract.whole(authored[field].get(stat), 1, SeasonPlayerCatalog.STAT_CAP):
				return {}
	# Call only on authored catalog/fresh recruit vectors, not a live developed
	# profile. Returning recruits use their existing SeasonDevelopment player.
	var result: Dictionary = authored.duplicate(true)
	for stat: String in SeasonPlayerCatalog.STATS:
		result.stats[stat] = int(authored.stats[permutation[stat]])
		result.base[stat] = int(authored.base[permutation[stat]])
	return result

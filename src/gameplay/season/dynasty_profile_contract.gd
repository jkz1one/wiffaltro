extends RefCounted
## Exact semantic Dynasty checkpoint and decay contracts, shared by the real capture facade.
## No compact record authenticates omitted source history. Access-bearing profiles
## still invoke the fixed real ClosedContentAccess validator, never a substitute.

const VERSION: int = 1
const ACCESS_VERSION: int = 2
const RULE_ID: String = "dynasty-foundation-2-per-grown-stat-1-known-mastery-paid-first-v1"
const MAX_ORDINAL: int = 1000000
const BUILD_MAX_EVENTS: int = 512
const _ACCESS_SCRIPT_PATH: String = "res://src/gameplay/season/closed_content_access.gd"
const ABILITY_COUNT: String = "ability.A05"
const ABILITY_HANDS: String = "ability.A06"
const ABILITY_SKY: String = "ability.C01"
const ABILITY_ITEMS: Dictionary = {
	ABILITY_COUNT:
	{
		"name": "Work the Count",
		"slot": "Hitting",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect": "After two actual called balls in this PA, spatial X/Y radii gain +6%."
	},
	ABILITY_HANDS:
	{
		"name": "Soft Hands",
		"slot": "Fielding",
		"price": 10,
		"rarity": "Common",
		"weight": 2.0,
		"effect":
		(
			"Grounded clean-control margin +0.10 after reach, height and reaction eligibility. "
			+ "Primary Fielder or pitcher."
		)
	},
	ABILITY_SKY:
	{
		"name": "Sky Reader",
		"slot": "Fielding",
		"price": 12,
		"rarity": "Uncommon",
		"weight": 1.0,
		"effect":
		(
			"Primary Fielder initial reaction delay ×0.60 on fair launches at least 25°. "
			+ "No speed or reach bonus."
		)
	}
}


static func rule() -> Dictionary:
	return {
		"id": RULE_ID,
		"stat_loss": 2,
		"stat_scope": "all-above-authored",
		"allocation": "paid-before-catchup-v1",
		"mastery_loss": 1,
		"mastery_scope": "all-known-recipes"
	}


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or not whole(value.get("version"), VERSION, WorkingPitchProgression.ACCESS_PROFILE_VERSION):
		return {}
	var current_pitches: bool = int(value.version) >= WorkingPitchProgression.PROFILE_VERSION
	var fields: Array = [
		"version",
		"lineage_id",
		"owner_id",
		"season_ordinal",
		"seed",
		"rule",
		"source",
		"roster",
		"players"
	]
	if current_pitches:
		fields.append("pitch_catalog")
		if not value.get("pitch_catalog") is String or value.pitch_catalog != WorkingPitchCatalog.signature():
			return {}
	if value.version == ACCESS_VERSION or value.version == WorkingPitchProgression.ACCESS_PROFILE_VERSION:
		fields.append("access")
		var access: Dictionary = _normalize_access(value.get("access"))
		if (
			access.is_empty()
			or access.owner_id != value.get("owner_id")
			or not value.get("source") is Dictionary
			or value.source.get("authority") != "season-replay"
		):
			return {}
	if (
		not keys(value, fields)
		or not token(value.lineage_id)
		or not token(value.owner_id)
		or not whole(value.season_ordinal, 1, MAX_ORDINAL)
		or not whole(value.seed, 0, 2147483647)
		or not same(value.rule, rule())
		or not keys(value.source, ["season_key", "seed", "build_revision", "catalog", "authority"])
		or not token(value.source.season_key)
		or not whole(value.source.seed, 0, 2147483647)
		or not whole(value.source.build_revision, 0, BUILD_MAX_EVENTS)
		or value.source.catalog != SeasonPlayerCatalog.signature()
		or value.source.authority not in ["build-replay", "season-replay"]
		or not value.roster is Array
		or value.roster.size() != 4
		or not value.players is Dictionary
		or value.players.size() != 4
	):
		return {}
	if not _source_valid(value.source.season_key, value.lineage_id, int(value.season_ordinal)):
		return {}
	var seen: Array = []
	var ability_rights: Array = []
	var learning_rights: Array = []
	var overflow: int = 0
	for id: Variant in value.roster:
		if (
			not id is String
			or seen.has(id)
			or not value.players.has(id)
			or not _player_valid(id, value.players[id], current_pitches)
		):
			return {}
		var player: Dictionary = value.players[id]
		for origin: Dictionary in player.known_origin.values():
			if (
				origin.kind != "authored"
				and not _source_valid(
					origin.source_season, value.lineage_id, int(value.season_ordinal)
				)
			):
				return {}
		for acquisition: Dictionary in player.active_learning.values():
			if not _source_valid(
				acquisition.source_season, value.lineage_id, int(value.season_ordinal)
			):
				return {}
			var right: Array = [acquisition.source_season, acquisition.receipt]
			if learning_rights.has(right):
				return {}
			learning_rights.append(right)
		for receipt: Dictionary in player.abilities:
			if not _source_valid(
				receipt.source_season, value.lineage_id, int(value.season_ordinal)
			):
				return {}
			var right: Array = [receipt.source_season, receipt.id]
			if ability_rights.has(right):
				return {}
			ability_rights.append(right)
		seen.append(id)
		overflow += int(value.players[id].temporary_fielding_slots == 2)
	if overflow > 1:
		return {}
	var result: Dictionary = value.duplicate(true)
	# JSON's integral floats have one canonical integer spelling throughout.
	result = _integers(result)
	freeze(result)
	return result


static func _player_valid(id: String, value: Variant, current_pitches: bool = false) -> bool:
	var recipes: Array = (WorkingPitchCatalog.known_ids() if current_pitches
		else SeasonPlayerCatalog.RECIPES.values())
	var authored: Dictionary = SeasonPlayerCatalog.profile(id)
	if (
		authored.is_empty()
		or not keys(
			value,
			[
				"authored",
				"stats",
				"active",
				"mastery",
				"trained",
				"catchup",
				"earned_mastery",
				"known_origin",
				"active_learning",
				"abilities",
				"temporary_fielding_slots",
				"ever_earned"
			]
		)
		or not same(
			value.authored,
			{"stats": authored.stats, "mastery": authored.mastery, "capacity": authored.capacity}
		)
		or not keys(value.stats, SeasonPlayerCatalog.STATS)
		or not keys(value.trained, SeasonPlayerCatalog.STATS)
		or not keys(value.catchup, ["origin", "stats", "mastery"])
		or not keys(value.catchup.stats, SeasonPlayerCatalog.STATS)
		or not value.ever_earned is bool
		or not whole(value.temporary_fielding_slots, 1, 2)
	):
		return false
	if not whole(value.authored.capacity, int(authored.capacity), int(authored.capacity)):
		return false
	for stat: String in SeasonPlayerCatalog.STATS:
		if not whole(
			value.authored.stats[stat], int(authored.stats[stat]), int(authored.stats[stat])
		):
			return false
	for recipe: String in authored.mastery:
		if not whole(
			value.authored.mastery[recipe],
			int(authored.mastery[recipe]),
			int(authored.mastery[recipe])
		):
			return false
	var origin: Variant = value.catchup.origin
	if (
		not origin is Dictionary
		or (
			not origin.is_empty()
			and (
				not keys(origin, ["stage", "price"])
				or origin.stage not in RecruitCatalog.STAGES
				or not whole(origin.price, 0, 1000)
				or RecruitCatalog.fresh(id, origin.stage).catchup.price != origin.price
			)
		)
	):
		return false
	for stat: String in SeasonPlayerCatalog.STATS:
		if (
			not whole(value.stats[stat], authored.stats[stat], 10)
			or not whole(value.trained[stat], 0, 9)
			or not whole(value.catchup.stats[stat], 0, 9)
			or (
				value.stats[stat]
				!= authored.stats[stat] + value.trained[stat] + value.catchup.stats[stat]
			)
			or (origin.is_empty() and value.catchup.stats[stat] != 0)
		):
			return false
		if (
			not origin.is_empty()
			and (
				value.catchup.stats[stat]
				> RecruitCatalog.fresh(id, origin.stage).stats[stat] - authored.stats[stat]
			)
		):
			return false
		if value.trained[stat] > 0 and not value.ever_earned:
			return false
	if (
		not value.mastery is Dictionary
		or value.mastery.is_empty()
		or value.mastery.size() > recipes.size()
		or not keys(value.earned_mastery, value.mastery.keys())
		or not keys(value.catchup.mastery, value.mastery.keys())
		or not keys(value.known_origin, value.mastery.keys())
		or not value.active is Array
		or value.active.size() < authored.active.size()
		or value.active.size() > authored.capacity
		or not value.active_learning is Dictionary
	):
		return false
	for recipe: String in authored.mastery:
		if not value.mastery.has(recipe):
			return false
	for recipe: Variant in value.mastery:
		if not recipe is String or not recipes.has(recipe):
			return false
		var floor_value: int = int(authored.mastery.get(recipe, 1))
		if (
			not whole(value.mastery[recipe], floor_value, 5)
			or not whole(value.earned_mastery[recipe], 0, 4)
			or not whole(value.catchup.mastery[recipe], 0, 4)
			or (
				value.mastery[recipe]
				!= floor_value + value.earned_mastery[recipe] + value.catchup.mastery[recipe]
			)
			or (origin.is_empty() and value.catchup.mastery[recipe] != 0)
		):
			return false
		if (
			not origin.is_empty()
			and (
				value.catchup.mastery[recipe]
				> RecruitCatalog.fresh(id, origin.stage).mastery.get(recipe, 1) - floor_value
			)
		):
			return false
		if value.earned_mastery[recipe] > 0 and not value.ever_earned:
			return false
		var known: Variant = value.known_origin[recipe]
		if (
			not keys(known, ["source_season", "kind", "receipt"])
			or not token(known.source_season)
			or not token(known.receipt)
			or known.kind not in ["authored", "learn", "exchange"]
			or (authored.mastery.has(recipe) != (known.kind == "authored"))
			or (
				known.kind == "authored"
				and (known.source_season != "authored" or known.receipt != recipe)
			)
		):
			return false
	var seen: Array = []
	for recipe: Variant in value.active:
		if not recipe is String or not value.mastery.has(recipe) or seen.has(recipe):
			return false
		seen.append(recipe)
	for recipe: Variant in value.active_learning:
		var acquisition: Variant = value.active_learning[recipe]
		if (
			not recipe is String
			or not value.active.has(recipe)
			or authored.active.has(recipe)
			or not keys(acquisition, ["source_season", "receipt"])
			or not token(acquisition.source_season)
			or not token(acquisition.receipt)
		):
			return false
	if not value.abilities is Array or value.abilities.size() > 3:
		return false
	var items: Array = []
	var receipts: Array = []
	var fielding: int = 0
	var hitting: int = 0
	for receipt: Variant in value.abilities:
		if not ability_valid(receipt) or items.has(receipt.item) or receipts.has(receipt.id):
			return false
		items.append(receipt.item)
		receipts.append(receipt.id)
		fielding += int(receipt.slot == "Fielding")
		hitting += int(receipt.slot == "Hitting")
	return hitting <= 1 and fielding <= value.temporary_fielding_slots


static func ability_valid(value: Variant) -> bool:
	return (
		keys(value, ["source_season", "id", "item", "slot", "paid"])
		and token(value.source_season)
		and token(value.id)
		and value.item is String
		and ABILITY_ITEMS.has(value.item)
		and value.slot == ABILITY_ITEMS[value.item].slot
		and whole(
			value.paid,
			int(ABILITY_ITEMS[value.item].price),
			int(ABILITY_ITEMS[value.item].price)
		)
	)


static func decay(value: Variant, choices: Dictionary = {}) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty():
		return {}
	var next: Dictionary = source.duplicate(true)
	var changes: Dictionary = {}
	var used: Array = []
	for id: String in source.roster:
		var before: Dictionary = source.players[id]
		var after: Dictionary = next.players[id]
		var row: Dictionary = {
			"stats": {},
			"mastery": {},
			"forgotten": [],
			"temporary_slots_before": before.temporary_fielding_slots
		}
		for stat: String in SeasonPlayerCatalog.STATS:
			var paid: int = int(before.trained[stat])
			var catchup: int = int(before.catchup.stats[stat])
			var drop: int = mini(2, paid + catchup)
			var paid_loss: int = mini(drop, paid)
			after.trained[stat] = paid - paid_loss
			after.catchup.stats[stat] = catchup - (drop - paid_loss)
			after.stats[stat] -= drop
			row.stats[stat] = _change(paid, catchup, drop, paid_loss)
		for recipe: String in before.mastery:
			var paid: int = int(before.earned_mastery[recipe])
			var catchup: int = int(before.catchup.mastery[recipe])
			var drop: int = mini(1, paid + catchup)
			var paid_loss: int = mini(drop, paid)
			after.earned_mastery[recipe] = paid - paid_loss
			after.catchup.mastery[recipe] = catchup - (drop - paid_loss)
			after.mastery[recipe] -= drop
			row.mastery[recipe] = _change(paid, catchup, drop, paid_loss)
		var fielding: Array = before.abilities.filter(
			func(receipt: Dictionary) -> bool: return receipt.slot == "Fielding"
		)
		if fielding.size() > 1:
			var choice: Variant = choices.get(id)
			# Same explicit no-beneficiary/forget payload used by Double Major removal.
			if (
				not keys(choice, ["player", "forget"])
				or choice.player != ""
				or not choice.forget is String
			):
				return {}
			var exact: Array = fielding.filter(
				func(receipt: Dictionary) -> bool: return receipt.id == choice.forget
			)
			if exact.size() != 1:
				return {}
			after.abilities.erase(exact[0])
			row.forgotten.append(
				{"index": before.abilities.find(exact[0]), "receipt": exact[0].duplicate(true)}
			)
			used.append(id)
		elif choices.has(id):
			return {}
		after.temporary_fielding_slots = 1
		changes[id] = row
	if used.size() != choices.size():
		return {}
	var normalized: Dictionary = normalize(next)
	return {} if normalized.is_empty() else {"profile": normalized, "changes": changes}


static func _change(paid: int, catchup: int, drop: int, paid_loss: int) -> Dictionary:
	return {
		"before": {"paid": paid, "catchup": catchup},
		"after": {"paid": paid - paid_loss, "catchup": catchup - drop + paid_loss},
		"removed": {"total": drop, "paid": paid_loss, "catchup": drop - paid_loss}
	}


static func keys(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field: Variant in fields:
		if not value.has(field):
			return false
	return true


static func whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and float(value) == floor(float(value))
		and value >= minimum
		and value <= maximum
	)


static func token(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 160


static func _source_valid(value: String, lineage: String, ordinal: int) -> bool:
	var prefix: String = lineage + ":"
	var number: String = value.trim_prefix(prefix)
	return (
		value.begins_with(prefix)
		and number.is_valid_int()
		and number == str(number.to_int())
		and number.to_int() >= 1
		and number.to_int() <= ordinal
	)


static func same(first: Variant, second: Variant) -> bool:
	return (
		JSON.stringify(first, "", true, true) == JSON.stringify(second, "", true, true)
		or (
			JSON.parse_string(JSON.stringify(first, "", true, true))
			== JSON.parse_string(JSON.stringify(second, "", true, true))
		)
	)


static func _integers(value: Variant) -> Variant:
	if value is Dictionary:
		for key: Variant in value:
			value[key] = _integers(value[key])
	elif value is Array:
		for index in range(value.size()):
			value[index] = _integers(value[index])
	elif value is float:
		return int(value)
	return value


static func freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values():
			freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value:
			freeze(child)
		value.make_read_only()


static func _normalize_access(value: Variant) -> Dictionary:
	var access_script: GDScript = load(_ACCESS_SCRIPT_PATH)
	return {} if access_script == null else access_script.normalize(value)


static func access_same_origin(first: Dictionary, second: Dictionary) -> bool:
	var access_script: GDScript = load(_ACCESS_SCRIPT_PATH)
	return access_script != null and access_script.same_origin(first, second)

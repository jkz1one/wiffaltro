class_name StadiumStock
extends RefCounted
## Pure construction-ownership proposal. No wallet, layout activation or production save adapter.
## Quotes must later commit through the shared Club Bucks journal, never a second balance.
# gdlint: disable=max-returns

const VERSION: int = 1
const REWARD_VERSION: int = 2
const SALVAGE_VERSION: int = 3
const MASTERY_VERSION: int = 4
const PLAQUE_VERSION: int = 5
const EXTENSION_VERSION: int = 6
const SALVAGE_SOURCE: String = "starter-salvage-v1"
const SALVAGE_COPY: String = "starter-salvage-v1:ST-005"
const MAX_COPIES: int = 4096
var starter: String = "unresolved"
var blueprints: Array[String] = []
var styles: Array[String] = []
var copies: Dictionary = {}


static func grant_signature() -> String:
	return ("starter-grant-v1:" + ",".join(StadiumCatalog.STARTERS)).sha256_text()


static func new_club() -> StadiumStock:
	var result: StadiumStock = StadiumStock.new()
	result.starter = "granted"
	result.blueprints.assign(StadiumCatalog.STARTERS)
	for id: String in StadiumCatalog.STARTERS:
		result.copies["starter-v1:" + id] = {"item": id, "paid": 0, "source": "starter-v1"}
	return result


func to_data() -> Dictionary:
	var result: Dictionary = {
		"version":
		(
			PLAQUE_VERSION
			if plaque_count() > 0
			else (
				MASTERY_VERSION
				if copies.has(StadiumPennantRewards.mastery_key())
				else (
					SALVAGE_VERSION
					if copies.has(SALVAGE_COPY)
					else REWARD_VERSION if earned_count() > 0 else VERSION
				)
			)
		),
		"catalog": StadiumCatalog.signature(),
		"starter": starter,
		"blueprints": blueprints.duplicate(),
		"styles": styles.duplicate(),
		"copies": copies.duplicate(true)
	}
	var seals: Dictionary = StadiumCatalog.extension_seals(blueprints)
	if not seals.is_empty():
		result.version = EXTENSION_VERSION
		result["extension_catalog"] = seals
	return result


static func from_data(value: Variant) -> StadiumStock:
	if (
		not value is Dictionary
		or not SeasonOwnership._whole(value.get("version"), VERSION, EXTENSION_VERSION)
	):
		return null
	if not SeasonOwnership._keys(
		value,
		(
			["version", "catalog", "starter", "blueprints", "styles", "copies"]
			+ (["extension_catalog"] if value.get("version") == EXTENSION_VERSION else [])
		)
	):
		return null
	if (
		not value.catalog is String
		or value.catalog != StadiumCatalog.signature()
		or not value.starter is String
		or value.starter not in ["unresolved", "granted"]
		or not _ids(value.blueprints, "copy", 103 if value.version == EXTENSION_VERSION else 101)
		or not _ids(value.styles, "style")
		or not value.copies is Dictionary
		or (
			value.copies.size()
			> MAX_COPIES + ClubCareer.MAX_RUNS + 1 + StadiumPlaqueRewards.MAX_AWARDS
		)
	):
		return null
	var seals: Dictionary = StadiumCatalog.extension_seals(value.blueprints)
	if value.version == EXTENSION_VERSION:
		if (
			seals.is_empty()
			or not value.extension_catalog is Dictionary
			or not ClubCareer.same(value.extension_catalog, seals)
		):
			return null
	elif not seals.is_empty():
		return null
	var result: StadiumStock = StadiumStock.new()
	result.starter = value.starter
	result.blueprints.assign(value.blueprints)
	result.styles.assign(value.styles)
	for key: Variant in value.copies:
		var copy: Variant = value.copies[key]
		if (
			not key is String
			or key.is_empty()
			or key.length() > 160
			or not copy is Dictionary
			or not SeasonOwnership._keys(
				copy,
				(
					["item", "paid", "source"]
					+ (
						["earned"]
						if (
							copy.get("source")
							in [
								StadiumPennantRewards.SOURCE,
								StadiumPennantRewards.MASTERY_SOURCE,
								StadiumPlaqueRewards.SOURCE
							]
						)
						else []
					)
				)
			)
		):
			return null
		if (
			not copy.item is String
			or not copy.source is String
			or (
				(
					copy.source
					not in [
						StadiumPennantRewards.SOURCE,
						StadiumPennantRewards.MASTERY_SOURCE,
						StadiumPlaqueRewards.SOURCE,
						SALVAGE_SOURCE
					]
				)
				and not result.blueprints.has(copy.item)
			)
		):
			return null
		var item: Dictionary = StadiumCatalog.item(copy.item)
		if copy.source == StadiumPennantRewards.SOURCE:
			if (
				value.version < REWARD_VERSION
				or copy.item != "ST-044"
				or not SeasonOwnership._whole(copy.paid, 0, 0)
				or not StadiumPennantRewards.valid_record(copy.earned)
				or key != StadiumPennantRewards.key(int(copy.earned.season_id))
			):
				return null
		elif copy.source == StadiumPennantRewards.MASTERY_SOURCE:
			if (
				value.version < MASTERY_VERSION
				or copy.item != "ST-067"
				or not SeasonOwnership._whole(copy.paid, 0, 0)
				or not StadiumPennantRewards.valid_mastery_record(copy.earned)
				or key != StadiumPennantRewards.mastery_key()
			):
				return null
		elif copy.source == StadiumPlaqueRewards.SOURCE:
			if (
				value.version < PLAQUE_VERSION
				or copy.item != "ST-066"
				or not SeasonOwnership._whole(copy.paid, 0, 0)
				or not StadiumPlaqueRewards.valid_record(copy.earned)
				or key != StadiumPlaqueRewards.key(copy.earned.player_id)
			):
				return null
		elif copy.source == SALVAGE_SOURCE:
			if (
				value.version < SALVAGE_VERSION
				or key != SALVAGE_COPY
				or copy.item != "ST-005"
				or result.starter != "granted"
				or not SeasonOwnership._whole(copy.paid, 0, 0)
			):
				return null
		elif copy.source == "starter-v1":
			if (
				result.starter != "granted"
				or not StadiumCatalog.STARTERS.has(copy.item)
				or key != "starter-v1:" + copy.item
				or not SeasonOwnership._whole(copy.paid, 0, 0)
			):
				return null
		elif copy.source == "purchase-v1":
			if (
				not key.begins_with("purchase:")
				or not SeasonOwnership._whole(copy.paid, int(item.copy_price), int(item.copy_price))
			):
				return null
		else:
			return null
		result.copies[key] = copy.duplicate(true)
		if value.version >= MASTERY_VERSION and result.copies[key].has("earned"):
			# Stock4+ has canonical earned identity on warm and JSON-cold paths.
			# Stock1-3 remain byte-contract compatible with their historical readers.
			if copy.source == StadiumPlaqueRewards.SOURCE:
				result.copies[key].earned = StadiumPlaqueRewards.canonical(copy.earned)
			else:
				for field: String in ["version", "season_id", "season_number"]:
					result.copies[key].earned[field] = int(result.copies[key].earned[field])
				result.copies[key].earned.era.version = int(result.copies[key].earned.era.version)
		if value.version >= PLAQUE_VERSION:
			result.copies[key].paid = int(result.copies[key].paid)
	if (
		result.pennant_count() > ClubCareer.MAX_RUNS
		or result.plaque_count() > StadiumPlaqueRewards.MAX_AWARDS
		or result.paid_count() > MAX_COPIES
		or (
			value.version < EXTENSION_VERSION
			and (value.version == PLAQUE_VERSION) != (result.plaque_count() > 0)
		)
		or (
			value.version < PLAQUE_VERSION
			and (
				(value.version == MASTERY_VERSION)
				!= result.copies.has(StadiumPennantRewards.mastery_key())
			)
		)
		or (
			value.version < MASTERY_VERSION
			and (value.version == SALVAGE_VERSION) != result.copies.has(SALVAGE_COPY)
		)
		or (
			value.version < SALVAGE_VERSION
			and (value.version == REWARD_VERSION) != (result.earned_count() > 0)
		)
	):
		return null
	if result.starter == "granted":
		for id: String in StadiumCatalog.STARTERS:
			if not result.blueprints.has(id) or not result.copies.has("starter-v1:" + id):
				return null
	return result


func starter_quote() -> Dictionary:
	var candidate: StadiumStock = from_data(to_data())
	if candidate == null:
		return _error("Existing construction ownership could not be read; preserve the original.")
	if candidate.starter == "granted":
		return {"ok": true, "cost": 0, "replayed": true, "state": candidate.to_data(), "error": ""}
	if candidate.paid_count() + StadiumCatalog.STARTERS.size() > MAX_COPIES:
		return _error("Starter grant needs save capacity; existing ownership is preserved.")
	# Owner approved missing-record legacy grants on October 5. Inventory count is not evidence.
	candidate.starter = "granted"
	for id: String in StadiumCatalog.STARTERS:
		if not candidate.blueprints.has(id):
			candidate.blueprints.append(id)
		candidate.copies["starter-v1:" + id] = {"item": id, "paid": 0, "source": "starter-v1"}
	candidate.blueprints.sort()
	return {"ok": true, "cost": 0, "replayed": false, "state": candidate.to_data(), "error": ""}


static func _ids(value: Variant, kind: String, capacity: int = 101) -> bool:
	if not value is Array or value.size() > capacity:
		return false
	var previous: String = ""
	for id: Variant in value:
		if not id is String or id <= previous or StadiumCatalog.item(id).get("kind") != kind:
			return false
		previous = id
	return true


func quote(id: String, quantity: int, progress: Dictionary, request: String) -> Dictionary:
	var candidate: StadiumStock = from_data(to_data())
	if candidate == null:
		return _error(
			"Existing construction ownership could not be validated; preserve the original."
		)
	if request.is_empty() or request.length() > 120 or quantity < 1 or quantity > MAX_COPIES:
		return _error("Invalid construction purchase request.")
	var item: Dictionary = StadiumCatalog.item(id)
	if item.is_empty() or item.kind == "reward":
		return _error("This item is earned through club history and is not a shop purchase.")
	if item.starter and starter != "granted":
		return _error(
			"This older club's starter entitlement needs reconciliation before this purchase."
		)
	if not StadiumCatalog.eligible(id, progress):
		return _error("The exact item requirement has not been met.")
	if item.kind == "style":
		if quantity != 1 or styles.has(id):
			return _error("A field style is one entitlement, not repeat physical copies.")
		candidate.styles.append(id)
		candidate.styles.sort()
		return {
			"ok": true,
			"cost": int(item.blueprint_price),
			"blueprint_cost": 0,
			"copy_cost": 0,
			"style_cost": int(item.blueprint_price),
			"state": candidate.to_data(),
			"placement_verified": false,
			"error": ""
		}
	if paid_count() + quantity > MAX_COPIES:
		return _error("Construction save capacity reached; existing copies are preserved.")
	var blueprint_cost: int = 0 if blueprints.has(id) else int(item.blueprint_price)
	if not candidate.blueprints.has(id):
		candidate.blueprints.append(id)
		candidate.blueprints.sort()
	for index in range(quantity):
		var instance: String = "purchase:%s:%d" % [request, index]
		if candidate.copies.has(instance):
			return _error("This copy receipt already exists; replay the original transaction.")
		candidate.copies[instance] = {
			"item": id, "paid": int(item.copy_price), "source": "purchase-v1"
		}
	return {
		"ok": true,
		"cost": blueprint_cost + int(item.copy_price) * quantity,
		"blueprint_cost": blueprint_cost,
		"copy_cost": int(item.copy_price) * quantity,
		"style_cost": 0,
		"state": candidate.to_data(),
		"placement_verified": false,
		"error": ""
	}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


func earned_count() -> int:
	var count: int = 0
	for copy: Variant in copies.values():
		if (
			copy is Dictionary
			and (
				copy.get("source")
				in [
					StadiumPennantRewards.SOURCE,
					StadiumPennantRewards.MASTERY_SOURCE,
					StadiumPlaqueRewards.SOURCE
				]
			)
		):
			count += 1
	return count


func _source_count(source: String) -> int:
	var count: int = 0
	for copy: Variant in copies.values():
		if copy is Dictionary and copy.get("source") == source:
			count += 1
	return count


func pennant_count() -> int:
	return _source_count(StadiumPennantRewards.SOURCE)


func plaque_count() -> int:
	return _source_count(StadiumPlaqueRewards.SOURCE)


func capacity_count() -> int:
	# Stock5 reserves bounded plaque history separately; legacy capacity is unchanged.
	return copies.size() - plaque_count()


func paid_count() -> int:
	return copies.size() - earned_count()


func pennant_quote(record: Dictionary) -> Dictionary:
	var candidate: StadiumStock = from_data(to_data())
	if candidate == null or not StadiumPennantRewards.valid_record(record):
		return _error("The championship record or construction ownership is invalid.")
	var id: String = StadiumPennantRewards.key(int(record.season_id))
	if candidate.copies.has(id):
		return (
			{"ok": true, "cost": 0, "replayed": true, "state": candidate.to_data(), "error": ""}
			if (ClubCareer.same(candidate.copies[id].get("earned"), record))
			else _error("This championship pennant already has a different historical identity.")
		)
	if candidate.pennant_count() >= ClubCareer.MAX_RUNS:
		return _error("Championship history is full; existing earned displays are preserved.")
	candidate.copies[id] = {
		"item": "ST-044",
		"paid": 0,
		"source": StadiumPennantRewards.SOURCE,
		"earned": record.duplicate(true)
	}
	return {"ok": true, "cost": 0, "replayed": false, "state": candidate.to_data(), "error": ""}


func mastery_quote(record: Dictionary) -> Dictionary:
	var candidate: StadiumStock = from_data(to_data())
	if candidate == null or not StadiumPennantRewards.valid_mastery_record(record):
		return _error("The mastery record or construction ownership is invalid.")
	var id: String = StadiumPennantRewards.mastery_key()
	if candidate.copies.has(id):
		return (
			{"ok": true, "cost": 0, "replayed": true, "state": candidate.to_data(), "error": ""}
			if ClubCareer.same(candidate.copies[id].get("earned"), record)
			else _error("This league already has a different frozen mastery record.")
		)
	candidate.copies[id] = {
		"item": "ST-067",
		"paid": 0,
		"source": StadiumPennantRewards.MASTERY_SOURCE,
		"earned": record.duplicate(true)
	}
	return {"ok": true, "cost": 0, "replayed": false, "state": candidate.to_data(), "error": ""}


func plaque_quote(record: Dictionary) -> Dictionary:
	var candidate: StadiumStock = from_data(to_data())
	if candidate == null or not StadiumPlaqueRewards.valid_record(record):
		return _error("The player-plaque record or construction ownership is invalid.")
	var id: String = StadiumPlaqueRewards.key(record.player_id)
	if candidate.copies.has(id):
		return (
			{"ok": true, "cost": 0, "replayed": true, "state": candidate.to_data(), "error": ""}
			if (ClubCareer.same(candidate.copies[id].get("earned"), record))
			else _error("This player plaque already has a different frozen historical identity.")
		)
	if candidate.plaque_count() >= StadiumPlaqueRewards.MAX_AWARDS:
		return _error("Player-plaque history is full; existing earned displays are preserved.")
	# A missing stable uniform number stays null. Ownership does not imply placement or art.
	candidate.copies[id] = {
		"item": "ST-066",
		"paid": 0,
		"source": StadiumPlaqueRewards.SOURCE,
		"earned": StadiumPlaqueRewards.canonical(record)
	}
	return {"ok": true, "cost": 0, "replayed": false, "state": candidate.to_data(), "error": ""}

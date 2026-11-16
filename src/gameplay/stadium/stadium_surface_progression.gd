class_name StadiumSurfaceProgression
extends RefCounted
## Approved progression direction; Working prices. Appearance state does not imply terrain physics.

const VERSION: int = 1
const ROUGH_ORIGIN: String = "rough-dirt-v1"
const LEGACY_ORIGIN: String = "legacy-grass-v1"
const PRICES: Dictionary = {"ground_prep": 80, "grass": 120}
const INITIAL_LEGACY: Array[String] = ["grass", "ground_prep"]
const HEIGHTS: Array[String] = ["very_short", "short", "medium", "long"]
const MOWING: Array[String] = ["ST-063a", "ST-063b", "ST-063c", "ST-063d"]


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "prices": PRICES,
		"origins": [ROUGH_ORIGIN, LEGACY_ORIGIN], "legacy": INITIAL_LEGACY,
		"heights": HEIGHTS, "mowing": MOWING, "terrain": "unchanged-flat-v1"},
		"", true, true).sha256_text()


static func initial(origin: String) -> Array[String]:
	var result: Array[String] = []
	if origin == LEGACY_ORIGIN:
		result.assign(INITIAL_LEGACY)
	return result


static func valid_origin(origin: Variant) -> bool:
	return origin is String and origin in [ROUGH_ORIGIN, LEGACY_ORIGIN]


static func valid_owned(owned: Variant) -> bool:
	if not owned is Array or owned.size() > PRICES.size():
		return false
	var previous: String = ""
	for item: Variant in owned:
		if not item is String or not PRICES.has(item) or item <= previous:
			return false
		previous = item
	return true


static func quote(owned: Array[String], item: String, version: int) -> Dictionary:
	if version != VERSION or not valid_owned(owned) or not PRICES.has(item):
		return {"ok": false, "error": "Unknown surface upgrade or price version."}
	if owned.has(item):
		return {"ok": false, "error": "This permanent surface upgrade is already owned."}
	var next: Array[String] = owned.duplicate()
	next.append(item)
	next.sort()
	return {"ok": true, "error": "", "cost": PRICES[item], "owned": next}


static func style_error(owned: Array[String], item: String) -> String:
	if MOWING.has(item) and not owned.has("grass"):
		return "Establish grass before purchasing a mowing pattern."
	if (StadiumGroundModels.IDS.has(item) or StadiumInfieldModels.IDS.has(item)) \
		and (not owned.has("grass") or not owned.has("ground_prep")):
		return "Prepare the ground and establish grass before purchasing a dirt cut."
	return ""


static func selection(owned: Array[String], grass: bool, height: String = "short") -> Dictionary:
	if not valid_owned(owned) or not HEIGHTS.has(height) or (grass and not owned.has("grass")):
		return {}
	return {"foundation": "grass" if grass else "dirt",
		"condition": "prepared" if owned.has("ground_prep") else "rough",
		"height": height if grass else "short"}


static func valid_selection(value: Variant, owned: Array[String]) -> bool:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["foundation", "condition", "height"]) or not value.foundation is String \
		or value.foundation not in ["grass", "dirt"] or not value.height is String \
		or not value.condition is String or value.condition not in ["rough", "prepared"]:
		return false
	return valid_owned(owned) and HEIGHTS.has(value.height) \
		and (value.foundation == "grass" or value.height == "short") \
		and (value.foundation != "grass" or owned.has("grass")) \
		and (value.condition != "prepared" or owned.has("ground_prep"))

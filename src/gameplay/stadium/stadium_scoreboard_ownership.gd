class_name StadiumScoreboardOwnership
extends RefCounted
## Extension holds only electronic copies; original manual/video copies stay in StadiumStock.
## Pure proposals only. A future journal operation must authorize unlocks and payment.

const VERSION: int = 1
var blueprints: Array[String] = []
var copies: Dictionary = {}


func to_data() -> Dictionary:
	return {"version": VERSION, "catalog": StadiumScoreboardCatalog.signature(),
		"blueprints": blueprints.duplicate(), "copies": copies.duplicate(true)}


static func from_data(value: Variant, other_count: int = 0) -> StadiumScoreboardOwnership:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "catalog", "blueprints", "copies"]):
		return null
	if not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or value.catalog != StadiumScoreboardCatalog.signature() \
		or not value.blueprints is Array or not value.copies is Dictionary \
		or other_count < 0 or other_count > StadiumStock.MAX_COPIES \
		or other_count + value.copies.size() > StadiumStock.MAX_COPIES:
		return null
	if value.blueprints != [] and value.blueprints != [StadiumScoreboardCatalog.ELECTRONIC]:
		return null
	var result: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	result.blueprints.assign(value.blueprints)
	for key: Variant in value.copies:
		var copy: Variant = value.copies[key]
		if not key is String or not key.begins_with("scoreboard:") or key.length() > 160 \
			or not copy is Dictionary or not SeasonOwnership._keys(copy, ["item", "paid", "source"]):
			return null
		if copy.item != StadiumScoreboardCatalog.ELECTRONIC \
			or not result.blueprints.has(copy.item) or copy.source != "purchase-scoreboard-v1" \
			or not SeasonOwnership._whole(copy.paid, StadiumScoreboardCatalog.MIDDLE.copy_price,
				StadiumScoreboardCatalog.MIDDLE.copy_price):
			return null
		result.copies[key] = {"item": copy.item, "paid": int(copy.paid), "source": copy.source}
	return result


func quote(quantity: int, request: String, progress: Dictionary,
	other_count: int = 0) -> Dictionary:
	var candidate: StadiumScoreboardOwnership = from_data(to_data(), other_count)
	if candidate == null:
		return _error("Invalid electronic-board ownership; preserve the original.")
	if not StadiumScoreboardCatalog.eligible(StadiumScoreboardCatalog.ELECTRONIC, progress):
		return _error("The electronic-board blueprint is still locked.")
	if request.is_empty() or request.length() > 120 or quantity < 1 \
		or quantity > StadiumStock.MAX_COPIES \
		or other_count + copies.size() + quantity > StadiumStock.MAX_COPIES:
		return _error("Invalid scoreboard request or combined construction capacity.")
	var blueprint: int = 0
	if candidate.blueprints.is_empty():
		blueprint = StadiumScoreboardCatalog.MIDDLE.blueprint_price
		candidate.blueprints.append(StadiumScoreboardCatalog.ELECTRONIC)
	for index in range(quantity):
		var key: String = "scoreboard:%s:%d" % [request, index]
		if candidate.copies.has(key):
			return _error("This copy receipt already exists; replay its journal transaction.")
		candidate.copies[key] = {"item": StadiumScoreboardCatalog.ELECTRONIC,
			"paid": StadiumScoreboardCatalog.MIDDLE.copy_price, "source": "purchase-scoreboard-v1"}
	var copy_cost: int = quantity * int(StadiumScoreboardCatalog.MIDDLE.copy_price)
	return {"ok": true, "error": "", "cost": blueprint + copy_cost,
		"blueprint_cost": blueprint, "copy_cost": copy_cost, "state": candidate.to_data(),
		"placement_verified": false}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

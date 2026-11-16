class_name StadiumWallPieceStock
extends RefCounted
## Isolated exact-copy container. The shared journal must separately authorize unlocks and payment.

const VERSION: int = 1
var copies: Dictionary = {}


func to_data() -> Dictionary:
	return {"version": VERSION, "catalog": StadiumWallPieceCatalog.signature(),
		"copies": copies.duplicate(true)}


static func from_data(value: Variant, standard_count: int = 0) -> StadiumWallPieceStock:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "catalog", "copies"]):
		return null
	if not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or value.catalog != StadiumWallPieceCatalog.signature() or not value.copies is Dictionary \
		or standard_count < 0 or standard_count + value.copies.size() > StadiumStock.MAX_COPIES:
		return null
	var result: StadiumWallPieceStock = StadiumWallPieceStock.new()
	for key: Variant in value.copies:
		var copy: Variant = value.copies[key]
		if not key is String or not key.begins_with("wall-piece:") or key.length() > 160 \
			or not copy is Dictionary or not SeasonOwnership._keys(copy, ["item", "paid", "source"]):
			return null
		if not copy.item is String or copy.source != "purchase-piece-v1":
			return null
		var item: Dictionary = StadiumWallPieceCatalog.item(copy.item)
		if item.is_empty() or not SeasonOwnership._whole(copy.paid, item.copy_price, item.copy_price):
			return null
		result.copies[key] = {"item": copy.item, "paid": int(copy.paid), "source": copy.source}
	return result


func quote(id: String, quantity: int, request: String, unlocked: Array[String],
	standard_count: int = 0) -> Dictionary:
	var candidate: StadiumWallPieceStock = from_data(to_data(), standard_count)
	if candidate == null:
		return _error("Existing wall-piece inventory is invalid; preserve the original.")
	var item: Dictionary = StadiumWallPieceCatalog.item(id)
	if item.is_empty() or not unlocked.has(id):
		return _error("This exact wall-piece type has not been unlocked.")
	if request.is_empty() or request.length() > 120 or quantity < 1 \
		or standard_count + copies.size() + quantity > StadiumStock.MAX_COPIES:
		return _error("Invalid wall-piece request or combined construction capacity.")
	for index in range(quantity):
		var key: String = "wall-piece:%s:%d" % [request, index]
		if candidate.copies.has(key):
			return _error("This wall-piece receipt already exists; replay its journal transaction.")
		candidate.copies[key] = {"item": id, "paid": int(item.copy_price), "source": "purchase-piece-v1"}
	return {"ok": true, "error": "", "cost": int(item.copy_price) * quantity,
		"state": candidate.to_data(), "placement_verified": false}


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

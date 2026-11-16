class_name StadiumWallPieceOwnership
extends RefCounted
## Exact variant blueprints and pieces. Payment authority belongs to ClubAssetLedger.

const VERSION: int = 1
const BLUEPRINT_PRICES: Dictionary = {"ST-024": 360, "ST-065": 520,
	"ST-077": 700, "ST-078": 450}
var blueprints: Array[String] = []
var stock: StadiumWallPieceStock = StadiumWallPieceStock.new()


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "pieces": StadiumWallPieceCatalog.signature(),
		"blueprints": BLUEPRINT_PRICES, "policy": "exact-variant-independent-v1"},
		"", true, true).sha256_text()


func to_data() -> Dictionary:
	if stock == null:
		return {}
	return {"version": VERSION, "catalog": signature(), "blueprints": blueprints.duplicate(),
		"stock": stock.to_data()}


static func from_data(value: Variant, standard_count: int = 0) -> StadiumWallPieceOwnership:
	if not value is Dictionary or not SeasonOwnership._keys(value,
		["version", "catalog", "blueprints", "stock"]):
		return null
	if not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or not value.catalog is String or value.catalog != signature() \
		or not value.blueprints is Array or value.blueprints.size() > 8:
		return null
	var result: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	var previous: String = ""
	for id: Variant in value.blueprints:
		if not id is String or id <= previous or StadiumWallPieceCatalog.item(id).is_empty():
			return null
		result.blueprints.append(id)
		previous = id
	result.stock = StadiumWallPieceStock.from_data(value.stock, standard_count)
	if result.stock == null:
		return null
	for copy: Dictionary in result.stock.copies.values():
		if not result.blueprints.has(copy.item):
			return null
	return result


func quote(id: String, quantity: int, request: String, progress: Dictionary,
	standard_count: int = 0, price_version: int = VERSION) -> Dictionary:
	var candidate: StadiumWallPieceOwnership = from_data(to_data(), standard_count)
	if candidate == null or price_version != VERSION:
		return StadiumWallPieceStock._error("Invalid wall-piece ownership or price version.")
	var item: Dictionary = StadiumWallPieceCatalog.item(id)
	if item.is_empty() or not StadiumCatalog.eligible(item.material, progress):
		return StadiumWallPieceStock._error("This wall-piece blueprint is still locked.")
	var blueprint_cost: int = 0
	if not candidate.blueprints.has(id):
		blueprint_cost = BLUEPRINT_PRICES[item.material]
		candidate.blueprints.append(id)
		candidate.blueprints.sort()
	var result: Dictionary = candidate.stock.quote(
		id, quantity, request, candidate.blueprints, standard_count)
	if not result.ok:
		return result
	candidate.stock = StadiumWallPieceStock.from_data(result.state, standard_count)
	return {"ok": true, "error": "", "cost": blueprint_cost + int(result.cost),
		"blueprint_cost": blueprint_cost, "state": candidate.to_data(), "placement_verified": false}

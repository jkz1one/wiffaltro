class_name StadiumGroundStyles
extends RefCounted
## Separately versioned prices and geometry preserve all earlier appearance receipts.

const PRICE_VERSION: int = 2
const LAYOUT_VERSION: int = 5
const PRICES: Dictionary = {"ST-063e": 160, "ST-063f": 270, "ST-063i": 300}


static func signature() -> String:
	return JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()


static func appearance_signature() -> String:
	var masks: Dictionary = {}
	for id: String in StadiumGroundModels.IDS:
		var rows: Array = []
		for mask: PackedVector2Array in StadiumGroundModels.masks(id):
			var points: Array = []
			for point: Vector2 in mask:
				points.append([point.x, point.y])
			rows.append(points)
		masks[id] = rows
	return JSON.stringify({"models": StadiumGroundModels.VERSION, "masks": masks,
		"height": StadiumGroundModels.HEIGHT}, "", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumClubItems.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 4, 4):
		result.version = LAYOUT_VERSION
		result.family = "reference-ground-v5"
		result["ground"] = ""
	return result


static func valid(id: Variant, stock: StadiumStock) -> bool:
	return stock != null and id is String and (id.is_empty() or (
		StadiumGroundModels.IDS.has(id) and stock.styles.has(id)))


static func quote(stock: StadiumStock, id: String, request: String,
	progress: Dictionary) -> Dictionary:
	if not PRICES.has(id):
		return ClubAssetLedger._error("This ground treatment is not enabled yet.")
	var result: Dictionary = stock.quote(id, 1, progress, request)
	if result.ok and (result.cost != PRICES[id] or result.copy_cost != 0):
		return ClubAssetLedger._error("The ground-treatment price changed; reload before purchasing.")
	return result

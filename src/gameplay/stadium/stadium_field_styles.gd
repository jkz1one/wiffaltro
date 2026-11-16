class_name StadiumFieldStyles
extends RefCounted
## Once-only style entitlements. Prices/access are separate from frozen appearance geometry.

const VERSION: int = 1
const LAYOUT_VERSION: int = 3
const PRICES: Dictionary = {"ST-062a": 115, "ST-062b": 300,
	"ST-063a": 200, "ST-063b": 400, "ST-063c": 550, "ST-063d": 700}


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "prices": PRICES}, "", true, true).sha256_text()


static func appearance_signature() -> String:
	return JSON.stringify({"version": VERSION, "models": StadiumFieldStyleModels.VERSION,
		"channels": StadiumFieldStyleModels.CHANNELS,
		"field_mask": StadiumBoundaryGraph.signature()}, "", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumHomeLayout.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 2, 2):
		result.version = LAYOUT_VERSION
		result.family = "reference-styles-v3"
		result["styles"] = {"line": "", "grass": ""}
	return result


static func valid(selection: Variant, stock: StadiumStock) -> bool:
	return stock != null and StadiumStock.from_data(stock.to_data()) != null \
		and StadiumFieldStylePrototype.validate(selection, stock)


static func quote(stock: StadiumStock, id: String, request: String,
	progress: Dictionary, version: int) -> Dictionary:
	if version == StadiumInfieldStyles.PRICE_VERSION:
		return StadiumInfieldStyles.quote(stock, id, request, progress)
	if version == StadiumGroundStyles.PRICE_VERSION:
		return StadiumGroundStyles.quote(stock, id, request, progress)
	if version != VERSION or not PRICES.has(id):
		return ClubAssetLedger._error("This field appearance has not been enabled yet.")
	var result: Dictionary = stock.quote(id, 1, progress, request)
	if result.ok and (result.cost != PRICES[id] or result.copy_cost != 0):
		return ClubAssetLedger._error("The style price changed; reload before purchasing.")
	return result

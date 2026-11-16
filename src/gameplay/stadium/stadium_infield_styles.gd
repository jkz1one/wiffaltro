class_name StadiumInfieldStyles
extends RefCounted
## Once-only base and footprint unlocks; older prices, masks and layouts stay frozen.

const PRICE_VERSION: int = 3
const LAYOUT_VERSION: int = 10
const PRICES: Dictionary = {"ST-062c": 190, "ST-062d": 360,
	"ST-063g": 340, "ST-063h": 650, "ST-063j": 520}
const NIGHT_VERIFIED: bool = true


static func signature() -> String:
	return JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()


static func appearance_signature() -> String:
	var masks: Dictionary = {}
	for id: String in StadiumInfieldModels.IDS:
		var rows: Array = []
		for mask: PackedVector2Array in StadiumInfieldModels.masks(id):
			var points: Array = []
			for point: Vector2 in mask:
				points.append([point.x, point.y])
			rows.append(points)
		masks[id] = rows
	var bases: Array = []
	for point: Vector2 in StadiumInfieldAnchors.bases():
		bases.append([point.x, point.y])
	return JSON.stringify({"models": StadiumInfieldModels.VERSION,
		"markers": StadiumBaseMarkerModels.VERSION, "anchors": StadiumInfieldAnchors.VERSION,
		"base_visibility": StadiumBaseMarkerVisibility.VERSION,
		"night_surface": StadiumInfieldNightPresentation.VERSION,
		"sand_night_color": StadiumInfieldNightPresentation.SAND_MULTIPLIER.to_html(),
		"bases": bases, "masks": masks, "height": StadiumInfieldModels.HEIGHT,
		"night_verified": NIGHT_VERIFIED}, "", true, true).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = StadiumLightItems.upgrade(layout)
	if SeasonOwnership._whole(result.get("version"), 9, 9):
		result.version = LAYOUT_VERSION
		result.family = "reference-infield-v10"
		result["bases"] = ""
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if not SeasonOwnership._keys(layout, ["version", "family", "receiver", "obstacles",
		"seating", "styles", "displays", "ground", "bleachers", "target", "net", "lights", "bases"]) \
		or not layout.family is String or layout.family != "reference-infield-v10" \
		or not layout.bases is String or not layout.ground is String or stock == null:
		return StadiumStarterLayout._error("Unknown infield layout.")
	if not layout.bases.is_empty() and (not StadiumBaseMarkerModels.IDS.has(layout.bases)
		or not stock.styles.has(layout.bases)):
		return StadiumStarterLayout._error("Select an exact owned base-marker set.")
	var new_ground: bool = StadiumInfieldModels.IDS.has(layout.ground)
	if new_ground and not stock.styles.has(layout.ground):
		return StadiumStarterLayout._error("Select an exact owned dirt footprint.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("bases")
	base.version = 9
	base.family = "reference-yard-lights-v9"
	if new_ground:
		base.ground = ""
	var result: Dictionary = StadiumHomeLayout.validate(base, stock, tier)
	if result.ok and (new_ground or not layout.bases.is_empty()) and not NIGHT_VERIFIED:
		result.night_qualified = false
	return result


static func quote(stock: StadiumStock, id: String, request: String,
	progress: Dictionary) -> Dictionary:
	if not PRICES.has(id):
		return ClubAssetLedger._error("This base or infield style is not enabled yet.")
	var result: Dictionary = stock.quote(id, 1, progress, request)
	if result.ok and (result.cost != PRICES[id] or result.copy_cost != 0):
		return ClubAssetLedger._error("The infield style price changed; reload before purchasing.")
	return result


static func apply(property: StadiumPropertyGeometry, layout: Dictionary,
	stock: StadiumStock) -> bool:
	if not StadiumPropertyGeometry.construction_target_allowed(property):
		return false
	var applied: bool = StadiumInfieldModels.apply(property, layout.ground, layout.styles, stock) \
		if StadiumInfieldModels.IDS.has(layout.ground) else (
			StadiumGroundModels.apply(property, layout.ground, layout.styles, stock))
	return applied and StadiumBaseMarkerModels.apply(property, layout.bases, stock)

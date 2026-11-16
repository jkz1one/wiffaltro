class_name StadiumPurchases
extends RefCounted
## First paid construction slice: extra copies of the three verified starter models.

const VERSION: int = 1
const SEATING_VERSION: int = 2
const DISPLAY_VERSION: int = 3
const BLEACHER_VERSION: int = 4
const POOL_VERSION: int = 9
const POOLS: Dictionary = {"ST-006": [540, 160]}
const LIGHT_VERSION: int = 7
const LIGHTS: Dictionary = {"ST-037": [300, 65]}
const NET_VERSION: int = 6
const NETS: Dictionary = {"ST-025": [300, 90]}
const TARGET_VERSION: int = 5
const TARGETS: Dictionary = {"ST-026": [230, 70]}
const BLEACHERS: Dictionary = {"ST-028": [480, 150], "ST-075": [480, 140]}
const DISPLAYS: Dictionary = {"ST-039": [340, 100], "ST-041": [100, 25]}
const SEATING: Dictionary = {"ST-080": [150, 40], "ST-027": [300, 100]}
const PRICES: Dictionary = {"ST-001": 40, "ST-003": 45, "ST-079": 35}


static func signature(version: int = VERSION) -> String:
	if version == StadiumOutfieldPlazaItems.PRICE_VERSION:
		return StadiumOutfieldPlazaItems.price_signature()
	if version == StadiumLightingKitItems.PRICE_VERSION:
		return StadiumLightingKitItems.price_signature()
	if version == StadiumWaterfallItems.PRICE_VERSION:
		return StadiumWaterfallItems.price_signature()
	if version == StadiumSalvageCarItems.PRICE_VERSION:
		return StadiumSalvageCarItems.price_signature()
	if version == StadiumStringLightItems.PRICE_VERSION:
		return StadiumStringLightItems.price_signature()
	if version == StadiumMountedDisplayItems.PRICE_VERSION:
		return StadiumMountedDisplayItems.price_signature()
	if version == StadiumPlayerTunnelItems.PRICE_VERSION:
		return StadiumPlayerTunnelItems.price_signature()
	if version == StadiumWallTopTerraceItems.PRICE_VERSION:
		return StadiumWallTopTerraceItems.price_signature()
	if version == StadiumRisingAppleItems.PRICE_VERSION:
		return StadiumRisingAppleItems.price_signature()
	if version == StadiumOutfieldBleacherItems.PRICE_VERSION:
		return StadiumOutfieldBleacherItems.price_signature()
	if version == StadiumLandmarkItems.PRICE_VERSION:
		return StadiumLandmarkItems.price_signature()
	if version == StadiumTreehouseItems.PRICE_VERSION:
		return StadiumTreehouseItems.price_signature()
	if version == StadiumPracticeFacilityItems.PRICE_VERSION:
		return StadiumPracticeFacilityItems.price_signature()
	if version == StadiumGroundBoxItems.PRICE_VERSION:
		return StadiumGroundBoxItems.price_signature()
	if version == StadiumMoldedSeatItems.PRICE_VERSION:
		return StadiumMoldedSeatItems.price_signature()
	if version == StadiumLiveFurnishingItems.PRICE_VERSION:
		return StadiumLiveFurnishingItems.price_signature()
	if version == StadiumLandscapeOwnedItems.PRICE_VERSION:
		return StadiumLandscapeOwnedItems.price_signature()
	if version == StadiumFloodlightOwnedItems.PRICE_VERSION:
		return StadiumFloodlightOwnedItems.price_signature()
	if version == StadiumReceiverOwnedItems.PRICE_VERSION:
		return StadiumReceiverOwnedItems.price_signature()
	if version == StadiumBoundaryItems.PRICE_VERSION:
		return StadiumBoundaryItems.price_signature()
	if version == StadiumFacilityItems.PRICE_VERSION:
		return StadiumFacilityItems.price_signature()
	if version == StadiumRoofItems.PRICE_VERSION:
		return StadiumRoofItems.price_signature()
	if version == StadiumStraightItems.PRICE_VERSION:
		return StadiumStraightItems.price_signature()
	if version == StadiumGroundPropsItems.PRICE_VERSION:
		return StadiumGroundPropsItems.price_signature()
	if version == StadiumFlagItems.PRICE_VERSION:
		return StadiumFlagItems.price_signature()
	if version == POOL_VERSION:
		return JSON.stringify({"version": version, "prices": POOLS}, "", true, true).sha256_text()
	if version == StadiumWallItems.PRICE_VERSION:
		return StadiumWallItems.price_signature()
	if version == LIGHT_VERSION:
		return JSON.stringify({"version": version, "prices": LIGHTS}, "", true, true).sha256_text()
	if version == NET_VERSION:
		return JSON.stringify({"version": version, "prices": NETS}, "", true, true).sha256_text()
	if version == TARGET_VERSION:
		return JSON.stringify({"version": version, "prices": TARGETS}, "", true, true).sha256_text()
	if version == BLEACHER_VERSION:
		return JSON.stringify({"version": version, "prices": BLEACHERS}, "", true, true).sha256_text()
	if version == DISPLAY_VERSION:
		return JSON.stringify({"version": version, "prices": DISPLAYS}, "", true, true).sha256_text()
	if version == SEATING_VERSION:
		return JSON.stringify({"version": version, "prices": SEATING}, "", true, true).sha256_text()
	return JSON.stringify({"version": VERSION, "prices": PRICES}, "", true, true).sha256_text()


static func quote(stock: StadiumStock, item: String, quantity: int, request: String,
	price_version: int, progress: Dictionary = {}) -> Dictionary:
	if price_version == StadiumOutfieldPlazaItems.PRICE_VERSION:
		return StadiumOutfieldPlazaItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumLightingKitItems.PRICE_VERSION:
		return StadiumLightingKitItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumWaterfallItems.PRICE_VERSION:
		return StadiumWaterfallItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumSalvageCarItems.PRICE_VERSION:
		return StadiumSalvageCarItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumStringLightItems.PRICE_VERSION:
		return StadiumStringLightItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumMountedDisplayItems.PRICE_VERSION:
		return StadiumMountedDisplayItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumPlayerTunnelItems.PRICE_VERSION:
		return StadiumPlayerTunnelItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumWallTopTerraceItems.PRICE_VERSION:
		return StadiumWallTopTerraceItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumRisingAppleItems.PRICE_VERSION:
		return StadiumRisingAppleItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumOutfieldBleacherItems.PRICE_VERSION:
		return StadiumOutfieldBleacherItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumLandmarkItems.PRICE_VERSION:
		return StadiumLandmarkItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumTreehouseItems.PRICE_VERSION:
		return StadiumTreehouseItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumPracticeFacilityItems.PRICE_VERSION:
		return StadiumPracticeFacilityItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumGroundBoxItems.PRICE_VERSION:
		return StadiumGroundBoxItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumMoldedSeatItems.PRICE_VERSION:
		return StadiumMoldedSeatItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumLiveFurnishingItems.PRICE_VERSION:
		return StadiumLiveFurnishingItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumLandscapeOwnedItems.PRICE_VERSION:
		return StadiumLandscapeOwnedItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumFloodlightOwnedItems.PRICE_VERSION:
		return StadiumFloodlightOwnedItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumReceiverOwnedItems.PRICE_VERSION:
		return StadiumReceiverOwnedItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumBoundaryItems.PRICE_VERSION:
		return StadiumBoundaryItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumFacilityItems.PRICE_VERSION:
		return StadiumFacilityItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumRoofItems.PRICE_VERSION:
		return StadiumRoofItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumStraightItems.PRICE_VERSION:
		return StadiumStraightItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumGroundPropsItems.PRICE_VERSION:
		return StadiumGroundPropsItems.quote(stock, item, quantity, request, progress)
	if price_version == StadiumFlagItems.PRICE_VERSION:
		return StadiumFlagItems.quote(stock, item, quantity, request, progress)
	if price_version == POOL_VERSION:
		return _pools(stock, item, quantity, request, progress)
	if price_version == StadiumWallItems.PRICE_VERSION:
		return StadiumWallItems.quote(stock, item, quantity, request, progress)
	if price_version == LIGHT_VERSION:
		return _lights(stock, item, quantity, request, progress)
	if price_version == NET_VERSION:
		return _nets(stock, item, quantity, request, progress)
	if price_version == TARGET_VERSION:
		return _targets(stock, item, quantity, request, progress)
	if price_version == BLEACHER_VERSION:
		return _bleachers(stock, item, quantity, request, progress)
	if price_version == DISPLAY_VERSION:
		return _displays(stock, item, quantity, request, progress)
	if price_version == SEATING_VERSION:
		return _seating(stock, item, quantity, request, progress)
	if price_version != VERSION or not PRICES.has(item):
		return ClubAssetLedger._error("This construction item or price is not available yet.")
	var result: Dictionary = stock.quote(item, quantity, {}, request)
	if result.ok and (result.blueprint_cost != 0 or result.copy_cost != PRICES[item] * quantity):
		return ClubAssetLedger._error("The construction quote changed; reload before purchasing.")
	return result


static func _seating(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not SEATING.has(item):
		return ClubAssetLedger._error("This item is not in the verified seating catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(SEATING[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(SEATING[item][1]) * quantity):
		return ClubAssetLedger._error("The seating quote changed; reload before purchasing.")
	return result


static func _displays(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not DISPLAYS.has(item):
		return ClubAssetLedger._error("This item is not in the verified club-display catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(DISPLAYS[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(DISPLAYS[item][1]) * quantity):
		return ClubAssetLedger._error("The display quote changed; reload before purchasing.")
	return result


static func _bleachers(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not BLEACHERS.has(item):
		return ClubAssetLedger._error("This item is not in the larger bleacher catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(BLEACHERS[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(BLEACHERS[item][1]) * quantity):
		return ClubAssetLedger._error("The bleacher quote changed; reload before purchasing.")
	return result


static func _targets(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not TARGETS.has(item):
		return ClubAssetLedger._error("This receiver configuration is not enabled yet.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(TARGETS[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(TARGETS[item][1]) * quantity):
		return ClubAssetLedger._error("The target quote changed; reload before purchasing.")
	return result


static func _nets(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not NETS.has(item):
		return ClubAssetLedger._error("This item is not in the verified catching-net catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(NETS[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(NETS[item][1]) * quantity):
		return ClubAssetLedger._error("The catching-net quote changed; reload before purchasing.")
	return result


static func _lights(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not LIGHTS.has(item):
		return ClubAssetLedger._error("This item is not in the verified yard-light catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(LIGHTS[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(LIGHTS[item][1]) * quantity):
		return ClubAssetLedger._error("The yard-light quote changed; reload before purchasing.")
	return result


static func _pools(stock: StadiumStock, item: String, quantity: int, request: String,
	progress: Dictionary) -> Dictionary:
	if not POOLS.has(item):
		return ClubAssetLedger._error("This item is not in the owned Pool catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(POOLS[item][0])
	if result.ok and (result.blueprint_cost != blueprint
		or result.copy_cost != int(POOLS[item][1]) * quantity):
		return ClubAssetLedger._error("The Pool quote changed; reload before purchasing.")
	return result

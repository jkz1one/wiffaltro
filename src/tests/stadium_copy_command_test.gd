extends Node
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var club: ClubCareer = ClubCareer.new()
	var before: Dictionary = club.to_data()
	var cases: Array = [
		[StadiumOutfieldPlazaItems.PRICES, StadiumOutfieldPlazaItems.PRICE_VERSION],
		[StadiumLightingKitItems.PRICES, StadiumLightingKitItems.PRICE_VERSION],
		[StadiumWaterfallItems.PRICES, StadiumWaterfallItems.PRICE_VERSION],
		[StadiumSalvageCarItems.PRICES, StadiumSalvageCarItems.PRICE_VERSION],
		[StadiumStringLightItems.PRICES, StadiumStringLightItems.PRICE_VERSION],
		[StadiumMountedDisplayItems.PRICES, StadiumMountedDisplayItems.PRICE_VERSION],
		[StadiumPlayerTunnelItems.PRICES, StadiumPlayerTunnelItems.PRICE_VERSION],
		[StadiumWallTopTerraceItems.PRICES, StadiumWallTopTerraceItems.PRICE_VERSION],
		[StadiumRisingAppleItems.PRICES, StadiumRisingAppleItems.PRICE_VERSION],
		[StadiumOutfieldBleacherItems.PRICES, StadiumOutfieldBleacherItems.PRICE_VERSION],
		[StadiumLandmarkItems.PRICES, StadiumLandmarkItems.PRICE_VERSION],
		[StadiumTreehouseItems.PRICES, StadiumTreehouseItems.PRICE_VERSION],
		[StadiumPracticeFacilityItems.PRICES, StadiumPracticeFacilityItems.PRICE_VERSION],
		[StadiumGroundBoxItems.PRICES, StadiumGroundBoxItems.PRICE_VERSION],
		[StadiumMoldedSeatItems.PRICES, StadiumMoldedSeatItems.PRICE_VERSION],
		[StadiumLiveFurnishingItems.PRICES, StadiumLiveFurnishingItems.PRICE_VERSION],
		[StadiumLandscapeOwnedItems.PRICES, StadiumLandscapeOwnedItems.PRICE_VERSION],
		[StadiumFloodlightOwnedItems.PRICES, StadiumFloodlightOwnedItems.PRICE_VERSION],
		[StadiumReceiverOwnedItems.PRICES, StadiumReceiverOwnedItems.PRICE_VERSION],
		[StadiumBoundaryItems.PRICES, StadiumBoundaryItems.PRICE_VERSION],
		[StadiumFacilityItems.PRICES, StadiumFacilityItems.PRICE_VERSION],
		[StadiumRoofItems.PRICES, StadiumRoofItems.PRICE_VERSION],
		[StadiumStraightItems.PRICES, StadiumStraightItems.PRICE_VERSION],
		[StadiumGroundPropsItems.PRICES, StadiumGroundPropsItems.PRICE_VERSION],
		[StadiumPurchases.POOLS, StadiumPurchases.POOL_VERSION],
		[StadiumPurchases.LIGHTS, StadiumPurchases.LIGHT_VERSION],
		[StadiumPurchases.NETS, StadiumPurchases.NET_VERSION],
		[StadiumPurchases.TARGETS, StadiumPurchases.TARGET_VERSION],
		[StadiumPurchases.BLEACHERS, StadiumPurchases.BLEACHER_VERSION],
		[StadiumPurchases.DISPLAYS, StadiumPurchases.DISPLAY_VERSION],
		[StadiumPurchases.SEATING, StadiumPurchases.SEATING_VERSION],
	]
	for pair: Array in cases:
		var ids: Array = pair[0].keys() if pair[0] is Dictionary else Array(pair[0])
		for id: String in ids:
			var command: Dictionary = ClubConstruction.copy_command(club, id, 7, 2)
			check(command.get("price_version") == pair[1], "existing catalog price " + id)
			check(command.id == "stadium-buy:7" and command.rev == 7 and command.op == "stadium_buy" and command.item == id and command.quantity == 2, "exact copy operands " + id)
			check(command.through == ClubPlayers.income_through(club) and command.progress_through == StadiumCareerProgress.capture(club).size(), "exact history witness " + id)
	for id: String in StadiumPurchases.PRICES:
		var command: Dictionary = ClubConstruction.copy_command(club, id, 3)
		check(command.price_version == 1 and not command.has("progress_through"), "starter grammar unchanged " + id)
	check(ClubConstruction.copy_command(club, "ST-043", 0).price_version == StadiumFlagItems.PRICE_VERSION, "flag catalog retained")
	check(ClubConstruction.copy_command(null, "ST-001", 0).is_empty(), "no synthetic career fallback")
	check(ClubCareer.same(before, club.to_data()), "pure builder changes no history or wallet")
	print("STADIUM_COPY_COMMAND checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

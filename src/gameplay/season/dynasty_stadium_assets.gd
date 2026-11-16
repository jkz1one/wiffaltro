extends RefCounted
## Bounded shared workshop journal. Current authority changes; admitted seasons
## retain their exact grant, owned field and draft pool. No ordinary save writes.
const Pool = preload("res://src/gameplay/season/dynasty_stadium_pool.gd")
const Upgrades = preload("res://src/gameplay/season/dynasty_stadium_upgrades.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")


static func supported(command: Variant) -> bool:
	if not command is Dictionary:
		return false
	if Upgrades.supported(command):
		return true
	match command.get("op"):
		"stadium_buy":
			if not command.get("item") is String:
				return false
			if not copy_enabled(command.item):
				return false
			var catalog: Dictionary = ClubConstruction.copy_catalog(command.item)
			return catalog.known and SeasonOwnership._whole(command.get("price_version"), catalog.price_version, catalog.price_version)
		"stadium_draft", "stadium_apply":
			# Later families have their own public activation gates. Do not infer
			# approval from ledger grammar or bypass ClubConstruction's gates.
			return command.get("layout") is Dictionary \
				and (layout_adapted(command.layout) or Pool.supported(command.layout))
	return false


static func layout_enabled(version: Variant) -> bool:
	# Explicit public adapters only. Later ledger families are not UI admission.
	return SeasonOwnership._whole(version, 1, 69) and int(version) in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 47]


static func copy_enabled(item: String) -> bool:
	# Preserve the ordinary public editor's purchase routing, not only ledger grammar.
	if item == "ST-006" and not StadiumPoolWorkshopUI.WORKSHOP_ENABLED:
		return false
	return ClubConstruction.copy_catalog(item).known


static func command(value: Dictionary, request: Dictionary) -> Dictionary:
	var authority: Dictionary = Authority.normalize(value)
	if authority.is_empty() or not supported(request):
		return {"authority": {}, "applied": ClubAssetLedger._error("Unsupported shared workshop transaction.")}
	var club: ClubCareer = Authority._history(authority)
	var applied: Dictionary = ClubPlayers.command(club, request)
	if not applied.ok:
		return {"authority": {}, "applied": applied}
	authority.assets = club._assets.duplicate(true)
	var result: Dictionary = Authority.normalize(authority)
	if result.is_empty():
		return {"authority": {}, "applied": ClubAssetLedger._error("Shared stadium journal did not validate.")}
	for field: String in value:
		if field != "assets" and not ClubCareer.same(value[field], result.get(field)):
			return {"authority": {}, "applied": ClubAssetLedger._error("A workshop command changed frozen career evidence.")}
	return {"authority": result, "applied": applied}


static func allowed(season: SeasonState, request: Dictionary) -> bool:
	if Pool.supported(request.get("layout")):
		return Pool.allowed(season, request)
	if request.get("op") == "stadium_draft":
		return request.get("layout") is Dictionary and ClubConstruction.draft_admission(season, request.layout, true).ok
	if request.get("op") == "stadium_apply":
		return request.get("layout") is Dictionary and ClubConstruction.apply_admission(season, request.layout, true).ok
	return Upgrades.allowed(season, request)


static func layout_adapted(layout: Variant) -> bool:
	if not layout is Dictionary or not layout_enabled(layout.get("version")):
		return false
	if int(layout.version) == 47:
		return layout.get("family") == StadiumWaterfallAnimationLayout.FAMILY \
			and SeasonOwnership._whole(layout.get("animation_base"), 45, 45) \
			and layout_adapted(StadiumWaterfallAnimationLayout.base(layout))
	if int(layout.version) == 17:
		return layout.get("family") == StadiumSurfaceLayout.TERRAIN_FAMILY
	# Later inherited cards remain flat-only; standalone terrain has its own adapter.
	return int(layout.version) < 18 or (SeasonOwnership._whole(layout.get("base_version"), 12, 12)
		and layout.get("family") == {18: StadiumFlagItems.FAMILY, 19: StadiumGroundPropsItems.FAMILY,
		20: StadiumStraightItems.FAMILY, 21: StadiumRoofItems.FAMILY, 22: StadiumFacilityItems.FAMILY,
		23: StadiumBoundaryItems.FAMILY, 24: StadiumReceiverOwnedItems.FAMILY,
		25: StadiumFloodlightOwnedItems.FAMILY, 26: StadiumLandscapeOwnedItems.FAMILY,
		27: StadiumLiveFurnishingItems.FAMILY, 28: StadiumSmallYardSceneryItems.FAMILY,
		29: StadiumMoldedSeatItems.FAMILY,
		30: StadiumGroundBoxItems.FAMILY,
		31: StadiumPracticeFacilityItems.FAMILY,
		32: StadiumTreehouseItems.FAMILY,
		33: StadiumLandmarkItems.FAMILY,
		34: StadiumOutfieldBleacherItems.FAMILY,
		35: StadiumRisingAppleItems.FAMILY,
		36: StadiumWallTopTerraceItems.FAMILY,
		37: StadiumPlayerTunnelItems.FAMILY,
		38: StadiumMountedDisplayItems.FAMILY, 39: StadiumStringLightItems.FAMILY,
		40: StadiumSalvageCarItems.FAMILY, 41: StadiumMasteryBannerItems.FAMILY,
		42: StadiumWaterfallItems.FAMILY, 43: StadiumLightingKitItems.FAMILY,
		44: StadiumOutfieldPlazaItems.FAMILY, 45: StadiumWaterfallLiveItems.FAMILY}.get(int(layout.version)))

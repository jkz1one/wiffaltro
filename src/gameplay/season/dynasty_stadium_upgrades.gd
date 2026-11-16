extends RefCounted
## Existing public upgrade grammar and gates. No season creation or persistence.

static func supported(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var item: Variant = value.get("item", "")
	if not item is String:
		return false
	match value.get("op"):
		"stadium_land":
			return value.get("tier") in StadiumLand.TIERS and _price(value, StadiumLand.VERSION)
		"stadium_style":
			var version: int = _style_version(item)
			return version >= 0 and _price(value, version)
		"stadium_surface":
			return item in StadiumSurfaceProgression.PRICES and _price(value, StadiumSurfaceProgression.VERSION)
		"stadium_scoreboard":
			return StadiumScoreboardLayout.RUNTIME_READY and item in StadiumScoreboardCatalog.IDS \
				and _price(value, StadiumScoreboardPurchases.VERSION)
		"stadium_wall_piece":
			return StadiumScoreboardLayout.RUNTIME_READY and not StadiumWallPieceCatalog.item(item).is_empty() \
				and _price(value, StadiumWallPieceOwnership.VERSION)
		"stadium_buy":
			return StadiumWallItems.RUNTIME_READY and item in StadiumWallItems.PRICES \
				and _price(value, StadiumWallItems.PRICE_VERSION)
		"stadium_salvage_clear":
			return value.get("copy") == StadiumStock.SALVAGE_COPY \
				and _price(value, ClubAssetLedger.SALVAGE_ORIGIN_VERSION)
	return false


static func _price(value: Dictionary, expected: int) -> bool:
	return SeasonOwnership._whole(value.get("price_version"), expected, expected)


static func _style_version(item: String) -> int:
	if item in StadiumInfieldStyles.PRICES:
		return StadiumInfieldStyles.PRICE_VERSION
	if item in StadiumGroundStyles.PRICES:
		return StadiumGroundStyles.PRICE_VERSION
	return StadiumFieldStyles.VERSION if item in StadiumFieldStyles.PRICES else -1


static func allowed(season: SeasonState, request: Dictionary) -> bool:
	if season == null:
		return false
	if request.get("op") in ["stadium_land", "stadium_salvage_clear"]:
		if not season.owned_surface_night.is_empty() and season.phase != SeasonState.Phase.COMPLETE \
			and not load("res://src/gameplay/season/dynasty_shared_time_runtime.gd").future_editable(season):
			return false
	if request.get("op") == "stadium_land":
		return season.phase == SeasonState.Phase.COMPLETE or season.home_property.has("boundary")
	return true


static func command(club: ClubCareer, operation: String, item: String, revision: int, quantity: int = 1) -> Dictionary:
	if club == null:
		return {}
	var result: Dictionary = {"id": "shared-%s:%d" % [operation, revision], "rev": revision,
		"op": operation, "through": ClubPlayers.income_through(club)}
	match operation:
		"stadium_land":
			result.tier = item
			result.price_version = StadiumLand.VERSION
		"stadium_style":
			result.item = item
			result.price_version = _style_version(item)
		"stadium_surface":
			result.item = item
			result.price_version = StadiumSurfaceProgression.VERSION
		"stadium_scoreboard":
			result.item = item
			result.quantity = quantity
			result.price_version = StadiumScoreboardPurchases.VERSION
		"stadium_wall_piece":
			result.item = item
			result.quantity = quantity
			result.price_version = StadiumWallPieceOwnership.VERSION
		"stadium_buy":
			result.item = item
			result.quantity = quantity
			result.price_version = StadiumWallItems.PRICE_VERSION
		"stadium_salvage_clear":
			result.copy = StadiumStock.SALVAGE_COPY
			result.price_version = ClubAssetLedger.SALVAGE_ORIGIN_VERSION
		_:
			return {}
	if operation not in ["stadium_surface", "stadium_salvage_clear"]:
		result.progress_through = StadiumCareerProgress.capture(club).size()
	return result if supported(result) else {}


static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tier: String in StadiumLand.TIERS:
		if tier != "backyard":
			result.append({"op": "stadium_land", "item": tier, "label": "Expand land: " + StadiumLand.NAMES[tier]})
	for prices: Dictionary in [StadiumFieldStyles.PRICES, StadiumGroundStyles.PRICES, StadiumInfieldStyles.PRICES]:
		for item: String in prices:
			result.append({"op": "stadium_style", "item": item, "label": "Appearance: " + item})
	for item: String in StadiumSurfaceProgression.PRICES:
		result.append({"op": "stadium_surface", "item": item, "label": "Surface: " + item})
	if StadiumScoreboardLayout.RUNTIME_READY:
		for item: String in StadiumScoreboardCatalog.IDS:
			result.append({"op": "stadium_scoreboard", "item": item, "label": "Scoreboard: " + StadiumScoreboardCatalog.item(item).name})
		for item: String in StadiumWallPieceCatalog.DATA:
			result.append({"op": "stadium_wall_piece", "item": item, "label": "Wall piece: " + StadiumWallPieceCatalog.item(item).name})
	if StadiumWallItems.RUNTIME_READY:
		for item: String in StadiumWallItems.PRICES:
			result.append({"op": "stadium_buy", "item": item, "label": "Wall copy: " + item})
	result.append({"op": "stadium_salvage_clear", "item": "", "label": "Clear starter salvage car"})
	return result

extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_public_new_club(
	seed_value: int = 0, credits: Array = [], progress: Array = [], championships: Dictionary = {}
) -> ClubAssetLedger:
	var result: ClubAssetLedger = ClubAssetLedger.new(seed_value, credits, progress, championships)
	result._initialize_surface_origin(StadiumSurfaceProgression.ROUGH_ORIGIN)
	result._initialize_salvage_origin()
	return result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_salvage_origin_record() -> Dictionary:
	return {
		"version": ClubAssetLedger.SALVAGE_ORIGIN_VERSION,
		"source": StadiumStock.SALVAGE_SOURCE,
		"copy": StadiumStock.SALVAGE_COPY,
		"item": "ST-005",
		"site": "CAR-START"
	}
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_valid_salvage_origin(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._keys(value, ["version", "source", "copy", "item", "site"])
		and SeasonOwnership._whole(value.version, ClubAssetLedger.SALVAGE_ORIGIN_VERSION, \
			ClubAssetLedger.SALVAGE_ORIGIN_VERSION)
		and value.source is String
		and value.source == StadiumStock.SALVAGE_SOURCE
		and value.copy is String
		and value.copy == StadiumStock.SALVAGE_COPY
		and value.item is String
		and value.item == "ST-005"
		and value.site is String
		and value.site == "CAR-START"
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_salvage_origin_signature() -> String:
	return (
		JSON
		. stringify(
			{
				"origin": ClubAssetLedger.salvage_origin_record(),
				"clearance_price": ClubAssetLedger.SALVAGE_CLEAR_PRICE,
				"clearance_version": ClubAssetLedger.SALVAGE_ORIGIN_VERSION,
				"blueprint": false,
				"clearance": "same-copy-active-and-draft-to-storage-once"
			},
			"",
			true,
			true
		)
		. sha256_text()
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_initialize_salvage_origin(_source_owner: ClubAssetLedger) -> void:
	_source_owner._advance_mutation_generation()
	_source_owner._salvage_origin = ClubAssetLedger.salvage_origin_record()
	_source_owner._salvage_cleared = false
	_source_owner._stock.copies[StadiumStock.SALVAGE_COPY] = {
		"item": "ST-005", "paid": 0, "source": StadiumStock.SALVAGE_SOURCE
	}
	_source_owner._stadium_draft = StadiumSalvageCarItems.upgrade(_source_owner._stadium_draft, \
		_source_owner._surface_owned)
	_source_owner._stadium_draft["salvage_cars"] = [{"copy": StadiumStock.SALVAGE_COPY, "site": \
		"CAR-START"}]
	_source_owner._stadium_active = _source_owner._stadium_draft.duplicate(true)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_initialize_surface_origin(_source_owner: ClubAssetLedger, origin: \
	String) -> void:
	_source_owner._advance_mutation_generation()
	_source_owner._surface_origin = origin
	_source_owner._surface_owned = StadiumSurfaceProgression.initial(origin)
	if origin == StadiumSurfaceProgression.ROUGH_ORIGIN:
		_source_owner._stadium_draft = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), \
			_source_owner._surface_owned)
		_source_owner._stadium_active = _source_owner._stadium_draft.duplicate(true)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_mutation_generation(_source_owner: ClubAssetLedger) -> int:
	return _source_owner._mutation_generation
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_private_advance_mutation_generation(_source_owner: ClubAssetLedger) -> void:
	# Exhaustion permanently disqualifies fast ownership; never wrap to an old seal.
	if _source_owner._mutation_generation < 0:
		return
	if _source_owner._mutation_generation == 9223372036854775807:
		_source_owner._mutation_generation = -1
	else:
		_source_owner._mutation_generation += 1
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_surface_owned(_source_owner: ClubAssetLedger) -> Array[String]:
	return _source_owner._surface_owned.duplicate()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_valid_credits(value: Variant) -> bool:
	return ClubAssetLedger.Journal.valid_credits(value)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_owned(_source_owner: ClubAssetLedger, earned: Array = []) -> \
	Array[String]:
	var result: Array[String] = ClubPlayerCatalog.initial_owned()
	result.append_array(_source_owner._pack_owned)
	for id: Variant in earned:
		if id is String and ClubPlayerCatalog.EARNED.has(id) and not result.has(id):
			result.append(id)
	result.sort()
	return result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_construction(_source_owner: ClubAssetLedger) -> StadiumStock:
	# Ownership returned to callers is isolated from the journal.
	return StadiumStock.from_data(_source_owner._stock.to_data())
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_wall_pieces(_source_owner: ClubAssetLedger) -> StadiumWallPieceOwnership:
	return StadiumWallPieceOwnership.from_data(
		_source_owner._wall_pieces.to_data(), _source_owner._stock.capacity_count() + \
			_source_owner._scoreboards.copies.size()
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_scoreboards(_source_owner: ClubAssetLedger) -> \
	StadiumScoreboardOwnership:
	return StadiumScoreboardOwnership.from_data(
		_source_owner._scoreboards.to_data(), _source_owner._stock.capacity_count() + \
			_source_owner._wall_pieces.stock.copies.size()
	)
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_balance(_source_owner: ClubAssetLedger) -> int:
	return _source_owner._income(_source_owner._credits.size()) - _source_owner._spent
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_revision(_source_owner: ClubAssetLedger) -> int:
	return _source_owner._events.size()
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_view(_source_owner: ClubAssetLedger) -> Dictionary:
	var result: Dictionary = {
		"revision": _source_owner.revision(),
		"balance": _source_owner.balance(),
		"spent": _source_owner._spent,
		"owned": _source_owner.owned(),
		"pending": _source_owner._pending.duplicate(true),
		"opened": _source_owner._opened,
		"surface_origin": _source_owner._surface_origin,
		"surface_owned": _source_owner.surface_owned(),
		"land": _source_owner._land,
		"stadium_draft": _source_owner._stadium_draft.duplicate(true),
		"stadium_active": _source_owner._stadium_active.duplicate(true),
		"pack_price": ClubPlayerCatalog.price(),
		"pack_remaining": ClubPlayerCatalog.pack_candidates(_source_owner.owned()).size()
	}

	if not _source_owner._salvage_origin.is_empty() or \
		ClubAssetLedger._has_salvage_events(_source_owner._events):
		result["salvage_origin"] = _source_owner._salvage_origin.duplicate(true)
		result["salvage_cleared"] = _source_owner._salvage_cleared
	return result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_to_data(_source_owner: ClubAssetLedger) -> Dictionary:
	var result: Dictionary = {
		"version": ClubAssetLedger.VERSION,
		"seed": _source_owner._seed,
		"catalog": ClubPlayerCatalog.signature(),
		"starter_grant": 1,
		"starter_catalog": StadiumStock.grant_signature(),
		"draft_catalog": StadiumStarterLayout.signature(),
		"property_catalog": StadiumProperty.signature("backyard"),
		"construction_catalog": StadiumPurchases.signature(),
		"seating_catalog": StadiumPurchases.signature(StadiumPurchases.SEATING_VERSION),
		"seating_layout_catalog": StadiumHomeLayout.signature(),
		"land_catalog": StadiumLand.signature(),
		"style_catalog": StadiumFieldStyles.signature(),
		"appearance_catalog": StadiumFieldStyles.appearance_signature(),
		"display_catalog": StadiumPurchases.signature(StadiumPurchases.DISPLAY_VERSION),
		"display_layout_catalog": StadiumClubItems.signature(),
		"ground_catalog": StadiumGroundStyles.signature(),
		"ground_layout_catalog": StadiumGroundStyles.appearance_signature(),
		"bleacher_catalog": StadiumPurchases.signature(StadiumPurchases.BLEACHER_VERSION),
		"bleacher_layout_catalog": StadiumBleacherItems.signature(),
		"target_catalog": StadiumPurchases.signature(StadiumPurchases.TARGET_VERSION),
		"target_layout_catalog": StadiumTargetItems.signature(),
		"net_catalog": StadiumPurchases.signature(StadiumPurchases.NET_VERSION),
		"net_layout_catalog": StadiumNetItems.signature(),
		"light_catalog": StadiumPurchases.signature(StadiumPurchases.LIGHT_VERSION),
		"light_layout_catalog": StadiumLightItems.signature(),
		"infield_catalog": StadiumInfieldStyles.signature(),
		"infield_layout_catalog": StadiumInfieldStyles.appearance_signature(),
		"wall_catalog": StadiumWallItems.price_signature(),
		"wall_layout_catalog": StadiumWallItems.signature(),
		"surface_catalog": StadiumSurfaceProgression.signature(),
		"surface_origin": _source_owner._surface_origin,
		"surface_layout_catalog": StadiumSurfaceLayout.signature(),
		"wall_piece_catalog": StadiumWallPieceOwnership.signature(),
		"advanced_layout_catalog": StadiumAdvancedWallLayout.signature(),
		"scoreboard_catalog": StadiumScoreboardPurchases.signature(),
		"scoreboard_layout_catalog": StadiumScoreboardLayout.signature(),
		"mounted_scoreboard_layout_catalog": StadiumMountedScoreboardLayout.signature(),
		"pool_catalog": StadiumPurchases.signature(StadiumPurchases.POOL_VERSION),
		"pool_layout_catalog": StadiumPoolOwnedLayout.signature(),
		"events": ClubAssetLedger.Journal.serialized_events(_source_owner._events)
	}
	if ClubAssetLedger._has_terrain_events(_source_owner._events):
		result.version = ClubAssetLedger.TERRAIN_VERSION
		result["terrain_catalog"] = StadiumSurfaceTerrain.signature("rough")
		result["leveled_terrain_catalog"] = StadiumSurfaceTerrain.signature("leveled")
	if ClubAssetLedger._has_flag_events(_source_owner._events):
		result.version = ClubAssetLedger.FLAG_VERSION
		result["flag_catalog"] = StadiumFlagItems.price_signature()
		result["flag_layout_catalog"] = StadiumFlagItems.signature()
	if ClubAssetLedger._has_ground_props_events(_source_owner._events):
		result.version = ClubAssetLedger.GROUND_PROPS_VERSION
		result["ground_props_catalog"] = StadiumGroundPropsItems.price_signature()
		result["ground_props_layout_catalog"] = StadiumGroundPropsItems.signature()
	if ClubAssetLedger._has_straight_events(_source_owner._events):
		result.version = ClubAssetLedger.STRAIGHT_VERSION
		result["straight_catalog"] = StadiumStraightItems.price_signature()
		result["straight_layout_catalog"] = StadiumStraightItems.signature()
	if ClubAssetLedger._has_pennant_events(_source_owner._events):
		result.version = ClubAssetLedger.PENNANT_VERSION
		result["pennant_catalog"] = StadiumPennantRewards.signature()
	if ClubAssetLedger._has_roof_events(_source_owner._events):
		result.version = ClubAssetLedger.ROOF_VERSION
		result["roof_catalog"] = StadiumRoofItems.price_signature()
		result["roof_layout_catalog"] = StadiumRoofItems.signature()
	if ClubAssetLedger._has_facility_events(_source_owner._events):
		result.version = ClubAssetLedger.FACILITY_VERSION
		result["facility_catalog"] = StadiumFacilityItems.price_signature()
		result["facility_layout_catalog"] = StadiumFacilityItems.signature()
	if ClubAssetLedger._has_boundary_events(_source_owner._events):
		result.version = ClubAssetLedger.BOUNDARY_VERSION
		result["boundary_catalog"] = StadiumBoundaryItems.price_signature()
		result["boundary_layout_catalog"] = StadiumBoundaryItems.signature()
	if ClubAssetLedger._has_receiver_events(_source_owner._events):
		result.version = ClubAssetLedger.RECEIVER_VERSION
		result["receiver_catalog"] = StadiumReceiverOwnedItems.price_signature()
		result["receiver_layout_catalog"] = StadiumReceiverOwnedItems.signature()
	if ClubAssetLedger._has_floodlight_events(_source_owner._events):
		result.version = ClubAssetLedger.FLOODLIGHT_VERSION
		result["floodlight_catalog"] = StadiumFloodlightOwnedItems.price_signature()
		result["floodlight_layout_catalog"] = StadiumFloodlightOwnedItems.signature()
	if ClubAssetLedger._has_landscape_events(_source_owner._events):
		result.version = ClubAssetLedger.LANDSCAPE_VERSION
		result["landscape_catalog"] = StadiumLandscapeOwnedItems.price_signature()
		result["landscape_layout_catalog"] = StadiumLandscapeOwnedItems.signature()
	if ClubAssetLedger._has_live_furnishing_events(_source_owner._events):
		result.version = ClubAssetLedger.LIVE_FURNISHING_VERSION
		result["live_furnishing_catalog"] = StadiumLiveFurnishingItems.price_signature()
		result["live_furnishing_layout_catalog"] = StadiumLiveFurnishingItems.signature()
	if ClubAssetLedger._has_small_yard_scenery_events(_source_owner._events):
		result.version = ClubAssetLedger.SMALL_YARD_SCENERY_VERSION
		result["yard_scenery_layout_catalog"] = StadiumSmallYardSceneryItems.signature()
	if ClubAssetLedger._has_molded_seat_events(_source_owner._events):
		result.version = ClubAssetLedger.MOLDED_SEAT_VERSION
		result["molded_seat_catalog"] = StadiumMoldedSeatItems.price_signature()
		result["molded_seat_layout_catalog"] = StadiumMoldedSeatItems.signature()
	if ClubAssetLedger._has_ground_box_events(_source_owner._events):
		result.version = ClubAssetLedger.GROUND_BOX_VERSION
		result["ground_box_catalog"] = StadiumGroundBoxItems.price_signature()
		result["ground_box_layout_catalog"] = StadiumGroundBoxItems.signature()
	if ClubAssetLedger._has_practice_facility_events(_source_owner._events):
		result.version = ClubAssetLedger.PRACTICE_FACILITY_VERSION
		result["practice_facility_catalog"] = StadiumPracticeFacilityItems.price_signature()
		result["practice_facility_layout_catalog"] = StadiumPracticeFacilityItems.signature()
	if ClubAssetLedger._has_treehouse_events(_source_owner._events):
		result.version = ClubAssetLedger.TREEHOUSE_VERSION
		result["treehouse_catalog"] = StadiumTreehouseItems.price_signature()
		result["treehouse_layout_catalog"] = StadiumTreehouseItems.signature()
	if ClubAssetLedger._has_landmark_events(_source_owner._events):
		result.version = ClubAssetLedger.LANDMARK_VERSION
		result["landmark_catalog"] = StadiumLandmarkItems.price_signature()
		result["landmark_layout_catalog"] = StadiumLandmarkItems.signature()
	if ClubAssetLedger._has_outfield_bleacher_events(_source_owner._events):
		result.version = ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
		result["outfield_bleacher_catalog"] = StadiumOutfieldBleacherItems.price_signature()
		result["outfield_bleacher_layout_catalog"] = StadiumOutfieldBleacherItems.signature()
	if ClubAssetLedger._has_rising_apple_events(_source_owner._events):
		result.version = ClubAssetLedger.RISING_APPLE_VERSION
		result["rising_apple_catalog"] = StadiumRisingAppleItems.price_signature()
		result["rising_apple_layout_catalog"] = StadiumRisingAppleItems.signature()
	if ClubAssetLedger._has_wall_top_terrace_events(_source_owner._events):
		result.version = ClubAssetLedger.WALL_TOP_TERRACE_VERSION
		result["wall_top_terrace_catalog"] = StadiumWallTopTerraceItems.price_signature()
		result["wall_top_terrace_layout_catalog"] = StadiumWallTopTerraceItems.signature()
	if ClubAssetLedger._has_player_tunnel_events(_source_owner._events):
		result.version = ClubAssetLedger.PLAYER_TUNNEL_VERSION
		result["player_tunnel_catalog"] = StadiumPlayerTunnelItems.price_signature()
		result["player_tunnel_layout_catalog"] = StadiumPlayerTunnelItems.signature()
	if ClubAssetLedger._has_mounted_display_events(_source_owner._events):
		result.version = ClubAssetLedger.MOUNTED_DISPLAY_VERSION
		result["mounted_display_catalog"] = StadiumMountedDisplayItems.price_signature()
		result["mounted_display_layout_catalog"] = StadiumMountedDisplayItems.signature()
	if ClubAssetLedger._has_string_light_events(_source_owner._events):
		result.version = ClubAssetLedger.STRING_LIGHT_VERSION
		result["string_light_catalog"] = StadiumStringLightItems.price_signature()
		result["string_light_layout_catalog"] = StadiumStringLightItems.signature()
	if not _source_owner._salvage_origin.is_empty() or \
		ClubAssetLedger._has_salvage_events(_source_owner._events):
		result.version = ClubAssetLedger.SALVAGE_VERSION
		result["salvage_origin"] = _source_owner._salvage_origin.duplicate(true)
		result["salvage_origin_catalog"] = ClubAssetLedger.salvage_origin_signature()
		result["salvage_catalog"] = StadiumSalvageCarItems.price_signature()
		result["salvage_layout_catalog"] = StadiumSalvageCarItems.signature()
	if ClubAssetLedger._has_mastery_events(_source_owner._events):
		result.version = ClubAssetLedger.MASTERY_VERSION
		result["mastery_catalog"] = StadiumPennantRewards.mastery_signature()
		if ClubAssetLedger._has_mastery_layout_events(_source_owner._events):
			result["mastery_layout_catalog"] = StadiumMasteryBannerItems.signature()
	if ClubAssetLedger._has_plaque_events(_source_owner._events):
		result.version = ClubAssetLedger.PLAQUE_VERSION
		result["plaque_catalog"] = StadiumPlaqueRewards.signature()
	if ClubAssetLedger._has_waterfall_events(_source_owner._events):
		result.version = ClubAssetLedger.WATERFALL_VERSION
		result["waterfall_catalog"] = StadiumWaterfallItems.price_signature()
		result["waterfall_layout_catalog"] = StadiumWaterfallItems.signature()
	if ClubAssetLedger._has_lighting_kit_events(_source_owner._events):
		result.version = ClubAssetLedger.LIGHTING_KIT_VERSION
		result["lighting_kit_catalog"] = StadiumLightingKitItems.price_signature()
		result["lighting_kit_layout_catalog"] = StadiumLightingKitItems.signature()
	if ClubAssetLedger._has_outfield_plaza_events(_source_owner._events):
		result.version = ClubAssetLedger.OUTFIELD_PLAZA_VERSION
		result["outfield_plaza_catalog"] = StadiumOutfieldPlazaItems.price_signature()
		result["outfield_plaza_layout_catalog"] = StadiumOutfieldPlazaItems.signature()
	if ClubAssetLedger._has_live_waterfall_events(_source_owner._events):
		result.version = ClubAssetLedger.LIVE_WATERFALL_VERSION
		result["live_waterfall_layout_catalog"] = StadiumWaterfallLiveItems.signature()
	if ClubAssetLedger._has_low_wall_events(_source_owner._events):
		result.version = ClubAssetLedger.LOW_WALL_VERSION
		result["low_wall_catalog"] = StadiumLowWallLayout.signature()
	if ClubAssetLedger._has_waterfall_animation_events(_source_owner._events):
		result.version = ClubAssetLedger.WATERFALL_ANIMATION_VERSION
		result["waterfall_animation_catalog"] = StadiumWaterfallAnimationLayout.signature()
	return result
# gdlint: enable=max-returns


# gdlint: disable=max-returns
static func _source_public_from_data(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array = [],
	championships: Dictionary = {}
) -> ClubAssetLedger:
	var ac02_token: int = ClubAssetLedger.AC02_PASSIVE_13.enter("club_asset_ledger.from_data")
	var ac02_result: ClubAssetLedger = ClubAssetLedger._ac02_passive_13_from_data(
		value, seed_value, credits, progress, championships
	)
	ClubAssetLedger.AC02_PASSIVE_13.leave(ac02_token)
	return ac02_result
# gdlint: enable=max-returns

extends RefCounted
## Stateless operations for the original ClubAssetLedger owner.


# gdlint: disable=max-returns
static func _source_private_restore_data_stage_3(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary,
	keys: Array
) -> ClubAssetLedger:
	if (
		value.version == ClubAssetLedger.PRACTICE_FACILITY_VERSION
		or (
			(
				value.version == ClubAssetLedger.TREEHOUSE_VERSION
				or (
					value.version == ClubAssetLedger.LANDMARK_VERSION
					or (
						value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
						or (
							value.version == ClubAssetLedger.RISING_APPLE_VERSION
							or (
								value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
								or (
									value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
									or (
										value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
										or (
											value.version == ClubAssetLedger.STRING_LIGHT_VERSION
											or (
												value.version == ClubAssetLedger.SALVAGE_VERSION
												or value.version >= ClubAssetLedger.MASTERY_VERSION
											)
										)
									)
								)
							)
						)
					)
				)
			)
			and ClubAssetLedger._has_practice_facility_events(value.get("events"))
		)
	):
		keys.append_array(["practice_facility_catalog", "practice_facility_layout_catalog"])
	if (
		value.version == ClubAssetLedger.TREEHOUSE_VERSION
		or (
			(
				value.version == ClubAssetLedger.LANDMARK_VERSION
				or (
					value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
					or (
						value.version == ClubAssetLedger.RISING_APPLE_VERSION
						or (
							value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
							or (
								value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
								or (
									value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
									or (
										value.version == ClubAssetLedger.STRING_LIGHT_VERSION
										or (
											value.version == ClubAssetLedger.SALVAGE_VERSION
											or value.version >= ClubAssetLedger.MASTERY_VERSION
										)
									)
								)
							)
						)
					)
				)
			)
			and ClubAssetLedger._has_treehouse_events(value.get("events"))
		)
	):
		keys.append_array(["treehouse_catalog", "treehouse_layout_catalog"])
	if (
		value.version == ClubAssetLedger.LANDMARK_VERSION
		or (
			(
				value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
				or (
					value.version == ClubAssetLedger.RISING_APPLE_VERSION
					or (
						value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
						or (
							value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
							or (
								value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
								or (
									value.version == ClubAssetLedger.STRING_LIGHT_VERSION
									or (
										value.version == ClubAssetLedger.SALVAGE_VERSION
										or value.version >= ClubAssetLedger.MASTERY_VERSION
									)
								)
							)
						)
					)
				)
			)
			and ClubAssetLedger._has_landmark_events(value.get("events"))
		)
	):
		keys.append_array(["landmark_catalog", "landmark_layout_catalog"])
	if (
		value.version == ClubAssetLedger.OUTFIELD_BLEACHER_VERSION
		or (
			(
				value.version == ClubAssetLedger.RISING_APPLE_VERSION
				or (
					value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
					or (
						value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
						or (
							value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
							or (
								value.version == ClubAssetLedger.STRING_LIGHT_VERSION
								or (
									value.version == ClubAssetLedger.SALVAGE_VERSION
									or value.version >= ClubAssetLedger.MASTERY_VERSION
								)
							)
						)
					)
				)
			)
			and ClubAssetLedger._has_outfield_bleacher_events(value.get("events"))
		)
	):
		keys.append_array(["outfield_bleacher_catalog", "outfield_bleacher_layout_catalog"])
	if (
		value.version == ClubAssetLedger.RISING_APPLE_VERSION
		or (
			(
				value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
				or (
					value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
					or (
						value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
						or (
							value.version == ClubAssetLedger.STRING_LIGHT_VERSION
							or (
								value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
									ClubAssetLedger.MASTERY_VERSION
							)
						)
					)
				)
			)
			and ClubAssetLedger._has_rising_apple_events(value.get("events"))
		)
	):
		keys.append_array(["rising_apple_catalog", "rising_apple_layout_catalog"])
	if (
		value.version == ClubAssetLedger.WALL_TOP_TERRACE_VERSION
		or (
			(
				value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
				or (
					value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
					or (
						value.version == ClubAssetLedger.STRING_LIGHT_VERSION
						or (value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
							ClubAssetLedger.MASTERY_VERSION)
					)
				)
			)
			and ClubAssetLedger._has_wall_top_terrace_events(value.get("events"))
		)
	):
		keys.append_array(["wall_top_terrace_catalog", "wall_top_terrace_layout_catalog"])
	if (
		value.version == ClubAssetLedger.PLAYER_TUNNEL_VERSION
		or (
			(
				value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
				or (
					value.version == ClubAssetLedger.STRING_LIGHT_VERSION
					or (value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
						ClubAssetLedger.MASTERY_VERSION)
				)
			)
			and ClubAssetLedger._has_player_tunnel_events(value.get("events"))
		)
	):
		keys.append_array(["player_tunnel_catalog", "player_tunnel_layout_catalog"])
	if (
		value.version == ClubAssetLedger.MOUNTED_DISPLAY_VERSION
		or (
			(
				value.version == ClubAssetLedger.STRING_LIGHT_VERSION
				or (value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
					ClubAssetLedger.MASTERY_VERSION)
			)
			and ClubAssetLedger._has_mounted_display_events(value.get("events"))
		)
	):
		keys.append_array(["mounted_display_catalog", "mounted_display_layout_catalog"])
	if (
		value.version == ClubAssetLedger.STRING_LIGHT_VERSION
		or (
			(value.version == ClubAssetLedger.SALVAGE_VERSION or value.version >= \
				ClubAssetLedger.MASTERY_VERSION)
			and ClubAssetLedger._has_string_light_events(value.get("events"))
		)
	):
		keys.append_array(["string_light_catalog", "string_light_layout_catalog"])
	if (
		value.version == ClubAssetLedger.SALVAGE_VERSION
		or (value.version >= ClubAssetLedger.MASTERY_VERSION and value.has("salvage_origin"))
	):
		keys.append_array(
			[
				"salvage_origin",
				"salvage_origin_catalog",
				"salvage_catalog",
				"salvage_layout_catalog"
			]
		)
	if (
		value.version == ClubAssetLedger.MASTERY_VERSION
		or (value.version >= ClubAssetLedger.PLAQUE_VERSION and \
			ClubAssetLedger._has_mastery_events(value.get("events")))
	):
		keys.append("mastery_catalog")
		if ClubAssetLedger._has_mastery_layout_events(value.get("events")):
			keys.append("mastery_layout_catalog")
			if value.get("mastery_layout_catalog") != StadiumMasteryBannerItems.signature():
				return null
		if (
			value.get("mastery_catalog") != StadiumPennantRewards.mastery_signature()
			or not ClubAssetLedger._has_mastery_events(value.get("events"))
		):
			return null
	if (
		value.version == ClubAssetLedger.PLAQUE_VERSION
		or (value.version >= ClubAssetLedger.WATERFALL_VERSION and \
			ClubAssetLedger._has_plaque_events(value.get("events")))
	):
		keys.append("plaque_catalog")
		if (
			value.get("plaque_catalog") != StadiumPlaqueRewards.signature()
			or not ClubAssetLedger._has_plaque_events(value.get("events"))
		):
			return null
	if (
		value.version == ClubAssetLedger.WATERFALL_VERSION
		or (value.version >= ClubAssetLedger.LIGHTING_KIT_VERSION and \
			ClubAssetLedger._has_waterfall_events(value.get("events")))
	):
		keys.append_array(["waterfall_catalog", "waterfall_layout_catalog"])
		if (
			value.get("waterfall_catalog") != StadiumWaterfallItems.price_signature()
			or value.get("waterfall_layout_catalog") != StadiumWaterfallItems.signature()
			or not ClubAssetLedger._has_waterfall_events(value.get("events"))
		):
			return null
	if (
		value.version == ClubAssetLedger.LIGHTING_KIT_VERSION
		or (
			value.version >= ClubAssetLedger.OUTFIELD_PLAZA_VERSION
			and ClubAssetLedger._has_lighting_kit_events(value.get("events"))
		)
	):
		keys.append_array(["lighting_kit_catalog", "lighting_kit_layout_catalog"])
		if (
			value.get("lighting_kit_catalog") != StadiumLightingKitItems.price_signature()
			or value.get("lighting_kit_layout_catalog") != StadiumLightingKitItems.signature()
			or not ClubAssetLedger._has_lighting_kit_events(value.get("events"))
		):
			return null
	if (
		value.version == ClubAssetLedger.OUTFIELD_PLAZA_VERSION
		or (
			value.version >= ClubAssetLedger.LIVE_WATERFALL_VERSION
			and ClubAssetLedger._has_outfield_plaza_events(value.get("events"))
		)
	):
		keys.append_array(["outfield_plaza_catalog", "outfield_plaza_layout_catalog"])
		if (
			value.get("outfield_plaza_catalog") != StadiumOutfieldPlazaItems.price_signature()
			or value.get("outfield_plaza_layout_catalog") != StadiumOutfieldPlazaItems.signature()
			or not ClubAssetLedger._has_outfield_plaza_events(value.get("events"))
		):
			return null
	if (
		value.version == ClubAssetLedger.LIVE_WATERFALL_VERSION
		or (value.version >= ClubAssetLedger.LOW_WALL_VERSION and \
			ClubAssetLedger._has_live_waterfall_events(value.get("events")))
	):
		keys.append("live_waterfall_layout_catalog")
		if (
			value.get("live_waterfall_layout_catalog") != StadiumWaterfallLiveItems.signature()
			or not ClubAssetLedger._has_live_waterfall_events(value.get("events"))
		):
			return null
	if (
		value.version == ClubAssetLedger.LOW_WALL_VERSION
		or (
			value.version >= ClubAssetLedger.WATERFALL_ANIMATION_VERSION
			and ClubAssetLedger._has_low_wall_events(value.get("events"))
		)
	):
		keys.append("low_wall_catalog")
		if (
			value.get("low_wall_catalog") != StadiumLowWallLayout.signature()
			or not ClubAssetLedger._has_low_wall_events(value.get("events"))
		):
			return null
	if value.version == ClubAssetLedger.WATERFALL_ANIMATION_VERSION:
		keys.append("waterfall_animation_catalog")
		if (
			value.get("waterfall_animation_catalog") != StadiumWaterfallAnimationLayout.signature()
			or not ClubAssetLedger._has_waterfall_animation_events(value.get("events"))
		):
			return null
	if not ClubAssetLedger.Journal.valid_header(value, keys, seed_value,
		ClubPlayerCatalog.signature, ClubAssetLedger.WATERFALL_ANIMATION_VERSION,
		ClubAssetLedger.MAX_EVENTS):
		return null
	if (
		value.version >= 2
		and (
			not SeasonOwnership._whole(value.starter_grant, 1, 1)
			or not value.starter_catalog is String
			or value.starter_catalog != StadiumStock.grant_signature()
		)
	):
		return null
	if (
		value.version >= 3
		and (
			not value.draft_catalog is String
			or value.draft_catalog != StadiumStarterLayout.signature()
		)
	):
		return null
	if (
		value.version >= 4
		and (
			not value.property_catalog is String
			or value.property_catalog != StadiumProperty.signature("backyard")
		)
	):
		return null
	if (
		value.version >= 5
		and (
			not value.construction_catalog is String
			or value.construction_catalog != StadiumPurchases.signature()
		)
	):
		return null
	if (
		value.version >= 6
		and (
			not value.seating_catalog is String
			or value.seating_catalog != StadiumPurchases.signature(StadiumPurchases.SEATING_VERSION)
		)
	):
		return null
	if (
		value.version >= 6
		and (
			not value.seating_layout_catalog is String
			or value.seating_layout_catalog != StadiumHomeLayout.signature()
		)
	):
		return null
	if (
		value.version >= 7
		and (not value.land_catalog is String or value.land_catalog != StadiumLand.signature())
	):
		return null
	if (
		value.version >= 8
		and (
			not value.style_catalog is String
			or value.style_catalog != StadiumFieldStyles.signature()
			or not value.appearance_catalog is String
			or value.appearance_catalog != StadiumFieldStyles.appearance_signature()
		)
	):
		return null
	if (
		value.version >= 9
		and (
			not value.display_catalog is String
			or value.display_catalog != StadiumPurchases.signature(StadiumPurchases.DISPLAY_VERSION)
			or not value.display_layout_catalog is String
			or value.display_layout_catalog != StadiumClubItems.signature()
		)
	):
		return null
	if (
		value.version >= 10
		and (
			not value.ground_catalog is String
			or value.ground_catalog != StadiumGroundStyles.signature()
			or not value.ground_layout_catalog is String
			or value.ground_layout_catalog != StadiumGroundStyles.appearance_signature()
		)
	):
		return null
	if (
		value.version >= 11
		and (
			not value.bleacher_catalog is String
			or (
				value.bleacher_catalog
				!= StadiumPurchases.signature(StadiumPurchases.BLEACHER_VERSION)
			)
			or not value.bleacher_layout_catalog is String
			or value.bleacher_layout_catalog != StadiumBleacherItems.signature()
		)
	):
		return null
	if (
		value.version >= 12
		and (
			not value.target_catalog is String
			or value.target_catalog != StadiumPurchases.signature(StadiumPurchases.TARGET_VERSION)
			or not value.target_layout_catalog is String
			or value.target_layout_catalog != StadiumTargetItems.signature()
		)
	):
		return null
	if (
		value.version >= 13
		and (
			not value.net_catalog is String
			or value.net_catalog != StadiumPurchases.signature(StadiumPurchases.NET_VERSION)
			or not value.net_layout_catalog is String
			or value.net_layout_catalog != StadiumNetItems.signature()
		)
	):
		return null
	if (
		value.version >= 14
		and (
			not value.light_catalog is String
			or value.light_catalog != StadiumPurchases.signature(StadiumPurchases.LIGHT_VERSION)
			or not value.light_layout_catalog is String
			or value.light_layout_catalog != StadiumLightItems.signature()
		)
	):
		return null
	if (
		value.version >= 15
		and (
			not value.infield_catalog is String
			or value.infield_catalog != StadiumInfieldStyles.signature()
			or not value.infield_layout_catalog is String
			or value.infield_layout_catalog != StadiumInfieldStyles.appearance_signature()
		)
	):
		return null
	if (
		value.version >= 16
		and (
			not value.wall_catalog is String
			or value.wall_catalog != StadiumWallItems.price_signature()
			or not value.wall_layout_catalog is String
			or value.wall_layout_catalog != StadiumWallItems.signature()
		)
	):
		return null
	if (
		value.version >= 17
		and (
			not value.surface_catalog is String
			or value.surface_catalog != StadiumSurfaceProgression.signature()
			or not StadiumSurfaceProgression.valid_origin(value.surface_origin)
			or not value.surface_layout_catalog is String
			or value.surface_layout_catalog != StadiumSurfaceLayout.signature()
		)
	):
		return null
	if (
		value.version >= 18
		and (
			not value.wall_piece_catalog is String
			or value.wall_piece_catalog != StadiumWallPieceOwnership.signature()
		)
	):
		return null
	if (
		value.version >= 19
		and (
			not value.advanced_layout_catalog is String
			or value.advanced_layout_catalog != StadiumAdvancedWallLayout.signature()
		)
	):
		return null
	if (
		value.version >= 20
		and (
			not value.scoreboard_catalog is String
			or value.scoreboard_catalog != StadiumScoreboardPurchases.signature()
		)
	):
		return null
	if (
		value.version >= 21
		and (
			not value.scoreboard_layout_catalog is String
			or value.scoreboard_layout_catalog != StadiumScoreboardLayout.signature()
		)
	):
		return null
	if (
		value.version >= 22
		and (
			not value.mounted_scoreboard_layout_catalog is String
			or value.mounted_scoreboard_layout_catalog != StadiumMountedScoreboardLayout.signature()
		)
	):
		return null
	if (
		value.version >= 23
		and (
			not value.pool_catalog is String
			or value.pool_catalog != StadiumPurchases.signature(StadiumPurchases.POOL_VERSION)
			or not value.pool_layout_catalog is String
			or value.pool_layout_catalog != StadiumPoolOwnedLayout.signature()
		)
	):
		return null
	return ClubAssetLedger._restore_data_stage_4(value, seed_value, credits, progress, championships)
# gdlint: enable=max-returns

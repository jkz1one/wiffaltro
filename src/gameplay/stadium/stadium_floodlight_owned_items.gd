class_name StadiumFloodlightOwnedItems
extends RefCounted
## Exact whole-copy lighting alternatives. Completeness alone is not night qualification.

const VERSION: int = 1
const PRICE_VERSION: int = 17
const LAYOUT_VERSION: int = 25
const FAMILY: String = "reference-owned-floodlights-v25"
const PRICES: Dictionary = {"ST-038": [520, 120], "ST-076": [750, 180]}
const PROFILES: Dictionary = {
	"CLUB4-LOW": {"item": "ST-038", "count": 4, "tier": "club", "preset": "LIGHT-CLUB-4X038-v1"},
	"MOGUL6-STANDARD":
	{"item": "ST-038", "count": 6, "tier": "mogul", "preset": "LIGHT-MOGUL-6X038-v1"},
	"MOGUL4-PREMIUM":
	{"item": "ST-076", "count": 4, "tier": "mogul", "preset": "LIGHT-MOGUL-4X076-v1"}
}

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_floodlight_owned_items_operations_1.gd"
)


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if (
		StadiumLandscapeOwnedItems.is_family(layout)
		or (
			StadiumLiveFurnishingItems.is_family(layout)
			or (
				StadiumSmallYardSceneryItems.is_family(layout)
				or (
					StadiumMoldedSeatItems.is_family(layout)
					or (
						StadiumGroundBoxItems.is_family(layout)
						or (
							StadiumPracticeFacilityItems.is_family(layout)
							or (
								StadiumTreehouseItems.is_family(layout)
								or (
									StadiumLandmarkItems.is_family(layout)
									or (
										StadiumOutfieldBleacherItems.is_family(layout)
										or (
											StadiumRisingAppleItems.is_family(layout)
											or (
												StadiumWallTopTerraceItems.is_family(layout)
												or (
													StadiumPlayerTunnelItems.is_family(layout)
													or (
														StadiumMountedDisplayItems.is_family(layout)
														or (
															StadiumStringLightItems.is_family(
																layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						layout
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumReceiverOwnedItems.upgrade(layout, access)
	if not StadiumReceiverOwnedItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["floodlight_profile"] = ""
	result["floodlights"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumLandscapeOwnedItems.is_family(layout)
		or (
			StadiumLiveFurnishingItems.is_family(layout)
			or (
				StadiumSmallYardSceneryItems.is_family(layout)
				or (
					StadiumMoldedSeatItems.is_family(layout)
					or (
						StadiumGroundBoxItems.is_family(layout)
						or (
							StadiumPracticeFacilityItems.is_family(layout)
							or (
								StadiumTreehouseItems.is_family(layout)
								or (
									StadiumLandmarkItems.is_family(layout)
									or (
										StadiumOutfieldBleacherItems.is_family(layout)
										or (
											StadiumRisingAppleItems.is_family(layout)
											or (
												StadiumWallTopTerraceItems.is_family(layout)
												or (
													StadiumPlayerTunnelItems.is_family(layout)
													or (
														StadiumMountedDisplayItems.is_family(layout)
														or (
															StadiumStringLightItems.is_family(
																layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						layout
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return base(StadiumLandscapeOwnedItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumReceiverOwnedItems.LAYOUT_VERSION
	result.family = StadiumReceiverOwnedItems.FAMILY
	result.erase("floodlight_profile")
	result.erase("floodlights")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumLandscapeOwnedItems.is_family(layout)
		or (
			StadiumLiveFurnishingItems.is_family(layout)
			or (
				StadiumSmallYardSceneryItems.is_family(layout)
				or (
					StadiumMoldedSeatItems.is_family(layout)
					or (
						StadiumGroundBoxItems.is_family(layout)
						or (
							StadiumPracticeFacilityItems.is_family(layout)
							or (
								StadiumTreehouseItems.is_family(layout)
								or (
									StadiumLandmarkItems.is_family(layout)
									or (
										StadiumOutfieldBleacherItems.is_family(layout)
										or (
											StadiumRisingAppleItems.is_family(layout)
											or (
												StadiumWallTopTerraceItems.is_family(layout)
												or (
													StadiumPlayerTunnelItems.is_family(layout)
													or (
														StadiumMountedDisplayItems.is_family(layout)
														or (
															StadiumStringLightItems.is_family(
																layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						layout
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return StadiumLandscapeOwnedItems.with_base(layout, original)
	if not is_family(layout):
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumReceiverOwnedItems.is_family(original)
		else StadiumReceiverOwnedItems.with_base(base(layout), original)
	)
	if not StadiumReceiverOwnedItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["floodlight_profile"] = layout.floodlight_profile
	result["floodlights"] = layout.floodlights.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumReceiverOwnedItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumReceiverOwnedItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumReceiverOwnedItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumReceiverOwnedItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 24,
				"profiles": PROFILES,
				"models":
				[StadiumFourHeadTowerModels.VERSION, StadiumPremiumLightTowerModels.VERSION],
				"club_sites": StadiumNpcAc02PublicLightSites.VERSION,
				"complete_copy_alternatives": true,
				"night": "measured-sparse-and-club-two-lower-canopies"
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	if (
		StadiumLandscapeOwnedItems.is_family(layout)
		or (
			StadiumLiveFurnishingItems.is_family(layout)
			or (
				StadiumSmallYardSceneryItems.is_family(layout)
				or (
					StadiumMoldedSeatItems.is_family(layout)
					or (
						StadiumGroundBoxItems.is_family(layout)
						or (
							StadiumPracticeFacilityItems.is_family(layout)
							or (
								StadiumTreehouseItems.is_family(layout)
								or (
									StadiumLandmarkItems.is_family(layout)
									or (
										StadiumOutfieldBleacherItems.is_family(layout)
										or (
											StadiumRisingAppleItems.is_family(layout)
											or (
												StadiumWallTopTerraceItems.is_family(layout)
												or (
													StadiumPlayerTunnelItems.is_family(layout)
													or (
														StadiumMountedDisplayItems.is_family(layout)
														or (
															StadiumStringLightItems.is_family(
																layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						layout
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return StadiumLandscapeOwnedItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumReceiverOwnedItems.geometry(tier, base(layout)),
				"floodlights": signature()
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func quote(
	stock: StadiumStock, item: String, quantity: int, request: String, progress: Dictionary
) -> Dictionary:
	if stock == null or not PRICES.has(item):
		return ClubAssetLedger._error("This item is not an owned floodlight tower.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The floodlight quote changed; reload before purchasing.")
	return result


static func sites(profile: String) -> Dictionary:
	match profile:
		"CLUB4-LOW":
			return StadiumNpcAc02PublicLightSites.SITES
		"MOGUL6-STANDARD":
			return StadiumFourHeadTowerSites.SITES
		"MOGUL4-PREMIUM":
			return StadiumPremiumLightTowerSites.SITES
	return {}


static func targets(profile: String) -> Dictionary:
	match profile:
		"CLUB4-LOW":
			return StadiumNpcAc02PublicLightSites.TARGETS
		"MOGUL6-STANDARD":
			return StadiumFourHeadTowerSites.TARGETS
		"MOGUL4-PREMIUM":
			return StadiumPremiumLightTowerSites.TARGETS
	return {}


static func row(copy: String, profile: String, site: String) -> Dictionary:
	if not PROFILES.has(profile) or not sites(profile).has(site):
		return {}
	var toward: Vector3 = targets(profile)[site] - sites(profile)[site]
	return {
		"copy": copy,
		"item": PROFILES[profile].item,
		"site": site,
		"position": sites(profile)[site],
		"yaw": rad_to_deg(atan2(toward.x, toward.z)),
		"role": "DECORATIVE_AFTER_TERMINAL",
		"profile": profile
	}


static func bounds(placed: Dictionary) -> AABB:
	var radius: float = (
		StadiumPremiumLightTowerModels.ENVELOPE_RADIUS
		if placed.item == "ST-076"
		else StadiumFourHeadTowerModels.ENVELOPE_RADIUS
	)
	var height: float = (
		StadiumPremiumLightTowerModels.HEIGHT
		if placed.item == "ST-076"
		else StadiumFourHeadTowerModels.HEIGHT
	)
	return AABB(
		placed.position + Vector3(-radius, 0, -radius), Vector3(radius * 2, height, radius * 2)
	)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumLandscapeOwnedItems.is_family(layout)
		or (
			StadiumLiveFurnishingItems.is_family(layout)
			or (
				StadiumSmallYardSceneryItems.is_family(layout)
				or (
					StadiumMoldedSeatItems.is_family(layout)
					or (
						StadiumGroundBoxItems.is_family(layout)
						or (
							StadiumPracticeFacilityItems.is_family(layout)
							or (
								StadiumTreehouseItems.is_family(layout)
								or (
									StadiumLandmarkItems.is_family(layout)
									or (
										StadiumOutfieldBleacherItems.is_family(layout)
										or (
											StadiumRisingAppleItems.is_family(layout)
											or (
												StadiumWallTopTerraceItems.is_family(layout)
												or (
													StadiumPlayerTunnelItems.is_family(layout)
													or (
														StadiumMountedDisplayItems.is_family(layout)
														or (
															StadiumStringLightItems.is_family(
																layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						layout
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return StadiumLandscapeOwnedItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("floodlight_profile") is String
		or not layout.get("floodlights") is Array
		or layout.floodlights.size() > 6
	):
		return StadiumStarterLayout._error("Unknown owned floodlight layout.")
	var result: Dictionary = StadiumReceiverOwnedItems.validate(base(layout), stock, tier)
	if not result.ok:
		return result
	result["floodlight_placements"] = []
	result["floodlight_complete"] = false
	result["floodlight_profile"] = layout.floodlight_profile
	result.night_qualified = false
	if layout.floodlight_profile.is_empty():
		return (
			result
			if layout.floodlights.is_empty()
			else StadiumStarterLayout._error("Choose a named floodlight preset.")
		)
	if not PROFILES.has(layout.floodlight_profile):
		return StadiumStarterLayout._error("This floodlight aim profile is not supported.")
	var preset: Dictionary = PROFILES[layout.floodlight_profile]
	if tier != preset.tier and not (tier == "mogul" and preset.tier == "club"):
		return StadiumStarterLayout._error(
			"The selected floodlight sites need " + preset.tier.capitalize() + " grounds."
		)
	var used: Array[String] = []
	var occupied: Array[String] = []
	for raw: Variant in layout.floodlights:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, ["copy", "item", "site"])
			or not raw.copy is String
			or not raw.item is String
			or not raw.site is String
			or raw.item != preset.item
			or not sites(layout.floodlight_profile).has(raw.site)
			or used.has(raw.copy)
			or occupied.has(raw.site)
			or stock == null
			or not stock.copies.has(raw.copy)
			or stock.copies[raw.copy].item != raw.item
		):
			return StadiumStarterLayout._error(
				"Each fixed floodlight site needs its own matching paid tower copy."
			)
		var placed: Dictionary = row(raw.copy, layout.floodlight_profile, raw.site)
		var envelope: AABB = bounds(placed)
		if not StadiumProperty.contains(tier, envelope):
			return StadiumStarterLayout._error(
				raw.site + " complete tower does not fit this property."
			)
		for other: Dictionary in result.placements:
			if other.copy == raw.copy:
				return StadiumStarterLayout._error("A tower copy cannot occupy two sites.")
			var other_bounds: AABB = StadiumHomeLayout.bounds(other)
			var closest: Vector3 = Vector3(
				clampf(placed.position.x, other_bounds.position.x, other_bounds.end.x),
				0,
				clampf(placed.position.z, other_bounds.position.z, other_bounds.end.z)
			)
			if (
				other_bounds.end.y > 0
				and other_bounds.position.y < envelope.end.y
				and (
					Vector2(closest.x - placed.position.x, closest.z - placed.position.z).length()
					< envelope.size.x / 2
				)
			):
				return StadiumStarterLayout._error(
					raw.site + " conflicts with " + other.site + "; store one placement."
				)
		used.append(raw.copy)
		occupied.append(raw.site)
		result.floodlight_placements.append(placed)
		result.placements.append(placed)
		result.stored.erase(raw.copy)
	result.floodlight_complete = used.size() == int(preset.count)
	return result


static func select_preset(layout: Dictionary, stock: StadiumStock, profile: String) -> Dictionary:
	return Operations1._public_select_preset(layout, stock, profile)


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumLandscapeOwnedItems.is_family(layout)
		or (
			StadiumLiveFurnishingItems.is_family(layout)
			or (
				StadiumSmallYardSceneryItems.is_family(layout)
				or (
					StadiumMoldedSeatItems.is_family(layout)
					or (
						StadiumGroundBoxItems.is_family(layout)
						or (
							StadiumPracticeFacilityItems.is_family(layout)
							or (
								StadiumTreehouseItems.is_family(layout)
								or (
									StadiumLandmarkItems.is_family(layout)
									or (
										StadiumOutfieldBleacherItems.is_family(layout)
										or (
											StadiumRisingAppleItems.is_family(layout)
											or (
												StadiumWallTopTerraceItems.is_family(layout)
												or (
													StadiumPlayerTunnelItems.is_family(layout)
													or (
														StadiumMountedDisplayItems.is_family(layout)
														or (
															StadiumStringLightItems.is_family(
																layout
															)
															or (
																StadiumSalvageCarItems.is_family(
																	layout
																)
																or (
																	(
																		StadiumMasteryBannerItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumWaterfallItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumLightingKitItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumOutfieldPlazaItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					StadiumWaterfallLiveItems
																					. is_family(
																						layout
																					)
																				)
																			)
																		)
																	)
																)
															)
														)
													)
												)
											)
										)
									)
								)
							)
						)
					)
				)
			)
		)
	):
		return StadiumLandscapeOwnedItems.with_base(
			layout, store_copy(StadiumLandscapeOwnedItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result):
		result.floodlights = result.floodlights.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	return Operations1._public_prune(layout)


static func night_profile(entry: Dictionary) -> Dictionary:
	return Operations1._public_night_profile(entry)


static func night_reason(entry: Dictionary) -> String:
	return Operations1._public_night_reason(entry)

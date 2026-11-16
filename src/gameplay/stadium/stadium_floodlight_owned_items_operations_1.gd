extends RefCounted
## Stateless operations for the original StadiumFloodlightOwnedItems script.


static func _public_select_preset(
	layout: Dictionary, stock: StadiumStock, profile: String
) -> Dictionary:
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
			layout,
			StadiumFloodlightOwnedItems.select_preset(
				StadiumLandscapeOwnedItems.base(layout), stock, profile
			)
		)
	if (
		not StadiumFloodlightOwnedItems.is_family(layout)
		or stock == null
		or (not profile.is_empty() and not StadiumFloodlightOwnedItems.PROFILES.has(profile))
	):
		return layout.duplicate(true)
	var result: Dictionary = layout.duplicate(true)
	result.floodlight_profile = profile
	result.floodlights = []
	if profile.is_empty():
		return result
	var copies: Array[String] = []
	for copy: String in stock.copies:
		if stock.copies[copy].item == StadiumFloodlightOwnedItems.PROFILES[profile].item:
			copies.append(copy)
	copies.sort()
	var selected_sites: Array = StadiumFloodlightOwnedItems.sites(profile).keys()
	selected_sites.sort()
	for index in range(mini(copies.size(), selected_sites.size())):
		result.floodlights.append(
			{
				"copy": copies[index],
				"item": StadiumFloodlightOwnedItems.PROFILES[profile].item,
				"site": selected_sites[index]
			}
		)
	return result


static func _public_prune(layout: Dictionary) -> Dictionary:
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
		return StadiumLandscapeOwnedItems.prune(layout)
	return StadiumFloodlightOwnedItems.with_base(
		layout, StadiumReceiverOwnedItems.prune(StadiumFloodlightOwnedItems.base(layout))
	)


static func _public_night_profile(entry: Dictionary) -> Dictionary:
	if (
		not entry.get("layout") is Dictionary
		or not StadiumFloodlightOwnedItems.is_family(entry.layout)
		or not entry.get("tier") is String
	):
		return {}
	var stock: StadiumStock = StadiumLayoutSnapshot.ownership(entry)
	var checked: Dictionary = StadiumFloodlightOwnedItems.validate(entry.layout, stock, entry.tier)
	if not checked.ok or not checked.floodlight_complete or not entry.layout.lights.is_empty():
		return {}
	var layout: Dictionary = entry.layout
	if (
		not ClubCareer.same(
			layout.surface, {"foundation": "grass", "condition": "prepared", "height": "short"}
		)
		or not ClubCareer.same(layout.styles, {"grass": "ST-063b", "line": ""})
		or layout.ground != "ST-063i"
		or not ClubCareer.same(layout.walls, StadiumWallLayout.empty())
	):
		return {}
	var lower: Array[String] = []
	var roofs: Array[String] = []
	for placed: Dictionary in checked.placements:
		if StadiumFloodlightOwnedItems.PRICES.has(placed.item):
			continue
		if layout.floodlight_profile != "CLUB4-LOW":
			return {}
		if placed.item == "ST-029" and placed.site in ["BASE-L2", "BASE-R2"]:
			lower.append(placed.site)
		elif (
			placed.item == "ST-053"
			and placed.get("roof_state") == "lower"
			and placed.site in ["BASE-L2", "BASE-R2"]
		):
			roofs.append(placed.site)
		else:
			return {}
	lower.sort()
	roofs.sort()
	if not lower.is_empty() or not roofs.is_empty():
		if lower != ["BASE-L2", "BASE-R2"] or roofs != ["BASE-L2", "BASE-R2"]:
			return {}
	return {
		"profile": layout.floodlight_profile,
		"placements": checked.floodlight_placements,
		"club_lower_canopies": not roofs.is_empty()
	}


static func _public_night_reason(entry: Dictionary) -> String:
	return (
		""
		if not StadiumFloodlightOwnedItems.night_profile(entry).is_empty()
		else (
			"Night needs one complete current owned preset and its measured sparse "
			+ "layout. Only Club4-LOW also supports the two lower BASE-L2/R2 "
			+ "canopies; upper, tall, mixed and other obstructing layouts remain "
			+ "daylight-only."
		)
	)

class_name StadiumHomeLayout
extends RefCounted
## Version-one starter grammar stays frozen; version two adds outside-play seating.

const VERSION: int = 2


static func signature() -> String:
	var sites: Dictionary = {}
	for id: String in StadiumSeatingLayout.SITES:
		var row: Dictionary = StadiumSeatingLayout.SITES[id]
		sites[id] = {
			"position": [row.position.x, row.position.y, row.position.z],
			"side": row.side,
			"item": row.item,
			"tier": row.tier
		}
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"models": StadiumSeatingModels.VERSION,
				"seating": StadiumSeatingLayout.VERSION,
				"sites": sites
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func upgrade(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if SeasonOwnership._whole(result.get("version"), 1, 1):
		result.version = VERSION
		result.family = "reference-seating-v2"
		result["seating"] = []
	return result


static func geometry(tier: String, layout: Dictionary) -> String:
	if (
		StadiumReceiverOwnedItems.is_family(layout)
		or (
			StadiumFloodlightOwnedItems.is_family(layout)
			or (
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
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumWaterfallItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumLightingKitItems
																						. is_family(
																							layout
																						)
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
			)
		)
	):
		return StadiumReceiverOwnedItems.geometry(tier, layout)
	if StadiumBoundaryItems.is_family(layout):
		return StadiumBoundaryItems.geometry(tier, layout)
	if StadiumFacilityItems.is_family(layout):
		return StadiumFacilityItems.geometry(tier, layout)
	if StadiumRoofItems.is_family(layout):
		return StadiumRoofItems.geometry(tier, layout)
	if StadiumStraightItems.is_family(layout):
		return StadiumStraightItems.geometry(tier, layout)
	if StadiumGroundPropsItems.is_family(layout):
		return StadiumGroundPropsItems.geometry(tier, layout)
	if StadiumFlagItems.is_family(layout):
		return StadiumFlagItems.geometry(tier, layout)
	if SeasonOwnership._whole(layout.get("version"), 12, 12):
		return (
			(geometry(tier, {"version": 11}) + ":" + StadiumSurfaceLayout.signature()).sha256_text()
		)
	if SeasonOwnership._whole(layout.get("version"), 11, 11):
		return (geometry(tier, {"version": 10}) + ":" + StadiumWallItems.signature()).sha256_text()
	if SeasonOwnership._whole(layout.get("version"), 10, 10):
		return (
			(geometry(tier, {"version": 9}) + ":" + StadiumInfieldStyles.appearance_signature())
			. sha256_text()
		)
	if SeasonOwnership._whole(layout.get("version"), 9, 9):
		return (geometry(tier, {"version": 8}) + ":" + StadiumLightItems.signature()).sha256_text()
	if SeasonOwnership._whole(layout.get("version"), 8, 8):
		return (geometry(tier, {"version": 7}) + ":" + StadiumNetItems.signature()).sha256_text()
	if SeasonOwnership._whole(layout.get("version"), 7, 7):
		return (
			(_prior_geometry(tier, {"version": 6}) + ":" + StadiumTargetItems.signature())
			. sha256_text()
		)
	return _prior_geometry(tier, layout)


static func _prior_geometry(tier: String, layout: Dictionary) -> String:
	var base: String = StadiumProperty.signature(tier)
	if SeasonOwnership._whole(layout.get("version"), 6, 6):
		return (
			(
				base
				+ ":"
				+ signature()
				+ ":"
				+ StadiumFieldStyles.appearance_signature()
				+ ":"
				+ StadiumClubItems.signature()
				+ ":"
				+ StadiumGroundStyles.appearance_signature()
				+ ":"
				+ StadiumBleacherItems.signature()
			)
			. sha256_text()
		)
	if SeasonOwnership._whole(layout.get("version"), 5, 5):
		return (
			(
				base
				+ ":"
				+ signature()
				+ ":"
				+ StadiumFieldStyles.appearance_signature()
				+ ":"
				+ StadiumClubItems.signature()
				+ ":"
				+ StadiumGroundStyles.appearance_signature()
			)
			. sha256_text()
		)
	if SeasonOwnership._whole(layout.get("version"), 4, 4):
		return (
			(
				base
				+ ":"
				+ signature()
				+ ":"
				+ StadiumFieldStyles.appearance_signature()
				+ ":"
				+ StadiumClubItems.signature()
			)
			. sha256_text()
		)
	if SeasonOwnership._whole(layout.get("version"), 3, 3):
		return (
			(base + ":" + signature() + ":" + StadiumFieldStyles.appearance_signature())
			. sha256_text()
		)
	if SeasonOwnership._whole(layout.get("version"), VERSION, VERSION):
		return (base + ":" + signature()).sha256_text()
	return base


static func validate(layout: Variant, stock: StadiumStock, tier: String = "backyard") -> Dictionary:
	if (
		StadiumReceiverOwnedItems.is_family(layout)
		or (
			StadiumFloodlightOwnedItems.is_family(layout)
			or (
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
															StadiumPlayerTunnelItems.is_family(
																layout
															)
															or (
																(
																	StadiumMountedDisplayItems
																	. is_family(layout)
																)
																or (
																	(
																		StadiumStringLightItems
																		. is_family(layout)
																	)
																	or (
																		(
																			StadiumSalvageCarItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumMasteryBannerItems
																				. is_family(layout)
																			)
																			or (
																				(
																					StadiumWaterfallItems
																					. is_family(
																						layout
																					)
																				)
																				or (
																					(
																						StadiumLightingKitItems
																						. is_family(
																							layout
																						)
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
			)
		)
	):
		return terrain_admission(
			layout, tier, StadiumReceiverOwnedItems.validate(layout, stock, tier)
		)
	if StadiumBoundaryItems.is_family(layout):
		return terrain_admission(layout, tier, StadiumBoundaryItems.validate(layout, stock, tier))
	if StadiumFacilityItems.is_family(layout):
		return terrain_admission(layout, tier, StadiumFacilityItems.validate(layout, stock, tier))
	if StadiumRoofItems.is_family(layout):
		return terrain_admission(layout, tier, StadiumRoofItems.validate(layout, stock, tier))
	if StadiumStraightItems.is_family(layout):
		return terrain_admission(layout, tier, StadiumStraightItems.validate(layout, stock, tier))
	if StadiumGroundPropsItems.is_family(layout):
		return terrain_admission(
			layout, tier, StadiumGroundPropsItems.validate(layout, stock, tier)
		)
	if StadiumFlagItems.is_family(layout):
		return terrain_admission(layout, tier, StadiumFlagItems.validate(layout, stock, tier))
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 12, 12):
		return StadiumSurfaceLayout.validate(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 11, 11):
		return StadiumWallItems.validate(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 10, 10):
		return StadiumInfieldStyles.validate(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 9, 9):
		return StadiumLightItems.validate(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 8, 8):
		return StadiumNetItems.validate(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 7, 7):
		return _target(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 6, 6):
		return _bleachers(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 5, 5):
		return _ground(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 4, 4):
		return _displays(layout, stock, tier)
	if layout is Dictionary and SeasonOwnership._whole(layout.get("version"), 3, 3):
		return _styles(layout, stock, tier)
	if (
		not layout is Dictionary
		or not SeasonOwnership._whole(layout.get("version"), VERSION, VERSION)
	):
		return StadiumStarterLayout.validate(layout, stock)
	if (
		not SeasonOwnership._keys(layout, ["version", "family", "receiver", "obstacles", "seating"])
		or not layout.family is String
		or layout.family != "reference-seating-v2"
	):
		return StadiumStarterLayout._error("Unknown seating layout fields or field family.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("seating")
	base.version = 1
	base.family = "reference-starter-v1"
	var result: Dictionary = StadiumStarterLayout.validate(base, stock)
	if not result.ok:
		return result
	var seating: Dictionary = StadiumSeatingLayout.validate(layout.seating, stock, tier)
	if not seating.ok:
		return seating
	for row: Dictionary in seating.placements:
		result.placements.append(row)
		result.stored.erase(row.copy)
	return result


static func preview(
	before: Dictionary, after: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	var current: Dictionary = validate(before, stock, tier)
	var candidate: Dictionary = validate(after, stock, tier)
	if not current.ok:
		return current
	if not candidate.ok:
		return candidate
	var displaced: Array[String] = []
	var placed: Array = current.placements.duplicate()
	placed.append_array(current.get("wall_panels", []))
	for row: Dictionary in placed:
		if candidate.stored.has(row.copy):
			displaced.append(row.copy)
	displaced.sort()
	candidate["displaced"] = displaced
	candidate["cost"] = 0
	return candidate


static func bounds(placement: Dictionary) -> AABB:
	if placement.item == "ST-046" and placement.site == StadiumWaterfallLiveSites.SITE:
		return StadiumWaterfallLiveItems.bounds(placement)
	if placement.item == "ST-112" or placement.has("plaza_recipe"):
		return StadiumOutfieldPlazaItems.bounds(placement)
	if placement.item == "ST-111":
		return StadiumLightingKitItems.bounds(placement)
	if placement.item == "ST-046":
		return StadiumWaterfallItems.bounds(placement)
	if placement.item == "ST-067":
		return StadiumMasteryBannerItems.bounds(placement)
	if placement.item == "ST-005":
		return (
			Transform3D(Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position)
			* AABB(Vector3(-1.15, 0, -2.2), Vector3(2.3, 1.8, 4.4))
		)
	if StadiumStringLightItems.PRICES.has(placement.item):
		return StadiumStringLightItems.bounds(placement)
	if StadiumMountedDisplayItems.PRICES.has(placement.item):
		return StadiumMountedDisplayItems.bounds(placement)
	if StadiumPlayerTunnelItems.PRICES.has(placement.item):
		return StadiumPlayerTunnelItems.bounds(placement)
	if StadiumWallTopTerraceItems.PRICES.has(placement.item):
		return StadiumWallTopTerraceItems.bounds(placement)
	if StadiumRisingAppleItems.PRICES.has(placement.item):
		return StadiumRisingAppleItems.bounds(placement)
	if StadiumOutfieldBleacherItems.PRICES.has(placement.item):
		return StadiumOutfieldBleacherItems.bounds(placement)
	if StadiumLandmarkItems.PRICES.has(placement.item):
		return StadiumLandmarkItems.bounds(placement)
	if StadiumTreehouseItems.PRICES.has(placement.item):
		return StadiumTreehouseItems.bounds(placement)
	if StadiumPracticeFacilityItems.PRICES.has(placement.item):
		return StadiumPracticeFacilityItems.bounds(placement)
	if StadiumGroundBoxItems.PRICES.has(placement.item):
		return StadiumGroundBoxItems.bounds(placement)
	if StadiumMoldedSeatItems.PRICES.has(placement.item):
		return StadiumMoldedSeatItems.bounds(placement)
	if (
		placement.get("site", "") in StadiumSmallYardSceneryItems.SITES
		and placement.item in StadiumSmallYardSceneryItems.ITEMS
	):
		return StadiumSmallYardSceneryItems.bounds(placement)
	if StadiumLiveFurnishingItems.PRICES.has(placement.item):
		return StadiumLiveFurnishingItems.bounds(placement)
	if StadiumLandscapeOwnedItems.PRICES.has(placement.item):
		return StadiumLandscapeOwnedItems.bounds(placement)
	if StadiumFloodlightOwnedItems.PRICES.has(placement.item):
		return StadiumFloodlightOwnedItems.bounds(placement)
	if StadiumReceiverOwnedItems.PRICES.has(placement.item):
		return StadiumReceiverOwnedItems.bounds(placement)
	if StadiumBoundaryItems.PRICES.has(placement.item):
		return StadiumBoundaryItems.bounds(placement)
	if StadiumFacilityItems.PRICES.has(placement.item):
		return StadiumFacilityItems.bounds(placement)
	if StadiumRoofItems.PRICES.has(placement.item):
		return StadiumRoofItems.bounds(placement)
	if (
		StadiumStraightItems.HOSTS.has(placement.item)
		or StadiumStraightItems.MOUNTS.has(placement.item)
	):
		return StadiumStraightItems.bounds(placement)
	if StadiumGroundPropsItems.PRICES.has(placement.item):
		return StadiumGroundPropsItems.bounds(placement)
	if placement.item == "ST-043":
		return (
			Transform3D(Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position)
			* StadiumFlagModels.ENVELOPE
		)
	if placement.item == "ST-037":
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position
		)
		return pose * StadiumYardLightModels.ENVELOPE
	if placement.item == "ST-025":
		var box: AABB = StadiumNetModels.ENVELOPE
		box.position += placement.position
		return box
	if placement.item == "ST-026":
		var box: AABB = StadiumTargetModels.ENVELOPE
		box.position += placement.position
		return box
	if StadiumPurchases.BLEACHERS.has(placement.item):
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position
		)
		return pose * StadiumBleacherModels.envelope(placement.item)
	if StadiumPurchases.DISPLAYS.has(placement.item):
		var pose: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position
		)
		return pose * StadiumClubSites.envelope(placement.item)
	if StadiumPurchases.SEATING.has(placement.item):
		var transform: Transform3D = Transform3D(
			Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position
		)
		return transform * StadiumSeatingLayout.envelope(placement.item)
	return StadiumProperty.layout_bounds(placement.item, placement.position)


static func _styles(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout, ["version", "family", "receiver", "obstacles", "seating", "styles"]
		)
		or not layout.family is String
		or layout.family != "reference-styles-v3"
		or not StadiumFieldStyles.valid(layout.styles, stock)
	):
		return StadiumStarterLayout._error("Select exact owned styles in their authored channels.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("styles")
	base.version = 2
	base.family = "reference-seating-v2"
	return validate(base, stock, tier)


static func _displays(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout, ["version", "family", "receiver", "obstacles", "seating", "styles", "displays"]
		)
		or not layout.family is String
		or layout.family != "reference-club-displays-v4"
	):
		return StadiumStarterLayout._error("Unknown club-display layout fields or family.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("displays")
	base.version = 3
	base.family = "reference-styles-v3"
	var result: Dictionary = validate(base, stock, tier)
	if not result.ok:
		return result
	var displays: Dictionary = StadiumClubSites.validate(layout.displays, stock, tier)
	if not displays.ok:
		return displays
	for row: Dictionary in displays.placements:
		result.placements.append(row)
		result.stored.erase(row.copy)
	return result


static func _ground(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout,
			[
				"version",
				"family",
				"receiver",
				"obstacles",
				"seating",
				"styles",
				"displays",
				"ground"
			]
		)
		or not layout.family is String
		or layout.family != "reference-ground-v5"
		or not StadiumGroundStyles.valid(layout.ground, stock)
	):
		return StadiumStarterLayout._error(
			"Select one exact owned ground treatment or the template."
		)
	var base: Dictionary = layout.duplicate(true)
	base.erase("ground")
	base.version = 4
	base.family = "reference-club-displays-v4"
	return validate(base, stock, tier)


static func _bleachers(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout,
			[
				"version",
				"family",
				"receiver",
				"obstacles",
				"seating",
				"styles",
				"displays",
				"ground",
				"bleachers"
			]
		)
		or not layout.family is String
		or layout.family != "reference-bleachers-v6"
	):
		return StadiumStarterLayout._error("Unknown larger-bleacher layout fields or family.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("bleachers")
	base.version = 5
	base.family = "reference-ground-v5"
	var result: Dictionary = validate(base, stock, tier)
	if not result.ok:
		return result
	var checked: Dictionary = StadiumBleacherSites.validate(layout.bleachers, stock, tier)
	if not checked.ok:
		return checked
	for placement: Dictionary in checked.placements:
		var side: String = StadiumSeatingLayout.SITES[placement.site].side
		for row: Dictionary in layout.seating:
			if StadiumSeatingLayout.SITES[row.site].side == side:
				return StadiumStarterLayout._error(
					"Store same-side seating before placing this bleacher."
				)
		result.placements.append(placement)
		result.stored.erase(placement.copy)
	return result


static func _target(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not SeasonOwnership._keys(
			layout,
			[
				"version",
				"family",
				"receiver",
				"obstacles",
				"seating",
				"styles",
				"displays",
				"ground",
				"bleachers",
				"target"
			]
		)
		or not layout.family is String
		or layout.family != "reference-target-v7"
		or not layout.target is String
	):
		return StadiumStarterLayout._error("Unknown target-only receiver layout.")
	var base: Dictionary = layout.duplicate(true)
	base.erase("target")
	base.version = 6
	base.family = "reference-bleachers-v6"
	var result: Dictionary = validate(base, stock, tier)
	if not result.ok or layout.target.is_empty():
		return result
	if (
		not layout.receiver.is_empty()
		or not stock.copies.has(layout.target)
		or stock.copies[layout.target].item != "ST-026"
	):
		return StadiumStarterLayout._error(
			"Install one owned target or one backstop chair, never both."
		)
	result.placements.append(
		{
			"copy": layout.target,
			"item": "ST-026",
			"site": "RECEIVER-PRIMARY",
			"position": StadiumTargetModels.POSITION,
			"yaw": 0,
			"role": "RECEIVER_CONTAINMENT_FOUL"
		}
	)
	result.stored.erase(layout.target)
	return result


static func terrain_admission(layout: Variant, tier: String, checked: Dictionary) -> Dictionary:
	# Only newly admitted larger terrain properties get the aggregate safeguard.
	# Old Backyard saves and every flat family's behavior remain unchanged.
	if (
		not checked.ok
		or tier == "backyard"
		or not (
			SeasonOwnership._whole(layout.get("version"), 17, 17)
			or SeasonOwnership._whole(layout.get("base_version"), 17, 17)
		)
	):
		return checked
	if (
		int(checked.get("live_units", 0)) != 0
		or not checked.get("wall_panels", []).is_empty()
		or not checked.get("advanced_panels", []).is_empty()
	):
		return StadiumStarterLayout._error(
			"Larger physical dirt properties retain daylight, no live obstacles and no paid walls."
		)
	for placed: Dictionary in checked.placements:
		if placed.role == "LIVE_RICOCHET":
			return StadiumStarterLayout._error(
				"Store live obstacles before using larger physical dirt properties."
			)
	checked.night_qualified = false
	return checked

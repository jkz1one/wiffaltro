class_name StadiumReceiverOwnedItems
extends RefCounted
## One separately owned catching assembly, with an empty/default, target or chair primary.

const VERSION: int = 1
const PRICE_VERSION: int = 16
const LAYOUT_VERSION: int = 24
const FAMILY: String = "reference-owned-receivers-v24"
const PRICES: Dictionary = {"ST-072": [470, 140], "ST-073": [480, 130]}
const RESERVE: AABB = AABB(Vector3(-5.25, 0, -5.25), Vector3(10.5, 7, 4.75))


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if (
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
														StadiumPlayerTunnelItems.is_family(layout)
														or (
															StadiumMountedDisplayItems.is_family(
																layout
															)
															or (
																StadiumStringLightItems.is_family(
																	layout
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
																				. is_family(layout)
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
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumBoundaryItems.upgrade(layout, access)
	if not StadiumBoundaryItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["catcher"] = ""
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
														StadiumPlayerTunnelItems.is_family(layout)
														or (
															StadiumMountedDisplayItems.is_family(
																layout
															)
															or (
																StadiumStringLightItems.is_family(
																	layout
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
																				. is_family(layout)
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
	):
		return base(StadiumFloodlightOwnedItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumBoundaryItems.LAYOUT_VERSION
	result.family = StadiumBoundaryItems.FAMILY
	result.erase("catcher")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
														StadiumPlayerTunnelItems.is_family(layout)
														or (
															StadiumMountedDisplayItems.is_family(
																layout
															)
															or (
																StadiumStringLightItems.is_family(
																	layout
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
																				. is_family(layout)
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
	):
		return StadiumFloodlightOwnedItems.with_base(layout, original)
	if not is_family(layout):
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumBoundaryItems.is_family(original)
		else StadiumBoundaryItems.with_base(base(layout), original)
	)
	if not StadiumBoundaryItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["catcher"] = layout.catcher
	# Selecting a legacy portable net explicitly stores the separate catching assembly.
	if not String(result.get("net", "")).is_empty():
		result.catcher = ""
	return result


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumBoundaryItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumBoundaryItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumBoundaryItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumBoundaryItems.graph_for(base(layout))


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 23,
				"models": StadiumReceiverOwnedModels.VERSION,
				"primaries": ["default", "ST-026", "ST-079"],
				"cage_front_center": 2.2 + 1.2 * tan(deg_to_rad(42.0)),
				"cage_pose": [0, 0, -2.65],
				"net_version": StadiumReceiverNetModels.VERSION,
				"terminal": "receiver-foul-no-later-catch"
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	if (
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
														StadiumPlayerTunnelItems.is_family(layout)
														or (
															StadiumMountedDisplayItems.is_family(
																layout
															)
															or (
																StadiumStringLightItems.is_family(
																	layout
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
																				. is_family(layout)
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
	):
		return StadiumFloodlightOwnedItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{"base": StadiumBoundaryItems.geometry(tier, base(layout)), "receiver": signature()},
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
		return ClubAssetLedger._error("This item is not in the owned receiver catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The receiver quote changed; reload before purchasing.")
	return result


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
														StadiumPlayerTunnelItems.is_family(layout)
														or (
															StadiumMountedDisplayItems.is_family(
																layout
															)
															or (
																StadiumStringLightItems.is_family(
																	layout
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
																				. is_family(layout)
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
	):
		return StadiumFloodlightOwnedItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("catcher") is String
	):
		return StadiumStarterLayout._error("Unknown owned receiver layout.")
	var enclosed: Dictionary = base(layout)
	var result: Dictionary = StadiumBoundaryItems.validate(enclosed, stock, tier)
	if not result.ok:
		return result
	result["receiver_placements"] = []
	if layout.catcher.is_empty():
		return result
	if (
		not String(layout.get("net", "")).is_empty()
		or stock == null
		or not stock.copies.has(layout.catcher)
	):
		return StadiumStarterLayout._error("Choose one exact owned catching assembly.")
	var item: String = stock.copies[layout.catcher].item
	if not PRICES.has(item):
		return StadiumStarterLayout._error("This copy is not a cage or tall stadium net.")
	if item == "ST-073" and tier not in ["club", "mogul"]:
		return StadiumStarterLayout._error("The tall stadium net requires Club grounds.")
	var row: Dictionary = {
		"copy": layout.catcher,
		"item": item,
		"site": "RECEIVER-CATCH",
		"position": StadiumReceiverOwnedModels.position(item),
		"yaw": 0.0,
		"role": "RECEIVER_CONTAINMENT_FOUL"
	}
	if not StadiumProperty.contains(tier, bounds(row)):
		return StadiumStarterLayout._error(
			"The complete receiver and supports do not fit this property."
		)
	for placed: Dictionary in result.placements:
		if placed.copy == row.copy:
			return StadiumStarterLayout._error("One copy cannot occupy two receiver sites.")
		if (
			placed.item not in ["ST-026", "ST-079"]
			and RESERVE.intersects(StadiumHomeLayout.bounds(placed))
		):
			return StadiumStarterLayout._error(
				"The receiver assembly well must stay clear of other owned objects."
			)
	result.placements.append(row)
	result.receiver_placements.append(row)
	result.stored.erase(row.copy)
	return result


static func bounds(row: Dictionary) -> AABB:
	var pose: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position)
	return pose * StadiumReceiverOwnedModels.envelope(row.item)


static func select(layout: Dictionary, stock: StadiumStock, copy: String) -> Dictionary:
	if (
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
														StadiumPlayerTunnelItems.is_family(layout)
														or (
															StadiumMountedDisplayItems.is_family(
																layout
															)
															or (
																StadiumStringLightItems.is_family(
																	layout
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
																				. is_family(layout)
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
	):
		return StadiumFloodlightOwnedItems.with_base(
			layout, select(StadiumFloodlightOwnedItems.base(layout), stock, copy)
		)
	if (
		not is_family(layout)
		or stock == null
		or (
			not copy.is_empty()
			and (not stock.copies.has(copy) or not PRICES.has(stock.copies[copy].item))
		)
	):
		return layout.duplicate(true)
	var result: Dictionary = layout.duplicate(true)
	result.catcher = copy
	if not copy.is_empty():
		result.net = ""
	return result


static func prune(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumBoundaryItems.prune(base(layout)))

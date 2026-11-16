class_name StadiumLandscapeOwnedItems
extends RefCounted
## Exact paid, off-field landscape copies. Existing field, ownership and lighting survive unchanged.

const VERSION: int = 1
const PRICE_VERSION: int = 18
const LAYOUT_VERSION: int = 26
const FAMILY: String = "reference-owned-landscape-v26"
const PRICES: Dictionary = {
	"ST-013": [260, 80], "ST-014": [200, 45], "ST-018": [720, 220], "ST-019": [350, 100]
}
const FIELDS: Array[String] = ["copy", "item", "site", "yaw"]
const SITES: Dictionary = {
	"TREE-L": {"items": ["ST-013"], "position": Vector3(-21.5, 0, 28)},
	"TREE-R": {"items": ["ST-013"], "position": Vector3(21.5, 0, 28)},
	"HEDGE-L1": {"items": ["ST-014"], "position": Vector3(-13, 0, 27)},
	"HEDGE-L2": {"items": ["ST-014"], "position": Vector3(-15, 0, 27)},
	"HEDGE-L3": {"items": ["ST-014"], "position": Vector3(-17, 0, 27)},
	"HEDGE-R1": {"items": ["ST-014"], "position": Vector3(13, 0, 27)},
	"HEDGE-R2": {"items": ["ST-014"], "position": Vector3(15, 0, 27)},
	"HEDGE-R3": {"items": ["ST-014"], "position": Vector3(17, 0, 27)},
	"LAND-L": {"items": ["ST-018", "ST-019"], "position": Vector3(-29, 0, 26.25)},
	"LAND-R": {"items": ["ST-018", "ST-019"], "position": Vector3(29, 0, 25.75)}
}
const EPS: float = 0.0001

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_landscape_owned_items_operations_1.gd"
)


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if (
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
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
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
	var result: Dictionary = StadiumFloodlightOwnedItems.upgrade(layout, access)
	if not StadiumFloodlightOwnedItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["landscape"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
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
		return base(StadiumLiveFurnishingItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumFloodlightOwnedItems.LAYOUT_VERSION
	result.family = StadiumFloodlightOwnedItems.FAMILY
	result.erase("landscape")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
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
		return StadiumLiveFurnishingItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("landscape") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumFloodlightOwnedItems.is_family(original)
		else StadiumFloodlightOwnedItems.with_base(base(layout), original)
	)
	if not StadiumFloodlightOwnedItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["landscape"] = layout.landscape.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
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
											or StadiumPlayerTunnelItems.is_family(layout)
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
		return (
			StadiumLiveFurnishingItems.is_terrain(layout)
			or (
				StadiumSmallYardSceneryItems.is_terrain(layout)
				or (
					StadiumMoldedSeatItems.is_terrain(layout)
					or (
						StadiumGroundBoxItems.is_terrain(layout)
						or (
							StadiumPracticeFacilityItems.is_terrain(layout)
							or (
								StadiumTreehouseItems.is_terrain(layout)
								or (
									StadiumLandmarkItems.is_terrain(layout)
									or (
										StadiumOutfieldBleacherItems.is_terrain(layout)
										or (
											StadiumRisingAppleItems.is_terrain(layout)
											or (
												StadiumWallTopTerraceItems.is_terrain(layout)
												or StadiumPlayerTunnelItems.is_terrain(layout)
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
	return is_family(layout) and StadiumFloodlightOwnedItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumFloodlightOwnedItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumFloodlightOwnedItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumFloodlightOwnedItems.graph_for(base(layout))


static func signature() -> String:
	var authored: Dictionary = {}
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		authored[id] = {
			"items": site.items, "position": [site.position.x, site.position.y, site.position.z]
		}
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 25,
				"models": StadiumLandscapeModels.VERSION,
				"sites": authored,
				"tree_radius": 3.5,
				"hedge_reserve": [2, 1, 1.8],
				"land_pocket": [6, 6],
				"rock_yaw": [0, 90, 180, 270],
				"off_field_only": true,
				"night_qualified": false
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
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
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
		return StadiumLiveFurnishingItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumFloodlightOwnedItems.geometry(tier, base(layout)),
				"landscape": signature()
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
		return ClubAssetLedger._error("This item is not in the owned landscape catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The landscaping quote changed; reload before purchasing.")
	return result


static func sites(item: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in SITES:
		if item in SITES[id].items:
			result.append(id)
	result.sort()
	return result


static func _yaw_valid(item: String, yaw: Variant) -> bool:
	return (
		SeasonOwnership._whole(yaw, 0, 270)
		and (int(yaw) in [0, 90, 180, 270] if item == "ST-019" else int(yaw) == 0)
	)


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or site not in sites(item) or not _yaw_valid(item, yaw):
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site].position,
		"yaw": int(yaw),
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func _pose(placed: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(placed.yaw))), placed.position)


static func bounds(placed: Dictionary) -> AABB:
	return _pose(placed) * StadiumLandscapeModels.envelope(placed.item)


static func _reservation(placed: Dictionary) -> AABB:
	if placed.item == "ST-014":
		return AABB(Vector3(-1, 0, -0.5), Vector3(2, 1.8, 1))
	return StadiumLandscapeModels.envelope(placed.item)


static func _radius(item: String) -> float:
	if item == "ST-013":
		return 3.5
	if item == "ST-018":
		return 2.75
	if item == "ST-038":
		return StadiumFourHeadTowerModels.ENVELOPE_RADIUS
	if item == "ST-076":
		return StadiumPremiumLightTowerModels.ENVELOPE_RADIUS
	return 0.0


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	return Operations1._public_validate(layout, stock, tier)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return Operations1._supported(box, layout)


static func _corners(placed: Dictionary, box: AABB) -> PackedVector2Array:
	return Operations1._corners(placed, box)


static func _segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	return Operations1._segment_distance(a, b, c, d)


static func _outside_play(placed: Dictionary, graph: StadiumRecipeBoundary) -> bool:
	return Operations1._outside_play(placed, graph)


static func _local_box(placed: Dictionary) -> AABB:
	return Operations1._local_box(placed)


static func _overlaps(a: Dictionary, b: Dictionary, reserve_pocket: bool = false) -> bool:
	return Operations1._overlaps(a, b, reserve_pocket)


static func place(
	layout: Dictionary, stock: StadiumStock, copy: String, site: String, yaw: float = 0.0
) -> Dictionary:
	if site.is_empty():
		return store_copy(layout, copy)
	if (
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
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
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
		return StadiumLiveFurnishingItems.with_base(
			layout, place(StadiumLiveFurnishingItems.base(layout), stock, copy, site, yaw)
		)
	if site.is_empty():
		return store_copy(layout, copy)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result) or stock == null or not stock.copies.has(copy):
		return result
	var item: String = stock.copies[copy].item
	if row(copy, item, site, yaw).is_empty():
		return result
	result.landscape = result.landscape.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	# Keep another occupant visible to validation; never silently store or replace it.
	result.landscape.append({"copy": copy, "item": item, "site": site, "yaw": int(yaw)})
	result.landscape.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
														StadiumStringLightItems.is_family(layout)
														or (
															StadiumSalvageCarItems.is_family(layout)
															or (
																StadiumMasteryBannerItems.is_family(
																	layout
																)
																or (
																	StadiumWaterfallItems.is_family(
																		layout
																	)
																	or (
																		(
																			StadiumLightingKitItems
																			. is_family(layout)
																		)
																		or (
																			(
																				StadiumOutfieldPlazaItems
																				. is_family(layout)
																			)
																			or (
																				StadiumWaterfallLiveItems
																				. is_family(layout)
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
		var removed: Dictionary = store_copy(StadiumLiveFurnishingItems.base(layout), copy)
		# Preserve the explicitly empty landscape layer for every outer wrapper.
		# Otherwise with_base would restore its old last tree from the outer layout.
		if StadiumFloodlightOwnedItems.is_family(removed):
			removed = upgrade(removed, [])
		return StadiumLiveFurnishingItems.with_base(layout, removed)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result):
		return result
	result.landscape = result.landscape.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	return base(result) if result.landscape.is_empty() else result


static func prune(layout: Dictionary) -> Dictionary:
	return Operations1._public_prune(layout)

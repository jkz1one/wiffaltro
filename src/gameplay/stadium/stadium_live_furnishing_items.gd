class_name StadiumLiveFurnishingItems
extends RefCounted
## BS fixed live furnishings and explicit BL/BM scenery uses of the same paid copies.
## Family 16 ST-006 and all preceding catalogs retain their own contracts.

const VERSION: int = 1
const PRICE_VERSION: int = 19
const LAYOUT_VERSION: int = 27
const FAMILY: String = "reference-live-furnishings-v27"
const PRICES: Dictionary = {"ST-002": [160, 45], "ST-007": [680, 200]}
const FIELDS: Array[String] = ["copy", "item", "site", "yaw"]
const SITES: Dictionary = {
	"O-L1": {"item": "ST-002", "position": Vector3(-8, 0, 14)},
	"O-L2": {"item": "ST-002", "position": Vector3(-11, 0, 19)},
	"O-R1": {"item": "ST-002", "position": Vector3(8, 0, 14)},
	"O-R2": {"item": "ST-002", "position": Vector3(11, 0, 19)},
	"OL-L": {"item": "ST-007", "position": Vector3(-12, 0, 18)},
	"OL-R": {"item": "ST-007", "position": Vector3(12, 0, 18)},
	"YS-L1": {"item": "ST-002", "position": Vector3(-21.25, 0, -6.75)},
	"YS-L2": {"item": "ST-002", "position": Vector3(-23.75, 0, -6.75)},
	"YS-L3": {"item": "ST-002", "position": Vector3(-21.25, 0, -4.25)},
	"YS-L4": {"item": "ST-002", "position": Vector3(-23.75, 0, -4.25)},
	"YS-R1": {"item": "ST-002", "position": Vector3(21.25, 0, -6.75)},
	"YS-R2": {"item": "ST-002", "position": Vector3(23.75, 0, -6.75)},
	"YS-R3": {"item": "ST-002", "position": Vector3(21.25, 0, -4.25)},
	"YS-R4": {"item": "ST-002", "position": Vector3(23.75, 0, -4.25)},
	"YL-L": {"item": "ST-007", "position": Vector3(-28, 0, -10)},
	"YL-R": {"item": "ST-007", "position": Vector3(28, 0, -10)}
}
const COMPANIONS: Dictionary = {"OL-L": "O-R2", "OL-R": "O-L2"}
const SMALL: Array[String] = ["ST-001", "ST-002", "ST-003", "ST-008", "ST-009"]
const EPS: float = 0.0001

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_live_furnishing_items_operations_1.gd"
)


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if (
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
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 keeps its separate owned-pool route and cannot be flattened.
	var result: Dictionary = StadiumLandscapeOwnedItems.upgrade(layout, access)
	if not StadiumLandscapeOwnedItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["live_furnishings"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return base(StadiumSmallYardSceneryItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumLandscapeOwnedItems.LAYOUT_VERSION
	result.family = StadiumLandscapeOwnedItems.FAMILY
	result.erase("live_furnishings")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumSmallYardSceneryItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("live_furnishings") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumLandscapeOwnedItems.is_family(original)
		else StadiumLandscapeOwnedItems.with_base(base(layout), original)
	)
	if not StadiumLandscapeOwnedItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["live_furnishings"] = layout.live_furnishings.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
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
	):
		return (
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
	return is_family(layout) and StadiumLandscapeOwnedItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumLandscapeOwnedItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumLandscapeOwnedItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumLandscapeOwnedItems.graph_for(base(layout))


static func signature() -> String:
	var authored: Dictionary = {}
	for id: String in SITES:
		var site: Dictionary = SITES[id]
		authored[id] = {
			"item": site.item,
			"position": [site.position.x, site.position.y, site.position.z],
			"yaw": 0
		}
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 26,
				"models": StadiumLiveFurnishingModels.VERSION,
				"sites": authored,
				"limits": [4, 4],
				"companions": COMPANIONS,
				"units": {"ST-002": 1, "ST-007": 3},
				"beach_radius": 0.4,
				"tub": [1.3, 1.05, 1.0, 0.78],
				"tub_reserve": [3.5, 1.5, 3.5],
				"fixed_centers": true,
				"scenery_water": false,
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
	):
		return StadiumSmallYardSceneryItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumLandscapeOwnedItems.geometry(tier, base(layout)),
				"live_furnishings": signature()
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
		return ClubAssetLedger._error("This item is not in the fixed furnishing catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The furnishing quote changed; reload before purchasing.")
	return result


static func sites(item: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in SITES:
		if SITES[id].item == item:
			result.append(id)
	result.sort()
	return result


static func is_live_site(site: String) -> bool:
	return SITES.has(site) and (site.begins_with("O-") or site.begins_with("OL-"))


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or site not in sites(item) or not is_finite(yaw) or yaw != 0.0:
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site].position,
		"yaw": 0,
		"role": "LIVE_RICOCHET" if is_live_site(site) else "DECORATIVE_AFTER_TERMINAL"
	}


static func bounds(placed: Dictionary) -> AABB:
	return _pose(placed) * StadiumLiveFurnishingModels.envelope(placed.item)


static func _pose(placed: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(placed.yaw))), placed.position)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	return Operations1._public_validate(layout, stock, tier)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	if not is_terrain(layout):
		return true
	var contract: Dictionary = terrain_contract(layout)
	if contract.is_empty():
		return false
	for x: float in [box.position.x, box.get_center().x, box.end.x]:
		for z: float in [box.position.z, box.get_center().z, box.end.z]:
			var support: Dictionary = StadiumSurfaceTerrain.support(Vector2(x, z), contract.mode)
			if support.is_empty() or support.support_height != 0.0:
				return false
	return not (
		Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		. intersects(StadiumSurfaceTerrain.PATCH)
	)


static func _inside_play(placed: Dictionary, reserve: AABB, graph: StadiumRecipeBoundary) -> bool:
	var footprint: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		placed, StadiumLiveFurnishingModels.reservation(placed.item)
	)
	var polygon: PackedVector2Array = graph.polygon()
	for point: Vector2 in footprint:
		if not graph.contains(point) or absf(point.x) > point.y * tan(deg_to_rad(42.0)) + 0.45:
			return false
	for a in range(footprint.size()):
		for b in range(polygon.size()):
			if (
				StadiumLandscapeOwnedItems._segment_distance(
					footprint[a],
					footprint[(a + 1) % footprint.size()],
					polygon[b],
					polygon[(b + 1) % polygon.size()]
				)
				< 0.5
			):
				return false
	# Authoring limits are reservations only; never use them as a solid or water collider.
	var radius: float = 3.0 if placed.item == "ST-007" else 1.0
	var occupied: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		placed, StadiumLiveFurnishingModels.envelope(placed.item)
	)
	for point: Vector2 in occupied:
		if point.distance_to(Vector2(placed.position.x, placed.position.z)) > radius + EPS:
			return false
	return reserve.position.y == 0.0 and reserve.end.y <= 1.5


static func _outside_play(placed: Dictionary, graph: StadiumRecipeBoundary) -> bool:
	var polygon: PackedVector2Array = graph.polygon()
	var footprint: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		placed, StadiumLiveFurnishingModels.reservation(placed.item)
	)
	for point: Vector2 in footprint:
		if graph.contains(point):
			return false
	for point: Vector2 in polygon:
		if Geometry2D.is_point_in_polygon(point, footprint):
			return false
	for a in range(footprint.size()):
		for b in range(polygon.size()):
			if (
				StadiumLandscapeOwnedItems._segment_distance(
					footprint[a],
					footprint[(a + 1) % footprint.size()],
					polygon[b],
					polygon[(b + 1) % polygon.size()]
				)
				<= StadiumRecipeBoundary.THICKNESS + EPS
			):
				return false
	return true


static func _local_box(placed: Dictionary) -> AABB:
	return (
		StadiumLiveFurnishingModels.reservation(placed.item)
		if PRICES.has(placed.item)
		else StadiumLandscapeOwnedItems._local_box(placed)
	)


static func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	var ab: AABB = _local_box(a)
	var bb: AABB = _local_box(b)
	var at: Transform3D = _pose(a)
	var bt: Transform3D = _pose(b)
	var ac: Vector3 = at * ab.get_center()
	var bc: Vector3 = bt * bb.get_center()
	if absf(ac.y - bc.y) >= (ab.size.y + bb.size.y) * 0.5 - EPS:
		return false
	for axis: Vector3 in [at.basis.x, at.basis.z, bt.basis.x, bt.basis.z]:
		var a_extent: float = (
			(absf(axis.dot(at.basis.x)) * ab.size.x + absf(axis.dot(at.basis.z)) * ab.size.z) * 0.5
		)
		var b_extent: float = (
			(absf(axis.dot(bt.basis.x)) * bb.size.x + absf(axis.dot(bt.basis.z)) * bb.size.z) * 0.5
		)
		if absf(axis.dot(ac - bc)) >= a_extent + b_extent - EPS:
			return false
	return true


static func place(
	layout: Dictionary, stock: StadiumStock, copy: String, site: String, yaw: float = 0.0
) -> Dictionary:
	if (
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
	):
		return StadiumSmallYardSceneryItems.with_base(
			layout, place(StadiumSmallYardSceneryItems.base(layout), stock, copy, site, yaw)
		)
	if site.is_empty():
		return store_copy(layout, copy)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result) or stock == null or not stock.copies.has(copy):
		return result
	var item: String = stock.copies[copy].item
	if row(copy, item, site, yaw).is_empty():
		return result
	result.live_furnishings = result.live_furnishings.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	result.live_furnishings.append({"copy": copy, "item": item, "site": site, "yaw": 0})
	result.live_furnishings.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
	):
		return StadiumSmallYardSceneryItems.with_base(
			layout, store_copy(StadiumSmallYardSceneryItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result):
		return result
	result.live_furnishings = result.live_furnishings.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	return base(result) if result.live_furnishings.is_empty() else result


static func prune(layout: Dictionary) -> Dictionary:
	return Operations1._public_prune(layout)

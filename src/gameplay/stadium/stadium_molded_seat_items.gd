class_name StadiumMoldedSeatItems
extends RefCounted
## A fixed empty map pad with four sockets. Only exact paid ST-051 copies fill them.

const VERSION: int = 1
const PRICE_VERSION: int = 20
const LAYOUT_VERSION: int = 29
const FAMILY: String = "reference-molded-seat-pad-v29"
const PRICES: Dictionary = {"ST-051": [220, 45]}
const ITEMS: Array[String] = ["ST-051"]
const FIELDS: Array[String] = ["copy", "site"]
const ENVELOPE: AABB = AABB(Vector3(-0.25, 0, -0.275), Vector3(0.50, 0.85, 0.55))
const PAD: AABB = AABB(Vector3(-31, 0, 19), Vector3(6, 0.15, 3))
const RAMP: AABB = AABB(Vector3(-29, 0, 17), Vector3(2, 0.15, 2))
const APPROACH: AABB = AABB(Vector3(-29, 0, 15), Vector3(2, 0, 2))
const EPS: float = 0.0001
const SITES: Dictionary = {
	"SEAT-PAD-1": Vector3(-29.5, 0.15, 20.8),
	"SEAT-PAD-2": Vector3(-28.5, 0.15, 20.8),
	"SEAT-PAD-3": Vector3(-27.5, 0.15, 20.8),
	"SEAT-PAD-4": Vector3(-26.5, 0.15, 20.8)
}

const Operations1: GDScript = preload(
	"res://src/gameplay/stadium/stadium_molded_seat_items_operations_1.gd"
)


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func has_pad(layout: Dictionary) -> bool:
	if is_family(layout):
		return true
	if (
		StadiumGroundBoxItems.is_family(layout)
		or StadiumPracticeFacilityItems.is_family(layout)
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
												StadiumMasteryBannerItems.is_family(layout)
												or (
													StadiumWaterfallItems.is_family(layout)
													or (
														StadiumLightingKitItems.is_family(layout)
														or (
															StadiumOutfieldPlazaItems.is_family(
																layout
															)
															or StadiumWaterfallLiveItems.is_family(
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
	):
		return is_family(StadiumGroundBoxItems.base(layout))
	return false


static func remove_pad(layout: Dictionary) -> Dictionary:
	# Removing infrastructure is a separate explicit action. Never store seats or
	# remove another occupied channel as a side effect of unselecting the pad.
	if not has_pad(layout):
		return layout.duplicate(true)
	var pad: Dictionary = layout if is_family(layout) else StadiumGroundBoxItems.base(layout)
	if not pad.get("molded_seats") is Array or not pad.molded_seats.is_empty():
		return layout.duplicate(true)
	if is_family(layout):
		return base(layout)
	# Families 30 through 34 carry the exact optional 28/29 parent selector.
	# Retain their other rows and identities while dropping only the empty pad.
	var result: Dictionary = layout.duplicate(true)
	result.ground_box_base_version = StadiumSmallYardSceneryItems.LAYOUT_VERSION
	result.erase("molded_seats")
	return result


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.with_base(
			layout, upgrade(StadiumGroundBoxItems.base(layout), access)
		)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its separate owned route.
	var result: Dictionary = StadiumSmallYardSceneryItems.upgrade(layout, access)
	if not StadiumSmallYardSceneryItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["molded_seats"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		var inherited: Dictionary = StadiumGroundBoxItems.base(layout)
		return base(inherited) if is_family(inherited) else inherited
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumSmallYardSceneryItems.LAYOUT_VERSION
	result.family = StadiumSmallYardSceneryItems.FAMILY
	result.erase("molded_seats")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("molded_seats") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumSmallYardSceneryItems.is_family(original)
		else StadiumSmallYardSceneryItems.with_base(base(layout), original)
	)
	if not StadiumSmallYardSceneryItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["molded_seats"] = layout.molded_seats.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
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
	):
		return (
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
	return is_family(layout) and StadiumSmallYardSceneryItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.terrain_contract(layout)
	return StadiumSmallYardSceneryItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.contacts_layout(layout)
	return with_base(layout, StadiumSmallYardSceneryItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.graph_for(layout)
	return StadiumSmallYardSceneryItems.graph_for(base(layout))


static func signature() -> String:
	var authored: Dictionary = {}
	for site: String in SITES:
		var point: Vector3 = SITES[site]
		authored[site] = [point.x, point.y, point.z, 0]
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 28,
				"models": StadiumMoldedSeatModels.VERSION,
				"sites": authored,
				"envelope": [-0.25, 0, -0.275, 0.50, 0.85, 0.55],
				"pad": [-31, 0, 19, 6, 0.15, 3],
				"ramp": [-29, 0, 17, 2, 0.15, 2],
				"approach": [-29, 0, 15, 2, 0, 2],
				"ramp_slope": 0.075,
				"tiers": ["expanded", "club", "mogul"],
				"empty_sockets": 4,
				"item": "ST-051",
				"copy_policy": "exact-owned-copy-store-first-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"night_qualified": false,
				"pad_inventory": false
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumSmallYardSceneryItems.geometry(tier, base(layout)),
				"molded_seats": signature()
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
		return ClubAssetLedger._error("This item is not the exact molded-seat catalog item.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The molded-seat quote changed; reload before purchasing.")
	return result


static func sites(item: String = "ST-051") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-051") -> Array[int]:
	var result: Array[int] = []
	if PRICES.has(item):
		result.append(0)
	return result


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or not SITES.has(site) or not is_finite(yaw) or yaw != 0.0:
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site],
		"yaw": 0,
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-051") -> AABB:
	return ENVELOPE if PRICES.has(item) else AABB()


static func reservations() -> Array[AABB]:
	return [PAD, RAMP, APPROACH]


static func bounds(placed: Dictionary) -> AABB:
	return StadiumLiveFurnishingItems._pose(placed) * envelope(placed.item)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	return Operations1._public_validate(layout, stock, tier)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	if not is_terrain(layout):
		return true
	var contract: Dictionary = terrain_contract(layout)
	if contract.is_empty() or contract.get("mode") not in ["rough", "leveled"]:
		return false
	# The fixed pad uses the actual flat outer-property ground, beyond the inner
	# terrain sampler. Neither the pad nor its local access intersects its patch.
	return not (
		Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		. intersects(StadiumSurfaceTerrain.PATCH)
	)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	if graph == null:
		return false
	var footprint: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		{"position": Vector3.ZERO, "yaw": 0}, box
	)
	var polygon: PackedVector2Array = graph.polygon()
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


static func _reservation_overlaps(reserve: AABB, other: Dictionary) -> bool:
	# Full horizontal map reservations use exact oriented footprints, not world
	# AABB approximations. Vertical clearance never licenses a host over the pad.
	var radius: float = (
		StadiumSmallYardSceneryItems.RADIUS
		if StadiumSmallYardSceneryItems.SITES.has(other.site)
		else StadiumLandscapeOwnedItems._radius(other.item)
	)
	if String(other.site).begins_with("LAND-"):
		radius = 0.0
	if radius > 0.0:
		var nearest: Vector2 = Vector2(
			clampf(other.position.x, reserve.position.x, reserve.end.x),
			clampf(other.position.z, reserve.position.z, reserve.end.z)
		)
		return nearest.distance_to(Vector2(other.position.x, other.position.z)) < radius - EPS
	var box: AABB = (
		AABB(Vector3(-3, 0, -3), Vector3(6, 2, 6))
		if String(other.site).begins_with("LAND-")
		else (
			StadiumFacilityItems.reserved(other.site)
			if StadiumFacilityItems.PRICES.has(other.item)
			else StadiumLiveFurnishingItems._local_box(other)
		)
	)
	var pose: Transform3D = StadiumLiveFurnishingItems._pose(other)
	var center: Vector3 = pose * box.get_center()
	var delta: Vector3 = reserve.get_center() - center
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK, pose.basis.x, pose.basis.z]:
		var a_extent: float = (absf(axis.x) * reserve.size.x + absf(axis.z) * reserve.size.z) * 0.5
		var b_extent: float = (
			(absf(axis.dot(pose.basis.x)) * box.size.x + absf(axis.dot(pose.basis.z)) * box.size.z)
			* 0.5
		)
		if absf(axis.dot(delta)) >= a_extent + b_extent - EPS:
			return false
	return true


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.with_base(
			layout, place(StadiumGroundBoxItems.base(layout), stock, copy, site, yaw, access)
		)
	if site.is_empty():
		return store_copy(layout, copy)
	if (
		stock == null
		or not stock.copies.has(copy)
		or row(copy, stock.copies[copy].item, site, yaw).is_empty()
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	result.molded_seats = result.molded_seats.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	# Keep another occupant visible so validation rejects it; never displace it.
	result.molded_seats.append({"copy": copy, "site": site})
	result.molded_seats.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
													StadiumMasteryBannerItems.is_family(layout)
													or (
														StadiumWaterfallItems.is_family(layout)
														or (
															StadiumLightingKitItems.is_family(
																layout
															)
															or (
																StadiumOutfieldPlazaItems.is_family(
																	layout
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
	):
		return StadiumGroundBoxItems.with_base(
			layout, store_copy(StadiumGroundBoxItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("molded_seats") is Array:
		result.molded_seats = result.molded_seats.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	return Operations1._public_prune(layout)

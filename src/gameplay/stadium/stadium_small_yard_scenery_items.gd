class_name StadiumSmallYardSceneryItems
extends RefCounted
## BL small cells reuse exact owned models. No new catalog, purchase or live rule.

const VERSION: int = 1
const LAYOUT_VERSION: int = 28
const FAMILY: String = "reference-small-yard-scenery-v28"
const ITEMS: Array[String] = ["ST-001", "ST-003", "ST-004", "ST-008", "ST-009"]
const FIELDS: Array[String] = ["copy", "item", "site", "yaw"]
const RADIUS: float = 1.0
const HEIGHT: float = 1.5
const EPS: float = 0.0001
const SITES: Dictionary = {
	"YS-L1": Vector3(-21.25, 0, -6.75),
	"YS-L2": Vector3(-23.75, 0, -6.75),
	"YS-L3": Vector3(-21.25, 0, -4.25),
	"YS-L4": Vector3(-23.75, 0, -4.25),
	"YS-R1": Vector3(21.25, 0, -6.75),
	"YS-R2": Vector3(23.75, 0, -6.75),
	"YS-R3": Vector3(21.25, 0, -4.25),
	"YS-R4": Vector3(23.75, 0, -4.25)
}


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
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
		return layout.duplicate(true)
	if StadiumMoldedSeatItems.is_family(layout):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate route.
	var result: Dictionary = StadiumLiveFurnishingItems.upgrade(layout, access)
	if not StadiumLiveFurnishingItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["yard_scenery"] = []
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
		return base(StadiumGroundBoxItems.base(layout))
	if StadiumMoldedSeatItems.is_family(layout):
		return base(StadiumMoldedSeatItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumLiveFurnishingItems.LAYOUT_VERSION
	result.family = StadiumLiveFurnishingItems.FAMILY
	result.erase("yard_scenery")
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
	if StadiumMoldedSeatItems.is_family(layout):
		return StadiumMoldedSeatItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("yard_scenery") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumLiveFurnishingItems.is_family(original)
		else StadiumLiveFurnishingItems.with_base(base(layout), original)
	)
	if not StadiumLiveFurnishingItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["yard_scenery"] = layout.yard_scenery.duplicate(true)
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
	if StadiumMoldedSeatItems.is_family(layout):
		return StadiumMoldedSeatItems.is_terrain(layout)
	return is_family(layout) and StadiumLiveFurnishingItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumLiveFurnishingItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumLiveFurnishingItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumLiveFurnishingItems.graph_for(base(layout))


static func signature() -> String:
	var authored: Dictionary = {}
	for site: String in SITES:
		var point: Vector3 = SITES[site]
		authored[site] = [point.x, point.y, point.z]
	var models: Dictionary = {}
	for item: String in ITEMS:
		var box: AABB = envelope(item)
		models[item] = [
			box.position.x,
			box.position.y,
			box.position.z,
			box.size.x,
			box.size.y,
			box.size.z,
			yaws(item)
		]
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 27,
				"sites": authored,
				"items": models,
				"radius": RADIUS,
				"height": HEIGHT,
				"starter_model": StadiumStarterModels.VERSION,
				"prop_model": StadiumGroundPropsModels.VERSION,
				"scenery_adapter": StadiumSmallYardSceneryModels.VERSION,
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"night_qualified": false,
				"copy_policy": "same-copy-exclusive-obstacles-props-yard-scenery-v1"
			},
			"",
			true,
			true
		)
		. sha256_text()
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
	if StadiumMoldedSeatItems.is_family(layout):
		return StadiumMoldedSeatItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumLiveFurnishingItems.geometry(tier, base(layout)),
				"yard_scenery": signature()
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func sites(item: String) -> Array[String]:
	var result: Array[String] = []
	if item in ITEMS:
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String) -> Array[int]:
	var result: Array[int] = []
	if item in ITEMS:
		result.assign([0] if item == "ST-001" else [0, 90, 180, 270])
	return result


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if (
		item not in ITEMS
		or not SITES.has(site)
		or not is_finite(yaw)
		or yaw != floorf(yaw)
		or int(yaw) not in yaws(item)
	):
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site],
		"yaw": int(yaw),
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String) -> AABB:
	return StadiumSmallYardSceneryModels.envelope(item)


static func reservation() -> AABB:
	# Bounding box for property/terrain support; horizontal collision exclusion is a disk.
	return AABB(Vector3(-RADIUS, 0, -RADIUS), Vector3(2 * RADIUS, HEIGHT, 2 * RADIUS))


static func bounds(placed: Dictionary) -> AABB:
	return StadiumLiveFurnishingItems._pose(placed) * envelope(placed.item)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
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
		return StadiumGroundBoxItems.validate(layout, stock, tier)
	if StadiumMoldedSeatItems.is_family(layout):
		return StadiumMoldedSeatItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("yard_scenery") is Array
		or layout.yard_scenery.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown small-yard scenery layout or cell capacity.")
	var checked: Dictionary = StadiumLiveFurnishingItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["yard_scenery_placements"] = []
	if layout.yard_scenery.is_empty():
		return checked
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error("Yard scenery needs a verified complete field boundary.")
	var occupied: Dictionary = {}
	for placed: Dictionary in checked.placements:
		occupied[placed.site] = true
	var previous: String = ""
	for raw: Variant in layout.yard_scenery:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, FIELDS)
			or not raw.copy is String
			or not raw.item is String
			or not raw.site is String
			or not SeasonOwnership._whole(raw.yaw, 0, 270)
			or raw.site <= previous
			or occupied.has(raw.site)
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or stock.copies[raw.copy].item != raw.item
		):
			return StadiumStarterLayout._error(
				"Each yard cell needs one distinct matching owned copy and a canonical site/yaw."
			)
		var placed: Dictionary = row(raw.copy, raw.item, raw.site, float(raw.yaw))
		if placed.is_empty() or not _fits(envelope(raw.item)):
			return StadiumStarterLayout._error(
				"This exact item and orientation do not fit the small-yard cell."
			)
		var reserve: AABB = reservation()
		reserve.position += placed.position
		if (
			not StadiumProperty.contains(tier, reserve)
			or not StadiumLiveFurnishingItems._supported(reserve, layout)
			or not _outside_play(placed.position, graph)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						raw.site
						+ " needs its complete level supported cell outside live play and inside the property."
					)
				)
			)
		for other: Dictionary in checked.placements:
			if _cell_overlaps(placed, other):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		checked.placements.append(placed)
		checked.yard_scenery_placements.append(placed)
		checked.stored.erase(raw.copy)
		occupied[raw.site] = true
		previous = raw.site
	# Scenery never enters the live obstacle budget or enables a lighting profile.
	checked.night_qualified = false
	checked["night_unqualified_reason"] = \
		("Small-yard scenery has not been qualified for Night. Store it to " + \
		"restore the prior lighting layout.")
	return checked


static func _fits(box: AABB) -> bool:
	if box.size == Vector3.ZERO or box.position.y < -EPS or box.end.y > HEIGHT + EPS:
		return false
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if Vector2(point.x, point.z).length() > RADIUS + EPS:
			return false
	return true


static func _outside_play(position: Vector3, graph: StadiumRecipeBoundary) -> bool:
	var center: Vector2 = Vector2(position.x, position.z)
	if graph.contains(center):
		return false
	var polygon: PackedVector2Array = graph.polygon()
	for index in range(polygon.size()):
		if (
			center.distance_to(
				Geometry2D.get_closest_point_to_segment(
					center, polygon[index], polygon[(index + 1) % polygon.size()]
				)
			)
			<= RADIUS + StadiumRecipeBoundary.THICKNESS + EPS
		):
			return false
	return true


static func _cell_overlaps(placed: Dictionary, other: Dictionary) -> bool:
	if SITES.has(other.site):
		return (
			(
				Vector2(placed.position.x - other.position.x, placed.position.z - other.position.z)
				. length()
			)
			< 2 * RADIUS - EPS
		)
	var box: AABB = (
		StadiumFacilityItems.reserved(other.site)
		if StadiumFacilityItems.PRICES.has(other.item)
		else StadiumLiveFurnishingItems._local_box(other)
	)
	var pose: Transform3D = StadiumLiveFurnishingItems._pose(other)
	if (
		pose.origin.y + box.end.y <= placed.position.y + EPS
		or pose.origin.y + box.position.y >= placed.position.y + HEIGHT - EPS
	):
		return false
	var local: Vector3 = pose.affine_inverse() * placed.position
	var nearest: Vector2 = Vector2(
		clampf(local.x, box.position.x, box.end.x), clampf(local.z, box.position.z, box.end.z)
	)
	return Vector2(local.x, local.z).distance_to(nearest) < RADIUS - EPS


static func _detach(layout: Dictionary, copy: String) -> void:
	# Same instance moves channels; no inventory or other copy is modified.
	layout.obstacles = layout.obstacles.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	if layout.get("props") is Array:
		layout.props = layout.props.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	if layout.get("yard_scenery") is Array:
		layout.yard_scenery = layout.yard_scenery.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
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
	var item: String = stock.copies[copy].item
	_detach(result, copy)
	result.yard_scenery.append({"copy": copy, "item": item, "site": site, "yaw": int(yaw)})
	result.yard_scenery.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func place_live(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if (
		SeasonOwnership._whole(result.get("version"), 16, 16)
		or not result.get("obstacles") is Array
		or stock == null
		or not stock.copies.has(copy)
		or not is_finite(yaw)
	):
		return result
	var item: String = stock.copies[copy].item
	if item not in ITEMS:
		return result
	var starter: bool = item in ["ST-001", "ST-003"]
	if starter:
		if (
			not StadiumStarterLayout.SITES.has(site)
			or yaw != floorf(yaw)
			or int(yaw) not in yaws(item)
		):
			return result
	elif (
		not StadiumGroundPropsItems.SITES.has(site)
		or item not in StadiumGroundPropsItems.SITES[site].items
		or yaw != StadiumGroundPropsItems.SITES[site].yaw
	):
		return result
	if not starter and not result.get("props") is Array:
		result = StadiumGroundPropsItems.upgrade(result, access)
		if result.is_empty():
			return layout.duplicate(true)
	_detach(result, copy)
	if starter:
		result.obstacles.append({"copy": copy, "site": site, "yaw": int(yaw)})
		result.obstacles.sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
		)
	else:
		result.props.append({"copy": copy, "site": site})
		result.props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
	return _after_yard_removal(result)


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if (
		SeasonOwnership._whole(result.get("version"), 16, 16)
		or not result.get("obstacles") is Array
	):
		return result
	_detach(result, copy)
	return _after_yard_removal(result)


static func _after_yard_removal(layout: Dictionary) -> Dictionary:
	# Only a removed family-28 channel can unwind its newly introduced empty wrappers.
	# Existing non-28 drafts keep their exact family and eligibility.
	if not is_family(layout) or not layout.yard_scenery.is_empty():
		return layout
	var result: Dictionary = base(layout)
	if result.get("live_furnishings") is Array and result.live_furnishings.is_empty():
		result = StadiumLiveFurnishingItems.base(result)
		if result.get("landscape") is Array and result.landscape.is_empty():
			result = StadiumLandscapeOwnedItems.base(result)
	return result


static func prune(layout: Dictionary) -> Dictionary:
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
		return StadiumGroundBoxItems.prune(layout)
	if StadiumMoldedSeatItems.is_family(layout):
		return StadiumMoldedSeatItems.prune(layout)
	return with_base(layout, StadiumLiveFurnishingItems.prune(base(layout)))

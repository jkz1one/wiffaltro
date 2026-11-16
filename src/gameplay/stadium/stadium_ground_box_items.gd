class_name StadiumGroundBoxItems
extends RefCounted
## Complete ground-supported boxes. Optional molded-seat infrastructure stays optional.

const VERSION: int = 1
const PRICE_VERSION: int = 21
const LAYOUT_VERSION: int = 30
const FAMILY: String = "reference-ground-box-v30"
const PRICES: Dictionary = {"ST-052": [520, 160]}
const ITEMS: Array[String] = ["ST-052"]
const FIELDS: Array[String] = ["copy", "site"]
const ENVELOPE: AABB = AABB(Vector3(-2.75, 0, -2), Vector3(5.5, 2.2, 4))
const SETBACK: float = 1.5
const EPS: float = 0.0001
const SITES: Dictionary = {
	"BOX-L": {"position": Vector3(-18.2, 0, 3), "yaw": 90},
	"BOX-R": {"position": Vector3(18.2, 0, 3), "yaw": -90}
}


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its separate exact owned route.
	var result: Dictionary = (
		layout.duplicate(true)
		if StadiumMoldedSeatItems.is_family(layout)
		else StadiumSmallYardSceneryItems.upgrade(layout, access)
	)
	if (
		not StadiumSmallYardSceneryItems.is_family(result)
		and not StadiumMoldedSeatItems.is_family(result)
	):
		return {}
	result["ground_box_base_version"] = int(result.version)
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["ground_boxes"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
		return base(StadiumPracticeFacilityItems.base(layout))
	if (
		not is_family(layout)
		or not SeasonOwnership._whole(layout.get("ground_box_base_version"), 28, 29)
	):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = int(result.ground_box_base_version)
	result.family = (
		StadiumMoldedSeatItems.FAMILY
		if result.version == 29
		else StadiumSmallYardSceneryItems.FAMILY
	)
	result.erase("ground_box_base_version")
	result.erase("ground_boxes")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
		return StadiumPracticeFacilityItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("ground_boxes") is Array or base(layout).is_empty():
		return {}
	var result: Dictionary
	if StadiumMoldedSeatItems.is_family(original):
		result = original.duplicate(true)
	elif StadiumSmallYardSceneryItems.is_family(original):
		result = (
			StadiumMoldedSeatItems.with_base(base(layout), original)
			if layout.ground_box_base_version == 29
			else original.duplicate(true)
		)
	else:
		result = (
			StadiumMoldedSeatItems.with_base(base(layout), original)
			if layout.ground_box_base_version == 29
			else StadiumSmallYardSceneryItems.with_base(base(layout), original)
		)
	if (
		not StadiumSmallYardSceneryItems.is_family(result)
		and not StadiumMoldedSeatItems.is_family(result)
	):
		return {}
	result["ground_box_base_version"] = int(result.version)
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["ground_boxes"] = layout.ground_boxes.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
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
	):
		return (
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
	return is_family(layout) and StadiumSmallYardSceneryItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumSmallYardSceneryItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumSmallYardSceneryItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumSmallYardSceneryItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"bases": [28, 29],
				"models": StadiumGroundBoxModels.VERSION,
				"sites": {"BOX-L": [-18.2, 0, 3, 90], "BOX-R": [18.2, 0, 3, -90]},
				"envelope": [-2.75, 0, -2, 5.5, 2.2, 4],
				"world_reservation": [4, 2.2, 5.5],
				"tiers": ["expanded", "club", "mogul"],
				"graph_line_setback": SETBACK,
				"slab_clearance": "actual-selected-graph-no-overlap-v1",
				"same_side_exclusions": ["ST-029:BASE1", "ST-029:BASE2", "ST-032", "ST-074"],
				"copy_policy": "exact-owned-copy-store-first-v1",
				"optional_pad": true,
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
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
		return StadiumPracticeFacilityItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumSmallYardSceneryItems.geometry(tier, base(layout)),
				"ground_boxes": signature()
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
		return ClubAssetLedger._error("This item is not the complete ground box-seat catalog item.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error(
			"The ground box-seat quote changed; reload before purchasing."
		)
	return result


static func sites(item: String = "ST-052") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-052") -> Array[int]:
	var result: Array[int] = []
	if PRICES.has(item):
		result.append(0)  # Fixed-pose command token; the site determines its field-facing yaw.
	return result


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if (
		not PRICES.has(item)
		or not SITES.has(site)
		or not is_finite(yaw)
		or (yaw != 0.0 and yaw != float(SITES[site].yaw))
	):
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site].position,
		"yaw": SITES[site].yaw,
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-052") -> AABB:
	return ENVELOPE if PRICES.has(item) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	# Authored quarter-turn sites have an exact axis-aligned world reservation.
	return AABB(placed.position + Vector3(-2, 0, -2.75), Vector3(4, 2.2, 5.5))


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
		return StadiumPracticeFacilityItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("ground_boxes") is Array
		or layout.ground_boxes.size() > SITES.size()
		or base(layout).is_empty()
	):
		return StadiumStarterLayout._error(
			"Unknown ground box-seat layout, parent or site capacity."
		)
	if tier not in ["expanded", "club", "mogul"]:
		return StadiumStarterLayout._error("Ground box seats require Expanded or larger property.")
	var checked: Dictionary = StadiumSmallYardSceneryItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["ground_box_placements"] = []
	if layout.ground_boxes.is_empty():
		return checked
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"Ground box seats need a verified complete selected field boundary."
		)
	var prior: String = ""
	for raw: Variant in layout.ground_boxes:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, FIELDS)
			or not raw.copy is String
			or not raw.site is String
			or not SITES.has(raw.site)
			or raw.site <= prior
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or stock.copies[raw.copy].item != "ST-052"
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"Each ground box needs one distinct exact owned ST-052 copy; explicitly store an "
						+ "occupant or moving copy first."
					)
				)
			)
		var placed: Dictionary = row(raw.copy, "ST-052", raw.site)
		var reserve: AABB = bounds(placed)
		if (
			not StadiumProperty.contains(tier, reserve)
			or not _supported(reserve, layout)
			or not _outside_play(reserve, graph)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						raw.site
						+ (" needs its complete supported footprint inside the property, outside " + \
							"play and clear of the selected boundary slabs.")
					)
				)
			)
		# Check the fully validated combined base, so placement order cannot bypass exclusions.
		for other: Dictionary in checked.placements:
			if _same_side_exclusion(placed, other) or _overlaps(reserve, other):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		if layout.ground_box_base_version == 29:
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if (
					Rect2(
						Vector2(reserve.position.x, reserve.position.z),
						Vector2(reserve.size.x, reserve.size.z)
					)
					. intersects(
						Rect2(
							Vector2(pad.position.x, pad.position.z), Vector2(pad.size.x, pad.size.z)
						)
					)
				):
					return (
						StadiumStarterLayout
						. _error(
							"The ground box must leave the existing molded-seat pad and its access clear."
						)
					)
		checked.placements.append(placed)
		checked.ground_box_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "Ground box-seat sections have not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _same_side_exclusion(placed: Dictionary, other: Dictionary) -> bool:
	var side: String = "L" if placed.site == "BOX-L" else "R"
	if other.item == "ST-029" and other.site in ["BASE-" + side + "1", "BASE-" + side + "2"]:
		return true
	return (
		other.item in ["ST-032", "ST-074"]
		and (
			(other.site == "DUGOUT-" + side)
			or (other.position.x < 0 if side == "L" else other.position.x > 0)
		)
	)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumLiveFurnishingItems._supported(box, layout)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	if graph == null:
		return false
	var footprint: PackedVector2Array = StadiumLandscapeOwnedItems._corners(
		{"position": Vector3.ZERO, "yaw": 0}, box
	)
	var polygon: PackedVector2Array = graph.polygon()
	var segments: Array[Dictionary] = graph.segments()
	if polygon.size() < 3 or segments.size() != polygon.size():
		return false
	for point: Vector2 in footprint:
		if graph.contains(point):
			return false
	for point: Vector2 in polygon:
		if not point.is_finite() or Geometry2D.is_point_in_polygon(point, footprint):
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
				< SETBACK - EPS
			):
				return false
	# Runtime slabs use the selected graph's mitered outer vertices. Clearance is
	# no overlap with those actual slabs, not a second 1.5m outer-face setback.
	for index in range(polygon.size()):
		var outer_a: Vector2 = graph.outer_vertex(index)
		var outer_b: Vector2 = graph.outer_vertex((index + 1) % polygon.size())
		if not outer_a.is_finite() or not outer_b.is_finite():
			return false
		var slab: PackedVector2Array = [
			polygon[index], polygon[(index + 1) % polygon.size()], outer_b, outer_a
		]
		if not Geometry2D.intersect_polygons(footprint, slab).is_empty():
			return false
	return true


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	if PRICES.has(other.item):
		var box: AABB = bounds(other)
		return (
			Rect2(
				Vector2(reserve.position.x, reserve.position.z),
				Vector2(reserve.size.x, reserve.size.z)
			)
			. intersects(
				Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
			)
		)
	if StadiumMoldedSeatItems.PRICES.has(other.item):
		return reserve.intersects(StadiumMoldedSeatItems.bounds(other))
	return StadiumMoldedSeatItems._reservation_overlaps(reserve, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
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
		return StadiumPracticeFacilityItems.with_base(
			layout, place(StadiumPracticeFacilityItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.ground_boxes:
		if current.copy == copy and current.site == site:
			return result
	# Keep conflicting occupants or a second request for an installed copy visible.
	# Validation rejects the combined draft; placement never silently moves a copy.
	result.ground_boxes.append({"copy": copy, "site": site})
	result.ground_boxes.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
		return StadiumPracticeFacilityItems.with_base(
			layout, store_copy(StadiumPracticeFacilityItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("ground_boxes") is Array:
		result.ground_boxes = result.ground_boxes.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
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
		return StadiumPracticeFacilityItems.prune(layout)
	return with_base(layout, StadiumSmallYardSceneryItems.prune(base(layout)))

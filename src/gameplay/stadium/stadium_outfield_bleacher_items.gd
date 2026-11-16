class_name StadiumOutfieldBleacherItems
extends RefCounted
## One complete paid elevated outfield bleacher assembly, including access and supports.

const VERSION: int = 1
const PRICE_VERSION: int = 25
const LAYOUT_VERSION: int = 34
const FAMILY: String = "reference-outfield-bleachers-v34"
const PRICES: Dictionary = {"ST-054": [450, 120]}
const ITEMS: Array[String] = ["ST-054"]
const FIELDS: Array[String] = ["copy", "site"]
const SITES: Dictionary = {"OF-BLEACHER-A": Vector3(-17, 0, 36)}
const ENVELOPE: AABB = StadiumOutfieldBleacherModels.ENVELOPE


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumLandmarkItems.upgrade(layout, access)
	if not StadiumLandmarkItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["outfield_bleachers"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return base(StadiumRisingAppleItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumLandmarkItems.LAYOUT_VERSION
	result.family = StadiumLandmarkItems.FAMILY
	result.erase("outfield_bleachers")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return StadiumRisingAppleItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("outfield_bleachers") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumLandmarkItems.is_family(original)
		else StadiumLandmarkItems.with_base(base(layout), original)
	)
	if not StadiumLandmarkItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["outfield_bleachers"] = layout.outfield_bleachers.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
		StadiumRisingAppleItems.is_family(layout)
		or (
			StadiumWallTopTerraceItems.is_family(layout)
			or StadiumPlayerTunnelItems.is_family(layout)
		)
	):
		return (
			StadiumRisingAppleItems.is_terrain(layout)
			or (
				StadiumWallTopTerraceItems.is_terrain(layout)
				or StadiumPlayerTunnelItems.is_terrain(layout)
			)
		)
	return is_family(layout) and StadiumLandmarkItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumLandmarkItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumLandmarkItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumLandmarkItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 33,
				"optional_base": [28, 29],
				"models": StadiumOutfieldBleacherModels.VERSION,
				"sites": {"OF-BLEACHER-A": [-17, 0, 36]},
				"envelope":
				[
					ENVELOPE.position.x,
					ENVELOPE.position.y,
					ENVELOPE.position.z,
					ENVELOPE.size.x,
					ENVELOPE.size.y,
					ENVELOPE.size.z
				],
				"yaw": 0,
				"tiers": ["club", "mogul"],
				"items": ITEMS,
				"wall_shapes": ["straight", "deeper_center"],
				"back_height": 3.25,
				"side_return_height": 1.20,
				"wall_eligibility": "exact-current-recipe-owned-graphs-v1",
				"sightline_exclusions": ["ST-013:TREE-L"],
				"copy_policy": "exact-owned-copy-store-first-v1",
				"site_capacity": 1,
				"bundled_access": true,
				"bundled_supports": true,
				"back_wall_consumption": false,
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "selected-boundary-slabs-and-full-occupied-reservations-v1",
				"symmetric_reservation_conflict": "explicit-store-first-both-orders-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"receiver": false,
				"crowd": false,
				"gameplay_bonus": false,
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return StadiumRisingAppleItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumLandmarkItems.geometry(tier, base(layout)),
				"outfield_bleachers": signature()
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
		return ClubAssetLedger._error(
			"This item is not the complete paid outfield bleacher assembly."
		)
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
			"The outfield bleacher quote changed; reload before purchasing."
		)
	return result


static func sites(item: String = "ST-054") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
		result.sort()
	return result


static func yaws(item: String = "ST-054") -> Array[int]:
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


static func envelope(item: String = "ST-054", site: String = "OF-BLEACHER-A") -> AABB:
	return ENVELOPE if PRICES.has(item) and SITES.has(site) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item, placed.site)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return StadiumRisingAppleItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("outfield_bleachers") is Array
		or layout.outfield_bleachers.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown outfield bleacher layout or site capacity.")
	var checked: Dictionary = StadiumLandmarkItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["outfield_bleacher_placements"] = []
	if layout.outfield_bleachers.is_empty():
		return checked
	if tier not in ["club", "mogul"]:
		return StadiumStarterLayout._error("Outfield bleachers require Club or Mogul property.")
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if not wall_eligible(graph):
		return (
			StadiumStarterLayout
			. _error(
				(
					"OF-BLEACHER-A requires the current straight or deeper-center boundary with 3.25 m "
					+ "back walls and 1.20 m side/return walls; taller or dormant wall profiles are not "
					+ "eligible."
				)
			)
		)
	var prior: String = ""
	for raw: Variant in layout.outfield_bleachers:
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
			or not PRICES.has(stock.copies[raw.copy].item)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"OF-BLEACHER-A needs one exact owned ST-054 copy; explicitly store its occupant or "
						+ "moving copy first."
					)
				)
			)
		var placed: Dictionary = row(raw.copy, stock.copies[raw.copy].item, raw.site)
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
						+ (" needs its entire supported reservation inside the property and " + \
							"outside the selected field and boundary slabs.")
					)
				)
			)
		# Validate the complete reconstructed layout in either command order.
		# Keep all paid occupants until the user explicitly stores one.
		for other: Dictionary in checked.placements:
			if other.item == "ST-013" and other.site == "TREE-L":
				return (
					StadiumStarterLayout
					. _error(
						(
							"TREE-L blocks the elevated bleacher sightline to home plate; explicitly store the "
							+ "tree or the outfield bleacher assembly first. Both paid copies remain owned."
						)
					)
				)
			if _overlaps(reserve, other):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		if StadiumMoldedSeatItems.has_pad(layout):
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if StadiumPracticeFacilityItems._horizontal_overlap(reserve, pad):
					return (
						StadiumStarterLayout
						. _error(
							"Outfield bleachers must leave the selected molded-seat pad and access clear."
						)
					)
		checked.placements.append(placed)
		checked.outfield_bleacher_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "Outfield bleachers have not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func wall_eligible(graph: StadiumRecipeBoundary) -> bool:
	# This is a finite qualification of the two current owned recipe graphs.
	# Dormant height/offset/prototype classes cannot inherit this qualification.
	if (
		graph == null
		or graph._shape not in ["straight", "deeper_center"]
		or (
			graph.get_script() != StadiumRecipeBoundary
			and graph.get_script() != StadiumBoundaryOwnedGraph
		)
	):
		return false
	var back_seen: bool = false
	for segment: Dictionary in graph.segments():
		var expected: float = 1.20
		match segment.role:
			"BACK_WALL_TERMINAL":
				expected = 3.25
				back_seen = true
			"SIDE_RETURN_LIVE", "REAR_PERIMETER_DEAD", "DUGOUT_FACE_LIVE":
				expected = 1.20
			"DUGOUT_OPENING_DEAD":
				if not graph is StadiumBoundaryOwnedGraph:
					return false
				var owned: StadiumBoundaryOwnedGraph = graph as StadiumBoundaryOwnedGraph
				var side: String = (
					"DUGOUT-L" if String(segment.id).begins_with("DUGOUT-L") else "DUGOUT-R"
				)
				if owned.owned_sides.get(side) not in StadiumBoundaryItems.DUGOUTS:
					return false
				expected = (
					StadiumTimberDugoutContract.ENTRY_HEIGHT
					if owned.owned_sides[side] == "ST-032"
					else 2.40
				)
			_:
				return false
		var height: Variant = segment.get("height")
		if (
			not (height is int or height is float)
			or not is_finite(float(height))
			or float(height) != expected
		):
			return false
	return back_seen


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._supported(box, layout)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	return StadiumGroundBoxItems._outside_play(box, graph)


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	if PRICES.has(other.item):
		return StadiumPracticeFacilityItems._horizontal_overlap(reserve, bounds(other))
	return StadiumLandmarkItems._overlaps(reserve, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return StadiumRisingAppleItems.with_base(
			layout, place(StadiumRisingAppleItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.outfield_bleachers:
		if current.copy == copy and current.site == site:
			return result
	result.outfield_bleachers.append({"copy": copy, "site": site})
	result.outfield_bleachers.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return StadiumRisingAppleItems.with_base(
			layout, store_copy(StadiumRisingAppleItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("outfield_bleachers") is Array:
		result.outfield_bleachers = result.outfield_bleachers.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
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
											StadiumOutfieldPlazaItems.is_family(layout)
											or StadiumWaterfallLiveItems.is_family(layout)
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
		return StadiumRisingAppleItems.prune(layout)
	return with_base(layout, StadiumLandmarkItems.prune(base(layout)))

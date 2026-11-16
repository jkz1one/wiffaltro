class_name StadiumTreehouseItems
extends RefCounted
## One complete paid treehouse, including its own support tree. Scenery only.

const VERSION: int = 1
const PRICE_VERSION: int = 23
const LAYOUT_VERSION: int = 32
const FAMILY: String = "reference-treehouse-v32"
const PRICES: Dictionary = {"ST-045": [560, 170]}
const ITEMS: Array[String] = ["ST-045"]
const FIELDS: Array[String] = ["copy", "site"]
const ENVELOPE: AABB = AABB(Vector3(-3, 0, -3), Vector3(6, 7, 6))
const EPS: float = 0.0001
const SITES: Dictionary = {"TREEHOUSE-A": Vector3(-29, 0, 20)}


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumPracticeFacilityItems.upgrade(layout, access)
	if not StadiumPracticeFacilityItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["treehouses"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
			)
		)
	):
		return base(StadiumLandmarkItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumPracticeFacilityItems.LAYOUT_VERSION
	result.family = StadiumPracticeFacilityItems.FAMILY
	result.erase("treehouses")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
			)
		)
	):
		return StadiumLandmarkItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("treehouses") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumPracticeFacilityItems.is_family(original)
		else StadiumPracticeFacilityItems.with_base(base(layout), original)
	)
	if not StadiumPracticeFacilityItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["treehouses"] = layout.treehouses.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
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
	):
		return (
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
	return is_family(layout) and StadiumPracticeFacilityItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumPracticeFacilityItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumPracticeFacilityItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumPracticeFacilityItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 31,
				"optional_base": [28, 29],
				"models": StadiumTreehouseModels.VERSION,
				"site": [-29, 0, 20],
				"envelope": [-3, 0, -3, 6, 7, 6],
				"yaw": 0,
				"tiers": ["expanded", "club", "mogul"],
				"item": "ST-045",
				"copy_policy": "exact-owned-copy-store-first-v1",
				"bundled_support_tree": true,
				"shade_tree_grant": false,
				"shade_tree_consumption": false,
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "selected-boundary-slabs-and-full-occupied-reservations-v1",
				"selected_pad": "remove-empty-pad-first-v1",
				"pad_overlap_m2": 15,
				"ramp_overlap_m2": 4,
				"land_pocket_gap": 0.25,
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"climbing": false,
				"receiver": false,
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
			)
		)
	):
		return StadiumLandmarkItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumPracticeFacilityItems.geometry(tier, base(layout)),
				"treehouses": signature()
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
		return ClubAssetLedger._error("This item is not the complete paid treehouse.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The treehouse quote changed; reload before purchasing.")
	return result


static func sites(item: String = "ST-045") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
	return result


static func yaws(item: String = "ST-045") -> Array[int]:
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


static func envelope(item: String = "ST-045") -> AABB:
	return ENVELOPE if PRICES.has(item) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
			)
		)
	):
		return StadiumLandmarkItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("treehouses") is Array
		or layout.treehouses.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown treehouse layout or site capacity.")
	var checked: Dictionary = StadiumPracticeFacilityItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["treehouse_placements"] = []
	if layout.treehouses.is_empty():
		return checked
	if tier not in ["expanded", "club", "mogul"]:
		return StadiumStarterLayout._error(
			"The complete treehouse requires Expanded or larger property."
		)
	if StadiumMoldedSeatItems.has_pad(layout):
		return (
			StadiumStarterLayout
			. _error(
				(
					"TREEHOUSE-A overlaps the selected molded-seat pad and ramp; explicitly store the "
					+ "treehouse before selecting the pad, or store every seat and remove the empty pad "
					+ "before placing the treehouse. Storing seats alone does not remove the pad."
				)
			)
		)
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error(
			"The treehouse needs a verified complete selected field boundary."
		)
	var prior: String = ""
	for raw: Variant in layout.treehouses:
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
			or stock.copies[raw.copy].item != "ST-045"
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"TREEHOUSE-A needs one exact owned ST-045 copy; explicitly store its occupant or "
						+ "moving copy first."
					)
				)
			)
		var placed: Dictionary = row(raw.copy, "ST-045", raw.site)
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
						"TREEHOUSE-A needs its entire supported 6 by 6 by 7 m reservation inside the "
						+ "property and outside the selected field and boundary slabs."
					)
				)
			)
		for other: Dictionary in checked.placements:
			if _overlaps(reserve, other):
				return StadiumStarterLayout._error(
					(
						"TREEHOUSE-A conflicts with "
						+ other.site
						+ "; explicitly store one placement first."
					)
				)
		checked.placements.append(placed)
		checked.treehouse_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "The treehouse has not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._supported(box, layout)


static func _outside_play(box: AABB, graph: StadiumRecipeBoundary) -> bool:
	return StadiumGroundBoxItems._outside_play(box, graph)


static func _overlaps(reserve: AABB, other: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._overlaps(reserve, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
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
			)
		)
	):
		return StadiumLandmarkItems.with_base(
			layout, place(StadiumLandmarkItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.treehouses:
		if current.copy == copy and current.site == site:
			return result
	result.treehouses.append({"copy": copy, "site": site})
	result.treehouses.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
			)
		)
	):
		return StadiumLandmarkItems.with_base(
			layout, store_copy(StadiumLandmarkItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("treehouses") is Array:
		result.treehouses = result.treehouses.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
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
			)
		)
	):
		return StadiumLandmarkItems.prune(layout)
	return with_base(layout, StadiumPracticeFacilityItems.prune(base(layout)))

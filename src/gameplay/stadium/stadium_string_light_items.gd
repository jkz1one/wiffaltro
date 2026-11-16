class_name StadiumStringLightItems
extends RefCounted
## Working DG1 paid installation. Complete counts are NOT measured Night qualification.

const VERSION: int = 1
const PRICE_VERSION: int = 30
const LAYOUT_VERSION: int = 39
const FAMILY: String = "reference-string-lights-v39"
const ITEMS: Array[String] = ["ST-036"]
const PRICES: Dictionary = {"ST-036": [260, 45]}
const SITES: Dictionary = {
	"STR-LF": [Vector3(-25, 0, -7), Vector3(-25, 0, 7)],
	"STR-LD": [Vector3(-25, 0, 17), Vector3(-25, 0, 31)],
	"STR-RF": [Vector3(25, 0, -7), Vector3(25, 0, 7)],
	"STR-RD": [Vector3(25, 0, 17), Vector3(25, 0, 31)],
	"STR-BL": [Vector3(-15, 0, -9), Vector3(-1, 0, -9)],
	"STR-BR": [Vector3(1, 0, -9), Vector3(15, 0, -9)],
	"STR-BC": [Vector3(-7, 0, -9), Vector3(7, 0, -9)]
}
const PRESETS: Dictionary = {
	"FESTOON-6X036-DG1": ["STR-BL", "STR-BR", "STR-LD", "STR-LF", "STR-RD", "STR-RF"],
	"MIXED-2X037-3X036-DG1": ["STR-BC", "STR-LF", "STR-RF"]
}
const EXCLUSIONS: Dictionary = {
	"STR-LF": ["YLIGHT-FL", "YS-L2", "YL-L"],
	"STR-RF": ["YLIGHT-FR", "YS-R2", "YL-R"],
	"STR-LD": ["YLIGHT-RL", "TREE-L"],
	"STR-RD": ["YLIGHT-RR", "TREE-R"],
	"STR-BL": ["STR-BC", "SIGN-GROUND-L", "FLAG-GROUND-L"],
	"STR-BR": ["STR-BC", "SIGN-GROUND-R", "FLAG-GROUND-R"],
	"STR-BC": ["STR-BL", "STR-BR"]
}
const UNSUPPORTED_CHANNELS: Array[String] = [
	"hosts",
	"roofs",
	"facilities",
	"floodlights",
	"mounted_displays",
	"player_tunnels",
	"wall_top_terrace",
	"practice_facilities",
	"treehouses",
	"landmarks",
	"outfield_bleachers",
	"rising_apple"
]
const UNQUALIFIED: String = \
	("String-light installation is a Working DG1 candidate. Even a complete " + \
	"Festoon or Mixed preset is daylight-only until its actual rig and " + \
	"ball readability are qualified.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumMountedDisplayItems.upgrade(layout, access)
	if not StadiumMountedDisplayItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["string_lights"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return base(StadiumSalvageCarItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumMountedDisplayItems.LAYOUT_VERSION
	result.family = StadiumMountedDisplayItems.FAMILY
	result.erase("string_lights")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumSalvageCarItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("string_lights") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumMountedDisplayItems.is_family(original)
		else StadiumMountedDisplayItems.with_base(base(layout), original)
	)
	if not StadiumMountedDisplayItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["string_lights"] = layout.string_lights.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
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
	):
		return (
			StadiumSalvageCarItems.is_terrain(layout)
			or (
				StadiumMasteryBannerItems.is_terrain(layout)
				or (
					StadiumWaterfallItems.is_terrain(layout)
					or (
						StadiumLightingKitItems.is_terrain(layout)
						or (
							StadiumOutfieldPlazaItems.is_terrain(layout)
							or StadiumWaterfallLiveItems.is_terrain(layout)
						)
					)
				)
			)
		)
	return is_family(layout) and StadiumMountedDisplayItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumMountedDisplayItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumMountedDisplayItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumMountedDisplayItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 38,
				"model": StadiumStringLightModels.VERSION,
				"sites": var_to_str(SITES),
				"presets": PRESETS,
				"exclusions": EXCLUSIONS,
				"unsupported_channels": UNSUPPORTED_CHANNELS,
				"copy_policy": "one-fixed-span-two-included-posts",
				"backyard_bridge": "canonical-empty-30-through-38-on-base28-v1",
				"boundary": "exact-straight-polygon-no-owned-dugout-openings-v1",
				"reserve": "two-half-meter-ground-post-clearances-and-overhead-corridor",
				"night": false
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
	):
		return StadiumSalvageCarItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumMountedDisplayItems.geometry(tier, base(layout)),
				"strings": signature()
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
		return ClubAssetLedger._error("This item is not a complete owned string-light span.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The string-light quote changed; reload before purchasing.")
	return result


static func site_name(site: String) -> String:
	return site + " • fixed 14m span with two included supports" if SITES.has(site) else "Stored"


static func row(copy: String, site: String) -> Dictionary:
	if not SITES.has(site):
		return {}
	var direction: Vector3 = SITES[site][1] - SITES[site][0]
	return {
		"copy": copy,
		"item": "ST-036",
		"site": site,
		"position": SITES[site][0],
		"yaw": rad_to_deg(atan2(-direction.z, direction.x)),
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-036") -> AABB:
	return StadiumStringLightModels.envelope(item)


static func bounds(placed: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(placed.yaw))), placed.position) * envelope()
	)


static func reservations(site: String) -> Array[AABB]:
	var result: Array[AABB] = []
	if not SITES.has(site):
		return result
	for point: Vector3 in SITES[site]:
		result.append(AABB(point + Vector3(-0.5, 0, -0.5), Vector3(1, 6.15, 1)))
	var a: Vector3 = SITES[site][0]
	var b: Vector3 = SITES[site][1]
	result.append(
		AABB(
			Vector3(minf(a.x, b.x) - 0.15, 5.2, minf(a.z, b.z) - 0.15),
			Vector3(absf(b.x - a.x) + 0.3, 0.95, absf(b.z - a.z) + 0.3)
		)
	)
	return result


static func conflicts(site: String, other: Dictionary) -> bool:
	if not SITES.has(site):
		return true
	if EXCLUSIONS[site].has(other.get("site", "")):
		return true
	var boxes: Array[AABB] = []
	if other.get("item", "") == "ST-036":
		boxes = reservations(other.site)
	else:
		boxes.append(StadiumHomeLayout.bounds(other))
		if boxes[0].size.is_zero_approx():
			return true  # Unknown full envelopes are not permission to overlap.
	for own: AABB in reservations(site):
		for box: AABB in boxes:
			if own.intersects(box):
				return true
	return false


static func complete_profile(strings: Array, poles: Array) -> String:
	var sites: Array[String] = []
	var light_sites: Array[String] = []
	for raw: Variant in strings:
		if not raw is Dictionary or not raw.get("site") is String or sites.has(raw.site):
			return ""
		sites.append(raw.site)
	for raw: Variant in poles:
		if not raw is Dictionary or not raw.get("site") is String or light_sites.has(raw.site):
			return ""
		light_sites.append(raw.site)
	sites.sort()
	light_sites.sort()
	if sites == PRESETS["FESTOON-6X036-DG1"] and light_sites.is_empty():
		return "FESTOON-6X036-DG1"
	if sites == PRESETS["MIXED-2X037-3X036-DG1"] and light_sites == ["YLIGHT-RL", "YLIGHT-RR"]:
		return "MIXED-2X037-3X036-DG1"
	return ""


static func _validate_base(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	var original: Dictionary = base(layout)
	if tier != "backyard":
		return StadiumMountedDisplayItems.validate(original, stock, tier)
	# Frozen family30 rejects Backyard even when empty. Only new family39 can bridge
	# a canonical EMPTY 30..38 chain on family28. Never admit the family29 seat pad,
	# nonempty later channels, extra keys, changed ancestry or malformed wrappers.
	var lower: Dictionary = StadiumGroundBoxItems.base(original)
	if (
		not StadiumSmallYardSceneryItems.is_family(lower)
		or not ClubCareer.same(original, StadiumMountedDisplayItems.upgrade(lower))
	):
		return StadiumStarterLayout._error(
			"Backyard strings require canonical empty stadium wrappers and no fixed seat pad."
		)
	var checked: Dictionary = StadiumSmallYardSceneryItems.validate(lower, stock, tier)
	if not checked.ok:
		return checked
	for channel: String in [
		"ground_box_placements",
		"practice_facility_placements",
		"treehouse_placements",
		"landmark_placements",
		"outfield_bleacher_placements",
		"rising_apple_placements",
		"wall_top_terrace_placements",
		"player_tunnel_placements",
		"mounted_display_placements"
	]:
		checked[channel] = []
	return checked


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
	):
		return StadiumSalvageCarItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("string_lights") is Array
		or layout.string_lights.size() > 6
	):
		return StadiumStarterLayout._error("Unknown string-light layout or fixed span capacity.")
	var checked: Dictionary = _validate_base(layout, stock, tier)
	if not checked.ok:
		return checked
	checked["string_light_placements"] = []
	checked["string_light_complete"] = false
	checked["string_light_profile"] = ""
	if layout.string_lights.is_empty():
		return checked  # Exactly preserve inherited eligibility when all spans are stored.
	for channel: String in UNSUPPORTED_CHANNELS:
		if not layout.get(channel, []).is_empty():
			return (
				StadiumStarterLayout
				. _error(
					(
						"DG1 currently supports STRUCT-YARD only; installed stadium structures require a "
						+ "separately qualified record."
					)
				)
			)
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if (
		graph == null
		or graph.polygon() != StadiumRecipeBoundary.create("straight").polygon()
		or (graph is StadiumBoundaryOwnedGraph and not graph.owned_sides.is_empty())
	):
		return (
			StadiumStarterLayout
			. _error(
				(
					"DG1 strings require the unchanged complete reference STRAIGHT field, not an angled "
					+ "or unverified boundary."
				)
			)
		)
	var prior: String = ""
	for raw: Variant in layout.string_lights:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, ["copy", "site"])
			or not raw.copy is String
			or not raw.site is String
			or not SITES.has(raw.site)
			or raw.site <= prior
			or stock == null
			or not stock.copies.has(raw.copy)
			or stock.copies[raw.copy].item != "ST-036"
			or not checked.stored.has(raw.copy)
		):
			return StadiumStarterLayout._error(
				"Each fixed span socket requires one distinct matching owned ST-036 copy."
			)
		for box: AABB in reservations(raw.site):
			if (
				not StadiumProperty.contains(tier, box)
				or not StadiumLandscapeOwnedItems._supported(box, layout)
			):
				return (
					StadiumStarterLayout
					. _error(
						"The whole string-light installation needs level supported clearance inside owned property."
					)
				)
		for other: Dictionary in checked.placements:
			if conflicts(raw.site, other):
				return StadiumStarterLayout._error(
					(
						raw.site
						+ " conflicts with "
						+ other.site
						+ "; explicitly Store a complete copy first."
					)
				)
		var placed: Dictionary = row(raw.copy, raw.site)
		checked.placements.append(placed)
		checked.string_light_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	checked.string_light_profile = complete_profile(layout.string_lights, layout.get("lights", []))
	checked.string_light_complete = not checked.string_light_profile.is_empty()
	checked.night_qualified = false
	checked["night_unqualified_reason"] = UNQUALIFIED
	return checked


static func place(
	layout: Dictionary, stock: StadiumStock, copy: String, site: String, access: Array[String] = []
) -> Dictionary:
	if (
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
	):
		return StadiumSalvageCarItems.with_base(
			layout, place(StadiumSalvageCarItems.base(layout), stock, copy, site, access)
		)
	if site.is_empty():
		return store_copy(layout, copy)
	if (
		stock == null
		or not stock.copies.has(copy)
		or stock.copies[copy].item != "ST-036"
		or not SITES.has(site)
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	result.string_lights = result.string_lights.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	result.string_lights.append({"copy": copy, "site": site})
	result.string_lights.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result  # Public Apply validates conflicts atomically; no implicit displacement.


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
	):
		return StadiumSalvageCarItems.with_base(
			layout, store_copy(StadiumSalvageCarItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("string_lights") is Array:
		result.string_lights = result.string_lights.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumSalvageCarItems.with_base(layout, prune(StadiumSalvageCarItems.base(layout)))
	return with_base(layout, StadiumMountedDisplayItems.prune(base(layout)))

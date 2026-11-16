class_name StadiumLightingKitItems
extends RefCounted
## Whole paid entry-tier lighting kit. Freely switchable patterns; no implicit legacy conversion.

const VERSION: int = 1
const PRICE_VERSION: int = 33
const LAYOUT_VERSION: int = 43
const FAMILY: String = "reference-lighting-kit-v43"
const PRICES: Dictionary = {"ST-111": [260, 120]}
const ITEMS: Array[String] = ["ST-111"]
const FIELDS: Array[String] = ["copy", "site"]
const PATTERNS: Array[String] = ["PARALLEL", "ZIGZAG", "PERIMETER", "MIXED_EDGE"]
const UNQUALIFIED: String = ("Working entry-tier lighting kit: installed illumination is not " + \
	"qualified for season Night until moving-ball readability is verified.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}  # ST-006 retains its exact separate owned route.
	var result: Dictionary = StadiumWaterfallItems.upgrade(layout, access)
	if not StadiumWaterfallItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["lighting_kits"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return base(StadiumOutfieldPlazaItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumWaterfallItems.LAYOUT_VERSION
	result.family = StadiumWaterfallItems.FAMILY
	result.erase("lighting_kits")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return StadiumOutfieldPlazaItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("lighting_kits") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumWaterfallItems.is_family(original)
		else StadiumWaterfallItems.with_base(base(layout), original)
	)
	if not StadiumWaterfallItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["lighting_kits"] = layout.lighting_kits.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return (
			StadiumOutfieldPlazaItems.is_terrain(layout)
			or StadiumWaterfallLiveItems.is_terrain(layout)
		)
	return is_family(layout) and StadiumWaterfallItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumWaterfallItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumWaterfallItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumWaterfallItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 42,
				"model": StadiumLightingKitModels.signature(),
				"patterns": PATTERNS,
				"capacity": 1,
				"copy_policy": "one-complete-kit-free-atomic-pattern-switch-v1",
				"legacy": "ST-036-unchanged-no-conversion",
				"yard_poles": "separately-owned-ST-037",
				"boundary": "unchanged-reference-straight",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"clearance": "each-post-1m-from-live-line-and-overhead-corridor-v1",
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
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return StadiumOutfieldPlazaItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumWaterfallItems.geometry(tier, base(layout)),
				"lighting_kits": signature()
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
		return ClubAssetLedger._error("This item is not the complete paid lighting kit.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The lighting-kit quote changed; reload before purchasing.")
	return result


static func sites(item: String = "ST-111") -> Array[String]:
	return PATTERNS.duplicate() if PRICES.has(item) else []


static func yaws(item: String = "ST-111") -> Array[int]:
	var result: Array[int] = []
	if PRICES.has(item):
		result.append(0)
	return result


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or not PATTERNS.has(site) or not is_finite(yaw) or yaw != 0.0:
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": Vector3.ZERO,
		"yaw": 0,
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-111", site: String = "PARALLEL") -> AABB:
	return StadiumLightingKitModels.envelope(item, site)


static func bounds(placed: Dictionary) -> AABB:
	return envelope(placed.item, placed.site)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return StadiumOutfieldPlazaItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("lighting_kits") is Array
		or layout.lighting_kits.size() > 1
	):
		return StadiumStarterLayout._error("Unknown lighting-kit layout or whole-kit capacity.")
	var checked: Dictionary = StadiumWaterfallItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["lighting_kit_placements"] = []
	if layout.lighting_kits.is_empty():
		return checked
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if (
		graph == null
		or graph.polygon() != StadiumRecipeBoundary.create("straight").polygon()
		or (graph is StadiumBoundaryOwnedGraph and not graph.owned_sides.is_empty())
	):
		return StadiumStarterLayout._error(
			"The entry kit requires the unchanged complete reference STRAIGHT field."
		)
	for raw: Variant in layout.lighting_kits:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, FIELDS)
			or not raw.copy is String
			or not raw.site is String
			or not PATTERNS.has(raw.site)
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or not PRICES.has(stock.copies[raw.copy].item)
		):
			return StadiumStarterLayout._error(
				"Select one exact owned ST-111 kit; all other copies remain stored."
			)
		var placed: Dictionary = row(raw.copy, stock.copies[raw.copy].item, raw.site)
		for component: Dictionary in StadiumLightingKitModels.components(raw.site):
			var reserve: AABB = component.bounds
			if not StadiumProperty.contains(tier, reserve):
				return StadiumStarterLayout._error(
					"Every kit support and cable must remain inside owned property."
				)
			if (
				component.kind == "post"
				and (not _supported(reserve, layout) or not _outside_play(reserve, graph))
			):
				return StadiumStarterLayout._error(
					"Kit supports need level ground outside the live field and boundary slabs."
				)
			if StadiumMoldedSeatItems.has_pad(layout):
				for pad: AABB in StadiumMoldedSeatItems.reservations():
					if reserve.intersects(pad):
						return StadiumStarterLayout._error(
							"The kit must leave the full selected seat pad and access clear."
						)
			for other: Dictionary in checked.placements:
				var obstacles: Array = (
					StadiumStringLightItems.reservations(other.site)
					if other.item == "ST-036"
					else [StadiumHomeLayout.bounds(other)]
				)
				for obstacle: AABB in obstacles:
					if reserve.intersects(obstacle):
						return StadiumStarterLayout._error(
							(
								"This kit pattern conflicts with "
								+ other.site
								+ "; store that complete copy or choose another pattern."
							)
						)
		checked.placements.append(placed)
		checked.lighting_kit_placements.append(placed)
		checked.stored.erase(raw.copy)
	checked.night_qualified = false
	checked["night_unqualified_reason"] = UNQUALIFIED
	return checked


static func _supported(box: AABB, layout: Dictionary) -> bool:
	return StadiumPracticeFacilityItems._supported(box, layout)


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
				< 1.0 - 0.0001
			):
				return false
	# Runtime slabs use the selected graph's mitered outer vertices. Clearance is
	# Kit contract: at least 1m from live boundary plus no actual slab overlap.
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
		return StadiumPracticeFacilityItems._horizontal_overlap(reserve, bounds(other))
	return StadiumPracticeFacilityItems._horizontal_overlap(
		reserve, StadiumHomeLayout.bounds(other)
	)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return StadiumOutfieldPlazaItems.with_base(
			layout, place(StadiumOutfieldPlazaItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.lighting_kits:
		if current.copy == copy and current.site == site:
			return result
	# One owned kit switches atomically, never displacing another owned kit.
	result.lighting_kits = result.lighting_kits.filter(
		func(value: Dictionary) -> bool: return value.copy != copy
	)
	result.lighting_kits.append({"copy": copy, "site": site})
	result.lighting_kits.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return StadiumOutfieldPlazaItems.with_base(
			layout, store_copy(StadiumOutfieldPlazaItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("lighting_kits") is Array:
		result.lighting_kits = result.lighting_kits.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if StadiumOutfieldPlazaItems.is_family(layout) or StadiumWaterfallLiveItems.is_family(layout):
		return StadiumOutfieldPlazaItems.prune(layout)
	return with_base(layout, StadiumWaterfallItems.prune(base(layout)))

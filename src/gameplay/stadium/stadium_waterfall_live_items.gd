class_name StadiumWaterfallLiveItems
extends RefCounted
## Explicit full-scale live installation of the existing paid ST046 copy.
## Decorative LANDMARK-A and plaza placements remain independent, out of play.
const Base = preload("res://src/gameplay/stadium/stadium_outfield_plaza_items.gd")
const VERSION: int = 1
const LAYOUT_VERSION: int = 45
const FAMILY: String = "reference-live-waterfall-v45"
const FIELDS: Array[String] = ["copy", "site"]
const NIGHT_REASON: String = ("The full-scale live waterfall is daylight-only until its exact " + \
	"lighting and camera coverage are qualified.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = Base.upgrade(layout, access)
	if not Base.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["live_waterfalls"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = Base.LAYOUT_VERSION
	result.family = Base.FAMILY
	result.erase("live_waterfalls")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if not is_family(layout) or not layout.get("live_waterfalls") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if Base.is_family(original)
		else Base.with_base(base(layout), original)
	)
	if not Base.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["live_waterfalls"] = layout.live_waterfalls.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and Base.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return Base.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, Base.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return Base.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 44,
				"item": "ST-046",
				"site": "WF-LIVE-LF",
				"position": [-10.2, 0, 19.4],
				"reservation": [9, 4, 7],
				"model": 1,
				"route": 1,
				"witness": 1,
				"quiet": [0.05, 0.005, 0.30, 0.15],
				"live_units": 4,
				"companions": 0,
				"copy_policy": "exact-owned-copy-store-first-v1",
				"tier": "mogul",
				"night": false,
				"rule":
				(
					"native-solid-stays-live-witnessed-unreachable-basin-minimum-single-preserve-floor-fo"
					+ "ul-first-v1"
				)
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	return (
		JSON
		. stringify(
			{"base": Base.geometry(tier, base(layout)), "live_waterfall": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func row(copy: String, site: String = StadiumWaterfallLiveSites.SITE) -> Dictionary:
	if copy.is_empty() or site != StadiumWaterfallLiveSites.SITE:
		return {}
	return {
		"copy": copy,
		"item": "ST-046",
		"site": site,
		"position": StadiumWaterfallLiveSites.CENTER,
		"yaw": 0,
		"role": "LIVE_RICOCHET"
	}


static func bounds(_placed: Dictionary) -> AABB:
	return StadiumWaterfallLiveSites.reservation()


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("live_waterfalls") is Array
		or layout.live_waterfalls.size() > 1
	):
		return StadiumStarterLayout._error("Unknown live-waterfall layout or capacity.")
	var checked: Dictionary = Base.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["live_waterfalls_placements"] = []
	if layout.live_waterfalls.is_empty():
		return checked
	var raw: Variant = layout.live_waterfalls[0]
	if (
		not raw is Dictionary
		or not SeasonOwnership._keys(raw, FIELDS)
		or not raw.copy is String
		or not raw.site is String
		or raw.site != StadiumWaterfallLiveSites.SITE
		or stock == null
		or not stock.copies.has(raw.copy)
		or stock.copies[raw.copy].item != "ST-046"
		or not checked.stored.has(raw.copy)
	):
		return (
			StadiumStarterLayout
			. _error(
				(
					"The live waterfall needs one exact stored ST046 copy and its explicit qualified "
					+ "site. Store before moving."
				)
			)
		)
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	if not StadiumWaterfallLiveSites.geometry_legal(
		tier, graph_for(layout), field, int(checked.get("live_units", 0))
	):
		return (
			StadiumStarterLayout
			. _error(
				(
					"The full-scale live waterfall requires Mogul, all four live units, clear stock "
					+ "defender anchors and a complete legal boundary. No live companions are qualified."
				)
			)
		)
	var placed: Dictionary = row(raw.copy, raw.site)
	var reserve: AABB = bounds(placed)
	if not StadiumPracticeFacilityItems._supported(reserve, base(layout)):
		return StadiumStarterLayout._error(
			"The entire live-waterfall reservation needs level supported ground."
		)
	for other: Dictionary in checked.placements:
		var obstacles: Array[AABB] = (
			StadiumOutfieldPlazaRecipes.reservations(other.recipe)
			if other.item == "ST-112"
			else Base._obstacles(other)
		)
		for obstacle: AABB in obstacles:
			if StadiumPracticeFacilityItems._horizontal_overlap(reserve, obstacle):
				return StadiumStarterLayout._error(
					(
						"Live waterfall conflicts with "
						+ other.site
						+ "; explicitly Store one placement first."
					)
				)
	if StadiumMoldedSeatItems.has_pad(base(layout)):
		for pad: AABB in StadiumMoldedSeatItems.reservations():
			if StadiumPracticeFacilityItems._horizontal_overlap(reserve, pad):
				return StadiumStarterLayout._error(
					"Live waterfall must leave the molded-seat pad and access clear."
				)
	checked.stored.erase(raw.copy)
	checked.placements.append(placed)
	checked.live_waterfalls_placements.append(placed)
	checked.live_units = StadiumWaterfallLiveSites.LIVE_UNITS
	checked.night_qualified = false
	checked["night_unqualified_reason"] = NIGHT_REASON
	return checked


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
		or stock.copies[copy].item != "ST-046"
		or site != StadiumWaterfallLiveSites.SITE
		or not is_finite(yaw)
		or yaw != 0.0
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	if result.live_waterfalls.is_empty():
		result.live_waterfalls.append({"copy": copy, "site": site})
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("live_waterfalls") is Array:
		result.live_waterfalls = result.live_waterfalls.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	return with_base(layout, Base.prune(base(layout)))

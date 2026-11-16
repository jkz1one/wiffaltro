class_name StadiumGroundPropsItems
extends RefCounted
## BN planting sockets and BS live recipes; the entire paid flag/terrain base survives.

const VERSION: int = 1
const PRICE_VERSION: int = 11
const LAYOUT_VERSION: int = 19
const FAMILY: String = "reference-ground-props-v19"
const PRICES: Dictionary = {
	"ST-004": [240, 70],
	"ST-008": [190, 55],
	"ST-009": [145, 40],
	"ST-010": [240, 70],
	"ST-011": [260, 75],
	"ST-012": [430, 130],
	"ST-015": [140, 35],
	"ST-016": [145, 40],
	"ST-017": [220, 65]
}
const PLANTS: Array[String] = ["ST-015", "ST-016", "ST-017"]
const LIVE: Array[String] = ["ST-004", "ST-008", "ST-009", "ST-010", "ST-011", "ST-012"]
const SITES: Dictionary = {
	"BED-L": {"items": ["ST-017"], "position": Vector3(-18.5, 0, -5.5), "yaw": 0},
	"BED-R": {"items": ["ST-017"], "position": Vector3(18.5, 0, -5.5), "yaw": 0},
	"O-L1": {"items": ["ST-008", "ST-009"], "position": Vector3(-8, 0, 14), "yaw": 0},
	"O-L2": {"items": ["ST-008", "ST-009"], "position": Vector3(-11, 0, 19), "yaw": 0},
	"O-R1": {"items": ["ST-008", "ST-009"], "position": Vector3(8, 0, 14), "yaw": 0},
	"O-R2": {"items": ["ST-008", "ST-009"], "position": Vector3(11, 0, 19), "yaw": 0},
	"OL-L": {"items": ["ST-012"], "position": Vector3(-12, 0, 18), "yaw": 0},
	"OL-R": {"items": ["ST-012"], "position": Vector3(12, 0, 18), "yaw": 0},
	"OM-L": {"items": ["ST-004", "ST-010", "ST-011"], "position": Vector3(-10, 0, 16), "yaw": 0},
	"OM-R": {"items": ["ST-004", "ST-010", "ST-011"], "position": Vector3(10, 0, 16), "yaw": 0},
	"PLANT-L1": {"items": ["ST-015", "ST-016"], "position": Vector3(-18.5, 0, -7), "yaw": 0},
	"PLANT-L2": {"items": ["ST-015", "ST-016"], "position": Vector3(-18.5, 0, -4), "yaw": 0},
	"PLANT-R1": {"items": ["ST-015", "ST-016"], "position": Vector3(18.5, 0, -7), "yaw": 0},
	"PLANT-R2": {"items": ["ST-015", "ST-016"], "position": Vector3(18.5, 0, -4), "yaw": 0}
}


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func signature() -> String:
	var sites: Dictionary = {}
	for id: String in SITES:
		var row: Dictionary = SITES[id]
		sites[id] = {
			"items": row.items,
			"position": [row.position.x, row.position.y, row.position.z],
			"yaw": row.yaw
		}
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"model": StadiumGroundPropsModels.VERSION,
				"sites": sites,
				"base": 18,
				"limits": [4, 4],
				"traps": []
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
		return ClubAssetLedger._error("This item is not in the ground-prop catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The ground-prop quote changed; reload before purchasing.")
	return result


static func is_family(layout: Variant) -> bool:
	return (
		layout is Dictionary
		and SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumFlagItems.is_terrain(base(layout))


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var original: Dictionary = StadiumFlagItems.upgrade(layout, access)
	if not StadiumFlagItems.is_family(original):
		return {}
	original.version = LAYOUT_VERSION
	original.family = FAMILY
	original["props"] = []
	return original


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumFlagItems.LAYOUT_VERSION
	result.family = StadiumFlagItems.FAMILY
	result.erase("props")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if not is_family(layout) or not layout.get("props") is Array:
		return {}
	var inner: Dictionary = (
		original.duplicate(true)
		if StadiumFlagItems.is_family(original)
		else StadiumFlagItems.with_base(base(layout), original)
	)
	if not StadiumFlagItems.is_family(inner):
		return {}
	inner.version = LAYOUT_VERSION
	inner.family = FAMILY
	inner["props"] = layout.props.duplicate(true)
	return inner


static func validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("props") is Array
		or layout.props.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown ground-prop layout or sites.")
	var checked: Dictionary = StadiumFlagItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	var prior: String = ""
	var occupied: Dictionary = {}
	var live_items: Array = []
	for row: Dictionary in checked.placements:
		occupied[row.site] = row
		if row.role == "LIVE_RICOCHET":
			live_items.append(row.item)
	for raw: Variant in layout.props:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, ["copy", "site"])
			or not raw.copy is String
			or not raw.site is String
			or raw.site <= prior
			or not SITES.has(raw.site)
			or not checked.stored.has(raw.copy)
			or occupied.has(raw.site)
		):
			return StadiumStarterLayout._error(
				"Each prop needs one distinct owned copy and canonical compatible site."
			)
		var item: String = stock.copies[raw.copy].item
		var site: Dictionary = SITES[raw.site]
		if not site.items.has(item):
			return StadiumStarterLayout._error("This prop does not fit the selected site class.")
		var row: Dictionary = {
			"copy": raw.copy,
			"site": raw.site,
			"item": item,
			"position": site.position,
			"yaw": site.yaw,
			"role": "DECORATIVE_AFTER_TERMINAL" if PLANTS.has(item) else "LIVE_RICOCHET"
		}
		var box: AABB = bounds(row)
		if not StadiumProperty.contains(tier, box) or not _supported(box, layout):
			return StadiumStarterLayout._error("The full prop needs supported property clearance.")
		if PLANTS.has(item) and not StadiumClubSites._outside(box):
			return StadiumStarterLayout._error("Planting sockets must remain outside live play.")
		if LIVE.has(item):
			live_items.append(item)
			if not _inside(box):
				return StadiumStarterLayout._error(
					"Live props must clear the physical field perimeter."
				)
		for previous: Dictionary in checked.placements:
			if box.intersects(StadiumHomeLayout.bounds(previous)):
				return StadiumStarterLayout._error(
					"Store the conflicting item before placing this prop."
				)
		checked.stored.erase(raw.copy)
		checked.placements.append(row)
		occupied[raw.site] = row
		prior = raw.site
	if not StadiumCatalog.within_live_budget(live_items):
		return StadiumStarterLayout._error(
			"Live props allow at most four instances and four capacity units."
		)
	for side: String in ["L", "R"]:
		if (
			occupied.has("OM-" + side)
			and (occupied.has("O-" + side + "1") or occupied.has("O-" + side + "2"))
		):
			return StadiumStarterLayout._error(
				"The medium site needs both same-side small sites clear."
			)
		if (
			occupied.has("BED-" + side)
			and (occupied.has("PLANT-" + side + "1") or occupied.has("PLANT-" + side + "2"))
		):
			return StadiumStarterLayout._error(
				"Store the small plants before placing their shared flowerbed."
			)
	var units: int = 0
	for item: String in live_items:
		units += int(StadiumCatalog.LIVE_UNITS[item])
	checked.live_units = units
	return checked


static func bounds(row: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(row.yaw)), row.position)
		* StadiumGroundPropsModels.envelope(row.item)
	)


static func _supported(box: AABB, layout: Dictionary) -> bool:
	if not is_terrain(layout):
		return true
	var contract: Dictionary = terrain_contract(layout)
	if contract.is_empty():
		return false
	for point: Vector2 in [
		Vector2(box.position.x, box.position.z),
		Vector2(box.end.x, box.position.z),
		Vector2(box.position.x, box.end.z),
		Vector2(box.end.x, box.end.z)
	]:
		var support: Dictionary = StadiumSurfaceTerrain.support(point, contract.mode)
		if support.is_empty() or support.support_height != 0.0:
			return false
	return not (
		Rect2(Vector2(box.position.x, box.position.z), Vector2(box.size.x, box.size.z))
		. intersects(StadiumSurfaceTerrain.PATCH)
	)


static func _inside(box: AABB) -> bool:
	for segment: Dictionary in StadiumBoundaryGraph.segments():
		for index in range(8):
			var point: Vector3 = box.get_endpoint(index)
			if (
				(Vector2(point.x, point.z) - segment.a).dot(StadiumBoundaryGraph.inward(segment))
				< 0.5
			):
				return false
	return true


static func geometry(tier: String, layout: Dictionary) -> String:
	return (
		JSON
		. stringify(
			{"base": StadiumFlagItems.geometry(tier, base(layout)), "props": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumFlagItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumFlagItems.contacts_layout(base(layout)))

class_name StadiumFlagItems
extends RefCounted
## Closed paid flag family. The complete flat/terrain base is retained, never flattened on adoption.

const VERSION: int = 1
const PRICE_VERSION: int = 10
const LAYOUT_VERSION: int = 18
const FAMILY: String = "reference-club-flags-v18"
const SITES: Dictionary = {
	"FLAG-GROUND-L": {"item": "ST-043", "position": Vector3(-12, 0, -8), "yaw": 0},
	"FLAG-GROUND-R": {"item": "ST-043", "position": Vector3(12, 0, -8), "yaw": 0}
}


static func price_signature() -> String:
	return (
		JSON
		. stringify({"version": PRICE_VERSION, "prices": {"ST-043": [190, 55]}}, "", true, true)
		. sha256_text()
	)


static func signature() -> String:
	var sites: Dictionary = {}
	for id: String in SITES:
		var row: Dictionary = SITES[id]
		sites[id] = {
			"item": row.item,
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
				"model": StadiumFlagModels.VERSION,
				"sites": sites,
				"envelope": [-0.30, 0, -0.30, 1.50, 3.60, 0.60],
				"bases": [12, 17]
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
	if stock == null or item != "ST-043":
		return ClubAssetLedger._error("This item is not in the club-flag catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else 190
	if result.ok and (result.blueprint_cost != blueprint or result.copy_cost != 55 * quantity):
		return ClubAssetLedger._error("The flag quote changed; reload before purchasing.")
	return result


static func is_family(layout: Variant) -> bool:
	return (
		layout is Dictionary
		and SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and SeasonOwnership._whole(layout.get("base_version"), 17, 17)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var original: Dictionary = (
		layout.duplicate(true)
		if layout.get("version") == 17
		else StadiumSurfaceLayout.upgrade(layout, access)
	)
	if (
		not SeasonOwnership._whole(original.get("version"), 12, 12)
		and not SeasonOwnership._whole(original.get("version"), 17, 17)
	):
		return {}
	original["base_version"] = int(original.version)
	original.version = LAYOUT_VERSION
	original.family = FAMILY
	original["flags"] = []
	return original


static func base(layout: Dictionary) -> Dictionary:
	if (
		not is_family(layout)
		or not SeasonOwnership._whole(layout.get("base_version"), 12, 17)
		or int(layout.base_version) not in [12, 17]
	):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = int(layout.base_version)
	result.family = (
		StadiumSurfaceLayout.TERRAIN_FAMILY
		if result.version == 17
		else "reference-surface-finishes-v12"
	)
	result.erase("base_version")
	result.erase("flags")
	return result


static func validate_rows(
	rows: Variant, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if (
		not rows is Array
		or stock == null
		or StadiumStock.from_data(stock.to_data()) == null
		or rows.size() > SITES.size()
		or not StadiumLand.TIERS.has(tier)
	):
		return StadiumStarterLayout._error("Invalid club-flag ownership or sites.")
	var previous: String = ""
	var used: Array[String] = []
	var placements: Array = []
	for row: Variant in rows:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(row, ["copy", "site"])
			or not row.copy is String
			or not row.site is String
			or not SITES.has(row.site)
			or row.site <= previous
			or used.has(row.copy)
			or not stock.copies.has(row.copy)
		):
			return StadiumStarterLayout._error(
				"Each flag needs one distinct compatible owned copy."
			)
		var site: Dictionary = SITES[row.site]
		if stock.copies[row.copy].item != site.item:
			return StadiumStarterLayout._error("This copy is not a club flag.")
		var box: AABB = (
			Transform3D(Basis(Vector3.UP, deg_to_rad(site.yaw)), site.position)
			* StadiumFlagModels.ENVELOPE
		)
		if not StadiumProperty.contains(tier, box) or not StadiumClubSites._outside(box):
			return StadiumStarterLayout._error(
				"The full flag needs outside-play property clearance."
			)
		placements.append(
			{
				"copy": row.copy,
				"site": row.site,
				"item": site.item,
				"position": site.position,
				"yaw": site.yaw,
				"role": "DECORATIVE_AFTER_TERMINAL"
			}
		)
		used.append(row.copy)
		previous = row.site
	return {"ok": true, "error": "", "placements": placements, "live_units": 0}


static func validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if not is_family(layout) or layout.get("family") != FAMILY or not layout.has("flags"):
		return StadiumStarterLayout._error("Unknown club-flag layout.")
	var original: Dictionary = base(layout)
	if original.is_empty():
		return StadiumStarterLayout._error("Unknown club-flag field base.")
	var checked: Dictionary = (
		StadiumSurfaceLayout.validate_terrain(original, stock, tier)
		if is_terrain(layout)
		else StadiumSurfaceLayout.validate(original, stock, tier)
	)
	if not checked.ok:
		return checked
	var flags: Dictionary = validate_rows(layout.flags, stock, tier)
	if not flags.ok:
		return flags
	for row: Dictionary in flags.placements:
		if not checked.stored.has(row.copy):
			return StadiumStarterLayout._error("A flag copy is already installed elsewhere.")
		checked.stored.erase(row.copy)
		checked.placements.append(row)
	return checked


static func geometry(tier: String, layout: Dictionary) -> String:
	var original: Dictionary = base(layout)
	if original.is_empty():
		return ""
	return (
		JSON
		. stringify(
			{"base": StadiumOwnedLayout.geometry(tier, original), "flags": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumSurfaceLayout.terrain_contract(base(layout)) if is_terrain(layout) else {}


static func contacts_layout(layout: Dictionary) -> Dictionary:
	# Contact validation keeps every decorative flag; only the already-authenticated ground projection
	# changes.
	var result: Dictionary = layout.duplicate(true)
	if is_terrain(result):
		result.base_version = 12
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		not is_family(layout)
		or not (
			SeasonOwnership._whole(original.get("version"), 12, 12)
			or SeasonOwnership._whole(original.get("version"), 17, 17)
		)
	):
		return {}
	var result: Dictionary = original.duplicate(true)
	result["base_version"] = int(result.version)
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["flags"] = layout.flags.duplicate(true)
	return result

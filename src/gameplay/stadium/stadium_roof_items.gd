class_name StadiumRoofItems
extends RefCounted
## Separate owned bowl layers, handed joins and remountable canopies on exact copied hosts.

const VERSION: int = 1
const PRICE_VERSION: int = 13
const LAYOUT_VERSION: int = 21
const FAMILY: String = "reference-curved-roofs-v21"
const PRICES: Dictionary = {
	"ST-081": [650, 140],
	"ST-083": [400, 80],
	"ST-082": [800, 180],
	"ST-084": [600, 140],
	"ST-085": [420, 100],
	"ST-086": [260, 60],
	"ST-088": [420, 100],
	"ST-089": [260, 60],
	"ST-053": [420, 110]
}
const FIELDS: Array[String] = [
	"copy",
	"site",
	"lower",
	"concourse",
	"upper",
	"bowl",
	"curved",
	"base",
	"straight",
	"roof_state"
]
const SUPPORTS: Array[String] = [
	"lower", "concourse", "upper", "bowl", "curved", "base", "straight"
]


static func price_signature() -> String:
	return (
		JSON.stringify({"version": PRICE_VERSION, "prices": PRICES}, "", true, true).sha256_text()
	)


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"model": StadiumRoofOwnedModels.VERSION,
				"base": 20,
				"bowl_sites": StadiumCurvedLowerSites.SITES,
				"join_sites": StadiumLowerTransitionSites.SITES,
				"supports": SUPPORTS,
				"roof_states": ["lower", "upper"],
				"lower_offset": [0, -3.75, -0.845],
				"outer_half_angle": 14.3,
				"straight_lower_width": 5.9
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
		return ClubAssetLedger._error("This item is not in the curved stands and canopy catalog.")
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
			"The canopy and bowl quote changed; reload before purchasing."
		)
	return result


static func is_family(layout: Variant) -> bool:
	return (
		layout is Dictionary
		and SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumStraightItems.is_terrain(base(layout))


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumStraightItems.upgrade(layout, access)
	if not StadiumStraightItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["roofs"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumStraightItems.LAYOUT_VERSION
	result.family = StadiumStraightItems.FAMILY
	result.erase("roofs")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if not is_family(layout) or not layout.get("roofs") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumStraightItems.is_family(original)
		else StadiumStraightItems.with_base(base(layout), original)
	)
	if not StadiumStraightItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["roofs"] = layout.roofs.duplicate(true)
	return result


static func row(site: String) -> Dictionary:
	var result: Dictionary = {}
	for field: String in FIELDS:
		result[field] = ""
	result.site = site
	return result


static func pose(site: String) -> Transform3D:
	if site in StadiumBaselineSites.SITES:
		return StadiumBaselineSites.pose(site)
	return (
		StadiumCurvedLowerSites.pose(site)
		if site in StadiumCurvedLowerSites.SITES
		else Transform3D.IDENTITY
	)


static func bounds(placement: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(placement.yaw))), placement.position)
		* StadiumRoofOwnedModels.envelope(placement.item, placement.get("roof_state", "lower"))
	)


static func validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("roofs") is Array
		or layout.roofs.size() > 28
	):
		return StadiumStarterLayout._error("Unknown curved roof layout or structural capacity.")
	var checked: Dictionary = StadiumStraightItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	var active: Dictionary = {}
	for entry: Dictionary in checked.placements:
		active[entry.copy] = entry
	var prior: String = ""
	var sites: Dictionary = {}
	var rows: Array = []
	for raw: Variant in layout.roofs:
		if not raw is Dictionary or not SeasonOwnership._keys(raw, FIELDS):
			return StadiumStarterLayout._error(
				"Each new structural copy needs its complete exact-host record."
			)
		for field: String in FIELDS:
			if not raw[field] is String:
				return StadiumStarterLayout._error(
					"Structural copy and support references must be exact strings."
				)
		if not checked.stored.has(raw.copy):
			return StadiumStarterLayout._error(
				"Every structural placement consumes one distinct owned copy."
			)
		var item: String = stock.copies[raw.copy].item
		var key: String = raw.site + ":" + item
		if (
			not PRICES.has(item)
			or key <= prior
			or sites.has(key)
			or not _site(item, raw.site, tier)
		):
			return StadiumStarterLayout._error(
				"Use the item's named site and one independently owned layer per site."
			)
		var placement: Dictionary = raw.duplicate(true)
		var transform: Transform3D = pose(raw.site)
		placement.merge(
			{
				"item": item,
				"position": transform.origin,
				"yaw": rad_to_deg(transform.basis.get_euler().y),
				"role": "DECORATIVE_AFTER_TERMINAL"
			}
		)
		var box: AABB = bounds(placement)
		if (
			box.size.is_zero_approx()
			or not StadiumProperty.contains(tier, box)
			or not StadiumClubSites._outside(box)
			or not StadiumGroundPropsItems._supported(box, StadiumStraightItems.base(base(layout)))
		):
			return StadiumStarterLayout._error(
				"The complete structural copy must fit supported outside-play property."
			)
		for previous: Dictionary in checked.placements:
			# Canonical structure reservations have intentional joined/stacked interfaces.
			# Other channels cannot gain permission to overlap those reservations.
			if (
				not StadiumStraightItems.HOSTS.has(previous.item)
				and not StadiumStraightItems.MOUNTS.has(previous.item)
				and box.intersects(StadiumHomeLayout.bounds(previous))
			):
				return StadiumStarterLayout._error(
					"Store the conflicting object before placing this structural layer."
				)
		checked.stored.erase(raw.copy)
		active[raw.copy] = placement
		sites[key] = placement
		rows.append(placement)
		prior = key
	for placement: Dictionary in rows:
		var expected: Dictionary = dependencies(
			placement.item, placement.site, placement.roof_state, active
		)
		if expected.is_empty():
			return StadiumStarterLayout._error(
				"This layer needs the exact installed lower, concourse, upper or named neighbors."
			)
		for field: String in SUPPORTS:
			if placement[field] != expected.get(field, ""):
				return StadiumStarterLayout._error(
					"A structural layer cannot borrow another site's or replacement copy's support."
				)
		if placement.item in ["ST-084", "ST-053"]:
			var upper_item: String = "ST-082" if placement.item == "ST-084" else "ST-030"
			if placement.roof_state == "lower" and _at(active, upper_item, placement.site) != "":
				return StadiumStarterLayout._error(
					"Remount this same canopy to the installed upper, or store it first."
				)
	checked.placements.append_array(rows)
	return checked


static func _site(item: String, site: String, tier: String) -> bool:
	if item == "ST-053":
		return site in StadiumBaselineSites.SITES and tier in ["club", "mogul"]
	if tier != "mogul":
		return false
	if item in ["ST-085", "ST-086"]:
		return site == "JOIN-R"
	if item in ["ST-088", "ST-089"]:
		return site == "JOIN-L"
	return site in StadiumCurvedLowerSites.SITES


static func _at(active: Dictionary, item: String, site: String) -> String:
	for copy: String in active:
		if active[copy].item == item and active[copy].site == site:
			return copy
	return ""


static func dependencies(
	item: String, site: String, state: String, active: Dictionary
) -> Dictionary:
	var result: Dictionary = {"valid": true}
	if item in ["ST-081", "ST-085", "ST-088"]:
		return result if state.is_empty() else {}
	if item in ["ST-083", "ST-082", "ST-084"]:
		result.lower = _at(active, "ST-081", site)
		if item == "ST-082" or (item == "ST-084" and state == "upper"):
			result.concourse = _at(active, "ST-083", site)
		if item == "ST-084" and state == "upper":
			result.upper = _at(active, "ST-082", site)
	elif item == "ST-053":
		result.lower = _at(active, "ST-029", site)
		if state == "upper":
			result.concourse = _at(active, "ST-031", site)
			result.upper = _at(active, "ST-030", site)
	elif item in ["ST-086", "ST-089"]:
		result.lower = _at(active, "ST-085" if item == "ST-086" else "ST-088", site)
		var bowl_site: String = StadiumTransitionConcourseSites.bowl_site(site)
		var base_site: String = StadiumTransitionConcourseSites.base_site(site)
		result.bowl = _at(active, "ST-081", bowl_site)
		result.curved = _at(active, "ST-083", bowl_site)
		result.base = _at(active, "ST-029", base_site)
		result.straight = _at(active, "ST-031", base_site)
	else:
		return {}
	if item in ["ST-053", "ST-084"]:
		if state not in ["lower", "upper"]:
			return {}
	elif not state.is_empty():
		return {}
	for field: String in SUPPORTS:
		if result.has(field) and str(result[field]).is_empty():
			return {}
	return result


static func active(layout: Dictionary, stock: StadiumStock) -> Dictionary:
	var result: Dictionary = {}
	for raw: Dictionary in layout.get("hosts", []) + layout.get("roofs", []):
		if stock.copies.has(raw.copy):
			result[raw.copy] = raw.duplicate(true)
			result[raw.copy]["item"] = stock.copies[raw.copy].item
	return result


static func prune(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result):
		return result
	result = with_base(result, StadiumStraightItems.prune(base(result)))
	for step in range(4):
		var installed: Array = []
		for entry: Dictionary in result.hosts + result.roofs:
			installed.append(entry.copy)
		result.roofs = result.roofs.filter(
			func(entry: Dictionary) -> bool:
				for field: String in SUPPORTS:
					if not entry[field].is_empty() and not installed.has(entry[field]):
						return false
				return true
		)
	return result


static func geometry(tier: String, layout: Dictionary) -> String:
	return (
		JSON
		. stringify(
			{"base": StadiumStraightItems.geometry(tier, base(layout)), "roofs": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumStraightItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumStraightItems.contacts_layout(base(layout)))

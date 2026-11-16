class_name StadiumFacilityItems
extends RefCounted
## Complete separately owned service rooms and fixed off-field facilities.

const VERSION: int = 1
const PRICE_VERSION: int = 14
const LAYOUT_VERSION: int = 22
const FAMILY: String = "reference-facilities-v22"
const PRICES: Dictionary = {
	"ST-055": [520, 140],
	"ST-057": [650, 180],
	"ST-033": [580, 170],
	"ST-034": [620, 180],
	"ST-056": [540, 160],
	"ST-059": [450, 130]
}
const FIELDS: Array[String] = ["copy", "site", "lower", "concourse"]
const ROOMS: Array[String] = ["ST-055", "ST-057"]
const GROUND_SITES: Array[String] = ["SERVICE-A", "SERVICE-B", "ANNOUNCER-A", "TICKET-APPROACH"]


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
				"model": StadiumFacilityOwnedModels.VERSION,
				"base": 21,
				"rooms": ROOMS,
				"sites": GROUND_SITES,
				"service_interface": "BASE-SERVICE-v1",
				"room_reserve": [-2.95, 0, 7.55, 5.9, 10.2, 8.6],
				"ticket_approach": [24, 0, -20.5, 180]
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
			"This item is not in the service rooms and facilities catalog."
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
		return ClubAssetLedger._error("The facilities quote changed; reload before purchasing.")
	return result


static func is_family(layout: Variant) -> bool:
	return (
		layout is Dictionary
		and SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumRoofItems.is_terrain(base(layout))


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumRoofItems.upgrade(layout, access)
	if not StadiumRoofItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["facilities"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumRoofItems.LAYOUT_VERSION
	result.family = StadiumRoofItems.FAMILY
	result.erase("facilities")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if not is_family(layout) or not layout.get("facilities") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumRoofItems.is_family(original)
		else StadiumRoofItems.with_base(base(layout), original)
	)
	if not StadiumRoofItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["facilities"] = layout.facilities.duplicate(true)
	return result


static func pose(site: String) -> Transform3D:
	if site in StadiumBaselineSites.SITES:
		return StadiumBaselineSites.pose(site)
	var position: Vector3 = Vector3.ZERO
	var yaw: float = 0.0
	match site:
		"SERVICE-A":
			position = Vector3(-36, 0, -7)
			yaw = -90.0
		"SERVICE-B":
			position = Vector3(36, 0, -7)
			yaw = 90.0
		"ANNOUNCER-A":
			position = Vector3(-35, 0, 12)
			yaw = -90.0
		"TICKET-APPROACH":
			position = Vector3(24, 0, -20.5)
			yaw = 180.0
	return Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), position)


static func reserved(site: String) -> AABB:
	if site in StadiumBaselineSites.SITES:
		return AABB(Vector3(-2.95, 0, 7.55), Vector3(5.9, 10.2, 8.6))
	if site in ["SERVICE-A", "SERVICE-B"]:
		return AABB(Vector3(-3, 0, -3), Vector3(6, 4.5, 6))
	if site == "ANNOUNCER-A":
		# World reservation is 5x4; local axes rotate through the fixed field-facing yaw.
		return AABB(Vector3(-2, 0, -2.5), Vector3(4, 4.5, 5))
	return AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 4, 3)) if site == "TICKET-APPROACH" else AABB()


static func bounds(placement: Dictionary) -> AABB:
	return pose(placement.site) * StadiumFacilityOwnedModels.envelope(placement.item)


static func sites(item: String) -> Array[String]:
	var result: Array[String] = []
	if item in ROOMS:
		result.assign(StadiumBaselineSites.SITES)
	elif item in ["ST-033", "ST-034"]:
		result.assign(["SERVICE-A", "SERVICE-B"])
	elif item == "ST-056":
		result.assign(["ANNOUNCER-A"])
	elif item == "ST-059":
		result.assign(["TICKET-APPROACH"])
	return result


static func dependencies(item: String, site: String, active: Dictionary) -> Dictionary:
	var result: Dictionary = {"valid": true, "lower": "", "concourse": ""}
	if item in ROOMS:
		result.lower = StadiumRoofItems._at(active, "ST-029", site)
		result.concourse = StadiumRoofItems._at(active, "ST-031", site)
		if result.lower.is_empty() or result.concourse.is_empty():
			return {}
	return result


static func room_at(layout: Dictionary, site: String) -> bool:
	for entry: Dictionary in layout.get("facilities", []):
		if entry.site == site and not entry.lower.is_empty():
			return true
	return false


static func validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("facilities") is Array
		or layout.facilities.size() > 8
	):
		return StadiumStarterLayout._error("Unknown service facility layout or site capacity.")
	var checked: Dictionary = StadiumRoofItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	var active: Dictionary = {}
	for placement: Dictionary in checked.placements:
		active[placement.copy] = placement
	var prior: String = ""
	var occupied: Array[String] = []
	var added: Array = []
	for raw: Variant in layout.facilities:
		if not raw is Dictionary or not SeasonOwnership._keys(raw, FIELDS):
			return StadiumStarterLayout._error(
				"A facility needs its exact copy, site, lower and concourse record."
			)
		for field: String in FIELDS:
			if not raw[field] is String:
				return StadiumStarterLayout._error(
					"Facility site and support references must be exact strings."
				)
		if not checked.stored.has(raw.copy):
			return StadiumStarterLayout._error("Every facility consumes one distinct owned copy.")
		var item: String = stock.copies[raw.copy].item
		var key: String = raw.site + ":" + item
		if (
			not PRICES.has(item)
			or raw.site not in sites(item)
			or tier not in ["club", "mogul"]
			or key <= prior
			or occupied.has(raw.site)
		):
			return StadiumStarterLayout._error(
				"Use one complete facility per named site on Club or Mogul property."
			)
		var required: Dictionary = dependencies(item, raw.site, active)
		if (
			required.is_empty()
			or raw.lower != required.lower
			or raw.concourse != required.concourse
		):
			return StadiumStarterLayout._error(
				"This service room needs its exact installed lower and matching concourse copies."
			)
		if (
			item in ROOMS
			and (
				StadiumRoofItems._at(active, "ST-030", raw.site) != ""
				or StadiumRoofItems._at(active, "ST-053", raw.site) != ""
			)
		):
			return (
				StadiumStarterLayout
				. _error(
					"Store the service room, upper or canopy first; this bay supports one of those configurations."
				)
			)
		var transform: Transform3D = pose(raw.site)
		var placement: Dictionary = raw.duplicate(true)
		placement.merge(
			{
				"item": item,
				"position": transform.origin,
				"yaw": rad_to_deg(transform.basis.get_euler().y),
				"role": "DECORATIVE_AFTER_TERMINAL"
			}
		)
		var local: AABB = StadiumFacilityOwnedModels.envelope(item)
		var box: AABB = bounds(placement)
		if (
			local.size.is_zero_approx()
			or not reserved(raw.site).grow(0.0001).encloses(local)
			or not StadiumProperty.contains(tier, box)
			or not StadiumClubSites._outside(box)
			or not StadiumGroundPropsItems._supported(
				box, StadiumStraightItems.base(StadiumRoofItems.base(base(layout)))
			)
		):
			return StadiumStarterLayout._error(
				"The complete room, platform or facility must fit supported outside-play property."
			)
		for previous: Dictionary in checked.placements + added:
			# Frozen canonical joined structures and their measured sockets have explicit interfaces.
			# The room's large support reservation is not a fictitious solid wall below its platform.
			if (
				item in ROOMS
				and (
					StadiumStraightItems.HOSTS.has(previous.item)
					or StadiumStraightItems.MOUNTS.has(previous.item)
					or StadiumRoofItems.PRICES.has(previous.item)
				)
			):
				continue
			if _overlaps(placement, previous):
				return StadiumStarterLayout._error(
					"Store the conflicting object before placing this complete facility."
				)
		checked.stored.erase(raw.copy)
		added.append(placement)
		occupied.append(raw.site)
		prior = key
	checked.placements.append_array(added)
	return checked


static func _local_box(placement: Dictionary) -> AABB:
	if placement.item == "ST-067":
		return StadiumMasteryBannerModels.ENVELOPE
	if StadiumStringLightItems.PRICES.has(placement.item):
		return StadiumStringLightItems.envelope(placement.item)
	if StadiumMountedDisplayItems.PRICES.has(placement.item):
		return StadiumMountedDisplayItems.envelope(placement.item)
	if StadiumPlayerTunnelItems.PRICES.has(placement.item):
		return StadiumPlayerTunnelItems.ENVELOPE
	if PRICES.has(placement.item):
		return StadiumFacilityOwnedModels.envelope(placement.item)
	if StadiumRoofItems.PRICES.has(placement.item):
		return StadiumRoofOwnedModels.envelope(placement.item, placement.get("roof_state", "lower"))
	if StadiumStraightItems.HOSTS.has(placement.item):
		return StadiumStraightOwnedModels.envelope(placement.item)
	var transform: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(placement.yaw))), placement.position
	)
	return transform.affine_inverse() * StadiumHomeLayout.bounds(placement)


static func _overlaps(a: Dictionary, b: Dictionary) -> bool:
	# Exact separating axes for fixed upright oriented reservations avoid world-AABB false positives.
	var ab: AABB = _local_box(a)
	var bb: AABB = _local_box(b)
	var at: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(a.yaw))), a.position)
	var bt: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(float(b.yaw))), b.position)
	var ac: Vector3 = at * ab.get_center()
	var bc: Vector3 = bt * bb.get_center()
	if absf(ac.y - bc.y) >= (ab.size.y + bb.size.y) * 0.5 - 0.0001:
		return false
	for axis: Vector3 in [at.basis.x, at.basis.z, bt.basis.x, bt.basis.z]:
		var ar: float = (
			(absf(axis.dot(at.basis.x)) * ab.size.x + absf(axis.dot(at.basis.z)) * ab.size.z) * 0.5
		)
		var br: float = (
			(absf(axis.dot(bt.basis.x)) * bb.size.x + absf(axis.dot(bt.basis.z)) * bb.size.z) * 0.5
		)
		if absf(axis.dot(ac - bc)) >= ar + br - 0.0001:
			return false
	return true


static func prune(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result):
		return result
	result = with_base(result, StadiumRoofItems.prune(base(result)))
	var installed: Array[String] = []
	for entry: Dictionary in result.hosts:
		installed.append(entry.copy)
	result.facilities = result.facilities.filter(
		func(entry: Dictionary) -> bool:
			return (
				(entry.lower.is_empty() or installed.has(entry.lower))
				and (entry.concourse.is_empty() or installed.has(entry.concourse))
			)
	)
	return result


static func geometry(tier: String, layout: Dictionary) -> String:
	return (
		JSON
		. stringify(
			{"base": StadiumRoofItems.geometry(tier, base(layout)), "facilities": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumRoofItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumRoofItems.contacts_layout(base(layout)))

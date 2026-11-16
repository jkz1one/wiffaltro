class_name StadiumStraightItems
extends RefCounted
## Exact owned support chain and whitelist mounts layered on the unchanged flag/prop field.

const VERSION: int = 1
const PRICE_VERSION: int = 12
const LAYOUT_VERSION: int = 20
const FAMILY: String = "reference-straight-hosts-v20"
const PRICES: Dictionary = {
	"ST-029": [420, 100],
	"ST-030": [600, 150],
	"ST-031": [280, 60],
	"ST-035": [550, 140],
	"ST-042": [300, 85]
}
const HOSTS: Array[String] = ["ST-029", "ST-031", "ST-030", "ST-035"]
const MOUNTS: Array[String] = ["ST-042", "ST-044"]
const ENTRY: Vector3 = Vector3(0, 0, -28.5)


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
				"model": StadiumStraightOwnedModels.VERSION,
				"base": 19,
				"sites": StadiumBaselineSites.SITES,
				"entry": [0, 0, -28.5],
				"supports": ["ST-029", "ST-031", "ST-030"],
				"crest_hosts": ["ST-029", "ST-030", "ST-035", "ST-039"],
				"pennant_hosts": ["ST-029", "ST-031"],
				"socket_rule": "exact-owned-host-and-support-v1"
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
		return ClubAssetLedger._error("This item is not in the straight host and crest catalog.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The straight host quote changed; reload before purchasing.")
	return result


static func is_family(layout: Variant) -> bool:
	return (
		layout is Dictionary
		and SeasonOwnership._whole(layout.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumGroundPropsItems.is_terrain(base(layout))


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumGroundPropsItems.upgrade(layout, access)
	if not StadiumGroundPropsItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["hosts"] = []
	result["mounts"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumGroundPropsItems.LAYOUT_VERSION
	result.family = StadiumGroundPropsItems.FAMILY
	result.erase("hosts")
	result.erase("mounts")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		not is_family(layout)
		or not layout.get("hosts") is Array
		or not layout.get("mounts") is Array
	):
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumGroundPropsItems.is_family(original)
		else StadiumGroundPropsItems.with_base(base(layout), original)
	)
	if not StadiumGroundPropsItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["hosts"] = layout.hosts.duplicate(true)
	result["mounts"] = layout.mounts.duplicate(true)
	return result


static func host_pose(site: String) -> Transform3D:
	return (
		Transform3D(Basis.IDENTITY, ENTRY)
		if site == "ENTRY-GATE"
		else StadiumBaselineSites.pose(site)
	)


static func bounds(row: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position)
		* StadiumStraightOwnedModels.envelope(row.item)
	)


static func validate(
	layout: Dictionary, stock: StadiumStock, tier: String = "backyard"
) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("hosts") is Array
		or not layout.get("mounts") is Array
		or layout.hosts.size() > 13
		or layout.mounts.size() > 14
	):
		return StadiumStarterLayout._error("Unknown straight host layout or mount capacity.")
	var checked: Dictionary = StadiumGroundPropsItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	var active: Dictionary = {}
	for row: Dictionary in checked.placements:
		active[row.copy] = row
	var prior: String = ""
	var sites: Dictionary = {}
	var rows: Array = []
	for raw: Variant in layout.hosts:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, ["copy", "site", "lower", "concourse"])
			or not raw.copy is String
			or not raw.site is String
			or not raw.lower is String
			or not raw.concourse is String
			or not checked.stored.has(raw.copy)
		):
			return StadiumStarterLayout._error(
				"Every host needs one distinct exact owned copy and its saved support copies."
			)
		var item: String = stock.copies[raw.copy].item
		var key: String = raw.site + ":" + item
		if not HOSTS.has(item) or key <= prior or sites.has(key):
			return StadiumStarterLayout._error("Use one compatible host layer per canonical site.")
		if item == "ST-035":
			if (
				raw.site != "ENTRY-GATE"
				or tier != "mogul"
				or not raw.lower.is_empty()
				or not raw.concourse.is_empty()
			):
				return StadiumStarterLayout._error(
					"The complete entrance gate needs its Mogul entry reservation."
				)
		elif raw.site not in StadiumBaselineSites.SITES or tier not in ["club", "mogul"]:
			return StadiumStarterLayout._error(
				"Straight stands need a designated Club or Mogul baseline site."
			)
		var pose: Transform3D = host_pose(raw.site)
		var row: Dictionary = {
			"copy": raw.copy,
			"site": raw.site,
			"item": item,
			"position": pose.origin,
			"yaw": rad_to_deg(pose.basis.get_euler().y),
			"role": "DECORATIVE_AFTER_TERMINAL",
			"lower": raw.lower,
			"concourse": raw.concourse
		}
		var box: AABB = bounds(row)
		if (
			not StadiumProperty.contains(tier, box)
			or not StadiumClubSites._outside(box)
			or not StadiumGroundPropsItems._supported(box, base(layout))
		):
			return StadiumStarterLayout._error(
				"The complete host must remain supported and outside live play on owned land."
			)
		for previous: Dictionary in checked.placements:
			if box.intersects(StadiumHomeLayout.bounds(previous)):
				return StadiumStarterLayout._error(
					"Store the conflicting object before placing this structural host."
				)
		checked.stored.erase(raw.copy)
		active[raw.copy] = row
		sites[key] = row
		rows.append(row)
		prior = key
	for row: Dictionary in rows:
		if row.item in ["ST-029", "ST-035"]:
			if not row.lower.is_empty() or not row.concourse.is_empty():
				return StadiumStarterLayout._error(
					"A ground host cannot claim unrelated supporting copies."
				)
		elif not _same_site(active, row.lower, "ST-029", row.site):
			return StadiumStarterLayout._error(
				"The structural layer requires its exact installed lower copy at this site."
			)
		elif row.item == "ST-031" and not row.concourse.is_empty():
			return StadiumStarterLayout._error(
				"The concourse is supported by its lower, never by another concourse."
			)
		elif (
			row.item == "ST-030"
			and (
				not _same_site(active, row.concourse, "ST-031", row.site)
				or active[row.concourse].lower != row.lower
			)
		):
			return StadiumStarterLayout._error(
				"The upper needs the exact matching installed lower and concourse copies."
			)
		for other: Dictionary in rows:
			if row.site != other.site and _structural_overlap(row, other):
				return StadiumStarterLayout._error("Complete structural bays cannot overlap.")
	checked.placements.append_array(rows)
	prior = ""
	var sockets: Dictionary = {}
	for raw: Variant in layout.mounts:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, ["copy", "host", "socket", "support"])
			or not raw.copy is String
			or not raw.host is String
			or not raw.socket is String
			or not raw.support is String
			or not checked.stored.has(raw.copy)
			or not active.has(raw.host)
		):
			return StadiumStarterLayout._error(
				"Every mounted display needs one owned copy and its exact installed host."
			)
		var item: String = stock.copies[raw.copy].item
		var kind: String = "crest" if item == "ST-042" else "pennant" if item == "ST-044" else ""
		var host: Dictionary = active[raw.host]
		var key: String = raw.host + ":" + raw.socket
		var socket: Dictionary = StadiumStraightOwnedModels.socket(host.item, kind)
		if (
			kind.is_empty()
			or raw.socket != kind
			or socket.is_empty()
			or key <= prior
			or sockets.has(key)
		):
			return StadiumStarterLayout._error(
				"This display has no free compatible socket on that exact host."
			)
		if kind == "crest" and not raw.support.is_empty():
			return StadiumStarterLayout._error("A crest binds only to its exact facade host.")
		if (
			kind == "pennant"
			and (
				host.item != "ST-029"
				or not _same_site(active, raw.support, "ST-031", host.site)
				or active[raw.support].lower != raw.host
				or not stock.copies[raw.copy].has("earned")
			)
		):
			return (
				StadiumStarterLayout
				. _error(
					"An earned pennant needs its exact lower plus matching concourse upper-band support."
				)
			)
		var pose: Transform3D = (
			Transform3D(Basis(Vector3.UP, deg_to_rad(float(host.yaw))), host.position)
			* socket.transform
		)
		var row: Dictionary = {
			"copy": raw.copy,
			"site": host.site + ":" + raw.socket,
			"item": item,
			"position": pose.origin,
			"yaw": rad_to_deg(pose.basis.get_euler().y),
			"role": "DECORATIVE_AFTER_TERMINAL",
			"host": raw.host,
			"support": raw.support,
			"socket": raw.socket
		}
		if item == "ST-044":
			row["earned"] = stock.copies[raw.copy].earned.duplicate(true)
		if (
			not StadiumProperty.contains(tier, bounds(row))
			or not StadiumClubSites._outside(bounds(row))
		):
			return StadiumStarterLayout._error(
				"The complete mounted display must fit outside-play property clearance."
			)
		for previous: Dictionary in checked.placements:
			if (
				previous.copy != raw.host
				and previous.copy != raw.support
				and previous.get("lower", "") != raw.host
				and _mount_overlap(row, previous)
			):
				return (
					StadiumStarterLayout
					. _error(
						(
							"Store this crest first. Its lower facade socket is occupied by the neighboring stand."
							if item == "ST-042" and host.item == "ST-029"
							else "The mount footprint overlaps another placed object."
						)
					)
				)
		checked.stored.erase(raw.copy)
		checked.placements.append(row)
		sockets[key] = raw.copy
		prior = key
	return checked


static func _same_site(active: Dictionary, copy: String, item: String, site: String) -> bool:
	return active.has(copy) and active[copy].item == item and active[copy].site == site


static func prune(layout: Dictionary) -> Dictionary:
	# Called only by editor changes. Validation never silently repairs corrupt saved data.
	var result: Dictionary = layout.duplicate(true)
	if not is_family(result):
		return result
	var installed: Array = []
	for row: Dictionary in result.hosts:
		installed.append(row.copy)
	for row: Dictionary in result.get("displays", []):
		installed.append(row.copy)
	for step in range(3):
		result.hosts = result.hosts.filter(
			func(row: Dictionary) -> bool:
				return (
					(row.lower.is_empty() or installed.has(row.lower))
					and (row.concourse.is_empty() or installed.has(row.concourse))
				)
		)
		installed.clear()
		for row: Dictionary in result.hosts:
			installed.append(row.copy)
		for row: Dictionary in result.get("displays", []):
			installed.append(row.copy)
	result.mounts = result.mounts.filter(
		func(row: Dictionary) -> bool:
			return (
				installed.has(row.host) and (row.support.is_empty() or installed.has(row.support))
			)
	)
	return result


static func geometry(tier: String, layout: Dictionary) -> String:
	return (
		JSON
		. stringify(
			{"base": StadiumGroundPropsItems.geometry(tier, base(layout)), "straight": signature()},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumGroundPropsItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumGroundPropsItems.contacts_layout(base(layout)))


static func _structural_overlap(row: Dictionary, other: Dictionary) -> bool:
	# Adjacent unscaled baseline bays share an authored edge. World AABBs overlap
	# merely because the entire rail is oblique; compare in the real first bay frame.
	var local: Transform3D = host_pose(row.site).affine_inverse() * host_pose(other.site)
	return StadiumStraightOwnedModels.envelope(row.item).grow(-0.0001).intersects(
		local * StadiumStraightOwnedModels.envelope(other.item).grow(-0.0001)
	)


static func _mount_overlap(row: Dictionary, other: Dictionary) -> bool:
	if not HOSTS.has(other.item):
		return bounds(row).intersects(StadiumHomeLayout.bounds(other))
	var mount: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(float(row.yaw))), row.position
	)
	var local: Transform3D = host_pose(other.site).affine_inverse() * mount
	return (local * StadiumStraightOwnedModels.envelope(row.item)).intersects(
		StadiumStraightOwnedModels.envelope(other.item).grow(-0.0001)
	)

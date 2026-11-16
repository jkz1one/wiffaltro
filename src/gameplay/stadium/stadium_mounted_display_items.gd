class_name StadiumMountedDisplayItems
extends RefCounted
## Paid, rigid named-fascia displays on exact installed current-family hosts.

const VERSION: int = 1
const PRICE_VERSION: int = 29
const LAYOUT_VERSION: int = 38
const FAMILY: String = "reference-mounted-displays-v38"
const PRICES: Dictionary = {"ST-068": [480, 80], "ST-069": [330, 90], "ST-070": [300, 85]}
const ITEMS: Array[String] = ["ST-068", "ST-069", "ST-070"]
const FIELDS: Array[String] = ["copy", "host", "socket"]
const HOSTS: Dictionary = {
	"ST-068": ["ST-030", "ST-031"], "ST-069": ["ST-035", "ST-039"], "ST-070": ["ST-035", "ST-039"]
}
const CAPACITY: int = 12
const STORE_FIRST: String = ("Store the mounted display first, then move, remove or replace its " \
	+ "exact host or choose another socket. The same paid display and host " + \
	"copies remain owned; restoring a host never mounts an item " + "automatically.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	# These separate paid ownership routes must never be silently converted.
	if SeasonOwnership._whole(layout.get("version"), 13, 16):
		return {}
	var result: Dictionary = StadiumPlayerTunnelItems.upgrade(layout, access)
	if not StadiumPlayerTunnelItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["mounted_displays"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return base(StadiumStringLightItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumPlayerTunnelItems.LAYOUT_VERSION
	result.family = StadiumPlayerTunnelItems.FAMILY
	result.erase("mounted_displays")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumStringLightItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("mounted_displays") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumPlayerTunnelItems.is_family(original)
		else StadiumPlayerTunnelItems.with_base(base(layout), original)
	)
	if not StadiumPlayerTunnelItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["mounted_displays"] = layout.mounted_displays.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumPlayerTunnelItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumPlayerTunnelItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumPlayerTunnelItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumPlayerTunnelItems.graph_for(base(layout))


static func signature() -> String:
	var sockets: Dictionary = {}
	for item: String in ITEMS:
		for host: String in HOSTS[item]:
			var socket: Dictionary = StadiumMountedDisplayModels.socket(host, item)
			sockets[host + ":" + item] = var_to_str(socket)
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 37,
				"models": StadiumMountedDisplayModels.VERSION,
				"model_catalog": StadiumMountedDisplayModels.signature(),
				"items": ITEMS,
				"source": "BP114:10945-10963",
				"hosts": HOSTS,
				"sockets": sockets,
				"fields": FIELDS,
				"capacity": CAPACITY,
				"unsupported_families": [13, 14, 15, 16],
				"copy_policy": "exact-owned-copy-host-and-named-socket-store-first-v1",
				"clearance":
				"complete-oriented-reservation-exact-host-and-measured-ST031-lower-interface-v1",
				"ribbon": "rigid-stable-club-color-no-curved-substitution-v1",
				"clock": "authoritative-simulation-clock-no-machine-time-v1",
				"pa": "silent-fixed-aim-presentation-no-audio-claim-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"receiver": false,
				"gameplay_bonus": false,
				"earned_route": false,
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
	):
		return StadiumStringLightItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumPlayerTunnelItems.geometry(tier, base(layout)),
				"mounted_displays": signature()
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
			"This item is not a complete paid ribbon, clock or PA display."
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
			"The mounted-display quote changed; reload before purchasing."
		)
	return result


static func candidates(layout: Dictionary, stock: StadiumStock, item: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if (
		stock == null
		or not HOSTS.has(item)
		or SeasonOwnership._whole(layout.get("version"), 13, 16)
	):
		return result
	for channel: String in ["hosts", "displays"]:
		if not layout.get(channel, []) is Array:
			continue
		for raw: Variant in layout.get(channel, []):
			if (
				not raw is Dictionary
				or not raw.get("copy") is String
				or not raw.get("site") is String
				or not stock.copies.has(raw.copy)
			):
				continue
			var host_item: String = stock.copies[raw.copy].item
			if host_item not in HOSTS[item]:
				continue
			if channel == "displays" and (host_item != "ST-039" or raw.site != "SCORE-SMALL"):
				continue
			if (
				channel == "hosts"
				and (
					host_item == "ST-039"
					or (
						raw.site != "ENTRY-GATE"
						if host_item == "ST-035"
						else raw.site not in StadiumBaselineSites.SITES
					)
				)
			):
				continue
			var socket: Dictionary = StadiumMountedDisplayModels.socket(host_item, item)
			if not socket.is_empty():
				result.append(
					{
						"host": raw.copy,
						"socket": socket.id,
						"host_item": host_item,
						"host_site": raw.site
					}
				)
	result.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.host + ":" + a.socket < b.host + ":" + b.socket
	)
	return result


static func row(copy: String, item: String, host: Dictionary, socket_id: String) -> Dictionary:
	if (
		not HOSTS.has(item)
		or host.get("item", "") not in HOSTS[item]
		or not String(host.get("model", "")).is_empty()
	):
		return {}
	var socket: Dictionary = StadiumMountedDisplayModels.socket(host.item, item)
	if socket.is_empty() or socket.id != socket_id:
		return {}
	var pose: Transform3D = (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(host.yaw))), host.position)
		* socket.transform
	)
	return {
		"copy": copy,
		"item": item,
		"host": host.copy,
		"host_item": host.item,
		"host_site": host.site,
		"host_model": "",
		"socket": socket_id,
		"site": host.site + ":" + socket_id,
		"position": pose.origin,
		"yaw": rad_to_deg(pose.basis.get_euler().y),
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String) -> AABB:
	return StadiumMountedDisplayModels.envelope(item) if PRICES.has(item) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(placed.yaw))), placed.position)
		* envelope(placed.item)
	)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
	):
		return StadiumStringLightItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("mounted_displays") is Array
		or layout.mounted_displays.size() > CAPACITY
	):
		return StadiumStarterLayout._error(
			"Unknown mounted-display layout or named socket capacity."
		)
	var checked: Dictionary = StadiumPlayerTunnelItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["mounted_display_placements"] = []
	if layout.mounted_displays.is_empty():
		return checked  # Empty family wrappers preserve inherited Night and all channels.
	var active: Dictionary = {}
	for placed: Dictionary in checked.placements:
		active[placed.copy] = placed
	var prior: String = ""
	for raw: Variant in layout.mounted_displays:
		if not raw is Dictionary or not SeasonOwnership._keys(raw, FIELDS):
			return StadiumStarterLayout._error(
				"Each mounted display needs its exact owned copy, host and named socket."
			)
		for field: String in FIELDS:
			if not raw[field] is String:
				return StadiumStarterLayout._error(
					"Mounted-display references must be exact strings."
				)
		var key: String = raw.host + ":" + raw.socket
		if (
			stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or not active.has(raw.host)
			or key <= prior
		):
			return StadiumStarterLayout._error(STORE_FIRST)
		var placed: Dictionary = row(
			raw.copy, stock.copies[raw.copy].item, active[raw.host], raw.socket
		)
		if placed.is_empty():
			return (
				StadiumStarterLayout
				. _error(
					(
						"This exact host has no named compatible socket. Only straight ST-030/ST-031 fascia "
						+ "and current ST-035/legacy ST-039 mounts are admitted; ST-040 and scoreboard "
						+ "families 14/15 remain separate."
					)
				)
			)
		var reserve: AABB = bounds(placed)
		if (
			reserve.size.is_zero_approx()
			or not StadiumProperty.contains(tier, reserve)
			or not StadiumClubSites._outside(reserve)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"The complete rigid display, fixing brackets and visible bounds must fit owned "
						+ "outside-play property."
					)
				)
			)
		for other: Dictionary in checked.placements:
			if other.copy == raw.host:
				continue  # Only the exact named host may touch the mount's rear fixing plate.
			if (
				placed.item == "ST-068"
				and placed.host_item == "ST-031"
				and other.item == "ST-029"
				and other.copy == active[raw.host].get("lower", "")
				and other.site == placed.host_site
			):
				# Measured real lower members clear the thin front fascia; only its exact validated support
				# qualifies.
				continue
			if StadiumFacilityItems._overlaps(placed, other):
				return StadiumStarterLayout._error(
					(
						"The full mounted-display reservation conflicts with "
						+ other.site
						+ "; explicitly store one complete copy first."
					)
				)
		checked.placements.append(placed)
		checked.mounted_display_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = key
	checked.night_qualified = false
	checked["night_unqualified_reason"] = \
		"Installed ribbon, clock and PA mounts have not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	host: String,
	socket: String,
	access: Array[String] = []
) -> Dictionary:
	if (
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
	):
		return StadiumStringLightItems.with_base(
			layout, place(StadiumStringLightItems.base(layout), stock, copy, host, socket, access)
		)
	if host.is_empty() and socket.is_empty():
		return store_copy(layout, copy)
	if stock == null or not stock.copies.has(copy) or not PRICES.has(stock.copies[copy].item):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	for current: Dictionary in result.mounted_displays:
		if current.copy == copy and current.host == host and current.socket == socket:
			return result  # A repeated selection never rebinds a replacement host.
	for candidate: Dictionary in candidates(result, stock, stock.copies[copy].item):
		if candidate.host == host and candidate.socket == socket:
			result.mounted_displays.append({"copy": copy, "host": host, "socket": socket})
			result.mounted_displays.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return a.host + ":" + a.socket < b.host + ":" + b.socket
			)
			return result
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
	):
		return StadiumStringLightItems.with_base(
			layout, store_copy(StadiumStringLightItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("mounted_displays") is Array:
		result.mounted_displays = result.mounted_displays.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func transition(before: Dictionary, after: Dictionary) -> Dictionary:
	for previous: Dictionary in before.get("mounted_displays", []):
		for next: Dictionary in after.get("mounted_displays", []):
			if (
				(
					previous.copy == next.copy
					or (previous.host == next.host and previous.socket == next.socket)
				)
				and not ClubCareer.same(previous, next)
			):
				return StadiumStarterLayout._error(STORE_FIRST)
		# A saved Store transaction must precede any host replacement or removal.
		var retained: bool = false
		for channel: String in ["hosts", "displays"]:
			for old: Dictionary in before.get(channel, []):
				if old.copy == previous.host:
					for next: Dictionary in after.get(channel, []):
						if ClubCareer.same(old, next):
							retained = true
		if not retained:
			return StadiumStarterLayout._error(STORE_FIRST)
	return {"ok": true, "error": ""}


static func prune(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumStringLightItems.prune(layout)
	# Never silently store a mounted copy when its structural or display host changes.
	return with_base(layout, StadiumPlayerTunnelItems.prune(base(layout)))

class_name StadiumPlayerTunnelItems
extends RefCounted
## BP114 CI1–CI5. A separate paid dead-region assembly with two exact owned hosts.

const VERSION: int = 1
const PRICE_VERSION: int = 28
const LAYOUT_VERSION: int = 37
const FAMILY: String = "reference-player-tunnel-v37"
const PRICES: Dictionary = {"ST-058": [420, 110]}
const ITEMS: Array[String] = ["ST-058"]
const FIELDS: Array[String] = ["copy", "site", "dugout", "lower"]
const SITES: Array[String] = ["TUNNEL-L", "TUNNEL-R"]
const ENVELOPE: AABB = AABB(Vector3(-1, 0, 0), Vector3(2, 2.7, 4.6))
const STORE_FIRST: String = \
	("Store the complete player tunnel first, then remove or replace its " + \
	"exact same-side concrete dugout or BASE1 stand. Both hosts regain " + \
	"their finished caps, and the same tunnel copy remains owned.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
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
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}
	var result: Dictionary = StadiumWallTopTerraceItems.upgrade(layout, access)
	if not StadiumWallTopTerraceItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["player_tunnels"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return base(StadiumMountedDisplayItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumWallTopTerraceItems.LAYOUT_VERSION
	result.family = StadiumWallTopTerraceItems.FAMILY
	result.erase("player_tunnels")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumMountedDisplayItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("player_tunnels") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumWallTopTerraceItems.is_family(original)
		else StadiumWallTopTerraceItems.with_base(base(layout), original)
	)
	if not StadiumWallTopTerraceItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["player_tunnels"] = layout.player_tunnels.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	return is_family(layout) and StadiumWallTopTerraceItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumWallTopTerraceItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumWallTopTerraceItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumWallTopTerraceItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 36,
				"models": StadiumPlayerTunnelModels.VERSION,
				"sites": SITES,
				"rail_reservation": [10, 12, 2.4, 7, 0, 2.7],
				"source": "BP114:14040-14164",
				"items": ITEMS,
				"hosts": ["ST-074:DUGOUT", "ST-029:BASE1"],
				"dugout_aperture": [10.25, 11.75, 2.4, 0, 2.4],
				"stand_aperture": [12, 5, 7, 0, 2.4],
				"copy_policy": "exact-two-owned-hosts-explicit-store-first-v1",
				"site_capacity": 2,
				"host_version": "named-capped-compatible-tunnel-interfaces-v1",
				"handedness": "single-symmetric-shell-rigid-positive-handed-frame-v1",
				"support": "complete-fixed-rail-reservation-on-supported-property-v1",
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"gameplay_bonus": false,
				"walkout_simulation": false,
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
	):
		return StadiumMountedDisplayItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumWallTopTerraceItems.geometry(tier, base(layout)),
				"player_tunnel": signature()
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
		return ClubAssetLedger._error("This item is not the complete paid player tunnel.")
	var result: Dictionary = stock.quote(item, quantity, progress, request)
	var blueprint: int = 0 if stock.blueprints.has(item) else int(PRICES[item][0])
	if (
		result.ok
		and (
			result.blueprint_cost != blueprint
			or result.copy_cost != int(PRICES[item][1]) * quantity
		)
	):
		return ClubAssetLedger._error("The player tunnel quote changed; reload before purchasing.")
	return result


static func sites(item: String = "ST-058") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES)
	return result


static func yaws(item: String = "ST-058") -> Array[int]:
	var result: Array[int] = []
	if PRICES.has(item):
		result.append(0)
	return result


static func placement(left: bool) -> Transform3D:
	var pose: Transform3D = StadiumDugoutRecipe.placement(left)
	pose.origin = StadiumDugoutRecipe.rail_point(11, 2.4, left)
	return pose


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or site not in SITES or not is_finite(yaw) or yaw != 0.0:
		return {}
	var left: bool = site == "TUNNEL-L"
	var pose: Transform3D = placement(left)
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": pose.origin,
		"yaw": rad_to_deg(pose.basis.get_euler().y),
		"left": left,
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-058", site: String = "TUNNEL-L") -> AABB:
	return ENVELOPE if PRICES.has(item) and site in SITES else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(placed.yaw))), placed.position) * ENVELOPE


static func host_info(layout: Dictionary, stock: StadiumStock, site: String) -> Dictionary:
	if site not in SITES or stock == null:
		return StadiumStarterLayout._error("Choose a Club or Mogul TUNNEL-L or TUNNEL-R site.")
	var side: String = "L" if site == "TUNNEL-L" else "R"
	var dugout: String = ""
	var lower: String = ""
	for raw: Variant in layout.get("boundary", []):
		if (
			raw is Dictionary
			and raw.get("site") == "DUGOUT-" + side
			and raw.get("item") == "ST-074"
			and raw.get("copy") is String
			and stock.copies.has(raw.copy)
			and stock.copies[raw.copy].item == "ST-074"
		):
			dugout = raw.copy
	for raw: Variant in layout.get("hosts", []):
		if (
			raw is Dictionary
			and raw.get("site") == "BASE-" + side + "1"
			and raw.get("copy") is String
			and stock.copies.has(raw.copy)
			and stock.copies[raw.copy].item == "ST-029"
		):
			lower = raw.copy
	if dugout.is_empty() or lower.is_empty():
		return (
			StadiumStarterLayout
			. _error(
				(
					(
						"Install one exact owned ST-074 at DUGOUT-%s and one exact owned ST-029 at BASE-%s1 "
						+ "before placing this tunnel. Timber, template and opposite-side hosts do not "
						+ "qualify."
					)
					% [side, side]
				)
			)
		)
	return {"ok": true, "error": "", "dugout": dugout, "lower": lower}


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
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
	):
		return StadiumMountedDisplayItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("player_tunnels") is Array
		or layout.player_tunnels.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown player tunnel layout or site capacity.")
	if not layout.player_tunnels.is_empty() and tier not in ["club", "mogul"]:
		return StadiumStarterLayout._error(
			"The complete player tunnel requires Club or Mogul property and both exact paid hosts."
		)
	for raw: Variant in layout.player_tunnels:
		if not raw is Dictionary or not SeasonOwnership._keys(raw, FIELDS):
			return StadiumStarterLayout._error(
				"A player tunnel needs its exact copy, site, dugout and lower host references."
			)
		for field: String in FIELDS:
			if not raw[field] is String:
				return StadiumStarterLayout._error(
					"Player tunnel references must be exact strings."
				)
		var host: Dictionary = host_info(layout, stock, raw.site)
		if not host.ok or raw.dugout != host.get("dugout") or raw.lower != host.get("lower"):
			return StadiumStarterLayout._error(
				STORE_FIRST + (" " + host.error if not host.ok else "")
			)
	var checked: Dictionary = StadiumWallTopTerraceItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["player_tunnel_placements"] = []
	var prior: String = ""
	for raw: Dictionary in layout.player_tunnels:
		if (
			raw.site <= prior
			or not checked.stored.has(raw.copy)
			or stock == null
			or not stock.copies.has(raw.copy)
			or stock.copies[raw.copy].item != "ST-058"
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"Each tunnel site requires one distinct exact owned ST-058 copy. Store an installed "
						+ "or moving copy first."
					)
				)
			)
		var placed: Dictionary = row(raw.copy, "ST-058", raw.site)
		placed["dugout"] = raw.dugout
		placed["lower"] = raw.lower
		var reserve: AABB = bounds(placed)
		if (
			not StadiumProperty.contains(tier, reserve)
			or not StadiumPracticeFacilityItems._supported(reserve, layout)
		):
			return (
				StadiumStarterLayout
				. _error(
					"The full player tunnel shell, turn, ports and supports must fit supported owned property."
				)
			)
		for other: Dictionary in checked.placements:
			if other.copy in [raw.dugout, raw.lower]:
				continue  # Only these exact compatible paid host interfaces can meet the shell.
			if _overlaps(placed, other):
				return StadiumStarterLayout._error(
					(
						"The complete player tunnel conflicts with "
						+ other.site
						+ "; explicitly store one assembly first. All paid copies remain owned."
					)
				)
		if StadiumMoldedSeatItems.has_pad(layout):
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if StadiumPracticeFacilityItems._horizontal_overlap(reserve, pad):
					return StadiumStarterLayout._error(
						"The tunnel must leave the full molded-seat pad and access clear."
					)
		checked.placements.append(placed)
		checked.player_tunnel_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = raw.site
	if not layout.player_tunnels.is_empty():
		checked.night_qualified = false
		checked["night_unqualified_reason"] = "The player tunnel has not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func _overlaps(placed: Dictionary, other: Dictionary) -> bool:
	return StadiumFacilityItems._overlaps(placed, other)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
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
	):
		return StadiumMountedDisplayItems.with_base(
			layout, place(StadiumMountedDisplayItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.player_tunnels:
		if current.copy == copy and current.site == site:
			return result  # Never silently rebind to replacement host identities.
	var host: Dictionary = host_info(result, stock, site)
	if not host.ok:
		return result
	result.player_tunnels.append(
		{"copy": copy, "site": site, "dugout": host.dugout, "lower": host.lower}
	)
	result.player_tunnels.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
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
	):
		return StadiumMountedDisplayItems.with_base(
			layout, store_copy(StadiumMountedDisplayItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("player_tunnels") is Array:
		result.player_tunnels = result.player_tunnels.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func transition(before: Dictionary, after: Dictionary) -> Dictionary:
	for previous: Dictionary in before.get("player_tunnels", []):
		for next: Dictionary in after.get("player_tunnels", []):
			if (
				(previous.site == next.site or previous.copy == next.copy)
				and not ClubCareer.same(previous, next)
			):
				return StadiumStarterLayout._error(STORE_FIRST)
		# A host-changing transaction must follow a saved Store transaction, not hide one.
		for field: String in ["boundary", "hosts"]:
			var reference: String = previous.dugout if field == "boundary" else previous.lower
			var retained: bool = false
			for old: Dictionary in before.get(field, []):
				if old.copy == reference:
					for next: Dictionary in after.get(field, []):
						if ClubCareer.same(old, next):
							retained = true
			if not retained:
				return StadiumStarterLayout._error(STORE_FIRST)
	return {"ok": true, "error": ""}


static func prune(layout: Dictionary) -> Dictionary:
	if (
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
	):
		return StadiumMountedDisplayItems.prune(layout)
	# No dependency change can silently store or mint a tunnel or a host.
	return with_base(layout, StadiumWallTopTerraceItems.prune(base(layout)))

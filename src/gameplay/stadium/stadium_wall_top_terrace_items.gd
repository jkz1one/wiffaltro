class_name StadiumWallTopTerraceItems
extends RefCounted
## BP114:11871–11927 / V5:142–151. One paid assembly bound to six exact paid wall hosts.

const VERSION: int = 1
const PRICE_VERSION: int = 27
const LAYOUT_VERSION: int = 36
const FAMILY: String = "reference-wall-top-terrace-v36"
const PRICES: Dictionary = {"ST-087": [950, 280]}
const ITEMS: Array[String] = ["ST-087"]
const FIELDS: Array[String] = ["copy", "site", "host_item", "host_copies"]
const SITES: Dictionary = {"TERRACE-R-A": Vector3(15, 0, 23.4)}
const HOST_ITEMS: Array[String] = ["ST-065", "ST-077"]
const HOST_INDICES: Array[int] = [1, 2, 3, 4, 5, 6]
const ENVELOPE: AABB = AABB(Vector3(-6, 0, 0), Vector3(12, 4.8, 7))
const STORE_FIRST: String = ("Store the complete terrace at TERRACE-R-A first, then replace or " \
	+ "remove its wall hosts. The same paid terrace copy remains owned; " + \
	"restoring hosts never places it automatically.")


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	if SeasonOwnership._whole(layout.get("version"), 16, 16):
		return {}
	var result: Dictionary = StadiumRisingAppleItems.upgrade(layout, access)
	if not StadiumRisingAppleItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["wall_top_terrace"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return base(StadiumPlayerTunnelItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumRisingAppleItems.LAYOUT_VERSION
	result.family = StadiumRisingAppleItems.FAMILY
	result.erase("wall_top_terrace")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return StadiumPlayerTunnelItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("wall_top_terrace") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumRisingAppleItems.is_family(original)
		else StadiumRisingAppleItems.with_base(base(layout), original)
	)
	if not StadiumRisingAppleItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["wall_top_terrace"] = layout.wall_top_terrace.duplicate(true)
	return result


static func is_terrain(layout: Variant) -> bool:
	if StadiumPlayerTunnelItems.is_family(layout):
		return StadiumPlayerTunnelItems.is_terrain(layout)
	return is_family(layout) and StadiumRisingAppleItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumRisingAppleItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumRisingAppleItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumRisingAppleItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 35,
				"optional_base": [28, 29],
				"models": StadiumWallTopTerraceModels.VERSION,
				"sites": {"TERRACE-R-A": [15, 0, 23.4]},
				"reservation": [-6, 0, 0, 12, 4.8, 7],
				"source": ["BP114:11871-11927", "V5:142-151"],
				"yaw": 0,
				"items": ITEMS,
				"host_items": HOST_ITEMS,
				"host_indices": HOST_INDICES,
				"complete_back_copies": 23,
				"host_shape": "straight",
				"host_height": 3.25,
				"padded_socket": StadiumWallTopTerraceModels.socket_profile("ST-065"),
				"brick_socket": StadiumWallTopTerraceModels.socket_profile("ST-077"),
				"copy_policy": "exact-owned-copy-and-six-host-identities-store-first-v1",
				"site_capacity": 1,
				"host_replacement": "explicit-store-never-auto-place-v1",
				"support": "whole-outer-property-ground-outside-terrain-patch-v1",
				"clearance": "full-reservation-with-only-six-host-contact-exemptions-v1",
				"symmetric_reservation_conflict": "explicit-store-first-both-orders-v1",
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
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return StadiumPlayerTunnelItems.geometry(tier, layout)
	return (
		JSON
		. stringify(
			{
				"base": StadiumRisingAppleItems.geometry(tier, base(layout)),
				"wall_top_terrace": signature()
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
		return ClubAssetLedger._error("This item is not the complete paid wall-top terrace.")
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
			"The wall-top terrace quote changed; reload before purchasing."
		)
	return result


static func sites(item: String = "ST-087") -> Array[String]:
	var result: Array[String] = []
	if PRICES.has(item):
		result.assign(SITES.keys())
	return result


static func yaws(item: String = "ST-087") -> Array[int]:
	var result: Array[int] = []
	if PRICES.has(item):
		result.append(0)
	return result


static func row(copy: String, item: String, site: String, yaw: float = 0.0) -> Dictionary:
	if not PRICES.has(item) or not SITES.has(site) or not is_finite(yaw) or yaw != 0.0:
		return {}
	return {
		"copy": copy,
		"item": item,
		"site": site,
		"position": SITES[site],
		"yaw": 0,
		"role": "DECORATIVE_AFTER_TERMINAL"
	}


static func envelope(item: String = "ST-087", site: String = "TERRACE-R-A") -> AABB:
	return ENVELOPE if PRICES.has(item) and SITES.has(site) else AABB()


static func bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * envelope(placed.item, placed.site)


static func occupied_bounds(placed: Dictionary) -> AABB:
	return Transform3D(Basis.IDENTITY, placed.position) * StadiumWallTopTerraceModels.ENVELOPE


static func host_info(layout: Dictionary, stock: StadiumStock) -> Dictionary:
	var walls: Variant = layout.get("walls")
	if not walls is Dictionary:
		return (
			StadiumStarterLayout
			. _error(
				(
					"TERRACE-R-A requires a complete straight 23-copy paid ST-065 padded or ST-077 brick "
					+ "back wall; its designated six full panels are the hosts."
				)
			)
		)
	# Back-only validation respects separately validated 16-panel dugout sides.
	var checked: Dictionary = StadiumWallLayout.validate(
		{"back": walls.get("back"), "left": [], "right": []}, stock
	)
	if (
		not checked.ok
		or walls.back.is_empty()
		or walls.back.shape != "straight"
		or walls.back.item not in HOST_ITEMS
	):
		return (
			StadiumStarterLayout
			. _error(
				(
					"TERRACE-R-A requires a complete straight 23-copy paid ST-065 padded or ST-077 brick "
					+ "back wall. Mixed, angled, plywood, chain-link and side-wall hosts are unsupported."
				)
			)
		)
	var recipe: Array[Dictionary] = StadiumWallRecipes.back("straight", walls.back.item)
	if recipe.size() != 23:
		return StadiumStarterLayout._error(
			"The terrace requires the authored complete 23-panel straight back wall."
		)
	var copies: Array[String] = []
	var sockets: Array[String] = []
	for index: int in HOST_INDICES:
		var panel: Dictionary = recipe[index]
		var x: float = 21.0 - float(index - 1) * 2.0
		if (
			panel.span != "full"
			or not panel.a.is_equal_approx(Vector2(x, 23.4))
			or not panel.b.is_equal_approx(Vector2(x - 2.0, 23.4))
			or panel.height != 3.25
		):
			return (
				StadiumStarterLayout
				. _error(
					"The authored TERRACE-R-A wall sockets changed; reload the matching wall and terrace catalog."
				)
			)
		copies.append(walls.back.copies[index])
		sockets.append(panel.socket)
	return {
		"ok": true,
		"error": "",
		"host_item": walls.back.item,
		"host_copies": copies,
		"host_sockets": sockets,
		"socket_profile": StadiumWallTopTerraceModels.socket_profile(walls.back.item)
	}


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return StadiumPlayerTunnelItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("wall_top_terrace") is Array
		or layout.wall_top_terrace.size() > SITES.size()
	):
		return StadiumStarterLayout._error("Unknown wall-top terrace layout or site capacity.")
	var host: Dictionary = {}
	if not layout.wall_top_terrace.is_empty():
		# BP114:13922-13925: six hosts are a subset of a full Club/Mogul wall.
		if tier not in ["club", "mogul"]:
			return (
				StadiumStarterLayout
				. _error(
					(
						"The complete wall-top terrace requires Club or Mogul property. Store the terrace "
						+ "before using a smaller property; all paid copies remain owned."
					)
				)
			)
		host = host_info(layout, stock)
		if not host.ok:
			return StadiumStarterLayout._error(STORE_FIRST + " " + host.error)
	var checked: Dictionary = StadiumRisingAppleItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["wall_top_terrace_placements"] = []
	if layout.wall_top_terrace.is_empty():
		return checked
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if not StadiumOutfieldBleacherItems.wall_eligible(graph) or graph._shape != "straight":
		return StadiumStarterLayout._error(
			STORE_FIRST + " Only the exact straight terminal back-wall graph supports this terrace."
		)
	for raw: Variant in layout.wall_top_terrace:
		if (
			not raw is Dictionary
			or not SeasonOwnership._keys(raw, FIELDS)
			or not raw.copy is String
			or not raw.site is String
			or not SITES.has(raw.site)
			or stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or not PRICES.has(stock.copies[raw.copy].item)
		):
			return (
				StadiumStarterLayout
				. _error(
					(
						"TERRACE-R-A needs one exact owned ST-087 copy; explicitly store its occupant or "
						+ "moving copy first."
					)
				)
			)
		if (
			raw.host_item != host.host_item
			or not ClubCareer.same(raw.host_copies, host.host_copies)
		):
			return StadiumStarterLayout._error(STORE_FIRST)
		var placed: Dictionary = row(raw.copy, stock.copies[raw.copy].item, raw.site)
		placed["host_item"] = host.host_item
		placed["host_copies"] = host.host_copies.duplicate()
		placed["host_sockets"] = host.host_sockets.duplicate()
		var reserve: AABB = bounds(placed)
		if (
			not StadiumProperty.contains(tier, reserve)
			or not StadiumPracticeFacilityItems._supported(reserve, layout)
		):
			return (
				StadiumStarterLayout
				. _error(
					"The full TERRACE-R-A deck, supports and access must fit supported outer-property ground."
				)
			)
		# This site intentionally meets its six terminal host slabs; every other
		# paid wall and object is checked without trimming the deck/access reserve.
		for panel: Dictionary in checked.get("wall_panels", []):
			if host.host_copies.has(panel.copy):
				continue
			var size: Vector3 = StadiumWallPanelModels.dimensions(panel.item, panel.span)
			var panel_box: AABB = (
				StadiumWallRecipes.placement(panel) * AABB(Vector3(-size.x / 2, 0, -size.z), size)
			)
			if StadiumPracticeFacilityItems._horizontal_overlap(reserve, panel_box):
				return StadiumStarterLayout._error(
					(
						"TERRACE-R-A conflicts with wall socket "
						+ panel.socket
						+ "; store the terrace before changing that wall."
					)
				)
		for other: Dictionary in checked.placements:
			if StadiumRisingAppleItems._overlaps(reserve, other):
				return (
					StadiumStarterLayout
					. _error(
						(
							"TERRACE-R-A conflicts with "
							+ other.site
							+ ("; explicitly store the terrace or that entire placement first. Both " + \
								"paid copies remain owned.")
						)
					)
				)
		if StadiumMoldedSeatItems.has_pad(layout):
			for pad: AABB in StadiumMoldedSeatItems.reservations():
				if StadiumPracticeFacilityItems._horizontal_overlap(reserve, pad):
					return (
						StadiumStarterLayout
						. _error(
							"TERRACE-R-A must leave the full molded-seat pad and access clear; store one assembly first."
						)
					)
		checked.placements.append(placed)
		checked.wall_top_terrace_placements.append(placed)
		checked.stored.erase(raw.copy)
	checked.night_qualified = false
	checked["night_unqualified_reason"] = "The wall-top terrace has not been qualified for Night."
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	site: String,
	yaw: float = 0.0,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return StadiumPlayerTunnelItems.with_base(
			layout, place(StadiumPlayerTunnelItems.base(layout), stock, copy, site, yaw, access)
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
	for current: Dictionary in result.wall_top_terrace:
		if current.copy == copy and current.site == site:
			return result  # Never silently rebind an already placed terrace.
	var host: Dictionary = host_info(result, stock)
	if not host.ok:
		return result
	result.wall_top_terrace.append(
		{
			"copy": copy,
			"site": site,
			"host_item": host.host_item,
			"host_copies": host.host_copies.duplicate()
		}
	)
	result.wall_top_terrace.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site
	)
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return StadiumPlayerTunnelItems.with_base(
			layout, store_copy(StadiumPlayerTunnelItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("wall_top_terrace") is Array:
		result.wall_top_terrace = result.wall_top_terrace.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func transition(before: Dictionary, after: Dictionary) -> Dictionary:
	for previous: Dictionary in before.get("wall_top_terrace", []):
		for next: Dictionary in after.get("wall_top_terrace", []):
			if previous.site == next.site and not ClubCareer.same(previous, next):
				return StadiumStarterLayout._error(STORE_FIRST)
	return {"ok": true, "error": ""}


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumPlayerTunnelItems.is_family(layout)
		or (
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
		)
	):
		return StadiumPlayerTunnelItems.prune(layout)
	# Dependency edits must fail validation, never silently dispose of the terrace.
	return with_base(layout, StadiumRisingAppleItems.prune(base(layout)))

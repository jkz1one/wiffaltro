class_name StadiumMasteryBannerItems
extends RefCounted
## BU2 earned-only, exact lower-facade display. Historical families stay frozen.

const VERSION: int = 1
const LAYOUT_VERSION: int = 41
const FAMILY: String = "reference-mastery-banners-v41"
const ITEM: String = "ST-067"
const SOCKET: String = "BANNER-WALL"
const HOST_ITEM: String = "ST-029"
const FIELDS: Array[String] = ["copy", "host", "socket"]
const CAPACITY: int = 4


static func is_family(value: Variant) -> bool:
	return (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), LAYOUT_VERSION, LAYOUT_VERSION)
	)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return layout.duplicate(true)
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = StadiumSalvageCarItems.upgrade(layout, access)
	if not StadiumSalvageCarItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["mastery_banners"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return base(StadiumWaterfallItems.base(layout))
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = StadiumSalvageCarItems.LAYOUT_VERSION
	result.family = StadiumSalvageCarItems.FAMILY
	result.erase("mastery_banners")
	return result


static func with_base(layout: Dictionary, original: Dictionary) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return StadiumWaterfallItems.with_base(layout, original)
	if not is_family(layout) or not layout.get("mastery_banners") is Array:
		return {}
	var result: Dictionary = (
		original.duplicate(true)
		if StadiumSalvageCarItems.is_family(original)
		else StadiumSalvageCarItems.with_base(base(layout), original)
	)
	if not StadiumSalvageCarItems.is_family(result):
		return {}
	result.version = LAYOUT_VERSION
	result.family = FAMILY
	result["mastery_banners"] = layout.mastery_banners.duplicate(true)
	# Editing a structural host stores its historical decoration, never transfers it.
	result.mastery_banners = result.mastery_banners.filter(
		func(value: Dictionary) -> bool: return _same_host(layout, result, value.host)
	)
	return result


static func is_terrain(layout: Variant) -> bool:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return (
			StadiumWaterfallItems.is_terrain(layout)
			or (
				StadiumLightingKitItems.is_terrain(layout)
				or (
					StadiumOutfieldPlazaItems.is_terrain(layout)
					or StadiumWaterfallLiveItems.is_terrain(layout)
				)
			)
		)
	return is_family(layout) and StadiumSalvageCarItems.is_terrain(base(layout))


static func terrain_contract(layout: Dictionary) -> Dictionary:
	return StadiumSalvageCarItems.terrain_contract(base(layout))


static func contacts_layout(layout: Dictionary) -> Dictionary:
	return with_base(layout, StadiumSalvageCarItems.contacts_layout(base(layout)))


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumSalvageCarItems.graph_for(base(layout))


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"layout": LAYOUT_VERSION,
				"family": FAMILY,
				"base": 40,
				"model": StadiumMasteryBannerModels.signature(),
				"item": ITEM,
				"host": HOST_ITEM,
				"socket": SOCKET,
				"fields": FIELDS,
				"capacity": CAPACITY,
				"host_geometry": "original-lower-facade-no-player-tunnel-adapter",
				"source": "BU2",
				"copy_policy": "earned-only-exact-host-store-dependent-no-transfer-v1",
				"clearance": "complete-oriented-facade-reservation-excludes-overlapping-crests-v1",
				"identity": "frozen-first-standard-d4-title-era-v1",
				"animation": false,
				"role": "DECORATIVE_AFTER_TERMINAL",
				"live_units": 0,
				"shop": false,
				"gameplay_bonus": false,
				"night_qualified": false
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func geometry(tier: String, layout: Dictionary) -> String:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return StadiumWaterfallItems.geometry(tier, layout)
	return (StadiumSalvageCarItems.geometry(tier, base(layout)) + ":" + signature()).sha256_text()


static func candidates(layout: Dictionary, stock: StadiumStock) -> Array[Dictionary]:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return candidates(StadiumWaterfallItems.base(layout), stock)
	var result: Array[Dictionary] = []
	if stock == null or not is_family(layout):
		return result
	for raw: Variant in layout.get("hosts", []):
		if (
			raw is Dictionary
			and raw.get("copy") is String
			and stock.copies.has(raw.copy)
			and stock.copies[raw.copy].item == HOST_ITEM
			and raw.get("site", "") in StadiumBaselineSites.SITES
			and _unaltered_facade(layout, raw.copy)
		):
			result.append({"host": raw.copy, "socket": SOCKET, "host_site": raw.site})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.host < b.host)
	return result


static func row(copy: String, host: Dictionary, earned: Dictionary) -> Dictionary:
	if (
		host.get("item", "") != HOST_ITEM
		or not String(host.get("model", "")).is_empty()
		or host.get("site", "") not in StadiumBaselineSites.SITES
		or not StadiumPennantRewards.valid_mastery_record(earned)
	):
		return {}
	var socket: Dictionary = StadiumMasteryBannerModels.socket(host.item)
	var pose: Transform3D = (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(host.yaw))), host.position)
		* socket.transform
	)
	return {
		"copy": copy,
		"item": ITEM,
		"host": host.copy,
		"host_item": host.item,
		"host_site": host.site,
		"socket": SOCKET,
		"site": host.site + ":" + SOCKET,
		"position": pose.origin,
		"yaw": rad_to_deg(pose.basis.get_euler().y),
		"role": "DECORATIVE_AFTER_TERMINAL",
		"earned": earned.duplicate(true)
	}


static func bounds(placed: Dictionary) -> AABB:
	return (
		Transform3D(Basis(Vector3.UP, deg_to_rad(float(placed.yaw))), placed.position)
		* StadiumMasteryBannerModels.ENVELOPE
	)


static func validate(layout: Dictionary, stock: StadiumStock, tier: String) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return StadiumWaterfallItems.validate(layout, stock, tier)
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("mastery_banners") is Array
		or layout.mastery_banners.size() > CAPACITY
	):
		return StadiumStarterLayout._error(
			"Unknown earned mastery-banner layout or socket capacity."
		)
	var checked: Dictionary = StadiumSalvageCarItems.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	checked["mastery_banner_placements"] = []
	if layout.mastery_banners.is_empty():
		return checked
	var active: Dictionary = {}
	for placed: Dictionary in checked.placements:
		active[placed.copy] = placed
	var prior: String = ""
	for raw: Variant in layout.mastery_banners:
		if not raw is Dictionary or not SeasonOwnership._keys(raw, FIELDS):
			return StadiumStarterLayout._error(
				"A mastery banner requires its exact earned copy, host and BANNER-WALL socket."
			)
		for field: String in FIELDS:
			if not raw[field] is String:
				return StadiumStarterLayout._error(
					"Mastery-banner references must be exact strings."
				)
		var key: String = raw.host + ":" + raw.socket
		if (
			stock == null
			or not stock.copies.has(raw.copy)
			or not checked.stored.has(raw.copy)
			or not active.has(raw.host)
			or raw.socket != SOCKET
			or key <= prior
		):
			return StadiumStarterLayout._error(
				"Use one distinct earned banner per exact installed BANNER-WALL host."
			)
		if not _unaltered_facade(layout, raw.host):
			return StadiumStarterLayout._error(
				"BANNER-WALL requires the original lower facade, not a player-tunnel-adapted host."
			)
		var owned: Dictionary = stock.copies[raw.copy]
		if (
			owned.get("item", "") != ITEM
			or owned.get("source", "") != "mastery-v1"
			or not StadiumPennantRewards.valid_mastery_record(owned.get("earned"))
		):
			return StadiumStarterLayout._error(
				"Only a validated first Standard mastery title can supply this banner."
			)
		var placed: Dictionary = row(raw.copy, active[raw.host], owned.earned)
		if placed.is_empty():
			return StadiumStarterLayout._error(
				"BANNER-WALL is available only on the exact current ST-029 lower-stand facade."
			)
		var reserve: AABB = bounds(placed)
		if not StadiumProperty.contains(tier, reserve) or not StadiumClubSites._outside(reserve):
			return StadiumStarterLayout._error(
				"The complete banner and fixing rail must fit outside-play owned property."
			)
		for other: Dictionary in checked.placements:
			if other.copy == raw.host:
				continue  # Only this exact facade may touch its fixing brackets.
			if other.item == "ST-042" and other.get("host", "") == raw.host:
				return StadiumStarterLayout._error(
					"Store the overlapping facade crest before mounting this mastery banner."
				)
			if StadiumFacilityItems._overlaps(placed, other):
				return StadiumStarterLayout._error(
					(
						"The whole BANNER-WALL reservation conflicts with "
						+ other.site
						+ "; explicitly store one copy first."
					)
				)
		checked.placements.append(placed)
		checked.mastery_banner_placements.append(placed)
		checked.stored.erase(raw.copy)
		prior = key
	checked.night_qualified = false
	checked["night_unqualified_reason"] = \
		("The static historical mastery-banner display awaits rendered Night " + "qualification.")
	return StadiumHomeLayout.terrain_admission(layout, tier, checked)


static func place(
	layout: Dictionary,
	stock: StadiumStock,
	copy: String,
	host: String,
	socket: String = SOCKET,
	access: Array[String] = []
) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return StadiumWaterfallItems.with_base(
			layout, place(StadiumWaterfallItems.base(layout), stock, copy, host, socket, access)
		)
	if host.is_empty():
		return store_copy(layout, copy)
	if (
		stock == null
		or not stock.copies.has(copy)
		or stock.copies[copy].item != ITEM
		or socket != SOCKET
	):
		return layout.duplicate(true)
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	for candidate: Dictionary in candidates(result, stock):
		if candidate.host == host and candidate.socket == socket:
			result.mastery_banners = result.mastery_banners.filter(
				func(value: Dictionary) -> bool: return value.copy != copy
			)
			result.mastery_banners.append({"copy": copy, "host": host, "socket": socket})
			result.mastery_banners.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return a.host + ":" + a.socket < b.host + ":" + b.socket
			)
			return result  # Occupancy/conflicts are rejected atomically, never displaced.
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return StadiumWaterfallItems.with_base(
			layout, store_copy(StadiumWaterfallItems.base(layout), copy)
		)
	var result: Dictionary = layout.duplicate(true)
	if is_family(result) and result.get("mastery_banners") is Array:
		result.mastery_banners = result.mastery_banners.filter(
			func(value: Dictionary) -> bool: return value.copy != copy
		)
	return result


static func prune(layout: Dictionary) -> Dictionary:
	if (
		StadiumWaterfallItems.is_family(layout)
		or (
			StadiumLightingKitItems.is_family(layout)
			or (
				StadiumOutfieldPlazaItems.is_family(layout)
				or StadiumWaterfallLiveItems.is_family(layout)
			)
		)
	):
		return StadiumWaterfallItems.prune(layout)
	if not is_family(layout):
		return layout.duplicate(true)
	return with_base(layout, StadiumSalvageCarItems.prune(base(layout)))


static func transition(before: Dictionary, after: Dictionary) -> Dictionary:
	for previous: Dictionary in before.get("mastery_banners", []):
		for next: Dictionary in after.get("mastery_banners", []):
			if previous.copy == next.copy and not _same_host(before, after, previous.host):
				return (
					StadiumStarterLayout
					. _error(
						(
							"Changing or storing a banner's exact host also stores the banner; it cannot "
							+ "transfer to a replacement."
						)
					)
				)
	return {"ok": true, "error": ""}


static func _same_host(before: Dictionary, after: Dictionary, copy: String) -> bool:
	for old: Dictionary in before.get("hosts", []):
		if old.get("copy", "") != copy:
			continue
		for next: Dictionary in after.get("hosts", []):
			if next.get("copy", "") == copy and ClubCareer.same(old, next):
				return true
	return false


static func _unaltered_facade(layout: Dictionary, copy: String) -> bool:
	for raw: Variant in layout.get("player_tunnels", []):
		if raw is Dictionary and raw.get("lower", "") == copy:
			return false  # The adapter may cut or mirror the exact facade region.
	return true

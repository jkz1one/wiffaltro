class_name StadiumWaterfallAnimationLayout
extends RefCounted
## Explicit presentation successor retaining its exact45 or46 base. No capability migration.
const VERSION: int = 47
const FAMILY: String = "reference-owned-waterfall-animation-v47"
const BASES: Array[int] = [45, 46]


static func is_family(value: Variant) -> bool:
	return value is Dictionary and SeasonOwnership._whole(value.get("version"), VERSION, VERSION)


static func upgrade(layout: Dictionary, access: Array[String] = []) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = (
		layout.duplicate(true)
		if StadiumLowWallLayout.is_family(layout)
		else StadiumWaterfallLiveItems.upgrade(layout, access)
	)
	if not (StadiumWaterfallLiveItems.is_family(result) or StadiumLowWallLayout.is_family(result)):
		return {}
	result["animation_base"] = int(result.version)
	result.version = VERSION
	result.family = FAMILY
	result["waterfall_motion"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout) or not SeasonOwnership._whole(layout.get("animation_base"), 45, 46):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = int(result.animation_base)
	result.family = (
		StadiumWaterfallLiveItems.FAMILY if result.version == 45 else StadiumLowWallLayout.FAMILY
	)
	result.erase("animation_base")
	result.erase("waterfall_motion")
	return result


static func presentation_base(layout: Dictionary) -> Dictionary:
	var result: Dictionary = base(layout)
	return StadiumLowWallLayout.base(result) if StadiumLowWallLayout.is_family(result) else result


static func with_base(layout: Dictionary, replacement: Dictionary) -> Dictionary:
	if not is_family(layout) or not layout.get("waterfall_motion") is Array:
		return {}
	var prior: Dictionary = base(layout)
	if prior.is_empty():
		return {}
	var result: Dictionary = replacement.duplicate(true)
	if not (StadiumWaterfallLiveItems.is_family(result) or StadiumLowWallLayout.is_family(result)):
		result = (
			StadiumLowWallLayout.with_base(prior, result)
			if StadiumLowWallLayout.is_family(prior)
			else StadiumWaterfallLiveItems.with_base(prior, result)
		)
	if not (StadiumWaterfallLiveItems.is_family(result) or StadiumLowWallLayout.is_family(result)):
		return {}
	result = upgrade(result)
	# Store removes only that copy's motion opt-in. It never arms a replacement copy.
	var placed: Array[String] = placed_copies(result)
	for copy: String in layout.waterfall_motion:
		if placed.has(copy):
			result.waterfall_motion.append(copy)
	return result


static func placed_copies(layout: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in layout.get("waterfalls", []) + layout.get("live_waterfalls", []):
		result.append(row.copy)
	for kit: Dictionary in layout.get("outfield_plaza", []):
		for row: Dictionary in kit.get("occupants", []):
			result.append(row.copy)
	return result


static func select(
	layout: Dictionary, copy: String, enabled: bool, access: Array[String] = []
) -> Dictionary:
	var result: Dictionary = upgrade(layout, access)
	if result.is_empty():
		return layout.duplicate(true)
	result.waterfall_motion.erase(copy)
	if enabled and placed_copies(result).has(copy):
		result.waterfall_motion.append(copy)
	result.waterfall_motion.sort()
	return result


static func store_copy(layout: Dictionary, copy: String) -> Dictionary:
	var retained: Dictionary = base(layout)
	var projected: Dictionary = (
		StadiumLowWallLayout.base(retained)
		if StadiumLowWallLayout.is_family(retained)
		else retained
	)
	projected = StadiumWaterfallLiveItems.store_copy(projected, copy)
	projected = StadiumOutfieldPlazaItems.store_copy(projected, copy)
	projected = StadiumWaterfallItems.store_copy(projected, copy)
	if StadiumLowWallLayout.is_family(retained):
		projected = StadiumLowWallLayout.with_base(retained, projected)
	return with_base(layout, projected)


static func validate(
	layout: Variant,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String],
	tier: String,
	boards: StadiumScoreboardOwnership = null
) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.get("waterfall_motion") is Array
		or layout.waterfall_motion.size() > 3
		or not StadiumOwnedLayout._complete_ownership(stock, pieces, boards)
	):
		return StadiumStarterLayout._error("Complete owned moving-water layout required.")
	var projected: Dictionary = base(layout)
	if projected.is_empty():
		return StadiumStarterLayout._error("Unknown retained waterfall base revision.")
	var checked: Dictionary = StadiumOwnedLayout.validate(
		projected, stock, pieces, access, tier, boards
	)
	if not checked.ok:
		return checked  # In particular,46 still forbids live-waterfall compositions.
	var eligible: Dictionary = {}
	for row: Dictionary in checked.placements:
		if row.item == "ST-046":
			eligible[row.copy] = row
	var prior: String = ""
	for value: Variant in layout.waterfall_motion:
		if not value is String or value <= prior or not eligible.has(value):
			return (
				StadiumStarterLayout
				. _error(
					(
						"Motion needs each exact placed waterfall copy once, in canonical order. Stored "
						+ "copies cannot animate."
					)
				)
			)
		prior = value
	checked["waterfall_motion_copies"] = layout.waterfall_motion.duplicate()
	return checked


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"family": FAMILY,
				"base_revisions": BASES,
				"copy_policy": "exact-current-placed-copy-opt-in-store-clears-v1",
				"visual": StadiumWaterfallAnimatedModels.VERSION,
				"water_shader": StadiumWaterfallMotionModels.CODE.sha256_text(),
				"physics": "unchanged-live45-or-decorative46-no-new-collision",
				"phase_speed": StadiumWaterfallMotionOwner.CYCLES_PER_SECOND,
				"gate": "idle-only-freeze-action-pause-hitch-no-catchup-v1"
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
			{
				"base": StadiumOwnedLayout.geometry(tier, base(layout)),
				"animation": signature(),
				"base_revision": int(layout.get("animation_base", 0))
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumOwnedLayout.graph_for(base(layout))


static func boundary_signature(layout: Dictionary) -> String:
	var graph: StadiumRecipeBoundary = graph_for(layout)
	return "" if graph == null else graph.signature()

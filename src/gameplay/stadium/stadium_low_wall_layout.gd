class_name StadiumLowWallLayout
extends RefCounted
## Complete ownership only. Never activate through the stock-only family chain.
const Base = preload("res://src/gameplay/stadium/stadium_waterfall_live_items.gd")
const VERSION: int = 46
const FAMILY: String = "reference-playable-low-wall-v46"
const RUNTIME_READY: bool = false


static func is_family(value: Variant) -> bool:
	return value is Dictionary and SeasonOwnership._whole(value.get("version"), VERSION, VERSION)


static func upgrade(layout: Dictionary, access: Array[String]) -> Dictionary:
	if is_family(layout):
		return layout.duplicate(true)
	var result: Dictionary = Base.upgrade(layout, access)
	if not Base.is_family(result):
		return {}
	result.version = VERSION
	result.family = FAMILY
	result["low_wall"] = StadiumLowWallManifest.empty()
	return result


static func base(layout: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = Base.LAYOUT_VERSION
	result.family = Base.FAMILY
	result.erase("low_wall")
	return result


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	var projected: Dictionary = base(layout)
	if projected.is_empty():
		return null
	if layout.get("low_wall") == StadiumLowWallManifest.empty():
		return Base.graph_for(projected)
	return StadiumLowWallGraph.create_low(
		StadiumReceiverOwnedItems.base(projected), layout.get("low_wall", {}).get("profile", "")
	)


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"family": FAMILY,
				"recipes": StadiumLowWallRecipes.signature(),
				"models": StadiumLowWallModels.VERSION,
				"ownership": "complete-distinct-low-standard-v1",
				"night": false
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
		. stringify({"base": Base.geometry(tier, base(layout)), "low": signature()}, "", true, true)
		. sha256_text()
	)


static func validate(
	layout: Variant,
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	access: Array[String],
	tier: String
) -> Dictionary:
	if (
		not is_family(layout)
		or layout.get("family") != FAMILY
		or not layout.has("low_wall")
		or pieces == null
		or stock == null
		or StadiumWallPieceOwnership.from_data(pieces.to_data(), stock.capacity_count()) == null
	):
		return StadiumStarterLayout._error("Complete owned low-wall layout required.")
	var projected: Dictionary = base(layout)
	if not projected.get("live_waterfalls", []).is_empty():
		return (
			StadiumStarterLayout
			. _error(
				(
					"Store the live in-field waterfall before selecting this low-wall revision; combined "
					+ "live contact qualification is pending. Decorative plaza waterfalls remain supported."
				)
			)
		)
	if Base.is_terrain(projected):
		return (
			StadiumStarterLayout
			. _error(
				"This low-wall revision qualifies flat ground only; store the terrain profile explicitly first."
			)
		)
	var checked: Dictionary = Base.validate(projected, stock, tier)
	if not checked.ok:
		return checked
	if not StadiumSurfaceLayout.owned(projected, access):
		return StadiumStarterLayout._error("Selected field preparation is not owned.")
	var manifest: Dictionary = StadiumLowWallManifest.validate(layout.low_wall, stock, pieces.stock)
	if not manifest.ok:
		return manifest
	checked["low_panels"] = manifest.panels
	checked["pieces_stored"] = pieces.stock.copies.keys()
	checked.pieces_stored.sort()
	checked.night_qualified = false
	if manifest.panels.is_empty():
		return checked
	if not layout.walls.back.is_empty():
		return StadiumStarterLayout._error(
			"Store the existing complete back wall before installing a low profile."
		)
	# Low hosts are not interchangeable with the historical 3.25 m host contracts.
	if not layout.get("wall_top_terrace", []).is_empty():
		return StadiumStarterLayout._error(
			"Store standard-height wall terraces before selecting a low-wall profile."
		)
	for placement: Dictionary in checked.placements:
		if placement.item in ["ST-021", "ST-064"]:
			return StadiumStarterLayout._error(
				"This low-wall revision does not qualify foul-pole or wall-mounted panel hosts."
			)
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		return StadiumStarterLayout._error("Unknown low-wall graph.")
	for row: Dictionary in manifest.panels:
		var size: Vector3 = Vector3(row.width, row.height, StadiumRecipeBoundary.THICKNESS)
		var box: AABB = (
			StadiumWallRecipes.placement(row) * AABB(Vector3(-size.x / 2, 0, -size.z), size)
		)
		if not StadiumProperty.contains(tier, box):
			return StadiumStarterLayout._error("Low wall exceeds owned land.")
		for placement: Dictionary in checked.placements:
			var reserves: Array[AABB] = [StadiumHomeLayout.bounds(placement)]
			if placement.item == "ST-111":
				reserves.clear()
				for component: Dictionary in StadiumLightingKitModels.components(placement.site):
					reserves.append(component.bounds)
			for reserve: AABB in reserves:
				if box.intersects(reserve):
					return StadiumStarterLayout._error(
						"Low wall overlaps an existing paid reservation."
					)
	for key: String in manifest.standard_used:
		if not checked.stored.has(key):
			return StadiumStarterLayout._error("A standard panel copy is already placed elsewhere.")
		checked.stored.erase(key)
	for key: String in manifest.pieces_used:
		checked.pieces_stored.erase(key)
	return checked


static func boundary_signature(layout: Dictionary) -> String:
	var graph: StadiumRecipeBoundary = graph_for(layout)
	return "" if graph == null else graph.signature()


static func with_base(layout: Dictionary, replacement: Dictionary) -> Dictionary:
	if not is_family(layout):
		return {}
	var result: Dictionary = (
		replacement.duplicate(true)
		if Base.is_family(replacement)
		else Base.with_base(base(layout), replacement)
	)
	if not Base.is_family(result):
		return {}
	result.version = VERSION
	result.family = FAMILY
	result["low_wall"] = layout.low_wall.duplicate(true)
	return result

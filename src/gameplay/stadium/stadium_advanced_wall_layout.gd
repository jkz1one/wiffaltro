class_name StadiumAdvancedWallLayout
extends RefCounted
## Isolated v13 grammar. No production dispatch, shop or frozen fixture activation yet.

const VERSION: int = 13
const FAMILY: String = "reference-advanced-walls-v13"
const RUNTIME_READY: bool = false
const OUTSIDE_CLEARANCE: float = 0.5


static func signature() -> String:
	var graphs: Dictionary = {}
	var rows: Dictionary = {}
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		graphs[shape] = StadiumAdvancedWallManifest.graph(shape).signature()
		rows[shape] = StadiumOffsetWallRecipes.back("ST-024") if shape == "offset_gables" \
			else StadiumHeightWallRecipes.rows(shape, "ST-024")
	return JSON.stringify({"version": VERSION, "family": FAMILY, "graphs": graphs, "rows": rows,
		"height_model": StadiumHeightWallStudy.VERSION, "offset_model": StadiumOffsetWallModels.VERSION,
		"surface": StadiumSurfaceLayout.signature(), "walls": StadiumWallItems.signature(),
		"manifest": StadiumAdvancedWallManifest.VERSION, "assembly": StadiumAdvancedOwnedAssembly.VERSION,
		"outside_clearance": OUTSIDE_CLEARANCE,
		"night": false}, "", true, true).sha256_text()


static func geometry(tier: String) -> String:
	return (StadiumHomeLayout.geometry(tier, {"version": 12}) + ":" + signature()).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	if not SeasonOwnership._whole(layout.get("version"), 12, 12):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = VERSION
	result.family = FAMILY
	result["advanced_back"] = StadiumAdvancedWallManifest.empty()
	return result


static func base(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	result.erase("advanced_back")
	result.version = 12
	result.family = StadiumSurfaceLayout.FAMILY
	return result


static func validate(layout: Variant, stock: StadiumStock, ownership: StadiumWallPieceOwnership,
	tier: String, surface_access: Array[String]) -> Dictionary:
	if not layout is Dictionary or not SeasonOwnership._keys(layout, ["version", "family", "receiver",
		"obstacles", "seating", "styles", "displays", "ground", "bleachers", "target", "net", "lights",
		"bases", "walls", "surface", "advanced_back"]) \
		or not SeasonOwnership._whole(layout.version, VERSION, VERSION) \
		or not layout.family is String or layout.family != FAMILY:
		return StadiumStarterLayout._error("Unknown advanced wall layout.")
	if stock == null or ownership == null or ownership.stock == null \
		or StadiumWallPieceOwnership.from_data(
		ownership.to_data(), stock.capacity_count()) == null:
		return StadiumStarterLayout._error("Explicit exact wall-piece ownership is required.")
	var checked: Dictionary = StadiumHomeLayout.validate(base(layout), stock, tier)
	if not checked.ok:
		return checked
	if not StadiumSurfaceLayout.owned(layout, surface_access):
		return StadiumStarterLayout._error("This surface selection is not owned.")
	var walls: Dictionary = StadiumAdvancedWallManifest.validate(
		layout.advanced_back, stock, ownership.stock)
	if not walls.ok:
		return walls
	return _bind(layout, stock, ownership, tier, checked, walls)


static func _bind(layout: Dictionary, stock: StadiumStock, ownership: StadiumWallPieceOwnership,
	tier: String, checked: Dictionary, walls: Dictionary) -> Dictionary:
	checked["advanced_panels"] = walls.panels
	checked["pieces_stored"] = ownership.stock.copies.keys()
	checked.pieces_stored.sort()
	checked.night_qualified = false
	if walls.panels.is_empty():
		return checked
	if not layout.walls.back.is_empty():
		return StadiumStarterLayout._error("Select one complete back wall, never overlapping backs.")
	var outline: StadiumRecipeBoundary = StadiumAdvancedWallManifest.graph(layout.advanced_back.shape)
	for placement: Dictionary in checked.placements:
		if placement.role == "DECORATIVE_AFTER_TERMINAL" and not outside_play(
			outline, StadiumHomeLayout.bounds(placement)):
			return StadiumStarterLayout._error("An outside-play object enters the new field outline.")
	for row: Dictionary in walls.panels:
		var size: Vector3 = Vector3(row.width, row.height, 0.35)
		var box: AABB = StadiumWallRecipes.placement(row) * AABB(Vector3(-size.x / 2, 0, -0.35), size)
		if not StadiumProperty.contains(tier, box):
			return StadiumStarterLayout._error("The complete advanced wall exceeds this property.")
		for placement: Dictionary in checked.placements:
			if box.intersects(StadiumHomeLayout.bounds(placement)):
				return StadiumStarterLayout._error("An existing object overlaps the advanced wall.")
	for key: String in walls.standard_used:
		if not checked.stored.has(key) or not stock.copies.has(key):
			return StadiumStarterLayout._error("A standard wall copy is already used elsewhere.")
		checked.stored.erase(key)
	for key: String in walls.pieces_used:
		checked.pieces_stored.erase(key)
	checked["advanced_shape"] = layout.advanced_back.shape
	return checked


static func outside_play(outline: StadiumRecipeBoundary, box: AABB) -> bool:
	if outline == null:
		return false
	var rect: Rect2 = Rect2(Vector2(box.position.x, box.position.z),
		Vector2(box.size.x, box.size.z)).grow(OUTSIDE_CLEARANCE)
	var corners: PackedVector2Array = [rect.position,
		Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	return Geometry2D.intersect_polygons(outline.polygon(), corners).is_empty()

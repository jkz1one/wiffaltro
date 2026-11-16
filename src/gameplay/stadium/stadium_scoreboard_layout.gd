class_name StadiumScoreboardLayout
extends RefCounted
## Explicit complete-owner layout14 grammar; runtime admission uses its separate readiness gate.

const VERSION: int = 14
const FAMILY: String = "reference-scoreboard-tiers-v14"
const RUNTIME_READY: bool = true


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "family": FAMILY,
		"advanced": StadiumAdvancedWallLayout.signature(), "models": StadiumScoreboardModels.signature(),
		"legacy_policy": "advanced-back-explicit-store-or-replace-v1",
		"legacy_cards": [[-1.4, 0, 1.4], 3.73, 0.15, 1.12, 0.34],
		"contact_margin": 0.00001, "night": false},
		"", true, true).sha256_text()


static func geometry(tier: String) -> String:
	return (StadiumAdvancedWallLayout.geometry(tier) + ":" + signature()).sha256_text()


static func upgrade(layout: Dictionary) -> Dictionary:
	if not SeasonOwnership._whole(layout.get("version"), 13, 13):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = VERSION
	result.family = FAMILY
	result["scoreboards"] = []
	return result


static func base(layout: Dictionary) -> Dictionary:
	var result: Dictionary = layout.duplicate(true)
	result.erase("scoreboards")
	result.version = 13
	result.family = StadiumAdvancedWallLayout.FAMILY
	return result


static func validate(layout: Variant, stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership, access: Array[String], tier: String) -> Dictionary:
	if not layout is Dictionary \
		or not SeasonOwnership._whole(layout.get("version"), VERSION, VERSION) \
		or not layout.get("family") is String or layout.family != FAMILY \
		or not layout.get("scoreboards") is Array \
		or layout.scoreboards.size() > StadiumScoreboardSites.SITES.size():
		return StadiumStarterLayout._error("Unknown scoreboard layout family or rows.")
	if stock == null or pieces == null or pieces.stock == null or boards == null \
		or StadiumScoreboardOwnership.from_data(boards.to_data(),
			stock.capacity_count() + pieces.stock.copies.size()) == null:
		return StadiumStarterLayout._error("Explicit complete scoreboard ownership is required.")
	var checked: Dictionary = StadiumAdvancedWallLayout.validate(
		base(layout), stock, pieces, tier, access)
	if not checked.ok:
		return checked
	var graph: StadiumRecipeBoundary = StadiumOwnedLayout.graph_for(base(layout))
	if graph == null:
		graph = StadiumRecipeBoundary.create("straight")
	if not layout.advanced_back.shape.is_empty():
		for placement: Dictionary in checked.placements:
			if placement.item == "ST-039" and not StadiumScoreboardSites.legacy_clear(placement, graph):
				return StadiumStarterLayout._error(
					"This advanced wall hides the old board; explicitly store or replace that copy.")
	return _boards(layout.scoreboards, checked, stock, boards, tier, graph)


static func _boards(rows: Array, checked: Dictionary, stock: StadiumStock,
	boards: StadiumScoreboardOwnership, tier: String, graph: StadiumRecipeBoundary) -> Dictionary:
	checked["scoreboards_stored"] = boards.copies.keys()
	checked.scoreboards_stored.sort()
	checked["board_placements"] = []
	var previous: String = ""
	for row: Variant in rows:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["copy", "item", "model", "site"]) \
			or not row.copy is String or not row.item is String or not row.model is String \
			or not row.site is String or row.site <= previous \
			or not StadiumScoreboardModels.MODELS.has(row.item) \
			or row.model != StadiumScoreboardModels.MODELS[row.item]:
			return StadiumStarterLayout._error("Each board requires an exact copy, model and ordered site.")
		var copies: Dictionary = boards.copies if row.item == "ST-090" else stock.copies
		var stored: Array = checked.scoreboards_stored if row.item == "ST-090" else checked.stored
		if not copies.has(row.copy) or copies[row.copy].item != row.item or not stored.has(row.copy):
			return StadiumStarterLayout._error("The board copy is unowned or already used elsewhere.")
		var site: Dictionary = StadiumScoreboardSites.inspect(row.item, row.site, tier, graph)
		if not site.ok:
			return site
		if not _walls_clear(site.bounds, checked, graph):
			return StadiumStarterLayout._error("The scoreboard overlaps the field boundary.")
		for other: Dictionary in checked.placements + checked.board_placements:
			if _overlaps(site.bounds, bounds(other)):
				return StadiumStarterLayout._error("The scoreboard overlaps existing field furniture.")
		var placement: Dictionary = row.duplicate(true)
		placement.merge({"position": site.pose.origin, "yaw": 180, "role": site.role})
		checked.board_placements.append(placement.duplicate(true))
		stored.erase(row.copy)
		previous = row.site
	checked.night_qualified = false
	return checked


static func bounds(placement: Dictionary) -> AABB:
	return StadiumScoreboardModels.bounds(placement) if placement.has("model") \
		else StadiumHomeLayout.bounds(placement)


static func preview(before: Dictionary, after: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String], tier: String) -> Dictionary:
	var old: Dictionary = StadiumAdvancedWallLayout.validate(before, stock, pieces, tier, access) \
		if SeasonOwnership._whole(before.get("version"), 13, 13) \
		else validate(before, stock, pieces, boards, access, tier)
	var next: Dictionary = validate(after, stock, pieces, boards, access, tier)
	if not old.ok or not next.ok:
		return StadiumStarterLayout._error(old.error if not old.ok else next.error)
	var removed: Array[String] = []
	var moved: Array[String] = []
	var active: Dictionary = {}
	for row: Dictionary in _physical_rows(next):
		active[row.copy] = row
	for row: Dictionary in _physical_rows(old):
		if not active.has(row.copy):
			removed.append(row.copy)
		elif not ClubCareer.same(row, active[row.copy]):
			moved.append(row.copy)
	removed.sort()
	moved.sort()
	return {"ok": true, "error": "", "cost": 0, "stored": next.stored.duplicate(),
		"pieces_stored": next.pieces_stored.duplicate(),
		"scoreboards_stored": next.scoreboards_stored.duplicate(),
		"displaced": removed, "moved": moved, "placement": next}


static func _overlaps(a: AABB, b: AABB) -> bool:
	return a.grow(0.00001).intersects(b)


static func _walls_clear(box: AABB, checked: Dictionary, graph: StadiumRecipeBoundary) -> bool:
	for row: Dictionary in checked.wall_panels:
		var size: Vector3 = StadiumWallPanelModels.dimensions(row.item, row.span)
		if _overlaps(box, StadiumWallRecipes.placement(row)
			* AABB(Vector3(-size.x / 2, 0, -size.z), size)):
			return false
	for row: Dictionary in checked.advanced_panels:
		var size: Vector3 = Vector3(row.width, row.height, 0.35)
		if _overlaps(box, StadiumWallRecipes.placement(row)
			* AABB(Vector3(-size.x / 2, 0, -size.z), size)):
			return false
	# Include the actual joined outer vertices; acute miters exceed a fixed XY margin.
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var slab: AABB = AABB(Vector3(row.a.x, 0, row.a.y), Vector3.ZERO)
		for point: Vector2 in [row.b, graph.outer_vertex(index),
			graph.outer_vertex((index + 1) % rows.size())]:
			slab = slab.expand(Vector3(point.x, row.height, point.y))
		if _overlaps(box, slab):
			return false
	return true


static func _physical_rows(checked: Dictionary) -> Array:
	return checked.placements + checked.get("board_placements", []) \
		+ checked.wall_panels + checked.advanced_panels

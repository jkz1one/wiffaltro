class_name StadiumMountedScoreboardLayout
extends RefCounted
## Complete-owner layout15 with explicit mounted-runtime admission.

const VERSION: int = 15
const FAMILY: String = "reference-mounted-scoreboards-v15"
const RUNTIME_READY: bool = true
const KEYS: Array[String] = ["version", "family", "receiver", "obstacles", "seating", "styles",
	"displays", "ground", "bleachers", "target", "net", "lights", "bases", "walls", "surface",
	"advanced_back", "scoreboards", "mount_catalog"]


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "family": FAMILY,
		"complete14": StadiumScoreboardLayout.signature(), "mount_catalog": 1,
		"mounts": StadiumScoreboardMountCatalog.signature(1),
		"rows": ["copy", "item", "model", "site", "mount_profile"],
		"policy": "exact-three-inventory-store-or-replace-mount-v1",
		"cost": 0, "night": false}, "", true, true).sha256_text()


static func geometry(tier: String, layout: Dictionary) -> String:
	return (StadiumScoreboardLayout.geometry(tier) + ":" + signature()).sha256_text() \
		if _grammar(layout) else ""


static func upgrade(layout: Dictionary, stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	access: Array[String], tier: String, boards: StadiumScoreboardOwnership) -> Dictionary:
	if not SeasonOwnership._whole(layout.get("version"), 14, 14) \
		or not StadiumOwnedLayout._complete_ownership(stock, pieces, boards) \
		or not StadiumScoreboardLayout.validate(layout, stock, pieces, boards, access, tier).ok:
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.version = VERSION
	result.family = FAMILY
	result["mount_catalog"] = 1
	for row: Dictionary in result.scoreboards:
		row["mount_profile"] = ""
	return result if validate(result, stock, pieces, access, tier, boards).ok else {}


static func base(layout: Dictionary) -> Dictionary:
	# Validation/boundary projection only. Never relocate a mounted board to a legacy socket.
	if not _grammar(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.erase("mount_catalog")
	result.version = 14
	result.family = StadiumScoreboardLayout.FAMILY
	result.scoreboards = []
	return result


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumOwnedLayout.graph_for(base(layout)) if _grammar(layout) else null


static func boundary_signature(layout: Dictionary) -> String:
	return StadiumOwnedLayout.boundary_signature(base(layout)) if _grammar(layout) else ""


static func validate(layout: Variant, stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	access: Array[String], tier: String, boards: StadiumScoreboardOwnership) -> Dictionary:
	if not layout is Dictionary or not _grammar(layout):
		return StadiumStarterLayout._error("Unknown mounted scoreboard layout, catalog or exact rows.")
	if not StadiumOwnedLayout._complete_ownership(stock, pieces, boards):
		return StadiumStarterLayout._error("Explicit complete three-inventory ownership is required.")
	# This preserves complete14's advanced walls, furniture, legacy visibility and storage rules.
	var checked: Dictionary = StadiumScoreboardLayout.validate(
		base(layout), stock, pieces, boards, access, tier)
	if not checked.ok:
		return checked
	var graph: StadiumRecipeBoundary = graph_for(layout)
	if graph == null:
		graph = StadiumRecipeBoundary.create("straight")
	return _bind(layout, checked, stock, boards, tier, graph)


static func bounds(placement: Dictionary) -> AABB:
	if placement.has("mount_profile"):
		return StadiumScoreboardMountCatalog.bounds(placement, 1)
	return StadiumScoreboardLayout.bounds(placement)


static func preview(before: Dictionary, after: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, access: Array[String], tier: String,
	boards: StadiumScoreboardOwnership) -> Dictionary:
	if not StadiumOwnedLayout._complete_ownership(stock, pieces, boards):
		return StadiumStarterLayout._error("Explicit complete three-inventory ownership is required.")
	var old: Dictionary = _preview_layout(before, stock, pieces, access, tier, boards)
	var next: Dictionary = _preview_layout(after, stock, pieces, access, tier, boards)
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
		"displaced": removed, "moved": moved, "placement": next.duplicate(true)}


static func _grammar(layout: Dictionary) -> bool:
	if not SeasonOwnership._keys(layout, KEYS) \
		or not SeasonOwnership._whole(layout.get("version"), VERSION, VERSION) \
		or not layout.family is String or layout.family != FAMILY \
		or not SeasonOwnership._whole(layout.mount_catalog, 1, 1) \
		or not layout.scoreboards is Array or layout.scoreboards.size() > 4:
		return false
	var previous: String = ""
	for row: Variant in layout.scoreboards:
		if not row is Dictionary \
			or not SeasonOwnership._keys(row, ["copy", "item", "model", "site", "mount_profile"]):
			return false
		for key: String in ["copy", "item", "model", "site", "mount_profile"]:
			if not row[key] is String:
				return false
		if row.copy.is_empty() or row.site <= previous or StadiumScoreboardMountCatalog.record(
			row.item, row.model, row.site, row.mount_profile, 1).is_empty():
			return false
		previous = row.site
	return true


static func _bind(layout: Dictionary, checked: Dictionary, stock: StadiumStock,
	boards: StadiumScoreboardOwnership, tier: String, graph: StadiumRecipeBoundary) -> Dictionary:
	for row: Dictionary in layout.scoreboards:
		var copies: Dictionary = boards.copies if row.item == "ST-090" else stock.copies
		var stored: Array = checked.scoreboards_stored if row.item == "ST-090" else checked.stored
		if not copies.has(row.copy) or copies[row.copy].item != row.item or not stored.has(row.copy):
			return StadiumStarterLayout._error("The exact mounted board copy is unowned or already used.")
		var site: Dictionary = StadiumScoreboardMountCatalog.inspect(row.item, row.model, row.site,
			row.mount_profile, layout.mount_catalog, tier, graph)
		if not site.ok:
			return site
		if not StadiumScoreboardLayout._walls_clear(site.bounds, checked, graph):
			return StadiumStarterLayout._error("The complete mount overlaps the joined field boundary.")
		for other: Dictionary in checked.placements + checked.board_placements:
			if StadiumScoreboardLayout._overlaps(site.bounds, bounds(other)):
				return StadiumStarterLayout._error("The complete mount overlaps installed furniture.")
		var placement: Dictionary = row.duplicate(true)
		placement.merge({"position": site.pose.origin, "yaw": 180, "role": site.role})
		checked.board_placements.append(placement)
		stored.erase(row.copy)
	checked.night_qualified = false
	return checked.duplicate(true)


static func _preview_layout(layout: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, access: Array[String], tier: String,
	boards: StadiumScoreboardOwnership) -> Dictionary:
	return validate(layout, stock, pieces, access, tier, boards) \
		if SeasonOwnership._whole(layout.get("version"), VERSION, VERSION) else (
			StadiumOwnedLayout._preview_layout(layout, stock, pieces, access, tier, boards))


static func _physical_rows(checked: Dictionary) -> Array:
	var result: Array = StadiumOwnedLayout._physical_rows(checked).duplicate(true)
	# Merely wrapping a historical v2 socket does not move its unchanged physical copy.
	for row: Dictionary in result:
		if row.get("mount_profile") == "":
			row.erase("mount_profile")
	return result

class_name StadiumPoolOwnedLayout
extends RefCounted
## Paid-copy layout grammar. Data validation is not native runtime qualification.
# gdlint: disable=max-returns

const VERSION: int = 16
const FAMILY: String = "reference-owned-pool-v16"
const KEYS: Array[String] = ["version", "family", "receiver", "obstacles", "seating", "styles",
	"displays", "ground", "bleachers", "target", "net", "lights", "bases", "walls", "surface", "pool"]
const LIVE_UNITS: int = 4


static func signature() -> String:
	return JSON.stringify({"version": VERSION, "family": FAMILY,
		"surface": StadiumSurfaceLayout.signature(), "contract": StadiumPoolContract.ID,
		"footprint": StadiumPoolOwnedFootprint.signature(), "position_grid": 0.5,
		"model": StadiumPoolModels.VERSION, "interior": StadiumPoolInteriorV2.ID,
		"interior_model": StadiumPoolInteriorV2.MODEL_ID,
		"water_volume": StadiumPoolInteriorV2.VOLUME_ID,
		"water_epsilon": StadiumPoolInteriorV2.EPSILON_M,
		"radii": [StadiumPoolContract.OUTER_RADIUS, StadiumPoolContract.INNER_RADIUS,
			StadiumPoolContract.RESERVATION_RADIUS, StadiumPoolOwnedFootprint.ROUTE_RADIUS],
		"heights": [StadiumPoolContract.WALL_HEIGHT, StadiumPoolContract.WATER_HEIGHT,
			StadiumPoolContract.VISUAL_HEIGHT], "segments": StadiumPoolContract.SEGMENTS,
		"ladder": [StadiumPoolContract.LADDER.position.x, StadiumPoolContract.LADDER.position.y,
			StadiumPoolContract.LADDER.position.z, StadiumPoolContract.LADDER.size.x,
			StadiumPoolContract.LADDER.size.y, StadiumPoolContract.LADDER.size.z],
		"yaw": [0, 90, 180, 270], "y": 0, "scale": [1, 1, 1], "live_units": LIVE_UNITS,
		"geometry_policy": "ordinary-backyard-receiver-only-preserved-surface-v1",
		"ownership": "exact-paid-copy-three-inventory-prefix-v1"}, "", true, true).sha256_text()


static func geometry(tier: String, layout: Dictionary) -> String:
	if tier != "backyard" or not _grammar(layout):
		return ""
	# Semantic versions remain replayable after unrelated source changes. Native source
	# provenance is bound by the installed authority/report, never by the purchase catalog.
	return (StadiumHomeLayout.geometry(tier, base(layout)) + ":" + signature()).sha256_text()


static func base(layout: Dictionary) -> Dictionary:
	if not _grammar(layout):
		return {}
	var result: Dictionary = layout.duplicate(true)
	result.erase("pool")
	result.version = StadiumSurfaceLayout.VERSION
	result.family = StadiumSurfaceLayout.FAMILY
	return result


static func current(layout: Dictionary, stock: StadiumStock, access: Array[String],
	tier: String) -> Dictionary:
	# This never projects v13-15 away or substitutes a selected surface with a default.
	if SeasonOwnership._whole(layout.get("version"), VERSION, VERSION):
		return layout.duplicate(true) if validate(layout, stock, access, tier).ok else {}
	if not migration_error(layout, stock, access, tier).is_empty():
		return {}
	return layout.duplicate(true) if int(layout.version) == 12 else (
		StadiumSurfaceLayout.upgrade(layout, access, access.has("grass")))


static func migration_error(layout: Dictionary, stock: StadiumStock, access: Array[String],
	tier: String) -> String:
	if not SeasonOwnership._whole(layout.get("version"), 1, 12):
		return "This layout cannot migrate to Pool v16; preserve its active selections."
	if not StadiumSurfaceProgression.valid_owned(access):
		return "Complete owned surface access is required; preserve the original."
	var checked: Dictionary = StadiumHomeLayout.validate(layout, stock, tier)
	if not checked.ok:
		return checked.error
	var surface: Dictionary = layout if int(layout.version) == 12 else (
		StadiumSurfaceLayout.upgrade(layout, access, access.has("grass")))
	if not StadiumSurfaceLayout.owned(surface, access):
		return "The selected surface is not owned; preserve the original."
	return _geometry_error(surface, checked, tier)


static func upgrade(layout: Dictionary, stock: StadiumStock, access: Array[String],
	tier: String, copy: String, position: Vector2 = Vector2(12, 18), yaw: int = 0) -> Dictionary:
	var result: Dictionary = current(layout, stock, access, tier)
	if result.is_empty():
		return {}
	if int(result.version) == VERSION:
		result = base(result)
	result.version = VERSION
	result.family = FAMILY
	result["pool"] = {"copy": copy, "position": [position.x, position.y], "yaw": yaw}
	return result if validate(result, stock, access, tier).ok else {}


static func relocated(layout: Dictionary, stock: StadiumStock, access: Array[String],
	tier: String, position: Vector2, yaw: int) -> Dictionary:
	if not validate(layout, stock, access, tier).ok:
		return {}
	return upgrade(layout, stock, access, tier, layout.pool.copy, position, yaw)


static func pose(layout: Dictionary) -> Transform3D:
	return transform(Vector2(layout.pool.position[0], layout.pool.position[1]),
		int(layout.pool.yaw)) if _grammar(layout) else Transform3D.IDENTITY


static func transform(position: Vector2, yaw: int) -> Transform3D:
	# Exact cardinal columns avoid trig residue in saved/replayed rigid transforms.
	var bases: Array[Basis] = [Basis.IDENTITY,
		Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0)),
		Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)),
		Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))]
	return Transform3D(bases[int(yaw / 90)], Vector3(position.x, 0, position.y)) \
		if position.is_finite() and yaw in [0, 90, 180, 270] else Transform3D.IDENTITY


static func graph_for(layout: Dictionary) -> StadiumRecipeBoundary:
	return StadiumWallItems.graph_for(base(layout)) if _grammar(layout) else null


static func boundary_signature(layout: Dictionary) -> String:
	return StadiumWallItems.boundary_signature(base(layout)) if _grammar(layout) else ""


static func validate(layout: Variant, stock: StadiumStock, access: Array[String],
	tier: String) -> Dictionary:
	if not layout is Dictionary or not _grammar(layout):
		return StadiumStarterLayout._error("Pool needs an exact v16 layout, owned copy and grid pose.")
	if not StadiumSurfaceProgression.valid_owned(access):
		return StadiumStarterLayout._error("Complete owned surface access is required.")
	var surface: Dictionary = base(layout)
	var checked: Dictionary = StadiumSurfaceLayout.validate(surface, stock, tier)
	if not checked.ok:
		return checked
	if not StadiumSurfaceLayout.owned(surface, access):
		return StadiumStarterLayout._error("The selected surface is not owned.")
	var unsupported: String = _geometry_error(surface, checked, tier)
	if not unsupported.is_empty():
		return StadiumStarterLayout._error(unsupported)
	if not stock.copies.has(layout.pool.copy) \
		or stock.copies[layout.pool.copy].item != "ST-006" \
		or not checked.stored.has(layout.pool.copy):
		return StadiumStarterLayout._error("Pool requires one unused owned ST-006 copy.")
	if StadiumCatalog.LIVE_UNITS.get("ST-006") != LIVE_UNITS \
		or not StadiumCatalog.within_live_budget(["ST-006"]):
		return StadiumStarterLayout._error("Pool consumes all four live capacity units.")
	var footprint: Dictionary = StadiumPoolOwnedFootprint.validate(pose(layout), tier)
	if footprint.is_empty():
		return StadiumStarterLayout._error(
			"Pool reservation blocks the boundary, anchors or defender routes.")
	checked.placements.append({"copy": layout.pool.copy, "item": "ST-006", "site": "OWNED-POOL",
		"position": pose(layout).origin, "yaw": int(layout.pool.yaw),
		"role": StadiumPoolContract.LIVE})
	checked.stored.erase(layout.pool.copy)
	checked.live_units = LIVE_UNITS
	checked["footprint"] = footprint
	checked.runtime_verified = false
	checked.night_qualified = false
	return checked


static func _grammar(layout: Dictionary) -> bool:
	if not SeasonOwnership._keys(layout, KEYS) \
		or not SeasonOwnership._whole(layout.get("version"), VERSION, VERSION) \
		or not layout.family is String or layout.family != FAMILY \
		or not layout.pool is Dictionary \
		or not SeasonOwnership._keys(layout.pool, ["copy", "position", "yaw"]):
		return false
	var row: Dictionary = layout.pool
	return row.copy is String and not row.copy.is_empty() and row.copy.length() <= 160 \
		and row.position is Array and row.position.size() == 2 \
		and _coordinate(row.position[0]) and _coordinate(row.position[1]) \
		and SeasonOwnership._whole(row.yaw, 0, 270) and int(row.yaw) % 90 == 0


static func _coordinate(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and absf(float(value)) <= 64.0 and float(value) * 2.0 == floorf(float(value) * 2.0)


static func _geometry_error(surface: Dictionary, checked: Dictionary, tier: String) -> String:
	if tier != "backyard":
		return "Owned Pool currently supports the ordinary backyard only; keep the current layout."
	if checked.live_units != 0 or not surface.obstacles.is_empty():
		return "Store other live obstacles before placing Pool; its copy uses four live units."
	if checked.placements.size() != 1 or checked.placements[0].item != "ST-079" \
		or surface.receiver.is_empty() or not surface.target.is_empty() \
		or not ClubCareer.same(surface.walls, StadiumWallLayout.empty()):
		return "Pool needs the ordinary receiver-only backyard; store other active furniture and walls."
	return ""

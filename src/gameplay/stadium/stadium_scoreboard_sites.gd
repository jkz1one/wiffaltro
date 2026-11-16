class_name StadiumScoreboardSites
extends RefCounted
## New explicit reservations. No old saved site or candidate-v1 pose is moved.

const VERSION: int = 1
const SITES: Dictionary = {
	"BOARD-LEFT-v2": {"position": Vector3(-20, 0, 29), "items": ["ST-039", "ST-090"]},
	"BOARD-RIGHT-v2": {"position": Vector3(20, 0, 29), "items": ["ST-039", "ST-090"]},
	"BOARD-LARGE-v2": {"position": Vector3(36.5, 0, 31.5), "items": ["ST-040"]}}


static func signature() -> String:
	var rows: Dictionary = {}
	for id: String in SITES:
		var p: Vector3 = SITES[id].position
		rows[id] = [SITES[id].items, [p.x, p.y, p.z], 180]
	return JSON.stringify({"version": VERSION, "sites": rows,
		"clearance": 0.5, "eye": [0, 1.5, -1], "wall_height_margin": 0.35,
		"scope": "upright-region-segment-sight-triangle-v1"}, "", true, true).sha256_text()


static func pose(site: String) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), SITES[site].position)


static func inspect(item: String, site: String, land: String,
	graph: StadiumRecipeBoundary) -> Dictionary:
	if not SITES.has(site) or not SITES[site].items.has(item) or graph == null:
		return StadiumStarterLayout._error("Unknown compatible scoreboard item/site/field.")
	var tier: String = StadiumScoreboardCatalog.TIERS[item]
	var transform: Transform3D = pose(site)
	var box: AABB = transform * StadiumScoreboardTiers.envelope(tier)
	if not StadiumProperty.contains(land, box) \
		or not StadiumScoreboardTierSites._outside(box, graph):
		return StadiumStarterLayout._error("The complete board needs outside-play property clearance.")
	var regions: Dictionary = StadiumScoreboardTiers.readouts(tier)
	regions.merge(StadiumScoreboardTiers.detail_slots(tier))
	for key: String in regions:
		var region: Dictionary = regions[key]
		var bottom: Vector3 = region.point - Vector3(0, region.height / 2, 0)
		if not StadiumScoreboardTierSites._region_clear(Vector3(0, 1.5, -1),
			transform * (bottom - Vector3(region.width / 2, 0, 0)),
			transform * (bottom + Vector3(region.width / 2, 0, 0)), graph):
			return StadiumStarterLayout._error("This wall obscures the " + key + " readout.")
	return {"ok": true, "error": "", "pose": transform, "bounds": box,
		"role": "DECORATIVE_AFTER_TERMINAL", "scope": "plate-region-wall-segments-only"}


static func legacy_clear(placement: Dictionary, graph: StadiumRecipeBoundary) -> bool:
	# Frozen v1 number cards are not the new manual-v2 number regions.
	var transform: Transform3D = Transform3D(
		Basis(Vector3.UP, deg_to_rad(placement.yaw)), placement.position)
	for x: float in [-1.4, 0, 1.4]:
		if not StadiumScoreboardTierSites._region_clear(Vector3(0, 1.5, -1),
			transform * Vector3(x - 0.56, 3.56, 0.15),
			transform * Vector3(x + 0.56, 3.56, 0.15), graph):
			return false
	return true

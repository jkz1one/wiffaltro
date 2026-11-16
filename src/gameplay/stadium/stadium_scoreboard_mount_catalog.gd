class_name StadiumScoreboardMountCatalog
extends RefCounted
## Frozen mount catalog1. Placement configuration only; never a SKU, grant or runtime factory.

const VERSION: int = 1
const CENTER_SITE: String = "BOARD-CENTER-v1"
const CENTER_PROFILE: String = "CENTER-ELECTRONIC-RAISED-v1"
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const CLEARANCE: float = 0.5
const EYES: Array[Vector3] = [Vector3(0, 1.5, -1),
	Vector3(-0.18, 2.1, -3.38), Vector3(0.18, 2.1, -3.38)]


static func signature(version: Variant = VERSION) -> String:
	return JSON.stringify(_data(), "", true, true).sha256_text() if _version(version) else ""


static func profile(id: String, version: Variant = VERSION) -> Dictionary:
	return _data().profiles.get(id, {}).duplicate(true) if _version(version) else {}


static func sites(version: Variant = VERSION) -> Array[String]:
	var result: Array[String] = []
	if _version(version):
		result.assign(_data().sockets.keys())
		result.append(CENTER_SITE)
		result.sort()
	return result


static func record(item: String, model: String, site: String, mount_profile: String,
	version: Variant = VERSION) -> Dictionary:
	if not _version(version):
		return {}
	var data: Dictionary = _data()
	if not data.models.has(item) or data.models[item].model != model:
		return {}
	var result: Dictionary = data.models[item].duplicate(true)
	if mount_profile.is_empty():
		if not data.sockets.has(site) or not data.sockets[site].items.has(item):
			return {}
		result.merge(data.sockets[site], true)
		result.merge({"display_path": "Visual/ScoreDisplay", "model_root_path": ".",
			"lift": 0.0}, true)
	else:
		var mount: Dictionary = profile(mount_profile, version)
		if mount.is_empty() or mount.item != item or mount.model != model or mount.site != site:
			return {}
		result.merge(mount, true)
	result.merge({"item": item, "model": model, "site": site,
		"mount_profile": mount_profile, "catalog": VERSION, "role": ROLE,
		"collision": false, "day_only": true}, true)
	return result.duplicate(true)


static func pose(item: String, model: String, site: String, mount_profile: String,
	version: Variant = VERSION) -> Transform3D:
	var row: Dictionary = record(item, model, site, mount_profile, version)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(row.yaw)), _vector(row.position)) \
		if not row.is_empty() else Transform3D.IDENTITY


static func bounds(placement: Dictionary, version: Variant = VERSION) -> AABB:
	var row: Dictionary = _placement(placement, version)
	return pose(row.item, row.model, row.site, row.mount_profile, version) * _box(row.envelope) \
		if not row.is_empty() else AABB()


static func readouts(item: String, model: String, site: String, mount_profile: String,
	version: Variant = VERSION) -> Dictionary:
	var row: Dictionary = record(item, model, site, mount_profile, version)
	var result: Dictionary = {}
	if row.is_empty():
		return result
	for key: String in row.regions:
		var region: Dictionary = row.regions[key].duplicate(true)
		region.point = _vector(region.point) + Vector3(0, row.lift, 0)
		result[key] = region
	return result


static func inspect(item: String, model: String, site: String, mount_profile: String,
	version: Variant, tier: String, graph: StadiumRecipeBoundary) -> Dictionary:
	var row: Dictionary = record(item, model, site, mount_profile, version)
	if row.is_empty() or graph == null or StadiumScoreboardTierSites.VERSION != 2:
		return StadiumStarterLayout._error("Unknown exact mount catalog, profile, model or site.")
	var transform: Transform3D = pose(item, model, site, mount_profile, version)
	var box: AABB = transform * _box(row.envelope)
	if not StadiumProperty.contains(tier, box) \
		or not StadiumScoreboardTierSites._outside(box, graph):
		return StadiumStarterLayout._error("The full mount needs outside-play property clearance.")
	var setback: float = INF
	if not mount_profile.is_empty():
		var outer_z: float = -INF
		for index in range(graph.polygon().size()):
			outer_z = maxf(outer_z, graph.outer_vertex(index).y)
		setback = box.position.z - outer_z
		if not is_finite(setback) or setback < CLEARANCE:
			return StadiumStarterLayout._error("The joined wall needs a 0.5 m support setback.")
	var regions: Dictionary = readouts(item, model, site, mount_profile, version)
	# Legacy sockets keep their exact plate-region rule. The new center also checks both hands.
	var eyes: Array[Vector3] = [EYES[0]]
	if not mount_profile.is_empty():
		eyes.assign(EYES)
	for eye: Vector3 in eyes:
		for key: String in regions:
			var region: Dictionary = regions[key]
			var bottom: Vector3 = region.point - Vector3(0, region.height / 2, 0)
			if not StadiumScoreboardTierSites._region_clear(eye,
				transform * (bottom - Vector3(region.width / 2, 0, 0)),
				transform * (bottom + Vector3(region.width / 2, 0, 0)), graph):
				return StadiumStarterLayout._error("This wall obscures the " + key + " readout.")
	return {"ok": true, "error": "", "pose": transform, "bounds": box, "role": ROLE,
		"outer_wall_setback": setback, "profile": row.duplicate(true), "night_qualified": false}


static func _placement(placement: Dictionary, version: Variant) -> Dictionary:
	var saved: Array[String] = ["copy", "item", "model", "site", "mount_profile"]
	var resolved: Array[String] = saved.duplicate()
	resolved.append_array(["position", "yaw", "role"])
	if not SeasonOwnership._keys(placement, saved) and not SeasonOwnership._keys(placement, resolved):
		return {}
	if not placement.get("copy") is String or placement.copy.is_empty():
		return {}
	for key: String in ["item", "model", "site", "mount_profile"]:
		if not placement.get(key) is String:
			return {}
	var row: Dictionary = record(placement.item, placement.model, placement.site,
		placement.mount_profile, version)
	if row.is_empty():
		return {}
	if placement.has("position"):
		if not placement.role is String or placement.role != ROLE \
			or not placement.position is Vector3 or not placement.position.is_finite() \
			or not SeasonOwnership._whole(placement.yaw, int(row.yaw), int(row.yaw)):
			return {}
		if placement.position != _vector(row.position):
			return {}
	return row


static func _version(value: Variant) -> bool:
	return SeasonOwnership._whole(value, VERSION, VERSION)


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func _box(value: Array) -> AABB:
	return AABB(_vector(value[0]), _vector(value[1]))


static func _data() -> Dictionary:
	# Literal snapshots, not aliases into MODELS/SITES/DATA or a future latest registry.
	return {"version": 1, "models": _models_v2(), "sockets": {
		"BOARD-LEFT-v2": {"position": [-20, 0, 29], "yaw": 180, "items": ["ST-039", "ST-090"]},
		"BOARD-RIGHT-v2": {"position": [20, 0, 29], "yaw": 180, "items": ["ST-039", "ST-090"]},
		"BOARD-LARGE-v2": {"position": [36.5, 0, 31.5], "yaw": 180, "items": ["ST-040"]}},
		"profiles": {CENTER_PROFILE: _center()},
		"policy": {"cost": 0, "grant": false, "blueprint": false,
			"role": ROLE, "collision": "none-after-terminal-only", "day_only": true,
			"legacy_allow_upright": {"ST-039": false, "ST-090": true, "ST-040": true},
			"raised_allow_upright": false, "clearance": 0.5, "wall_height_margin": 0.35,
			"contact_margin": 0.00001, "eyes": [[0, 1.5, -1], [-0.18, 2.1, -3.38], [0.18, 2.1, -3.38]],
			"visibility": "upright-region-segment-sight-triangle-v1",
			"models_version": 1, "art_version": 2, "sites_version": 1, "visibility_version": 2}}


static func _center() -> Dictionary:
	return {"item": "ST-090", "model": "electronic-v2", "site": CENTER_SITE,
		"position": [0, 0, 30.75], "yaw": 180, "lift": 2.4,
		"envelope": [[-4.4, 0, -1.1], [8.8, 10.8, 2.2]],
		"support_envelope": [[-3.4, 0, -1.1], [6.8, 7.8, 2.2]],
		"cabinet_envelope": [[-4.4, 7.6, -0.4], [8.8, 3.2, 0.8]],
		"node_name": "MountedScoreboard", "model_root_path": "Visual/ElectronicV2Cabinet",
		"display_path": "Visual/ElectronicV2Cabinet/Visual/ScoreDisplay",
		"display_class": "StadiumScoreboardTierDisplay",
		"remove_model_nodes": ["Visual/Support-1", "Visual/Support1", "Visual/Foot-1", "Visual/Foot1"],
		"support": _support(), "cost": 0, "grant": false, "blueprint": false,
		"collision": false, "day_only": true, "allow_upright": false}


static func _support() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for side in [-1, 1]:
		var x: float = side * 2.8
		rows.append({"name": "Foundation%d" % side, "kind": "box", "center": [x, 0.125, 0],
			"size": [1.2, 0.25, 2.2], "color": "777a71"})
		rows.append({"name": "Mast%d" % side, "kind": "box", "center": [x, 4.0, -0.2],
			"size": [0.42, 7.5, 0.5], "color": "526066"})
		rows.append({"name": "BasePlate%d" % side, "kind": "box", "center": [x, 0.28, -0.2],
			"size": [0.70, 0.06, 0.75], "color": "526066"})
		rows.append({"name": "RearRake%d" % side, "kind": "beam", "from": [x, 0.3, -0.9],
			"to": [x, 7.45, -0.2], "width": 0.14, "color": "526066"})
		rows.append({"name": "CrossBrace%d" % side, "kind": "beam", "from": [x, 0.45, -0.47],
			"to": [-x, 7.45, -0.47], "width": 0.14, "color": "526066"})
	rows.append({"name": "CabinetBearing", "kind": "box", "center": [0, 7.55, -0.2],
		"size": [6.25, 0.25, 0.65], "color": "526066"})
	rows.append({"name": "WaistTie", "kind": "box", "center": [0, 3.8, -0.43],
		"size": [5.6, 0.16, 0.2], "color": "526066"})
	return rows


static func _models_v2() -> Dictionary:
	return {"ST-039": {"model": "manual-v2", "allow_upright": false,
		"envelope": [[-3.1, 0, -1], [6.2, 5.8, 2]],
		"regions": {"inning": _slot(-1.85, 4.45, 1.665, 0.64, 64, 0.009),
			"home": _slot(0, 4.45, 1.665, 0.64, 64, 0.009),
			"away": _slot(1.85, 4.45, 1.665, 0.64, 64, 0.009)}},
		"ST-090": {"model": "electronic-v2", "allow_upright": true,
			"envelope": [[-4.4, 0, -1], [8.8, 8.4, 2]],
			"regions": {"away": _slot(-0.75, 6.95, 2.05, 0.80, 54, 0.013),
				"home": _slot(-0.75, 5.95, 2.05, 0.80, 54, 0.013),
				"inning": _slot(2.65, 7.0, 2.15, 0.80, 54, 0.013),
				"away_name": _slot(-2.8, 6.95, 2.15, 0.5, 25, 0.013),
				"home_name": _slot(-2.8, 5.95, 2.15, 0.5, 25, 0.013),
				"half": _slot(2.65, 7.58, 2.1, 0.32, 20, 0.013),
				"balls": _slot(1.55, 5.75, 0.8, 0.58, 36, 0.013),
				"strikes": _slot(2.6, 5.75, 0.8, 0.58, 36, 0.013),
				"outs": _slot(3.65, 5.75, 0.8, 0.58, 36, 0.013)}},
		"ST-040": {"model": "video-v2", "allow_upright": true,
			"envelope": [[-7.5, 0, -1], [15.0, 14.0, 2]],
			"regions": {"away": _slot(-4.9, 7.4, 2.8, 0.85, 40, 0.018),
				"home": _slot(4.9, 7.4, 2.8, 0.85, 40, 0.018),
				"inning": _slot(0, 7.4, 2.8, 0.85, 40, 0.018),
				"away_name": _slot(-4.9, 8.0, 4.2, 0.42, 26, 0.014),
				"home_name": _slot(4.9, 8.0, 4.2, 0.42, 26, 0.014),
				"half": _slot(0, 8.0, 2.8, 0.42, 26, 0.014),
				"batter_heading": _slot(-0.7, 12.04, 7.2, 0.40, 19, 0.018),
				"pitcher_heading": _slot(-0.7, 10.55, 7.2, 0.36, 17, 0.018),
				"batter": _slot(-0.7, 11.4, 7.2, 0.65, 34, 0.018),
				"pitcher": _slot(-0.7, 9.85, 7.2, 0.55, 28, 0.018),
				"event": _slot(-1.8, 8.8, 9.6, 0.40, 22, 0.016),
				"balls": _slot(5.6, 11.5, 2.25, 0.86, 42, 0.018),
				"strikes": _slot(5.6, 10.15, 2.25, 0.86, 42, 0.018),
				"outs": _slot(5.6, 8.8, 2.25, 0.86, 42, 0.018)}}}


static func _slot(x: float, y: float, width: float, height: float,
	font_size: int, pixels: float) -> Dictionary:
	return {"point": [x, y, 0.32], "width": width, "height": height,
		"font_size": font_size, "pixels": pixels}

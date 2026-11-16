class_name StadiumStarterLayout
extends RefCounted
## Working reference-family starter grammar only.
## Static checks are not gameplay/camera certification.
# gdlint: disable=max-returns

const VERSION: int = 1
const SITES: Dictionary = {
	"O-L1": Vector3(-8, 0, 14), "O-L2": Vector3(-11, 0, 19),
	"O-R1": Vector3(8, 0, 14), "O-R2": Vector3(11, 0, 19)
}
const RECEIVER: Vector3 = Vector3(0, 0, -1.05)


static func signature() -> String:
	var sites: Dictionary = {}
	for id: String in SITES:
		var point: Vector3 = SITES[id]
		sites[id] = [point.x, point.y, point.z]
	return JSON.stringify({"version": VERSION, "sites": sites,
		"receiver": [RECEIVER.x, RECEIVER.y, RECEIVER.z],
		"items": StadiumCatalog.STARTERS}, "", true, true).sha256_text()


static func empty() -> Dictionary:
	return {"version": VERSION, "family": "reference-starter-v1", "receiver": "", "obstacles": []}


static func validate(layout: Variant, ownership: StadiumStock) -> Dictionary:
	if ownership == null or StadiumStock.from_data(ownership.to_data()) == null:
		return _error("Construction ownership could not be validated.")
	if not layout is Dictionary or not SeasonOwnership._keys(
		layout, ["version", "family", "receiver", "obstacles"]):
		return _error("Unknown starter-layout fields; preserve the saved layout.")
	if not SeasonOwnership._whole(layout.version, VERSION, VERSION) \
		or not layout.family is String or layout.family != "reference-starter-v1" \
		or not layout.receiver is String or not layout.obstacles is Array:
		return _error("Unknown layout version or field family.")
	var used: Array[String] = []
	var placements: Array = []
	if not layout.receiver.is_empty():
		if not ownership.copies.has(layout.receiver) \
			or ownership.copies[layout.receiver].item != "ST-079":
			return _error("RECEIVER-PRIMARY needs one owned ST-079 backstop chair.")
		used.append(layout.receiver)
		placements.append({"copy": layout.receiver, "item": "ST-079", "site": "RECEIVER-PRIMARY",
			"position": RECEIVER, "yaw": 0, "role": "RECEIVER_CONTAINMENT_FOUL"})
	var previous: String = ""
	var items: Array = []
	for row: Variant in layout.obstacles:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["copy", "site", "yaw"]):
			return _error("Every obstacle needs an exact copy, site and authored yaw.")
		if not row.copy is String or not ownership.copies.has(row.copy) or used.has(row.copy):
			return _error("An obstacle copy is missing or already placed: " + str(row.get("copy")))
		if not row.site is String or not SITES.has(row.site) or row.site <= previous:
			return _error("Obstacle sites must be unique and canonically ordered: " + str(row.get("site")))
		if not SeasonOwnership._whole(row.yaw, 0, 270) or int(row.yaw) % 90 != 0:
			return _error("Only authored quarter-turn orientations are supported at " + row.site)
		var item: String = ownership.copies[row.copy].item
		if item not in ["ST-001", "ST-003"] or (item == "ST-001" and row.yaw != 0):
			return _error(row.site + " supports a fixed cone or a quarter-turn woven lawn chair only.")
		used.append(row.copy)
		items.append(item)
		previous = row.site
		placements.append({"copy": row.copy, "item": item, "site": row.site,
			"position": SITES[row.site], "yaw": int(row.yaw), "role": "LIVE_RICOCHET"})
	if not StadiumCatalog.within_live_budget(items):
		return _error("The layout exceeds four live objects or four capacity units.")
	var stored: Array[String] = []
	for key: String in ownership.copies:
		if not used.has(key):
			stored.append(key)
	stored.sort()
	return {"ok": true, "error": "", "placements": placements, "stored": stored,
		"live_units": items.size(), "runtime_verified": false, "night_qualified": false}


static func preview(before: Dictionary, after: Dictionary, ownership: StadiumStock) -> Dictionary:
	var current: Dictionary = validate(before, ownership)
	var candidate: Dictionary = validate(after, ownership)
	if not current.ok:
		return current
	if not candidate.ok:
		return candidate
	var displaced: Array[String] = []
	for placement: Dictionary in current.placements:
		if candidate.stored.has(placement.copy):
			displaced.append(placement.copy)
	displaced.sort()
	candidate["displaced"] = displaced
	candidate["cost"] = 0
	return candidate


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

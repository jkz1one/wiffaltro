class_name StadiumSeatingLayout
extends RefCounted
## BT/BI outside-play candidates; production journal and land adapters remain gated.
# gdlint: disable=max-returns

const VERSION: int = 1
const SITES: Dictionary = {
	"SC-L1": {"position": Vector3(-24, 0, 10), "side": "L", "item": "ST-080", "tier": 0},
	"SC-L2": {"position": Vector3(-24, 0, 12), "side": "L", "item": "ST-080", "tier": 0},
	"SC-L3": {"position": Vector3(-24, 0, 14), "side": "L", "item": "ST-080", "tier": 1},
	"SC-R1": {"position": Vector3(24, 0, 10), "side": "R", "item": "ST-080", "tier": 0},
	"SC-R2": {"position": Vector3(24, 0, 12), "side": "R", "item": "ST-080", "tier": 0},
	"SC-R3": {"position": Vector3(24, 0, 14), "side": "R", "item": "ST-080", "tier": 1},
	"SIDE-SEAT-L": {"position": Vector3(-24, 0, 12.5), "side": "L", "item": "ST-027", "tier": 0},
	"SIDE-SEAT-R": {"position": Vector3(24, 0, 12.5), "side": "R", "item": "ST-027", "tier": 0}
}
const TIERS: Array[String] = ["backyard", "expanded", "club", "mogul"]


static func envelope(item: String) -> AABB:
	if item == "ST-080":
		return AABB(Vector3(-0.4, 0, -0.45), Vector3(0.8, 1.4, 0.9))
	if item == "ST-027":
		return AABB(Vector3(-3, 0, -1.5), Vector3(6, 2.2, 3))
	return AABB()


static func validate(rows: Variant, stock: StadiumStock, tier: String = "backyard") -> Dictionary:
	if not rows is Array or rows.size() > SITES.size() or stock == null \
		or StadiumStock.from_data(stock.to_data()) == null or not TIERS.has(tier):
		return _error("Unknown seating, ownership or property data.")
	var previous: String = ""
	var used: Array[String] = []
	var sites: Array[String] = []
	var kinds: Dictionary = {}
	var placements: Array[Dictionary] = []
	for value: Variant in rows:
		if not value is Dictionary or not SeasonOwnership._keys(value, ["copy", "site"]) \
			or not value.copy is String or not value.site is String or not SITES.has(value.site) \
			or not stock.copies.has(value.copy) or used.has(value.copy) or value.site <= previous:
			return _error("Every seating site needs one distinct owned compatible copy.")
		var site: Dictionary = SITES[value.site]
		var item: String = stock.copies[value.copy].item
		if item != site.item or TIERS.find(tier) < site.tier:
			return _error("This exact seat identity or property does not support the site.")
		var kind: String = "chair" if item == "ST-080" else "bleacher"
		if kinds.has(site.side) and kinds[site.side] != kind:
			return _error("Store the same-side chairs before installing bleachers.")
		kinds[site.side] = kind
		var yaw: int = 90 if site.side == "L" else 270
		var transform: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), site.position)
		var bounds: AABB = transform * envelope(item)
		if not StadiumProperty.contains(tier, bounds) or not _outside_play(bounds):
			return _error("The full seating/audience envelope needs safe outside-play clearance.")
		previous = value.site
		used.append(value.copy)
		sites.append(value.site)
		placements.append({"copy": value.copy, "site": value.site, "item": item,
			"position": site.position, "yaw": yaw, "role": "DECORATIVE_AFTER_TERMINAL"})
	return {"ok": true, "error": "", "placements": placements, "live_units": 0}


static func _outside_play(bounds: AABB) -> bool:
	# Every rectangle corner must stay at least 1.5m beyond the corresponding side face.
	var segment: Dictionary = StadiumBoundaryGraph.segment(
		"SIDE-L-01" if bounds.get_center().x < 0 else "SIDE-R-01")
	for index in range(8):
		var point: Vector3 = bounds.get_endpoint(index)
		if (Vector2(point.x, point.z) - segment.a).dot(StadiumBoundaryGraph.inward(segment)) > -1.5:
			return false
	return true


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func preview(before: Array, after: Array, stock: StadiumStock,
	tier: String = "backyard") -> Dictionary:
	var old: Dictionary = validate(before, stock, tier)
	var next: Dictionary = validate(after, stock, tier)
	if not old.ok:
		return old
	if not next.ok:
		return next
	var retained: Array = after.map(func(row: Dictionary) -> String: return row.copy)
	var displaced: Array[String] = []
	for row: Dictionary in before:
		if not retained.has(row.copy):
			displaced.append(row.copy)
	displaced.sort()
	next["stored"] = displaced
	next["cost"] = 0
	return next

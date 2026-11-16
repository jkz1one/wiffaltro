class_name StadiumClubSites
extends RefCounted
## BO ground candidates. No tree, host, night or income capability is inferred.

const VERSION: int = 1
const SITES: Dictionary = {
	"SCORE-SMALL": {"item": "ST-039", "position": Vector3(-20, 0, 30), "yaw": 180},
	"SIGN-GROUND-L": {"item": "ST-041", "position": Vector3(-15, 0, -8), "yaw": 40},
	"SIGN-GROUND-R": {"item": "ST-041", "position": Vector3(15, 0, -8), "yaw": 320}
}


static func envelope(item: String) -> AABB:
	if item == "ST-039":
		return AABB(Vector3(-2.5, 0, -1), Vector3(5, 4, 2))
	return AABB(Vector3(-1.25, 0, -0.4), Vector3(2.5, 1.9, 0.8)) if item == "ST-041" else AABB()


static func validate(rows: Variant, stock: StadiumStock, tier: String = "backyard") -> Dictionary:
	if not rows is Array or stock == null or StadiumStock.from_data(stock.to_data()) == null \
		or rows.size() > SITES.size() or not StadiumLand.TIERS.has(tier):
		return StadiumStarterLayout._error("Invalid club-display ownership or sites.")
	var previous: String = ""
	var used: Array[String] = []
	var placements: Array = []
	for row: Variant in rows:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["copy", "site"]) \
			or not row.copy is String or not row.site is String or not SITES.has(row.site) \
			or row.site <= previous or used.has(row.copy) or not stock.copies.has(row.copy):
			return StadiumStarterLayout._error("Each display needs one distinct compatible owned copy.")
		var site: Dictionary = SITES[row.site]
		if stock.copies[row.copy].item != site.item:
			return StadiumStarterLayout._error("This display identity does not fit the selected site.")
		var transform: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(site.yaw)), site.position)
		var box: AABB = transform * envelope(site.item)
		if not StadiumProperty.contains(tier, box) or not _outside(box):
			return StadiumStarterLayout._error("The full display needs outside-play property clearance.")
		placements.append({"copy": row.copy, "site": row.site, "item": site.item,
			"position": site.position, "yaw": site.yaw, "role": "DECORATIVE_AFTER_TERMINAL"})
		used.append(row.copy)
		previous = row.site
	return {"ok": true, "error": "", "placements": placements, "live_units": 0}


static func _outside(box: AABB) -> bool:
	for segment: Dictionary in StadiumBoundaryGraph.segments():
		var clear: bool = true
		for index in range(8):
			var point: Vector3 = box.get_endpoint(index)
			if (Vector2(point.x, point.z) - segment.a).dot(
				StadiumBoundaryGraph.inward(segment)) > -0.5:
				clear = false
		if clear:
			return true
	return false

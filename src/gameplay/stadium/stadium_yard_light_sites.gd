class_name StadiumYardLightSites
extends RefCounted
## Four fixed ground-light sockets; a placed copy is neither a live obstacle nor a free night grant.

const VERSION: int = 1


static func yaw(site: String) -> float:
	var position: Vector3 = StadiumYardLightModels.SITES[site]
	var target: Vector3 = Vector3(0, 0.7, 8 if site in ["YLIGHT-FL", "YLIGHT-FR"] else 18)
	var direction: Vector3 = target - position
	return rad_to_deg(atan2(direction.x, direction.z))


static func validate(rows: Variant, stock: StadiumStock, tier: String) -> Dictionary:
	if not rows is Array or rows.size() > 4 or stock == null:
		return StadiumStarterLayout._error("Invalid yard-light placements.")
	var copies: Array[String] = []
	var sites: Array[String] = []
	var placements: Array[Dictionary] = []
	var previous: String = ""
	for row: Variant in rows:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["copy", "site"]) \
			or not row.copy is String or not row.site is String \
			or not StadiumYardLightModels.SITES.has(row.site) or row.site <= previous \
			or copies.has(row.copy) or not stock.copies.has(row.copy) \
			or stock.copies[row.copy].item != "ST-037":
			return StadiumStarterLayout._error("Each named yard-light site needs one distinct owned pole.")
		var point: Vector3 = StadiumYardLightModels.SITES[row.site]
		var pose: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw(row.site))), point)
		if not StadiumProperty.contains(tier, pose * StadiumYardLightModels.ENVELOPE):
			return StadiumStarterLayout._error("Yard-light envelope does not fit this property.")
		copies.append(row.copy)
		sites.append(row.site)
		previous = row.site
		placements.append({"copy": row.copy, "site": row.site, "item": "ST-037",
			"position": point, "yaw": yaw(row.site), "role": "DECORATIVE_AFTER_TERMINAL"})
	return {"ok": true, "error": "", "placements": placements,
		"complete": sites.size() == StadiumYardLightModels.SITES.size()}

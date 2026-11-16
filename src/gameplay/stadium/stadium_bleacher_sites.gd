class_name StadiumBleacherSites
extends RefCounted
## Explicit BT side-site candidates; earlier seating grammar stays frozen.
# gdlint: disable=max-returns

const VERSION: int = 1
const TIERS: Dictionary = {"ST-028": 1, "ST-075": 2}


static func validate(rows: Variant, stock: StadiumStock, tier: String) -> Dictionary:
	if not rows is Array or rows.size() > 2 or stock == null \
		or StadiumStock.from_data(stock.to_data()) == null or not StadiumSeatingLayout.TIERS.has(tier):
		return StadiumSeatingLayout._error("Unknown advanced bleacher ownership or property.")
	var previous: String = ""
	var used: Array[String] = []
	var placements: Array[Dictionary] = []
	for row: Variant in rows:
		if not row is Dictionary or not SeasonOwnership._keys(row, ["copy", "site"]) \
			or not row.copy is String or not row.site is String \
			or row.site not in ["SIDE-SEAT-L", "SIDE-SEAT-R"] or row.site <= previous \
			or not stock.copies.has(row.copy) or used.has(row.copy):
			return StadiumSeatingLayout._error("Each side needs a distinct exact owned bleacher.")
		var item: String = stock.copies[row.copy].item
		if not TIERS.has(item) or StadiumSeatingLayout.TIERS.find(tier) < TIERS[item]:
			return StadiumSeatingLayout._error("This bleacher needs its authored land tier.")
		var site: Dictionary = StadiumSeatingLayout.SITES[row.site]
		var yaw: int = 90 if site.side == "L" else 270
		var pose: Transform3D = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), site.position)
		var bounds: AABB = pose * StadiumBleacherModels.envelope(item)
		if not StadiumProperty.contains(tier, bounds) or not StadiumSeatingLayout._outside_play(bounds):
			return StadiumSeatingLayout._error("The whole roof/audience envelope needs exterior clearance.")
		placements.append({"copy": row.copy, "site": row.site, "item": item,
			"position": site.position, "yaw": yaw, "role": "DECORATIVE_AFTER_TERMINAL"})
		previous = row.site
		used.append(row.copy)
	return {"ok": true, "error": "", "placements": placements, "live_units": 0}

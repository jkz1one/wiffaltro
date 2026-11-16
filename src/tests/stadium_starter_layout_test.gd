extends Node
## Exhaustive 1296 static assignments only. Routes, collisions and camera remain separate gates.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var before: Dictionary = stock.to_data()
	var layout: Dictionary = StadiumStarterLayout.empty()
	var result: Dictionary = StadiumStarterLayout.validate(layout, stock)
	_check(result.ok and result.stored.size() == 3 and result.placements.is_empty(),
		"default field grants no phantom receiver and stores the three owned objects")
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-003", "site": "O-L1", "yaw": 90}]
	result = StadiumStarterLayout.validate(layout, stock)
	_check(result.ok and result.live_units == 1 and not result.runtime_verified,
		"backstop chair not counted as live obstacle, static validity not runtime proof")
	var cleared: Dictionary = StadiumStarterLayout.preview(layout, StadiumStarterLayout.empty(), stock)
	_check(cleared.ok and cleared.cost == 0 and cleared.displaced.size() == 2
		and cleared.stored.size() == 3 and stock.to_data() == before,
		"removal previews the same stored copies for free; ownership is never deleted")
	for mutation: String in ["chair", "duplicate", "yaw", "site", "scale", "version"]:
		var bad: Dictionary = layout.duplicate(true)
		match mutation:
			"chair": bad.receiver = "starter-v1:ST-003"
			"duplicate": bad.obstacles.append(bad.obstacles[0].duplicate(true))
			"yaw": bad.obstacles[0].yaw = 45
			"site": bad.obstacles[0].site = "anywhere"
			"scale": bad.obstacles[0].scale = [2, 2, 2]
			"version": bad.version = true
		_check(not StadiumStarterLayout.preview(layout, bad, stock).ok
			and stock.to_data() == before, "invalid " + mutation + " leaves prior ownership intact")
	var quote: Dictionary = stock.quote("ST-001", 3, {}, "extra-cones")
	stock = StadiumStock.from_data(quote.state)
	quote = stock.quote("ST-003", 3, {}, "extra-chairs")
	stock = StadiumStock.from_data(quote.state)
	# Synthetic quote candidates are not paid user purchases.
	var cones: Array = stock.copies.keys().filter(func(id: String) -> bool:
		return stock.copies[id].item == "ST-001")
	var chairs: Array = stock.copies.keys().filter(func(id: String) -> bool:
		return stock.copies[id].item == "ST-003")
	var sites: Array = StadiumStarterLayout.SITES.keys()
	for assignment in range(1296):
		var encoded: int = assignment
		var cone: int = 0
		var chair: int = 0
		var candidate: Dictionary = StadiumStarterLayout.empty()
		for site: String in sites:
			var digit: int = encoded % 6
			encoded = int(encoded / 6)
			if digit == 0:
				continue
			var id: String = cones[cone] if digit == 1 else chairs[chair]
			cone += 1 if digit == 1 else 0
			chair += 1 if digit > 1 else 0
			candidate.obstacles.append({"copy": id, "site": site,
				"yaw": 0 if digit == 1 else (digit - 2) * 90})
		_check(StadiumStarterLayout.validate(candidate, stock).ok, "authored static assignment")
	var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID)
	var tangent: float = tan(deg_to_rad(field.fair_half_angle_degrees))
	for point: Vector3 in StadiumStarterLayout.SITES.values():
		var edge_distance: float = (point.z * tangent + 0.45 - absf(point.x)) \
			/ sqrt(1 + tangent * tangent)
		_check(edge_distance > 1, "radius-one site stays within reference tolerated fair wedge")
		for anchor in range(9):
			if field.is_fielder_anchor_available(anchor):
				_check(point.distance_to(field.fielder_anchor(anchor)) > 2,
					"candidate radius-one reservations do not overlap enabled anchor reservations")
	if _failures == 0:
		print("Wiffaltro starter layout checks passed:1296 static assignments and preserved storage.")
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

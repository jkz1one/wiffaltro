class_name StadiumScoreboardTiers
extends RefCounted
## Three separately authored art candidates. Old ST-039 models and saved sites stay frozen.

const VERSION: int = 2
const TIERS: Array[String] = ["manual", "electronic", "video"]
const DATA: Dictionary = {
	"manual": {"width": 6.2, "height": 5.8, "bottom": 3.55, "column": 1.85,
		"heading": 5.03, "number": 4.45, "pixels": 0.009},
	"electronic": {"width": 8.8, "height": 8.4, "bottom": 5.2, "column": 2.6,
		"heading": 7.5, "number": 6.6, "pixels": 0.013},
	"video": {"width": 15.0, "height": 14.0, "bottom": 6.9, "column": 3.8,
		"heading": 8.0, "number": 7.4, "pixels": 0.018}}


static func spec(tier: String) -> Dictionary:
	return DATA.get(tier, {}).duplicate(true)


static func envelope(tier: String) -> AABB:
	var row: Dictionary = spec(tier)
	return AABB(Vector3(-row.width / 2, 0, -1), Vector3(row.width, row.height, 2)) \
		if not row.is_empty() else AABB()


static func readouts(tier: String) -> Dictionary:
	if tier == "manual":
		return {"inning": _slot(-1.85, 4.45, 1.665, 0.64, 64, 0.009),
			"home": _slot(0, 4.45, 1.665, 0.64, 64, 0.009),
			"away": _slot(1.85, 4.45, 1.665, 0.64, 64, 0.009)}
	if tier == "electronic":
		return {"away": _slot(-0.75, 6.95, 2.05, 0.80, 54, 0.013),
			"home": _slot(-0.75, 5.95, 2.05, 0.80, 54, 0.013),
			"inning": _slot(2.65, 7.0, 2.15, 0.80, 54, 0.013)}
	if tier == "video":
		return {"away": _slot(-4.9, 7.4, 2.8, 0.85, 40, 0.018),
			"home": _slot(4.9, 7.4, 2.8, 0.85, 40, 0.018),
			"inning": _slot(0, 7.4, 2.8, 0.85, 40, 0.018)}
	return {}


static func detail_slots(tier: String) -> Dictionary:
	if tier == "electronic":
		return {"away_name": _slot(-2.8, 6.95, 2.15, 0.5, 25, 0.013),
			"home_name": _slot(-2.8, 5.95, 2.15, 0.5, 25, 0.013),
			"half": _slot(2.65, 7.58, 2.1, 0.32, 20, 0.013),
			"balls": _slot(1.55, 5.75, 0.8, 0.58, 36, 0.013),
			"strikes": _slot(2.6, 5.75, 0.8, 0.58, 36, 0.013),
			"outs": _slot(3.65, 5.75, 0.8, 0.58, 36, 0.013)}
	if tier == "video":
		return {"away_name": _slot(-4.9, 8.0, 4.2, 0.42, 26, 0.014),
			"home_name": _slot(4.9, 8.0, 4.2, 0.42, 26, 0.014),
			"half": _slot(0, 8.0, 2.8, 0.42, 26, 0.014),
			"batter_heading": _slot(-0.7, 12.04, 7.2, 0.40, 19, 0.018),
			"pitcher_heading": _slot(-0.7, 10.55, 7.2, 0.36, 17, 0.018),
			"batter": _slot(-0.7, 11.4, 7.2, 0.65, 34, 0.018),
			"pitcher": _slot(-0.7, 9.85, 7.2, 0.55, 28, 0.018),
			"event": _slot(-1.8, 8.8, 9.6, 0.40, 22, 0.016),
			"balls": _slot(5.6, 11.5, 2.25, 0.86, 42, 0.018),
			"strikes": _slot(5.6, 10.15, 2.25, 0.86, 42, 0.018),
			"outs": _slot(5.6, 8.8, 2.25, 0.86, 42, 0.018)}
	return {}


static func _slot(x: float, y: float, width: float, height: float,
	font_size: int, pixels: float) -> Dictionary:
	return {"point": Vector3(x, y, 0.32), "width": width, "height": height,
		"font_size": font_size, "pixels": pixels}


static func create(tier: String) -> Node3D:
	if not TIERS.has(tier):
		return null
	var root: Node3D = Node3D.new()
	root.name = "Scoreboard" + tier.capitalize()
	root.set_meta("scoreboard_candidate", tier)
	root.set_meta("scoreboard_model_version", VERSION)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	match tier:
		"manual": _manual(root)
		"electronic": _electronic(root)
		"video": _video(root)
	for key: String in readouts(tier):
		var slot: Dictionary = readouts(tier)[key]
		_box(root, "NumberWell_" + key, slot.point - Vector3(0, 0, 0.08),
			Vector3(slot.width, slot.height, 0.025), Color("071312"))
	for key: String in detail_slots(tier):
		if key in ["balls", "strikes", "outs"]:
			var slot: Dictionary = detail_slots(tier)[key]
			_box(root, "CountWell_" + key, slot.point - Vector3(0, 0, 0.045),
				Vector3(slot.width, slot.height, 0.02), Color("071312"))
	var display: StadiumScoreboardTierDisplay = StadiumScoreboardTierDisplay.new()
	display.name = "ScoreDisplay"
	display.tier = tier
	visual.add_child(display)
	display.build()
	return root


static func _manual(root: Node3D) -> void:
	_posts(root, 3.55, 2.05, 0.22, Color("8b6845"))
	_box(root, "TimberFrame", Vector3(0, 4.65, -0.12), Vector3(6.2, 2.25, 0.40), Color("987653"))
	_box(root, "PaintedFace", Vector3(0, 4.65, 0.12), Vector3(5.94, 1.98, 0.10), Color("193d31"))
	for y: float in [3.72, 5.2]:
		_box(root, "PaintedDivider" + str(y), Vector3(0, y, 0.19),
			Vector3(5.65, 0.028, 0.02), Color("d3cbb0"))
	for index in range(3):
		var x: float = (index - 1) * 1.85
		_box(root, "CardSeam%d" % index, Vector3(x, 4.45, 0.27),
			Vector3(0.012, 0.64, 0.02), Color("334138"))
		for side in [-1, 1]:
			_box(root, "CardClip%d_%d" % [index, side], Vector3(x + side * 0.65, 4.77, 0.29),
				Vector3(0.09, 0.10, 0.025), Color("c3b799"))
	_text(root, "HOME CLUB", Vector3(0, 5.48, 0.31), 28, 0.009, Color("e0d9bf"))
	_text(root, "MANUAL SCORE", Vector3(0, 3.93, 0.31), 16, 0.009, Color("b5b79d"))


static func _electronic(root: Node3D) -> void:
	_posts(root, 5.2, 2.8, 0.36, Color("526066"))
	_box(root, "EnamelCabinet", Vector3(0, 6.55, -0.1), Vector3(8.8, 2.7, 0.52), Color("783d3b"))
	_box(root, "DisplayFace", Vector3(0, 6.55, 0.19), Vector3(8.44, 2.38, 0.10), Color("17212a"))
	_box(root, "RaisedNamePlate", Vector3(0, 8.08, -0.1), Vector3(5.8, 0.55, 0.4), Color("783d3b"))
	_box(root, "LeftShoulder", Vector3(-3.5, 7.94, -0.1), Vector3(1.4, 0.26, 0.38), Color("59686b"))
	_box(root, "RightShoulder", Vector3(3.5, 7.94, -0.1), Vector3(1.4, 0.26, 0.38), Color("59686b"))
	_box(root, "ModuleDivider", Vector3(0.62, 6.55, 0.28), Vector3(0.04, 2.22, 0.025), Color("8c9895"))
	_box(root, "TeamDivider", Vector3(-1.77, 6.45, 0.28), Vector3(4.6, 0.025, 0.02), Color("536767"))
	_text(root, "CLUB FIELD", Vector3(0, 8.08, 0.32), 32, 0.013, Color("efe2be"))
	for row: Array in [["BALL", 1.55], ["STRIKE", 2.6], ["OUT", 3.65]]:
		_text(root, row[0], Vector3(row[1], 6.22, 0.32), 14, 0.013, Color("d4d8c7"))
	for side in [-1, 1]:
		for y: float in [5.38, 7.72]:
			_box(root, "Fastener%s_%s" % [side, y], Vector3(side * 4.2, y, 0.29),
				Vector3(0.065, 0.065, 0.02), Color("b4b6ad"))


static func _video(root: Node3D) -> void:
	var steel: Color = Color("344f5b")
	_posts(root, 7.0, 5.4, 0.6, steel)
	for side in [-1, 1]:
		_beam(root, "LowerBrace%d" % side, Vector3(side * 5.4, 0.5, -0.4),
			Vector3(0, 6.7, -0.4), 0.20, steel)
		_box(root, "EndPylon%d" % side, Vector3(side * 7.25, 10.65, -0.15),
			Vector3(0.4, 6.3, 0.6), steel)
	_box(root, "MainHousing", Vector3(-1.8, 10.45, -0.14), Vector3(10.6, 4.3, 0.5), steel)
	_box(root, "MainScreen", Vector3(-1.8, 10.45, 0.17), Vector3(10.25, 3.98, 0.1), Color("163349"))
	_box(root, "SideHousing", Vector3(5.6, 10.25, -0.14), Vector3(2.9, 4.2, 0.5), steel)
	_box(root, "SideScreen", Vector3(5.6, 10.25, 0.17), Vector3(2.58, 3.92, 0.1), Color("0c202a"))
	_box(root, "ScoreRibbon", Vector3(0, 7.64, -0.05), Vector3(14.6, 1.48, 0.48), Color("132832"))
	_box(root, "ServiceLedge", Vector3(0, 8.42, -0.18), Vector3(14.5, 0.14, 1.6), steel)
	for y: float in [12.85, 13.75]:
		_box(root, "CrownRail" + str(y), Vector3(0, y, -0.15), Vector3(14.5, 0.16, 0.3), steel)
	for index in range(8):
		var x: float = -6.8 + index * 1.7
		_beam(root, "CrownBrace%d" % index, Vector3(x, 12.85, -0.15),
			Vector3(x + 1.35, 13.75, -0.15), 0.1, steel)
	_text(root, "HOME FIELD", Vector3(0, 13.32, 0.31), 34, 0.020, Color("e5e4ce"))
	_box(root, "CoralAccent", Vector3(-1.8, 12.35, 0.28), Vector3(9.75, 0.09, 0.03), Color("be7465"))
	for row: Array in [["BALL", 12.02], ["STRIKE", 10.67], ["OUT", 9.32]]:
		_text(root, row[0], Vector3(5.6, row[1], 0.32), 16, 0.018, Color("b6cfc8"))
	_box(root, "PortraitShirt", Vector3(-5.5, 9.8, 0.35), Vector3(1.2, 1.55, 0.12), Color("aab35c"))
	var head: MeshInstance3D = MeshInstance3D.new()
	head.name = "PortraitIcon"
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.45
	head.mesh.height = 0.9
	head.position = Vector3(-5.5, 11.05, 0.38)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("cccbb2")
	head.material_override = material
	root.get_node("Visual").add_child(head)


static func _posts(root: Node3D, height: float, spread: float, width: float, color: Color) -> void:
	for side in [-1, 1]:
		_box(root, "Support%d" % side, Vector3(side * spread, height / 2, -0.2),
			Vector3(width, height, 0.38), color)
		_box(root, "Foot%d" % side, Vector3(side * spread, 0.10, 0),
			Vector3(width + 0.4, 0.2, 1.9), Color("555951"))


static func _beam(root: Node3D, id: String, a: Vector3, b: Vector3,
	width: float, color: Color) -> void:
	_box(root, id, (a + b) / 2, Vector3(width, a.distance_to(b), width), color)
	root.get_node("Visual/" + id).quaternion = Quaternion(Vector3.UP, (b - a).normalized())


static func _text(root: Node3D, value: String, point: Vector3, size: int,
	pixels: float, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = value
	label.position = point
	label.font_size = size
	label.pixel_size = pixels
	label.modulate = color
	label.outline_size = 0
	root.get_node("Visual").add_child(label)


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3, color: Color) -> void:
	StadiumSeatingModels._box(root, id, point, size, color, false)

class_name StadiumBleacherModels
extends RefCounted
## Two separately owned complete assemblies; neither consumes an earlier bleacher copy.

const VERSION: int = 1
const IDS: Array[String] = ["ST-028", "ST-075"]


static func envelope(id: String) -> AABB:
	if id == "ST-028":
		return AABB(Vector3(-3.25, 0, -2), Vector3(6.5, 3.2, 4))
	if id == "ST-075":
		return AABB(Vector3(-3.25, 0, -1.75), Vector3(6.5, 4.2, 3.5))
	return AABB()


static func create(id: String, occupied: bool = true) -> Node3D:
	if not IDS.has(id):
		return null
	var root: Node3D = Node3D.new()
	root.name = id.replace("-", "")
	root.set_meta("stadium_item", id)
	root.set_meta("represented_seats", 24 if id == "ST-028" else 10)
	for name_value: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = name_value
		root.add_child(node)
	if id == "ST-028":
		_aluminum(root, occupied)
	else:
		StadiumSeatingModels._bleachers(root, occupied)
		_roof(root)
	return root


static func _aluminum(root: Node3D, occupied: bool) -> void:
	var bright: Color = Color("aebfc1")
	var dark: Color = Color("627c80")
	for row in range(4):
		var height: float = 0.45 + row * 0.5
		var depth: float = 1.35 - row * 0.9
		_box(root, "AluminumBench%d" % row, Vector3(0, height, depth),
			Vector3(5.7, 0.10, 0.40), bright)
		_box(root, "FootTread%d" % row, Vector3(0, height - 0.35, depth + 0.35),
			Vector3(6.10, 0.10, 0.46), dark)
		for support in range(3):
			_box(root, "Upright%d_%d" % [row, support],
				Vector3((support - 1) * 2.75, height / 2, depth),
				Vector3(0.08, height, 0.08), dark)
		if occupied:
			for seat in range(6):
				StadiumSeatingModels._person(root, row * 6 + seat,
					Vector3(-2.35 + seat * 0.94, height + 0.05, depth))
	for support in range(3):
		var x: float = (support - 1) * 2.9
		_box(root, "GroundRail%d" % support, Vector3(x, 0.05, 0),
			Vector3(0.12, 0.10, 3.85), dark)
		StadiumSeatingModels._segment(root, "Diagonal%d" % support,
			Vector3(x, 0.10, 1.7), Vector3(x, 1.95, -1.55), 0.075, dark)
	for side in [-1, 1]:
		_box(root, "RearPost%d" % side, Vector3(side * 3.05, 1.48, -1.83),
			Vector3(0.09, 2.96, 0.09), dark)
		_box(root, "SideRail%d" % side, Vector3(side * 3.05, 1.5, 0),
			Vector3(0.09, 0.09, 3.7), bright)
	_box(root, "RearGuard", Vector3(0, 2.95, -1.83), Vector3(6.18, 0.09, 0.09), bright)
	for step in range(8):
		var height: float = (step + 1) * 0.21
		_box(root, "AccessStep%d" % step, Vector3(2.97, height / 2, 1.68 - step * 0.43),
			Vector3(0.40, height, 0.38), dark)


static func _roof(root: Node3D) -> void:
	var timber: Color = Color("725138")
	for side in [-1, 1]:
		for end in [-1, 1]:
			_box(root, "RoofPost%d_%d" % [side, end], Vector3(side * 2.95, 1.75, end * 1.45),
				Vector3(0.14, 3.5, 0.14), timber)
		_box(root, "EaveBeam%d" % side, Vector3(0, 3.48, side * 1.45),
			Vector3(6.05, 0.16, 0.16), timber)
		var id: String = "RoofPlane%d" % side
		_box(root, id, Vector3(0, 3.72, side * 0.84),
			Vector3(6.4, 0.10, 1.76), Color("755343"))
		root.get_node("Visual/" + id).rotation.x = side * atan2(0.44, 1.68)
		root.get_node("Collision/" + id).rotation.x = side * atan2(0.44, 1.68)
	_box(root, "RoofRidge", Vector3(0, 3.95, 0), Vector3(6.4, 0.12, 0.14), timber)


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color) -> void:
	StadiumSeatingModels._box(root, id, center, size, color)

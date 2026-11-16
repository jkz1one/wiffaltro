class_name StadiumNpcExpandedClubV1
extends RefCounted
## Retained AE-01/r1 correspondence copy.
## Original: src/presentation/stadium/stadium_club_models.gd
## Original manual scoreboard and freestanding painted sign, without free mounted catalog items.

const VERSION: int = 1


static func create(item: String) -> Node3D:
	if item not in ["ST-039", "ST-041"]:
		return null
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "")
	root.set_meta("stadium_item", item)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	if item == "ST-039":
		_scoreboard(root)
	else:
		_sign(root)
	return root


static func _scoreboard(root: Node3D) -> void:
	var wood: Color = Color("876044")
	_box(root, "Board", Vector3(0, 3.60, 0), Vector3(4.50, 0.75, 0.18), Color("284c3d"))
	_box(root, "Header", Vector3(0, 3.92, 0), Vector3(4.70, 0.16, 0.24), wood)
	_box(root, "LowerFrame", Vector3(0, 3.225, 0), Vector3(4.70, 0.16, 0.24), wood)
	for side in [-1, 1]:
		_box(root, "SideFrame%d" % side, Vector3(side * 2.30, 3.60, 0),
			Vector3(0.16, 0.80, 0.24), wood)
		_box(root, "Post%d" % side, Vector3(side * 1.8, 1.95, -0.14),
			Vector3(0.16, 3.90, 0.16), wood)
		_box(root, "Foot%d" % side, Vector3(side * 1.8, 0.08, 0),
			Vector3(0.30, 0.16, 1.70), Color("604833"))
		_box(root, "NumberDivider%d" % side, Vector3(side * 0.7, 3.65, 0.11),
			Vector3(0.04, 0.42, 0.04), wood)
	for index in range(3):
		StadiumNpcExpandedSeatingV1._box(root, "NumberCard%d" % index,
			Vector3((index - 1) * 1.4, 3.73, 0.115), Vector3(1.12, 0.34, 0.03),
			Color("172b22"), false)
	var display: StadiumNpcExpandedDisplayV1 = StadiumNpcExpandedDisplayV1.new()
	display.name = "ScoreDisplay"
	root.get_node("Visual").add_child(display)
	display.build()
	_label(root, "WIFFALTRO", Vector3(0, 3.35, 0.12), 18, 0.009)


static func _sign(root: Node3D) -> void:
	var wood: Color = Color("a27c51")
	for index in range(2):
		_box(root, "PaintedPlank%d" % index, Vector3(0, 1.35 + index * 0.33, 0),
			Vector3(2.40, 0.30, 0.16), wood)
	for side in [-1, 1]:
		_box(root, "SignPost%d" % side, Vector3(side * 0.80, 0.84, -0.12),
			Vector3(0.13, 1.68, 0.14), Color("6e5136"))
		_box(root, "SignFoot%d" % side, Vector3(side * 0.80, 0.07, 0),
			Vector3(0.25, 0.14, 0.70), Color("6e5136"))
	_label(root, "HOME CLUB", Vector3(0, 1.68, 0.10), 28, 0.011)
	_label(root, "WIFFALTRO", Vector3(0, 1.35, 0.10), 24, 0.011)


static func _label(root: Node3D, text: String, point: Vector3, font: int, pixels: float) -> void:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = point
	label.font_size = font
	label.pixel_size = pixels
	label.modulate = Color("e1dcc8")
	label.outline_size = 0
	root.get_node("Visual").add_child(label)


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3, color: Color) -> void:
	# The shared v1 scenery-box primitive has stable named after-terminal surfaces.
	StadiumNpcExpandedSeatingV1._box(root, id, center, size, color)

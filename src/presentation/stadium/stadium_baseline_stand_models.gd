class_name StadiumBaselineStandModels
extends RefCounted
## BA seven-meter straight lower bay with BK solid bases and represented access/seating.

const VERSION: int = 1
const ROWS: int = 10
const SEATS_PER_ROW: int = 5


static func lower(occupied: bool = true) -> Node3D:
	var root: Node3D = _root("ST-029")
	root.set_meta("represented_seats", ROWS * SEATS_PER_ROW)
	for row in range(ROWS):
		var height: float = 3.0 + row / 3.0
		var z: float = row * 0.7 + 0.35
		_box(root, "SolidRow%d" % row, Vector3(-0.35, height / 2, z),
			Vector3(5.3, height, 0.7), Color("818e84"))
		for column in range(SEATS_PER_ROW):
			var x: float = -2.55 + column * 0.8
			var index: int = row * SEATS_PER_ROW + column
			var color: Color = Color("4e776b") if row % 2 == 0 else Color("597f73")
			_box(root, "Seat%d" % index, Vector3(x, height + 0.42, z),
				Vector3(0.58, 0.08, 0.38), color, false)
			_box(root, "Back%d" % index, Vector3(x, height + 0.68, z + 0.21),
				Vector3(0.58, 0.46, 0.06), color, false)
			_box(root, "SeatBase%d" % index, Vector3(x, height + 0.20, z),
				Vector3(0.12, 0.40, 0.20), Color("48554e"), false)
			if occupied:
				StadiumSeatingModels._person(root, index, Vector3(x, height + 0.46, z))
				root.get_node("Visual/CrowdAnchor%d" % index).rotation.y = PI
		_box(root, "AislePost%d" % row, Vector3(2.18, height + 0.5, z),
			Vector3(0.05, 1, 0.05), Color("c0c7b9"))
		if row > 0:
			StadiumSeatingModels._segment(root, "AisleRail%d" % row,
				Vector3(2.18, height - 1.0 / 3.0 + 1, z - 0.7),
				Vector3(2.18, height + 1, z), 0.05, Color("c0c7b9"))
	# An outer ascent reaches the rear landing; the adjacent row aisle descends toward the field.
	for step in range(40):
		var height: float = (step + 1) * 0.15
		_box(root, "EntryStep%d" % step, Vector3(2.65, height / 2, (step + 0.5) * 0.175),
			Vector3(0.7, height, 0.175), Color("a6aa98"))
	_box(root, "FrontGuard", Vector3(-0.35, 3.5, 0.06),
		Vector3(5.3, 1, 0.12), Color("657969"))
	return root


static func lower_canopy() -> Node3D:
	var root: Node3D = _root("ST-053")
	root.set_meta("candidate_mount", "BASE-LOWER-ROOF-v1")
	for side in [-1, 1]:
		_box(root, "RearColumn%d" % side, Vector3(side * 2.7, 7.2, 6.6),
			Vector3(0.18, 2.4, 0.18), Color("6c7e80"))
		_box(root, "RoofBeam%d" % side, Vector3(side * 2.7, 8.49, 3.5),
			Vector3(0.18, 0.18, 7), Color("6c7e80"))
	_box(root, "Canopy", Vector3(0, 8.61, 3.5), Vector3(6.5, 0.06, 7), Color("b4b7a5"))
	_box(root, "FrontFascia", Vector3(0, 8.52, 0.06),
		Vector3(6.5, 0.24, 0.12), Color("536f6c"))
	return root


static func _root(item: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "") + "Candidate"
	root.set_meta("stadium_item", item)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	return root


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3,
	color: Color, solid: bool = true) -> void:
	StadiumSeatingModels._box(root, id, point, size, color, solid)

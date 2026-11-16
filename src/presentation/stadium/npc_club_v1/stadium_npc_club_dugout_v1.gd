class_name StadiumNpcClubDugoutV1
extends RefCounted
## Retained AC-01/r1 correspondence copy; never a current authoring dependency.
## Original: src/presentation/stadium/stadium_concrete_dugout_models.gd
## ST-074 CI blockout. Candidate until full side replacement and entry routing qualify.

const VERSION: int = 1


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ConcreteDugoutCandidate"
	root.set_meta("stadium_item", "ST-074")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	var concrete: Color = Color("8c968b")
	_box(root, "Roof", Vector3(0, 2.55, 1.325), Vector3(6, 0.3, 2.65),
		concrete, "DUGOUT_ROOF_TERMINAL")
	_box(root, "Rear", Vector3(0, 1.2, 2.575), Vector3(6, 2.4, 0.15),
		Color("657568"), "DECORATIVE_AFTER_TERMINAL")
	for side in [-1, 1]:
		_box(root, "FrontBarrier%d" % side, Vector3(side * 2, 0.6, 0.10),
			Vector3(2, 1.2, 0.2), concrete, "DUGOUT_FACE_LIVE")
		_box(root, "EndWall%d" % side, Vector3(side * 2.925, 1.2, 1.325),
			Vector3(0.15, 2.4, 2.65), Color("788779"), "DECORATIVE_AFTER_TERMINAL")
		_box(root, "RoofSupport%d" % side, Vector3(side * 2.80, 1.8, 0.12),
			Vector3(0.20, 1.2, 0.24), concrete, "DUGOUT_ROOF_TERMINAL")
		_box(root, "BenchLeg%d" % side, Vector3(side * 1.9, 0.225, 2.05),
			Vector3(0.15, 0.45, 0.42), Color("5b6658"), "DECORATIVE_AFTER_TERMINAL")
	_box(root, "BenchSeat", Vector3(0, 0.49, 2.05), Vector3(5.5, 0.08, 0.44),
		Color("b39a70"), "DECORATIVE_AFTER_TERMINAL")
	_box(root, "BenchBack", Vector3(0, 0.83, 2.28), Vector3(5.5, 0.42, 0.08),
		Color("9b8059"), "DECORATIVE_AFTER_TERMINAL")
	return root


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3,
	color: Color, role: String) -> void:
	StadiumNpcClubSeatingV1._box(root, id, point, size, color)
	var body: StaticBody3D = root.get_node("Collision/" + id)
	body.set_meta("ball_surface", &"stadium_dugout_candidate")
	body.set_meta("surface_role", role)
	body.get_child(0).shape.margin = 0

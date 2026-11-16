class_name StadiumTimberDugoutModels
extends RefCounted
## Complete ST-032 roofless timber candidate. Timber palette and thickness are authored choices.

const VERSION: int = 1
const TIMBER: Color = Color("866044")
const SEAT: Color = Color("bd9568")
const DARK: Color = Color("614936")


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "TimberDugoutCandidate"
	root.set_meta("stadium_item", "ST-032")
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_id", StadiumTimberDugoutContract.ID)
	root.set_meta("stadium_candidate_only", true)
	root.set_meta("runtime_adapter", "NOT_IMPLEMENTED")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	for side: int in [-1, 1]:
		_box(
			root,
			"FrontBarrier%d" % side,
			Vector3(side * 2, 0.6, 0.09),
			Vector3(2, 1.2, 0.18),
			TIMBER,
			"DUGOUT_FACE_LIVE"
		)
		# Finish rails stop at the full two-metre aperture and stay below the front cap.
		for row: int in range(5):
			_detail(
				root,
				"FrontJoin%d_%d" % [side, row],
				Vector3(side * 2, 0.20 + row * 0.20, 0.184),
				Vector3(2, 0.008, 0.008)
			)
		for end: int in [0, 1]:
			_box(
				root,
				"EndPost%d_%d" % [side, end],
				Vector3(side * 2.94, 0.65, 0.24 if end == 0 else 2.59),
				Vector3(0.12, 1.30, 0.12),
				TIMBER,
				"DECORATIVE_AFTER_TERMINAL"
			)
		for row: int in range(3):
			_box(
				root,
				"EndRail%d_%d" % [side, row],
				Vector3(side * 2.94, 0.35 + row * 0.45, 1.415),
				Vector3(0.12, 0.10, 2.47),
				SEAT,
				"DECORATIVE_AFTER_TERMINAL"
			)
		_box(
			root,
			"BenchLeg%d" % side,
			Vector3(side * 1.9, 0.225, 2.05),
			Vector3(0.14, 0.45, 0.42),
			DARK,
			"DECORATIVE_AFTER_TERMINAL"
		)
	for row: int in range(3):
		_box(
			root,
			"RearRail%d" % row,
			Vector3(0, 0.35 + row * 0.45, 2.59),
			Vector3(6, 0.10, 0.12),
			SEAT,
			"DECORATIVE_AFTER_TERMINAL"
		)
	_box(
		root,
		"RearPost",
		Vector3(0, 0.65, 2.59),
		Vector3(0.12, 1.30, 0.12),
		TIMBER,
		"DECORATIVE_AFTER_TERMINAL"
	)
	_box(
		root,
		"BenchSeat",
		Vector3(0, 0.49, 2.05),
		Vector3(5.5, 0.08, 0.44),
		SEAT,
		"DECORATIVE_AFTER_TERMINAL"
	)
	_box(
		root,
		"BenchBack",
		Vector3(0, 0.83, 2.28),
		Vector3(5.5, 0.42, 0.08),
		TIMBER,
		"DECORATIVE_AFTER_TERMINAL"
	)
	return root


static func _box(
	root: Node3D, id: String, at: Vector3, size: Vector3, color: Color, role: String
) -> void:
	StadiumStarterModels._box(root, id, at, size, color, role)
	var body: StaticBody3D = root.get_node("Collision/" + id)
	body.set_meta("ball_surface", &"stadium_timber_candidate")
	body.get_child(0).name = "Shape"
	body.get_child(0).shape.margin = 0


static func _detail(root: Node3D, id: String, at: Vector3, size: Vector3) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	StadiumStarterModels._mesh(root, id, at, mesh, DARK)

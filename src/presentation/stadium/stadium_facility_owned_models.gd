class_name StadiumFacilityOwnedModels
extends RefCounted
## Fresh full-size owned facilities; only the surviving primitive helper is reused.
## Placement/admission belongs to the shared runtime. Frozen factories are untouched.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-033", "ST-034", "ST-055", "ST-056", "ST-057", "ST-059"]
const ROOM_SHELL: AABB = AABB(Vector3(-2.75, 7.20, 12.0), Vector3(5.5, 3.0, 4.0))
const ROOM_RESERVATION: AABB = AABB(Vector3(-2.95, 0, 7.55), Vector3(5.9, 10.2, 8.6))
const STONE: Color = Color("c5b38d")
const FRAME: Color = Color("425b53")
const WALL: Color = Color("d2ceb9")
const STEEL: Color = Color("64796e")
const GLASS: Color = Color(0.47, 0.69, 0.73, 0.36)
const TIMBER: Color = Color("a27c54")


static func create(item: String) -> Node3D:
	match item:
		"ST-033":
			return _concession()
		"ST-034":
			return _merchandise()
		"ST-055", "ST-057":
			return _elevated_room(item)
		"ST-056":
			return _announcer()
		"ST-059":
			return _ticket()
	return null


static func envelope(item: String) -> AABB:
	match item:
		"ST-033":
			return AABB(Vector3(-3, 0, -3), Vector3(6, 3.2, 6))
		"ST-034":
			return AABB(Vector3(-3, 0, -3), Vector3(6, 3.0, 6))
		"ST-055", "ST-057":
			return ROOM_RESERVATION
		"ST-056":
			return AABB(Vector3(-2, 0, -2.5), Vector3(4, 3.5, 5))
		"ST-059":
			return AABB(Vector3(-1.5, 0, -1.5), Vector3(3, 3.0, 3))
	return AABB()


static func _root(item: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "") + "OwnedFacility"
	root.set_meta("stadium_item", item)
	root.set_meta("model_version", VERSION)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("owned_geometry_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("authoring_source", "fresh-owned-facility-primitives-v1")
	root.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("physics_profile", "DECORATIVE_AFTER_TERMINAL")
	root.set_meta("front_direction", Vector3.FORWARD)
	root.set_meta("envelope", envelope(item))
	for branch: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = branch
		root.add_child(node)
	return root


static func _elevated_room(item: String) -> Node3D:
	var root: Node3D = _root(item)
	root.set_meta("room_shell_bounds", ROOM_SHELL)
	root.set_meta("room_floor_top", 7.35)
	root.set_meta("access_host", "ST-031")
	root.set_meta("host_contact_surface", "Visual/ConcourseDeck")
	root.set_meta("host_contact_height", 6.15)
	root.set_meta("represented_access", "eight-risers-rear-bridge-front-door")
	_room_supports(root)
	# Full 5.5 x 4 x 3m shell. Floors/roof are included, never a scaled facade.
	_box(root, "RoomFloor", Vector3(0, 7.275, 14), Vector3(5.5, 0.15, 4), STONE)
	_box(root, "RoomRoof", Vector3(0, 10.125, 14), Vector3(5.5, 0.15, 4), FRAME)
	_box(root, "RoomLeftWall", Vector3(-2.675, 8.70, 14), Vector3(0.15, 2.70, 4), WALL)
	_box(root, "RoomRightWall", Vector3(2.675, 8.70, 14), Vector3(0.15, 2.70, 4), WALL)
	_box(root, "RoomRearWall", Vector3(0, 8.70, 15.925), Vector3(5.2, 2.70, 0.15), WALL)
	_box(root, "RoomFrontSill", Vector3(-0.725, 7.775, 12.075), Vector3(3.75, 0.85, 0.15), WALL)
	_box(root, "RoomFrontHeader", Vector3(0, 9.85, 12.075), Vector3(5.2, 0.40, 0.15), FRAME)
	_box(root, "RoomDoorJambLeft", Vector3(1.20, 8.50, 12.075), Vector3(0.10, 2.30, 0.15), FRAME)
	_box(root, "RoomDoorJambRight", Vector3(2.525, 8.50, 12.075), Vector3(0.15, 2.30, 0.15), FRAME)
	# Three individually glazed field-facing panes, with disjoint mullions.
	for index in range(3):
		var x0: float = -2.60 + index * 1.25
		_box(
			root,
			"RoomWindow%d" % index,
			Vector3(x0 + 0.60, 8.925, 12.075),
			Vector3(1.20, 1.45, 0.05),
			GLASS
		)
		_box(
			root,
			"RoomMullion%d" % index,
			Vector3(x0 + 1.225, 8.925, 12.075),
			Vector3(0.05, 1.45, 0.15),
			FRAME
		)
	_box(root, "RoomDoorLower", Vector3(1.85, 7.80, 12.075), Vector3(1.20, 0.90, 0.07), FRAME)
	_box(root, "RoomDoorGlass", Vector3(1.85, 8.90, 12.075), Vector3(1.20, 1.30, 0.05), GLASS)
	_box(root, "RoomDoorTop", Vector3(1.85, 9.60, 12.075), Vector3(1.20, 0.10, 0.07), FRAME)
	_box(root, "RoomDoorHandle", Vector3(2.30, 8.25, 12.025), Vector3(0.05, 0.24, 0.03), STONE)
	_sign(
		root,
		"PRESS" if item == "ST-055" else "CLUB SUITE",
		Vector3(-0.75, 9.85, 11.94),
		Vector2(3.0, 0.34),
		42,
		0.005
	)
	# The sign board back touches the full front header at z12.0.
	if item == "ST-055":
		_press_furniture(root, 7.35, 12.65)
	else:
		_suite_furniture(root)
	return root


static func _room_supports(root: Node3D) -> void:
	# The first footing starts z10.10, behind the untouched ST031 rear face9.875.
	for row in range(3):
		var z: float = [10.40, 12.40, 15.60][row]
		var beam_bottom: float = 6.95 if row == 0 else 7.0
		for side: int in [-1, 1]:
			var x: float = side * 2.40
			_box(
				root,
				"SupportFoot%d_%d" % [row, side],
				Vector3(x, 0.15, z),
				Vector3(0.60, 0.30, 0.60),
				STONE
			)
			_box(
				root,
				"GroundSupport%d_%d" % [row, side],
				Vector3(x, (0.30 + beam_bottom) / 2.0, z),
				Vector3(0.26, beam_bottom - 0.30, 0.26),
				STEEL
			)
		_box(
			root,
			"SupportBeam%d" % row,
			Vector3(0, beam_bottom + 0.10, z),
			Vector3(5.5, 0.20, 0.30),
			STEEL
		)
	_box(root, "RearLanding", Vector3(0, 7.25, 10.655), Vector3(5.5, 0.20, 2.69), STONE)
	for index in range(8):
		var top: float = 6.30 + index * 0.15
		_box(
			root,
			"AccessStep%d" % index,
			Vector3(1.75, (6.15 + top) / 2.0, 7.66 + index * 0.22),
			Vector3(1.10, top - 6.15, 0.22),
			STONE
		)
	# Guard panels butt at corners. The 1.10m stair entrance remains open.
	_box(root, "LandingFrontGuard", Vector3(-0.775, 7.85, 9.36), Vector3(3.95, 1.0, 0.10), FRAME)
	_box(
		root, "LandingFrontGuardRight", Vector3(2.525, 7.85, 9.36), Vector3(0.45, 1.0, 0.10), FRAME
	)
	for side: int in [-1, 1]:
		_box(
			root,
			"LandingSideGuard%d" % side,
			Vector3(side * 2.70, 7.85, 10.705),
			Vector3(0.10, 1.0, 2.59),
			FRAME
		)


static func _concession() -> Node3D:
	var root: Node3D = _root("ST-033")
	root.set_meta("building_shell_bounds", AABB(Vector3(-2.25, 0, -0.85), Vector3(4.5, 3.2, 3.5)))
	_ground_shell(root, 4.5, 3.5, 3.2, 0.90)
	_box(root, "FrontApron", Vector3(0, 0.075, -1.725), Vector3(4.5, 0.15, 1.75), STONE)
	_box(root, "ServingBase", Vector3(0, 0.575, -0.775), Vector3(4.2, 0.85, 0.15), WALL)
	_box(root, "ServingCounter", Vector3(0, 1.05, -0.775), Vector3(4.2, 0.10, 0.45), TIMBER)
	for side: int in [-1, 1]:
		_box(
			root,
			"ServingPillar%d" % side,
			Vector3(side * 2.025, 2.075, -0.775),
			Vector3(0.15, 1.95, 0.15),
			FRAME
		)
	_box(root, "ServingHeader", Vector3(0, 2.70, -0.775), Vector3(3.90, 0.70, 0.15), FRAME)
	# Field-facing shade, with posts grounded in the included front apron.
	for stripe in range(10):
		_box(
			root,
			"AwningStripe%d" % stripe,
			Vector3(-1.935 + stripe * 0.43, 2.54, -1.625),
			Vector3(0.43, 0.12, 1.55),
			WALL if stripe % 2 == 0 else Color("b86d4a")
		)
	for side: int in [-1, 1]:
		_box(
			root,
			"AwningPost%d" % side,
			Vector3(side * 2.05, 1.315, -2.30),
			Vector3(0.10, 2.33, 0.10),
			FRAME
		)
	_sign(root, "CONCESSIONS", Vector3(0, 2.84, -1.00), Vector2(3.95, 0.46), 48, 0.006)
	_sign_brackets(root, 2.84, -0.895, 0.09, 1.6)
	_box(root, "RearWorktop", Vector3(0, 1.02, 2.1), Vector3(3.8, 0.12, 0.6), TIMBER)
	for side: int in [-1, 1]:
		_box(
			root,
			"WorktopBase%d" % side,
			Vector3(side * 1.5, 0.555, 2.1),
			Vector3(0.40, 0.81, 0.60),
			FRAME
		)
	_box(root, "MenuBoard", Vector3(-0.7, 2.0, 2.48), Vector3(1.75, 1.0, 0.04), FRAME)
	_label(root, "MenuText", "SNACKS  /  DRINKS", Vector3(-0.7, 2.0, 2.45), 34, 0.005, WALL)
	return root


static func _merchandise() -> Node3D:
	var root: Node3D = _root("ST-034")
	root.set_meta("building_shell_bounds", AABB(Vector3(-1.75, 0, -0.90), Vector3(3.5, 3, 3)))
	_ground_shell(root, 3.5, 3.0, 3.0, 0.60)
	_box(root, "FrontApron", Vector3(0, 0.075, -1.50), Vector3(3.5, 0.15, 1.20), STONE)
	_shop_front(root, 3.5, -0.90, 2.85, 0.45, 1.45)
	_box(root, "Awning", Vector3(0, 2.45, -1.50), Vector3(3.4, 0.12, 1.20), FRAME)
	_sign(root, "CLUB SHOP", Vector3(0, 2.73, -1.05), Vector2(2.9, 0.40), 48, 0.005)
	_sign_brackets(root, 2.73, -0.945, 0.09, 1.1)
	# Freestanding display case is grounded through its full plinth.
	_box(root, "MerchDisplayPlinth", Vector3(-0.65, 0.30, 1.45), Vector3(1.7, 0.30, 0.65), FRAME)
	_box(root, "MerchDisplayCase", Vector3(-0.65, 1.15, 1.45), Vector3(1.7, 1.40, 0.65), TIMBER)
	for shelf in range(3):
		_box(
			root,
			"MerchShelf%d" % shelf,
			Vector3(-0.65, 0.61 + shelf * 0.53, 1.09),
			Vector3(1.7, 0.06, 0.07),
			STONE
		)
		for stock in range(4):
			_box(
				root,
				"FoldedMerch%d_%d" % [shelf, stock],
				Vector3(-1.28 + stock * 0.42, 0.72 + shelf * 0.53, 1.09),
				Vector3(0.32, 0.16, 0.07),
				WALL if stock % 2 == 0 else Color("577f73")
			)
	return root


static func _announcer() -> Node3D:
	var root: Node3D = _root("ST-056")
	root.set_meta("building_shell_bounds", AABB(Vector3(-2, 0, -1.15), Vector3(4, 3.5, 3)))
	_ground_shell(root, 4.0, 3.0, 3.5, 0.35)
	_box(root, "FrontApron", Vector3(0, 0.075, -1.50), Vector3(4.0, 0.15, 0.70), STONE)
	_shop_front(root, 4.0, -1.15, 3.35, 0.75, 1.65)
	_sign(root, "ANNOUNCER", Vector3(-0.30, 3.10, -1.30), Vector2(3.1, 0.38), 48, 0.005)
	_sign_brackets(root, 3.10, -1.195, 0.09, 1.1)
	_press_furniture(root, 0.15, -0.60, 0.65)
	return root


static func _ticket() -> Node3D:
	var root: Node3D = _root("ST-059")
	root.set_meta("building_shell_bounds", AABB(Vector3(-1.1, 0, -0.90), Vector3(2.2, 3, 2.2)))
	_ground_shell(root, 2.2, 2.2, 3.0, 0.20)
	_box(root, "FrontApron", Vector3(0, 0.075, -1.10), Vector3(2.2, 0.15, 0.40), STONE)
	_box(root, "TicketFrontBase", Vector3(0, 0.575, -0.825), Vector3(1.9, 0.85, 0.15), WALL)
	_box(root, "TicketCounter", Vector3(0, 1.05, -1.0), Vector3(1.9, 0.10, 0.50), TIMBER)
	for side: int in [-1, 1]:
		_box(
			root,
			"TicketFrontJamb%d" % side,
			Vector3(side * 0.90, 1.70, -0.825),
			Vector3(0.10, 1.20, 0.15),
			FRAME
		)
	_box(root, "TicketWindow", Vector3(0, 1.95, -0.825), Vector3(1.7, 0.70, 0.05), GLASS)
	_box(root, "TicketHeader", Vector3(0, 2.575, -0.825), Vector3(1.9, 0.55, 0.15), FRAME)
	_box(root, "TicketAwning", Vector3(0, 2.30, -1.15), Vector3(2.1, 0.10, 0.50), FRAME)
	_sign(root, "TICKETS", Vector3(0, 2.65, -1.05), Vector2(1.95, 0.36), 44, 0.005)
	_sign_brackets(root, 2.65, -0.945, 0.09, 0.65)
	_box(root, "TicketDesk", Vector3(0, 0.96, 0.45), Vector3(1.6, 0.10, 0.50), TIMBER)
	for side: int in [-1, 1]:
		_box(
			root,
			"TicketDeskLeg%d" % side,
			Vector3(side * 0.66, 0.53, 0.45),
			Vector3(0.10, 0.76, 0.45),
			FRAME
		)
	return root


static func _ground_shell(
	root: Node3D, width: float, depth: float, height: float, center_z: float
) -> void:
	var wall_height: float = height - 0.30
	_box(root, "GroundBase", Vector3(0, 0.075, center_z), Vector3(width, 0.15, depth), STONE)
	_box(
		root,
		"BuildingRoof",
		Vector3(0, height - 0.075, center_z),
		Vector3(width, 0.15, depth),
		FRAME
	)
	for side: int in [-1, 1]:
		_box(
			root,
			"SideWall%d" % side,
			Vector3(side * (width / 2.0 - 0.075), height / 2.0, center_z),
			Vector3(0.15, wall_height, depth),
			WALL
		)
	# A real rear staff door is partitioned into the rear wall, rather than pasted on it.
	var rear_z: float = center_z + depth / 2.0 - 0.075
	var wing: float = (width - 0.30 - 0.80) / 2.0
	for side: int in [-1, 1]:
		_box(
			root,
			"RearWall%d" % side,
			Vector3(side * (0.40 + wing / 2.0), height / 2.0, rear_z),
			Vector3(wing, wall_height, 0.15),
			WALL
		)
	_box(root, "StaffDoor", Vector3(0, 1.175, rear_z), Vector3(0.80, 2.05, 0.07), FRAME)
	_box(
		root,
		"StaffDoorHeader",
		Vector3(0, (2.20 + height - 0.15) / 2.0, rear_z),
		Vector3(0.80, height - 2.35, 0.15),
		WALL
	)
	_box(
		root,
		"StaffDoorHandle",
		Vector3(0.27, 1.15, rear_z + 0.05),
		Vector3(0.04, 0.20, 0.03),
		STONE
	)


static func _shop_front(
	root: Node3D, width: float, front: float, top: float, door_left: float, door_right: float
) -> void:
	var left: float = -width / 2.0 + 0.15
	var right: float = width / 2.0 - 0.15
	var split: float = door_left - 0.10
	var face_z: float = front + 0.075
	_box(
		root,
		"DisplaySill",
		Vector3((left + split) / 2.0, 0.425, face_z),
		Vector3(split - left, 0.55, 0.15),
		WALL
	)
	_box(
		root,
		"DisplayWindow",
		Vector3((left + split) / 2.0, 1.525, face_z),
		Vector3(split - left, 1.65, 0.05),
		GLASS
	)
	_box(
		root,
		"FrontHeader",
		Vector3(0, (2.35 + top) / 2.0, face_z),
		Vector3(width - 0.30, top - 2.35, 0.15),
		FRAME
	)
	_box(
		root,
		"FrontDoorJamb",
		Vector3(door_left - 0.05, 1.25, face_z),
		Vector3(0.10, 2.20, 0.15),
		FRAME
	)
	_box(
		root,
		"FrontDoorLower",
		Vector3((door_left + door_right) / 2.0, 0.60, face_z),
		Vector3(door_right - door_left, 0.90, 0.07),
		FRAME
	)
	_box(
		root,
		"FrontDoorGlass",
		Vector3((door_left + door_right) / 2.0, 1.65, face_z),
		Vector3(door_right - door_left, 1.20, 0.05),
		GLASS
	)
	_box(
		root,
		"FrontDoorTop",
		Vector3((door_left + door_right) / 2.0, 2.30, face_z),
		Vector3(door_right - door_left, 0.10, 0.07),
		FRAME
	)
	_box(
		root,
		"FrontDoorReturn",
		Vector3((door_right + right) / 2.0, 1.25, face_z),
		Vector3(right - door_right, 2.20, 0.15),
		FRAME
	)
	_box(
		root,
		"FrontDoorHandle",
		Vector3(door_right - 0.14, 1.15, front + 0.025),
		Vector3(0.04, 0.20, 0.03),
		STONE
	)


static func _press_furniture(
	root: Node3D, floor_y: float, front_z: float, scale_width: float = 1.0
) -> void:
	# Width parameter selects a new authored desk size; transforms always stay identity.
	var width: float = 3.0 * scale_width
	var center_x: float = -0.65
	_box(
		root,
		"BroadcastDesk",
		Vector3(center_x, floor_y + 0.79, front_z),
		Vector3(width, 0.10, 0.65),
		TIMBER
	)
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			_box(
				root,
				"DeskLeg%d_%d" % [side, end],
				Vector3(
					center_x + side * (width / 2.0 - 0.12), floor_y + 0.37, front_z + end * 0.22
				),
				Vector3(0.08, 0.74, 0.08),
				FRAME
			)
	for index in range(2):
		var x: float = center_x + (-0.68 if index == 0 else 0.68) * scale_width
		_box(
			root,
			"MonitorFoot%d" % index,
			Vector3(x, floor_y + 0.86, front_z - 0.10),
			Vector3(0.30, 0.04, 0.20),
			FRAME
		)
		_box(
			root,
			"MonitorStem%d" % index,
			Vector3(x, floor_y + 0.94, front_z - 0.10),
			Vector3(0.06, 0.12, 0.06),
			FRAME
		)
		_box(
			root,
			"Monitor%d" % index,
			Vector3(x, floor_y + 1.18, front_z - 0.10),
			Vector3(0.56, 0.36, 0.06),
			Color("263d3d")
		)
		_chair(root, "DeskChair%d" % index, Vector3(x, floor_y, front_z + 0.85))


static func _chair(root: Node3D, id: String, origin: Vector3) -> void:
	_box(root, id + "Seat", origin + Vector3(0, 0.46, 0), Vector3(0.52, 0.08, 0.50), FRAME)
	_box(root, id + "Back", origin + Vector3(0, 0.72, 0.21), Vector3(0.52, 0.44, 0.08), FRAME)
	for side: int in [-1, 1]:
		for end: int in [-1, 1]:
			_box(
				root,
				id + "Leg%d_%d" % [side, end],
				origin + Vector3(side * 0.20, 0.21, end * 0.19),
				Vector3(0.05, 0.42, 0.05),
				STEEL
			)


static func _suite_furniture(root: Node3D) -> void:
	for side: int in [-1, 1]:
		_box(
			root,
			"SofaFoot%d" % side,
			Vector3(-0.30 + side * 1.50, 7.45, 15.15),
			Vector3(0.15, 0.20, 0.65),
			FRAME
		)
	_box(root, "SofaBase", Vector3(-0.30, 7.65, 15.15), Vector3(3.6, 0.20, 0.85), TIMBER)
	_box(root, "SofaBack", Vector3(-0.30, 8.15, 15.475), Vector3(3.6, 0.80, 0.20), FRAME)
	for side: int in [-1, 1]:
		_box(
			root,
			"SofaArm%d" % side,
			Vector3(-0.30 + side * 1.70, 7.95, 15.05),
			Vector3(0.20, 0.40, 0.65),
			FRAME
		)
	for index in range(3):
		_box(
			root,
			"SofaCushion%d" % index,
			Vector3(-1.365 + index * 1.065, 7.85, 15.05),
			Vector3(1.065, 0.20, 0.65),
			Color("6b8e7e")
		)
	_box(root, "SuiteTableTop", Vector3(-0.30, 7.91, 13.90), Vector3(1.80, 0.12, 0.75), TIMBER)
	for side: int in [-1, 1]:
		_box(
			root,
			"SuiteTableLeg%d" % side,
			Vector3(-0.30 + side * 0.65, 7.60, 13.90),
			Vector3(0.10, 0.50, 0.55),
			FRAME
		)


static func _sign(
	root: Node3D, value: String, point: Vector3, size: Vector2, font_size: int, pixels: float
) -> void:
	_box(root, "SignBoard", point, Vector3(size.x, size.y, 0.12), FRAME)
	var text_point: Vector3 = point + Vector3(0, 0, -0.08)
	_label(root, "SignText", value, text_point, font_size, pixels, WALL)
	root.set_meta("sign_board_center", point)
	root.set_meta("sign_front_z", point.z - 0.06)
	root.set_meta("sign_text_z", text_point.z)
	root.set_meta("sign_usable_size", size - Vector2(0.12, 0.04))
	root.get_node("Visual/SignText").set_meta("backing_board", NodePath("../SignBoard"))


static func _sign_brackets(
	root: Node3D, y: float, z: float, depth: float, half_span: float
) -> void:
	for side: int in [-1, 1]:
		_box(
			root,
			"SignMount%d" % side,
			Vector3(side * half_span, y, z),
			Vector3(0.10, 0.20, depth),
			FRAME
		)


static func _label(
	root: Node3D,
	id: String,
	value: String,
	point: Vector3,
	font_size: int,
	pixels: float,
	color: Color
) -> void:
	var label: Label3D = Label3D.new()
	label.name = id
	label.text = value
	label.font = ThemeDB.fallback_font
	label.font_size = font_size
	label.pixel_size = pixels
	label.outline_size = 0
	label.modulate = color
	label.position = point
	label.rotation.y = PI
	label.no_depth_test = false
	label.double_sided = false
	label.set_meta("surface_role", "DECORATIVE_LABEL_ONLY")
	label.set_meta("requires_process_frame_for_mesh", true)
	label.set_meta(
		"font_measurement",
		label.font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size) * pixels
	)
	root.get_node("Visual").add_child(label)


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3, color: Color) -> void:
	StadiumSeatingModels._box(root, id, point, size, color)
	var shape: CollisionShape3D = root.get_node("Collision/" + id).get_child(0)
	shape.shape.margin = 0.0
	var visual: MeshInstance3D = root.get_node("Visual/" + id)
	visual.set_meta("physical_bounds", AABB(point - size / 2.0, size))
	if color.a < 1.0:
		var material: StandardMaterial3D = visual.material_override
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.roughness = 0.20

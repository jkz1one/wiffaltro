class_name StadiumRisingAppleModels
extends RefCounted
## Complete ST-047 landmark in metres. The caller owns confirmed-result timing.
## One translation moves the complete apple and every matching physical solid.
## Reset concealment changes only RisingAssembly visibility; its decorative hulls remain enabled.

const P = preload("res://src/presentation/stadium/stadium_landmark_models.gd")
const VERSION: int = 1
const ITEM: String = "ST-047"
const ITEMS: Array[String] = [ITEM]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const MAX_RISE: float = 3.2
const ENVELOPE: AABB = AABB(Vector3(-3, 0, -3), Vector3(6, 8, 6))
# Conservative authored geometry bounds retain the concealed fruit and physical hulls.
const DOWN_BOUNDS: AABB = AABB(Vector3(-2.9, 0, -2.9), Vector3(5.8, 4.65, 5.8))
const SWEPT_BOUNDS: AABB = AABB(Vector3(-2.9, 0, -2.9), Vector3(5.8, 7.85, 5.8))
const MOVING_PATH: NodePath = ^"RisingAssembly"
const FIXED_MESH_COUNT: int = 59
const MOVING_MESH_COUNT: int = 10
const MESH_COUNT: int = FIXED_MESH_COUNT + MOVING_MESH_COUNT
const SOLID_COUNT: int = MESH_COUNT
const RED: Color = Color("c83d38")
const RED_LIGHT: Color = Color("dc5145")
const RED_DARK: Color = Color("aa302f")
const LEAF_GREEN: Color = Color("4c7950")
const LEAF_VEIN: Color = Color("9ca95e")
const DRUM: Color = Color("364e4a")


static func create(item: String = ITEM) -> Node3D:
	if item != ITEM:
		return null
	var root: Node3D = _assembly("ST047RisingHomeRunApple")
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("final_art_accepted", false)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("visible_bounds", DOWN_BOUNDS)
	root.set_meta("swept_bounds", SWEPT_BOUNDS)
	root.set_meta("static_geometry", false)
	root.set_meta("scenery_only", true)
	root.set_meta("physics_profile", ROLE)
	root.set_meta("obstacle_units", 0)
	root.set_meta("ambient_ball_count", 0)
	root.set_meta("animated_during_pitch", false)
	root.set_meta("ball_award_enabled", false)
	root.set_meta("water_entry_enabled", false)
	root.set_meta("confirmed_result_only", true)
	_base(root)
	var moving: Node3D = _assembly("RisingAssembly")
	root.add_child(moving)
	moving.visible = false
	_apple(moving)
	return root


static func _assembly(id: String) -> Node3D:
	var branch: Node3D = Node3D.new()
	branch.name = id
	branch.set_meta("stadium_item", ITEM)
	branch.set_meta("surface_role", ROLE)
	for child_name: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = child_name
		branch.add_child(child)
	return branch


static func envelope(item: String = ITEM) -> AABB:
	return ENVELOPE if item == ITEM else AABB()


static func bounds(item: String = ITEM) -> AABB:
	return envelope(item)


static func visible_bounds(item: String = ITEM, rise: float = 0.0) -> AABB:
	if item != ITEM or not is_finite(rise) or rise < 0.0 or rise > MAX_RISE:
		return AABB()
	return AABB(DOWN_BOUNDS.position, DOWN_BOUNDS.size + Vector3(0, rise, 0))


static func swept_bounds(item: String = ITEM) -> AABB:
	return SWEPT_BOUNDS if item == ITEM else AABB()


static func mesh_count(item: String = ITEM) -> int:
	return MESH_COUNT if item == ITEM else 0


static func solid_count(item: String = ITEM) -> int:
	return SOLID_COUNT if item == ITEM else 0


static func support_points(item: String = ITEM) -> PackedVector3Array:
	if item != ITEM:
		return PackedVector3Array()
	return PackedVector3Array(
		[
			Vector3.ZERO,
			Vector3(-2.7, 0, 0),
			Vector3(2.7, 0, 0),
			Vector3(0, 0, -2.7),
			Vector3(0, 0, 2.7)
		]
	)


static func set_rise(model: Node3D, metres: float) -> bool:
	if (
		model == null
		or not is_instance_valid(model)
		or model.get_meta("stadium_item", "") != ITEM
		or not model.has_node(MOVING_PATH)
		or not is_finite(metres)
		or metres < 0.0
		or metres > MAX_RISE
	):
		return false
	var moving: Node3D = model.get_node(MOVING_PATH)
	moving.transform = Transform3D(Basis.IDENTITY, Vector3(0, metres, 0))
	# Use the actual stored pose, including native-float rounding at zero.
	# Node visibility has no effect on the retained after-terminal collision.
	moving.visible = moving.position.y > 0.0
	return true


static func rise_height(model: Node3D) -> float:
	if (
		model == null
		or not is_instance_valid(model)
		or model.get_meta("stadium_item", "") != ITEM
		or not model.has_node(MOVING_PATH)
	):
		return 0.0
	return (model.get_node(MOVING_PATH) as Node3D).position.y


static func _base(root: Node3D) -> void:
	P._stem(root, "AppleGroundPlinth", Vector3.ZERO, Vector3(0, 0.30, 0), 2.9, 2.9, P.STONE, 32)
	P._stem(
		root,
		"AppleDrumFoot",
		Vector3(0, 0.30, 0),
		Vector3(0, 0.46, 0),
		2.65,
		2.65,
		P.STONE_EDGE,
		32
	)
	# The open top-hat consists of real convex shell sectors, never an aperture-spanning proxy.
	# The entire unchanged apple clears the 1.90m inner radius throughout its vertical travel.
	_ring(root, "AppleHatBody", 0.46, 4.25, 1.90, 2.45, P.DARK_STEEL)
	_ring(root, "AppleHatBand", 3.92, 4.25, 2.45, 2.50, P.BRASS)
	_ring(root, "AppleHatBrim", 4.25, 4.50, 1.90, 2.85, P.DARK_STEEL)
	# The fixed guide stays inside the top-hat body, including when the apple is hidden.
	# At maximum rise it still intersects the translated carriage by 0.02m.
	P._stem(
		root, "AppleLiftGuide", Vector3(0, 0.30, 0), Vector3(0, 4.32, 0), 0.18, 0.18, P.STEEL, 16
	)
	P._box(root, "AppleFrontPlaque", Vector3(0, 0.93, -2.46), Vector3(1.70, 0.48, 0.08), P.BRASS)
	P._box(
		root, "ApplePlaqueInset", Vector3(0, 0.93, -2.51), Vector3(1.48, 0.30, 0.035), P.DARK_STEEL
	)
	for side: int in [-1, 1]:
		P._sphere(
			root,
			"ApplePlaqueRivet%d" % side,
			Vector3(side * 0.70, 0.93, -2.54),
			Vector3(0.055, 0.055, 0.035),
			P.STONE_EDGE
		)
	for side: int in [-1, 1]:
		for back: int in [-1, 1]:
			P._stem(
				root,
				"AppleBaseBolt%d_%d" % [side, back],
				Vector3(side * 1.91, 0.30, back * 1.91),
				Vector3(side * 1.91, 0.39, back * 1.91),
				0.11,
				0.11,
				P.DARK_STEEL,
				12
			)


static func _ring(
	root: Node3D, id: String, bottom: float, top: float, inner: float, outer: float, color: Color
) -> void:
	for segment in range(16):
		var a: float = TAU * segment / 16.0
		var b: float = TAU * (segment + 1) / 16.0
		var points: PackedVector3Array = []
		for y: float in [bottom, top]:
			for polar: Vector2 in [
				Vector2(inner, a), Vector2(outer, a), Vector2(outer, b), Vector2(inner, b)
			]:
				points.append(Vector3(cos(polar.y) * polar.x, y, sin(polar.y) * polar.x))
		P._solid(root, "%s%02d" % [id, segment], points, P.PRISM_FACES, color)


static func _apple(root: Node3D) -> void:
	P._stem(
		root,
		"AppleLiftCarriage",
		Vector3(0, 1.10, 0),
		Vector3(0, 1.38, 0),
		0.95,
		0.95,
		P.DARK_STEEL,
		16
	)
	P._sphere(root, "AppleLowerBody", Vector3(0, 2.15, 0), Vector3(1.10, 0.90, 1.10), RED_DARK)
	P._sphere(root, "AppleMainBody", Vector3(0, 2.80, 0), Vector3(1.75, 1.30, 1.65), RED)
	P._sphere(root, "AppleShoulderLeft", Vector3(-0.62, 3.40, 0), Vector3(1.16, 0.80, 1.58), RED)
	P._sphere(
		root, "AppleShoulderRight", Vector3(0.62, 3.40, 0), Vector3(1.16, 0.80, 1.58), RED_LIGHT
	)
	P._stem(
		root, "AppleCrownDimple", Vector3(0, 3.98, 0), Vector3(0, 4.20, 0), 0.38, 0.30, RED_DARK, 16
	)
	P._stem(
		root, "AppleStem", Vector3(0, 4.08, 0), Vector3(0, 4.65, 0), 0.30, 0.22, P.TIKI_WOOD, 12
	)
	P._beam(
		root, "AppleLeafStalk", Vector3(0.08, 4.30, 0), Vector3(0.48, 4.39, 0), 0.10, P.TIKI_WOOD
	)
	var leaf: PackedVector3Array = []
	for thickness: float in [-0.035, 0.035]:
		for point: Vector3 in [
			Vector3(0.26, 4.34, 0),
			Vector3(0.825, 4.40, -0.40),
			Vector3(1.39, 4.46, 0),
			Vector3(0.825, 4.40, 0.40)
		]:
			leaf.append(point + Vector3(0, thickness, 0))
	P._solid(root, "AppleLeaf", leaf, P.PRISM_FACES, LEAF_GREEN)
	P._beam(root, "AppleLeafVein", Vector3(0.28, 4.39, 0), Vector3(1.28, 4.49, 0), 0.035, LEAF_VEIN)

class_name StadiumWaterfallLiveModels
extends RefCounted
## Isolated ST046 full-scale live candidate. The archived factory remains untouched.
## Water is visual only. Entry admits observation, NEVER a terminal baseball result.
## Unreachable means grounded defenders outside the actual closed basin perimeter;
## climbing, floating balls, a broad reservation and an arbitrary water box prove nothing.

const Frozen = preload("res://src/presentation/stadium/stadium_waterfall_models.gd")
const VERSION: int = 1
const ITEM: String = "ST-046"
const ITEMS: Array[String] = [ITEM]
const LIVE_UNITS: int = 4
const SURFACE: String = "WATERFALL_STONE"
const LIVE: String = "LIVE_RICOCHET"
const TRAP_ID: String = "ST046_BASIN_POCKET_v1"
const APERTURE_ID: String = "BASIN_TOP"
const BODY_RADIUS: float = 0.32
const MAX_DEFENDER_REACH: float = 0.76
const SUPPORT_TOLERANCE: float = 0.005
const EPS: float = 0.00001
const SOLID_IDS: Array[String] = [
	"BasinFloor",
	"BasinFront",
	"BasinLeft",
	"BasinRight",
	"BasinBack",
	"RockLower",
	"RockMiddle",
	"RockCrownLeft",
	"RockCrownRight",
	"RockShoulderLeft",
	"RockShoulderRight",
	"SpillLip",
	"CatchLedge"
]
# A deliberately small SUBSET of the free channel, not a collider or a water volume.
# Even its nearest front corner is 0.97 m from a legal exterior defender's centre.
const POCKET: Rect2 = Rect2(Vector2(-3.30, -1.25), Vector2(6.60, 0.35))


static func create(item: String = ITEM, live: bool = true) -> Node3D:
	if item != ITEM or not geometry_contract_valid():
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST046FullScaleLiveCandidate"
	root.set_meta("stadium_item", ITEM)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("waterfall_live_version", VERSION)
	root.set_meta("live_furnishing", live)
	root.set_meta("scenery_only", not live)
	root.set_meta("working_geometry_only", true)
	root.set_meta("night_qualified", false)
	root.set_meta("obstacle_units", LIVE_UNITS if live else 0)
	root.set_meta("envelope", envelope())
	root.set_meta("reservation", reservation())
	var visual: Node3D = Frozen.create()
	visual.name = "Visual"
	root.add_child(visual)
	var collision: Node3D = Node3D.new()
	collision.name = "Collision"
	root.add_child(collision)
	if live:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = SURFACE
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("stadium_item", ITEM)
		body.set_meta("surface_id", SURFACE)
		body.set_meta("surface_role", LIVE)
		collision.add_child(body)
		for row: Dictionary in solid_specs():
			var shape: BoxShape3D = BoxShape3D.new()
			shape.size = row.size
			shape.margin = 0.0
			var node: CollisionShape3D = CollisionShape3D.new()
			node.name = row.id
			node.position = row.center
			node.shape = shape
			body.add_child(node)
		var carrier: Node3D = Node3D.new()
		carrier.name = "BasinTrap"
		carrier.set_meta("volume_id", TRAP_ID)
		carrier.set_meta("volume", basin_volume())
		carrier.set_meta("pocket", POCKET)
		carrier.set_meta("apertures", trap_apertures())
		carrier.set_meta("body_radius", BODY_RADIUS)
		carrier.set_meta("maximum_reach", MAX_DEFENDER_REACH)
		root.add_child(carrier)
	return root


static func envelope(item: String = ITEM) -> AABB:
	return AABB(Vector3(-4.2, 0, -1.9), Vector3(8.4, 3.8, 3.8)) if item == ITEM else AABB()


static func reservation(item: String = ITEM) -> AABB:
	# 9 m wide, 7 m deep, 4 m high. This is NEVER physical collision.
	return AABB(Vector3(-4.5, 0, -3.5), Vector3(9, 4, 7)) if item == ITEM else AABB()


static func surfaces(item: String = ITEM) -> Array[String]:
	if item == ITEM:
		return [SURFACE]
	return []


static func solid_bounds(id: String) -> AABB:
	if id not in SOLID_IDS:
		return AABB()
	var center: Vector3 = Frozen.PARTS[id][0]
	var size: Vector3 = Frozen.PARTS[id][1]
	return AABB(center - size / 2.0, size)


static func solid_specs() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for id: String in SOLID_IDS:
		rows.append(
			{
				"id": id,
				"bounds": solid_bounds(id),
				"center": Frozen.PARTS[id][0],
				"size": Frozen.PARTS[id][1]
			}
		)
	return rows


static func basin_volume() -> AABB:
	# Derive all six faces from real stones. The lower rock's x extent excludes
	# the two narrow side slots; they are not part of this candidate's admission.
	var front: AABB = solid_bounds("BasinFront")
	var floor: AABB = solid_bounds("BasinFloor")
	var rock: AABB = solid_bounds("RockLower")
	var low: Vector3 = Vector3(rock.position.x, floor.end.y, front.end.z)
	var high: Vector3 = Vector3(rock.end.x, front.end.y, rock.position.z)
	return AABB(low, high - low)


static func trap_polygon() -> PackedVector2Array:
	return PackedVector2Array(
		[
			POCKET.position,
			Vector2(POCKET.end.x, POCKET.position.y),
			POCKET.end,
			Vector2(POCKET.position.x, POCKET.end.y)
		]
	)


static func trap_apertures() -> Array[Dictionary]:
	var volume: AABB = basin_volume()
	return [
		{
			"id": APERTURE_ID,
			"origin": Vector3(0, volume.end.y, 0),
			"inward": Vector3.DOWN,
			"bounds":
			Rect2(
				Vector2(volume.position.x, volume.position.z), Vector2(volume.size.x, volume.size.z)
			)
		}
	]


static func basin_contains_local(point: Vector3, radius: float) -> bool:
	if not _sphere_valid(point, radius):
		return false
	var volume: AABB = basin_volume()
	# Supporting-floor tangency is legal; wall, rock and aperture edge tangency is not.
	return (
		point.y >= volume.position.y + radius - EPS
		and point.y < volume.end.y - radius - EPS
		and point.x > volume.position.x + radius + EPS
		and point.x < volume.end.x - radius - EPS
		and point.z > volume.position.z + radius + EPS
		and point.z < volume.end.z - radius - EPS
	)


static func trap_contains_local(point: Vector3, radius: float) -> bool:
	# Use this stricter predicate ONLY with separately witnessed entry and quiet dwell.
	# A sphere merely below the water, hovering, or close to any rim is not trapped.
	if (
		not basin_contains_local(point, radius)
		or absf(point.y - (basin_volume().position.y + radius)) > SUPPORT_TOLERANCE
	):
		return false
	return (
		point.x > POCKET.position.x + radius + EPS
		and point.x < POCKET.end.x - radius - EPS
		and point.z > POCKET.position.y + radius + EPS
		and point.z < POCKET.end.y - radius - EPS
		and minimum_exterior_reach_distance_local(point, radius) > MAX_DEFENDER_REACH + EPS
	)


static func trap_entry_local(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	if not _sphere_valid(previous, radius) or not _sphere_valid(current, radius):
		return {}
	var volume: AABB = basin_volume()
	if radius * 2.0 >= minf(volume.size.y, minf(volume.size.x, volume.size.z)) - EPS:
		return {}
	var motion: Vector3 = current - previous
	if not motion.is_finite() or motion.y >= -EPS:
		return {}
	# Witness trailing sphere crossing the top plane. A wholly inside initial
	# overlap, a rising ball, rim skim, side crossing or mere water contact cannot arm.
	var entry_y: float = volume.end.y - radius - EPS * 2.0
	if previous.y < volume.end.y - radius or current.y >= entry_y:
		return {}
	var fraction: float = (entry_y - previous.y) / motion.y
	var position: Vector3 = previous.lerp(current, fraction)
	if (
		not is_finite(fraction)
		or fraction < 0.0
		or fraction > 1.0
		or not basin_contains_local(position, radius)
		or not segment_clear_of_solids(previous, position, radius)
	):
		return {}
	return {
		"fraction": fraction, "position": position, "aperture": APERTURE_ID, "volume_id": TRAP_ID
	}


static func segment_clear_of_solids(previous: Vector3, current: Vector3, radius: float) -> bool:
	if not _sphere_valid(previous, radius) or not _sphere_valid(current, radius):
		return false
	var motion: Vector3 = current - previous
	if not motion.is_finite():
		return false
	# Expanded boxes deliberately overestimate rounded sphere/box corners. This is
	# conservative admission only; actual native sphere sweeps decide solid contacts.
	for row: Dictionary in solid_specs():
		if _segment_intersects_box(previous, motion, row.bounds.grow(radius + EPS)):
			return false
	return true


static func minimum_exterior_reach_distance_local(point: Vector3, radius: float) -> float:
	if not _sphere_valid(point, radius):
		return -INF
	var floor: AABB = solid_bounds("BasinFloor")
	if (
		point.x <= floor.position.x
		or point.x >= floor.end.x
		or point.z <= floor.position.z
		or point.z >= floor.end.z
	):
		return -INF
	# The four joined real rim solids close the entire perimeter. Grounded legal
	# feet lie outside its radius-expanded footprint. For an interior point the
	# nearest such foot is on a straight edge; rounded exterior corners are farther.
	# Subtract sphere radius, and ignore height, to give a conservative reach bound.
	var edge_distance: float = minf(
		minf(point.x - floor.position.x, floor.end.x - point.x),
		minf(point.z - floor.position.z, floor.end.z - point.z)
	)
	return edge_distance + BODY_RADIUS - radius


static func defender_foot_legal_local(point: Vector3) -> bool:
	if not point.is_finite() or absf(point.y) > EPS:
		return false
	var floor: AABB = solid_bounds("BasinFloor")
	var nearest: Vector2 = Vector2(
		clampf(point.x, floor.position.x, floor.end.x),
		clampf(point.z, floor.position.z, floor.end.z)
	)
	return Vector2(point.x, point.z).distance_to(nearest) >= BODY_RADIUS - EPS


static func geometry_contract_valid() -> bool:
	var bounds: AABB = AABB()
	var first: bool = true
	for id: String in Frozen.PARTS:
		var center: Vector3 = Frozen.PARTS[id][0]
		var size: Vector3 = Frozen.PARTS[id][1]
		if (
			not center.is_finite()
			or not size.is_finite()
			or size.x <= 0
			or size.y <= 0
			or size.z <= 0
		):
			return false
		var part: AABB = AABB(center - size / 2, size)
		bounds = part if first else bounds.merge(part)
		first = false
	if (
		Frozen.PARTS.size() != 21
		or SOLID_IDS.size() != 13
		or not bounds.position.is_equal_approx(envelope().position)
		or not bounds.size.is_equal_approx(envelope().size)
	):
		return false
	var floor: AABB = solid_bounds("BasinFloor")
	var front: AABB = solid_bounds("BasinFront")
	var back: AABB = solid_bounds("BasinBack")
	var left: AABB = solid_bounds("BasinLeft")
	var right: AABB = solid_bounds("BasinRight")
	# An actual continuous perimeter, not an obstacle reservation, excludes feet.
	if (
		not is_equal_approx(front.position.x, floor.position.x)
		or not is_equal_approx(front.end.x, floor.end.x)
		or not is_equal_approx(back.position.x, floor.position.x)
		or not is_equal_approx(back.end.x, floor.end.x)
		or not is_equal_approx(front.position.z, floor.position.z)
		or not is_equal_approx(back.end.z, floor.end.z)
		or not is_equal_approx(left.position.x, floor.position.x)
		or not is_equal_approx(right.end.x, floor.end.x)
		or not is_equal_approx(left.position.z, front.end.z)
		or not is_equal_approx(right.position.z, front.end.z)
		or not is_equal_approx(left.end.z, back.position.z)
		or not is_equal_approx(right.end.z, back.position.z)
	):
		return false
	for wall: AABB in [front, back, left, right]:
		if wall.position.y > floor.end.y or wall.end.y < BODY_RADIUS * 2.0:
			return false
	var volume: AABB = basin_volume()
	if (
		not volume.size.is_equal_approx(Vector3(7.6, 0.5, 1.0))
		or not volume.position.is_equal_approx(Vector3(-3.8, 0.2, -1.6))
	):
		return false
	for row: Dictionary in solid_specs():
		var overlap: AABB = volume.intersection(row.bounds)
		if overlap.size.x > EPS and overlap.size.y > EPS and overlap.size.z > EPS:
			return false
	for x: float in [POCKET.position.x, POCKET.end.x]:
		for z: float in [POCKET.position.y, POCKET.end.y]:
			if (
				x <= volume.position.x
				or x >= volume.end.x
				or z <= volume.position.z
				or z >= volume.end.z
				or (
					minimum_exterior_reach_distance_local(Vector3(x, volume.position.y, z), EPS * 2)
					<= MAX_DEFENDER_REACH
				)
			):
				return false
	return true


static func valid(root: Node3D, live: bool = true) -> bool:
	if (
		not is_instance_valid(root)
		or root.get_class() != "Node3D"
		or not _clean(root)
		or not root.transform.origin.is_finite()
		or not root.basis.is_finite()
		or not root.basis.is_equal_approx(root.basis.orthonormalized())
		or not is_equal_approx(root.basis.determinant(), 1.0)
		or not root.basis.y.is_equal_approx(Vector3.UP)
		or root.get_child_count() != (3 if live else 2)
		or not geometry_contract_valid()
	):
		return false
	for row: Array in [
		["stadium_item", ITEM],
		["geometry_version", VERSION],
		["waterfall_live_version", VERSION],
		["live_furnishing", live],
		["scenery_only", not live],
		["working_geometry_only", true],
		["night_qualified", false],
		["obstacle_units", LIVE_UNITS if live else 0],
		["envelope", envelope()],
		["reservation", reservation()]
	]:
		if not _meta(root, row[0], row[1]):
			return false
	var visual: Node3D = root.get_node_or_null("Visual") as Node3D
	var collision: Node3D = root.get_node_or_null("Collision") as Node3D
	if (
		visual == null
		or visual.transform != Transform3D.IDENTITY
		or not Frozen.valid(visual)
		or collision == null
		or collision.get_class() != "Node3D"
		or not _clean(collision)
		or collision.transform != Transform3D.IDENTITY
		or collision.get_child_count() != (1 if live else 0)
	):
		return false
	if not live:
		return true
	var body: StaticBody3D = collision.get_node_or_null(SURFACE) as StaticBody3D
	if (
		body == null
		or body.get_class() != "StaticBody3D"
		or not _clean(body)
		or body.transform != Transform3D.IDENTITY
		or body.collision_layer != 1
		or body.collision_mask != 0
		or body.get_child_count() != SOLID_IDS.size()
		or body.physics_material_override != null
		or body.constant_linear_velocity != Vector3.ZERO
		or body.constant_angular_velocity != Vector3.ZERO
		or not _meta(body, "stadium_item", ITEM)
		or not _meta(body, "surface_id", SURFACE)
		or not _meta(body, "surface_role", LIVE)
		or body.get_shape_owners().size() != SOLID_IDS.size()
	):
		return false
	for row: Dictionary in solid_specs():
		var node: CollisionShape3D = body.get_node_or_null(row.id) as CollisionShape3D
		if (
			node == null
			or node.get_class() != "CollisionShape3D"
			or not _clean(node)
			or node.get_child_count() != 0
			or node.transform != Transform3D(Basis.IDENTITY, row.center)
			or node.disabled
			or not node.shape is BoxShape3D
			or node.shape.get_script() != null
			or node.shape.size != row.size
			or node.shape.margin != 0.0
		):
			return false
		var owner: int = body.shape_find_owner(node.get_index())
		if (
			body.shape_owner_get_owner(owner) != node
			or body.is_shape_owner_disabled(owner)
			or body.shape_owner_get_shape_count(owner) != 1
			or body.shape_owner_get_shape(owner, 0) != node.shape
			or body.shape_owner_get_transform(owner) != node.transform
		):
			return false
	var carrier: Node3D = root.get_node_or_null("BasinTrap") as Node3D
	return (
		carrier != null
		and carrier.get_class() == "Node3D"
		and _clean(carrier)
		and carrier.get_child_count() == 0
		and carrier.transform == Transform3D.IDENTITY
		and _meta(carrier, "volume_id", TRAP_ID)
		and _meta(carrier, "volume", basin_volume())
		and _meta(carrier, "pocket", POCKET)
		and _meta(carrier, "apertures", trap_apertures())
		and _meta(carrier, "body_radius", BODY_RADIUS)
		and _meta(carrier, "maximum_reach", MAX_DEFENDER_REACH)
	)


static func _sphere_valid(point: Vector3, radius: float) -> bool:
	return point.is_finite() and is_finite(radius) and radius > EPS


static func _segment_intersects_box(start: Vector3, motion: Vector3, box: AABB) -> bool:
	var low: float = 0.0
	var high: float = 1.0
	for axis in range(3):
		if absf(motion[axis]) < EPS:
			if start[axis] < box.position[axis] or start[axis] > box.end[axis]:
				return false
		else:
			var a: float = (box.position[axis] - start[axis]) / motion[axis]
			var b: float = (box.end[axis] - start[axis]) / motion[axis]
			low = maxf(low, minf(a, b))
			high = minf(high, maxf(a, b))
			if low > high:
				return false
	return true


static func _meta(node: Node, key: String, expected: Variant) -> bool:
	return (
		node.has_meta(key)
		and typeof(node.get_meta(key)) == typeof(expected)
		and node.get_meta(key) == expected
	)


static func _clean(node: Node3D) -> bool:
	return (
		node.get_script() == null
		and node.visible
		and not node.top_level
		and not node.is_queued_for_deletion()
		and node.process_mode == Node.PROCESS_MODE_INHERIT
	)

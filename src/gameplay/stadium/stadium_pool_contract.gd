class_name StadiumPoolContract
extends RefCounted
## DB1 versioned geometry candidate. Approved BS outcomes are future adapter requirements only.

const VERSION: int = 1
const ID: String = "ST006-ANNULAR-POOL-DB1-v1"
const OUTER_RADIUS: float = 2.10
const INNER_RADIUS: float = 1.95
const WALL_HEIGHT: float = 1.20
const WATER_HEIGHT: float = 1.05
const LADDER: AABB = AABB(Vector3(2.10, 0, -0.35), Vector3(0.35, 1.45, 0.70))
const VISUAL_RADIUS: float = 2.50
const VISUAL_HEIGHT: float = 1.50
const RESERVATION_RADIUS: float = 3.00
const SEGMENTS: int = 128
const WATER_VOLUME_ID: String = "ST006_WATER_VOLUME_v1"
const LIVE: String = "LIVE_GEOMETRY_CANDIDATE"
const SCENERY: String = "SCENERY"
const SURFACES: Array[String] = ["POOL_OUTER_WALL", "POOL_INNER_WALL", "POOL_RIM", "POOL_BOTTOM"]


static func placement() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(12, 0, 18))


static func geometry(role: String) -> Dictionary:
	if role not in [LIVE, SCENERY]:
		return {}
	return {
		"id": ID,
		"version": VERSION,
		"item": "ST-006",
		"role": role,
		"outer_radius": OUTER_RADIUS,
		"inner_radius": INNER_RADIUS,
		"wall_height": WALL_HEIGHT,
		"water_height": WATER_HEIGHT,
		"ladder": LADDER,
		"visual_radius": VISUAL_RADIUS,
		"visual_height": VISUAL_HEIGHT,
		"segments": SEGMENTS,
		"water_volume": WATER_VOLUME_ID if role == LIVE else "",
		"water_award_active": false,
		"runtime_adapter": "NOT_IMPLEMENTED",
		"authority": "DB1_PROPOSED_AUTHORED_CANDIDATE",
		"source_sha256": StadiumPoolPartyAssetIntegrity.source_sha256()
	}


static func live_site() -> Dictionary:
	return {
		"id": "POOL-OL-R-DB1-v1",
		"site": "OL-R",
		"placement": placement(),
		"capacity_units_future_adapter": 4,
		"reservation_radius": RESERVATION_RADIUS,
		"route_envelope_radius_future_adapter": VISUAL_RADIUS,
		"future_fair_entry": "GROUND_RULE_DOUBLE",
		"future_foul_entry": "FOUL",
		"same_time_priority": ["solid", "water"],
		"climbable": false,
		"catch_after_water": false,
		"physics_qualified": false,
		"geometry": geometry(LIVE)
	}


static func valid_binding(root: Node3D, role: String, pose: Transform3D, record: Variant) -> bool:
	if (
		root == null
		or not record is Dictionary
		or record.is_empty()
		or String(record.get("source_sha256", "")).length() != 64
		or record != geometry(role)
		or not StadiumPoolPartyAssetIntegrity.rigid(pose)
	):
		return false
	# Live dependency has one proposed pose. Scenery can be rigidly placed, never scaled.
	if role == LIVE and pose != placement():
		return false
	var reference: Node3D = StadiumPoolModels.create(role)
	if reference == null:
		return false
	reference.transform = pose
	var valid: bool = StadiumPoolPartyAssetIntegrity.same_tree(root, reference)
	reference.free()
	return valid


static func point(radius: float, y: float, index: int) -> Vector3:
	# Modulo closes the mesh exactly; never use sin(TAU) for the final seam.
	var angle: float = TAU * posmod(index, SEGMENTS) / float(SEGMENTS)
	return Vector3(radius * cos(angle), y, radius * sin(angle))


static func faces(surface: String) -> PackedVector3Array:
	var result: PackedVector3Array = []
	if surface not in SURFACES:
		return result
	for index: int in range(SEGMENTS):
		var outer_low: Vector3 = point(OUTER_RADIUS, 0, index)
		var outer_next: Vector3 = point(OUTER_RADIUS, 0, index + 1)
		var inner_low: Vector3 = point(INNER_RADIUS, 0, index)
		var inner_next: Vector3 = point(INNER_RADIUS, 0, index + 1)
		var up: Vector3 = Vector3.UP * WALL_HEIGHT
		match surface:
			"POOL_OUTER_WALL":
				_quad(result, outer_low, outer_low + up, outer_next + up, outer_next)
			"POOL_INNER_WALL":
				_quad(result, inner_next, inner_next + up, inner_low + up, inner_low)
			"POOL_RIM":
				_quad(result, inner_low + up, inner_next + up, outer_next + up, outer_low + up)
			"POOL_BOTTOM":
				_quad(result, inner_next, inner_low, outer_low, outer_next)
	return result


static func _quad(
	faces_value: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3
) -> void:
	# Godot front-face is clockwise. Outward normals use the negative cross product.
	faces_value.append_array(PackedVector3Array([a, c, b, a, d, c]))

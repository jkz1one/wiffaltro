class_name StadiumHillsideProbeActor
extends CharacterBody3D
## Actual engine-grounded private actor probe. No ordinary fielder, reach, AI or venue admission.

const RADIUS: float = 0.28
const HEIGHT: float = 1.70
const GRAVITY: float = 9.80665
const PENETRATION_TOLERANCE: float = 0.002
var profile: String = "hill"
var speed: float = 4.6
var command: Vector2 = Vector2.ZERO
var active: bool = false
var last_error: String = ""
var elapsed: float = 0.0
var _body_shape: CapsuleShape3D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_constant_speed = true
	floor_stop_on_slope = true
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(35)
	safe_margin = 0.001
	_body_shape = CapsuleShape3D.new()
	_body_shape.radius = RADIUS
	_body_shape.height = HEIGHT
	_body_shape.margin = 0
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = _body_shape
	collider.position.y = HEIGHT / 2
	add_child(collider)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	mesh.mesh = capsule
	mesh.position = collider.position
	add_child(mesh)


func place(point: Vector2, requested_profile: String = "hill") -> bool:
	var foot: Vector3 = StadiumHillsideTerrain.point(point.x, point.y, requested_profile)
	var spawn: Vector3 = foot + Vector3.UP * 0.05
	if not foot.is_finite() or not _support_matches(foot, requested_profile) \
		or not _inside_body_bounds(foot) or not _clear(spawn, 0, requested_profile):
		last_error = "Missing physical support, body clearance or valid spawn."
		return false
	profile = requested_profile
	global_position = spawn
	velocity = Vector3.ZERO
	command = Vector2.ZERO
	elapsed = 0
	last_error = ""
	active = true
	return true


func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_finite(delta) or delta <= 0 or not is_finite(speed) or speed < 0 \
		or not command.is_finite():
		_stop("Invalid time, speed or direction.")
		return
	var foot: Vector3 = StadiumHillsideTerrain.point(global_position.x, global_position.z, profile)
	if not _support_matches(foot, profile) or not _clear(global_position, PENETRATION_TOLERANCE):
		_stop("Physical support removed or body obstructed.")
		return
	var heading: Vector2 = command.normalized()
	var proposal: Dictionary = StadiumHillsideLocomotion.step(foot, heading, speed * delta, profile)
	if proposal.is_empty() or not _inside_body_bounds(proposal.position):
		_stop("Finite terrain body margin reached.")
		return
	velocity.x = heading.x * speed
	velocity.z = heading.y * speed
	velocity.y = 0 if is_on_floor() else velocity.y - GRAVITY * delta
	# Grounded constant-speed motion is provided by Godot's actual contact solver.
	# The arc helper defines/probes the budget independently; it does not teleport the actor.
	move_and_slide()
	apply_floor_snap()
	elapsed += delta


func body_clear() -> bool:
	return _clear(global_position, PENETRATION_TOLERANCE)


func _stop(message: String) -> void:
	last_error = message
	active = false
	velocity = Vector3.ZERO


func _support_matches(point: Vector3, expected_profile: String) -> bool:
	if not is_inside_tree() or not point.is_finite():
		return false
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 3, point - Vector3.UP * 3,
		StadiumHillsideTerrainModels.QUERY_LAYER)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider.get_meta("ball_surface", &"") \
		== StadiumHillsideTerrainModels.SURFACE \
		and hit.collider.get_meta("terrain_profile", "") == expected_profile \
		and hit.position.distance_to(point) <= 0.0002


func _clear(at: Vector3, tolerance: float, requested_profile: String = "") -> bool:
	if _body_shape == null or not is_inside_tree() or not at.is_finite():
		return false
	var ground: float = StadiumHillsideTerrain.support_height(Vector2(at.x, at.z),
		profile if requested_profile.is_empty() else requested_profile)
	if not is_finite(ground) or at.y < ground - tolerance:
		return false
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = RADIUS - tolerance
	shape.height = HEIGHT - tolerance * 2
	shape.margin = 0
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0
	query.collision_mask = 1
	query.exclude = [get_rid()]
	query.transform.origin = at + Vector3.UP * (HEIGHT / 2)
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _inside_body_bounds(point: Vector3) -> bool:
	var interior: Rect2 = StadiumHillsideTerrain.BOUNDS.grow(-RADIUS)
	return point.x >= interior.position.x and point.x <= interior.end.x \
		and point.z >= interior.position.y and point.z <= interior.end.y

class_name BallInPlayCamera
extends RefCounted

# One coverage rig per player side. Open the field, then pan within that view.
# No launch-selected orbit, lateral obstacle detour, or simultaneous lens zoom.
const MAX_SPEED: float = 24.0
const MAX_TURN_SPEED: float = 1.35

var _defense: bool = false
var _pending: bool = true
var _coverage: float = 0.0
var _age: float = 0.0
var _entry: Vector3
var _focus: Vector3
var _previous_ball: Vector3
var _height: float = 0.0
var _depth: float = 0.0
var _entry_fov: float = 70.0


func prepare(defense: bool, ball: Vector3, launch: Vector3) -> void:
	_defense = defense
	_pending = true
	# Hard contact needs reaction space; soft contact can remain close.
	_coverage = smoothstep(8.0, 27.0, Vector2(launch.x, launch.z).length())
	_age = 0.0
	_previous_ball = ball
	_height = ball.y
	_depth = ball.z


func update(
	camera: Camera3D, delta: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	if delta <= 0.0:
		return
	if _pending:
		_entry = camera.global_position
		_entry_fov = camera.fov
		_focus = _entry - camera.global_basis.z * _entry.distance_to(ball)
		_pending = false
	var steps: int = maxi(1, int(ceil(delta * 120.0)))
	var dt: float = delta / steps
	for step in range(steps):
		var at: Vector3 = _previous_ball.lerp(ball, float(step + 1) / steps)
		_advance(camera, dt, at, visibility)
	_previous_ball = ball
	visibility.update_occluders(camera.global_position, ball, delta)


func _advance(
	camera: Camera3D, dt: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	_age += dt
	# Coverage can open further, but never pumps back inward on the bounce/descent.
	_height = maxf(_height, ball.y)
	_depth = maxf(_depth, ball.z)
	var position: Vector3
	if _defense:
		position = Vector3(
			-4.0 * _coverage,
			maxf(lerpf(5.0, 16.0, _coverage), _height + lerpf(3.5, 8.0, _coverage)),
			maxf(
				lerpf(19.0, visibility.field_wall_z - 0.1, _coverage),
				minf(visibility.field_wall_z - 0.1, _depth + 0.5)
			)
		)
	else:
		position = Vector3(0, maxf(lerpf(6.0, 13.0, _coverage), _height + 7.0), -9.0)
	var open_weight: float = smoothstep(0.0, 0.85, _age)
	position = _entry.lerp(position, open_weight)
	var step: Vector3 = (position - camera.global_position) * (1.0 - exp(-7.0 * dt))
	camera.global_position += step.limit_length(MAX_SPEED * dt)
	# Keep ground reference in the composition. Only pan as play leaves the
	# central field; do not attach the lens directly to every bounce of the ball.
	var anchor: Vector3 = Vector3(0, ball.y * 0.45, lerpf(6.0, 13.0, _coverage))
	var focus: Vector3 = anchor.lerp(ball, 0.65)
	_focus = _focus.lerp(focus, 1.0 - exp(-5.0 * dt))
	var direction: Vector3 = (_focus - camera.global_position).normalized()
	var target: Quaternion = Basis.looking_at(direction, Vector3.UP).get_rotation_quaternion()
	var current: Quaternion = camera.global_basis.get_rotation_quaternion()
	var angle: float = current.angle_to(target)
	if angle > 0.0001:
		var weight: float = minf(1.0 - exp(-7.0 * dt), MAX_TURN_SPEED * dt / angle)
		camera.global_basis = Basis(current.slerp(target, weight))
	camera.fov = _entry_fov

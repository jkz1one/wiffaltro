class_name BallInPlayCamera
extends RefCounted

# Coverage is selected from observable flight, then approached without a contact cut.
const MAX_SPEED: float = 32.0
const MAX_ACCELERATION: float = 95.0
const MAX_TURN_SPEED: float = 1.65
const MAX_TURN_ACCELERATION: float = 4.5

var _defense: bool = false
var _pending: bool = true
var _side: float = -1.0
var _air_coverage: float = 0.0
var _ground_coverage: float = 0.0
var _carry: float = 0.0
var _age: float = 0.0
var _velocity: Vector3 = Vector3.ZERO
var _turn_speed: float = 0.0
var _entry: Vector3
var _focus: Vector3
var _previous_ball: Vector3
var _height: float = 0.0
var _entry_fov: float = 70.0
var _clearance_offset: float = 0.0


func prepare(defense: bool, ball: Vector3, launch: Vector3) -> void:
	_defense = defense
	_pending = true
	_side = signf(launch.x) if absf(launch.x) > 1.0 else -1.0
	# Ground coverage stays outside the travel corridor. Air coverage opens
	# across that corridor to show its depth without chasing beneath the ball.
	if launch.y > 3.0 and absf(launch.x) > 1.0:
		_side = -_side
	var air_time: float = (launch.y + sqrt(launch.y * launch.y + 19.62 * maxf(0, ball.y))) / 9.81
	# Conservative drag allowance. This is a coverage estimate, never a scoring forecast.
	var horizontal_speed: float = Vector2(launch.x, launch.z).length()
	_carry = horizontal_speed * air_time * 0.65
	_ground_coverage = smoothstep(9.0, 28.0, horizontal_speed)
	_air_coverage = smoothstep(10.0, 28.0, _carry) * smoothstep(3.0, 11.0, launch.y)
	_age = 0.0
	_velocity = Vector3.ZERO
	_turn_speed = 0.0
	_previous_ball = ball
	_height = 0.0
	_clearance_offset = 0.0


func update(
	camera: Camera3D, delta: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	if delta <= 0.0:
		return
	if _pending:
		_entry = camera.global_position
		_entry_fov = camera.fov
		_focus = ball
		_pending = false
	var steps: int = maxi(1, int(ceil(delta * 120.0)))
	var dt: float = delta / steps
	for step in range(steps):
		var at: Vector3 = _previous_ball.lerp(ball, float(step + 1) / steps)
		_advance(camera, dt, at, visibility)
	_previous_ball = ball


func _advance(
	camera: Camera3D, dt: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	_age += dt
	_height = maxf(_height, ball.y)
	_focus = _focus.lerp(ball, 1.0 - exp(-12.0 * dt))
	var position: Vector3
	if _defense:
		# Rollers keep a view toward home even beyond Double. Airborne carry earns
		# a larger lateral move; this passes through a side view instead of reversing.
		_clearance_offset = maxf(_clearance_offset, visibility.lateral_clearance(ball))
		var ground_width: float = lerpf(2.0, 12.0, _ground_coverage)
		var ground_height: float = maxf(
			lerpf(3.5, 7.5, _ground_coverage) + _height * 0.4, _height + 3.0
		)
		var ground_depth: float = maxf(lerpf(17.5, 20.0, _ground_coverage), ball.z + 13.0)
		if _clearance_offset > 0.0:
			ground_width = 12.0 + _clearance_offset
			ground_height = maxf(ground_height, 9.0)
			ground_depth = ball.z + 6.0
		var ground: Vector3 = Vector3(
			_side * ground_width + ball.x * 0.35,
			ground_height,
			minf(visibility.field_wall_z - 0.05, ground_depth)
		)
		var aerial: Vector3 = Vector3(
			_side * 23.0 + ball.x * 0.25,
			maxf(17.0, _height + 9.0),
			lerpf(23.0, 7.0 + ball.z * 0.15, smoothstep(0.4, 1.8, _age))
		)
		position = ground.lerp(aerial, _air_coverage)
	else:
		position = Vector3(_side * 5.0 + ball.x * 0.20, maxf(8.0, _height + 5.0), -8.0)
	var entry_weight: float = smoothstep(0.0, 0.65, _age)
	position = _entry.lerp(position, entry_weight)
	position = visibility.clear_position(position, ball)
	var acceleration: Vector3 = (
		((position - camera.global_position) * 64.0 - _velocity * 16.0)
		. limit_length(MAX_ACCELERATION)
	)
	_velocity = (_velocity + acceleration * dt).limit_length(MAX_SPEED)
	camera.global_position += _velocity * dt
	var direction: Vector3 = (_focus - camera.global_position).normalized()
	# Lateral coverage keeps the usual horizon meaningful, including high popups.
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.995 else camera.global_basis.y
	var target: Quaternion = Basis.looking_at(direction, up).get_rotation_quaternion()
	var current: Quaternion = camera.global_basis.get_rotation_quaternion()
	var angle: float = current.angle_to(target)
	var desired_speed: float = minf(MAX_TURN_SPEED, sqrt(2.0 * MAX_TURN_ACCELERATION * angle))
	_turn_speed = move_toward(_turn_speed, desired_speed, MAX_TURN_ACCELERATION * dt)
	if angle > 0.0001:
		camera.global_basis = Basis(current.slerp(target, minf(1.0, _turn_speed * dt / angle)))
	var target_fov: float = (
		_entry_fov + lerpf(2.0, 8.0, maxf(_ground_coverage, _air_coverage)) * entry_weight
	)
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-3.0 * dt))

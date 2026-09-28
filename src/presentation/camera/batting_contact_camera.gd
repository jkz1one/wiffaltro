class_name BattingContactCamera
extends RefCounted

# Offensive framing retains the plate-side view, with coverage earned by the play.
var context: FieldCameraContext = FieldCameraContext.new()
var defenders: PackedVector3Array = PackedVector3Array()
var grounded: bool = false
var shot_name: String = "local"
var _pending: bool = true
var _previous_ball: Vector3
var _velocity: Vector3
var _entry: Transform3D
var _entry_fov: float
var _focus: Vector3
var _motion: Vector3 = Vector3.ZERO
var _opening: float = 0.0
var _distance: float = 0.0
var _lens: float = 0.0


func prepare(ball: Vector3, launch: Vector3 = Vector3.ZERO) -> void:
	_pending = true
	_previous_ball = ball
	_velocity = launch
	_motion = Vector3.ZERO
	_opening = 0.0
	grounded = false
	defenders.clear()
	shot_name = "local"


func update(
	camera: Camera3D, delta: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	if delta <= 0.0:
		return
	if _pending:
		_entry = camera.global_transform
		_distance = _entry.origin.distance_to(_previous_ball)
		_focus = _entry.origin - _entry.basis.z * _distance
		_entry_fov = camera.fov
		_lens = camera.fov
		_pending = false
	_velocity = _velocity.lerp((ball - _previous_ball) / delta, 1.0 - exp(-12.0 * delta))
	var steps: int = maxi(1, int(ceil(delta * 120.0)))
	for step in range(steps):
		_advance(camera, delta / steps, _previous_ball.lerp(ball, float(step + 1) / steps))
	_previous_ball = ball
	visibility.update_occluders(camera.global_position, ball, delta)


func _advance(camera: Camera3D, dt: float, ball: Vector3) -> void:
	var up: Vector3 = context.up()
	var ground: Vector3 = context.ground_point(ball)
	var height: float = maxf(0.0, (ball - ground).dot(up))
	var forecast: Vector3 = ball + _velocity * 0.30 - up * 4.905 * 0.09
	var floor_point: Vector3 = context.ground_point(forecast)
	if grounded or (forecast - floor_point).dot(up) < 0.0:
		forecast = floor_point + up * 0.08
	var points: PackedVector3Array = CameraGroupFraming.play_subjects(
		context, ball, forecast, defenders, _velocity.length()
	)
	var local: Vector3 = context.frame().affine_inverse() * forecast
	var depth: float = context.play_bounds().size.z
	var need: float = maxf(
		smoothstep(depth * 0.35, depth * 0.80, local.z), smoothstep(2.0, 8.0, height)
	)
	if _opening < 0.02 and need < 0.02 and CameraGroupFraming.fits(camera, points, 0.88):
		return
	_opening = lerpf(_opening, maxf(_opening, need), 1.0 - exp(-5.0 * dt))
	shot_name = "flight" if height > 3.0 else "ground"
	var bounds: AABB = AABB(points[0], Vector3.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	_focus = _focus.lerp(bounds.get_center(), 1.0 - exp(-6.0 * dt))
	var offset: Vector3 = (context.frame().basis * Vector3(0, 0.85, -1)).normalized()
	var desired: Quaternion = Basis.looking_at(-offset, up).get_rotation_quaternion()
	var target: Quaternion = _entry.basis.get_rotation_quaternion().slerp(desired, _opening)
	var current: Quaternion = camera.global_basis.get_rotation_quaternion()
	var angle: float = current.angle_to(target)
	var basis: Basis = Basis(current.slerp(target, minf(1, 1.05 * dt / maxf(angle, 0.00001))))
	var fit: float = CameraGroupFraming.fit_distance(camera, basis, _focus, points, _entry_fov)
	var distance: float = maxf(lerpf(_distance, context.depth_m() * 0.55, _opening), fit)
	var position: Vector3 = _focus + basis.z * distance
	position += up * maxf(0, 1.5 - (position - context.ground_point(position)).dot(up))
	var speed: float = maxf(24.0, context.depth_m() * 1.2)
	var desired_motion: Vector3 = ((position - camera.global_position) * 8.0).limit_length(speed)
	_motion = _motion.move_toward(desired_motion, speed * 3.0 * dt)
	camera.global_position += _motion * dt
	camera.global_basis = basis
	_lens = maxf(_lens, minf(_entry_fov + 12.0, CameraGroupFraming.required_fov(camera, points)))
	camera.fov = move_toward(camera.fov, _lens, 18.0 * dt)

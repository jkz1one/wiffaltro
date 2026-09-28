class_name BallInPlayCamera
extends RefCounted

# Defensive shot selection is separate from the perspective group fit and motion.
# No camera position depends on a venue ID, scoring line, or named scenery node.
var context: FieldCameraContext = FieldCameraContext.new()
var shot_name: String = "local"
var debug_subjects: PackedVector3Array = PackedVector3Array()
var defenders: PackedVector3Array = PackedVector3Array()
var grounded: bool = false
var _pending: bool = true
var _previous_ball: Vector3
var _velocity: Vector3
var _motion: Vector3 = Vector3.ZERO
var _entry: Transform3D
var _focus: Vector3
var _entry_distance: float
var _entry_fov: float
var _lens: float
var _opening: float = 0.0
var _side: float = -1.0
var _deep: bool = false
var _popup: bool = false


func prepare(ball: Vector3, launch: Vector3) -> void:
	_pending = true
	_previous_ball = ball
	_velocity = launch
	_motion = Vector3.ZERO
	_opening = 0.0
	grounded = false
	defenders.clear()
	shot_name = "local"
	var local: Vector3 = context.frame().basis.inverse() * launch
	_side = -signf(local.x) if absf(local.x) > 1.0 else -1.0
	var air_time: float = (
		(
			local.y
			+ sqrt(
				(
					local.y * local.y
					+ 19.62 * maxf(0, (ball - context.ground_point(ball)).dot(context.up()))
				)
			)
		)
		/ 9.81
	)
	var horizontal: float = Vector2(local.x, local.z).length()
	# Conservative carry estimate for shot choice only, not scoring or AI knowledge.
	_deep = (
		local.y > 4.0
		and horizontal > absf(local.y) * 0.5
		and horizontal * air_time * 0.55 > context.depth_m() * 0.6
	)
	_popup = not _deep and local.y > horizontal * 0.9 and local.y > 4.0


func update(
	camera: Camera3D, delta: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	if delta <= 0.0:
		return
	if _pending:
		_entry = camera.global_transform
		_entry_distance = _entry.origin.distance_to(_previous_ball)
		_focus = _entry.origin - _entry.basis.z * _entry_distance
		_entry_fov = camera.fov
		_lens = camera.fov
		_pending = false
	var observed: Vector3 = (ball - _previous_ball) / delta
	_velocity = _velocity.lerp(observed, 1.0 - exp(-12.0 * delta))
	var steps: int = maxi(1, int(ceil(delta * 120.0)))
	for step in range(steps):
		_advance(camera, delta / steps, _previous_ball.lerp(ball, float(step + 1) / steps))
	_previous_ball = ball
	visibility.update_occluders(camera.global_position, ball, delta)


func _advance(camera: Camera3D, dt: float, ball: Vector3) -> void:
	var up: Vector3 = context.up()
	var height: float = maxf(0.0, (ball - context.ground_point(ball)).dot(up))
	var horizon: float = 0.45 if _deep else 0.28
	var forecast: Vector3 = ball + _velocity * horizon - up * 4.905 * horizon * horizon
	var floor_point: Vector3 = context.ground_point(forecast)
	if grounded or (forecast - floor_point).dot(up) < 0.0:
		forecast = floor_point + up * 0.08
	debug_subjects = CameraGroupFraming.play_subjects(
		context, ball, forecast, defenders, _velocity.length()
	)
	var inverse: Transform3D = context.frame().affine_inverse()
	var entry_z: float = (inverse * _entry.origin).z
	var future_z: float = (inverse * forecast).z
	var need: float = smoothstep(entry_z * 0.3, entry_z * 0.9, future_z)
	need = maxf(need, smoothstep(1.5, 6.0, height))
	if _deep or _popup:
		need = 1.0
	# A settled frame has a dead zone. Soft contact does not schedule a flyby.
	if _opening < 0.02 and need < 0.02 and CameraGroupFraming.fits(camera, debug_subjects, 0.72):
		return
	_opening = lerpf(_opening, maxf(_opening, need), 1.0 - exp(-5.0 * dt))
	shot_name = "flight" if _deep else ("popup" if _popup else "ground")
	var bounds: AABB = AABB(debug_subjects[0], Vector3.ZERO)
	for point in debug_subjects:
		bounds = bounds.expand(point)
	var center: Vector3 = bounds.get_center()
	_focus = _focus.lerp(center, 1.0 - exp(-6.0 * dt))
	var offset: Vector3 = (
		Vector3(_side * 0.70 if _deep else 0.0, 1.05 if _deep or _popup else 0.65, 1.0).normalized()
	)
	var desired_basis: Basis = Basis.looking_at(-(context.frame().basis * offset), up)
	var entry_q: Quaternion = _entry.basis.get_rotation_quaternion()
	var target_q: Quaternion = entry_q.slerp(desired_basis.get_rotation_quaternion(), _opening)
	var current_q: Quaternion = camera.global_basis.get_rotation_quaternion()
	var angle: float = current_q.angle_to(target_q)
	var basis: Basis = Basis(current_q.slerp(target_q, minf(1.0, 1.05 * dt / maxf(angle, 0.00001))))
	var distance: float = maxf(
		_entry_distance * lerpf(1.0, 0.55, _opening),
		CameraGroupFraming.fit_distance(camera, basis, _focus, debug_subjects, _entry_fov)
	)
	var position: Vector3 = _focus + basis.z * distance
	# Terrain clearance uses the provider at the proposed camera point, not world y=0.
	var ground: Vector3 = context.ground_point(position)
	position += up * maxf(0.0, 1.5 - (position - ground).dot(up))
	var speed: float = maxf(24.0, context.depth_m() * 1.2)
	var desired_motion: Vector3 = ((position - camera.global_position) * 8.0).limit_length(speed)
	_motion = _motion.move_toward(desired_motion, speed * 3.0 * dt)
	camera.global_position += _motion * dt
	camera.global_basis = basis
	# Lens widening is a bounded secondary correction, retained through descent.
	_lens = maxf(
		_lens, minf(_entry_fov + 12.0, CameraGroupFraming.required_fov(camera, debug_subjects))
	)
	camera.fov = move_toward(camera.fov, _lens, 18.0 * dt)

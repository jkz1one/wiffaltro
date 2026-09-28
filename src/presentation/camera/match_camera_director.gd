class_name MatchCameraDirector
extends RefCounted

enum Shot {
	BATTING,
	PITCHING,
	SIDE,
	BALL_IN_PLAY,
	FIELD_SETUP,
	PITCHING_STAFF,
	ESTABLISHING,
	FOUL_SIDE,
	OUTFIELD,
}

enum PresentationMotion {
	STILL,
	ZOOM_IN,
	ZOOM_OUT,
	PAN_LEFT,
	PAN_RIGHT,
	TILT_UP,
	TILT_DOWN,
}

const TRANSITION_SPEED: float = 7.5

var field_context: FieldCameraContext = FieldCameraContext.new()
var shot: Shot = Shot.BATTING
var tracking_visibility: BallTrackingVisibility = BallTrackingVisibility.new()
var _field_focus: Vector3 = Vector3(0.0, 2.2, 10.0)
var _batter_side: float = 1.0
var _presentation_motion: PresentationMotion = PresentationMotion.STILL
var _presentation_progress: float = 0.0
var _presentation_transition_speed: float = TRANSITION_SPEED
var _pitch_focus: Vector3 = Vector3(0, 1.05, 0)
var _live_coverage: BallInPlayCamera = BallInPlayCamera.new()
var _batting_coverage: BattingContactCamera = BattingContactCamera.new()
var _defense_ball_view: bool = false
var _standard_fov: float = 0.0
var _tracking_height: float = 18.0
var _shot_before_inspection: int = -1


func set_shot(next_shot: Shot) -> void:
	if next_shot != Shot.BALL_IN_PLAY:
		tracking_visibility.restore_occluders()
	shot = next_shot
	if _shot_before_inspection >= 0:
		# Closing a setup panel during inspection changes the view to restore.
		_shot_before_inspection = int(next_shot)


func cycle_paused_view() -> void:
	if _shot_before_inspection < 0:
		_shot_before_inspection = int(shot)
	shot = ((int(shot) + 1) % Shot.size()) as Shot


func restore_after_pause() -> void:
	if _shot_before_inspection < 0:
		return
	shot = _shot_before_inspection as Shot
	_shot_before_inspection = -1


func set_batter_handedness(is_left_handed: bool) -> void:
	# Match the camera to the batter's box/shoulder side: left-handed Batters
	# occupy -X (screen right), while right-handed Batters occupy +X (screen left).
	_batter_side = -1.0 if is_left_handed else 1.0


func configure_field(field: FieldDefinition, geometry: Node3D, mound: Vector3) -> void:
	field_context.configure(field, geometry, mound)
	_live_coverage.context = field_context
	tracking_visibility.configure(geometry)


func set_fielding_subjects(positions: PackedVector3Array, has_grounded: bool) -> void:
	_live_coverage.defenders = positions
	_live_coverage.grounded = has_grounded


func prepare_ball_in_play(
	defense_view: bool, ball_position: Vector3, launch_velocity: Vector3 = Vector3.ZERO
) -> void:
	_defense_ball_view = defense_view
	if defense_view:
		_live_coverage.prepare(ball_position, launch_velocity)
	else:
		_batting_coverage.prepare(ball_position)
	tracking_visibility.refresh()
	_field_focus = ball_position
	_tracking_height = 18.0


func track_released_pitch(active: bool, position: Vector3) -> void:
	# A restrained pan follows visible flight after release. Batting coverage
	# currently favors its readable strike corridor, but has no motion lock.
	position = field_context.frame().affine_inverse() * position
	_pitch_focus = (
		Vector3(position.x * 0.10, 1.05 + (position.y - 1.05) * 0.05, maxf(0.0, position.z) * 0.03)
		if active
		else Vector3(0, 1.05, 0)
	)


func set_presentation_motion(
	motion: PresentationMotion, progress: float, transition_speed: float = TRANSITION_SPEED
) -> void:
	_presentation_motion = motion
	_presentation_progress = clampf(progress, 0.0, 1.0)
	_presentation_transition_speed = transition_speed


func clear_presentation_motion() -> void:
	_presentation_motion = PresentationMotion.STILL
	_presentation_progress = 0.0
	_presentation_transition_speed = TRANSITION_SPEED


func cycle_shot() -> void:
	shot = ((int(shot) + 1) % Shot.size()) as Shot


func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	if camera == null:
		return
	_apply_projection(camera)
	tracking_visibility.restore_occluders()
	camera.fov = _standard_fov
	var desired: Transform3D = _desired_transform(ball_position, 1.0)
	camera.global_transform = desired


func update(
	camera: Camera3D, delta_seconds: float, ball_live: bool, ball_position: Vector3
) -> void:
	if camera == null:
		return
	_apply_projection(camera)
	if shot == Shot.BALL_IN_PLAY and not ball_live and _shot_before_inspection < 0:
		return
	if ball_live and shot == Shot.BALL_IN_PLAY:
		if _defense_ball_view:
			_live_coverage.update(camera, delta_seconds, ball_position, tracking_visibility)
		else:
			camera.fov = _standard_fov
			_batting_coverage.update(camera, delta_seconds, ball_position, tracking_visibility)
		return
	tracking_visibility.restore_occluders()
	var desired: Transform3D = _desired_transform(ball_position, delta_seconds)
	var transition_weight: float = 1.0 - exp(-_presentation_transition_speed * delta_seconds)
	camera.global_transform = camera.global_transform.interpolate_with(desired, transition_weight)
	if _standard_fov > 0.0:
		camera.fov = lerpf(camera.fov, _standard_fov, transition_weight)


func _desired_transform(ball_position: Vector3, _delta_seconds: float) -> Transform3D:
	var camera_position: Vector3
	var focus: Vector3
	match shot:
		Shot.BATTING:
			# Stay nearly centered on the Pitch lane. A small handed offset keeps
			# depth readable without placing the loaded barrel across the view.
			camera_position = Vector3(_batter_side * 0.18, 2.10, -3.38)
			focus = Vector3(0.0, 1.10, 7.1)
		Shot.PITCHING:
			camera_position = (
				field_context.ground_point(
					field_context.frame() * (field_context.mound + Vector3(0, 0, 3.184))
				)
				+ field_context.up() * 2.45
			)
			focus = field_context.frame() * _pitch_focus
		Shot.SIDE:
			camera_position = Vector3(8.6, 2.65, 6.8)
			focus = Vector3(0.0, 1.15, 6.8)
		Shot.FIELD_SETUP:
			focus = field_context.frame() * field_context.play_bounds().get_center()
			camera_position = focus + field_context.up() * field_context.depth_m() * 1.4
		Shot.PITCHING_STAFF:
			camera_position = _venue_point(Vector3(-0.72, 0.36, 0.94))
			focus = _venue_point(Vector3(0, 0.047, 0.42))
		Shot.ESTABLISHING:
			camera_position = _venue_point(Vector3(-0.79, 0.49, -0.30))
			focus = _venue_point(Vector3(0, 0.047, 0.51))
		Shot.FOUL_SIDE:
			camera_position = _venue_point(Vector3(0.61, 0.25, -0.064))
			focus = _venue_point(Vector3(0, 0.047, 0.45))
		Shot.OUTFIELD:
			camera_position = _venue_point(Vector3(0, 0.33, 1.09))
			focus = _venue_point(Vector3(0, 0.051, 0.30))
		Shot.BALL_IN_PLAY:
			focus = _field_focus.lerp(ball_position, 0.65)
			# Static inspection view. Live coverage goes through BallInPlayCamera.
			camera_position = Vector3(_field_focus.x * 0.18, _tracking_height, -8.0)
			camera_position = tracking_visibility.clear_position(camera_position, ball_position)
		_:
			camera_position = Vector3(0.0, 5.0, -10.0)
			focus = Vector3(0.0, 1.0, 6.0)
	var motion_amount: float = smoothstep(0.0, 1.0, _presentation_progress)
	match _presentation_motion:
		PresentationMotion.ZOOM_IN:
			camera_position = camera_position.lerp(focus, 0.075 * motion_amount)
		PresentationMotion.ZOOM_OUT:
			camera_position += (camera_position - focus).normalized() * 1.35 * motion_amount
		PresentationMotion.PAN_LEFT:
			camera_position.x -= 1.10 * motion_amount
			focus.x -= 0.64 * motion_amount
		PresentationMotion.PAN_RIGHT:
			camera_position.x += 1.10 * motion_amount
			focus.x += 0.64 * motion_amount
		PresentationMotion.TILT_UP:
			focus.y += 0.78 * motion_amount
		PresentationMotion.TILT_DOWN:
			focus.y -= 0.62 * motion_amount
		_:
			pass
	if shot == Shot.BALL_IN_PLAY:
		return _tracking_transform(camera_position, focus)
	var direction: Vector3 = (focus - camera_position).normalized()
	var up_direction: Vector3 = (
		field_context.frame().basis.z.normalized() if shot == Shot.FIELD_SETUP else Vector3.UP
	)
	return Transform3D(Basis.looking_at(direction, up_direction), camera_position)


func _venue_point(ratio: Vector3) -> Vector3:
	var bounds: AABB = field_context.play_bounds()
	var local: Vector3 = Vector3(
		bounds.get_center().x + ratio.x * bounds.size.x * 0.5,
		0,
		bounds.position.z + ratio.z * bounds.size.z
	)
	var ground: Vector3 = field_context.ground_point(field_context.frame() * local)
	return ground + field_context.up() * ratio.y * field_context.depth_m()


func _tracking_transform(position: Vector3, focus: Vector3) -> Transform3D:
	# Keep a level horizon, with a well-defined fallback directly overhead.
	var up: Vector3 = Vector3.UP
	if absf((focus - position).normalized().dot(up)) > 0.98:
		up = Vector3.BACK
	return Transform3D(Basis.looking_at((focus - position).normalized(), up), position)


func _apply_projection(camera: Camera3D) -> void:
	if _standard_fov <= 0.0:
		_standard_fov = camera.fov
	if shot == Shot.FIELD_SETUP:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var bounds: AABB = field_context.play_bounds()
		var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
		camera.size = maxf(bounds.size.z, bounds.size.x / (viewport.x / maxf(1, viewport.y))) * 1.12
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE

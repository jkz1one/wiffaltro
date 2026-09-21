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
const FIELD_FOLLOW_SPEED: float = 4.5

var shot: Shot = Shot.BATTING
var _field_focus: Vector3 = Vector3(0.0, 2.2, 10.0)
var _batter_side: float = 1.0
var _presentation_motion: PresentationMotion = PresentationMotion.STILL
var _presentation_progress: float = 0.0
var _defense_ball_view: bool = false
var _shot_before_inspection: int = -1


func set_shot(next_shot: Shot) -> void:
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
	# occupy +X, while right-handed Batters occupy -X.
	_batter_side = 1.0 if is_left_handed else -1.0


func prepare_ball_in_play(defense_view: bool, ball_position: Vector3) -> void:
	_defense_ball_view = defense_view
	_field_focus = Vector3(
		ball_position.x * 0.40,
		clampf(ball_position.y * 0.25 + 1.2, 1.2, 4.0),
		lerpf(1.0, ball_position.z, 0.55)
	)


func set_presentation_motion(motion: PresentationMotion, progress: float) -> void:
	_presentation_motion = motion
	_presentation_progress = clampf(progress, 0.0, 1.0)


func clear_presentation_motion() -> void:
	_presentation_motion = PresentationMotion.STILL
	_presentation_progress = 0.0


func cycle_shot() -> void:
	shot = ((int(shot) + 1) % Shot.size()) as Shot


func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	if camera == null:
		return
	_apply_projection(camera)
	var desired: Transform3D = _desired_transform(ball_position, 1.0)
	camera.global_transform = desired


func update(
	camera: Camera3D, delta_seconds: float, ball_live: bool, ball_position: Vector3
) -> void:
	if camera == null:
		return
	_apply_projection(camera)
	if ball_live and shot == Shot.BALL_IN_PLAY:
		var follow_weight: float = 1.0 - exp(-FIELD_FOLLOW_SPEED * delta_seconds)
		_field_focus = _field_focus.lerp(
			Vector3(
				ball_position.x * 0.78,
				clampf(ball_position.y * 0.65 + 1.2, 1.2, 12.0),
				lerpf(5.0, ball_position.z, 0.82)
			),
			follow_weight
		)
	var desired: Transform3D = _desired_transform(ball_position, delta_seconds)
	var transition_weight: float = 1.0 - exp(-TRANSITION_SPEED * delta_seconds)
	camera.global_transform = camera.global_transform.interpolate_with(desired, transition_weight)


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
			camera_position = Vector3(0.0, 2.45, 16.9)
			focus = Vector3(0.0, 1.05, 0.0)
		Shot.SIDE:
			camera_position = Vector3(8.6, 2.65, 6.8)
			focus = Vector3(0.0, 1.15, 6.8)
		Shot.FIELD_SETUP:
			camera_position = Vector3(0.0, 32.0, 11.7)
			focus = Vector3(0.0, 0.0, 11.7)
		Shot.PITCHING_STAFF:
			camera_position = Vector3(-15.0, 8.4, 22.0)
			focus = Vector3(0.0, 1.1, 9.8)
		Shot.ESTABLISHING:
			camera_position = Vector3(-16.5, 11.5, -7.0)
			focus = Vector3(0.0, 1.1, 12.0)
		Shot.FOUL_SIDE:
			camera_position = Vector3(12.8, 5.8, -1.5)
			focus = Vector3(0.0, 1.1, 10.5)
		Shot.OUTFIELD:
			camera_position = Vector3(0.0, 7.8, 25.5)
			focus = Vector3(0.0, 1.2, 7.0)
		Shot.BALL_IN_PLAY:
			focus = _field_focus
			var depth_pullback: float = clampf(ball_position.z * 0.16, 0.0, 7.0)
			if _defense_ball_view:
				var defense_height: float = 9.5 + clampf(ball_position.y * 0.40, 0.0, 6.0)
				camera_position = focus + Vector3(
					0.0, defense_height, 15.5 + depth_pullback * 0.55
				)
			else:
				var offense_height: float = 13.0 + clampf(ball_position.y * 0.38, 0.0, 5.0)
				camera_position = focus + Vector3(
					0.0, offense_height, -14.0 - depth_pullback
				)
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
	var direction: Vector3 = (focus - camera_position).normalized()
	var up_direction: Vector3 = (
		Vector3.BACK if shot == Shot.FIELD_SETUP else Vector3.UP
	)
	return Transform3D(Basis.looking_at(direction, up_direction), camera_position)


func _apply_projection(camera: Camera3D) -> void:
	if shot == Shot.FIELD_SETUP:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 29.0
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE

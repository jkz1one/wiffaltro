class_name MatchCameraDirector
extends RefCounted

enum Shot {
	BATTING,
	PITCHING,
	SIDE,
	BALL_IN_PLAY,
}

const TRANSITION_SPEED: float = 7.5
const FIELD_FOLLOW_SPEED: float = 4.5

var shot: Shot = Shot.BATTING
var _field_focus: Vector3 = Vector3(0.0, 2.2, 10.0)

func set_shot(next_shot: Shot) -> void:
	shot = next_shot

func cycle_shot() -> void:
	shot = (int(shot) + 1) % Shot.size()

func snap(camera: Camera3D, ball_position: Vector3 = Vector3.ZERO) -> void:
	if camera == null:
		return
	var desired: Transform3D = _desired_transform(ball_position, 1.0)
	camera.global_transform = desired

func update(
	camera: Camera3D,
	delta_seconds: float,
	ball_live: bool,
	ball_position: Vector3
) -> void:
	if camera == null:
		return
	if ball_live and shot == Shot.BALL_IN_PLAY:
		var follow_weight: float = 1.0 - exp(
			-FIELD_FOLLOW_SPEED * delta_seconds
		)
		_field_focus = _field_focus.lerp(
			Vector3(
				ball_position.x * 0.48,
				clampf(ball_position.y * 0.30 + 1.2, 1.2, 5.5),
				lerpf(5.0, ball_position.z, 0.58)
			),
			follow_weight
		)
	var desired: Transform3D = _desired_transform(ball_position, delta_seconds)
	var transition_weight: float = 1.0 - exp(
		-TRANSITION_SPEED * delta_seconds
	)
	camera.global_transform = camera.global_transform.interpolate_with(
		desired,
		transition_weight
	)

func _desired_transform(
	ball_position: Vector3,
	_delta_seconds: float
) -> Transform3D:
	var camera_position: Vector3
	var focus: Vector3
	match shot:
		Shot.BATTING:
			camera_position = Vector3(0.0, 1.68, -2.85)
			focus = Vector3(0.0, 1.18, 8.0)
		Shot.PITCHING:
			camera_position = Vector3(0.0, 2.45, 16.9)
			focus = Vector3(0.0, 1.05, 0.0)
		Shot.SIDE:
			camera_position = Vector3(8.6, 2.65, 6.8)
			focus = Vector3(0.0, 1.15, 6.8)
		_:
			focus = _field_focus
			var depth_pullback: float = clampf(ball_position.z * 0.16, 0.0, 7.0)
			var height: float = 13.0 + clampf(ball_position.y * 0.38, 0.0, 5.0)
			camera_position = focus + Vector3(0.0, height, -14.0 - depth_pullback)
	var direction: Vector3 = (focus - camera_position).normalized()
	return Transform3D(
		Basis.looking_at(direction, Vector3.UP),
		camera_position
	)

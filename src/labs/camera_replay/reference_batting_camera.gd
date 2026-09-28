class_name ReferenceBattingCamera
extends RefCounted

# Developer replay reference captured from 6edb9a4. Never used by a normal match.
var _focus: Vector3


func prepare(ball: Vector3) -> void:
	_focus = Vector3(ball.x * 0.40, clampf(ball.y * 0.25 + 1.2, 1.2, 4.0), lerpf(1.0, ball.z, 0.55))


func update(
	camera: Camera3D, delta: float, ball: Vector3, visibility: BallTrackingVisibility
) -> void:
	_focus = _focus.lerp(
		Vector3(ball.x * 0.78, clampf(ball.y * 0.65 + 1.2, 1.2, 12.0), lerpf(5.0, ball.z, 0.82)),
		1.0 - exp(-4.5 * delta)
	)
	var focus: Vector3 = _focus.lerp(ball, 0.65)
	var position: Vector3 = (
		focus
		+ Vector3(
			0, 13.0 + clampf(ball.y * 0.38, 0.0, 5.0), -14.0 - clampf(ball.z * 0.16, 0.0, 7.0)
		)
	)
	position = visibility.clear_position(position, ball)
	camera.global_transform = camera.global_transform.interpolate_with(
		_transform(position, focus), 1.0 - exp(-7.5 * delta)
	)
	var safe: Vector3 = visibility.clear_position(camera.global_position, ball)
	var rect: Rect2 = camera.get_viewport().get_visible_rect().grow(-32.0)
	if (
		not safe.is_equal_approx(camera.global_position)
		or camera.is_position_behind(ball)
		or not rect.has_point(camera.unproject_position(ball))
	):
		camera.global_transform = _transform(safe, ball)
	visibility.update_occluders(camera.global_position, ball, delta)


func _transform(position: Vector3, focus: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at((focus - position).normalized(), Vector3.BACK), position)

class_name DeflectionModel
extends RefCounted

static func velocity_after_bobble(
	incoming_velocity: Vector3,
	defender_position: Vector3,
	ball_position: Vector3
) -> Vector3:
	var away: Vector3 = ball_position - defender_position
	away.y = 0.0
	if away.length_squared() <= 0.000001:
		away = Vector3.RIGHT
	away = away.normalized()

	var retained_horizontal: Vector3 = incoming_velocity
	retained_horizontal.y = 0.0
	retained_horizontal *= 0.07
	return (
		retained_horizontal
		+ away * clampf(incoming_velocity.length() * 0.035, 0.50, 1.10)
		+ Vector3.UP * clampf(incoming_velocity.length() * 0.025, 0.25, 0.85)
	)

static func spin_after_bobble(incoming_spin: Vector3) -> Vector3:
	return incoming_spin * 0.24 + Vector3(0.0, 4.0, 1.5)

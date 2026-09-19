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
	retained_horizontal *= 0.24
	return (
		retained_horizontal
		+ away * maxf(1.4, incoming_velocity.length() * 0.10)
		+ Vector3.UP * clampf(incoming_velocity.length() * 0.08, 1.0, 3.5)
	)

static func spin_after_bobble(incoming_spin: Vector3) -> Vector3:
	return incoming_spin * 0.38 + Vector3(0.0, 7.0, 3.0)

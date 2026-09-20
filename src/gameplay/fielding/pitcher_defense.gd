class_name PitcherDefense
extends RefCounted

const REACTION_RADIUS_M: float = 0.60
const MAX_REACTION_HEIGHT_M: float = 1.85


static func can_attempt(ball_position: Vector3, pitcher_position: Vector3) -> bool:
	return attempt_position(ball_position, ball_position, pitcher_position) != Vector3.INF


static func attempt_position(
	previous_position: Vector3,
	current_position: Vector3,
	pitcher_position: Vector3
) -> Vector3:
	var segment_xz: Vector2 = Vector2(
		current_position.x - previous_position.x,
		current_position.z - previous_position.z
	)
	var to_pitcher_xz: Vector2 = Vector2(
		pitcher_position.x - previous_position.x,
		pitcher_position.z - previous_position.z
	)
	var alpha: float = 0.0
	if segment_xz.length_squared() > 0.000001:
		alpha = clampf(to_pitcher_xz.dot(segment_xz) / segment_xz.length_squared(), 0.0, 1.0)
	var closest: Vector3 = previous_position.lerp(current_position, alpha)
	var horizontal_distance: float = Vector2(
		closest.x - pitcher_position.x,
		closest.z - pitcher_position.z
	).length()
	if (
		horizontal_distance > REACTION_RADIUS_M
		or closest.y < 0.05
		or closest.y > MAX_REACTION_HEIGHT_M
	):
		return Vector3.INF
	return closest


static func resolve(
	ball_position: Vector3,
	ball_velocity: Vector3,
	pitcher_position: Vector3,
	has_grounded: bool,
	fielding_rating: int
) -> FieldingResolver.Outcome:
	var distance: float = (
		Vector2(ball_position.x - pitcher_position.x, ball_position.z - pitcher_position.z).length()
	)
	return FieldingResolver.resolve(
		distance, ball_velocity.length(), ball_position.y, has_grounded, fielding_rating, 0.0
	)

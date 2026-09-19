class_name PitcherDefense
extends RefCounted

const REACTION_RADIUS_M: float = 1.15
const MAX_REACTION_HEIGHT_M: float = 2.10

static func can_attempt(ball_position: Vector3, pitcher_position: Vector3) -> bool:
	var horizontal_distance: float = Vector2(
		ball_position.x - pitcher_position.x,
		ball_position.z - pitcher_position.z
	).length()
	return (
		horizontal_distance <= REACTION_RADIUS_M
		and ball_position.y >= 0.05
		and ball_position.y <= MAX_REACTION_HEIGHT_M
	)

static func resolve(
	ball_position: Vector3,
	ball_velocity: Vector3,
	pitcher_position: Vector3,
	has_grounded: bool,
	fielding_rating: int
) -> FieldingResolver.Outcome:
	var distance: float = Vector2(
		ball_position.x - pitcher_position.x,
		ball_position.z - pitcher_position.z
	).length()
	return FieldingResolver.resolve(
		distance,
		ball_velocity.length(),
		ball_position.y,
		has_grounded,
		fielding_rating,
		0.0
	)

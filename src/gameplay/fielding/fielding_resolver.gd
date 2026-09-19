class_name FieldingResolver
extends RefCounted

enum Outcome {
	CLEAN,
	BOBBLE,
	MISS,
}

const MAX_AIR_CONTROL_HEIGHT_M: float = 2.05
const MAX_GROUND_CONTROL_HEIGHT_M: float = 1.05

static func resolve(
	distance_m: float,
	ball_speed_mps: float,
	ball_height_m: float,
	has_grounded: bool,
	fielding_rating: int,
	reaction_margin_seconds: float = 0.0
) -> Outcome:
	var rating: float = clampf(float(fielding_rating), 0.0, 10.0)
	var allowed_height: float = (
		MAX_GROUND_CONTROL_HEIGHT_M if has_grounded
		else MAX_AIR_CONTROL_HEIGHT_M
	)
	if ball_height_m < 0.0 or ball_height_m > allowed_height:
		return Outcome.MISS

	var reach_limit: float = 0.52 + rating * 0.024
	if distance_m > reach_limit:
		return Outcome.MISS

	var difficulty: float = ball_speed_mps * (0.028 if has_grounded else 0.030)
	difficulty += distance_m * 0.88
	difficulty -= reaction_margin_seconds * 0.50
	var skill: float = 0.50 + rating * 0.095
	var control_margin: float = skill - difficulty

	if control_margin >= 0.16:
		return Outcome.CLEAN
	if control_margin >= -0.12:
		return Outcome.BOBBLE
	return Outcome.MISS

static func outcome_name(outcome: Outcome) -> String:
	match outcome:
		Outcome.CLEAN:
			return "CLEAN"
		Outcome.BOBBLE:
			return "BOBBLE"
		_:
			return "MISS"

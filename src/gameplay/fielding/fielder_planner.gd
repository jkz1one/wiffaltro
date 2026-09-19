class_name FielderPlanner
extends RefCounted

const GRAVITY_MPS2: float = 9.80665
const SAMPLE_STEP_SECONDS: float = 0.10
const MAX_PREDICTION_SECONDS: float = 3.0

static func plan(
	ball_position: Vector3,
	ball_velocity: Vector3,
	has_grounded: bool,
	fielder_position: Vector3,
	move_speed_mps: float,
	reach_m: float
) -> FielderPlan:
	var plan_result: FielderPlan = FielderPlan.new()
	var fallback_position: Vector3 = ball_position

	var sample_time: float = SAMPLE_STEP_SECONDS
	while sample_time <= MAX_PREDICTION_SECONDS:
		var predicted: Vector3
		if has_grounded:
			var decay: float = exp(-1.15 * sample_time)
			predicted = ball_position + Vector3(
				ball_velocity.x,
				0.0,
				ball_velocity.z
			) * sample_time * decay
			predicted.y = 0.45
		else:
			predicted = (
				ball_position
				+ ball_velocity * sample_time
				+ Vector3.DOWN * 0.5 * GRAVITY_MPS2 * sample_time * sample_time
			)
			if predicted.y < 0.35:
				predicted.y = 0.35

		fallback_position = predicted
		var travel_distance: float = Vector2(
			predicted.x - fielder_position.x,
			predicted.z - fielder_position.z
		).length()
		var travel_seconds: float = maxf(
			0.0,
			(travel_distance - reach_m) / maxf(0.1, move_speed_mps)
		)
		if travel_seconds <= sample_time:
			plan_result.intercept_position = predicted
			plan_result.intercept_seconds = sample_time
			plan_result.reachable = true
			plan_result.reaction_margin_seconds = sample_time - travel_seconds
			return plan_result

		sample_time += SAMPLE_STEP_SECONDS

	plan_result.intercept_position = fallback_position
	plan_result.intercept_seconds = MAX_PREDICTION_SECONDS
	return plan_result

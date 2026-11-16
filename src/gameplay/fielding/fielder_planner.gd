class_name FielderPlanner
extends RefCounted

const GRAVITY_MPS2: float = 9.80665
const SAMPLE_STEP_SECONDS: float = 0.10
const MAX_PREDICTION_SECONDS: float = 3.0
# Working private supported forecast bound; ordinary flat loop stays unchanged.
const MAX_SUPPORTED_FORECAST_SAMPLES: int = 30

static func plan(
	ball_position: Vector3,
	ball_velocity: Vector3,
	has_grounded: bool,
	fielder_position: Vector3,
	move_speed_mps: float,
	reach_m: float,
	stationary: bool = false,
	support_provider: Callable = Callable(),
	arrival_provider: Callable = Callable()
) -> FielderPlan:
	if not support_provider.is_null() or not arrival_provider.is_null():
		return _supported_plan(ball_position, ball_velocity, has_grounded, fielder_position,
			move_speed_mps, reach_m, stationary, support_provider, arrival_provider)
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
		if stationary:
			travel_seconds = 0.0 if travel_distance <= reach_m else INF
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


static func _supported_plan(ball_position: Vector3, ball_velocity: Vector3,
	has_grounded: bool, fielder_position: Vector3, move_speed_mps: float,
	reach_m: float, stationary: bool, support_provider: Callable,
	arrival_provider: Callable) -> FielderPlan:
	var result: FielderPlan = FielderPlan.new()
	result.advisory_route = true
	result.route_reason = "invalid_provider"
	result.intercept_position = ball_position
	if not support_provider.is_valid() or not arrival_provider.is_valid() \
		or not ball_position.is_finite() or not ball_velocity.is_finite() \
		or not fielder_position.is_finite() or not is_finite(move_speed_mps) \
		or move_speed_mps < 0 or not is_finite(reach_m) or reach_m < 0:
		return result
	result.route_reason = "unsupported_forecast"
	for index in range(1, MAX_SUPPORTED_FORECAST_SAMPLES + 1):
		var seconds: float = float(index) * SAMPLE_STEP_SECONDS
		result.forecast_samples = index
		var predicted: Vector3
		if has_grounded:
			var decay: float = exp(-1.15 * seconds)
			predicted = ball_position + Vector3(ball_velocity.x, 0.0, ball_velocity.z) * seconds * decay
		else:
			predicted = ball_position + ball_velocity * seconds \
				+ Vector3.DOWN * 0.5 * GRAVITY_MPS2 * seconds * seconds
		var support: Dictionary = support_provider.call(Vector2(predicted.x, predicted.z))
		if support.is_empty() or not support.get("position") is Vector3 \
			or not support["position"].is_finite():
			continue
		var feet: Vector3 = support["position"]
		# Same approximate gravity/decay/game-feel. This never changes grounded state.
		predicted.y = feet.y + 0.45 if has_grounded else maxf(predicted.y, feet.y + 0.35)
		var route: Dictionary = arrival_provider.call(predicted, feet, seconds,
			move_speed_mps, reach_m, stationary, has_grounded)
		result.route_queries += 1
		result.route_support_segments += int(route.get("support_segments", 0))
		result.route_support_checks += int(route.get("support_checks", 0))
		var goal: Vector3 = route.get("feet_target", Vector3.INF)
		if not goal.is_finite():
			continue
		result.intercept_position = predicted
		result.supported_feet_position = goal
		result.route_endpoint = route.get("position", Vector3.INF)
		result.intercept_seconds = seconds
		result.route_reason = str(route.get("reason", "unknown"))
		var elapsed: float = float(route.get("elapsed", INF))
		if bool(route.get("reached", false)) and is_finite(elapsed) \
			and elapsed >= 0.0 and elapsed <= seconds:
			result.reachable = true
			# A coarse route estimate must never manufacture handling/reaction credit.
			result.reaction_margin_seconds = 0.0
			return result
	return result

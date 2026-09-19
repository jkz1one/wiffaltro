class_name PitchAimSolver
extends RefCounted

const MAX_ITERATIONS: int = 24
const TARGET_TOLERANCE_M: float = 0.0125
const MAX_GUIDE_OFFSET_M: float = 20.0
const GRAVITY_MPS2: float = 9.80665
const NO_CROSSING_RAISE_M: float = 0.75

static func solve(
	pitch: PitchDefinition,
	ball_setup: BallSetupDefinition,
	mound_origin: Vector3,
	target_position: Vector3,
	is_left_handed: bool,
	flight_seed: int
) -> PitchLaunchParameters:
	var guide_target: Vector3 = target_position
	var direct_distance_m: float = absf(target_position.z - mound_origin.z)
	var initial_flight_seconds: float = (
		direct_distance_m / maxf(4.0, pitch.nominal_velocity_mps)
	)
	guide_target.y += minf(
		0.5 * GRAVITY_MPS2 * initial_flight_seconds * initial_flight_seconds,
		MAX_GUIDE_OFFSET_M
	)
	var best_parameters: PitchLaunchParameters = null
	var best_error_squared: float = INF

	for _iteration in range(MAX_ITERATIONS):
		var candidate: PitchLaunchParameters = PitchLaunchBuilder.build_nominal(
			pitch,
			ball_setup,
			mound_origin,
			guide_target,
			is_left_handed,
			flight_seed
		)
		if candidate == null:
			return null

		var crossing: PitchCrossingResult = (
			PitchTrajectorySimulator.simulate_to_plane(
				candidate,
				target_position.z
			)
		)

		if not crossing.crossed:
			guide_target.y = minf(
				guide_target.y + NO_CROSSING_RAISE_M,
				target_position.y + MAX_GUIDE_OFFSET_M
			)
			continue

		var error_x: float = target_position.x - crossing.point.x
		var error_y: float = target_position.y - crossing.point.y
		var error_squared: float = error_x * error_x + error_y * error_y

		if error_squared < best_error_squared:
			best_error_squared = error_squared
			best_parameters = candidate

		if error_squared <= TARGET_TOLERANCE_M * TARGET_TOLERANCE_M:
			return candidate

		guide_target.x = clampf(
			guide_target.x + error_x,
			target_position.x - MAX_GUIDE_OFFSET_M,
			target_position.x + MAX_GUIDE_OFFSET_M
		)
		guide_target.y = clampf(
			guide_target.y + error_y,
			target_position.y - MAX_GUIDE_OFFSET_M,
			target_position.y + MAX_GUIDE_OFFSET_M
		)

	return best_parameters

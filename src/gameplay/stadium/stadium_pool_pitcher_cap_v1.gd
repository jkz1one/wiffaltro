class_name StadiumPoolPitcherCapV1
extends RefCounted

# A pure, conditional numerical lemma. This class has no resolver or award path.
# The owner must authenticate the sampled facts and the unchanged source/phase.
const VERSION: StringName = &"POOL-PITCHER-CAP-NUMERICS-v1"
const ENGINE_SOURCE_PREFIX: String = "ed1daf0bf"
const GRID_M: float = 1.0 / 16.0
const COORD_XZ_MAX_M: float = 64.0
const COORD_Y_MAX_M: float = 16.0
const BALL_VELOCITY_COMPONENT_MAX_MPS: float = 4096.0
const SCALAR_MAX: float = 1048576.0
const MOVE_SPEED_MIN_MPS: float = 0.1
const MOVE_SPEED_MAX_MPS: float = 16.0
const MOUND: Vector3 = Vector3(0.0, 0.0, 13.716)
const MOVING_CAP_EXTRA_M: float = 7.0
const CATCH_GAP_M: float = 11.0 / 16.0
const DOUBLE_OUTWARD_M: float = 1.0 / 1099511627776.0
const ROTATION_GRAM_MAX: float = 1.0 + 1.0 / 262144.0


static func descriptor() -> Dictionary:
	return {
		"version": VERSION,
		"engine_source_prefix": ENGINE_SOURCE_PREFIX,
		"vector_precision": "binary32; GDScript scalar binary64",
		"coordinate_xz_max_m": COORD_XZ_MAX_M,
		"coordinate_y_max_m": COORD_Y_MAX_M,
		"ball_velocity_component_max_mps": BALL_VELOCITY_COMPONENT_MAX_MPS,
		"normal_move_speed_mps": normal_move_speed_mps(),
		"grid_m": GRID_M,
		"shadow_only": true,
		"early_award_authority": false,
		"source_contract":
		{
			"defender_spacing.gd":
			"60a99a60e46f45863a35c319a1b9a3cf100263b6bb0a3454000f7924d7ff5040",
			"pitcher_defense.gd":
			"0c6774f23b58d1456e95531c31ecf29e0f61b771aaa9b3476ac3d35d8417f9dd",
			"fielder_planner.gd":
			"a722c7fd617352eeccc4764936ed6debdbb30afb541bac481a11e7a222e3e8eb",
			"pitch_bat_lab_defense_support.gd":
			"3227e3358e432ced68d359e8578a8e37f05c1392a38e103185f807ade8a016a3",
		},
	}


static func normal_move_speed_mps() -> float:
	# MatchLabSupport.pitcher_fielding_rating is 5 in the non-match lab;
	# PitchBatLabDefenseSupport.gear_factor is 1.0 in that same branch.
	return lerpf(3.6, 4.6, 5.0 / 10.0) * 1.0


static func evaluate(
	previous: Vector3, current: Vector3, pitcher: Vector3, primary: Vector3, inputs: Dictionary
) -> Dictionary:
	var result: Dictionary = _empty_result()
	for point: Vector3 in [previous, current, pitcher, primary]:
		if not _coordinate_domain(point):
			return _reject(result, &"COORDINATE_DOMAIN_UNPROVEN")
	for key: String in ["pitcher_attempted", "defender_touched"]:
		if not inputs.has(key) or typeof(inputs[key]) != TYPE_BOOL:
			return _reject(result, &"BOOLEAN_INPUT_MISSING")
	for key: String in ["cooldown_seconds", "elapsed_seconds", "delta", "move_speed_mps"]:
		if not inputs.has(key) or not _finite_scalar(inputs[key]):
			return _reject(result, &"NONFINITE_OR_MISSING_SCALAR")
	if (
		absf(float(inputs.cooldown_seconds)) > SCALAR_MAX
		or float(inputs.elapsed_seconds) < 0.0
		or float(inputs.elapsed_seconds) > SCALAR_MAX
		or float(inputs.move_speed_mps) < MOVE_SPEED_MIN_MPS
		or float(inputs.move_speed_mps) > MOVE_SPEED_MAX_MPS
	):
		return _reject(result, &"SCALAR_DOMAIN_UNPROVEN")
	var profile: Dictionary = engine_numeric_profile()
	result["engine_numeric_profile"] = profile
	if not bool(profile.valid):
		return _reject(result, StringName(profile.reason))
	result.valid = true
	if bool(inputs.pitcher_attempted) or float(inputs.cooldown_seconds) > 0.0:
		result.supported = true
		result.excluded = true
		result.numeric_proof = true
		result.pursuit_mode = &"ATTEMPT_GATE_CLOSED"
		result.numeric_scope = &"ORDINARY_ATTEMPT_GATE_CLOSED"
		result.reason = &"ORDINARY_ATTEMPT_GATE_CLOSED"
		return result
	var zero_pursuit: bool = (
		bool(inputs.defender_touched)
		or float(inputs.elapsed_seconds) < PitchBatLabDefenseSupport.CHARGE_REACTION_SECONDS
	)
	if not zero_pursuit:
		if (
			typeof(inputs.get("velocity_provenance")) not in [TYPE_STRING, TYPE_STRING_NAME]
			or inputs.velocity_provenance != &"controller_entry_observed"
		):
			return _reject(result, &"POST_AERO_DOMAIN_UNPROVEN")
		if not inputs.has("velocity") or typeof(inputs.velocity) != TYPE_VECTOR3:
			return _reject(result, &"CONTROLLER_VELOCITY_MISSING")
		var velocity: Vector3 = inputs.velocity
		if (
			not velocity.is_finite()
			or absf(velocity.x) > BALL_VELOCITY_COMPONENT_MAX_MPS
			or absf(velocity.y) > BALL_VELOCITY_COMPONENT_MAX_MPS
			or absf(velocity.z) > BALL_VELOCITY_COMPONENT_MAX_MPS
		):
			return _reject(result, &"CONTROLLER_VELOCITY_DOMAIN_UNPROVEN")
	var displacement_upper: float = 0.0
	if not zero_pursuit:
		# Scalar binary64 arithmetic gets an explicit outward guard before ceil.
		# This is a cap from actual P; P is never assumed to be at the mound.
		var l1: float = absf(float(pitcher.x) - float(MOUND.x))
		l1 += absf(float(pitcher.z) - float(MOUND.z))
		displacement_upper = (ceilf((l1 + DOUBLE_OUTWARD_M) / GRID_M) * GRID_M + MOVING_CAP_EXTRA_M)
	var box: Array[float] = [
		floorf(minf(previous.x, current.x) / GRID_M) * GRID_M - GRID_M,
		ceilf(maxf(previous.x, current.x) / GRID_M) * GRID_M + GRID_M,
		floorf(minf(previous.z, current.z) / GRID_M) * GRID_M - GRID_M,
		ceilf(maxf(previous.z, current.z) / GRID_M) * GRID_M + GRID_M,
	]
	var gap_x: float = maxf(box[0] - float(pitcher.x), float(pitcher.x) - box[1])
	var gap_z: float = maxf(box[2] - float(pitcher.z), float(pitcher.z) - box[3])
	var gap: float = maxf(0.0, maxf(gap_x, gap_z))
	var gap_lower: float = maxf(0.0, floorf((gap - DOUBLE_OUTWARD_M) / GRID_M) * GRID_M)
	result.has_displacement_bound = true
	result.displacement_upper_m = displacement_upper
	result.endpoint_box_xz = box
	result.gap_lower_m = gap_lower
	result.required_gap_m = displacement_upper + CATCH_GAP_M
	result.separation_axis = &"x" if gap_x >= gap_z else &"z"
	result.pursuit_mode = &"FLAG_GATED_ZERO" if zero_pursuit else &"ALL_DELTA_MOVING_CAP"
	result.numeric_scope = (
		&"FLAG_GATED_ZERO_PURSUIT" if zero_pursuit else &"CONTROLLER_ENTRY_OBSERVED_ONLY"
	)
	result.numeric_proof = true
	result.excluded = gap_lower > float(result.required_gap_m)
	result.supported = result.excluded
	result.reason = (
		&"ROUNDED_PITCHER_PREDICATE_EXCLUDED"
		if result.excluded
		else &"HISTORICAL_PITCHER_ORDER_UNPROVEN"
	)
	return result


static func engine_numeric_profile() -> Dictionary:
	# This read-only check obtains the actual 72 coefficient matrices. It does
	# not import a sin/cos error assumption, nor trust a caller's receipt.
	var profile: Dictionary = {"valid": false, "reason": &"ENGINE_NUMERIC_PROFILE_UNPROVEN"}
	var version: Dictionary = Engine.get_version_info()
	if not str(version.get("hash", "")).begins_with(ENGINE_SOURCE_PREFIX):
		return profile
	if Vector3(16777217.0, 0.0, 0.0).x != 16777216.0:
		return profile
	if (
		PitcherDefense.REACTION_RADIUS_M != 0.60
		or DefenderSpacing.MOUND_CLEARANCE_M != 1.55
		or PitchBatLabDefenseSupport.CHARGE_RADIUS_M != 5.0
		or PitchBatLabDefenseSupport.CHARGE_REACTION_SECONDS != 0.20
		or FielderPlanner.SAMPLE_STEP_SECONDS != 0.10
		or FielderPlanner.MAX_PREDICTION_SECONDS != 3.0
		or FielderPlanner.GRAVITY_MPS2 != 9.80665
	):
		return profile
	var maximum_gram: float = 0.0
	for index in range(72):
		var angle: float = float(index) * TAU / 72.0
		var rotation: Basis = Basis(Vector3.UP, angle)
		if not rotation.is_finite():
			return profile
		if rotation.x.y != 0.0 or rotation.z.y != 0.0 or rotation.y != Vector3.UP:
			return profile
		var a: float = rotation.x.x
		var b: float = rotation.z.x
		var c: float = rotation.x.z
		var d: float = rotation.z.z
		if maxf(maxf(absf(a), absf(b)), maxf(absf(c), absf(d))) > 2.0:
			return profile
		var cross: float = absf(a * b + c * d)
		var gram: float = maxf(a * a + c * c + cross, b * b + d * d + cross)
		gram += DOUBLE_OUTWARD_M
		if gram > ROTATION_GRAM_MAX:
			return profile
		maximum_gram = maxf(maximum_gram, gram)
	# Source-identical planner sample times; all possible exp inputs are finite.
	var sample_time: float = FielderPlanner.SAMPLE_STEP_SECONDS
	var planner_samples: int = 0
	while sample_time <= FielderPlanner.MAX_PREDICTION_SECONDS:
		var decay: float = exp(-1.15 * sample_time)
		if not is_finite(decay) or decay < 0.0 or decay > 1.0:
			return profile
		planner_samples += 1
		if planner_samples > 31:
			return profile
		sample_time += FielderPlanner.SAMPLE_STEP_SECONDS
	profile.valid = true
	profile.reason = &"ENGINE_NUMERIC_PROFILE_CHECKED"
	profile["rotation_count"] = 72
	profile["maximum_gram_upper"] = maximum_gram
	profile["planner_sample_count"] = planner_samples
	profile["source_prefix"] = ENGINE_SOURCE_PREFIX
	return profile


static func _coordinate_domain(point: Vector3) -> bool:
	return (
		point.is_finite()
		and absf(point.x) <= COORD_XZ_MAX_M
		and absf(point.z) <= COORD_XZ_MAX_M
		and absf(point.y) <= COORD_Y_MAX_M
	)


static func _finite_scalar(value: Variant) -> bool:
	return (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and is_finite(float(value))


static func _empty_result() -> Dictionary:
	return {
		"descriptor_version": VERSION,
		"valid": false,
		"supported": false,
		"excluded": false,
		"numeric_proof": false,
		"shadow_only": true,
		"early_award_authority": false,
		"reason": &"INPUTS_UNPROVEN",
		"pursuit_mode": &"UNPROVEN",
		"numeric_scope": &"UNPROVEN",
		"has_displacement_bound": false,
		"displacement_upper_m": -1.0,
		"endpoint_box_xz": [],
		"separation_axis": &"none",
		"gap_lower_m": 0.0,
		"required_gap_m": -1.0,
	}


static func _reject(result: Dictionary, reason: StringName) -> Dictionary:
	result.valid = false
	result.reason = reason
	return result

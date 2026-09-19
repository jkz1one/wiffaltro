class_name BallPlayResolver
extends RefCounted

signal play_resolved(outcome: BallPlayOutcome)

var field: FieldDefinition
var state: BallPlayState

func start_play(field_definition: FieldDefinition) -> void:
	field = field_definition
	state = BallPlayState.new()

func advance_time(delta_seconds: float) -> void:
	if state != null and not state.dead:
		state.elapsed_seconds += delta_seconds

func observe_segment(previous: Vector3, current: Vector3) -> void:
	if state == null or state.dead or field == null:
		return

	var safe_crossing: Vector3 = _forward_plane_crossing(
		previous,
		current,
		field.safe_hit_z_m
	)
	if not safe_crossing.is_equal_approx(Vector3.INF):
		if field.is_fair_point(safe_crossing):
			state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)

	var deep_crossing: Vector3 = _forward_plane_crossing(
		previous,
		current,
		field.deep_air_z_m
	)
	if not deep_crossing.is_equal_approx(Vector3.INF):
		if (
			field.is_fair_point(deep_crossing)
			and not state.has_grounded
			and not state.defender_touched
		):
			state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)

	var wall_crossing: Vector3 = _forward_plane_crossing(
		previous,
		current,
		field.back_wall_z_m
	)
	if not wall_crossing.is_equal_approx(Vector3.INF):
		if (
			field.is_fair_point(wall_crossing)
			and not state.has_grounded
			and wall_crossing.y > field.home_run_height_m
		):
			state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
			_resolve_floor(&"cleared_hr_boundary", wall_crossing)
			return

	if current.z >= field.dead_ball_z_m or current.y < -2.0:
		resolve_settled(current)

func record_ground_contact(position: Vector3) -> void:
	if state == null or state.dead or state.has_grounded:
		return
	state.has_grounded = true
	state.first_ground_position = position
	state.is_fair = field.is_fair_point(position)

func record_back_wall_contact(position: Vector3) -> void:
	if state == null or state.dead:
		return
	if state.has_grounded or state.defender_touched:
		state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
		_resolve_floor(&"bounce_to_back_wall", position)
	else:
		state.raise_result_floor(BallPlayState.ResultFloor.TRIPLE)
		_resolve_floor(&"back_wall_on_fly", position)

func record_live_object_contact(object_id: StringName) -> void:
	if state == null or state.dead:
		return
	state.last_obstacle_contact = object_id

func record_clean_control(
	defender_id: StringName,
	position: Vector3,
	is_airborne: bool
) -> void:
	if state == null or state.dead:
		return
	state.last_defender_touch = defender_id
	state.defender_touched = true
	if is_airborne and not state.has_grounded:
		state.caught = true
		state.catch_position = position
		state.catch_time = state.elapsed_seconds
		_resolve_out(BallPlayOutcome.Result.OUT, &"fly_catch", position, true)
		return

	if state.result_floor == BallPlayState.ResultFloor.NONE:
		_resolve_out(BallPlayOutcome.Result.OUT, &"ground_control", position)
	else:
		_resolve_floor(&"controlled_after_safe", position)

func record_bobble(defender_id: StringName) -> void:
	if state == null or state.dead:
		return
	state.last_defender_touch = defender_id
	state.defender_touched = true
	state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)

func record_miss(defender_id: StringName) -> void:
	if state == null or state.dead:
		return
	state.last_defender_touch = defender_id

func resolve_settled(position: Vector3) -> void:
	if state == null or state.dead:
		return
	if state.result_floor == BallPlayState.ResultFloor.NONE:
		state.raise_result_floor(BallPlayState.ResultFloor.SINGLE)
	_resolve_floor(&"ball_settled", position)

func _resolve_floor(reason: StringName, position: Vector3) -> void:
	var result: BallPlayOutcome.Result = BallPlayOutcome.Result.SINGLE
	match state.result_floor:
		BallPlayState.ResultFloor.DOUBLE:
			result = BallPlayOutcome.Result.DOUBLE
		BallPlayState.ResultFloor.TRIPLE:
			result = BallPlayOutcome.Result.TRIPLE
		BallPlayState.ResultFloor.HOME_RUN:
			result = BallPlayOutcome.Result.HOME_RUN
		_:
			result = BallPlayOutcome.Result.SINGLE
	_resolve_out(result, reason, position)

func _resolve_out(
	result: BallPlayOutcome.Result,
	reason: StringName,
	position: Vector3,
	caught: bool = false
) -> void:
	state.dead = true
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = result
	outcome.reason = reason
	outcome.caught = caught
	outcome.resolution_position = position
	play_resolved.emit(outcome)

func _forward_plane_crossing(
	previous: Vector3,
	current: Vector3,
	plane_z: float
) -> Vector3:
	if previous.z >= plane_z or current.z < plane_z:
		return Vector3.INF
	var denominator: float = current.z - previous.z
	if absf(denominator) <= 0.000001:
		return Vector3.INF
	var fraction: float = clampf(
		(plane_z - previous.z) / denominator,
		0.0,
		1.0
	)
	return previous.lerp(current, fraction)

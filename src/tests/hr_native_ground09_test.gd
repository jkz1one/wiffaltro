extends "res://src/tests/hr_shared_lifecycle09_test.gd"
## Synthetic terminal HR state plus real native sphere/ground contacts.
## Not an earned legal HR, paid-venue admission, visual apron or terminal-save witness.

var _native_contacts: int = 0
var _edge_departures: int = 0
var _case_trace: Dictionary = {}
var _trace_ball: BattedBallBody


func _ready() -> void:
	await _native_case(false)
	await _native_case(true)
	print(
		"HR_NATIVE_GROUND09 checks=",
		_checks,
		" failures=",
		_failures,
		" native_contacts=",
		_native_contacts,
		" edge_departures=",
		_edge_departures
	)
	get_tree().quit(0 if _failures == 0 and _native_contacts >= 2 and _edge_departures == 1 else 1)


func _native_case(edge: bool) -> void:
	var lab: LifecycleLab = _lifecycle_fixture(MatchState.Phase.PLAY_DEAD)
	lab.process_mode = Node.PROCESS_MODE_INHERIT
	lab.set_process(false)
	lab.set_physics_process(false)
	var ground: StaticBody3D = StaticBody3D.new()
	ground.set_meta(&"ball_surface", &"ground")
	ground.collision_layer = 1
	ground.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 0.2, 4.0 if edge else 20.0)
	shape.shape = box
	ground.position.y = -0.1
	ground.add_child(shape)
	lab.add_child(ground)
	var ball: BattedBallBody = lab._batted_ball
	var play: BallPlayState = lab._ball_play_resolver.state
	var old_contacts: int = _native_contacts
	_case_trace = {"edge": edge}
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0.0, 0.3 if edge else 0.6, -1.0 if edge else 0.0)
	launch.velocity = Vector3(0.0, 0.0, 10.0 if edge else 0.0)
	launch.orientation = Quaternion.IDENTITY
	_case_trace["launch_position"] = _vector(launch.position)
	_case_trace["launch_velocity"] = _vector(launch.velocity)
	# The inherited component scaffold is frozen, unlike ordinary fresh-body launch.
	# Replace only that synthetic scaffold before the physics witness begins.
	lab._home_run.cancel()
	ball.free()
	ball = BattedBallBody.new()
	lab._batted_ball = ball
	lab.add_child(ball)
	ball.surface_contact.connect(lab._on_batted_surface_contact)
	ball.surface_contact.connect(_native_contact)
	_trace_ball = ball
	var physics: Array = [
		ball.mass, ball.radius_m, ball.gravity_scale, ball.collision_layer, ball.collision_mask
	]
	_check(not ball.freeze, "native witness uses ordinary fresh unfrozen launch body")
	ball.launch(launch)
	var outcome: BallPlayOutcome = BallPlayOutcome.new()
	outcome.result = BallPlayOutcome.Result.HOME_RUN
	lab._home_run.resolve_ball(lab, outcome)
	_case_trace["actual_launch_velocity"] = _vector(ball.linear_velocity)
	var first_ground: float = -1.0
	var left_ground: bool = false
	var flight_reason: StringName = &""
	var flight_finished_at: float = -1.0
	var body_same_until_finish: bool = true
	var state_same: bool = true
	for frame: int in range(8 * Engine.physics_ticks_per_second):
		await get_tree().physics_frame
		if frame == 0:
			_case_trace["after_first_physics_velocity"] = _vector(ball.linear_velocity)
		if not lab._home_run.active:
			break
		body_same_until_finish = body_same_until_finish and lab._batted_ball == ball
		state_same = (
			state_same
			and lab._ball_play_resolver.state == play
			and play.dead
			and play.result_floor == BallPlayState.ResultFloor.HOME_RUN
			and not play.has_grounded
			and play.stadium_contacts.is_empty()
		)
		var before_velocity: Vector3 = ball.linear_velocity
		lab._home_run.advance(lab, 1.0 / Engine.physics_ticks_per_second)
		if first_ground < 0.0 and lab._home_run._ground_seen:
			first_ground = lab._home_run.flight_elapsed
		if (
			edge
			and lab._home_run._ground_seen
			and is_instance_valid(ball)
			and not ball.is_queued_for_deletion()
			and ball.global_position.z > 2.0 + ball.radius_m
			and not ball.get_colliding_bodies().has(ground)
		):
			left_ground = true
		if flight_finished_at < 0.0 and lab._home_run.flight_complete:
			flight_reason = lab._home_run.flight_end_reason
			flight_finished_at = lab._home_run.flight_elapsed
			_case_trace["flight_end_position"] = _vector(ball.global_position)
			_case_trace["flight_end_velocity"] = _vector(ball.linear_velocity)
			_case_trace["pre_finish_velocity"] = _vector(before_velocity)
			_check(
				(
					[
						ball.mass,
						ball.radius_m,
						ball.gravity_scale,
						ball.collision_layer,
						ball.collision_mask
					]
					== physics
				),
				"native landing leaves physics/collision configuration unchanged"
			)
	_case_trace.merge(
		{
			"contacts": _native_contacts - old_contacts,
			"first_ground_seconds": first_ground,
			"flight_finished_seconds": flight_finished_at,
			"flight_reason": str(flight_reason),
			"left_native_ground": left_ground,
			"cleanup_calls": lab.cleanup_calls
		},
		true
	)
	print("HR_NATIVE_GROUND09_CASE ", JSON.stringify(_case_trace))
	_trace_ball = null
	_check(
		_native_contacts > old_contacts and first_ground >= 0.0,
		"native contact, not assigned history, qualifies ground case edge=%s" % edge
	)
	_check(
		body_same_until_finish and state_same,
		"native post-terminal flight preserves body and scoring evidence"
	)
	_check(
		flight_finished_at >= first_ground + PitchBatLabHomeRun.LANDING_CONTEXT_SECONDS - 0.02,
		"native contact keeps bounded landing observation"
	)
	if edge:
		_edge_departures += int(left_ground)
		_check(
			(
				left_ground
				and flight_reason == &"timeout"
				and flight_finished_at >= PitchBatLabHomeRun.MAX_FLIGHT_SECONDS
			),
			"real native bounce off finite edge retains history and uses honest timeout"
		)
	else:
		_check(
			(
				flight_reason in [&"landed", &"rest"]
				and flight_finished_at < PitchBatLabHomeRun.MAX_FLIGHT_SECONDS
			),
			"real broad native ground completes landing before timeout"
		)
	_check(
		not lab._home_run.active and lab._batted_ball == null and lab.cleanup_calls == 1,
		"native flight and return retire through supported cleanup exactly once"
	)
	_dispose(lab)
	await get_tree().process_frame


func _native_contact(surface: StringName, point: Vector3) -> void:
	if surface == &"ground":
		_native_contacts += 1
		if not _case_trace.has("first_contact_position"):
			_case_trace["first_contact_position"] = _vector(point)
			_case_trace["first_contact_observed_velocity"] = _vector(_trace_ball.linear_velocity)


func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

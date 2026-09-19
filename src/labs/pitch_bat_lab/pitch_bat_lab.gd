extends Node3D

const PITCH_IDS: Array[StringName] = [
	&"pitch.overhand_four_seam",
	&"pitch.overhand_sinker",
	&"pitch.sidearm_sinker",
	&"pitch.overhand_slider",
	&"pitch.sidearm_slider",
	&"pitch.eephus",
	&"pitch.knuckleball",
	&"pitch.riser",
	&"pitch.drop",
]

const CONTACT_SWING_ID: StringName = &"swing.contact"
const POWER_SWING_ID: StringName = &"swing.power"
const BALL_SETUP_ID: StringName = &"ball_setup.fresh"
const FIELD_ID: StringName = &"field.starter_backyard"

const MOUND_ORIGIN: Vector3 = Vector3(0.0, 0.0, 13.716)
const DEFAULT_TARGET: Vector2 = Vector2(0.0, 1.05)
const DEFAULT_BATTING_AIM: Vector2 = Vector2(0.0, 1.05)

const ZONE_MIN_X: float = -0.43
const ZONE_MAX_X: float = 0.43
const ZONE_MIN_Y: float = 0.55
const ZONE_MAX_Y: float = 1.55
const AIM_STEP_M: float = 0.05
const BATTED_BALL_TIMEOUT_SECONDS: float = 9.0
const SETTLED_SPEED_MPS: float = 0.55
const SETTLED_HOLD_SECONDS: float = 0.65

var _pitch_actor: PitchFlightActor
var _batted_ball: BattedBallBody
var _ball_play_resolver: BallPlayResolver
var _field_definition: FieldDefinition
var _primary_fielder: FielderController
var _pitcher_marker: Node3D
var _base_state: BaseState = BaseState.new()
var _trajectory_draw: TrajectoryDebugDraw
var _contact_vector_draw: TrajectoryDebugDraw
var _trajectory_points: Array[Vector3] = []

var _pitch_target_marker: MeshInstance3D
var _batting_aim_marker: MeshInstance3D
var _camera: Camera3D
var _camera_mode: int = 0

var _status_label: Label
var _live_label: Label
var _config_label: Label
var _controls_label: Label

var _selected_pitch_index: int = 0
var _pitch_target: Vector2 = DEFAULT_TARGET
var _batting_aim: Vector2 = DEFAULT_BATTING_AIM
var _execution_quality: float = 1.0
var _fatigue: float = 0.0
var _throw_number: int = 0
var _swing_consumed: bool = false
var _fielder_anchor_index: int = 4
var _base_preset_index: int = 0
var _debug_launch_index: int = 0
var _primary_attempts: int = 0
var _pitcher_attempted: bool = false
var _fielding_cooldown_seconds: float = 0.0
var _settled_seconds: float = 0.0
var _previous_batted_position: Vector3 = Vector3.ZERO
var _last_fielding_text: String = "No defensive attempt"

var _last_nominal_release_speed_mps: float = 0.0
var _last_executed_release_speed_mps: float = 0.0
var _last_expected_plate_speed_mps: float = 0.0
var _last_movement_x_m: float = 0.0
var _last_movement_y_m: float = 0.0

func _ready() -> void:
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab loaded with invalid content.")
		return

	_field_definition = ContentDB.get_field(FIELD_ID)
	if _field_definition == null:
		push_error("Pitch/Bat Lab: starter field definition is missing.")
		return

	_build_environment()
	_build_pitch_actor()
	_build_defenders()
	_build_ball_play_resolver()
	_build_ui()
	_refresh_markers()
	_refresh_config()

	print(
		"Pitch/Bat Lab ready: %d pitch(es), %d swing profile(s)."
		% [
			ContentDB.pitch_by_id.size(),
			ContentDB.swing_by_id.size(),
		]
	)

	call_deferred("_throw_pitch")

func _process(_delta: float) -> void:
	if _batted_ball != null and _ball_play_resolver != null:
		if not _ball_play_resolver.state.dead:
			_live_label.text = (
				"BALL IN PLAY  t %.2f s   speed %.1f mph\n"
				+ "ball x %.1f / y %.1f / z %.1f   floor %s\n"
				+ "%s"
			) % [
				_ball_play_resolver.state.elapsed_seconds,
				_batted_ball.linear_velocity.length() * 2.236936,
				_batted_ball.global_position.x,
				_batted_ball.global_position.y,
				_batted_ball.global_position.z,
				_result_floor_name(_ball_play_resolver.state.result_floor),
				_last_fielding_text,
			]
		return

	if (
		_pitch_actor == null
		or not _pitch_actor.running
		or _pitch_actor.state == null
		or _live_label == null
	):
		return

	var state: PitchState = _pitch_actor.state
	_live_label.text = (
		"FLIGHT  t %.3f s   speed %.1f mph\n"
		+ "ball  x %.2f m   y %.2f m   z %.2f m"
	) % [
		state.elapsed_time,
		state.velocity.length() * 2.236936,
		state.position.x,
		state.position.y,
		state.position.z,
	]

func _physics_process(delta: float) -> void:
	if (
		_batted_ball == null
		or _ball_play_resolver == null
		or _ball_play_resolver.state == null
		or _ball_play_resolver.state.dead
	):
		return

	var current_ball_position: Vector3 = _batted_ball.global_position
	_ball_play_resolver.observe_segment(
		_previous_batted_position,
		current_ball_position
	)
	_previous_batted_position = current_ball_position
	if _ball_play_resolver.state.dead:
		return

	_ball_play_resolver.advance_time(delta)
	_fielding_cooldown_seconds = maxf(
		0.0,
		_fielding_cooldown_seconds - delta
	)

	_primary_fielder.plan_for_ball(
		_batted_ball.global_position,
		_batted_ball.linear_velocity,
		_ball_play_resolver.state.has_grounded
	)
	_try_pitcher_defense()
	_try_primary_fielder()

	if _batted_ball.linear_velocity.length() <= SETTLED_SPEED_MPS:
		_settled_seconds += delta
	else:
		_settled_seconds = 0.0

	if (
		_settled_seconds >= SETTLED_HOLD_SECONDS
		or _ball_play_resolver.state.elapsed_seconds
		>= BATTED_BALL_TIMEOUT_SECONDS
	):
		_ball_play_resolver.resolve_settled(_batted_ball.global_position)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		var requested_index: int = int(key_event.keycode - KEY_1)
		if requested_index < PITCH_IDS.size():
			_selected_pitch_index = requested_index
			_refresh_config()
			get_viewport().set_input_as_handled()
			return

	match key_event.keycode:
		KEY_SPACE:
			_throw_pitch()
		KEY_R:
			_reset_lab()
		KEY_V:
			_cycle_camera()
		KEY_C:
			_cycle_fielder_anchor()
		KEY_G:
			_cycle_base_preset()
		KEY_B:
			_launch_debug_batted_ball()

		KEY_LEFT:
			_adjust_pitch_target(Vector2(-AIM_STEP_M, 0.0))
		KEY_RIGHT:
			_adjust_pitch_target(Vector2(AIM_STEP_M, 0.0))
		KEY_UP:
			_adjust_pitch_target(Vector2(0.0, AIM_STEP_M))
		KEY_DOWN:
			_adjust_pitch_target(Vector2(0.0, -AIM_STEP_M))

		KEY_A:
			_adjust_batting_aim(Vector2(-AIM_STEP_M, 0.0))
		KEY_D:
			_adjust_batting_aim(Vector2(AIM_STEP_M, 0.0))
		KEY_W:
			_adjust_batting_aim(Vector2(0.0, AIM_STEP_M))
		KEY_S:
			_adjust_batting_aim(Vector2(0.0, -AIM_STEP_M))

		KEY_COMMA:
			_execution_quality = clampf(_execution_quality - 0.10, 0.0, 1.0)
			_refresh_config()
		KEY_PERIOD:
			_execution_quality = clampf(_execution_quality + 0.10, 0.0, 1.0)
			_refresh_config()
		KEY_BRACKETLEFT:
			_fatigue = clampf(_fatigue - 0.10, 0.0, 1.0)
			_refresh_config()
		KEY_BRACKETRIGHT:
			_fatigue = clampf(_fatigue + 0.10, 0.0, 1.0)
			_refresh_config()

		KEY_Z:
			_attempt_swing(CONTACT_SWING_ID)
		KEY_X:
			_attempt_swing(POWER_SWING_ID)

		_:
			return

	get_viewport().set_input_as_handled()

func _throw_pitch() -> void:
	var pitch: PitchDefinition = _selected_pitch()
	var ball_setup: BallSetupDefinition = ContentDB.get_ball_setup(BALL_SETUP_ID)

	if pitch == null or ball_setup == null:
		push_error("Pitch/Bat Lab: required prototype content is missing.")
		return

	_cleanup_batted_ball()
	_throw_number += 1
	_swing_consumed = false
	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	var target_position: Vector3 = Vector3(
		_pitch_target.x,
		_pitch_target.y,
		0.0
	)

	var base_parameters: PitchLaunchParameters = PitchAimSolver.solve(
		pitch,
		ball_setup,
		MOUND_ORIGIN,
		target_position,
		false,
		_throw_number
	)

	if base_parameters == null:
		_status_label.text = "Aim solver failed for %s." % pitch.display_name
		return

	_measure_nominal_pitch(base_parameters, target_position)

	var executed_parameters: PitchLaunchParameters = PitchExecutionModel.apply(
		base_parameters,
		_execution_quality,
		_fatigue,
		pitch.control_difficulty,
		pitch.execution_difficulty,
		pitch.category == PitchDefinition.Category.BREAKING,
		_throw_number * 1009 + _selected_pitch_index
	)
	_last_executed_release_speed_mps = executed_parameters.velocity.length()
	var executed_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(
			executed_parameters,
			target_position.z
		)
	)
	if executed_crossing.crossed:
		_last_expected_plate_speed_mps = executed_crossing.velocity.length()
	else:
		_last_expected_plate_speed_mps = 0.0

	_status_label.text = (
		"THROW %d — %s\n"
		+ "release %.1f → %.1f mph   predicted plate %.1f mph\n"
		+ "aero movement vs no-spin/asym baseline  X %+0.1f cm   Y %+0.1f cm"
	) % [
		_throw_number,
		pitch.display_name,
		_last_nominal_release_speed_mps * 2.236936,
		_last_executed_release_speed_mps * 2.236936,
		_last_expected_plate_speed_mps * 2.236936,
		_last_movement_x_m * 100.0,
		_last_movement_y_m * 100.0,
	]

	_pitch_actor.start_pitch(executed_parameters)

func _measure_nominal_pitch(
	base_parameters: PitchLaunchParameters,
	target_position: Vector3
) -> void:
	_last_nominal_release_speed_mps = base_parameters.velocity.length()

	var nominal_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(
			base_parameters,
			target_position.z
		)
	)

	var neutral_parameters: PitchLaunchParameters = base_parameters.copy()
	neutral_parameters.magnus_scale = 0.0
	neutral_parameters.perforation_force_scale = 0.0
	neutral_parameters.instability_strength = 0.0

	var neutral_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(
			neutral_parameters,
			target_position.z
		)
	)

	if nominal_crossing.crossed and neutral_crossing.crossed:
		_last_movement_x_m = (
			nominal_crossing.point.x - neutral_crossing.point.x
		)
		_last_movement_y_m = (
			nominal_crossing.point.y - neutral_crossing.point.y
		)
	else:
		_last_movement_x_m = 0.0
		_last_movement_y_m = 0.0

func _attempt_swing(profile_id: StringName) -> void:
	if (
		_pitch_actor == null
		or not _pitch_actor.running
		or _pitch_actor.state == null
		or _swing_consumed
	):
		return

	var profile: SwingProfileDefinition = ContentDB.get_swing(profile_id)
	if profile == null:
		push_error("Pitch/Bat Lab: swing profile missing: %s" % String(profile_id))
		return

	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile_id
	intent.aim_point = _batting_aim
	intent.handedness_left = false

	var result: ContactResult = ContactResolver.resolve(
		_pitch_actor.state,
		intent,
		profile
	)

	_swing_consumed = true
	_pitch_actor.stop_pitch(&"swing")

	var outcome_name: String = _contact_outcome_name(result.outcome)

	if result.outcome == ContactResult.Outcome.MISS:
		_status_label.text = (
			"%s — MISS\n"
			+ "bat aim x %.2f / y %.2f   ball x %.2f / y %.2f / z %.2f"
		) % [
			profile.display_name,
			_batting_aim.x,
			_batting_aim.y,
			result.contact_position.x,
			result.contact_position.y,
			result.contact_position.z,
		]
		return
	if result.outcome == ContactResult.Outcome.FOUL:
		_status_label.text = (
			"%s — FOUL\n"
			+ "quality %.0f%%   no fair ball-in-play"
		) % [
			profile.display_name,
			result.quality * 100.0,
		]
		return

	var exit_speed_mph: float = result.exit_velocity.length() * 2.236936
	_status_label.text = (
		"%s — %s   quality %.0f%%\n"
		+ "EV %.1f mph   launch %+0.1f°   spray %+0.1f°\n"
		+ "Physical ball launched into starter field."
	) % [
		profile.display_name,
		outcome_name,
		result.quality * 100.0,
		exit_speed_mph,
		result.launch_angle_degrees,
		result.spray_degrees,
	]

	var vector_end: Vector3 = (
		result.contact_position
		+ result.exit_velocity.normalized() * 4.0
	)
	var launch_points: Array[Vector3] = [
		result.contact_position,
		vector_end,
	]
	_contact_vector_draw.draw_polyline(launch_points)
	_start_ball_in_play(BattedBallLaunch.from_contact(result))

func _start_ball_in_play(launch_data: BattedBallLaunch) -> void:
	_cleanup_batted_ball()
	_pitch_actor.reset_pitch()

	_ball_play_resolver.start_play(_field_definition)
	_primary_attempts = 0
	_pitcher_attempted = false
	_fielding_cooldown_seconds = 0.0
	_settled_seconds = 0.0
	_last_fielding_text = "Defense tracking"

	_batted_ball = BattedBallBody.new()
	_batted_ball.name = "BattedBall"
	_batted_ball.configure_aero(ContentDB.get_ball_setup(BALL_SETUP_ID))
	_batted_ball.surface_contact.connect(_on_batted_surface_contact)
	add_child(_batted_ball)
	_batted_ball.launch(launch_data)
	_previous_batted_position = launch_data.position
	_primary_fielder.begin_play()

	_camera_mode = 3
	_apply_camera_mode()

func _launch_debug_batted_ball() -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0.0, 1.05, 0.35)
	var preset_name: String
	match _debug_launch_index:
		0:
			preset_name = "Grounder"
			launch.velocity = Vector3(-2.0, 1.5, 18.0)
			launch.angular_velocity = Vector3(18.0, 4.0, 0.0)
		1:
			preset_name = "Deep Air"
			launch.velocity = Vector3(3.0, 6.5, 12.5)
			launch.angular_velocity = Vector3(-70.0, 0.0, 5.0)
		2:
			preset_name = "Wall On Fly"
			launch.velocity = Vector3(-3.0, 7.0, 26.0)
			launch.angular_velocity = Vector3(-45.0, 0.0, 0.0)
		_:
			preset_name = "Home Run Arc"
			launch.velocity = Vector3(1.0, 14.5, 27.0)
			launch.angular_velocity = Vector3(-95.0, 0.0, 0.0)

	_debug_launch_index = (_debug_launch_index + 1) % 4
	_status_label.text = "DEBUG BIP — %s\nJolt launch with live field rules and defense" % preset_name
	_start_ball_in_play(launch)

func _on_batted_surface_contact(
	surface_id: StringName,
	position: Vector3
) -> void:
	if _ball_play_resolver == null:
		return
	match surface_id:
		&"ground":
			_ball_play_resolver.record_ground_contact(position)
		&"back_wall":
			_ball_play_resolver.record_back_wall_contact(position)
		&"live_object":
			_ball_play_resolver.record_live_object_contact(&"starter_pole")

func _try_pitcher_defense() -> void:
	if _pitcher_attempted or _fielding_cooldown_seconds > 0.0:
		return
	var ball_position: Vector3 = _batted_ball.global_position
	if not PitcherDefense.can_attempt(ball_position, MOUND_ORIGIN):
		return

	_pitcher_attempted = true
	var outcome: FieldingResolver.Outcome = PitcherDefense.resolve(
		ball_position,
		_batted_ball.linear_velocity,
		MOUND_ORIGIN,
		_ball_play_resolver.state.has_grounded,
		5
	)
	_apply_fielding_outcome(&"pitcher", MOUND_ORIGIN, outcome)

func _try_primary_fielder() -> void:
	if (
		_primary_attempts >= 2
		or _fielding_cooldown_seconds > 0.0
	):
		return
	var ball_position: Vector3 = _batted_ball.global_position
	var allowed_height: float = (
		1.15 if _ball_play_resolver.state.has_grounded else 2.35
	)
	if ball_position.y < 0.0 or ball_position.y > allowed_height:
		return
	var distance: float = _primary_fielder.horizontal_distance_to(ball_position)
	if distance > _primary_fielder.reach_m:
		return

	var outcome: FieldingResolver.Outcome = FieldingResolver.resolve(
		distance,
		_batted_ball.linear_velocity.length(),
		ball_position.y,
		_ball_play_resolver.state.has_grounded,
		_primary_fielder.fielding_rating,
		_primary_fielder.last_reaction_margin_seconds
	)
	_primary_attempts += 1
	_apply_fielding_outcome(
		&"primary_fielder",
		_primary_fielder.global_position,
		outcome
	)

func _apply_fielding_outcome(
	defender_id: StringName,
	defender_position: Vector3,
	outcome: FieldingResolver.Outcome
) -> void:
	_last_fielding_text = "%s: %s" % [
		String(defender_id).replace("_", " ").capitalize(),
		FieldingResolver.outcome_name(outcome),
	]
	match outcome:
		FieldingResolver.Outcome.CLEAN:
			_batted_ball.stop_and_freeze()
			_ball_play_resolver.record_clean_control(
				defender_id,
				_batted_ball.global_position,
				not _ball_play_resolver.state.has_grounded
			)
		FieldingResolver.Outcome.BOBBLE:
			_ball_play_resolver.record_bobble(defender_id)
			_batted_ball.deflect(
				DeflectionModel.velocity_after_bobble(
					_batted_ball.linear_velocity,
					defender_position,
					_batted_ball.global_position
				),
				DeflectionModel.spin_after_bobble(
					_batted_ball.angular_velocity
				)
			)
			_fielding_cooldown_seconds = 0.55
		FieldingResolver.Outcome.MISS:
			_ball_play_resolver.record_miss(defender_id)
			_fielding_cooldown_seconds = 0.35

func _on_ball_play_resolved(outcome: BallPlayOutcome) -> void:
	if _batted_ball != null:
		_batted_ball.stop_and_freeze()
	_primary_fielder.end_play()

	var runs_scored: int = 0
	var advancement_text: String = "Runners hold"
	if outcome.result == BallPlayOutcome.Result.OUT:
		if outcome.caught:
			var defender_rating: int = (
				5
				if _ball_play_resolver.state.last_defender_touch == &"pitcher"
				else _primary_fielder.fielding_rating
			)
			var tag_result: TagAdvanceResult = TagAdvanceResolver.resolve(
				_base_state,
				outcome.resolution_position,
				defender_rating
			)
			runs_scored = tag_result.runs_scored
			advancement_text = tag_result.description
	else:
		runs_scored = _base_state.advance_for_hit(
			outcome.result,
			StringName("batter.%d" % _throw_number)
		)
		advancement_text = "%d run(s) score" % runs_scored

	_status_label.text = (
		"%s — %s\n%s   %s\n%s"
	) % [
		outcome.display_name(),
		String(outcome.reason).replace("_", " ").capitalize(),
		_last_fielding_text,
		advancement_text,
		_base_state.display_string(),
	]
	_live_label.text = "PLAY DEAD   B: next diagnostic launch   SPACE: next pitch"
	_refresh_config()

func _on_trace_sampled(point: Vector3) -> void:
	_trajectory_points.append(point)
	_trajectory_draw.draw_polyline(_trajectory_points)

func _on_plate_crossed(
	point: Vector3,
	speed_mps: float,
	elapsed_seconds: float
) -> void:
	var target_error_x: float = point.x - _pitch_target.x
	var target_error_y: float = point.y - _pitch_target.y

	_status_label.text = (
		"PLATE — %s\n"
		+ "cross x %.2f / y %.2f   miss X %+0.1f cm / Y %+0.1f cm\n"
		+ "release %.1f → %.1f mph   plate %.1f mph   flight %.3f s"
	) % [
		_selected_pitch().display_name,
		point.x,
		point.y,
		target_error_x * 100.0,
		target_error_y * 100.0,
		_last_nominal_release_speed_mps * 2.236936,
		_last_executed_release_speed_mps * 2.236936,
		speed_mps * 2.236936,
		elapsed_seconds,
	]

func _on_flight_stopped(reason: StringName) -> void:
	if reason == &"plate_crossed" or reason == &"swing":
		return

	_status_label.text = (
		"Pitch stopped: %s\nSPACE: throw again"
		% String(reason)
	)

func _adjust_pitch_target(delta_xy: Vector2) -> void:
	_pitch_target.x = clampf(
		_pitch_target.x + delta_xy.x,
		ZONE_MIN_X,
		ZONE_MAX_X
	)
	_pitch_target.y = clampf(
		_pitch_target.y + delta_xy.y,
		ZONE_MIN_Y,
		ZONE_MAX_Y
	)
	_refresh_markers()
	_refresh_config()

func _adjust_batting_aim(delta_xy: Vector2) -> void:
	_batting_aim.x = clampf(
		_batting_aim.x + delta_xy.x,
		ZONE_MIN_X,
		ZONE_MAX_X
	)
	_batting_aim.y = clampf(
		_batting_aim.y + delta_xy.y,
		ZONE_MIN_Y,
		ZONE_MAX_Y
	)
	_refresh_markers()
	_refresh_config()

func _selected_pitch() -> PitchDefinition:
	return ContentDB.get_pitch(PITCH_IDS[_selected_pitch_index])

func _cycle_fielder_anchor() -> void:
	if (
		(_pitch_actor != null and _pitch_actor.running)
		or _ball_in_play_is_live()
	):
		_status_label.text = "Fielder position is locked during the play."
		return
	_fielder_anchor_index = (_fielder_anchor_index + 1) % 9
	if _primary_fielder != null:
		_primary_fielder.set_anchor(
			_field_definition.fielder_anchor(_fielder_anchor_index)
		)
	_refresh_config()

func _cycle_base_preset() -> void:
	if _ball_in_play_is_live():
		_status_label.text = "Base state is locked during the play."
		return
	_base_preset_index = (_base_preset_index + 1) % 3
	_base_state.set_debug_preset(_base_preset_index)
	_refresh_config()

func _ball_in_play_is_live() -> bool:
	return (
		_batted_ball != null
		and _ball_play_resolver != null
		and _ball_play_resolver.state != null
		and not _ball_play_resolver.state.dead
	)

func _cleanup_batted_ball() -> void:
	if _batted_ball != null:
		_batted_ball.queue_free()
		_batted_ball = null
	if _primary_fielder != null:
		_primary_fielder.end_play()
	_settled_seconds = 0.0

func _reset_lab() -> void:
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	_cleanup_batted_ball()

	_pitch_target = DEFAULT_TARGET
	_batting_aim = DEFAULT_BATTING_AIM
	_execution_quality = 1.0
	_fatigue = 0.0
	_swing_consumed = false
	_fielder_anchor_index = 4
	_base_preset_index = 0
	_base_state.clear()
	_primary_fielder.set_anchor(
		_field_definition.fielder_anchor(_fielder_anchor_index)
	)

	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	_status_label.text = "Lab reset. SPACE: throw"
	_live_label.text = ""
	_refresh_markers()
	_refresh_config()

func _cycle_camera() -> void:
	_camera_mode = (_camera_mode + 1) % 4
	_apply_camera_mode()

func _apply_camera_mode() -> void:
	match _camera_mode:
		0:
			_camera.position = Vector3(7.5, 4.2, -3.5)
			_camera.look_at(Vector3(0.0, 1.15, 6.5), Vector3.UP)
		1:
			_camera.position = Vector3(0.0, 1.65, -2.8)
			_camera.look_at(Vector3(0.0, 1.20, 8.0), Vector3.UP)
		2:
			_camera.position = Vector3(8.5, 2.5, 6.8)
			_camera.look_at(Vector3(0.0, 1.15, 6.8), Vector3.UP)
		3:
			_camera.position = Vector3(0.0, 13.0, -8.5)
			_camera.look_at(Vector3(0.0, 2.2, 13.5), Vector3.UP)

func _refresh_config() -> void:
	if _config_label == null:
		return

	var pitch: PitchDefinition = _selected_pitch()
	_config_label.text = (
		"PITCH %d/%d  %s\n"
		+ "target x %.2f / y %.2f   execution %.0f%%   fatigue %.0f%%\n"
		+ "bat aim x %.2f / y %.2f\n"
		+ "fielder %s   %s"
	) % [
		_selected_pitch_index + 1,
		PITCH_IDS.size(),
		pitch.display_name,
		_pitch_target.x,
		_pitch_target.y,
		_execution_quality * 100.0,
		_fatigue * 100.0,
		_batting_aim.x,
		_batting_aim.y,
		_field_definition.fielder_anchor_name(_fielder_anchor_index),
		_base_state.display_string(),
	]

func _refresh_markers() -> void:
	if _pitch_target_marker != null:
		_pitch_target_marker.position = Vector3(
			_pitch_target.x,
			_pitch_target.y,
			0.015
		)

	if _batting_aim_marker != null:
		_batting_aim_marker.position = Vector3(
			_batting_aim.x,
			_batting_aim.y,
			-0.015
		)

func _contact_outcome_name(outcome: int) -> String:
	match outcome:
		ContactResult.Outcome.FOUL:
			return "FOUL"
		ContactResult.Outcome.CONTACT:
			return "CONTACT"
		ContactResult.Outcome.PERFECT:
			return "PERFECT"
		_:
			return "MISS"

func _result_floor_name(result_floor: BallPlayState.ResultFloor) -> String:
	match result_floor:
		BallPlayState.ResultFloor.SINGLE:
			return "Single"
		BallPlayState.ResultFloor.DOUBLE:
			return "Double"
		BallPlayState.ResultFloor.TRIPLE:
			return "Triple"
		BallPlayState.ResultFloor.HOME_RUN:
			return "Home Run"
		_:
			return "None"

func _build_pitch_actor() -> void:
	_pitch_actor = PitchFlightActor.new()
	_pitch_actor.name = "PitchFlightActor"
	_pitch_actor.trace_every_substeps = 2
	_pitch_actor.trace_sampled.connect(_on_trace_sampled)
	_pitch_actor.plate_crossed.connect(_on_plate_crossed)
	_pitch_actor.flight_stopped.connect(_on_flight_stopped)
	add_child(_pitch_actor)

	_trajectory_draw = TrajectoryDebugDraw.new()
	_trajectory_draw.name = "TrajectoryTrace"
	_trajectory_draw.material_override = _make_unshaded_material(
		Color(1.0, 0.72, 0.12)
	)
	add_child(_trajectory_draw)

	_contact_vector_draw = TrajectoryDebugDraw.new()
	_contact_vector_draw.name = "ContactVector"
	_contact_vector_draw.material_override = _make_unshaded_material(
		Color(0.25, 0.90, 1.0)
	)
	add_child(_contact_vector_draw)

func _build_ball_play_resolver() -> void:
	_ball_play_resolver = BallPlayResolver.new()
	_ball_play_resolver.play_resolved.connect(_on_ball_play_resolved)

func _build_defenders() -> void:
	_primary_fielder = FielderController.new()
	_primary_fielder.name = "PrimaryFielder"
	add_child(_primary_fielder)
	_primary_fielder.set_anchor(
		_field_definition.fielder_anchor(_fielder_anchor_index)
	)

	_pitcher_marker = Node3D.new()
	_pitcher_marker.name = "PitcherDefender"
	_pitcher_marker.position = MOUND_ORIGIN
	add_child(_pitcher_marker)

	var pitcher_mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.31
	capsule.height = 1.72
	pitcher_mesh.mesh = capsule
	pitcher_mesh.position.y = 0.86
	pitcher_mesh.material_override = _make_material(Color(0.92, 0.30, 0.18))
	_pitcher_marker.add_child(pitcher_mesh)

func _build_environment() -> void:
	var geometry: StarterFieldLabGeometry = StarterFieldLabGeometry.new()
	geometry.name = "StarterFieldGeometry"
	add_child(geometry)
	geometry.build(
		_field_definition,
		MOUND_ORIGIN,
		ZONE_MIN_X,
		ZONE_MAX_X,
		ZONE_MIN_Y,
		ZONE_MAX_Y
	)
	_pitch_target_marker = geometry.pitch_target_marker
	_batting_aim_marker = geometry.batting_aim_marker

	_camera = Camera3D.new()
	_camera.name = "LabCamera"
	_camera.current = true
	add_child(_camera)
	_apply_camera_mode()

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "DebugUI"
	add_child(canvas)

	_config_label = Label.new()
	_config_label.position = Vector2(20.0, 16.0)
	_config_label.add_theme_font_size_override("font_size", 19)
	canvas.add_child(_config_label)

	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 125.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.text = "Loading Pitch Lab..."
	canvas.add_child(_status_label)

	_live_label = Label.new()
	_live_label.position = Vector2(20.0, 230.0)
	_live_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(_live_label)

	_controls_label = Label.new()
	_controls_label.position = Vector2(20.0, 565.0)
	_controls_label.add_theme_font_size_override("font_size", 14)
	_controls_label.text = (
		"1–9 pitch   SPACE throw   arrows pitch target   WASD bat aim\n"
		+ "Z Contact Swing   X Power Swing   ,/. execution   [/] fatigue\n"
		+ "C fielder position   G base preset   B BIP diagnostic   V camera   R reset"
	)
	canvas.add_child(_controls_label)

	var footer: Label = Label.new()
	footer.position = Vector2(20.0, 670.0)
	footer.add_theme_font_size_override("font_size", 13)
	footer.text = (
		"Phase 2 mechanics lab — yellow Safe, cyan Deep Air, wall top HR boundary."
	)
	canvas.add_child(footer)

func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

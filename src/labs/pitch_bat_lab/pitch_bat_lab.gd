class_name PitchBatLab
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
const DEBUG_PLAYER_ID: StringName = &"player.debug_pitcher"
const PLAYER_TEAM_NAME: String = "PLAYER"
const RIVAL_TEAM_NAME: String = "RIVAL"

const MOUND_ORIGIN: Vector3 = Vector3(0.0, 0.0, 13.716)
const DEFAULT_TARGET: Vector2 = Vector2(0.0, 1.05)
const DEFAULT_BATTING_AIM: Vector2 = Vector2(0.0, 1.05)

const ZONE_MIN_X: float = -0.43
const ZONE_MAX_X: float = 0.43
const ZONE_MIN_Y: float = 0.55
const ZONE_MAX_Y: float = 1.55
const PITCH_AIM_MIN_X: float = -0.75
const PITCH_AIM_MAX_X: float = 0.75
const PITCH_AIM_MIN_Y: float = 0.30
const PITCH_AIM_MAX_Y: float = 1.85
const BATTING_AIM_MIN_X: float = -0.75
const BATTING_AIM_MAX_X: float = 0.75
const BATTING_AIM_MIN_Y: float = 0.30
const BATTING_AIM_MAX_Y: float = 1.85
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
var _debug_base_state: BaseState = BaseState.new()
var _base_state: BaseState = _debug_base_state
var _match_state: MatchState
var _trajectory_draw: TrajectoryDebugDraw
var _contact_vector_draw: TrajectoryDebugDraw
var _trajectory_points: Array[Vector3] = []

var _pitch_target_marker: MeshInstance3D
var _batting_aim_marker: Node3D
var _camera: Camera3D
var _camera_mode: int = 0
var _camera_director: MatchCameraDirector

var _status_label: Label
var _live_label: Label
var _config_label: Label
var _controls_label: Label
var _scoreboard_label: Label
var _action_label: Label

var _selected_pitch_index: int = 0
var _pitch_target: Vector2 = DEFAULT_TARGET
var _batting_aim: Vector2 = DEFAULT_BATTING_AIM
var _execution_quality: float = 1.0
var _fatigue: float = 0.0
var _pitch_effort: float = 1.0
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
var _match_mode: bool = true
var _debug_overlay_visible: bool = false
var _ai_swing_decided: bool = false
var _last_ai_pitch_index: int = -1
var _release_controller: PitchReleaseController
var _pending_release_quality: float = 1.0
var _last_release_quality: float = 1.0
var _last_release_offset_seconds: float = 0.0
var _active_play_record: PlayRecord
var _play_records: Array[PlayRecord] = []

func _ready() -> void:
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab loaded with invalid content.")
		return

	_field_definition = ContentDB.get_field(FIELD_ID)
	if _field_definition == null:
		push_error("Pitch/Bat Lab: starter field definition is missing.")
		return

	PitchBatLabPresentation.build_environment(self)
	PitchBatLabPresentation.build_pitch_actor(self)
	PitchBatLabPresentation.build_defenders(self)
	_build_ball_play_resolver()
	PitchBatLabPresentation.build_ui(self)
	PitchBatLabFeelSupport.initialize(self)
	_start_new_match()
	_refresh_markers()
	_refresh_config()

	print(
		"Pitch/Bat Lab ready: %d pitch(es), %d swing profile(s)."
		% [
			ContentDB.pitch_by_id.size(),
			ContentDB.swing_by_id.size(),
		]
	)


func _process(delta: float) -> void:
	PitchBatLabFeelSupport.update(self, delta)
	if _match_mode and _match_state != null:
		if _match_state.phase != MatchState.Phase.GAME_END:
			_match_state.elapsed_seconds += delta
		MatchLabSupport.try_ai_swing(self)

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
				PitchBatLabPresentation.result_floor_name(
					_ball_play_resolver.state.result_floor
				),
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

func _unhandled_input(event: InputEvent) -> void:
	PitchBatLabInput.handle(self, event)

func _throw_pitch() -> void:
	if _match_mode:
		if _match_state == null or not _match_state.begin_pitch():
			return
		if _player_is_batting():
			MatchLabSupport.apply_ai_pitch_choice(self)
			_pending_release_quality = 1.0
			_last_release_offset_seconds = 0.0

	var pitch: PitchDefinition = _selected_pitch()
	var ball_setup: BallSetupDefinition = ContentDB.get_ball_setup(BALL_SETUP_ID)

	if pitch == null or ball_setup == null:
		push_error("Pitch/Bat Lab: required prototype content is missing.")
		return

	_cleanup_batted_ball()
	_throw_number += 1
	_swing_consumed = false
	_ai_swing_decided = false
	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	var target_position: Vector3 = Vector3(
		_pitch_target.x,
		_pitch_target.y,
		0.0
	)

	var launch_pitch: PitchDefinition = pitch
	var is_left_handed: bool = false
	var execution_quality: float = _execution_quality
	var applied_fatigue: float = _fatigue
	if _match_mode:
		var pitcher_state: PlayerMatchState = _match_state.pitcher()
		pitcher_state.spend_stamina(
			MatchLabSupport.stamina_cost(pitch, _pitch_effort)
		)
		applied_fatigue = maxf(
			pitcher_state.fatigue_ratio(),
			_fatigue
		)
		var authored_quality: float = (
			_pending_release_quality if _player_is_pitching() else 1.0
		)
		execution_quality = minf(
			authored_quality,
			0.86 + float(pitcher_state.definition.control) * 0.014
		)
		execution_quality = maxf(
			0.0,
			execution_quality
			- MatchLabSupport.execution_quality_penalty(_pitch_effort)
		)
		is_left_handed = (
			pitcher_state.definition.throws
			== PlayerDefinition.Handedness.LEFT
		)
		launch_pitch = MatchLabSupport.rated_pitch(
			pitch,
			pitcher_state.definition,
			_pitch_effort
		)
	else:
		var debug_pitcher: PlayerDefinition = ContentDB.get_player(DEBUG_PLAYER_ID)
		launch_pitch = MatchLabSupport.rated_pitch(
			pitch,
			debug_pitcher,
			_pitch_effort
		)

	var base_parameters: PitchLaunchParameters = PitchAimSolver.solve(
		launch_pitch,
		ball_setup,
		MOUND_ORIGIN,
		target_position,
		is_left_handed,
		_throw_number
	)

	if base_parameters == null:
		_status_label.text = "Aim solver failed for %s." % pitch.display_name
		return

	PitchBatLabFeelSupport.measure_nominal_pitch(
		self,
		base_parameters,
		target_position
	)

	var executed_parameters: PitchLaunchParameters = PitchExecutionModel.apply(
		base_parameters,
		execution_quality,
		applied_fatigue,
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
	_last_release_quality = execution_quality
	PitchBatLabFeelSupport.start_record(
		self,
		pitch,
		applied_fatigue,
		execution_quality,
		executed_parameters.seed
	)
	_pending_release_quality = 1.0

	_status_label.text = (
		"THROW %d — %s%s\n"
		+ "release %.1f → %.1f mph   predicted plate %.1f mph\n"
		+ "release %s   aero movement X %+0.1f cm   Y %+0.1f cm"
	) % [
		_throw_number,
		pitch.display_name,
		("   fatigue %.0f%%" % (applied_fatigue * 100.0)) if _match_mode else "",
		_last_nominal_release_speed_mps * 2.236936,
		_last_executed_release_speed_mps * 2.236936,
		_last_expected_plate_speed_mps * 2.236936,
		PitchReleaseController.grade_name(execution_quality),
		_last_movement_x_m * 100.0,
		_last_movement_y_m * 100.0,
	]

	_pitch_actor.start_pitch(executed_parameters)
	_refresh_config()

func _handle_match_advance() -> void:
	if _match_state == null or _ball_in_play_is_live():
		return
	match _match_state.phase:
		MatchState.Phase.PRE_PITCH:
			_throw_pitch()
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION:
			var changed_half: bool = (
				_match_state.phase == MatchState.Phase.INNING_TRANSITION
			)
			_cleanup_batted_ball()
			_match_state.continue_after_dead_ball()
			_base_state = _match_state.bases
			if changed_half:
				_selected_pitch_index = 0
				_pitch_effort = 1.0
				MatchLabSupport.assign_ai_defense_for_half(self)
			_apply_defensive_assignment()
			_apply_role_camera()
			if _match_state.phase == MatchState.Phase.GAME_END:
				_status_label.text = "%s\nR: new match" % _match_state.last_event
			else:
				_status_label.text = (
					"%s\nSPACE: start next pitch" % _match_state.last_event
				)
			_refresh_markers()
			_refresh_config()
		MatchState.Phase.GAME_END:
			_status_label.text = "%s\nR: new match" % _match_state.last_event

func _attempt_swing(profile_id: StringName) -> void:
	_resolve_swing(profile_id, _batting_aim)

func _resolve_swing(
	profile_id: StringName,
	aim_point: Vector2
) -> void:
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
	intent.aim_point = aim_point
	var contact_rating: int = 5
	var power_rating: int = 5
	if _match_mode:
		var batter_definition: PlayerDefinition = (
			_match_state.batter().definition
		)
		intent.handedness_left = (
			batter_definition.bats == PlayerDefinition.Handedness.LEFT
		)
		contact_rating = batter_definition.contact
		power_rating = batter_definition.power

	var result: ContactResult = ContactResolver.resolve(
		_pitch_actor.state,
		intent,
		profile,
		contact_rating,
		power_rating
	)
	PitchBatLabFeelSupport.note_swing(self, profile_id, aim_point, result)

	_swing_consumed = true
	_pitch_actor.stop_pitch(&"swing")

	var outcome_name: String = PitchBatLabPresentation.contact_outcome_name(
		result.outcome
	)

	if result.outcome == ContactResult.Outcome.MISS:
		if _match_mode:
			_match_state.record_strike(true)
		_status_label.text = (
			"%s — %s\n"
			+ "timing %s   aim %s   ball x %.2f / y %.2f / z %.2f"
		) % [
			profile.display_name,
			result.miss_reason_name(),
			result.timing_name(),
			result.aim_name(),
			result.contact_position.x,
			result.contact_position.y,
			result.contact_position.z,
		]
		PitchBatLabFeelSupport.finish_record(self, &"swinging_strike")
		_finish_non_contact_pitch()
		return
	if result.outcome == ContactResult.Outcome.FOUL:
		if _match_mode:
			_match_state.record_foul()
		_status_label.text = (
			"%s — FOUL\n"
			+ "quality %.0f%%   no fair ball-in-play"
		) % [
			profile.display_name,
			result.quality * 100.0,
		]
		PitchBatLabFeelSupport.finish_record(self, &"foul")
		_finish_non_contact_pitch()
		return

	var exit_speed_mph: float = result.exit_velocity.length() * 2.236936
	_status_label.text = (
		"%s — %s   quality %.0f%%\n"
		+ "timing %s   aim %s\n"
		+ "EV %.1f mph   launch %+0.1f°   spray %+0.1f°\n"
		+ "Physical ball launched into starter field."
	) % [
		profile.display_name,
		outcome_name,
		result.quality * 100.0,
		result.timing_name(),
		result.aim_name(),
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

func _finish_non_contact_pitch() -> void:
	if not _match_mode:
		return
	_live_label.text = "PLAY DEAD   SPACE: continue"
	_refresh_config()

func _start_ball_in_play(launch_data: BattedBallLaunch) -> void:
	_cleanup_batted_ball()
	_pitch_actor.reset_pitch()

	_ball_play_resolver.start_play(_field_definition)
	_primary_attempts = 0
	_pitcher_attempted = false
	_fielding_cooldown_seconds = 0.0
	_settled_seconds = 0.0
	_last_fielding_text = "Defense tracking"
	if _match_mode:
		_match_state.begin_ball_in_play()
		_apply_defensive_assignment()

	_batted_ball = BattedBallBody.new()
	_batted_ball.name = "BattedBall"
	_batted_ball.configure_aero(ContentDB.get_ball_setup(BALL_SETUP_ID))
	_batted_ball.surface_contact.connect(_on_batted_surface_contact)
	add_child(_batted_ball)
	_batted_ball.launch(launch_data)
	_previous_batted_position = launch_data.position
	_primary_fielder.begin_play()

	_camera_mode = 3
	PitchBatLabPresentation.apply_camera_mode(self)

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
		MatchLabSupport.pitcher_fielding_rating(self)
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
		if outcome.caught and (not _match_mode or _match_state.outs < 2):
			var defender_rating: int = (
				MatchLabSupport.pitcher_fielding_rating(self)
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
		if _match_mode:
			_match_state.record_ball_in_play_out(
				runs_scored,
				outcome.display_name()
			)
	else:
		if _match_mode:
			runs_scored = _match_state.record_hit(outcome.result)
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
	_live_label.text = (
		"PLAY DEAD   SPACE: continue"
		if _match_mode
		else "PLAY DEAD   B: next diagnostic launch   SPACE: next pitch"
	)
	PitchBatLabFeelSupport.finish_record(
		self,
		StringName(outcome.display_name().to_snake_case()),
		runs_scored
	)
	_refresh_config()

func _on_trace_sampled(point: Vector3) -> void:
	_trajectory_points.append(point)
	_trajectory_draw.draw_polyline(_trajectory_points)

func _on_plate_crossed(
	point: Vector3,
	speed_mps: float,
	elapsed_seconds: float
) -> void:
	PitchBatLabFeelSupport.note_crossing(self, point, speed_mps)
	var target_error_x: float = point.x - _pitch_target.x
	var target_error_y: float = point.y - _pitch_target.y
	var call_text: String = ""
	if _match_mode:
		var in_zone: bool = (
			point.x >= ZONE_MIN_X
			and point.x <= ZONE_MAX_X
			and point.y >= ZONE_MIN_Y
			and point.y <= ZONE_MAX_Y
		)
		var call: StringName = _match_state.record_called_pitch(in_zone)
		call_text = "   %s" % String(call).replace("_", " ").to_upper()

	_status_label.text = (
		"PLATE — %s%s\n"
		+ "cross x %.2f / y %.2f   miss X %+0.1f cm / Y %+0.1f cm\n"
		+ "release %.1f → %.1f mph   plate %.1f mph   flight %.3f s"
	) % [
		_selected_pitch().display_name,
		call_text,
		point.x,
		point.y,
		target_error_x * 100.0,
		target_error_y * 100.0,
		_last_nominal_release_speed_mps * 2.236936,
		_last_executed_release_speed_mps * 2.236936,
		speed_mps * 2.236936,
		elapsed_seconds,
	]
	if _match_mode:
		_live_label.text = "PLAY DEAD   SPACE: continue"
		_refresh_config()
	PitchBatLabFeelSupport.finish_record(
		self,
		StringName(call_text.strip_edges().to_lower().replace(" ", "_"))
		if not call_text.is_empty()
		else &"plate_crossed"
	)

func _on_flight_stopped(reason: StringName) -> void:
	if reason == &"plate_crossed" or reason == &"swing":
		return
	if (
		_match_mode
		and _match_state != null
		and _match_state.phase == MatchState.Phase.PITCH_IN_FLIGHT
	):
		_match_state.record_ball()
		PitchBatLabFeelSupport.finish_record(self, &"ball_no_crossing")
		_live_label.text = "PLAY DEAD   SPACE: continue"
		_refresh_config()

	_status_label.text = (
		"Pitch stopped: %s\nSPACE: continue"
		% String(reason)
	)

func _adjust_pitch_target(delta_xy: Vector2) -> void:
	_pitch_target.x = clampf(
		_pitch_target.x + delta_xy.x,
		PITCH_AIM_MIN_X,
		PITCH_AIM_MAX_X
	)
	_pitch_target.y = clampf(
		_pitch_target.y + delta_xy.y,
		PITCH_AIM_MIN_Y,
		PITCH_AIM_MAX_Y
	)
	_refresh_markers()
	_refresh_config()

func _adjust_pitch_effort(delta: float) -> void:
	_pitch_effort = clampf(
		_pitch_effort + delta,
		MatchLabSupport.MIN_EFFORT,
		MatchLabSupport.MAX_EFFORT
	)
	_refresh_config()

func _adjust_batting_aim(delta_xy: Vector2) -> void:
	_batting_aim.x = clampf(
		_batting_aim.x + delta_xy.x,
		BATTING_AIM_MIN_X,
		BATTING_AIM_MAX_X
	)
	_batting_aim.y = clampf(
		_batting_aim.y + delta_xy.y,
		BATTING_AIM_MIN_Y,
		BATTING_AIM_MAX_Y
	)
	_refresh_markers()
	_refresh_config()

func _selected_pitch() -> PitchDefinition:
	if _match_mode:
		var options: Array[PitchDefinition] = _current_pitch_options()
		if options.is_empty():
			return null
		_selected_pitch_index = clampi(
			_selected_pitch_index,
			0,
			options.size() - 1
		)
		return options[_selected_pitch_index]
	return ContentDB.get_pitch(PITCH_IDS[_selected_pitch_index])

func _current_pitch_options() -> Array[PitchDefinition]:
	var result: Array[PitchDefinition] = []
	if _match_state == null or _match_state.pitcher() == null:
		return result
	for pitch in _match_state.pitcher().definition.starting_pitches:
		if pitch != null:
			result.append(pitch)
	if result.is_empty():
		var fallback: PitchDefinition = ContentDB.get_pitch(PITCH_IDS[0])
		if fallback != null:
			result.append(fallback)
	return result

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
	PitchBatLabFeelSupport.cancel_release(self)
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	_cleanup_batted_ball()

	_pitch_target = DEFAULT_TARGET
	_batting_aim = DEFAULT_BATTING_AIM
	_execution_quality = 1.0
	_fatigue = 0.0
	_pitch_effort = 1.0
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

func _start_new_match() -> void:
	PitchBatLabFeelSupport.cancel_release(self)
	PitchBatLabFeelSupport.clear_records(self)
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	_cleanup_batted_ball()
	_match_state = MatchLabSupport.create_match(
		DEBUG_PLAYER_ID,
		PLAYER_TEAM_NAME,
		RIVAL_TEAM_NAME
	)
	_base_state = _match_state.bases
	_throw_number = 0
	_selected_pitch_index = 0
	_pitch_target = DEFAULT_TARGET
	_batting_aim = DEFAULT_BATTING_AIM
	_fatigue = 0.0
	_execution_quality = 1.0
	_pitch_effort = 1.0
	_swing_consumed = false
	_ai_swing_decided = false
	_last_ai_pitch_index = -1
	_fielder_anchor_index = 4
	_trajectory_points.clear()
	if _trajectory_draw != null:
		_trajectory_draw.clear()
	if _contact_vector_draw != null:
		_contact_vector_draw.clear()
	_apply_defensive_assignment()
	_apply_role_camera()
	_status_label.text = "TOP 1 — Player batting\nSPACE: request first pitch"
	_live_label.text = ""
	_refresh_markers()
	_refresh_config()

func _player_is_batting() -> bool:
	return _match_mode and _match_state != null and _match_state.top_half

func _player_is_pitching() -> bool:
	return _match_mode and _match_state != null and not _match_state.top_half

func _cycle_pitcher(direction: int) -> void:
	if not _player_is_pitching() or not _match_state.can_change_defense():
		_status_label.text = "Pitching changes are allowed only between batters."
		return
	_match_state.defensive_team().cycle_pitcher(direction)
	_selected_pitch_index = 0
	_apply_defensive_assignment()
	_refresh_config()

func _cycle_primary_fielder() -> void:
	if not _player_is_pitching() or not _match_state.can_change_defense():
		_status_label.text = "Fielder changes are allowed only between batters."
		return
	_match_state.defensive_team().cycle_fielder(1)
	_apply_defensive_assignment()
	_refresh_config()

func _apply_defensive_assignment() -> void:
	if not _match_mode or _match_state == null:
		return
	var fielder_state: PlayerMatchState = _match_state.fielder()
	if fielder_state != null and _primary_fielder != null:
		_primary_fielder.fielding_rating = fielder_state.definition.fielding
		_primary_fielder.set_anchor(
			_field_definition.fielder_anchor(_fielder_anchor_index)
		)

func _toggle_match_mode() -> void:
	_match_mode = not _match_mode
	if _match_mode:
		_start_new_match()
	else:
		_debug_overlay_visible = true
		_base_state = _debug_base_state
		_reset_lab()
	_apply_role_camera()
	_refresh_markers()
	_refresh_config()

func _toggle_debug_overlay() -> void:
	_debug_overlay_visible = not _debug_overlay_visible
	_config_label.visible = _debug_overlay_visible
	_live_label.visible = _debug_overlay_visible
	_trajectory_draw.visible = _debug_overlay_visible
	_contact_vector_draw.visible = _debug_overlay_visible
	_refresh_config()

func _cycle_camera() -> void:
	PitchBatLabPresentation.cycle_camera(self)

func _apply_role_camera() -> void:
	PitchBatLabPresentation.apply_role_camera(self)

func _refresh_config() -> void:
	PitchBatLabPresentation.refresh(self)

func _refresh_markers() -> void:
	PitchBatLabPresentation.refresh_markers(self)

func _build_ball_play_resolver() -> void:
	_ball_play_resolver = BallPlayResolver.new()
	_ball_play_resolver.play_resolved.connect(_on_ball_play_resolved)

class_name PitchBatLab
extends Node3D

signal match_return_requested
signal menu_exit_requested


@warning_ignore_start("unused_private_class_variable")
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
const DEFAULT_FIELDER_ANCHOR_INDEX: int = 3
var _configured_match: MatchState
var _managed_match: bool = false
var _player_home: bool = false
var _pitch_actor: PitchFlightActor
var _batted_ball: BattedBallBody
var _ball_play_resolver: BallPlayResolver
var _field_definition: FieldDefinition
var _field_id: StringName = FIELD_ID
var _primary_fielder: FielderController
var _pitcher_marker: Node3D
var _pitcher_avatar: PlayerAvatar
var _batter_avatar: PlayerAvatar
var _bat_actor: BatActor
var _debug_base_state: BaseState = BaseState.new()
var _base_state: BaseState = _debug_base_state
var _match_state: MatchState
var _trajectory_draw: TrajectoryDebugDraw
var _contact_vector_draw: TrajectoryDebugDraw
var _trajectory_points: Array[Vector3] = []
var _pitch_target_marker: MeshInstance3D
var _batting_aim_marker: Node3D
var _receiver_marker: Node3D
var _camera: Camera3D
var _camera_mode: int = 0
var _camera_director: MatchCameraDirector
var _hud_anchor_index: int = 0
var _world_environment: WorldEnvironment
var _sky_backdrop_enabled: bool = true
var _match_presentation_director: MatchPresentationDirector
var _status_label: Label
var _live_label: Label
var _config_label: Label
var _controls_label: Label
var _scorebug: MatchScorebug
var _event_panel: Panel
var _action_label: Label
var _display_menu_button: Button
var _display_menu_panel: VBoxContainer
var _hud_anchor_button: Button
var _backdrop_button: Button
var _display_menu_open: bool = false
var _pause_menu: PitchBatLabPauseMenu
var _pitch_picker: PitchPicker
var _sounds_muted: bool = false
var _sounds: PlaySounds
var _ball_visibility: BallVisibility
var _pitch_feedback: PitchFeedback
var _home_run: PitchBatLabHomeRun = PitchBatLabHomeRun.new()
var _pitch_release_bar: ProgressBar
var _pitch_release_ideal_marker: ColorRect
var _presentation_backdrop: ColorRect
var _presentation_title: Label
var _presentation_subtitle: Label
var _pitching_staff_toggle_button: Button
var _pitching_staff_panel: VBoxContainer
var _pitcher_buttons: Array[Button] = []
var _field_setup_toggle_button: Button
var _field_setup_panel: VBoxContainer
var _field_anchor_buttons: Array[Button] = []
var _selected_pitch_index: int = 0
var _pitch_target: Vector2 = DEFAULT_TARGET
var _batting_aim: Vector2 = DEFAULT_BATTING_AIM
var _execution_quality: float = 1.0
var _fatigue: float = 0.0
var _pitch_effort: float = 1.0
var _throw_number: int = 0
var _swing_consumed: bool = false
var _swing_tracker: SwingContactTracker
var _pending_swing_miss: ContactResult
var _fielder_anchor_index: int = DEFAULT_FIELDER_ANCHOR_INDEX
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
var _pending_release_overdrive: float = 0.0
var _last_release_quality: float = 1.0
var _last_release_offset_seconds: float = 0.0
var _last_release_overdrive: float = 0.0
var _last_exit_speed_mph: float = 0.0
var _active_play_record: PlayRecord
var _play_records: Array[PlayRecord] = []
var _record_export: PlayRecordExport = PlayRecordExport.new()
var _at_bat_cadence: AtBatCadenceController
var _batter_approach: BatterApproachModel
var _ai_pitch_preselected: bool = false
var _awaiting_batter_confirm: bool = true
var _last_ai_awareness: float = 0.0
var _last_ai_read_text: String = "No read"
var _field_setup_active: bool = false
var _pitching_staff_active: bool = false
var _debug_paused: bool = false
var _status_before_pause: String = ""
var _match_suspend_snapshot: Dictionary = {}
@warning_ignore_restore("unused_private_class_variable")
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab loaded with invalid content.")
		return

	_field_definition = ContentDB.get_field(_field_id)
	if _field_definition == null:
		push_error("Pitch/Bat Lab: configured field definition is missing.")
		return

	PitchBatLabSettings.restore(self)
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
		(
			"Pitch/Bat Lab ready: %d pitch(es), %d swing profile(s)."
			% [
				ContentDB.pitch_by_id.size(),
				ContentDB.swing_by_id.size(),
			]
		)
	)

func _exit_tree() -> void:
	if _debug_paused:
		get_tree().paused = false


func _process(delta: float) -> void:
	PitchBatLabFeelSupport.update(self, delta)
	if _debug_paused:
		return
	if _match_mode and _match_state != null:
		if (
			_match_state.phase != MatchState.Phase.GAME_END
			and (
				_match_presentation_director == null
				or not _match_presentation_director.blocks_gameplay()
			)
		):
			_match_state.elapsed_seconds += delta
		MatchLabSupport.try_ai_swing(self)

	if _batted_ball != null and _ball_play_resolver != null and _ball_play_resolver.state != null:
		if not _ball_play_resolver.state.dead:
			_live_label.text = (
				(
					"BALL IN PLAY  t %.2f s   speed %.1f mph\n"
					+ "ball x %.1f / y %.1f / z %.1f   floor %s\n"
					+ "%s"
				)
				% [
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
			)
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
		("FLIGHT  t %.3f s   speed %.1f mph\n" + "ball  x %.2f m   y %.2f m   z %.2f m")
		% [
			state.elapsed_time,
			state.velocity.length() * 2.236936,
			state.position.x,
			state.position.y,
			state.position.z,
		]
	)


func _physics_process(delta: float) -> void:
	if _debug_paused:
		return
	if (
		_batted_ball == null
		or _ball_play_resolver == null
		or _ball_play_resolver.state == null
		or _ball_play_resolver.state.dead
	):
		return

	var previous_ball_position: Vector3 = _previous_batted_position
	var current_ball_position: Vector3 = _batted_ball.global_position
	PitchBatLabDefenseSupport.advance_pitcher(self, delta)
	# Resolve contact at its swept position before observing the remaining
	# segment; the pitcher helper preserves floors reached before contact.
	_try_pitcher_defense(previous_ball_position, current_ball_position)
	if _ball_play_resolver.state.dead:
		_previous_batted_position = current_ball_position
		return
	_ball_play_resolver.observe_segment(previous_ball_position, current_ball_position)
	_previous_batted_position = current_ball_position
	if _ball_play_resolver.state.dead:
		return

	_ball_play_resolver.advance_time(delta)
	_fielding_cooldown_seconds = maxf(0.0, _fielding_cooldown_seconds - delta)

	_primary_fielder.plan_for_ball(
		_batted_ball.global_position,
		_batted_ball.linear_velocity,
		_ball_play_resolver.state.has_grounded
	)
	_try_primary_fielder()

	if _batted_ball.linear_velocity.length() <= SETTLED_SPEED_MPS:
		_settled_seconds += delta
	else:
		_settled_seconds = 0.0

	if (
		_settled_seconds >= SETTLED_HOLD_SECONDS
		or _ball_play_resolver.state.elapsed_seconds >= BATTED_BALL_TIMEOUT_SECONDS
	):
		_ball_play_resolver.resolve_settled(_batted_ball.global_position)


func _unhandled_input(event: InputEvent) -> void:
	PitchBatLabInput.handle(self, event)

func _input(event: InputEvent) -> void:
	if _debug_paused:
		PitchBatLabInput.cancel_paused_release(self, event)


func _throw_pitch() -> void:
	if _field_setup_active or _pitching_staff_active:
		return
	if _pitcher_marker != null:
		_pitcher_marker.position = MOUND_ORIGIN
		_pitcher_marker.rotation = Vector3.ZERO
	if _pitcher_avatar != null:
		_pitcher_avatar.reset_pose()
	if _match_mode:
		if _match_state == null or not _match_state.begin_pitch():
			return
		if _player_is_batting():
			if not _ai_pitch_preselected:
				MatchLabSupport.apply_ai_pitch_choice(self)
			_ai_pitch_preselected = false
			_pending_release_quality = 1.0
			_last_release_offset_seconds = 0.0

	var pitch: PitchDefinition = _selected_pitch()
	var ball_setup: BallSetupDefinition = ContentDB.get_ball_setup(BALL_SETUP_ID)

	if pitch == null or ball_setup == null:
		if _match_mode:
			_match_state.cancel_pitch()
		push_error("Pitch/Bat Lab: required prototype content is missing.")
		return

	_cleanup_batted_ball()
	_pitch_feedback.clear()
	_last_exit_speed_mph = 0.0
	var candidate_throw_number: int = _throw_number + 1
	_swing_consumed = false
	PitchBatLabSwingSupport.reset(self)
	_ai_swing_decided = false
	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	var target_position: Vector3 = Vector3(_pitch_target.x, _pitch_target.y, 0.0)

	var launch_pitch: PitchDefinition = pitch
	var is_left_handed: bool = false
	var execution_quality: float = _execution_quality
	var applied_fatigue: float = _fatigue
	var release_overdrive: float = 0.0
	var pitcher_state: PlayerMatchState
	var pending_stamina_cost: float = 0.0
	if _match_mode:
		pitcher_state = _match_state.pitcher()
		pending_stamina_cost = MatchLabSupport.stamina_cost(pitch, _pitch_effort)
		release_overdrive = (_pending_release_overdrive if _player_is_pitching() else 0.0)
		pending_stamina_cost *= lerpf(1.0, 1.08, release_overdrive)
		var authored_quality: float = _pending_release_quality if _player_is_pitching() else 1.0
		execution_quality = minf(
			authored_quality, 0.86 + float(pitcher_state.definition.control) * 0.014
		)
		execution_quality = maxf(
			0.0,
			(
				execution_quality
				- MatchLabSupport.execution_quality_penalty(_pitch_effort)
				- MatchLabSupport.release_overdrive_control_penalty(release_overdrive)
			)
		)
		is_left_handed = (pitcher_state.definition.throws == PlayerDefinition.Handedness.LEFT)
		launch_pitch = MatchLabSupport.rated_pitch(
			pitch, pitcher_state.definition, _pitch_effort, release_overdrive
		)
	else:
		var debug_pitcher: PlayerDefinition = ContentDB.get_player(DEBUG_PLAYER_ID)
		launch_pitch = MatchLabSupport.rated_pitch(pitch, debug_pitcher, _pitch_effort)

	var base_parameters: PitchLaunchParameters = PitchAimSolver.solve(
		launch_pitch,
		ball_setup,
		MOUND_ORIGIN,
		target_position,
		is_left_handed,
		candidate_throw_number
	)

	if base_parameters == null:
		PitchBatLabFeelSupport.recover_failed_pitch(self, pitch)
		return

	_throw_number = candidate_throw_number
	if pitcher_state != null:
		pitcher_state.spend_stamina(pending_stamina_cost)
		applied_fatigue = maxf(pitcher_state.fatigue_ratio(), _fatigue)

	PitchBatLabFeelSupport.measure_nominal_pitch(self, base_parameters, target_position)

	var executed_parameters: PitchLaunchParameters = PitchExecutionModel.apply(
		base_parameters,
		execution_quality,
		applied_fatigue,
		pitch.control_difficulty,
		pitch.execution_difficulty,
		pitch.category,
		_throw_number * 1009 + _selected_pitch_index
	)
	_last_executed_release_speed_mps = executed_parameters.velocity.length()
	var executed_crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		executed_parameters, target_position.z
	)
	if executed_crossing.crossed:
		_last_expected_plate_speed_mps = executed_crossing.velocity.length()
	else:
		_last_expected_plate_speed_mps = 0.0
	_last_release_quality = execution_quality
	_last_release_overdrive = release_overdrive
	PitchBatLabFeelSupport.start_record(
		self, pitch, applied_fatigue, execution_quality, executed_parameters.seed, release_overdrive
	)
	_pending_release_quality = 1.0
	_pending_release_overdrive = 0.0

	_status_label.text = ""
	_live_label.text = (
		(
			"THROW %d — %s%s\n"
			+ "release %.1f → %.1f mph   predicted plate %.1f mph\n"
			+ "release %s   overcook %.0f%%   movement X %+0.1f / Y %+0.1f cm"
		)
		% [
			_throw_number,
			pitch.display_name,
			("   fatigue %.0f%%" % (applied_fatigue * 100.0)) if _match_mode else "",
			_last_nominal_release_speed_mps * 2.236936,
			_last_executed_release_speed_mps * 2.236936,
			_last_expected_plate_speed_mps * 2.236936,
			PitchReleaseController.grade_name(execution_quality),
			release_overdrive * 100.0,
			_last_movement_x_m * 100.0,
			_last_movement_y_m * 100.0,
		]
	)

	_pitch_actor.start_pitch(executed_parameters)
	if _player_is_batting() and _at_bat_cadence != null:
		_at_bat_cadence.mark_pitch_live()
	_refresh_config()


func _handle_match_advance() -> void:
	PitchBatLabFeelSupport.handle_match_advance(self)


func _attempt_swing(profile_id: StringName) -> void:
	_resolve_swing(profile_id, _batting_aim)


func _resolve_swing(profile_id: StringName, aim_point: Vector2) -> void:
	PitchBatLabSwingSupport.begin_swing(self, profile_id, aim_point)


func _on_pitch_segment_advanced(
	previous_position: Vector3, previous_elapsed_seconds: float
) -> void:
	PitchBatLabSwingSupport.advance_swing(self, previous_position, previous_elapsed_seconds)


func _finish_non_contact_pitch() -> void:
	if not _match_mode:
		return
	PitchBatLabFeelSupport.notify_pitch_dead(self)
	_live_label.text = ("PLAY DEAD   next Pitch readying automatically")
	_refresh_config()


func _start_ball_in_play(launch_data: BattedBallLaunch) -> void:
	_cleanup_batted_ball()
	_pitch_actor.reset_pitch()
	_camera_director.prepare_ball_in_play(
		_match_mode and _player_is_pitching(), launch_data.position
	)

	_ball_play_resolver.start_play(_field_definition, launch_data.is_foul)
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
	_batted_ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	_batted_ball.configure_aero(ContentDB.get_ball_setup(BALL_SETUP_ID))
	_batted_ball.surface_contact.connect(_on_batted_surface_contact)
	add_child(_batted_ball)
	_batted_ball.launch(launch_data)
	_previous_batted_position = launch_data.position
	_primary_fielder.begin_play()

	if _match_mode:
		_camera_mode = 3
		PitchBatLabPresentation.apply_camera_mode(self)
		_refresh_config()


func _on_batted_surface_contact(surface_id: StringName, contact_position: Vector3) -> void:
	if _ball_play_resolver == null or _ball_play_resolver.state == null:
		return
	if _ball_play_resolver.state.dead:
		return
	match surface_id:
		&"ground":
			if not _ball_play_resolver.state.has_grounded:
				PitchBatLabFeelSupport.note_first_ground(self, contact_position)
			_ball_play_resolver.record_ground_contact(contact_position)
		&"back_wall":
			_sounds.play(&"wall")
			_ball_play_resolver.record_back_wall_contact(contact_position)
		&"live_object":
			_ball_play_resolver.record_live_object_contact(&"starter_pole")


func _try_pitcher_defense(previous_position: Vector3, current_position: Vector3) -> void:
	PitchBatLabDefenseSupport.try_pitcher(self, previous_position, current_position)


func _try_primary_fielder() -> void:
	if _primary_attempts >= 2 or _fielding_cooldown_seconds > 0.0:
		return
	var ball_position: Vector3 = _batted_ball.global_position
	var allowed_height: float = (
		FieldingResolver.MAX_GROUND_CONTROL_HEIGHT_M
		if _ball_play_resolver.state.has_grounded
		else FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M
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
	_apply_fielding_outcome(&"primary_fielder", _primary_fielder.global_position, outcome)


func _apply_fielding_outcome(
	defender_id: StringName,
	defender_position: Vector3,
	outcome: FieldingResolver.Outcome,
	control_position: Vector3 = Vector3.INF
) -> void:
	var resolved_position: Vector3 = (
		_batted_ball.global_position if control_position == Vector3.INF else control_position
	)
	if defender_id == &"pitcher":
		PitchBatLabPresentation.show_pitcher_fielding_attempt(
			self, resolved_position, outcome
		)
	_last_fielding_text = (
		"%s: %s"
		% [
			String(defender_id).replace("_", " ").capitalize(),
			FieldingResolver.outcome_name(outcome),
		]
	)
	match outcome:
		FieldingResolver.Outcome.CLEAN:
			_sounds.play(&"catch")
			var ball_was_moving: bool = _batted_ball.linear_velocity.length() > SETTLED_SPEED_MPS
			_batted_ball.global_position = resolved_position
			_batted_ball.stop_and_freeze()
			PitchBatLabFeelSupport.record_clean_fielding_control(
				self, defender_id, resolved_position, ball_was_moving
			)
		FieldingResolver.Outcome.BOBBLE:
			_sounds.play(&"bobble")
			_pitch_feedback.show_note("BOBBLE")
			_ball_play_resolver.record_bobble(defender_id, resolved_position)
			if _ball_play_resolver.state.dead:
				return
			_pitch_feedback.show_note("BOBBLE • Ball still live")
			_batted_ball.deflect(
				DeflectionModel.velocity_after_bobble(
					_batted_ball.linear_velocity, defender_position, _batted_ball.global_position
				),
				DeflectionModel.spin_after_bobble(_batted_ball.angular_velocity)
			)
			_fielding_cooldown_seconds = 0.55
		FieldingResolver.Outcome.MISS:
			_ball_play_resolver.record_miss(defender_id)
			_fielding_cooldown_seconds = 0.35


func _on_ball_play_resolved(outcome: BallPlayOutcome) -> void:
	_home_run.resolve_ball(self, outcome)
	if outcome.result == BallPlayOutcome.Result.HOME_RUN:
		_sounds.play(&"home_run")
	_primary_fielder.end_play()
	if _pitch_feedback.text.begins_with("BOBBLE"):
		_pitch_feedback.show_note("BOBBLED • " + outcome.display_name())

	var runs_scored: int = 0
	var advancement_text: String = "Runners hold"
	if outcome.result == BallPlayOutcome.Result.FOUL:
		if _match_mode:
			_match_state.record_foul()
		advancement_text = "Ball remains live only for the catch"
	elif outcome.result == BallPlayOutcome.Result.OUT:
		if outcome.caught and (not _match_mode or _match_state.outs < 2):
			var defender_rating: int = (
				MatchLabSupport.pitcher_fielding_rating(self)
				if _ball_play_resolver.state.last_defender_touch == &"pitcher"
				else _primary_fielder.fielding_rating
			)
			var tag_result: TagAdvanceResult = TagAdvanceResolver.resolve(
				_base_state, outcome.resolution_position, defender_rating
			)
			runs_scored = tag_result.runs_scored
			advancement_text = tag_result.description
		if _match_mode:
			_match_state.record_ball_in_play_out(runs_scored, outcome.display_name())
	else:
		if _match_mode:
			runs_scored = _match_state.record_hit(outcome.result)
		else:
			runs_scored = _base_state.advance_for_hit(
				outcome.result, StringName("batter.%d" % _throw_number)
			)
		advancement_text = "%d run(s) score" % runs_scored

	var compact_result: String = outcome.display_name()
	if _last_exit_speed_mph > 0.0:
		compact_result += "\nEV %.0f MPH" % _last_exit_speed_mph
	if outcome.result != BallPlayOutcome.Result.FOUL and not advancement_text.is_empty():
		compact_result += "\n%s" % advancement_text
	_status_label.text = compact_result
	_live_label.text = (
		"%s • %s\n%s\n%s"
		% [
			outcome.display_name(),
			String(outcome.reason).replace("_", " ").capitalize(),
			_last_fielding_text,
			_base_state.display_string(),
		]
	)
	if _match_mode:
		_live_label.text += "\nPLAY DEAD • next state automatic"
	else:
		_live_label.text += "\nPLAY DEAD • B diagnostic • SPACE next Pitch"
	PitchBatLabFeelSupport.note_ball_play_outcome(
		self,
		outcome,
		_ball_play_resolver.state.last_defender_touch,
		_ball_play_resolver.state.result_floor
	)
	PitchBatLabFeelSupport.finish_record(
		self, StringName(outcome.display_name().to_snake_case()), runs_scored
	)
	PitchBatLabFeelSupport.notify_pitch_dead(self)
	if outcome.caught:
		_at_bat_cadence.active_hold_seconds = maxf(_at_bat_cadence.active_hold_seconds, 2.25)
	_refresh_config()


func _on_trace_sampled(point: Vector3) -> void:
	_trajectory_points.append(point)
	_trajectory_draw.draw_polyline(_trajectory_points)


func _on_plate_crossed(point: Vector3, speed_mps: float, elapsed_seconds: float) -> void:
	PitchBatLabPitchCall.resolve(self, point, speed_mps, elapsed_seconds)


func _on_flight_stopped(reason: StringName) -> void:
	if reason == &"plate_crossed" or reason == &"contact":
		return
	if (
		_match_mode
		and _match_state != null
		and _match_state.phase == MatchState.Phase.PITCH_IN_FLIGHT
	):
		var record_result: StringName = &"ball_no_crossing"
		if _swing_consumed:
			PitchBatLabSwingSupport.ensure_miss(self)
			_match_state.record_strike(true)
			record_result = &"swinging_strike"
		else:
			_match_state.record_ball()
		PitchBatLabFeelSupport.finish_record(self, record_result)
		PitchBatLabFeelSupport.notify_pitch_dead(self)
		_live_label.text = "PLAY DEAD   next state readying automatically"
		_refresh_config()

	var continuation: String = "SPACE: continue"
	if _match_mode:
		continuation = "Next state automatic"
	_status_label.text = (
		"PITCH ENDED • %s\n%s"
		% [
			String(reason).replace("_", " ").to_upper(),
			continuation,
		]
	)


func _adjust_pitch_target(delta_xy: Vector2) -> void:
	PitchBatLabFeelSupport.adjust_pitch_target(self, delta_xy)


func _adjust_pitch_effort(delta: float) -> void:
	PitchBatLabFeelSupport.adjust_pitch_effort(self, delta)


func _adjust_batting_aim(delta_xy: Vector2) -> void:
	PitchBatLabFeelSupport.adjust_batting_aim(self, delta_xy)


func _selected_pitch() -> PitchDefinition:
	if _match_mode:
		var options: Array[PitchDefinition] = _current_pitch_options()
		if options.is_empty():
			return null
		_selected_pitch_index = clampi(_selected_pitch_index, 0, options.size() - 1)
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
	var candidate: int = _fielder_anchor_index
	for _step in range(9):
		candidate = (candidate + 1) % 9
		if _field_definition.is_fielder_anchor_available(candidate):
			MatchLabSupport.select_fielder_anchor(self, candidate)
			return


func _toggle_field_setup() -> void:
	MatchLabSupport.toggle_field_setup(self)


func _toggle_pitching_staff() -> void:
	MatchLabSupport.toggle_pitching_staff(self)


func _select_fielder_anchor(anchor_index: int) -> void:
	MatchLabSupport.select_fielder_anchor(self, anchor_index)


func _cycle_base_preset() -> void:
	MatchLabSupport.cycle_base_preset(self)


func _ball_in_play_is_live() -> bool:
	return (
		_batted_ball != null
		and _ball_play_resolver != null
		and _ball_play_resolver.state != null
		and not _ball_play_resolver.state.dead
	)


func _cleanup_batted_ball() -> void:
	if _ball_visibility != null:
		_ball_visibility.clear()
	_home_run.active = false
	if _pitcher_marker != null:
		_pitcher_marker.position = MOUND_ORIGIN
		_pitcher_marker.rotation = Vector3.ZERO
	if _batted_ball != null:
		if _batted_ball.surface_contact.is_connected(_on_batted_surface_contact):
			_batted_ball.surface_contact.disconnect(_on_batted_surface_contact)
		_batted_ball.queue_free()
		_batted_ball = null
	if _primary_fielder != null:
		_primary_fielder.end_play()
	_settled_seconds = 0.0


func _reset_lab() -> void:
	PitchBatLabFeelSupport.reset_debug_pause(self)
	PitchBatLabFeelSupport.cancel_release(self)
	PitchBatLabSwingSupport.reset(self)
	if _match_presentation_director != null:
		_match_presentation_director.reset()
	PitchBatLabPresentation.hide_match_presentation(self)
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	_cleanup_batted_ball()

	_pitch_target = DEFAULT_TARGET
	_batting_aim = DEFAULT_BATTING_AIM
	_execution_quality = 1.0
	_fatigue = 0.0
	_pitch_effort = 1.0
	_pending_release_overdrive = 0.0
	_last_release_overdrive = 0.0
	_last_exit_speed_mph = 0.0
	_swing_consumed = false
	_field_setup_active = false
	_pitching_staff_active = false
	_fielder_anchor_index = DEFAULT_FIELDER_ANCHOR_INDEX
	_base_preset_index = 0
	_base_state.clear()
	_primary_fielder.set_anchor(_field_definition.fielder_anchor(_fielder_anchor_index))

	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	_status_label.text = "Lab reset. SPACE: throw"
	_live_label.text = ""
	_refresh_markers()
	_refresh_config()


func _start_new_match() -> void:
	if _managed_match and _match_state != null:
		return
	PitchBatLabFeelSupport.reset_debug_pause(self)
	PitchBatLabFeelSupport.cancel_release(self)
	PitchBatLabSwingSupport.reset(self)
	if _match_presentation_director != null:
		_match_presentation_director.reset()
	PitchBatLabPresentation.hide_match_presentation(self)
	PitchBatLabFeelSupport.clear_records(self)
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	_cleanup_batted_ball()
	if _configured_match == null:
		_player_home = false
	_match_state = _configured_match if _configured_match != null else (
		MatchLabSupport.create_match(DEBUG_PLAYER_ID, PLAYER_TEAM_NAME, RIVAL_TEAM_NAME)
	)
	_configured_match = null
	_base_state = _match_state.bases
	_throw_number = 0
	_selected_pitch_index = 0
	_pitch_target = DEFAULT_TARGET
	_batting_aim = DEFAULT_BATTING_AIM
	_fatigue = 0.0
	_execution_quality = 1.0
	_pitch_effort = 1.0
	_pending_release_overdrive = 0.0
	_last_release_overdrive = 0.0
	_last_exit_speed_mph = 0.0
	_swing_consumed = false
	_ai_swing_decided = false
	_last_ai_pitch_index = -1
	_ai_pitch_preselected = false
	_awaiting_batter_confirm = true
	_field_setup_active = false
	_pitching_staff_active = false
	_last_ai_awareness = 0.0
	_last_ai_read_text = "No read"
	_match_suspend_snapshot.clear()
	if _batter_approach != null:
		_batter_approach.reset(_match_state.plate_appearance_number)
	_fielder_anchor_index = DEFAULT_FIELDER_ANCHOR_INDEX
	MatchLabSupport.assign_ai_defense_for_half(self)
	_trajectory_points.clear()
	if _trajectory_draw != null:
		_trajectory_draw.clear()
	if _contact_vector_draw != null:
		_contact_vector_draw.clear()
	_apply_defensive_assignment()
	_apply_role_camera()
	_status_label.text = "TOP 1 • %s\nGame presentation starting" % (
		"Player batting" if _player_is_batting() else "Player pitching"
	)
	_live_label.text = ""
	_refresh_markers()
	_refresh_config()
	PitchBatLabFeelSupport.begin_match_intro(self)


func _player_is_batting() -> bool:
	return _match_mode and _match_state != null and _match_state.top_half != _player_home


func _player_is_pitching() -> bool:
	return _match_mode and _match_state != null and _match_state.top_half == _player_home


func _select_pitcher(roster_index: int) -> void:
	MatchLabSupport.select_pitcher(self, roster_index)


func _apply_defensive_assignment() -> void:
	if not _match_mode or _match_state == null:
		return
	if not _field_definition.is_fielder_anchor_available(_fielder_anchor_index):
		_fielder_anchor_index = DEFAULT_FIELDER_ANCHOR_INDEX
	var fielder_state: PlayerMatchState = _match_state.fielder()
	if fielder_state != null and _primary_fielder != null:
		_primary_fielder.configure_player(fielder_state.definition)
		_primary_fielder.set_anchor(_field_definition.fielder_anchor(_fielder_anchor_index))
		_primary_fielder.set_pitcher_lane(MOUND_ORIGIN.z)
	PitchBatLabPresentation.sync_players(self)


func _toggle_match_mode() -> void:
	PitchBatLabFeelSupport.toggle_match_mode(self)


func _toggle_debug_overlay() -> void:
	_debug_overlay_visible = not _debug_overlay_visible
	_config_label.visible = _debug_overlay_visible
	_live_label.visible = _debug_overlay_visible
	_trajectory_draw.visible = _debug_overlay_visible
	_contact_vector_draw.visible = _debug_overlay_visible
	_refresh_config()


func _cycle_camera() -> void:
	PitchBatLabPresentation.cycle_camera(self)


func _toggle_display_menu() -> void:
	if not _debug_paused:
		PitchBatLabFeelSupport.toggle_debug_pause(self)
	_display_menu_open = not _display_menu_open
	PitchBatLabPresentation.refresh_display_menu(self)


func _cycle_hud_anchor() -> void:
	PitchBatLabPresentation.cycle_hud_anchor(self)


func _toggle_sky_backdrop() -> void:
	PitchBatLabPresentation.toggle_sky_backdrop(self)


func _apply_role_camera() -> void:
	PitchBatLabPresentation.apply_role_camera(self)


func _refresh_config() -> void:
	PitchBatLabPresentation.refresh(self)


func _refresh_markers() -> void:
	PitchBatLabPresentation.refresh_markers(self)


func _build_ball_play_resolver() -> void:
	_ball_play_resolver = BallPlayResolver.new()
	_ball_play_resolver.play_resolved.connect(_on_ball_play_resolved)

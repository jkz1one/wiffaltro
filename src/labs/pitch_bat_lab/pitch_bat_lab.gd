class_name PitchBatLab
extends Node3D
# gdlint: disable=max-file-lines,max-returns

signal match_return_requested
signal menu_exit_requested
signal hillside_public_install_finished(success: bool)

const AC02_PASSIVE_17 = preload("res://src/diagnostics/ac02_passive_attribution.gd")

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
const BATTING_AIM_MIN_X: float = SwingIntent.AIM_MIN_X
const BATTING_AIM_MAX_X: float = SwingIntent.AIM_MAX_X
const BATTING_AIM_MIN_Y: float = SwingIntent.AIM_MIN_Y
const BATTING_AIM_MAX_Y: float = SwingIntent.AIM_MAX_Y
const AIM_STEP_M: float = 0.05
const BATTED_BALL_TIMEOUT_SECONDS: float = 9.0
const SETTLED_SPEED_MPS: float = 0.55
const SETTLED_HOLD_SECONDS: float = 0.65
const DEFAULT_FIELDER_ANCHOR_INDEX: int = 3
# Private V19 integration; ordinary launches remain disabled unless explicitly installed.
var pool_active_receipt: StadiumPoolActiveReceipt
var pool_controller_active: StadiumPoolControllerActive
# Private bound-extension startup rejects before delivery; absent by default.
var pool_bound_startup_failed: bool = false
var yard_bound_startup_failed: bool = false
# Non-null only for the captured Hillside post-attachment registration phase.
var hillside_public_pending: StadiumNpcPublicProperty
# Private movement-only opt-in; no automatic venue or ball-target binding.
var hillside_pitcher_motion: StadiumHillsideDefenderMotion
var hillside_pitcher_target: Vector3 = Vector3.INF
var hillside_private_runtime: StadiumHillsidePrivateRuntime
# Runtime-only sticky new-contract owner; not a snapshot, save field or historical flag.
var _ac02_startup_attempt: RefCounted
var _ac02_startup_enrolled: bool = false
var _ac02_startup_committed: bool = false

var _ac02_issued_owner: StadiumNpcAc02IssuedStateV1
# Routing history only, never authority. Set once at ACTIVE; no supported path clears it.
var _ac02_issued_history: bool = false
var _hillside_public_install_state: MatchState
var _hillside_public_install_reported: bool = true
# Saved public NPC fixture authority is supplied by the managed caller before startup.
var _npc_season: SeasonState

var _automation: MatchAutomation
var _configured_match: MatchState
# In-process paid-prefix proof. Never copied into MatchState, saves or worker requests.
var _stadium_ledger: ClubAssetLedger
var _managed_match: bool = false
var _player_home: bool = false
var _pitch_actor: PitchFlightActor
var _batted_ball: BattedBallBody
var _ball_play_resolver: BallPlayResolver
var _field_definition: FieldDefinition
var _field_id: StringName = FIELD_ID
var _primary_fielder: FielderController
var _pitcher_marker: Node3D
# Captured at explicit private installation; removal cannot become ordinary fallback.
var _hillside_private_owner_identity: WeakRef
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
var _hr_celebration_label: Label
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
var _contact_pitch_summary: String = ""
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
func ac02_startup_pending() -> bool:
	return _ac02_startup_enrolled and not _ac02_startup_committed


func _ready() -> void:
	process_mode = (Node.PROCESS_MODE_PAUSABLE if _automation != null else Node.PROCESS_MODE_ALWAYS)
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab loaded with invalid content.")
		return

	if _configured_match != null and StadiumNpcSnapshot.is_public(_configured_match.stadium):
		if _field_id != StringName(StadiumNpcSnapshot.FIELD):
			yard_bound_startup_failed = true
			push_error("Public AY02 fixture requires its exact NPC field selection.")
			return
		# Build the unchanged starter host; only the validated commit replaces its geometry.
		_field_id = FIELD_ID
	_field_definition = ContentDB.get_field(_field_id)
	if _field_definition == null:
		push_error("Pitch/Bat Lab: configured field definition is missing.")
		return

	if _automation == null:
		PitchBatLabSettings.restore(self)
	PitchBatLabPresentation.build_environment(self)
	PitchBatLabPresentation.build_pitch_actor(self)
	PitchBatLabPresentation.build_defenders(self)
	_build_ball_play_resolver()
	PitchBatLabPresentation.build_ui(self)
	PitchBatLabFeelSupport.initialize(self)
	_start_new_match()
	if hillside_public_pending != null:
		return
	if (
		not StadiumSurfaceTerrainRuntime.action_allowed(self)
		or pool_bound_startup_failed
		or yard_bound_startup_failed
		or (
			has_meta(StadiumSurfaceNightRuntime.BOUND)
			and not StadiumSurfaceNightRuntime.action_allowed(self)
		)
	):
		push_error("Bound stadium startup rejected before delivery.")
		return
	if (
		not _match_state.stadium.is_empty()
		and not StadiumNpcSnapshot.is_public(_match_state.stadium)
		and not StadiumSurfaceNightSnapshot.is_family(_match_state.stadium)
		and not StadiumLayoutSnapshot.is_terrain(_match_state.stadium)
		and not (pool_controller_active != null and pool_controller_active.is_bound_profile())
		and not StadiumPropertyRuntime.install_bound(self)
	):
		push_error("Frozen home-property snapshot could not be installed.")
	if ac02_startup_pending():
		if _ac02_startup_attempt == null or not _ac02_startup_attempt.markers():
			return
		_refresh_config()
		_ac02_startup_attempt.ready_complete()
	else:
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
	if ac02_startup_pending():
		if _ac02_startup_attempt != null:
			_ac02_startup_attempt.abort("lab lifecycle interrupted startup")
		return
	StadiumSurfaceTerrainRuntime.retire(self, "LAB_EXIT")
	StadiumSurfaceNightRuntime.retire(self, "LAB_EXIT")
	StadiumPoolOwnedExtension.retire_installed_field(self, "LAB_EXIT")
	if pool_controller_active != null:
		pool_controller_active.detach()
	_stadium_ledger = null
	if _debug_paused:
		get_tree().paused = false


func _process(delta: float) -> void:
	var ac02_token: int = AC02_PASSIVE_17.enter("pitch_bat_lab._process")
	_ac02_passive_17_private_process(delta)
	AC02_PASSIVE_17.leave(ac02_token)


func _ac02_passive_17_private_process(delta: float) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	PitchBatLabFeelSupport.update(self, delta)
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	StadiumPropertyRuntime.refresh_receiver_visibility(self)
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

	if not MatchAutomation.presented(self):
		return

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
	var ac02_token: int = AC02_PASSIVE_17.enter("pitch_bat_lab._physics_process")
	_ac02_passive_17_private_physics_process(delta)
	AC02_PASSIVE_17.leave(ac02_token)


func _ac02_passive_17_private_physics_process(delta: float) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
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
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if pool_active_receipt != null:
		pool_active_receipt.capture_decision(self, previous_ball_position, current_ball_position)
	if (
		pool_controller_active != null
		and pool_controller_active.try_resolve(self, previous_ball_position, current_ball_position)
	):
		_previous_batted_position = current_ball_position
		return
	# Resolve contact at its swept position before observing the remaining
	# segment; the pitcher helper preserves floors reached before contact.
	_try_pitcher_defense(previous_ball_position, current_ball_position)
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if _ball_play_resolver.state.dead:
		_previous_batted_position = current_ball_position
		return
	_ball_play_resolver.observe_segment(previous_ball_position, current_ball_position)
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_previous_batted_position = current_ball_position
	if _ball_play_resolver.state.dead:
		return

	_ball_play_resolver.advance_time(delta)
	_fielding_cooldown_seconds = maxf(0.0, _fielding_cooldown_seconds - delta)

	_primary_fielder.plan_for_ball(
		_batted_ball.global_position,
		_batted_ball.linear_velocity,
		_ball_play_resolver.state.has_grounded,
		delta
	)
	_try_primary_fielder()
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return

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
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	PitchBatLabInput.handle(self, event)


func _input(event: InputEvent) -> void:
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	if _debug_paused:
		PitchBatLabInput.cancel_paused_release(self, event)


func bind_hillside_pitcher_motion() -> bool:
	if hillside_pitcher_motion == null:
		hillside_pitcher_motion = StadiumHillsideDefenderMotion.new()
	if not hillside_pitcher_motion.configure_pitcher(self):
		return false
	hillside_pitcher_target = Vector3.INF
	return true


func _private_hillside_admits() -> bool:
	if not StadiumSurfaceTerrainRuntime.action_allowed(self):
		return false
	if _hillside_private_owner_identity == null:
		return (
			hillside_private_runtime == null
			and get_node_or_null(NodePath(StadiumHillsidePrivateRuntime.NODE_NAME)) == null
		)
	var captured: Object = _hillside_private_owner_identity.get_ref()
	if (
		not is_instance_valid(captured)
		or captured != hillside_private_runtime
		or get_node_or_null(NodePath(StadiumHillsidePrivateRuntime.NODE_NAME)) != captured
	):
		return false
	if hillside_private_runtime == null:
		return false
	return is_instance_valid(hillside_private_runtime) and hillside_private_runtime.admits_action()


func reset_hillside_pitcher() -> bool:
	if StadiumSurfaceTerrainRuntime.requested(self):
		var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
		if owner != null and owner.phase == StadiumSurfaceTerrainRuntime.Phase.CONFIGURED:
			return StadiumSurfaceTerrainRuntime.continue_startup(self, owner, _configured_match)
		return owner != null and owner.reset_pitcher(self)
	hillside_pitcher_target = Vector3.INF
	if hillside_pitcher_motion != null:
		return hillside_pitcher_motion.reset_pitcher(self)
	if _pitcher_marker != null:
		_pitcher_marker.position = MOUND_ORIGIN
		_pitcher_marker.rotation = Vector3.ZERO
	return true


func _request_lab_pitch() -> void:
	# Ordinary mechanics labs retain their immediate throw behavior.
	_throw_pitch()


func _throw_pitch() -> void:
	if ac02_startup_pending():
		return
	if not StadiumWaterfallAnimationRuntime.before_pitch(self):
		return
	if not StadiumRisingAppleRuntime.before_pitch(self):
		return
	if not StadiumMountedClockRuntime.before_pitch(self):
		return
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(self)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(self)
	):
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	if _field_setup_active or _pitching_staff_active:
		return
	if (
		not StadiumNpcPublicRuntime.admits_action(self)
		or not StadiumNpcYardTwoRuntimeV1.launch_pitch(self)
	):
		return
	var yard_owner: StadiumNpcYardTwoPropertyV1 = StadiumNpcYardTwoRuntimeV1._property(self)
	var yard_play: int = yard_owner.play_generation if yard_owner != null else -1
	if not reset_hillside_pitcher():
		return
	if _pitcher_avatar != null:
		_pitcher_avatar.reset_pose()
	if not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
	):
		return
	if _match_mode:
		if _match_state == null or not _match_state.begin_pitch():
			StadiumNpcYardTwoRuntimeV1.abandon_launch(self, yard_play, yard_owner)
			return
		# begin_pitch emits inventory_boundary; full authority is rechecked before launch.
		if not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner):
			return
		if (
			not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
			or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
		):
			return
		if MatchAutomation.pitching(self):
			if not _ai_pitch_preselected:
				MatchLabSupport.apply_ai_pitch_choice(self)
			_ai_pitch_preselected = false
			_pending_release_quality = 1.0
			_last_release_offset_seconds = 0.0

	var pitch: PitchDefinition = _selected_pitch()
	if _match_mode and pitch != null and not _match_state.sure_shot.allows(_match_state, pitch.id):
		_match_state.cancel_pitch()
		StadiumNpcYardTwoRuntimeV1.abandon_launch(self, yard_play, yard_owner)
		return
	var ball_setup: BallSetupDefinition = ContentDB.get_ball_setup(BALL_SETUP_ID)

	if pitch == null or ball_setup == null:
		if _match_mode:
			_match_state.cancel_pitch()
		push_error("Pitch/Bat Lab: required prototype content is missing.")
		StadiumNpcYardTwoRuntimeV1.abandon_launch(self, yard_play, yard_owner)
		return

	if not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_cleanup_batted_ball(true)
	if not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_pitch_feedback.clear()
	_last_exit_speed_mph = 0.0
	var candidate_throw_number: int = _throw_number + 1
	_swing_consumed = false
	PitchBatLabSwingSupport.reset(self)
	SeasonOpponentBase.first_release_note(self)
	_ai_swing_decided = false
	if _batter_approach != null:
		_batter_approach.reset_pitch()
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
		pending_stamina_cost *= SeasonGearCatalog.workload(pitcher_state, _pitch_effort)
		pending_stamina_cost *= SeasonSponsorEffects.workload(pitcher_state.definition, pitch)
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
		launch_pitch = MatchTactics.pitch(launch_pitch, _match_state)
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
		StadiumNpcYardTwoRuntimeV1.abandon_launch(self, yard_play, yard_owner)
		return

	if _match_mode and not _match_state.sure_shot.current(_match_state).is_empty():
		base_parameters.execution_direction_scale = 0.8
	# AY02 rechecks after setup callbacks, before release counters/stamina are spent.
	if not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_throw_number = candidate_throw_number
	if pitcher_state != null:
		var stamina_before: float = pitcher_state.stamina_remaining
		pitcher_state.spend_stamina(pending_stamina_cost)
		if LeagueRules.doubleheader(_match_state.defensive_team().league_rules):
			_match_state.defensive_team().recovery.workload_input = {
				"effort": _pitch_effort,
				"overdrive": release_overdrive,
				"base_cost": pitch.stamina_cost,
				"gear_scale": SeasonGearCatalog.workload(pitcher_state, _pitch_effort),
				"sponsor_scale": SeasonSponsorEffects.workload(pitcher_state.definition, pitch)
			}
		_match_state.note_pitch_released(pitch.id, stamina_before - pitcher_state.stamina_remaining)
		if _automation != null:
			_automation.note_release(
				_match_state, pitch.id, stamina_before - pitcher_state.stamina_remaining
			)
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

	if not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if terrain_owner != null and not terrain_owner.claim_pitch(self, executed_parameters):
		return
	var night_pitch: PitchFlightActor = _pitch_actor
	night_pitch.start_pitch(executed_parameters)
	if (
		not StadiumSurfaceNightRuntime.continue_pitch(
			self, night_owner, night_state, night_pitch, executed_parameters
		)
		or not StadiumSurfaceTerrainRuntime.continue_pitch(
			self, terrain_owner, night_state, night_pitch, executed_parameters
		)
	):
		return
	if not StadiumNpcYardTwoRuntimeV1.bind_live_pitch(self, yard_play, yard_owner):
		return
	MatchPitchDisclosure.present(self)
	if _player_is_batting() and _at_bat_cadence != null:
		_at_bat_cadence.mark_pitch_live()
	_refresh_config()


func _handle_match_advance() -> void:
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(self)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(self)
	):
		return
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	PitchBatLabFeelSupport.handle_match_advance(self)


func _attempt_swing(profile_id: StringName) -> void:
	_resolve_swing(profile_id, _batting_aim)


func _resolve_swing(profile_id: StringName, aim_point: Vector2) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	PitchBatLabSwingSupport.begin_swing(self, profile_id, aim_point)


func _on_pitch_segment_advanced(
	previous_position: Vector3, previous_elapsed_seconds: float
) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	var swing_is_noop: bool = (
		PitchBatLabFeelSupport.owned_noop_scope(self, night_owner, night_state)
		and PitchBatLabFeelSupport.swing_noop(self)
	)
	PitchBatLabSwingSupport.advance_swing(self, previous_position, previous_elapsed_seconds)
	if (
		(
			(
				not swing_is_noop
				or not PitchBatLabFeelSupport.owned_noop_scope(self, night_owner, night_state)
			)
			and not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	MatchLabSupport.try_ai_swing(self)


func _finish_non_contact_pitch() -> void:
	if not _match_mode:
		return
	PitchBatLabFeelSupport.notify_pitch_dead(self)
	_live_label.text = ("PLAY DEAD   next Pitch readying automatically")
	_refresh_config()


func _start_ball_in_play(launch_data: BattedBallLaunch) -> void:
	if ac02_startup_pending():
		return
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(self)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(self)
	):
		return
	var ac02_owner: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(self)
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if not _private_hillside_admits():
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	if pool_controller_active != null and pool_controller_active.is_committing():
		return
	if (
		not StadiumNpcPublicRuntime.admits_action(self)
		or not StadiumNpcYardTwoRuntimeV1.launch_ball(self)
	):
		return
	var captured_hillside: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(self)
	if captured_hillside != null and captured_hillside.venue_id != "HILLSIDE":
		captured_hillside = null
	var hillside_match: MatchState = _match_state
	var hillside_resolver: BallPlayResolver = _ball_play_resolver
	var yard_owner: StadiumNpcYardTwoPropertyV1 = StadiumNpcYardTwoRuntimeV1._property(self)
	var yard_play: int = yard_owner.play_generation if yard_owner != null else -1
	_cleanup_batted_ball(true)
	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not _hillside_launch_context(captured_hillside, hillside_match, hillside_resolver)
	):
		return
	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
	):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_pitch_actor.reset_pitch()
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not _hillside_launch_context(captured_hillside, hillside_match, hillside_resolver)
	):
		return
	if (
		not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
		or not StadiumNpcYardTwoRuntimeV1.prepare_ball_camera(self, yard_play, yard_owner)
	):
		return
	_camera_director.prepare_ball_in_play(
		_match_mode and _player_is_pitching(), launch_data.position, launch_data.velocity
	)

	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
	):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not _hillside_launch_context(captured_hillside, hillside_match, hillside_resolver)
	):
		return
	_ball_play_resolver.start_play(_field_definition, launch_data.is_foul)
	_primary_attempts = 0
	_pitcher_attempted = false
	_fielding_cooldown_seconds = 0.0
	_settled_seconds = 0.0
	_last_fielding_text = "Defense tracking"
	if _match_mode:
		_match_state.begin_ball_in_play()
		if (
			not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
			or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
		):
			return
		_apply_defensive_assignment()

	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
	):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if (
		(ac02_owner != null and not ac02_owner.continue_action(self))
		or not _hillside_launch_context(captured_hillside, hillside_match, hillside_resolver)
	):
		return
	var ac02_candidate: BattedBallBody = BattedBallBody.new()
	if ac02_owner != null and not ac02_owner.created_ball(self, ac02_candidate):
		ac02_candidate.free()
		return
	_batted_ball = ac02_candidate
	_batted_ball.name = "BattedBall"
	_batted_ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	_batted_ball.configure_aero(ContentDB.get_ball_setup(BALL_SETUP_ID))
	_batted_ball.surface_contact.connect(_on_batted_surface_contact)
	if hillside_private_runtime != null:
		var private_owner: StadiumHillsidePrivateRuntime = hillside_private_runtime
		var private_ball: BattedBallBody = _batted_ball
		var private_state: BallPlayState = _ball_play_resolver.state
		add_child(private_ball)
		# Both attachment and launch emit callbacks. Bind only this original candidate.
		if (
			hillside_private_runtime != private_owner
			or not is_instance_valid(private_owner)
			or not is_instance_valid(private_ball)
			or _batted_ball != private_ball
			or _ball_play_resolver.state != private_state
			or not StadiumPropertyRuntime.bind_ball(self, private_ball, _ball_play_resolver)
		):
			if is_instance_valid(private_owner):
				private_owner.reject_candidate(
					private_ball, "The candidate changed before its physical binding."
				)
			else:
				_hold_private_candidate(
					private_ball, "The private owner disappeared before binding."
				)
			return
		private_ball.launch(launch_data)
		if (
			hillside_private_runtime != private_owner
			or not is_instance_valid(private_owner)
			or not is_instance_valid(private_ball)
			or not private_owner.launch_binding_valid(private_ball, private_state)
		):
			if is_instance_valid(private_owner):
				private_owner.reject_candidate(
					private_ball, "The candidate changed during the launch callback."
				)
			else:
				_hold_private_candidate(
					private_ball, "The private owner disappeared during launch."
				)
			return
	elif captured_hillside != null:
		var hillside_owner: StadiumNpcPublicProperty = captured_hillside
		var hillside_ball: BattedBallBody = _batted_ball
		var hillside_state: BallPlayState = _ball_play_resolver.state
		add_child(hillside_ball)
		if (
			not is_instance_valid(hillside_owner)
			or StadiumNpcPublicRuntime._property(self) != hillside_owner
			or not is_instance_valid(hillside_ball)
			or _batted_ball != hillside_ball
			or _ball_play_resolver.state != hillside_state
			or not StadiumNpcPublicRuntime.bind_ball(self, hillside_ball, _ball_play_resolver)
		):
			StadiumNpcPublicRuntime.reject_hillside_candidate(self, hillside_owner, hillside_ball)
			return
		hillside_ball.launch(launch_data)
		if (
			not is_instance_valid(hillside_owner)
			or StadiumNpcPublicRuntime._property(self) != hillside_owner
			or not hillside_owner.hillside_launch_binding_valid(hillside_ball, hillside_state)
		):
			StadiumNpcPublicRuntime.reject_hillside_candidate(self, hillside_owner, hillside_ball)
			return
	elif terrain_owner != null:
		var terrain_ball: BattedBallBody = _batted_ball
		var terrain_play: BallPlayState = _ball_play_resolver.state
		if not terrain_owner.claim_ball(self, terrain_ball, terrain_play):
			return
		add_child(terrain_ball)
		if (
			not terrain_owner.ball_context(self, terrain_ball, terrain_play)
			or not StadiumPropertyRuntime.bind_ball(self, terrain_ball, _ball_play_resolver)
		):
			terrain_owner._abandon()
			return
		terrain_ball.launch(launch_data)
		if not terrain_owner.ball_context(self, terrain_ball, terrain_play):
			return
	elif night_owner != null:
		var night_ball: BattedBallBody = _batted_ball
		var night_play: BallPlayState = _ball_play_resolver.state
		if not StadiumSurfaceNightRuntime.claim_ball(
			self, night_owner, night_state, night_ball, night_play
		):
			return
		add_child(night_ball)
		if not StadiumSurfaceNightRuntime.continue_ball(
			self, night_owner, night_state, night_ball, night_play
		):
			return
		night_ball.launch(launch_data)
		if not StadiumSurfaceNightRuntime.continue_ball(
			self, night_owner, night_state, night_ball, night_play
		):
			return
		StadiumPropertyRuntime.bind_ball(self, night_ball, _ball_play_resolver)
		if not StadiumSurfaceNightRuntime.continue_ball(
			self, night_owner, night_state, night_ball, night_play
		):
			return
	elif ac02_owner != null:
		# Same ordinary factory operations, with this original issuance token at each seam.
		var issued_ball: BattedBallBody = _batted_ball
		add_child(issued_ball)
		if not ac02_owner.continue_action(self):
			return
		issued_ball.launch(launch_data)
		if not ac02_owner.continue_action(self):
			return
		StadiumPropertyRuntime.bind_ball(self, issued_ball, _ball_play_resolver)
		if not ac02_owner.continue_action(self):
			return
	elif yard_owner == null:
		add_child(_batted_ball)
		if pool_controller_active != null and pool_controller_active.is_bound_profile():
			# Compose ordinary listeners/router before the bound guard and launch signal.
			StadiumPropertyRuntime.bind_ball(self, _batted_ball, _ball_play_resolver)
			pool_controller_active.bind_ball(self, launch_data)
			_batted_ball.launch(launch_data)
		else:
			if pool_controller_active != null:
				pool_controller_active.bind_ball(self, launch_data)
			_batted_ball.launch(launch_data)
			StadiumPropertyRuntime.bind_ball(self, _batted_ball, _ball_play_resolver)
	else:
		var created_ball: BattedBallBody = _batted_ball
		add_child(created_ball)
		# ready/child_entered_tree can reset or replace the pending play synchronously.
		if (
			yard_owner != null
			and (
				not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
				or not is_instance_valid(created_ball)
				or _batted_ball != created_ball
				or created_ball.is_queued_for_deletion()
				or not created_ball.is_inside_tree()
				or created_ball.get_parent() != self
				or created_ball.get_script() != BattedBallBody
			)
		):
			return
		if ac02_owner != null and not ac02_owner.continue_action(self):
			return
		created_ball.launch(launch_data)
		# launch_started is another public callback seam; never bind a replacement ball.
		if (
			yard_owner != null
			and (
				not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
				or not is_instance_valid(created_ball)
				or _batted_ball != created_ball
				or created_ball.is_queued_for_deletion()
				or not created_ball.is_inside_tree()
				or created_ball.get_parent() != self
				or created_ball.get_script() != BattedBallBody
			)
		):
			return
		if ac02_owner != null and not ac02_owner.continue_action(self):
			return
		StadiumPropertyRuntime.bind_ball(self, created_ball, _ball_play_resolver)
		if ac02_owner != null and not ac02_owner.continue_action(self):
			return
		if (
			yard_owner != null
			and (
				not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
				or not is_instance_valid(created_ball)
				or _batted_ball != created_ball
				or created_ball.is_queued_for_deletion()
				or not created_ball.is_inside_tree()
				or created_ball.get_parent() != self
				or created_ball.get_script() != BattedBallBody
			)
		):
			return
		if not StadiumNpcYardTwoRuntimeV1.bind_live_ball(self, yard_play, yard_owner):
			return
	_previous_batted_position = launch_data.position
	_primary_fielder.begin_play(
		_match_mode and not launch_data.is_foul and SeasonCornerstone.active(_match_state),
		(
			SeasonJumpstart.direction(_match_state)
			if _match_mode and not launch_data.is_foul
			else Vector3.ZERO
		),
		launch_data
	)

	if _match_mode:
		_camera_mode = 3
		PitchBatLabPresentation.apply_camera_mode(self)
		_refresh_config()


func _hold_private_candidate(candidate: Variant, message: String) -> void:
	# The captured body remains ours even if a callback freed its private owner.
	# Never freeze, clear or delete a callback-installed replacement.
	process_mode = Node.PROCESS_MODE_DISABLED
	if (
		is_instance_valid(candidate)
		and candidate is BattedBallBody
		and candidate.get_script() == BattedBallBody
		and candidate.get_parent() == self
	):
		candidate.freeze = true
		if candidate.surface_contact.is_connected(_on_batted_surface_contact):
			candidate.surface_contact.disconnect(_on_batted_surface_contact)
		if _batted_ball == candidate:
			_batted_ball = null
		candidate.queue_free()
	if is_instance_valid(_status_label):
		_status_label.text = "Private Hillside held: " + message


func _on_batted_surface_contact(surface_id: StringName, contact_position: Vector3) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
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
	PitchBatLabDefenseSupport.try_primary(self)


func _apply_fielding_outcome(
	defender_id: StringName,
	defender_position: Vector3,
	outcome: FieldingResolver.Outcome,
	control_position: Vector3 = Vector3.INF
) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	# Capture contact before CLEAN can synchronously end the PA/half and change defenders.
	# A miss is not a fielding play; repeated touches remain one per-player game flag.
	if (
		_match_mode
		and _match_state != null
		and _match_state.phase == MatchState.Phase.BALL_IN_PLAY
		and not _ball_play_resolver.state.dead
		and outcome in [FieldingResolver.Outcome.CLEAN, FieldingResolver.Outcome.BOBBLE]
	):
		if defender_id == &"pitcher":
			_match_state.performance.fielding_play(_match_state.pitcher().definition.id)
		elif defender_id == &"primary_fielder":
			_match_state.performance.fielding_play(_match_state.fielder().definition.id)
	var resolved_position: Vector3 = (
		_batted_ball.global_position if control_position == Vector3.INF else control_position
	)
	if defender_id == &"pitcher":
		PitchBatLabPresentation.show_pitcher_fielding_attempt(self, resolved_position, outcome)
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
			if (
				not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_action(
					self, terrain_owner, night_state
				)
			):
				return
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
	var ac02_token: int = AC02_PASSIVE_17.enter("pitch_bat_lab._on_ball_play_resolved")
	_ac02_passive_17_private_on_ball_play_resolved(outcome)
	AC02_PASSIVE_17.leave(ac02_token)


func _ac02_passive_17_private_on_ball_play_resolved(outcome: BallPlayOutcome) -> void:
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(self)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(self)
	):
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if (
		not StadiumNpcPublicRuntime.admits_action(self)
		or not StadiumNpcYardTwoRuntimeV1.outcome_gate(self, &"ball")
	):
		return
	var captured_hillside: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(self)
	if captured_hillside != null and captured_hillside.venue_id != "HILLSIDE":
		captured_hillside = null
	var hillside_match: MatchState = _match_state
	var hillside_resolver: BallPlayResolver = _ball_play_resolver
	var hillside_play: BallPlayState = _ball_play_resolver.state
	var receipt_before: Array = []
	if pool_active_receipt != null:
		receipt_before = pool_active_receipt.before_outcome(self, outcome)
	_home_run.resolve_ball(self, outcome)
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
	):
		return
	if outcome.result == BallPlayOutcome.Result.HOME_RUN:
		_sounds.play(&"home_run")
	_primary_fielder.end_play()
	if _pitch_feedback.text.begins_with("BOBBLE"):
		_pitch_feedback.show_note("BOBBLED • " + outcome.display_name())

	if (
		captured_hillside != null
		and (
			not _hillside_launch_context(captured_hillside, hillside_match, hillside_resolver)
			or _ball_play_resolver.state != hillside_play
		)
	):
		return
	var runs_scored: int = 0
	var advancement_text: String = "Runners hold"
	if outcome.result == BallPlayOutcome.Result.FOUL:
		if _match_mode:
			_match_state.record_foul()
			if (
				not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_boundary(
					self, terrain_owner, night_state
				)
			):
				return
		advancement_text = "Ball remains live only for the catch"
	elif outcome.result == BallPlayOutcome.Result.OUT:
		if outcome.caught and (not _match_mode or _match_state.outs < 2):
			var defender_rating: int = (
				MatchLabSupport.pitcher_fielding_rating(self)
				if _ball_play_resolver.state.last_defender_touch == &"pitcher"
				else _primary_fielder.fielding_rating
			)
			var gather_scale: float = 1.0
			var travel_scale: float = 1.0
			if _match_mode:
				var catcher: PlayerDefinition = _match_state.fielder().definition
				if _ball_play_resolver.state.last_defender_touch == &"pitcher":
					catcher = _match_state.pitcher().definition
				gather_scale = SeasonSponsorEffects.gather_scale(catcher)
				travel_scale = SeasonSponsorEffects.tag_scale(_match_state.batter().definition)
				_match_state.base_flow.tag(
					_match_state,
					outcome.resolution_position,
					defender_rating,
					gather_scale,
					travel_scale,
					String(catcher.id)
				)
			var tag_result: TagAdvanceResult = TagAdvanceResolver.resolve(
				_base_state,
				outcome.resolution_position,
				defender_rating,
				gather_scale,
				travel_scale
			)
			runs_scored = tag_result.runs_scored
			advancement_text = tag_result.description
		if _match_mode:
			_match_state.clean_outs.record(_match_state, _ball_play_resolver.state, outcome)
			_match_state.record_ball_in_play_out(runs_scored, outcome.display_name())
			if (
				not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_boundary(
					self, terrain_owner, night_state
				)
			):
				return
	else:
		if _match_mode:
			runs_scored = _match_state.record_hit(outcome.result)
			if (
				not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_boundary(
					self, terrain_owner, night_state
				)
			):
				return
		else:
			runs_scored = _base_state.advance_for_hit(
				outcome.result, StringName("batter.%d" % _throw_number)
			)
		advancement_text = "%d run(s) score" % runs_scored

	var compact_result: String = outcome.display_name()
	if not _contact_pitch_summary.is_empty():
		compact_result += "\n" + _contact_pitch_summary
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
	if pool_active_receipt != null:
		pool_active_receipt.after_outcome(self, receipt_before)


func _on_trace_sampled(point: Vector3) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	if not MatchAutomation.presented(self):
		return
	_trajectory_points.append(point)
	_trajectory_draw.draw_polyline(_trajectory_points)


func _on_plate_crossed(point: Vector3, speed_mps: float, elapsed_seconds: float) -> void:
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(self)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(self)
	):
		return
	if (
		not StadiumNpcPublicRuntime.admits_action(self)
		or not StadiumNpcYardTwoRuntimeV1.outcome_gate(self, &"plate")
	):
		return
	PitchBatLabPitchCall.resolve(self, point, speed_mps, elapsed_seconds)


func _on_flight_stopped(reason: StringName) -> void:
	if (
		not StadiumSurfaceNightRuntime.action_allowed(self)
		or not StadiumSurfaceTerrainRuntime.action_allowed(self)
	):
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if reason == &"plate_crossed" or reason == &"contact":
		return
	if (
		not StadiumNpcPublicRuntime.admits_action(self)
		or not StadiumNpcYardTwoRuntimeV1.outcome_gate(self, &"noncontact")
	):
		return
	if (
		_match_mode
		and _match_state != null
		and _match_state.phase == MatchState.Phase.PITCH_IN_FLIGHT
	):
		if (
			not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
			or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
		):
			return
		var record_result: StringName = &"ball_no_crossing"
		if _swing_consumed:
			PitchBatLabSwingSupport.ensure_miss(self)
			_match_state.record_strike(true)
			if (
				not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_boundary(
					self, terrain_owner, night_state
				)
			):
				return
			record_result = &"swinging_strike"
		else:
			_match_state.record_called_pitch(false)
			if (
				not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_boundary(
					self, terrain_owner, night_state
				)
			):
				return
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


func _continuous_input_blocked() -> bool:
	# Private scenes may reserve held aim keys while their own UI is open.
	return false


func _adjust_pitch_target(delta_xy: Vector2) -> void:
	PitchBatLabFeelSupport.adjust_pitch_target(self, delta_xy)


func _adjust_pitch_effort(delta: float) -> void:
	PitchBatLabFeelSupport.adjust_pitch_effort(self, delta)


func _adjust_batting_aim(delta_xy: Vector2) -> void:
	PitchBatLabFeelSupport.adjust_batting_aim(self, delta_xy)


func _selected_pitch() -> PitchDefinition:
	return MatchLabSupport.selected_pitch(self)


func _current_pitch_options() -> Array[PitchDefinition]:
	return MatchLabSupport.pitch_options(self)


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


func _cleanup_batted_ball(preserve_yard_launch: bool = false) -> void:
	var ac02_owner: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(self)
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _configured_match if _configured_match != null else _match_state
	if pool_controller_active != null and not pool_controller_active.release_ball():
		return
	# Shared supported cleanup: next pitch, reset, match advance and suspended-match resume.
	if not StadiumNpcYardTwoRuntimeV1.cleanup_play(self, preserve_yard_launch):
		return
	var yard_owner: StadiumNpcYardTwoPropertyV1 = StadiumNpcYardTwoRuntimeV1._property(self)
	var yard_play: int = yard_owner.play_generation if yard_owner != null else -1
	var cleanup_ball: Variant = _batted_ball
	var cleanup_resolver: BallPlayResolver = _ball_play_resolver
	var cleanup_play: BallPlayState = cleanup_resolver.state if cleanup_resolver != null else null
	var cleanup_match: MatchState = _match_state
	var hillside_owner: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(self)
	var hillside_cleanup: bool = hillside_owner != null and hillside_owner.venue_id == "HILLSIDE"
	var hillside_cleanup_state: MatchState = _match_state
	var hillside_cleanup_resolver: BallPlayResolver = _ball_play_resolver
	if hillside_cleanup:
		hillside_owner.clear_hillside_ball(cleanup_ball)
	if is_instance_valid(hillside_private_runtime):
		hillside_private_runtime.clear_ball(cleanup_ball)
	if _ball_visibility != null:
		_ball_visibility.clear()
	# clear emits visibility_changed; do not cancel a newer ball created by that callback.
	if (
		not StadiumSurfaceNightRuntime.continue_startup(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_startup(self, terrain_owner, night_state)
	):
		return
	if terrain_owner != null and _batted_ball != cleanup_ball:
		terrain_owner._abandon()
		return
	if night_owner != null and _batted_ball != cleanup_ball:
		StadiumSurfaceNightRuntime.retire_captured(self, night_owner)
		return
	if (
		yard_owner != null
		and (
			not StadiumNpcYardTwoRuntimeV1.validate_play(self, yard_play, yard_owner)
			or _batted_ball != cleanup_ball
		)
	):
		return
	if (
		hillside_cleanup
		and (
			not is_instance_valid(hillside_owner)
			or StadiumNpcPublicRuntime._property(self) != hillside_owner
			or _batted_ball != cleanup_ball
			or _match_state != hillside_cleanup_state
			or _ball_play_resolver != hillside_cleanup_resolver
			or hillside_owner.hillside_support == null
			or not hillside_owner.hillside_support.cleanup_owned()
		)
	):
		StadiumNpcPublicRuntime.reject_hillside_candidate(self, hillside_owner, cleanup_ball)
		return
	if ac02_owner != null and not ac02_owner.continue_action(self):
		return
	# Visibility callbacks may start a new plain-Day play too, not only an owned venue.
	if (
		_batted_ball != cleanup_ball
		or _ball_play_resolver != cleanup_resolver
		or _match_state != cleanup_match
		or (cleanup_resolver != null and cleanup_resolver.state != cleanup_play)
	):
		return
	StadiumRisingAppleRuntime.cleanup_current(self)
	reset_hillside_pitcher()
	if is_instance_valid(cleanup_ball):
		if cleanup_ball.surface_contact.is_connected(_on_batted_surface_contact):
			cleanup_ball.surface_contact.disconnect(_on_batted_surface_contact)
		if ac02_owner != null and not ac02_owner.clear_ball(self, cleanup_ball):
			return
		cleanup_ball.queue_free()
		_batted_ball = null
	var cleanup_hr: PitchBatLabHomeRun = _home_run
	var cleanup_fielder: FielderController = _primary_fielder
	var cleanup_had_fielder: bool = cleanup_fielder != null
	var cancelled_generation: int = cleanup_hr._generation + 1
	cleanup_hr.cancel()
	# Headline visibility callbacks may install a new play after retirement.
	# Do not end its fielder or reset its settled timer from the old cleanup.
	if (
		not is_instance_valid(self)
		or is_queued_for_deletion()
		or (
			cleanup_had_fielder
			and (not is_instance_valid(cleanup_fielder) or cleanup_fielder.is_queued_for_deletion())
		)
		or _home_run != cleanup_hr
		or cleanup_hr._generation != cancelled_generation
		or _batted_ball != null
		or _ball_play_resolver != cleanup_resolver
		or _match_state != cleanup_match
		or _primary_fielder != cleanup_fielder
		or (cleanup_resolver != null and cleanup_resolver.state != cleanup_play)
	):
		return
	if _primary_fielder != null:
		_primary_fielder.end_play()
	_settled_seconds = 0.0


func _reset_lab() -> void:
	if ac02_startup_pending():
		if _ac02_startup_attempt != null:
			_ac02_startup_attempt.abort("lab lifecycle interrupted startup")
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
	):
		return
	PitchBatLabFeelSupport.reset_debug_pause(self)
	PitchBatLabFeelSupport.cancel_release(self)
	PitchBatLabSwingSupport.reset(self)
	if _match_presentation_director != null:
		_match_presentation_director.reset()
	PitchBatLabPresentation.hide_match_presentation(self)
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
	):
		return
	_cleanup_batted_ball()
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(self, terrain_owner, night_state)
	):
		return

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
	if ac02_startup_pending() and (_match_state != null or _ac02_startup_attempt == null):
		if _ac02_startup_attempt != null:
			_ac02_startup_attempt.abort("new match reentered startup")
		return
	if has_meta(StadiumSurfaceTerrainRuntime.BOUND) and _match_state != null:
		StadiumSurfaceTerrainRuntime.retire(self, "NEW_MATCH")
		return
	if _managed_match and _match_state != null:
		return
	if has_meta(StadiumSurfaceNightRuntime.BOUND) and _match_state != null:
		StadiumSurfaceNightRuntime.retire(self, "NEW_MATCH")
		return
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _configured_match if _configured_match != null else _match_state
	StadiumPoolOwnedExtension.retire_installed_field(self, "NEW_MATCH")
	PitchBatLabFeelSupport.reset_debug_pause(self)
	PitchBatLabFeelSupport.cancel_release(self)
	PitchBatLabSwingSupport.reset(self)
	if _match_presentation_director != null:
		_match_presentation_director.reset()
	PitchBatLabPresentation.hide_match_presentation(self)
	PitchBatLabFeelSupport.clear_records(self)
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()
	if (
		not StadiumSurfaceNightRuntime.continue_startup(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_startup(self, terrain_owner, night_state)
	):
		return
	_cleanup_batted_ball()
	if (
		not StadiumSurfaceNightRuntime.continue_startup(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_startup(self, terrain_owner, night_state)
	):
		return
	if _configured_match == null:
		_player_home = false
		_stadium_ledger = null
	elif (
		_match_state != null
		and (
			StadiumLayoutSnapshot.key(_match_state.stadium)
			!= StadiumLayoutSnapshot.key(_configured_match.stadium)
		)
	):
		# A different fixture must arrive in a new lab with its own paid-prefix proof.
		_stadium_ledger = null
	_match_state = (
		_configured_match
		if _configured_match != null
		else (MatchLabSupport.create_match(DEBUG_PLAYER_ID, PLAYER_TEAM_NAME, RIVAL_TEAM_NAME))
	)
	_configured_match = null
	if (
		StadiumNpcYardTwoRuntimeV1.applies(self)
		and not StadiumNpcYardTwoRuntimeV1.rebind_match(self)
	):
		StadiumNpcYardTwoRuntimeV1.interrupt(self, StadiumNpcYardTwoRuntimeV1._property(self))
		return
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
	if _batter_approach != null:
		_batter_approach.reset_pitch()
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
	if StadiumNpcSnapshot.is_public(_match_state.stadium):
		var install_state: MatchState = _match_state
		var hillside_install: bool = (
			install_state.stadium.get("version")
			== StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
		)
		var install_ok: bool
		if ac02_startup_pending():
			install_ok = _ac02_startup_attempt != null and _ac02_startup_attempt.install()
			if not install_ok:
				yard_bound_startup_failed = true
				return
		else:
			install_ok = StadiumPropertyRuntime.install_bound(self)
		if (
			hillside_install
			and (
				_match_state != install_state
				or (not install_ok and is_instance_valid(StadiumNpcPublicRuntime._property(self)))
			)
		):
			return
		yard_bound_startup_failed = not install_ok
		if yard_bound_startup_failed:
			var failed_manifest: Variant = _match_state.stadium.get("manifest")
			if failed_manifest is Dictionary and failed_manifest.get("id") == "AY-03":
				StadiumNpcYardThreeRuntimeV1.refuse_bound_start(self)
			elif (
				failed_manifest is Dictionary
				and (
					failed_manifest.get("id")
					in [
						"AY-01",
						"AE-01",
						"AE-02",
						"AC-01",
						"AC-02",
						"AM-01",
						"AM-02",
						"LONG-YARD",
						"GRAND-I",
						"GRAND-II",
						"GRAND-III",
						"POOL-PARTY",
						"HILLSIDE"
					]
				)
			):
				StadiumNpcPublicRuntime.refuse_bound_start(self)
			else:
				StadiumNpcYardTwoRuntimeV1.interrupt(self, null)
			return
	if hillside_public_pending != null:
		return
	if ac02_startup_pending():
		if _ac02_startup_attempt != null:
			_ac02_startup_attempt.finish_setup()
		return
	_finish_new_match_start()


func _finish_new_match_start(hillside_owner: StadiumNpcPublicProperty = null) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(self)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(self)
	var night_state: MatchState = _match_state
	if (
		has_meta(StadiumSurfaceNightRuntime.BOUND)
		or StadiumSurfaceNightSnapshot.is_family(_match_state.stadium)
	):
		if not StadiumSurfaceNightRuntime.install_bound(self):
			StadiumSurfaceNightRuntime.retire_captured(self, night_owner)
			return
	if StadiumSurfaceTerrainRuntime.requested(self):
		if not StadiumSurfaceTerrainRuntime.install_bound(self):
			return
		terrain_owner = StadiumSurfaceTerrainRuntime.current(self)
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	SeasonOpponentChoices.prepare(self)
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_apply_role_camera()
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_status_label.text = (
		"TOP 1 • %s\nGame presentation starting"
		% ("Player batting" if _player_is_batting() else "Player pitching")
	)
	_live_label.text = ""
	_refresh_markers()
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	_refresh_config()
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	var bound_ready: bool = StadiumPoolBoundExtension.prepare_match_start(self)
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	pool_bound_startup_failed = not bound_ready
	if not pool_bound_startup_failed:
		var owned_ready: bool = StadiumPoolOwnedExtension.prepare_match_start(self)
		if not _hillside_start_context(hillside_owner):
			return
		if (
			not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
			or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
		):
			return
		pool_bound_startup_failed = not owned_ready
	if not _hillside_start_context(hillside_owner):
		return
	if (
		not StadiumSurfaceNightRuntime.continue_action(self, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(self, terrain_owner, night_state)
	):
		return
	if pool_bound_startup_failed or yard_bound_startup_failed:
		return
	if _automation != null:
		_automation.begin(self)
	else:
		PitchBatLabFeelSupport.begin_match_intro(self)


func _player_is_batting() -> bool:
	return MatchAutomation.player_batting(self)


func _player_is_pitching() -> bool:
	return MatchAutomation.player_pitching(self)


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


func _finish_hillside_public_start(property: StadiumNpcPublicProperty, state: MatchState) -> void:
	if (
		not is_instance_valid(property)
		or property.venue_id != "HILLSIDE"
		or StadiumNpcPublicRuntime._property(self) != property
		or _match_state != state
		or property.bound_state != state
		or hillside_public_pending != null
		or not property.issued
		or not property.callback_intact()
	):
		if is_instance_valid(property):
			property.retire_installation("The captured Hillside startup continuation changed")
		return
	_finish_new_match_start(property)
	# Startup presentation may emit callbacks; a changed match never inherits this issue.
	if (
		is_instance_valid(property)
		and (
			_match_state != state
			or StadiumNpcPublicRuntime._property(self) != property
			or not property.callback_intact()
		)
	):
		property.retire_installation("The Hillside startup callback changed its bound match")


func _report_hillside_public_install(success: bool, state: MatchState) -> void:
	if (
		_hillside_public_install_reported
		or state != _hillside_public_install_state
		or _match_state != state
	):
		return
	_hillside_public_install_reported = true
	hillside_public_install_finished.emit(success and _match_state == state)


func _hillside_launch_context(
	property: StadiumNpcPublicProperty, state: MatchState, resolver: BallPlayResolver
) -> bool:
	if property == null:
		return true
	if (
		is_instance_valid(property)
		and _match_state == state
		and _ball_play_resolver == resolver
		and StadiumNpcPublicRuntime._property(self) == property
		and property.hillside_owner_intact()
		and property.callback_intact()
	):
		return true
	if is_instance_valid(property):
		property.retire_installation("The captured Hillside launch context changed")
	return false


func _hillside_start_context(property: StadiumNpcPublicProperty) -> bool:
	return (
		property == null
		or (
			is_instance_valid(property)
			and property.hillside_support != null
			and property.hillside_support.cleanup_owned()
		)
	)

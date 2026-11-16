extends RefCounted

const AIM_SPEED_MPS: float = 0.82


static func adjust_pitch_target(lab: PitchBatLab, delta_xy: Vector2) -> void:
	lab._pitch_target.x = clampf(
		lab._pitch_target.x + delta_xy.x, lab.PITCH_AIM_MIN_X, lab.PITCH_AIM_MAX_X
	)
	lab._pitch_target.y = clampf(
		lab._pitch_target.y + delta_xy.y, lab.PITCH_AIM_MIN_Y, lab.PITCH_AIM_MAX_Y
	)
	lab._refresh_markers()
	lab._refresh_config()


static func adjust_pitch_effort(lab: PitchBatLab, delta: float) -> void:
	lab._pitch_effort = clampf(
		lab._pitch_effort + delta, MatchLabSupport.MIN_EFFORT, MatchLabSupport.MAX_EFFORT
	)
	lab._refresh_config()


static func adjust_batting_aim(lab: PitchBatLab, delta_xy: Vector2) -> void:
	lab._batting_aim.x = clampf(
		lab._batting_aim.x + delta_xy.x, lab.BATTING_AIM_MIN_X, lab.BATTING_AIM_MAX_X
	)
	lab._batting_aim.y = clampf(
		lab._batting_aim.y + delta_xy.y, lab.BATTING_AIM_MIN_Y, lab.BATTING_AIM_MAX_Y
	)
	lab._refresh_markers()
	lab._refresh_config()


static func initialize(lab: PitchBatLab) -> void:
	lab._sounds = PlaySounds.new()
	lab.add_child(lab._sounds)
	lab._sounds.set_muted(lab._sounds_muted)
	lab._ball_visibility = BallVisibility.new()
	lab.add_child(lab._ball_visibility)
	lab._release_controller = PitchReleaseController.new()
	lab._at_bat_cadence = AtBatCadenceController.new()
	lab._batter_approach = BatterApproachModel.new()
	lab._swing_tracker = SwingContactTracker.new()
	lab._match_presentation_director = MatchPresentationDirector.new()
	if lab._camera_director == null:
		lab._camera_director = MatchCameraDirector.new()
	lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
	lab._camera_director.snap(lab._camera)


static func _reset_pitcher_telegraph(lab: PitchBatLab) -> void:
	if lab._pitcher_marker == null:
		return
	lab.reset_hillside_pitcher()
	if lab._pitcher_avatar != null:
		lab._pitcher_avatar.reset_pose()


static func _update_at_bat_cadence(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._at_bat_cadence == null:
		return
	var cadence_delta: float = delta_seconds
	if lab._automation != null and not lab._home_run.active:
		# Omit presentation-only set/windup/result waits, never flight or Jolt time.
		cadence_delta = (
			maxf(
				lab._at_bat_cadence.active_delivery_seconds, lab._at_bat_cadence.active_hold_seconds
			)
			+ delta_seconds
		)
	var event: AtBatCadenceController.Event = lab._at_bat_cadence.advance(cadence_delta)
	match event:
		AtBatCadenceController.Event.THROW_PITCH:
			_reset_pitcher_telegraph(lab)
			lab._throw_pitch()
		AtBatCadenceController.Event.CONTINUE_PLAY:
			lab._handle_match_advance()
		_:
			pass


static func _update_camera(lab: PitchBatLab, delta_seconds: float) -> void:
	var ball_live: bool = lab._ball_in_play_is_live() or lab._home_run.active
	var ball_position: Vector3 = (
		lab._batted_ball.global_position if lab._batted_ball != null else Vector3.ZERO
	)
	var pitch_live: bool = lab._pitch_actor != null and lab._pitch_actor.running
	lab._camera_director.track_released_pitch(
		pitch_live, lab._pitch_actor.state.position if pitch_live else Vector3.ZERO
	)
	lab._camera_director.update(lab._camera, delta_seconds, ball_live, ball_position)


static func _apply_bat_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"bat_aim_left", &"bat_aim_right", &"bat_aim_down", &"bat_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_batting_aim(direction * amount)
static func _apply_pitch_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"pitch_aim_left", &"pitch_aim_right", &"pitch_aim_down", &"pitch_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_pitch_target(direction * amount)


static func _update_continuous_input(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._automation != null:
		return
	var amount: float = AIM_SPEED_MPS * delta_seconds
	if lab._match_mode:
		if (
			lab._player_is_pitching()
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
			and not lab._release_controller.active
			and not lab._field_setup_active
			and not lab._pitching_staff_active
		):
			_apply_pitch_aim(lab, amount)
		elif lab._player_is_batting() and not lab._swing_consumed:
			_apply_bat_aim(lab, amount)
		return
	_apply_pitch_aim(lab, amount)
	_apply_bat_aim(lab, amount)


static func _finish_intro(lab: PitchBatLab, snap_camera: bool) -> void:
	lab._camera_director.clear_presentation_motion()
	lab._apply_role_camera()
	if snap_camera:
		lab._camera_director.snap(lab._camera)
	PitchBatLabPresentation.hide_match_presentation(lab)
	if lab._player_is_batting():
		lab._awaiting_batter_confirm = true
		lab._status_label.text = (
			"%s steps in\nLeft click, SPACE, or controller A to begin the at-bat."
			% lab._match_state.batter().definition.display_name
		)
		lab._refresh_config()
	else:
		lab._awaiting_batter_confirm = false
		lab._status_label.text = ""
		lab._refresh_config()

	SeasonOpponentChoices.disclose(lab)


static func _sync_presentation_camera(lab: PitchBatLab) -> void:
	var result_view: bool = (
		lab._match_presentation_director.mode
		in [MatchPresentationDirector.Mode.OUTRO, MatchPresentationDirector.Mode.OUTRO_HOLD]
	)
	lab._camera_director.set_presentation_motion(
		lab._match_presentation_director.current_motion(),
		lab._match_presentation_director.shot_progress(),
		0.8 if result_view else MatchCameraDirector.TRANSITION_SPEED
	)


static func _update_match_presentation(lab: PitchBatLab, delta_seconds: float) -> bool:
	if (
		lab._match_presentation_director == null
		or not lab._match_presentation_director.blocks_gameplay()
	):
		return false
	var event: MatchPresentationDirector.Event = lab._match_presentation_director.advance(
		delta_seconds
	)
	match event:
		MatchPresentationDirector.Event.SHOT_CHANGED:
			lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
		MatchPresentationDirector.Event.RETURN_TO_GAMEPLAY:
			lab._camera_director.clear_presentation_motion()
			lab._apply_role_camera()
		MatchPresentationDirector.Event.INTRO_COMPLETE:
			_finish_intro(lab, false)
		MatchPresentationDirector.Event.OUTRO_COMPLETE:
			_sync_presentation_camera(lab)
		_:
			pass
	if (
		lab._match_presentation_director.mode == MatchPresentationDirector.Mode.INTRO
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD
	):
		_sync_presentation_camera(lab)
	return true


static func commit_pitch_release(lab: PitchBatLab) -> void:
	if not lab._release_controller.active or lab._match_state == null:
		return
	var pitcher_state: PlayerMatchState = lab._match_state.pitcher()
	var fatigue: float = maxf(pitcher_state.fatigue_ratio(), lab._fatigue)
	lab._pending_release_overdrive = lab._release_controller.overdrive_amount()
	lab._pending_release_quality = lab._release_controller.release(
		pitcher_state.definition.control, fatigue
	)
	lab._last_release_quality = lab._pending_release_quality
	lab._last_release_offset_seconds = (lab._release_controller.last_offset_seconds)
	lab._throw_pitch()


static func _update_pitch_release(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._release_controller == null or not lab._release_controller.active:
		return
	if lab._release_controller.advance(delta_seconds):
		commit_pitch_release(lab)
	else:
		lab._refresh_config()


static func _update_pitcher_telegraph(lab: PitchBatLab) -> void:
	if lab._pitcher_marker == null or lab._match_state == null:
		return
	var progress: float = -1.0
	var ai_delivery: bool = false
	if (
		lab._at_bat_cadence != null
		and lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
	):
		progress = lab._at_bat_cadence.delivery_progress()
		ai_delivery = true
	elif (
		lab._player_is_pitching()
		and lab._release_controller != null
		and lab._release_controller.active
	):
		progress = lab._release_controller.meter_progress()
	if progress < 0.0:
		return
	if (
		lab.hillside_pitcher_motion != null
		and not lab.hillside_pitcher_motion.begin_pitcher_presentation(lab)
	):
		return
	var lift: float = sin(progress * PI)
	var selected_pitch: PitchDefinition = lab._selected_pitch()
	var slot_amount: float = 0.08
	var sidearm: bool = false
	if (
		selected_pitch != null
		and selected_pitch.delivery_profile != null
		and selected_pitch.delivery_profile.delivery >= DeliveryProfileDefinition.Delivery.SIDEARM
	):
		slot_amount = 0.22
		sidearm = true
	var handedness: float = (
		-1.0
		if (lab._match_state.pitcher().definition.throws == PlayerDefinition.Handedness.LEFT)
		else 1.0
	)
	lab._pitcher_marker.position = (
		lab.MOUND_ORIGIN
		+ Vector3(
			handedness * slot_amount * lift, 0.16 * lift, -0.18 * smoothstep(0.55, 1.0, progress)
		)
	)
	if lab.hillside_pitcher_motion != null:
		lab.hillside_pitcher_motion.set_pitcher_rotation(handedness * slot_amount * lift)
	else:
		lab._pitcher_marker.rotation.z = handedness * slot_amount * lift
	if lab._pitcher_avatar != null:
		lab._pitcher_avatar.set_pitch_delivery_progress(progress, sidearm)
	if ai_delivery and lab._action_label != null:
		lab._action_label.text = lab._at_bat_cadence.delivery_cue()


static func cadence_noop(lab: PitchBatLab) -> bool:
	return (
		lab._at_bat_cadence == null
		or (
			lab._at_bat_cadence.get_script() == AtBatCadenceController
			and (
				lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
				or lab._at_bat_cadence.state == AtBatCadenceController.State.PITCH_LIVE
			)
			and (
				lab._automation == null
				or (lab._home_run != null and lab._home_run.get_script() == PitchBatLabHomeRun)
			)
		)
	)


static func continuous_release_noop(lab: PitchBatLab) -> bool:
	return (
		lab._automation != null
		and (
			lab._release_controller == null
			or (
				lab._release_controller.get_script() == PitchReleaseController
				and not lab._release_controller.active
			)
		)
	)


static func home_run_noop(lab: PitchBatLab) -> bool:
	return (
		lab._home_run != null
		and lab._home_run.get_script() == PitchBatLabHomeRun
		and not lab._home_run.active
	)


static func owned_noop_scope(
	lab: PitchBatLab, owner: StadiumSurfaceNightRuntime, state: MatchState
) -> bool:
	# A synchronous local proof, never an admission check or a cached frame lease.
	# Candidate3 reuses only these same exact no-op branches after a full action check.
	return (
		is_instance_valid(lab)
		and lab.get_script() == PitchBatLab
		and owner != null
		and owner.get_script() == StadiumSurfaceNightRuntime
		and StadiumSurfaceNightRuntime.current(lab) == owner
		and (owner._floodlight_mode or owner._kit_mode)
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and not owner._restoring
		and not owner._tree_transition
		and owner._lab != null
		and owner._lab.get_ref() == lab
		and state != null
		and state.get_script() == MatchState
		and owner._state == state
		and lab._match_state == state
		and not lab.has_meta(StadiumSurfaceTerrainRuntime.OWNER)
		and not lab.has_meta(StadiumSurfaceTerrainRuntime.BOUND)
	)


static func update(lab: PitchBatLab, delta_seconds: float) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	if lab.has_meta("loadout_open"):
		return
	if not MatchAutomation.presented(lab):
		# Keep the exact gameplay cadence and home-run body/hold lifecycle.
		if not lab._debug_paused:
			lab._home_run.advance(lab, delta_seconds)
			if (
				not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
			):
				return
			_update_at_bat_cadence(lab, delta_seconds)
			if (
				not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
			):
				return
		return
	lab._pitch_feedback.advance(lab, delta_seconds)
	if lab._debug_paused:
		_update_camera(lab, delta_seconds)
		return
	if _update_match_presentation(lab, delta_seconds):
		_update_camera(lab, delta_seconds)
		PitchBatLabPresentation.refresh_event(lab)
		return
	lab._ball_visibility.update_ball(
		lab._batted_ball,
		lab._camera,
		delta_seconds,
		(
			lab._camera_director.tracking_visibility.field_wall_z
			if lab.has_meta("stadium_property")
			else lab._field_definition.back_wall_z_m
		)
	)
	if (
		not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
	):
		return
	# Reuse only the immediately preceding check across exact, read-only branches.
	# Active helpers, foreign scripts and every outer/event entry retain their checks.
	var release_noop: bool = (
		owned_noop_scope(lab, night_owner, night_state) and continuous_release_noop(lab)
	)
	_update_continuous_input(lab, delta_seconds)
	_update_pitch_release(lab, delta_seconds)
	if (
		(
			(not release_noop or not owned_noop_scope(lab, night_owner, night_state))
			and not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
		)
		or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
	):
		return
	var home_noop: bool = owned_noop_scope(lab, night_owner, night_state) and home_run_noop(lab)
	lab._home_run.advance(lab, delta_seconds)
	if (
		(
			(not home_noop or not owned_noop_scope(lab, night_owner, night_state))
			and not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
		)
		or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
	):
		return
	var cadence_is_noop: bool = (
		owned_noop_scope(lab, night_owner, night_state) and cadence_noop(lab)
	)
	_update_at_bat_cadence(lab, delta_seconds)
	if (
		(
			(not cadence_is_noop or not owned_noop_scope(lab, night_owner, night_state))
			and not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
		)
		or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
	):
		return
	_update_pitcher_telegraph(lab)
	_update_camera(lab, delta_seconds)
	PitchBatLabPresentation.refresh_event(lab)


static func swing_noop(lab: PitchBatLab) -> bool:
	# This branch returns before advance_swing reads the actor or calls the tracker.
	return (
		lab._swing_tracker == null
		or (
			lab._swing_tracker.get_script() == SwingContactTracker and not lab._swing_tracker.active
		)
	)


static func begin_match_intro(lab: PitchBatLab) -> void:
	if lab._match_presentation_director == null:
		lab._match_presentation_director = MatchPresentationDirector.new()
	lab._at_bat_cadence.stop()
	lab._status_label.text = ""
	PitchBatLabPresentation.refresh_event(lab)
	lab._match_presentation_director.begin_intro(int(Time.get_ticks_usec() & 0x7fffffff))
	lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
	_sync_presentation_camera(lab)
	lab._camera_director.snap(lab._camera)
	PitchBatLabPresentation.show_match_intro(lab)


static func begin_match_outro(lab: PitchBatLab) -> void:
	if lab._automation != null:
		lab._at_bat_cadence.stop()
		return
	if (
		lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or lab._match_presentation_director == null
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO
		or lab._match_presentation_director.mode == MatchPresentationDirector.Mode.OUTRO_HOLD
	):
		return
	lab._at_bat_cadence.stop()
	lab._status_label.text = ""
	PitchBatLabPresentation.refresh_event(lab)
	lab._match_presentation_director.begin_outro(int(Time.get_ticks_usec() & 0x7fffffff))
	lab._camera_director.set_shot(lab._match_presentation_director.current_shot())
	_sync_presentation_camera(lab)
	PitchBatLabPresentation.show_match_outro(
		lab,
		(
			lab._match_state.winner_name
			== (
				lab._match_state.home_team.display_name
				if lab._player_home
				else lab._match_state.away_team.display_name
			)
		)
	)


static func skip_match_presentation(lab: PitchBatLab) -> void:
	if lab._match_presentation_director == null:
		return
	var event: MatchPresentationDirector.Event = lab._match_presentation_director.skip()
	if event == MatchPresentationDirector.Event.INTRO_COMPLETE:
		_finish_intro(lab, true)
	elif event == MatchPresentationDirector.Event.OUTRO_COMPLETE:
		_sync_presentation_camera(lab)


static func _begin_ai_delivery_cadence(lab: PitchBatLab, seed_offset: int = 0) -> void:
	if lab._at_bat_cadence == null or lab._match_state == null:
		return
	lab._at_bat_cadence.begin_delivery(
		(
			lab._throw_number * 811
			+ lab._match_state.plate_appearance_number * 131
			+ lab._match_state.inning * 17
			+ seed_offset
		)
	)
	lab._status_label.text = ""
	lab._refresh_config()


static func begin_ai_delivery(lab: PitchBatLab) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	# prepare handles both roles and can end the game through Take A Base.
	# Full validation precedes its actual pre-PA work, not every cadence tick.
	if (
		night_state != null
		and night_state.phase == MatchState.Phase.PRE_PITCH
		and night_state.between_batters
		and (
			not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
			or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
		)
	):
		return
	SeasonOpponentChoices.prepare(lab)
	if (
		not StadiumSurfaceNightRuntime.continue_action(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state)
	):
		return
	if (
		not MatchAutomation.pitching(lab)
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or (lab._pitch_actor != null and lab._pitch_actor.running)
		or lab._at_bat_cadence == null
		or lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
	):
		return
	if not lab._ai_pitch_preselected:
		MatchLabSupport.apply_ai_pitch_choice(lab)
	lab._ai_pitch_preselected = true
	_begin_ai_delivery_cadence(lab)


static func confirm_batter_ready(lab: PitchBatLab) -> void:
	if (
		not lab._awaiting_batter_confirm
		or not lab._player_is_batting()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
	):
		return
	lab._awaiting_batter_confirm = false
	begin_ai_delivery(lab)


static func request_batter_timeout(lab: PitchBatLab) -> bool:
	if not lab._player_is_batting() or lab._debug_paused or lab._awaiting_batter_confirm:
		return false
	if lab._match_state.phase != MatchState.Phase.PRE_PITCH or lab._match_state.batter_timeout_used:
		return false
	var cadence: AtBatCadenceController = lab._at_bat_cadence
	if (
		cadence.state != AtBatCadenceController.State.DELIVERY
		or cadence.elapsed_seconds >= cadence.active_set_seconds
	):
		return false
	lab._match_state.batter_timeout_used = true
	cadence.stop()
	_reset_pitcher_telegraph(lab)
	lab._awaiting_batter_confirm = true
	lab._status_label.text = "TIME\nClick or Space when ready"
	lab._refresh_config()
	return true


static func handle_match_advance(lab: PitchBatLab) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	if lab._match_state == null or lab._ball_in_play_is_live():
		return
	match lab._match_state.phase:
		MatchState.Phase.PRE_PITCH:
			if lab._player_is_batting():
				confirm_batter_ready(lab)
			else:
				lab._throw_pitch()
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION:
			lab._at_bat_cadence.stop()
			var changed_half: bool = lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
			var completed_plate_appearance: bool = lab._match_state.between_batters
			lab._cleanup_batted_ball()
			if (
				not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
				or not StadiumSurfaceTerrainRuntime.continue_boundary(
					lab, terrain_owner, night_state
				)
			):
				return
			lab._match_state.continue_after_dead_ball()
			lab._base_state = lab._match_state.bases
			if lab._automation != null:
				lab._automation.select_offense(lab)
			if completed_plate_appearance and lab._batter_approach != null:
				lab._batter_approach.begin_plate_appearance(
					lab._match_state.plate_appearance_number
				)
				lab._last_ai_awareness = 0.0
				lab._last_ai_read_text = "New batter"
			if changed_half:
				lab._field_setup_active = false
				lab._pitching_staff_active = false
				lab._selected_pitch_index = 0
				lab._pitch_effort = 1.0
				MatchLabSupport.assign_ai_defense_for_half(lab)
			elif completed_plate_appearance and MatchAutomation.pitching(lab):
				MatchLabSupport.consider_ai_pitching_change(lab)
				MatchLabSupport.assign_ai_fielder_anchor(lab)
			lab._awaiting_batter_confirm = (
				lab._automation == null
				and lab._player_is_batting()
				and (completed_plate_appearance or changed_half)
			)
			lab._apply_defensive_assignment()
			SeasonOpponentChoices.prepare(lab)
			if not StadiumSurfaceTerrainRuntime.continue_action(lab, terrain_owner, night_state):
				return
			lab._apply_role_camera()
			if lab._match_state.phase == MatchState.Phase.GAME_END:
				begin_match_outro(lab)
			else:
				lab._status_label.text = lab._match_state.last_event
				if lab._awaiting_batter_confirm:
					lab._status_label.text += "\nClick to begin the next at-bat"
			lab._refresh_markers()
			lab._refresh_config()
			if (
				MatchAutomation.pitching(lab)
				and lab._match_state.phase == MatchState.Phase.PRE_PITCH
				and not lab._awaiting_batter_confirm
			):
				begin_ai_delivery(lab)
		MatchState.Phase.GAME_END:
			begin_match_outro(lab)


static func notify_pitch_dead(lab: PitchBatLab) -> void:
	if lab._home_run.active:
		if lab._match_mode:
			lab._at_bat_cadence.hold_dead_ball()
			lab._at_bat_cadence.active_hold_seconds = PitchBatLabHomeRun.HOLD_SECONDS
		else:
			lab._at_bat_cadence.stop()
		return
	# Preserve the actual fielding position through the readable result hold.
	if lab._batted_ball == null:
		_reset_pitcher_telegraph(lab)
	if lab._match_state != null and lab._match_state.phase == MatchState.Phase.GAME_END:
		lab._at_bat_cadence.hold_dead_ball()
		lab._at_bat_cadence.active_hold_seconds = 2.5
		return
	if (
		lab._match_state != null
		and (
			lab._match_state.phase == MatchState.Phase.PLAY_DEAD
			or lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
		)
	):
		lab._at_bat_cadence.hold_dead_ball(
			lab._throw_number * 457 + lab._match_state.plate_appearance_number * 73,
			lab._match_state.between_batters,
			lab._match_state.phase == MatchState.Phase.INNING_TRANSITION
		)
		return
	lab._at_bat_cadence.stop()


static func recover_failed_pitch(lab: PitchBatLab, pitch: PitchDefinition) -> void:
	if lab._match_mode and lab._match_state != null:
		lab._match_state.cancel_pitch()
		if lab._at_bat_cadence != null:
			lab._at_bat_cadence.stop()
	lab._pending_release_quality = 1.0
	lab._pending_release_overdrive = 0.0
	if (
		lab._match_mode
		and MatchAutomation.pitching(lab)
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._current_pitch_options().is_empty()
	):
		lab._selected_pitch_index = 0
		lab._pitch_target = lab.DEFAULT_TARGET
		lab._pitch_effort = 1.0
		lab._last_ai_pitch_index = 0
		lab._ai_pitch_preselected = true
		lab._awaiting_batter_confirm = false
		_begin_ai_delivery_cadence(lab, 7919)
		lab._status_label.text = (
			"%s flight reset safely. Pitcher preparing a center fallback." % pitch.display_name
		)
		lab._refresh_markers()
		lab._refresh_config()
		return
	lab._status_label.text = (
		"%s could not produce a valid flight. Adjust effort/target and retry." % pitch.display_name
	)
	lab._refresh_config()


static func set_batting_aim_from_screen(lab: PitchBatLab, screen_position: Vector2) -> bool:
	if lab._camera == null:
		return false
	var ray_origin: Vector3 = lab._camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = lab._camera.project_ray_normal(screen_position)
	if absf(ray_direction.z) <= 0.000001:
		return false
	var distance: float = (ContactResolver.CONTACT_PLANE_Z - ray_origin.z) / ray_direction.z
	if distance <= 0.0:
		return false
	var world_point: Vector3 = ray_origin + ray_direction * distance
	lab._batting_aim = Vector2(
		clampf(world_point.x, lab.BATTING_AIM_MIN_X, lab.BATTING_AIM_MAX_X),
		clampf(world_point.y, lab.BATTING_AIM_MIN_Y, lab.BATTING_AIM_MAX_Y)
	)
	lab._refresh_markers()
	return true


static func set_pitch_target_from_screen(lab: PitchBatLab, screen_position: Vector2) -> bool:
	if lab._camera == null:
		return false
	var ray_origin: Vector3 = lab._camera.project_ray_origin(screen_position)
	var ray_direction: Vector3 = lab._camera.project_ray_normal(screen_position)
	if absf(ray_direction.z) <= 0.000001:
		return false
	var distance: float = -ray_origin.z / ray_direction.z
	if distance <= 0.0:
		return false
	var world_point: Vector3 = ray_origin + ray_direction * distance
	lab._pitch_target = Vector2(
		clampf(world_point.x, lab.PITCH_AIM_MIN_X, lab.PITCH_AIM_MAX_X),
		clampf(world_point.y, lab.PITCH_AIM_MIN_Y, lab.PITCH_AIM_MAX_Y)
	)
	lab._refresh_markers()
	lab._refresh_config()
	return true


static func toggle_debug_pause(lab: PitchBatLab) -> void:
	lab._debug_paused = not lab._debug_paused
	lab.get_tree().paused = lab._debug_paused
	if lab._debug_paused:
		lab._status_before_pause = lab._status_label.text
		lab._status_label.text = "PAUSED • V: camera • Esc: resume"
	else:
		lab._display_menu_open = false
		lab._status_label.text = lab._status_before_pause
		lab._camera_director.restore_after_pause()
	lab._refresh_config()


static func reset_debug_pause(lab: PitchBatLab) -> void:
	if not lab._debug_paused:
		return
	lab._debug_paused = false
	lab._display_menu_open = false
	lab.get_tree().paused = false
	lab._status_label.text = lab._status_before_pause
	lab._camera_director.restore_after_pause()


static func _can_suspend_match_for_lab(lab: PitchBatLab) -> bool:
	return (
		lab._match_state != null
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._field_setup_active
		and not lab._pitching_staff_active
		and (lab._pitch_actor == null or not lab._pitch_actor.running)
		and not lab._ball_in_play_is_live()
		and (lab._release_controller == null or not lab._release_controller.active)
		and (
			lab._at_bat_cadence == null
			or lab._at_bat_cadence.state == AtBatCadenceController.State.IDLE
		)
		and (
			lab._match_presentation_director == null
			or not lab._match_presentation_director.blocks_gameplay()
		)
	)


static func cancel_release(lab: PitchBatLab) -> void:
	if lab._release_controller != null:
		lab._release_controller.cancel()
	lab._pending_release_quality = 1.0
	lab._pending_release_overdrive = 0.0
	lab._last_release_offset_seconds = 0.0
	if lab._at_bat_cadence != null:
		lab._at_bat_cadence.stop()
	_reset_pitcher_telegraph(lab)


static func _resume_suspended_match(lab: PitchBatLab) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	cancel_release(lab)
	PitchBatLabSwingSupport.reset(lab)
	if lab._pitch_actor != null:
		lab._pitch_actor.reset_pitch()
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	lab._cleanup_batted_ball()
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	if lab._match_state == null or lab._match_suspend_snapshot.is_empty():
		lab._match_mode = true
		lab._start_new_match()
		return
	lab._match_mode = true
	lab._base_state = lab._match_state.bases
	lab._selected_pitch_index = int(lab._match_suspend_snapshot["selected_pitch_index"])
	lab._pitch_target = lab._match_suspend_snapshot["pitch_target"] as Vector2
	lab._batting_aim = lab._match_suspend_snapshot["batting_aim"] as Vector2
	lab._fatigue = float(lab._match_suspend_snapshot["fatigue"])
	lab._pitch_effort = float(lab._match_suspend_snapshot["pitch_effort"])
	lab._fielder_anchor_index = int(lab._match_suspend_snapshot["fielder_anchor_index"])
	lab._awaiting_batter_confirm = bool(lab._match_suspend_snapshot["awaiting_batter_confirm"])
	lab._ai_pitch_preselected = bool(lab._match_suspend_snapshot["ai_pitch_preselected"])
	lab._last_ai_pitch_index = int(lab._match_suspend_snapshot["last_ai_pitch_index"])
	lab._last_ai_awareness = float(lab._match_suspend_snapshot["last_ai_awareness"])
	lab._last_ai_read_text = String(lab._match_suspend_snapshot["last_ai_read_text"])
	lab._debug_overlay_visible = bool(lab._match_suspend_snapshot["debug_overlay_visible"])
	lab._status_label.text = String(lab._match_suspend_snapshot["status_text"])
	lab._match_suspend_snapshot.clear()
	lab._field_setup_active = false
	lab._pitching_staff_active = false
	lab._apply_defensive_assignment()


static func _suspend_match_for_lab(lab: PitchBatLab) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	lab._match_suspend_snapshot = {
		"selected_pitch_index": lab._selected_pitch_index,
		"pitch_target": lab._pitch_target,
		"batting_aim": lab._batting_aim,
		"fatigue": lab._fatigue,
		"pitch_effort": lab._pitch_effort,
		"fielder_anchor_index": lab._fielder_anchor_index,
		"awaiting_batter_confirm": lab._awaiting_batter_confirm,
		"ai_pitch_preselected": lab._ai_pitch_preselected,
		"last_ai_pitch_index": lab._last_ai_pitch_index,
		"last_ai_awareness": lab._last_ai_awareness,
		"last_ai_read_text": lab._last_ai_read_text,
		"debug_overlay_visible": lab._debug_overlay_visible,
		"status_text": lab._status_label.text,
	}
	lab._match_mode = false
	lab._debug_overlay_visible = true
	lab._base_state = lab._debug_base_state
	lab._reset_lab()
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	lab._status_label.text = "MECHANICS LAB\nF2 resumes the suspended match."

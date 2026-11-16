extends RefCounted
## Stateless operations for the original PitchBatLabFeelSupport script.


static func _public_start_record(
	lab: PitchBatLab,
	pitch: PitchDefinition,
	fatigue: float,
	execution_quality: float,
	play_seed: int,
	release_overdrive: float = 0.0
) -> void:
	if lab.ac02_startup_pending():
		return
	var record: PlayRecord = PlayRecord.new()
	record.mode = "match" if lab._match_mode else "mechanics_lab"
	record.play_number = lab._throw_number
	record.pitch_id = pitch.id
	record.intended_target = lab._pitch_target
	record.effort = lab._pitch_effort
	record.fatigue = fatigue
	record.execution_quality = execution_quality
	record.release_offset_seconds = lab._last_release_offset_seconds
	record.release_overdrive = release_overdrive
	record.seed = play_seed
	if lab._match_mode and lab._match_state != null:
		record.inning = lab._match_state.inning
		record.top_half = lab._match_state.top_half
		record.balls_before = lab._match_state.balls
		record.strikes_before = lab._match_state.strikes
		record.outs_before = lab._match_state.outs
		record.batter_id = lab._match_state.batter().definition.id
		record.pitcher_id = lab._match_state.pitcher().definition.id
		record.batter_hand = lab._match_state.batter().batting_hand()
		record.pitcher_hand = lab._match_state.pitcher().definition.throws
	lab._active_play_record = record


static func _public_note_crossing(lab: PitchBatLab, point: Vector3, speed_mps: float) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.crossed_plate = true
	lab._active_play_record.crossing_point = Vector2(point.x, point.y)
	lab._active_play_record.plate_speed_mps = speed_mps


static func _public_note_swing(
	lab: PitchBatLab, profile_id: StringName, aim_point: Vector2, result: ContactResult
) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.swing_profile_id = profile_id
	lab._active_play_record.swing_aim = aim_point
	lab._active_play_record.contact_outcome = result.outcome
	lab._active_play_record.contact_quality = result.quality
	lab._active_play_record.timing_error_m = result.timing_error_m
	lab._active_play_record.horizontal_error_m = result.horizontal_error_m
	lab._active_play_record.vertical_error_m = result.vertical_error_m
	lab._active_play_record.exit_speed_mps = result.exit_velocity.length()
	lab._active_play_record.launch_angle_degrees = result.launch_angle_degrees
	lab._active_play_record.spray_degrees = result.spray_degrees
	lab._active_play_record.frozen_launch = result.frozen_launch.duplicate(true)


static func _public_note_first_ground(lab: PitchBatLab, position: Vector3) -> void:
	if lab._active_play_record == null or lab._active_play_record.has_first_ground:
		return
	lab._active_play_record.has_first_ground = true
	lab._active_play_record.first_ground_position = position


static func _public_note_ball_play_outcome(
	lab: PitchBatLab,
	outcome: BallPlayOutcome,
	last_defender_touch: StringName,
	result_floor: BallPlayState.ResultFloor
) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.stadium_contacts = (
		lab._ball_play_resolver.state.stadium_contacts.duplicate(true)
	)
	lab._active_play_record.resolution_reason = outcome.reason
	lab._active_play_record.resolution_position = outcome.resolution_position
	lab._active_play_record.last_defender_touch = last_defender_touch
	lab._active_play_record.result_floor = int(result_floor)


static func _public_record_clean_fielding_control(
	lab: PitchBatLab, defender_id: StringName, resolved_position: Vector3, ball_was_moving: bool
) -> void:
	var is_airborne: bool = not lab._ball_play_resolver.state.has_grounded
	if (
		defender_id == &"pitcher"
		and PitcherDefense.can_attempt(resolved_position, lab.MOUND_ORIGIN)
	):
		lab._ball_play_resolver.record_pitcher_clean_control(
			resolved_position, is_airborne, ball_was_moving
		)
	else:
		lab._ball_play_resolver.record_clean_control(
			defender_id, resolved_position, is_airborne, ball_was_moving
		)


static func _public_finish_record(
	lab: PitchBatLab, result: StringName, runs_scored: int = 0
) -> void:
	if lab.ac02_startup_pending():
		return
	if lab._active_play_record == null:
		return
	# Explicit issued-v1 automated completion is in-memory only, not an export proof.
	# A consumed refusal never falls through to historical record completion.
	if StadiumNpcAc02IssuedStateV1.complete_automated_record(lab, result, runs_scored):
		return
	if StadiumNpcAc02IssuedStateV1.complete_manual_record(lab, result, runs_scored):
		return
	lab._active_play_record.result = result
	lab._active_play_record.runs_scored = runs_scored
	lab._play_records.append(lab._active_play_record)
	lab._active_play_record = null
	# Literal historical per-play save remains. A matching successful save can also
	# acknowledge earlier pending native records, but custom completion creates no batch.
	var context: Dictionary = PitchBatLabFeelSupport._begin_manual_qc_export(lab)
	var saved: bool = PitchBatLabFeelSupport._save_records(lab)
	PitchBatLabFeelSupport._end_manual_qc_export(context, saved)


static func _public_clear_records(lab: PitchBatLab) -> void:
	if not lab._ac02_issued_history:
		lab._active_play_record = null
		lab._play_records.clear()
		lab._record_export = PlayRecordExport.new()
		return
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	# Automated resets retain the original path; manual telemetry never classifies them.
	if (
		issue != null
		and issue._bindings_pin.get("lab") == lab
		and issue._bindings_pin.get("automation") != null
	):
		lab._active_play_record = null
		lab._play_records.clear()
		lab._record_export = PlayRecordExport.new()
		return
	var state: MatchState = lab._match_state
	var exporter: PlayRecordExport = lab._record_export
	var records: Array[PlayRecord] = lab._play_records
	if issue == null or not issue.manual_qc_owner(lab):
		return
	if (
		issue._manual_qc_started
		and (
			exporter != issue._manual_qc_exporter or not is_same(records, issue._manual_qc_records)
		)
	):
		issue._manual_qc_opted_out = true
		return
	if not PitchBatLabFeelSupport.flush_pending_manual_records(lab, false):
		return
	if (
		not is_instance_valid(lab)
		or lab._match_state != state
		or StadiumNpcAc02IssuedStateV1.current(lab) != issue
		or lab._record_export != exporter
		or not is_same(lab._play_records, records)
		or (issue != null and not issue.manual_qc_owner(lab))
	):
		return
	PitchBatLabFeelSupport.warn_pending_manual_records(lab)
	lab._active_play_record = null
	lab._play_records.clear()
	lab._record_export = PlayRecordExport.new()
	if issue != null:
		issue.manual_qc_reset_session()


static func _public_dump_records(lab: PitchBatLab) -> void:
	if (
		PitchBatLabFeelSupport.MANUAL_QC_COMMAND_V1.run(lab, true)
		!= PitchBatLabFeelSupport.MANUAL_QC_COMMAND_V1.Outcome.FALLBACK
	):
		return
	# F3 remains unconditional, even with no pending records, and may retry failed I/O.
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issue != null and issue._manual_qc_flushing:
		return
	var context: Dictionary = PitchBatLabFeelSupport._begin_manual_qc_export(lab)
	# Refuse before either QC output; an empty field object is not an export refusal.
	if not PitchBatLabFeelSupport._public_export_intact(lab):
		PitchBatLabFeelSupport._end_manual_qc_export(context, false)
		return
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(lab)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(lab)
	):
		PitchBatLabFeelSupport._end_manual_qc_export(context, false)
		return
	print(
		"WIFFALTRO_FIELD_QC ",
		JSON.stringify(
			(
				PlayRecordExport.field_metadata(
					lab._field_definition, lab.get_meta("stadium_snapshot", {})
				)
				if PitchBatLabFeelSupport._export_ready(lab)
				else {}
			)
		)
	)
	var serialized: Array[Dictionary] = []
	for record in lab._play_records:
		serialized.append(record.to_dict())
	print("WIFFALTRO_PLAY_RECORDS ", JSON.stringify(serialized))
	# A retained custom record may reenter during Output serialization, before save.
	# Only the existing started-batch lease gets this check; never export its replacement.
	if not PitchBatLabFeelSupport._manual_qc_export_context_intact(context):
		PitchBatLabFeelSupport._end_manual_qc_export(context, false)
		return
	var saved: bool = PitchBatLabFeelSupport._save_records(lab)
	if not PitchBatLabFeelSupport._end_manual_qc_export(context, saved):
		return
	if lab._status_label != null:
		lab._status_label.text = (
			(
				"Saved %d records to %s"
				% [serialized.size(), ProjectSettings.globalize_path(lab._record_export.path)]
			)
			if saved
			else "QC save failed. Records remain in Output."
		)


static func _public_flush_pending_manual_records(lab: PitchBatLab, terminal: bool = true) -> bool:
	var command: int = PitchBatLabFeelSupport.MANUAL_QC_COMMAND_V1.run(lab, false, terminal)
	if command != PitchBatLabFeelSupport.MANUAL_QC_COMMAND_V1.Outcome.FALLBACK:
		return command == PitchBatLabFeelSupport.MANUAL_QC_COMMAND_V1.Outcome.HANDLED
	# Return continuation safety, NOT persistence success. QC I/O never gates a season save.
	# Terminal attempts are one-shot before revocation/disposal. A deliberate reset
	# may attempt its own pending flush; F3 also ignores (and never clears) the latch.
	if not is_instance_valid(lab):
		return true
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issue == null:
		return not lab._ac02_issued_history
	if issue._bindings_pin.get("lab") != lab:
		return false
	if issue._manual_qc_flushing:
		return false
	if not issue.manual_qc_pending():
		return true
	# The latch suppresses repeated I/O, never the fresh original-owner/session check.
	if not issue.manual_qc_owner(lab):
		return false
	if (
		lab._record_export != issue._manual_qc_exporter
		or not is_same(lab._play_records, issue._manual_qc_records)
	):
		issue._manual_qc_opted_out = true
		return false
	if terminal and issue._manual_qc_terminal_attempted:
		return (
			lab._play_records.size() == issue._manual_qc_terminal_count
			and issue._manual_qc_dirty_revision == issue._manual_qc_terminal_revision
		)
	if terminal:
		issue._manual_qc_terminal_attempted = true
		issue._manual_qc_terminal_count = lab._play_records.size()
		issue._manual_qc_terminal_revision = issue._manual_qc_dirty_revision
	var context: Dictionary = PitchBatLabFeelSupport._begin_manual_qc_export(lab)
	if context.is_empty():
		push_warning("Pending QC was not exported: its active manual session no longer matches.")
		return false
	var saved: bool = PitchBatLabFeelSupport._save_records(lab)
	return PitchBatLabFeelSupport._end_manual_qc_export(context, saved)


static func _public_warn_pending_manual_records(lab: PitchBatLab) -> void:
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issue != null and issue._bindings_pin.get("lab") == lab and issue.manual_qc_pending():
		push_warning("Discarding unsaved development QC records. Season saves are independent.")


static func _begin_manual_qc_export(lab: PitchBatLab) -> Dictionary:
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if (
		issue == null
		or not issue._manual_qc_started
		or issue._manual_qc_flushing
		or not issue.manual_qc_owner(lab)
	):
		return {}
	if (
		lab._record_export != issue._manual_qc_exporter
		or not is_same(lab._play_records, issue._manual_qc_records)
	):
		issue._manual_qc_opted_out = true
		return {}
	if lab._play_records.size() != issue._manual_qc_count:
		issue._manual_qc_opted_out = true
	issue._manual_qc_flushing = true
	return {
		"issue": issue,
		"lab": lab,
		"match": lab._match_state,
		"exporter": lab._record_export,
		"records": lab._play_records,
		"count": lab._play_records.size(),
		"revision": issue._manual_qc_dirty_revision
	}


static func _manual_qc_export_context_intact(context: Dictionary) -> bool:
	if context.is_empty():
		return true
	var issue: StadiumNpcAc02IssuedStateV1 = context.issue
	var lab: PitchBatLab = context.lab
	return (
		is_instance_valid(lab)
		and StadiumNpcAc02IssuedStateV1.current(lab) == issue
		and lab._match_state == context.match
		and lab._record_export == context.exporter
		and is_same(lab._play_records, context.records)
		and lab._play_records.size() == context.count
		and issue._manual_qc_dirty_revision == context.revision
		and issue.manual_qc_owner(lab)
	)


static func _end_manual_qc_export(context: Dictionary, saved: bool) -> bool:
	if context.is_empty():
		return true
	var issue: StadiumNpcAc02IssuedStateV1 = context.issue
	issue._manual_qc_flushing = false
	var intact: bool = PitchBatLabFeelSupport._manual_qc_export_context_intact(context)
	# A successful automation no-op, stale exporter, changed revision or revoked owner
	# cannot acknowledge this batch or authorize continuation of its captured boundary.
	# Every actual save still ran both full audits; ordinary I/O failure is nonblocking.
	if saved and intact:
		issue._manual_qc_saved_revision = context.revision
	return intact


static func _save_records(lab: PitchBatLab) -> bool:
	if not PitchBatLabFeelSupport._public_export_intact(lab):
		return false
	if lab._automation != null:
		return true
	if not PitchBatLabFeelSupport._export_ready(lab):
		push_warning("QC export refused: the frozen property does not match the installed field.")
		return false
	var error: Error = lab._record_export.save(
		lab._play_records, lab._field_definition, lab.get_meta("stadium_snapshot", {})
	)
	if error != OK:
		push_warning("QC export failed: %s" % error_string(error))
		return false
	return true


static func _export_ready(lab: PitchBatLab) -> bool:
	if not PitchBatLabFeelSupport._public_export_intact(lab):
		return false
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(lab)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(lab)
	):
		return false
	var snapshot: Variant = lab.get_meta("stadium_snapshot", {})
	if not snapshot is Dictionary:
		return false
	var state: MatchState = lab._match_state
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	if night_owner != null and night_owner._kit_mode:
		# This synchronous call does one full deep reconciliation against the exact
		# issued receipt. Only its install-derived canonical data are reused.
		return not StadiumSurfaceNightRuntime.issued_export_key(lab, snapshot).is_empty()
	if snapshot.is_empty():
		return state == null or state.stadium.is_empty()
	if (
		state == null
		or not StadiumLayoutSnapshot.valid(snapshot)
		or StadiumLayoutSnapshot.key(snapshot) != StadiumLayoutSnapshot.key(state.stadium)
	):
		return false
	return not snapshot.has("boundary") or StadiumBoundaryRuntime.installed(lab, snapshot)


static func _public_export_intact(lab: PitchBatLab) -> bool:
	if is_instance_valid(lab) and lab.ac02_startup_pending():
		return false
	if not is_instance_valid(lab):
		return false
	# Only explicit new-runtime publication selects this additional boundary.
	# Historical and ineligible AC02 exports retain their original dispatch.
	var issue: StadiumNpcAc02IssuedStateV1 = lab._ac02_issued_owner
	if issue == null:
		return true
	var state: MatchState = lab._match_state
	if not StadiumNpcPublicRuntime.installed_bound(lab, state.stadium if state != null else {}):
		return false
	var property: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	return (
		is_instance_valid(property)
		and property.has_ac02_issue()
		and lab._ac02_issued_owner == issue
		and property._ac02_issue == issue
		and property._ac02_issue_pin == issue
	)


static func _public_measure_nominal_pitch(
	lab: PitchBatLab, base_parameters: PitchLaunchParameters, target_position: Vector3
) -> void:
	lab._last_nominal_release_speed_mps = base_parameters.velocity.length()
	var nominal: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		base_parameters, target_position.z
	)
	var neutral: PitchLaunchParameters = base_parameters.copy()
	neutral.magnus_scale = 0.0
	neutral.perforation_force_scale = 0.0
	neutral.instability_strength = 0.0
	var neutral_crossing: PitchCrossingResult = PitchTrajectorySimulator.simulate_to_plane(
		neutral, target_position.z
	)
	if nominal.crossed and neutral_crossing.crossed:
		lab._last_movement_x_m = nominal.point.x - neutral_crossing.point.x
		lab._last_movement_y_m = nominal.point.y - neutral_crossing.point.y
	else:
		lab._last_movement_x_m = 0.0
		lab._last_movement_y_m = 0.0


static func _update_pitch_release(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._release_controller == null or not lab._release_controller.active:
		return
	if lab._release_controller.advance(delta_seconds):
		PitchBatLabFeelSupport.commit_pitch_release(lab)
	else:
		lab._refresh_config()


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
	var event: AtBatCadenceController.Event = lab._at_bat_cadence.advance(
		cadence_delta, not lab._home_run.presentation_pending(lab)
	)
	match event:
		AtBatCadenceController.Event.THROW_PITCH:
			PitchBatLabFeelSupport._reset_pitcher_telegraph(lab)
			lab._throw_pitch()
		AtBatCadenceController.Event.CONTINUE_PLAY:
			lab._handle_match_advance()
		_:
			pass


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
	if selected_pitch != null and selected_pitch.delivery_profile != null:
		if selected_pitch.delivery_profile.delivery == DeliveryProfileDefinition.Delivery.THREE_QUARTER:
			slot_amount = 0.14
		elif selected_pitch.delivery_profile.delivery == DeliveryProfileDefinition.Delivery.SUBMARINE:
			slot_amount = 0.32
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
		if selected_pitch != null and selected_pitch.delivery_profile != null and (
			selected_pitch.delivery_profile.delivery in [DeliveryProfileDefinition.Delivery.THREE_QUARTER,
				DeliveryProfileDefinition.Delivery.SUBMARINE]
		):
			var release: Vector3 = selected_pitch.delivery_profile.release_offset_pitcher_frame_m
			var release_world: Vector3 = lab.MOUND_ORIGIN + CoordinateFrame.pitcher_frame_vector(
				release.x, release.y, release.z, handedness < 0.0)
			lab._pitcher_avatar.set_pitch_profile_progress(
				progress, selected_pitch.delivery_profile, release_world)
		else:
			lab._pitcher_avatar.set_pitch_delivery_progress(progress, sidearm)
	if ai_delivery and lab._action_label != null:
		lab._action_label.text = lab._at_bat_cadence.delivery_cue()


static func _reset_pitcher_telegraph(lab: PitchBatLab) -> void:
	if lab._pitcher_marker == null:
		return
	lab.reset_hillside_pitcher()
	if lab._pitcher_avatar != null:
		lab._pitcher_avatar.reset_pose()


static func _update_continuous_input(lab: PitchBatLab, delta_seconds: float) -> void:
	if lab._automation != null or lab._continuous_input_blocked():
		return
	var amount: float = PitchBatLabFeelSupport.AIM_SPEED_MPS * delta_seconds
	if lab._match_mode:
		if (
			lab._player_is_pitching()
			and lab._match_state.phase == MatchState.Phase.PRE_PITCH
			and not lab._release_controller.active
			and not lab._field_setup_active
			and not lab._pitching_staff_active
		):
			PitchBatLabFeelSupport._apply_pitch_aim(lab, amount)
		elif lab._player_is_batting() and not lab._swing_consumed:
			PitchBatLabFeelSupport._apply_bat_aim(lab, amount)
		return
	PitchBatLabFeelSupport._apply_pitch_aim(lab, amount)
	PitchBatLabFeelSupport._apply_bat_aim(lab, amount)


static func _apply_pitch_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"pitch_aim_left", &"pitch_aim_right", &"pitch_aim_down", &"pitch_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_pitch_target(direction * amount)


static func _apply_bat_aim(lab: PitchBatLab, amount: float) -> void:
	var direction: Vector2 = Input.get_vector(
		&"bat_aim_left", &"bat_aim_right", &"bat_aim_down", &"bat_aim_up"
	)
	if direction.length_squared() > 0.0001:
		lab._adjust_batting_aim(direction * amount)

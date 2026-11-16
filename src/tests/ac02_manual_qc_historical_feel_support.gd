extends "res://src/tests/ac02_manual_qc_historical_feel_support_fixture_base.gd"
static func toggle_match_mode(lab: PitchBatLab) -> void:
	var night_owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	var terrain_owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	var night_state: MatchState = lab._match_state
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	if lab._match_mode and not _can_suspend_match_for_lab(lab):
		lab._status_label.text = "MECHANICS LAB\nAvailable before a Pitch, while play is stopped."
		if lab._debug_paused:
			lab._status_label.text += "\nPAUSED • V: camera • Esc: resume"
		lab._refresh_config()
		return
	reset_debug_pause(lab)
	if lab._match_mode:
		_suspend_match_for_lab(lab)
	else:
		_resume_suspended_match(lab)
	if (
		not StadiumSurfaceNightRuntime.continue_boundary(lab, night_owner, night_state)
		or not StadiumSurfaceTerrainRuntime.continue_boundary(lab, terrain_owner, night_state)
	):
		return
	lab._apply_role_camera()
	lab._refresh_markers()
	lab._refresh_config()


static func begin_pitch_release(lab: PitchBatLab) -> void:
	if (
		not lab._player_is_pitching()
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._release_controller.active
		or lab._field_setup_active
		or lab._pitching_staff_active
	):
		return
	lab._release_controller.begin()
	lab._status_label.text = ""
	lab._refresh_config()


static func release_meter_text(lab: PitchBatLab) -> String:
	if lab._release_controller == null or not lab._release_controller.active:
		return ""
	var progress: float = lab._release_controller.meter_progress()
	var marker_distance: float = absf(progress - lab._release_controller.ideal_progress())
	var cue: String = "●" if marker_distance <= 0.055 else "○"
	if marker_distance <= 0.055:
		return "RELEASE  %s" % cue
	if progress > lab._release_controller.ideal_progress():
		return "OVERCOOK  %s" % cue
	return "HOLD  %s" % cue


static func start_record(
	lab: PitchBatLab,
	pitch: PitchDefinition,
	fatigue: float,
	execution_quality: float,
	play_seed: int,
	release_overdrive: float = 0.0
) -> void:
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


static func note_crossing(lab: PitchBatLab, point: Vector3, speed_mps: float) -> void:
	if lab._active_play_record == null:
		return
	lab._active_play_record.crossed_plate = true
	lab._active_play_record.crossing_point = Vector2(point.x, point.y)
	lab._active_play_record.plate_speed_mps = speed_mps


static func note_swing(
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


static func note_first_ground(lab: PitchBatLab, position: Vector3) -> void:
	if lab._active_play_record == null or lab._active_play_record.has_first_ground:
		return
	lab._active_play_record.has_first_ground = true
	lab._active_play_record.first_ground_position = position


static func note_ball_play_outcome(
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


static func record_clean_fielding_control(
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
	var intact: bool = _manual_qc_export_context_intact(context)
	# A successful automation no-op, stale exporter, changed revision or revoked owner
	# cannot acknowledge this batch or authorize continuation of its captured boundary.
	# Every actual save still ran both full audits; ordinary I/O failure is nonblocking.
	if saved and intact:
		issue._manual_qc_saved_revision = context.revision
	return intact


static func _public_export_intact(lab: PitchBatLab) -> bool:
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


static func _export_ready(lab: PitchBatLab) -> bool:
	if not _public_export_intact(lab):
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


static func _save_records(lab: PitchBatLab) -> bool:
	if not _public_export_intact(lab):
		return false
	if lab._automation != null:
		return true
	if not _export_ready(lab):
		push_warning("QC export refused: the frozen property does not match the installed field.")
		return false
	var error: Error = lab._record_export.save(
		lab._play_records, lab._field_definition, lab.get_meta("stadium_snapshot", {})
	)
	if error != OK:
		push_warning("QC export failed: %s" % error_string(error))
		return false
	return true


static func finish_record(lab: PitchBatLab, result: StringName, runs_scored: int = 0) -> void:
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
	var context: Dictionary = _begin_manual_qc_export(lab)
	var saved: bool = _save_records(lab)
	_end_manual_qc_export(context, saved)


static func flush_pending_manual_records(lab: PitchBatLab, terminal: bool = true) -> bool:
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
	var context: Dictionary = _begin_manual_qc_export(lab)
	if context.is_empty():
		push_warning("Pending QC was not exported: its active manual session no longer matches.")
		return false
	var saved: bool = _save_records(lab)
	return _end_manual_qc_export(context, saved)


static func warn_pending_manual_records(lab: PitchBatLab) -> void:
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issue != null and issue._bindings_pin.get("lab") == lab and issue.manual_qc_pending():
		push_warning("Discarding unsaved development QC records. Season saves are independent.")


static func clear_records(lab: PitchBatLab) -> void:
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
	if not flush_pending_manual_records(lab, false):
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
	warn_pending_manual_records(lab)
	lab._active_play_record = null
	lab._play_records.clear()
	lab._record_export = PlayRecordExport.new()
	if issue != null:
		issue.manual_qc_reset_session()


static func dump_records(lab: PitchBatLab) -> void:
	# F3 remains unconditional, even with no pending records, and may retry failed I/O.
	var issue: StadiumNpcAc02IssuedStateV1 = StadiumNpcAc02IssuedStateV1.current(lab)
	if issue != null and issue._manual_qc_flushing:
		return
	var context: Dictionary = _begin_manual_qc_export(lab)
	# Refuse before either QC output; an empty field object is not an export refusal.
	if not _public_export_intact(lab):
		_end_manual_qc_export(context, false)
		return
	if (
		not StadiumSurfaceNightRuntime.boundary_allowed(lab)
		or not StadiumSurfaceTerrainRuntime.boundary_allowed(lab)
	):
		_end_manual_qc_export(context, false)
		return
	print(
		"WIFFALTRO_FIELD_QC ",
		JSON.stringify(
			(
				PlayRecordExport.field_metadata(
					lab._field_definition, lab.get_meta("stadium_snapshot", {})
				)
				if _export_ready(lab)
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
	if not _manual_qc_export_context_intact(context):
		_end_manual_qc_export(context, false)
		return
	var saved: bool = _save_records(lab)
	if not _end_manual_qc_export(context, saved):
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


static func measure_nominal_pitch(
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

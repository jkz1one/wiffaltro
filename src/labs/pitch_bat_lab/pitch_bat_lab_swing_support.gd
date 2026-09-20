class_name PitchBatLabSwingSupport
extends RefCounted


static func begin_swing(lab: PitchBatLab, profile_id: StringName, aim_point: Vector2) -> void:
	if (
		lab._pitch_actor == null
		or not lab._pitch_actor.running
		or lab._pitch_actor.state == null
		or lab._swing_consumed
		or lab._swing_tracker == null
	):
		return
	var profile: SwingProfileDefinition = ContentDB.get_swing(profile_id)
	if profile == null:
		push_error("Pitch/Bat Lab: swing profile missing: %s" % String(profile_id))
		return

	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile_id
	intent.aim_point = aim_point
	intent.start_time_seconds = lab._pitch_actor.state.elapsed_time
	var contact_rating: int = 5
	var power_rating: int = 5
	if lab._match_mode:
		var batter_definition: PlayerDefinition = lab._match_state.batter().definition
		intent.handedness_left = (batter_definition.bats == PlayerDefinition.Handedness.LEFT)
		contact_rating = batter_definition.contact
		power_rating = batter_definition.power

	lab._swing_consumed = true
	lab._status_label.text = ""
	lab._pending_swing_miss = null
	lab._swing_tracker.begin(intent, profile, contact_rating, power_rating)
	PitchBatLabPresentation.play_batter_swing(lab, profile)


static func advance_swing(
	lab: PitchBatLab, previous_position: Vector3, previous_elapsed_seconds: float
) -> void:
	if (
		lab._swing_tracker == null
		or not lab._swing_tracker.active
		or lab._pitch_actor == null
		or lab._pitch_actor.state == null
	):
		return
	var result: ContactResult = lab._swing_tracker.sample_segment(
		previous_position, previous_elapsed_seconds, lab._pitch_actor.state
	)
	if result == null:
		return
	if result.outcome == ContactResult.Outcome.MISS:
		_register_miss(lab, result)
		return
	_resolve_contact(lab, result)


static func ensure_miss(lab: PitchBatLab) -> ContactResult:
	if lab._pending_swing_miss != null:
		return lab._pending_swing_miss
	if lab._swing_tracker == null or lab._pitch_actor == null:
		return null
	var result: ContactResult = lab._swing_tracker.force_miss(lab._pitch_actor.state)
	if result != null:
		_register_miss(lab, result)
	return result


static func reset(lab: PitchBatLab) -> void:
	if lab._swing_tracker != null:
		lab._swing_tracker.reset()
	if lab._bat_actor != null:
		lab._bat_actor.reset_swing()
	if lab._batter_avatar != null:
		lab._batter_avatar.reset_pose()
	lab._pending_swing_miss = null


static func _register_miss(lab: PitchBatLab, result: ContactResult) -> void:
	lab._pending_swing_miss = result
	var profile: SwingProfileDefinition = lab._swing_tracker.profile
	PitchBatLabFeelSupport.note_swing(lab, profile.id, lab._swing_tracker.intent.aim_point, result)
	lab._status_label.text = ""
	lab._live_label.text = (
		"%s • %s • ball continuing to receiver"
		% [
			profile.display_name,
			result.miss_reason_name(),
		]
	)


static func _resolve_contact(lab: PitchBatLab, result: ContactResult) -> void:
	var profile: SwingProfileDefinition = lab._swing_tracker.profile
	var aim_point: Vector2 = lab._swing_tracker.intent.aim_point
	PitchBatLabFeelSupport.note_swing(lab, profile.id, aim_point, result)
	lab._pitch_actor.stop_pitch(&"contact")
	lab._last_exit_speed_mph = result.exit_velocity.length() * 2.236936

	if result.outcome == ContactResult.Outcome.FOUL:
		lab._status_label.text = ""
		lab._live_label.text = (
			("FOUL CONTACT • %s • quality %.0f%% • EV %.1f mph")
			% [
				profile.display_name,
				result.quality * 100.0,
				lab._last_exit_speed_mph,
			]
		)
		lab._start_ball_in_play(BattedBallLaunch.from_contact(result, lab._pitch_actor.state))
		return

	lab._status_label.text = ""
	lab._live_label.text = (
		(
			"%s — %s   quality %.0f%%\n"
			+ "timing %s   aim %s\n"
			+ "EV %.1f mph   launch %+0.1f°   spray %+0.1f°\n"
			+ "Physical ball launched into starter field."
		)
		% [
			profile.display_name,
			PitchBatLabPresentation.contact_outcome_name(result.outcome),
			result.quality * 100.0,
			result.timing_name(),
			result.aim_name(),
			lab._last_exit_speed_mph,
			result.launch_angle_degrees,
			result.spray_degrees,
		]
	)

	var vector_end: Vector3 = result.contact_position + result.exit_velocity.normalized() * 4.0
	var launch_points: Array[Vector3] = [
		result.contact_position,
		vector_end,
	]
	lab._contact_vector_draw.draw_polyline(launch_points)
	lab._start_ball_in_play(BattedBallLaunch.from_contact(result, lab._pitch_actor.state))

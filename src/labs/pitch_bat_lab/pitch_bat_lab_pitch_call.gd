class_name PitchBatLabPitchCall
extends RefCounted


static func resolve(
	lab: PitchBatLab, point: Vector3, speed_mps: float, elapsed_seconds: float
) -> void:
	PitchBatLabFeelSupport.note_crossing(lab, point, speed_mps)
	var target_error_x: float = point.x - lab._pitch_target.x
	var target_error_y: float = point.y - lab._pitch_target.y
	var call_text: String = ""
	var swing_feedback: String = ""
	var plate_call: StringName = &""
	if lab._match_mode:
		var feedback: String = ""
		if lab._swing_consumed:
			var miss: ContactResult = PitchBatLabSwingSupport.ensure_miss(lab)
			feedback = PitchFeedback.plate_message(lab, point)
			plate_call = lab._match_state.record_strike(true)
			if miss != null:
				swing_feedback = "   %s" % miss.miss_reason_name()
		else:
			var in_zone: bool = (
				point.x >= lab.ZONE_MIN_X
				and point.x <= lab.ZONE_MAX_X
				and point.y >= lab.ZONE_MIN_Y
				and point.y <= lab.ZONE_MAX_Y
			)
			feedback = PitchFeedback.plate_message(lab, point)
			plate_call = lab._match_state.record_called_pitch(in_zone)
		call_text = "   %s" % String(plate_call).replace("_", " ").to_upper()
		lab._pitch_feedback.show_note(feedback)

	lab._live_label.text = (
		(
			"PLATE • %s%s%s\n"
			+ "cross %.2f / %.2f • error %+0.1f / %+0.1f cm\n"
			+ "release %.1f → %.1f • plate %.1f mph • %.3f s"
		)
		% [
			lab._selected_pitch().display_name,
			call_text,
			swing_feedback,
			point.x,
			point.y,
			target_error_x * 100.0,
			target_error_y * 100.0,
			lab._last_nominal_release_speed_mps * 2.236936,
			lab._last_executed_release_speed_mps * 2.236936,
			speed_mps * 2.236936,
			elapsed_seconds,
		]
	)
	if lab._match_mode:
		lab._status_label.text = (
			"%s\n%s  %.0f MPH"
			% [
				String(plate_call).replace("_", " ").to_upper(),
				lab._selected_pitch().display_name,
				speed_mps * 2.236936,
			]
		)
	else:
		lab._status_label.text = "PLATE • %s" % lab._selected_pitch().display_name
	if lab._match_mode:
		PitchBatLabFeelSupport.notify_pitch_dead(lab)
		if plate_call == &"strikeout":
			lab._at_bat_cadence.active_hold_seconds = maxf(lab._at_bat_cadence.active_hold_seconds, 2.25)
		lab._live_label.text += "\nPLAY DEAD • next state automatic"
		lab._refresh_config()
	var record_result: StringName = &"plate_crossed"
	if lab._swing_consumed:
		record_result = &"swinging_strike"
	elif not call_text.is_empty():
		record_result = StringName(call_text.strip_edges().to_lower().replace(" ", "_"))
	PitchBatLabFeelSupport.finish_record(lab, record_result)

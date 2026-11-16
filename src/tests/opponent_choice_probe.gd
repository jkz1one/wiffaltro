class_name OpponentChoiceProbe
extends RefCounted
## Read-only samples of paid effects in ordinary physical play.

var wide_frames: int = 0
var anchored_frames: int = 0


func observe(lab: PitchBatLab, check: Callable) -> void:
	if lab == null or lab._match_state == null:
		return
	var state: MatchState = lab._match_state
	if state.batting_team().ai_sponsor_choices and state.batter().definition.season_sponsors.get(
		"F03", false) and lab._swing_tracker.active:
		check.call(state.optics_mode == "wide", "paid AI locks wide for actual swings")
		if lab._swing_tracker.profile.id == &"swing.contact":
			var normal: SwingProfileDefinition = SeasonSponsorEffects.swing(
				ContentDB.get_swing(&"swing.contact"), state)
			check.call(is_equal_approx(lab._swing_tracker.profile.contact_radius_x_m,
				normal.contact_radius_x_m) and is_equal_approx(
				lab._swing_tracker.profile.contact_radius_y_m, normal.contact_radius_y_m),
				"actual AI Contact uses shared once-scaled ellipse")
			wide_frames += 1
	if state.defensive_team().ai_sponsor_choices and SeasonCornerstone.active(state) \
		and lab._primary_fielder.active and lab._ball_play_resolver != null \
		and lab._ball_play_resolver.state != null \
		and not lab._ball_play_resolver.state.is_foul_play:
		check.call(lab._primary_fielder.stationary
			and lab._primary_fielder.global_position.is_equal_approx(
			lab._primary_fielder.anchor_position), "committed AI primary stays at legal fair-ball anchor")
		anchored_frames += 1


func summary() -> String:
	return "wide_contact_frames=%d anchored_fair_frames=%d" % [wide_frames, anchored_frames]

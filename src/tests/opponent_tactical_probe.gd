class_name OpponentTacticalProbe
extends RefCounted
## Read-only actual swing samples; no activation or outcome is manufactured.

var tape_frames: int = 0
var plan_frames: int = 0


func observe(lab: PitchBatLab, check: Callable) -> void:
	if lab == null or lab._match_state == null or not lab._swing_tracker.active:
		return
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.batting_team()
	if team.ai_tactical_hitter.is_empty():
		return
	var item: String = team.tactics.active(state)
	if item not in SeasonOpponentTactics.ITEMS:
		return
	check.call(
		String(state.batter().definition.id) == team.ai_tactical_hitter,
		"paid supplies only affect the committed featured hitter"
	)
	var actual: SwingProfileDefinition = lab._swing_tracker.profile
	var shared: SwingProfileDefinition = SeasonSponsorEffects.swing(
		ContentDB.get_swing(actual.id), state
	)
	check.call(
		(
			is_equal_approx(actual.contact_radius_x_m, shared.contact_radius_x_m)
			and is_equal_approx(actual.contact_radius_y_m, shared.contact_radius_y_m)
			and is_equal_approx(actual.gear_fair_exit_scale, shared.gear_fair_exit_scale)
		),
		"real AI swings carry the shared paid coverage and exit-speed tradeoff once"
	)
	if item == "A10":
		tape_frames += 1
	else:
		check.call(
			(
				actual.id == team.tactics.locked_swing(state)
				and actual.id == StringName(SeasonOpponentTactics.plan(state.batter().definition))
				and is_equal_approx(actual.tactical_quality_exit_scale, 1.06)
			),
			"actual Swing Plan locks the public stat-selected swing and quality-gated benefit"
		)
		plan_frames += 1


func summary() -> String:
	return "tape_swing_frames=%d plan_swing_frames=%d" % [tape_frames, plan_frames]

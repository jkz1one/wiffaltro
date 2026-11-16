class_name OpponentRecoveryProbe
extends RefCounted
## Read-only actual released-parameter comparison, not an activation/outcome shortcut.

var activations: int = 0
var releases: int = 0
var recipes: Dictionary = {}
var _activated: Dictionary = {}
var _seen: Dictionary = {}


func observe(lab: PitchBatLab, check: Callable) -> void:
	observe_activation(lab, check)
	if (
		lab == null
		or lab._match_state == null
		or lab._pitch_actor == null
		or not lab._pitch_actor.running
	):
		return
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.defensive_team()
	if team.ai_recovery_pitcher.is_empty() or not team.tactics.consumed.any(
		func(action: Dictionary) -> bool: return team.ai_tactical_initial.any(
			func(copy: Dictionary) -> bool: return copy.id == action.receipt and copy.item == "C02")):
		return
	var key: String = "%d:%d" % [lab.get_instance_id(), lab._throw_number]
	if _seen.has(key):
		return
	_seen[key] = true
	var pitch: PitchDefinition = lab._selected_pitch()
	var rated: PitchDefinition = MatchLabSupport.rated_pitch(
		pitch, state.pitcher().definition, lab._pitch_effort, lab._last_release_overdrive
	)
	var launch: PitchDefinition = MatchTactics.pitch(rated, state)
	var target: Vector3 = Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.0)
	var expected: PitchLaunchParameters = PitchAimSolver.solve(
		launch,
		ContentDB.get_ball_setup(lab.BALL_SETUP_ID),
		lab.MOUND_ORIGIN,
		target,
		state.pitcher().definition.throws == PlayerDefinition.Handedness.LEFT,
		lab._throw_number
	)
	check.call(expected != null, "actual recovered recipe remains physically solvable")
	if expected == null:
		return
	if not state.sure_shot.current(state).is_empty():
		expected.execution_direction_scale = 0.8
	expected = PitchExecutionModel.apply(
		expected,
		lab._last_release_quality,
		maxf(state.pitcher().fatigue_ratio(), lab._fatigue),
		pitch.control_difficulty,
		pitch.execution_difficulty,
		pitch.category,
		lab._throw_number * 1009 + lab._selected_pitch_index
	)
	check.call(
		(
			lab._pitch_actor.parameters.pitch_id == expected.pitch_id
			and lab._pitch_actor.parameters.velocity.is_equal_approx(expected.velocity)
		),
		"actual physical release uses shared recovery, normal execution and fatigue"
	)
	releases += 1
	recipes[String(pitch.id)] = true


func summary() -> String:
	return "recovery_uses=%d releases=%d recipes=%s" % [activations, releases, str(recipes.keys())]


func observe_activation(lab: PitchBatLab, check: Callable) -> void:
	if lab == null or lab._match_state == null:
		return
	var state: MatchState = lab._match_state
	for team: TeamMatchState in [state.away_team, state.home_team]:
		if team.ai_recovery_pitcher.is_empty():
			continue
		for action: Dictionary in team.tactics.consumed:
			if not team.ai_tactical_initial.any(func(copy: Dictionary) -> bool:
				return copy.id == action.receipt and copy.item == "C02"):
				continue
			var key: String = "%d:%s" % [lab.get_instance_id(), action.receipt]
			if _activated.has(key):
				continue
			_activated[key] = true
			activations += 1
			var ready: Array = team.recovery.ready.filter(func(row: Dictionary) -> bool:
				return row.pa == action.pa)
			check.call(ready.size() == 1 and action.player == team.ai_recovery_pitcher,
				"actual paid Recovery uses the saved planned pitcher at readiness")
			if ready.size() == 1:
				var initial: Dictionary = team.recovery.initial[action.player]
				check.call(SeasonOpponentRecovery.eligible(initial.capacity, ready[0].remaining),
					"actual recovery waited until at least ten percent game-start stamina was spent")
				if state.phase == MatchState.Phase.PRE_PITCH and state.between_batters \
					and action.pa == state.plate_appearance_number:
					check.call(PhysicalRecoveryFlow.near(state.pitcher().stamina_remaining,
						minf(initial.capacity, ready[0].remaining + initial.capacity * 0.1)),
						"actual shared activation restores exactly ten percent with its normal cap")

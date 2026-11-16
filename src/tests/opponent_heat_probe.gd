class_name OpponentHeatProbe
extends RefCounted
## Read-only actual released-parameter comparison, not an activation/outcome shortcut.

var releases: int = 0
var recipes: Dictionary = {}
var _seen: Dictionary = {}


func observe(lab: PitchBatLab, check: Callable) -> void:
	if (
		lab == null
		or lab._match_state == null
		or lab._pitch_actor == null
		or not lab._pitch_actor.running
	):
		return
	var state: MatchState = lab._match_state
	if (
		not state.defensive_team().ai_heat
		or state.defensive_team().tactics.active(state) != (SeasonTacticalCatalog.HEAT)
	):
		return
	var key: String = "%d:%d" % [lab.get_instance_id(), lab._throw_number]
	if _seen.has(key):
		return
	_seen[key] = true
	check.call(
		String(state.batter().definition.id) == SeasonOpponentHeat.target(state.batting_team()),
		"actual Heat faces the opposing highest-Power hitter only"
	)
	var pitch: PitchDefinition = lab._selected_pitch()
	var rated: PitchDefinition = MatchLabSupport.rated_pitch(
		pitch, state.pitcher().definition, lab._pitch_effort, lab._last_release_overdrive
	)
	var launch: PitchDefinition = MatchTactics.pitch(rated, state)
	check.call(
		(
			is_equal_approx(launch.nominal_velocity_mps, rated.nominal_velocity_mps * 1.05)
			and launch.id == rated.id
		),
		"shared Heat applies once after real ratings/mastery/Ball"
	)
	var target: Vector3 = Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.0)
	var expected: PitchLaunchParameters = PitchAimSolver.solve(
		launch,
		ContentDB.get_ball_setup(lab.BALL_SETUP_ID),
		lab.MOUND_ORIGIN,
		target,
		state.pitcher().definition.throws == PlayerDefinition.Handedness.LEFT,
		lab._throw_number
	)
	check.call(expected != null, "actual Heat recipe remains physically solvable")
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
		"actual physical release uses shared Heat, normal execution and fatigue"
	)
	releases += 1
	recipes[String(pitch.id)] = true


func summary() -> String:
	return "heat_releases=%d recipes=%s" % [releases, str(recipes.keys())]

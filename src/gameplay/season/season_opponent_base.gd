class_name SeasonOpponentBase
extends RefCounted
## A paid card uses the shared legal trailing-runner advance before own offensive supplies.


static func select(held: Array, bases: BaseState) -> Dictionary:
	var target: Dictionary = TacticalBaseAdvance.target(bases)
	if target.get("from") != 3 or target.get("to") != 4:
		return {}
	return PhysicalRecoveryFlow.select(held, SeasonTacticalCatalog.BASE)


static func prepare(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state == null or state.phase != MatchState.Phase.PRE_PITCH or not state.between_batters \
		or not MatchAutomation.batting(lab) or not state.batting_team().ai_base:
		return
	var team: TeamMatchState = state.batting_team()
	var copy: Dictionary = select(team.tactics.held, state.bases)
	if not copy.is_empty():
		team.tactics.activate(state, team, copy.id)


static func evidence(state: MatchState, row: Dictionary, include_base: bool) -> Dictionary:
	row.version = 5
	if include_base:
		row["base"] = state.base_flow.evidence(state)
	return row


static func first_release_note(lab: PitchBatLab) -> void:
	if not MatchAutomation.presented(lab) or lab._match_state == null or lab._pitch_feedback == null:
		return
	var state: MatchState = lab._match_state
	if state.batting_team().ai_base and state._pa_pitchers.is_empty() \
		and state.batting_team().tactics.active(state) == SeasonTacticalCatalog.BASE:
		# Pitch setup clears prior feedback. Preserve this actual score through its first release.
		# Later pitches in the same PA do not announce a second run.
		lab._pitch_feedback.show_note("OPPONENT TAKE A BASE • +1 RUN")

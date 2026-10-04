class_name SeasonOpponentChoices
extends RefCounted
## Policy8: explicit shared pre-PA choices, before pitch selection or ball flight.


static func prepare(lab: PitchBatLab) -> void:
	var state: MatchState = lab._match_state
	if state == null or state.phase != MatchState.Phase.PRE_PITCH \
		or not state.between_batters:
		return
	for role: String in ["bat", "field"]:
		var team: TeamMatchState = state.batting_team() if role == "bat" else state.defensive_team()
		var controlled: bool = (MatchAutomation.batting(lab) if role == "bat"
			else MatchAutomation.pitching(lab))
		var key: String = "%d:%s" % [state.plate_appearance_number, role]
		if not team.ai_sponsor_choices or not controlled or state._ai_choice_prepared.has(key):
			continue
		var player: PlayerDefinition = (state.batter().definition if role == "bat"
			else state.fielder().definition)
		var item: String = "F03" if role == "bat" else "F01"
		var mode: String = "normal"
		if player.season_sponsors.get(item, false):
			var chosen: bool = SeasonSponsorEffects.choose_optics(state, "wide") if role == "bat" \
				else SeasonCornerstone.choose(state, true)
			if not chosen:
				continue # Fail closed; never record a choice the shared rules rejected.
			mode = "wide" if role == "bat" else "anchor"
		state.ai_choice_events.append({"pa": state.plate_appearance_number,
			"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
			"role": role, "player": String(player.id), "mode": mode,
			"spot": -1 if role == "bat" else lab._fielder_anchor_index})
		state._ai_choice_prepared[key] = true
	SeasonOpponentTactics.prepare(lab)
	disclose(lab)


static func disclose(lab: PitchBatLab) -> void:
	if lab._pitch_feedback == null or not MatchAutomation.presented(lab):
		return
	var state: MatchState = lab._match_state
	var team: TeamMatchState = state.batting_team()
	var active: String = team.tactics.active(state)
	if not team.ai_tactical_hitter.is_empty() and active in SeasonOpponentTactics.ITEMS:
		lab._pitch_feedback.show_note("OPPONENT " + SeasonTacticalCatalog.item(active).name.to_upper()
			+ (" • " + String(team.tactics.locked_swing(state)).trim_prefix("swing.").to_upper()
				if active == "C03" else ""))
	elif state.batting_team().ai_sponsor_choices and state.optics_mode == "wide":
		lab._pitch_feedback.show_note("OPPONENT OPTICS: WIDE")
	elif state.defensive_team().ai_sponsor_choices and SeasonCornerstone.active(state):
		lab._pitch_feedback.show_note("OPPONENT PRIMARY: ANCHORED")

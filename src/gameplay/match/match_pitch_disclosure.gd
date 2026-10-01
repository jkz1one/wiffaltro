class_name MatchPitchDisclosure
extends RefCounted
## An explicit identity-only information exception. Never carries solver/flight state.


static func release(state: MatchState, recipe: StringName, throw_number: int) -> Dictionary:
	state.pitch_disclosure = state.sure_shot.cue(state)
	if not state.pitch_disclosure.is_empty():
		return state.pitch_disclosure.duplicate(true)
	if (
		state.phase != MatchState.Phase.PITCH_IN_FLIGHT
		or recipe == &""
		or state.batting_team().scouted_recipe != recipe
		or not state.batter().definition.season_sponsors.get("J08", false)
	):
		return {}
	state.pitch_disclosure = {
		"source": "J08",
		"recipe": String(recipe),
		"throw": throw_number,
		"time": state.elapsed_seconds
	}
	return state.pitch_disclosure.duplicate(true)


static func present(lab: PitchBatLab) -> void:
	if not lab._match_mode or not lab._pitch_actor.running:
		return
	var event: Dictionary = release(lab._match_state, lab._selected_pitch().id, lab._throw_number)
	if event.is_empty():
		return
	if lab._active_play_record != null:
		lab._active_play_record.pitch_disclosure = event.duplicate(true)
	if lab._batter_approach != null:
		lab._batter_approach.recognized_recipe = event.duplicate(true)
	if lab._player_is_batting():
		lab._status_label.text = (
			("SURE SHOT • " if event.source == "F08" else "FILM ROOM • ")
			+ ContentDB.get_pitch(StringName(event.recipe)).display_name
		)

class_name MatchAutomation
extends RefCounted
## Both clubs use the ordinary bounded live controllers. No outcome shortcuts.

var seed: int = 0
var releases: Array[Dictionary] = []
var initial: Dictionary = {}
var pitch_indices: Dictionary = {}
var approaches: Array[BatterApproachModel] = []


static func player_batting(lab: PitchBatLab) -> bool:
	return lab._match_mode and lab._match_state != null and (
		lab._match_state.top_half != lab._player_home)


static func player_pitching(lab: PitchBatLab) -> bool:
	return lab._match_mode and lab._match_state != null and (
		lab._match_state.top_half == lab._player_home)


static func pitching(lab: PitchBatLab) -> bool:
	return lab._automation != null or player_batting(lab)


static func batting(lab: PitchBatLab) -> bool:
	return lab._automation != null or player_pitching(lab)


func begin(lab: PitchBatLab) -> void:
	releases.clear()
	initial.clear()
	pitch_indices.clear()
	approaches = [BatterApproachModel.new(), BatterApproachModel.new()]
	select_offense(lab)
	lab._batter_approach.reset(lab._match_state.plate_appearance_number)
	for team: TeamMatchState in [lab._match_state.away_team, lab._match_state.home_team]:
		for player: PlayerMatchState in team.roster:
			initial[String(player.definition.id)] = player.stamina_remaining
	lab._throw_number = seed * 1000
	lab._awaiting_batter_confirm = false
	lab._sounds.set_muted(true)
	PitchBatLabFeelSupport.begin_ai_delivery(lab)


func note_release(state: MatchState, recipe: StringName, paid: float) -> void:
	releases.append({
		"pa": state.plate_appearance_number,
		"half": (state.inning - 1) * 2 + (0 if state.top_half else 1),
		"player": String(state.pitcher().definition.id),
		"recipe": String(recipe), "paid": paid
	})


func select_offense(lab: PitchBatLab) -> void:
	lab._batter_approach = approaches[0 if lab._match_state.top_half else 1]

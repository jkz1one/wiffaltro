class_name MatchRosterControls
extends Node

var _lab: PitchBatLab
var _fielder: OptionButton
var _switch: Button
var _roster_key: String = ""


func build(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	_lab = lab
	_fielder = OptionButton.new()
	_fielder.name = "FielderChoice"
	_fielder.custom_minimum_size = Vector2(336, 38)
	_fielder.focus_mode = Control.FOCUS_NONE
	_fielder.item_selected.connect(_select_fielder)
	lab._field_setup_panel.add_child(_fielder)
	lab._field_setup_panel.move_child(_fielder, 1)
	_switch = Button.new()
	_switch.name = "SwitchBattingSide"
	_switch.position = Vector2(1010, 110)
	_switch.custom_minimum_size = Vector2(245, 38)
	_switch.focus_mode = Control.FOCUS_NONE
	_switch.pressed.connect(_switch_side)
	canvas.add_child(_switch)


func _process(_delta: float) -> void:
	if _lab._match_state == null or not _lab._match_mode:
		_switch.hide()
		return
	var state: MatchState = _lab._match_state
	var batter: PlayerMatchState = state.batter()
	if not _lab._player_is_batting() and batter.definition.switch_hitter and state.between_batters:
		var desired: int = 0 if state.pitcher().definition.throws == 1 else 1
		if batter.batting_hand_override != desired:
			batter.batting_hand_override = desired
			PitchBatLabPresentation.sync_players(_lab)
	_switch.visible = (
		_lab._player_is_batting()
		and batter.definition.switch_hitter
		and _lab._awaiting_batter_confirm
		and not _lab._debug_paused
		and not _lab._match_presentation_director.blocks_gameplay()
	)
	_switch.text = "BATS %s  •  SWITCH SIDE" % ("L" if batter.bats_left() else "R")
	_switch.disabled = not can_switch(_lab)
	_switch.tooltip_text = "Choose a side before confirming the at-bat. Locked for this at-bat."
	if not _lab._field_setup_active:
		return
	var team: TeamMatchState = state.defensive_team()
	if _roster_key != team.display_name:
		_roster_key = team.display_name
		_fielder.clear()
		for player_state in team.roster:
			var player: PlayerDefinition = player_state.definition
			_fielder.add_item("%s  •  Fielding %d" % [player.display_name, player.fielding])
	for index in range(team.roster.size()):
		_fielder.set_item_disabled(index, index == team.pitcher_index)
	_fielder.select(team.fielder_index)
	_fielder.disabled = not (
		MatchLabSupport.can_edit_pitch_plan(_lab) and state.can_change_defense()
	)
	_fielder.tooltip_text = "Choose a roster player between batters. Pitcher stays separate."


static func can_switch(lab: PitchBatLab) -> bool:
	return (
		lab._match_mode
		and lab._match_state != null
		and lab._player_is_batting()
		and lab._match_state.batter().definition.switch_hitter
		and lab._awaiting_batter_confirm
		and lab._match_state.between_batters
		and not lab._ai_pitch_preselected
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._debug_paused
	)


func _switch_side() -> void:
	if not can_switch(_lab):
		return
	var batter: PlayerMatchState = _lab._match_state.batter()
	batter.batting_hand_override = 0 if batter.bats_left() else 1
	PitchBatLabPresentation.sync_players(_lab)
	_lab._apply_role_camera()
	_lab._refresh_config()


func _select_fielder(index: int) -> void:
	if not MatchLabSupport.can_edit_pitch_plan(_lab) or not _lab._match_state.can_change_defense():
		return
	var team: TeamMatchState = _lab._match_state.defensive_team()
	if index < 0 or index >= team.roster.size() or index == team.pitcher_index:
		return
	team.fielder_index = index
	_lab._apply_defensive_assignment()
	_lab._refresh_config()

class_name MatchJumpstartControls
extends Node
## Readiness-only direction input; no ball state or prediction is read.

var lab: PitchBatLab
var choice: Button


func build(owner_lab: PitchBatLab) -> void:
	lab = owner_lab
	choice = Button.new()
	choice.name = "JumpstartChoice"
	choice.custom_minimum_size = Vector2(336, 64)
	choice.add_theme_font_size_override("font_size", 13)
	choice.pressed.connect(_choose)
	choice.tooltip_text = (
		"Before the first pitch, cycle Normal / Left / Right / In / Out. "
		+ "Left/Right use the field's anchor labels; In is toward home, Out toward the wall. "
		+ "At fair contact: 0.20s at normal speed. Cannot combine with Cornerstone anchor."
	)
	lab._field_setup_panel.add_child(choice)
	lab._field_setup_panel.move_child(choice, 2)
	choice.hide()


func can_choose() -> bool:
	return (
		MatchLabSupport.can_edit_pitch_plan(lab)
		and lab._match_state.can_change_defense()
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and lab._match_state.fielder().definition.season_sponsors.get("J04", false)
		and not lab._match_state.cornerstone_anchored
		and not lab._match_presentation_director.blocks_gameplay()
	)


func _process(_delta: float) -> void:
	choice.visible = (
		lab._match_mode
		and lab._match_state != null
		and lab._player_is_pitching()
		and lab._match_state.fielder().definition.season_sponsors.get("J04", false)
	)
	choice.disabled = not choice.visible or not can_choose()
	if choice.visible:
		choice.text = (
			"JUMPSTART: %s • 0.20s normal-speed step\n%s"
			% [
				lab._match_state.jumpstart_mode.to_upper(),
				(
					"Turn off Cornerstone anchor first"
					if lab._match_state.cornerstone_anchored
					else (
						"Click to cycle • Working"
						if not choice.disabled
						else "Locked until next batter"
					)
				)
			]
		)


func _choose() -> void:
	if not can_choose():
		return
	var modes: Array[String] = SeasonJumpstart.MODES
	var next: int = (modes.find(lab._match_state.jumpstart_mode) + 1) % modes.size()
	SeasonJumpstart.choose(lab._match_state, modes[next])
	lab._refresh_config()
	_process(0)

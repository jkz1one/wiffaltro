class_name MatchSureShotControls
extends Node
## Both observers read the same timestamped identity-only announcement.

var lab: PitchBatLab
var choice: Button
var announcement: Label


func build(owner_lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab = owner_lab
	choice = Button.new()
	choice.name = "SureShotChoice"
	choice.custom_minimum_size = Vector2(336, 64)
	choice.add_theme_font_size_override("font_size", 13)
	choice.pressed.connect(_choose)
	choice.tooltip_text = (
		"Select a recipe in the pitch picker, then announce it here before the PA. "
		+ "The announcement is final, including after canceled windups. Two uses per team per game. "
		+ "Location and effort stay available; recipe and pitcher lock until the next batter."
	)
	lab._field_setup_panel.add_child(choice)
	lab._field_setup_panel.move_child(choice, 2)
	choice.hide()
	announcement = Label.new()
	announcement.name = "SureShotAnnouncement"
	announcement.position = Vector2(330, 150)
	announcement.size = Vector2(620, 40)
	announcement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announcement.add_theme_font_size_override("font_size", 16)
	announcement.add_theme_constant_override("outline_size", 4)
	announcement.add_theme_color_override("font_outline_color", Color("102332"))
	announcement.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(announcement)
	announcement.hide()


func can_choose() -> bool:
	if not lab._match_mode or lab._match_state == null:
		return false
	var state: MatchState = lab._match_state
	return (
		lab._player_is_pitching()
		and state.phase == MatchState.Phase.PRE_PITCH
		and state.between_batters
		and state.sure_shot.current(state).is_empty()
		and state.sure_shot.remaining(state.defensive_team()) > 0
		and state.pitcher().definition.season_sponsors.get("F08", false)
		and not lab._match_presentation_director.blocks_gameplay()
	)


func _process(_delta: float) -> void:
	if lab._match_state == null:
		return
	var state: MatchState = lab._match_state
	choice.visible = (
		lab._match_mode
		and lab._player_is_pitching()
		and state.pitcher().definition.season_sponsors.get("F08", false)
	)
	choice.disabled = not can_choose()
	var call: Dictionary = state.sure_shot.current(state)
	if choice.visible:
		choice.text = (
			"SURE SHOT • %d/2 uses left\n%s"
			% [
				state.sure_shot.remaining(state.defensive_team()),
				(
					"Announce " + lab._selected_pitch().display_name
					if can_choose()
					else (
						"Committed until next batter"
						if not call.is_empty()
						else "Ready before next PA"
					)
				)
			]
		)
	announcement.visible = lab._match_mode and not call.is_empty()
	if announcement.visible:
		announcement.text = (
			"SURE SHOT • %s • announced %.1fs"
			% [ContentDB.get_pitch(StringName(call.recipe)).display_name, float(call.time)]
		)


func _choose() -> void:
	if can_choose():
		lab._match_state.sure_shot.choose(lab._match_state, lab._selected_pitch().id)
		lab._refresh_config()
		_process(0)

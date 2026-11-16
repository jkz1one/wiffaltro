extends RefCounted
## Stateless operations for the original PitchBatLabPresentation script.


static func _build_pitching_staff(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab._pitching_staff_toggle_button = Button.new()
	lab._pitching_staff_toggle_button.position = Vector2(1123.0, 16.0)
	lab._pitching_staff_toggle_button.custom_minimum_size = Vector2(132.0, 34.0)
	lab._pitching_staff_toggle_button.focus_mode = Control.FOCUS_NONE
	lab._pitching_staff_toggle_button.pressed.connect(lab._toggle_pitching_staff)
	canvas.add_child(lab._pitching_staff_toggle_button)

	lab._pitching_staff_panel = ClubhouseMenuStack.new()
	lab._pitching_staff_panel.position = Vector2(855.0, 128.0)
	lab._pitching_staff_panel.custom_minimum_size = Vector2(400.0, 0.0)
	canvas.add_child(lab._pitching_staff_panel)
	var title: Label = Label.new()
	title.text = "BULLPEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	lab._pitching_staff_panel.add_child(title)
	for index in range(TeamMatchState.ROSTER_SIZE):
		var row: HBoxContainer = HBoxContainer.new()
		lab._pitching_staff_panel.add_child(row)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(308.0, 62.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(lab._select_pitcher.bind(index))
		row.add_child(button)
		lab._pitcher_buttons.append(button)
		var inspect_button: Button = Button.new()
		inspect_button.text = "DETAILS"
		inspect_button.custom_minimum_size = Vector2(84, 44)
		inspect_button.set_meta("inspect_staff", index)
		inspect_button.pressed.connect(
			PitchBatLabPresentation._inspect_pitcher.bind(lab, index, inspect_button)
		)
		row.add_child(inspect_button)
	var return_button: Button = Button.new()
	return_button.text = "RETURN TO PITCH (ESC)"
	return_button.custom_minimum_size = Vector2(400.0, 38.0)
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.pressed.connect(lab._toggle_pitching_staff)
	lab._pitching_staff_panel.add_child(return_button)


static func _inspect_pitcher(lab: PitchBatLab, index: int, button: Button) -> void:
	if lab._match_state == null or not lab._pitching_staff_active:
		return
	var team: TeamMatchState = lab._match_state.defensive_team()
	SeasonPlayerInspector.open_from(button, team.roster[index].definition)


static func _build_pitch_release_meter(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab._pitch_release_bar = ProgressBar.new()
	lab._pitch_release_bar.position = Vector2(507.0, 72.0)
	lab._pitch_release_bar.size = Vector2(300.0, 12.0)
	lab._pitch_release_bar.min_value = 0.0
	lab._pitch_release_bar.max_value = 100.0
	lab._pitch_release_bar.show_percentage = false
	lab._pitch_release_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lab._pitch_release_bar)

	lab._pitch_release_ideal_marker = ColorRect.new()
	lab._pitch_release_ideal_marker.color = Color(0.95, 0.82, 0.18)
	lab._pitch_release_ideal_marker.size = Vector2(4.0, 18.0)
	lab._pitch_release_ideal_marker.position = Vector2(
		507.0 + 300.0 * PitchReleaseController.new().ideal_progress() - 2.0, 69.0
	)
	lab._pitch_release_ideal_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lab._pitch_release_ideal_marker)


static func _public_refresh_display_menu(lab: PitchBatLab) -> void:
	if lab._pause_menu == null:
		return
	var presentation_active: bool = (
		lab._match_presentation_director != null
		and lab._match_presentation_director.blocks_gameplay()
	)
	lab._display_menu_button.visible = not presentation_active or lab._debug_paused
	lab._pause_menu.refresh()


static func _build_match_presentation(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab._presentation_backdrop = ColorRect.new()
	lab._presentation_backdrop.theme = ClubhouseTheme.create()
	lab._presentation_backdrop.position = Vector2.ZERO
	lab._presentation_backdrop.size = Vector2(1280.0, 720.0)
	lab._presentation_backdrop.color = Color(0.015, 0.025, 0.04, 0.18)
	lab._presentation_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lab._presentation_backdrop)

	lab._presentation_title = Label.new()
	lab._presentation_title.position = Vector2(0.0, 270.0)
	lab._presentation_title.size = Vector2(1280.0, 78.0)
	lab._presentation_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._presentation_title.add_theme_font_size_override("font_size", 52)
	lab._presentation_title.add_theme_constant_override("outline_size", 6)
	lab._presentation_title.add_theme_color_override(
		"font_outline_color", Color(0.025, 0.055, 0.085, 1.0)
	)
	lab._presentation_title.add_theme_constant_override("shadow_offset_x", 5)
	lab._presentation_title.add_theme_constant_override("shadow_offset_y", 5)
	lab._presentation_title.add_theme_color_override(
		"font_shadow_color", Color(0.025, 0.055, 0.085, 0.82)
	)
	lab._presentation_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._presentation_backdrop.add_child(lab._presentation_title)

	lab._presentation_subtitle = Label.new()
	lab._presentation_subtitle.position = Vector2(0.0, 350.0)
	lab._presentation_subtitle.size = Vector2(1280.0, 90.0)
	lab._presentation_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._presentation_subtitle.add_theme_font_size_override("font_size", 22)
	lab._presentation_subtitle.add_theme_constant_override("outline_size", 4)
	lab._presentation_subtitle.add_theme_color_override(
		"font_outline_color", Color(0.025, 0.055, 0.085, 1.0)
	)
	lab._presentation_subtitle.add_theme_constant_override("shadow_offset_x", 3)
	lab._presentation_subtitle.add_theme_constant_override("shadow_offset_y", 3)
	lab._presentation_subtitle.add_theme_color_override(
		"font_shadow_color", Color(0.025, 0.055, 0.085, 0.78)
	)
	lab._presentation_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._presentation_backdrop.add_child(lab._presentation_subtitle)
	lab._presentation_backdrop.visible = false


static func _build_event_panel(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab._event_panel = Panel.new()
	lab._event_panel.position = Vector2(320.0, 270.0)
	lab._event_panel.size = Vector2(640.0, 142.0)
	lab._event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._event_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	canvas.add_child(lab._event_panel)
	lab._status_label = Label.new()
	lab._status_label.position = Vector2(8.0, 4.0)
	lab._status_label.size = Vector2(624.0, 134.0)
	lab._status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab._status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._status_label.add_theme_font_size_override("font_size", 22)
	lab._status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._event_panel.add_child(lab._status_label)

	lab._hr_celebration_label = Label.new()
	lab._hr_celebration_label.name = "HomeRunCelebration"
	lab._hr_celebration_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._hr_celebration_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab._hr_celebration_label.add_theme_font_size_override("font_size", 88)
	lab._hr_celebration_label.add_theme_constant_override("outline_size", 6)
	lab._hr_celebration_label.add_theme_color_override(
		"font_outline_color", Color(0.025, 0.055, 0.085, 1.0)
	)
	lab._hr_celebration_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.58, 1.0))
	lab._hr_celebration_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._hr_celebration_label.visible = false
	canvas.add_child(lab._hr_celebration_label)


static func _make_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style


static func _refresh_pitch_release_meter(lab: PitchBatLab) -> void:
	if lab._pitch_release_bar == null or lab._pitch_release_ideal_marker == null:
		return
	var visible: bool = (
		lab._match_mode
		and lab._player_is_pitching()
		and lab._release_controller != null
		and lab._release_controller.active
	)
	lab._pitch_release_bar.visible = visible
	lab._pitch_release_ideal_marker.visible = visible
	if visible:
		lab._pitch_release_bar.value = (lab._release_controller.meter_progress() * 100.0)


static func _build_field_setup(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab._field_setup_toggle_button = Button.new()
	lab._field_setup_toggle_button.position = Vector2(1123.0, 62.0)
	lab._field_setup_toggle_button.custom_minimum_size = Vector2(132.0, 34.0)
	lab._field_setup_toggle_button.focus_mode = Control.FOCUS_NONE
	lab._field_setup_toggle_button.pressed.connect(lab._toggle_field_setup)
	canvas.add_child(lab._field_setup_toggle_button)

	lab._field_setup_panel = ClubhouseMenuStack.new()
	lab._field_setup_panel.position = Vector2(910.0, 128.0)
	canvas.add_child(lab._field_setup_panel)
	var title: Label = Label.new()
	title.text = "FIELD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._field_setup_panel.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	lab._field_setup_panel.add_child(grid)
	var visual_order: Array[int] = [8, 7, 6, 5, 4, 3, 2, 1, 0]
	for anchor_index in visual_order:
		var anchor_button: Button = Button.new()
		anchor_button.custom_minimum_size = Vector2(112.0, 38.0)
		anchor_button.add_theme_font_size_override("font_size", 12)
		anchor_button.focus_mode = Control.FOCUS_NONE
		anchor_button.text = (
			lab._field_definition.fielder_anchor_name(anchor_index)
			if lab._field_definition.is_fielder_anchor_available(anchor_index)
			else "PITCHER LANE"
		)
		anchor_button.set_meta(&"anchor_index", anchor_index)
		anchor_button.pressed.connect(lab._select_fielder_anchor.bind(anchor_index))
		grid.add_child(anchor_button)
		lab._field_anchor_buttons.append(anchor_button)
	var exit_button: Button = Button.new()
	exit_button.text = "RETURN TO PITCH (ESC)"
	exit_button.custom_minimum_size = Vector2(336.0, 38.0)
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(lab._toggle_field_setup)
	lab._field_setup_panel.add_child(exit_button)
	var roster_controls: MatchRosterControls = MatchRosterControls.new()
	roster_controls.name = "RosterControls"
	roster_controls.build(lab, canvas)
	canvas.add_child(roster_controls)
	var sponsors: MatchSponsorControls = MatchSponsorControls.new()
	sponsors.name = "SponsorControls"
	sponsors.build(lab, canvas)
	canvas.add_child(sponsors)
	var tactics: MatchTacticalControls = MatchTacticalControls.new()
	tactics.name = "TacticalControls"
	lab.add_child(tactics)
	tactics.build(lab, canvas)


static func _refresh_field_setup(lab: PitchBatLab) -> void:
	if lab._field_setup_toggle_button == null or lab._field_setup_panel == null:
		return
	var on_defense: bool = (
		lab._match_mode and lab._match_state != null and lab._player_is_pitching()
	)
	lab._field_setup_toggle_button.visible = (on_defense and not lab._pitching_staff_active)
	lab._field_setup_panel.visible = on_defense and lab._field_setup_active
	if not on_defense:
		return
	lab._field_setup_toggle_button.text = (
		"BACK"
		if lab._field_setup_active
		else (
			"FIELD: ANCHOR"
			if SeasonCornerstone.active(lab._match_state)
			else (
				"FIELD: " + lab._match_state.jumpstart_mode.to_upper()
				if not SeasonJumpstart.direction(lab._match_state).is_zero_approx()
				else "FIELD"
			)
		)
	)
	lab._field_setup_toggle_button.disabled = (
		lab._debug_paused
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._release_controller.active
		or lab._ball_in_play_is_live()
		or (lab._pitch_actor != null and lab._pitch_actor.running)
	)
	for button in lab._field_anchor_buttons:
		var anchor_index: int = int(button.get_meta(&"anchor_index", -1))
		button.disabled = (
			not MatchLabSupport.can_edit_pitch_plan(lab)
			or SeasonCornerstone.position_locked(lab._match_state)
			or not lab._field_definition.is_fielder_anchor_available(anchor_index)
			or anchor_index == lab._fielder_anchor_index
		)


static func _refresh_pitching_staff(lab: PitchBatLab) -> void:
	if lab._pitching_staff_panel == null or lab._pitching_staff_toggle_button == null:
		return
	var on_defense: bool = (
		lab._match_mode and lab._match_state != null and lab._player_is_pitching()
	)
	lab._pitching_staff_toggle_button.visible = (on_defense and not lab._field_setup_active)
	lab._pitching_staff_panel.visible = (on_defense and lab._pitching_staff_active)
	if not on_defense:
		return
	lab._pitching_staff_toggle_button.text = ("BACK" if lab._pitching_staff_active else "BULLPEN")
	lab._pitching_staff_toggle_button.disabled = (
		lab._debug_paused
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._release_controller.active
		or lab._ball_in_play_is_live()
		or (lab._pitch_actor != null and lab._pitch_actor.running)
	)
	var team: TeamMatchState = lab._match_state.defensive_team()
	var can_change: bool = (
		lab._match_state.can_change_defense()
		and MatchLabSupport.can_edit_pitch_plan(lab)
		and not lab._debug_paused
	)
	for index in range(mini(lab._pitcher_buttons.size(), team.roster.size())):
		var player: PlayerMatchState = team.roster[index]
		var button: Button = lab._pitcher_buttons[index]
		var role: String = "PITCHER" if index == team.pitcher_index else "READY"
		var encore: bool = SeasonEncore.available(team, index)
		if player.pitching_finished:
			role = "ENCORE RETURN" if encore else "USED"
		button.text = (
			"%s • %s\nThrows %s • %.0f%% stamina • %s"
			% [
				player.definition.display_name,
				role,
				"LEFT" if player.definition.throws == PlayerDefinition.Handedness.LEFT else "RIGHT",
				player.stamina_percent() * 100.0,
				PitchExecutionModel.fatigue_stage_name(player.fatigue_ratio()),
			]
		)
		button.disabled = (
			not can_change
			or team.sure_shot_locked
			or index == team.pitcher_index
			or (player.pitching_finished and not encore)
		)
		button.tooltip_text = (
			"Review your one Encore return. Spent stamina and used effects stay unchanged."
			if encore
			else "Removed pitchers cannot pitch again; batting and fielding remain available."
		)


static func _add_label(canvas: CanvasLayer, position: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.position = position
	label.add_theme_font_size_override("font_size", font_size)
	canvas.add_child(label)
	return label


static func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

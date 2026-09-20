class_name PitchBatLabPresentation
extends RefCounted

static func build_pitch_actor(lab: PitchBatLab) -> void:
	lab._pitch_actor = PitchFlightActor.new()
	lab._pitch_actor.name = "PitchFlightActor"
	lab._pitch_actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._pitch_actor.trace_every_substeps = 2
	lab._pitch_actor.trace_sampled.connect(lab._on_trace_sampled)
	lab._pitch_actor.segment_advanced.connect(lab._on_pitch_segment_advanced)
	lab._pitch_actor.plate_crossed.connect(lab._on_plate_crossed)
	lab._pitch_actor.flight_stopped.connect(lab._on_flight_stopped)
	lab.add_child(lab._pitch_actor)

	lab._trajectory_draw = TrajectoryDebugDraw.new()
	lab._trajectory_draw.name = "TrajectoryTrace"
	lab._trajectory_draw.material_override = _make_unshaded_material(
		Color(1.0, 0.72, 0.12)
	)
	lab.add_child(lab._trajectory_draw)

	lab._contact_vector_draw = TrajectoryDebugDraw.new()
	lab._contact_vector_draw.name = "ContactVector"
	lab._contact_vector_draw.material_override = _make_unshaded_material(
		Color(0.25, 0.90, 1.0)
	)
	lab.add_child(lab._contact_vector_draw)

static func build_defenders(lab: PitchBatLab) -> void:
	lab._primary_fielder = FielderController.new()
	lab._primary_fielder.name = "PrimaryFielder"
	lab._primary_fielder.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab.add_child(lab._primary_fielder)
	lab._primary_fielder.set_anchor(
		lab._field_definition.fielder_anchor(lab._fielder_anchor_index)
	)

	lab._pitcher_marker = Node3D.new()
	lab._pitcher_marker.name = "PitcherDefender"
	lab._pitcher_marker.position = lab.MOUND_ORIGIN
	lab.add_child(lab._pitcher_marker)

	lab._pitcher_avatar = PlayerAvatar.new()
	lab._pitcher_avatar.name = "PitcherAvatar"
	lab._pitcher_marker.add_child(lab._pitcher_avatar)
	lab._pitcher_avatar.configure(
		PlayerAvatar.Role.PITCHER,
		false,
		false,
		Color(0.92, 0.30, 0.18)
	)

	lab._batter_avatar = PlayerAvatar.new()
	lab._batter_avatar.name = "BatterAvatar"
	lab.add_child(lab._batter_avatar)
	lab._batter_avatar.configure(
		PlayerAvatar.Role.BATTER,
		false,
		false,
		Color(0.94, 0.78, 0.18)
	)

	lab._bat_actor = BatActor.new()
	lab._bat_actor.name = "BatActor"
	lab.add_child(lab._bat_actor)

static func sync_players(lab: PitchBatLab) -> void:
	if lab._match_state == null:
		return
	var batter: PlayerDefinition = lab._match_state.batter().definition
	var pitcher: PlayerDefinition = lab._match_state.pitcher().definition
	var fielder: PlayerDefinition = lab._match_state.fielder().definition
	var batter_left: bool = batter.bats == PlayerDefinition.Handedness.LEFT
	if lab._batter_avatar != null:
		var batter_position: Vector3 = Vector3(
			0.82 if batter_left else -0.82,
			0.0,
			0.34
		)
		lab._batter_avatar.configure(
			PlayerAvatar.Role.BATTER,
			batter_left,
			batter.throws == PlayerDefinition.Handedness.LEFT,
			Color(0.94, 0.78, 0.18)
		)
		lab._batter_avatar.position = batter_position
		if lab._bat_actor != null:
			lab._bat_actor.configure(batter_left, batter_position)
	if lab._pitcher_avatar != null:
		lab._pitcher_avatar.configure(
			PlayerAvatar.Role.PITCHER,
			pitcher.bats == PlayerDefinition.Handedness.LEFT,
			pitcher.throws == PlayerDefinition.Handedness.LEFT,
			Color(0.92, 0.30, 0.18)
		)
	if lab._primary_fielder != null:
		lab._primary_fielder.configure_player(fielder)
	if lab._camera_director != null:
		lab._camera_director.set_batter_handedness(batter_left)

static func play_batter_swing(
	lab: PitchBatLab,
	profile: SwingProfileDefinition
) -> void:
	if lab._bat_actor != null:
		lab._bat_actor.play_swing(profile)

static func show_pitcher_fielding_attempt(
	lab: PitchBatLab,
	ball_position: Vector3,
	outcome: FieldingResolver.Outcome
) -> void:
	if lab._pitcher_marker == null:
		return
	var offset: Vector3 = ball_position - lab.MOUND_ORIGIN
	offset.y = 0.0
	if offset.length_squared() > 0.0001:
		offset = offset.normalized() * minf(0.72, offset.length())
	lab._pitcher_marker.position = lab.MOUND_ORIGIN + offset
	lab._pitcher_marker.rotation.z = (
		0.18 if outcome == FieldingResolver.Outcome.CLEAN else 0.10
	) * signf(offset.x if absf(offset.x) > 0.01 else 1.0)

static func build_environment(lab: PitchBatLab) -> void:
	var geometry: StarterFieldLabGeometry = StarterFieldLabGeometry.new()
	geometry.name = "StarterFieldGeometry"
	lab.add_child(geometry)
	var contact_profile: SwingProfileDefinition = ContentDB.get_swing(
		lab.CONTACT_SWING_ID
	)
	var power_profile: SwingProfileDefinition = ContentDB.get_swing(
		lab.POWER_SWING_ID
	)
	geometry.build(
		lab._field_definition,
		lab.MOUND_ORIGIN,
		lab.ZONE_MIN_X,
		lab.ZONE_MAX_X,
		lab.ZONE_MIN_Y,
		lab.ZONE_MAX_Y,
		Vector2(
			contact_profile.contact_radius_x_m * 2.0,
			contact_profile.contact_radius_y_m * 2.0
		),
		Vector2(
			power_profile.contact_radius_x_m * 2.0,
			power_profile.contact_radius_y_m * 2.0
		)
	)
	lab._pitch_target_marker = geometry.pitch_target_marker
	lab._batting_aim_marker = geometry.batting_aim_marker
	lab._receiver_marker = geometry.receiver_marker

	lab._camera = Camera3D.new()
	lab._camera.name = "LabCamera"
	lab._camera.current = true
	lab.add_child(lab._camera)
	lab._camera_director = MatchCameraDirector.new()
	apply_camera_mode(lab)
	lab._camera_director.snap(lab._camera)

static func build_ui(lab: PitchBatLab) -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "DebugUI"
	lab.add_child(canvas)

	lab._scorebug = MatchScorebug.new()
	lab._scorebug.position = Vector2(18.0, 16.0)
	canvas.add_child(lab._scorebug)
	_build_pitch_release_meter(lab, canvas)
	lab._action_label = _add_label(canvas, Vector2(392.0, 14.0), 17)
	lab._action_label.size = Vector2(530.0, 62.0)
	lab._action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._config_label = _add_label(canvas, Vector2(20.0, 154.0), 13)
	lab._config_label.size = Vector2(350.0, 150.0)
	lab._config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_event_panel(lab, canvas)
	lab._status_label.text = "Loading Pitch Lab..."
	lab._live_label = _add_label(canvas, Vector2(20.0, 315.0), 13)
	lab._live_label.size = Vector2(350.0, 130.0)
	lab._live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._controls_label = _add_label(canvas, Vector2(20.0, 646.0), 13)
	lab._controls_label.size = Vector2(930.0, 58.0)
	_build_pitching_staff(lab, canvas)
	_build_field_setup(lab, canvas)
	_build_match_presentation(lab, canvas)
	refresh_controls(lab)

static func show_match_intro(lab: PitchBatLab) -> void:
	if lab._presentation_backdrop == null:
		return
	lab._presentation_backdrop.visible = true
	lab._presentation_title.text = "GAME START"
	lab._presentation_subtitle.text = "%s at %s" % [
		lab.PLAYER_TEAM_NAME,
		lab.RIVAL_TEAM_NAME,
	]
	_set_gameplay_hud_visible(lab, false)

static func show_match_outro(lab: PitchBatLab, player_won: bool) -> void:
	if lab._presentation_backdrop == null or lab._match_state == null:
		return
	lab._presentation_backdrop.visible = true
	lab._presentation_title.text = "WIN" if player_won else "LOSS"
	lab._presentation_subtitle.text = "%s\nR: NEW MATCH" % (
		lab._match_state.score_label()
	)
	_set_gameplay_hud_visible(lab, false)

static func hide_match_presentation(lab: PitchBatLab) -> void:
	if lab._presentation_backdrop != null:
		lab._presentation_backdrop.visible = false

static func _set_gameplay_hud_visible(lab: PitchBatLab, visible: bool) -> void:
	if lab._scorebug != null:
		lab._scorebug.visible = visible and lab._match_mode
	if lab._action_label != null:
		lab._action_label.visible = visible and lab._match_mode
	if lab._controls_label != null:
		lab._controls_label.visible = visible
	if lab._config_label != null:
		lab._config_label.visible = false
	if lab._live_label != null:
		lab._live_label.visible = false
	if lab._event_panel != null:
		lab._event_panel.visible = false
	if lab._pitching_staff_panel != null:
		lab._pitching_staff_panel.visible = false
	if lab._field_setup_toggle_button != null:
		lab._field_setup_toggle_button.visible = false
	if lab._field_setup_panel != null:
		lab._field_setup_panel.visible = false
	if lab._pitch_release_bar != null:
		lab._pitch_release_bar.visible = false
	if lab._pitch_release_ideal_marker != null:
		lab._pitch_release_ideal_marker.visible = false
	if lab._trajectory_draw != null:
		lab._trajectory_draw.visible = false
	if lab._contact_vector_draw != null:
		lab._contact_vector_draw.visible = false
	if lab._receiver_marker != null:
		lab._receiver_marker.visible = false

static func refresh_event(lab: PitchBatLab) -> void:
	if lab._event_panel == null or lab._status_label == null:
		return
	lab._event_panel.visible = not lab._status_label.text.strip_edges().is_empty()

static func cycle_camera(lab: PitchBatLab) -> void:
	if lab._field_setup_active:
		return
	lab._camera_mode = (lab._camera_mode + 1) % 4
	apply_camera_mode(lab)

static func apply_camera_mode(lab: PitchBatLab) -> void:
	if lab._camera_director == null:
		lab._camera_director = MatchCameraDirector.new()
	match lab._camera_mode:
		0:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.BATTING)
		1:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING)
		2:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.SIDE)
		3:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)

static func apply_role_camera(lab: PitchBatLab) -> void:
	if lab._camera == null:
		return
	if lab._match_mode:
		if lab._field_setup_active:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.FIELD_SETUP)
			return
		lab._camera_mode = 0 if lab._player_is_batting() else 1
	else:
		lab._camera_mode = 0
	apply_camera_mode(lab)

static func refresh(lab: PitchBatLab) -> void:
	if (
		lab._config_label == null
		or lab._scorebug == null
		or lab._action_label == null
	):
		return
	var pitch: PitchDefinition = lab._selected_pitch()
	if lab._match_mode and lab._match_state != null:
		_refresh_match(lab, pitch)
	else:
		_refresh_lab(lab, pitch)
	_refresh_pitching_staff(lab)
	_refresh_field_setup(lab)
	_refresh_pitch_release_meter(lab)
	lab._action_label.visible = lab._match_mode
	lab._controls_label.visible = true
	lab._config_label.visible = lab._debug_overlay_visible
	lab._live_label.visible = lab._debug_overlay_visible
	lab._trajectory_draw.visible = lab._debug_overlay_visible
	lab._contact_vector_draw.visible = lab._debug_overlay_visible
	if lab._receiver_marker != null:
		lab._receiver_marker.visible = lab._debug_overlay_visible
	refresh_event(lab)
	refresh_controls(lab)

static func refresh_markers(lab: PitchBatLab) -> void:
	if lab._pitch_target_marker != null:
		lab._pitch_target_marker.position = Vector3(
			lab._pitch_target.x,
			lab._pitch_target.y,
			0.015
		)
		lab._pitch_target_marker.visible = (
			not lab._match_mode or lab._player_is_pitching()
		)
	if lab._batting_aim_marker != null:
		lab._batting_aim_marker.position = Vector3(
			lab._batting_aim.x,
			lab._batting_aim.y,
			-0.015
		)
		lab._batting_aim_marker.visible = (
			not lab._match_mode or lab._player_is_batting()
		)
		var contact_factor: float = 1.0
		if lab._match_mode and lab._match_state != null:
			contact_factor = lerpf(
				0.82,
				1.18,
				float(lab._match_state.batter().definition.contact) / 10.0
			)
		lab._batting_aim_marker.scale = Vector3(
			contact_factor,
			contact_factor,
			1.0
		)

static func refresh_controls(lab: PitchBatLab) -> void:
	if lab._controls_label == null:
		return
	if lab._match_mode:
		lab._controls_label.text = (
			"F1 DEBUG   F2 LAB   F3 RECORDS   P PAUSE   V CAMERA   R NEW MATCH\n"
			+ "BAT: pointer + click Contact/Power   •   "
			+ "PITCH: aim + hold/release   •   FIELD VIEW before Pitch"
		)
	else:
		lab._controls_label.text = (
			"F1 OVERLAY   F2 RESUME MATCH   F3 RECORDS   P PAUSE   V CAMERA   R RESET\n"
			+ "1–9 Pitch   arrows target   pointer/WASD bat   ,/. execution   [/] fatigue   B BIP"
		)

static func contact_outcome_name(outcome: ContactResult.Outcome) -> String:
	match outcome:
		ContactResult.Outcome.FOUL:
			return "FOUL"
		ContactResult.Outcome.CONTACT:
			return "CONTACT"
		ContactResult.Outcome.PERFECT:
			return "PERFECT"
		_:
			return "MISS"

static func result_floor_name(result_floor: BallPlayState.ResultFloor) -> String:
	match result_floor:
		BallPlayState.ResultFloor.SINGLE:
			return "Single"
		BallPlayState.ResultFloor.DOUBLE:
			return "Double"
		BallPlayState.ResultFloor.TRIPLE:
			return "Triple"
		BallPlayState.ResultFloor.HOME_RUN:
			return "Home Run"
		_:
			return "None"

static func _refresh_match(lab: PitchBatLab, pitch: PitchDefinition) -> void:
	var match_state: MatchState = lab._match_state
	var on_deck_state: PlayerMatchState = match_state.on_deck_batter()
	var pitcher_state: PlayerMatchState = match_state.pitcher()
	var fielder_state: PlayerMatchState = match_state.fielder()
	lab._scorebug.refresh(match_state)
	var options: Array[PitchDefinition] = lab._current_pitch_options()
	if lab._debug_paused:
		lab._action_label.text = "DEBUG PAUSED     P: resume"
	elif lab._field_setup_active:
		lab._action_label.text = (
			"FIELD SETUP     choose an anchor     RETURN TO PITCH when ready"
		)
	elif (
		match_state.phase == MatchState.Phase.PLAY_DEAD
		or match_state.phase == MatchState.Phase.INNING_TRANSITION
		or match_state.phase == MatchState.Phase.BALL_IN_PLAY
		or match_state.phase == MatchState.Phase.GAME_END
	):
		lab._action_label.text = ""
	elif lab._player_is_batting():
		if lab._awaiting_batter_confirm:
			lab._action_label.text = ""
		else:
			var cadence_text: String = "PITCHER READYING"
			if (
				lab._at_bat_cadence != null
				and lab._at_bat_cadence.state
				== AtBatCadenceController.State.DELIVERY
			):
				cadence_text = lab._at_bat_cadence.delivery_cue()
			elif lab._pitch_actor != null and lab._pitch_actor.running:
				cadence_text = "TRACK THE BALL"
			lab._action_label.text = (
				"%s\nLEFT CLICK CONTACT   •   RIGHT CLICK POWER"
				% cadence_text
			)
	else:
		if match_state.phase != MatchState.Phase.PRE_PITCH:
			lab._action_label.text = ""
		else:
			var release_text: String = (
				PitchBatLabFeelSupport.release_meter_text(lab)
			)
			lab._action_label.text = (
				release_text
				if not release_text.is_empty()
				else "%d: %s   •   EFFORT %.0f%%\nAIM, THEN HOLD CLICK/SPACE" % [
					lab._selected_pitch_index + 1,
					pitch.display_name if pitch != null else "None",
					lab._pitch_effort * 100.0,
				]
			)
	var applied_fatigue: float = maxf(
		pitcher_state.fatigue_ratio(),
		lab._fatigue
	)
	lab._config_label.text = (
		"DEBUG • %s • %.1f s\n"
		+ "Pitch %d/%d %s • effort %.0f%%\n"
		+ "target %.2f / %.2f • bat %.2f / %.2f\n"
		+ "fatigue %.0f%% → %.0f%% %s • overcook %.0f%%\n"
		+ "fielder %s %s • %s • records %d\n"
		+ "AI read %.0f%% • %s • on deck %s"
	) % [
		"PLAYER BATTING" if lab._player_is_batting() else "PLAYER PITCHING",
		match_state.elapsed_seconds,
		lab._selected_pitch_index + 1,
		options.size(),
		pitch.display_name if pitch != null else "None",
		lab._pitch_effort * 100.0,
		lab._pitch_target.x,
		lab._pitch_target.y,
		lab._batting_aim.x,
		lab._batting_aim.y,
		applied_fatigue * 100.0,
		PitchExecutionModel.fatigue_pressure(applied_fatigue) * 100.0,
		PitchExecutionModel.fatigue_stage_name(applied_fatigue),
		lab._last_release_overdrive * 100.0,
		fielder_state.definition.display_name,
		"L" if fielder_state.definition.throws == PlayerDefinition.Handedness.LEFT else "R",
		lab._field_definition.fielder_anchor_name(lab._fielder_anchor_index),
		lab._play_records.size(),
		lab._last_ai_awareness * 100.0,
		lab._last_ai_read_text,
		on_deck_state.definition.display_name,
	]

static func _refresh_lab(lab: PitchBatLab, pitch: PitchDefinition) -> void:
	lab._scorebug.visible = false
	lab._config_label.text = (
		"MECHANICS LAB   PITCH %d/%d  %s   effort %.0f%%\n"
		+ "target x %.2f / y %.2f   execution %.0f%%   fatigue %.0f%% → effect %.0f%%\n"
		+ "bat aim x %.2f / y %.2f\n"
		+ "fielder %s   %s"
	) % [
		lab._selected_pitch_index + 1,
		lab.PITCH_IDS.size(),
		pitch.display_name,
		lab._pitch_effort * 100.0,
		lab._pitch_target.x,
		lab._pitch_target.y,
		lab._execution_quality * 100.0,
		lab._fatigue * 100.0,
		PitchExecutionModel.fatigue_pressure(lab._fatigue) * 100.0,
		lab._batting_aim.x,
		lab._batting_aim.y,
		lab._field_definition.fielder_anchor_name(lab._fielder_anchor_index),
		lab._base_state.display_string(),
	]

static func _build_pitching_staff(
	lab: PitchBatLab,
	canvas: CanvasLayer
) -> void:
	lab._pitching_staff_panel = VBoxContainer.new()
	lab._pitching_staff_panel.position = Vector2(960.0, 125.0)
	lab._pitching_staff_panel.custom_minimum_size = Vector2(295.0, 0.0)
	canvas.add_child(lab._pitching_staff_panel)
	var title: Label = Label.new()
	title.text = "PITCHING STAFF — CLICK TO CHANGE"
	title.add_theme_font_size_override("font_size", 15)
	lab._pitching_staff_panel.add_child(title)
	for index in range(TeamMatchState.ROSTER_SIZE):
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(295.0, 36.0)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(lab._select_pitcher.bind(index))
		lab._pitching_staff_panel.add_child(button)
		lab._pitcher_buttons.append(button)

static func _build_pitch_release_meter(
	lab: PitchBatLab,
	canvas: CanvasLayer
) -> void:
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
		507.0 + 300.0 * PitchReleaseController.new().ideal_progress() - 2.0,
		69.0
	)
	lab._pitch_release_ideal_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(lab._pitch_release_ideal_marker)

static func _build_match_presentation(
	lab: PitchBatLab,
	canvas: CanvasLayer
) -> void:
	lab._presentation_backdrop = ColorRect.new()
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
	lab._presentation_title.add_theme_constant_override("outline_size", 8)
	lab._presentation_title.add_theme_color_override("font_outline_color", Color.BLACK)
	lab._presentation_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._presentation_backdrop.add_child(lab._presentation_title)

	lab._presentation_subtitle = Label.new()
	lab._presentation_subtitle.position = Vector2(0.0, 350.0)
	lab._presentation_subtitle.size = Vector2(1280.0, 90.0)
	lab._presentation_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._presentation_subtitle.add_theme_font_size_override("font_size", 22)
	lab._presentation_subtitle.add_theme_constant_override("outline_size", 5)
	lab._presentation_subtitle.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)
	lab._presentation_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._presentation_backdrop.add_child(lab._presentation_subtitle)
	lab._presentation_backdrop.visible = false

static func _build_event_panel(
	lab: PitchBatLab,
	canvas: CanvasLayer
) -> void:
	lab._event_panel = Panel.new()
	lab._event_panel.position = Vector2(390.0, 252.0)
	lab._event_panel.size = Vector2(500.0, 88.0)
	lab._event_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._event_panel.add_theme_stylebox_override(
		"panel",
		_make_panel_style(
			Color(0.025, 0.055, 0.085, 0.90),
			Color(0.82, 0.68, 0.24, 0.95)
		)
	)
	canvas.add_child(lab._event_panel)
	lab._status_label = Label.new()
	lab._status_label.position = Vector2(14.0, 8.0)
	lab._status_label.size = Vector2(472.0, 72.0)
	lab._status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab._status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._status_label.add_theme_font_size_override("font_size", 21)
	lab._status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lab._event_panel.add_child(lab._status_label)

static func _make_panel_style(
	background_color: Color,
	border_color: Color
) -> StyleBoxFlat:
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
		lab._pitch_release_bar.value = (
			lab._release_controller.meter_progress() * 100.0
		)

static func _build_field_setup(
	lab: PitchBatLab,
	canvas: CanvasLayer
) -> void:
	lab._field_setup_toggle_button = Button.new()
	lab._field_setup_toggle_button.position = Vector2(960.0, 322.0)
	lab._field_setup_toggle_button.custom_minimum_size = Vector2(295.0, 38.0)
	lab._field_setup_toggle_button.focus_mode = Control.FOCUS_NONE
	lab._field_setup_toggle_button.pressed.connect(lab._toggle_field_setup)
	canvas.add_child(lab._field_setup_toggle_button)

	lab._field_setup_panel = VBoxContainer.new()
	lab._field_setup_panel.position = Vector2(910.0, 365.0)
	canvas.add_child(lab._field_setup_panel)
	var title: Label = Label.new()
	title.text = "PRIMARY FIELDER POSITION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._field_setup_panel.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	lab._field_setup_panel.add_child(grid)
	for index in range(9):
		var anchor_button: Button = Button.new()
		anchor_button.custom_minimum_size = Vector2(112.0, 38.0)
		anchor_button.focus_mode = Control.FOCUS_NONE
		anchor_button.text = lab._field_definition.fielder_anchor_name(index)
		anchor_button.pressed.connect(lab._select_fielder_anchor.bind(index))
		grid.add_child(anchor_button)
		lab._field_anchor_buttons.append(anchor_button)
	var exit_button: Button = Button.new()
	exit_button.text = "RETURN TO PITCH"
	exit_button.custom_minimum_size = Vector2(336.0, 38.0)
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(lab._toggle_field_setup)
	lab._field_setup_panel.add_child(exit_button)

static func _refresh_field_setup(lab: PitchBatLab) -> void:
	if lab._field_setup_toggle_button == null or lab._field_setup_panel == null:
		return
	var on_defense: bool = (
		lab._match_mode
		and lab._match_state != null
		and lab._player_is_pitching()
	)
	lab._field_setup_toggle_button.visible = on_defense
	lab._field_setup_panel.visible = on_defense and lab._field_setup_active
	if not on_defense:
		return
	lab._field_setup_toggle_button.text = (
		"RETURN TO PITCH" if lab._field_setup_active else "FIELD VIEW / POSITION"
	)
	lab._field_setup_toggle_button.disabled = (
		lab._debug_paused
		or lab._match_state.phase != MatchState.Phase.PRE_PITCH
		or lab._release_controller.active
		or lab._ball_in_play_is_live()
		or (lab._pitch_actor != null and lab._pitch_actor.running)
	)
	for index in range(lab._field_anchor_buttons.size()):
		lab._field_anchor_buttons[index].disabled = (
			not MatchLabSupport.can_edit_pitch_plan(lab)
			or index == lab._fielder_anchor_index
		)

static func _refresh_pitching_staff(lab: PitchBatLab) -> void:
	if lab._pitching_staff_panel == null:
		return
	var should_show: bool = (
		lab._match_mode
		and lab._match_state != null
		and lab._player_is_pitching()
	)
	lab._pitching_staff_panel.visible = should_show
	if not should_show:
		return
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
		button.text = "%s   %s   %.0f%% stamina   %s" % [
			role,
			player.definition.display_name,
			player.stamina_percent() * 100.0,
			PitchExecutionModel.fatigue_stage_name(player.fatigue_ratio()),
		]
		button.disabled = not can_change or index == team.pitcher_index

static func _add_label(
	canvas: CanvasLayer,
	position: Vector2,
	font_size: int
) -> Label:
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

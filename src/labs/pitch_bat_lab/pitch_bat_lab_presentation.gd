class_name PitchBatLabPresentation
extends RefCounted

static func build_pitch_actor(lab: PitchBatLab) -> void:
	lab._pitch_actor = PitchFlightActor.new()
	lab._pitch_actor.name = "PitchFlightActor"
	lab._pitch_actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab._pitch_actor.trace_every_substeps = 2
	lab._pitch_actor.trace_sampled.connect(lab._on_trace_sampled)
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

	var pitcher_mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.31
	capsule.height = 1.72
	pitcher_mesh.mesh = capsule
	pitcher_mesh.position.y = 0.86
	pitcher_mesh.material_override = _make_material(Color(0.92, 0.30, 0.18))
	lab._pitcher_marker.add_child(pitcher_mesh)

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

	lab._scoreboard_label = _add_label(canvas, Vector2(20.0, 16.0), 19)
	lab._action_label = _add_label(canvas, Vector2(20.0, 130.0), 18)
	lab._config_label = _add_label(canvas, Vector2(20.0, 175.0), 15)
	lab._status_label = _add_label(canvas, Vector2(20.0, 290.0), 18)
	lab._status_label.text = "Loading Pitch Lab..."
	lab._live_label = _add_label(canvas, Vector2(20.0, 405.0), 16)
	lab._controls_label = _add_label(canvas, Vector2(20.0, 550.0), 14)
	_build_pitching_staff(lab, canvas)

	var footer: Label = _add_label(canvas, Vector2(20.0, 680.0), 13)
	footer.text = "Phase 3 match simulator + shared mechanics lab. F1 overlay, F2 mode."
	refresh_controls(lab)

static func cycle_camera(lab: PitchBatLab) -> void:
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
		lab._camera_mode = 0 if lab._player_is_batting() else 1
	else:
		lab._camera_mode = 0
	apply_camera_mode(lab)

static func refresh(lab: PitchBatLab) -> void:
	if (
		lab._config_label == null
		or lab._scoreboard_label == null
		or lab._action_label == null
	):
		return
	var pitch: PitchDefinition = lab._selected_pitch()
	if lab._match_mode and lab._match_state != null:
		_refresh_match(lab, pitch)
	else:
		_refresh_lab(lab, pitch)
	_refresh_pitching_staff(lab)
	lab._action_label.visible = lab._match_mode
	lab._config_label.visible = lab._debug_overlay_visible
	lab._live_label.visible = lab._debug_overlay_visible
	lab._trajectory_draw.visible = lab._debug_overlay_visible
	lab._contact_vector_draw.visible = lab._debug_overlay_visible
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
			"F1 debug   F2 Lab   F3 records   P pause   V camera   R new match\n"
			+ "BATTING: mouse tracks aim   left click Contact   right click Power\n"
			+ "WASD/left stick aim   Z/A Contact   X/X Power\n"
			+ "PITCHING: 1–9 Pitch   arrows/right stick aim   -/= effort\n"
			+ "hold/release SPACE/A   click staff to change Pitcher   F Fielder   C position"
		)
	else:
		lab._controls_label.text = (
			"F1 overlay   F2 Match   F3 records   P pause   1–9 Pitch   SPACE throw\n"
			+ "arrows target   mouse/WASD bat aim   click or Z/X swing   V camera\n"
			+ ",/. execution   [/] fatigue   C fielder   G bases   B BIP diagnostic   R reset"
		)

static func contact_outcome_name(outcome: int) -> String:
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
	var batter_state: PlayerMatchState = match_state.batter()
	var on_deck_state: PlayerMatchState = match_state.on_deck_batter()
	var pitcher_state: PlayerMatchState = match_state.pitcher()
	var fielder_state: PlayerMatchState = match_state.fielder()
	lab._scoreboard_label.visible = true
	lab._scoreboard_label.text = (
		"%s     %s\n"
		+ "BALLS %d   STRIKES %d   OUTS %d     %s\n"
		+ "BAT %s   ON DECK %s\n"
		+ "PIT %s   PITCHES %d   STAMINA %.0f%%   %s"
	) % [
		match_state.half_label(),
		match_state.score_label(),
		match_state.balls,
		match_state.strikes,
		match_state.outs,
		lab._base_state.display_string(),
		batter_state.definition.display_name,
		on_deck_state.definition.display_name,
		pitcher_state.definition.display_name,
		pitcher_state.pitch_count,
		pitcher_state.stamina_percent() * 100.0,
		PitchExecutionModel.fatigue_stage_name(pitcher_state.fatigue_ratio()),
	]
	var options: Array[PitchDefinition] = lab._current_pitch_options()
	if lab._debug_paused:
		lab._action_label.text = "DEBUG PAUSED     P: resume"
	elif lab._player_is_batting():
		var cadence_text: String = "SPACE: begin at-bat"
		if (
			lab._at_bat_cadence != null
			and lab._at_bat_cadence.state
			== AtBatCadenceController.State.DELIVERY
		):
			cadence_text = lab._at_bat_cadence.delivery_cue()
		elif lab._pitch_actor != null and lab._pitch_actor.running:
			cadence_text = "TRACK THE BALL"
		lab._action_label.text = (
			"%s     LEFT CLICK CONTACT     RIGHT CLICK POWER     %s Contact %d"
		) % [
			cadence_text,
			batter_state.definition.display_name,
			batter_state.definition.contact,
		]
	else:
		var release_text: String = PitchBatLabFeelSupport.release_meter_text(lab)
		lab._action_label.text = (
			release_text
			if not release_text.is_empty()
			else "%d: %s   EFFORT %.0f%%   TARGET %.2f / %.2f   hold SPACE to deliver" % [
				lab._selected_pitch_index + 1,
				pitch.display_name if pitch != null else "None",
				lab._pitch_effort * 100.0,
				lab._pitch_target.x,
				lab._pitch_target.y,
			]
		)
	var applied_fatigue: float = maxf(
		pitcher_state.fatigue_ratio(),
		lab._fatigue
	)
	lab._config_label.text = (
		"DEBUG   %s   match %.1f s\n"
		+ "pitch %d/%d %s   effort %.0f%%   target %.2f / %.2f\n"
		+ "bat aim %.2f / %.2f   fatigue %.0f%% → effect %.0f%% %s\n"
		+ "fielder %s: %s   anchor %s   records %d"
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
		fielder_state.definition.display_name,
		str(fielder_state.definition.fielding),
		lab._field_definition.fielder_anchor_name(lab._fielder_anchor_index),
		lab._play_records.size(),
	]

static func _refresh_lab(lab: PitchBatLab, pitch: PitchDefinition) -> void:
	lab._scoreboard_label.visible = false
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
		lab._match_state.can_change_defense() and not lab._debug_paused
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

static func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

static func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

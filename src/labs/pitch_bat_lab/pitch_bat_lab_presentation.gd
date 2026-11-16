class_name PitchBatLabPresentation
extends RefCounted

const HUD_ANCHOR_BOTTOM_RIGHT: int = 0
const HUD_ANCHOR_TOP_LEFT: int = 1
const HUD_ANCHOR_TOP_RIGHT: int = 2
const HUD_ANCHOR_COUNT: int = 3
const VIEWPORT_SIZE: Vector2 = Vector2(1280.0, 720.0)
const HUD_MARGIN: float = 12.0
const ROUTINE_EVENT_HEIGHT: float = 44.0

const Operations1: GDScript = preload(
	"res://src/labs/pitch_bat_lab/pitch_bat_lab_presentation_operations_1.gd"
)


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
	lab._trajectory_draw.material_override = _make_unshaded_material(Color(1.0, 0.72, 0.12))
	lab.add_child(lab._trajectory_draw)

	lab._contact_vector_draw = TrajectoryDebugDraw.new()
	lab._contact_vector_draw.name = "ContactVector"
	lab._contact_vector_draw.material_override = _make_unshaded_material(Color(0.25, 0.90, 1.0))
	lab.add_child(lab._contact_vector_draw)


static func build_defenders(lab: PitchBatLab) -> void:
	lab._primary_fielder = FielderController.new()
	lab._primary_fielder.name = "PrimaryFielder"
	lab._primary_fielder.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab.add_child(lab._primary_fielder)
	lab._primary_fielder.set_anchor(lab._field_definition.fielder_anchor(lab._fielder_anchor_index))
	lab._primary_fielder.set_pitcher_lane(lab.MOUND_ORIGIN.z)

	lab._pitcher_marker = Node3D.new()
	lab._pitcher_marker.name = "PitcherDefender"
	lab._pitcher_marker.position = lab.MOUND_ORIGIN
	lab.add_child(lab._pitcher_marker)
	lab._primary_fielder.pitcher_defender = lab._pitcher_marker

	lab._pitcher_avatar = PlayerAvatar.new()
	lab._pitcher_avatar.name = "PitcherAvatar"
	lab._pitcher_marker.add_child(lab._pitcher_avatar)
	lab._pitcher_avatar.configure(PlayerAvatar.Role.PITCHER, false, false, Color(0.92, 0.30, 0.18))

	lab._batter_avatar = PlayerAvatar.new()
	lab._batter_avatar.name = "BatterAvatar"
	lab._batter_avatar.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab.add_child(lab._batter_avatar)
	lab._batter_avatar.configure(PlayerAvatar.Role.BATTER, false, false, Color(0.94, 0.78, 0.18))

	lab._bat_actor = BatActor.new()
	lab._bat_actor.name = "BatActor"
	lab._bat_actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	lab.add_child(lab._bat_actor)


static func sync_players(lab: PitchBatLab) -> void:
	if lab._match_state == null:
		return
	var batter: PlayerDefinition = lab._match_state.batter().definition
	var pitcher: PlayerDefinition = lab._match_state.pitcher().definition
	var fielder: PlayerDefinition = lab._match_state.fielder().definition
	var batter_left: bool = lab._match_state.batter().bats_left()
	if lab._batter_avatar != null:
		var batter_position: Vector3 = Vector3(-0.82 if batter_left else 0.82, 0.0, 0.34)
		lab._batter_avatar.configure(
			PlayerAvatar.Role.BATTER,
			batter_left,
			batter.throws == PlayerDefinition.Handedness.LEFT,
			Color(0.94, 0.78, 0.18)
		)
		lab._batter_avatar.position = batter_position
		if lab._bat_actor != null:
			lab._bat_actor.configure(batter_left, batter_position)
			lab._bat_actor.set_cosmetic(String(batter.season_gear.get("bat", "")))
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


static func play_batter_swing(lab: PitchBatLab, profile: SwingProfileDefinition) -> void:
	if lab._bat_actor != null:
		var cosmetic: String = ""
		if lab._match_mode and lab._match_state != null:
			cosmetic = String(lab._match_state.batter().definition.season_gear.get("bat", ""))
		lab._bat_actor.set_cosmetic(cosmetic)
		lab._bat_actor.play_swing(profile)
	if lab._batter_avatar != null:
		lab._batter_avatar.play_batting_swing(profile)


static func show_pitcher_fielding_attempt(
	lab: PitchBatLab, ball_position: Vector3, outcome: FieldingResolver.Outcome
) -> void:
	if lab._pitcher_marker == null:
		return
	if lab.hillside_pitcher_motion != null and not lab.hillside_pitcher_motion.guard_pitcher(lab):
		return
	var offset: Vector3 = ball_position - lab._pitcher_marker.global_position
	offset.y = 0.0
	if offset.length_squared() > 0.0001:
		offset = offset.normalized() * minf(0.72, offset.length())
	var next: Vector3
	if lab.hillside_pitcher_motion != null:
		var target: Vector3 = StadiumHillsideTerrain.point(
			lab._pitcher_marker.global_position.x + offset.x,
			lab._pitcher_marker.global_position.z + offset.z,
			lab.hillside_pitcher_motion.profile
		)
		next = StadiumPropertyRuntime.pitcher_step(
			lab, target, offset.length(), lab._pitcher_marker.global_position
		)
	else:
		next = DefenderSpacing.step_around_mound(
			lab._pitcher_marker.global_position,
			lab._pitcher_marker.global_position + offset,
			lab._primary_fielder.global_position,
			offset.length()
		)
		# The presentation lunge must respect the same Pool/fence swept clearance.
		if StadiumPoolOwnedExtension.current(lab) != null:
			next = StadiumPropertyRuntime.pitcher_step(
				lab, lab._pitcher_marker.global_position + offset, offset.length(), next
			)
	lab._pitcher_marker.global_position = next
	if lab.hillside_pitcher_motion != null:
		if not lab.hillside_pitcher_motion.blocked:
			lab.hillside_pitcher_motion.set_pitcher_rotation(
				(
					(0.18 if outcome == FieldingResolver.Outcome.CLEAN else 0.10)
					* signf(offset.x if absf(offset.x) > 0.01 else 1.0)
				)
			)
	else:
		lab._pitcher_marker.rotation.z = (
			(0.18 if outcome == FieldingResolver.Outcome.CLEAN else 0.10)
			* signf(offset.x if absf(offset.x) > 0.01 else 1.0)
		)


static func build_environment(lab: PitchBatLab) -> void:
	var geometry: StarterFieldLabGeometry = StarterFieldLabGeometry.new()
	geometry.name = "StarterFieldGeometry"
	lab.add_child(geometry)
	var contact_profile: SwingProfileDefinition = ContentDB.get_swing(lab.CONTACT_SWING_ID)
	var power_profile: SwingProfileDefinition = ContentDB.get_swing(lab.POWER_SWING_ID)
	geometry.build(
		lab._field_definition,
		lab.MOUND_ORIGIN,
		lab.ZONE_MIN_X,
		lab.ZONE_MAX_X,
		lab.ZONE_MIN_Y,
		lab.ZONE_MAX_Y,
		Vector2(contact_profile.contact_radius_x_m * 2.0, contact_profile.contact_radius_y_m * 2.0),
		Vector2(power_profile.contact_radius_x_m * 2.0, power_profile.contact_radius_y_m * 2.0)
	)
	if lab._field_definition.environment_style == 1:
		CommonsParkScenery.build(geometry, lab._field_definition)
	lab._pitch_target_marker = geometry.pitch_target_marker
	lab._batting_aim_marker = geometry.batting_aim_marker
	lab._receiver_marker = geometry.receiver_marker
	_build_world_environment(lab)

	lab._camera = Camera3D.new()
	lab._camera.name = "LabCamera"
	lab._camera.current = true
	lab._camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	lab.add_child(lab._camera)
	lab._camera_director = MatchCameraDirector.new()
	lab._camera_director.tracking_visibility.configure(geometry)
	apply_camera_mode(lab)
	lab._camera_director.snap(lab._camera)


static func build_ui(lab: PitchBatLab) -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "DebugUI"
	lab.add_child(canvas)

	lab._scorebug = MatchScorebug.new()
	canvas.add_child(lab._scorebug)
	lab._pitch_feedback = PitchFeedback.new()
	canvas.add_child(lab._pitch_feedback)
	_build_pitch_release_meter(lab, canvas)
	lab._action_label = _add_label(canvas, Vector2(460.0, 14.0), 14)
	lab._action_label.size = Vector2(360.0, 30.0)
	lab._action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._config_label = _add_label(canvas, Vector2(20.0, 154.0), 13)
	lab._config_label.size = Vector2(350.0, 150.0)
	lab._config_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_event_panel(lab, canvas)
	apply_hud_anchor(lab)
	lab._status_label.text = "Loading Pitch Lab..."
	lab._live_label = _add_label(canvas, Vector2(20.0, 315.0), 13)
	lab._live_label.size = Vector2(350.0, 130.0)
	lab._live_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab._controls_label = _add_label(canvas, Vector2(20.0, 624.0), 13)
	lab._controls_label.size = Vector2(930.0, 44.0)
	_build_pitching_staff(lab, canvas)
	_build_field_setup(lab, canvas)
	_build_display_menu(lab, canvas)
	lab._pitch_picker = PitchPicker.new()
	canvas.add_child(lab._pitch_picker)
	lab._pitch_picker.build(lab)
	apply_hud_anchor(lab)
	_build_match_presentation(lab, canvas)
	var controls_theme: Theme = ClubhouseTheme.create()
	controls_theme.default_font_size = 16
	for child in canvas.get_children():
		if child is BaseButton:
			child.theme = controls_theme
	refresh_controls(lab)
	refresh_display_menu(lab)


static func _build_world_environment(lab: PitchBatLab) -> void:
	lab._world_environment = WorldEnvironment.new()
	lab._world_environment.name = "LabWorldEnvironment"
	var environment: Environment = Environment.new()
	environment.background_mode = (
		Environment.BG_SKY if lab._sky_backdrop_enabled else Environment.BG_COLOR
	)
	environment.background_color = Color(0.12, 0.20, 0.15)
	if lab._automation != null:
		# Non-rendering jobs do not need sky/radiance textures or their deferred uploads.
		environment.background_mode = Environment.BG_COLOR
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.63, 0.79, 0.88)
		environment.ambient_light_energy = 0.58
		environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		lab._world_environment.environment = environment
		lab.add_child(lab._world_environment)
		return
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.17, 0.43, 0.68)
	sky_material.sky_horizon_color = Color(0.63, 0.79, 0.88)
	sky_material.ground_horizon_color = Color(0.46, 0.57, 0.48)
	sky_material.ground_bottom_color = Color(0.16, 0.22, 0.18)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.58
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	lab._world_environment.environment = environment
	lab.add_child(lab._world_environment)


static func toggle_sky_backdrop(lab: PitchBatLab) -> void:
	if lab._world_environment == null or lab._world_environment.environment == null:
		return
	lab._sky_backdrop_enabled = not lab._sky_backdrop_enabled
	if lab._sky_backdrop_enabled:
		lab._world_environment.environment.background_mode = Environment.BG_SKY
	else:
		lab._world_environment.environment.background_mode = Environment.BG_COLOR
	PitchBatLabSettings.save(lab)
	refresh_display_menu(lab)


static func cycle_hud_anchor(lab: PitchBatLab) -> void:
	lab._hud_anchor_index = (lab._hud_anchor_index + 1) % HUD_ANCHOR_COUNT
	apply_hud_anchor(lab)
	refresh_event(lab)
	PitchBatLabSettings.save(lab)
	refresh_display_menu(lab)


static func apply_hud_anchor(lab: PitchBatLab) -> void:
	if lab._scorebug == null:
		return
	match lab._hud_anchor_index:
		HUD_ANCHOR_TOP_LEFT:
			lab._scorebug.position = Vector2(HUD_MARGIN, HUD_MARGIN)
		HUD_ANCHOR_TOP_RIGHT:
			lab._scorebug.position = Vector2(
				VIEWPORT_SIZE.x - MatchScorebug.PANEL_SIZE.x - HUD_MARGIN, HUD_MARGIN
			)
		_:
			lab._scorebug.position = Vector2(
				VIEWPORT_SIZE.x - MatchScorebug.PANEL_SIZE.x - HUD_MARGIN,
				VIEWPORT_SIZE.y - MatchScorebug.PANEL_SIZE.y - ROUTINE_EVENT_HEIGHT - HUD_MARGIN
			)
	if lab._pitching_staff_toggle_button != null:
		var menu_y: float = 204.0 if lab._hud_anchor_index == HUD_ANCHOR_TOP_RIGHT else 16.0
		lab._pitching_staff_toggle_button.position.y = menu_y
		lab._field_setup_toggle_button.position.y = menu_y + 46.0
		lab._pitching_staff_panel.position.y = menu_y + 112.0
		lab._field_setup_panel.position.y = menu_y + 112.0
	var debug_offset: float = 20.0 if lab._hud_anchor_index == HUD_ANCHOR_TOP_LEFT else 0.0
	if lab._config_label != null:
		lab._config_label.position.y = 154.0 + debug_offset
	if lab._live_label != null:
		lab._live_label.position.y = 315.0 + debug_offset


static func show_match_intro(lab: PitchBatLab) -> void:
	if lab._presentation_backdrop == null:
		return
	lab._presentation_backdrop.visible = true
	lab._presentation_title.text = "GAME START"
	lab._presentation_subtitle.text = (
		"%s at %s\n%s"
		% [
			lab._match_state.away_team.display_name,
			lab._match_state.home_team.display_name,
			lab._field_definition.display_name,
		]
	)
	_set_gameplay_hud_visible(lab, false)


static func show_match_outro(lab: PitchBatLab, player_won: bool) -> void:
	if lab._presentation_backdrop == null or lab._match_state == null:
		return
	lab._presentation_backdrop.visible = true
	lab._presentation_title.text = "WIN" if player_won else "LOSS"
	lab._presentation_subtitle.text = (
		"%s\n%s"
		% [
			lab._match_state.score_label(),
			"CLICK / SPACE: CONTINUE" if lab._managed_match else "R: NEW MATCH"
		]
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
	if lab._pitch_picker != null and not visible:
		lab._pitch_picker.visible = false
	if lab._controls_label != null:
		lab._controls_label.visible = visible
	if lab._config_label != null:
		lab._config_label.visible = false
	if lab._live_label != null:
		lab._live_label.visible = false
	if lab._event_panel != null:
		lab._event_panel.visible = false
	if lab._hr_celebration_label != null:
		lab._hr_celebration_label.visible = false
	if lab._pitching_staff_panel != null:
		lab._pitching_staff_panel.visible = false
	if lab._pitching_staff_toggle_button != null:
		lab._pitching_staff_toggle_button.visible = false
	if lab._field_setup_toggle_button != null:
		lab._field_setup_toggle_button.visible = false
	if lab._field_setup_panel != null:
		lab._field_setup_panel.visible = false
	if lab._pitch_release_bar != null:
		lab._pitch_release_bar.visible = false
	if lab._pitch_release_ideal_marker != null:
		lab._pitch_release_ideal_marker.visible = false
	if lab._display_menu_button != null:
		lab._display_menu_button.visible = visible
	if lab._display_menu_panel != null:
		lab._display_menu_panel.visible = visible and lab._display_menu_open
	if lab._trajectory_draw != null:
		lab._trajectory_draw.visible = false
	if lab._contact_vector_draw != null:
		lab._contact_vector_draw.visible = false
	if lab._receiver_marker != null:
		lab._receiver_marker.visible = false


static func refresh_event(lab: PitchBatLab) -> void:
	# Clear first, including hidden UI, empty status and changed-play early returns.
	if lab._hr_celebration_label != null:
		lab._hr_celebration_label.visible = false
		lab._hr_celebration_label.text = ""
	if not MatchAutomation.presented(lab):
		return
	if lab._event_panel == null or lab._status_label == null:
		return
	var event_text: String = lab._status_label.text.strip_edges()
	lab._event_panel.visible = not event_text.is_empty()
	if event_text.is_empty():
		return
	# Keep the compact scored HR status while a brief headline celebrates the result.
	# Keep the complete status payload; only its presentation has a short lifetime.
	lab._event_panel.modulate.a = 1.0
	lab._status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab._status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var hr_notice: bool = lab._home_run.compact_notice(lab, event_text)
	_refresh_hr_celebration(lab, hr_notice)
	var routine: bool = _event_is_routine(event_text)
	if hr_notice:
		var extent: Vector2 = lab.get_viewport().get_visible_rect().size
		var notice_size: Vector2 = Vector2(clampf(extent.x - HUD_MARGIN * 2.0, 1.0, 300.0), 88.0)
		var right_side: bool = lab._hud_anchor_index == HUD_ANCHOR_TOP_LEFT
		lab._event_panel.position = Vector2(
			extent.x - notice_size.x - HUD_MARGIN if right_side else HUD_MARGIN, HUD_MARGIN
		)
		lab._event_panel.size = notice_size
		lab._status_label.position = Vector2.ZERO
		lab._status_label.size = notice_size
		lab._event_panel.visible = lab._home_run.elapsed < PitchBatLabHomeRun.NOTICE_SECONDS
		lab._event_panel.modulate.a = minf(
			smoothstep(0.0, PitchBatLabHomeRun.NOTICE_FADE_IN_SECONDS, lab._home_run.elapsed),
			smoothstep(
				0.0,
				PitchBatLabHomeRun.NOTICE_FADE_OUT_SECONDS,
				PitchBatLabHomeRun.NOTICE_SECONDS - lab._home_run.elapsed
			)
		)
	elif routine:
		lab._event_panel.position = Vector2(
			lab._scorebug.position.x, lab._scorebug.position.y + MatchScorebug.PANEL_SIZE.y + 2.0
		)
		lab._event_panel.size = Vector2(MatchScorebug.PANEL_SIZE.x, ROUTINE_EVENT_HEIGHT)
		lab._status_label.position = Vector2.ZERO
		lab._status_label.size = lab._event_panel.size
	else:
		lab._event_panel.position = Vector2(320.0, 210.0)
		lab._event_panel.size = Vector2(640.0, 142.0)
		lab._status_label.position = Vector2(8.0, 4.0)
		lab._status_label.size = Vector2(624.0, 134.0)
	var event_font_size: int = 18 if event_text.contains("Tag + margin / return") else 26
	lab._status_label.add_theme_font_size_override(
		"font_size", 14 if hr_notice else (12 if routine else event_font_size)
	)
	lab._status_label.add_theme_constant_override("outline_size", 3 if routine or hr_notice else 5)
	lab._status_label.add_theme_color_override(
		"font_outline_color", Color(0.025, 0.055, 0.085, 1.0)
	)
	lab._status_label.add_theme_constant_override(
		"shadow_offset_x", 0 if routine or hr_notice else 4
	)
	lab._status_label.add_theme_constant_override(
		"shadow_offset_y", 0 if routine or hr_notice else 4
	)
	lab._status_label.add_theme_color_override(
		"font_shadow_color", Color(0.025, 0.055, 0.085, 0.0 if routine or hr_notice else 0.85)
	)


static func _refresh_hr_celebration(lab: PitchBatLab, hr_notice: bool) -> void:
	var headline: Label = lab._hr_celebration_label
	var hr: PitchBatLabHomeRun = lab._home_run
	if (
		headline == null
		or not hr_notice
		or not hr.presentation_pending(lab)
		or hr.celebration_text.is_empty()
		or hr.elapsed >= PitchBatLabHomeRun.CELEBRATION_SECONDS
	):
		return
	var extent: Vector2 = lab.get_viewport().get_visible_rect().size
	headline.add_theme_font_size_override(
		"font_size", int(clampf(extent.x / 1280.0 * 88.0, 24.0, 88.0))
	)
	headline.text = hr.celebration_text
	# Keep the existing type and fade, but leave the central flight corridor clear.
	var minimum: Vector2 = headline.get_combined_minimum_size()
	headline.size = Vector2(maxf(extent.x, minimum.x), maxf(112.0, minimum.y))
	headline.position = Vector2(
		(extent.x - headline.size.x) * 0.5,
		clampf(extent.y * 0.125, 0.0, maxf(0.0, extent.y - headline.size.y))
	)
	headline.modulate.a = minf(
		smoothstep(0.0, PitchBatLabHomeRun.CELEBRATION_FADE_IN_SECONDS, hr.elapsed),
		smoothstep(
			0.0,
			PitchBatLabHomeRun.CELEBRATION_FADE_OUT_SECONDS,
			PitchBatLabHomeRun.CELEBRATION_SECONDS - hr.elapsed
		)
	)
	headline.visible = true


static func _event_is_routine(event_text: String) -> bool:
	var headline: String = event_text.get_slice("\n", 0).to_upper()
	return (
		not headline.contains("OUT")
		and (
			headline.begins_with("FILM ROOM")
			or headline.begins_with("BALL")
			or headline.begins_with("CALLED STRIKE")
			or headline.begins_with("SWINGING STRIKE")
			or headline.begins_with("STRIKE")
			or headline.begins_with("FOUL")
		)
	)


static func cycle_camera(lab: PitchBatLab) -> void:
	if lab._debug_paused:
		lab._camera_director.cycle_paused_view()
		return
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
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)


static func apply_role_camera(lab: PitchBatLab) -> void:
	if lab._camera == null:
		return
	if lab._match_mode:
		if lab._field_setup_active:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.FIELD_SETUP)
			return
		if lab._pitching_staff_active:
			lab._camera_director.set_shot(MatchCameraDirector.Shot.PITCHING_STAFF)
			return
		lab._camera_mode = 0 if lab._player_is_batting() else 1
	else:
		lab._camera_mode = 0
	apply_camera_mode(lab)


static func refresh(lab: PitchBatLab) -> void:
	if not MatchAutomation.presented(lab):
		return
	if lab._config_label == null or lab._scorebug == null or lab._action_label == null:
		return
	var pitch: PitchDefinition = lab._selected_pitch()
	if lab._match_mode and lab._match_state != null:
		_refresh_match(lab, pitch)
	else:
		_refresh_lab(lab, pitch)
	_refresh_pitching_staff(lab)
	_refresh_field_setup(lab)
	_refresh_pitch_release_meter(lab)
	lab._action_label.visible = (
		lab._match_mode
		and lab._player_is_pitching()
		and not lab._field_setup_active
		and not lab._pitching_staff_active
	)
	lab._controls_label.visible = true
	lab._config_label.visible = lab._debug_overlay_visible
	lab._live_label.visible = lab._debug_overlay_visible
	lab._trajectory_draw.visible = lab._debug_overlay_visible
	lab._contact_vector_draw.visible = lab._debug_overlay_visible
	if lab._receiver_marker != null:
		lab._receiver_marker.visible = lab._debug_overlay_visible
	refresh_event(lab)
	refresh_controls(lab)
	if lab._pitch_picker != null:
		lab._pitch_picker.refresh()
		if lab._pitch_picker.visible:
			lab._action_label.visible = false
	if lab._match_presentation_director.blocks_gameplay():
		_set_gameplay_hud_visible(lab, false)
	refresh_display_menu(lab)
	if lab._debug_paused:
		lab._event_panel.visible = false


static func refresh_markers(lab: PitchBatLab) -> void:
	if not _refresh_markers_prefix(lab):
		return
	StadiumPropertyRuntime.refresh_receiver_visibility(lab)
	_refresh_markers_suffix(lab)


static func refresh_ac02_setup_markers(lab: PitchBatLab) -> Dictionary:
	if not _refresh_markers_prefix(lab):
		return {"admitted": false, "reason": "marker-prefix-incomplete"}
	var result: Dictionary = StadiumNpcAc02SetupAdmission.refresh_receiver(lab)
	_refresh_markers_suffix(lab)
	return result


static func _refresh_markers_prefix(lab: PitchBatLab) -> bool:
	var geometry: StarterFieldLabGeometry = lab.get_node_or_null("StarterFieldGeometry")
	if geometry != null:
		geometry.set_batting_view(not lab._match_mode or lab._player_is_batting())
	# AC02's issued guide guard checks the actual target pose. Ordinary aim writers update
	# _pitch_target first, so publish that pose to the captured genuine marker before callback.
	var public: StadiumNpcPublicProperty = StadiumNpcPublicRuntime._property(lab)
	if public != null and public.venue_id == "AC-02" and geometry != null:
		var guides: StadiumNpcAc02PublicGuides = public._ac02_guides_pin
		if (
			is_instance_valid(guides)
			and guides == public.ac02_guides
			and guides.get_script() == StadiumNpcAc02PublicGuides
			and guides._guides.size() == 5
		):
			var row: Dictionary = guides._guides[4]
			var marker: MeshInstance3D = (
				row.node.get_ref() as MeshInstance3D if row.get("node") is WeakRef else null
			)
			if (
				is_instance_valid(marker)
				and not row.get("bar", true)
				and marker == lab._pitch_target_marker
				and marker == geometry.pitch_target_marker
				and geometry.get_node_or_null("PitchTarget") == marker
				and marker.get_parent() == geometry
				and marker.mesh == row.get("mesh")
				and marker.material_override == row.get("material")
			):
				marker.position = Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.015)

	return true


static func _refresh_markers_suffix(lab: PitchBatLab) -> void:
	if lab._pitch_target_marker != null:
		lab._pitch_target_marker.position = Vector3(lab._pitch_target.x, lab._pitch_target.y, 0.015)
		lab._pitch_target_marker.visible = (not lab._match_mode or lab._player_is_pitching())
	if lab._batting_aim_marker != null:
		lab._batting_aim_marker.position = Vector3(lab._batting_aim.x, lab._batting_aim.y, -0.015)
		lab._batting_aim_marker.visible = (not lab._match_mode or lab._player_is_batting())
		var contact_factor: float = 1.0
		if lab._match_mode and lab._match_state != null:
			contact_factor = lerpf(
				0.82, 1.18, float(lab._match_state.batter().definition.contact) / 10.0
			)
		lab._batting_aim_marker.scale = Vector3(contact_factor, contact_factor, 1.0)
		MatchSponsorControls.refresh_ellipse(lab)
	var normalized_batting_aim: Vector2 = Vector2(
		inverse_lerp(lab.BATTING_AIM_MIN_X, lab.BATTING_AIM_MAX_X, lab._batting_aim.x) * 2.0 - 1.0,
		inverse_lerp(lab.BATTING_AIM_MIN_Y, lab.BATTING_AIM_MAX_Y, lab._batting_aim.y) * 2.0 - 1.0
	)
	if lab._bat_actor != null:
		lab._bat_actor.set_aim_pose(normalized_batting_aim)
	if lab._batter_avatar != null:
		lab._batter_avatar.set_batting_aim_pose(normalized_batting_aim)


static func refresh_controls(lab: PitchBatLab) -> void:
	if lab._controls_label == null:
		return
	if lab._match_mode:
		lab._controls_label.text = (
			"F1 DEBUG   F2 LAB   F3 RECORDS   Esc PAUSE   V CAMERA\n"
			+ "BAT: pointer + click Contact/Power • T timeout before windup   •   "
			+ "PITCH: aim + hold/release"
		)
	else:
		lab._controls_label.text = (
			"F1 OVERLAY   F2 RESUME MATCH   F3 RECORDS   Esc PAUSE   V CAMERA   R RESET\n"
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
	lab._scorebug.refresh(match_state, not lab._player_is_pitching())
	var options: Array[PitchDefinition] = lab._current_pitch_options()
	lab._action_label.text = (
		(
			"%d  %s"
			% [
				lab._selected_pitch_index + 1,
				pitch.display_name if pitch != null else "None",
			]
		)
		if lab._player_is_pitching()
		else ""
	)
	var applied_fatigue: float = maxf(pitcher_state.fatigue_ratio(), lab._fatigue)
	lab._config_label.text = (
		(
			"DEBUG • %s • %.1f s\n"
			+ "Pitch %d/%d %s • effort %.0f%%\n"
			+ "target %.2f / %.2f • bat %.2f / %.2f\n"
			+ "fatigue %.0f%% → %.0f%% %s • overcook %.0f%%\n"
			+ "fielder %s %s • %s • records %d\n"
			+ "AI read %.0f%% • %s • on deck %s"
		)
		% [
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
	)


static func _refresh_lab(lab: PitchBatLab, pitch: PitchDefinition) -> void:
	lab._scorebug.visible = false
	lab._config_label.text = (
		(
			"MECHANICS LAB   PITCH %d/%d  %s   effort %.0f%%\n"
			+ "target x %.2f / y %.2f   execution %.0f%%   fatigue %.0f%% → effect %.0f%%\n"
			+ "bat aim x %.2f / y %.2f\n"
			+ "fielder %s   %s"
		)
		% [
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
	)


static func _build_pitching_staff(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	Operations1._build_pitching_staff(lab, canvas)


static func _inspect_pitcher(lab: PitchBatLab, index: int, button: Button) -> void:
	Operations1._inspect_pitcher(lab, index, button)


static func _build_pitch_release_meter(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	Operations1._build_pitch_release_meter(lab, canvas)


static func _build_display_menu(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	lab._display_menu_button = Button.new()
	lab._display_menu_button.text = "PAUSE  Esc"
	lab._display_menu_button.position = Vector2(10.0, 684.0)
	lab._display_menu_button.size = Vector2(132.0, 26.0)
	lab._display_menu_button.focus_mode = Control.FOCUS_NONE
	lab._display_menu_button.add_theme_font_size_override("font_size", 12)
	lab._display_menu_button.pressed.connect(
		func() -> void: PitchBatLabFeelSupport.toggle_debug_pause(lab)
	)
	canvas.add_child(lab._display_menu_button)
	lab._pause_menu = PitchBatLabPauseMenu.new()
	canvas.add_child(lab._pause_menu)
	lab._pause_menu.build(lab)


static func refresh_display_menu(lab: PitchBatLab) -> void:
	Operations1._public_refresh_display_menu(lab)


static func _build_match_presentation(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	Operations1._build_match_presentation(lab, canvas)


static func _build_event_panel(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	Operations1._build_event_panel(lab, canvas)


static func _make_panel_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	return Operations1._make_panel_style(background_color, border_color)


static func _refresh_pitch_release_meter(lab: PitchBatLab) -> void:
	Operations1._refresh_pitch_release_meter(lab)


static func _build_field_setup(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	Operations1._build_field_setup(lab, canvas)


static func _refresh_field_setup(lab: PitchBatLab) -> void:
	Operations1._refresh_field_setup(lab)


static func _refresh_pitching_staff(lab: PitchBatLab) -> void:
	Operations1._refresh_pitching_staff(lab)


static func _add_label(canvas: CanvasLayer, position: Vector2, font_size: int) -> Label:
	return Operations1._add_label(canvas, position, font_size)


static func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	return Operations1._make_unshaded_material(color)

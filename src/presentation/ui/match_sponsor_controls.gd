class_name MatchSponsorControls
extends Node
## Working Optics choice; no pitch information enters the selection.

var _lab: PitchBatLab
var _choice: Button


func build(lab: PitchBatLab, canvas: CanvasLayer) -> void:
	_lab = lab
	_choice = Button.new()
	_choice.name = "OpticsChoice"
	_choice.theme = ClubhouseTheme.create()
	_choice.position = Vector2(420, 464)
	_choice.custom_minimum_size = Vector2(440, 52)
	_choice.focus_mode = Control.FOCUS_ALL
	_choice.pressed.connect(_choose)
	_choice.tooltip_text = "Choose before confirming this at-bat. Contact only; Power unchanged."
	canvas.add_child(_choice)
	_choice.hide()
	_build_ellipse()


static func can_choose(lab: PitchBatLab) -> bool:
	return (
		lab._match_mode
		and lab._match_state != null
		and lab._player_is_batting()
		and lab._match_state.batter().definition.season_sponsors.get("F03", false)
		and lab._awaiting_batter_confirm
		and lab._match_state.between_batters
		and not lab._ai_pitch_preselected
		and lab._match_state.phase == MatchState.Phase.PRE_PITCH
		and not lab._debug_paused
		and not lab._match_presentation_director.blocks_gameplay()
	)


func _process(_delta: float) -> void:
	_choice.visible = can_choose(_lab)
	_choice.disabled = not _choice.visible
	if _choice.visible:
		_choice.text = (
			"OPTICS: %s • click to cycle\nContact shape • locked after start"
			% (_lab._match_state.optics_mode.to_upper())
		)
	refresh_ellipse(_lab)


func _choose() -> void:
	if not can_choose(_lab):
		return
	var modes: Array[String] = ["normal", "wide", "tall"]
	var next: String = modes[(modes.find(_lab._match_state.optics_mode) + 1) % modes.size()]
	if SeasonSponsorEffects.choose_optics(_lab._match_state, next):
		_lab._refresh_config()
	_process(0.0)


func _build_ellipse() -> void:
	var outline: Node3D = Node3D.new()
	outline.name = "OpticsCoverage"
	var line: MeshInstance3D = MeshInstance3D.new()
	var mesh: ImmediateMesh = ImmediateMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.20, 0.90, 1.0, 0.82)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for index in range(65):
		var angle: float = TAU * float(index) / 64.0
		mesh.surface_add_vertex(Vector3(cos(angle), sin(angle), 0.0))
	mesh.surface_end()
	line.mesh = mesh
	line.material_override = material
	outline.add_child(line)
	_lab._batting_aim_marker.add_child(outline)
	outline.hide()


static func refresh_ellipse(lab: PitchBatLab) -> void:
	var outline: Node3D = lab._batting_aim_marker.get_node_or_null("OpticsCoverage")
	if outline == null:
		return
	var owned: bool = (
		lab._match_mode
		and lab._match_state != null
		and lab._match_state.batter().definition.season_sponsors.get("F03", false)
	)
	outline.visible = owned
	lab._batting_aim_marker.get_node("ContactCoverage").visible = not owned
	if owned:
		var profile: SwingProfileDefinition = SeasonSponsorEffects.swing(
			ContentDB.get_swing(&"swing.contact"), lab._match_state
		)
		# Parent already supplies the batter's ordinary Contact rating factor.
		outline.scale = Vector3(profile.contact_radius_x_m, profile.contact_radius_y_m, 1.0)

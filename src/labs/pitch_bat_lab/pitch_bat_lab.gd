extends Node3D

const PITCH_IDS: Array[StringName] = [
	&"pitch.overhand_four_seam",
	&"pitch.overhand_sinker",
	&"pitch.sidearm_sinker",
	&"pitch.overhand_slider",
	&"pitch.sidearm_slider",
	&"pitch.eephus",
	&"pitch.knuckleball",
	&"pitch.riser",
	&"pitch.drop",
]

const CONTACT_SWING_ID: StringName = &"swing.contact"
const POWER_SWING_ID: StringName = &"swing.power"
const BALL_SETUP_ID: StringName = &"ball_setup.fresh"

const MOUND_ORIGIN: Vector3 = Vector3(0.0, 0.0, 13.716)
const DEFAULT_TARGET: Vector2 = Vector2(0.0, 1.05)
const DEFAULT_BATTING_AIM: Vector2 = Vector2(0.0, 1.05)

const ZONE_MIN_X: float = -0.43
const ZONE_MAX_X: float = 0.43
const ZONE_MIN_Y: float = 0.55
const ZONE_MAX_Y: float = 1.55
const AIM_STEP_M: float = 0.05

var _pitch_actor: PitchFlightActor
var _trajectory_draw: TrajectoryDebugDraw
var _contact_vector_draw: TrajectoryDebugDraw
var _trajectory_points: Array[Vector3] = []

var _pitch_target_marker: MeshInstance3D
var _batting_aim_marker: MeshInstance3D
var _camera: Camera3D
var _camera_mode: int = 0

var _status_label: Label
var _live_label: Label
var _config_label: Label
var _controls_label: Label

var _selected_pitch_index: int = 0
var _pitch_target: Vector2 = DEFAULT_TARGET
var _batting_aim: Vector2 = DEFAULT_BATTING_AIM
var _execution_quality: float = 1.0
var _fatigue: float = 0.0
var _throw_number: int = 0
var _swing_consumed: bool = false

var _last_release_speed_mps: float = 0.0
var _last_expected_plate_speed_mps: float = 0.0
var _last_movement_x_m: float = 0.0
var _last_movement_y_m: float = 0.0

func _ready() -> void:
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab loaded with invalid content.")
		return

	_build_environment()
	_build_pitch_actor()
	_build_ui()
	_refresh_markers()
	_refresh_config()

	print(
		"Pitch/Bat Lab ready: %d pitch(es), %d swing profile(s)."
		% [
			ContentDB.pitch_by_id.size(),
			ContentDB.swing_by_id.size(),
		]
	)

	call_deferred("_throw_pitch")

func _process(_delta: float) -> void:
	if (
		_pitch_actor == null
		or not _pitch_actor.running
		or _pitch_actor.state == null
		or _live_label == null
	):
		return

	var state: PitchState = _pitch_actor.state
	_live_label.text = (
		"FLIGHT  t %.3f s   speed %.1f mph\n"
		+ "ball  x %.2f m   y %.2f m   z %.2f m"
	) % [
		state.elapsed_time,
		state.velocity.length() * 2.236936,
		state.position.x,
		state.position.y,
		state.position.z,
	]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode >= KEY_1 and key_event.keycode <= KEY_9:
		var requested_index: int = int(key_event.keycode - KEY_1)
		if requested_index < PITCH_IDS.size():
			_selected_pitch_index = requested_index
			_refresh_config()
			get_viewport().set_input_as_handled()
			return

	match key_event.keycode:
		KEY_SPACE:
			_throw_pitch()
		KEY_R:
			_reset_lab()
		KEY_V:
			_cycle_camera()

		KEY_LEFT:
			_adjust_pitch_target(Vector2(-AIM_STEP_M, 0.0))
		KEY_RIGHT:
			_adjust_pitch_target(Vector2(AIM_STEP_M, 0.0))
		KEY_UP:
			_adjust_pitch_target(Vector2(0.0, AIM_STEP_M))
		KEY_DOWN:
			_adjust_pitch_target(Vector2(0.0, -AIM_STEP_M))

		KEY_A:
			_adjust_batting_aim(Vector2(-AIM_STEP_M, 0.0))
		KEY_D:
			_adjust_batting_aim(Vector2(AIM_STEP_M, 0.0))
		KEY_W:
			_adjust_batting_aim(Vector2(0.0, AIM_STEP_M))
		KEY_S:
			_adjust_batting_aim(Vector2(0.0, -AIM_STEP_M))

		KEY_COMMA:
			_execution_quality = clampf(_execution_quality - 0.10, 0.0, 1.0)
			_refresh_config()
		KEY_PERIOD:
			_execution_quality = clampf(_execution_quality + 0.10, 0.0, 1.0)
			_refresh_config()
		KEY_BRACKETLEFT:
			_fatigue = clampf(_fatigue - 0.10, 0.0, 1.0)
			_refresh_config()
		KEY_BRACKETRIGHT:
			_fatigue = clampf(_fatigue + 0.10, 0.0, 1.0)
			_refresh_config()

		KEY_Z:
			_attempt_swing(CONTACT_SWING_ID)
		KEY_X:
			_attempt_swing(POWER_SWING_ID)

		_:
			return

	get_viewport().set_input_as_handled()

func _throw_pitch() -> void:
	var pitch: PitchDefinition = _selected_pitch()
	var ball_setup: BallSetupDefinition = ContentDB.get_ball_setup(BALL_SETUP_ID)

	if pitch == null or ball_setup == null:
		push_error("Pitch/Bat Lab: required prototype content is missing.")
		return

	_throw_number += 1
	_swing_consumed = false
	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	var target_position: Vector3 = Vector3(
		_pitch_target.x,
		_pitch_target.y,
		0.0
	)

	var base_parameters: PitchLaunchParameters = PitchAimSolver.solve(
		pitch,
		ball_setup,
		MOUND_ORIGIN,
		target_position,
		false,
		_throw_number
	)

	if base_parameters == null:
		_status_label.text = "Aim solver failed for %s." % pitch.display_name
		return

	_measure_nominal_pitch(base_parameters, target_position)

	var executed_parameters: PitchLaunchParameters = PitchExecutionModel.apply(
		base_parameters,
		_execution_quality,
		_fatigue,
		pitch.execution_difficulty,
		_throw_number * 1009 + _selected_pitch_index
	)

	_status_label.text = (
		"THROW %d — %s\n"
		+ "release %.1f mph   expected plate %.1f mph\n"
		+ "aero movement vs no-spin/asym baseline  X %+0.1f cm   Y %+0.1f cm"
	) % [
		_throw_number,
		pitch.display_name,
		_last_release_speed_mps * 2.236936,
		_last_expected_plate_speed_mps * 2.236936,
		_last_movement_x_m * 100.0,
		_last_movement_y_m * 100.0,
	]

	_pitch_actor.start_pitch(executed_parameters)

func _measure_nominal_pitch(
	base_parameters: PitchLaunchParameters,
	target_position: Vector3
) -> void:
	_last_release_speed_mps = base_parameters.velocity.length()

	var nominal_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(
			base_parameters,
			target_position.z
		)
	)

	if nominal_crossing.crossed:
		_last_expected_plate_speed_mps = nominal_crossing.velocity.length()
	else:
		_last_expected_plate_speed_mps = 0.0

	var neutral_parameters: PitchLaunchParameters = base_parameters.copy()
	neutral_parameters.magnus_scale = 0.0
	neutral_parameters.perforation_force_scale = 0.0
	neutral_parameters.instability_strength = 0.0

	var neutral_crossing: PitchCrossingResult = (
		PitchTrajectorySimulator.simulate_to_plane(
			neutral_parameters,
			target_position.z
		)
	)

	if nominal_crossing.crossed and neutral_crossing.crossed:
		_last_movement_x_m = (
			nominal_crossing.point.x - neutral_crossing.point.x
		)
		_last_movement_y_m = (
			nominal_crossing.point.y - neutral_crossing.point.y
		)
	else:
		_last_movement_x_m = 0.0
		_last_movement_y_m = 0.0

func _attempt_swing(profile_id: StringName) -> void:
	if (
		_pitch_actor == null
		or not _pitch_actor.running
		or _pitch_actor.state == null
		or _swing_consumed
	):
		return

	var profile: SwingProfileDefinition = ContentDB.get_swing(profile_id)
	if profile == null:
		push_error("Pitch/Bat Lab: swing profile missing: %s" % String(profile_id))
		return

	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile_id
	intent.aim_point = _batting_aim
	intent.handedness_left = false

	var result: ContactResult = ContactResolver.resolve(
		_pitch_actor.state,
		intent,
		profile
	)

	_swing_consumed = true
	_pitch_actor.stop_pitch(&"swing")

	var outcome_name: String = _contact_outcome_name(result.outcome)

	if result.outcome == ContactResult.Outcome.MISS:
		_status_label.text = (
			"%s — MISS\n"
			+ "bat aim x %.2f / y %.2f   ball x %.2f / y %.2f / z %.2f"
		) % [
			profile.display_name,
			_batting_aim.x,
			_batting_aim.y,
			result.contact_position.x,
			result.contact_position.y,
			result.contact_position.z,
		]
		return

	var exit_speed_mph: float = result.exit_velocity.length() * 2.236936
	_status_label.text = (
		"%s — %s   quality %.0f%%\n"
		+ "EV %.1f mph   launch %+0.1f°   spray %+0.1f°\n"
		+ "Contact/Power math is debug-only until ball-in-play phase."
	) % [
		profile.display_name,
		outcome_name,
		result.quality * 100.0,
		exit_speed_mph,
		result.launch_angle_degrees,
		result.spray_degrees,
	]

	var vector_end: Vector3 = (
		result.contact_position
		+ result.exit_velocity.normalized() * 4.0
	)
	var launch_points: Array[Vector3] = [
		result.contact_position,
		vector_end,
	]
	_contact_vector_draw.draw_polyline(launch_points)

func _on_trace_sampled(point: Vector3) -> void:
	_trajectory_points.append(point)
	_trajectory_draw.draw_polyline(_trajectory_points)

func _on_plate_crossed(
	point: Vector3,
	speed_mps: float,
	elapsed_seconds: float
) -> void:
	var target_error_x: float = point.x - _pitch_target.x
	var target_error_y: float = point.y - _pitch_target.y

	_status_label.text = (
		"PLATE — %s\n"
		+ "cross x %.2f / y %.2f   miss X %+0.1f cm / Y %+0.1f cm\n"
		+ "release %.1f mph → plate %.1f mph   flight %.3f s"
	) % [
		_selected_pitch().display_name,
		point.x,
		point.y,
		target_error_x * 100.0,
		target_error_y * 100.0,
		_last_release_speed_mps * 2.236936,
		speed_mps * 2.236936,
		elapsed_seconds,
	]

func _on_flight_stopped(reason: StringName) -> void:
	if reason == &"plate_crossed" or reason == &"swing":
		return

	_status_label.text = (
		"Pitch stopped: %s\nSPACE: throw again"
		% String(reason)
	)

func _adjust_pitch_target(delta_xy: Vector2) -> void:
	_pitch_target.x = clampf(
		_pitch_target.x + delta_xy.x,
		ZONE_MIN_X,
		ZONE_MAX_X
	)
	_pitch_target.y = clampf(
		_pitch_target.y + delta_xy.y,
		ZONE_MIN_Y,
		ZONE_MAX_Y
	)
	_refresh_markers()
	_refresh_config()

func _adjust_batting_aim(delta_xy: Vector2) -> void:
	_batting_aim.x = clampf(
		_batting_aim.x + delta_xy.x,
		ZONE_MIN_X,
		ZONE_MAX_X
	)
	_batting_aim.y = clampf(
		_batting_aim.y + delta_xy.y,
		ZONE_MIN_Y,
		ZONE_MAX_Y
	)
	_refresh_markers()
	_refresh_config()

func _selected_pitch() -> PitchDefinition:
	return ContentDB.get_pitch(PITCH_IDS[_selected_pitch_index])

func _reset_lab() -> void:
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()

	_pitch_target = DEFAULT_TARGET
	_batting_aim = DEFAULT_BATTING_AIM
	_execution_quality = 1.0
	_fatigue = 0.0
	_swing_consumed = false

	_trajectory_points.clear()
	_trajectory_draw.clear()
	_contact_vector_draw.clear()

	_status_label.text = "Lab reset. SPACE: throw"
	_live_label.text = ""
	_refresh_markers()
	_refresh_config()

func _cycle_camera() -> void:
	_camera_mode = (_camera_mode + 1) % 3
	_apply_camera_mode()

func _apply_camera_mode() -> void:
	match _camera_mode:
		0:
			_camera.position = Vector3(7.5, 4.2, -3.5)
			_camera.look_at(Vector3(0.0, 1.15, 6.5), Vector3.UP)
		1:
			_camera.position = Vector3(0.0, 1.65, -2.8)
			_camera.look_at(Vector3(0.0, 1.20, 8.0), Vector3.UP)
		2:
			_camera.position = Vector3(8.5, 2.5, 6.8)
			_camera.look_at(Vector3(0.0, 1.15, 6.8), Vector3.UP)

func _refresh_config() -> void:
	if _config_label == null:
		return

	var pitch: PitchDefinition = _selected_pitch()
	_config_label.text = (
		"PITCH %d/%d  %s\n"
		+ "target x %.2f / y %.2f   execution %.0f%%   fatigue %.0f%%\n"
		+ "bat aim x %.2f / y %.2f"
	) % [
		_selected_pitch_index + 1,
		PITCH_IDS.size(),
		pitch.display_name,
		_pitch_target.x,
		_pitch_target.y,
		_execution_quality * 100.0,
		_fatigue * 100.0,
		_batting_aim.x,
		_batting_aim.y,
	]

func _refresh_markers() -> void:
	if _pitch_target_marker != null:
		_pitch_target_marker.position = Vector3(
			_pitch_target.x,
			_pitch_target.y,
			0.015
		)

	if _batting_aim_marker != null:
		_batting_aim_marker.position = Vector3(
			_batting_aim.x,
			_batting_aim.y,
			-0.015
		)

func _contact_outcome_name(outcome: int) -> String:
	match outcome:
		ContactResult.Outcome.FOUL:
			return "FOUL"
		ContactResult.Outcome.CONTACT:
			return "CONTACT"
		ContactResult.Outcome.PERFECT:
			return "PERFECT"
		_:
			return "MISS"

func _build_pitch_actor() -> void:
	_pitch_actor = PitchFlightActor.new()
	_pitch_actor.name = "PitchFlightActor"
	_pitch_actor.trace_every_substeps = 2
	_pitch_actor.trace_sampled.connect(_on_trace_sampled)
	_pitch_actor.plate_crossed.connect(_on_plate_crossed)
	_pitch_actor.flight_stopped.connect(_on_flight_stopped)
	add_child(_pitch_actor)

	_trajectory_draw = TrajectoryDebugDraw.new()
	_trajectory_draw.name = "TrajectoryTrace"
	_trajectory_draw.material_override = _make_unshaded_material(
		Color(1.0, 0.72, 0.12)
	)
	add_child(_trajectory_draw)

	_contact_vector_draw = TrajectoryDebugDraw.new()
	_contact_vector_draw.name = "ContactVector"
	_contact_vector_draw.material_override = _make_unshaded_material(
		Color(0.25, 0.90, 1.0)
	)
	add_child(_contact_vector_draw)

func _build_environment() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	ground.name = "Ground"

	var ground_mesh: PlaneMesh = PlaneMesh.new()
	ground_mesh.size = Vector2(20.0, 22.0)
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, 0.0, 7.0)
	ground.material_override = _make_material(Color(0.19, 0.34, 0.19))
	add_child(ground)

	_add_box(
		"Plate",
		Vector3(0.0, 0.025, 0.0),
		Vector3(0.7, 0.05, 0.45),
		Color(0.92, 0.92, 0.88)
	)

	_add_box(
		"MoundMarker",
		MOUND_ORIGIN + Vector3(0.0, 0.025, 0.0),
		Vector3(0.8, 0.05, 0.8),
		Color(0.55, 0.38, 0.22)
	)

	_build_strike_zone_outline()
	_build_aim_markers()

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

	_camera = Camera3D.new()
	_camera.name = "LabCamera"
	_camera.current = true
	add_child(_camera)
	_apply_camera_mode()

func _build_strike_zone_outline() -> void:
	var zone_color: Color = Color(0.86, 0.90, 0.96)
	var thickness: float = 0.025

	_add_box(
		"ZoneLeft",
		Vector3(ZONE_MIN_X, (ZONE_MIN_Y + ZONE_MAX_Y) * 0.5, 0.0),
		Vector3(thickness, ZONE_MAX_Y - ZONE_MIN_Y, thickness),
		zone_color
	)
	_add_box(
		"ZoneRight",
		Vector3(ZONE_MAX_X, (ZONE_MIN_Y + ZONE_MAX_Y) * 0.5, 0.0),
		Vector3(thickness, ZONE_MAX_Y - ZONE_MIN_Y, thickness),
		zone_color
	)
	_add_box(
		"ZoneBottom",
		Vector3(0.0, ZONE_MIN_Y, 0.0),
		Vector3(ZONE_MAX_X - ZONE_MIN_X, thickness, thickness),
		zone_color
	)
	_add_box(
		"ZoneTop",
		Vector3(0.0, ZONE_MAX_Y, 0.0),
		Vector3(ZONE_MAX_X - ZONE_MIN_X, thickness, thickness),
		zone_color
	)

func _build_aim_markers() -> void:
	_pitch_target_marker = MeshInstance3D.new()
	_pitch_target_marker.name = "PitchTarget"

	var pitch_marker_mesh: SphereMesh = SphereMesh.new()
	pitch_marker_mesh.radius = 0.055
	pitch_marker_mesh.height = 0.11
	_pitch_target_marker.mesh = pitch_marker_mesh
	_pitch_target_marker.material_override = _make_unshaded_material(
		Color(1.0, 0.22, 0.18)
	)
	add_child(_pitch_target_marker)

	_batting_aim_marker = MeshInstance3D.new()
	_batting_aim_marker.name = "BattingAim"

	var bat_marker_mesh: BoxMesh = BoxMesh.new()
	bat_marker_mesh.size = Vector3(0.12, 0.12, 0.025)
	_batting_aim_marker.mesh = bat_marker_mesh
	_batting_aim_marker.material_override = _make_unshaded_material(
		Color(0.20, 0.90, 1.0)
	)
	add_child(_batting_aim_marker)

func _build_ui() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "DebugUI"
	add_child(canvas)

	_config_label = Label.new()
	_config_label.position = Vector2(20.0, 16.0)
	_config_label.add_theme_font_size_override("font_size", 19)
	canvas.add_child(_config_label)

	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 105.0)
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.text = "Loading Pitch Lab..."
	canvas.add_child(_status_label)

	_live_label = Label.new()
	_live_label.position = Vector2(20.0, 205.0)
	_live_label.add_theme_font_size_override("font_size", 16)
	canvas.add_child(_live_label)

	_controls_label = Label.new()
	_controls_label.position = Vector2(20.0, 565.0)
	_controls_label.add_theme_font_size_override("font_size", 14)
	_controls_label.text = (
		"1–9 pitch   SPACE throw   arrows pitch target   WASD bat aim\n"
		+ "Z Contact Swing   X Power Swing   ,/. execution   [/] fatigue\n"
		+ "V camera   R reset"
	)
	canvas.add_child(_controls_label)

	var footer: Label = Label.new()
	footer.position = Vector2(20.0, 670.0)
	footer.add_theme_font_size_override("font_size", 13)
	footer.text = (
		"Phase 1 debug lab — coefficients, swing math, and visuals are provisional."
	)
	canvas.add_child(footer)

func _add_box(
	node_name: String,
	world_position: Vector3,
	size: Vector3,
	color: Color
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.position = world_position

	var box: BoxMesh = BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = _make_material(color)

	add_child(instance)
	return instance

func _make_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

func _make_unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material

extends Node3D

const PITCH_ID: StringName = &"pitch.overhand_four_seam"
const BALL_SETUP_ID: StringName = &"ball_setup.fresh"

# Debug-only lab geometry. This is not a locked regulation distance.
const MOUND_ORIGIN := Vector3(0.0, 0.0, 13.716)
const TARGET_POSITION := Vector3(0.0, 0.80, 0.0)

var _pitch_actor: PitchFlightActor
var _trajectory_draw: TrajectoryDebugDraw
var _trajectory_points: Array[Vector3] = []

var _status_label: Label
var _live_label: Label
var _throw_number: int = 0

func _ready() -> void:
	if not ContentDB.validate_or_error():
		push_error("Pitch/Bat Lab loaded with invalid content.")
		return

	_build_environment()
	_build_pitch_actor()
	_build_ui()

	print(
		"Pitch/Bat Lab ready: %d pitch(es), %d player(s), %d delivery profile(s)."
		% [
			ContentDB.pitch_by_id.size(),
			ContentDB.player_by_id.size(),
			ContentDB.delivery_by_id.size(),
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

	var state := _pitch_actor.state
	_live_label.text = (
		"t: %.3f s   speed: %.1f mph\n"
		+ "ball: x %.2f m   y %.2f m   z %.2f m"
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

	match key_event.keycode:
		KEY_SPACE:
			_throw_pitch()
			get_viewport().set_input_as_handled()
		KEY_R:
			_reset_lab()
			get_viewport().set_input_as_handled()

func _throw_pitch() -> void:
	var pitch := ContentDB.get_pitch(PITCH_ID)
	var ball_setup := ContentDB.get_ball_setup(BALL_SETUP_ID)

	if pitch == null or ball_setup == null:
		push_error("Pitch/Bat Lab: required prototype content is missing.")
		return

	_throw_number += 1
	_trajectory_points.clear()
	_trajectory_draw.clear()

	var parameters := PitchLaunchBuilder.build_nominal(
		pitch,
		ball_setup,
		MOUND_ORIGIN,
		TARGET_POSITION,
		false,
		_throw_number
	)

	if parameters == null:
		return

	_status_label.text = (
		"Throw %d — %s\n"
		+ "Nominal %.1f mph / %.0f rpm\n"
		+ "SPACE: throw again    R: clear"
	) % [
		_throw_number,
		pitch.display_name,
		pitch.nominal_velocity_mps * 2.236936,
		pitch.nominal_spin_rpm,
	]

	_pitch_actor.start_pitch(parameters)

func _reset_lab() -> void:
	if _pitch_actor != null:
		_pitch_actor.reset_pitch()

	_trajectory_points.clear()
	if _trajectory_draw != null:
		_trajectory_draw.clear()

	if _status_label != null:
		_status_label.text = "Lab reset. SPACE: throw"
	if _live_label != null:
		_live_label.text = ""

func _on_trace_sampled(point: Vector3) -> void:
	_trajectory_points.append(point)
	_trajectory_draw.draw_polyline(_trajectory_points)

func _on_plate_crossed(
	point: Vector3,
	speed_mps: float,
	elapsed_seconds: float
) -> void:
	_status_label.text = (
		"Plate crossed — %s\n"
		+ "x %.2f m   y %.2f m   speed %.1f mph   flight %.3f s\n"
		+ "SPACE: throw again    R: clear"
	) % [
		String(PITCH_ID),
		point.x,
		point.y,
		speed_mps * 2.236936,
		elapsed_seconds,
	]

func _on_flight_stopped(reason: StringName) -> void:
	if reason == &"plate_crossed":
		return

	_status_label.text = (
		"Pitch stopped: %s\nSPACE: throw again    R: clear"
		% String(reason)
	)

func _build_pitch_actor() -> void:
	_pitch_actor = PitchFlightActor.new()
	_pitch_actor.name = "PitchFlightActor"
	_pitch_actor.trace_sampled.connect(_on_trace_sampled)
	_pitch_actor.plate_crossed.connect(_on_plate_crossed)
	_pitch_actor.flight_stopped.connect(_on_flight_stopped)
	add_child(_pitch_actor)

	_trajectory_draw = TrajectoryDebugDraw.new()
	_trajectory_draw.name = "TrajectoryTrace"

	var trace_material := StandardMaterial3D.new()
	trace_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace_material.albedo_color = Color(1.0, 0.75, 0.15)
	_trajectory_draw.material_override = trace_material
	add_child(_trajectory_draw)

func _build_environment() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Ground"

	var ground_mesh := PlaneMesh.new()
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

	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	light.shadow_enabled = true
	add_child(light)

	var camera := Camera3D.new()
	camera.name = "LabCamera"
	camera.position = Vector3(7.5, 4.2, -3.5)
	camera.current = true
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.15, 6.5), Vector3.UP)

func _build_strike_zone_outline() -> void:
	var zone_color := Color(0.86, 0.90, 0.96)
	var half_width := 0.43
	var bottom := 0.55
	var top := 1.55
	var thickness := 0.025

	_add_box(
		"ZoneLeft",
		Vector3(-half_width, (bottom + top) * 0.5, 0.0),
		Vector3(thickness, top - bottom, thickness),
		zone_color
	)
	_add_box(
		"ZoneRight",
		Vector3(half_width, (bottom + top) * 0.5, 0.0),
		Vector3(thickness, top - bottom, thickness),
		zone_color
	)
	_add_box(
		"ZoneBottom",
		Vector3(0.0, bottom, 0.0),
		Vector3(half_width * 2.0, thickness, thickness),
		zone_color
	)
	_add_box(
		"ZoneTop",
		Vector3(0.0, top, 0.0),
		Vector3(half_width * 2.0, thickness, thickness),
		zone_color
	)

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DebugUI"
	add_child(canvas)

	_status_label = Label.new()
	_status_label.position = Vector2(20.0, 18.0)
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.text = "Loading Pitch Lab..."
	canvas.add_child(_status_label)

	_live_label = Label.new()
	_live_label.position = Vector2(20.0, 100.0)
	_live_label.add_theme_font_size_override("font_size", 17)
	canvas.add_child(_live_label)

	var footer := Label.new()
	footer.position = Vector2(20.0, 675.0)
	footer.add_theme_font_size_override("font_size", 14)
	footer.text = (
		"Phase 1 physics lab — debug geometry and coefficients are provisional."
	)
	canvas.add_child(footer)

func _add_box(
	node_name: String,
	world_position: Vector3,
	size: Vector3,
	color: Color
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = world_position

	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = _make_material(color)

	add_child(instance)
	return instance

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material

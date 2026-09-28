extends Node3D

# Developer-only deterministic visual replay; never advances a season or AI.
const LAUNCHES: Array[Vector3] = [
	Vector3(0, -2, 8),
	Vector3(5, -1, 22),
	Vector3(0, 2, 33),
	Vector3(12, 5, 30),
	Vector3(0, 18, 26),
	Vector3(0, 22, 5)
]
const NAMES: Array[String] = [
	"Soft grounder", "Grounder past Double", "Fast liner", "Angled liner", "Deep fly", "Short popup"
]
var _case: int = 0
var _defense: bool = true
var _away: bool = false
var _lab: PitchBatLab
var _ball_mesh: MeshInstance3D
var _label: Label
var _ball: Vector3
var _velocity: Vector3
var _time: float = 0.0
var _accumulator: float = 0.0
var _grounded: bool = false
var _paused: bool = false
var _reference: bool = false
var _reference_camera: ReferenceBattingCamera = ReferenceBattingCamera.new()


func _ready() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	add_child(canvas)
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(16, 16)
	canvas.add_child(panel)
	_label = Label.new()
	panel.add_child(_label)
	_build_venue()


func _build_venue() -> void:
	if is_instance_valid(_lab):
		_lab._camera_director.tracking_visibility.restore_occluders()
		_lab.free()
	_lab = PitchBatLab.new()
	_lab._field_id = SeasonState.AWAY_FIELD_ID if _away else PitchBatLab.FIELD_ID
	add_child(_lab)
	_lab.process_mode = Node.PROCESS_MODE_DISABLED
	for child in _lab.get_children():
		if child is CanvasLayer:
			child.visible = false
	_ball_mesh = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	_ball_mesh.mesh = sphere
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1, 0.9, 0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ball_mesh.material_override = material
	_lab.add_child(_ball_mesh)
	_restart()


func _restart() -> void:
	_time = -0.75
	_accumulator = 0.0
	_grounded = false
	_ball = Vector3(0, 1, 0.28)
	_velocity = LAUNCHES[_case]
	_lab._primary_fielder.global_position = _lab._primary_fielder.anchor_position
	var director: MatchCameraDirector = _lab._camera_director
	director.clear_presentation_motion()
	director.set_shot(
		MatchCameraDirector.Shot.PITCHING if _defense else MatchCameraDirector.Shot.BATTING
	)
	director.snap(_lab._camera)
	director.prepare_ball_in_play(_defense, _ball, _velocity)
	_reference_camera.prepare(_ball)
	_ball_mesh.position = _ball


func _process(delta: float) -> void:
	if not _paused:
		_accumulator += minf(delta, 0.1)
		while _accumulator >= 1.0 / 120.0:
			_step()
			_accumulator -= 1.0 / 120.0
	_label.text = (
		(
			"Camera replay | %s | %s | %s | %.2f s\n"
			+ "Left/Right: play   R: restart   B: batting/defense   V: venue   Space: pause\n"
			+ "C: compare old/new batting follow\n"
			+ "Shot: %s   FOV: %.1f   Yellow ball enlarged for review"
		)
		% [
			NAMES[_case],
			"Defense" if _defense else "Batting",
			"Commons" if _away else "Yard",
			maxf(0, _time),
			(
				_lab._camera_director._live_coverage.shot_name
				if _defense
				else (
					"REFERENCE batting"
					if _reference
					else _lab._camera_director._batting_coverage.shot_name
				)
			),
			_lab._camera.fov
		]
	)


func _step() -> void:
	_time += 1.0 / 120.0
	if _time <= 0.0:
		return
	var live: bool = _time <= (0.5 if _case == 0 else 3.0)
	if not live:
		_lab._camera_director.update(_lab._camera, 1.0 / 120.0, false, _ball)
		return
	_velocity += (
		(
			Vector3(0, -9.81, 0)
			+ BattedBallAerodynamics.acceleration(
				_velocity,
				Quaternion.IDENTITY,
				Vector3.ZERO,
				0.020,
				0.0365,
				0.22,
				1.0,
				1.0,
				Vector3.RIGHT
			)
		)
		/ 120.0
	)
	_ball += _velocity / 120.0
	if _ball.y < 0.08:
		_ball.y = 0.08
		_velocity.y = absf(_velocity.y) * 0.52
		_grounded = true
	_ball_mesh.position = _ball
	var fielder: Node3D = _lab._primary_fielder
	fielder.global_position = fielder.global_position.move_toward(
		Vector3(_ball.x, 0, _ball.z), 4.6 / 120.0
	)
	var director: MatchCameraDirector = _lab._camera_director
	director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
	director.set_fielding_subjects(
		PackedVector3Array([fielder.global_position, _lab._pitcher_marker.global_position]),
		_grounded
	)
	if _reference and not _defense:
		_reference_camera.update(_lab._camera, 1.0 / 120.0, _ball, director.tracking_visibility)
	else:
		director.update(_lab._camera, 1.0 / 120.0, true, _ball)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_RIGHT:
			_case = (_case + 1) % LAUNCHES.size()
			_restart()
		KEY_LEFT:
			_case = posmod(_case - 1, LAUNCHES.size())
			_restart()
		KEY_R:
			_restart()
		KEY_B:
			_defense = not _defense
			_restart()
		KEY_V:
			_away = not _away
			_build_venue()
		KEY_C:
			_reference = not _reference
			_defense = false
			_restart()
		KEY_SPACE:
			_paused = not _paused

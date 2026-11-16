extends "res://src/tests/stadium_mogul_two_tracking_test.gd"
## Bounded headless observation of the unchanged full synthetic30Hz gate.
## No camera, visibility, physics, endpoint, framing or motion policy is overridden.

const DiagnosticArchive = preload("res://src/tests/stadium_mogul_two_history_archive.gd")

var _diagnostic_samples: int = 0
var _diagnostic_outside: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check(DisplayServer.get_name() == "headless", "bounded diagnostic is headless only")
	if _failures > 0:
		get_tree().quit(1)
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native helper has no hidden failure")
	_check(await _native.resize(Vector2i(1280, 720)), "unchanged synthetic extent acknowledged")
	_sample_fps = 30
	await _walls("synthetic-geometric-controls", "candidate")
	_check(_diagnostic_samples == 9600, "observer retains every original30Hz synthetic sample")
	print(
		"MOGUL_TWO_SYNTHETIC_DIAGNOSTIC samples=", _diagnostic_samples,
		" outside=", _diagnostic_outside, " fps=30 expected_samples=9600",
		" original_assertions=true camera_mutations=false physics_mutations=false"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AM-02 synthetic diagnostic passed: unchanged9600 samples and gates.")
	get_tree().quit(0 if _failures == 0 else 1)


func _near_clear(camera: Camera3D) -> bool:
	var original: bool = super._near_clear(camera)
	var stack: Array = get_stack()
	# The original loop invokes this query exactly once per sample. Nested positive,
	# actor, pause and teardown controls remain unchanged and are not miscounted.
	if stack.size() > 1 and stack[1].get("function", "") == "_walls":
		_observe_sample(camera, original)
	return original


func _observe_sample(camera: Camera3D, near_clear: bool) -> void:
	var lab: PitchBatLab = camera.get_parent() as PitchBatLab
	var ball: BattedBallBody = lab._batted_ball
	var director: MatchCameraDirector = lab._camera_director
	var coverage: BallInPlayCamera = director._live_coverage
	var requested_rows: Array[Vector3] = _endpoints(0)
	var frame: int = _diagnostic_samples % 120
	var path_index: int = floori(float(_diagnostic_samples) / 120.0)
	var projected: Vector2 = camera.unproject_position(ball.position)
	var behind: bool = camera.is_position_behind(ball.position)
	var outside: bool = behind or not Rect2(24, 24, 1232, 672).has_point(projected)
	_diagnostic_samples += 1
	_diagnostic_outside += int(outside)
	if not outside and frame not in [0, 119]:
		return
	var width: float = lerpf(2.0, 12.0, coverage._ground_coverage)
	var desired_depth: float = maxf(
		lerpf(17.5, 20.0, coverage._ground_coverage), ball.position.z + 13.0
	)
	if coverage._clearance_offset > 0:
		width = 12.0 + coverage._clearance_offset
		desired_depth = ball.position.z + 6.0
	var ground_x: float = coverage._side * width + ball.position.x * 0.35
	var row: Dictionary = {
		"sample": _diagnostic_samples - 1,
		"path_index": path_index,
		"frame": frame,
		"fps": _sample_fps,
		"left": lab._match_state.batter().definition.bats == PlayerDefinition.Handedness.LEFT,
		"defense": coverage._defense,
		"requested": requested_rows[path_index % requested_rows.size()],
		"ball": ball.position,
		"camera": camera.global_transform,
		"fov": camera.fov,
		"near": camera.near,
		"viewport": camera.get_viewport().get_visible_rect().size,
		"projected": projected,
		"behind": behind,
		"outside": outside,
		"near_clear": near_clear,
		"coverage_age": coverage._age,
		"coverage_side": coverage._side,
		"ground_coverage": coverage._ground_coverage,
		"air_coverage": coverage._air_coverage,
		"clearance_offset": coverage._clearance_offset,
		"ground_x": ground_x,
		"desired_ground_depth": desired_depth,
		"depth": _depth_record(director.tracking_visibility, ground_x, desired_depth, ball.position)
	}
	var errors: Array[String] = []
	var encoded: Variant = DiagnosticArchive._numeric(row, errors)
	_check(errors.is_empty(), "diagnostic observation is finite inspectable numeric data")
	print("MOGUL_TWO_SYNTHETIC_FRAME ", JSON.stringify(encoded, "", true, true))


func _depth_record(
	visibility: BallTrackingVisibility, x: float, desired: float, ball: Vector3
) -> Dictionary:
	var graph: StadiumRecipeBoundary = visibility._recipe
	var caps: Array[Dictionary] = []
	var limiting: String = "field_wall_z"
	var minimum: float = visibility.field_wall_z - BallTrackingVisibility.WALL_CAMERA_CLEARANCE
	for face: Dictionary in graph.segments():
		if face.role != "BACK_WALL_TERMINAL":
			continue
		var normal: Vector2 = graph.inward(face)
		if normal.y >= -StadiumRecipeBoundary.EPS:
			continue
		var depth: float = face.a.y - (
			(x - face.a.x) * normal.x - BallTrackingVisibility.WALL_CAMERA_CLEARANCE
		) / normal.y
		caps.append({"id": face.id, "a": face.a, "b": face.b, "depth": depth})
		if depth < minimum:
			minimum = depth
			limiting = face.id
	var path: Vector3 = Vector3(ball.x, 0, ball.z)
	var crossing: Dictionary = graph.crossing(Vector3.ZERO, path * 1000)
	return {
		"actual_adapter_depth": visibility.defense_depth(x, desired, ball),
		"all_back_kernel_depth": minf(minimum, desired),
		"all_back_limiting_face": limiting,
		"crossing_role": crossing.get("role", ""),
		"crossing_surface": crossing.get("segment", ""),
		"back_caps": caps
	}

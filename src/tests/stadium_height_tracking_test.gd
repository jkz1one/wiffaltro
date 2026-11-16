extends "res://src/tests/stadium_offset_tracking_test.gd"
## Actual-height camera qualification. No paid layout or saved field activation.

var _candidate_shape: String = "left_loft"


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	for shape: String in StadiumHeightWallRecipes.SHAPES:
		_candidate_shape = shape
		for item: String in StadiumWallRecipes.BACK_IDS:
			await _walls(shape, item)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro height tracking checks passed: both stepped outlines, hands and cameras.")
	get_tree().quit(0 if _failures == 0 else 1)


func _install_walls(lab: PitchBatLab, shape: String, item: String) -> void:
	_check(StadiumPropertyRuntime._install(lab, StadiumStarterLayout.empty(),
		StadiumStock.new_club()), "original isolated lab substrate")
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumHeightBoundaryBody = StadiumHeightBoundaryBody.new()
	boundary.name = "BoundaryGraph"
	property.add_child(boundary)
	_check(boundary.build(shape, item), "explicit separate-piece height candidate")
	StadiumWallRenderQuality.attach(boundary)
	lab._camera_director.tracking_visibility = StadiumHeightCameraVisibility.new()
	lab._camera_director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	_kernel_check(lab._camera_director.tracking_visibility, boundary.graph)
	_check(is_equal_approx(lab._camera_director.tracking_visibility.field_wall_z,
		27.0 if shape == "left_loft" else 27.5), "camera reads the true candidate depth")
	_check(not StadiumWallRecipes.SHAPES.has(shape), "saved recipe factories stay frozen")


func _endpoints(_depth: float) -> Array[Vector3]:
	var graph: StadiumHeightBoundary = StadiumHeightBoundary.candidate(_candidate_shape)
	var result: Array[Vector3] = []
	for row: Dictionary in graph.segments():
		if row.role == "BACK_WALL_TERMINAL":
			var point: Vector2 = (row.a + row.b) / 2 + graph.inward(row) * 0.15
			result.append(Vector3(point.x, 0.15, point.y))
	result.append_array([Vector3(7, 0.15, 11.75), Vector3(-25, 1.8, 18),
		Vector3(25, 1.8, 18), Vector3(0, 7, 30), Vector3(0, 35, 29)])
	return result


func _kernel_check(visibility: BallTrackingVisibility, graph: StadiumRecipeBoundary) -> void:
	var rows: Array[Dictionary] = graph.segments()
	for x: float in [-20, -12, 0, 12, 20]:
		var at: Vector2 = Vector2(x, visibility.defense_depth(x, 100))
		_check(at.is_finite(), "candidate viewing target remains finite")
		for index in range(4, rows.size() - 3):
			var row: Dictionary = rows[index]
			_check(graph.inward(row).dot(at - row.a)
				>= BallTrackingVisibility.WALL_CAMERA_CLEARANCE - 0.00001,
				"camera keeps the interior shoulder viewing kernel without remote end extrapolation")

extends "res://src/tests/stadium_height_tracking_test.gd"
## Dense geometry-only face/joint coverage at three frame rates, not rendered contrast evidence.


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for shape: String in StadiumHeightWallRecipes.SHAPES:
		_candidate_shape = shape
		for fps: int in [30, 60, 120]:
			_sample_fps = fps
			await _walls(shape, "ST-024")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro height camera sweep passed: stepped faces and joints at 30/60/120fps.")
	get_tree().quit(0 if _failures == 0 else 1)


func _endpoints(depth: float) -> Array[Vector3]:
	var result: Array[Vector3] = super._endpoints(depth)
	var graph: StadiumHeightBoundary = StadiumHeightBoundary.candidate(_candidate_shape)
	for row: Dictionary in graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		for fraction: float in [0.05, 0.25, 0.75, 0.95]:
			var at: Vector2 = row.a.lerp(row.b, fraction) + graph.inward(row) * 0.15
			result.append(Vector3(at.x, 0.15, at.y))
		var joint: Vector2 = row.a + row.a.direction_to(Vector2(0, 10)) * 0.2
		result.append(Vector3(joint.x, 0.15, joint.y))
	return result

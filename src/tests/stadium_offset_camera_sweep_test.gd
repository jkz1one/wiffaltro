extends "res://src/tests/stadium_offset_tracking_test.gd"
## Additional geometry-only coverage at every back face and joint, never a rendered contrast claim.


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	_check(_endpoints(28).size() == 44, "every back face and joint contributes coverage")
	for fps: int in [30, 60, 120]:
		_sample_fps = fps
		await _walls("offset_gables", "ST-024")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro offset camera sweep passed: "
			+ "44 face/joint/foul paths; both hands/roles at 30/60/120fps.")
	get_tree().quit(0 if _failures == 0 else 1)


func _endpoints(_depth: float) -> Array[Vector3]:
	var result: Array[Vector3] = super._endpoints(28)
	var graph: StadiumRecipeBoundary = StadiumOffsetBoundary.new()
	for row: Dictionary in graph.segments():
		if row.role != "BACK_WALL_TERMINAL":
			continue
		for fraction: float in [0.05, 0.25, 0.5, 0.75, 0.95]:
			var at: Vector2 = row.a.lerp(row.b, fraction) + graph.inward(row) * 0.15
			result.append(Vector3(at.x, 0.15, at.y))
		var joint: Vector2 = row.a + row.a.direction_to(Vector2(0, 10)) * 0.2
		result.append(Vector3(joint.x, 0.15, joint.y))
	return result

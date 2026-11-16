extends "res://src/tests/stadium_yard_two_legacy_camera_test.gd"
## Bounded diagnosis only. All existing camera assertions stay in force; never a substitute pass.


func _ready() -> void:
	_diagnostic = true
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "diagnostic native startup handshake")
	_check(await _native.resize(Vector2i(1280, 720)), "diagnostic tracking extent acknowledged")
	if _failures == 0:
		_sample_fps = 30
		await _walls("yard-complete", "four-copies")
	print(
		"AY02_CAMERA_DIAGNOSTIC_COMPLETE failures=",
		_failures,
		"; original visibility assertions retained"
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

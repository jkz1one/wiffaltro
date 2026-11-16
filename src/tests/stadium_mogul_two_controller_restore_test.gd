extends "res://src/tests/stadium_mogul_two_tracking_test.gd"
## Short native reproduction; does not claim the complete tracking or six-family gate.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_native_evidence.controller_only = true
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(DisplayServer.get_name() != "headless", "controller restoration gate requires native")
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native handshake has no hidden failure")
	_check(await _native.resize(Vector2i(1280, 720)), "actual controller extent acknowledged")
	_check(
		Evidence.fits_budget(Evidence.CONTROLLER_MAX_BYTES - 1, 1, Evidence.CONTROLLER_MAX_BYTES),
		"bounded image budget admits exact final byte"
	)
	_check(
		not Evidence.fits_budget(Evidence.CONTROLLER_MAX_BYTES, 1, Evidence.CONTROLLER_MAX_BYTES),
		"bounded image budget refuses first excess byte before writing"
	)
	_check(
		not Evidence.fits_budget(-1, 1, Evidence.CONTROLLER_MAX_BYTES),
		"unreadable evidence budget fails closed"
	)
	await EvidenceProof.run(self)
	EvidenceInventory.guards(self)
	await HistoryProof.run(self, true)
	_check(
		_native_evidence.actual.size() == 24 and _native_evidence.finish(self),
		"bounded native evidence retains every24 triplets/72 PNGs within36MiB"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro AM-02 controller restoration passed: bounded native4 sources/12 states.")
	get_tree().quit(0 if _failures == 0 else 1)

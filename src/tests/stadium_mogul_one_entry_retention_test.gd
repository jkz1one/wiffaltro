extends "res://src/tests/stadium_mogul_one_tracking_test.gd"
## Bounded native entry reproduction through the unchanged full-profile capture path.
## Four triplets and four standalone witnesses; no launched-history/full-matrix claim.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_check(DisplayServer.get_name() != "headless", "entry retention requires actual native pixels")
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	_check(not _capture_dir.is_empty(), "entry retention requires a private evidence destination")
	if _capture_dir.is_empty():
		get_tree().quit(1)
		return
	_array_controls()
	_native = NativeCapture.new()
	add_child(_native)
	await _native.initialize()
	_check(_native._failures == 0, "native handshake has no hidden failure")
	_check(await _native.resize(Vector2i(1280, 720)), "actual entry extent acknowledged")
	await EvidenceProof.run(self)
	EvidenceInventory.guards(self)
	await EntryProof.run(self)
	_check(_entry_inventory(), "actual entry retains exact four triplets and all subject witnesses")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro AM-01 entry retention passed: native4 triplets/16 PNGs/12 subject receipts."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _array_controls() -> void:
	var first: Image = Image.new()
	var second: Image = Image.new()
	var third: Image = Image.new()
	var images: Array[Image] = [first, second, third]
	var untyped: Array = [first, second, third]
	_check(
		(
			images.is_typed()
			and images.get_typed_builtin() == TYPE_OBJECT
			and images.get_typed_class_name() == &"Image"
			and images[0] == first
			and images[1] == second
			and images[2] == third
		),
		"typed image carrier preserves exact three objects and order before dynamic dispatch"
	)
	_check(
		not untyped.is_typed(),
		"untyped literal does not satisfy the dynamic Array[Image] carrier contract"
	)


func _entry_inventory() -> bool:
	var required: Dictionary = {}
	for hand: String in ["left", "right"]:
		for extent: Vector2i in EvidenceInventory.EXTENTS:
			required[EvidenceInventory.pair_key("mogul-one-static-entry-zone-" + hand, extent)] = true
	var complete: bool = (
		_native_evidence.errors.is_empty()
		and EvidenceInventory.same_keys(required, _native_evidence.expected)
		and EvidenceInventory.same_keys(required, _native_evidence.actual)
	)
	for key: String in _native_evidence.actual:
		complete = complete and bool(_native_evidence.actual[key].get("ok", false))
	var root: String = Evidence.budget_root(_capture_dir.path_join("entry-inventory"))
	var verified: Dictionary = Evidence.verify_inventory(root)
	complete = (
		complete
		and bool(verified.get("ok", false))
		and _native_evidence._verified_keys(self, verified)
		and int(verified.get("triplet_count", -1)) == 4
		and int(verified.get("standalone_count", -1)) == 4
		and int(verified.get("png_count", -1)) == 16
		and int(verified.get("raw_readback_receipt_count", -1)) == 12
		and int(verified.get("raw_readback_count", -1)) == 48
	)
	for key: String in ["images", "triplet_keys", "readback_keys"]:
		verified.erase(key)
	var receipt: Dictionary = {
		"kind": "BOUNDED_AM01_ACTUAL_ENTRY_RETENTION",
		"complete": complete,
		"required_keys": required.keys(),
		"expected_keys": _native_evidence.expected.keys(),
		"actual_keys": _native_evidence.actual.keys(),
		"errors": _native_evidence.errors,
		"verified_inventory": verified,
		"full_tracking_qualification": false,
		"genuine_launched_physics": false
	}
	var saved: bool = Evidence.record_receipt(receipt, _capture_dir.path_join("entry-inventory"))
	print("MOGUL_ONE_ENTRY_RETENTION_INVENTORY ", receipt)
	return complete and saved and bool(Evidence.verify_inventory(root).get("ok", false))

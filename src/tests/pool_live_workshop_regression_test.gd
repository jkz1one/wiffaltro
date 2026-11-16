extends "res://src/tests/stadium_pool_workshop_v51_test.gd"
## Current enabled-workshop contract, using explicitly simulated earned test career.
## This is not a human-earned or physically progressed startup fixture.
# gdlint: disable=max-returns

func _ready() -> void:
	_output = OS.get_environment("POOL_LIVE_TEST_OUTPUT")
	if not _output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		get_tree().quit(2)
		return
	_admitted = true
	_runtime = StadiumPoolPartyAssetIntegrity.source_sha256()
	if _check(await _setup(), "simulated career setup completed"):
		await _live()
	if is_instance_valid(_app):
		_app.queue_free()
	await _frames()
	await TestAudioDrain.finish(get_tree())
	print("POOL_LIVE_WORKSHOP checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _press(label: String) -> bool:
	var button: Button = _button(_app.menu, label)
	if not _check(button != null and not button.disabled, "enabled action: " + label):
		return false
	button.pressed.emit()
	await _frames()
	return true

func _live() -> void:
	_check(StadiumPoolWorkshopUI.WORKSHOP_ENABLED, "current Pool workshop enabled")
	var held: PackedByteArray = _held()
	StadiumEditorUI.show(_app.menu)
	await _frames()
	if not await _press("POOL INVENTORY"):
		return
	_check(_preview(_app) == null and held == _held(), "inventory opens without world or mutation")
	if not await _press("PLACE POOL"):
		return
	_check(_placement_card() != null and _preview(_app) != null and held == _held(),
		"placement preview keeps earned ledger and frozen home unchanged")
	_check(_button(_app.menu, "APPLY LAYOUT").disabled, "unsaved Pool cannot apply")
	var old_callbacks: Array[Callable] = []
	for action: String in ["SAVE DRAFT", "APPLY LAYOUT"]:
		for connection: Dictionary in _button(_app.menu, action).get_signal_connection_list("pressed"):
			old_callbacks.append(connection.callable)
	if not await _press("SAVE DRAFT"):
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(_app.season.career)
	_check(ClubCareer.same(ledger.view().stadium_draft, _layout)
		and var_to_bytes(_app.season.home_property) == _frozen_home,
		"save stages exact paid Pool without changing home")
	_check(_button(_app.menu, "SAVE DRAFT").disabled, "saved draft cannot duplicate save")
	var saved: PackedByteArray = _held()
	for callback: Callable in old_callbacks:
		callback.call()
	_check(old_callbacks.size() == 2 and saved == _held() and not _app._dialog.visible,
		"callbacks from replaced placement cannot save or confirm again")
	if not await _press("APPLY LAYOUT"):
		return
	_check(_app._dialog.visible and saved == _held(), "apply confirms before any mutation")
	_app._dialog.get_cancel_button().pressed.emit()
	await _frames()
	_check(not _app._dialog.visible and saved == _held(), "cancel keeps exact staged save")
	if not await _press("APPLY LAYOUT"):
		return
	_app._dialog.get_ok_button().pressed.emit()
	await _frames()
	ledger = ClubPlayers.assets(_app.season.career)
	_check(ClubCareer.same(ledger.view().stadium_active, _layout)
		and ClubCareer.same(_app.season.home_property.layout, _layout),
		"confirmed paid Pool applies to eligible pre-draft home")
	_check(SeasonSave.restore() != null, "applied earned test career cold restores")
	_check(_button(_app.menu, "APPLY LAYOUT").disabled, "applied Pool cannot duplicate apply")
	var applied: PackedByteArray = _held()
	if not await _press("STORE POOL"):
		return
	_check(not StadiumPoolWorkshopUI.pool_intent(
		_placement_card().get_meta("pool_placement_draft", {}))
		if _placement_card() != null else true, "store exits Pool placement")
	_check(ledger.construction().copies.has(_pool_copy), "storage keeps exact paid copy owned")

	_check(applied == _held(), "storage preview does not immediately mutate applied layout")
	if not await _press("SAVE DRAFT"):
		return
	ledger = ClubPlayers.assets(_app.season.career)
	_check(not StadiumPoolWorkshopUI.pool_intent(ledger.view().stadium_draft)
		and StadiumPoolWorkshopUI.pool_intent(ledger.view().stadium_active),
		"saved storage draft preserves active Pool until apply")
	if not await _press("APPLY LAYOUT"):
		return
	_check(_app._dialog.visible, "Pool storage apply requests confirmation")
	_app._dialog.get_ok_button().pressed.emit()
	await _frames()
	ledger = ClubPlayers.assets(_app.season.career)
	_check(not StadiumPoolWorkshopUI.pool_intent(ledger.view().stadium_active)
		and ledger.construction().copies.has(_pool_copy), "applied storage retains exact paid Pool")
	_check(SeasonSave.restore() != null, "stored Pool career cold restores")

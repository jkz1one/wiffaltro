extends Node
## Invalid layout schemas must fail closed before any preview/transaction UI is built.
var failures: int = 0
var checks: int = 0

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _button(root: Node, label: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		if node.text == label:
			return node
	return null

func _ready() -> void:
	SeasonSave.path = "user://invalid-draft-guard.json"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	app.begin_surface_time_season("day", 51)
	var ledger: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var held: PackedByteArray = var_to_bytes(SeasonSave.snapshot(app.season))
	var disk: String = FileAccess.get_file_as_string(SeasonSave.path)
	var drafts: Array[Dictionary] = []
	for version: int in range(1, 48):
		drafts.append({"version": version})
	drafts.append({"pool": null})
	drafts.append({"family": StadiumPoolOwnedLayout.FAMILY})
	for value: Variant in ["broken", null, {}, [], 45.5]:
		drafts.append({"version": 47, "animation_base": value})
	for draft: Dictionary in drafts:
		StadiumEditorUI.show(app.menu, draft, ledger.revision())
		await get_tree().process_frame
		_check(app.menu.find_children("*", "SubViewport", true, false).is_empty(),
			"invalid schema allocates no preview")
		_check(_button(app.menu, "SAVE DRAFT") == null and _button(app.menu, "APPLY LAYOUT") == null,
			"invalid schema exposes no save or apply controls")
		var reload_button: Button = _button(app.menu, "RELOAD SAVED")
		var back: Button = _button(app.menu, "CLUB RECORD")
		_check(reload_button != null and back != null, "invalid schema has recovery navigation")
		if back != null:
			back.pressed.emit()
			_check(app._dialog.visible, "unsaved invalid draft back requests discard confirmation")
			app._dialog.get_cancel_button().pressed.emit()
			await get_tree().process_frame
			_check(not app._dialog.visible and app.menu.page == "stadium", "cancel stays in workshop")
		_check(held == var_to_bytes(SeasonSave.snapshot(app.season))
			and disk == FileAccess.get_file_as_string(SeasonSave.path),
			"invalid schema and cancel preserve memory and save bytes")
		if reload_button != null:
			reload_button.pressed.emit()
			await get_tree().process_frame
			_check(not app.menu.find_children("*", "SubViewport", true, false).is_empty(),
				"explicit reload renders the valid saved draft")
		_check(held == var_to_bytes(SeasonSave.snapshot(app.season))
			and disk == FileAccess.get_file_as_string(SeasonSave.path), "reload is read-only")
	app.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	print("WORKSHOP_MALFORMED_FAMILIES checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

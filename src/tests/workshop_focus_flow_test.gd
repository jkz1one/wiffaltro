extends Node

const NativeCapture = preload("res://src/tests/stadium_mounted_scoreboard_capture_support.gd")
var app: SeasonApp
var native: NativeCapture
var failures: int = 0
var checks: int = 0
var capture_dir: String
var rows: Array = []


func _ready() -> void:
	capture_dir = OS.get_environment("WORKSHOP_CAPTURE_DIR")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	native = NativeCapture.new()
	add_child(native)
	await native.initialize()
	_check(await native.resize(Vector2i(1280, 720)), "native normal size acknowledged")
	SeasonSave.path = "user://workshop-qa.json"
	var file := FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(OS.get_environment("WORKSHOP_PROFILE_FIXTURE")))
	file.close()
	app = SeasonApp.new()
	add_child(app)
	await _settle()
	_check(app.season != null and app.season.career != null, "retained fixture loads")
	var memory: Dictionary = SeasonSave.snapshot(app.season)
	var primary: String = FileAccess.get_file_as_string(SeasonSave.path)
	var backup: String = _bytes(SeasonSave.path + ".bak")
	StadiumEditorUI.show(app.menu)
	await _settle()
	await _capture("normal-first")
	StadiumEditorUI.show(app.menu)
	await _settle()
	await _capture("normal-repeat")
	_check(await native.resize(Vector2i(700, 400)), "native minimum size acknowledged")
	await _settle()
	await _capture("small-resize")
	StadiumEditorUI.show(app.menu)
	await _settle()
	await _capture("small-reopen")
	await _interaction_cases()
	_check(
		ClubCareer.same(memory, SeasonSave.snapshot(app.season)), "viewing leaves career unchanged"
	)
	_check(
		primary == _bytes(SeasonSave.path) and backup == _bytes(SeasonSave.path + ".bak"),
		"viewing leaves primary and backup unchanged"
	)
	_check(native._failures == 0, "native capture support clean")
	file = FileAccess.open(capture_dir.path_join("geometry.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(rows, "\t"))
	file.close()
	app.queue_free()
	await get_tree().process_frame
	await TestAudioDrain.finish(get_tree())
	print("WORKSHOP_FOCUS_FLOW checks=", checks, " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)


func _settle() -> void:
	for frame in range(12):
		await get_tree().process_frame
		await RenderingServer.frame_post_draw


func _capture(label: String) -> void:
	var menu: SeasonMenu = app.menu
	var scroll: ScrollContainer = menu._body.get_parent()
	var summary: Label = null
	for node in menu._body.get_children():
		if node is Label and node.text.contains(" in draft "):
			summary = node
	_check(summary != null, "workshop inventory summary exists")
	var focus: Control = get_viewport().gui_get_focus_owner()
	var row: Dictionary = {
		"label": label,
		"window": str(get_window().size),
		"scroll": scroll.scroll_vertical,
		"scroll_rect": str(scroll.get_global_rect()),
		"body_rect": str(menu._body.get_global_rect()),
		"summary_rect": str(summary.get_global_rect()) if summary != null else "missing",
		"focus_path": str(focus.get_path()) if focus != null else "none",
		"focus_text": focus.text if focus is BaseButton else "",
		"focus_rect": str(focus.get_global_rect()) if focus != null else "none"
	}
	rows.append(row)
	print("WORKSHOP_VIEW ", JSON.stringify(row))
	if summary != null:
		_check(
			scroll.get_global_rect().encloses(summary.get_global_rect()),
			"initial workshop summary is fully visible " + label
		)
	var image := get_viewport().get_texture().get_image()
	_check(image.save_png(capture_dir.path_join(label + ".png")) == OK, "native screenshot saved")


func _bytes(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _interaction_cases() -> void:
	var menu: SeasonMenu = app.menu
	var scroll: ScrollContainer = menu._body.get_parent()
	var focus: Control = get_viewport().gui_get_focus_owner()
	_check(
		focus is BaseButton and focus.text == "FIELD VIEW", "initial footer focus names Field View"
	)
	_check(scroll.follow_focus, "normal focus following remains enabled")
	var preview: StadiumDraftPreview
	for child in menu._body.get_children():
		if child is StadiumDraftPreview:
			preview = child
	var pose: Transform3D = preview.camera.transform
	_button("FIELD VIEW").pressed.emit()
	await _settle()
	_check(
		scroll.scroll_vertical > 0 and scroll.get_global_rect().encloses(preview.get_global_rect()),
		"explicit Field View reveals full preview"
	)
	_check(preview.camera.transform == pose, "initial and explicit overview camera are identical")
	scroll.scroll_vertical = 600
	await _settle()
	_check(scroll.scroll_vertical == 600, "deliberate manual scroll is not reset")
	var choice: OptionButton = _surface("foundation")
	choice.grab_focus()
	await _settle()
	_check(_body_focus_visible(), "deliberate settled body focus scrolls into view")
	choice.item_selected.emit(choice.selected)
	await _settle()
	focus = get_viewport().gui_get_focus_owner()
	_check(
		focus is OptionButton and focus.get_meta("surface_choice", "") == "foundation",
		"selector rebuild restores intended control focus"
	)
	_check(_body_focus_visible(), "restored selector focus remains fully visible")
	await _plain_capture("selector-restored")
	scroll = menu._body.get_parent()
	scroll.scroll_vertical = 600
	await _settle()
	_check(scroll.scroll_vertical == 600, "manual scroll after restored focus is not reset")
	_button("RELOAD SAVED").pressed.emit()
	await _settle()
	await _capture("reload-saved")
	_button("CLUB RECORD").pressed.emit()
	await _settle()
	_check(menu.page != "stadium", "Back leaves clean workshop")
	StadiumEditorUI.show(menu)
	await _settle()
	await _capture("back-reopen")
	var notice: String = app.notice
	app.notice = ""
	StadiumEditorUI.show(menu)
	await _settle()
	await _capture("short-notice")
	app.notice = notice
	StadiumEditorUI.show(menu)
	StadiumEditorUI.show(menu)
	await _settle()
	await _capture("rapid-reopen")
	StadiumEditorUI.show(menu)
	_button("CLUB RECORD").pressed.emit()
	await _settle()
	_check(menu.page != "stadium", "queued workshop focus never restores an older page")
	StadiumEditorUI.show(menu)
	await _settle()
	await _capture("rapid-away-reopen")
	# Exercise detachment while the one-shot callback is suspended after frame one.
	menu._settle_workshop_focus(menu._body)
	var parent: Node = menu.get_parent()
	parent.remove_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	parent.add_child(menu)
	await _settle()
	_check(menu.is_inside_tree() and menu.page == "stadium", "detached menu safely returns")
	StadiumEditorUI.show(menu)
	await _settle()
	await _capture("detach-reopen")
	menu._settle_workshop_focus.call_deferred(menu._body)
	parent.remove_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame
	parent.add_child(menu)
	await _settle()
	_check(menu.is_inside_tree() and menu.page == "stadium", "deferred-start detach safely returns")
	StadiumEditorUI.show(menu)
	await _settle()
	await _capture("deferred-detach-reopen")
	var ledger: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var draft: Dictionary = ledger.view().stadium_draft.duplicate(true)
	draft.surface.height = "medium" if draft.surface.height != "medium" else "long"
	StadiumEditorUI.show(menu, draft, ledger.revision())
	await _settle()
	_button("CLUB RECORD").pressed.emit()
	await _settle()
	_check(
		app._dialog.visible and app._dialog.dialog_text.contains("Unsaved stadium draft"),
		"dirty Back opens discard confirmation"
	)
	app._dialog.get_cancel_button().pressed.emit()
	await _settle()
	_check(not app._dialog.visible and menu.page == "stadium", "Cancel keeps workshop open")
	_check(not _button("SAVE DRAFT").disabled, "Cancel retains unsaved preview")
	_button("RELOAD SAVED").pressed.emit()
	await _settle()
	await _capture("cancel-reload")
	_check(_button("SAVE DRAFT").disabled, "Reload discards only ephemeral preview")


func _button(label: String) -> Button:
	for node: Node in app.menu._footer.get_children():
		if node is Button and node.text == label:
			return node
	return null


func _surface(channel: String) -> OptionButton:
	for node in app.menu._body.find_children("*", "OptionButton", true, false):
		if node.get_meta("surface_choice", "") == channel:
			return node
	return null


func _body_focus_visible() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	var scroll: ScrollContainer = app.menu._body.get_parent()
	return (
		focus != null
		and app.menu._body.is_ancestor_of(focus)
		and scroll.get_global_rect().encloses(focus.get_global_rect())
	)


func _plain_capture(label: String) -> void:
	var image := get_viewport().get_texture().get_image()
	_check(
		image.save_png(capture_dir.path_join(label + ".png")) == OK, "interaction screenshot saved"
	)

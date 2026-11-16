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
	print("WORKSHOP_INITIAL_VIEW checks=", checks, " failures=", failures)
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

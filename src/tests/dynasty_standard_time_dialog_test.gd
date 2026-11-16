extends "res://src/tests/dynasty_standard_time_ui_test.gd"
## Exact SeasonApp + real ConfirmationDialog/button signal order, fake write endpoint.
func _ready() -> void:
	SeasonSave.path = "user://time-dialog-unused.json"
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	var endpoint: Owner = Owner.new()
	app.dynasty_owner = endpoint
	var events: Array[String] = []
	app._dialog.confirmed.connect(func() -> void: events.append("confirmed"))
	app._dialog.visibility_changed.connect(func() -> void:
		if not app._dialog.visible:
			events.append("hidden"))
	UI._ask_other(app, "standard", 17, 2)
	var first: OptionButton = app._confirmation_body.get_node("SharedStandardTime")
	first.select(2)
	check(app.get_script() == SeasonApp and app._dialog.visible, "exact main app real dialog visible")
	app._dialog.get_ok_button().pressed.emit()
	check(endpoint.calls.size() == 1 and endpoint.calls[0][4] == "night", "actual OK button forwards selected Night once")
	check(events.has("confirmed") and events.has("hidden"), "engine confirm and hide both delivered: " + str(events))
	await get_tree().process_frame
	check(not is_instance_valid(first), "accepted selector cleanup after engine callbacks")
	UI._ask_other(app, "standard", 19, 1)
	var cancelled: Callable = app._confirmed_action
	var second: OptionButton = app._confirmation_body.get_node("SharedStandardTime")
	second.select(1)
	app._dialog.get_cancel_button().pressed.emit()
	await get_tree().process_frame
	check(endpoint.calls.size() == 1 and not is_instance_valid(second), "actual Cancel has no write endpoint call")
	cancelled.call()
	check(endpoint.calls.size() == 1, "retained cancelled callback harmless")
	UI._ask_other(app, "standard", 21, 0)
	var reopened: OptionButton = app._confirmation_body.get_node("SharedStandardTime")
	check(reopened.selected == 0, "reopen resets Day default")
	app._dialog.get_ok_button().pressed.emit()
	check(endpoint.calls.size() == 2 and endpoint.calls.back()[1] == 21
		and endpoint.calls.back()[4] == "day", "reopened real confirmation uses new revision and Day")
	check(not FileAccess.file_exists(SeasonSave.path), "no ordinary save created by dialog proof")
	app.queue_free()
	await get_tree().process_frame
	print("SHARED_TIME_DIALOG checks=%d failures=%d owner_writes=0 games=0" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

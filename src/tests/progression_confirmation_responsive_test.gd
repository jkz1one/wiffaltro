extends "res://src/tests/paid_shop_ui_test.gd"


class ProbeApp:
	extends SeasonApp
	var chosen: Array = []

	func begin_surface_time_season(
		profile: String = "day", seed_value: int = -1, selected_tier: int = 0
	) -> void:
		chosen.append([profile, seed_value, selected_tier])


var _checks: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	super._check(ok, label)


func _choices(app: SeasonApp) -> Array[OptionButton]:
	var choices: Array[OptionButton] = []
	for node: Node in app._dialog.find_children("*", "OptionButton", true, false):
		if not node.is_queued_for_deletion():
			choices.append(node)
	return choices


func _bounds(app: SeasonApp, label: String) -> void:
	var d: ConfirmationDialog = app._dialog
	var screen: Rect2 = get_viewport().get_visible_rect()
	_check(
		screen.encloses(Rect2(Vector2(d.position), Vector2(d.size))), "whole modal visible " + label
	)
	for button: Button in [d.get_ok_button(), d.get_cancel_button()]:
		var r: Rect2 = button.get_global_rect()
		r.position += Vector2(d.position)
		_check(screen.encloses(r), "action reachable " + label + button.text)
	_check(
		app._confirmation_text.text == d.dialog_text,
		"complete original disclosure unchanged " + label
	)
	var choices: Array[OptionButton] = _choices(app)
	_check(choices.size() == 1, "exactly one current profile selector " + label)
	if choices.size() == 1:
		var r: Rect2 = choices[0].get_global_rect()
		r.position += Vector2(d.position)
		_check(screen.encloses(r), "profile selector reachable " + label)
	var scrollbar: VScrollBar = app._confirmation_scroll.get_v_scroll_bar()
	app._confirmation_scroll.scroll_vertical = int(scrollbar.max_value)
	await _frames(5)
	_check(
		scrollbar.value + scrollbar.page >= scrollbar.max_value - 1,
		"complete text scrolls to bottom " + label
	)


func _ready() -> void:
	SeasonSave.path = "user://isolated-responsive-confirmation.json"
	get_window().content_scale_size = Vector2i.ZERO
	var app: ProbeApp = ProbeApp.new()
	add_child(app)
	await _frames(8)
	for dimensions: Vector2i in [
		Vector2i(1280, 720),
		Vector2i(960, 540),
		Vector2i(700, 400),
		Vector2i(420, 720),
		Vector2i(360, 640)
	]:
		get_window().size = dimensions
		await _frames(8)
		for tier in range(5):
			app.ask_progression_season(tier)
			await _frames(8)
			await _bounds(app, str(dimensions) + " tier " + str(tier))
			await _click(app._dialog.get_cancel_button())
			_check(not app._dialog.visible and app.chosen.is_empty(), "Cancel never starts season")
			await _frames(8)
	# Resize the open modal, then invoke each exact selected policy through real OK.
	for selection in range(3):
		get_window().size = Vector2i(1280, 720)
		app.ask_progression_season(2)
		await _frames(8)
		get_window().size = Vector2i(700, 400)
		await _frames(8)
		await _bounds(app, "open resize")
		var choices: Array[OptionButton] = _choices(app)
		choices[0].select(selection)
		await _click(app._dialog.get_ok_button())
		_check(
			(
				app.chosen.size() == 1
				and app.chosen[0] == [["day", "sunset", "night"][selection], -1, 2]
			),
			"exact selected profile called once"
		)
		app.chosen.clear()
		await _frames(8)
	# A repeated request replaces an already-open modal, including same-frame choices.
	app.ask_progression_season(1)
	app.ask_progression_season(3)
	await _frames(8)
	await _bounds(app, "repeated request")
	_check(_choices(app).size() == 1, "repeat request keeps one selector")
	await _click(app._dialog.get_ok_button())
	_check(
		app.chosen.size() == 1 and app.chosen[0] == ["day", -1, 3],
		"only newer requested tier starts"
	)
	app.chosen.clear()
	await _frames(8)
	# A later generic confirmation must not inherit a stale profile selector or action.
	var calls: Array[int] = [0]
	app._confirm("Short independent confirmation", func() -> void: calls[0] += 1)
	await _frames(8)
	_check(_choices(app).is_empty(), "closed profile selector removed before independent modal")
	await _click(app._dialog.get_ok_button())
	_check(calls[0] == 1 and app.chosen.is_empty(), "independent action invoked exactly once")
	app.queue_free()
	await _frames(8)
	print("CONFIRM_RESPONSIVE_RESULT checks=", _checks, " failures=", _failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

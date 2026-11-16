extends "res://src/tests/paid_shop_ui_test.gd"
var _checks: int = 0
func _check(ok: bool, label: String) -> void:
	_checks += 1
	super._check(ok,label)
func _ready() -> void:
	SeasonSave.path = "user://isolated-confirmation.json"
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames(8)
	for tier in range(5):
		app.ask_progression_season(tier)
		await _frames(8)
		var dialog: ConfirmationDialog = app._dialog
		var rect: Rect2 = Rect2(Vector2(dialog.position),Vector2(dialog.size))
		var screen: Rect2 = get_viewport().get_visible_rect()
		print("CONFIRM_GEOMETRY tier=",tier," dialog=",rect," screen=",screen)
		_check(screen.encloses(rect),"complete progression modal fits viewport tier %d" % tier)
		for button: Button in [dialog.get_ok_button(),dialog.get_cancel_button()]:
			var bounds: Rect2 = button.get_global_rect()
			bounds.position += Vector2(dialog.position)
			_check(screen.encloses(bounds),"confirmation action visible tier %d: %s" % [tier,button.text])
		await _click(dialog.get_cancel_button())
		_check(not dialog.visible,"Cancel dismisses modal via actual input tier %d" % tier)
		dialog.hide()
		await _frames(8)
	app.queue_free()
	await _frames(8)
	print("CONFIRM_BOUNDS_RESULT checks=",_checks," failures=",_failures)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

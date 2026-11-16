extends Node
## UI callback/cancel contract only. No owner admission or physical claim.
const UI = preload("res://src/presentation/season/dynasty_career_ui.gd")
class Owner:
	extends RefCounted
	var calls: Array = []
	func start_other(league: String, revision: int, seed: int, tier: int, profile: String = "") -> bool:
		calls.append([league, revision, seed, tier, profile])
		return true
class App:
	extends Node
	var _dialog: ConfirmationDialog
	var _confirmation_body: VBoxContainer
	var _confirmed_action: Callable
	var dynasty_owner: Owner = Owner.new()
	func _ready() -> void:
		_dialog = ConfirmationDialog.new()
		add_child(_dialog)
		_confirmation_body = VBoxContainer.new()
		_dialog.add_child(_confirmation_body)
	func _confirm(message: String, action: Callable) -> void:
		_dialog.dialog_text = message
		_confirmed_action = action
		_dialog.popup_centered()
	func _refresh_confirmation() -> void:
		pass
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var app: App = App.new()
	add_child(app)
	UI._ask_other(app, "standard", 7, 2)
	var first: OptionButton = app._confirmation_body.get_node("SharedStandardTime")
	check(first.item_count == 3 and first.selected == 0, "day default and all modes")
	first.select(2)
	var cancelled: Callable = app._confirmed_action
	app._dialog.hide()
	await get_tree().process_frame
	check(not is_instance_valid(first) and app.dynasty_owner.calls.is_empty(), "cancel frees selector without action")
	cancelled.call()
	check(app.dynasty_owner.calls.is_empty(), "stale cancelled callback cannot start")
	UI._ask_other(app, "standard", 9, 1)
	var current: OptionButton = app._confirmation_body.get_node("SharedStandardTime")
	current.select(1)
	app._confirmed_action.call()
	check(app.dynasty_owner.calls.size() == 1, "current confirmation one action")
	check(app.dynasty_owner.calls[0][1] == 9 and app.dynasty_owner.calls[0][3] == 1
		and app.dynasty_owner.calls[0][4] == "sunset", "exact revision tier and selected profile forwarded")
	app._dialog.hide()
	await get_tree().process_frame
	UI._ask_other(app, "dugout", 11, 0)
	check(app._confirmation_body.get_node_or_null("SharedStandardTime") == null, "closed league no time control")
	app._confirmed_action.call()
	check(app.dynasty_owner.calls.back()[4] == "", "closed league preserves old absent profile")
	app.queue_free()
	await get_tree().process_frame
	print("SHARED_TIME_UI checks=%d failures=%d writes=0 games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

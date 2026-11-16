extends Node
## No owner/save access. Runs real shared transaction presentation with fake IO.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
const Busy = preload("res://src/presentation/stadium/shared_stadium_transaction_ui.gd")
class ProbeApp extends Node:
	var menu: SeasonMenu
	var notice: String = ""
var app: ProbeApp
var calls: int = 0
var completed: int = 0
var checks: int = 0
var failures: int = 0
var success: bool = true
var screenshot: String = ""

func check(value: bool, label: String) -> void:
	checks += 1
	print("PROCESSING_CHECK ", checks, " ", value, " ", label)
	if not value:
		failures += 1
		push_error(label)

func screen() -> void:
	if app.menu._body != null:
		app.menu.remove_child(app.menu._body)
		app.menu._body.free()
		app.menu.remove_child(app.menu._footer)
		app.menu._footer.free()
	app.menu.page = "shared_stadium"
	app.menu._body = VBoxContainer.new()
	app.menu.add_child(app.menu._body)
	app.menu._footer = HBoxContainer.new()
	app.menu.add_child(app.menu._footer)
	app.menu._button(app.menu._footer, "SAVE", start)
	app.menu._button(app.menu._footer, "DISABLED", start).disabled = true
	var choice: OptionButton = OptionButton.new()
	choice.add_item("Stored")
	choice.add_item("Placed")
	choice.item_selected.connect(func(_index: int) -> void: calls += 100)
	app.menu._body.add_child(choice)
	var quantity: SpinBox = SpinBox.new()
	quantity.value_changed.connect(func(_value: float) -> void: calls += 100)
	app.menu._body.add_child(quantity)
	UI._guard_controls(app)

func start() -> void:
	Busy.run(app, UI._origin_guard(app.menu), "SAVING SHARED DRAFT…", work, finish)

func work() -> Dictionary:
	calls += 1
	check(Busy.busy(app.menu), "lock holds during synchronous durable work")
	check(app.has_node("SharedStadiumProcessing"), "processing overlay exists before work")
	check(app.notice.is_empty(), "no success before durable result")
	if not screenshot.is_empty() and DisplayServer.get_name() != "headless":
		check(get_viewport().get_texture().get_image().save_png(screenshot) == OK, "painted busy frame captured before work")
		screenshot = ""
	return {"ok": success, "error": "Exact owner needs recovery."}

func finish(result: Dictionary) -> void:
	completed += 1
	check(Busy.busy(app.menu), "lock remains through completion and queued input drain")
	# Model input deferred during blocked IO; it must still see the busy barrier.
	UI._route_action(app, start).call_deferred()
	app.notice = "Saved." if result.ok else result.error

func settle() -> void:
	# The helper may await post-draw on a native renderer.
	while is_instance_valid(app) and Busy.busy(app.menu):
		await get_tree().process_frame
	for frame in range(3):
		await get_tree().process_frame

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--processing-screenshot="):
			screenshot = arg.trim_prefix("--processing-screenshot=")
	app = ProbeApp.new()
	add_child(app)
	app.menu = SeasonMenu.new()
	app.add_child(app.menu)
	screen()
	var button: Button = app.menu._footer.get_child(0)
	var save: Callable = button.pressed.get_connections()[0].callable
	var choice: OptionButton = app.menu._body.get_child(0)
	var pick: Callable = choice.item_selected.get_connections()[0].callable
	var quantity: SpinBox = app.menu._body.get_child(1)
	var change: Callable = quantity.value_changed.get_connections()[0].callable
	var confirm: Callable = UI._route_action(app, start)
	confirm.call()
	check(Busy.busy(app.menu) and calls == 0 and completed == 0, "busy locks synchronously before work is queued")
	check(button.disabled and choice.disabled and not quantity.editable, "buttons selectors and quantity visibly disabled")
	confirm.call()
	save.call()
	pick.call(1)
	change.call(1.0)
	start()
	check(calls == 0, "duplicate confirmation and retained controls do not activate during busy")
	await settle()
	check(calls == 1 and completed == 1 and app.notice == "Saved.", "one durable call and success after its result")
	check(not Busy.busy(app.menu) and not button.disabled and not choice.disabled and quantity.editable, "lock and original enabled states restore")
	check(app.menu._footer.get_child(1).disabled, "original disabled state stays disabled")
	confirm.call()
	await settle()
	check(calls == 1, "already-used confirmation stays inert on same body")

	app.notice = ""
	success = false
	var failed: Callable = UI._route_action(app, start)
	failed.call()
	await settle()
	check(calls == 2 and completed == 2 and app.notice == "Exact owner needs recovery.", "error result remains visible without false success")
	check(not Busy.busy(app.menu) and not button.disabled, "failure releases controls for explicit retry or recovery")
	failed.call()
	await settle()
	check(calls == 2, "failed confirmation cannot be replayed")
	app.notice = ""
	success = true
	start()
	await settle()
	check(calls == 3 and completed == 3, "new explicit action can retry after failure")

	app.notice = ""
	start()
	screen()
	var replacement: Control = app.menu._body
	await settle()
	check(calls == 3 and completed == 3 and app.menu._body == replacement, "origin replacement during paint yield abandons work")
	check(not Busy.busy(app.menu) and not app.menu._footer.get_child(0).disabled, "abandoned cleanup leaves replacement controls enabled")
	save.call()
	pick.call(1)
	change.call(1.0)
	confirm.call()
	check(calls == 3, "freed-origin callbacks stay inert")
	start()
	app.free()
	await settle()
	check(calls == 3 and completed == 3, "freed app during yield performs no work or completion")
	print("SHARED_STADIUM_PROCESSING checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

extends Node
## No owner/save access: shared wrappers protect the real reusable control callbacks.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
class ProbeApp extends Node:
	var menu: SeasonMenu
	var prompt: String
	var action: Callable
	func _confirm(message: String, destination: Callable) -> void:
		prompt = message
		action = destination
var checks: int = 0
var failures: int = 0
var calls: int = 0
var draft: Dictionary
var app: ProbeApp
var menu: SeasonMenu
var stock: StadiumStock

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func screen(page: String = "shared_stadium") -> void:
	if menu._body != null:
		menu.remove_child(menu._body)
		menu._body.queue_free()
		menu.remove_child(menu._footer)
		menu._footer.queue_free()
	menu.page = page
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	menu._footer = HBoxContainer.new()
	menu.add_child(menu._footer)

func capture(next: Dictionary, revision: int) -> void:
	check(revision == 17, "current callback retains exact revision")
	draft = next
	calls += 1
	screen()

func visit() -> void:
	calls += 1
	screen("shared_stadium_catalog")

func selection(kind: String, enabled: bool = true) -> OptionButton:
	screen()
	var panel: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(panel)
	match kind:
		"seating":
			StadiumSeatingEditorUI.card(menu, panel, draft, "synthetic-seat", "ST-080", 17, enabled, "backyard", capture)
		"appearance":
			StadiumFieldStylesUI._selector(menu, panel, draft, stock, "line", 17, enabled, capture)
		"target":
			StadiumTargetItemsUI.card(menu, panel, draft, "synthetic-target", 17, enabled, capture)
	UI._guard_controls(app)
	return panel.find_children("*", "OptionButton", true, false)[0]

func callback(value: Signal) -> Callable:
	return value.get_connections()[0].callable

func _ready() -> void:
	app = ProbeApp.new()
	add_child(app)
	menu = SeasonMenu.new()
	app.menu = menu
	app.add_child(menu)
	stock = StadiumStock.new_club()
	stock.styles = ["ST-062a"]
	draft = StadiumHomeLayout.upgrade(StadiumStarterLayout.empty())
	for kind: String in ["seating", "appearance", "target"]:
		var control: OptionButton = selection(kind, false)
		var stale: Callable = callback(control.item_selected)
		var before: int = calls
		stale.call(1)
		check(calls == before, kind + " disabled captured selector is inert")
		control.disabled = false
		control.set_item_disabled(1, true)
		stale.call(1)
		stale.call(-1)
		stale.call(999)
		check(calls == before, kind + " disabled item and bad indexes are inert")
		control.set_item_disabled(1, false)
		stale.call(1)
		check(calls == before + 1, kind + " current callback works")
		var newer: Control = menu._body
		var next: Dictionary = draft.duplicate(true)
		stale.call(0)
		check(calls == before + 1 and menu._body == newer and draft == next, kind + " retired callback cannot overwrite newer edit")
		await get_tree().process_frame
		stale.call(0)
		check(calls == before + 1 and menu._body == newer, kind + " freed control callback is inert")
		control = selection(kind)
		stale = callback(control.item_selected)
		screen()
		newer = menu._body
		stale.call(1)
		check(calls == before + 1 and menu._body == newer, kind + " same-page rerender retires callbacks")
		control = selection(kind)
		stale = callback(control.item_selected)
		screen("shared_stadium_catalog")
		screen()
		newer = menu._body
		stale.call(1)
		check(calls == before + 1 and menu._body == newer, kind + " away/back does not revive callbacks")

	screen()
	var navigation: Button = menu._button(menu._body, "Catalog", UI._navigate.bind(app, true, visit))
	var purchase: Button = menu._button(menu._footer, "Buy", visit)
	purchase.disabled = true
	var quantity: SpinBox = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 64
	menu._body.add_child(quantity)
	quantity.value_changed.connect(func(_value: float) -> void: visit())
	UI._guard_controls(app)
	var old_navigation: Callable = callback(navigation.pressed)
	var old_purchase: Callable = callback(purchase.pressed)
	var old_quantity: Callable = callback(quantity.value_changed)
	var before: int = calls
	old_purchase.call()
	check(calls == before, "disabled purchase never invokes transaction action")
	quantity.editable = false
	old_quantity.call(2.0)
	quantity.editable = true
	for value: float in [0.0, 65.0, 1.5, NAN, INF]:
		old_quantity.call(value)
	check(calls == before, "disabled, nonfinite and invalid quantities are inert")
	old_navigation.call()
	check(calls == before and app.prompt.contains("Discard unsaved"), "dirty route waits for confirmation")
	var discarded: Callable = app.action
	app.action = Callable()
	check(calls == before, "cancel keeps dirty preview")
	screen()
	var replacement: Control = menu._body
	discarded.call()
	old_navigation.call()
	old_purchase.call()
	old_quantity.call(2.0)
	check(calls == before and menu._body == replacement, "retired discard, navigation, transaction and quantity callbacks are inert")
	await get_tree().process_frame
	discarded.call()
	old_navigation.call()
	old_purchase.call()
	old_quantity.call(2.0)
	check(calls == before and menu._body == replacement, "freed routes are inert without accessing deleted controls")
	UI._navigate(app, true, visit)
	app.action.call()
	check(calls == before + 1 and menu.page == "shared_stadium_catalog", "current discard confirmation still navigates")
	var after: Control = menu._body
	app.action.call()
	check(calls == before + 1 and menu._body == after, "retired confirmation cannot execute twice")
	var stale_preview: Callable = UI._preview.bind(app, menu._body)
	screen("shared_stadium_catalog")
	stale_preview.call(draft, 17)
	check(menu.page == "shared_stadium_catalog", "direct captured preview route is rejected before authority access")
	await get_tree().process_frame
	stale_preview.call(draft, 17)
	check(menu.page == "shared_stadium_catalog", "direct freed preview route is inert")
	app.free()
	old_navigation.call()
	old_purchase.call()
	old_quantity.call(2.0)
	print("SHARED_ROUTE_CONTROLS checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

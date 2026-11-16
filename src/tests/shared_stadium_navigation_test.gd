extends Node
## No owner/save access: exercise the exact discard guard used by workshop routes.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
class PreviewApp extends Node:
	var menu: SeasonMenu
	var prompt: String = ""
	var action: Callable
	var visits: int = 0
	func _confirm(message: String, destination: Callable) -> void:
		prompt = message
		action = destination
	func visit() -> void:
		visits += 1
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	var app: PreviewApp = PreviewApp.new()
	add_child(app)
	app.menu = SeasonMenu.new()
	app.add_child(app.menu)
	app.menu._body = VBoxContainer.new()
	app.menu.add_child(app.menu._body)
	UI._navigate(app, false, app.visit)
	check(app.visits == 1 and app.prompt.is_empty(), "clean preview navigates directly")
	for route: String in ["catalog", "upgrades", "reload", "club record"]:
		var before: int = app.visits
		UI._navigate(app, true, app.visit)
		check(app.visits == before, route + " does not discard before confirmation")
		check(app.prompt.contains("Discard unsaved"), route + " explains discard")
		# Cancel closes the dialog without executing its stored action.
		app.action = Callable()
		check(app.visits == before, route + " cancellation retains preview")
		UI._navigate(app, true, app.visit)
		app.action.call()
		check(app.visits == before + 1, route + " confirmation navigates once")
	app.free()
	print("SHARED_STADIUM_NAVIGATION checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

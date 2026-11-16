extends Node
## Read-only preview button routing; no owner, save, geometry or gameplay mutation.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
class ProbePreview extends StadiumDraftPreview:
	var overviews: int = 0
	var lighting_changes: int = 0
	var focused: Array[String] = []
	func overview(_reveal: bool = true) -> void:
		overviews += 1
	func toggle_environment() -> void:
		lighting_changes += 1
	func focus_copy(id: String) -> void:
		focused.append(id)
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var menu: SeasonMenu = SeasonMenu.new()
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	var preview: ProbePreview = ProbePreview.new()
	menu._body.add_child(preview)
	preview.positions = {"pole-b": Vector3.ZERO, "pole-a": Vector3.ONE}
	preview.items = {"pole-b": "ST-037", "pole-a": "ST-037"}
	UI._preview_controls(menu, preview)
	var buttons: Array[Node] = menu._body.get_children().filter(func(node: Node) -> bool: return node is Button)
	check(buttons.size() == 3, "daylight field gets overview and exact placed copies only")
	check(buttons[0].get_meta("shared_preview_action") == "overview", "overview comes first")
	buttons[0].pressed.emit()
	check(preview.overviews == 1, "overview button reaches same preview")
	buttons[1].pressed.emit()
	buttons[2].pressed.emit()
	check(preview.focused == ["pole-a", "pole-b"], "sorted focus buttons bind distinct exact copies")
	preview.night_eligible = true
	UI._preview_controls(menu, preview)
	buttons = menu._body.get_children().filter(func(node: Node) -> bool: return node is Button)
	check(buttons.size() == 7, "qualified field additionally exposes lighting preview")
	check(buttons[4].text == "DAY / NIGHT PREVIEW", "night label does not claim schedule change")
	buttons[4].pressed.emit()
	check(preview.lighting_changes == 1, "lighting preview routes to same private world")
	var prior: VBoxContainer = menu._body
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	buttons[0].pressed.emit()
	buttons[4].pressed.emit()
	buttons[5].pressed.emit()
	check(preview.overviews == 1 and preview.lighting_changes == 1 and preview.focused.size() == 2,
		"detached screen callbacks leave old and new views alone")
	prior.remove_child(preview)
	buttons[0].pressed.emit()
	check(preview.overviews == 1, "retired preview callback is inert")
	preview.free()
	menu.free()
	print("SHARED_PREVIEW_CONTROLS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

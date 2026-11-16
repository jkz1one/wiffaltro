extends RefCounted
## Presentation only. No game/save authority and no progress estimate.


static func show(owner: Node, message: String) -> CanvasLayer:
	var canvas := CanvasLayer.new()
	canvas.layer = 120
	owner.add_child(canvas)
	var cover := ColorRect.new()
	cover.color = Color(0.025, 0.045, 0.04, 1.0)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.focus_mode = Control.FOCUS_ALL
	canvas.add_child(cover)
	cover.focus_next = NodePath(".")
	cover.focus_previous = NodePath(".")
	for direction: String in ["top", "bottom", "left", "right"]:
		cover.set("focus_neighbor_" + direction, NodePath("."))
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(label)
	var previous: Control = owner.get_viewport().gui_get_focus_owner()
	if previous != null:
		previous.release_focus()
	cover.grab_focus()
	return canvas


static func remove(canvas: CanvasLayer) -> void:
	if is_instance_valid(canvas):
		canvas.free()

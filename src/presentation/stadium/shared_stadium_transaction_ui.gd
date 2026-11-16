extends RefCounted
## Presentation lock only. Durable authority, commands and retries stay in Access.
const BUSY: StringName = &"shared_stadium_processing"


static func busy(menu: Variant) -> bool:
	return is_instance_valid(menu) and menu.has_meta(BUSY)


static func run(app: Node, attached: Callable, message: String, work: Callable, completed: Callable) -> void:
	if not is_instance_valid(app) or not attached.call() or busy(app.menu):
		return
	var app_ref: WeakRef = weakref(app)
	var menu_ref: WeakRef = weakref(app.menu)
	var token: RefCounted = RefCounted.new()
	app.menu.set_meta(BUSY, token)
	var controls: Array[Dictionary] = []
	for parent: Control in [app.menu._body, app.menu._footer]:
		for control: Node in parent.find_children("*", "Control", true, false):
			if control is BaseButton:
				controls.append({"node": weakref(control), "property": "disabled", "value": control.disabled})
				control.disabled = true
			elif control is SpinBox:
				controls.append({"node": weakref(control), "property": "editable", "value": control.editable})
				control.editable = false
	# Replace the confirmation immediately; its old OK/Cancel must not look live.
	if app is SeasonApp and is_instance_valid(app._dialog):
		app._dialog.hide()
	var overlay: CanvasLayer = _overlay(app, message)
	var overlay_ref: WeakRef = weakref(overlay)
	var tree: SceneTree = app.get_tree()
	# A process-frame alone resumes before drawing. Wait for a rendered frame on
	# desktop so this static status is visible throughout synchronous durable IO.
	await tree.process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	if is_instance_valid(app_ref.get_ref()) and attached.call():
		var result: Dictionary = work.call()
		if is_instance_valid(app_ref.get_ref()) and attached.call():
			completed.call(result)
		# Keep the barrier through a complete input/deferred pass: clicks queued while
		# synchronous IO blocked the thread must not land on the refreshed page.
		await tree.process_frame
		await tree.process_frame
	# An abandoned/freed origin never commits. Restore only the exact old controls;
	# newer pages and their enabled states are not changed by cleanup.
	for row: Dictionary in controls:
		var control: Object = row.node.get_ref()
		if is_instance_valid(control):
			control.set(row.property, row.value)
	var menu: Object = menu_ref.get_ref()
	if is_instance_valid(menu) and menu.get_meta(BUSY, null) == token:
		menu.remove_meta(BUSY)
	var live_overlay: CanvasLayer = overlay_ref.get_ref()
	if is_instance_valid(live_overlay):
		live_overlay.hide()
		live_overlay.queue_free()


static func _overlay(app: Node, message: String) -> CanvasLayer:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "SharedStadiumProcessing"
	layer.layer = 100
	app.add_child(layer)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.025, 0.04, 0.065, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.focus_mode = Control.FOCUS_ALL
	layer.add_child(shade)
	shade.grab_focus()
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var label: Label = Label.new()
	label.text = message + "\n\nSaving the shared club record. This may take a minute.\nPlease wait. Do not close the game.\nCurrent and paused season fields stay unchanged."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 23)
	label.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(label)
	return layer

class_name SeasonLoadoutUI
extends CanvasLayer
## One consistent utility entry and modal across season, shop and managed matches.

var app: SeasonApp
var shop: SeasonShopWindow
var match_snapshot: Dictionary = {}
var entry: Button
var shade: ColorRect
var panel: PanelContainer
var tabs: HBoxContainer
var scroll: ScrollContainer
var body: VBoxContainer
var close_button: Button
var sale: SeasonLoadoutSale
var context: Label
var cash_badge: Label
var _sale_buttons: Array[Button] = []
var _tab: String = "gear"
var _rows: Dictionary = {}
var _tab_buttons: Array[Button] = []
var _previous_focus: WeakRef
var _paused_lab: PitchBatLab
var _was_paused: bool = false
var _was_tree_paused: bool = false


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = ClubhouseTheme.create()
	add_child(root)
	entry = Button.new()
	entry.name = "EquippedEntry"
	entry.text = "EQUIPPED"
	entry.tooltip_text = "Gear, sponsors, supplies and learned abilities"
	entry.custom_minimum_size = Vector2(176, 44)
	entry.pressed.connect(open)
	root.add_child(entry)
	shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.025, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_outside_input)
	root.add_child(shade)
	panel = PanelContainer.new()
	panel.name = "EquippedLightbox"
	panel.add_theme_stylebox_override("panel", ClubhouseTheme.surface(false, 20))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.add_child(panel)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)
	var heading: HBoxContainer = HBoxContainer.new()
	layout.add_child(heading)
	var title: Label = _label(heading, "YOUR LOADOUT", 26)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cash_badge = _label(heading, "", 18)
	cash_badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	cash_badge.add_theme_color_override("font_color", ClubhouseTheme.GREEN)
	cash_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_constant_override("separation", 16)
	close_button = Button.new()
	close_button.text = "CLOSE  Esc"
	close_button.custom_minimum_size = Vector2(132, 44)
	close_button.pressed.connect(close)
	heading.add_child(close_button)
	context = _label(layout, "", 16)
	context.add_theme_color_override("font_color", ClubhouseTheme.MUTED)
	tabs = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	layout.add_child(tabs)
	for key: String in ["gear", "sponsors", "supplies", "abilities"]:
		var button: Button = Button.new()
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		button.pressed.connect(_select.bind(key))
		button.set_meta("loadout_tab", key)
		tabs.add_child(button)
		_tab_buttons.append(button)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(scroll)
	var focus_controls: Array[Control] = [close_button]
	focus_controls.append_array(_tab_buttons)
	focus_controls.append(scroll)
	for index in range(focus_controls.size()):
		var control: Control = focus_controls[index]
		var previous: NodePath = control.get_path_to(
			focus_controls[posmod(index - 1, focus_controls.size())]
		)
		var following: NodePath = control.get_path_to(
			focus_controls[(index + 1) % focus_controls.size()]
		)
		control.focus_neighbor_top = previous
		control.focus_neighbor_left = previous
		control.focus_neighbor_bottom = following
		control.focus_neighbor_right = following
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	var footer: Label = _label(
		layout, "Sell Gear and sponsors during games. Buy and replace in the Season Shop.", 14
	)
	footer.add_theme_color_override("font_color", ClubhouseTheme.MUTED)
	sale = SeasonLoadoutSale.new()
	sale.ui = self
	add_child(sale)
	shade.hide()
	_resize()
	get_viewport().size_changed.connect(_resize)


func _process(_delta: float) -> void:
	# Wrapped text resolves its minimum size after the container layout pass.
	context.visible = not context.text.is_empty()
	_resize()
	entry.visible = shop != null or app.season != null or app.lab != null
	entry.disabled = shade.visible or _blocked()


func _blocked() -> bool:
	if shop != null:
		return shop._confirm.visible
	if app._dialog.visible:
		return true
	for child: Node in app.menu.get_children():
		if child is SeasonShopWindow and child.visible:
			return true
	if app.lab != null:
		if SeasonEncoreUI.reviewing(app.lab):
			return true
		var tactics: MatchTacticalControls = app.lab.get_node_or_null("TacticalControls")
		return tactics != null and tactics._dialog.visible
	return false


func open() -> void:
	if shade.visible or _blocked():
		return
	_previous_focus = weakref(get_viewport().gui_get_focus_owner())
	_rows = SeasonLoadoutData.pages(app)
	_paused_lab = app.lab
	if _paused_lab != null:
		_was_paused = _paused_lab._debug_paused
		_was_tree_paused = get_tree().paused
		_paused_lab.set_meta("loadout_open", true)
		if _paused_lab._release_controller.active:
			PitchBatLabFeelSupport.cancel_release(_paused_lab)
		_paused_lab._debug_paused = true
		get_tree().paused = true
	context.text = (
		"GAME PAUSED • Your club's current equipment and remaining supplies"
		if _paused_lab != null
		else ""
	)
	context.visible = not context.text.is_empty()
	shade.show()
	_select(_tab)
	_resize()
	close_button.grab_focus()


func close(restore_focus: bool = true) -> void:
	if not shade.visible:
		return
	sale.hide()
	shade.hide()
	entry.disabled = _blocked()
	var resumed_match: bool = is_instance_valid(_paused_lab) and not _was_paused
	if is_instance_valid(_paused_lab) and _paused_lab.is_inside_tree():
		_paused_lab.remove_meta("loadout_open")
		_paused_lab._debug_paused = _was_paused
		get_tree().paused = _was_tree_paused
		_paused_lab._refresh_config()
	_paused_lab = null
	if not restore_focus:
		return
	if resumed_match:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null:
			focused.release_focus()
		return
	var target: Control = _previous_focus.get_ref() if _previous_focus != null else null
	if is_instance_valid(target) and target.is_inside_tree() and target.is_visible_in_tree():
		target.grab_focus()
	elif entry.is_visible_in_tree():
		entry.grab_focus()


func _exit_tree() -> void:
	if shade != null and shade.visible:
		close(false)
	if get_viewport() != null and get_viewport().size_changed.is_connected(_resize):
		get_viewport().size_changed.disconnect(_resize)


func _input(event: InputEvent) -> void:
	if not shade.visible:
		return
	if sale.visible:
		return
	var pad_cancel: bool = (
		event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B
	)
	if event.is_action_pressed(&"ui_cancel") or pad_cancel:
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_cycle_focus(event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
			scroll.scroll_vertical += -200 if event.keycode == KEY_PAGEUP else 200
			get_viewport().set_input_as_handled()
	# Other input is consumed by the modal, never by match keyboard shortcuts.


func _cycle_focus(backward: bool) -> void:
	var controls: Array[Control] = [close_button]
	controls.append_array(_tab_buttons)
	controls.append(scroll)
	controls.append_array(_sale_buttons)
	var current: int = controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(current + (-1 if backward else 1), controls.size())].grab_focus()


func _outside_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
		get_viewport().set_input_as_handled()


func _resize() -> void:
	if not is_inside_tree() or get_viewport() == null:
		return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	entry.position = Vector2((extent.x - 176) / 2.0, extent.y - 52)
	entry.size = Vector2(176, 44)
	panel.size = Vector2(minf(900, extent.x - 32), minf(552, extent.y - 32))
	panel.position = (extent - panel.size) / 2.0


func _select(key: String) -> void:
	_refresh_balance()
	_sale_buttons.clear()
	_tab = key
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for button: Button in _tab_buttons:
		var id: String = button.get_meta("loadout_tab")
		var count: int = _rows[id].size()
		button.text = id.capitalize() + "  " + str(count)
		button.set_pressed_no_signal(id == key)
	if key == "supplies":
		_label(body, "%d / %d held slots" % [_rows.supplies.size(), _rows.capacity.held], 16)
	elif key == "abilities":
		_label(body, "One Hitting + one Fielding slot per player • Season only • Not sellable", 16)
	elif key == "sponsors":
		_label(
			body, "%d / %d active sponsors" % [_rows.sponsors.size(), _rows.capacity.sponsors], 16
		)
	for row: Dictionary in _rows[key]:
		_card(row)
	if _rows[key].is_empty():
		var empty: Dictionary = {
			"sponsors": "No active sponsors yet.",
			"supplies": "No supplies held.",
			"abilities": "No learned abilities yet."
		}
		_label(body, empty.get(key, "No items equipped."), 22)
		_label(body, "Available items appear in the Season Shop.", 16)
	if key == "supplies" and not _rows.used.is_empty():
		_label(body, "USED THIS GAME • Already spent", 16)
		for row: Dictionary in _rows.used:
			_card(row)
	scroll.scroll_vertical = 0


func _card(row: Dictionary) -> void:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", ClubhouseTheme.surface(false, 14))
	body.add_child(card)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	card.add_child(stack)
	var tag: Label = _label(stack, row.label, 14)
	tag.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 12)
	stack.add_child(heading)
	var title: Label = _label(heading, row.name, 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sale_action(heading, row)
	_label(stack, row.effect, 17)
	var status: Label = _label(stack, row.status, 14)
	status.add_theme_color_override(
		"font_color", ClubhouseTheme.RED if row.status.begins_with("SOLD") else ClubhouseTheme.MUTED
	)


func _sale_action(parent: Node, row: Dictionary) -> void:
	var receipt: String = row.get("receipt", "")
	if not can_sell() or receipt.is_empty() or app.sales.pending.has(receipt):
		return
	var owned: Dictionary = SeasonOwnership._owned(app.season.build.view().wallet, receipt)
	if owned.is_empty():
		return
	var refund: int = (
		SeasonSponsorCatalog.resale(owned) if owned.kind == "sponsor" else int(owned.paid / 2)
	)
	var button: Button = Button.new()
	button.text = "SELL • %d Cash" % refund
	button.tooltip_text = "Review this sale before confirming."
	button.custom_minimum_size = Vector2(152, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(sale.review.bind(receipt, row.name))
	parent.add_child(button)
	_sale_buttons.append(button)


func _refresh_balance() -> void:
	# An exhibition must not advertise the separate saved season's wallet.
	cash_badge.visible = (
		app.season != null and app.season.build != null and (app.lab == null or app._season_game)
	)
	if cash_badge.visible:
		cash_badge.text = "%d Cash" % app.season.cash()


func can_sell() -> bool:
	return (
		SeasonMatchSales.available(app)
		or (
			shop != null
			and app.lab == null
			and app.season != null
			and app.season.shop_available()
			and app.season.build._visit.open
			and not app.season.build.pack_pending()
		)
	)


static func _label(parent: Node, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

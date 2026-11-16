class_name SeasonLoadoutUI
extends CanvasLayer
## One consistent utility entry and modal across season, shop and managed matches.

const LoadoutGlyph = preload("res://src/presentation/season/season_loadout_glyph.gd")

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
var _player_buttons: Array[Button] = []
var _item_buttons: Array[Button] = []
var _grid: HFlowContainer
var _detail: PanelContainer
var _detail_stack: VBoxContainer
var _selected_identity: String = ""
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
	if (
		app._dialog.visible
		or (
			app.season != null
			and app.season.physical != null
			and not app.season.physical.pending.is_empty()
		)
	):
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
	context.text = ("PAUSED" if _paused_lab != null else "")
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
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		_cycle_focus(false)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		_cycle_focus(true)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		var target: Button = get_viewport().gui_get_focus_owner() as Button
		if target != null and not target.disabled and panel.is_ancestor_of(target):
			get_viewport().set_input_as_handled()
			target.pressed.emit()
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
	controls.append_array(_player_buttons)
	controls.append_array(_item_buttons)
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
	_player_buttons.clear()
	_item_buttons.clear()
	if _tab != key:
		_selected_identity = ""
	_tab = key
	_detail_stack = null
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	for button: Button in _tab_buttons:
		var id: String = button.get_meta("loadout_tab")
		var count: int = _rows[id].size()
		button.text = id.capitalize() + "  " + str(count)
		button.set_pressed_no_signal(id == key)
	if key == "supplies":
		_label(body, "%d / %d supplies" % [_rows.supplies.size(), _rows.capacity.held], 16)
	elif key == "abilities":
		var team: TeamMatchState
		if app.lab != null and app.lab._match_state != null:
			var state: MatchState = app.lab._match_state
			team = state.home_team if app.lab._player_home else state.away_team
		var players: Array[PlayerDefinition] = SeasonAbilityLoadout.players(app, team)
		var capacity_text: String = "1 Hitting + 1 Fielding per player"
		for player: PlayerDefinition in players:
			if String(player.id) == _rows.get("major_player", ""):
				capacity_text = (
					"1 Hitting per player • 1 Fielding by default\n"
					+ "%s: 2 Fielding • Double Major" % player.display_name
				)
		_label(body, capacity_text, 16)
		for player: PlayerDefinition in players:
			_player_buttons.append(
				SeasonPlayerCard.inspection_button(body, player, "INSPECT " + player.display_name)
			)
	elif key == "sponsors":
		_label(
			body, "%d / %d active sponsors" % [_rows.sponsors.size(), _rows.capacity.sponsors], 16
		)
	_grid = HFlowContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	body.add_child(_grid)
	for row: Dictionary in _rows[key]:
		_card(row)
	if key == "gear" and _rows.get("equipment_league", false):
		_card(_rows.spare)
	_detail = PanelContainer.new()
	_detail.name = "HighlightedItemDetail"
	_detail.add_theme_stylebox_override("panel", ClubhouseTheme.surface(true, 12))
	body.add_child(_detail)
	_detail_stack = VBoxContainer.new()
	_detail_stack.add_theme_constant_override("separation", 5)
	_detail.add_child(_detail_stack)
	_detail.visible = not _item_buttons.is_empty()
	if not _item_buttons.is_empty():
		var selected: Button = _item_buttons[0]
		for candidate: Button in _item_buttons:
			if candidate.get_meta("loadout_identity") == _selected_identity:
				selected = candidate
				break
		_highlight(selected, true)
	if _rows[key].is_empty():
		var empty: Dictionary = {
			"sponsors": "No active sponsors yet.",
			"supplies": "No supplies remaining.",
			"abilities": "No learned abilities yet."
		}
		_label(body, empty.get(key, "No items equipped."), 22)
	scroll.scroll_vertical = 0


func _card(row: Dictionary) -> void:
	# Selection is attached to the paid copy, never an array offset.
	var tile: Button = Button.new()
	tile.custom_minimum_size = Vector2(120, 106)
	tile.clip_contents = true
	tile.set_meta("loadout_row", row.duplicate(true))
	tile.set_meta("loadout_identity", _identity(row))
	tile.set_meta("loadout_name", row.name)
	tile.mouse_entered.connect(_highlight.bind(tile))
	tile.focus_entered.connect(_highlight.bind(tile))
	tile.pressed.connect(_activate_tile.bind(tile))
	_grid.add_child(tile)
	_item_buttons.append(tile)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 6
	stack.offset_right = -6
	stack.offset_top = 5
	stack.offset_bottom = -5
	stack.add_theme_constant_override("separation", 2)
	tile.add_child(stack)
	var inactive: bool = row.get("inactive_spare", false)
	var badge: String = "INACTIVE SPARE" if inactive else str(row.label).to_upper()
	if _tab == "sponsors":
		badge = "SPONSOR"
	elif _tab == "supplies":
		badge = "SUPPLY"
	if inactive:
		tile.tooltip_text = (
			"Swap between games."
			if inventory_sales_enabled()
			else "Swap or sell in the shop between games."
		)
	if _tab == "abilities":
		badge = str(row.label).get_slice(" • ", 0)
	if str(row.status).begins_with("SOLD"):
		badge = "SOLD • RETIRING"
	var tag: Label = _label(stack, badge, 11)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var glyph = LoadoutGlyph.new()
	glyph.category = _tab if _tab != "gear" else str(row.label).to_lower()
	if inactive:
		glyph.category = str(row.label).get_slice(" • ", 1).to_lower()
	glyph.inactive = inactive
	stack.add_child(glyph)
	var caption: Label = _label(stack, row.name, 13)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.max_lines_visible = 2
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _identity(row: Dictionary) -> String:
	var receipt: String = row.get("receipt", "")
	if not receipt.is_empty():
		return _tab + ":" + receipt
	return _tab + ":" + str(row.label) + ":" + str(row.name)


func _activate_tile(tile: Button) -> void:
	_highlight(tile)
	# A tap/activation reveals the detail and actions even on a short viewport.
	# Hover and focus do not scroll the icon out from underneath the pointer.
	_reveal_detail(_selected_identity)


func _reveal_detail(identity: String) -> void:
	# Wait for wrapped detail text to resolve before measuring its scroll bounds.
	await get_tree().process_frame
	await get_tree().process_frame
	if shade.visible and _selected_identity == identity and is_instance_valid(_detail):
		scroll.ensure_control_visible(_detail)


func _highlight(tile: Button, rebuilding: bool = false) -> void:
	if (
		(sale.visible and not rebuilding)
		or not is_instance_valid(_detail_stack)
		or not is_instance_valid(tile)
	):
		return
	var identity: String = tile.get_meta("loadout_identity")
	if _selected_identity == identity and _detail_stack.get_child_count() > 0:
		return
	_selected_identity = identity
	for button: Button in _item_buttons:
		button.add_theme_stylebox_override("normal", ClubhouseTheme.surface(button == tile, 6))
	_sale_buttons.clear()
	for child: Node in _detail_stack.get_children():
		_detail_stack.remove_child(child)
		child.queue_free()
	var row: Dictionary = tile.get_meta("loadout_row")
	var tag: Label = _label(_detail_stack, row.label, 13)
	tag.add_theme_color_override("font_color", ClubhouseTheme.GOLD)
	_label(_detail_stack, row.name, 22)
	_label(_detail_stack, row.effect, 16)
	var status_text: String = str(row.status).trim_prefix("Working • ")
	if status_text in ["Working", "Base"]:
		status_text = ""
	if not status_text.is_empty():
		var status: Label = _label(_detail_stack, status_text, 13)
		status.add_theme_color_override(
			"font_color",
			ClubhouseTheme.RED if status_text.begins_with("SOLD") else ClubhouseTheme.MUTED
		)
	# A separate action row wraps naturally at narrow widths and remains in the
	# same scroll surface; no floating tooltip obscures the tile or confirmation.
	var actions: HFlowContainer = HFlowContainer.new()
	_detail_stack.add_child(actions)
	_sale_action(actions, row)


func _sale_action(parent: Node, row: Dictionary) -> void:
	if _tab not in ["gear", "sponsors", "supplies"]:
		return
	var receipt: String = row.get("receipt", "")
	var modern: bool = inventory_sales_enabled()
	if _tab == "supplies" and not modern:
		return
	if (
		row.get("inactive_spare", false)
		and not modern
		and (shop == null or not shop.spare_actions_available())
	):
		return
	_sale_action_remaining_checks(parent, row, receipt, modern)


func _sale_action_remaining_checks(
	parent: Node,
	row: Dictionary,
	receipt: String,
	modern: bool
) -> void:
	if not can_sell() or receipt.is_empty() or app.sales.pending.has(receipt):
		return
	var build: SeasonBuild = app.season.build
	var owned: Dictionary = SeasonMatchSales.copy_for(app, receipt)
	if owned.is_empty():
		# Neither an owned nor an actual current runtime copy exists.
		return
	var refund: int
	if modern:
		var quote: Dictionary = SeasonLoadoutSale.quote_for(self, receipt)
		if not quote.get("ok", false):
			return
		refund = int(quote.refund)
		if row.get("inactive_spare", false) or _tab == "supplies":
			# Controller capability gates unsafe boundaries and unqualified live
			# supply adapters; a bank quote is never sufficient by itself.
			var request: Dictionary = SeasonLoadoutSale.command_for(self, receipt)
			if request.is_empty() or not build.preview(request).get("ok", false):
				return
	else:
		refund = (
			SeasonSponsorCatalog.resale(owned) if owned.kind == "sponsor" else int(owned.paid / 2)
		)
	var button: Button = Button.new()
	button.text = "SELL • %d Cash" % refund
	button.tooltip_text = "Review this sale before confirming."
	button.custom_minimum_size = Vector2(152, 44)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 16)
	button.set_meta("sale_receipt", receipt)
	if row.get("inactive_spare", false) and not modern:
		button.pressed.connect(_review_spare_sale.bind(receipt, row.name, refund))
	else:
		button.pressed.connect(sale.review.bind(receipt, row.name))
	parent.add_child(button)
	_sale_buttons.append(button)


func _review_spare_sale(receipt: String, item_name: String, refund: int) -> void:
	if shop == null or not shop.spare_actions_available():
		return
	if not SeasonEquipment.is_spare(app.season.build, receipt):
		context.text = "The spare changed. Review the current inventory before selling."
		_rows = SeasonLoadoutData.pages(app)
		_select(_tab)
		return
	close(false)
	shop._preview(
		shop._request("sell_gear", {"receipt": receipt}),
		(
			"Sell inactive spare %s for %d Cash.\nYour active equipment and effects stay unchanged."
			% [item_name, refund]
		)
	)


func _refresh_balance() -> void:
	# An exhibition must not advertise the separate saved season's wallet.
	cash_badge.visible = (
		app.season != null and app.season.build != null and (app.lab == null or app._season_game)
	)
	if cash_badge.visible:
		cash_badge.text = "%d Cash" % app.season.cash()


func inventory_sales_enabled() -> bool:
	return (
		app.season != null
		and app.season.build != null
		and SeasonInventoryResale.enabled(app.season.build._bank)
	)


func can_sell() -> bool:
	if (
		app.lab == null
		and inventory_sales_enabled()
		and SeasonInventoryRules.menu_available(app.season.build)
	):
		return true
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

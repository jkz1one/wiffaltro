class_name OwnershipLab
extends Window
## Synthetic items exercise ownership only. Nothing here modifies SeasonApp.season.

var bank: SeasonOwnership
var save_path: String = "user://ownership-lab-v1.json"
var _body: VBoxContainer
var _notice: String = ""
var _pending: Dictionary = {}
var _confirm: ConfirmationDialog


func _ready() -> void:
	title = "Ownership transaction lab"
	size = Vector2i(900, 600)
	min_size = Vector2i(650, 400)
	transient = true
	close_requested.connect(queue_free)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = ClubhouseTheme.create()
	add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	scroll.add_child(_body)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Confirm transaction"
	_confirm.confirmed.connect(_commit_pending)
	_confirm.canceled.connect(func() -> void: _pending.clear())
	add_child(_confirm)
	_reset()


func _reset() -> void:
	_pending.clear()
	bank = SeasonOwnership.new(OwnershipFixtures.catalog())
	bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 0, "win": true}))
	bank.commit(
		OwnershipFixtures.request(
			bank,
			"stock",
			{
				"offers":
				{
					"bat6": "fixture.bat6",
					"bat15": "fixture.bat15",
					"free": "fixture.ball0",
					"expensive": "fixture.misc99",
					"card1": "fixture.card",
					"card2": "fixture.card",
					"card3": "fixture.card",
					"capacity": "fixture.capacity"
				}
			}
		)
	)
	_notice = "New synthetic session. Saved test snapshot has not changed."
	_refresh()


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_label("OWNERSHIP TEST LAB")
	_label("Synthetic funds/items with no gameplay effects. Your season is unchanged.")
	var view: Dictionary = bank.view()
	_label(
		(
			"Cash: %d  |  Held: %d/%d  |  Active sponsors: %d/%d"
			% [
				bank.cash(),
				view.held.size(),
				view.capacity.held,
				view.sponsors.size(),
				view.capacity.sponsors
			]
		)
	)
	_label(_notice)
	var equipped: Dictionary = view.gear.bat
	var replace: String = str(equipped.get("id", ""))
	_label("Bat: " + str(equipped.get("item", "neutral")))
	_action("Buy Bat fixture for 6", OwnershipFixtures.buy(bank, "bat6", replace))
	_action("Replace / buy Bat fixture for 15", OwnershipFixtures.buy(bank, "bat15", replace))
	_action("Claim free Ball fixture", OwnershipFixtures.buy(bank, "free"))
	_action("Attempt unaffordable Misc fixture for 99", OwnershipFixtures.buy(bank, "expensive"))
	_action("Acquire capacity sponsor fixture", OwnershipFixtures.buy(bank, "capacity"))
	for offer in ["card1", "card2", "card3"]:
		_action("Claim " + offer, OwnershipFixtures.buy(bank, offer))
	for receipt: Dictionary in view.gear.values() + view.sponsors:
		if not receipt.is_empty():
			_action(
				"Sell " + str(receipt.item),
				OwnershipFixtures.request(bank, "sell", {"receipt": receipt.id, "discard": []})
			)
	for receipt: Dictionary in view.held:
		_action(
			"Discard " + str(receipt.id),
			OwnershipFixtures.request(bank, "discard", {"receipts": [receipt.id]})
		)
	_button("Save test snapshot", _save)
	_button("Reload test snapshot", _restore)
	_button("Reset synthetic session", _reset)
	_button("Close", queue_free)


func _preview(command: Dictionary) -> void:
	var result: Dictionary = bank.preview(command)
	if not result.ok:
		_notice = result.error
		_refresh()
		return
	_pending = command.duplicate(true)
	var before: Dictionary = bank.view()
	var after: Dictionary = result.after
	var added: PackedStringArray = _changes(after, before)
	var removed: PackedStringArray = _changes(before, after)
	_confirm.dialog_text = (
		"Acquire: %s\nRemove: %s\nCash: %d → %d\nConfirm this exact transaction?"
		% [
			", ".join(added) if not added.is_empty() else "none",
			", ".join(removed) if not removed.is_empty() else "none",
			bank.cash(),
			int(after.cash)
		]
	)

	_confirm.popup_centered()


func _commit_pending() -> void:
	var result: Dictionary = bank.commit(_pending)
	_pending.clear()
	_notice = "Transaction committed. Save snapshot to test reload." if result.ok else result.error
	_refresh()


func _save() -> void:
	var ok: bool = SeasonOwnershipStore.save(bank, save_path, OwnershipFixtures.catalog())
	_notice = "Test snapshot saved." if ok else "Save failed; snapshot was not replaced."
	_refresh()


func _restore() -> void:
	var restored: SeasonOwnership = SeasonOwnershipStore.restore(
		save_path, OwnershipFixtures.catalog()
	)
	if restored != null:
		bank = restored
		_notice = "Saved test snapshot restored."
	else:
		_notice = "No valid test snapshot. Current session and files were preserved."
	if not SeasonOwnershipStore.last_error.is_empty():
		_notice = SeasonOwnershipStore.last_error
	_pending.clear()
	_refresh()


func _label(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(label)


func _button(text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	_body.add_child(button)


func _action(text: String, command: Dictionary) -> void:
	_button(text, _preview.bind(command))


static func _changes(first: Dictionary, second: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = []
	for item: Dictionary in first.gear.values() + first.sponsors + first.held:
		if item.is_empty():
			continue
		if SeasonOwnership._owned(second, item.id).is_empty():
			result.append("%s (paid %d)" % [item.item, item.paid])
	return result

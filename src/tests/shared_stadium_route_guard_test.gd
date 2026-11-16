extends "res://src/tests/shared_stadium_ui_test.gd"
## Captured real callbacks against a fresh isolated shared owner. No physical games.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
const Access = preload("res://src/presentation/stadium/stadium_career_access.gd")
var app: SeasonApp
var owner_path: String
var owner_sha256: String

func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-ui-owner="):
			owner_path = arg.trim_prefix("--shared-ui-owner=")
		if arg.begins_with("--stadium-assets-root="):
			root = arg.trim_prefix("--stadium-assets-root=")
	if owner_path.is_empty():
		if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(root)
		owner_path = root.path_join("ordinary.json.dynasty-owner")
		_run(owner_path)
	elif not owner_path.is_absolute_path() or not FileAccess.file_exists(owner_path):
		get_tree().quit(2)
		return
	var original: String = SeasonSave.path
	SeasonSave.path = owner_path.trim_suffix(".dynasty-owner")
	app = Main.instantiate()
	add_child(app)
	await _routes()
	app.free()
	SeasonSave.path = original
	SeasonSave._dynasty_owner_path = ""
	print("SHARED_STADIUM_ROUTE_GUARD checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func button(text: String) -> Button:
	for parent: Control in [app.menu._body, app.menu._footer]:
		for child: Node in parent.find_children("*", "Button", true, false):
			if child.text == text:
				return child as Button
	return null

func buy_button() -> Button:
	for child: Node in app.menu._body.find_children("*", "Button", true, false):
		if child.get_meta("shared_stadium_buy", "") == "ST-001":
			return child as Button
	return null

func option(meta: String = "", value: String = "") -> OptionButton:
	for child: Node in app.menu._body.find_children("*", "OptionButton", true, false):
		if meta.is_empty() or child.get_meta(meta, "") == value:
			return child as OptionButton
	return null

func callback(signal_value: Signal) -> Callable:
	return signal_value.get_connections()[0].callable

func unchanged(body: Control, _owner: Dictionary, label: String) -> void:
	check(app.menu._body == body, label + " leaves current render unchanged")
	check(FileAccess.get_sha256(owner_path) == owner_sha256, label + " leaves owner unchanged")

func dismiss() -> void:
	app._dialog.canceled.emit()
	app._dialog.hide()

func _routes() -> void:
	var owner: Dictionary = Store.inspect(owner_path).owner
	owner_sha256 = FileAccess.get_sha256(owner_path)
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	UI.show(app)
	var old_body: Control = app.menu._body
	var receiver: OptionButton = option("shared_stadium_site", "RECEIVER-PRIMARY")
	var old_selection: Callable = callback(receiver.item_selected)
	var old_style: Callable = callback(option("stadium_style", "line").item_selected)
	var old_buy: Callable = callback(buy_button().pressed)
	var old_navigation: Callable = callback(button("OWNED COPY CATALOG").pressed)
	var old_save: Callable = callback(button("SAVE SHARED DRAFT").pressed)
	var old_preview: Callable = UI._preview.bind(app, old_body)
	var saved: Dictionary = Access.ledger(app).view().stadium_draft
	var revision: int = Access.ledger(app).revision()
	receiver.item_selected.emit(1)
	check(app.menu._body != old_body and option("shared_stadium_site", "RECEIVER-PRIMARY").selected == 1,
		"current starter selector makes a newer unsaved preview")
	var newer: Control = app.menu._body
	old_selection.call(0)
	old_style.call(0)
	old_buy.call()
	old_navigation.call()
	old_save.call()
	old_preview.call(saved, revision)
	unchanged(newer, owner, "captured callbacks after a newer edit")
	check(not app._dialog.visible, "retired navigation cannot open a dialog")
	await get_tree().process_frame
	old_selection.call(0)
	old_style.call(0)
	old_buy.call()
	old_navigation.call()
	old_save.call()
	old_preview.call(saved, revision)
	unchanged(newer, owner, "captured callbacks after retired controls are freed")

	var disabled: OptionButton = option("shared_stadium_site", "RECEIVER-PRIMARY")
	disabled.disabled = true
	callback(disabled.item_selected).call(0)
	disabled.disabled = false
	disabled.set_item_disabled(0, true)
	callback(disabled.item_selected).call(0)
	callback(disabled.item_selected).call(-1)
	callback(disabled.item_selected).call(99)
	unchanged(newer, owner, "disabled selector, item and invalid indexes")
	check(buy_button().disabled, "dirty preview disables immediate purchases")
	callback(buy_button().pressed).call()
	unchanged(newer, owner, "disabled dirty-preview purchase callback")

	button("OWNED COPY CATALOG").pressed.emit()
	check(app._dialog.visible and app._dialog.dialog_text.contains("Discard unsaved"), "dirty navigation asks before discard")
	var discarded: Callable = app._confirmed_action
	dismiss()
	unchanged(newer, owner, "cancelled dirty discard")
	UI.show(app, saved, revision)
	var same_page: Control = app.menu._body
	discarded.call()
	unchanged(same_page, owner, "old discard confirmation after same-page rerender")
	old_selection.call(0)
	unchanged(same_page, owner, "old selector after same-page rerender")
	var before_exit: Callable = callback(option("stadium_style", "line").item_selected)
	UI.show_catalog(app)
	UI.show(app)
	var returned: Control = app.menu._body
	before_exit.call(0)
	unchanged(returned, owner, "old callback after navigation away and back")

	option("shared_stadium_site", "RECEIVER-PRIMARY").item_selected.emit(1)
	button("OWNED COPY CATALOG").pressed.emit()
	var confirmed_discard: Callable = app._confirmed_action
	app._dialog.hide()
	confirmed_discard.call()
	check(app.menu.page == "shared_stadium_catalog", "current discard confirmation navigates normally")
	var catalog: Control = app.menu._body
	confirmed_discard.call()
	unchanged(catalog, owner, "replayed discard from retired render")
	var catalog_choice: Callable = callback(option().item_selected)
	var catalog_review: Callable = callback(button("REVIEW PURCHASE").pressed)
	button("REVIEW PURCHASE").pressed.emit()
	var purchase: Callable = app._confirmed_action
	dismiss()
	UI.show_catalog(app, "ST-001")
	var next_catalog: Control = app.menu._body
	catalog_choice.call(0)
	catalog_review.call()
	purchase.call()
	unchanged(next_catalog, owner, "catalog selection, review and purchase from retired render")
	check(not app._dialog.visible, "retired catalog review does not reopen a dialog")

	var rows: Array[Dictionary] = Access.Assets.Upgrades.entries()
	var selection: int = -1
	for index in rows.size():
		if rows[index].op == "stadium_wall_piece":
			selection = index
			break
	check(selection >= 0, "quantity upgrade fixture found")
	UI.show_upgrades(app, selection, 1)
	var count: SpinBox = app.menu._body.find_children("*", "SpinBox", true, false)[0]
	var old_count: Callable = callback(count.value_changed)
	var upgrades: Control = app.menu._body
	count.editable = false
	old_count.call(2.0)
	count.editable = true
	old_count.call(0.0)
	old_count.call(65.0)
	old_count.call(1.5)
	unchanged(upgrades, owner, "disabled and invalid quantity callbacks")
	var old_upgrade_choice: Callable = callback(option().item_selected)
	count.value_changed.emit(2.0)
	check(app.menu._body != upgrades, "current quantity control rerenders requested quantity")
	var quantity_body: Control = app.menu._body
	old_count.call(3.0)
	old_upgrade_choice.call(0)
	unchanged(quantity_body, owner, "retired upgrade quantity and selection")
	var style_index: int = -1
	for index in rows.size():
		if rows[index].op == "stadium_style" and rows[index].item == "ST-062a":
			style_index = index
	UI.show_upgrades(app, style_index)
	button("REVIEW UPGRADE").pressed.emit()
	var upgrade: Callable = app._confirmed_action
	dismiss()
	UI.show(app)
	var workshop: Control = app.menu._body
	upgrade.call()
	unchanged(workshop, owner, "retired upgrade confirmation")

	# Current controls still save and apply; a captured Save cannot overwrite them.
	option("shared_stadium_site", "RECEIVER-PRIMARY").item_selected.emit(1)
	var save: Callable = callback(button("SAVE SHARED DRAFT").pressed)
	button("SAVE SHARED DRAFT").pressed.emit()
	while UI.Transaction.busy(app.menu):
		await get_tree().process_frame
	check(Access.ledger(app).view().stadium_draft.receiver == "starter-v1:ST-079", "current Save persists exact preview")
	var saved_owner: Dictionary = Store.inspect(owner_path).owner
	owner_sha256 = FileAccess.get_sha256(owner_path)
	save.call()
	unchanged(app.menu._body, saved_owner, "replayed save callback")
	button("APPLY FOR FUTURE SEASONS").pressed.emit()
	var apply: Callable = app._confirmed_action
	dismiss()
	UI.show(app)
	var before_apply: Control = app.menu._body
	apply.call()
	unchanged(before_apply, saved_owner, "retired Apply confirmation")
	button("APPLY FOR FUTURE SEASONS").pressed.emit()
	app._dialog.hide()
	app._confirmed_action.call()
	while UI.Transaction.busy(app.menu):
		await get_tree().process_frame
	check(Access.ledger(app).view().stadium_active.receiver == "starter-v1:ST-079", "current Apply commits future field")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "all route checks preserve current frozen season")

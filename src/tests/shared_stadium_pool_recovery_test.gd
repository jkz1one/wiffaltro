extends "res://src/tests/shared_stadium_ui_test.gd"
## Continues only the disposable Pool lifecycle fixture, never a campaign owner.
func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-ui-owner="):
			path = arg.trim_prefix("--shared-ui-owner=")
	if not path.is_absolute_path() or not path.ends_with("ordinary.json.dynasty-owner") or not FileAccess.file_exists(path):
		get_tree().quit(2)
		return
	var access = load("res://src/presentation/stadium/stadium_career_access.gd")
	var ui = load("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
	SeasonSave.path = path.trim_suffix(".dynasty-owner")
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	var before: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var paid: ClubAssetLedger = access.ledger(app)
	var layout: Dictionary = paid.view().stadium_active
	if not check(layout.get("version") == 16, "requires isolated applied Pool fixture"):
		app.free()
		get_tree().quit(1)
		return
	var future_grant: Dictionary = Grant.capture(before.career)
	var context: Dictionary = Bound.binding({"owner_id": before.owner_id, "lineage_id": before.lineage.id,
		"generation": 1, "ordinal": 2, "session_id": "runtime-pool-future:2", "seed": 302,
		"tier": 0, "league": "standard", "format": 89,
		"grant_sha256": Save.snapshot_reference(future_grant).sha256})
	check(not context.is_empty(), "future binding uses exact ordinal and generation")
	var future: SeasonState = Live.create(future_grant, context)
	check(future != null and ClubCareer.same(future.home_property.get("layout"), layout), "future admission captures exact applied Pool")
	check(future != null and future.career == null and future.player_access == app.season.player_access, "future uses shared authority without new roster grants")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "future preparation cannot mutate current field")
	ui.show(app)
	check(app.menu.page == "shared_stadium_pool", "final-source actual main Pool panel")
	var catalog_action: Callable = _button(app.menu, "OWNED COPY CATALOG").get_signal_connection_list("pressed")[0].callable
	_button(app.menu, "OWNED COPY CATALOG").pressed.emit()
	check(app.menu.page == "shared_stadium_catalog", "saved Pool keeps catalog reachable")
	ui.show(app)
	catalog_action.call()
	check(app.menu.page == "shared_stadium_pool", "detached catalog callback cannot change view")
	_button(app.menu, "FIELD UPGRADES").pressed.emit()
	check(app.menu.page == "shared_stadium_upgrades", "saved Pool keeps upgrades reachable")
	ui.show(app)
	_button(app.menu, "STORE POOL").pressed.emit()
	check(_button(app.menu, "OWNED COPY CATALOG").disabled and _button(app.menu, "FIELD UPGRADES").disabled, "unsaved storage keeps purchase navigation disabled")
	check(app.menu.page == "shared_stadium_pool", "store keeps lossless surface preview panel")
	var reload_action: Callable = _button(app.menu, "RELOAD SAVED").get_signal_connection_list("pressed")[0].callable
	var dirty_body: Control = app.menu._body
	_button(app.menu, "RELOAD SAVED").pressed.emit()
	check(app._dialog.dialog_text.contains("Discard unsaved") and app.menu._body == dirty_body, "dirty Pool reload asks before replacing preview")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(app.menu._body == dirty_body, "cancel reload retains dirty Pool preview")
	_button(app.menu, "RELOAD SAVED").pressed.emit()
	var pending_reload: Callable = app._confirmed_action
	ui.show(app)
	var replacement: Control = app.menu._body
	pending_reload.call()
	reload_action.call()
	app._dialog.hide()
	check(app.menu._body == replacement, "detached reload and confirmation cannot replace newer screen")
	_button(app.menu, "STORE POOL").pressed.emit()
	_button(app.menu, "RELOAD SAVED").pressed.emit()
	app._dialog.confirmed.emit()
	app._dialog.hide()
	check(_button(app.menu, "STORE POOL") != null, "confirmed reload restores saved Pool")
	_button(app.menu, "STORE POOL").pressed.emit()
	var base: Dictionary = StadiumPoolOwnedLayout.base(layout)
	var revision: int = paid.revision()
	Store._test_stop_after = "intent.rename"
	_button(app.menu, "SAVE SHARED DRAFT").pressed.emit()
	while ui.Transaction.busy(app.menu):
		await get_tree().process_frame
	Store._test_stop_after = ""
	check(Store.inspect(path).status == "pending" and access.ledger(app) == null, "interrupted storage save hides stale owner")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(app.dynasty_owner.recover(), "cold storage save recovery")
	check(access.save_draft(app, base, revision).get("replayed", false), "storage save exact retry")
	ui.show(app)
	paid = access.ledger(app)
	check(ClubCareer.same(paid.view().stadium_draft, base) and ClubCareer.same(paid.view().stadium_active, layout), "recovered storage draft preserves applied Pool")
	var saved: Dictionary = Store.inspect(path).owner
	var old_save: Callable = _button(app.menu, "SAVE SHARED DRAFT").get_signal_connection_list("pressed")[0].callable
	ui.show(app)
	old_save.call()
	check(ClubCareer.same(saved, Store.inspect(path).owner), "detached save callback cannot write")
	_button(app.menu, "APPLY FOR FUTURE SEASONS").pressed.emit()
	check(app._dialog.dialog_text.contains("unchanged"), "Pool apply confirmation freezes fields")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(ClubCareer.same(saved, Store.inspect(path).owner), "Pool apply cancel no write")
	revision = paid.revision()
	_button(app.menu, "APPLY FOR FUTURE SEASONS").pressed.emit()
	Store._test_stop_after = "intent.rename"
	app._dialog.confirmed.emit()
	app._dialog.hide()
	while ui.Transaction.busy(app.menu):
		await get_tree().process_frame
	Store._test_stop_after = ""
	check(Store.inspect(path).status == "pending", "interrupted actual confirmed storage apply is pending")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(app.dynasty_owner.recover(), "cold storage apply recovery")
	check(access.apply_draft(app, base, revision).get("replayed", false), "storage apply exact retry")
	paid = access.ledger(app)
	check(ClubCareer.same(paid.view().stadium_active, base) and paid.construction().copies.has(layout.pool.copy), "storage retains exact paid Pool copy")
	check(paid.balance() == Authority.view(before.career).balance, "moving and storage do not charge")
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "all grant evidence frozen")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "all snapshot references frozen")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current exact snapshot frozen after both recoveries")
	app.free()
	print("SHARED_POOL_RECOVERY checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _button(node: Node, label: String) -> Button:
	if node is Button and node.text == label:
		return node
	for child: Node in node.get_children():
		var found: Button = _button(child, label)
		if found != null:
			return found
	return null

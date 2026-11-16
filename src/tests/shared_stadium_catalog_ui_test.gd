extends "res://src/tests/shared_stadium_ui_test.gd"
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
	var history: ClubCareer = Authority._history(before.career)
	for item: String in ClubConstruction.copy_items():
		var command: Dictionary = ClubConstruction.copy_command(history, item, paid.revision())
		var enabled: bool = not (item == "ST-006" and not StadiumPoolWorkshopUI.WORKSHOP_ENABLED)
		check(Assets.supported(command) == enabled, "existing public purchase gate preserved " + item)
		command.price_version = 999
		check(not Assets.supported(command), "wrong catalog price rejected " + item)
	check(not Assets.supported({"op": "stadium_buy", "item": "fake-item", "price_version": 1}), "unknown item rejected")
	for item: String in ["ST-080", "ST-006", "ST-037"]:
		var command: Dictionary = ClubConstruction.copy_command(history, item, paid.revision())
		var ordinary: Dictionary = ClubPlayers.command(Authority._history(before.career), command)
		var shared: Dictionary = Assets.command(before.career, command)
		check(ClubCareer.same(ordinary, shared.applied), "existing progression and prices match " + item)
	var quote: Dictionary = access.copy_quote(app, "ST-080")
	if not check(quote.get("ok", false), "earned seating quote: " + str(quote)):
		app.free()
		get_tree().quit(1)
		return
	var expected_cost: int = 40 if paid.construction().blueprints.has("ST-080") else 190
	check(quote.cost == expected_cost, "seating blueprint charged only when not owned")
	ui.show_catalog(app, "ST-080")
	check(app.menu.page == "shared_stadium_catalog", "actual shared catalog renders")
	ui._catalog_confirm(app, "ST-080", quote)
	check(app._dialog.dialog_text.contains(str(expected_cost)) and app._dialog.dialog_text.contains("unchanged"), "confirmation gives total and frozen field promise")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(ClubCareer.same(before, Store.inspect(path).owner), "quote and cancel do not mutate owner")
	check(access.commit_quote(app, quote).get("ok", false), "actual shared nonstarter purchase commits")
	check(not access.commit_quote(app, quote).get("ok", false), "stale confirmation rejected")
	check(access.transact(app, quote.command).get("replayed", false), "original exact command retry replays")
	check(access.ledger(app).balance() == paid.balance() - expected_cost, "one blueprint and copy debit")
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "all frozen grants unchanged")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "all frozen snapshot refs unchanged")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current field unchanged")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(access.ledger(app).construction().blueprints.has("ST-080"), "cold actual main retains purchased seating blueprint")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "cold actual field remains frozen")
	app.free()
	print("SHARED_STADIUM_CATALOG checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

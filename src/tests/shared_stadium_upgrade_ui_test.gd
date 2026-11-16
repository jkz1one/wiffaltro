extends "res://src/tests/shared_stadium_ui_test.gd"
const Upgrades = preload("res://src/gameplay/season/dynasty_stadium_upgrades.gd")
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
	for row: Dictionary in Upgrades.entries():
		var command: Dictionary = Upgrades.command(history, row.op, row.item, paid.revision())
		check(not command.is_empty() and Assets.supported(command), "public upgrade grammar " + row.label)
		var wrong: Dictionary = command.duplicate(true)
		wrong.price_version = 999
		check(not Assets.supported(wrong), "wrong upgrade price refused " + row.label)
	for row: Dictionary in [
		{"op": "stadium_land", "item": "expanded"},
		{"op": "stadium_style", "item": "ST-062a"},
		{"op": "stadium_surface", "item": "grass"},
		{"op": "stadium_scoreboard", "item": "ST-039"},
		{"op": "stadium_wall_piece", "item": "ST-024-L"},
		{"op": "stadium_buy", "item": "ST-022"},
		{"op": "stadium_salvage_clear", "item": ""}]:
		var command: Dictionary = Upgrades.command(history, row.op, row.item, paid.revision())
		var ordinary: Dictionary = ClubPlayers.command(Authority._history(before.career), command)
		var shared: Dictionary = Assets.command(before.career, command)
		check(ClubCareer.same(ordinary, shared.applied), "unchanged journal arithmetic and access " + row.op)
	check(not Assets.supported({"op": "stadium_salvage_clear", "copy": "fake-copy", "price_version": ClubAssetLedger.SALVAGE_ORIGIN_VERSION}), "salvage exact identity required")
	check(Upgrades.command(history, "stadium_style", "fake-style", paid.revision()).is_empty(), "unknown style refused")
	var saved_home: Dictionary = app.season.home_property
	var saved_night: Dictionary = app.season.owned_surface_night
	app.season.home_property = {}
	check(not Upgrades.allowed(app.season, {"op": "stadium_land"}), "pre-draft expansion still requires complete-boundary profile")
	app.season.home_property = saved_home
	app.season.owned_surface_night = {"test": true}
	check(not Upgrades.allowed(app.season, {"op": "stadium_land"}) and not Upgrades.allowed(app.season, {"op": "stadium_salvage_clear"}), "night freeze blocks land and salvage before completion")
	app.season.owned_surface_night = saved_night
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "guard-only probes restore original in-memory source")
	var quote: Dictionary = access.upgrade_quote(app, "stadium_style", "ST-062a")
	if not check(quote.get("ok", false) and quote.get("cost") == 115, "exact eligible appearance quote115CB"):
		app.free()
		get_tree().quit(1)
		return
	ui.show_upgrades(app)
	check(app.menu.page == "shared_stadium_upgrades", "actual upgrade panel renders")
	ui._upgrade_confirm(app, 0, 1, "Appearance ST-062a", quote)
	check(app._dialog.dialog_text.contains("115") and app._dialog.dialog_text.contains("unchanged"), "upgrade confirmation states exact cost and frozen fields")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(ClubCareer.same(before, Store.inspect(path).owner), "upgrade previews and cancel write nothing")
	check(access.commit_quote(app, quote).get("ok", false), "appearance owner transaction commits")
	check(not access.commit_quote(app, quote).get("ok", false), "stale upgrade confirmation rejected")
	check(access.transact(app, quote.command).get("replayed", false), "exact upgrade command replays")
	check(access.ledger(app).balance() == paid.balance() - 115, "appearance debit exactly once")
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "all admitted grants stay frozen")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "all admitted snapshots stay frozen")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current source not refreshed by upgrade")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(access.ledger(app).construction().styles.has("ST-062a"), "cold main retains new appearance entitlement")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "cold field still original")
	app.free()
	print("SHARED_STADIUM_UPGRADES checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

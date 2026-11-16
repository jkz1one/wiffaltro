extends "res://src/tests/shared_stadium_ui_test.gd"
## Runs only after the isolated starter UI fixture; no user save access.
func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-ui-owner="):
			path = arg.trim_prefix("--shared-ui-owner=")
	if not path.is_absolute_path() or not path.ends_with("ordinary.json.dynasty-owner") or not FileAccess.file_exists(path):
		get_tree().quit(2)
		return
	var access = load("res://src/presentation/stadium/stadium_career_access.gd")
	SeasonSave.path = path.trim_suffix(".dynasty-owner")
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	var before: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var paid: ClubAssetLedger = access.ledger(app)
	var ui = load("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
	ui._ask_apply(app, paid.view().stadium_draft, paid.revision())
	check(app._dialog.dialog_text.contains("future seasons") and app._dialog.dialog_text.contains("unchanged"), "confirmation explains frozen field policy")
	app._dialog.canceled.emit()
	app._dialog.hide()
	check(ClubCareer.same(before, Store.inspect(path).owner), "cancel performs no transaction")
	var revision: int = paid.revision()
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = access.buy_copy(app, "ST-003", revision)
	Store._test_stop_after = ""
	check(not stopped.get("ok", false) and Store.inspect(path).status == "pending", "UI interruption leaves durable pending")
	check(access.ledger(app) == null, "pending cannot expose stale editor wallet")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(app.dynasty_owner.recover(), "cold actual main recovers exact workshop intent")
	check(access.buy_copy(app, "ST-003", revision).get("replayed", false), "recovered original command exact retry")
	check(access.ledger(app).balance() == paid.balance() - 45, "recovery and retry debit exactly once")
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "recovery freezes both grants")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "recovery freezes both snapshot references")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "recovery freezes current snapshot")
	app.free()
	print("SHARED_STADIUM_UI_RECOVERY checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

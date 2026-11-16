extends "res://src/tests/shared_stadium_pool_ui_test.gd"
func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-ui-owner="):
			path = arg.trim_prefix("--shared-ui-owner=")
	if not path.is_absolute_path() or not path.ends_with("ordinary.json.dynasty-owner") or not FileAccess.file_exists(path):
		get_tree().quit(2)
		return
	SeasonSave.path = path.trim_suffix(".dynasty-owner")
	var app: SeasonApp = Main.instantiate()
	add_child(app)
	var access = load("res://src/presentation/stadium/stadium_career_access.gd")
	var ui = load("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
	var pool_ui = load("res://src/presentation/stadium/shared_stadium_pool_ui.gd")
	var before: Dictionary = Store.inspect(path).owner
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var paid: ClubAssetLedger = access.ledger(app)
	var copy: String = ""
	for id: String in paid.construction().copies:
		if paid.construction().copies[id].item == "ST-006":
			copy = id
	var base: Dictionary = StadiumStarterLayout.empty()
	base.receiver = "starter-v1:ST-079"
	pool_ui._place(app, base, paid.revision(), copy)
	check(app.menu.page == "shared_stadium_pool", "actual main Pool preview")
	var card: VBoxContainer = _pool_card(app.menu._body)
	if not check(card != null, "Pool placement card"):
		app.free()
		return
	var layout: Dictionary = card.get_meta("shared_pool_draft")
	check(access.save_draft(app, layout, paid.revision()).get("ok", false), "Pool draft saves")
	paid = access.ledger(app)
	ui.show(app)
	check(app.menu.page == "shared_stadium_pool", "saved Pool renders")
	var saved_revision: int = paid.revision()
	check(access.apply_draft(app, layout, saved_revision).get("ok", false), "Pool future field applies")
	check(access.apply_draft(app, layout, saved_revision).get("replayed", false), "Pool apply retry")
	var after: Dictionary = Store.inspect(path).owner
	check(ClubCareer.same(before.career.sessions, after.career.sessions), "session grants unchanged")
	check(ClubCareer.same(before.dynasty, after.dynasty) and ClubCareer.same(before.other, after.other), "both saved fields unchanged")
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "current exact snapshot frozen")
	app.free()
	app = Main.instantiate()
	add_child(app)
	check(ClubCareer.same(frozen, SeasonSave.snapshot(app.season)), "actual main cold frozen restore")
	check(ClubCareer.same(access.ledger(app).view().stadium_active, layout), "cold shared field persists separately")
	app.free()
	print("SHARED_POOL_RESUME checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

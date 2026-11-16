extends Node
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("STANDARD_MAIN_HISTORY ", ok, " ", label)
	if not ok: failures += 1
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--player-route-root="): root = arg.trim_prefix("--player-route-root=")
	if not root.is_absolute_path():
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	add_child(app)
	_run(app)
	app.free()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("STANDARD_MAIN_HISTORY_RESULT %d checks, %d failures" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(app: SeasonApp) -> void:
	if not check(app.season != null and app.dynasty_owner.ready(), "actual main cold restores owned92"): return
	var current: Dictionary = app.dynasty_owner.found()
	if current.owner.career.sessions[current.owner.other.session_id].settled == 0:
		if not check(app.dynasty_owner.switch_to("other", current.revision), "resume existing alternate before explicit close"): return
		current = app.dynasty_owner.found()
		if not check(app.dynasty_owner.close_current("abandon", current.revision), "explicitly close isolated alternate fixture"): return
	current = app.dynasty_owner.found()
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "return to Dynasty before choosing replacement"): return
	preload("res://src/presentation/season/dynasty_career_ui.gd").show(app)
	var button: Button = _league_button(app.menu)
	if not check(button != null and not button.disabled, "actual chooser offers Standard after Dynasty settlement"): return
	button.pressed.emit()
	check(app._dialog.visible, "actual Standard review opens")
	app._dialog.hide()
	app._dialog.confirmed.emit()
	if not check(app.season != null and not app.season._standard_live_context.is_empty(), "actual chooser opens Standard89: " + app.notice): return
	current = app.dynasty_owner.found()
	check(current.owner.other.snapshot_version == 89 and current.owner.selected == "other", "saved selected Standard89 slot")
	check(app.season._standard_bound_grant.version == 3 and app.season._standard_live_context.template.career.version == 29,
		"explicit grant3 projection29 retained")
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "actual main Standard cold replay")

func _league_button(node: Node) -> Button:
	if node is Button and node.get_meta("owner_league", "") == "standard" and node.get_meta("owner_league_tier", -1) == 0:
		return node as Button
	for child: Node in node.get_children():
		var found: Button = _league_button(child)
		if found != null: return found
	return null

extends Node
## Actual SeasonApp/SeasonSave route in the runner's isolated user root only.
## Does not claim a completed physical game or human visual acceptance.
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var user_root: String = OS.get_environment("WIFFALTRO_MODERN_USER_ROOT").trim_suffix("/")
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or user_root.is_empty() or not OS.get_user_data_dir().begins_with(user_root + "/"):
		push_error("This test requires the bounded runner and an isolated modern user root.")
		get_tree().quit(2)
		return
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://expanded-ui-prior-club-test.json"
	var prior: SeasonState = WorkingPitchProgression.create_season(930)
	check(SeasonSave.save(prior), "test prior club saved")
	var prior_hash: String = FileAccess.get_sha256(SeasonSave.path)
	var prior_path: String = SeasonSave.path
	var app: SeasonApp = load("res://src/presentation/season/season_app.tscn").instantiate() as SeasonApp
	add_child(app)
	for _frame in range(120):
		await get_tree().process_frame
		if app.menu != null:
			break
	check(app.menu != null, "real SeasonApp menu ready")
	if app.menu == null:
		app.queue_free()
		get_tree().quit(1)
		return
	check(_button_exists(app.menu, "43-PITCH SEASON"), "normal menu exposes standalone v6 route")
	ExpandedSeasonUI.begin(app)
	check(SeasonSave.path == ExpandedSeasonUI.SAVE_PATH and app.season != null and app.season.build.pitch_catalog_expanded(), "route enters new isolated v6 slot")
	if app.season != null and app.season.build.pitch_catalog_expanded():
		for _pick in range(4):
			app.choose_player(app.season.offers()[0])
		check(app.season.picks.size() == 4 and app._unsaved_draft == null, "real app draft persists four authored players")
		var saved: Dictionary = SeasonSave.snapshot(app.season)
		var restored: SeasonState = SeasonSave.restore()
		check(restored != null and ClubCareer.same(saved, SeasonSave.snapshot(restored)), "save and disk restore preserve v6 draft")
		ExpandedSeasonUI.return_to_club(app)
		check(SeasonSave.path == prior_path and FileAccess.get_sha256(prior_path) == prior_hash, "return preserves prior club bytes")
		ExpandedSeasonUI.open(app)
		check(app.season != null and app.season.build.pitch_catalog_expanded() and app.season.picks.size() == 4, "reopen resumes persisted standalone season")
		ExpandedSeasonUI.return_to_club(app)
		check(FileAccess.get_sha256(prior_path) == prior_hash, "repeated open/return never rewrites prior club")
	app.queue_free()
	await get_tree().process_frame
	SeasonSave.path = original_path
	print("Expanded SeasonApp route failures: %d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _button_exists(node: Node, label: String) -> bool:
	if node is Button and node.text == label:
		return true
	for child: Node in node.get_children():
		if _button_exists(child, label):
			return true
	return false

extends "res://src/tests/club_career_test.gd"
## Actual editor input and atomic draft storage; explicitly no live field activation.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://stadium-editor-%d.json" % OS.get_process_id()
	var path: String = SeasonSave.path
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.begin_season(83, true)
	ClubCareerUI.show(app.menu)
	await _click(_button(app.menu, "STADIUM WORKSHOP"))
	if _button(app.menu, "SAVE DRAFT") == null:
		_check(false, "editor must build its save control")
		_stop(app)
		return
	_check(app.menu.page == "stadium" and _button(app.menu, "SAVE DRAFT").disabled,
		"actual editor entry and no redundant initial save")
	await _choose(app, "ST-001", 1)
	_check(ClubPlayers.assets(app.season.career).view().stadium_draft.obstacles.is_empty(),
		"preview does not mutate saved draft")
	var conflict_index: int = _live_choice_index("ST-003", "O-L1", 0)
	_check(_choice(app, "ST-003") != null and conflict_index >= 0
		and conflict_index < _choice(app, "ST-003").item_count
		and _choice(app, "ST-003").is_item_disabled(conflict_index),
		"occupied cone site cannot be selected by the live tile control")
	var local: Dictionary = StadiumStarterLayout.empty()
	local.obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	var conflict: Dictionary = local.duplicate(true)
	conflict.obstacles.append({"copy": "starter-v1:ST-003", "site": "O-L1", "yaw": 0})
	var base_revision: int = ClubPlayers.assets(app.season.career).revision()
	var before_conflict: Dictionary = SeasonSave.snapshot(app.season)
	var conflict_bytes: String = FileAccess.get_file_as_string(path)
	StadiumEditorUI.show(app.menu, conflict, base_revision)
	await _frames()
	_check(_button(app.menu, "SAVE DRAFT") == null
		and _button(app.menu, "APPLY LAYOUT") == null
		and _button(app.menu, "FIELD VIEW") == null
		and _button(app.menu, "FOCUS IN PREVIEW") == null
		and _preview(app) == null and _choice(app, "ST-001") == null,
		"invalid same-site draft exposes no save, apply, preview or placement controls")
	var conflict_error: String = "Obstacle sites must be unique and canonically ordered: O-L1"
	_check(_visible_label(app.menu._body, conflict_error), "same-site validation error is visible")
	var reload: Button = _button(app.menu, "RELOAD SAVED")
	var back: Button = _button(app.menu, "CLUB RECORD")
	_check(reload != null and back != null, "invalid draft offers visible reload and back controls")
	if reload == null or back == null:
		_stop(app)
		return
	_check(not reload.disabled and not back.disabled, "invalid draft recovery controls are enabled")
	_check(ClubCareer.same(before_conflict, SeasonSave.snapshot(app.season))
		and FileAccess.get_file_as_string(path) == conflict_bytes,
		"displaying invalid draft leaves saved state and bytes untouched")
	_check(not ClubConstruction.save_draft(app.season, conflict, base_revision).ok
		and ClubCareer.same(before_conflict, SeasonSave.snapshot(app.season))
		and FileAccess.get_file_as_string(path) == conflict_bytes,
		"injected stale conflict also rejects without saved mutation")
	await _click(reload)
	var recovered_save: Button = _button(app.menu, "SAVE DRAFT")
	var recovered_apply: Button = _button(app.menu, "APPLY LAYOUT")
	var recovered_choice: OptionButton = _choice(app, "ST-001")
	_check(recovered_save != null and recovered_apply != null
		and recovered_choice != null and _preview(app) != null,
		"explicit reload rebuilds valid editor controls and preview")
	if recovered_save == null or recovered_apply == null or recovered_choice == null:
		_stop(app)
		return
	_check(app.menu.page == "stadium" and recovered_save.disabled and recovered_apply.disabled
		and recovered_choice.selected == 0 and not _visible_label(app.menu._body, conflict_error)
		and ClubCareer.same(before_conflict, SeasonSave.snapshot(app.season))
		and FileAccess.get_file_as_string(path) == conflict_bytes,
		"explicit reload restores the saved empty layout without saving invalid edits")
	StadiumEditorUI.show(app.menu, local, base_revision)
	await _choose(app, "ST-003", _live_choice_index("ST-003", "O-R1", 0))
	await _choose(app, "ST-003", _live_choice_index("ST-003", "O-R1", 90))
	await _choose(app, "ST-079", 1)
	_check(_button(app.menu, "SAVE DRAFT") != null
		and not _button(app.menu, "SAVE DRAFT").disabled, "legal three-object draft can save")
	SeasonSave.path = path + "/missing/profile.json"
	await _click(_button(app.menu, "SAVE DRAFT"))
	_check(app.menu.page == "stadium" and _choice(app, "ST-001") != null
		and _choice(app, "ST-001").selected == 1
		and ClubPlayers.assets(app.season.career).view().stadium_draft.obstacles.is_empty(),
		"failed write retains local preview and previous saved layout")
	SeasonSave.path = path
	await _click(_button(app.menu, "SAVE DRAFT"))
	var saved: Dictionary = ClubPlayers.assets(app.season.career).view().stadium_draft
	_check(saved.receiver == "starter-v1:ST-079" and saved.obstacles.size() == 2
		and saved.obstacles[0].site == "O-L1" and saved.obstacles[1].site == "O-R1"
		and saved.obstacles[1].yaw == 90, "exact sites, copies and rotation saved")
	_check(app.season.career.balance() == 0 and app.season.results.is_empty()
		and app.season.physical.reports.is_empty(), "no debit or game result from editor")
	_check(app.season.home_property.layout.obstacles.is_empty(),
		"saving a draft does not silently activate it")
	var before_field: Dictionary = app.season.home_property.duplicate(true)
	SeasonSave.path = path + "/missing/profile.json"
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(app.season.home_property == before_field
		and ClubPlayers.assets(app.season.career).view().stadium_active.obstacles.is_empty(),
		"failed Apply preserves both the field and active ownership state")
	SeasonSave.path = path
	await _click(_button(app.menu, "APPLY LAYOUT"))
	_check(ClubCareer.same(app.season.home_property.layout, saved)
		and _button(app.menu, "APPLY LAYOUT") != null
		and _button(app.menu, "APPLY LAYOUT").disabled and app.season.career.balance() == 0,
		"actual Apply atomically publishes owned geometry once without a charge")
	var preview: StadiumDraftPreview = _preview(app)
	_check(preview != null and preview.get_child_count() > 0 and preview.get_child(0).own_world_3d,
		"preview isolates its world from live gameplay")
	await _bounds(app, "stadium-draft-field")
	await _click(_button(app.menu, "FOCUS IN PREVIEW"))
	await _bounds(app, "stadium-draft-cone")
	get_window().size = Vector2i(700, 400)
	await _bounds(app, "stadium-draft-small")
	await _choose(app, "ST-079", 0)
	await _click(_button(app.menu, "CLUB RECORD"))
	_check(app._dialog.visible, "leaving an unsaved preview asks before discard")
	await _key(KEY_ESCAPE)
	_check(app.menu.page == "stadium", "cancel keeps unsaved preview")
	await _click(_button(app.menu, "CLUB RECORD"))
	await _click(app._dialog.get_ok_button())
	_check(app.menu.page == "career", "confirmed discard returns to club record")
	await _click(_button(app.menu, "STADIUM WORKSHOP"))
	_check(_choice(app, "ST-079") != null and _choice(app, "ST-079").selected == 1,
		"discard restores saved receiver selection")
	app.queue_free()
	await _frames()
	app = SeasonApp.new()
	add_child(app)
	await _frames()
	StadiumEditorUI.show(app.menu)
	_check(ClubCareer.same(ClubPlayers.assets(app.season.career).view().stadium_draft, saved),
		"whole app restart retains draft and only three owned starter copies")
	await _choose(app, "ST-003", _live_choice_index("ST-003", "O-R1", 180))
	var revision: int = ClubPlayers.assets(app.season.career).revision()
	_check(ClubConstruction.save_draft(app.season, StadiumStarterLayout.empty(), revision).ok,
		"separate newer valid draft saved")
	await _click(_button(app.menu, "SAVE DRAFT"))
	_check(_button(app.menu, "SAVE DRAFT") != null and _button(app.menu, "SAVE DRAFT").disabled
		and ClubPlayers.assets(app.season.career).view().stadium_draft.obstacles.is_empty(),
		"stale preview cannot overwrite newer saved draft")
	await _click(_button(app.menu, "RELOAD SAVED"))
	_check(_choice(app, "ST-001") != null and _choice(app, "ST-001").selected == 0,
		"explicit reload adopts newer saved state")
	app.choose_player(app.season.offers()[0])
	StadiumEditorUI.show(app.menu)
	_check(_choice(app, "ST-001") != null and _choice(app, "ST-001").disabled
		and _button(app.menu, "SAVE DRAFT") != null and _button(app.menu, "SAVE DRAFT").disabled,
		"editing locks once roster drafting begins")
	get_window().size = Vector2i(1280, 720)
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro stadium editor checks passed: "
			+ "preview, conflicts, atomic saves and stale recovery.")
	get_tree().quit(0 if _failures == 0 else 1)


func _choice(app: SeasonApp, id: String, yaw: bool = false) -> OptionButton:
	for option: OptionButton in app.menu._body.find_children("*", "OptionButton", true, false):
		if option.get_meta("stadium_yaw" if yaw else "stadium_copy", "") == "starter-v1:" + id:
			return option
	return null


func _choose(app: SeasonApp, id: String, index: int, yaw: bool = false) -> void:
	# Occupied sites are disabled and keyboard navigation skips them.
	await _frames()
	var option: OptionButton = _choice(app, id, yaw)
	_check(option != null and not option.disabled, "requested placement control is available")
	if option == null or option.disabled:
		get_tree().quit(1)
		return
	_check(index >= 0 and index < option.item_count and not option.is_item_disabled(index),
		"requested exact starter site is enabled")
	if index < 0 or index >= option.item_count or option.is_item_disabled(index):
		return
	var allowed: Array[int] = []
	for item in range(option.item_count):
		if not option.is_item_disabled(item) or item == option.selected:
			allowed.append(item)
	var previous: int = allowed.find(option.selected)
	var target: int = allowed.find(index)
	option.grab_focus()
	await _frames()
	await _key(KEY_ENTER)
	for step in range(absi(target - previous)):
		await _key(KEY_DOWN if target > previous else KEY_UP)
	await _key(KEY_ENTER)
	await _frames()
	var rebuilt: OptionButton = _choice(app, id, yaw)
	_check(rebuilt != null, "placement control survives editor rebuild")
	if rebuilt == null:
		get_tree().quit(1)
		return
	_check(rebuilt.selected == index, "actual keyboard chooses requested placement")
	_check(rebuilt.has_focus(), "keyboard focus follows rebuilt placement control")


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)
		await _frames(1)


func _preview(app: SeasonApp) -> StadiumDraftPreview:
	for node: Node in app.menu._body.get_children():
		if node is StadiumDraftPreview:
			return node
	return null


func _bounds(app: SeasonApp, label: String) -> void:
	await _frames()
	var rect: Rect2 = get_viewport().get_visible_rect()
	_check(rect.encloses(app.menu._footer.get_global_rect()), "editor footer remains visible")
	for control: Control in app.menu._body.find_children("*", "Control", true, false):
		if control.is_visible_in_tree() and control.get_viewport() == app.menu.get_viewport():
			_check(control.get_global_rect().position.x >= rect.position.x
				and control.get_global_rect().end.x <= rect.end.x, "editor horizontal bounds " + label)
	await _capture(get_viewport(), label)


func _live_choice_index(item: String, site: String, yaw: int) -> int:
	var choices: Array[Dictionary] = StadiumSmallYardSceneryItemsUI.choices(item)
	for index in range(choices.size()):
		var choice: Dictionary = choices[index]
		if choice.mode == "live" and choice.site == site and choice.yaw == yaw:
			return index
	_check(false, "original exact live site and orientation remain available")
	return -1


func _visible_label(parent: Node, text: String) -> bool:
	for label: Label in parent.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and label.text == text:
			return true
	return false


func _stop(app: SeasonApp) -> void:
	app.queue_free()
	_cleanup()
	get_tree().quit(1)

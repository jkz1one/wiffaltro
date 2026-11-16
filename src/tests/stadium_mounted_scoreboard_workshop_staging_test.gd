extends "res://src/tests/stadium_editor_ui_test.gd"
## Earned staged ledger22 history remains exact when the complete workshop is admitted.

var _app: SeasonApp
var _helper: Node
var _supported: Dictionary = {}
var _mounted: Dictionary = {}
var _save_path: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_save_path = "user://mounted-workshop-staging-%d" % OS.get_process_id()
	SeasonSave.path = _save_path + "-completed.json"
	_cleanup()
	get_window().size = Vector2i(1280, 720)
	_helper = load("res://src/tests/stadium_mounted_scoreboard_staging_test.gd").new()
	await _exercise_workshop()
	if is_instance_valid(_app):
		_app.queue_free()
		await _frames()
	_check(_helper._failures == 0, "reused earned funding and paid staging helpers all pass")
	_helper.free()
	for suffix: String in ["-completed.json", "-frozen.json"]:
		SeasonSave.path = _save_path + suffix
		_cleanup()
	get_window().size = Vector2i(1280, 720)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted workshop staging passed: gated controls and exact saved preservation.")
	get_tree().quit(0 if _failures == 0 else 1)


func _exercise_workshop() -> void:
	var completed: SeasonState = _helper._fund_boards()
	_check(completed != null and completed.career.runs.size() == 22
		and completed.career.balance() == 4315 and _helper._failures == 0,
		"twenty-two synthetic scheduled seasons earn the unchanged ordinary receipts")
	if _failures != 0:
		return
	_helper._purchase_existing(completed)
	var ledger: ClubAssetLedger = ClubPlayers.assets(completed.career)
	_supported = _helper._old_layout(ledger)
	_check(ClubConstruction.save_draft(completed, _supported, ledger.revision()).ok,
		"supported14 draft uses public Save")
	_check(ClubConstruction.apply_draft(completed, _supported,
		ClubPlayers.assets(completed.career).revision()).ok, "supported14 uses public Apply")
	ledger = ClubPlayers.assets(completed.career)
	_mounted = _helper._mounted_layout(_supported, ledger)
	_check(not _mounted.is_empty(), "mounted15 is exact paid data from the original inventories")
	_check(StadiumOwnedLayout.validate(_mounted, ledger.construction(), ledger.wall_pieces(),
		ledger.surface_owned(), ledger.view().land, ledger.scoreboards()).ok
		and StadiumEditorUI._checked(ledger, _mounted).ok
			== StadiumMountedScoreboardLayout.RUNTIME_READY,
		"the complete workshop obeys the separately qualified production gate")
	if _failures != 0 or _helper._failures != 0:
		return
	# Separate save fixtures branch from the same earned history; neither mints or edits receipts.
	var supported_completed: Dictionary = SeasonSave.snapshot(completed).duplicate(true)
	await _restart()
	await _supported_workshop()
	_helper._stage_raw(_app.season, _mounted)
	await _restart()
	_check(_app.season.phase == SeasonState.Phase.COMPLETE,
		"saved active15 is reopened at the formerly misleading next-season status")
	await _blocked_workshop("mounted-staged-completed")
	if _failures != 0:
		return
	_app.queue_free()
	await _frames()
	SeasonSave.path = _save_path + "-frozen.json"
	_cleanup()
	var supported_season: SeasonState = SeasonSave._decode(supported_completed)
	_check(supported_season != null and SeasonSave.save(supported_season),
		"a separate supported14 fixture retains the same real earned ownership")
	if _failures != 0:
		return
	await _restart()
	_app.begin_season(88, true)
	_check(_app.season.phase == SeasonState.Phase.DRAFT
		and _app.season.home_property.get("version") == 12,
		"ordinary next-season creation freezes the supported older home")
	var frozen: Dictionary = _app.season.home_property.duplicate(true)
	await _supported_workshop()
	ledger = ClubPlayers.assets(_app.season.career)
	_check(ClubPlayers.transact(_app.season, {"id": "workshop-staged-draft",
		"rev": ledger.revision(), "op": "stadium_draft", "layout": _mounted}).ok,
		"data-only journal stores draft15 without applying or charging")
	await _restart()
	ledger = ClubPlayers.assets(_app.season.career)
	_check(ledger.to_data().version == 28 and ledger.construction().pennant_count() == 22
		and ledger.view().stadium_draft.version == 15
		and ClubCareer.same(ledger.view().stadium_active, _supported),
		"actual save restore preserves draft-only15 beside the exact active14")
	await _blocked_workshop("mounted-staged-draft-only")
	ledger = ClubPlayers.assets(_app.season.career)
	_check(ClubPlayers.transact(_app.season, {"id": "workshop-staged-active",
		"rev": ledger.revision(), "op": "stadium_apply", "layout": _mounted,
		"geometry": StadiumMountedScoreboardLayout.geometry(ledger.view().land, _mounted)}).ok,
		"data-only journal stages active15 without changing the current home")
	await _restart()
	await _blocked_workshop("mounted-staged-frozen-home")
	ledger = ClubPlayers.assets(_app.season.career)
	_check(ClubCareer.same(frozen, _app.season.home_property)
		and StadiumScoreboardSnapshot.matches(frozen, ledger)
		and ClubCareer.same(ledger.view().stadium_active, _mounted)
		and ClubCareer.same(ledger.view().stadium_draft, _mounted),
		"current frozen12 and exact paid active/draft15 survive every workshop interaction")


func _restart() -> void:
	if is_instance_valid(_app):
		_app.queue_free()
		await _frames()
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_check(_app.season != null, "whole-app restart restores the real saved fixture")


func _supported_workshop() -> void:
	var before: Dictionary = _helper._held_mounted(_app.season)
	ClubCareerUI.show(_app.menu)
	await _click(_button(_app.menu, "STADIUM WORKSHOP"))
	var preview: StadiumDraftPreview = _preview(_app)
	_check(preview != null and preview.preview_property is StadiumScoreboardPropertyGeometry
		and preview.preview_property.boundary != null
		and ClubCareer.same(preview.preview_property.get_meta("scoreboard_layout", {}), _supported),
		"ordinary14 keeps its exact complete preview and installed boundary")
	_check(_enabled_choice("scoreboard_choice", "primary")
		and _enabled_choice("advanced_wall_choice", "back")
		and _enabled_choice("surface_choice", "height"),
		"ordinary14 primary, advanced wall and surface controls remain enabled")
	_check(_button(_app.menu, "SAVE DRAFT").disabled
		and _button(_app.menu, "APPLY LAYOUT").disabled,
		"unchanged already-applied14 retains normal Save and Apply state")
	await _choose(_app, "ST-079", 0)
	_check(not _button(_app.menu, "SAVE DRAFT").disabled
		and _button(_app.menu, "APPLY LAYOUT").disabled,
		"real14 selection enables Save and requires it before Apply")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(ClubCareer.same(before, _helper._held_mounted(_app.season))
		and _choice(_app, "ST-079").selected == 1,
		"normal14 preview and reload are read-only and restore the exact receiver selection")


func _blocked_workshop(stage: String) -> void:
	if StadiumMountedScoreboardLayout.RUNTIME_READY:
		await _admitted_workshop(stage)
		return
	var before: Dictionary = _helper._held_mounted(_app.season)
	_app.notice = "Applied for next season" # A stale UI notice must not override the refusal.
	ClubCareerUI.show(_app.menu)
	await _click(_button(_app.menu, "STADIUM WORKSHOP"))
	_assert_blocked()
	await _bounds(_app, stage)
	for label: String in ["SAVE DRAFT", "APPLY LAYOUT"]:
		await _click(_button(_app.menu, label), false)
	_check(not _app._dialog.visible, "disabled staged actions never open a confirmation")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_assert_blocked()
	await _click(_button(_app.menu, "CLUB RECORD"))
	_check(_app.menu.page == "career" and not _app._dialog.visible,
		"saved staged layout leaves normally for Club Record without a discard dialog")
	await _click(_button(_app.menu, "STADIUM WORKSHOP"))
	get_window().size = Vector2i(700, 400)
	await _bounds(_app, stage + "-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	# Stale callbacks and an older local candidate cannot overwrite saved staged ownership.
	var revision: int = ClubPlayers.assets(_app.season.career).revision()
	for candidate: Dictionary in [_mounted, _supported]:
		for action: Callable in [StadiumEditorUI._save, StadiumEditorUI._apply,
			StadiumEditorUI._apply_now]:
			action.call(_app.menu, candidate.duplicate(true), revision)
			_assert_blocked()
			_check(not _app._dialog.visible, "unsupported direct callback refuses without approval")
	await _click(_button(_app.menu, "CLUB RECORD"))
	_check(_app._dialog.visible, "leaving an unsaved older candidate still asks before discarding")
	await _click(_app._dialog.get_cancel_button())
	_check(_app.menu.page == "stadium", "cancelled Back retains the blocked local candidate")
	_assert_blocked()
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_assert_blocked()
	_check(ClubCareer.same(before, _helper._held_mounted(_app.season)),
		"all staged controls, reload, Back and callbacks preserve raw journal, ownership, "
		+ "wallet, frozen home and exact primary/backup bytes: " + stage)


func _assert_blocked() -> void:
	var text: String = ""
	for label: Label in _app.menu.find_children("*", "Label", true, false):
		text += label.text + "\n"
	_check(_app.menu.page == "stadium" and text.contains("STAGED LAYOUT")
		and text.contains("not available") and text.contains("frozen field"),
		"actual workshop explains staged unavailability and preservation of the frozen home")
	_check(not text.contains("Applied for next season")
		and not text.contains("Applied to this season")
		and not text.contains("Save and apply to use this layout"),
		"staged layout never claims application or invites unsupported use")
	_check(_preview(_app) == null
		and _app.menu._body.find_children("*", "SubViewport", true, false).is_empty()
		and _app.menu._body.find_children("*", "OptionButton", true, false).is_empty()
		and _app.menu._body.find_children("*", "Button", true, false).is_empty(),
		"no basic fallback field, live selection or purchase controls masquerade as15 support")
	_check(_button(_app.menu, "FIELD VIEW") == null
		and _button(_app.menu, "DAY / NIGHT PREVIEW") == null,
		"no unsupported preview or night control is offered")
	for label: String in ["SAVE DRAFT", "APPLY LAYOUT"]:
		var button: Button = _button(_app.menu, label)
		_check(button != null and button.disabled and button.tooltip_text.contains("not available"),
			"staged " + label + " is explicitly unavailable")
	for label: String in ["RELOAD SAVED", "CLUB RECORD"]:
		var button: Button = _button(_app.menu, label)
		_check(button != null and not button.disabled, "ordinary navigation remains usable: " + label)


func _enabled_choice(meta: String, value: String) -> bool:
	for choice: OptionButton in _app.menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta(meta, "") == value:
			return not choice.disabled
	return false


func _admitted_workshop(stage: String) -> void:
	var before: Dictionary = _helper._held_mounted(_app.season)
	ClubCareerUI.show(_app.menu)
	await _click(_button(_app.menu, "STADIUM WORKSHOP"))
	var preview: StadiumDraftPreview = _preview(_app)
	_check(preview != null and preview.preview_property is StadiumScoreboardPropertyGeometry
		and preview.preview_property.boundary != null
		and ClubCareer.same(preview.preview_property.get_meta("scoreboard_layout", {}), _mounted),
		"previously staged15 now opens its exact complete production assembly")
	_check(_enabled_choice("scoreboard_choice", "primary")
		and _enabled_choice("advanced_wall_choice", "back")
		and _enabled_choice("surface_choice", "height")
		and _button(_app.menu, "DAY / NIGHT PREVIEW") == null,
		"admitted staged data has ordinary independent controls and daylight-only preview")
	await _bounds(_app, stage)
	get_window().size = Vector2i(700, 400)
	await _bounds(_app, stage + "-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	await _choose(_app, "ST-079", 0)
	_check(not _button(_app.menu, "SAVE DRAFT").disabled
		and _button(_app.menu, "APPLY LAYOUT").disabled,
		"real staged15 edit requires Save Draft before Apply")
	await _click(_button(_app.menu, "CLUB RECORD"))
	_check(_app._dialog.visible, "leaving a mounted local edit asks before discarding")
	await _click(_app._dialog.get_cancel_button())
	_check(_app.menu.page == "stadium" and _choice(_app, "ST-079").selected == 0,
		"cancel keeps the exact local mounted selection")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(_choice(_app, "ST-079").selected == 1
		and _button(_app.menu, "SAVE DRAFT").disabled,
		"reload restores the exact saved mounted receiver")
	await _click(_button(_app.menu, "CLUB RECORD"))
	_check(_app.menu.page == "career" and not _app._dialog.visible
		and ClubCareer.same(before, _helper._held_mounted(_app.season)),
		"admitted preview, cancel, reload and navigation preserve historical field and all paid data")

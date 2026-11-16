extends "res://src/tests/stadium_displays_ui_test.gd"
## Earned career funding, real workshop input, exact ownership and production match binding.

var _app: SeasonApp
var _manual: String = ""
var _second_manual: String = ""
var _electronic: String = ""
var _video: String = ""
var _signs: Array[String] = []
var _save_path: String = ""
var _legacy_layout: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_save_path = "user://scoreboard-workshop-ui-%d.json" % OS.get_process_id()
	SeasonSave.path = _save_path
	_cleanup()
	get_window().size = Vector2i(1280, 720)
	_check(StadiumScoreboardLayout.RUNTIME_READY, "production scoreboard workshop is enabled")
	if _failures == 0:
		await _exercise_workshop()
	SeasonSave.path = _save_path
	get_window().size = Vector2i(1280, 720)
	if is_instance_valid(_app):
		if _app.lab != null:
			_app._close_match()
		_app.queue_free()
		await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro scoreboard workshop passed: real purchases, primary storage, "
				+ "advanced walls, atomic saves, cameras and production match binding."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _exercise_workshop() -> void:
	var funding_started: int = Time.get_ticks_msec()
	_trace("funding begin")
	var helper: Node = load("res://src/tests/stadium_scoreboard_save_test.gd").new()
	var funded: SeasonState = helper._fund_boards()
	_trace("funding end", funding_started)
	_check(
		helper._failures == 0 and funded != null,
		"off-tree funding completes twenty-two real synthetic scheduled seasons"
	)
	helper.free()
	if _failures != 0:
		return
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_check(_app.season != null, "actual app restores the funded career")
	if _app.season == null:
		return
	_app.begin_season(754, true)
	_check(
		_app.season.phase == SeasonState.Phase.DRAFT and _app.season.career.balance() == 4315,
		"a fresh editable season retains exactly 4315 earned Club Bucks"
	)
	StadiumEditorUI.show(_app.menu)
	_check(
		(
			_meta_choice("scoreboard_choice", "primary") != null
			and _meta_choice("advanced_wall_choice", "back") != null
			and _button(_app.menu, "SAVE DRAFT") != null
		),
		"the actual workshop exposes its primary, advanced-back and save controls"
	)
	for stage: Callable in [
		_legacy_displays,
		_board_purchases,
		_wall_purchases,
		_migrate_primary,
		_complete_advanced_draft,
		_atomic_save_apply,
		_new_manual_purchase,
		_surface_and_storage,
		_dirty_stale_controls,
		_restart_and_play
	]:
		if _failures != 0:
			break
		var stage_name: String = str(stage.get_method())
		var stage_started: int = Time.get_ticks_msec()
		_trace("stage begin " + stage_name)
		await stage.call()
		_trace("stage end %s failures=%d" % [stage_name, _failures], stage_started)


func _legacy_displays() -> void:
	var initial: Dictionary = _ledger().view().stadium_active.duplicate(true)
	var purchase_revision: int = _ledger().revision()
	_manual = "purchase:stadium-buy:%d:0" % purchase_revision
	await _click(_buy_button(_app, "ST-039"))
	_check(
		(
			not _app._dialog.visible
			and _app.season.career.balance() == 3875
			and _ledger().construction().copies.has(_manual)
		),
		"legacy manual button preserves immediate purchase and stadium-buy receipt identity"
	)
	var paid: Dictionary = SeasonSave.snapshot(_app.season)
	var paid_primary: String = FileAccess.get_file_as_string(_save_path)
	var replay: Dictionary = ClubConstruction.buy_copy(_app.season, "ST-039", purchase_revision)
	_check(replay.ok and replay.replayed
		and ClubCareer.same(paid, SeasonSave.snapshot(_app.season))
		and paid_primary == FileAccess.get_file_as_string(_save_path),
		"repeated actual receipt cannot mint another manual or charge its blueprint twice")
	var replayed: Dictionary = _profile()
	_check(not ClubConstruction.buy_copy(_app.season, "ST-039", purchase_revision, 2).ok
		and not ClubConstruction.buy_copy(_app.season, "ST-041", purchase_revision).ok
		and _unchanged(replayed),
		"same receipt cannot be reused for a changed quantity or item")
	if purchase_revision > 0:
		_check(not ClubConstruction.buy_copy(_app.season, "ST-039", 0).ok
			and _unchanged(replayed), "unrelated stale revision is not the actual paid receipt")
	for index in range(2):
		_signs.append("purchase:stadium-buy:%d:0" % _ledger().revision())
		await _click(_buy_button(_app, "ST-041"))
	_check(
		(
			_app.season.career.balance() == 3725
			and ClubCareer.same(initial, _ledger().view().stadium_active)
		),
		"two actual signs charge one blueprint and purchases never activate a field"
	)
	if _failures != 0:
		return
	await _pick_copy(_app, _manual, 1)
	await _pick_copy(_app, _signs[0], 1)
	await _pick_copy(_app, _signs[1], 2)
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _click(_button(_app.menu, "APPLY LAYOUT"))
	_legacy_layout = _ledger().view().stadium_active.duplicate(true)
	_check(
		_legacy_layout.get("version") == 4 and _legacy_layout.get("displays", []).size() == 3,
		"legacy manual and both exact signs apply without an automatic layout14 migration"
	)
	var primary: OptionButton = _meta_choice("scoreboard_choice", "primary")
	_check(
		primary != null and primary.get_item_text(primary.selected).contains("retained"),
		"opening the primary selector preserves old manual placements until explicitly selected"
	)
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(
		(
			ClubCareer.same(_legacy_layout, _ledger().view().stadium_active)
			and ClubCareer.same(_legacy_layout, _ledger().view().stadium_draft)
		),
		"reopening the legacy workshop never rewrites its saved model or layout"
	)


func _board_purchases() -> void:
	var before: Dictionary = _profile()
	var revision: int = _ledger().revision()
	await _purchase("scoreboard_buy", "ST-090", 700, false)
	_check(_unchanged(before), "cancelled electronic confirmation preserves file and career")
	SeasonSave.path = _save_path + "/missing/file.json"
	await _purchase("scoreboard_buy", "ST-090", 700)
	_check(_unchanged(before), "failed electronic save preserves wallet, ownership and both files")
	SeasonSave.path = _save_path
	await _purchase("scoreboard_buy", "ST-090", 700)
	_electronic = "scoreboard:stadium-scoreboard:%d:0" % revision
	_check(
		_ledger().scoreboards().copies.has(_electronic) and _app.season.career.balance() == 3025,
		"retry buys exactly one electronic board through the actual confirmation"
	)
	var paid: Dictionary = _profile()
	_check(
		(
			ClubConstruction.buy_scoreboard(_app.season, "ST-090", 1, revision).get(
				"replayed", false
			)
			and ClubCareer.same(paid.season, SeasonSave.snapshot(_app.season))
			and paid.primary == FileAccess.get_file_as_string(_save_path)
		),
		"duplicate confirmed electronic request preserves exact copy, blueprint and debit"
	)
	revision = _ledger().revision()
	await _purchase("scoreboard_buy", "ST-040", 1020)
	_video = "purchase:stadium-scoreboard:%d:0" % revision
	_check(
		_ledger().construction().copies.has(_video) and _app.season.career.balance() == 2005,
		"video ownership uses the standard inventory and the earned twenty-two-season gate"
	)
	var primary: OptionButton = _meta_choice("scoreboard_choice", "primary")
	var index: int = _option_index(primary, _video)
	_check(
		(
			index >= 0
			and primary.is_item_disabled(index)
			and not primary.get_item_tooltip(index).is_empty()
		),
		"owned video remains visibly disabled with a reason on the Backyard property"
	)
	_check(
		(
			_paid_choice(_app, _video) == null
			and ClubCareer.same(_legacy_layout, _ledger().view().stadium_active)
		),
		"stored video has no generic obstacle route and no purchase changes the active field"
	)


func _wall_purchases() -> void:
	var choice: OptionButton = _meta_choice("advanced_wall_choice", "back")
	var index: int = _option_index(choice, "Left-field shelf • Plywood")
	_check(
		index >= 0 and choice.is_item_disabled(index),
		"the player-facing shelf is unavailable before its complete owned recipe"
	)
	await _purchase("advanced_wall_buy", "right_shelf:ST-024", 930)
	_check(
		(
			_count_item(_ledger().construction().copies, "ST-024") == 19
			and _ledger().construction().blueprints.has("ST-024")
			and not _ledger().wall_pieces().blueprints.has("ST-024-L")
		),
		"nineteen standard panels include only the independent standard blueprint"
	)
	choice = _meta_choice("advanced_wall_choice", "back")
	index = _option_index(choice, "Left-field shelf • Plywood")
	_check(
		index >= 0 and choice.is_item_disabled(index),
		"standard panels alone cannot select the mixed-height shelf"
	)
	await _purchase("advanced_wall_buy", "right_shelf:ST-024-L", 465)
	_check(
		(
			_count_item(_ledger().wall_pieces().stock.copies, "ST-024-L") == 7
			and _ledger().wall_pieces().blueprints.has("ST-024-L")
			and not _ledger().wall_pieces().blueprints.has("ST-024-T")
			and _app.season.career.balance() == 610
		),
		"seven low panels buy their own blueprint; all purchases stay within 4315 earned CB"
	)
	for item: String in ["ST-024", "ST-024-L"]:
		var button: Button = _meta_button("advanced_wall_buy", "right_shelf:" + item)
		_check(
			button != null and button.disabled and button.text.contains("SET OWNED"),
			"complete exact-height recipe purchases are disabled instead of charging again"
		)
	_check(
		ClubCareer.same(_legacy_layout, _ledger().view().stadium_active),
		"complete wall purchases stay in storage until explicitly selected, saved and applied"
	)


func _migrate_primary() -> void:
	await _pick_primary(_manual)
	var draft: Dictionary = _draft14()
	_check(
		draft.get("version") == 14 and draft.get("scoreboards", []).size() == 1,
		"an explicit primary selection proposes exactly one complete layout14 board"
	)
	if draft.get("scoreboards", []).size() != 1:
		return
	_check(
		(
			draft.scoreboards[0].copy == _manual
			and draft.scoreboards[0].model == "manual-v2"
			and _sign_copies(draft) == _signs
			and draft.displays.size() == 2
		),
		"legacy migration reuses its exact manual copy and preserves both sign placements"
	)
	_check(
		(
			_paid_choice(_app, _manual) == null
			and _meta_button("scoreboard_buy", "ST-039").disabled
			and _button(_app.menu, "APPLY LAYOUT").disabled
		),
		"new14 avoids duplicate legacy placement and dirty drafts lock purchases and Apply"
	)
	await _pick_meta("scoreboard_choice", "site", 1)
	await _focus_board(_manual, "scoreboard-workshop-manual")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _focus_board(_manual, "scoreboard-workshop-manual-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	await _pick_primary(_electronic)
	draft = _draft14()
	_check(
		(
			draft.get("scoreboards", []).size() == 1
			and draft.scoreboards[0].copy == _electronic
			and _sign_copies(draft) == _signs
			and _ledger().construction().copies.has(_manual)
		),
		"electronic replacement stores the exact manual for free without disturbing signs"
	)
	await _pick_meta("scoreboard_choice", "primary", 0)
	draft = _draft14()
	_check(
		draft.get("scoreboards", []).is_empty() and _sign_copies(draft) == _signs,
		"Stored removes every primary placement but preserves the signs and owned copies"
	)
	await _pick_primary(_electronic)
	await _pick_meta("scoreboard_choice", "site", 1)
	var sites: OptionButton = _meta_choice("scoreboard_choice", "site")
	_check(
		(
			sites != null
			and sites.item_count == (3 if StadiumMountedScoreboardLayout.RUNTIME_READY else 2)
			and sites.get_item_text(0) == "Right-field perimeter"
			and sites.get_item_text(1) == "Left-field perimeter"
		),
		"original perimeter choices retain their order alongside the qualified mounted choice"
	)
	var snapshot: Dictionary = _profile()
	var rejected: Dictionary = StadiumScoreboardUI.propose(
		_draft14(),
		_ledger().construction(),
		_ledger().wall_pieces(),
		_ledger().scoreboards(),
		_ledger().surface_owned(),
		_ledger().view().land,
		_electronic,
		"BOARD-UNKNOWN"
	)
	_check(
		not rejected.ok and _unchanged(snapshot),
		"an unknown site cannot be published through the workshop proposal path"
	)
	_check(
		_button(_app.menu, "DAY / NIGHT PREVIEW") == null and not _preview(_app).night_eligible,
		"new14 has no unsupported night toggle"
	)


func _complete_advanced_draft() -> void:
	var before: Dictionary = _draft14()
	var choice: OptionButton = _meta_choice("advanced_wall_choice", "back")
	var index: int = _option_index(choice, "Left-field shelf • Plywood")
	await _pick_meta("advanced_wall_choice", "back", index)
	var draft: Dictionary = _draft14()
	_check(
		(
			draft.get("advanced_back", {}).get("shape") == "right_shelf"
			and draft.advanced_back.copies.size() == 26
			and draft.walls.back.is_empty()
			and draft.walls.left == before.walls.left
			and draft.walls.right == before.walls.right
			and draft.surface == before.surface
			and draft.scoreboards == before.scoreboards
			and _sign_copies(draft) == _signs
		),
		"actual shelf option uses all 19 standard and 7 low copies and preserves independent choices"
	)
	if _failures != 0:
		return
	var preview: StadiumDraftPreview = _preview(_app)
	_check(
		(
			preview.preview_property is StadiumScoreboardPropertyGeometry
			and preview.preview_property.boundary is StadiumHeightBoundaryBody
		),
		"the real preview builds the complete scoreboard property and height-aware boundary"
	)
	await _click(_button(_app.menu, "FIELD VIEW"))
	await _bounds(_app, "scoreboard-workshop-complete-field")
	await _focus_board(_electronic, "scoreboard-workshop-electronic")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _focus_board(_electronic, "scoreboard-workshop-electronic-small")
	await _click(_button(_app.menu, "FIELD VIEW"))
	await _bounds(_app, "scoreboard-workshop-complete-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	_check(
		_button(_app.menu, "DAY / NIGHT PREVIEW") == null,
		"advanced layout14 remains daylight-only in both window sizes"
	)


func _atomic_save_apply() -> void:
	var draft: Dictionary = _draft14()
	var before: Dictionary = _profile()
	SeasonSave.path = _save_path + "/missing/file.json"
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_check(
		_unchanged(before) and ClubCareer.same(draft, _draft14()),
		"failed actual Save preserves local14, active field, journal, wallet and both files"
	)
	SeasonSave.path = _save_path
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_check(
		(
			ClubCareer.same(draft, _ledger().view().stadium_draft)
			and ClubCareer.same(_legacy_layout, _ledger().view().stadium_active)
		),
		"successful Save commits only the intended draft"
	)
	before = _profile()
	await _apply(false)
	_check(_unchanged(before), "cancelled complete-layout Apply changes nothing")
	SeasonSave.path = _save_path + "/missing/file.json"
	await _apply()
	_check(
		_unchanged(before), "failed confirmed Apply preserves entry, active field and both files"
	)
	SeasonSave.path = _save_path
	await _apply()
	_check(
		(
			ClubCareer.same(draft, _ledger().view().stadium_active)
			and _app.season.home_property.get("version") == 12
			and ClubCareer.same(draft, _app.season.home_property.layout)
			and StadiumLayoutSnapshot.matches(_app.season.home_property, _ledger())
			and _app.season.career.balance() == 610
		),
		"actual Apply atomically freezes complete entry12 without a second purchase or debit"
	)
	_check(
		_button(_app.menu, "APPLY LAYOUT").disabled,
		"already applied exact field cannot be applied again"
	)


func _new_manual_purchase() -> void:
	var before: Dictionary = _profile()
	var buy: Button = _meta_button("scoreboard_buy", "ST-039")
	_check(
		buy != null and not buy.has_meta("stadium_buy"),
		"new14 manual purchase uses only the scoreboard wrapper"
	)
	await _purchase("scoreboard_buy", "ST-039", 100, false)
	_check(_unchanged(before), "owned manual quotes only its copy price and cancellation is free")
	var revision: int = _ledger().revision()
	await _purchase("scoreboard_buy", "ST-039", 100)
	_second_manual = "purchase:stadium-scoreboard:%d:0" % revision
	_check(
		(
			_ledger().construction().copies.has(_manual)
			and _ledger().construction().copies.has(_second_manual)
			and _count_item(_ledger().construction().copies, "ST-039") == 2
			and _app.season.career.balance() == 510
			and ClubCareer.same(before.season.home_property, _app.season.home_property)
		),
		"new14 buys a second exact manual for only 100 CB without recharging its blueprint"
	)
	if _failures != 0:
		return
	await _pick_primary(_second_manual)
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	var active: Dictionary = _ledger().view().stadium_active
	_check(
		(
			active.get("scoreboards", []).size() == 1
			and active.scoreboards[0].copy == _second_manual
			and not _preview(_app).positions.has(_manual)
			and not _preview(_app).positions.has(_electronic)
			and _sign_copies(active) == _signs
		),
		"choosing the new manual installs only that exact copy and stores both replaced boards"
	)
	await _pick_primary(_electronic)
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	_check(
		(
			not _preview(_app).positions.has(_manual)
			and not _preview(_app).positions.has(_second_manual)
			and _ledger().construction().copies.has(_manual)
			and _ledger().construction().copies.has(_second_manual)
		),
		"both independently purchased manual copies remain owned and stored after replacement"
	)


func _surface_and_storage() -> void:
	var before: Dictionary = _draft14()
	var choice: OptionButton = _meta_choice("surface_choice", "height")
	_check(
		choice != null and not choice.disabled,
		"legacy-owned grass exposes independent mowing-height controls on14"
	)
	if choice == null:
		return
	await _pick_meta("surface_choice", "height", 3)
	var draft: Dictionary = _draft14()
	_check(
		(
			draft.get("surface", {}).get("height") == "long"
			and draft.advanced_back == before.advanced_back
			and draft.scoreboards == before.scoreboards
			and draft.walls == before.walls
			and draft.displays == before.displays
		),
		"changing grass height preserves the advanced wall, exact primary and signs"
	)
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	before = _draft14()
	await _pick_meta("scoreboard_choice", "primary", 0)
	var stored_started: int = Time.get_ticks_msec()
	_trace("Stored save begin")
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_trace("Stored save end", stored_started)
	stored_started = Time.get_ticks_msec()
	_trace("Stored Apply opener begin")
	await _click(_button(_app.menu, "APPLY LAYOUT"))
	_trace("Stored Apply opener end", stored_started)
	_check(
		(
			_app._dialog.visible
			and _app._dialog.dialog_text.contains("Electronic club scoreboard")
			and _app._dialog.dialog_text.contains("1 displaced")
		),
		"actual storage confirmation names the displaced extension copy"
	)
	if not _app._dialog.visible:
		return
	stored_started = Time.get_ticks_msec()
	_trace("Stored modal OK begin")
	await _click(_app._dialog.get_ok_button())
	_trace("Stored modal OK end", stored_started)
	var active: Dictionary = _ledger().view().stadium_active
	_check(
		(
			active.scoreboards.is_empty()
			and active.advanced_back == before.advanced_back
			and active.surface == before.surface
			and _sign_copies(active) == _signs
			and _ledger().scoreboards().copies.has(_electronic)
		),
		"applying Stored removes only the board and retains all paid ownership"
	)
	await _pick_primary(_electronic)
	await _pick_meta("scoreboard_choice", "site", 1)
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	_check(_app.season.career.balance() == 510, "surface, storage and replacement are free")


func _dirty_stale_controls() -> void:
	await _pick_meta("surface_choice", "height", 0)
	var dirty: Dictionary = _draft14()
	await _click(_button(_app.menu, "CLUB RECORD"))
	_check(_app._dialog.visible, "leaving the dirty complete field asks before discarding")
	if not _app._dialog.visible:
		return
	await _click(_app._dialog.get_cancel_button())
	_check(
		_app.menu.page == "stadium" and ClubCareer.same(dirty, _draft14()),
		"cancelled navigation retains the complete local14 draft"
	)
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(_draft14().surface.height == "long", "reload discards the unsaved height change")
	await _pick_meta("surface_choice", "height", 0)
	var newer: Dictionary = _ledger().view().stadium_draft.duplicate(true)
	newer.surface.height = "medium"
	_check(
		ClubConstruction.save_draft(_app.season, newer, _ledger().revision()).ok,
		"a separate newer valid save creates a genuine stale editor revision"
	)
	var before: Dictionary = _profile()
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_check(
		(
			_unchanged(before)
			and _button(_app.menu, "SAVE DRAFT").disabled
			and _meta_choice("scoreboard_choice", "primary").disabled
			and _meta_choice("advanced_wall_choice", "back").disabled
			and _meta_choice("surface_choice", "height").disabled
			and _meta_button("scoreboard_buy", "ST-039").disabled
		),
		"stale input cannot overwrite the newer draft; every related editor control locks"
	)
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(ClubCareer.same(newer, _draft14()), "explicit reload adopts the newer complete14")
	await _apply()


func _restart_and_play() -> void:
	var before: Dictionary = SeasonSave.snapshot(_app.season)
	var key: String = StadiumLayoutSnapshot.key(_app.season.home_property)
	_app.queue_free()
	await _frames()
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_check(_app.season != null, "whole-app restart restores the workshop career")
	if _app.season == null:
		return
	_check(
		ClubCareer.same(before, SeasonSave.snapshot(_app.season)),
		"restart preserves complete14, all three inventories, receipts and earned balance"
	)
	StadiumEditorUI.show(_app.menu)
	var draft: Dictionary = _draft14()
	_check(
		(
			draft.get("scoreboards", []).size() == 1
			and draft.scoreboards[0].copy == _electronic
			and draft.surface.height == "medium"
			and _sign_copies(draft) == _signs
		),
		"restart rebuilds the actual selected primary, surface and signs"
	)
	for pick in range(4):
		var offers: Array = _app.season.offers()
		_check(not offers.is_empty(), "real player draft has an available offered player")
		if offers.is_empty():
			return
		_app.choose_player(offers[0])
	StadiumEditorUI.show(_app.menu)
	_check(
		(
			_meta_choice("scoreboard_choice", "primary").disabled
			and _meta_choice("advanced_wall_choice", "back").disabled
			and _meta_button("scoreboard_buy", "ST-039").disabled
			and _button(_app.menu, "SAVE DRAFT").disabled
			and _button(_app.menu, "APPLY LAYOUT").disabled
		),
		"roster drafting locks real primary, advanced-wall, purchase, save and Apply controls"
	)
	var fixture: Dictionary = {}
	for candidate: Dictionary in _app.season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	_check(not fixture.is_empty(), "the actual schedule contains a human home fixture")
	if fixture.is_empty():
		return
	var state: MatchState = SeasonPhysicalFixtures.match_for(_app.season, fixture)
	_check(
		state != null and state.stadium.get("version") == 13,
		"the actual human fixture freezes the complete production13 stadium"
	)
	if state == null or state.stadium.get("version") != 13:
		return
	_app._open_match(state, true, true)
	_check(
		_app.lab != null and _app.lab.has_meta("stadium_property"),
		"actual human match opens with the saved property"
	)
	if _app.lab != null and _app.lab.has_meta("stadium_property"):
		await _live_binding(state)
	var restored: SeasonState = SeasonSave.restore()
	_check(
		restored != null and StadiumLayoutSnapshot.key(restored.home_property) == key,
		"game entry and exit preserve the exact saved home-field identity"
	)


func _live_binding(state: MatchState) -> void:
	var value: Variant = _app.lab.get_meta("stadium_property")
	_check(
		value is StadiumScoreboardPropertyGeometry,
		"production match installs the complete scoreboard property class"
	)
	if not value is StadiumScoreboardPropertyGeometry:
		return
	var property: StadiumScoreboardPropertyGeometry = value
	_check(
		property != null and property.board_objects.has(_electronic),
		"runtime installs the exact chosen electronic copy"
	)
	if property == null or not property.board_objects.has(_electronic):
		return
	await _frames(4)
	var display: Node = property.board_objects[_electronic].get_node_or_null("Visual/ScoreDisplay")
	var readout: Dictionary = StadiumScoreboardReadout.capture(_app.lab._match_state)
	_check(
		(
			display is StadiumScoreboardTierDisplay
			and display._match == _app.lab._match_state
			and not readout.is_empty()
			and display.shown == readout.get("base", {})
		),
		"the actual board observes the actual game readout rather than fabricated preview data"
	)
	_check(
		(
			StadiumScoreboardRuntime.installed(_app.lab, state.stadium)
			and property.board_objects.size() == 1
			and property.objects.has(_signs[0])
			and property.objects.has(_signs[1])
			and not property.objects.has(_manual)
			and not property.objects.has(_second_manual)
			and not property.objects.has(_video)
			and property.route_obstacles().is_empty()
		),
		"production integrity validates one board, both signs and no stored-copy route obstacles"
	)
	_check(
		(
			property.boundary is StadiumHeightBoundaryBody
			and _app.lab._camera_director.tracking_visibility is StadiumHeightCameraVisibility
		),
		"real game reuses the qualified mixed-height boundary and camera observer"
	)
	await _capture(get_viewport(), "scoreboard-workshop-human-home")
	_app._close_match()
	await _frames()


func _purchase(meta: String, value: String, cost: int, confirm: bool = true) -> void:
	await _click(_meta_button(meta, value))
	_check(
		_app._dialog.visible and _app._dialog.dialog_text.contains("%d Club Bucks" % cost),
		"actual confirmation displays the exact quoted total for " + value
	)
	if not _app._dialog.visible:
		return
	await _click(_app._dialog.get_ok_button() if confirm else _app._dialog.get_cancel_button())
	_check(not _app._dialog.visible, "the completed or cancelled purchase dialog closes")


func _apply(confirm: bool = true) -> void:
	await _click(_button(_app.menu, "APPLY LAYOUT"))
	_check(
		(
			_app._dialog.visible
			and _app._dialog.dialog_text.contains("complete stadium layout")
			and _app._dialog.dialog_text.contains("No Club Bucks charge")
		),
		"actual Apply discloses complete geometry and free storage"
	)
	if not _app._dialog.visible:
		return
	await _click(_app._dialog.get_ok_button() if confirm else _app._dialog.get_cancel_button())


func _pick_primary(copy: String) -> void:
	var index: int = _option_index(_meta_choice("scoreboard_choice", "primary"), copy)
	await _pick_meta("scoreboard_choice", "primary", index)


func _pick_meta(meta: String, value: String, index: int) -> void:
	await _frames()
	var choice: OptionButton = _meta_choice(meta, value)
	_check(
		choice != null and index >= 0 and index < choice.item_count,
		"the requested real option exists: " + meta + ":" + value
	)
	if choice == null or index < 0 or index >= choice.item_count:
		return
	_check(
		not choice.disabled and not choice.is_item_disabled(index),
		"the requested exact option is currently available"
	)
	if choice.disabled or choice.is_item_disabled(index):
		return
	if choice.selected == index:
		return
	var allowed: Array[int] = []
	for option in range(choice.item_count):
		if not choice.is_item_disabled(option) or option == choice.selected:
			allowed.append(option)
	var previous: int = allowed.find(choice.selected)
	var target: int = allowed.find(index)
	choice.grab_focus()
	await _frames()
	await _key(KEY_ENTER)
	for step in range(absi(target - previous)):
		await _key(KEY_DOWN if target > previous else KEY_UP)
	await _key(KEY_ENTER)
	await _frames()
	choice = _meta_choice(meta, value)
	_check(
		choice != null and choice.selected == index,
		"actual keyboard input chooses the requested " + meta + ":" + value
	)


func _focus_board(copy: String, label: String) -> void:
	var preview: StadiumDraftPreview = _preview(_app)
	_check(
		preview != null and preview.board_bounds.has(copy),
		"the real preview contains an authored board envelope"
	)
	if preview == null or not preview.board_bounds.has(copy):
		return
	await _click(_focus_button(_app, copy))
	await _bounds(_app, label)
	var bounds: AABB = preview.board_bounds[copy]
	var camera: Camera3D = preview.camera
	var viewport: Rect2 = camera.get_viewport().get_visible_rect()
	_check(
		camera.projection == Camera3D.PROJECTION_PERSPECTIVE,
		"the actual focus button selects the model-aware camera"
	)
	for index in range(8):
		var point: Vector3 = bounds.get_endpoint(index)
		_check(
			(
				not camera.is_position_behind(point)
				and viewport.has_point(camera.unproject_position(point))
			),
			"focus fits every real envelope corner including its feet: " + label
		)


func _meta_button(meta: String, value: String) -> Button:
	for button: Button in _app.menu._body.find_children("*", "Button", true, false):
		if button.get_meta(meta, "") == value:
			return button
	return null


func _meta_choice(meta: String, value: String) -> OptionButton:
	for option: OptionButton in _app.menu._body.find_children("*", "OptionButton", true, false):
		if option.get_meta(meta, "") == value:
			return option
	return null


func _option_index(choice: OptionButton, text: String) -> int:
	if choice != null:
		for index in range(choice.item_count):
			if choice.get_item_text(index).contains(text):
				return index
	return -1


func _ledger() -> ClubAssetLedger:
	return ClubPlayers.assets(_app.season.career)


func _draft14() -> Dictionary:
	var preview: StadiumDraftPreview = _preview(_app)
	return (
		preview.preview_property.get_meta("scoreboard_layout", {}).duplicate(true)
		if preview != null and preview.preview_property != null
		else {}
	)


func _profile() -> Dictionary:
	return {
		"season": SeasonSave.snapshot(_app.season),
		"primary": FileAccess.get_file_as_string(_save_path),
		"backup": FileAccess.get_file_as_string(_save_path + ".bak")
	}


func _unchanged(before: Dictionary) -> bool:
	return (
		ClubCareer.same(before.season, SeasonSave.snapshot(_app.season))
		and before.primary == FileAccess.get_file_as_string(_save_path)
		and before.backup == FileAccess.get_file_as_string(_save_path + ".bak")
	)


func _sign_copies(layout: Dictionary) -> Array[String]:
	var copies: Array[String] = []
	for row: Dictionary in layout.get("displays", []):
		if _signs.has(row.copy):
			copies.append(row.copy)
	copies.sort()
	return copies


func _count_item(copies: Dictionary, item: String) -> int:
	var count: int = 0
	for row: Dictionary in copies.values():
		if row.item == item:
			count += 1
	return count


func _click(button: Button, expected_press: bool = true) -> void:
	var label: String = button.text if is_instance_valid(button) else "<missing button>"
	var started: int = Time.get_ticks_msec()
	_trace("click begin " + label)
	await super._click(button, expected_press)
	_trace("click end " + label, started)


func _trace(message: String, started: int = -1) -> void:
	var now: int = Time.get_ticks_msec()
	var elapsed: String = " dt=%dms" % (now - started) if started >= 0 else ""
	print("SCOREBOARD_WORKSHOP t=%dms%s %s" % [now, elapsed, message])

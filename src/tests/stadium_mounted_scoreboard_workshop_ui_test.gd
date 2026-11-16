extends "res://src/tests/stadium_scoreboard_workshop_ui_test.gd"
## Real keyboard/mouse selections, complete assembly and atomic paid-prefix persistence.

var _second_electronic: String = ""
var _owned_before: Dictionary = {}
var _historical: Dictionary = {}


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_save_path = "user://mounted-scoreboard-workshop-ui-%d.json" % OS.get_process_id()
	SeasonSave.path = _save_path
	_cleanup()
	get_window().size = Vector2i(1280, 720)
	_check(StadiumMountedScoreboardLayout.RUNTIME_READY, "complete mounted workshop is admitted")
	if _failures == 0:
		await _mounted_workshop()
	SeasonSave.path = _save_path
	get_window().size = Vector2i(1280, 720)
	if is_instance_valid(_app):
		_app.queue_free()
		await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard workshop passed: actual center input, complete preview, "
			+ "replacement, storage, paid ownership and atomic save/reopen.")
	get_tree().quit(0 if _failures == 0 else 1)


func _mounted_workshop() -> void:
	var helper: Node = load("res://src/tests/stadium_scoreboard_save_test.gd").new()
	var funded: SeasonState = helper._fund_boards()
	_check(funded != null and helper._failures == 0,
		"unchanged twenty-two scheduled seasons earn the actual workshop budget")
	helper.free()
	if _failures != 0:
		return
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_app.begin_season(756, true)
	StadiumEditorUI.show(_app.menu)
	for stage: Callable in [_legacy_displays, _board_purchases, _wall_purchases,
		_paid_spares, _historical_primary, _center_selection, _independent_controls,
		_atomic_mounted, _replacement_storage, _mounted_stale, _mounted_reopen]:
		if _failures != 0:
			break
		_trace("mounted stage " + str(stage.get_method()))
		await stage.call()


func _paid_spares() -> void:
	var revision: int = _ledger().revision()
	await _purchase("scoreboard_buy", "ST-090", 160)
	_second_electronic = "scoreboard:stadium-scoreboard:%d:0" % revision
	_check(ClubConstruction.buy_wall_pieces(_app.season, "ST-024-L", 1,
		_ledger().revision()).ok, "one extra low panel uses the original paid receipt")
	StadiumEditorUI.show(_app.menu)
	await _purchase("wall_buy", "ST-024:23", 120)
	_check(_ledger().scoreboards().copies.has(_second_electronic)
		and _count_item(_ledger().wall_pieces().stock.copies, "ST-024-L") == 8
		and _count_item(_ledger().construction().copies, "ST-024") == 23
		and _ledger().construction().copies.has(_video)
		and _ledger().balance() == 315,
		"all three inventories include exact paid surplus without free copies or new prices")
	_owned_before = _ownership()


func _historical_primary() -> void:
	await _pick_primary(_electronic)
	var old: Dictionary = _draft14()
	_check(old.get("version") == 14 and old.displays.size() == 2
		and _sign_copies(old) == _signs and _paid_choice(_app, _manual) == null,
		"explicit perimeter replacement stores legacy manual and keeps signs without opting into15")
	old.scoreboards = [{"copy": _electronic, "item": "ST-090", "model": "electronic-v2",
		"site": "BOARD-LEFT-v2"}, {"copy": _second_electronic, "item": "ST-090",
		"model": "electronic-v2", "site": "BOARD-RIGHT-v2"}]
	StadiumEditorUI.show(_app.menu, old, _ledger().revision())
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	_historical = _ledger().view().stadium_active.duplicate(true)
	_check(ClubCareer.same(_historical, old),
		"historical multi-board14 remains a valid deliberate complete layout")
	var before: Dictionary = _profile()
	await _reopen()
	var primary: OptionButton = _meta_choice("scoreboard_choice", "primary")
	_check(primary.get_item_text(primary.selected).contains("retained")
		and ClubCareer.same(_historical, _draft14()) and _unchanged(before),
		"whole-app reopen shows retained historical multi-board placements without normalization")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(ClubCareer.same(_historical, _draft14()) and _unchanged(before),
		"historical reload preserves both board copies, paid receipts, wallet and exact files")


func _center_selection() -> void:
	var before: Dictionary = _profile()
	await _pick_primary(_electronic)
	_check(_draft14().version == 14 and _draft14().scoreboards.size() == 1,
		"choosing one primary replaces historical copies but preserves the old family")
	var sites: OptionButton = _meta_choice("scoreboard_choice", "site")
	var center: int = _option_index(sites, "Raised center field")
	_check(sites.item_count == 3 and center == 2
		and sites.get_item_text(0) == "Right-field perimeter"
		and sites.get_item_text(1) == "Left-field perimeter",
		"exact owned electronic offers the two unchanged perimeter sites and one explicit center")
	await _pick_meta("scoreboard_choice", "site", center)
	var draft: Dictionary = _draft14()
	_check(draft.get("version") == 15 and draft.get("mount_catalog") == 1
		and draft.scoreboards.size() == 1 and draft.scoreboards[0].copy == _electronic
		and draft.scoreboards[0].site == StadiumScoreboardMountCatalog.CENTER_SITE
		and draft.scoreboards[0].mount_profile == StadiumScoreboardMountCatalog.CENTER_PROFILE,
		"actual center input explicitly upgrades14 to exact15/catalog1 using the owned copy")
	_check(_sign_copies(draft) == _signs and _unchanged(before)
		and _paid_choice(_app, _manual) == null and _button(_app.menu, "APPLY LAYOUT").disabled
		and _meta_button("scoreboard_buy", "ST-090").disabled,
		"center preview stores replaced boards, preserves signs and locks purchase/Apply until Save")
	_negative_proposals(draft)
	await _focus_board(_electronic, "mounted-workshop-center")
	get_window().size = Vector2i(700, 400)
	await _frames()
	await _focus_board(_electronic, "mounted-workshop-center-small")
	await _click(_button(_app.menu, "FIELD VIEW"))
	await _bounds(_app, "mounted-workshop-field-small")
	get_window().size = Vector2i(1280, 720)
	await _frames()
	var preview: StadiumDraftPreview = _preview(_app)
	_check(preview.preview_property is StadiumScoreboardPropertyGeometry
		and preview.preview_property.boundary != null
		and preview.board_bounds[_electronic] == StadiumScoreboardAssembly.bounds(draft.scoreboards[0])
		and is_equal_approx(preview.board_bounds[_electronic].size.y, 10.8)
		and not preview.positions.has(_manual) and not preview.positions.has(_second_electronic)
		and not preview.night_eligible and _button(_app.menu, "DAY / NIGHT PREVIEW") == null,
		"preview uses complete production assembly and full support bounds with no night admission")


func _negative_proposals(draft: Dictionary) -> void:
	var before: Dictionary = _profile()
	for copy: String in [_manual, _video, "same-looking-unpaid-copy", ""]:
		var result: Dictionary = StadiumScoreboardUI.propose(draft, _ledger().construction(),
			_ledger().wall_pieces(), _ledger().scoreboards(), _ledger().surface_owned(),
			_ledger().view().land, copy, StadiumScoreboardMountCatalog.CENTER_SITE)
		_check(not result.ok, "center refuses incompatible, unowned or absent exact copy: " + copy)
	for item: String in [_manual, _video]:
		var sites: Array[Dictionary] = StadiumScoreboardUI.available_sites(draft,
			_ledger().construction(), _ledger().wall_pieces(), _ledger().scoreboards(),
			_ledger().surface_owned(), _ledger().view().land, item)
		_check(sites.all(func(row: Dictionary) -> bool:
			return row.site != StadiumScoreboardMountCatalog.CENTER_SITE),
			"manual/video never gain the electronic-only center choice")
	var missing: Dictionary = StadiumScoreboardUI.propose(draft, _ledger().construction(),
		null, _ledger().scoreboards(), _ledger().surface_owned(), _ledger().view().land,
		_electronic, StadiumScoreboardMountCatalog.CENTER_SITE)
	_check(not missing.ok, "proposal requires complete three-inventory ownership")
	for bad: Dictionary in _invalid_layouts(draft):
		_check(not StadiumEditorUI._checked(_ledger(), bad).ok
			and not ClubConstruction.save_draft(_app.season, bad, _ledger().revision()).ok,
			"malformed, future or unowned mounted declaration cannot save")
	_check(not ClubConstruction.apply_draft(_app.season, draft, _ledger().revision()).ok,
		"direct mounted Apply also requires the exact previously saved draft")
	_check(_unchanged(before), "all negative proposals and callbacks preserve paid history and files")


func _invalid_layouts(draft: Dictionary) -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for field: String in ["mount_catalog", "mount_profile", "copy", "surface"]:
		var bad: Dictionary = draft.duplicate(true)
		match field:
			"mount_catalog":
				bad.mount_catalog = 2
			"mount_profile":
				bad.scoreboards[0].mount_profile = "CENTER-FUTURE-v2"
			"copy":
				bad.scoreboards[0].copy = "same-looking-unpaid-copy"
			"surface":
				bad.surface.height = "invented"
		values.append(bad)
	return values


func _independent_controls() -> void:
	var row: Dictionary = _draft14().scoreboards[0].duplicate(true)
	await _pick_meta("surface_choice", "height", 3)
	var choice: OptionButton = _meta_choice("advanced_wall_choice", "back")
	await _pick_meta("advanced_wall_choice", "back",
		_option_index(choice, "Left-field shelf • Plywood"))
	var shelf: Dictionary = _draft14()
	_check(shelf.version == 15 and shelf.advanced_back.shape == "right_shelf"
		and shelf.advanced_back.copies.size() == 26 and shelf.surface.height == "long"
		and ClubCareer.same(shelf.scoreboards[0], row) and _sign_copies(shelf) == _signs,
		"independent grass and advanced wall controls preserve the exact mounted row and signs")
	choice = _meta_choice("wall_slot", "back")
	await _pick_meta("wall_slot", "back", _option_index(choice, "Plywood • straight"))
	var ordinary: Dictionary = _draft14()
	_check(ordinary.version == 15 and ordinary.advanced_back.shape.is_empty()
		and ordinary.walls.back.shape == "straight" and ordinary.surface == shelf.surface
		and ClubCareer.same(ordinary.scoreboards, shelf.scoreboards),
		"ordinary wall control replaces only the advanced back, keeping the mounted profile")
	choice = _meta_choice("advanced_wall_choice", "back")
	await _pick_meta("advanced_wall_choice", "back",
		_option_index(choice, "Left-field shelf • Plywood"))
	await _pick_meta("surface_choice", "foundation", 0)
	_check(_draft14().version == 15 and _draft14().surface.foundation == "dirt"
		and _draft14().advanced_back == shelf.advanced_back
		and _draft14().scoreboards == shelf.scoreboards
		and _meta_choice("stadium_style", "grass").disabled
		and _meta_choice("stadium_style", "ground").disabled,
		"rough dirt remains independent and locks grass-only appearance on mounted layouts")
	await _pick_meta("surface_choice", "foundation", 2)
	await _pick_meta("surface_choice", "height", 3)
	await _click(_button(_app.menu, "FIELD VIEW"))
	await _bounds(_app, "mounted-workshop-complete-shelf")
	_check(ClubCareer.same(_ownership(), _owned_before),
		"mount, grass and complete-wall edits neither purchase nor alter any paid ownership")


func _atomic_mounted() -> void:
	var draft: Dictionary = _draft14()
	var before: Dictionary = _profile()
	var revision: int = _ledger().revision()
	SeasonSave.path = _save_path + "/missing/file.json"
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_check(_unchanged(before) and ClubCareer.same(draft, _draft14())
		and not _button(_app.menu, "SAVE DRAFT").disabled,
		"failed mounted Save preserves local retry, journal, wallet and primary/backup bytes")
	SeasonSave.path = _save_path
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_check(ClubCareer.same(draft, _ledger().view().stadium_draft)
		and ClubCareer.same(_historical, _ledger().view().stadium_active)
		and _app.season.home_property.version == 12 and _ledger().revision() == revision + 1,
		"Save commits exactly one free mounted draft event without replacing the old frozen home")
	before = _profile()
	await _apply(false)
	_check(_unchanged(before), "cancelled mounted Apply preserves draft, active field and both saves")
	SeasonSave.path = _save_path + "/missing/file.json"
	await _apply()
	_check(_unchanged(before) and ClubCareer.same(draft, _draft14()),
		"failed mounted Apply keeps exact saved draft available for atomic retry")
	SeasonSave.path = _save_path
	await _apply()
	_check(_ledger().revision() == revision + 2
		and ClubCareer.same(draft, _ledger().view().stadium_active)
		and _app.season.home_property.version == 14
		and ClubCareer.same(draft, _app.season.home_property.layout)
		and SeasonSave.snapshot(_app.season).version == 63
		and StadiumLayoutSnapshot.matches(_app.season.home_property, _ledger())
		and ClubCareer.same(_owned_before, _ownership()),
		"Apply freezes exact entry14/current save63 and paid surplus with one free event")
	var saved: Dictionary = SeasonSave.snapshot(_app.season)
	print("MOUNTED_WORKSHOP_SAVE_CONTRACT version=", saved.version,
		" home_version=", saved.home_property.version)
	var cold: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(saved, "", true, true)))
	_check(cold != null and ClubCareer.same(cold.npc_venues, _app.season.npc_venues)
		and ClubCareer.same(cold.final_venue, _app.season.final_venue)
		and StadiumLayoutSnapshot.key(cold.home_property)
		== StadiumLayoutSnapshot.key(_app.season.home_property),
		"current save63 cold replay preserves exact home and assigned venue identities")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var old: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true)))
	_check(old != null and old.npc_venues.is_empty() and old.final_venue.is_empty()
		and StadiumLayoutSnapshot.key(old.home_property)
		== StadiumLayoutSnapshot.key(_app.season.home_property),
		"historical save59 retains exact paid entry14 without invented venue assignments")
	var entry: Dictionary = _app.season.home_property
	_check(ClubCareer.same(entry.inventory, _ledger().construction().to_data())
		and ClubCareer.same(entry.wall_piece_inventory, _ledger().wall_pieces().to_data())
		and ClubCareer.same(entry.scoreboard_inventory, _ledger().scoreboards().to_data())
		and _button(_app.menu, "APPLY LAYOUT").disabled,
		"entry includes every stored standard, low-panel and electronic receipt exactly once")
	_complete_boundary_required(draft)


func _complete_boundary_required(draft: Dictionary) -> void:
	var candidate: SeasonState = SeasonSave._decode(SeasonSave.snapshot(_app.season))
	_check(candidate != null, "mounted save decodes before the incomplete-boundary guard probe")
	if candidate == null:
		return
	candidate.home_property.erase("boundary")
	var journal: Dictionary = ClubPlayers.assets(candidate.career).to_data()
	var before: Dictionary = _profile()
	var result: Dictionary = ClubConstruction.apply_draft(candidate, draft,
		ClubPlayers.assets(candidate.career).revision())
	_check(not result.ok and result.error.contains("complete boundary")
		and ClubCareer.same(journal, ClubPlayers.assets(candidate.career).to_data())
		and _unchanged(before),
		"layout15 reaches explicit complete-boundary guard before journal mutation or persistence")


func _replacement_storage() -> void:
	var before: Dictionary = _draft14()
	await _pick_primary(_second_electronic)
	var draft: Dictionary = _draft14()
	_check(draft.version == 15 and draft.scoreboards.size() == 1
		and draft.scoreboards[0].copy == _second_electronic
		and draft.scoreboards[0].mount_profile == StadiumScoreboardMountCatalog.CENTER_PROFILE
		and not _preview(_app).positions.has(_electronic),
		"new owned electronic replaces the primary at center and stores the previous exact copy")
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	await _pick_primary(_manual)
	draft = _draft14()
	_check(draft.version == 15 and draft.scoreboards[0].copy == _manual
		and draft.scoreboards[0].mount_profile.is_empty()
		and _meta_choice("scoreboard_choice", "site").item_count == 2
		and _paid_choice(_app, _manual) == null,
		"manual replacement keeps15 with empty mount profile and no duplicate legacy selector")
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	await _pick_meta("scoreboard_choice", "primary", 0)
	draft = _draft14()
	_check(draft.version == 15 and draft.scoreboards.is_empty()
		and draft.surface == before.surface and draft.advanced_back == before.advanced_back
		and _sign_copies(draft) == _signs and _preview(_app).board_bounds.is_empty(),
		"Stored keeps15, signs, grass and walls and removes every mounted/freestanding assembly")
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	await _reopen()
	_check(_draft14().version == 15 and _draft14().scoreboards.is_empty()
		and _meta_choice("scoreboard_choice", "primary").selected == 0,
		"Stored15 survives actual app restart without downgrading or resurrecting a board")
	await _pick_primary(_electronic)
	await _pick_meta("scoreboard_choice", "site", 1)
	_check(_draft14().version == 15 and _draft14().scoreboards[0].mount_profile.is_empty(),
		"explicit perimeter placement retains15 with the exact empty mount profile")
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	await _reopen()
	_check(_draft14().scoreboards[0].site == "BOARD-RIGHT-v2"
		and _draft14().scoreboards[0].mount_profile.is_empty(),
		"saved freestanding15 reopens at its unchanged perimeter site")
	await _pick_meta("scoreboard_choice", "site", 2)
	await _click(_button(_app.menu, "SAVE DRAFT"))
	await _apply()
	_check(ClubCareer.same(_ownership(), _owned_before),
		"center/perimeter/replacement/storage round trip leaves every original receipt and price exact")


func _mounted_stale() -> void:
	await _pick_meta("surface_choice", "height", 0)
	var dirty: Dictionary = _draft14()
	await _click(_button(_app.menu, "CLUB RECORD"))
	_check(_app._dialog.visible, "leaving a local mounted edit asks before discarding")
	await _click(_app._dialog.get_cancel_button())
	_check(ClubCareer.same(dirty, _draft14()), "cancelled Back retains the exact mounted local draft")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	_check(_draft14().surface.height == "long", "reload restores saved mounted grass height")
	await _pick_meta("surface_choice", "height", 0)
	var newer: Dictionary = _ledger().view().stadium_draft.duplicate(true)
	newer.surface.height = "medium"
	_check(ClubConstruction.save_draft(_app.season, newer, _ledger().revision()).ok,
		"a separate valid save advances the revision behind a real local mounted draft")
	var before: Dictionary = _profile()
	await _click(_button(_app.menu, "SAVE DRAFT"))
	_check(_unchanged(before) and _button(_app.menu, "SAVE DRAFT").disabled
		and _meta_choice("scoreboard_choice", "primary").disabled
		and _meta_choice("advanced_wall_choice", "back").disabled
		and _meta_choice("surface_choice", "height").disabled,
		"stale mounted input locks every independent editor and cannot overwrite the newer save")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	await _click(_button(_app.menu, "APPLY LAYOUT"))
	_check(_app._dialog.visible, "mounted Apply opens a revision-bound confirmation")
	var replacement: Dictionary = newer.duplicate(true)
	replacement.surface.height = "short"
	_check(ClubConstruction.save_draft(_app.season, replacement, _ledger().revision()).ok,
		"newer saved draft invalidates the previously opened mounted confirmation")
	before = _profile()
	await _click(_app._dialog.get_ok_button())
	_check(_unchanged(before) and _button(_app.menu, "APPLY LAYOUT").disabled,
		"stale mounted confirmation preserves active home, newer draft and primary/backup bytes")
	await _click(_button(_app.menu, "RELOAD SAVED"))
	await _apply()


func _mounted_reopen() -> void:
	var before: Dictionary = _profile()
	await _reopen()
	_check(_unchanged(before) and ClubCareer.same(_ownership(), _owned_before)
		and _draft14().version == 15 and _draft14().scoreboards[0].copy == _electronic
		and _draft14().scoreboards[0].mount_profile == StadiumScoreboardMountCatalog.CENTER_PROFILE
		and _draft14().surface.height == "short" and _sign_copies(_draft14()) == _signs,
		"whole-app reopen preserves complete mounted choice, signs, all three paid inventories and saves")
	var pending: Dictionary = _app.season.physical.pending.duplicate(true)
	_app.season.physical.pending = {"workshop-lock-probe": true}
	StadiumEditorUI.show(_app.menu)
	_check(_meta_choice("scoreboard_choice", "primary").disabled
		and _button(_app.menu, "SAVE DRAFT").disabled
		and _button(_app.menu, "APPLY LAYOUT").disabled,
		"pending physical work locks mounted editing before any new request is accepted")
	_app.season.physical.pending = pending
	_app.choose_player(_app.season.offers()[0])
	StadiumEditorUI.show(_app.menu)
	_check(_meta_choice("scoreboard_choice", "primary").disabled
		and _meta_choice("advanced_wall_choice", "back").disabled
		and _meta_choice("surface_choice", "height").disabled
		and _meta_button("scoreboard_buy", "ST-090").disabled
		and _button(_app.menu, "SAVE DRAFT").disabled
		and _button(_app.menu, "APPLY LAYOUT").disabled,
		"actual roster input locks mounted choices, independent controls, purchase, Save and Apply")


func _reopen() -> void:
	_app.queue_free()
	await _frames()
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_check(_app.season != null, "real app restores the latest mounted workshop save")
	StadiumEditorUI.show(_app.menu)


func _ownership() -> Dictionary:
	return {"standard": _ledger().construction().to_data(),
		"pieces": _ledger().wall_pieces().to_data(), "boards": _ledger().scoreboards().to_data(),
		"balance": _ledger().balance(), "surface": _ledger().surface_owned()}

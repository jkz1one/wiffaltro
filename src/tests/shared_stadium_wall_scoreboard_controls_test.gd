extends Node
## Synthetic funded ledger; exact reusable shared callbacks, no owner/source/visual qualification.
const Data = preload("res://src/tests/stadium_mounted_scoreboard_test_data.gd")
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
var checks: int = 0
var failures: int = 0
var count: int = 0
var preview: Dictionary = {}
var ledger: ClubAssetLedger
var menu: SeasonMenu
var app: SeasonApp

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok

func capture(next: Dictionary, revision: int) -> void:
	check(revision == ledger.revision(), "preview preserves exact paid revision")
	preview = next
	count += 1

func screen(draft: Dictionary, enabled: bool = true) -> void:
	menu._screen("shared_stadium", "Shared control fixture", "Synthetic paid ledger")
	StadiumWallItemsUI.show(menu, ledger, draft, ledger.revision(), enabled, false, capture)
	StadiumScoreboardUI.show(menu, ledger, draft, ledger.revision(), enabled, false, capture)

func choice(key: String, value: String) -> OptionButton:
	for node: Node in menu._body.find_children("*", "OptionButton", true, false):
		if node.get_meta(key, "") == value:
			return node
	return null

func index_of(control: OptionButton, text: String) -> int:
	for index in range(control.item_count):
		if control.get_item_text(index).contains(text):
			return index
	return -1

func _ready() -> void:
	ledger = Data.fund()
	if not check(ledger != null, "existing paid board/wall fixture funds"):
		get_tree().quit(1)
		return
	var original: Dictionary = Data.state(ledger)
	app = SeasonApp.new() # Deliberately off-tree: no saved owner or synthetic career installed.
	menu = SeasonMenu.new()
	add_child(menu)
	menu.build(app)
	var draft: Dictionary = StadiumStarterLayout.empty()
	screen(draft)
	var back: OptionButton = choice("wall_slot", "back")
	var index: int = index_of(back, "Plywood • straight")
	if not check(index > 0 and not back.is_item_disabled(index), "owned complete back run is selectable"):
		finish()
		return
	back.item_selected.emit(index)
	if not check(preview.get("version") == 11, "wall callback creates family11 without ordinary career"):
		finish()
		return
	check(preview.walls.back.copies.size() == 23, "whole back run binds23 distinct purchased panels")
	check(StadiumEditorUI._checked(ledger, preview).ok, "paid complete wall validates")
	draft = preview.duplicate(true)
	screen(draft)
	var electronic: String = Data.copy_id(ledger.scoreboards().copies, "ST-090")
	var primary: OptionButton = choice("scoreboard_choice", "primary")
	index = index_of(primary, electronic)
	if not check(index > 0 and not primary.is_item_disabled(index), "exact purchased electronic board is selectable"):
		finish()
		return
	primary.item_selected.emit(index)
	check(preview.version == 14 and preview.scoreboards.size() == 1 and preview.scoreboards[0].copy == electronic,
		"primary callback selects exact paid electronic board in family14")
	check(ClubCareer.same(preview.walls, draft.walls), "scoreboard upgrade preserves complete paid wall")
	check(StadiumEditorUI._checked(ledger, preview).ok, "complete stock plus electronic ownership validates")
	draft = preview.duplicate(true)
	screen(draft)
	var sites: OptionButton = choice("scoreboard_choice", "site")
	index = index_of(sites, "Raised center")
	if not check(index >= 0 and not sites.is_item_disabled(index), "runtime-enabled raised mount fits owned field"):
		finish()
		return
	sites.item_selected.emit(index)
	check(preview.version == 15 and preview.scoreboards[0].site == StadiumScoreboardMountCatalog.CENTER_SITE,
		"mounted callback retains exact board and creates family15")
	check(StadiumEditorUI._checked(ledger, preview).ok, "mounted ownership validates without stock-only fallback")
	var mounted: Dictionary = preview.duplicate(true)
	var foreign: Dictionary = mounted.duplicate(true)
	foreign.scoreboards[0].copy = "foreign-copy"
	check(not StadiumEditorUI._checked(ledger, foreign).ok, "foreign mounted copy cannot enter shared preview")
	draft = preview.duplicate(true)
	screen(draft)
	primary = choice("scoreboard_choice", "primary")
	var manual: String = Data.copy_id(ledger.construction().copies, "ST-039")
	primary.item_selected.emit(index_of(primary, manual))
	check(preview.version == 15 and preview.scoreboards.size() == 1 and preview.scoreboards[0].copy == manual,
		"manual replacement stores electronic board without duplication")
	draft = preview.duplicate(true)
	screen(draft)
	choice("scoreboard_choice", "primary").item_selected.emit(0)
	check(preview.scoreboards.is_empty() and ClubCareer.same(preview.walls, draft.walls), "Stored removes only selected scoreboard")
	draft = preview.duplicate(true)
	screen(draft)
	choice("wall_slot", "back").item_selected.emit(0)
	check(preview.walls.back.is_empty() and preview.version == 15, "complete-family wall storage stays in shared adapter")
	check(StadiumEditorUI._checked(ledger, preview).ok, "stored complete field stays valid")
	check(ClubCareer.same(Data.state(ledger), original), "all previews preserve exact ledger stock and balance")
	check(app.season == null, "callbacks never inject ordinary career")
	draft = preview.duplicate(true)
	screen(draft, false)
	var before: int = count
	for control: OptionButton in [choice("wall_slot", "back"), choice("scoreboard_choice", "primary")]:
		control.item_selected.emit(1)
		control.disabled = false
		control.item_selected.emit(-1)
		control.item_selected.emit(999)
	check(count == before, "disabled and invalid selections cannot preview")
	primary = choice("scoreboard_choice", "primary")
	back = choice("wall_slot", "back")
	screen(draft)
	primary.item_selected.emit(1)
	back.item_selected.emit(1)
	check(count == before, "detached old controls cannot reopen shared preview")
	check(not StadiumAdvancedWallLayout.RUNTIME_READY and not StadiumLowWallLayout.RUNTIME_READY,
		"staged advanced and low-wall runtime flags unchanged")
	check(not Assets.layout_enabled(13) and not Assets.layout_enabled(46), "staged families not admitted")
	check(Data.apply(ledger, mounted), "mounted callback result saves and applies through existing journal")
	var restored: ClubAssetLedger = Data.restore(ledger.to_data())
	check(restored != null and ClubCareer.same(restored.view().stadium_active, mounted), "exact mounted active layout survives JSON replay")
	check(ledger.balance() == original.view.balance, "placements and apply never charge again")
	var season: SeasonState = SeasonState.new()
	season.phase = SeasonState.Phase.COMPLETE
	for version: int in [11, 14, 15]:
		check(Assets.supported({"op": "stadium_draft", "layout": {"version": version}})
			and Assets.allowed(season, {"op": "stadium_apply", "layout": {"version": version}}), "explicit family admits only through public gates")
	season.phase = SeasonState.Phase.DRAFT
	season.picks.append("fixture")
	check(not Assets.allowed(season, {"op": "stadium_draft", "layout": draft}), "first pick still locks shared complete field")
	finish()

func finish() -> void:
	menu.free()
	app.free()
	print("SHARED_WALL_SCOREBOARD_CONTROLS checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

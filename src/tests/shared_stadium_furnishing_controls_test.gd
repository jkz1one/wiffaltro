extends Node
## Synthetic legacy paid fixtures; real shared card callbacks, not physical or source-qualified play.
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
var checks: int = 0
var failures: int = 0
var callbacks: int = 0
var ledger: ClubAssetLedger
var app: SeasonApp
var menu: SeasonMenu
var panel: VBoxContainer
var draft: Dictionary = {}
var copies: Dictionary = {}
var credits: Array = []
var progress: Array = []

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok

func capture(next: Dictionary, revision: int) -> void:
	check(revision == ledger.revision(), "exact owner revision retained")
	check(Assets.layout_adapted(next), "only explicit flat adapter returns preview")
	check(StadiumEditorUI._checked(ledger, next).ok, "returned preview validates exact current ownership")
	draft = next
	callbacks += 1

func screen() -> void:
	menu._screen("shared_stadium", "Paid furnishing controls", "Synthetic fixture")
	panel = SeasonPlayerCard.panel(menu._body)

func option() -> OptionButton:
	for node: Node in panel.find_children("*", "OptionButton", true, false):
		return node as OptionButton
	return null

func button(meta: String, value: String) -> Button:
	for node: Node in menu._body.find_children("*", "Button", true, false):
		if node.get_meta(meta, "") == value:
			return node as Button
	return null

func select_first() -> bool:
	var control: OptionButton = option()
	if not check(control != null and not control.disabled, "shared paid placement control exists"):
		return false
	for index in range(1, control.item_count):
		if not control.is_item_disabled(index):
			control.item_selected.emit(index)
			return true
	check(false, "an owned compatible site is enabled")
	return false

func card(kind: String, enabled: bool = true) -> void:
	screen()
	match kind:
		"flag": StadiumClubItemsUI.flag_card(menu, panel, draft, copies["ST-043"], ledger.revision(), enabled, ledger, capture)
		"prop": StadiumClubItemsUI.ground_props_card(menu, panel, draft, copies["ST-015"], "ST-015", ledger.revision(), enabled, ledger, capture)
		"landscape": StadiumLandscapeOwnedItemsUI.card(menu, panel, draft, copies["ST-013"], "ST-013", ledger.revision(), enabled, ledger, capture)
		"furnishing": StadiumLiveFurnishingItemsUI.card(menu, panel, draft, copies["ST-002"], "ST-002", ledger.revision(), enabled, ledger, capture)
		"scenery": StadiumSmallYardSceneryItemsUI.card(menu, panel, draft, "starter-v1:ST-001", "ST-001", ledger.revision(), enabled, ledger, capture)

func _ready() -> void:
	for n in range(40):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 5, "strikeouts": 5})
	ledger = ClubAssetLedger.new(901, credits, progress)
	for tier: String in ["expanded", "club"]:
		check(ledger.commit({"id": tier, "rev": ledger.revision(), "op": "stadium_land", "tier": tier,
			"through": 40, "progress_through": 40, "price_version": StadiumLand.VERSION}).ok, "paid land " + tier)
	for item: String in ["ST-043", "ST-015", "ST-013", "ST-002", "ST-038"]:
		var catalog: Dictionary = ClubConstruction.copy_catalog(item)
		var command: Dictionary = {"id": "furnishing:%d" % ledger.revision(), "rev": ledger.revision(),
			"op": "stadium_buy", "item": item, "quantity": 4 if item == "ST-038" else 1,
			"price_version": catalog.price_version, "through": 40, "progress_through": 40}
		check(Assets.supported(command) and ledger.commit(command).ok, "existing shared purchase grammar " + item)
		var balance: int = ledger.balance()
		check(ledger.commit(command).replayed and ledger.balance() == balance, "exact purchase retries once " + item)
	for copy: String in ledger.construction().copies:
		copies[ledger.construction().copies[copy].item] = copy
	var original: Dictionary = ledger.to_data()
	var balance: int = ledger.balance()
	app = SeasonApp.new() # Intentionally off-tree, no ordinary career or external save.
	menu = SeasonMenu.new()
	add_child(menu)
	menu.build(app)
	draft = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned())
	for kind: String in ["flag", "prop"]:
		card(kind)
		if not select_first():
			finish()
			return
	check(draft.version == 19 and draft.flags.size() == 1 and draft.props.size() == 1, "paid flag and ground prop coexist")
	screen()
	StadiumFloodlightOwnedItemsUI.presets(menu, ledger, draft, ledger.revision(), true, capture)
	var preset: Button = button("floodlight_profile", "CLUB4-LOW")
	if not check(preset != null and not preset.disabled, "owned four-tower preset available"):
		finish()
		return
	preset.pressed.emit()
	check(draft.version == 25 and draft.floodlights.size() == 4, "preset binds four distinct paid towers")
	var tower: String = draft.floodlights[0].copy
	screen()
	StadiumFloodlightOwnedItemsUI.card(menu, panel, draft, tower, ledger.revision(), true, ledger, capture)
	button("stadium_copy", tower).pressed.emit()
	check(draft.floodlights.size() == 3 and not StadiumEditorUI._checked(ledger, draft).get("night_qualified", false), "partial tower set stays daylight-only")
	for kind: String in ["landscape", "furnishing"]:
		card(kind)
		if not select_first():
			finish()
			return
	check(draft.version == 27 and draft.flags.size() == 1 and draft.props.size() == 1 and draft.landscape.size() == 1 and draft.live_furnishings.size() == 1,
		"later furnishing callbacks preserve earlier exact placements")
	card("scenery")
	var control: OptionButton = option()
	var selected: bool = false
	for index in range(1, control.item_count):
		if control.get_item_text(index).contains("Scenery") and not control.is_item_disabled(index):
			control.item_selected.emit(index)
			selected = true
			break
	if not check(selected and draft.version == 28 and draft.yard_scenery.size() == 1, "same starter copy moves into approved scenery cell"):
		finish()
		return
	card("scenery")
	option().item_selected.emit(0)
	check(draft.version == 27 and draft.live_furnishings.size() == 1, "scenery storage unwinds only empty new wrapper")
	for kind: String in ["flag", "prop", "landscape", "furnishing"]:
		card(kind)
		option().item_selected.emit(0)
	check(draft.get("flags", []).is_empty() and draft.get("props", []).is_empty() and draft.get("landscape", []).is_empty() and draft.get("live_furnishings", []).is_empty(),
		"each paid furnishing stores independently without dropping the existing field")
	screen()
	StadiumFloodlightOwnedItemsUI.presets(menu, ledger, draft, ledger.revision(), false, capture)
	preset = button("floodlight_profile", "CLUB4-LOW")
	var previous: int = callbacks
	preset.pressed.emit()
	preset.disabled = false
	screen()
	preset.pressed.emit()
	check(callbacks == previous, "disabled and detached preset buttons cannot change preview")
	for kind: String in ["flag", "prop", "landscape", "furnishing", "scenery"]:
		card(kind, false)
		control = option()
		var before: int = callbacks
		control.item_selected.emit(1)
		control.disabled = false
		control.item_selected.emit(-1)
		control.item_selected.emit(999)
		screen()
		control.item_selected.emit(1)
		check(callbacks == before, kind + " disabled invalid and detached signals ignored")
	var terrain: Dictionary = draft.duplicate(true)
	terrain.base_version = 17
	check(not Assets.layout_adapted(terrain) and not Assets.supported({"op": "stadium_draft", "layout": terrain}), "terrain-backed descendant remains read-only")
	check(not Assets.layout_adapted({"version": 29, "base_version": 12}), "unadapted later family remains read-only")
	check(app.season == null and ClubCareer.same(original, ledger.to_data()), "preview callbacks never create career or change paid journal")
	var saved: Dictionary = ledger.commit({"id": "draft", "rev": ledger.revision(), "op": "stadium_draft", "layout": draft})
	check(saved.ok, "shared-supported flat descendant saves in original journal: " + str(saved.get("error", "")))
	check(ledger.commit({"id": "apply", "rev": ledger.revision(), "op": "stadium_apply", "layout": draft,
		"geometry": StadiumOwnedLayout.geometry(ledger.view().land, draft)}).ok, "original apply keeps geometry contract")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(ledger.to_data())), 901, credits, progress)
	check(restored != null and ClubCareer.same(restored.view().stadium_active, draft) and restored.balance() == balance, "exact paid layout replays with no placement debit")
	finish()

func finish() -> void:
	menu.free()
	app.free()
	print("SHARED_FURNISHING_CONTROLS checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

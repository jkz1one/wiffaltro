extends Node
## Actual modern salvage origin with explicitly synthetic credits/progress/title authority.
## No authentic earned title, physical game or source-qualified owner-runtime claim.
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const Shared = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
var ledger: ClubAssetLedger
var app: SeasonApp
var menu: SeasonMenu
var panel: VBoxContainer
var draft: Dictionary
var copies: Dictionary = {}
var credits: Array = []
var progress: Array = []
var authority: Dictionary = {}
var checks: int = 0
var failures: int = 0
var callbacks: int = 0

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok

func capture(next: Dictionary, revision: int) -> void:
	check(revision == ledger.revision() and Assets.layout_adapted(next), "exact revision and supported flat origin preserved")
	check(StadiumEditorUI._checked(ledger, next).ok, "preview validates complete paid ownership")
	draft = next
	callbacks += 1

func screen() -> void:
	menu._screen("shared_stadium", "Modern shared-origin fixture", "Synthetic paid/title evidence")
	panel = SeasonPlayerCard.panel(menu._body)

func option() -> OptionButton:
	for node: Node in panel.find_children("*", "OptionButton", true, false):
		return node as OptionButton
	return null

func first_site() -> bool:
	var control: OptionButton = option()
	if not check(control != null and not control.disabled, "owned current-origin card is editable"):
		return false
	for index in range(1, control.item_count):
		if not control.is_item_disabled(index):
			control.item_selected.emit(index)
			return true
	check(false, "exact paid compatible host/site exists")
	return false

func card(kind: String, enabled: bool = true) -> void:
	screen()
	match kind:
		"car": StadiumSalvageCarUI.card(menu, panel, draft, StadiumStock.SALVAGE_COPY, ledger.revision(), enabled, ledger, capture)
		"string": StadiumStringLightItemsUI.card(menu, panel, draft, copies["ST-036"], ledger.revision(), enabled, ledger, capture)
		"display": StadiumMountedDisplayItemsUI.card(menu, panel, draft, copies["ST-069"], ledger.revision(), enabled, ledger, capture)
		"banner": StadiumMasteryBannerItemsUI.card(menu, panel, draft, StadiumPennantRewards.mastery_key(), ledger.revision(), enabled, ledger, capture)

func _ready() -> void:
	for n in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5})
	var earned: Dictionary = {"version": 1, "season_id": 5, "season_number": 5,
		"league_id": "standard", "difficulty_id": "standard.d4", "era": StadiumClubIdentity.current()}
	authority[StadiumPennantRewards.key(5)] = earned.duplicate(true)
	earned.mastery_contract = "standard.d4"
	authority[StadiumPennantRewards.mastery_key()] = earned
	ledger = ClubAssetLedger.new_club(902, credits, progress, authority)
	draft = ledger.view().stadium_draft.duplicate(true)
	check(draft.version == 40 and draft.base_version == 12 and Assets.layout_adapted(draft), "actual new_club family40 is admitted without conversion")
	check(draft.surface.foundation == "dirt" and draft.surface.condition == "rough", "modern rough-dirt origin stays exact")
	var car: Dictionary = ledger.construction().copies[StadiumStock.SALVAGE_COPY].duplicate(true)
	app = SeasonApp.new()
	menu = SeasonMenu.new()
	add_child(menu)
	menu.build(app)
	app.menu = menu
	card("car")
	var count: int = callbacks
	check(option().disabled, "uncleared starter car cannot be moved or stored")
	option().item_selected.emit(0)
	check(callbacks == count, "uncleared forged storage signal is rejected")
	var removed: Dictionary = StadiumSalvageCarItems.store_copy(draft, StadiumStock.SALVAGE_COPY)
	check(not ledger.commit({"id": "illegal-free-clear", "rev": ledger.revision(), "op": "stadium_draft", "layout": removed}).ok,
		"original paid-clearance journal guard rejects free car omission")
	Shared._salvage_clearance(app, ledger, ledger.revision(), false)
	var review: Button
	for node: Node in menu._body.find_children("*", "Button", true, false):
		if node.get_meta("shared_salvage_clear", false):
			review = node
	check(review != null and review.disabled and review.text.contains("190"), "shared clearance control discloses cost and locks while dirty")
	var command: Dictionary = {"id": "modern-clear", "rev": ledger.revision(), "op": "stadium_salvage_clear",
		"copy": StadiumStock.SALVAGE_COPY, "price_version": 1, "through": 40}
	var balance: int = ledger.balance()
	check(Assets.supported(command) and ledger.commit(command).ok, "existing shared clearance grammar executes original journal operation")
	check(ledger.balance() == balance - 190 and ledger.view().salvage_cleared and ledger.view().stadium_active.salvage_cars.is_empty(), "190 CB paid once and original car stored")
	check(ledger.commit(command).replayed and ledger.balance() == balance - 190, "same clearance retry cannot charge twice")
	check(ClubCareer.same(ledger.construction().copies[StadiumStock.SALVAGE_COPY], car) and not ledger.construction().blueprints.has("ST-005"), "clearance preserves exact car and grants no blueprint")
	draft = ledger.view().stadium_draft.duplicate(true)
	card("car")
	first_site()
	check(draft.salvage_cars.size() == 1 and draft.salvage_cars[0].copy == StadiumStock.SALVAGE_COPY, "same cleared car reinstalls free")
	card("car")
	option().item_selected.emit(0)
	check(draft.salvage_cars.is_empty() and draft.version == 40, "same car stores again without losing origin wrapper")
	for tier: String in ["expanded", "club"]:
		check(ledger.commit({"id": tier, "rev": ledger.revision(), "op": "stadium_land", "tier": tier,
			"price_version": StadiumLand.VERSION, "through": 40, "progress_through": 40}).ok, "paid required land")
	for item: String in ["ST-039", "ST-069", "ST-036", "ST-029"]:
		check(ledger.commit({"id": item, "rev": ledger.revision(), "op": "stadium_buy", "item": item, "quantity": 1,
			"price_version": ClubConstruction.copy_catalog(item).price_version, "through": 40, "progress_through": 40}).ok, "original paid purchase " + item)
	for copy: String in ledger.construction().copies:
		copies[ledger.construction().copies[copy].item] = copy
	screen()
	StadiumClubItemsUI.card(menu, panel, draft, copies["ST-039"], "ST-039", ledger.revision(), true, capture)
	if not first_site():
		finish()
		return
	card("display")
	if not first_site():
		finish()
		return
	check(draft.version == 40 and draft.mounted_displays.size() == 1 and draft.mounted_displays[0].host == copies["ST-039"], "display mounts to exact installed paid manual host without dropping modern origin")
	var changed: Dictionary = draft.duplicate(true)
	changed.displays = []
	check(not StadiumMountedDisplayItems.transition(draft, changed).ok, "mounted host cannot disappear before its display is stored")
	card("string")
	var blocked: bool = true
	for index in range(1, option().item_count):
		blocked = blocked and option().is_item_disabled(index)
	check(blocked, "unqualified mounted-display/string combination remains blocked")
	card("display")
	option().item_selected.emit(0)
	check(draft.mounted_displays.is_empty(), "store mounted display before adopting approved string recipe")
	card("string")
	if not first_site():
		finish()
		return
	check(draft.version == 40 and draft.string_lights.size() == 1 and not StadiumEditorUI._checked(ledger, draft).get("night_qualified", false), "paid string span remains decorative and daylight-only")
	card("string")
	option().item_selected.emit(0)
	check(draft.string_lights.is_empty(), "store spans before installing incompatible stadium host")
	for id: String in [StadiumPennantRewards.key(5), StadiumPennantRewards.mastery_key()]:
		check(ledger.commit({"id": id, "rev": ledger.revision(), "op": "stadium_mastery" if id == StadiumPennantRewards.mastery_key() else "stadium_pennant", "earned": authority[id]}).ok,
			"original earned-reward journal accepts explicitly synthetic title fixture")
	check(not Assets.copy_enabled("ST-067"), "mastery banner never becomes a shop purchase")
	draft = StadiumStraightItemsUI.select(draft, ledger.construction(), copies["ST-029"], {"site": "BASE-L1", "lower": "", "concourse": ""})
	card("banner")
	if not first_site():
		finish()
		return
	check(draft.version == 41 and draft.mastery_banners.size() == 1 and draft.mastery_banners[0].host == copies["ST-029"], "earned immutable banner uses exact paid lower facade")
	for kind: String in ["display", "string", "banner"]:
		card(kind)
		option().item_selected.emit(0)
	check(draft.get("mounted_displays", []).is_empty() and draft.get("string_lights", []).is_empty() and draft.get("mastery_banners", []).is_empty(), "modern-origin displays spans and banner store independently")
	for kind: String in ["car", "display", "string", "banner"]:
		card(kind, false)
		var control: OptionButton = option()
		count = callbacks
		control.item_selected.emit(1)
		control.disabled = false
		control.item_selected.emit(-1)
		control.item_selected.emit(999)
		screen()
		control.item_selected.emit(1)
		check(callbacks == count, kind + " rejects disabled invalid and detached events")
	balance = ledger.balance()
	check(Assets.supported({"op": "stadium_draft", "layout": draft}) and ledger.commit({"id": "final-draft", "rev": ledger.revision(), "op": "stadium_draft", "layout": draft}).ok, "modern flat shared draft saves without conversion")
	check(ledger.commit({"id": "final-apply", "rev": ledger.revision(), "op": "stadium_apply", "layout": draft, "geometry": StadiumOwnedLayout.geometry(ledger.view().land, draft)}).ok, "existing geometry-bound apply succeeds")
	var restored: ClubAssetLedger = ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(ledger.to_data())), 902, credits, progress, authority)
	check(restored != null and restored.balance() == balance and ClubCareer.same(restored.view().stadium_active, draft) and ClubCareer.same(restored.construction().copies[StadiumPennantRewards.mastery_key()].earned, earned), "cold journal preserves modern origin exact balance and immutable earned banner")
	check(app.season == null, "no ordinary career injected")
	finish()

func finish() -> void:
	menu.free()
	app.free()
	print("SHARED_MODERN_ORIGIN_CONTROLS checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

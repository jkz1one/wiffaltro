extends Node
## Synthetic paid stock exercises real reusable UI callbacks, not physical qualification.
var checks: int = 0
var failures: int = 0
var preview: Dictionary = {}
var callback_count: int = 0
var menu: SeasonMenu
var panel: VBoxContainer

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func capture(next: Dictionary, revision: int) -> void:
	check(revision == 17, "callback preserves owner revision")
	preview = next
	callback_count += 1

func reset() -> void:
	if panel != null:
		panel.free()
	panel = VBoxContainer.new()
	menu.add_child(panel)

func choice() -> OptionButton:
	for child: Node in panel.get_children():
		if child is OptionButton:
			return child
	return null

func _ready() -> void:
	menu = SeasonMenu.new()
	add_child(menu)
	var credits: Array = [220, 220, 220, 220]
	var progress: Array = []
	for n in range(4):
		progress.append({"seasons": 1, "wins": 10, "strikeouts": 10})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(9, credits, progress)
	for item: String in ["ST-026", "ST-025"]:
		var command: Dictionary = {"id": "receiver:%d" % ledger.revision(), "rev": ledger.revision(),
			"op": "stadium_buy", "item": item, "quantity": 1,
			"price_version": StadiumPurchases.TARGET_VERSION if item == "ST-026" else StadiumPurchases.NET_VERSION,
			"through": 4, "progress_through": 4}
		check(ledger.commit(command).ok, "separately purchase " + item)
	var stock: StadiumStock = ledger.construction()
	var target: String = "purchase:receiver:0:0"
	var net: String = "purchase:receiver:1:0"
	var draft: Dictionary = StadiumStarterLayout.empty()
	draft.receiver = "starter-v1:ST-079"
	reset()
	StadiumTargetItemsUI.card(menu, panel, draft, target, 17, true, capture)
	choice().item_selected.emit(1)
	check(preview.version == 7 and preview.target == target and preview.receiver == "", "target stores chair and returns shared preview")
	check(StadiumHomeLayout.validate(preview, stock).ok, "target preview validates exact paid stock")
	draft = preview.duplicate(true)
	reset()
	StadiumNetItemsUI.card(menu, panel, draft, net, 17, true, capture)
	choice().item_selected.emit(1)
	check(preview.version == 8 and preview.target == target and preview.net == net, "separate net pairs with exact target")
	check(StadiumHomeLayout.validate(preview, stock).ok, "paired preview validates")
	draft = preview.duplicate(true)
	reset()
	StadiumTargetItemsUI.card(menu, panel, draft, target, 17, true, capture)
	choice().item_selected.emit(0)
	check(preview.target == "" and preview.net == "", "target removal stores both paid copies")
	check(StadiumHomeLayout.validate(preview, stock).ok, "stored receiver copies remain valid")
	reset()
	StadiumNetItemsUI.card(menu, panel, preview, net, 17, true, capture)
	var count: int = callback_count
	check(choice().is_item_disabled(1), "net placement unavailable without target")
	choice().item_selected.emit(1)
	choice().item_selected.emit(-1)
	choice().item_selected.emit(99)
	check(callback_count == count, "disabled and invalid receiver selections cannot mutate preview")
	for kind: String in ["target", "net", "light", "bleacher"]:
		reset()
		match kind:
			"target": StadiumTargetItemsUI.card(menu, panel, draft, target, 17, false, capture)
			"net": StadiumNetItemsUI.card(menu, panel, draft, net, 17, false, capture)
			"light": StadiumLightItemsUI.card(menu, panel, draft, "unused", 17, false, capture)
			"bleacher": StadiumBleacherItemsUI.card(menu, panel, draft, "unused", "ST-028", 17, false, "expanded", capture)
		choice().item_selected.emit(1)
		check(callback_count == count, kind + " disabled editor ignores forged signals")
		choice().disabled = false
		menu.remove_child(panel)
		choice().item_selected.emit(1)
		check(callback_count == count, kind + " detached stale control ignores signals")
		menu.add_child(panel)
	check(ledger.balance() == 190 and stock.copies.size() == 5, "preview callbacks never debit or bundle stock")
	menu.free()
	print("SHARED_RECEIVER_CONTROLS checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

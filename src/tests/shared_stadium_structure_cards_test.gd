extends Node
## Synthetic paid journal, actual card controls; no career injection, owner I/O or physical qualification.
const UI = preload("res://src/presentation/stadium/shared_stadium_workshop_ui.gd")
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index: int in range(40):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 5})
	var paid: ClubAssetLedger = ClubAssetLedger.new(71, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(paid.commit({"id": tier, "rev": paid.revision(), "op": "stadium_land", "tier": tier,
			"through": 40, "progress_through": 40, "price_version": StadiumLand.VERSION}).ok, "paid land " + tier)
	for item: String in ["ST-029", "ST-031", "ST-081", "ST-056", "ST-021", "ST-072", "ST-020"]:
		var catalog: Dictionary = ClubConstruction.copy_catalog(item)
		check(paid.commit({"id": item, "rev": paid.revision(), "op": "stadium_buy", "item": item,
			"quantity": 8 if item == "ST-020" else 1, "through": 40, "progress_through": 40,
			"price_version": catalog.price_version}).ok, "paid exact catalog copy " + item)
	var before: Dictionary = paid.to_data()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.page = "shared_stadium"
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	check(menu.app == null, "cards have no ordinary career to fall back on")
	var result: Dictionary = {"calls": 0}
	var callback: Callable = func(next: Dictionary, revision: int) -> void:
		result.calls += 1
		result.layout = next
		result.revision = revision
	var draft: Dictionary = paid.view().stadium_draft
	for item: String in ["ST-029", "ST-031", "ST-081", "ST-056", "ST-021", "ST-072"]:
		var copy: String = _copy(paid, item)
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		UI._structure_card(item).call(menu, panel, draft, copy, item, paid.revision(), true, paid, callback)
		var choice: OptionButton = panel.get_child(0)
		check(choice.item_count > 1 and not choice.disabled and not choice.is_item_disabled(1), "compatible owned placement " + item)
		var captured: Dictionary = draft
		var original: Dictionary = draft.duplicate(true)
		choice.item_selected.emit(1)
		if result.has("layout"):
			draft = result.layout
			check(UI._validate(draft, paid).ok, "full paid validation " + item)
			check(Assets.layout_adapted(draft), "only implemented family admitted " + item)
			check(result.revision == paid.revision() and menu.page == "shared_stadium", "owner callback/revision retained")
		check(ClubCareer.same(before, paid.to_data()), "preview leaves journal untouched")
		check(ClubCareer.same(captured, original), "card never mutates captured layout")
		var count: int = result.calls
		choice.item_selected.emit(-1)
		choice.item_selected.emit(999)
		choice.disabled = true
		choice.item_selected.emit(0)
		check(count == result.calls, "disabled/invalid callback blocked " + item)
		panel.queue_free()
	# Removing a lower stand must store its dependent concourse without deleting ownership.
	var storage: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(storage)
	StadiumStraightItemsUI.card(menu, storage, draft, _copy(paid, "ST-029"), "ST-029", paid.revision(), true, paid, callback)
	(storage.get_child(0) as OptionButton).item_selected.emit(0)
	var removed: Dictionary = result.layout
	check(UI._validate(removed, paid).ok and removed.hosts.is_empty(), "support removal stores dependent concourse")
	check(paid.construction().copies.has(_copy(paid, "ST-031")), "dependent copy remains owned")
	StadiumBoundaryItemsUI.runs(menu, paid, draft, paid.revision(), true, callback)
	var rear: OptionButton
	for node: Node in menu._body.find_children("*", "OptionButton", true, false):
		if node.has_meta("boundary_rear_run"):
			rear = node
	check(rear != null and not rear.is_item_disabled(1), "complete paid rear run available")
	if rear != null:
		rear.item_selected.emit(1)
		check(result.layout.boundary.size() == draft.boundary.size() + 8 and UI._validate(result.layout, paid).ok, "rear run installs eight exact paid copies")
		var count: int = result.calls
		rear.item_selected.emit(-1)
		rear.item_selected.emit(999)
		rear.item_selected.emit(2)
		rear.disabled = true
		rear.item_selected.emit(0)
		check(result.calls == count, "rear run rejects invalid, unowned and disabled selections")
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(paid.to_data())), 71, credits, progress)
	check(cold != null and ClubCareer.same(cold.to_data(), before), "paid inventory cold replays exactly")
	var unowned: Dictionary = draft.duplicate(true)
	unowned.catcher = "not-owned"
	check(not UI._validate(unowned, paid).ok, "unowned receiver rejected")
	var malformed: Dictionary = draft.duplicate(true)
	malformed.family = "wrong"
	check(not Assets.layout_adapted(malformed), "wrong family rejected despite enabled version")
	var terrain: Dictionary = draft.duplicate(true)
	terrain.base_version = 17
	check(not Assets.layout_adapted(terrain), "terrain descendants remain outside this flat editor batch")
	check(ClubCareer.same(before, paid.to_data()), "all controls retain exact one-debit journal")
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame
	print("SHARED_STRUCTURE_CARDS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _copy(paid: ClubAssetLedger, item: String) -> String:
	for copy: String in paid.construction().copies:
		if paid.construction().copies[copy].item == item:
			return copy
	return ""

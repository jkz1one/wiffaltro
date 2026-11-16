extends "res://src/tests/shared_stadium_structure_cards_test.gd"
## Synthetic paid progress and actual public cards; no physical or Night qualification.
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
	for item: String in ["ST-046", "ST-111", "ST-112"]:
		var command: Dictionary = {"id": item, "rev": paid.revision(), "op": "stadium_buy", "item": item,
			"quantity": 2 if item == "ST-046" else 1, "through": 40, "progress_through": 40,
			"price_version": ClubConstruction.copy_catalog(item).price_version}
		check(paid.commit(command).ok, "paid exact " + item)
		check(paid.commit(command).get("replayed", false), "one-debit retry " + item)
	var before: Dictionary = paid.to_data()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.page = "shared_stadium"
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	var result: Dictionary = {"calls": 0}
	var callback: Callable = func(next: Dictionary, revision: int) -> void:
		result.calls += 1
		result.layout = next
		result.revision = revision
	var base: Dictionary = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), paid.surface_owned(), true)
	var live: Dictionary = {}
	for row: Array in [["ST-046", 1, 42], ["ST-046", 2, 45], ["ST-111", 1, 43], ["ST-111", 2, 43], ["ST-111", 3, 43], ["ST-111", 4, 43]]:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		UI._assembly_card(row[0]).call(menu, panel, base, _copy(paid, row[0]), paid.revision(), true, paid, callback)
		var choice: OptionButton = panel.get_child(0)
		check(not choice.is_item_disabled(row[1]), "public placement available " + str(row))
		choice.item_selected.emit(row[1])
		if not result.has("layout"):
			continue
		var placed: Dictionary = result.layout
		var valid: Dictionary = UI._validate(placed, paid)
		check(valid.ok and placed.version == row[2] and Assets.layout_adapted(placed), "exact flat paid family " + str(row))
		check(not valid.get("night_qualified", false), "placement grants no Night authority")
		if row[2] == 45:
			live = placed.duplicate(true)
			check(valid.live_units == 4 and not StadiumHomeLayout.validate(placed, paid.construction(), "club").ok, "live waterfall consumes all four units and requires Mogul")
			var conflict: Dictionary = placed.duplicate(true)
			conflict.obstacles = [{"copy": _copy(paid, "ST-001"), "site": StadiumStarterLayout.SITES.keys()[0], "yaw": 0}]
			check(UI._validate(StadiumWaterfallLiveItems.store_copy(conflict, _copy(paid, "ST-046")), paid).ok, "companion is independently legal paid stock")
			check(not UI._validate(conflict, paid).ok, "live waterfall rejects live companion")
		var count: int = result.calls
		choice.item_selected.emit(-1)
		choice.item_selected.emit(99)
		choice.disabled = true
		choice.item_selected.emit(0)
		check(result.calls == count, "invalid and disabled selection ignored")
		var storage: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(storage)
		UI._assembly_card(row[0]).call(menu, storage, placed, _copy(paid, row[0]), paid.revision(), true, paid, callback)
		(storage.get_child(0) as OptionButton).item_selected.emit(0)
		check(UI._validate(result.layout, paid).ok and ClubCareer.same(before, paid.to_data()), "free exact-copy storage changes preview only")
		panel.queue_free()
		storage.queue_free()
	var plaza: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(plaza)
	StadiumOutfieldPlazaItemsUI.card(menu, plaza, base, _copy(paid, "ST-112"), paid.revision(), true, paid, callback)
	var recipe: OptionButton = plaza.get_child(0)
	check(not recipe.is_item_disabled(1), "public plaza recipe available")
	recipe.item_selected.emit(1)
	var installed: Dictionary = result.layout
	check(installed.version == 44 and installed.outfield_plaza[0].occupants.is_empty() and UI._validate(installed, paid).ok, "plaza includes no free optional occupants")
	var occupants: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(occupants)
	StadiumOutfieldPlazaItemsUI.card(menu, occupants, installed, _copy(paid, "ST-112"), paid.revision(), true, paid, callback)
	var picked: bool = false
	for node: Node in occupants.get_children():
		if node is OptionButton and not node.has_meta("stadium_copy") and node.item_count > 1:
			var count: int = result.calls
			node.item_selected.emit(-1)
			node.item_selected.emit(999)
			node.disabled = true
			node.item_selected.emit(1)
			check(result.calls == count, "plaza picker ignores invalid and disabled callbacks")
			node.disabled = false
			node.item_selected.emit(1)
			picked = true
			break
	check(picked and result.layout.outfield_plaza[0].occupants.size() == 1, "plaza picker uses exact separately paid waterfall")
	if picked:
		var occupied: Dictionary = result.layout
		var occupant: String = occupied.outfield_plaza[0].occupants[0].copy
		check(UI._validate(occupied, paid).ok, "plaza occupant validates")
		check(ClubCareer.same(StadiumOutfieldPlazaItems.store_copy(occupied, _copy(paid, "ST-112")), occupied), "plaza kit waits for occupant storage")
		var store_panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(store_panel)
		StadiumOutfieldPlazaItemsUI.card(menu, store_panel, occupied, occupant, paid.revision(), true, paid, callback)
		for node: Node in store_panel.get_children():
			if node is Button:
				node.pressed.emit()
		check(result.layout.outfield_plaza[0].occupants.is_empty(), "occupant control stores exact copy without leaving shared route")
		store_panel.queue_free()
	check(ClubCareer.same(before, paid.to_data()), "all public previews leave paid journal untouched")
	check(not StadiumLightingKitNightCandidate.RUNTIME_READY and not StadiumLightingKitNightCandidate.PUBLIC_READY, "candidate lighting-kit Night gates remain shut")
	check(not Assets.layout_enabled(46), "low-wall saved family remains gated")
	if not live.is_empty():
		check(paid.commit({"id": "live-draft", "rev": paid.revision(), "op": "stadium_draft", "layout": live}).ok, "paid live waterfall draft journal")
		check(paid.commit({"id": "live-apply", "rev": paid.revision(), "op": "stadium_apply", "layout": live,
			"geometry": StadiumOwnedLayout.geometry(paid.view().land, live)}).ok, "paid live waterfall apply journal")
		var cold: ClubAssetLedger = ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(paid.to_data())), 71, credits, progress)
		check(cold != null and ClubCareer.same(cold.to_data(), paid.to_data()), "exact waterfall journal cold replay")
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame
	print("SHARED_PLAZA_WATERFALL checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

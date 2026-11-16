extends "res://src/tests/shared_stadium_structure_cards_test.gd"
## Synthetic paid progress, actual reusable assembly cards; no owner I/O or physical qualification.
func _ready() -> void:
	var credits: Array = []
	var progress: Array = []
	for index: int in range(40):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 5, "hits": 4, "strikeouts": 3, "homers": 2})
	var paid: ClubAssetLedger = ClubAssetLedger.new(71, credits, progress)
	for tier: String in ["expanded", "club", "mogul"]:
		check(paid.commit({"id": tier, "rev": paid.revision(), "op": "stadium_land", "tier": tier,
			"through": 40, "progress_through": 40, "price_version": StadiumLand.VERSION}).ok, "paid land " + tier)
	var items: Array[String] = ["ST-051", "ST-052", "ST-060", "ST-061", "ST-045", "ST-048", "ST-054", "ST-047", "ST-087", "ST-058"]
	for item: String in items + ["ST-074", "ST-029", "ST-065"]:
		var command: Dictionary = {"id": item, "rev": paid.revision(), "op": "stadium_buy", "item": item,
			"quantity": 23 if item == "ST-065" else 1, "through": 40, "progress_through": 40,
			"price_version": StadiumWallItems.PRICE_VERSION if item == "ST-065" else ClubConstruction.copy_catalog(item).price_version}
		check(paid.commit(command).ok, "actual paid copy " + item)
		check(paid.commit(command).get("replayed", false), "exact purchase retry " + item)
	var before: Dictionary = paid.to_data()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.page = "shared_stadium"
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	check(menu.app == null, "no ordinary career fallback available")
	var result: Dictionary = {"calls": 0}
	var callback: Callable = func(next: Dictionary, revision: int) -> void:
		result.calls += 1
		result.layout = next
		result.revision = revision
	var base: Dictionary = StadiumSurfaceLayout.upgrade(paid.view().stadium_draft, paid.surface_owned(), true)
	var last: Dictionary = {}
	for item: String in items:
		var draft: Dictionary = base.duplicate(true)
		if item in ["ST-058", "ST-087"]:
			var unhosted: VBoxContainer = VBoxContainer.new()
			menu._body.add_child(unhosted)
			UI._assembly_card(item).call(menu, unhosted, draft, _copy(paid, item), paid.revision(), true, paid, callback)
			var gated: OptionButton = _choice(unhosted)
			check(gated != null and _enabled(gated) == -1, "unpaid template cannot provide exact hosts " + item)
			var count: int = result.calls
			gated.item_selected.emit(1)
			check(result.calls == count, "disabled missing-host selection cannot callback")
			unhosted.queue_free()
		if item == "ST-058":
			draft = StadiumPlayerTunnelItems.upgrade(draft, paid.surface_owned())
			draft = StadiumBoundaryItems.select(draft, paid.construction(), _copy(paid, "ST-074"), {"copy": "", "item": "ST-074", "site": "DUGOUT-R", "host": ""})
			draft = StadiumStraightItemsUI.select(draft, paid.construction(), _copy(paid, "ST-029"), {"copy": "", "site": "BASE-R1", "lower": "", "concourse": ""})
		elif item == "ST-087":
			draft = StadiumWallTopTerraceItems.upgrade(draft, paid.surface_owned())
			var wall: Dictionary = StadiumWallLayout.propose(draft.walls, paid.construction(), "back", "ST-065", "straight")
			check(wall.ok, "complete paid back-wall hosts")
			if wall.ok:
				draft.walls = wall.walls
		var original: Dictionary = draft.duplicate(true)
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		UI._assembly_card(item).call(menu, panel, draft, _copy(paid, item), paid.revision(), true, paid, callback)
		var choice: OptionButton = _choice(panel)
		var index: int = _enabled(choice)
		check(index > 0, "exact paid assembly placement available " + item)
		if index < 1:
			continue
		choice.item_selected.emit(index)
		var placed: Dictionary = result.layout
		check(UI._validate(placed, paid).ok and Assets.layout_adapted(placed), "paid flat family validates and is adapted " + item)
		if item in ["ST-052", "ST-060", "ST-061", "ST-045", "ST-054", "ST-087", "ST-058"]:
			check(not StadiumOwnedLayout.validate(placed, paid.construction(), paid.wall_pieces(), paid.surface_owned(), "backyard", paid.scoreboards()).ok, "smaller property cannot admit complete assembly " + item)
		if item == "ST-087":
			var missing: Dictionary = placed.duplicate(true)
			missing.walls.back = {}
			check(not UI._validate(missing, paid).ok, "terrace refuses removal of exact paid wall hosts")
		check(ClubCareer.same(original, draft) and result.revision == paid.revision(), "immutable source and exact revision " + item)
		var count: int = result.calls
		choice.item_selected.emit(-1)
		choice.item_selected.emit(999)
		choice.disabled = true
		choice.item_selected.emit(0)
		check(count == result.calls, "disabled and invalid callbacks ignored " + item)
		if item == "ST-058":
			var missing: Dictionary = StadiumStraightItemsUI.select(placed, paid.construction(), _copy(paid, "ST-029"), {})
			check(not UI._validate(missing, paid).ok and ClubCareer.same(missing.player_tunnels, placed.player_tunnels), "installed tunnel preserves row and refuses missing paid host")
		if item == "ST-051":
			var pad: VBoxContainer = VBoxContainer.new()
			menu._body.add_child(pad)
			StadiumMoldedSeatItemsUI.pad_controls(menu, pad, paid, placed, paid.revision(), true, callback)
			check(_pad_remove(pad).disabled, "occupied molded pad cannot be removed")
			pad.queue_free()
		var storage: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(storage)
		UI._assembly_card(item).call(menu, storage, placed, _copy(paid, item), paid.revision(), true, paid, callback)
		_choice(storage).item_selected.emit(0)
		last = result.layout
		check(UI._validate(last, paid).ok and paid.construction().copies.has(_copy(paid, item)), "free storage retains exact paid assembly " + item)
		if item == "ST-051":
			var pad: VBoxContainer = VBoxContainer.new()
			menu._body.add_child(pad)
			StadiumMoldedSeatItemsUI.pad_controls(menu, pad, paid, last, paid.revision(), true, callback)
			check(not _pad_remove(pad).disabled, "empty pad removal becomes available")
			_pad_remove(pad).pressed.emit()
			check(not StadiumMoldedSeatItems.has_pad(result.layout) and result.layout.version == 28, "pad removal preserves exact scenery base")
			pad.queue_free()
		check(ClubCareer.same(before, paid.to_data()), "preview and storage never mutate paid journal")
		panel.queue_free()
		storage.queue_free()
	var saved: Dictionary = paid.commit({"id": "assembly-draft", "rev": paid.revision(), "op": "stadium_draft", "layout": last})
	check(saved.ok, "actual ledger saves final tunnel storage draft")
	check(paid.commit({"id": "assembly-apply", "rev": paid.revision(), "op": "stadium_apply", "layout": last,
		"geometry": StadiumOwnedLayout.geometry(paid.view().land, last)}).ok, "actual ledger applies exact assembly layout")
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(JSON.parse_string(JSON.stringify(paid.to_data())), 71, credits, progress)
	check(cold != null and ClubCareer.same(cold.to_data(), paid.to_data()), "paid assembly journal cold replays exactly")
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame
	print("SHARED_ASSEMBLY_CARDS checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _choice(panel: Node) -> OptionButton:
	for node: Node in panel.get_children():
		if node is OptionButton:
			return node
	return null
func _enabled(choice: OptionButton) -> int:
	for index: int in range(1, choice.item_count):
		if not choice.is_item_disabled(index):
			return index
	return -1
func _pad_remove(panel: Node) -> Button:
	for node: Node in panel.get_children():
		if node is Button and node.has_meta("molded_pad_remove"):
			return node
	return null

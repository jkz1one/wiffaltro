extends Node
## Fast actual-control regression; synthetic paid stock, no owner or save qualification.
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	for item: String in ["ST-080", "ST-062a", "ST-063a"]:
		var quote: Dictionary = stock.quote(item, 1, {"seasons": 20, "wins": 100}, item)
		check(quote.ok, "synthetic paid quote " + item)
		stock = StadiumStock.from_data(quote.state)
	var draft: Dictionary = StadiumHomeLayout.upgrade(StadiumStarterLayout.empty())
	for copy: String in stock.copies:
		if stock.copies[copy].item == "ST-080":
			draft.seating.append({"copy": copy, "site": "CHAIR-L1"})
	# Use the authored site rather than relying on a display label.
	for site: String in StadiumSeatingLayout.SITES:
		if StadiumSeatingLayout.SITES[site].item == "ST-080":
			draft.seating[0].site = site
			break
	check(StadiumHomeLayout.validate(draft, stock).ok, "paid seating fixture valid")
	var before: Dictionary = draft.duplicate(true)
	var menu: SeasonMenu = SeasonMenu.new()
	menu.page = "shared_stadium"
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	var result: Dictionary = {"calls": 0}
	var callback: Callable = func(next: Dictionary, revision: int) -> void:
		result.calls += 1
		result["layout"] = next
		result["revision"] = revision
	for channel: String in StadiumFieldStyleModels.CHANNELS:
		var panel: VBoxContainer = VBoxContainer.new()
		menu._body.add_child(panel)
		StadiumFieldStylesUI._selector(menu, panel, draft, stock, channel, 17, true, callback)
		var choice: OptionButton = panel.get_child(0)
		check(choice.item_count == 2 and choice.selected == 0, "only template and paid " + channel)
		choice.item_selected.emit(1)
		check(result.layout.version == 3 and result.layout.styles[channel] == ("ST-062a" if channel == "line" else "ST-063a"), "shared callback selects exact " + channel)
		check(result.revision == 17 and menu.page == "shared_stadium", "revision and shared route preserved")
		check(ClubCareer.same(result.layout.seating, before.seating) and ClubCareer.same(draft, before), "preview retains seating without mutating input")
		check(StadiumHomeLayout.validate(result.layout, stock).ok, "selected style uses paid validation")
		var count: int = result.calls
		choice.item_selected.emit(-1)
		choice.item_selected.emit(99)
		choice.disabled = true
		choice.item_selected.emit(0)
		check(result.calls == count, "invalid and disabled selections do not callback")
		choice.disabled = false
		choice.item_selected.emit(0)
		check(result.layout.styles[channel] == "", "template switch remains available")
		panel.queue_free()
	var panel: VBoxContainer = VBoxContainer.new()
	menu._body.add_child(panel)
	var dirt: Dictionary = StadiumFieldStyles.upgrade(draft)
	dirt["surface"] = {"foundation": "dirt"}
	StadiumFieldStylesUI._selector(menu, panel, dirt, stock, "grass", 18, true, callback)
	check((panel.get_child(0) as OptionButton).disabled, "existing dirt-foundation grass gate preserved")
	await get_tree().process_frame
	menu.queue_free()
	await get_tree().process_frame
	print("SHARED_STYLES_SELECTOR checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

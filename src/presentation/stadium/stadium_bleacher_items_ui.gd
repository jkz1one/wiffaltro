class_name StadiumBleacherItemsUI
extends RefCounted
## Exact complete assemblies with same-side displacement and explicit land prerequisites.


static func card(menu: SeasonMenu, parent: VBoxContainer, draft: Dictionary, copy: String,
	item: String, revision: int, enabled: bool, tier: String, on_preview: Callable = Callable()) -> void:
	var options: Array[String] = ["Stored"]
	if StadiumLand.TIERS.find(tier) >= StadiumBleacherSites.TIERS[item]:
		options.append_array(["SIDE-SEAT-L", "SIDE-SEAT-R"])
	var selected: int = 0
	for row: Dictionary in draft.get("bleachers", []):
		if row.copy == copy:
			selected = options.find(row.site)
	var choice: OptionButton = StadiumEditorUI._options(parent, options, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not enabled
	SeasonPages.wrapped(parent, "Needs " + ("Expanded yard" if item == "ST-028" else "Club grounds")
		+ ". Choosing a side stores its existing seating free of charge. Each is a complete object.")
	choice.item_selected.connect(func(index: int) -> void:
		if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
			return
		if choice.is_item_disabled(index):
			return
		var next: Dictionary = StadiumBleacherItems.upgrade(draft)
		next.bleachers = next.bleachers.filter(func(row: Dictionary) -> bool: return row.copy != copy)
		if index > 0:
			var site: String = options[index]
			var side: String = StadiumSeatingLayout.SITES[site].side
			next.seating = next.seating.filter(func(row: Dictionary) -> bool:
				return StadiumSeatingLayout.SITES[row.site].side != side)
			next.bleachers = next.bleachers.filter(func(row: Dictionary) -> bool: return row.site != site)
			next.bleachers.append({"copy": copy, "site": site})
		next.bleachers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
		if on_preview.is_valid():
			on_preview.call(next, revision)
		else:
			StadiumEditorUI.show(menu, next, revision)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false))


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "LARGER BLEACHERS", 22)
	SeasonPages.wrapped(panel, "Separate complete assemblies. Buying one does not consume old seating."
		+ " "
		+ "Placement needs the listed land tier; no extra income or player benefits.")
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumPurchases.BLEACHERS:
		var quote: Dictionary = StadiumPurchases.quote(ledger.construction(), item, 1,
			"bleacher-preview", StadiumPurchases.BLEACHER_VERSION, progress)
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if ledger.construction().blueprints.has(item) else entry.blueprint_price
		var cost: int = blueprint + int(entry.copy_price)
		SeasonPages.wrapped(panel, "%s • Requires %d completed seasons and %d regular-season wins" % [
			entry.name, entry.requires.seasons, entry.requires.wins])
		SeasonPages.wrapped(panel, ("Blueprint owned • %d CB per copy" % entry.copy_price) if (
			blueprint == 0) else "%d blueprint + %d copy = %d CB" % [blueprint, entry.copy_price, cost])
		var buy: Button = menu._button(panel, "BUY " + entry.name.to_upper(),
			StadiumEditorUI._buy.bind(menu, item, ledger.revision()))
		buy.set_meta("stadium_buy", item)
		buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
		if not quote.ok:
			buy.tooltip_text = quote.error

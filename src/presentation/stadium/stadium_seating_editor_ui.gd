class_name StadiumSeatingEditorUI
extends RefCounted
## Exact owned seating, independent sides and visible free-storage consequences.


static func card(menu: SeasonMenu, parent: VBoxContainer, draft: Dictionary, copy: String,
	item: String, revision: int, enabled: bool, tier: String = "backyard", on_preview: Callable = Callable()) -> void:
	var options: Array[String] = ["Stored"]
	for site: String in StadiumSeatingLayout.SITES:
		var row: Dictionary = StadiumSeatingLayout.SITES[site]
		if row.item == item and row.tier <= StadiumLand.TIERS.find(tier):
			options.append(site)
	var selected: int = 0
	for row: Dictionary in draft.get("seating", []):
		if row.copy == copy:
			selected = options.find(row.site)
	var choice: OptionButton = StadiumEditorUI._options(parent, options, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not enabled
	if item == "ST-080":
		for row: Dictionary in draft.get("seating", []) + draft.get("bleachers", []):
			if row.site.begins_with("SIDE-SEAT-"):
				var side: String = StadiumSeatingLayout.SITES[row.site].side
				for index in range(1, options.size()):
					if StadiumSeatingLayout.SITES[options[index]].side == side:
						choice.set_item_disabled(index, true)
		SeasonPages.wrapped(parent,
			"Outside play. Remove a side's bleachers before placing chairs there.")
	else:
		SeasonPages.wrapped(parent, "Outside play. Choosing a side stores its chairs, free of charge. "
			+ "Removing bleachers does not automatically restore those chairs.")
	choice.item_selected.connect(func(index: int) -> void:
		if choice.is_item_disabled(index):
			return
		var next: Dictionary = StadiumHomeLayout.upgrade(draft)
		next.seating = next.seating.filter(func(row: Dictionary) -> bool: return row.copy != copy)
		if index > 0:
			var site: String = options[index]
			var side: String = StadiumSeatingLayout.SITES[site].side
			next.seating = next.seating.filter(func(row: Dictionary) -> bool:
				return row.site != site and (item != "ST-027" or (
					StadiumSeatingLayout.SITES[row.site].side != side)))
			if item == "ST-027" and next.has("bleachers"):
				next.bleachers = next.bleachers.filter(func(row: Dictionary) -> bool:
					return StadiumSeatingLayout.SITES[row.site].side != side)
			next.seating.append({"copy": copy, "site": site})
		next.seating.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.site < b.site)
		if on_preview.is_valid():
			on_preview.call(next, revision)
		else:
			StadiumEditorUI.show(menu, next, revision)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false))


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "SPECTATOR SEATING", 22)
	SeasonPages.wrapped(panel, "Unlock a blueprint once, then pay per copy. Uses the same Club Bucks. "
		+ "Audience is included with the seating and earns no extra income.")
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	SeasonPages.wrapped(panel, "Your club: %d completed seasons • %d regular-season wins" % [
		progress.seasons, progress.wins])
	for item: String in StadiumPurchases.SEATING:
		var quote: Dictionary = StadiumPurchases.quote(ledger.construction(), item, 1,
			"seating-preview", StadiumPurchases.SEATING_VERSION, progress)
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

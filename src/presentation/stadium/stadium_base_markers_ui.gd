class_name StadiumBaseMarkersUI
extends RefCounted
## One complete, once-owned marker set, independent of ground and mowing appearance.


static func show(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, editable: bool, clean_draft: bool) -> void:
	var stock: StadiumStock = ledger.construction()
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "BASE MARKERS", 22)
	SeasonPages.wrapped(panel, "Three visual bases; the existing home plate stays in place. "
		+ "Switch sets independently of dirt and grass. Scoring and running rules stay the same.")
	_selector(menu, panel, draft, stock, revision, editable)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumBaseMarkerModels.IDS:
		if stock.styles.has(item):
			continue
		var entry: Dictionary = StadiumCatalog.item(item)
		SeasonPages.wrapped(panel, "%s • Requires %d completed seasons and %d regular-season wins" % [
			entry.name, entry.requires.seasons, entry.requires.wins])
		var quote: Dictionary = StadiumInfieldStyles.quote(stock, item, "base-preview", progress)
		var buy: Button = menu._button(panel, "UNLOCK • %d CB" % entry.blueprint_price,
			StadiumFieldStylesUI._buy.bind(menu, item, revision))
		buy.set_meta("stadium_style_buy", item)
		buy.disabled = not editable or not clean_draft or not quote.ok \
			or ledger.balance() < entry.blueprint_price
		if not quote.ok:
			buy.tooltip_text = quote.error


static func _selector(menu: SeasonMenu, panel: VBoxContainer, draft: Dictionary,
	stock: StadiumStock, revision: int, editable: bool,
	preview: Callable = Callable()) -> void:
	var ids: Array[String] = [""]
	var names: Array[String] = ["Template • no extra markers"]
	for item: String in StadiumBaseMarkerModels.IDS:
		if stock.styles.has(item):
			ids.append(item)
			names.append(StadiumCatalog.item(item).name)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, ids.find(draft.get("bases", "")))
	choice.set_meta("stadium_style", "bases")
	choice.disabled = not editable
	choice.item_selected.connect(func(index: int) -> void:
		if choice.disabled or index < 0 or index >= ids.size():
			return
		if ids[index] == draft.get("bases", ""):
			return
		var next: Dictionary = StadiumInfieldStyles.upgrade(draft)
		next.bases = ids[index]
		if preview.is_valid():
			preview.call(next, revision)
		else:
			StadiumEditorUI.show(menu, next, revision)
		StadiumFieldStylesUI._focus.call_deferred(menu, "bases"))

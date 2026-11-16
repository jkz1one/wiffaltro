class_name StadiumGroundStylesUI
extends RefCounted
## One mutually exclusive ground treatment, independently owned from grass and lines.


static func show(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, editable: bool, clean_draft: bool) -> void:
	var stock: StadiumStock = ledger.construction()
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "DIRT / GRASS LAYOUT", 22)
	SeasonPages.wrapped(panel, "Choose where dirt replaces grass. "
		+ "Select the mowing pattern separately above. "
		+ "Owned layouts can be swapped freely; full infields and plate treatments are exclusive.")
	_selector(menu, panel, draft, stock, revision, editable, ledger.surface_owned())
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in _ids():
		if stock.styles.has(item):
			continue
		var entry: Dictionary = StadiumCatalog.item(item)
		var requirement: String = "%d completed seasons" % entry.requires.seasons
		if entry.requires.has("wins"):
			requirement += " and %d regular-season wins" % entry.requires.wins
		SeasonPages.wrapped(panel, entry.name + " • Requires " + requirement)
		var quote: Dictionary = StadiumInfieldStyles.quote(stock, item, "ground-preview", progress) \
			if StadiumInfieldModels.IDS.has(item) else (
				StadiumGroundStyles.quote(stock, item, "ground-preview", progress))
		var gate: String = StadiumSurfaceProgression.style_error(ledger.surface_owned(), item)
		if not gate.is_empty():
			quote = {"ok": false, "error": gate}
		var buy: Button = menu._button(panel, "UNLOCK • %d CB" % entry.blueprint_price,
			StadiumFieldStylesUI._buy.bind(menu, item, revision))
		buy.set_meta("stadium_style_buy", item)
		buy.disabled = not editable or not clean_draft or not quote.ok \
			or ledger.balance() < entry.blueprint_price
		if not quote.ok:
			buy.tooltip_text = quote.error


static func _ids() -> Array[String]:
	var result: Array[String] = StadiumGroundModels.IDS.duplicate()
	result.append_array(StadiumInfieldModels.IDS)
	return result


static func _selector(menu: SeasonMenu, panel: VBoxContainer, draft: Dictionary,
	stock: StadiumStock, revision: int, editable: bool, surface_owned: Array,
	preview: Callable = Callable()) -> void:
	var ids: Array[String] = [""]
	var names: Array[String] = ["Functional template"]
	for item: String in _ids():
		if stock.styles.has(item):
			ids.append(item)
			names.append(StadiumCatalog.item(item).name)
	var choice: OptionButton = StadiumEditorUI._options(
		panel, names, ids.find(draft.get("ground", "")))
	choice.set_meta("stadium_style", "ground")
	choice.disabled = not editable or (draft.has("surface") and (
		draft.surface.foundation != "grass" or not surface_owned.has("ground_prep")))
	choice.item_selected.connect(func(index: int) -> void:
		if choice.disabled or index < 0 or index >= ids.size():
			return
		var next: Dictionary = StadiumInfieldStyles.upgrade(draft) \
			if StadiumInfieldModels.IDS.has(ids[index]) else StadiumGroundStyles.upgrade(draft)
		next.ground = ids[index]
		if preview.is_valid():
			preview.call(next, revision)
		else:
			StadiumEditorUI.show(menu, next, revision)
		StadiumFieldStylesUI._focus.call_deferred(menu, "ground"))

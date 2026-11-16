class_name StadiumFieldStylesUI
extends RefCounted
## Individually purchased appearance channels; template remains functional without a purchase.


static func show(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, editable: bool, clean_draft: bool) -> void:
	var stock: StadiumStock = ledger.construction()
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "FIELD APPEARANCE", 22)
	SeasonPages.wrapped(panel, "Each look is a permanent unlock. Switching owned looks is free. "
		+ "Field dimensions, scoring, ball physics and player stats stay the same.")
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for channel: String in StadiumFieldStyleModels.CHANNELS:
		menu._label(panel, "BASELINES" if channel == "line" else "GRASS PATTERN", 18)
		_selector(menu, panel, draft, stock, channel, revision, editable)
		for item: String in StadiumFieldStyleModels.CHANNELS[channel]:
			if stock.styles.has(item):
				continue
			var entry: Dictionary = StadiumCatalog.item(item)
			var requirement: String = "%d completed seasons" % entry.requires.seasons
			if entry.requires.has("wins"):
				requirement += " and %d regular-season wins" % entry.requires.wins
			SeasonPages.wrapped(panel, entry.name + " • Requires " + requirement)
			var quote: Dictionary = StadiumFieldStyles.quote(stock, item, "style-preview",
				progress, StadiumFieldStyles.VERSION)
			var gate: String = StadiumSurfaceProgression.style_error(ledger.surface_owned(), item)
			if not gate.is_empty():
				quote = {"ok": false, "error": gate}
			var buy: Button = menu._button(panel, "UNLOCK • %d CB" % entry.blueprint_price,
				_buy.bind(menu, item, revision))
			buy.set_meta("stadium_style_buy", item)
			buy.disabled = not editable or not clean_draft or not quote.ok \
				or ledger.balance() < entry.blueprint_price
			if not quote.ok:
				buy.tooltip_text = quote.error


static func _selector(menu: SeasonMenu, panel: VBoxContainer, draft: Dictionary,
	stock: StadiumStock, channel: String, revision: int, editable: bool,
	preview: Callable = Callable()) -> void:
	var ids: Array[String] = [""]
	var names: Array[String] = ["Functional template"]
	for item: String in StadiumFieldStyleModels.CHANNELS[channel]:
		if stock.styles.has(item):
			ids.append(item)
			names.append(StadiumCatalog.item(item).name)
	var current: String = draft.get("styles", {}).get(channel, "")
	var choice: OptionButton = StadiumEditorUI._options(panel, names, ids.find(current))
	choice.set_meta("stadium_style", channel)
	choice.disabled = not editable or (channel == "grass" and draft.has("surface")
		and draft.surface.foundation != "grass")
	choice.item_selected.connect(func(index: int) -> void:
		if choice.disabled or index < 0 or index >= ids.size():
			return
		var next: Dictionary = StadiumFieldStyles.upgrade(draft)
		next.styles[channel] = ids[index]
		if preview.is_valid():
			preview.call(next, revision)
		else:
			StadiumEditorUI.show(menu, next, revision)
		_focus.call_deferred(menu, channel))


static func _focus(menu: SeasonMenu, channel: String) -> void:
	if menu.page not in ["stadium", "shared_stadium"]:
		return
	for control: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if control.get_meta("stadium_style", "") == channel:
			control.grab_focus()
			return


static func _buy(menu: SeasonMenu, item: String, revision: int) -> void:
	var result: Dictionary = ClubConstruction.buy_style(menu.app.season, item, revision)
	menu.app.notice = "Appearance unlocked. Select it, save the draft, then apply." if result.ok \
		else result.error
	StadiumEditorUI.show(menu)

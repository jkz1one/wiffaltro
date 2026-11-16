class_name StadiumLightItemsUI
extends RefCounted
## Distinct paid yard poles, fixed sockets and explicit night eligibility feedback.


static func card(menu: SeasonMenu, parent: VBoxContainer, draft: Dictionary, copy: String,
	revision: int, enabled: bool, on_preview: Callable = Callable()) -> void:
	var options: Array[String] = ["Stored"]
	options.append_array(StadiumYardLightModels.SITES.keys())
	var selected: int = 0
	for row: Dictionary in draft.get("lights", []):
		if row.copy == copy:
			selected = options.find(row.site)
	var choice: OptionButton = StadiumEditorUI._options(parent, options, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not enabled
	SeasonPages.wrapped(parent, "Four distinct poles in all four sockets unlock the yard night pool. "
		+ "Choosing an occupied socket stores its previous pole for free.")
	choice.item_selected.connect(func(index: int) -> void:
		if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
			return
		if choice.is_item_disabled(index):
			return
		if index == selected:
			return
		var next: Dictionary = StadiumLightItems.upgrade(draft)
		next.lights = next.lights.filter(func(row: Dictionary) -> bool:
			return row.copy != copy and (index == 0 or row.site != options[index]))
		if index > 0:
			next.lights.append({"copy": copy, "site": options[index]})
		next.lights.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a.site < b.site)
		if on_preview.is_valid():
			on_preview.call(next, revision)
		else:
			StadiumEditorUI.show(menu, next, revision)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false))


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "YARD LIGHTS", 22)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	SeasonPages.wrapped(panel, "Unlock after 3 completed seasons and 8 regular-season wins. "
		+ "Your closed career: %d seasons • %d wins." % [progress.seasons, progress.wins])
	var quote: Dictionary = StadiumPurchases.quote(ledger.construction(), "ST-037", 1,
		"light-preview", StadiumPurchases.LIGHT_VERSION, progress)
	var blueprint: int = 0 if ledger.construction().blueprints.has("ST-037") else 300
	SeasonPages.wrapped(panel, "Blueprint owned • 65 CB per pole" if blueprint == 0 \
		else "300 blueprint + 65 first pole = 365 CB • Four-pole set totals 560 CB")
	SeasonPages.wrapped(panel, "Night qualification: Backyard or Expanded, all four yard sockets, "
		+ "compatible installed items. Partial sets remain decorative. Day games stay available.")
	var buy: Button = menu._button(panel, "BUY YARD LIGHT POLE",
		StadiumEditorUI._buy.bind(menu, "ST-037", ledger.revision()))
	buy.set_meta("stadium_buy", "ST-037")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < blueprint + 65
	if not quote.ok:
		buy.tooltip_text = quote.error


static func status(checked: Dictionary) -> String:
	return "Day + night eligible" if checked.get("night_qualified", false) else "Daylight only"


static func warning(menu: SeasonMenu, active: Dictionary, checked: Dictionary,
	stock: StadiumStock, tier: String, ledger: ClubAssetLedger = null) -> void:
	var previous: Dictionary = StadiumEditorUI._checked(ledger, active, tier) if ledger != null \
		else StadiumHomeLayout.validate(active, stock, tier)
	if previous.get("night_qualified", false) and not checked.get("night_qualified", false):
		SeasonPages.wrapped(menu._body, "This draft removes night eligibility. Applying it makes "
			+ "future home starts daylight-only; already frozen games keep their environment.")

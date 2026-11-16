class_name StadiumWaterfallItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Each explicit decorative or live installation consumes one exact paid waterfall copy.

const NIGHT_REASON: String = ("The decorative waterfall is daylight-only until its lighting and " \
	+ "camera views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "LANDMARK-A", "WF-LIVE-LF"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "COMPLETE ROCK-FACE WATERFALL", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumWaterfallItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Decorative site: %d of 1 • live site: %d of 1 • %d owned copies"
			% [
				draft.get("waterfalls", []).size(),
				draft.get("live_waterfalls", []).size(),
				owned_count
			]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Choose decorative LANDMARK-A, a qualified outfield plaza pad, or the explicit "
				+ "full-scale live WF-LIVE-LF site. Decorative placements remain out of play, have no "
				+ "colliders and never award a result. The live site uses all four live units with no "
				+ "companions: rock and basin hits stay live; a genuinely witnessed unreachable resting "
				+ "ball awards at least a single, preserving higher earned awards and foul precedence."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumWaterfallItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		var gate: String = "24 completed seasons / 90 regular-season wins"
		SeasonPages.wrapped(
			panel,
			(
				"%s • %s • %d blueprint + %d per copy • next copy %d CB"
				% [entry.name, gate, entry.blueprint_price, entry.copy_price, cost]
			)
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock,
			item,
			1,
			"waterfalls-preview:" + item,
			StadiumWaterfallItems.PRICE_VERSION,
			progress
		)
		var buy: Button = menu._button(
			panel, "BUY " + entry.name.to_upper(), StadiumEditorUI._buy.bind(menu, item, revision)
		)
		buy.set_meta("stadium_buy", item)
		buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
		if not quote.ok:
			buy.tooltip_text = quote.error
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Store the exact copy or conflicting installation before moving it. Plaza pads are "
					+ "selected in the plaza card. Live capacity and no-companion balancing are Working, "
					+ "not final user tuning. "
				)
				+ NIGHT_REASON
			)
		)
	)


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var stock: StadiumStock = ledger.construction()
	var names: Array[String] = choices()
	var selected: int = 0
	for placed: Dictionary in draft.get("waterfalls", []) + draft.get("live_waterfalls", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = _place(draft, stock, copy, names[index], ledger.surface_owned())
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in (
			candidate.get("waterfalls", []) + candidate.get("live_waterfalls", [])
		):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This exact layout cannot adopt this complete waterfall assembly."
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				_store(draft, copy)
				if index == 0
				else _place(draft, stock, copy, names[index], ledger.surface_owned())
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func _place(
	layout: Dictionary, stock: StadiumStock, copy: String, site: String, access: Array[String]
) -> Dictionary:
	return (
		StadiumWaterfallLiveItems.place(layout, stock, copy, site, 0.0, access)
		if site == StadiumWaterfallLiveSites.SITE
		else StadiumWaterfallItems.place(layout, stock, copy, site, 0.0, access)
	)


static func _store(layout: Dictionary, copy: String) -> Dictionary:
	return StadiumWaterfallItems.store_copy(
		StadiumWaterfallLiveItems.store_copy(layout, copy), copy
	)

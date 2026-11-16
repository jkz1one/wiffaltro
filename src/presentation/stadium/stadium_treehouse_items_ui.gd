class_name StadiumTreehouseItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## One complete paid treehouse includes its support tree, cabin, platform and ladder.

const NIGHT_REASON: String = \
	("The treehouse is daylight-only until its lighting and camera views " + "are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "TREEHOUSE-A"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "BACKYARD TIMBER TREEHOUSE", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumTreehouseItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Treehouse site: %d filled • %d owned copies"
			% [draft.get("treehouses", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Expanded+ supplies one fixed site. One owned ST-045 copy includes its tree, cabin, "
				+ "platform, ladder and railings. It neither grants nor consumes a separate ST-013 tree."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumTreehouseItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		var gate: String = "6 seasons / 18 recorded wins"
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
			"treehouse-preview:" + item,
			StadiumTreehouseItems.PRICE_VERSION,
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
					"Store all molded seats and explicitly remove the overlapping pad before placing the "
					+ "treehouse. Store the treehouse before selecting that pad again. No automatic "
					+ "displacement, climbing, training, player-stat or income effect. "
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
	for placed: Dictionary in draft.get("treehouses", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumTreehouseItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("treehouses", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This exact layout cannot adopt the complete treehouse."
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumTreehouseItems.store_copy(draft, copy)
				if index == 0
				else StadiumTreehouseItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

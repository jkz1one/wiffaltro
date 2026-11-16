class_name StadiumRisingAppleItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Each installation consumes one exact complete paid rising-apple copy.

const NIGHT_REASON: String = \
	("The rising apple is daylight-only until their lighting and camera " + "views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "LANDMARK-A"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "COMPLETE RISING HOME-RUN APPLE", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumRisingAppleItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Rising apple site: %d of 1 filled • %d owned copies"
			% [draft.get("rising_apple", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Mogul grounds supply the exclusive LANDMARK-A reservation. The complete assembly "
				+ "includes its fixed base, lift guide and moving apple. It rises only after a "
				+ "confirmed home run and resets before the next pitch."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumRisingAppleItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		var gate: String = "20 seasons / 40 validated home runs"
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
			"rising_apple-preview:" + item,
			StadiumRisingAppleItems.PRICE_VERSION,
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
					"Store an existing landmark or conflicting outer-right Club tower first. The full "
					+ "reservation is exclusive, with no Plaza placement. This presentation awards no "
					+ "score or gameplay bonus. "
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
	for placed: Dictionary in draft.get("rising_apple", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumRisingAppleItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("rising_apple", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This exact layout cannot adopt this complete rising-apple assembly."
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumRisingAppleItems.store_copy(draft, copy)
				if index == 0
				else StadiumRisingAppleItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

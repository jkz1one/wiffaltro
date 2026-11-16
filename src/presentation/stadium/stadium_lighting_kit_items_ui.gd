class_name StadiumLightingKitItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## One complete paid kit freely switches patterns; no legacy conversion.

const NIGHT_REASON: String = \
	("Season Night remains unavailable until this kit passes moving-ball " + "readability checks.")


static func choices() -> Array[String]:
	return ["Stored", "PARALLEL", "ZIGZAG", "PERIMETER", "MIXED_EDGE"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "SWITCHABLE FIELD STRING-LIGHT KIT", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumLightingKitItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Kit pattern: %d of 1 filled • %d owned copies"
			% [draft.get("lighting_kits", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"One complete kit, one selected pattern. Switch patterns freely without buying again. "
				+ "Supports stay outside play; overhead cables do not collide with balls. Basic ST-037 "
				+ "yard poles are separately purchased and can be mixed where clearance allows."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumLightingKitItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		var gate: String = "3 completed seasons / 8 regular-season wins"
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
			"lighting_kits-preview:" + item,
			StadiumLightingKitItems.PRICE_VERSION,
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
					"Working prices: 260 CB blueprint plus 120 CB per complete kit. Existing ST-036 "
					+ "fixed spans stay owned separately, without conversion. Authored away parks do not "
					+ "automatically adopt the home selection. "
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
	for placed: Dictionary in draft.get("lighting_kits", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumLightingKitItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("lighting_kits", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This exact layout cannot adopt this complete lighting kit."
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumLightingKitItems.store_copy(draft, copy)
				if index == 0
				else StadiumLightingKitItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

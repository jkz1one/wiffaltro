class_name StadiumPracticeFacilityItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Complete paid practice lanes are scenery, not training purchases or receivers.

const NIGHT_REASON: String = \
	("Practice facilities are daylight-only until their lighting and camera " + "views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "PRACTICE-CLUB", "PRACTICE-M1", "PRACTICE-M2"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "COMPLETE PRACTICE FACILITIES", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumPracticeFacilityItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Practice sites: %d filled • %d owned copies"
			% [draft.get("practice_facilities", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Club supplies one lane; Mogul supplies two independent lanes. Each complete bullpen "
				+ "or practice cage uses one paid copy, including its frame, fence or net, supported "
				+ "base and practice markings. Expansion grants no copies."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumPracticeFacilityItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		var gate: String = (
			"10 seasons / 120 recorded strikeouts"
			if item == "ST-060"
			else "10 seasons / 160 recorded hits"
		)
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
			"practice-facility-preview:" + item,
			StadiumPracticeFacilityItems.PRICE_VERSION,
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
					"Store the Club facility before selecting either overlapping Mogul lane, and Store "
					+ "either Mogul occupant before returning to Club. No automatic displacement, "
					+ "training, player-stat or income effect. Practice facilities never replace the "
					+ "active catcher or backstop. "
				)
				+ NIGHT_REASON
			)
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Recorded hits count only validated new career evidence. Historical totals that were "
				+ "not saved remain unknown and do not unlock a practice cage."
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
	for placed: Dictionary in draft.get("practice_facilities", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumPracticeFacilityItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("practice_facilities", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This exact layout cannot adopt a complete practice facility."
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumPracticeFacilityItems.store_copy(draft, copy)
				if index == 0
				else StadiumPracticeFacilityItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

class_name StadiumBoundaryItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Ordinary Workshop controls for exact boundary ownership and whole-run replacement.


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "DUGOUTS & BOUNDARY OBJECTS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Dugouts and foul poles are separately owned on each side. Distance panels need an "
				+ "exact back-wall host. Rear fences install as complete eight-copy runs. Moving and "
				+ "storage are free."
			)
		)
	)
	var history: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(history, history.size())
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumBoundaryItems.PRICES:
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if stock.blueprints.has(item) else int(entry.blueprint_price)
		var cost: int = blueprint + int(entry.copy_price)
		SeasonPages.wrapped(
			panel,
			(
				"%s • Requires %d seasons and %d wins • %d blueprint + %d copy = %d CB"
				% [
					entry.name,
					entry.requires.seasons,
					entry.requires.get("wins", 0),
					blueprint,
					entry.copy_price,
					cost
				]
			)
		)
		var quote: Dictionary = StadiumPurchases.quote(
			stock, item, 1, "boundary-preview", StadiumBoundaryItems.PRICE_VERSION, progress
		)
		var buy: Button = menu._button(
			panel,
			"BUY " + entry.name.to_upper(),
			StadiumEditorUI._buy.bind(menu, item, ledger.revision())
		)
		buy.set_meta("stadium_buy", item)
		buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
		if not quote.ok:
			buy.tooltip_text = quote.error
		if item in StadiumBoundaryItems.FENCES:
			var count: int = StadiumWallItemsUI._count(stock, item)
			var missing: int = maxi(0, 8 - count)
			var run_cost: int = blueprint + missing * int(entry.copy_price)
			var run_quote: Dictionary = StadiumPurchases.quote(
				stock,
				item,
				maxi(1, missing),
				"rear-preview",
				StadiumBoundaryItems.PRICE_VERSION,
				progress
			)
			var run: Button = menu._button(
				panel,
				(
					"COMPLETE REAR RUN • %d OWNED • BUY %d MISSING • %d CB"
					% [count, missing, run_cost]
				),
				_buy_run.bind(menu, item, missing, run_cost, ledger.revision())
			)
			run.set_meta("boundary_run_buy", item)
			run.disabled = (
				not enabled or missing == 0 or not run_quote.ok or ledger.balance() < run_cost
			)


static func _buy_run(menu: SeasonMenu, item: String, count: int, cost: int, revision: int) -> void:
	(
		menu
		. app
		. _confirm(
			(
				"Buy %d %s copies for %d Club Bucks, including any unowned blueprint? Copies go into storage."
				% [count, StadiumFieldLabels.item_name(item), cost]
			),
			_complete_run_buy.bind(menu, item, count, revision)
		)
	)


static func _complete_run_buy(menu: SeasonMenu, item: String, count: int, revision: int) -> void:
	var result: Dictionary = ClubConstruction.buy_copy(menu.app.season, item, revision, count)
	menu.app.notice = (
		"Rear fence copies purchased and stored. Choose the complete run, save, then apply."
		if result.ok
		else result.error
	)
	StadiumEditorUI.show(menu)


static func card(
	menu: SeasonMenu,
	panel: VBoxContainer,
	draft: Dictionary,
	copy: String,
	item: String,
	revision: int,
	editable: bool,
	supplied: ClubAssetLedger = null,
	preview: Callable = Callable()
) -> void:
	if item in StadiumBoundaryItems.FENCES:
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"This exact fence copy belongs to inventory. Use the complete rear-run control to "
					+ "install or store eight copies together."
				)
			)
		)
		return
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var stock: StadiumStock = ledger.construction()
	var next_base: Dictionary = StadiumBoundaryItems.upgrade(draft, ledger.surface_owned())
	var labels: Array[String] = ["Stored"]
	var choices: Array = [{}]
	var selected: int = 0
	if not next_base.is_empty():
		choices.append_array(
			StadiumBoundaryItems.options(next_base, stock, item, ledger.view().land)
		)
	for index in range(1, choices.size()):
		labels.append(choices[index].label)
		var placement: Dictionary = choices[index].row.duplicate(true)
		placement.copy = copy
		if next_base.get("boundary", []).has(placement):
			selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or next_base.is_empty()
	if item in StadiumBoundaryItems.DUGOUTS:
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"A dugout replaces its side's three opening panels; those exact copies are stored. "
					+ "Storing or moving the dugout restores the included side boundary and stores its "
					+ "sixteen paid panels. Use explicit wall restoration to reinstall nineteen paid "
					+ "copies."
				)
			)
		)
	elif item == "ST-064":
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"The distance is derived from this exact installed wall host. Replacing or storing "
					+ "that host also stores the panel."
				)
			)
		)
	else:
		SeasonPages.wrapped(
			panel,
			"Each side uses its own owned pole. Replacing an occupant stores that exact copy."
		)
	if choices.size() == 1:
		SeasonPages.wrapped(panel, "No compatible site is available. This exact copy stays stored.")
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= choices.size() or index == selected or next_base.is_empty():
				return
			var next: Dictionary = StadiumBoundaryItems.select(
				next_base, stock, copy, choices[index].get("row", {})
			)
			EditorAccess.editor_preview(menu, next, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)


static func runs(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, editable: bool, preview: Callable = Callable()
) -> void:
	var layout: Dictionary = StadiumBoundaryItems.upgrade(draft, ledger.surface_owned())
	if layout.is_empty():
		return
	var stock: StadiumStock = ledger.construction()
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "REAR RUN & SIDE RESTORATION", 22)
	var labels: Array[String] = ["Included rear boundary"]
	var items: Array[String] = [""]
	var selected: int = 0
	for item: String in StadiumBoundaryItems.FENCES:
		items.append(item)
		labels.append(StadiumFieldLabels.item_name(item) + " • eight owned copies")
		for row: Dictionary in layout.boundary:
			if row.site.begins_with("REAR-") and row.item == item:
				selected = items.size() - 1
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("boundary_rear_run", true)
	choice.disabled = not editable
	for index in range(1, items.size()):
		choice.set_item_disabled(index, StadiumWallItemsUI._count(stock, items[index]) < 8)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"One complete run at a time. Replacing a run stores all eight displaced copies. The "
				+ "existing Apply preview shows every displaced copy before commitment."
			)
		)
	)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.disabled and index >= 0 and index < items.size() and not choice.is_item_disabled(index) and index != selected:
				EditorAccess.editor_preview(
					menu, StadiumBoundaryItems.select_rear(layout, stock, items[index]), revision, preview
				)
	)
	var checked: Dictionary = StadiumBoundaryItems.validate(layout, stock, ledger.view().land)
	if not checked.ok:
		return
	for left: bool in [true, false]:
		var side: String = "left" if left else "right"
		if layout.walls[side].size() != 16:
			continue
		var copies: Array[String] = []
		for copy: String in checked.stored:
			if stock.copies[copy].item == StadiumWallLayout.SIDES[side]:
				copies.append(copy)
		copies.sort()
		if copies.size() > 3:
			copies.resize(3)
		(
			SeasonPages
			. wrapped(
				panel,
				(
					"%s side: restore nineteen paid panels and store the dugout. Exact extra copies: %s."
					% [side.capitalize(), ", ".join(copies)]
				)
			)
		)
		var restore: Button = menu._button(
			panel,
			"PREVIEW " + side.to_upper() + " WALL RESTORATION",
			_restore.bind(menu, layout, stock, left, copies, revision, preview)
		)
		restore.set_meta("boundary_restore", side)
		restore.disabled = not editable or copies.size() != 3


static func _restore(
	menu: SeasonMenu,
	layout: Dictionary,
	stock: StadiumStock,
	left: bool,
	copies: Array[String],
	revision: int, preview: Callable = Callable()
) -> void:
	var result: Dictionary = StadiumBoundaryItems.restore_side(layout, stock, left, copies)
	if result.ok:
		EditorAccess.editor_preview(menu, result.layout, revision, preview)
	else:
		menu.app.notice = result.error
		EditorAccess.editor_preview(menu, layout, revision, preview)

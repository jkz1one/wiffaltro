class_name StadiumReceiverOwnedItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Ordinary exact-copy Workshop choices for the catching layer and empty primary.


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "RECEIVER CAGE & TALL NET", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"One separately owned catching assembly. Keep the primary empty, or install your "
				+ "target or chair. The empty primary is free and has no physical object. Tall nets "
				+ "need Club grounds. Moving and storage are free."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumReceiverOwnedItems.PRICES:
		var entry: Dictionary = StadiumCatalog.item(item)
		var blueprint: int = 0 if stock.blueprints.has(item) else int(entry.blueprint_price)
		var cost: int = blueprint + int(entry.copy_price)
		SeasonPages.wrapped(
			panel,
			(
				"%s • %d seasons / %d wins • %d blueprint + %d copy = %d CB"
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
			stock, item, 1, "receiver-preview", StadiumReceiverOwnedItems.PRICE_VERSION, progress
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
	var ledger: ClubAssetLedger = EditorAccess.editor_ledger(menu, supplied)
	var layout: Dictionary = StadiumReceiverOwnedItems.upgrade(draft, ledger.surface_owned())
	var selected: int = 1 if layout.get("catcher", "") == copy else 0
	var choice: OptionButton = StadiumEditorUI._options(
		panel, ["Stored", "Receiver catching assembly"], selected
	)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or layout.is_empty()
	var candidate: Dictionary = StadiumReceiverOwnedItems.select(
		layout, ledger.construction(), copy
	)
	var checked: Dictionary = StadiumHomeLayout.validate(
		candidate, ledger.construction(), ledger.view().land
	)
	choice.set_item_disabled(1, not checked.ok)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Installs this exact copy and stores the previous catching assembly. Primary target "
					+ "or chair stays in place. The cage stays open at the front and top."
				)
				if item == "ST-072"
				else ("Installs this exact tall net and stores the previous catching " + \
					"assembly. Primary target or chair stays in place.")
			)
		)
	)
	if not checked.ok:
		SeasonPages.wrapped(panel, checked.error)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= choice.item_count or choice.is_item_disabled(index) or index == selected or layout.is_empty():
				return
			EditorAccess.editor_preview(
				menu,
				StadiumReceiverOwnedItems.select(
					layout, ledger.construction(), copy if index == 1 else ""
				),
				revision, preview
			)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

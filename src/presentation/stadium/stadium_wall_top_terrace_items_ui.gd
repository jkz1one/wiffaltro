class_name StadiumWallTopTerraceItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Each installation consumes one exact complete paid wall-top terrace copy.

const NIGHT_REASON: String = \
	("The wall-top terrace is daylight-only until its lighting and camera " + "views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "TERRACE-R-A"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "COMPLETE WALL-TOP SPECTATOR TERRACE", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if StadiumWallTopTerraceItems.PRICES.has(stock.copies[copy].item):
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Wall-top terrace site: %d of 1 filled • %d owned copies"
			% [draft.get("wall_top_terrace", []).size(), owned_count]
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"TERRACE-R-A needs a complete straight back wall: 23 independently paid ST-065 padded "
				+ "panels or 23 independently paid ST-077 brick panels. Six designated consecutive full "
				+ "panels are the terrace hosts; six total wall purchases are insufficient. The terrace "
				+ "is a separate complete paid copy with deck, viewing positions, rails, rear supports, "
				+ "access and finished ends."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for item: String in StadiumWallTopTerraceItems.ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		var cost: int = (
			int(entry.copy_price)
			+ (0 if stock.blueprints.has(item) else int(entry.blueprint_price))
		)
		var gate: String = "14 seasons / 44 validated wins"
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
			"wall_top_terrace-preview:" + item,
			StadiumWallTopTerraceItems.PRICE_VERSION,
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
					"Only a uniform straight padded or brick run qualifies. Store the terrace first "
					+ "before removing or replacing any of its six exact hosts. Restoring the wall never "
					+ "places it automatically. Store TREE-R or conflicting hedges first. This terrace is "
					+ "outside live play, consumes no live-object unit and awards no gameplay bonus. "
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
	var host: Dictionary = StadiumWallTopTerraceItems.host_info(draft, stock)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Requires 23 separately paid matching wall panels; six exact consecutive panels "
					+ "support this complete terrace. "
				)
				+ ("Compatible hosts installed." if host.ok else host.error)
			)
		)
	)
	var selected: int = 0
	for placed: Dictionary in draft.get("wall_top_terrace", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumWallTopTerraceItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("wall_top_terrace", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			(
				choice
				. set_item_tooltip(
					index,
					(
						checked.error
						if not checked.ok
						else (
							host.error
							if not host.ok
							else "This exact layout cannot adopt this complete wall-top terrace assembly."
						)
					)
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumWallTopTerraceItems.store_copy(draft, copy)
				if index == 0
				else StadiumWallTopTerraceItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

class_name StadiumGroundBoxItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## One complete paid section per fixed ground box site, never an implicit pad adoption.

const NIGHT_REASON: String = \
	("Ground box-seat sections are daylight-only until their lighting and " + \
	"camera views are qualified.")


static func choices() -> Array[String]:
	return ["Stored", "BOX-L", "BOX-R"]


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "GROUND BOX-SEAT SECTIONS", 22)
	var stock: StadiumStock = ledger.construction()
	var owned_count: int = 0
	for copy: String in stock.copies:
		if stock.copies[copy].item == "ST-052":
			owned_count += 1
	SeasonPages.wrapped(
		panel,
		(
			"Box sites: %d of 2 filled • %d owned copies"
			% [draft.get("ground_boxes", []).size(), owned_count]
		)
	)
	var entry: Dictionary = StadiumCatalog.item("ST-052")
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var cost: int = (
		int(entry.copy_price)
		+ (0 if stock.blueprints.has("ST-052") else int(entry.blueprint_price))
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Expanded+ supplies two independent BOX sites. Each rail-enclosed section uses one "
				+ "owned ST-052 copy, including its base, represented seats and local access. "
				+ "Individual molded seats and their optional pad are separate."
			)
		)
	)
	SeasonPages.wrapped(
		panel,
		(
			"%d seasons / %d wins • %d blueprint + %d per copy • next copy %d CB"
			% [
				entry.requires.seasons,
				entry.requires.wins,
				entry.blueprint_price,
				entry.copy_price,
				cost
			]
		)
	)
	var quote: Dictionary = StadiumPurchases.quote(
		stock, "ST-052", 1, "ground-box-preview", StadiumGroundBoxItems.PRICE_VERSION, progress
	)
	var buy: Button = menu._button(
		panel, "BUY " + entry.name.to_upper(), StadiumEditorUI._buy.bind(menu, "ST-052", revision)
	)
	buy.set_meta("stadium_buy", "ST-052")
	buy.disabled = not enabled or not quote.ok or ledger.balance() < cost
	if not quote.ok:
		buy.tooltip_text = quote.error
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Store the same-side BASE grandstand or dugout before placing a section. Opposite "
					+ "sides are independent; stored copies are never consumed or automatically "
					+ "reinstalled. "
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
	for placed: Dictionary in draft.get("ground_boxes", []):
		if placed.copy == copy:
			selected = names.find(placed.site)
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(1, names.size()):
		var candidate: Dictionary = StadiumGroundBoxItems.place(
			draft, stock, copy, names[index], 0.0, ledger.surface_owned()
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var exact: bool = false
		for placed: Dictionary in candidate.get("ground_boxes", []):
			if placed.copy == copy and placed.site == names[index]:
				exact = true
		choice.set_item_disabled(index, not checked.ok or not exact)
		if not checked.ok or not exact:
			choice.set_item_tooltip(
				index,
				(
					checked.error
					if not checked.ok
					else "This exact layout cannot adopt a ground box section."
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumGroundBoxItems.store_copy(draft, copy)
				if index == 0
				else StadiumGroundBoxItems.place(
					draft, stock, copy, names[index], 0.0, ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

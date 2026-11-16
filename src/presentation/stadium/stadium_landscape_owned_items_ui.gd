class_name StadiumLandscapeOwnedItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Exact owned landscape choices; invalid sites stay visible with their measured reason.

const NIGHT_REASON: String = \
	("Owned landscaping is daylight-only until its lighting and backdrop " + \
	"are qualified. Store the landscaping to recover the prior floodlight " + "layout.")


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "OFF-FIELD LANDSCAPING", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Whole trees, finished two-metre hedge sections, koi ponds and rock gardens. One paid "
				+ "copy per site; moving and storage are free. These scenery sites have no live ball, "
				+ "fielding or treehouse role. Ponds and rock gardens need Expanded grounds."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumLandscapeOwnedItems.PRICES:
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
			stock, item, 1, "landscape-preview", StadiumLandscapeOwnedItems.PRICE_VERSION, progress
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
	SeasonPages.wrapped(panel, NIGHT_REASON)


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
	var stock: StadiumStock = ledger.construction()
	var layout: Dictionary = StadiumLandscapeOwnedItems.upgrade(draft, ledger.surface_owned())
	var active: String = ""
	var yaw: int = 0
	for row: Dictionary in layout.get("landscape", []):
		if row.copy == copy:
			active = row.site
			yaw = int(row.yaw)
	var names: Array[String] = ["Stored"]
	var sites: Array[String] = [""]
	var angles: Array[int] = [0]
	for site: String in StadiumLandscapeOwnedItems.sites(item):
		var rotations: Array[int] = [0]
		if item == "ST-019":
			rotations = [0, 90, 180, 270]
		for angle: int in rotations:
			names.append(site + (" • %d°" % angle if item == "ST-019" else ""))
			sites.append(site)
			angles.append(angle)
	var selected: int = 0
	for index in range(1, sites.size()):
		if sites[index] == active and angles[index] == yaw:
			selected = index
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable or layout.is_empty()
	for index in range(1, sites.size()):
		var candidate: Dictionary = StadiumLandscapeOwnedItems.place(
			layout, stock, copy, sites[index], angles[index]
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		choice.set_item_disabled(index, not checked.ok)
		if not checked.ok:
			choice.set_item_tooltip(index, checked.error)
			SeasonPages.wrapped(panel, names[index] + ": " + checked.error)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Each hedge is a finished two-metre section; gaps stay empty and included caps "
					+ "create no extra copies."
				)
				if item == "ST-014"
				else ("This entire scenery assembly belongs to the selected paid copy. " + \
					"Conflicting placements must be stored explicitly.")
			)
		)
	)
	choice.item_selected.connect(
		func(index: int) -> void:
			if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= choice.item_count:
				return
			if choice.is_item_disabled(index):
				return
			if index == selected or layout.is_empty():
				return
			var candidate: Dictionary = StadiumLandscapeOwnedItems.place(
				layout, stock, copy, sites[index], angles[index]
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

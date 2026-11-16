class_name StadiumLiveFurnishingItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")
## Exact paid BS furnishings. Live and scenery use the same owned copy.

const NIGHT_REASON: String = \
	("Live furnishings are daylight-only until their lighting and camera " + \
	"views are qualified. Store them to recover the prior layout.")


static func purchases(menu: SeasonMenu, ledger: ClubAssetLedger, enabled: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "BEACH BALL AND HOT TUB", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"One paid copy moves freely between compatible live-field and scenery sites. Beach "
				+ "ball: one unit, fixed center with visual wobble. Hot tub: three units, live rim and "
				+ "fair water entry awards at least Double, preserving any higher earned result; foul "
				+ "water entry stays Foul. Scenery has no live effect. Four live instances and four "
				+ "total units maximum."
			)
		)
	)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	var stock: StadiumStock = ledger.construction()
	for item: String in StadiumLiveFurnishingItems.PRICES:
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
			stock,
			item,
			1,
			"live_furnishings-preview",
			StadiumLiveFurnishingItems.PRICE_VERSION,
			progress
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
	var layout: Dictionary = StadiumLiveFurnishingItems.upgrade(draft, ledger.surface_owned())
	var active: String = ""
	var yaw: int = 0
	for row: Dictionary in layout.get("live_furnishings", []):
		if row.copy == copy:
			active = row.site
			yaw = int(row.yaw)
	var names: Array[String] = ["Stored"]
	var sites: Array[String] = [""]
	var angles: Array[int] = [0]
	for site: String in StadiumLiveFurnishingItems.sites(item):
		var rotations: Array[int] = [0]

		for angle: int in rotations:
			names.append(site)
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
		var candidate: Dictionary = StadiumLiveFurnishingItems.place(
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
				"The live tub permits only one opposite-side O2 small companion. Incompatible "
				+ "occupants must be stored explicitly; nothing is displaced automatically."
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
			var candidate: Dictionary = StadiumLiveFurnishingItems.place(
				layout, stock, copy, sites[index], angles[index]
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
			if not preview.is_valid():
				StadiumEditorUI._focus_choice.call_deferred(menu, copy, false)
	)

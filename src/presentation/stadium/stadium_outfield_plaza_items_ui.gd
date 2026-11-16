class_name StadiumOutfieldPlazaItemsUI
extends RefCounted
const EditorAccess = preload("res://src/presentation/stadium/stadium_career_access.gd")


static func purchases(
	menu: SeasonMenu, ledger: ClubAssetLedger, _draft: Dictionary, revision: int, enabled: bool
) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "OUTFIELD CONCOURSES & PLAZAS", 22)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				"Mogul outer-ground infrastructure: connected paving, seating benches and a partial "
				+ "outer backdrop. Choose Promenade Court, Garden Plaza or Heritage Walk. The HR wall "
				+ "stays separate. Landmarks and rock gardens are optional separately owned copies, "
				+ "never bundled or moved automatically."
			)
		)
	)
	(
		SeasonPages
		. wrapped(
			panel,
			(
				(
					"Working price: 1100 CB blueprint + 420 CB per complete kit. Requires 24 completed "
					+ "seasons and 90 regular-season wins. "
				)
				+ StadiumOutfieldPlazaItems.NIGHT_REASON
			)
		)
	)
	var progress_rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(progress_rows, progress_rows.size())
	var quote: Dictionary = StadiumPurchases.quote(
		ledger.construction(),
		"ST-112",
		1,
		"plaza-preview",
		StadiumOutfieldPlazaItems.PRICE_VERSION,
		progress
	)
	var buy: Button = menu._button(
		panel, "BUY COMPLETE PLAZA KIT", StadiumEditorUI._buy.bind(menu, "ST-112", revision)
	)
	buy.set_meta("stadium_buy", "ST-112")
	buy.disabled = (
		not enabled
		or not quote.ok
		or ledger.balance() < int(quote.get("blueprint_cost", 0)) + int(quote.get("copy_cost", 0))
	)
	if not quote.ok:
		buy.tooltip_text = quote.error


static func placement(layout: Dictionary, copy: String) -> Dictionary:
	for kit: Dictionary in layout.get("outfield_plaza", []):
		if kit.copy == copy:
			return {"site": "OUTFIELD-PLAZA", "recipe": kit.recipe, "kit": true}
		for child: Dictionary in kit.occupants:
			if child.copy == copy:
				return {"site": child.site, "recipe": kit.recipe, "kit": false}
	return {}


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
	var installed: Dictionary = placement(draft, copy)
	if not installed.is_empty() and not installed.kit:
		SeasonPages.wrapped(
			panel,
			(
				"Installed in "
				+ installed.recipe.replace("_", " ").capitalize()
				+ " / "
				+ installed.site
				+ ". Store before returning to another site."
			)
		)
		var store: Button = menu._button(
			panel,
			"STORE THIS PLAZA OCCUPANT",
			func() -> void:
				if editable:
					EditorAccess.editor_preview(menu, StadiumOutfieldPlazaItems.store_copy(draft, copy), revision, preview)
		)
		store.disabled = not editable
		return
	var names: Array[String] = ["Stored", "Promenade Court", "Garden Plaza", "Heritage Walk"]
	var recipes: Array[String] = StadiumOutfieldPlazaRecipes.CURRENT_RECIPES.duplicate()
	recipes.append("heritage_walk")
	names.append("Heritage Walk (original revision)")
	var selected: int = 0 if installed.is_empty() else recipes.find(installed.recipe) + 1
	var choice: OptionButton = StadiumEditorUI._options(panel, names, selected)
	choice.set_meta("stadium_copy", copy)
	choice.disabled = not editable
	for index in range(names.size()):
		if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
			continue
		var candidate: Dictionary = (
			StadiumOutfieldPlazaItems.store_copy(draft, copy)
			if index == 0
			else StadiumOutfieldPlazaItems.place(
				draft, stock, copy, recipes[index - 1], ledger.surface_owned()
			)
		)
		var checked: Dictionary = StadiumHomeLayout.validate(candidate, stock, ledger.view().land)
		var changed: bool = not ClubCareer.same(candidate, draft)
		choice.set_item_disabled(index, not checked.ok or not changed)
		if not checked.ok or not changed:
			(
				choice
				. set_item_tooltip(
					index,
					(
						checked.error
						if not checked.ok
						else "Store optional occupants first, then Store the kit before changing recipe."
					)
				)
			)
	choice.item_selected.connect(
		func(index: int) -> void:
			if choice.disabled or index < 0 or index >= names.size() or choice.is_item_disabled(index) or index == selected:
				return
			var candidate: Dictionary = (
				StadiumOutfieldPlazaItems.store_copy(draft, copy)
				if index == 0
				else StadiumOutfieldPlazaItems.place(
					draft, stock, copy, recipes[index - 1], ledger.surface_owned()
				)
			)
			EditorAccess.editor_preview(menu, candidate, revision, preview)
	)
	if installed.is_empty():
		return
	var kit: Dictionary = draft.outfield_plaza[0]
	var recipe: Dictionary = StadiumOutfieldPlazaRecipes.definition(kit.recipe)
	for site: String in recipe.sites:
		SeasonPages.wrapped(panel, site + " · optional exact owned copy")
		var occupied: String = ""
		for child: Dictionary in kit.occupants:
			if child.site == site:
				occupied = child.copy
		if not occupied.is_empty():
			SeasonPages.wrapped(
				panel, StadiumCatalog.item(stock.copies[occupied].item).name + " · " + occupied
			)
			var store: Button = menu._button(
				panel, "STORE " + site, _store.bind(menu, draft, occupied, revision, preview, editable)
			)
			store.disabled = not editable
			continue
		var copies: Array[String] = [""]
		var labels: Array[String] = ["Empty (nothing included)"]
		for candidate_copy: String in stock.copies:
			if recipe.sites[site].items.has(stock.copies[candidate_copy].item):
				var proposal: Dictionary = StadiumOutfieldPlazaItems.place_occupant(
					draft, candidate_copy, site
				)
				if StadiumHomeLayout.validate(proposal, stock, ledger.view().land).ok:
					copies.append(candidate_copy)
					labels.append(
						(
							StadiumCatalog.item(stock.copies[candidate_copy].item).name
							+ " · "
							+ candidate_copy
						)
					)
		var picker: OptionButton = StadiumEditorUI._options(panel, labels, 0)
		picker.disabled = not editable or copies.size() == 1
		picker.item_selected.connect(_select.bind(menu, draft, copies, site, revision, picker, preview))


static func _store(menu: SeasonMenu, draft: Dictionary, copy: String, revision: int,
	preview: Callable = Callable(), enabled: bool = true) -> void:
	if enabled:
		EditorAccess.editor_preview(menu, StadiumOutfieldPlazaItems.store_copy(draft, copy), revision, preview)


static func _select(index: int, menu: SeasonMenu, draft: Dictionary, copies: Array[String],
	site: String, revision: int, picker: OptionButton = null, preview: Callable = Callable()) -> void:
	if picker != null and (not is_instance_valid(picker) or picker.disabled):
		return
	if index > 0 and index < copies.size():
		EditorAccess.editor_preview(menu,
			StadiumOutfieldPlazaItems.place_occupant(draft, copies[index], site), revision, preview)

class_name StadiumAdvancedWallUI
extends RefCounted
## Complete advanced-back proposals, independent height blueprints and exact missing-copy quotes.

const SHAPE_NAMES: Dictionary = {"left_loft": "Right-field loft",
	"right_shelf": "Left-field shelf", "offset_gables": "Offset gables"}


static func requirements(shape: String, material: String) -> Dictionary:
	if shape == "offset_gables":
		var rows: Array[Dictionary] = StadiumOffsetWallRecipes.back(material)
		return {} if rows.is_empty() else {"standard": rows.size(), "low": 0, "tall": 0}
	return StadiumHeightWallRecipes.requirements(shape, material)


static func propose(draft: Dictionary, stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership, access: Array[String], tier: String,
	shape: String, material: String) -> Dictionary:
	if stock == null or pieces == null or pieces.stock == null or boards == null:
		return StadiumStarterLayout._error("Reload complete ownership before choosing an advanced back.")
	var next: Dictionary = StadiumScoreboardUI.upgrade(draft, access)
	if next.is_empty():
		return StadiumStarterLayout._error("This field cannot use an advanced back-wall selection.")
	if shape.is_empty():
		if not material.is_empty():
			return StadiumStarterLayout._error("An empty back has no material selection.")
		next.advanced_back = StadiumAdvancedWallManifest.empty()
	else:
		var suggested: Dictionary = StadiumAdvancedWallManifest.suggest(
			shape, material, stock, pieces.stock)
		if not suggested.ok:
			return suggested
		next.advanced_back = suggested.manifest
		next.walls.back = {}
	return StadiumScoreboardUI.checked_proposal(draft, next, stock, pieces, boards, access, tier)


static func propose_ordinary(draft: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String], tier: String, item: String, shape: String = "straight") -> Dictionary:
	if stock == null or pieces == null or boards == null:
		return StadiumStarterLayout._error("Reload complete ownership before choosing an ordinary back.")
	var next: Dictionary = StadiumScoreboardUI.upgrade(draft, access)
	if next.is_empty():
		return StadiumStarterLayout._error("This field cannot use an ordinary back-wall selection.")
	var proposed: Dictionary = StadiumWallLayout.propose(next.walls, stock, "back", item, shape)
	if not proposed.ok:
		return proposed
	next.walls = proposed.walls
	next.advanced_back = StadiumAdvancedWallManifest.empty()
	return StadiumScoreboardUI.checked_proposal(draft, next, stock, pieces, boards, access, tier)


static func quote(ledger: ClubAssetLedger, item: String, quantity: int,
	progress: Dictionary, revision: int = -1) -> Dictionary:
	if ledger == null:
		return StadiumStarterLayout._error("Reload the club before purchasing wall pieces.")
	var bound_revision: int = ledger.revision() if revision == -1 else revision
	var stock: StadiumStock = ledger.construction()
	var pieces: StadiumWallPieceOwnership = ledger.wall_pieces()
	var boards: StadiumScoreboardOwnership = ledger.scoreboards()
	var result: Dictionary = StadiumStarterLayout._error("Unknown wall material or height variant.")
	if StadiumWallRecipes.BACK_IDS.has(item):
		result = StadiumWallItems.quote(stock, item, quantity,
			"stadium-wall-buy:%d" % bound_revision, progress)
	elif not StadiumWallPieceCatalog.item(item).is_empty():
		result = pieces.quote(item, quantity, "stadium-wall-piece:%d" % bound_revision,
			progress, stock.copies.size() + boards.copies.size())
	result = {"ok": result.ok, "error": result.error, "cost": result.get("cost", 0),
		"blueprint_cost": result.get("blueprint_cost", 0)}
	result["item"] = item
	result["quantity"] = quantity
	result["revision"] = bound_revision
	if bound_revision != ledger.revision():
		result.ok = false
		result.error = "Club data changed. Reload before purchasing."
	elif stock.copies.size() + pieces.stock.copies.size() + boards.copies.size() \
		+ quantity > StadiumStock.MAX_COPIES:
		result.ok = false
		result.error = "Combined construction capacity reached."
	return result


static func missing(ledger: ClubAssetLedger, shape: String, material: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var needed: Dictionary = requirements(shape, material)
	var stock: StadiumStock = ledger.construction()
	var pieces: StadiumWallPieceOwnership = ledger.wall_pieces()
	for height: String in ["standard", "low", "tall"]:
		var required: int = int(needed.get(height, 0))
		if required == 0:
			continue
		var item: String = material if height == "standard" \
			else StadiumWallPieceCatalog.identity(material, height)
		var owned: int = 0
		var inventory: Dictionary = stock.copies if height == "standard" else pieces.stock.copies
		for copy: Dictionary in inventory.values():
			if copy.item == item:
				owned += 1
		var blueprint: int = 0
		if height == "standard" and not stock.blueprints.has(item):
			blueprint = StadiumWallItems.PRICES[item][0]
		elif height != "standard" and not pieces.blueprints.has(item):
			blueprint = StadiumWallPieceOwnership.BLUEPRINT_PRICES[material]
		var price: int = StadiumWallItems.PRICES[item][1] if height == "standard" \
			else int(StadiumWallPieceCatalog.item(item).copy_price)
		rows.append({"item": item, "height": height, "required": required, "owned": owned,
			"missing": maxi(0, required - owned), "blueprint_cost": blueprint, "copy_price": price})
	return rows


static func show(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, editable: bool, buyable: bool) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "ADVANCED OUTFIELD WALL", 22)
	SeasonPages.wrapped(panel, "Choose a complete shape and material. This replaces only the back "
		+ "wall; side walls and surface choices stay in place. Standard, low and tall copies have "
		+ "independent blueprints. Short end panels still use a full owned copy.")
	SeasonPages.wrapped(panel, "Advanced fields are daylight-only. If a wall hides an old manual "
		+ "board, explicitly choose Stored or a compatible primary replacement first.")
	var enabled: bool = editable and revision == ledger.revision()
	_choices(menu, panel, ledger, draft, revision, enabled)
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		for material: String in StadiumWallRecipes.BACK_IDS:
			_recipe(menu, panel, ledger, shape, material, progress, revision, enabled and buyable)


static func _choices(menu: SeasonMenu, panel: VBoxContainer, ledger: ClubAssetLedger,
	draft: Dictionary, revision: int, enabled: bool) -> void:
	var options: Array[Dictionary] = [{"shape": "", "material": ""}]
	var labels: Array[String] = ["No advanced back • keep ordinary wall choice"]
	var current: Dictionary = draft.get("advanced_back", StadiumAdvancedWallManifest.empty())
	var selected: int = 0
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		for material: String in StadiumWallRecipes.BACK_IDS:
			if current.shape == shape and current.material == material:
				selected = labels.size()
			labels.append(SHAPE_NAMES[shape] + " • " + StadiumWallItemsUI.SHORT_NAMES[material])
			options.append({"shape": shape, "material": material})
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	choice.set_meta("advanced_wall_choice", "back")
	choice.fit_to_longest_item = false
	choice.clip_text = true
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.disabled = not enabled
	for index in range(options.size()):
		var proposed: Dictionary = propose(draft, ledger.construction(), ledger.wall_pieces(),
			ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
			options[index].shape, options[index].material)
		choice.set_item_disabled(index, not proposed.ok)
		choice.set_item_tooltip(index, labels[index] if proposed.ok else proposed.error)
	choice.item_selected.connect(func(index: int) -> void:
		if index == selected:
			return
		var proposed: Dictionary = propose(draft, ledger.construction(), ledger.wall_pieces(),
			ledger.scoreboards(), ledger.surface_owned(), ledger.view().land,
			options[index].shape, options[index].material)
		menu.app.notice = "" if proposed.ok else proposed.error
		StadiumEditorUI.show(menu, proposed.layout if proposed.ok else draft, revision)
		_focus.call_deferred(menu))


static func _recipe(menu: SeasonMenu, panel: VBoxContainer, ledger: ClubAssetLedger,
	shape: String, material: String, progress: Dictionary, revision: int, enabled: bool) -> void:
	menu._label(panel, SHAPE_NAMES[shape] + " • " + StadiumWallItemsUI.SHORT_NAMES[material], 18)
	var required: Dictionary = requirements(shape, material)
	SeasonPages.wrapped(panel,
		"Complete set: %d standard (3.25m), %d low (1.625m), %d tall (4.875m)." % [
		required.standard, required.low, required.tall])
	var entry: Dictionary = StadiumCatalog.item(material)
	SeasonPages.wrapped(panel, "Requires %d completed seasons • %d regular-season wins." % [
		entry.requires.get("seasons", 0), entry.requires.get("wins", 0)])
	for row: Dictionary in missing(ledger, shape, material):
		var name_value: String = StadiumCatalog.item(row.item).name if row.height == "standard" \
			else StadiumWallPieceCatalog.item(row.item).name
		SeasonPages.wrapped(panel, "%s • %d required • %d owned • %d CB per copy • %s" % [name_value,
			row.required, row.owned, row.copy_price, "Blueprint owned" if row.blueprint_cost == 0 \
			else "Independent blueprint %d CB" % row.blueprint_cost])
		var cost: int = 0 if row.missing == 0 else row.blueprint_cost + row.missing * row.copy_price
		var quoted: Dictionary = quote(ledger, row.item, maxi(1, row.missing), progress, revision)
		var label: String = "COMPLETE %s SET OWNED" % row.height.to_upper() if row.missing == 0 \
			else "BUY %d MISSING %s • %d CB" % [row.missing, row.height.to_upper(), cost]
		var buy: Button = menu._button(panel, label, _buy.bind(menu, quoted.duplicate(true)))
		buy.set_meta("advanced_wall_buy", shape + ":" + row.item)
		buy.disabled = row.missing == 0 or not StadiumScoreboardUI.purchase_ready(
			ledger, quoted, enabled)
		if not quoted.ok:
			buy.tooltip_text = quoted.error


static func _buy(menu: SeasonMenu, quoted: Dictionary) -> void:
	if not quoted.get("ok", false):
		return
	var name_value: String = StadiumCatalog.item(quoted.item).name \
		if StadiumWallRecipes.BACK_IDS.has(quoted.item) \
		else StadiumWallPieceCatalog.item(quoted.item).name
	menu.app._confirm("Buy %d %s for %d Club Bucks? " % [quoted.quantity, name_value, quoted.cost]
		+ "Includes only this exact blueprint if unowned. Pieces go into storage. "
		+ "Choose a complete wall, save, then apply.", _complete_buy.bind(menu, quoted.duplicate(true)))


static func _complete_buy(menu: SeasonMenu, quoted: Dictionary) -> void:
	var result: Dictionary = ClubConstruction.buy_walls(menu.app.season,
		quoted.item, quoted.quantity, quoted.revision) if StadiumWallRecipes.BACK_IDS.has(quoted.item) \
		else ClubConstruction.buy_wall_pieces(menu.app.season,
			quoted.item, quoted.quantity, quoted.revision)
	menu.app.notice = "Wall pieces purchased and stored. Choose a complete run, save, then apply." \
		if result.ok else result.error
	StadiumEditorUI.show(menu)


static func _focus(menu: SeasonMenu) -> void:
	if menu.page != "stadium":
		return
	for choice: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if choice.has_meta("advanced_wall_choice"):
			choice.grab_focus()
			return

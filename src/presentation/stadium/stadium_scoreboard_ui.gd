class_name StadiumScoreboardUI
extends RefCounted
## Intentional primary selection. Rendering never rewrites historical or comparison layouts.

const SITE_NAMES: Dictionary = {"BOARD-LEFT-v2": "Right-field perimeter",
	"BOARD-RIGHT-v2": "Left-field perimeter", "BOARD-LARGE-v2": "Left-field video perimeter",
	"BOARD-CENTER-v1": "Raised center field"}


static func upgrade(draft: Dictionary, access: Array[String]) -> Dictionary:
	var next: Dictionary = draft.duplicate(true)
	if SeasonOwnership._whole(next.get("version"), 1, 12):
		next = StadiumSurfaceLayout.upgrade(next, access, access.has("grass"))
	if SeasonOwnership._whole(next.get("version"), 12, 12):
		next = StadiumAdvancedWallLayout.upgrade(next)
	if SeasonOwnership._whole(next.get("version"), 13, 13):
		next = StadiumScoreboardLayout.upgrade(next)
	return next if SeasonOwnership._whole(next.get("version"), 14, 15) else {}


static func propose(draft: Dictionary, stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership, access: Array[String], tier: String,
	copy: String = "", site: String = "") -> Dictionary:
	if stock == null or pieces == null or boards == null:
		return StadiumStarterLayout._error("Reload complete construction ownership before selecting.")
	var next: Dictionary = upgrade(draft, access)
	if next.is_empty():
		return StadiumStarterLayout._error("This field cannot use the primary scoreboard selector.")
	var item: String = item_for(copy, stock, boards)
	if (not copy.is_empty() and item.is_empty()) or (copy.is_empty() and not site.is_empty()):
		return StadiumStarterLayout._error("Select an exact owned board copy and compatible site.")
	next.scoreboards = []
	next.displays = next.displays.filter(func(row: Dictionary) -> bool:
		return not stock.copies.has(row.copy) or stock.copies[row.copy].item != "ST-039")
	var center: bool = site == StadiumScoreboardMountCatalog.CENTER_SITE
	if center and (item != "ST-090" or not StadiumMountedScoreboardLayout.RUNTIME_READY):
		return StadiumStarterLayout._error("Raised center requires an owned electronic board "
			+ "and verified mounted-field integration.")
	if center and next.version == 14:
		next = StadiumMountedScoreboardLayout.upgrade(next, stock, pieces, access, tier, boards)
		if next.is_empty():
			return StadiumStarterLayout._error("This complete field cannot use the raised center mount.")
	if not copy.is_empty():
		var row: Dictionary = {"copy": copy, "item": item,
			"model": StadiumScoreboardModels.MODELS[item], "site": site}
		if next.version == 15:
			row["mount_profile"] = StadiumScoreboardMountCatalog.CENTER_PROFILE if center else ""
		next.scoreboards.append(row)
	return checked_proposal(draft, next, stock, pieces, boards, access, tier)


static func checked_proposal(before: Dictionary, after: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String], tier: String) -> Dictionary:
	var preview: Dictionary = StadiumOwnedLayout.preview(
		before, after, stock, pieces, access, tier, boards)
	return {"ok": true, "error": "", "layout": after.duplicate(true), "preview": preview} \
		if preview.ok else preview


static func item_for(copy: String, stock: StadiumStock,
	boards: StadiumScoreboardOwnership) -> String:
	if stock != null and stock.copies.has(copy):
		var item: String = stock.copies[copy].item
		return item if item in ["ST-039", "ST-040"] else ""
	return "ST-090" if boards != null and boards.copies.has(copy) else ""


static func available_sites(draft: Dictionary, stock: StadiumStock,
	pieces: StadiumWallPieceOwnership, boards: StadiumScoreboardOwnership,
	access: Array[String], tier: String, copy: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var item: String = item_for(copy, stock, boards)
	for site: String in StadiumScoreboardSites.SITES:
		if not StadiumScoreboardSites.SITES[site].items.has(item):
			continue
		var result: Dictionary = propose(draft, stock, pieces, boards, access, tier, copy, site)
		rows.append({"site": site, "label": SITE_NAMES[site],
			"ok": result.ok, "error": result.error})
	if item == "ST-090" and StadiumMountedScoreboardLayout.RUNTIME_READY:
		var center_site: String = StadiumScoreboardMountCatalog.CENTER_SITE
		var center: Dictionary = propose(draft, stock, pieces, boards, access, tier, copy, center_site)
		rows.append({"site": center_site, "label": SITE_NAMES[center_site],
			"ok": center.ok, "error": center.error})
	return rows


static func quote(ledger: ClubAssetLedger, item: String, quantity: int,
	progress: Dictionary, revision: int = -1, legacy_manual: bool = false) -> Dictionary:
	if ledger == null:
		return StadiumStarterLayout._error("Reload the club before purchasing a board.")
	var bound_revision: int = ledger.revision() if revision == -1 else revision
	var result: Dictionary = StadiumScoreboardPurchases.quote(ledger.construction(),
		ledger.wall_pieces(), ledger.scoreboards(), item, quantity,
		"stadium-scoreboard:%d" % bound_revision, progress)
	if result.ok and legacy_manual and item == "ST-039" and quantity == 1:
		result = StadiumPurchases.quote(ledger.construction(), item, quantity,
			"stadium-buy:%d" % bound_revision, StadiumPurchases.DISPLAY_VERSION, progress)
	result = {"ok": result.ok, "error": result.error, "cost": result.get("cost", 0),
		"blueprint_cost": result.get("blueprint_cost", 0), "copy_cost": result.get("copy_cost", 0)}
	result["legacy_manual"] = legacy_manual and item == "ST-039" and quantity == 1
	result["item"] = item
	result["quantity"] = quantity
	result["revision"] = bound_revision
	if bound_revision != ledger.revision():
		result.ok = false
		result.error = "Club data changed. Reload before purchasing."
	return result


static func purchase_ready(ledger: ClubAssetLedger, quoted: Dictionary, enabled: bool) -> bool:
	return enabled and ledger != null and quoted.get("ok", false) \
		and quoted.get("revision", -1) == ledger.revision() \
		and ledger.balance() >= int(quoted.get("cost", 0))


static func show(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, editable: bool, buyable: bool, on_preview: Callable = Callable()) -> void:
	var panel: VBoxContainer = SeasonPlayerCard.panel(menu._body)
	menu._label(panel, "PRIMARY SCOREBOARD", 22)
	SeasonPages.wrapped(panel, "Choose one owned copy and a compatible position, or Stored. "
		+ "Replacing a board stores the previous copies for free, including an old manual display. "
		+ "Club signs stay in place. Save and apply to use your selection.")
	SeasonPages.wrapped(panel, "New primary-board layouts are daylight-only. " + (
		"An owned electronic copy can use the raised center mount at no extra cost."
		if StadiumMountedScoreboardLayout.RUNTIME_READY else
		"Mounted positions are not yet available."))
	var enabled: bool = editable and revision == ledger.revision()
	_primary(menu, panel, ledger, draft, revision, enabled, on_preview)
	if on_preview.is_valid():
		SeasonPages.wrapped(panel, "Buy stored copies through Shared Field Upgrades. Current and paused fields stay unchanged.")
		return
	var rows: Array = StadiumCareerProgress.capture(menu.app.season.career)
	var progress: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	SeasonPages.wrapped(panel, "Closed career: %d seasons • %d regular-season wins. " % [
		progress.seasons, progress.wins] + "Purchases store copies; they do not change your field.")
	for item: String in StadiumScoreboardCatalog.IDS:
		_purchase_card(menu, panel, ledger, item, progress, revision, enabled and buyable,
			SeasonOwnership._whole(draft.get("version"), 1, 12))


static func _primary(menu: SeasonMenu, panel: VBoxContainer, ledger: ClubAssetLedger,
	draft: Dictionary, revision: int, enabled: bool, on_preview: Callable = Callable()) -> void:
	var stock: StadiumStock = ledger.construction()
	var boards: StadiumScoreboardOwnership = ledger.scoreboards()
	var copies: Array[String] = []
	for copy: String in stock.copies:
		if stock.copies[copy].item in ["ST-039", "ST-040"]:
			copies.append(copy)
	copies.append_array(boards.copies.keys())
	copies.sort()
	var labels: Array[String] = ["Stored"]
	var options: Array[Dictionary] = [{"copy": "", "site": "", "ok": true, "error": ""}]
	var current: Array = draft.get("scoreboards", [])
	var legacy: bool = _has_legacy(draft, stock)
	var retained: bool = legacy or current.size() > 1
	var selected: int = 0
	for copy: String in copies:
		var item: String = item_for(copy, stock, boards)
		labels.append("%s • %s" % [StadiumScoreboardCatalog.item(item).name, copy])
		options.append(_first_site(ledger, draft, copy))
		if not retained and current.size() == 1 and current[0].copy == copy:
			selected = options.size() - 1
	if retained:
		selected = labels.size()
		labels.append("Current layout retained • choose a primary or Stored")
		options.append({"copy": "", "site": "", "ok": false, "error": ""})
		SeasonPages.wrapped(panel, "Your existing board placements are preserved until you choose. "
			+ "A primary selection replaces all current boards; unused copies remain owned.")
	var stored: Dictionary = propose(draft, stock, ledger.wall_pieces(), boards,
		ledger.surface_owned(), ledger.view().land)
	options[0].ok = stored.ok
	options[0].error = stored.error
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	_style_choice(choice, "primary", enabled)
	for index in range(options.size()):
		choice.set_item_disabled(index, not options[index].ok)
		choice.set_item_tooltip(index, options[index].error if not options[index].ok else labels[index])
	choice.item_selected.connect(func(index: int) -> void:
		if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= options.size():
			return
		if index == selected or not options[index].ok:
			return
		_select(menu, ledger, draft, revision, options[index].copy, options[index].site, on_preview))
	if not retained and current.size() == 1:
		_sites(menu, panel, ledger, draft, revision, current[0], enabled, on_preview)


static func _first_site(ledger: ClubAssetLedger, draft: Dictionary, copy: String) -> Dictionary:
	var sites: Array[Dictionary] = available_sites(draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land, copy)
	var preferred: String = ""
	if draft.get("scoreboards", []).size() == 1:
		preferred = draft.scoreboards[0].site
	var result: Dictionary = {"copy": copy, "site": "", "ok": false,
		"error": "No compatible position fits this complete field and property."}
	for row: Dictionary in sites:
		if row.ok and (not result.ok or row.site == preferred):
			result.merge({"site": row.site, "ok": true, "error": ""}, true)
	return result


static func _sites(menu: SeasonMenu, panel: VBoxContainer, ledger: ClubAssetLedger,
	draft: Dictionary, revision: int, current: Dictionary, enabled: bool, on_preview: Callable = Callable()) -> void:
	var rows: Array[Dictionary] = available_sites(draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land, current.copy)
	var labels: Array[String] = []
	var selected: int = 0
	for row: Dictionary in rows:
		if row.site == current.site:
			selected = labels.size()
		labels.append(row.label)
	var choice: OptionButton = StadiumEditorUI._options(panel, labels, selected)
	_style_choice(choice, "site", enabled)
	for index in range(rows.size()):
		choice.set_item_disabled(index, not rows[index].ok)
		choice.set_item_tooltip(index, rows[index].error if not rows[index].ok else labels[index])
	choice.item_selected.connect(func(index: int) -> void:
		if not choice.is_inside_tree() or choice.disabled or index < 0 or index >= rows.size():
			return
		if index != selected and rows[index].ok:
			_select(menu, ledger, draft, revision, current.copy, rows[index].site, on_preview))


static func _style_choice(choice: OptionButton, key: String, enabled: bool) -> void:
	choice.set_meta("scoreboard_choice", key)
	choice.fit_to_longest_item = false
	choice.clip_text = true
	choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice.disabled = not enabled


static func _select(menu: SeasonMenu, ledger: ClubAssetLedger, draft: Dictionary,
	revision: int, copy: String, site: String, on_preview: Callable = Callable()) -> void:
	var result: Dictionary = propose(draft, ledger.construction(), ledger.wall_pieces(),
		ledger.scoreboards(), ledger.surface_owned(), ledger.view().land, copy, site)
	menu.app.notice = "" if result.ok else result.error
	if on_preview.is_valid():
		if result.ok:
			on_preview.call(result.layout, revision)
	else:
		StadiumEditorUI.show(menu, result.layout if result.ok else draft, revision)
		_focus.call_deferred(menu)


static func _purchase_card(menu: SeasonMenu, panel: VBoxContainer, ledger: ClubAssetLedger,
	item: String, progress: Dictionary, revision: int, enabled: bool, legacy: bool) -> void:
	var entry: Dictionary = StadiumScoreboardCatalog.item(item)
	var owned: bool = ledger.scoreboards().blueprints.has(item) if item == "ST-090" \
		else ledger.construction().blueprints.has(item)
	var blueprint: int = 0 if owned else int(entry.blueprint_price)
	var cost: int = blueprint + int(entry.copy_price)
	menu._label(panel, entry.name, 18)
	SeasonPages.wrapped(panel, "%d completed seasons • %d regular-season wins. " % [
		entry.requires.get("seasons", 0), entry.requires.get("wins", 0)]
		+ "%d blueprint + %d copy = %d CB" % [blueprint, entry.copy_price, cost])
	var quoted: Dictionary = quote(ledger, item, 1, progress, revision, legacy)
	var buy: Button = menu._button(panel, "BUY COPY • %d CB" % cost,
		_buy.bind(menu, quoted.duplicate(true)))
	buy.set_meta("scoreboard_buy", item)
	if quoted.legacy_manual:
		buy.set_meta("stadium_buy", item)
	buy.disabled = not purchase_ready(ledger, quoted, enabled)
	if not quoted.ok:
		buy.tooltip_text = quoted.error


static func _buy(menu: SeasonMenu, quoted: Dictionary) -> void:
	if not quoted.get("ok", false):
		return
	if quoted.get("legacy_manual", false):
		_complete_buy(menu, quoted)
		return
	menu.app._confirm("Buy %d %s for %d Club Bucks? " % [quoted.quantity,
		StadiumScoreboardCatalog.item(quoted.item).name, quoted.cost]
		+ "Includes any unowned blueprint. Copies go into storage. "
		+ "Choose a primary board, save, then apply.", _complete_buy.bind(menu, quoted.duplicate(true)))


static func _complete_buy(menu: SeasonMenu, quoted: Dictionary) -> void:
	var result: Dictionary = ClubConstruction.buy_copy(menu.app.season, quoted.item,
		quoted.revision) if quoted.get("legacy_manual", false) else ClubConstruction.buy_scoreboard(
			menu.app.season, quoted.item, quoted.quantity, quoted.revision)
	menu.app.notice = "Scoreboard purchased and stored. Choose a primary, save, then apply." \
		if result.ok else result.error
	StadiumEditorUI.show(menu)


static func _has_legacy(draft: Dictionary, stock: StadiumStock) -> bool:
	for row: Dictionary in draft.get("displays", []):
		if stock.copies.has(row.copy) and stock.copies[row.copy].item == "ST-039":
			return true
	return false


static func _focus(menu: SeasonMenu) -> void:
	if menu.page != "stadium":
		return
	for choice: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta("scoreboard_choice", "") == "primary":
			choice.grab_focus()
			return

extends Node
## Staged selector helpers and controls; production and real-season acceptance remain separate.

const ACCESS: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY
const PROGRESS: Dictionary = {"seasons": 22, "wins": 88}
var _failures: int = 0
var _ledger: ClubAssetLedger
var _stock: StadiumStock
var _pieces: StadiumWallPieceOwnership
var _boards: StadiumScoreboardOwnership


func _ready() -> void:
	_fund()
	_old_versions()
	_primary_selection()
	_advanced_selection()
	_preserve_controls()
	_rejections()
	_quotes()
	_render_controls()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro workshop selections passed: "
			+ "exact proposals, storage, quotes and disabled states.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund() -> void:
	_ledger = _new_ledger()
	for item: String in StadiumScoreboardCatalog.IDS:
		_check(_ledger.commit(_command(_ledger, item, 2)).ok, "fund exact scoreboard copies")
	for item: String in ["ST-024", "ST-065", "ST-077", "ST-078", "ST-022", "ST-023"]:
		_check(_ledger.commit(_command(_ledger, item, 27)).ok, "fund ordinary wall inventory")
	for item: String in StadiumWallPieceCatalog.DATA:
		_check(_ledger.commit(_command(_ledger, item, 12)).ok, "fund independent low/tall variants")
	for item: String in ["ST-041", "ST-080", "ST-027", "ST-028", "ST-025", "ST-026", "ST-037"]:
		_check(_ledger.commit(_command(_ledger, item, 4 if item == "ST-037" else 1)).ok,
			"fund remaining furniture")
	_stock = _ledger.construction()
	_pieces = _ledger.wall_pieces()
	_boards = _ledger.scoreboards()


func _new_ledger(credit: int = 100000) -> ClubAssetLedger:
	var credits: Array = []
	var progress: Array = []
	for index in range(22):
		credits.append(credit)
		progress.append({"seasons": 1, "wins": 4, "strikeouts": 2})
	return ClubAssetLedger.new(51, credits, progress)


func _command(ledger: ClubAssetLedger, item: String, quantity: int) -> Dictionary:
	var op: String = "stadium_buy"
	var price: int = StadiumWallItems.PRICE_VERSION
	if StadiumScoreboardCatalog.IDS.has(item):
		op = "stadium_scoreboard"
		price = StadiumScoreboardPurchases.VERSION
	elif StadiumWallPieceCatalog.DATA.has(item):
		op = "stadium_wall_piece"
		price = StadiumWallPieceOwnership.VERSION
	elif StadiumPurchases.DISPLAYS.has(item):
		price = StadiumPurchases.DISPLAY_VERSION
	elif StadiumPurchases.SEATING.has(item):
		price = StadiumPurchases.SEATING_VERSION
	elif StadiumPurchases.BLEACHERS.has(item):
		price = StadiumPurchases.BLEACHER_VERSION
	elif StadiumPurchases.NETS.has(item):
		price = StadiumPurchases.NET_VERSION
	elif StadiumPurchases.TARGETS.has(item):
		price = StadiumPurchases.TARGET_VERSION
	elif StadiumPurchases.LIGHTS.has(item):
		price = StadiumPurchases.LIGHT_VERSION
	return {"id": "selection-%d" % ledger.revision(), "rev": ledger.revision(),
		"op": op, "through": 22, "progress_through": 22,
		"price_version": price, "item": item, "quantity": quantity}


func _copy(item: String, index: int = 0) -> String:
	var source: Dictionary = _boards.copies if item == "ST-090" else _stock.copies
	var copies: Array[String] = []
	for copy: String in source:
		if source[copy].item == item:
			copies.append(copy)
	copies.sort()
	return copies[index]


func _base() -> Dictionary:
	return StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ACCESS, true)


func _propose(draft: Dictionary, item: String = "",
	site: String = "", index: int = 0) -> Dictionary:
	return StadiumScoreboardUI.propose(draft, _stock, _pieces, _boards, ACCESS, "mogul",
		"" if item.is_empty() else _copy(item, index), site)


func _advanced(draft: Dictionary, shape: String, material: String = "ST-024") -> Dictionary:
	return StadiumAdvancedWallUI.propose(draft, _stock, _pieces, _boards, ACCESS, "mogul",
		shape, material)


func _old_versions() -> void:
	var current: Dictionary = StadiumStarterLayout.empty()
	var helpers: Array[Callable] = [StadiumHomeLayout.upgrade, StadiumFieldStyles.upgrade,
		StadiumClubItems.upgrade, StadiumGroundStyles.upgrade, StadiumBleacherItems.upgrade,
		StadiumTargetItems.upgrade, StadiumNetItems.upgrade, StadiumLightItems.upgrade,
		StadiumInfieldStyles.upgrade, StadiumWallItems.upgrade]
	var old: Array[Dictionary] = [current]
	for helper: Callable in helpers:
		current = helper.call(current)
		old.append(current)
	old.append(StadiumSurfaceLayout.upgrade(current, ACCESS, true))
	for draft: Dictionary in old:
		var before: Dictionary = draft.duplicate(true)
		var selected: Dictionary = _propose(draft, "ST-039", "BOARD-RIGHT-v2")
		_check(selected.ok and selected.layout.version == 14
			and selected.layout.scoreboards.size() == 1 and selected.preview.cost == 0,
			"explicit legacy selection creates complete14: " + str(draft.version))
		_check(ClubCareer.same(draft, before), "legacy selection never mutates its input")
		if selected.ok:
			for key: String in draft:
				if key not in ["version", "family", "displays"]:
					_check(ClubCareer.same({"value": draft[key]}, {"value": selected.layout[key]}),
						"legacy controls preserved: " + key)
	var rough: Array[String] = []
	var dirt: Dictionary = StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), rough)
	var result: Dictionary = StadiumScoreboardUI.propose(dirt, _stock, _pieces, _boards,
		rough, "mogul", _copy("ST-039"), "BOARD-RIGHT-v2")
	_check(result.ok and result.layout.surface == dirt.surface,
		"rough-origin upgrade neither grants grass nor changes dirt selection")


func _primary_selection() -> void:
	var original: Dictionary = _base()
	var sign: Dictionary = {"copy": _copy("ST-041"), "site": "SIGN-GROUND-R"}
	original.displays = [{"copy": _copy("ST-039"), "site": "SCORE-SMALL"}, sign]
	var before: Dictionary = original.duplicate(true)
	var ownership: Dictionary = _inventory()
	var electronic: Dictionary = _propose(original, "ST-090", "BOARD-RIGHT-v2")
	_check(electronic.ok and electronic.layout.scoreboards == [_row("ST-090", "BOARD-RIGHT-v2")]
		and electronic.layout.displays == [sign] and electronic.preview.displaced == [_copy("ST-039")]
		and electronic.preview.stored.has(_copy("ST-039")),
		"primary replacement stores old manual display and preserves exact sign")
	if not electronic.ok:
		return
	var replacement: Dictionary = _propose(electronic.layout, "ST-090", "BOARD-LEFT-v2", 1)
	_check(replacement.ok and replacement.preview.scoreboards_stored.has(_copy("ST-090"))
		and replacement.preview.displaced == [_copy("ST-090")],
		"selecting a second electronic stores the original exact paid copy")
	var moved: Dictionary = _propose(original, "ST-039", "BOARD-RIGHT-v2")
	_check(moved.ok and moved.preview.displaced.is_empty()
		and moved.preview.moved == [_copy("ST-039")], "old manual explicitly reuses the exact paid copy")
	var stored: Dictionary = _propose(electronic.layout)
	_check(stored.ok and stored.layout.scoreboards.is_empty() and stored.layout.displays == [sign]
		and stored.preview.scoreboards_stored.size() == _boards.copies.size(),
		"Stored removes primary boards only and retains electronic ownership")
	var comparison: Dictionary = electronic.layout.duplicate(true)
	comparison.scoreboards = [_row("ST-040", "BOARD-LARGE-v2"), _row("ST-039", "BOARD-LEFT-v2"),
		_row("ST-090", "BOARD-RIGHT-v2")]
	_check(StadiumOwnedLayout.validate(comparison, _stock, _pieces, ACCESS, "mogul", _boards).ok,
		"global grammar still accepts the historical three-board comparison")
	var normalized: Dictionary = _propose(comparison, "ST-039", "BOARD-RIGHT-v2", 1)
	_check(normalized.ok and normalized.layout.scoreboards.size() == 1
		and normalized.preview.displaced.size() == 3 and comparison.scoreboards.size() == 3,
		"only explicit primary selection reduces comparison rows, storing every displaced copy")
	_check(ClubCareer.same(before, original) and ClubCareer.same(ownership, _inventory()),
		"all proposals preserve caller layouts and all three ownership records")
	_partition(normalized.preview.placement)


func _advanced_selection() -> void:
	var original: Dictionary = _base()
	original.walls = StadiumWallLayout.propose(original.walls, _stock, "left", "ST-022").walls
	original.walls = StadiumWallLayout.propose(original.walls, _stock, "right", "ST-023").walls
	original.walls = StadiumWallLayout.propose(original.walls, _stock, "back", "ST-024").walls
	original.surface.height = "long"
	var before: Dictionary = original.duplicate(true)
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		for material: String in StadiumWallRecipes.BACK_IDS:
			var result: Dictionary = _advanced(original, shape, material)
			_check(result.ok and result.layout.version == 14 and result.layout.walls.back.is_empty()
				and result.layout.advanced_back.shape == shape,
				"complete shape/material proposal replaces ordinary back: " + shape + "/" + material)
			if not result.ok:
				continue
			_check(result.layout.walls.left == original.walls.left
				and result.layout.walls.right == original.walls.right
				and result.layout.surface == original.surface, "back swap preserves sides and surface")
			var ordinary: Dictionary = StadiumAdvancedWallUI.propose_ordinary(result.layout,
				_stock, _pieces, _boards, ACCESS, "mogul", "ST-024", "deeper_center")
			_check(ordinary.ok and ordinary.layout.advanced_back == StadiumAdvancedWallManifest.empty()
				and ordinary.layout.walls.back.shape == "deeper_center"
				and ordinary.layout.walls.left == original.walls.left
				and ordinary.layout.surface == original.surface,
				"ordinary selection clears only advanced back and preserves complete14")
			_partition(ordinary.preview.placement)
			var template: Dictionary = StadiumAdvancedWallUI.propose_ordinary(result.layout,
				_stock, _pieces, _boards, ACCESS, "mogul", "")
			_check(template.ok and template.layout.walls.back.is_empty()
				and template.layout.advanced_back.shape.is_empty()
				and template.layout.walls.right == original.walls.right,
				"ordinary template choice explicitly clears either back only")
			var cleared: Dictionary = _advanced(result.layout, "", "")
			_check(cleared.ok and cleared.layout.advanced_back.shape.is_empty()
				and cleared.layout.walls.left == original.walls.left,
				"explicit advanced storage keeps side walls")
	_check(ClubCareer.same(original, before), "advanced proposals do not mutate the source")
	var legacy: Dictionary = _base()
	legacy.displays = [{"copy": _copy("ST-039"), "site": "SCORE-SMALL"}]
	var rejected: Dictionary = _advanced(legacy, "left_loft")
	_check(not rejected.ok and rejected.error.contains("explicitly store or replace")
		and legacy.displays.size() == 1, "obscured legacy board is not silently discarded")
	var storage: Dictionary = _propose(legacy)
	_check(storage.ok and _advanced(storage.layout, "left_loft").ok,
		"an explicit Stored action permits the formerly obscured advanced back")
	var board: Dictionary = _propose(legacy, "ST-090", "BOARD-RIGHT-v2")
	_check(board.ok and _advanced(board.layout, "left_loft").ok,
		"an explicit compatible primary replacement permits the advanced back")


func _preserve_controls() -> void:
	var proposed: Dictionary = _advanced(_base(), "right_shelf")
	if not proposed.ok:
		_check(false, "control preservation fixture is valid")
		return
	var original: Dictionary = proposed.layout
	var helpers: Array[Callable] = [StadiumHomeLayout.upgrade, StadiumFieldStyles.upgrade,
		StadiumClubItems.upgrade, StadiumGroundStyles.upgrade, StadiumBleacherItems.upgrade,
		StadiumTargetItems.upgrade, StadiumNetItems.upgrade, StadiumLightItems.upgrade,
		StadiumInfieldStyles.upgrade, StadiumWallItems.upgrade]
	for helper: Callable in helpers:
		_check(ClubCareer.same(original, helper.call(original)),
			"existing independent upgrade helpers preserve full14 without a rewrite")
	_check(ClubCareer.same(original, StadiumSurfaceLayout.upgrade(original, ACCESS, false)),
		"surface opt-in helper preserves existing14 surface choices")


func _rejections() -> void:
	var original: Dictionary = _base()
	for site: String in ["BOARD-RIGHT-v1", "BOARD-ELEVATED", "BOARD-LARGE-v2", ""]:
		_check(not _propose(original, "ST-039", site).ok, "unsupported manual site is not selectable")
	_check(not StadiumScoreboardUI.propose(original, _stock, _pieces, _boards, ACCESS,
		"backyard", _copy("ST-040"), "BOARD-LARGE-v2").ok,
		"video needs its actual complete property clearance")
	_check(not StadiumScoreboardUI.propose(original, _stock, _pieces, _boards, ACCESS,
		"mogul", "unowned", "BOARD-RIGHT-v2").ok, "unknown copy is never substituted")
	var loft: Dictionary = _advanced(original, "left_loft")
	_check(loft.ok and not _propose(loft.layout, "ST-039", "BOARD-LEFT-v2").ok,
		"full candidate validation includes wall visibility")
	var rows: Array[Dictionary] = StadiumScoreboardUI.available_sites(loft.layout, _stock,
		_pieces, _boards, ACCESS, "mogul", _copy("ST-090"))
	var expected_sites: Array[String] = ["BOARD-LEFT-v2", "BOARD-RIGHT-v2"]
	if StadiumMountedScoreboardLayout.RUNTIME_READY:
		expected_sites.append(StadiumScoreboardMountCatalog.CENTER_SITE)
	var actual_sites: Array[String] = []
	for row: Dictionary in rows:
		actual_sites.append(row.site)
	_check(actual_sites == expected_sites,
		"electronic choices are exactly the two freestanding sockets plus the admitted center")
	_check(rows.size() >= 2 and not rows[0].ok and not rows[0].error.is_empty()
		and rows[1].ok and rows[1].error.is_empty(),
		"the original obscured freestanding choice stays disabled with a reason; its peer stays usable")
	if StadiumMountedScoreboardLayout.RUNTIME_READY:
		_check(rows.size() == 3 and rows[2].ok and rows[2].error.is_empty(),
			"the raised electronic center clears the same complete loft field")
	var corrupt: StadiumScoreboardOwnership = StadiumScoreboardOwnership.from_data(_boards.to_data())
	corrupt.copies[_copy("ST-090")].paid = 0
	_check(not StadiumScoreboardUI.propose(original, _stock, _pieces, corrupt, ACCESS,
		"mogul", _copy("ST-039"), "BOARD-RIGHT-v2").ok,
		"a manual proposal still validates all electronic ownership, including stored copies")
	var bad: Dictionary = original.duplicate(true)
	bad.obstacles = [{"copy": _copy("ST-040"), "site": "O-L1", "yaw": 0}]
	_check(not _propose(bad, "ST-039", "BOARD-RIGHT-v2").ok,
		"candidate cannot bypass unrelated invalid furniture")
	var unavailable: Array[String] = []
	_check(not StadiumScoreboardUI.propose(original, _stock, _pieces, _boards, unavailable,
		"mogul", _copy("ST-039"), "BOARD-RIGHT-v2").ok, "unowned surface access fails closed")
	_check(StadiumScoreboardUI.SITE_NAMES["BOARD-LEFT-v2"].begins_with("Right-field")
		and StadiumAdvancedWallUI.SHAPE_NAMES.left_loft.begins_with("Right-field"),
		"player-facing handedness changes labels only")


func _quotes() -> void:
	var ledger: ClubAssetLedger = _new_ledger()
	var before: Dictionary = ledger.to_data()
	for item: String in StadiumScoreboardCatalog.IDS:
		var quoted: Dictionary = StadiumScoreboardUI.quote(ledger, item, 2, PROGRESS)
		var entry: Dictionary = StadiumScoreboardCatalog.item(item)
		_check(quoted.ok and quoted.cost == entry.blueprint_price + 2 * entry.copy_price
			and quoted.revision == 0 and quoted.quantity == 2, "exact scoreboard quote and revision")
		_check(StadiumScoreboardUI.purchase_ready(ledger, quoted, true)
			and not StadiumScoreboardUI.purchase_ready(ledger, quoted, false),
			"caller purchase lock is honored independently from quoting")
		_check(not StadiumScoreboardUI.quote(ledger, item, 1, {}, 0).ok,
			"closed career unlock requirements are enforced")
	var legacy: Dictionary = StadiumScoreboardUI.quote(ledger, "ST-039", 1, PROGRESS, 0, true)
	_check(legacy.ok and legacy.legacy_manual, "legacy manual uses its independent historic route")
	var need: Array[Dictionary] = StadiumAdvancedWallUI.missing(ledger, "left_loft", "ST-024")
	_check(need.size() == 2 and need[0].required == 13 and need[1].required == 12
		and need[0].missing == 13 and need[1].missing == 12, "loft needs 13 standard and 12 tall")
	need = StadiumAdvancedWallUI.missing(ledger, "right_shelf", "ST-024")
	_check(need[0].required == 19 and need[1].height == "low" and need[1].required == 7,
		"shelf needs 19 standard and 7 low")
	_check(StadiumAdvancedWallUI.requirements("offset_gables", "ST-024").standard == 27,
		"offset requirement comes from all 27 authored sockets")
	var tall: Dictionary = StadiumAdvancedWallUI.quote(ledger, "ST-024-T", 12, PROGRESS)
	_check(tall.ok and tall.cost == 360 + 12 * 45 and tall.blueprint_cost == 360,
		"independent tall blueprint is included in exact missing quote")
	var stale: Dictionary = tall.duplicate(true)
	_check(ClubCareer.same(before, ledger.to_data()),
		"quotes and missing-set reads never debit or grant")
	_check(ledger.commit(_command(ledger, "ST-024", 13)).ok, "buy standard blueprint independently")
	tall = StadiumAdvancedWallUI.quote(ledger, "ST-024-T", 12, PROGRESS)
	_check(tall.ok and tall.blueprint_cost == 360, "standard blueprint does not unlock tall variant")
	_check(not StadiumScoreboardUI.purchase_ready(ledger, stale, true)
		and not StadiumAdvancedWallUI.quote(ledger, "ST-024-T", 12, PROGRESS, 0).ok,
		"stale confirmation stays bound to original revision")
	_check(ledger.commit(_command(ledger, "ST-024-T", 12)).ok, "buy exact tall copies")
	tall = StadiumAdvancedWallUI.quote(ledger, "ST-024-T", 1, PROGRESS)
	var low: Dictionary = StadiumAdvancedWallUI.quote(ledger, "ST-024-L", 7, PROGRESS)
	_check(tall.ok and tall.cost == 45 and low.ok and low.blueprint_cost == 360,
		"tall blueprint repeats once, without unlocking the low blueprint")
	var poor: ClubAssetLedger = _new_ledger(1)
	var priced: Dictionary = StadiumScoreboardUI.quote(poor, "ST-090", 1, PROGRESS)
	_check(priced.ok and not StadiumScoreboardUI.purchase_ready(poor, priced, true),
		"insufficient balance disables an otherwise qualified quote")


func _render_controls() -> void:
	var app: SeasonApp = SeasonApp.new()
	app.season = SeasonState.new()
	app.season.career = ClubCareer.new()
	var menu: SeasonMenu = SeasonMenu.new()
	menu.app = app
	menu._body = VBoxContainer.new()
	menu.add_child(menu._body)
	add_child(menu)
	app._dialog = ConfirmationDialog.new()
	menu.add_child(app._dialog)
	var original: Dictionary = _base()
	original.displays = [{"copy": _copy("ST-039"), "site": "SCORE-SMALL"}]
	var before: Dictionary = original.duplicate(true)
	StadiumScoreboardUI.show(menu, _ledger, original, _ledger.revision(), true, false)
	StadiumAdvancedWallUI.show(menu, _ledger, original, _ledger.revision(), true, false)
	_check(ClubCareer.same(original, before), "rendering legacy controls never upgrades or stores")
	var primary: OptionButton = _choice(menu, "scoreboard_choice", "primary")
	_check(primary != null and not primary.disabled
		and primary.get_item_text(primary.selected).contains("Current layout retained"),
		"legacy state has an honest retained selection rather than silently showing Stored")
	_check(_all_buys_disabled(menu), "dirty draft disables purchases while selection stays editable")
	_clear(menu)
	var complete: Dictionary = _propose(_base(), "ST-039", "BOARD-RIGHT-v2").layout
	StadiumScoreboardUI.show(menu, _ledger, complete, _ledger.revision() - 1, true, true)
	StadiumAdvancedWallUI.show(menu, _ledger, complete, _ledger.revision() - 1, true, true)
	_check(_all_choices_disabled(menu) and _all_buys_disabled(menu),
		"stale revision disables every new selection and purchase control")
	_clear(menu)
	StadiumScoreboardUI.show(menu, _ledger, complete, _ledger.revision(), false, true)
	StadiumAdvancedWallUI.show(menu, _ledger, complete, _ledger.revision(), false, true)
	_check(_all_choices_disabled(menu) and _all_buys_disabled(menu),
		"locked caller state is honored even with buyable true")
	_clear(menu)
	StadiumScoreboardUI.show(menu, _ledger, complete, _ledger.revision(), true, true)
	StadiumAdvancedWallUI.show(menu, _ledger, complete, _ledger.revision(), true, true)
	_check(not _choice(menu, "scoreboard_choice", "site").disabled,
		"passed editing permission opens staged site controls without changing readiness")
	_check(_all_buys_disabled(menu), "unqualified closed career disables purchases despite flags")
	_check(_has_text(menu, "Electronic club scoreboard") and _has_text(menu, "Tall painted plywood")
		and _has_text(menu, "13 standard") and _has_text(menu, "19 standard")
		and _has_text(menu, "27 standard"), "extension names and full material requirements render")
	_confirmation(app)
	_clear(menu)
	_legacy_capacity(menu)
	menu.free()
	app.free()


func _legacy_capacity(menu: SeasonMenu) -> void:
	var ledger: ClubAssetLedger = _new_ledger()
	_check(ledger.commit(_command(ledger, "ST-090", 1)).ok,
		"capacity fixture includes electronic ownership")
	_check(ledger.commit(_command(ledger, "ST-024-L", 1)).ok,
		"capacity fixture includes independent piece ownership")
	var fill: Dictionary = _command(ledger, "ST-001", StadiumStock.MAX_COPIES - 5)
	fill.price_version = StadiumPurchases.VERSION
	fill.erase("progress_through")
	_check(ledger.commit(fill).ok, "all three inventories reach the shared physical-copy limit")
	var before: Dictionary = ledger.to_data()
	var standard: Dictionary = StadiumPurchases.quote(ledger.construction(), "ST-039", 1,
		"legacy-capacity-check", StadiumPurchases.DISPLAY_VERSION, PROGRESS)
	_check(standard.ok and ledger.construction().copies.size() == StadiumStock.MAX_COPIES - 2,
		"standard-only legacy quote would fit while combined ownership is full")
	var quoted: Dictionary = StadiumScoreboardUI.quote(ledger, "ST-039", 1,
		PROGRESS, ledger.revision(), true)
	_check(not quoted.ok and quoted.legacy_manual and quoted.error.contains("capacity")
		and not StadiumScoreboardUI.purchase_ready(ledger, quoted, true),
		"legacy manual quote preserves full-context capacity failure")
	StadiumScoreboardUI._purchase_card(menu, menu._body, ledger, "ST-039", PROGRESS,
		ledger.revision(), true, true)
	var found: bool = false
	for buy: Button in menu._body.find_children("*", "Button", true, false):
		if buy.get_meta("stadium_buy", "") == "ST-039":
			found = true
			_check(buy.disabled and buy.tooltip_text.contains("capacity"),
				"actual legacy manual Buy button is disabled by the shared capacity limit")
	_check(found and ClubCareer.same(before, ledger.to_data()),
		"legacy capacity card retains original route metadata without changing ownership")


func _confirmation(app: SeasonApp) -> void:
	var quoted: Dictionary = StadiumScoreboardUI.quote(_ledger, "ST-090", 2, PROGRESS)
	var revision: int = quoted.revision
	var menu: SeasonMenu = app._dialog.get_parent() as SeasonMenu
	StadiumScoreboardUI._buy(menu, quoted)
	quoted.revision += 9
	var arguments: Array = app._confirmed_action.get_bound_arguments()
	_check(app._dialog.dialog_text.contains("320 Club Bucks")
		and arguments[1].revision == revision and arguments[1].quantity == 2,
		"scoreboard confirmation snapshots exact original cost, quantity and revision")
	app._dialog.hide()
	quoted = StadiumAdvancedWallUI.quote(_ledger, "ST-024-T", 2, PROGRESS)
	StadiumAdvancedWallUI._buy(menu, quoted)
	quoted.revision += 10
	arguments = app._confirmed_action.get_bound_arguments()
	_check(app._dialog.dialog_text.contains("90 Club Bucks")
		and arguments[1].revision == revision and arguments[1].item == "ST-024-T",
		"wall-piece confirmation keeps exact variant and original revision")
	app._dialog.hide()


func _choice(menu: SeasonMenu, key: String, value: String) -> OptionButton:
	for choice: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if choice.get_meta(key, "") == value:
			return choice
	return null


func _all_choices_disabled(menu: SeasonMenu) -> bool:
	for choice: OptionButton in menu._body.find_children("*", "OptionButton", true, false):
		if not choice.disabled:
			return false
	return true


func _all_buys_disabled(menu: SeasonMenu) -> bool:
	for buy: Button in menu._body.find_children("*", "Button", true, false):
		if (buy.has_meta("scoreboard_buy") or buy.has_meta("advanced_wall_buy")) and not buy.disabled:
			return false
	return true


func _has_text(menu: SeasonMenu, text: String) -> bool:
	for label: Label in menu._body.find_children("*", "Label", true, false):
		if label.text.nocasecmp_to(text) == 0 or label.text.to_lower().contains(text.to_lower()):
			return true
	return false


func _clear(menu: SeasonMenu) -> void:
	for child: Node in menu._body.get_children():
		menu._body.remove_child(child)
		child.free()


func _row(item: String, site: String, index: int = 0) -> Dictionary:
	return {"copy": _copy(item, index), "item": item,
		"model": StadiumScoreboardModels.MODELS[item], "site": site}


func _inventory() -> Dictionary:
	return {"stock": _stock.to_data(), "pieces": _pieces.to_data(), "boards": _boards.to_data()}


func _partition(checked: Dictionary) -> void:
	_check(checked.placements.size() + checked.board_placements.size() + checked.wall_panels.size()
		+ checked.advanced_panels.size() + checked.stored.size() + checked.pieces_stored.size()
		+ checked.scoreboards_stored.size() == _stock.copies.size()
		+ _pieces.stock.copies.size() + _boards.copies.size(),
		"every exact copy remains placed or stored")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

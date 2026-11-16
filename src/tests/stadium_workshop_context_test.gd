extends Node
## Complete workshop context stays detached; stored purchases use real saved career receipts.

const LayoutFixtures = preload("res://src/tests/stadium_scoreboard_layout_test.gd")
const SaveFixtures = preload("res://src/tests/stadium_scoreboard_save_test.gd")
const ACCESS: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY
var _failures: int = 0
var _checks: int = 0
var _stock: StadiumStock
var _pieces: StadiumWallPieceOwnership
var _boards: StadiumScoreboardOwnership


func _ready() -> void:
	var layouts: Node = LayoutFixtures.new()
	layouts._fund()
	_stock = layouts._stock
	_pieces = layouts._pieces
	_boards = layouts._boards
	_check(not layouts.is_inside_tree(), "reused layout helpers never run their ready scene")
	layouts.free()
	_all_versions()
	_primary_replacement()
	_wall_displacement()
	_context_guards()
	_saved_purchases()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro workshop context passed: ", _checks, " exact-copy checks.")
	get_tree().quit(0 if _failures == 0 else 1)


func _all_versions() -> void:
	var layouts: Array[Dictionary] = [StadiumStarterLayout.empty()]
	layouts[0].receiver = "starter-v1:ST-079"
	layouts[0].obstacles = [{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0}]
	layouts.append(StadiumHomeLayout.upgrade(layouts[-1]))
	layouts.append(StadiumFieldStyles.upgrade(layouts[-1]))
	layouts.append(StadiumClubItems.upgrade(layouts[-1]))
	layouts.append(StadiumGroundStyles.upgrade(layouts[-1]))
	layouts.append(StadiumBleacherItems.upgrade(layouts[-1]))
	layouts.append(StadiumTargetItems.upgrade(layouts[-1]))
	layouts.append(StadiumNetItems.upgrade(layouts[-1]))
	layouts.append(StadiumLightItems.upgrade(layouts[-1]))
	layouts.append(StadiumInfieldStyles.upgrade(layouts[-1]))
	layouts.append(StadiumWallItems.upgrade(layouts[-1]))
	layouts.append(StadiumSurfaceLayout.upgrade(layouts[-1], ACCESS, true))
	layouts.append(StadiumAdvancedWallLayout.upgrade(layouts[-1]))
	layouts.append(StadiumScoreboardLayout.upgrade(layouts[-1]))
	var originals: Array[Dictionary] = layouts.duplicate(true)
	var ownership: Dictionary = _ownership()
	for before: Dictionary in layouts:
		for after: Dictionary in layouts:
			var result: Dictionary = _preview(before, after)
			_check(result.ok and result.cost == 0 and result.displaced.is_empty()
				and result.moved.is_empty(), "all exact version endpoints preview for no charge")
			if result.ok:
				_partition(result.placement)
				_check(result.pieces_stored.size() == _pieces.stock.copies.size()
					and result.scoreboards_stored.size() == _boards.copies.size(),
					"old layouts retain every unused extension copy in its own channel")
	_check(ClubCareer.same(layouts, originals) and ClubCareer.same(ownership, _ownership()),
		"all-version preview never upgrades the source or changes ownership and paid values")


func _primary_replacement() -> void:
	_stock = StadiumStock.from_data(_stock.quote("ST-041", 1,
		LayoutFixtures.PROGRESS, "workshop-sign").state)
	var before: Dictionary = StadiumClubItems.upgrade(StadiumStarterLayout.empty())
	var sign: Dictionary = {"copy": "purchase:workshop-sign:0", "site": "SIGN-GROUND-R"}
	before.displays = [{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"}, sign]
	var after: Dictionary = _complete(before)
	after.displays = [sign.duplicate(true)]
	after.scoreboards = [_board("ST-039", "BOARD-RIGHT-v2")]
	var result: Dictionary = _preview(before, after)
	_check(result.ok and result.displaced.is_empty() and result.moved == ["purchase:ST-039:0"],
		"old manual to new manual moves the same paid copy without displacement or repurchase")
	_partition(result.placement)
	var previous: String = "purchase:ST-039:0"
	for item: String in ["ST-090", "ST-040", "ST-039"]:
		before = after.duplicate(true)
		after.scoreboards = [_board(item,
			"BOARD-LARGE-v2" if item == "ST-040" else "BOARD-RIGHT-v2")]
		result = _preview(before, after)
		_check(result.ok and result.cost == 0 and result.displaced == [previous]
			and result.moved.is_empty() and after.displays == [sign],
			"primary replacement stores the exact previous copy and preserves the club sign")
		_check(result.scoreboards_stored.has(previous) if _boards.copies.has(previous)
			else result.stored.has(previous), "replaced board returns to its original inventory")
		_partition(result.placement)
		previous = after.scoreboards[0].copy
	var source: Dictionary = after.duplicate(true)
	var ownership: Dictionary = _ownership()
	result.placement.placements.clear()
	result.placement.stored.clear()
	result.pieces_stored.clear()
	result.scoreboards_stored.clear()
	_check(ClubCareer.same(source, after) and ClubCareer.same(ownership, _ownership()),
		"editing returned preview arrays cannot mutate the saved layout or inventories")


func _wall_displacement() -> void:
	for shape: String in ["straight", "left_loft", "right_shelf", "offset_gables"]:
		var before: Dictionary = _complete(StadiumStarterLayout.empty())
		if shape == "straight":
			before.walls = StadiumWallLayout.propose(
				before.walls, _stock, "back", "ST-024", shape).walls
		else:
			before.advanced_back = StadiumAdvancedWallManifest.suggest(
				shape, "ST-024", _stock, _pieces.stock).manifest
		before.scoreboards = [_board("ST-090", "BOARD-RIGHT-v2")]
		var checked: Dictionary = _preview(before, before).placement
		var expected: Array[String] = []
		for row: Dictionary in checked.wall_panels + checked.advanced_panels:
			expected.append(row.copy)
		expected.sort()
		var after: Dictionary = before.duplicate(true)
		after.walls.back = {}
		after.advanced_back = StadiumAdvancedWallManifest.empty()
		var result: Dictionary = _preview(before, after)
		_check(result.ok and result.cost == 0 and result.displaced == expected
			and result.moved.is_empty(), "wall removal reports exact standard and variant copies")
		_partition(result.placement)
		for copy: String in expected:
			_check(result.stored.has(copy) if _stock.copies.has(copy)
				else result.pieces_stored.has(copy), "removed panel returns to its own paid stock")
		var legacy: Dictionary = StadiumAdvancedWallLayout.base(StadiumScoreboardLayout.base(after))
		result = _preview(before, legacy)
		expected.append("scoreboard:electronic:0")
		expected.sort()
		_check(result.ok and result.displaced == expected
			and result.scoreboards_stored.size() == _boards.copies.size(),
			"return to old layout reports wall and electronic storage without dropping copies")


func _context_guards() -> void:
	var old: Dictionary = StadiumStarterLayout.empty()
	var next: Dictionary = _complete(old)
	for before: Dictionary in [old, next]:
		_check(not StadiumOwnedLayout.preview(before, next, _stock,
			_pieces, ACCESS, "mogul").ok, "missing board context fails even for an old endpoint")
		_check(not StadiumOwnedLayout.preview(before, next, _stock,
			null, ACCESS, "mogul", _boards).ok, "missing piece context fails safely")
	var bad: StadiumWallPieceOwnership = StadiumWallPieceOwnership.from_data(_pieces.to_data())
	bad.stock.copies[bad.stock.copies.keys()[0]].paid = 0
	_check(not StadiumOwnedLayout.preview(old, old, _stock, bad, ACCESS, "mogul", _boards).ok,
		"legacy preview cannot hide a corrupt unused piece receipt")
	bad.stock = null
	_check(not StadiumOwnedLayout.preview(old, next, _stock, bad, ACCESS, "mogul", _boards).ok,
		"missing nested piece stock fails without a runtime error")
	var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.from_data(_boards.to_data())
	boards.copies[boards.copies.keys()[0]].paid = 0
	_check(not StadiumOwnedLayout.preview(old, old, _stock, _pieces, ACCESS, "mogul", boards).ok,
		"legacy preview cannot hide a corrupt unused electronic receipt")
	var count: int = StadiumStock.MAX_COPIES - _stock.copies.size() \
		- _pieces.stock.copies.size() - _boards.copies.size() + 1
	var full: StadiumStock = StadiumStock.from_data(_stock.quote("ST-001", count,
		LayoutFixtures.PROGRESS, "workshop-overflow").state)
	_check(not StadiumOwnedLayout.preview(old, old, full, _pieces, ACCESS, "mogul", _boards).ok,
		"all three inventories share capacity even when both layouts are legacy")
	_check(not _preview({}, next).ok and not _preview(old, {}).ok,
		"malformed endpoints fail without exposing a partial candidate")
	_check(not StadiumOwnedLayout.preview(old, next, _stock, _pieces,
		StadiumSurfaceProgression.initial(StadiumSurfaceProgression.ROUGH_ORIGIN),
		"mogul", _boards).ok,
		"a complete preview checks surface ownership as well as exact physical copies")


func _saved_purchases() -> void:
	var fixture: Node = SaveFixtures.new()
	SeasonSave.path = "user://workshop-context-%d.json" % OS.get_process_id()
	var season: SeasonState = fixture._fund_boards()
	_check(fixture._failures == 0 and not fixture.is_inside_tree(),
		"actual closed twenty-two-season funding helper runs off-tree")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var original_copies: Dictionary = ledger.construction().copies.duplicate(true)
	var purchased: Dictionary = {
		"purchase:stadium-wall-buy:%d:0" % ledger.revision(): "ST-024"}
	var active: Dictionary = ledger.view().stadium_active.duplicate(true)
	_check(ClubConstruction.buy_walls(season, "ST-024", 1, ledger.revision()).ok,
		"ordinary wall blueprint is acquired through its unchanged public wrapper")
	for item: String in ["ST-024-L", "ST-024-T", "ST-039", "ST-090", "ST-040"]:
		var quantity: int = 2 if item in ["ST-024-L", "ST-024-T", "ST-039"] else 1
		if item in ["ST-039", "ST-040"]:
			var revision: int = ClubPlayers.assets(season.career).revision()
			for index in range(quantity):
				purchased["purchase:stadium-scoreboard:%d:%d" % [revision, index]] = item
		_purchase_roundtrip(season, item, quantity)
	ledger = ClubPlayers.assets(season.career)
	_check(ledger.construction().blueprints.has("ST-024")
		and ledger.wall_pieces().blueprints == ["ST-024-L", "ST-024-T"],
		"standard, low and tall blueprints stay independent in the restored real career")
	_purchase_roundtrip(season, "ST-024-L", 1)
	_purchase_roundtrip(season, "ST-024-T", 1)
	_purchase_roundtrip(season, "ST-090", 1)
	ledger = ClubPlayers.assets(season.career)
	_check(ledger.wall_pieces().stock.copies.size() == 6 and ledger.scoreboards().copies.size() == 2
		and ledger.construction().copies.size() == original_copies.size() + purchased.size(),
		"paid quantities restore into their original three ownership channels")
	var actual: Dictionary = ledger.construction().copies
	for copy: String in original_copies:
		_check(actual.has(copy) and ClubCareer.same(actual[copy], original_copies[copy]),
			"purchases preserve exact starter and earned receipt " + copy)
	for copy: String in purchased:
		_check(actual.has(copy) and actual[copy].item == purchased[copy]
			and actual[copy].source == "purchase-v1" and actual[copy].paid > 0,
			"exact paid receipt stays in generic stock " + copy)
	_check(ClubCareer.same(active, ledger.view().stadium_active),
		"purchases store copies without upgrading or applying any layout")
	var balance: int = ledger.balance()
	_check(ClubConstruction.save_draft(season, active, ledger.revision()).ok
		and ClubPlayers.assets(season.career).balance() == balance,
		"an ordinary layout-only save is still zero-charge")
	_purchase_rejections(season)
	var held_balance: int = ClubPlayers.assets(season.career).balance()
	_check(ClubConstruction.save_draft(season, _complete(active),
		ClubPlayers.assets(season.career).revision()).ok and StadiumScoreboardLayout.RUNTIME_READY,
		"qualified complete-family draft can be saved through the public controller")
	_check(ClubPlayers.assets(season.career).balance() == held_balance
		and ClubCareer.same(active, ClubPlayers.assets(season.career).view().stadium_active),
		"saving complete-family draft never spends currency or silently applies it")
	fixture._cleanup()
	fixture.free()


func _purchase_roundtrip(season: SeasonState, item: String, quantity: int) -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var revision: int = ledger.revision()
	var request: Dictionary = _request(season, item, quantity, revision)
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	var price: Dictionary = ledger.preview(request)
	_check(price.ok and price.price == _expected_price(ledger, item, quantity),
		"wrapper command exactly quotes its independent blueprint and requested copies")
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	var backup: String = FileAccess.get_file_as_string(path + ".bak")
	SeasonSave.path = path + "/missing/file.json"
	_check(not _buy(season, item, quantity, revision).ok,
		"failed write cannot publish the purchased scoreboard or wall piece")
	SeasonSave.path = path
	_check(ClubCareer.same(snapshot, SeasonSave.snapshot(season))
		and FileAccess.get_file_as_string(path) == bytes
		and FileAccess.get_file_as_string(path + ".bak") == backup,
		"failed purchase preserves memory, wallet, primary file and backup")
	_check(_buy(season, item, quantity, revision).ok
		and ClubPlayers.assets(season.career).balance() == ledger.balance() - price.price,
		"the exact original confirmed revision retries and spends the shared quoted amount")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var result: Dictionary = _buy(season, item, quantity, revision)
	_check(result.ok and result.replayed and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"exact replay neither charges twice nor mints another receipt")
	_check(not _buy(season, item, quantity + 1, revision).ok
		and ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"changed quantity cannot reuse an already-paid revision-bound request")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(saved, SeasonSave.snapshot(restored)),
		"saved synthetic career restores exact receipts, ownership and shared balance")


func _purchase_rejections(season: SeasonState) -> void:
	var revision: int = ClubPlayers.assets(season.career).revision()
	_check(ClubConstruction.buy_copy(season, "ST-001", revision).ok,
		"another transaction can make an outstanding confirmation stale")
	var saved: Dictionary = SeasonSave.snapshot(season)
	_check(not ClubConstruction.buy_scoreboard(season, "ST-090", 1, revision).ok
		and not ClubConstruction.buy_wall_pieces(season, "ST-024-L", 1, revision).ok,
		"both wrappers bind the supplied revision rather than silently adopting a newer one")
	revision = ClubPlayers.assets(season.career).revision()
	for item: String in ["ST-090", "ST-024-L"]:
		for quantity: int in [0, -1, StadiumStock.MAX_COPIES]:
			_check(not _buy(season, item, quantity, revision).ok,
				"bad quantities and shared inventory capacity reject without purchase")
		_check(not _buy(season, item, 100, revision).ok,
			"insufficient shared earned balance cannot create extension ownership")
	_check(not ClubConstruction.buy_scoreboard(season, "ST-024-L", 1, revision).ok
		and not ClubConstruction.buy_wall_pieces(season, "ST-024", 1, revision).ok,
		"wrappers reject catalog and height-channel confusion")
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"all rejected and stale purchase attempts preserve the complete career")
	_check(not ClubConstruction.buy_scoreboard(null, "ST-039", 1, 0).ok
		and not ClubConstruction.buy_wall_pieces(null, "ST-024-L", 1, 0).ok,
		"missing club fails closed before inspecting career progress")
	var phase: SeasonState.Phase = season.phase
	season.phase = SeasonState.Phase.DRAFT
	_check(not ClubConstruction.buy_scoreboard(season, "ST-039", 1, revision).ok
		and not ClubConstruction.buy_wall_pieces(season, "ST-024-L", 1, revision).ok,
		"a started draft preserves the existing between-season purchase lock")
	season.phase = phase


func _request(season: SeasonState, item: String, quantity: int, revision: int) -> Dictionary:
	var board: bool = StadiumScoreboardCatalog.IDS.has(item)
	return {"id": ("stadium-scoreboard:%d" if board else "stadium-wall-piece:%d") % revision,
		"rev": revision, "op": "stadium_scoreboard" if board else "stadium_wall_piece",
		"item": item, "quantity": quantity, "price_version": StadiumScoreboardPurchases.VERSION
		if board else StadiumWallPieceOwnership.VERSION,
		"through": ClubPlayers.income_through(season.career),
		"progress_through": StadiumCareerProgress.capture(season.career).size()}


func _buy(season: SeasonState, item: String, quantity: int, revision: int) -> Dictionary:
	return ClubConstruction.buy_scoreboard(season, item, quantity, revision) \
		if StadiumScoreboardCatalog.IDS.has(item) \
		else ClubConstruction.buy_wall_pieces(season, item, quantity, revision)


func _expected_price(ledger: ClubAssetLedger, item: String, quantity: int) -> int:
	if not StadiumScoreboardCatalog.IDS.has(item):
		var piece: Dictionary = StadiumWallPieceCatalog.item(item)
		return int(piece.copy_price) * quantity + (0 if ledger.wall_pieces().blueprints.has(item)
			else int(StadiumWallPieceOwnership.BLUEPRINT_PRICES[piece.material]))
	var entry: Dictionary = StadiumScoreboardCatalog.item(item)
	var owned: bool = ledger.scoreboards().blueprints.has(item) if item == "ST-090" \
		else ledger.construction().blueprints.has(item)
	return int(entry.copy_price) * quantity + (0 if owned else int(entry.blueprint_price))


func _complete(layout: Dictionary) -> Dictionary:
	return StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(layout, ACCESS, true)))


func _preview(before: Dictionary, after: Dictionary) -> Dictionary:
	return StadiumOwnedLayout.preview(before, after, _stock, _pieces, ACCESS, "mogul", _boards)


func _board(item: String, site: String) -> Dictionary:
	return {"copy": "scoreboard:electronic:0" if item == "ST-090" else "purchase:" + item + ":0",
		"item": item, "model": StadiumScoreboardModels.MODELS[item], "site": site}


func _ownership() -> Dictionary:
	return {"stock": _stock.to_data(), "pieces": _pieces.to_data(), "boards": _boards.to_data()}


func _partition(checked: Dictionary) -> void:
	var copies: Array = checked.stored + checked.pieces_stored + checked.scoreboards_stored
	for row: Dictionary in checked.placements + checked.wall_panels \
		+ checked.advanced_panels + checked.board_placements:
		copies.append(row.copy)
	var unique: Dictionary = {}
	for copy: String in copies:
		unique[copy] = true
	_check(copies.size() == unique.size() and copies.size() == _stock.copies.size()
		+ _pieces.stock.copies.size() + _boards.copies.size(),
		"every owned copy is counted exactly once as placed or stored across all channels")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)

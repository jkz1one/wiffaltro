extends Node
## Synthetic eligibility proves pure contracts, not wallet/save or player-facing activation.

const PROGRESS: Dictionary = {"seasons": 22, "wins": 80}
var _failures: int = 0


func _ready() -> void:
	_check(not StadiumScoreboardCatalog.eligible("ST-090", {"seasons": 11, "wins": 35})
		and not StadiumScoreboardCatalog.eligible("ST-090", {"seasons": 12, "wins": 34})
		and StadiumScoreboardCatalog.eligible("ST-090", {"seasons": 12, "wins": 35}),
		"both exact electronic unlock boundaries are enforced")
	var old_catalog: String = StadiumCatalog.signature()
	var old_displays: String = StadiumPurchases.signature(StadiumPurchases.DISPLAY_VERSION)
	var stock: StadiumStock = StadiumStock.new_club()
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	_check(StadiumScoreboardOwnership.from_data(boards.to_data()) != null,
		"empty extension grants no blueprint or copy")
	for id: String in StadiumScoreboardCatalog.IDS:
		var before: Array = [stock.to_data(), pieces.to_data(), boards.to_data()]
		var entry: Dictionary = StadiumScoreboardCatalog.item(id)
		var quoted: Dictionary = StadiumScoreboardPurchases.quote(
			stock, pieces, boards, id, 2, "first:" + id, PROGRESS)
		_check(quoted.ok and quoted.cost == entry.blueprint_price + 2 * entry.copy_price,
			"each item pays its own blueprint plus copies")
		_check(ClubCareer.same(before, [stock.to_data(), pieces.to_data(), boards.to_data()]),
			"pure quotes never mutate any caller inventory")
		stock = StadiumStock.from_data(quoted.stock)
		boards = StadiumScoreboardOwnership.from_data(quoted.scoreboards, stock.copies.size())
		for other: String in StadiumScoreboardCatalog.IDS:
			_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
				other, 1, "first:" + id, PROGRESS).ok,
				"receipt request cannot cross item or inventory namespaces")
		quoted = StadiumScoreboardPurchases.quote(stock, pieces, boards,
			id, 1, "second:" + id, PROGRESS)
		_check(quoted.ok and quoted.blueprint_cost == 0 and quoted.cost == entry.copy_price,
			"subsequent copies retain exact-item blueprint ownership")
		stock = StadiumStock.from_data(quoted.stock)
		boards = StadiumScoreboardOwnership.from_data(quoted.scoreboards, stock.copies.size())
	_check(stock.copies.size() == 9 and boards.copies.size() == 3
		and boards.blueprints == [StadiumScoreboardCatalog.ELECTRONIC],
		"original manual/video copies remain standard; only electronic is extended")
	_check(ClubCareer.same(boards.to_data(), StadiumScoreboardOwnership.from_data(
		JSON.parse_string(JSON.stringify(boards.to_data())), stock.copies.size()).to_data()),
		"JSON round-trip preserves exact electronic receipts")
	var detached: Dictionary = boards.to_data()
	detached.copies.clear()
	_check(boards.copies.size() == 3, "serialized data is detached")
	for request: String in ["x".repeat(120), "trailing:"]:
		var accepted: Dictionary = StadiumScoreboardPurchases.quote(stock, pieces, boards,
			"ST-090", 1, request, PROGRESS)
		_check(accepted.ok, "legal bounded request names are preserved")
		accepted.stock.copies.clear()
		accepted.scoreboards.copies.clear()
		_check(stock.copies.size() == 9 and boards.copies.size() == 3,
			"mutating nested quote results cannot mutate inputs")
	_rejections(stock, pieces, boards)
	_capacity()
	_check(StadiumCatalog.signature() == old_catalog and StadiumCatalog.ROWS.size() == 101
		and StadiumPurchases.signature(StadiumPurchases.DISPLAY_VERSION) == old_displays
		and StadiumCatalog.item("ST-090").is_empty(),
		"extension never changes catalog101 or legacy display prices")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard ownership passed: isolated exact copies and combined proposals.")
	get_tree().quit(0 if _failures == 0 else 1)


func _rejections(stock: StadiumStock, pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership) -> void:
	var before: Array = [stock.to_data(), pieces.to_data(), boards.to_data()]
	for id: String in StadiumScoreboardCatalog.IDS:
		for progress: Dictionary in [{}, {"seasons": 22, "wins": -1}, {"seasons": 1.5, "wins": 80}]:
			_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
				id, 1, "locked", progress).ok, "unlock evidence is mandatory and integral")
		for quantity: int in [0, -1, 4097, 9223372036854775807]:
			_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
				id, quantity, "bad-quantity", PROGRESS).ok, "invalid quantity rejects")
		for request: String in ["", "x".repeat(121)]:
			_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
				id, 1, request, PROGRESS).ok, "invalid receipt request rejects")
	_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
		"ST-041", 1, "unknown", PROGRESS).ok, "unrelated catalog item is not a scoreboard")
	_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
		"ST-039", 1, "version", PROGRESS, 99).ok, "unknown price version rejects")
	for change: String in ["catalog", "version", "blueprint", "paid", "item", "source", "extra"]:
		var bad: Dictionary = boards.to_data()
		var key: String = bad.copies.keys()[0]
		match change:
			"catalog": bad.catalog = "forged"
			"version": bad.version = 2
			"blueprint": bad.blueprints = []
			"paid": bad.copies[key].paid = 0
			"item": bad.copies[key].item = "ST-039"
			"source": bad.copies[key].source = "starter-v1"
			"extra": bad["balance"] = 1000
		_check(StadiumScoreboardOwnership.from_data(bad) == null,
			"forged extension rejects: " + change)
	_check(ClubCareer.same(before, [stock.to_data(), pieces.to_data(), boards.to_data()]),
		"all rejected proposals preserve inputs")
	_check(not boards.quote(9223372036854775807, "huge", PROGRESS, 3).ok,
		"direct electronic quote rejects huge quantity before sum or range")
	_check(StadiumScoreboardOwnership.from_data(boards.to_data(), 9223372036854775807) == null,
		"huge external count rejects before overflowing capacity arithmetic")
	var item: Dictionary = StadiumScoreboardCatalog.item("ST-090")
	item.requires.clear()
	_check(not StadiumScoreboardCatalog.eligible("ST-090", {}), "catalog results are detached")


func _capacity() -> void:
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	var wall_id: String = StadiumWallPieceCatalog.DATA.keys()[0]
	var quoted: Dictionary = pieces.quote(wall_id, 1, "wall", PROGRESS, 3)
	_check(quoted.ok, "synthetic paid wall copy for combined capacity")
	if not quoted.ok:
		return
	pieces = StadiumWallPieceOwnership.from_data(quoted.state, 3)
	for id: String in StadiumScoreboardCatalog.IDS:
		var stock: StadiumStock = StadiumStock.new_club()
		stock = StadiumStock.from_data(stock.quote("ST-001", 4091, PROGRESS, "bulk").state)
		var boards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
		var before: Array = [stock.to_data(), pieces.to_data(), boards.to_data()]
		_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
			id, 1, "wall", PROGRESS).ok, "wall receipt cannot be reused for a board")
		quoted = StadiumScoreboardPurchases.quote(stock, pieces, boards,
			id, 1, "last", PROGRESS)
		_check(quoted.ok, "combined copy4096 is allowed for every scoreboard route")
		_check(ClubCareer.same(before, [stock.to_data(), pieces.to_data(), boards.to_data()]),
			"capacity preview is detached")
		stock = StadiumStock.from_data(quoted.stock)
		boards = StadiumScoreboardOwnership.from_data(quoted.scoreboards,
			stock.copies.size() + pieces.stock.copies.size())
		for next: String in StadiumScoreboardCatalog.IDS:
			_check(not StadiumScoreboardPurchases.quote(stock, pieces, boards,
				next, 1, "overflow", PROGRESS).ok, "combined copy4097 rejects across both stores")
		_check(StadiumScoreboardOwnership.from_data(boards.to_data(), 4097) == null,
			"external inventory counts cannot exceed the shared capacity")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

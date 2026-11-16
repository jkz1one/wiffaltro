extends Node
## Exact whole-run manifests and reversible proposals without ownership mutation.

var _failures: int = 0


func _ready() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var empty: Dictionary = StadiumWallLayout.empty()
	_check(StadiumWallLayout.validate(empty, stock).ok, "free template has no paid manifest")
	var short: Dictionary = StadiumWallLayout.propose(empty, stock, "back", "ST-024", "straight")
	_check(not short.ok and short.missing == 23, "no free wall from selecting a shape")
	stock = _buy(stock, "ST-024", 22, "plywood", 1020)
	var before: Dictionary = stock.to_data()
	short = StadiumWallLayout.propose(empty, stock, "back", "ST-024", "straight")
	_check(not short.ok and short.missing == 1 and ClubCareer.same(before, stock.to_data()),
		"incomplete straight run preserves every owned copy")
	var proposal: Dictionary = StadiumWallLayout.propose(
		empty, stock, "back", "ST-024", "deeper_center")
	_check(proposal.ok and StadiumWallLayout.validate(proposal.walls, stock).used.size() == 22,
		"deeper reference consumes exactly twenty-two copies")
	stock = _buy(stock, "ST-024", 1, "plywood-extra", 30)
	proposal = StadiumWallLayout.propose(proposal.walls, stock, "back", "ST-024", "straight")
	_check(proposal.ok and proposal.walls.back.copies.size() == 23,
		"one extra copy completes straight")
	var straight: Dictionary = proposal.walls.duplicate(true)
	proposal = StadiumWallLayout.propose(straight, stock, "back", "ST-024", "deeper_center")
	_check(proposal.ok and proposal.walls.back.copies.size() == 22
		and stock.copies.size() == 26, "shape swap stores surplus without refund or minted copy")
	stock = _buy(stock, "ST-022", 19, "left", 755)
	stock = _buy(stock, "ST-023", 19, "right", 755)
	proposal = StadiumWallLayout.propose(straight, stock, "left", "ST-022")
	proposal = StadiumWallLayout.propose(proposal.walls, stock, "right", "ST-023")
	_check(proposal.ok and StadiumWallLayout.validate(proposal.walls, stock).used.size() == 61,
		"complete straight and independent sides bind sixty-one exact copies")
	var complete: Dictionary = proposal.walls.duplicate(true)
	var invalid: Dictionary = complete.duplicate(true)
	invalid.left[0] = invalid.right[0]
	_check(not StadiumWallLayout.validate(invalid, stock).ok, "wrong handed copy rejects")
	invalid = complete.duplicate(true)
	invalid.back.copies[1] = invalid.back.copies[0]
	_check(not StadiumWallLayout.validate(invalid, stock).ok, "duplicate copy cannot fill two sockets")
	invalid = complete.duplicate(true)
	invalid.back.copies.reverse()
	_check(not StadiumWallLayout.validate(invalid, stock).ok, "noncanonical socket order rejects")
	invalid = complete.duplicate(true)
	invalid.back.copies.pop_back()
	_check(not StadiumWallLayout.validate(invalid, stock).ok, "short end still consumes whole copy")
	invalid = complete.duplicate(true)
	invalid.back.copies[0] = "forged-copy"
	_check(not StadiumWallLayout.validate(invalid, stock).ok, "unowned panel rejects")
	_check(not StadiumWallLayout.propose(complete, stock, "left", "ST-023").ok,
		"proposal cannot silently use wrong handed material")
	for row: Array in [["ST-065", 1325], ["ST-077", 1735], ["ST-078", 1140]]:
		stock = _buy(stock, row[0], 23, row[0], row[1])
		for shape: String in StadiumWallRecipes.SHAPES:
			proposal = StadiumWallLayout.propose(complete, stock, "back", row[0], shape)
			_check(proposal.ok and StadiumWallLayout.validate(proposal.walls, stock).ok,
				"each retained back material uses its own complete manifest")
	invalid = complete.duplicate(true)
	invalid.back.copies[0] = proposal.walls.back.copies[0]
	_check(not StadiumWallLayout.validate(invalid, stock).ok, "mixed back materials reject")
	before = stock.to_data()
	proposal = {"walls": complete}
	for slot: String in ["back", "left", "right"]:
		proposal = StadiumWallLayout.propose(proposal.walls, stock, slot)
	_check(proposal.ok and StadiumWallLayout.validate(proposal.walls, stock).used.is_empty()
		and ClubCareer.same(before, stock.to_data()),
		"dismantling stores rather than deletes owned panels")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wall manifest checks passed: exact copies, handedness and reversible proposals.")
	get_tree().quit(0 if _failures == 0 else 1)


func _buy(stock: StadiumStock, item: String, quantity: int, request: String,
	cost: int) -> StadiumStock:
	var quote: Dictionary = stock.quote(item, quantity, {"seasons": 50, "wins": 200}, request)
	_check(quote.ok and quote.cost == cost, "retained blueprint and full-copy economics " + item)
	return StadiumStock.from_data(quote.state)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

class_name StadiumScoreboardPurchases
extends RefCounted
## Pure combined proposal. Does not charge a wallet, write a receipt journal or activate a layout.

const VERSION: int = 1


static func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"catalog": StadiumScoreboardCatalog.signature(),
				"ownership": StadiumScoreboardOwnership.VERSION
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func quote(
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership,
	id: String,
	quantity: int,
	request: String,
	progress: Dictionary,
	price_version: int = VERSION
) -> Dictionary:
	if (
		stock == null
		or pieces == null
		or pieces.stock == null
		or boards == null
		or price_version != VERSION
		or not StadiumScoreboardCatalog.IDS.has(id)
	):
		return StadiumScoreboardOwnership._error("Unknown scoreboard quote or missing ownership.")
	if _request_used(stock, pieces, boards, request):
		return StadiumScoreboardOwnership._error("This purchase request already has a receipt.")
	var standard: StadiumStock = StadiumStock.from_data(stock.to_data())
	var extension: StadiumScoreboardOwnership = StadiumScoreboardOwnership.from_data(
		boards.to_data(), stock.capacity_count() + pieces.stock.copies.size()
	)
	if (
		standard == null
		or extension == null
		or (
			StadiumWallPieceOwnership.from_data(
				pieces.to_data(), stock.capacity_count() + boards.copies.size()
			)
			== null
		)
	):
		return StadiumScoreboardOwnership._error("Invalid combined construction ownership.")
	if (
		quantity < 1
		or quantity > StadiumStock.MAX_COPIES
		or (
			stock.capacity_count() + pieces.stock.copies.size() + boards.copies.size() + quantity
			> StadiumStock.MAX_COPIES
		)
	):
		return StadiumScoreboardOwnership._error("Combined construction capacity reached.")
	var result: Dictionary = (
		extension.quote(
			quantity, request, progress, stock.capacity_count() + pieces.stock.copies.size()
		)
		if id == StadiumScoreboardCatalog.ELECTRONIC
		else standard.quote(id, quantity, progress, request)
	)
	if not result.ok:
		return result
	var entry: Dictionary = StadiumScoreboardCatalog.item(id)
	var owned: bool = (
		boards.blueprints.has(id)
		if id == StadiumScoreboardCatalog.ELECTRONIC
		else stock.blueprints.has(id)
	)
	if (
		result.blueprint_cost != (0 if owned else entry.blueprint_price)
		or result.copy_cost != int(entry.copy_price) * quantity
	):
		return StadiumScoreboardOwnership._error("The scoreboard quote changed; reload it.")
	return {
		"ok": true,
		"error": "",
		"cost": result.cost,
		"blueprint_cost": result.blueprint_cost,
		"copy_cost": result.copy_cost,
		"stock": standard.to_data() if id == StadiumScoreboardCatalog.ELECTRONIC else result.state,
		"scoreboards":
		result.state if id == StadiumScoreboardCatalog.ELECTRONIC else extension.to_data(),
		"placement_verified": false
	}


static func _request_used(
	stock: StadiumStock,
	pieces: StadiumWallPieceOwnership,
	boards: StadiumScoreboardOwnership,
	request: String
) -> bool:
	for row: Array in [
		[stock.copies, "purchase:"],
		[pieces.stock.copies, "wall-piece:"],
		[boards.copies, "scoreboard:"]
	]:
		for key: Variant in row[0]:
			if (
				key is String
				and key.begins_with(row[1])
				and key.left(key.rfind(":")) == row[1] + request
			):
				return true
	return false

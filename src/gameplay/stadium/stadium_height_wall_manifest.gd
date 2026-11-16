class_name StadiumHeightWallManifest
extends RefCounted
## Exact immutable sockets across legacy standard copies and distinct low/tall copies.

const VERSION: int = 1


static func empty() -> Dictionary:
	return {"shape": "", "material": "", "copies": []}


static func validate(value: Variant, stock: StadiumStock,
	pieces: StadiumWallPieceStock) -> Dictionary:
	if stock == null or pieces == null or StadiumStock.from_data(stock.to_data()) == null \
		or StadiumWallPieceStock.from_data(pieces.to_data(), stock.capacity_count()) == null:
		return _error("Invalid construction ownership.")
	if not value is Dictionary or not SeasonOwnership._keys(value, ["shape", "material", "copies"]) \
		or not value.shape is String or not value.material is String or not value.copies is Array:
		return _error("Invalid exact wall-piece manifest.")
	if value == empty():
		return {"ok": true, "error": "", "panels": [], "standard_used": [], "pieces_used": []}
	var rows: Array[Dictionary] = StadiumHeightWallRecipes.rows(value.shape, value.material)
	if rows.is_empty() or value.copies.size() != rows.size():
		return _error("This wall requires its complete exact authored socket list.")
	return _bind(value.copies, rows, stock, pieces)


static func _bind(ids: Array, rows: Array[Dictionary], stock: StadiumStock,
	pieces: StadiumWallPieceStock) -> Dictionary:
	var used: Array[String] = []
	var standard_used: Array[String] = []
	var pieces_used: Array[String] = []
	for index in range(rows.size()):
		var key: Variant = ids[index]
		var row: Dictionary = rows[index]
		if not key is String or used.has(key):
			return _error("Each wall socket needs a distinct exact owned piece.")
		var standard: bool = row.height == 3.25
		var owned: Dictionary = stock.copies if standard else pieces.copies
		var expected: String = row.item if standard else StadiumWallPieceCatalog.identity(
			row.item, StadiumHeightWallRecipes.piece_type(row.height))
		if not owned.has(key) or owned[key].item != expected:
			return _error("Wrong material or height; standard pieces cannot become low/tall pieces.")
		used.append(key)
		if standard:
			standard_used.append(key)
		else:
			pieces_used.append(key)
		row["copy"] = key
		row["piece_item"] = expected
	return {"ok": true, "error": "", "panels": rows,
		"standard_used": standard_used, "pieces_used": pieces_used}


static func suggest(shape: String, material: String, stock: StadiumStock,
	pieces: StadiumWallPieceStock) -> Dictionary:
	var rows: Array[Dictionary] = StadiumHeightWallRecipes.rows(shape, material)
	if rows.is_empty() or stock == null or pieces == null:
		return _error("Unknown wall recipe or ownership.")
	var available: Dictionary = {"standard": [], "low": [], "tall": []}
	for key: String in stock.copies:
		if stock.copies[key].item == material:
			available.standard.append(key)
	for key: String in pieces.copies:
		var item: Dictionary = StadiumWallPieceCatalog.item(pieces.copies[key].item)
		if not item.is_empty() and item.material == material:
			available[item.height].append(key)
	for list: Array in available.values():
		list.sort()
	var ids: Array[String] = []
	for row: Dictionary in rows:
		var kind: String = StadiumHeightWallRecipes.piece_type(row.height)
		if available[kind].is_empty():
			return _error("Missing owned " + kind + " pieces for the complete wall.")
		ids.append(available[kind].pop_front())
	var result: Dictionary = {"shape": shape, "material": material, "copies": ids}
	var checked: Dictionary = validate(result, stock, pieces)
	return {"ok": true, "error": "", "manifest": result} if checked.ok else checked


static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

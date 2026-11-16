class_name StadiumLowWallManifest
extends RefCounted
## Exact paid sockets; old low-piece catalog and receipt meanings are unchanged.
const VERSION: int = 1


static func empty() -> Dictionary:
	return {"profile": "", "material": "", "copies": []}


static func validate(
	value: Variant, stock: StadiumStock, pieces: StadiumWallPieceStock
) -> Dictionary:
	if (
		stock == null
		or pieces == null
		or StadiumStock.from_data(stock.to_data()) == null
		or StadiumWallPieceStock.from_data(pieces.to_data(), stock.capacity_count()) == null
	):
		return StadiumHeightWallManifest._error(
			"Complete paid standard and low-piece ownership is required."
		)
	if (
		not value is Dictionary
		or not SeasonOwnership._keys(value, ["profile", "material", "copies"])
		or not value.profile is String
		or not value.material is String
		or not value.copies is Array
	):
		return StadiumHeightWallManifest._error("Unknown low-wall manifest.")
	if value == empty():
		return {"ok": true, "error": "", "panels": [], "standard_used": [], "pieces_used": []}
	var rows: Array[Dictionary] = StadiumLowWallRecipes.rows(value.profile, value.material)
	if rows.is_empty() or rows.size() != value.copies.size():
		return StadiumHeightWallManifest._error(
			"A low-wall profile requires its complete authored socket list."
		)
	return StadiumHeightWallManifest._bind(value.copies, rows, stock, pieces)


static func suggest(
	profile: String, material: String, stock: StadiumStock, pieces: StadiumWallPieceStock
) -> Dictionary:
	if stock == null or pieces == null:
		return StadiumHeightWallManifest._error("Complete paid ownership is required.")
	var rows: Array[Dictionary] = StadiumLowWallRecipes.rows(profile, material)
	if rows.is_empty():
		return StadiumHeightWallManifest._error("Unknown authored low-wall profile.")
	var standard: Array[String] = []
	var low: Array[String] = []
	for key: String in stock.copies:
		if stock.copies[key].item == material:
			standard.append(key)
	for key: String in pieces.copies:
		if pieces.copies[key].item == StadiumWallPieceCatalog.identity(material, "low"):
			low.append(key)
	standard.sort()
	low.sort()
	var ids: Array[String] = []
	for row: Dictionary in rows:
		var available: Array[String] = (
			standard if row.height == StadiumLowWallRecipes.STANDARD else low
		)
		if available.is_empty():
			return StadiumHeightWallManifest._error(
				"Missing distinct owned low or standard wall copies."
			)
		ids.append(available.pop_front())
	var manifest: Dictionary = {"profile": profile, "material": material, "copies": ids}
	var checked: Dictionary = validate(manifest, stock, pieces)
	return {"ok": true, "error": "", "manifest": manifest} if checked.ok else checked

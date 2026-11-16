class_name StadiumAdvancedWallManifest
extends RefCounted
## New-family adapter only. Existing saved recipe factories/signatures stay frozen.

const VERSION: int = 1
const SHAPES: Array[String] = ["left_loft", "right_shelf", "offset_gables"]


static func empty() -> Dictionary:
	return StadiumHeightWallManifest.empty()


static func graph(shape: String) -> StadiumRecipeBoundary:
	return StadiumOffsetBoundary.new() if shape == "offset_gables" else (
		StadiumHeightBoundary.candidate(shape))


static func validate(value: Variant, stock: StadiumStock,
	pieces: StadiumWallPieceStock) -> Dictionary:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["shape", "material", "copies"]) \
		or not value.shape is String or not value.material is String or not value.copies is Array:
		return StadiumStarterLayout._error("Invalid advanced wall manifest.")
	if value.shape != "offset_gables":
		return StadiumHeightWallManifest.validate(value, stock, pieces)
	if stock == null or pieces == null or StadiumStock.from_data(stock.to_data()) == null \
		or StadiumWallPieceStock.from_data(pieces.to_data(), stock.capacity_count()) == null:
		return StadiumStarterLayout._error("Invalid advanced wall ownership.")
	var rows: Array[Dictionary] = StadiumOffsetWallRecipes.back(value.material)
	var result: Dictionary = {"ok": true, "error": "", "used": [], "panels": [],
		"standard_used": [], "pieces_used": []}
	if rows.is_empty() or not StadiumWallLayout._copies(value.copies, rows, stock, result):
		return StadiumStarterLayout._error("Offset Gables requires its complete exact standard copies.")
	result.standard_used = result.used.duplicate()
	result.erase("used")
	for row: Dictionary in result.panels:
		row["width"] = StadiumOffsetWallRecipes.LENGTHS[row.span]
		row["piece_item"] = row.item
	return result


static func suggest(shape: String, material: String, stock: StadiumStock,
	pieces: StadiumWallPieceStock) -> Dictionary:
	if stock == null or pieces == null or StadiumStock.from_data(stock.to_data()) == null \
		or StadiumWallPieceStock.from_data(pieces.to_data(), stock.capacity_count()) == null:
		return StadiumStarterLayout._error("Invalid advanced wall ownership.")
	if shape != "offset_gables":
		return StadiumHeightWallManifest.suggest(shape, material, stock, pieces)
	var rows: Array[Dictionary] = StadiumOffsetWallRecipes.back(material)
	var available: Array[String] = []
	for key: String in stock.copies:
		if stock.copies[key].item == material:
			available.append(key)
	available.sort()
	if rows.is_empty() or available.size() < rows.size():
		return StadiumStarterLayout._error("Missing standard pieces for Offset Gables.")
	var manifest: Dictionary = {"shape": shape, "material": material,
		"copies": available.slice(0, rows.size())}
	var checked: Dictionary = validate(manifest, stock, pieces)
	return {"ok": true, "error": "", "manifest": manifest} if checked.ok else checked

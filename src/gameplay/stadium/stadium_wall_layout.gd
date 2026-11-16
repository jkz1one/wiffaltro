class_name StadiumWallLayout
extends RefCounted
## Exact complete-run ownership. No per-panel live-object budget or automatic copy grants.

const VERSION: int = 1
const SIDES: Dictionary = {"left": "ST-022", "right": "ST-023"}


static func empty() -> Dictionary:
	return {"back": {}, "left": [], "right": []}


static func validate(value: Variant, stock: StadiumStock) -> Dictionary:
	if stock == null or not value is Dictionary or not SeasonOwnership._keys(
		value, ["back", "left", "right"]) or not value.back is Dictionary:
		return StadiumStarterLayout._error("Unknown complete-wall selection.")
	var result: Dictionary = {"ok": true, "error": "", "used": [], "panels": [],
		"shape": "straight", "has_paid": false}
	if not value.back.is_empty():
		var back: Dictionary = value.back
		if not SeasonOwnership._keys(back, ["shape", "item", "copies"]) \
			or not back.shape is String or not back.item is String:
			return StadiumStarterLayout._error("Unknown complete back-wall selection.")
		var rows: Array[Dictionary] = StadiumWallRecipes.back(back.shape, back.item)
		if rows.is_empty() or not _copies(back.copies, rows, stock, result):
			return StadiumStarterLayout._error("A back wall needs its complete exact owned-copy manifest.")
		result.shape = back.shape
	for side: String in SIDES:
		if not value[side] is Array:
			return StadiumStarterLayout._error("Unknown side-wall manifest.")
		if not value[side].is_empty() and not _copies(value[side],
			StadiumWallRecipes.side(side == "left"), stock, result):
			return StadiumStarterLayout._error("Each side needs nineteen exact handed owned copies.")
	result.has_paid = not result.used.is_empty()
	return result


static func _copies(copies: Variant, rows: Array[Dictionary], stock: StadiumStock,
	result: Dictionary) -> bool:
	if not copies is Array or copies.size() != rows.size():
		return false
	var previous: String = ""
	for index in range(copies.size()):
		var copy: Variant = copies[index]
		if not copy is String or copy <= previous or not stock.copies.has(copy) \
			or stock.copies[copy].item != rows[index].item or result.used.has(copy):
			return false
		previous = copy
		result.used.append(copy)
		var row: Dictionary = rows[index].duplicate(true)
		row["copy"] = copy
		result.panels.append(row)
	return true


static func propose(current: Dictionary, stock: StadiumStock, slot: String,
	item: String = "", shape: String = "straight") -> Dictionary:
	if not validate(current, stock).ok or slot not in ["back", "left", "right"]:
		return StadiumStarterLayout._error("Reload the current wall selection before replacing it.")
	var next: Dictionary = current.duplicate(true)
	if item.is_empty():
		next[slot] = {} if slot == "back" else []
		return {"ok": true, "error": "", "walls": next, "missing": 0}
	var rows: Array[Dictionary] = []
	if slot == "back":
		rows = StadiumWallRecipes.back(shape, item)
	elif item == SIDES[slot]:
		rows = StadiumWallRecipes.side(slot == "left")
	if rows.is_empty():
		return StadiumStarterLayout._error("This material does not fit the selected wall recipe.")
	var owned: Array[String] = []
	for copy: String in stock.copies:
		if stock.copies[copy].item == item:
			owned.append(copy)
	owned.sort()
	if owned.size() < rows.size():
		return {"ok": false, "error": "Complete wall needs %d more copies." % (
			rows.size() - owned.size()), "missing": rows.size() - owned.size(),
			"required": rows.size(), "owned": owned.size()}
	var selected: Array[String] = []
	selected.assign(owned.slice(0, rows.size()))
	next[slot] = {"shape": shape, "item": item, "copies": selected} if slot == "back" else selected
	return {"ok": true, "error": "", "walls": next, "missing": 0}

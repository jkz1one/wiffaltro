class_name StadiumOffsetWallRecipes
extends RefCounted
## Exact candidate closures, with no new shop grant or accepted saved layout.

const VERSION: int = 1
const LENGTHS: Dictionary = {"full": 2.0, "offset_end_01": 0.528839739645543,
	"offset_end_02": 0.602325267042627, "offset_end_04": 1.069705149024927,
	"offset_end_05": 1.615773105863909, "offset_end_06": 0.849327613589604}
const SPANS: Array = [
	["full", "full", "full", "full", "offset_end_01"],
	["full", "full", "full", "full", "offset_end_02"],
	["full", "full", "full", "full"],
	["full", "full", "full", "offset_end_04", "offset_end_04"],
	["full", "full", "full", "offset_end_05"],
	["full", "full", "full", "offset_end_06"]]


static func back(item: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not StadiumWallRecipes.BACK_IDS.has(item):
		return rows
	var points: PackedVector2Array = StadiumOffsetBoundary.new().polygon().slice(3, 10)
	for index in range(6):
		var a: Vector2 = points[index]
		var b: Vector2 = points[index + 1]
		var direction: Vector2 = a.direction_to(b)
		var distance: float = 0
		for span: String in SPANS[index]:
			var length: float = LENGTHS[span]
			rows.append({"socket": "OFFSET-%s-%02d" % [item, rows.size() + 1],
				"item": item, "span": span, "a": a + direction * distance,
				"b": a + direction * (distance + length), "height": 3.25})
			distance += length
	return rows

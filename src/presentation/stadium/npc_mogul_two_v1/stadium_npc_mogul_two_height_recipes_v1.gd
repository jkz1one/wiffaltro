class_name StadiumNpcMogulTwoHeightRecipesV1
extends RefCounted
## Working separate-piece candidate; never a conversion of old standard inventory.

const VERSION: int = 1
const SHAPES: Dictionary = {
	"left_loft": [
		[Vector2(21.519454636569, 23.4), Vector2(8, 27), 3.25,
			[2, 2, 2, 2, 2, 2, 1.99055587424056]],
		[Vector2(8, 27), Vector2(-4, 27), 3.25,
			[2, 2, 2, 2, 2, 2]],
		[Vector2(-4, 27), Vector2(-10, 22), 4.875,
			[2, 2, 2, 1.81024967590665]],
		[Vector2(-10, 22), Vector2(-18, 21), 4.875,
			[2, 2, 2, 1.03112887414927, 1.03112887414927]],
		[Vector2(-18, 21), Vector2(-21.519454636569, 23.4), 4.875,
			[2, 1.12993902136112, 1.12993902136112]]],
	"right_shelf": [
		[Vector2(21.519454636569, 23.4), Vector2(17, 21), 1.625,
			[2, 2, 1.11717404550647]],
		[Vector2(17, 21), Vector2(10, 21), 1.625,
			[2, 2, 2, 1]],
		[Vector2(10, 21), Vector2(4, 25.5), 3.25,
			[2, 2, 2, 1.5]],
		[Vector2(4, 25.5), Vector2(-8, 27.5), 3.25,
			[2, 2, 2, 2, 2, 1.08276253029822, 1.08276253029822]],
		[Vector2(-8, 27.5), Vector2(-21.519454636569, 23.4), 3.25,
			[2, 2, 2, 2, 2, 2, 1.06373933675088, 1.06373933675088]]]}


static func rows(shape: String, item: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not SHAPES.has(shape) or not StadiumNpcClubWallRecipesV1.BACK_IDS.has(item):
		return result
	for section: Array in SHAPES[shape]:
		var a: Vector2 = section[0]
		var b: Vector2 = section[1]
		var direction: Vector2 = a.direction_to(b)
		var cursor: Vector2 = a
		for width: float in section[3]:
			var end: Vector2 = cursor + direction * width
			result.append({"socket": "%s-%02d" % [shape, result.size()], "item": item,
				"a": cursor, "b": end, "width": width, "height": section[2]})
			cursor = end
	return result


static func piece_type(height: float) -> String:
	return "low" if height == 1.625 else "standard" if height == 3.25 else (
		"tall" if height == 4.875 else "")


static func requirements(shape: String, item: String) -> Dictionary:
	var result: Dictionary = {"low": 0, "standard": 0, "tall": 0}
	var panels: Array[Dictionary] = rows(shape, item)
	if panels.is_empty():
		return {}
	for row: Dictionary in panels:
		result[piece_type(row.height)] += 1
	return result

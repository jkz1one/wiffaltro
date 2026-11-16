class_name StadiumNpcExpandedWallRecipesV1
extends RefCounted
## Retained AE-01/r1 correspondence copy.
## Original: src/gameplay/stadium/stadium_wall_recipes.gd
## Exact authoring manifests only. These definitions do not grant ownership or activate play.

const VERSION: int = 1
const BACK_X: float = 21.519454636569
const BACK_Z: float = 23.4
const BACK_IDS: Array[String] = ["ST-024", "ST-065", "ST-077", "ST-078"]
const SHAPES: Array[String] = ["straight", "deeper_center"]


static func back(shape: String, item: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not SHAPES.has(shape) or not BACK_IDS.has(item):
		return rows
	if shape == "straight":
		_append(rows, Vector2(BACK_X, BACK_Z), Vector2(21, BACK_Z), item, "straight_end")
		_run(rows, Vector2(21, BACK_Z), Vector2(-21, BACK_Z), 21, item)
		_append(rows, Vector2(-21, BACK_Z), Vector2(-BACK_X, BACK_Z), item, "straight_end")
	else:
		var right: Vector2 = Vector2(BACK_X, BACK_Z)
		var joint: Vector2 = Vector2(10, 26)
		var full_end: Vector2 = joint + joint.direction_to(right) * 10
		_append(rows, right, full_end, item, "angled_end")
		_run(rows, full_end, joint, 5, item)
		_run(rows, joint, Vector2(-10, 26), 10, item)
		_run(rows, Vector2(-10, 26), Vector2(-full_end.x, full_end.y), 5, item)
		_append(rows, Vector2(-full_end.x, full_end.y), Vector2(-BACK_X, BACK_Z),
			item, "angled_end")
	return rows


static func side(left: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var item: String = "ST-022" if left else "ST-023"
	var rear: Vector2 = Vector2(8, -6)
	var corner: Vector2 = Vector2(24, BACK_Z)
	var full_end: Vector2 = rear + rear.direction_to(corner) * 32
	_run(rows, rear, full_end, 16, item)
	_append(rows, full_end, corner, item, "side_end")
	_append(rows, corner, Vector2(22, BACK_Z), item, "full")
	_append(rows, Vector2(22, BACK_Z), Vector2(BACK_X, BACK_Z), item, "return_end")
	if left:
		rows.reverse()
		for row: Dictionary in rows:
			var a: Vector2 = row.a
			row.a = Vector2(-row.b.x, row.b.y)
			row.b = Vector2(-a.x, a.y)
	for index in range(rows.size()):
		rows[index].socket = "%s-%02d" % [item, index + 1]
	return rows


static func placement(row: Dictionary) -> Transform3D:
	var a: Vector2 = row.a
	var b: Vector2 = row.b
	var direction: Vector2 = a.direction_to(b)
	var tangent: Vector3 = Vector3(direction.x, 0, direction.y)
	var center: Vector2 = (a + b) / 2
	return Transform3D(Basis(tangent, Vector3.UP, tangent.cross(Vector3.UP)),
		Vector3(center.x, 0, center.y))


static func _run(rows: Array[Dictionary], a: Vector2, b: Vector2, count: int,
	item: String) -> void:
	for index in range(count):
		_append(rows, a.lerp(b, float(index) / count),
			a.lerp(b, float(index + 1) / count), item, "full")


static func _append(rows: Array[Dictionary], a: Vector2, b: Vector2, item: String,
	span: String) -> void:
	rows.append({"socket": "%s-%02d" % [item, rows.size() + 1], "item": item,
		"span": span, "a": a, "b": b, "height": 3.25 if BACK_IDS.has(item) else 1.2})

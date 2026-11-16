class_name StadiumWallViewPrisms
extends RefCounted
## Exact joined wall volumes for presentation rays, independent of conservative broad boxes.

var walls: Array[Dictionary] = []


func _init(graph: StadiumRecipeBoundary) -> void:
	var rows: Array[Dictionary] = graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var polygon: PackedVector2Array = [row.a, row.b,
			graph.outer_vertex((index + 1) % rows.size()), graph.outer_vertex(index)]
		var planes: Array[Plane] = [Plane(Vector3.DOWN, 0), Plane(Vector3.UP, row.height)]
		for edge in range(polygon.size()):
			var a: Vector2 = polygon[edge]
			var direction: Vector2 = a.direction_to(polygon[(edge + 1) % polygon.size()])
			var normal: Vector3 = Vector3(-direction.y, 0, direction.x)
			planes.append(Plane(normal, normal.dot(Vector3(a.x, 0, a.y))))
		walls.append({"polygon": polygon, "planes": planes, "height": row.height})


func margin(ball: Vector3, maximum: float = 0.4) -> float:
	var result: float = maximum
	for wall: Dictionary in walls:
		# Half the largest separating-plane gap keeps the ball outside the
		# inflated convex volume, including near an acute miter corner.
		var gap: float = 0
		for plane: Plane in wall.planes:
			gap = maxf(gap, plane.distance_to(ball))
		result = minf(result, gap * 0.5)
	return result


func blocked(camera: Vector3, ball: Vector3, padding: float) -> bool:
	for wall: Dictionary in walls:
		if _hit(wall.planes, camera, ball, padding):
			return true
	return false


func _hit(planes: Array[Plane], camera: Vector3, ball: Vector3, padding: float) -> bool:
	var enter: float = 0
	var leave: float = 1
	for plane: Plane in planes:
		var from: float = plane.distance_to(camera) - padding
		var to: float = plane.distance_to(ball) - padding
		if from > 0 and to > 0:
			return false
		if from > 0:
			enter = maxf(enter, from / (from - to))
		elif to > 0:
			leave = minf(leave, from / (from - to))
		if enter > leave:
			return false
	return true

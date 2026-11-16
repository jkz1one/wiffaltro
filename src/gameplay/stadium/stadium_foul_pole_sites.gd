class_name StadiumFoulPoleSites
extends RefCounted
## Nominal foul-ray sockets. Pole dimensions are Working blockouts, not new scoring tolerances.

const VERSION: int = 1
const RADIUS: float = 0.09
const HEIGHT: float = 8.0
const ANGLE: float = 42.0


static func rows(graph: StadiumRecipeBoundary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if graph == null:
		return result
	for side in [-1, 1]:
		var ray: Vector2 = Vector2(side * tan(deg_to_rad(ANGLE)), 1) * 100
		var best: Dictionary = {}
		for row: Dictionary in graph.segments():
			if row.role != "BACK_WALL_TERMINAL":
				continue
			var hit: Variant = Geometry2D.segment_intersects_segment(Vector2.ZERO, ray, row.a, row.b)
			if hit != null and (best.is_empty() or hit.length() < best.point.length()):
				best = {"point": hit, "split": row.height, "segment": row.id}
		if best.is_empty() or best.split >= HEIGHT:
			return []
		result.append({"site": "FOUL-POLE-L" if side == -1 else "FOUL-POLE-R",
			"position": Vector3(best.point.x, 0, best.point.y), "split": best.split,
			"segment": best.segment, "radius": RADIUS, "height": HEIGHT})
	return result


static func validate(ids: Variant, stock: StadiumStock, graph: StadiumRecipeBoundary) -> Dictionary:
	if not ids is Array or ids.size() != 2 or stock == null \
		or StadiumStock.from_data(stock.to_data()) == null:
		return {"ok": false, "error": "Each pole needs its own exact owned ST-021 copy."}
	var sockets: Array[Dictionary] = rows(graph)
	if sockets.size() != 2:
		return {"ok": false, "error": "No complete authored pole sockets for this field."}
	var used: Array[String] = []
	for index in range(2):
		var key: Variant = ids[index]
		if not key is String or used.has(key) or not stock.copies.has(key) \
			or stock.copies[key].item != "ST-021":
			return {"ok": false, "error": "Two distinct pole copies are required; no wall substitution."}
		used.append(key)
		sockets[index]["copy"] = key
	return {"ok": true, "error": "", "placements": sockets}

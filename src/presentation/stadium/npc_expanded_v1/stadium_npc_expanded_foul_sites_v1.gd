class_name StadiumNpcExpandedFoulSitesV1
extends RefCounted
## Retained AE-01/r1 correspondence copy.
## Original: src/gameplay/stadium/stadium_foul_pole_sites.gd
## Nominal foul-ray sockets. Pole dimensions are Working blockouts, not new scoring tolerances.

const VERSION: int = 1
const RADIUS: float = 0.09
const HEIGHT: float = 8.0
const ANGLE: float = 42.0


static func rows(graph: StadiumNpcExpandedGraphV1) -> Array[Dictionary]:
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

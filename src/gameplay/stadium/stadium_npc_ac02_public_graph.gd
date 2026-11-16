class_name StadiumNpcAc02PublicGraph
extends StadiumDugoutBoundary
## AC-02 isolated graph: actual low/standard backs and original concrete-dugout subdivisions.


func identity() -> String:
	return "PROTOTYPE-CLUB-DUGOUT-RIGHT-SHELF-v1"


func polygon() -> PackedVector2Array:
	var result: PackedVector2Array = []
	var original: StadiumRecipeBoundary = StadiumHeightBoundary.candidate("right_shelf")
	for row: Dictionary in original.segments():
		result.append(row.a)
		if row.id in ["SIDE-R-01", "SIDE-L-01"]:
			var left: bool = row.id == "SIDE-L-01"
			var distances: Array = [16, 14, 12, 10] if left else [10, 12, 14, 16]
			for distance: float in distances:
				var point: Vector3 = StadiumDugoutRecipe.rail_point(distance, 0, left)
				result.append(Vector2(point.x, point.z))
	return result


func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var points: PackedVector2Array = polygon()
	var original: StadiumRecipeBoundary = StadiumHeightBoundary.candidate("right_shelf")
	for index in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		for row: Dictionary in original.segments():
			if a.distance_to(Geometry2D.get_closest_point_to_segment(a, row.a, row.b)) > EPS \
				or b.distance_to(Geometry2D.get_closest_point_to_segment(b, row.a, row.b)) > EPS:
				continue
			var next: Dictionary = row.duplicate(true)
			next.a = a
			next.b = b
			if row.id in ["SIDE-R-01", "SIDE-L-01"]:
				_side(next, row.id == "SIDE-L-01")
			result.append(next)
			break
	return result


func signature() -> String:
	return JSON.stringify({"base": super.signature(),
		"height_recipe": StadiumHeightWallRecipes.VERSION,
		"prism_margin": 0.0, "step_resolution": "first-sphere-contact-or-clear-v1",
		"ball_radius": 0.0365, "query_layer": StadiumNpcAc02PublicBoundarySource.QUERY_MASK},
		"", true, true).sha256_text()

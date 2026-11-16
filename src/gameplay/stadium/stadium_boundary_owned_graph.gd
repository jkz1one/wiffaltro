class_name StadiumBoundaryOwnedGraph
extends StadiumDugoutBoundary
## Additive handed openings. The original field polygon and rear-foul semantics stay fixed.

var owned_sides: Dictionary = {}


static func create_owned(layout: Dictionary) -> StadiumBoundaryOwnedGraph:
	if not StadiumBoundaryItems.is_family(layout) or not layout.get("boundary") is Array:
		return null
	var result: StadiumBoundaryOwnedGraph = StadiumBoundaryOwnedGraph.new()
	result._shape = layout.get("walls", {}).get("back", {}).get("shape", "straight")
	if result._shape not in StadiumWallRecipes.SHAPES:
		return null
	for raw: Variant in layout.boundary:
		if (
			raw is Dictionary
			and raw.get("site", "") in ["DUGOUT-L", "DUGOUT-R"]
			and raw.get("item", "") in StadiumBoundaryItems.DUGOUTS
		):
			result.owned_sides[raw.site] = raw.item
	return result


func identity() -> String:
	return "PERIM-OWNED-BOUNDARY-" + _shape.to_upper().replace("_", "-") + "-v1"


func polygon() -> PackedVector2Array:
	var result: PackedVector2Array = []
	var original: StadiumRecipeBoundary = StadiumRecipeBoundary.create(_shape)
	for row: Dictionary in original.segments():
		result.append(row.a)
		var left: bool = row.id == "SIDE-L-01"
		if (
			row.id in ["SIDE-R-01", "SIDE-L-01"]
			and owned_sides.has("DUGOUT-L" if left else "DUGOUT-R")
		):
			var distances: Array = [16, 14, 12, 10] if left else [10, 12, 14, 16]
			for distance: float in distances:
				var point: Vector3 = StadiumDugoutRecipe.rail_point(distance, 0, left)
				result.append(Vector2(point.x, point.z))
	return result


func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var points: PackedVector2Array = polygon()
	var original: StadiumRecipeBoundary = StadiumRecipeBoundary.create(_shape)
	for index in range(points.size()):
		var a: Vector2 = points[index]
		var b: Vector2 = points[(index + 1) % points.size()]
		for row: Dictionary in original.segments():
			if (
				a.distance_to(Geometry2D.get_closest_point_to_segment(a, row.a, row.b)) > EPS
				or b.distance_to(Geometry2D.get_closest_point_to_segment(b, row.a, row.b)) > EPS
			):
				continue
			var next: Dictionary = row.duplicate(true)
			next.a = a
			next.b = b
			var left: bool = row.id == "SIDE-L-01"
			var site: String = "DUGOUT-L" if left else "DUGOUT-R"
			if row.id in ["SIDE-R-01", "SIDE-L-01"] and owned_sides.has(site):
				StadiumDugoutBoundary._side(next, left)
				if next.role == "DUGOUT_OPENING_DEAD" and owned_sides[site] == "ST-032":
					next.height = StadiumTimberDugoutContract.ENTRY_HEIGHT
			result.append(next)
			break
	return result


func signature() -> String:
	return (
		JSON
		. stringify({"base": super.signature(), "sides": owned_sides, "version": 1}, "", true, true)
		. sha256_text()
	)

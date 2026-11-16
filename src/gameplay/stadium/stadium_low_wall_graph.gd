class_name StadiumLowWallGraph
extends StadiumBoundaryOwnedGraph
## Same straight footprint and optional handed dugouts; only authored back segments change.
var profile: String = "low_flanks"


static func create_low(boundary_layout: Dictionary, selected: String) -> StadiumLowWallGraph:
	var base_graph: StadiumBoundaryOwnedGraph = StadiumBoundaryOwnedGraph.create_owned(
		boundary_layout
	)
	if (
		base_graph == null
		or base_graph._shape != "straight"
		or selected not in StadiumLowWallRecipes.PROFILES
	):
		return null
	var result: StadiumLowWallGraph = StadiumLowWallGraph.new()
	result.owned_sides = base_graph.owned_sides.duplicate(true)
	result.profile = selected
	return result


func identity() -> String:
	return "PERIM-OWNED-LOW46-" + profile.to_upper() + "-v1"


func polygon() -> PackedVector2Array:
	var original: PackedVector2Array = super.polygon()
	var result: PackedVector2Array = []
	for point: Vector2 in original:
		result.append(point)
		if point.is_equal_approx(Vector2(StadiumWallRecipes.BACK_X, StadiumWallRecipes.BACK_Z)):
			result.append(Vector2(StadiumLowWallRecipes.CENTER_HALF, StadiumWallRecipes.BACK_Z))
			result.append(Vector2(-StadiumLowWallRecipes.CENTER_HALF, StadiumWallRecipes.BACK_Z))
	return result


func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = super.segments()
	var back_index: int = 0
	for row: Dictionary in result:
		if row.role == "BACK_WALL_TERMINAL":
			back_index += 1
			row.id = "LOW46-BACK-%02d" % back_index
			var center: Vector2 = (row.a + row.b) * 0.5
			row.height = (
				StadiumLowWallRecipes.STANDARD
				if profile == "low_flanks" and absf(center.x) < StadiumLowWallRecipes.CENTER_HALF
				else StadiumLowWallRecipes.LOW
			)
	return result


func signature() -> String:
	return (
		JSON
		. stringify(
			{
				"base": super.signature(),
				"profile": profile,
				"recipes": StadiumLowWallRecipes.signature(),
				"version": 1
			},
			"",
			true,
			true
		)
		. sha256_text()
	)

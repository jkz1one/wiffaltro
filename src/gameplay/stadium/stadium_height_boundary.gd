class_name StadiumHeightBoundary
extends StadiumRecipeBoundary
## Isolated fixed-height graph; saved recipe factories intentionally still reject it.

var candidate_shape: String = "left_loft"


static func candidate(shape: String) -> StadiumHeightBoundary:
	if not StadiumHeightWallRecipes.SHAPES.has(shape):
		return null
	var result: StadiumHeightBoundary = StadiumHeightBoundary.new()
	result.candidate_shape = shape
	return result


func identity() -> String:
	return "PROTOTYPE-HEIGHT-" + candidate_shape.to_upper().replace("_", "-") + "-v1"


func polygon() -> PackedVector2Array:
	var points: PackedVector2Array = [Vector2(-8, -6), Vector2(8, -6), Vector2(24, 23.4),
		Vector2(StadiumWallRecipes.BACK_X, 23.4)]
	for section: Array in StadiumHeightWallRecipes.SHAPES[candidate_shape]:
		points.append(section[1])
	points.append(Vector2(-24, 23.4))
	return points


func segments() -> Array[Dictionary]:
	var result: Array[Dictionary] = super.segments()
	for index in range(3, result.size() - 2):
		result[index].height = StadiumHeightWallRecipes.SHAPES[candidate_shape][index - 3][2]
	return result


func signature() -> String:
	return JSON.stringify({"base": super.signature(), "prism_margin": 0.0,
		"step_resolution": "first-sphere-contact-or-clear-v1", "ball_radius": 0.0365,
		"query_layer": 16}, "", true, true).sha256_text()

class_name StadiumOffsetBoundary
extends StadiumRecipeBoundary
## Isolated standard-height asymmetric authoring candidate. Never accepted by saved factories.

const AUTHORING_VERSION: int = 1


func identity() -> String:
	return "PROTOTYPE-OFFSET-GABLES-v1"


func polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(-8, -6), Vector2(8, -6), Vector2(24, 23.4),
		Vector2(StadiumWallRecipes.BACK_X, 23.4), Vector2(13, 23), Vector2(6, 28),
		Vector2(-2, 28), Vector2(-8, 22.5), Vector2(-15, 25.5),
		Vector2(-StadiumWallRecipes.BACK_X, 23.4), Vector2(-24, 23.4)])

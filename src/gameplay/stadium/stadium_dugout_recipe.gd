class_name StadiumDugoutRecipe
extends RefCounted
## CI exact rail replacement. Removing art alone must never leave the old continuous collider.

const VERSION: int = 1
const ENVELOPE: AABB = AABB(Vector3(-3, 0, 0), Vector3(6, 2.7, 2.65))
const ROOF_UNDERSIDE: float = 2.4


static func rail_point(s: float, d: float, left: bool) -> Vector3:
	var along: Vector2 = Vector2(16, 29.4).normalized()
	var outward: Vector2 = Vector2(along.y, -along.x)
	var point: Vector2 = Vector2(8, -6) + s * along + d * outward
	return Vector3(-point.x if left else point.x, 0, point.y)


static func placement(left: bool) -> Transform3D:
	var tangent: Vector3 = rail_point(14, 0, left) - rail_point(13, 0, left)
	# Separate positive-handed authored frames; never mirror/scale a collision shape.
	var x: Vector3 = tangent if left else -tangent
	return Transform3D(Basis(x.normalized(), Vector3.UP, x.normalized().cross(Vector3.UP)),
		rail_point(13, 0, left))


static func panels(left: bool) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in StadiumWallRecipes.side(left):
		var center: Vector2 = (row.a + row.b) / 2
		var right: Vector2 = Vector2(absf(center.x), center.y)
		var s: float = (right - Vector2(8, -6)).dot(Vector2(16, 29.4).normalized())
		if s > 10 and s < 16:
			continue
		result.append(row)
	return result


static func fits(left: bool, land: String) -> bool:
	return land in ["expanded", "club", "mogul"] and StadiumProperty.contains(
		land, placement(left) * ENVELOPE)

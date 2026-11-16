class_name StadiumWaterfallLiveSites
extends RefCounted
## Explicit candidate site contract. Not an owned-layout upgrader or stock mutation.
const VERSION: int = 1
const SITE: String = "WF-LIVE-LF"
const CENTER: Vector3 = Vector3(-10.2, 0, 19.4)
const LIVE_UNITS: int = 4
const LAYOUT_VERSION: int = 45
const LEDGER_VERSION: int = 54


static func reservation() -> AABB:
	return Transform3D(Basis.IDENTITY, CENTER) * StadiumWaterfallLiveModels.reservation()


static func geometry_legal(
	tier: String, graph: StadiumRecipeBoundary, field: FieldDefinition, other_live_units: int
) -> bool:
	if (
		tier != "mogul"
		or graph == null
		or field == null
		or other_live_units != 0
		or CENTER != StadiumWaterfallLiveRoutes.CENTER
		or not StadiumProperty.contains(tier, reservation())
	):
		return false
	var reserve: AABB = reservation()
	var corners: Array[Vector2] = [
		Vector2(reserve.position.x, reserve.position.z),
		Vector2(reserve.end.x, reserve.position.z),
		Vector2(reserve.end.x, reserve.end.z),
		Vector2(reserve.position.x, reserve.end.z)
	]
	var rect: Rect2 = Rect2(corners[0], Vector2(reserve.size.x, reserve.size.z))
	if rect.intersects(StadiumSurfaceTerrain.PATCH, true):
		return false
	for corner: Vector2 in corners:
		if not graph.contains(corner) or not field.is_fair_point(Vector3(corner.x, 0, corner.y)):
			return false
	for index in range(4):
		for wall: Dictionary in graph.segments():
			if (
				StadiumLandscapeOwnedItems._segment_distance(
					corners[index], corners[(index + 1) % 4], wall.a, wall.b
				)
				<= StadiumRecipeBoundary.THICKNESS * 0.5
			):
				return false
	for index in range(9):
		if (
			field.is_fielder_anchor_available(index)
			and not StadiumWaterfallLiveRoutes.legal(field.fielder_anchor(index), graph)
		):
			return false
	return true

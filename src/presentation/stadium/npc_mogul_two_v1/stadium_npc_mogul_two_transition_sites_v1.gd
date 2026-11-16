class_name StadiumNpcMogulTwoTransitionSitesV1
extends RefCounted
## Working ground sites, no registry admission, purchase or dependent-layer socket.

const SITES: Array[String] = ["JOIN-R", "JOIN-L"]
const ITEMS: Array[String] = ["ST-085", "ST-088"]
const HEIGHT: float = 7.3
const MIN_T: float = 0.035
const MAX_T: float = 0.96
const MIN_U: float = 0.12
const MAX_U: float = 6.88


static func item(site: String) -> String:
	return ITEMS[SITES.find(site)] if site in SITES else ""


static func pose(_site: String) -> Transform3D:
	# Both independently authored world-shaped assets install at a positive identity pose.
	return Transform3D.IDENTITY


static func point(site: String, t: float, u: float, height: float = 0) -> Vector3:
	var left: bool = site == "JOIN-L"
	var arc: Vector3 = StadiumNpcMogulOneBowlV1.polar(18 + u, 105, 0)
	if left:
		arc.x = -arc.x
	var rail: Vector3 = StadiumNpcClubDugoutRecipeV1.rail_point(12, 3.5 + u, left)
	return arc.lerp(rail, t) + Vector3.UP * height


static func corners(site: String) -> PackedVector2Array:
	var result: PackedVector2Array = []
	for pair: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 7), Vector2(0, 7)]:
		var vertex: Vector3 = point(site, pair.x, pair.y)
		result.append(Vector2(vertex.x, vertex.z))
	return result


static func contains(site: String, vertex: Vector3) -> bool:
	if site not in SITES or vertex.y < -0.001 or vertex.y > HEIGHT + 0.001:
		return false
	var polygon: PackedVector2Array = corners(site)
	var probe: Vector2 = Vector2(vertex.x, vertex.z)
	var orientation: float = 1 if site == "JOIN-R" else -1
	for edge in range(4):
		var start: Vector2 = polygon[edge]
		var finish: Vector2 = polygon[(edge + 1) % 4]
		if orientation * (finish - start).cross(probe - start) > 0.001:
			return false
	return true

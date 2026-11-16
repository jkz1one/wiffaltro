class_name StadiumCurvedLowerSites
extends RefCounted
## Working ST-081 ground-only authoring sites; never an ownership or runtime registry.

const VERSION: int = 1
const SITES: Array[String] = ["BOWL-01", "BOWL-02", "BOWL-03", "BOWL-04", "BOWL-05"]
const GRAND_I: Array[String] = ["BOWL-02", "BOWL-03", "BOWL-04"]
const INNER: float = 18.0
const OUTER: float = 25.0
const HALF_ANGLE: float = 14.7
const HEIGHT: float = 5.3
const LOWER_BOUNDS: AABB = AABB(Vector3(-6.4, 0, 17.4), Vector3(12.8, HEIGHT, 7.6))


static func pose(site: String) -> Transform3D:
	if site not in SITES:
		return Transform3D.IDENTITY
	return Transform3D(Basis(Vector3.UP, deg_to_rad(120 + 30 * SITES.find(site))), Vector3.ZERO)


static func fits(site: String, land: String) -> bool:
	return site in SITES and land == "mogul" \
		and StadiumProperty.contains(land, pose(site) * LOWER_BOUNDS)


static func contains_local(point: Vector3, tolerance: float = 0.001) -> bool:
	var radius: float = Vector2(point.x, point.z).length()
	return radius >= INNER - tolerance and radius <= OUTER + tolerance \
		and absf(rad_to_deg(atan2(point.x, point.z))) <= HALF_ANGLE + tolerance \
		and point.y >= -tolerance and point.y <= HEIGHT + tolerance

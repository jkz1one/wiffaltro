class_name StadiumBaselineSites
extends RefCounted
## BA/BI baseline candidates. Ground sockets do not grant structural pieces or crowd income.

const VERSION: int = 1
const SITES: Array[String] = ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]
const LOWER_BOUNDS: AABB = AABB(Vector3(-3, 0, 0), Vector3(6, 7.4, 7))
const LOWER_ROOF_BOUNDS: AABB = AABB(Vector3(-3.25, 6, 0), Vector3(6.5, 2.64, 7))


static func pose(site: String) -> Transform3D:
	if site not in SITES:
		return Transform3D.IDENTITY
	var left: bool = site.begins_with("BASE-L")
	var result: Transform3D = StadiumDugoutRecipe.placement(left)
	result.origin = StadiumDugoutRecipe.rail_point(15 if site.ends_with("1") else 21, 3.5, left)
	return result


static func fits(site: String, land: String, roof: bool = false) -> bool:
	if site not in SITES or land not in ["club", "mogul"]:
		return false
	var bounds: AABB = LOWER_BOUNDS.merge(LOWER_ROOF_BOUNDS) if roof else LOWER_BOUNDS
	return StadiumProperty.contains(land, pose(site) * bounds)

class_name StadiumNpcAc02PublicLightSites
extends RefCounted
## AC-02-only dormant CM2 poses. No new shared profile, light source or night admission.

const VERSION: int = 1
const PRESET: String = "LIGHT-CLUB-4X038-v1"
const PROFILE: String = "CLUB4-LOW"
const SITES: Dictionary = {
	"CLIGHT-HL": Vector3(-30, 0, -16), "CLIGHT-HR": Vector3(30, 0, -16),
	"CLIGHT-OL": Vector3(-32, 0, 38), "CLIGHT-OR": Vector3(32, 0, 38)}
const TARGETS: Dictionary = {
	"CLIGHT-HL": Vector3(-8, 1.5, 12), "CLIGHT-HR": Vector3(8, 1.5, 12),
	"CLIGHT-OL": Vector3(-8, 1.5, 15), "CLIGHT-OR": Vector3(8, 1.5, 15)}


static func create(site: String) -> Node3D:
	if not SITES.has(site):
		return null
	var root: Node3D = StadiumFourHeadTowerModels.create()
	if not place(root, site):
		root.free()
		return null
	return root


static func place(root: Node3D, site: String, profile: String = PROFILE) -> bool:
	if root == null or profile != PROFILE or not SITES.has(site) \
		or root.get_meta("stadium_item", "") != "ST-038" \
		or not root.get_meta("working_geometry_only", false):
		return false
	var ancestor: Node = root.get_parent()
	while ancestor != null:
		if ancestor is Node3D and ancestor.transform != Transform3D.IDENTITY:
			return false
		ancestor = ancestor.get_parent()
	for index in range(4):
		if not root.has_node("Visual/Head%d" % index):
			return false
	root.transform = pose(site)
	StadiumFourHeadTowerModels._aim(root, root.transform.affine_inverse() * TARGETS[site])
	root.set_meta("site", site)
	root.set_meta("candidate_site", site)
	root.set_meta("candidate_preset", PRESET)
	root.set_meta("aim_profile", profile)
	root.set_meta("reference_target", TARGETS[site])
	root.set_meta("club_site_version", VERSION)
	return true


static func pose(site: String) -> Transform3D:
	if not SITES.has(site):
		return Transform3D.IDENTITY
	var toward: Vector3 = TARGETS[site] - SITES[site]
	return Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)), SITES[site])


static func head_rays(site: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not SITES.has(site):
		return result
	var transform: Transform3D = pose(site)
	var target: Vector3 = transform.affine_inverse() * TARGETS[site]
	for index in range(4):
		var center: Vector3 = Vector3(
			StadiumFourHeadTowerModels.HEAD_X[index], StadiumFourHeadTowerModels.HEAD_HEIGHT, 0)
		var direction: Vector3 = (target - center).normalized()
		var origin: Vector3 = transform * (center + direction * 0.139)
		direction = (transform.basis * direction).normalized()
		result.append({"id": "HEAD-%d" % (index + 1), "origin": [origin.x, origin.y, origin.z],
			"direction": [direction.x, direction.y, direction.z]})
	return result

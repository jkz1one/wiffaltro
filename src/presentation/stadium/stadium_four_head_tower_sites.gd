class_name StadiumFourHeadTowerSites
extends RefCounted
## Six fixed authoring sites. A reference aim is not a certified coverage solution.

const PRESET: String = "LIGHT-MOGUL-6X038-v1"
const PROFILE: String = "MOGUL6-STANDARD"
const SITES: Dictionary = {
	"MLIGHT-HL": Vector3(-46, 0, -22), "MLIGHT-HR": Vector3(46, 0, -22),
	"MLIGHT-ML": Vector3(-47, 0, 14), "MLIGHT-MR": Vector3(47, 0, 14),
	"MLIGHT-OL": Vector3(-46, 0, 50), "MLIGHT-OR": Vector3(46, 0, 50),
}
const TARGETS: Dictionary = {
	"MLIGHT-HL": Vector3(-10, 1.5, 10), "MLIGHT-HR": Vector3(10, 1.5, 10),
	"MLIGHT-ML": Vector3(-6, 1.5, 15), "MLIGHT-MR": Vector3(6, 1.5, 15),
	"MLIGHT-OL": Vector3(-10, 1.5, 18), "MLIGHT-OR": Vector3(10, 1.5, 18),
}


static func place(root: Node3D, site: String, profile: String = PROFILE) -> bool:
	if root == null or profile != PROFILE or not SITES.has(site) \
		or root.get_meta("stadium_item", "") != "ST-038" \
		or not root.get_meta("working_geometry_only", false):
		return false
	# These poses and dormant rays are field-frame data. Until an assembly adapter is
	# qualified, require an identity ancestor chain rather than silently moving sites.
	var ancestor: Node = root.get_parent()
	while ancestor != null:
		if ancestor is Node3D and ancestor.transform != Transform3D.IDENTITY:
			return false
		ancestor = ancestor.get_parent()
	for index in range(4):
		if not root.has_node("Visual/Head%d" % index):
			return false
	var toward: Vector3 = TARGETS[site] - SITES[site]
	root.transform = Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)), SITES[site])
	StadiumFourHeadTowerModels._aim(root, root.transform.affine_inverse() * TARGETS[site])
	root.set_meta("site", site)
	root.set_meta("candidate_preset", PRESET)
	root.set_meta("aim_profile", profile)
	root.set_meta("reference_target", TARGETS[site])
	return true

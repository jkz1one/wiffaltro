class_name StadiumPremiumLightTowerSites
extends RefCounted
## Four fixed authoring sites. A reference aim is not a certified coverage solution.

const PRESET: String = "LIGHT-MOGUL-4X076-v1"
const PROFILE: String = "MOGUL4-PREMIUM"
const SITES: Dictionary = {
	"PLIGHT-HL": Vector3(-46, 0, -22), "PLIGHT-HR": Vector3(46, 0, -22),
	"PLIGHT-OL": Vector3(-46, 0, 50), "PLIGHT-OR": Vector3(46, 0, 50),
}
const TARGETS: Dictionary = {
	"PLIGHT-HL": Vector3(-8, 1.5, 12), "PLIGHT-HR": Vector3(8, 1.5, 12),
	"PLIGHT-OL": Vector3(-8, 1.5, 18), "PLIGHT-OR": Vector3(8, 1.5, 18),
}


static func place(root: Node3D, site: String, profile: String = PROFILE) -> bool:
	if root == null or profile != PROFILE or not SITES.has(site) \
		or root.get_meta("stadium_item", "") != "ST-076" \
		or not root.get_meta("working_geometry_only", false):
		return false
	# These poses and dormant rays are field-frame data. Until an assembly adapter is
	# qualified, require an identity ancestor chain rather than silently moving sites.
	var ancestor: Node = root.get_parent()
	while ancestor != null:
		if ancestor is Node3D and ancestor.transform != Transform3D.IDENTITY:
			return false
		ancestor = ancestor.get_parent()
	for index in range(8):
		if not root.has_node("Visual/Head%d" % index):
			return false
	# The four shared ground sites cannot host both exact item identities.
	# This authoring helper checks sibling assemblies; it is not a production installer.
	if root.get_parent() != null:
		for sibling: Node in root.get_parent().get_children():
			if sibling == root or not sibling is Node3D:
				continue
			if sibling.get_meta("stadium_item", "") in ["ST-038", "ST-076"] \
				and sibling.has_meta("site") \
				and sibling.position.distance_to(SITES[site]) < 3.5:
				return false
	var toward: Vector3 = TARGETS[site] - SITES[site]
	root.transform = Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)), SITES[site])
	StadiumPremiumLightTowerModels._aim(root, root.transform.affine_inverse() * TARGETS[site])
	root.set_meta("site", site)
	root.set_meta("candidate_preset", PRESET)
	root.set_meta("aim_profile", profile)
	root.set_meta("reference_target", TARGETS[site])
	return true

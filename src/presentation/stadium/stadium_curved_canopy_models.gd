class_name StadiumCurvedCanopyModels
extends RefCounted
## One separately purchased ST-084 upper roof. No lower mount/remount or activation.

const VERSION: int = 1


static func create(lower: Node3D, concourse: Node3D, upper: Node3D,
	site: String) -> Node3D:
	if not StadiumCurvedCanopySites.valid_hosts(lower, concourse, upper, site):
		return null
	var root: Node3D = StadiumCurvedStackModels._root("ST-084")
	StadiumCurvedStackModels._bind(root, lower, site, StadiumCurvedCanopySites.INTERFACE)
	root.set_meta("concourse_instance", concourse.get_instance_id())
	root.set_meta("upper_instance", upper.get_instance_id())
	root.set_meta("roof_state", "BOWL-UPPER-ROOF-v1")
	for side: int in [-1, 1]:
		var angle: float = side * 12.7 - 0.55
		# Exact upper-owned rear pylon top is a physical contact, never penetration.
		StadiumCurvedStackModels._band(root, "RoofPost%d" % side,
			25.20, 26.00, angle, angle + 1.1, 8.15, 10.25, "64796e")
		StadiumCurvedStackModels._band(root, "RoofBeam%d" % side,
			19.90, 26.30, angle, angle + 1.1, 9.80, 10.25, "64796e")
		var end: float = -14.7 if side == -1 else 14.05
		StadiumCurvedStackModels._band(root, "FinishedRoofEnd%d" % side,
			19.90, 26.30, end, end + 0.65, 10.10, 10.65, "c5b38d")
	StadiumCurvedStackModels._band(root, "RoofSlab", 19.90, 26.30,
		-14.7, 14.7, 10.25, 10.55, "507969")
	StadiumCurvedStackModels._band(root, "FrontRoofFascia", 19.90, 20.10,
		-14.7, 14.7, 10.10, 10.65, "c5b38d")
	StadiumCurvedStackModels._band(root, "RearRoofFascia", 26.10, 26.30,
		-14.7, 14.7, 10.10, 10.65, "c5b38d")
	return root

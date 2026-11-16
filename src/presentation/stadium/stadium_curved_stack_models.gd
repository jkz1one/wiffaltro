class_name StadiumCurvedStackModels
extends RefCounted
## Purchased layers remain separate; no canopy, transition, stock or activation.

const VERSION: int = 1
const HALF: float = 14.7
const ROWS: int = 4
const ANGLES: Array[float] = [-10.0, -6.0, 6.0, 10.0]


static func create_concourse(lower: Node3D, site: String) -> Node3D:
	if not StadiumCurvedStackSites.valid_lower(lower, site) \
		or StadiumCurvedStackSites.occupied(lower, "ST-083"):
		return null
	var root: Node3D = _concourse()
	_bind(root, lower, site, StadiumCurvedStackSites.INTERFACE)
	return root


static func create_upper(lower: Node3D, concourse: Node3D, site: String,
	occupied: bool = true) -> Node3D:
	if not StadiumCurvedStackSites.valid_lower(lower, site) \
		or not is_instance_valid(concourse) or not concourse.is_inside_tree():
		return null
	if concourse.get_parent() != lower.get_parent() \
		or not StadiumCurvedStackSites.valid_pose(concourse, site) \
		or concourse.get_meta("stadium_item", "") != "ST-083" \
		or concourse.get_meta("model_version", 0) != VERSION \
		or concourse.get_meta("lower_instance", 0) != lower.get_instance_id() \
		or concourse.get_meta("interface", "") != StadiumCurvedStackSites.INTERFACE \
		or StadiumCurvedStackSites.occupied(lower, "ST-082"):
		return null
	var reference: Node3D = _concourse()
	var valid: bool = StadiumCurvedStackSites.geometry_signature(concourse) \
		== StadiumCurvedStackSites.geometry_signature(reference)
	reference.free()
	if not valid:
		return null
	var root: Node3D = _upper(occupied)
	_bind(root, lower, site, StadiumCurvedStackSites.UPPER_INTERFACE)
	root.set_meta("concourse_instance", concourse.get_instance_id())
	return root


static func _bind(root: Node3D, lower: Node3D, site: String, interface: String) -> void:
	root.transform = StadiumCurvedLowerSites.pose(site)
	root.set_meta("lower_instance", lower.get_instance_id())
	root.set_meta("site", site)
	root.set_meta("interface", interface)


static func _root(item: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = item.replace("-", "") + "CurvedWorking"
	root.set_meta("stadium_item", item)
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	return root


static func _concourse() -> Node3D:
	var root: Node3D = _root("ST-083")
	_band(root, "GroundedRearPlinth", 25.05, 27.80, -HALF, HALF, 0, 4.40, "7b8981")
	_band(root, "ConcourseDeck", 25.05, 27.80, -HALF, HALF, 4.40, 4.55, "c5b38d")
	# Contact only: saddle underside sits on the existing rear-rim top, never cuts it.
	_band(root, "RearSaddle", 24.68, 25.30, -1.5, 1.5, 4.40, 4.55, "c5b38d")
	_band(root, "RearParapet", 27.65, 27.85, -HALF, HALF, 4.55, 5.35, "bbc2ae")
	for side: int in [-1, 1]:
		var a: float = -HALF if side == -1 else HALF - 0.65
		_band(root, "FinishedEnd%d" % side, 25.05, 27.85, a, a + 0.65,
			4.55, 5.35, "bbc2ae")
	_band(root, "RearEntryInlay", 27.80, 27.84, -1.5, 1.5, 0.10, 2.25, "344b43", false)
	# Stylized closed access mass: no implied traversable interior or simulation.
	for step in range(8):
		var a: float = -7.0 + step * 1.75
		_band(root, "GroundAccessAccent%d" % step, 27.80, 27.86, a, a + 1.5,
			0.05, 0.45 + step * 0.5, "a5b3a1", false)
	return root


static func _upper(occupied: bool) -> Node3D:
	var root: Node3D = _root("ST-082")
	root.set_meta("represented_seats", ROWS * ANGLES.size())
	for side: int in [-1, 1]:
		var a: float = side * 12.7 - 0.55
		_band(root, "RearPylon%d" % side, 25.20, 26.0, a, a + 1.1, 4.55, 8.15, "64796e")
		_band(root, "Cantilever%d" % side, 20.25, 26.0, a, a + 1.1, 5.80, 6.30, "64796e")
	for row in range(ROWS):
		var inner: float = 20.25 + row * 1.10
		var deck: float = 6.50 + row * 0.45
		_band(root, "UpperDeck%d" % row, inner, inner + 1.10, -HALF, HALF,
			deck - 0.20, deck, "89968a")
		for side: int in [-1, 1]:
			var a: float = side * 12.7 - 0.55
			_band(root, "DeckRib%d_%d" % [row, side], inner, inner + 1.10,
				a, a + 1.1, 6.30, deck, "64796e")
			var start: float = -12.0 if side == -1 else 2.8
			var end: float = -2.8 if side == -1 else 12.0
			_band(root, "UpperBench%d_%d" % [row, side], inner + 0.3, inner + 0.75,
				start, end, deck + 0.37, deck + 0.45, "507969", false)
			_band(root, "UpperBack%d_%d" % [row, side], inner + 0.75, inner + 0.83,
				start, end, deck + 0.43, deck + 0.83, "507969", false)
			_band(root, "BenchPlinth%d_%d" % [row, side], inner + 0.43, inner + 0.60,
				start, end, deck, deck + 0.37, "56645b", false)
			var cap: float = -HALF if side == -1 else HALF - 0.65
			_band(root, "FinishedEnd%d_%d" % [row, side], inner, inner + 1.10,
				cap, cap + 0.65, deck, deck + 0.85, "bbc2ae")
		_band(root, "UpperAisle%d" % row, inner, inner + 1.10, -1.6, 1.6,
			deck, deck + 0.035, "c5b38d", false)
		if occupied:
			for column in range(ANGLES.size()):
				var index: int = row * ANGLES.size() + column
				var point: Vector3 = StadiumCurvedLowerModels.polar(inner + 0.5,
					ANGLES[column], deck + 0.46)
				StadiumSeatingModels._person(root, index, point)
				var anchor: Node3D = root.get_node("Visual/CrowdAnchor%d" % index)
				anchor.rotation.y = deg_to_rad(ANGLES[column]) + PI
				anchor.set_meta("rest_position", point)
	_band(root, "FrontFascia", 20.25, 20.45, -HALF, HALF, 6.30, 7.15, "bbc2ae")
	_band(root, "RearUpperParapet", 24.45, 24.65, -HALF, HALF, 7.85, 8.70, "bbc2ae")
	# Owned upper access spine sits behind frozen lower; each riser rests on concourse.
	for step in range(8):
		var inner: float = 27.45 - (step + 1) * 0.35
		_band(root, "UpperAccess%d" % step, inner, inner + 0.35, -1.5, 1.5,
			4.55 if inner >= 25.05 else 5.80, 4.95 + step * 0.415, "a5b3a1")
	return root


static func _band(root: Node3D, id: String, inner: float, outer: float,
	start: float, end: float, bottom: float, top: float, color: String,
	solid: bool = true) -> void:
	StadiumCurvedLowerModels._band(root, id, inner, outer, start, end,
		bottom, top, Color(color), solid)
	if solid:
		root.get_node("Collision/" + id).set_meta("stadium_item", root.get_meta("stadium_item"))

class_name StadiumStraightStackModels
extends RefCounted
## Working purchased ST-031/ST-030 layers. No roof/service/ownership activation.

const VERSION: int = 1
const ROWS: int = 4
const COLUMNS: Array[float] = [-2.0, -0.9, 0.2, 1.3]


static func create_concourse(lower: Node3D, site: String) -> Node3D:
	if not StadiumStraightStackSites.valid_lower(lower, site) \
		or StadiumStraightStackSites.conflicting(lower, site) \
		or StadiumStraightStackSites.occupied(lower, "ST-031", site):
		return null
	var root: Node3D = _concourse()
	_bind(root, lower, site, StadiumStraightStackSites.INTERFACE)
	return root


static func create_upper(lower: Node3D, concourse: Node3D, site: String,
	occupied: bool = true) -> Node3D:
	if not StadiumStraightStackSites.valid_lower(lower, site) \
		or StadiumStraightStackSites.conflicting(lower, site) \
		or not is_instance_valid(concourse) or not concourse.is_inside_tree():
		return null
	if concourse.get_parent() != lower.get_parent() \
		or not StadiumStraightStackSites.valid_pose(concourse, site) \
		or concourse.get_meta("stadium_item", "") != "ST-031" \
		or concourse.get_meta("model_version", 0) != VERSION \
		or concourse.get_meta("lower_instance", 0) != lower.get_instance_id() \
		or concourse.get_meta("site", "") != site \
		or concourse.get_meta("interface", "") != StadiumStraightStackSites.INTERFACE \
		or StadiumStraightStackSites.occupied(lower, "ST-030", site):
		return null
	var reference: Node3D = _concourse()
	var actual: String = StadiumStraightStackSites.geometry_signature(concourse)
	var valid: bool = not actual.is_empty() \
		and actual == StadiumStraightStackSites.geometry_signature(reference)
	reference.free()
	if not valid:
		return null
	var root: Node3D = _upper(occupied)
	_bind(root, lower, site, StadiumStraightStackSites.UPPER_INTERFACE)
	root.set_meta("concourse_instance", concourse.get_instance_id())
	return root


static func _bind(root: Node3D, lower: Node3D, site: String, interface: String) -> void:
	root.transform = StadiumBaselineSites.pose(site)
	root.set_meta("lower_instance", lower.get_instance_id())
	root.set_meta("site", site)
	root.set_meta("interface", interface)


static func _root(item: String) -> Node3D:
	var root: Node3D = StadiumBaselineStandModels._root(item)
	root.name = item.replace("-", "") + "StraightWorking"
	root.set_meta("model_version", VERSION)
	root.set_meta("authoring_status", "Working")
	return root


static func _concourse() -> Node3D:
	var root: Node3D = _root("ST-031")
	_box(root, "GroundedRearPlinth", Vector3(0, 3, 8.45), Vector3(5.9, 6, 2.8), "7b8981")
	_box(root, "ConcourseDeck", Vector3(0, 6.075, 8.425), Vector3(5.9, 0.15, 2.85), "c5b38d")
	# Only the stair-side saddle enters z<7: underside touches existing EntryStep39 at y6.
	_box(root, "RearSaddle", Vector3(2.65, 6.075, 7.05), Vector3(0.5, 0.15, 0.3), "c5b38d")
	_box(root, "RearParapet", Vector3(0, 6.55, 9.8), Vector3(5.9, 0.8, 0.15), "bbc2ae")
	for side: int in [-1, 1]:
		_box(root, "FinishedEnd%d" % side, Vector3(side * 2.875, 6.55, 8.425),
			Vector3(0.15, 0.8, 2.85), "bbc2ae")
	_box(root, "RearEntryInlay", Vector3(0, 1.2, 9.86), Vector3(0.95, 2.2, 0.02), "344b43", false)
	for step in range(8):
		_box(root, "GroundAccessAccent%d" % step, Vector3(-2.25 + step * 0.55,
			0.25 + step * 0.34, 9.87), Vector3(0.45, 0.08, 0.02), "c5b38d", false)
	return root


static func _upper(occupied: bool) -> Node3D:
	var root: Node3D = _root("ST-030")
	root.set_meta("represented_seats", ROWS * COLUMNS.size())
	for side: int in [-1, 1]:
		_box(root, "RearPylon%d" % side, Vector3(side * 2.6, 8.625, 7.7),
			Vector3(0.4, 4.95, 0.8), "64796e")
		_box(root, "Cantilever%d" % side, Vector3(side * 2.6, 8.1, 5.05),
			Vector3(0.4, 0.4, 6.1), "64796e")
	for row in range(ROWS):
		var z: float = 2.0 + row * 1.25
		var deck: float = 8.5 + row * 0.8
		_box(root, "UpperDeck%d" % row, Vector3(0, deck - 0.1, z + 0.625),
			Vector3(5.9, 0.2, 1.25), "89968a")
		for side: int in [-1, 1]:
			_box(root, "DeckRib%d_%d" % [row, side], Vector3(side * 2.6,
				(8.3 + deck) / 2, z + 0.625), Vector3(0.4, deck - 8.3, 1.25), "64796e")
			_box(root, "FinishedEnd%d_%d" % [row, side],
				Vector3(side * 2.875, deck + 0.35, z + 0.625), Vector3(0.15, 0.7, 1.25), "bbc2ae")
		_box(root, "UpperBench%d" % row, Vector3(-0.35, deck + 0.41, z + 0.5),
			Vector3(4.0, 0.08, 0.42), "507969", false)
		_box(root, "UpperBack%d" % row, Vector3(-0.35, deck + 0.64, z + 0.74),
			Vector3(4.0, 0.46, 0.06), "507969", false)
		_box(root, "BenchPlinth%d" % row, Vector3(-0.35, deck + 0.185, z + 0.5),
			Vector3(4.0, 0.37, 0.16), "56645b", false)
		_box(root, "UpperAisle%d" % row, Vector3(2.1, deck + 0.015, z + 0.625),
			Vector3(0.55, 0.03, 1.25), "c5b38d", false)
		if occupied:
			for column in range(COLUMNS.size()):
				var index: int = row * COLUMNS.size() + column
				StadiumSeatingModels._person(root, index,
					Vector3(COLUMNS[column], deck + 0.46, z + 0.5))
				root.get_node("Visual/CrowdAnchor%d" % index).rotation.y = PI
	_box(root, "FrontFascia", Vector3(0, 8.65, 2.06), Vector3(5.9, 0.7, 0.12), "bbc2ae")
	_box(root, "RearUpperParapet", Vector3(-0.575, 11.275, 6.925),
		Vector3(4.75, 0.75, 0.15), "bbc2ae")
	_box(root, "RearAccessEnd", Vector3(2.675, 11.275, 6.925),
		Vector3(0.55, 0.75, 0.15), "bbc2ae")
	for step in range(10):
		var top: float = 6.625 + step * 0.475
		_box(root, "UpperAccess%d" % step, Vector3(2.1, (6.15 + top) / 2,
			9.375 - step * 0.25), Vector3(0.55, top - 6.15, 0.25), "a5b3a1")
	return root


static func _box(root: Node3D, id: String, point: Vector3, size: Vector3,
	color: String, solid: bool = true) -> void:
	StadiumSeatingModels._box(root, id, point, size, Color(color), solid)
	if solid:
		var shape: CollisionShape3D = root.get_node("Collision/" + id).get_child(0)
		shape.shape.margin = 0.0

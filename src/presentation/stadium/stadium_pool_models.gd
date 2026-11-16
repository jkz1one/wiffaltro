class_name StadiumPoolModels
extends RefCounted
## Same ST-006 art for live/scenery. The annular wall is hollow; water is never a solid ball body.

const VERSION: int = 1
const SHELL: Color = Color("507f96")
const LINER: Color = Color("345d73")
const RIM: Color = Color("a5b5ac")
const WATER: Color = Color("54877a")


static func create(role: String = StadiumPoolContract.SCENERY) -> Node3D:
	if role not in [StadiumPoolContract.LIVE, StadiumPoolContract.SCENERY]:
		return null
	var root: Node3D = Node3D.new()
	root.name = "PoolCandidate"
	root.set_meta("stadium_item", "ST-006")
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_id", StadiumPoolContract.ID)
	root.set_meta("placement_role", role)
	root.set_meta("stadium_candidate_only", true)
	root.set_meta("water_award_active", false)
	root.set_meta("runtime_adapter", "NOT_IMPLEMENTED")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	var surface_role: String = (
		"LIVE_RICOCHET" if role == StadiumPoolContract.LIVE else "DECORATIVE_AFTER_TERMINAL"
	)
	for id: String in StadiumPoolContract.SURFACES:
		var faces: PackedVector3Array = StadiumPoolContract.faces(id)
		var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		shape.margin = 0
		var color: Color = RIM if id == "POOL_RIM" else LINER if id == "POOL_INNER_WALL" else SHELL
		StadiumStarterModels._part(root, id, Vector3.ZERO, _mesh(faces), shape, color, surface_role)
		root.get_node("Collision/" + id).get_child(0).name = "Shape"
		root.get_node("Collision/" + id).set_meta("ball_surface", &"stadium_pool_candidate")
	_ladder(root, surface_role)
	_water(root, role)
	return root


static func _mesh(faces: PackedVector3Array) -> ArrayMesh:
	var normals: PackedVector3Array = []
	for index: int in range(0, faces.size(), 3):
		var normal: Vector3 = -(
			(faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).normalized()
		)
		normals.append_array(PackedVector3Array([normal, normal, normal]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = faces
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _ladder(root: Node3D, role: String) -> void:
	var box: AABB = StadiumPoolContract.LADDER
	# A closed shallow stair body prevents rung gaps becoming ball traps.
	# This deliberately visible backing matches the simple closed collision proxy.
	StadiumStarterModels._box(root, "POOL_LADDER", box.get_center(), box.size, LINER, role)
	root.get_node("Collision/POOL_LADDER").get_child(0).name = "Shape"
	root.get_node("Collision/POOL_LADDER").get_child(0).shape.margin = 0
	root.get_node("Collision/POOL_LADDER").set_meta("ball_surface", &"stadium_pool_candidate")
	for side: int in [-1, 1]:
		var rail: BoxMesh = BoxMesh.new()
		rail.size = Vector3(0.035, 1.45, 0.035)
		StadiumStarterModels._mesh(
			root, "LadderRail%d" % side, Vector3(2.4325, 0.725, side * 0.3325), rail, RIM
		)
	for step: int in range(5):
		var tread: BoxMesh = BoxMesh.new()
		tread.size = Vector3(0.045, 0.045, 0.63)
		StadiumStarterModels._mesh(
			root, "LadderTread%d" % step, Vector3(2.4275, 0.16 + step * 0.27, 0), tread, RIM
		)


static func _water(root: Node3D, role: String) -> void:
	var faces: PackedVector3Array = []
	var height: float = StadiumPoolContract.WATER_HEIGHT
	for index: int in range(StadiumPoolContract.SEGMENTS):
		faces.append_array(
			PackedVector3Array(
				[
					Vector3(0, height, 0),
					StadiumPoolContract.point(StadiumPoolContract.INNER_RADIUS, height, index),
					StadiumPoolContract.point(StadiumPoolContract.INNER_RADIUS, height, index + 1)
				]
			)
		)
	StadiumStarterModels._mesh(root, "WaterVisual", Vector3.ZERO, _mesh(faces), WATER)
	if role != StadiumPoolContract.LIVE:
		return
	var volume: Area3D = Area3D.new()
	volume.name = StadiumPoolContract.WATER_VOLUME_ID
	volume.position.y = height / 2
	volume.collision_layer = 0
	volume.collision_mask = 0
	volume.monitoring = false
	volume.monitorable = false
	volume.set_meta("volume_id", StadiumPoolContract.WATER_VOLUME_ID)
	volume.set_meta("volume_role", "WATER_GEOMETRY_ONLY")
	volume.set_meta("water_award_active", false)
	volume.set_meta("runtime_adapter", "NOT_IMPLEMENTED")
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "WaterGeometry"
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = StadiumPoolContract.INNER_RADIUS
	cylinder.height = height
	cylinder.margin = 0
	collider.shape = cylinder
	volume.add_child(collider)
	root.add_child(volume)

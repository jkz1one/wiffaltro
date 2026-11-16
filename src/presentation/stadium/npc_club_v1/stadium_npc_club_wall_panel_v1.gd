class_name StadiumNpcClubWallPanelV1
extends RefCounted
## Retained AC-01/r1 correspondence copy; never a current authoring dependency.
## Original: src/presentation/stadium/stadium_wall_panel_models.gd
## Original fixed-size panel meshes. Local +Z faces the field; supports extend outward.

const VERSION: int = 2
const LENGTHS: Dictionary = {"full": 2.0, "straight_end": 0.519454636569,
	"angled_end": 1.809226694579586, "side_end": 1.47177915797127,
	"return_end": 0.480545363431}
const SIDE_IDS: Array[String] = ["ST-022", "ST-023"]


static func dimensions(item: String, span: String) -> Vector3:
	var back: bool = StadiumNpcClubWallRecipesV1.BACK_IDS.has(item)
	if not back and not SIDE_IDS.has(item):
		return Vector3.ZERO
	if not LENGTHS.has(span):
		return Vector3.ZERO
	if span != "full" and ((back and span not in ["straight_end", "angled_end"])
		or (not back and span not in ["side_end", "return_end"])):
		return Vector3.ZERO
	return Vector3(LENGTHS[span], 3.25 if back else 1.2, 0.35)


static func create(item: String, span: String) -> Node3D:
	var size: Vector3 = dimensions(item, span)
	if size == Vector3.ZERO:
		return null
	var root: Node3D = Node3D.new()
	root.name = "WallPanel"
	root.set_meta("wall_item", item)
	root.set_meta("wall_span", span)
	root.set_meta("wall_model_version", VERSION)
	var visual: Node3D = Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	match item:
		"ST-065": _padding(visual, size)
		"ST-077": _brick(visual, size)
		"ST-078": _chain(visual, size)
		_: _wood(visual, size)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "PanelCollision"
	body.collision_layer = 1
	body.collision_mask = 2
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = Vector3(0, size.y / 2, -size.z / 2)
	body.add_child(collision)
	root.add_child(body)
	return root


static func _wood(root: Node3D, size: Vector3) -> void:
	# Recessed seam backing avoids coplanar dark strips fighting the painted face.
	_box(root, Vector3(size.x, size.y, 0.12), Vector3(0, size.y / 2, -0.066), "345d73")
	var count: int = maxi(1, floori(size.x / 0.34))
	var width: float = size.x / count
	for index in range(count):
		_box(root, Vector3(width - 0.008, size.y, 0.006),
			Vector3(-size.x / 2 + (index + 0.5) * width, size.y / 2, -0.003), "507f96")
	for x: float in [-size.x / 2 + 0.05, size.x / 2 - 0.05]:
		_box(root, Vector3(0.1, size.y, 0.23), Vector3(x, size.y / 2, -0.235), "866340")
	for y: float in [0.10, size.y - 0.10]:
		_box(root, Vector3(size.x, 0.14, 0.10), Vector3(0, y, -0.17), "a67d50")


static func _padding(root: Node3D, size: Vector3) -> void:
	_box(root, Vector3(size.x, size.y, 0.15), Vector3(0, size.y / 2, -0.275), "444e55")
	var count: int = maxi(1, ceili(size.x / 0.5))
	var width: float = size.x / count
	for index in range(count):
		_box(root, Vector3(width - 0.012, size.y - 0.048, 0.20),
			Vector3(-size.x / 2 + (index + 0.5) * width, size.y / 2, -0.10), "244953")
	for y: float in [0.012, size.y - 0.012]:
		_box(root, Vector3(size.x, 0.024, 0.2), Vector3(0, y, -0.10), "19343d")


static func _brick(root: Node3D, size: Vector3) -> void:
	_box(root, Vector3(size.x, size.y, size.z - 0.016),
		Vector3(0, size.y / 2, -(size.z + 0.016) / 2), "acaaa0")
	var rows: int = ceili(size.y / 0.13)
	var height: float = size.y / rows
	var transforms: Array[Transform3D] = []
	for row in range(rows):
		var x: float = -size.x / 2 - (0.14 if row % 2 else 0.0)
		while x < size.x / 2:
			var low: float = maxf(x, -size.x / 2) + 0.005
			var high: float = minf(x + 0.28, size.x / 2) - 0.005
			if high > low:
				transforms.append(Transform3D(Basis.from_scale(Vector3(high - low,
					height - 0.01, 0.015)), Vector3((low + high) / 2,
					(row + 0.5) * height, -0.0075)))
			x += 0.28
	# One instanced draw for all original brick faces, not one draw per brick.
	_batch(root, transforms, "965b47")


static func _chain(root: Node3D, size: Vector3) -> void:
	for x: float in [-size.x / 2 + 0.035, size.x / 2 - 0.035]:
		_box(root, Vector3(0.07, size.y, 0.10), Vector3(x, size.y / 2, -0.05), "667477")
	for y: float in [0.035, size.y - 0.035]:
		_box(root, Vector3(size.x, 0.07, 0.10), Vector3(0, y, -0.05), "667477")
	var transforms: Array[Transform3D] = []
	for slope: float in [-1.0, 1.0]:
		for index in range(-ceili(size.x / 0.12), ceili((size.y + size.x) / 0.12)):
			var intercept: float = index * 0.12
			var low: float = maxf(-size.x / 2 + 0.04,
				minf((0.04 - intercept) / slope, (size.y - 0.04 - intercept) / slope))
			var high: float = minf(size.x / 2 - 0.04,
				maxf((0.04 - intercept) / slope, (size.y - 0.04 - intercept) / slope))
			if high <= low:
				continue
			var a: Vector3 = Vector3(low, slope * low + intercept, -0.055)
			var b: Vector3 = Vector3(high, slope * high + intercept, -0.055)
			var axis: Vector3 = a.direction_to(b)
			var basis: Basis = Basis(axis, Vector3(-axis.y, axis.x, 0), Vector3.BACK)
			transforms.append(Transform3D(basis.scaled_local(
				Vector3(a.distance_to(b), 0.008, 0.008)), (a + b) / 2))
	_batch(root, transforms, "849293")


static func _box(root: Node3D, size: Vector3, at: Vector3, color: String) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = _material(color)
	root.add_child(mesh)


static func _batch(root: Node3D, transforms: Array[Transform3D], color: String) -> void:
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var batch: MultiMesh = MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = _material(color)
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	node.multimesh = batch
	node.set_meta("authored_transforms", transforms.duplicate())
	root.add_child(node)


static func _material(color: String) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.84
	return material

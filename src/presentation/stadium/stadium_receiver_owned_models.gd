class_name StadiumReceiverOwnedModels
extends RefCounted
## Exact owned catching assemblies; placement and admission belong to the shared runtime.
## CB's inward endpoint is superseded by the owner's outward foul-line correction.
## Owner, 2026-10-18 23:23:27: “should cage outer walls angle same as foul lines basically? not
## inwards?”

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-072", "ST-073"]
const ROLE: String = "RECEIVER_CONTAINMENT_FOUL"
const CAGE_POSITION: Vector3 = Vector3(0, 0, -2.65)
const CAGE_FRONT_X: float = 3.280484853157408
const CAGE_ENVELOPE: AABB = AABB(Vector3(-3.430485, 0, -0.40), Vector3(6.86097, 3.10, 1.70))
const CAGE_PANELS: Dictionary = {
	"ST072_REAR_MESH": [Vector2(-2.15, 0), Vector2(2.15, 0)],
	"ST072_WING_R": [Vector2(2.20, 0), Vector2(CAGE_FRONT_X, 1.20)],
	"ST072_WING_L": [Vector2(-CAGE_FRONT_X, 1.20), Vector2(-2.20, 0)]
}
const CAGE_BOTTOM: float = 0.15
const CAGE_TOP: float = 2.95
const CAGE_GRID: float = 0.05
const CAGE_WIRE_WIDTH: float = 0.003
const CAGE_FLEX: float = 0.08
const CAGE_SETTLE: float = 0.35


static func create(item: String, row: Dictionary) -> Node3D:
	if (
		not ITEMS.has(item)
		or not row.get("copy") is String
		or str(row.copy).is_empty()
		or not row.get("site") is String
		or str(row.site).is_empty()
		or (row.has("item") and row.item != item)
	):
		return null
	var root: Node3D = _cage() if item == "ST-072" else StadiumReceiverNetModels.create()
	root.name = item.replace("-", "") + "OwnedReceiver"
	root.set_meta("model_factory", "StadiumReceiverOwnedModels")
	root.set_meta("model_version", VERSION)
	root.set_meta("owned_geometry_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("art_acceptance", "OPEN")
	root.set_meta("envelope", envelope(item))
	root.set_meta("receiver_placement", row.duplicate(true))
	root.set_meta("front_direction", Vector3.BACK)
	root.set_meta("open_front", true)
	root.set_meta("open_top", true)
	root.set_meta(
		"source_factory", "StadiumReceiverNetModels" if item == "ST-073" else "CB-owner-corrected"
	)
	root.set_meta("source_version", StadiumReceiverNetModels.VERSION if item == "ST-073" else 1)
	_bind(root, root, item, row, "")
	return root


static func envelope(item: String) -> AABB:
	if item == "ST-072":
		return CAGE_ENVELOPE
	return StadiumReceiverNetModels.ENVELOPE if item == "ST-073" else AABB()


static func position(item: String) -> Vector3:
	return CAGE_POSITION if item == "ST-072" else Vector3.ZERO


static func surfaces(item: String) -> Array[String]:
	if item == "ST-072":
		return ["ST072_REAR_MESH", "ST072_WING_R", "ST072_WING_L", "ST072_FRAME", "ST072_SUPPORTS"]
	var result: Array[String] = []
	if item == "ST-073":
		for id: String in StadiumReceiverNetModels.PANELS:
			result.append(id)
			result.append(id + "_LINE_BOTTOM")
			result.append(id + "_LINE_TOP")
		for side: int in [-1, 1]:
			result.append("ST073_POLE%d" % side)
			result.append("ST073_ANCHOR%d" % side)
	return result


static func _bind(
	node: Node, root: Node3D, item: String, row: Dictionary, inherited: String
) -> void:
	var surface: String = str(node.get_meta("surface_id", inherited))
	if node.get_parent() == root.get_node("Visual"):
		var body: Node = root.get_node_or_null("Collision/" + str(node.name))
		if body != null:
			surface = str(body.get_meta("surface_id", str(body.name)))
	node.set_meta("stadium_item", item)
	node.set_meta("owned_copy", row.copy)
	node.set_meta("paid_copy", row.copy)
	node.set_meta("site", row.site)
	node.set_meta("receiver_owned", true)
	node.set_meta("surface_role", ROLE)
	node.set_meta("ball_surface", &"stadium_receiver")
	if not surface.is_empty():
		node.set_meta("surface_id", surface)
		node.set_meta("owned_surface_id", str(row.copy) + ":" + surface)
	if node is StaticBody3D:
		node.set_meta("owned_body_id", str(row.copy) + ":" + str(node.name))
		(node as StaticBody3D).collision_layer = 1
		(node as StaticBody3D).collision_mask = 2
	if node is CollisionShape3D:
		node.name = str(node.get_parent().name) + "Shape"
		(node as CollisionShape3D).shape.margin = 0.0
	for child: Node in node.get_children():
		_bind(child, root, item, row, surface)


static func _cage() -> Node3D:
	var root: Node3D = Node3D.new()
	root.set_meta("stadium_item", "ST-072")
	root.set_meta("wing_angle_degrees", 42.0)
	root.set_meta("mesh_pattern", "metal_chain_diamond")
	for branch: String in ["Visual", "Collision"]:
		var node: Node3D = Node3D.new()
		node.name = branch
		root.add_child(node)
	for id: String in CAGE_PANELS:
		_cage_panel(root, id, CAGE_PANELS[id][0], CAGE_PANELS[id][1])
	for side: int in [-1, 1]:
		for front: bool in [false, true]:
			var x: float = side * (CAGE_FRONT_X if front else 2.20)
			var z: float = 1.20 if front else 0.0
			var suffix: String = ("Front" if front else "Rear") + str(side)
			_tube(
				root,
				"ST072_Post" + suffix,
				Vector3(x, 0.12, z),
				Vector3(x, 3.0, z),
				0.05,
				"ST072_FRAME"
			)
			StadiumStarterModels._box(
				root,
				"ST072_Foot" + suffix,
				Vector3(x, 0.05, 1.20 if front else -0.15),
				Vector3(0.24, 0.10, 0.20 if front else 0.50),
				Color("697778"),
				ROLE
			)
			_group(root, "ST072_Foot" + suffix, "ST072_SUPPORTS")
		_tube(
			root,
			"ST072_RearBrace%d" % side,
			Vector3(side * 2.20, 0.10, -0.30),
			Vector3(side * 2.20, 1.12, 0),
			0.035,
			"ST072_SUPPORTS"
		)
	for level: String in ["Bottom", "Top"]:
		var y: float = 0.12 if level == "Bottom" else 3.0
		_tube(
			root,
			"ST072_RearRail" + level,
			Vector3(-2.20, y, 0),
			Vector3(2.20, y, 0),
			0.05,
			"ST072_FRAME"
		)
		for side: int in [-1, 1]:
			_tube(
				root,
				"ST072_WingRail%s%d" % [level, side],
				Vector3(side * 2.20, y, 0),
				Vector3(side * CAGE_FRONT_X, y, 1.20),
				0.05,
				"ST072_FRAME"
			)
	return root


static func _tube(
	root: Node3D, id: String, a: Vector3, b: Vector3, radius: float, group: String
) -> void:
	# Capsule endpoints include the round caps; centerline endpoints remain a and b.
	StadiumTargetModels._tube(
		root, id, (a + b) / 2, a.direction_to(b), a.distance_to(b) + radius * 2, radius, true
	)
	_group(root, id, group)
	var material: StandardMaterial3D = root.get_node("Visual/" + id).material_override
	material.albedo_color = Color("899997")
	material.metallic = 0.65
	material.roughness = 0.48


static func _group(root: Node3D, id: String, surface: String) -> void:
	for branch: String in ["Visual", "Collision"]:
		root.get_node(branch + "/" + id).set_meta("surface_id", surface)


static func _cage_panel(root: Node3D, id: String, a: Vector2, b: Vector2) -> void:
	var width: float = a.distance_to(b)
	var pose: Transform3D = StadiumWallRecipes.placement({"a": a, "b": b})
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.transform = pose
	body.position.y = (CAGE_BOTTOM + CAGE_TOP) / 2
	body.set_meta("surface_id", id)
	body.set_meta("panel_endpoints", [a, b])
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = id + "Shape"
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(width, CAGE_TOP - CAGE_BOTTOM, 0.006)
	shape.shape = box
	body.add_child(shape)
	root.get_node("Collision").add_child(body)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Two diagonals form true small chain diamonds, unlike ST-073's square textile grid.
	for slope: float in [-1.0, 1.0]:
		var first: int = floori((CAGE_BOTTOM - width / 2) / CAGE_GRID) - 1
		var last: int = ceili((CAGE_TOP + width / 2) / CAGE_GRID) + 1
		for line in range(first, last + 1):
			var intercept: float = line * CAGE_GRID
			var low: float = maxf(
				-width / 2, minf((CAGE_BOTTOM - intercept) / slope, (CAGE_TOP - intercept) / slope)
			)
			var high: float = minf(
				width / 2, maxf((CAGE_BOTTOM - intercept) / slope, (CAGE_TOP - intercept) / slope)
			)
			if high > low:
				_wire(
					surface,
					Vector2(low, slope * low + intercept),
					Vector2(high, slope * high + intercept),
					width
				)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = surface.commit()
	mesh.transform = pose
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("a5b5b6")
	material.metallic = 0.72
	material.roughness = 0.42
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	mesh.set_meta("rest_vertices", mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	mesh.set_meta("panel_width", width)
	mesh.set_meta("diamond_pitch", CAGE_GRID)
	mesh.set_meta("wire_width", CAGE_WIRE_WIDTH)
	root.get_node("Visual").add_child(mesh)


static func _wire(surface: SurfaceTool, a: Vector2, b: Vector2, width: float) -> void:
	var direction: Vector2 = a.direction_to(b)
	var offset: Vector2 = Vector2(-direction.y, direction.x) * CAGE_WIRE_WIDTH / 2
	var count: int = maxi(1, ceili(a.distance_to(b) / 0.15))
	for index in range(count):
		var start: Vector2 = a.lerp(b, float(index) / count)
		var end: Vector2 = a.lerp(b, float(index + 1) / count)
		for raw: Vector2 in [
			start - offset, end - offset, end + offset, start - offset, end + offset, start + offset
		]:
			surface.set_normal(Vector3.BACK)
			surface.add_vertex(
				Vector3(
					clampf(raw.x, -width / 2, width / 2), clampf(raw.y, CAGE_BOTTOM, CAGE_TOP), 0
				)
			)


static func flex(model: Node3D, surface: String, elapsed: float, point: Vector3) -> bool:
	if model == null or not is_finite(elapsed) or not point.is_finite():
		return false
	var item: String = str(model.get_meta("stadium_item", ""))
	if item == "ST-073":
		return StadiumReceiverNetModels.flex(model, surface, elapsed, point)
	if item != "ST-072" or not CAGE_PANELS.has(surface):
		return false
	var mesh: MeshInstance3D = model.get_node_or_null("Visual/" + surface)
	if mesh == null:
		return false
	var rest: PackedVector3Array = mesh.get_meta("rest_vertices")
	var changed: PackedVector3Array = rest.duplicate()
	var width: float = mesh.get_meta("panel_width")
	var local: Vector3 = mesh.transform.affine_inverse() * point
	var pulse: float = (
		0.0
		if elapsed <= 0 or elapsed >= CAGE_SETTLE
		else sin(PI * elapsed / CAGE_SETTLE) * CAGE_FLEX
	)
	for index in range(changed.size()):
		var vertex: Vector3 = rest[index]
		var edge: float = maxf(
			0,
			(
				sin(PI * (vertex.x + width / 2) / width)
				* sin(PI * (vertex.y - CAGE_BOTTOM) / (CAGE_TOP - CAGE_BOTTOM))
			)
		)
		var distance: float = Vector2(vertex.x - local.x, vertex.y - local.y).length_squared()
		changed[index].z = -pulse * edge / (1 + distance * 0.15)
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_VERTEX] = changed
	arrays[Mesh.ARRAY_TANGENT] = null
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = result
	return true

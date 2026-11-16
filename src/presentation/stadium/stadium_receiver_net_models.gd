class_name StadiumReceiverNetModels
extends RefCounted
## ST-073 v2: corrected cup opens toward the field/target, per October 6 owner feedback.

const VERSION: int = 2
const ENVELOPE: AABB = AABB(Vector3(-5.1, 0, -5.15), Vector3(10.2, 6.9, 2.75))
const PANELS: Dictionary = {
	"ST073_CENTER_NET": [Vector2(-2, -4.5), Vector2(2, -4.5)],
	"ST073_NET_R": [Vector2(2, -4.5), Vector2(4.5, -2.7)],
	"ST073_NET_L": [Vector2(-4.5, -2.7), Vector2(-2, -4.5)]}
const BOTTOM: float = 0.25
const TOP: float = 6.5
const FLEX: float = 0.25
const SETTLE: float = 0.55
const GRID: float = 0.06


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "StadiumReceiverNetCandidate"
	root.set_meta("stadium_item", "ST-073")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	for id: String in PANELS:
		_panel(root, id, PANELS[id][0], PANELS[id][1])
	for side in [-1, 1]:
		StadiumTargetModels._tube(root, "ST073_POLE%d" % side,
			Vector3(side * 4.5, 3.4, -2.7), Vector3.UP, 6.8, 0.09)
		StadiumSeatingModels._box(root, "ST073_ANCHOR%d" % side,
			Vector3(side * 4.72, 0.12, -2.9), Vector3(0.5, 0.24, 0.65), Color("5c686a"))
	for body: StaticBody3D in root.get_node("Collision").get_children():
		body.collision_mask = 2
		body.set_meta("ball_surface", &"stadium_receiver_net_candidate")
		body.set_meta("surface_role", "RECEIVER_CONTAINMENT_FOUL")
		body.get_child(0).shape.margin = 0
	return root


static func _panel(root: Node3D, id: String, a: Vector2, b: Vector2) -> void:
	var width: float = a.distance_to(b)
	var pose: Transform3D = StadiumWallRecipes.placement({"a": a, "b": b})
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.transform = pose
	body.position.y = (TOP + BOTTOM) / 2
	body.collision_layer = 1
	body.set_meta("stadium_item", "ST-073")
	body.set_meta("surface_id", id)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = BoxShape3D.new()
	collider.shape.size = Vector3(width, TOP - BOTTOM, 0.006)
	body.add_child(collider)
	root.get_node("Collision").add_child(body)
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = ceili(width / GRID)
	var rows: int = ceili((TOP - BOTTOM) / GRID)
	for index in range(columns + 1):
		var x: float = -width / 2 + width * index / columns
		_quad(surface, Vector2(maxf(-width / 2, x - 0.002), BOTTOM),
			Vector2(minf(width / 2, x + 0.002), TOP))
	for index in range(rows + 1):
		var y: float = BOTTOM + (TOP - BOTTOM) * index / rows
		_quad(surface, Vector2(-width / 2, maxf(BOTTOM, y - 0.002)),
			Vector2(width / 2, minf(TOP, y + 0.002)))
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = id
	mesh.mesh = surface.commit()
	mesh.transform = pose
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("a2b39d")
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1
	mesh.material_override = material
	mesh.set_meta("rest_vertices", mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	mesh.set_meta("panel_width", width)
	root.get_node("Visual").add_child(mesh)
	for y: float in [BOTTOM, TOP]:
		var center: Vector3 = pose.origin + Vector3(0, y, 0)
		var line_id: String = id + ("_LINE_BOTTOM" if y == BOTTOM else "_LINE_TOP")
		StadiumTargetModels._tube(root, line_id, center, pose.basis.x, width, 0.012)


static func _quad(surface: SurfaceTool, a: Vector2, b: Vector2) -> void:
	# Split long strands so interior vertices can flex while edge attachments remain fixed.
	var columns: int = maxi(1, ceili((b.x - a.x) / 0.25))
	var rows: int = maxi(1, ceili((b.y - a.y) / 0.25))
	for column in range(columns):
		for row in range(rows):
			_cell(surface, Vector2(lerpf(a.x, b.x, float(column) / columns),
				lerpf(a.y, b.y, float(row) / rows)), Vector2(
				lerpf(a.x, b.x, float(column + 1) / columns),
				lerpf(a.y, b.y, float(row + 1) / rows)))


static func _cell(surface: SurfaceTool, a: Vector2, b: Vector2) -> void:
	for point: Vector2 in [a, Vector2(b.x, a.y), b, a, b, Vector2(a.x, b.y)]:
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(Vector3(point.x, point.y, 0))


static func flex(root: Node3D, id: String, elapsed: float, impact: Vector3) -> bool:
	if root == null or not PANELS.has(id) or not is_finite(elapsed) or not impact.is_finite():
		return false
	var mesh: MeshInstance3D = root.get_node_or_null("Visual/" + id)
	if mesh == null:
		return false
	var rest: PackedVector3Array = mesh.get_meta("rest_vertices")
	var changed: PackedVector3Array = rest.duplicate()
	var width: float = mesh.get_meta("panel_width")
	var local: Vector3 = mesh.transform.affine_inverse() * impact
	var pulse: float = sin(PI * clampf(elapsed / SETTLE, 0, 1)) * FLEX
	for index in range(changed.size()):
		var point: Vector3 = rest[index]
		var edge: float = maxf(0, sin(PI * (point.x + width / 2) / width)
			* sin(PI * (point.y - BOTTOM) / (TOP - BOTTOM)))
		var distance: float = Vector2(point.x - local.x, point.y - local.y).length_squared()
		changed[index].z = -pulse * edge / (1 + distance * 0.15)
	var arrays: Array = mesh.mesh.surface_get_arrays(0)
	arrays[Mesh.ARRAY_VERTEX] = changed
	arrays[Mesh.ARRAY_TANGENT] = null
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.mesh = result
	return true

class_name StadiumHillsideTerrainModels
extends RefCounted
## Actual closed collision volume and identical visible mesh. No flat underlay or extra force.

const QUERY_LAYER: int = 512
const SURFACE: StringName = &"hillside_dependency_ground"


static func create(profile: String = "hill") -> Node3D:
	if not StadiumHillsideTerrain.PROFILES.has(profile):
		return null
	var root: Node3D = Node3D.new()
	root.name = "HillsideTerrainDependency"
	root.set_meta("terrain_signature", StadiumHillsideTerrain.signature(profile))
	root.set_meta("terrain_profile", profile)
	root.set_meta("production_ready", false)
	var data: Dictionary = geometry(profile)
	var builder: SurfaceTool = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(data.faces.size()):
		builder.set_normal(data.normals[index])
		builder.add_vertex(data.faces[index])
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.name = "TerrainVisual"
	mesh.mesh = builder.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("315640")
	material.roughness = 0.9
	mesh.material_override = material
	root.add_child(mesh)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1 | QUERY_LAYER
	body.collision_mask = 2
	body.set_meta("ball_surface", SURFACE)
	body.set_meta("terrain_profile", profile)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "ClosedTerrainShape"
	var collision: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	collision.margin = 0
	collision.backface_collision = false
	collision.set_faces(data.faces)
	shape.shape = collision
	body.add_child(shape)
	root.add_child(body)
	return root


static func geometry(profile: String) -> Dictionary:
	if not StadiumHillsideTerrain.PROFILES.has(profile):
		return {}
	var result: Dictionary = {"faces": PackedVector3Array(), "normals": PackedVector3Array()}
	var knots: PackedFloat64Array = StadiumHillsideTerrain.knots()
	var lo: float = StadiumHillsideTerrain.BOUNDS.position.x
	var hi: float = StadiumHillsideTerrain.BOUNDS.end.x
	var bottom: float = StadiumHillsideTerrain.BOTTOM
	for index in range(knots.size() - 1):
		var a: Vector3 = StadiumHillsideTerrain.point(lo, knots[index], profile)
		var b: Vector3 = StadiumHillsideTerrain.point(hi, knots[index], profile)
		var c: Vector3 = StadiumHillsideTerrain.point(hi, knots[index + 1], profile)
		var d: Vector3 = StadiumHillsideTerrain.point(lo, knots[index + 1], profile)
		var normal: Vector3 = Vector3(0, 1, -(c.y - b.y) / (c.z - b.z)).normalized()
		_quad(result, a, b, c, d, normal)
		_quad(result, a, d, Vector3(lo, bottom, d.z), Vector3(lo, bottom, a.z), Vector3.LEFT)
		_quad(result, b, Vector3(hi, bottom, b.z), Vector3(hi, bottom, c.z), c, Vector3.RIGHT)
		_quad(result, Vector3(lo, bottom, a.z), Vector3(lo, bottom, d.z),
			Vector3(hi, bottom, c.z), Vector3(hi, bottom, b.z), Vector3.DOWN)
	var near_z: float = knots[0]
	var far_z: float = knots[-1]
	for z: float in [near_z, far_z]:
		_quad(result, StadiumHillsideTerrain.point(lo, z, profile),
			Vector3(lo, bottom, z), Vector3(hi, bottom, z),
			StadiumHillsideTerrain.point(hi, z, profile), Vector3.FORWARD if z == near_z else Vector3.BACK)
	return result


static func _quad(data: Dictionary, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	outward: Vector3) -> void:
	# Godot uses clockwise front faces. Render normals and collision winding agree.
	var corners: Array[Vector3] = [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(outward) > 0:
		corners = [a, c, b, a, d, c]
	for point_value: Vector3 in corners:
		data.faces.append(point_value)
		data.normals.append(outward)

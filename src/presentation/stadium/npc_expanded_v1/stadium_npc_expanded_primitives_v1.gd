class_name StadiumNpcExpandedPrimitivesV1
extends RefCounted
## Retained AE-01/r1 correspondence copy.
## Original: src/presentation/stadium/stadium_starter_models.gd
## Retained receiver construction primitives only; no starter catalog factory.

const VERSION: int = 1


static func _box(root: Node3D, id: String, center: Vector3, size: Vector3,
	color: Color, role: String) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	_part(root, id, center, mesh, shape, color, role)


static func _part(root: Node3D, id: String, center: Vector3, mesh: Mesh,
	shape: Shape3D, color: Color, role: String) -> void:
	_mesh(root, id, center, mesh, color)
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.position = center
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface_id", id)
	body.set_meta("surface_role", role)
	body.set_meta("stadium_item", root.get_meta("stadium_item"))
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	root.get_node("Collision").add_child(body)


static func _mesh(root: Node3D, id: String, center: Vector3, mesh: Mesh, color: Color) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.mesh = mesh
	instance.position = center
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	root.get_node("Visual").add_child(instance)

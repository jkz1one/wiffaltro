class_name StadiumYardLightModels
extends RefCounted
## Original single-head yard pole. BP blockout variables, not a night-schedule entitlement.

const VERSION: int = 2
const ENVELOPE: AABB = AABB(Vector3(-0.75, 0, -0.75), Vector3(1.5, 7, 1.5))
const SITES: Dictionary = {
	"YLIGHT-FL": Vector3(-25, 0, 0), "YLIGHT-FR": Vector3(25, 0, 0),
	"YLIGHT-RL": Vector3(-25, 0, 25), "YLIGHT-RR": Vector3(25, 0, 25),
}
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"


static func create() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ST037"
	root.set_meta("stadium_item", "ST-037")
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	StadiumSeatingModels._box(root, "Footing", Vector3(0, 0.10, 0),
		Vector3(0.46, 0.20, 0.46), Color("77817b"))
	StadiumSeatingModels._box(root, "BasePlate", Vector3(0, 0.225, 0),
		Vector3(0.34, 0.05, 0.34), Color("52646a"))
	_cylinder(root, "Pole", Vector3(0, 3.29, 0), Vector3.UP, 6.18, 0.085)
	_cylinder(root, "Arm", Vector3(0, 6.32, 0.225), Vector3.BACK, 0.45, 0.055)
	StadiumSeatingModels._box(root, "LampHousing", Vector3(0, 6.32, 0.43),
		Vector3(0.48, 0.40, 0.20), Color("384951"))
	root.get_node("Visual/LampHousing").rotation.x = deg_to_rad(13)
	root.get_node("Collision/LampHousing").rotation.x = deg_to_rad(13)
	var lens: MeshInstance3D = MeshInstance3D.new()
	lens.name = "LampLens"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.40, 0.32, 0.015)
	lens.mesh = mesh
	lens.position = Vector3(0, 6.32, 0.43) + Basis(Vector3.RIGHT, deg_to_rad(13)) \
		* Vector3(0, 0, 0.108)
	lens.rotation.x = deg_to_rad(13)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color("ece5c7")
	material.emission = Color("ffdeb0")
	material.roughness = 0.35
	lens.material_override = material
	root.get_node("Visual").add_child(lens)
	var beam: SpotLight3D = SpotLight3D.new()
	beam.name = "FieldLight"
	beam.position = Vector3(0, 6.295, 0.54)
	beam.light_color = Color("ffe4c2")
	beam.light_energy = 0.40
	beam.spot_range = 54
	beam.spot_angle = 68
	beam.spot_attenuation = 0.65
	beam.spot_angle_attenuation = 0.7
	beam.shadow_enabled = true
	beam.shadow_bias = 0.1
	beam.shadow_normal_bias = 2.0
	beam.visible = false
	root.add_child(beam)
	for body: StaticBody3D in root.get_node("Collision").get_children():
		body.set_meta("ball_surface", &"stadium_scenery")
	return root


static func _cylinder(root: Node3D, id: String, point: Vector3, direction: Vector3,
	height: float, radius: float) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	StadiumStarterModels._part(root, id, point, mesh, shape, Color("52646a"), ROLE)
	var pose: Quaternion = Quaternion(Vector3.UP, direction)
	root.get_node("Visual/" + id).quaternion = pose
	root.get_node("Collision/" + id).quaternion = pose


static func place(root: Node3D, site: String) -> bool:
	if not SITES.has(site):
		return false
	root.position = SITES[site]
	var target: Vector3 = Vector3(0, 0.7, 8 if site.ends_with("FL") or site.ends_with("FR") else 18)
	var toward: Vector3 = target - root.position
	root.rotation.y = atan2(toward.x, toward.z)
	root.set_meta("site", site)
	var beam: SpotLight3D = root.get_node("FieldLight")
	var local_target: Vector3 = root.transform.affine_inverse() * target
	beam.quaternion = Quaternion(Vector3.FORWARD, (local_target - beam.position).normalized())
	return true


static func night(root: Node3D, active: bool) -> void:
	root.get_node("FieldLight").visible = active
	var lens: MeshInstance3D = root.get_node("Visual/LampLens")
	lens.material_override.emission_enabled = active
	lens.material_override.emission_energy_multiplier = 1.0 if active else 0.0

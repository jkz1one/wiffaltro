class_name StadiumFoulPoleModels
extends RefCounted
## Isolated pole geometry. Complete contact precedence and saved-runtime integration remain gates.

const VERSION: int = 1


static func create(split: float) -> Node3D:
	if not is_finite(split) or split <= 0 or split >= StadiumFoulPoleSites.HEIGHT:
		return null
	var root: Node3D = Node3D.new()
	root.name = "FoulPoleCandidate"
	root.set_meta("stadium_item", "ST-021")
	root.set_meta("wall_cap_height", split)
	for id: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = id
		root.add_child(child)
	for region: Array in [["Lower", 0.0, split], ["Upper", split, StadiumFoulPoleSites.HEIGHT]]:
		var height: float = region[2] - region[1]
		var point: Vector3 = Vector3(0, (region[1] + region[2]) / 2, 0)
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = StadiumFoulPoleSites.RADIUS
		mesh.bottom_radius = StadiumFoulPoleSites.RADIUS
		mesh.height = height
		mesh.radial_segments = 16
		StadiumSeatingModels._mesh(root.get_node("Visual"), region[0], mesh, point, Color("e0ba3f"))
	# A single uninterrupted cylinder avoids a spurious internal physical cap at the scoring split.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "Pole"
	body.position = Vector3(0, StadiumFoulPoleSites.HEIGHT / 2, 0)
	body.collision_layer = 1
	body.collision_mask = 2
	body.set_meta("ball_surface", &"stadium_foul_pole_candidate")
	body.set_meta("surface_role", "FOUL_POLE_CONTACT")
	body.set_meta("surface_id", "ST-021-POLE")
	body.set_meta("wall_cap_height", split)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = CylinderShape3D.new()
	shape.shape.radius = StadiumFoulPoleSites.RADIUS
	shape.shape.height = StadiumFoulPoleSites.HEIGHT
	shape.shape.margin = 0
	body.add_child(shape)
	root.get_node("Collision").add_child(body)
	return root


static func role_at(height: float, split: float) -> String:
	if not is_finite(height) or not is_finite(split) or split <= 0 \
		or split >= StadiumFoulPoleSites.HEIGHT or height < 0 or height > StadiumFoulPoleSites.HEIGHT:
		return ""
	return "FOUL_POLE_LOWER" if height <= split else "FOUL_POLE_UPPER"

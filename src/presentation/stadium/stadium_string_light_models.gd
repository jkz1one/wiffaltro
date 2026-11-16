class_name StadiumStringLightModels
extends RefCounted
## DG1 Working ST-036: one fixed fourteen-metre span with two included supports.
## This dormant presentation candidate grants no inventory or night qualification.

const VERSION: int = 1
const ITEM: String = "ST-036"
const VARIANT: String = "STRING-14M-DG1"
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const SPAN: float = 14.0
const POST_HEIGHT: float = 6.15
const ATTACHMENT_HEIGHT: float = 6.0
const BULB_COUNT: int = 14
const BULB_RADIUS: float = 0.045
const BULB_DROP: float = 0.15
const CABLE_RADIUS: float = 0.012
const CABLE_SEGMENTS: int = 56
const POST_RADIUS: float = 0.25
const CLEARANCE_RADIUS: float = 0.50
const ENVELOPE: AABB = AABB(Vector3(-0.25, 0, -0.25), Vector3(14.5, 6.15, 0.5))
const CABLE_ENVELOPE: AABB = AABB(Vector3(-0.15, 5.20, -0.15), Vector3(14.3, 0.95, 0.3))
const SITES: Dictionary = {
	"STR-LF": [Vector3(-25, 0, -7), Vector3(-25, 0, 7)],
	"STR-LD": [Vector3(-25, 0, 17), Vector3(-25, 0, 31)],
	"STR-RF": [Vector3(25, 0, -7), Vector3(25, 0, 7)],
	"STR-RD": [Vector3(25, 0, 17), Vector3(25, 0, 31)],
	"STR-BL": [Vector3(-15, 0, -9), Vector3(-1, 0, -9)],
	"STR-BR": [Vector3(1, 0, -9), Vector3(15, 0, -9)],
	"STR-BC": [Vector3(-7, 0, -9), Vector3(7, 0, -9)],
}


static func create(item: String = ITEM, placement: Dictionary = {}) -> Node3D:
	if item != ITEM:
		return null
	if (
		not placement.is_empty()
		and (
			not placement.get("copy") is String
			or str(placement.copy).is_empty()
			or not placement.get("site") is String
			or not SITES.has(placement.site)
		)
	):
		return null
	var root: Node3D = Node3D.new()
	root.name = "ST036StringLightSpan"
	for branch: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = branch
		root.add_child(child)
	root.set_meta("stadium_item", ITEM)
	root.set_meta("model_version", VERSION)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_variant", VARIANT)
	root.set_meta("authoring_status", "Working")
	root.set_meta("qualification_status", "CANDIDATE")
	root.set_meta("final_art_accepted", false)
	root.set_meta("night_qualified", false)
	root.set_meta("scenery_only", true)
	root.set_meta("static_geometry", true)
	root.set_meta("obstacle_units", 0)
	root.set_meta("included_supports", 2)
	root.set_meta("fixed_span", SPAN)
	root.set_meta("envelope", ENVELOPE)
	root.set_meta("cable_envelope", CABLE_ENVELOPE)
	root.set_meta("post_clearance_radius", CLEARANCE_RADIUS)
	root.set_meta("supports_separately_owned", false)
	root.set_meta("surface_role", ROLE)
	root.set_meta("physics_profile", ROLE)
	for index in range(2):
		var prefix: String = "PostA" if index == 0 else "PostB"
		var x: float = SPAN * index
		# The visible round base fits inside radius 0.25, not a square of that half-width.
		_cylinder(root, prefix + "Footing", Vector3(x, 0.06, 0), 0.12, 0.24, Color("7d8981"), true)
		_cylinder(root, prefix + "Plate", Vector3(x, 0.14, 0), 0.04, 0.16, Color("425a53"), true)
		_cylinder(root, prefix + "Mast", Vector3(x, 3.155, 0), 5.99, 0.07, Color("526b61"), true)
	for index in range(CABLE_SEGMENTS):
		var a: Vector3 = cable_point(float(index) / CABLE_SEGMENTS)
		var b: Vector3 = cable_point(float(index + 1) / CABLE_SEGMENTS)
		var cable: MeshInstance3D = _cylinder(
			root, "Cable%02d" % index, (a + b) / 2, a.distance_to(b), CABLE_RADIUS, Color("323d38")
		)
		cable.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
		cable.set_meta("cable_t0", float(index) / CABLE_SEGMENTS)
		cable.set_meta("cable_t1", float(index + 1) / CABLE_SEGMENTS)
	for index in range(BULB_COUNT):
		var t: float = (index + 0.5) / BULB_COUNT
		var anchor: Vector3 = cable_point(t)
		_cylinder(
			root, "Dropper%02d" % index, anchor - Vector3(0, 0.03, 0), 0.06, 0.009, Color("323d38")
		)
		_cylinder(
			root,
			"Socket%02d" % index,
			anchor - Vector3(0, 0.0575, 0),
			0.035,
			0.024,
			Color("425a53")
		)
		var globe: SphereMesh = SphereMesh.new()
		globe.radius = BULB_RADIUS
		globe.height = BULB_RADIUS * 2
		globe.radial_segments = 16
		globe.rings = 8
		var bulb: MeshInstance3D = _mesh(
			root,
			"Bulb%02d" % index,
			anchor - Vector3(0, BULB_DROP - BULB_RADIUS, 0),
			globe,
			Color("eee2bd")
		)
		bulb.set_meta("bulb_index", index)
		bulb.set_meta("cable_t", t)
		bulb.set_meta("cable_anchor", anchor)
		# Plain opaque lenses. No per-bulb light, bloom, animation or night entitlement.
		var material: StandardMaterial3D = bulb.material_override
		material.emission = Color("ffe1ae")
		material.emission_enabled = false
		material.emission_energy_multiplier = 0.0
	if not placement.is_empty():
		_bind(root, str(placement.copy), str(placement.site))
		root.transform = pose(str(placement.site))
	return root


static func envelope(item: String = ITEM) -> AABB:
	return ENVELOPE if item == ITEM else AABB()


static func components(item: String = ITEM) -> Array[Dictionary]:
	# Installation reservations only. These boxes must never become broad colliders.
	if item != ITEM:
		return []
	return [
		{
			"id": "PostA",
			"kind": "post",
			"radius": POST_RADIUS,
			"bounds": AABB(Vector3(-0.25, 0, -0.25), Vector3(0.5, POST_HEIGHT, 0.5))
		},
		{
			"id": "PostB",
			"kind": "post",
			"radius": POST_RADIUS,
			"bounds": AABB(Vector3(SPAN - 0.25, 0, -0.25), Vector3(0.5, POST_HEIGHT, 0.5))
		},
		{"id": "CableBulbs", "kind": "cable", "bounds": CABLE_ENVELOPE},
	]


static func clearance_components(item: String = ITEM) -> Array[Dictionary]:
	if item != ITEM:
		return []
	return [
		{"id": "PostA", "center": Vector3.ZERO, "radius": CLEARANCE_RADIUS},
		{"id": "PostB", "center": Vector3(SPAN, 0, 0), "radius": CLEARANCE_RADIUS},
	]


static func cable_point(t: float) -> Vector3:
	return Vector3(SPAN * t, ATTACHMENT_HEIGHT - 2.4 * t * (1.0 - t), 0)


static func bulb_points() -> PackedVector3Array:
	# Actual globe centers; cable attachment points are 0.105 metres above these.
	var points: PackedVector3Array = []
	for index in range(BULB_COUNT):
		points.append(
			cable_point((index + 0.5) / BULB_COUNT) - Vector3(0, BULB_DROP - BULB_RADIUS, 0)
		)
	return points


static func pose(site: String) -> Transform3D:
	if not SITES.has(site):
		return Transform3D.IDENTITY
	var a: Vector3 = SITES[site][0]
	var b: Vector3 = SITES[site][1]
	var direction: Vector3 = (b - a).normalized()
	# Godot's positive Y yaw turns +X toward -Z. This proper basis maps +X to B-A.
	return Transform3D(Basis(direction, Vector3.UP, direction.cross(Vector3.UP)), a)


static func place(root: Node3D, site: String) -> bool:
	if root == null or root.get_meta("stadium_item", "") != ITEM or not SITES.has(site):
		return false
	root.transform = pose(site)
	_bind(root, str(root.get_meta("owned_copy", "")), site)
	return true


static func _bind(node: Node, copy: String, site: String) -> void:
	node.set_meta("stadium_item", ITEM)
	node.set_meta("site", site)
	node.set_meta("surface_role", ROLE)
	if not copy.is_empty():
		node.set_meta("owned_copy", copy)
		node.set_meta("paid_copy", copy)
	for child: Node in node.get_children():
		_bind(child, copy, site)


static func _mesh(
	root: Node3D, id: String, center: Vector3, mesh: Mesh, color: Color
) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = id
	instance.position = center
	instance.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	instance.material_override = material
	root.get_node("Visual").add_child(instance)
	return instance


static func _cylinder(
	root: Node3D,
	id: String,
	center: Vector3,
	height: float,
	radius: float,
	color: Color,
	solid: bool = false
) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	var instance: MeshInstance3D = _mesh(root, id, center, mesh, color)
	if solid:
		var body: StaticBody3D = StaticBody3D.new()
		body.name = id
		body.position = center
		body.collision_layer = 1
		body.collision_mask = 0
		body.set_meta("stadium_item", ITEM)
		body.set_meta("surface_id", id)
		body.set_meta("surface_role", ROLE)
		body.set_meta("ball_surface", &"stadium_scenery")
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.name = "Shape"
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.height = height
		shape.radius = radius
		shape.margin = 0
		collision.shape = shape
		body.add_child(collision)
		root.get_node("Collision").add_child(body)
	return instance

class_name StadiumNpcYardV1
extends Node3D
## Retained AY-01/r1 construction correspondence ONLY. No production lab installer.
## Deliberately not StadiumPropertyGeometry: existing runtime adapters cannot install this.
## No current catalog, ContentDB, human stock or candidate generator is consulted.

const VERSION: int = 1
const BOUNDS: Rect2 = Rect2(-26, -10, 52, 42)
const MOUND_ORIGIN: Vector3 = Vector3(0.0, 0.0, 13.716)
const FIELD: Dictionary = {
	"id": "field.starter_backyard",
	"display_name": "Yard Club Field",
	"environment_style": 0,
	"fair_half_angle_degrees": 42.0,
	"safe_hit_z_m": 11.25,
	"deep_air_z_m": 17.0,
	"back_wall_z_m": 23.4,
	"home_run_height_m": 3.25,
	"dead_ball_z_m": 29.0,
	"shallow_anchor_z_m": 8.5,
	"middle_anchor_z_m": 14.0,
	"middle_center_anchor_z_m": 17.0,
	"deep_anchor_z_m": 19.5,
	"side_anchor_x_m": 5.5,
	"shallow_center_available": false,
	"middle_center_available": false
}
const RECEIVER: Dictionary = {
	"batted_surfaces": [],
	"catalog_item": "",
	"configuration": "RX-DEFAULT-00",
	"hold": 0.18,
	"id": "RX-PRIMARY-DEFAULT-v1",
	"max_travel": 0.16,
	"min_travel": 0.055,
	"pitch_surfaces": [],
	"plane_z": -1.05,
	"site": "RECEIVER-PRIMARY",
	"transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.05],
	"visible_model": "debug-only"
}
const SURFACE: Dictionary = {
	"bounds": [-26, -10, 52, 42],
	"geometry": "flat",
	"grass": "default",
	"ground": "default",
	"id": "AY-01-default-backyard-v1",
	"lines": "default",
	"physics": "unchanged-reference-field",
	"styles": [],
	"version": 1
}
const ROUTING: Dictionary = {
	"boundary": "PERIM-BACKYARD-STRAIGHT-BX1-v1",
	"defender_radius": 0.54,
	"live_obstacles": [],
	"version": 1
}
const SITES: Dictionary = {
	"SC-L1": Vector3(-24, 0, 10),
	"SC-L2": Vector3(-24, 0, 12),
	"SC-R1": Vector3(24, 0, 10),
	"SC-R2": Vector3(24, 0, 12)
}

var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "backyard"


class TemplateView extends StadiumRecipeBoundary:
	## Retained joined-prism camera correspondence; no live camera is selected or installed.
	func polygon() -> PackedVector2Array:
		return PackedVector2Array(StadiumNpcYardGraphV1.VERTICES)

	func segments() -> Array[Dictionary]:
		return StadiumNpcYardGraphV1.segments()

	func outer_vertex(index: int) -> Vector2:
		return StadiumNpcYardGraphV1.outer_vertex(index)

	func identity() -> String:
		return StadiumNpcYardGraphV1.ID


static func build() -> StadiumNpcYardV1:
	var property: StadiumNpcYardV1 = StadiumNpcYardV1.new()
	property.name = "AY01Revision1Correspondence"
	property.set_meta("npc_correspondence_only", true)
	property._build()
	return property


static func pose(site: String) -> Transform3D:
	if not SITES.has(site):
		return Transform3D.IDENTITY
	var sign_value: float = 1.0 if site.begins_with("SC-L") else -1.0
	return Transform3D(
		Basis(Vector3(0, 0, -sign_value), Vector3.UP, Vector3(sign_value, 0, 0)), SITES[site]
	)


func route_obstacles() -> Array[Dictionary]:
	# All four ST-080 instances are decorative after terminal; never live route obstacles.
	return []


func _build() -> void:
	field = FieldDefinition.new()
	for key: String in FIELD:
		field.set(key, FIELD[key])
	_surface()
	var boundary: StadiumNpcYardBoundaryV1 = StadiumNpcYardBoundaryV1.new()
	boundary.name = "BoundaryGraph"
	boundary.build()
	add_child(boundary)
	for site: String in SITES:
		var model: Node3D = StadiumNpcYardSeatingV1.create("ST-080")
		var identity: String = "npc:AY-01:r1:" + site
		model.name = site
		model.transform = pose(site)
		model.set_meta("npc_instance", identity)
		model.set_meta("npc_site", site)
		add_child(model)
		objects[identity] = model
		for body: Node in model.get_node("Collision").get_children():
			body.set_meta("npc_instance", identity)
	# RX-DEFAULT-00 intentionally adds no node, collider, sound or inventory copy.


func _surface() -> void:
	var ground: AABB = AABB(Vector3(-26, -0.16, -10), Vector3(52, 0.16, 42))
	_box("PropertyGround", ground.get_center(), ground.size, Color("315640"), &"ground")
	_box("Plate", Vector3(0, 0.025, 0), Vector3(0.70, 0.05, 0.45), Color("e7e1cf"))
	_box("Mound", MOUND_ORIGIN + Vector3(0, 0.025, 0), Vector3(0.8, 0.05, 0.8), Color("927553"))
	for band: Array in [
		["Safe", field.safe_hit_z_m, Color("e4ca66")], ["Deep", field.deep_air_z_m, Color("70c0c3")]
	]:
		var half: float = float(band[1]) * tan(deg_to_rad(field.fair_half_angle_degrees))
		_box(band[0], Vector3(0, 0.016, band[1]), Vector3(half * 2, 0.025, 0.08), band[2])
	for side: int in [-1, 1]:
		var end: Vector3 = Vector3(
			side * field.back_wall_z_m * tan(deg_to_rad(field.fair_half_angle_degrees)),
			0,
			field.back_wall_z_m
		)
		var line: Node3D = _box(
			"FoulLine" + str(side),
			end / 2 + Vector3(0, 0.02, 0),
			Vector3(0.055, 0.025, end.length()),
			Color("d8ded0")
		)
		line.rotation.y = atan2(end.x, end.z)
	var bounds: Rect2 = BOUNDS
	for edge: Array in [
		[
			Vector3(bounds.position.x, 0.02, bounds.get_center().y),
			Vector3(0.08, 0.02, bounds.size.y)
		],
		[Vector3(bounds.end.x, 0.02, bounds.get_center().y), Vector3(0.08, 0.02, bounds.size.y)],
		[Vector3(0, 0.02, bounds.position.y), Vector3(bounds.size.x, 0.02, 0.08)],
		[Vector3(0, 0.02, bounds.end.y), Vector3(bounds.size.x, 0.02, 0.08)]
	]:
		_box("LandEdge", edge[0], edge[1], Color("84a67e"))


func _box(
	id: String, center: Vector3, size: Vector3, color: Color, surface: StringName = &""
) -> Node3D:
	var root: Node3D = Node3D.new() if surface.is_empty() else StaticBody3D.new()
	root.name = id
	root.position = center
	if root is StaticBody3D:
		root.collision_layer = 1
		root.collision_mask = 2
		root.set_meta("ball_surface", surface)
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		root.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	root.add_child(mesh)
	add_child(root)
	return root

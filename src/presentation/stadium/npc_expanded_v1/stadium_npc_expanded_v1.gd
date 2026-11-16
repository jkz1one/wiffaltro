class_name StadiumNpcExpandedV1
extends Node3D
## Retained AE-01/r1 detached construction correspondence only; no runtime installer.
## Geometry is independently retained from the exact Working ExpandedVenueStudy build.
## No current catalog, ContentDB, human stock or candidate generator is consulted.
## Shared FieldDefinition/resolver/visibility semantics still need a separate runtime gate.

const VERSION: int = 1
const BOUNDS: Rect2 = Rect2(-32, -16, 64, 54)
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
	"id": "RX-TARGET-NET-026025-v2",
	"version": 1,
	"archival_net_site": "RECEIVER-CATCH",
	"runtime_net_alias": "RECEIVER-NET",
	"blockout": "RX-CATCH025-BLOCKOUT-v2",
	"target_site": "RECEIVER-PRIMARY",
	"target_item": "ST-026",
	"net_item": "ST-025",
	"target_transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.05],
	"net_transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -2.20],
	"target_envelope": [-0.6, 0, -0.675, 1.2, 1.645, 0.705],
	"net_envelope": [-1.9, 0, -0.85, 3.8, 2.7, 0.89],
	"net_world_z": [-3.05, -2.16],
	"clearance": 0.435,
	"surface_role": "RECEIVER_CONTAINMENT_FOUL",
	"target_surfaces": [
		"ST026_PANEL", "ST026_BASE_CROSS",
		"ST026_FRAME_SIDE-1", "ST026_FRAME_BAR-1", "ST026_LEGS-1", "ST026_BASE_SKID-1",
		"ST026_FRAME_SIDE1", "ST026_FRAME_BAR1", "ST026_LEGS1", "ST026_BASE_SKID1"
	],
	"net_surfaces": [
		"ST025_NET", "ST025_BASE_CROSS",
		"ST025_FRAME_SIDE-1", "ST025_FRAME_BAR-1", "ST025_SUPPORTS-1", "ST025_BASE_SKID-1",
		"ST025_FRAME_SIDE1", "ST025_FRAME_BAR1", "ST025_SUPPORTS1", "ST025_BASE_SKID1"
	],
	"cleanup_z": -3.10,
	"step": 1.0 / 240.0,
	"timeout": 0.24,
	"target_flex_duration": 0.18,
	"target_flex_depth": 0.03,
	"net_pocket_duration": 0.24,
	"net_flex_depth": 0.16
}
const SURFACE: Dictionary = {
	"bounds": [-32, -16, 64, 54],
	"geometry": "flat",
	"grass": "default",
	"ground": "default",
	"id": "AE-01-default-expanded-v1",
	"lines": "default",
	"markings": "default",
	"physics": "unchanged-reference-field",
	"styles": [],
	"version": 1
}
const ROUTING: Dictionary = {
	"boundary": "PERIM-BACKYARD-ANGLED-BX1-v1",
	"defender_radius": 0.54,
	"live_obstacles": [],
	"receiver_avoidance": {
		"body_radius": 0.32,
		"coordinate_space": "field-local",
		"sites": ["RECEIVER-PRIMARY", "RECEIVER-CATCH"],
		"radius": "half-xz-envelope-diagonal-plus-body-radius"
	},
	"version": 1
}
const SITES: Array[String] = [
	"RECEIVER-PRIMARY", "RECEIVER-CATCH", "SIDE-SEAT-L", "SIDE-SEAT-R", "SCORE-SMALL"
]
const ITEMS: Array[String] = ["ST-026", "ST-025", "ST-028", "ST-028", "ST-039"]
const COUNTS: Dictionary = {"ST-024": 22, "ST-026": 1, "ST-025": 1, "ST-028": 2, "ST-039": 1}

var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "expanded"


class TemplateView extends StadiumRecipeBoundary:
	## Shared visibility adapter only; no camera is installed by this detached factory.
	var retained: StadiumNpcExpandedGraphV1 = StadiumNpcExpandedGraphV1.create("deeper_center")

	func polygon() -> PackedVector2Array:
		return retained.polygon()

	func segments() -> Array[Dictionary]:
		return retained.segments()

	func outer_vertex(index: int) -> Vector2:
		return retained.outer_vertex(index)

	func identity() -> String:
		return retained.identity()


static func build() -> StadiumNpcExpandedV1:
	var property: StadiumNpcExpandedV1 = StadiumNpcExpandedV1.new()
	property.name = "AE01Revision1Correspondence"
	property.set_meta("npc_correspondence_only", true)
	property._build()
	return property


static func pose(site: String) -> Transform3D:
	match site:
		"RECEIVER-PRIMARY":
			return Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.05))
		"RECEIVER-CATCH":
			return Transform3D(Basis.IDENTITY, Vector3(0, 0, -2.20))
		"SIDE-SEAT-L":
			return Transform3D(
				Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(-24, 0, 12.5)
			)
		"SIDE-SEAT-R":
			return Transform3D(
				Basis(Vector3(0, 0, 1), Vector3.UP, Vector3.LEFT), Vector3(24, 0, 12.5)
			)
		"SCORE-SMALL":
			return Transform3D(
				Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3(-20, 0, 30)
			)
	return Transform3D.IDENTITY



func route_obstacles() -> Array[Dictionary]:
	# Receiver avoidance is distinct from counted live units. Keep exact candidate envelopes.
	# Local poses preserve detached field-local geometry without querying a scene tree.
	var result: Array[Dictionary] = []
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var identity: String = "npc:AE-01:r1:" + site
		var model: Node3D = objects[identity]
		var envelope: AABB = (
			StadiumNpcExpandedNetV1.ENVELOPE if site == "RECEIVER-CATCH"
			else StadiumNpcExpandedTargetV1.ENVELOPE
		)
		var bounds: AABB = model.transform * envelope
		result.append({
			"center": bounds.get_center(),
			"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32,
			"copy": identity
		})
	return result


func _build() -> void:
	field = FieldDefinition.new()
	for key: String in FIELD:
		field.set(key, FIELD[key])
	_surface()
	var boundary: StadiumNpcExpandedBoundaryV1 = StadiumNpcExpandedBoundaryV1.new()
	boundary.name = "BoundaryGraph"
	add_child(boundary)
	boundary.build()
	_foul_lines(boundary.graph)
	for panel: Node3D in boundary.get_node("PanelVisuals").get_children():
		objects[panel.get_meta("npc_instance")] = panel
	for index in range(SITES.size()):
		var item: String = ITEMS[index]
		var site: String = SITES[index]
		var model: Node3D = (
			StadiumNpcExpandedTargetV1.create()
			if item == "ST-026"
			else (
				StadiumNpcExpandedNetV1.create()
				if item == "ST-025"
				else (
					StadiumNpcExpandedBleachersV1.create(item)
					if item == "ST-028"
					else StadiumNpcExpandedClubV1.create(item)
				)
			)
		)
		var identity: String = "npc:AE-01:r1:" + site
		model.transform = pose(site)
		model.set_meta("npc_instance", identity)
		model.set_meta("npc_site", site)
		# This alias is presentation correspondence, not ownership or receiver installation.
		model.set_meta("site", "RECEIVER-NET" if site == "RECEIVER-CATCH" else site)
		add_child(model)
		objects[identity] = model
		for body: StaticBody3D in model.get_node("Collision").get_children():
			body.set_meta("npc_instance", identity)


func _foul_lines(graph: StadiumNpcExpandedGraphV1) -> void:
	for socket: Dictionary in StadiumNpcExpandedFoulSitesV1.rows(graph):
		var side: int = -1 if socket.site == "FOUL-POLE-L" else 1
		var line: Node3D = get_node("FoulLine" + str(side))
		var end: Vector3 = socket.position
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0)
		(mesh.mesh as BoxMesh).size = Vector3(0.055, 0.025, end.length())


func _surface() -> void:
	var ground: AABB = AABB(Vector3(-32, -0.16, -16), Vector3(64, 0.16, 54))
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

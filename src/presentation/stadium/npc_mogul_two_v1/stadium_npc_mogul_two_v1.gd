class_name StadiumNpcMogulTwoV1
extends Node3D
## Retained AM-02/r1 detached 91-copy correspondence; no runtime installer.
## Source-derived infrastructure and genuine retained component leaves. No current catalog,
## mutable model factory, receiver, camera, lab, fixture, season or ownership installation.

const VERSION: int = 1
const BOUNDS: Rect2 = Rect2(-52, -30, 104, 88)
const MOUND_ORIGIN: Vector3 = Vector3(0.0, 0.0, 13.716)
const BOARD_SITE: String = "SCORE-SMALL"
const INSTANCE_PREFIX: String = "npc:AM-02:r1:"
const FIELD: Dictionary = {
	"id": "field.npc_venue",
	"display_name": "NPC Venue",
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
const COUNTS: Dictionary = {
	"ST-065": 13,
	"ST-065-T": 12,
	"ST-023": 16,
	"ST-022": 16,
	"ST-074": 2,
	"ST-021": 2,
	"ST-026": 1,
	"ST-073": 1,
	"ST-029": 4,
	"ST-031": 4,
	"ST-030": 4,
	"ST-053": 4,
	"ST-081": 5,
	"ST-085": 1,
	"ST-088": 1,
	"ST-039": 1,
	"ST-076": 4
}
const RECEIVER: Dictionary = {
	"id": "RX-TARGET-CLUB-NET-026073-v1",
	"version": 1,
	"archival_net_site": "RECEIVER-CATCH",
	"runtime_net_alias": "RECEIVER-NET",
	"target_site": "RECEIVER-PRIMARY",
	"target_item": "ST-026",
	"net_item": "ST-073",
	"net_model_version": 2,
	"target_transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.05],
	"net_transform": [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
	"target_envelope": [-0.6, 0, -0.675, 1.2, 1.645, 0.705],
	"net_envelope": [-5.1, 0, -5.15, 10.2, 6.9, 2.75],
	"surface_role": "RECEIVER_CONTAINMENT_FOUL",
	"target_surfaces": [
		"ST026_PANEL", "ST026_BASE_CROSS",
		"ST026_FRAME_SIDE-1", "ST026_FRAME_BAR-1", "ST026_LEGS-1", "ST026_BASE_SKID-1",
		"ST026_FRAME_SIDE1", "ST026_FRAME_BAR1", "ST026_LEGS1", "ST026_BASE_SKID1"
	],
	"net_panels": ["ST073_CENTER_NET", "ST073_NET_R", "ST073_NET_L"],
	"cleanup_z": -5.2,
	"camera_cut_z": -3.1,
	"camera_cut_half_width": 2.5,
	"step": 1.0 / 240.0,
	"timeout": 0.38,
	"target_flex_duration": 0.18,
	"target_flex_depth": 0.03,
	"net_settle_duration": 0.55,
	"net_flex_depth": 0.25,
	"installed": false
}
const SURFACE: Dictionary = {
	"bounds": [-52, -30, 104, 88],
	"geometry": "flat", "grass": "default", "ground": "default",
	"id": "AM-02-default-mogul-left-loft-v1", "lines": "default", "markings": "default",
	"physics": "unchanged-reference-field", "styles": [], "version": 1
}
const ROUTING: Dictionary = {
	"boundary": "PROTOTYPE-CLUB-DUGOUT-LEFT-LOFT-v1",
	"defender_radius": 0.54,
	"live_obstacles": [],
	"receiver_avoidance": {
		"coordinate_space": "field-local",
		"sites": ["RECEIVER-PRIMARY", "RECEIVER-CATCH"],
		"net_panel_spacing": 0.3, "net_panel_radius": 0.8,
		"body_radius": 0.32,
		"bounds": "target-and-two-net-anchor-half-xz-diagonal-plus-body-radius"
	},
	"version": 1
}
const SHARED_SEMANTICS: Dictionary = {
	"field": "FieldDefinition/DefinitionBase methods remain shared; all exports pinned above",
	"resolver": "BallPlayResolver/BallPlayState and StadiumBoundaryObserver remain shared",
	"visibility": "TemplateView adapts retained graph to shared StadiumRecipeBoundary APIs",
	"display": "Unbound retained display references shared MatchState/SeasonOwnership",
	"engine": "Mesh, physics, materials, font and Transform3D behavior are not frozen",
	"gate": "Independent correspondence is not historical runtime replay qualification"
}

var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "mogul"


class TemplateView extends StadiumRecipeBoundary:
	## Shared visibility compatibility seam only; no camera is installed.
	var retained: StadiumNpcMogulTwoGraphV1 = StadiumNpcMogulTwoGraphV1.new()

	func polygon() -> PackedVector2Array:
		return retained.polygon()

	func segments() -> Array[Dictionary]:
		return retained.segments()

	func outer_vertex(index: int) -> Vector2:
		return retained.outer_vertex(index)

	func identity() -> String:
		return retained.identity()


static func build() -> StadiumNpcMogulTwoV1:
	var property: StadiumNpcMogulTwoV1 = StadiumNpcMogulTwoV1.new()
	property.name = "AM02Revision1Correspondence"
	property.set_meta("npc_correspondence_only", true)
	if not property._build():
		property.free()
		return null
	return property


static func board_pose() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))

func route_obstacles() -> Array[Dictionary]:
	# This is the retained candidate's cup-shaped chain, not a filled giant net disc.
	# Every transform stays field-local, so a detached build never reads global_transform.
	var result: Array[Dictionary] = []
	for ends: Array in StadiumNpcClubNetV1.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			result.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	var target: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-PRIMARY"]
	_bounds_obstacle(result, target.transform * StadiumNpcClubTargetV1.ENVELOPE)
	var net: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-CATCH"]
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			_bounds_obstacle(result,
				net.transform * body.transform * shape.transform * AABB(-size / 2, size))
	return result


static func _bounds_obstacle(result: Array[Dictionary], bounds: AABB) -> void:
	result.append({"center": bounds.get_center(),
		"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32})


func _build() -> bool:
	field = FieldDefinition.new()
	for key: String in FIELD:
		field.set(key, FIELD[key])
	_surface()
	var boundary: StadiumNpcMogulTwoBoundaryV1 = StadiumNpcMogulTwoBoundaryV1.new()
	boundary.name = "ClubBoundary"
	add_child(boundary)
	if not boundary.build("left_loft"):
		return false
	_foul_lines(boundary.graph)
	for model: Node3D in boundary.items:
		_register(model, model.get_meta("candidate_site"))
	var rows: Dictionary = {}
	for row: Dictionary in StadiumNpcMogulTwoCandidateV1.definition().instances:
		rows[row.site] = row
	for site: String in ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]:
		var stand: Node3D = StadiumNpcMogulOneStandV1.lower()
		add_child(stand)
		stand.transform = StadiumNpcMogulTwoContractV1.transform(rows[site].transform)
		stand.set_meta("site", site)
		_register(stand, site)
		var concourse: Node3D = StadiumNpcMogulTwoStackV1._concourse()
		_layer(concourse, stand, site, ".CONCOURSE", "ST029-guard-v2_REAR-STAIR-SADDLE-v2")
		var upper: Node3D = StadiumNpcMogulTwoStackV1._upper()
		_layer(upper, stand, site, ".UPPER", "ST031-guard-v2_STRAIGHT-CANTILEVER-v2")
		upper.set_meta("concourse_instance", concourse.get_instance_id())
		var roof: Node3D = StadiumNpcMogulTwoStackV1._roof()
		_layer(roof, stand, site, ".ROOF-UPPER", "ST030-guard-v2_PYLON-CAP-v2")
		roof.set_meta("concourse_instance", concourse.get_instance_id())
		roof.set_meta("upper_instance", upper.get_instance_id())
		stand.set_meta("assembly_state", "BASE-UPPER-ROOF-v1")
	for site: String in ["BOWL-01", "BOWL-02", "BOWL-03", "BOWL-04", "BOWL-05",
		"JOIN-R", "JOIN-L", BOARD_SITE]:
		var model: Node3D
		if site.begins_with("BOWL"):
			model = StadiumNpcMogulOneBowlV1.create()
		elif site == "JOIN-R":
			model = StadiumNpcMogulTwoTransitionV1.create_right()
		elif site == "JOIN-L":
			model = StadiumNpcMogulTwoTransitionV1.create_left()
		else:
			model = StadiumNpcClubBoardV1.create("ST-039")
			model.get_node("Visual/ScoreDisplay").set_process(true)
		add_child(model)
		model.transform = StadiumNpcMogulTwoContractV1.transform(rows[site].transform)
		_register(model, site)
	for site: String in StadiumNpcMogulTwoTowerSitesV1.SITES:
		var tower: Node3D = StadiumNpcMogulTwoTowerV1.create()
		add_child(tower)
		if not StadiumNpcMogulTwoTowerSitesV1.place(tower, site):
			return false
		_register(tower, site)
	var counts: Dictionary = {}
	for model: Node3D in objects.values():
		var item: String = model.get_meta("stadium_item")
		counts[item] = int(counts.get(item, 0)) + 1
	return objects.size() == 91 and counts == COUNTS


func _layer(model: Node3D, lower: Node3D, site: String, suffix: String, face: String) -> void:
	model.transform = lower.transform
	model.set_meta("lower_instance", lower.get_instance_id())
	model.set_meta("site", site)
	model.set_meta("interface", face)
	add_child(model)
	_register(model, site + suffix)


func _register(model: Node3D, site: String, host: String = "field") -> void:
	var identity: String = INSTANCE_PREFIX + site
	# Replace authoring labels with admitted correspondence identity only.
	for key: String in ["candidate_site"]:
		if model.has_meta(key):
			model.remove_meta(key)
	model.set_meta("npc_instance", identity)
	model.set_meta("npc_site", site)
	model.set_meta("npc_host", host)
	objects[identity] = model
	var collision: Node = model.get_node_or_null("Collision")
	if collision != null:
		for body: StaticBody3D in collision.get_children():
			body.set_meta("npc_instance", identity)


func _foul_lines(graph: StadiumNpcClubGraphBaseV1) -> void:
	for socket: Dictionary in StadiumNpcClubFoulSitesV1.rows(graph):
		var side: int = -1 if socket.site == "FOUL-POLE-L" else 1
		var line: Node3D = get_node("FoulLine" + str(side))
		var end: Vector3 = socket.position
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0)
		(mesh.mesh as BoxMesh).size = Vector3(0.055, 0.025, end.length())


func _surface() -> void:
	var ground: AABB = AABB(Vector3(-52, -0.16, -30), Vector3(104, 0.16, 88))
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
	# Original AM02 inset preserves the complete land envelope without moving any item.
	for child: Node in get_children():
		if not child is Node3D:
			continue
		var edge: Node3D = child as Node3D
		if absf(edge.position.x) == 52:
			edge.position.x = signf(edge.position.x) * 51.96
		elif edge.position.z == -30:
			edge.position.z = -29.96
		elif edge.position.z == 58:
			edge.position.z = 57.96


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

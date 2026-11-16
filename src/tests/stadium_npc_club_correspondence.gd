class_name StadiumNpcClubCorrespondence
extends RefCounted
## Admission-only comparison of actual retained AC-01/r1 and qualified Offset authoring geometry.
## The authoring source briefly needs an in-tree host; the retained factory stays detached.
## No receiver/camera installation, runtime replay, physics or environment certificate is implied.
## Shared field, route and visibility compatibility is tested, not frozen in its entirety.

const FIELD: Dictionary = {
	"id": &"field.starter_backyard", "display_name": "Yard Club Field", "environment_style": 0,
	"fair_half_angle_degrees": 42.0, "safe_hit_z_m": 11.25, "deep_air_z_m": 17.0,
	"back_wall_z_m": 23.4, "home_run_height_m": 3.25, "dead_ball_z_m": 29.0,
	"shallow_anchor_z_m": 8.5, "middle_anchor_z_m": 14.0, "middle_center_anchor_z_m": 17.0,
	"deep_anchor_z_m": 19.5, "side_anchor_x_m": 5.5,
	"shallow_center_available": false, "middle_center_available": false
}
const COUNTS: Dictionary = {"ST-065": 27, "ST-022": 16, "ST-023": 16,
	"ST-074": 2, "ST-021": 2, "ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-053": 2, "ST-039": 1}
const GRAPH_ID: String = "PROTOTYPE-CLUB-DUGOUT-OFFSET-GABLES-v2"
const GRAPH_SHA256: String = "5f6f2c841e2783fc82c75f6f5432c422b4e996156fed2f1a42caa0b3c358e9ac"
const PREFIX: String = "npc:AC-01:r1:"
const BOARD_SITE: String = "SCORE-OFFSET-CORNER-R"
const META: Array[String] = [
	"stadium_item", "ball_surface", "surface_role", "surface_id", "boundary_segment",
	"represented_seats", "represented_audience", "wall_item", "wall_span", "wall_model_version",
	"club_surface", "surface_priority", "surface_kind", "wall_cap_height",
	"net_rest_vertices", "net_pocket_weights", "rest_vertices", "panel_width"
]
const SKIP_PROPERTIES: Array[String] = [
	"script", "resource_path", "resource_name", "resource_local_to_scene", "resource_scene_unique_id",
	"name", "unique_name_in_owner", "owner", "scene_file_path", "editor_description"
]

var _failures: Array[String] = []


static func verify(value: Dictionary, host: Node3D) -> Array[String]:
	var check: StadiumNpcClubCorrespondence = StadiumNpcClubCorrespondence.new()
	check._verify(value, host)
	return check._failures


func _verify(value: Dictionary, host: Node3D) -> void:
	var original: PackedByteArray = var_to_bytes(value)
	_transform_representation_controls()
	_check(_byte_hash(PackedByteArray([0, 255, 128, 1]))
		== "6509423fd9da5c225d2f8619ffae394b40f9f7686fee55a38c54b1424ac65f46",
		"raw geometry fingerprint hashes exact binary bytes including NUL and non-UTF8")
	_check(host != null and host.is_inside_tree()
		and host.global_transform == Transform3D.IDENTITY, "identity authoring comparison host")
	if host == null or not host.is_inside_tree() or host.global_transform != Transform3D.IDENTITY:
		return
	var actual: StadiumNpcClubV1 = StadiumNpcClubV1.build()
	var source: StadiumPropertyGeometry = StadiumClubOffsetVenueStudy.build(host)
	_check(actual != null and source != null, "independent complete Club factories build")
	if actual == null or source == null:
		if actual != null:
			actual.free()
		if source != null:
			source.free()
		return
	# No runtime adapter is configured. Detach source before physical/semantic comparison.
	host.remove_child(source)
	_check(not actual.is_inside_tree() and actual.get_parent() == null
		and actual.transform == Transform3D.IDENTITY and not source.is_inside_tree(),
		"retained construction stays detached at identity")
	for method: String in ["install", "install_bound", "bind_ball", "prepare_receiver",
		"configure_candidate", "observe"]:
		_check(not actual.has_method(method), "no retained runtime entry point " + method)
	_check(actual.tier == "club" and actual.objects.size() == 72, "exact complete 72-copy Club build")
	_check(not actual.get_node("ClubBoundary").has_method("bind_ball")
		and not actual.get_node("ClubBoundary").has_signal("contact_applied"),
		"retained boundary does not expose the authoring contact callback")
	_check(not actual.has_node("TemplateBackWall")
		and not actual.has_node("PitchReceiverPresentation"), "no stale wall or installed receiver")
	var baseline: Array[String] = _geometry(actual)
	var source_geometry: Array[String] = _geometry(source)
	if baseline != source_geometry:
		_diagnose_geometry(actual, source, "initial retained/source")
	_check(baseline == source_geometry,
		"actual full mesh arrays/materials/text/colliders/surface roles and field poses correspond")
	_instances(actual, source, value)
	_no_ownership(actual)
	_fields(actual, source)
	_substrate(actual)
	_check(StadiumNpcClubV1.SURFACE.id == value.presentation.profile
		and StadiumNpcClubV1.SURFACE.version == value.surface_version,
		"retained surface contract matches exact admitted presentation profile and version")
	_receiver(actual)
	_routes(actual, source)
	_graph(actual, source, value)
	_prisms(actual, source)
	_mutations(actual)
	_isolation(actual, source, baseline)
	_check(var_to_bytes(value) == original, "physical inspection never mutates the manifest")
	actual.free()
	source.free()


func _instances(actual: StadiumNpcClubV1, source: StadiumPropertyGeometry,
	value: Dictionary) -> void:
	var source_models: Dictionary = _source_models(source)
	var rows: Dictionary = {}
	for row: Dictionary in value.instances:
		_check(not rows.has(row.site), "literal unique site " + row.site)
		rows[row.site] = row
	var recipes: Array[Dictionary] = StadiumOffsetWallRecipes.back("ST-065")
	recipes.append_array(StadiumDugoutRecipe.panels(false))
	recipes.append_array(StadiumDugoutRecipe.panels(true))
	var panels: Node3D = actual.get_node("ClubBoundary/PanelVisuals")
	_check(rows.size() == 72 and source_models.size() == 72
		and panels.get_child_count() == 59 and recipes.size() == 59,
		"exact 72 unique copies and 27 back plus 32 side panel assemblies")
	var counts: Dictionary = {}
	for site: String in rows:
		var row: Dictionary = rows[site]
		var identity: String = PREFIX + site
		_check(actual.objects.has(identity) and source_models.has(site), "actual/source copy " + site)
		if not actual.objects.has(identity) or not source_models.has(site):
			continue
		var model: Node3D = actual.objects[identity]
		var independent: Node3D = source_models[site]
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		_check(row.instance == identity and model.get_meta("npc_instance", "") == identity
			and model.get_meta("npc_site", "") == site
			and model.get_meta("npc_host", "") == row.host
			and model.get_meta("stadium_item", "") == row.item
			and independent.get_meta("stadium_item", "") == row.item,
			"exact NPC identity/site/item " + site)
		_check(_relative(model, actual) == _relative(independent, source),
			"all twelve composed world-pose components match qualified source " + site)
		if row.item == "ST-053":
			var stand: String = site.trim_suffix(".ROOF-LOWER")
			_check(row.host == PREFIX + stand and actual.objects.has(row.host)
				and model.get_parent() == actual.objects[row.host]
				and model.transform == Transform3D.IDENTITY
				and _components(model.transform) == row.transform,
				"roof has explicit retained stand host and identity local pose " + site)
		else:
			_check(row.host == "field" and _components(_relative(model, actual)) == row.transform,
				"field-hosted literal transform matches physical pose " + site)
		if row.item in ["ST-065", "ST-022", "ST-023"]:
			_check(model.get_parent() == panels and panels.transform == Transform3D.IDENTITY
				and panels.get_parent().transform == Transform3D.IDENTITY
				and not model.has_node("PanelCollision"), "joined slabs own panel collision " + site)
		else:
			_check(model.get_node("Collision").get_child_count() > 0,
				"real constructed fixture collision " + site)
	_check(counts == COUNTS, "exact ten-item copy composition without fabricated assets")
	for index in range(recipes.size()):
		var recipe: Dictionary = recipes[index]
		var model: Node3D = panels.get_child(index)
		_check(model.get_meta("npc_site", "") == recipe.socket
			and model.transform == StadiumWallRecipes.placement(recipe)
			and model.get_meta("wall_span") == recipe.span,
			"exact retained front-face recipe and closure span " + recipe.socket)
	var board: Node3D = actual.objects[PREFIX + BOARD_SITE]
	_check(board.transform == Transform3D(Basis(Vector3.UP, deg_to_rad(225)), Vector3(27.5, 0, 24))
		and board.transform == StadiumClubOffsetVenueStudy.board_pose()
		and board.get_node("Visual/ScoreDisplay").get_child_count() == 6
		and board.find_children("*", "Label3D", true, false).size() == 7,
		"grounded unchanged manual board at corner yaw225 with all six score labels and header")
	_check(board.get_node("Visual/ScoreDisplay").shown == {"inning": 1, "home": 0, "away": 0}
		and board.get_node("Visual/ScoreDisplay")._match == null,
		"manual readout is unbound default construction, never a live match binding")


func _source_models(source: Node3D) -> Dictionary:
	var result: Dictionary = {}
	for node: Node in source.find_children("*", "Node3D", true, false):
		if node.has_meta("candidate_instance"):
			var site: String = node.get_meta("candidate_site", "")
			_check(not site.is_empty() and not result.has(site), "unique constructed source site " + site)
			result[site] = node
	return result


func _fields(actual: StadiumNpcClubV1, source: StadiumPropertyGeometry) -> void:
	_check(actual.field != source.field
		and actual.field != ContentDB.get_field(&"field.starter_backyard"), "fresh field resource")
	for key: String in FIELD:
		_check(actual.field.get(key) == FIELD[key] and source.field.get(key) == FIELD[key],
			"pinned field value and current-source correspondence " + key)
	_check(_resource(actual.field) == _resource(source.field), "all stored field exports correspond")
	var names: Array[String] = ["Shallow Right", "Shallow Center", "Shallow Left",
		"Middle Right", "Middle Center", "Middle Left", "Deep Right", "Deep Center", "Deep Left"]
	for index in range(-1, 11):
		var safe: int = clampi(index, 0, 8)
		_check(actual.field.fielder_anchor_name(index) == names[safe]
			and actual.field.fielder_anchor_name(index) == source.field.fielder_anchor_name(index),
			"shared exact anchor name and clamping " + str(index))
		var xs: Array[float] = [-5.5, 0.0, 5.5]
		var zs: Array[float] = [8.5, 14.0, 19.5]
		var expected: Vector3 = Vector3(xs[safe % 3], 0,
			17.0 if safe == 4 else zs[floori(float(safe) / 3.0)])
		_check(actual.field.fielder_anchor(index) == expected
			and actual.field.fielder_anchor(index) == source.field.fielder_anchor(index)
			and actual.field.is_fielder_anchor_available(index) == (safe != 1 and safe != 4)
			and actual.field.is_fielder_anchor_available(index)
			== source.field.is_fielder_anchor_available(index), "shared anchor semantics " + str(index))
	for point: Vector3 in [Vector3.ZERO, Vector3(0, 0, -0.5), Vector3(0, 0, -0.51),
		Vector3(0.45, 0, 0), Vector3(0.46, 0, 0), Vector3(22, 0, 24), Vector3(30, 0, 10)]:
		var expected: bool = point.z >= -0.5 and absf(point.x) <= (
			maxf(0, point.z) * tan(deg_to_rad(42.0)) + 0.45)
		_check(actual.field.is_fair_point(point) == expected
			and actual.field.is_fair_point(point) == source.field.is_fair_point(point),
			"shared mathematical foul-wedge semantics " + str(point))


func _substrate(actual: StadiumNpcClubV1) -> void:
	_check(StadiumNpcClubV1.SURFACE == {"bounds": [-40, -22, 80, 68], "geometry": "flat",
		"grass": "default", "ground": "default", "id": "AC-01-default-club-offset-v1", "lines": "default",
		"markings": "default", "physics": "unchanged-reference-field", "styles": [], "version": 1},
		"complete pinned default flat Club surface contract")
	_check(StadiumNpcClubV1.BOUNDS == Rect2(-40, -22, 80, 68), "exact Club land bounds")
	var ground: StaticBody3D = actual.get_node("PropertyGround")
	var collision: CollisionShape3D = ground.get_child(0)
	var visual: MeshInstance3D = ground.get_child(1)
	_check(ground.position == Vector3(0, -0.08, 12) and collision.shape is BoxShape3D
		and collision.shape.size == Vector3(80, 0.16, 68) and visual.mesh is BoxMesh
		and visual.mesh.size == collision.shape.size and ground.collision_layer == 1
		and ground.collision_mask == 2 and ground.get_meta("ball_surface") == &"ground",
		"real flat Club substrate preserves ground dimensions and physical layers")
	_check(actual.get_node("Mound").position == Vector3(0, 0.025, 13.716)
		and actual.get_node("Safe").position == Vector3(0, 0.016, 11.25)
		and actual.get_node("Deep").position == Vector3(0, 0.016, 17),
		"land changes do not scale field rules, mound or safe/deep marks")
	var graph: StadiumClubOffsetGraph = StadiumClubOffsetGraph.new()
	for socket: Dictionary in StadiumFoulPoleSites.rows(graph):
		var side: int = -1 if socket.site.ends_with("L") else 1
		var line: Node3D = actual.get_node("FoulLine" + str(side))
		var mesh: MeshInstance3D = line.get_child(0)
		var pole: Node3D = actual.objects[PREFIX + socket.site]
		_check(line.position == socket.position / 2 + Vector3(0, 0.02, 0)
			and line.basis == Basis.from_euler(Vector3(0,
				atan2(socket.position.x, socket.position.z), 0))
			and mesh.mesh.size == Vector3(0.055, 0.025, socket.position.length())
			and _relative(pole, actual).origin == socket.position and socket.split == 3.25,
			"painted line and true pole share exact 42-degree shaped graph intersection " + socket.site)
		var body: StaticBody3D = pole.get_node("Collision/Pole")
		var shape: CollisionShape3D = body.get_child(0)
		_check(shape.shape is CylinderShape3D and shape.shape.height == 8
			and is_equal_approx(shape.shape.radius, 0.09) and shape.shape.margin == 0
			and body.position == Vector3(0, 4, 0) and body.collision_layer == 33
			and body.collision_mask == 2 and body.get_meta("wall_cap_height") == 3.25
			and body.get_meta("surface_priority") == 500
			and body.get_meta("surface_role") == "FOUL_POLE_CONTACT",
			"single uninterrupted real pole collider and priority at retained wall-cap split")
	_check(StadiumFoulPoleModels.role_at(3.25, 3.25) == "FOUL_POLE_LOWER"
		and StadiumFoulPoleModels.role_at(3.251, 3.25) == "FOUL_POLE_UPPER",
		"shared pole cap classification remains compatible without installing resolver")


func _receiver(actual: StadiumNpcClubV1) -> void:
	var recipe: Dictionary = StadiumNpcClubV1.RECEIVER
	_check(recipe.id == "RX-TARGET-CLUB-NET-026073-v1" and recipe.version == 1
		and recipe.target_site == "RECEIVER-PRIMARY" and recipe.target_item == "ST-026"
		and recipe.archival_net_site == "RECEIVER-CATCH" and recipe.runtime_net_alias == "RECEIVER-NET"
		and recipe.net_item == "ST-073" and recipe.net_model_version == 2 and not recipe.installed
		and recipe.surface_role == "RECEIVER_CONTAINMENT_FOUL"
		and recipe.target_transform == [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.05]
		and recipe.net_transform == [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]
		and recipe.target_surfaces == StadiumTargetModels.surfaces()
		and recipe.net_panels == StadiumReceiverNetModels.PANELS.keys(),
		"exact retained receiver identity, pose, source surfaces and explicit no-install contract")
	_check(recipe.target_envelope == [-0.6, 0, -0.675, 1.2, 1.645, 0.705]
		and recipe.net_envelope == [-5.1, 0, -5.15, 10.2, 6.9, 2.75]
		and recipe.cleanup_z == StadiumClubPitchReceiver.PAIR_CLEANUP
		and recipe.camera_cut_z == StadiumClubPitchReceiver.CAMERA_CUT
		and recipe.camera_cut_half_width == 2.5 and recipe.step == StadiumPitchReceiver.STEP
		and recipe.timeout == StadiumClubPitchReceiver.PAIR_TIMEOUT
		and recipe.target_flex_duration == 0.18 and recipe.target_flex_depth == 0.03
		and recipe.net_settle_duration == StadiumReceiverNetModels.SETTLE
		and recipe.net_flex_depth == StadiumReceiverNetModels.FLEX,
		"retained receiver source contract matches current timing/envelopes without configuring runtime")
	_check(StadiumTargetModels.ENVELOPE == AABB(Vector3(-0.6, 0, -0.675),
		Vector3(1.2, 1.645, 0.705)) and StadiumReceiverNetModels.ENVELOPE == AABB(
		Vector3(-5.1, 0, -5.15), Vector3(10.2, 6.9, 2.75)), "pinned target and corrected cup envelopes")
	_check(StadiumClubPitchReceiver.PAIR_VERSION == 1 and StadiumClubPitchReceiver.PAIR_TIMEOUT == 0.38
		and StadiumClubPitchReceiver.PAIR_CLEANUP == -5.2 and StadiumClubPitchReceiver.CAMERA_CUT == -3.1
		and StadiumPitchReceiver.STEP == 1.0 / 240.0 and StadiumReceiverNetModels.FLEX == 0.25
		and StadiumReceiverNetModels.SETTLE == 0.55 and StadiumReceiverNetModels.VERSION == 2,
		"explicit shared receiver timing/camera-cut/flex compatibility, no runtime freeze")
	var target: Node3D = actual.objects[PREFIX + "RECEIVER-PRIMARY"]
	var net: Node3D = actual.objects[PREFIX + "RECEIVER-CATCH"]
	_check(_relative(target, actual) == Transform3D(Basis.IDENTITY, Vector3(0, 0, -1.05))
		and _relative(net, actual) == Transform3D.IDENTITY
		and target.get_node("Collision").get_child_count() == 10
		and net.get_node("Collision").get_child_count() == 13,
		"retained target and ST073-v2 full cup at original source poses")
	for model: Node3D in [target, net]:
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_check(body.get_meta("surface_role") == "RECEIVER_CONTAINMENT_FOUL"
				and body.get_meta("club_surface") == String(body.name)
				and body.get_meta("surface_priority") == 450
				and body.get_meta("surface_kind") == "receiver"
				and body.collision_layer == 33 and body.collision_mask == 2,
				"exact independent detached receiver contact role/layers " + String(body.name))
	for id: String in StadiumReceiverNetModels.PANELS:
		var body: StaticBody3D = net.get_node("Collision/" + id)
		var ends: Array = StadiumReceiverNetModels.PANELS[id]
		var shape: CollisionShape3D = body.get_child(0)
		_check(shape.shape is BoxShape3D
			and shape.shape.size == Vector3(ends[0].distance_to(ends[1]), 6.25, 0.006)
			and body.position.y == 3.375 and shape.shape.margin == 0,
			"corrected physical cup plane has exact endpoints/height/thickness " + id)


func _routes(actual: StadiumNpcClubV1, source: StadiumPropertyGeometry) -> void:
	_check(StadiumNpcClubV1.ROUTING == {"boundary": GRAPH_ID, "defender_radius": 0.54,
		"live_obstacles": [], "receiver_avoidance": {"coordinate_space": "field-local",
			"sites": ["RECEIVER-PRIMARY", "RECEIVER-CATCH"], "net_panel_spacing": 0.3,
			"net_panel_radius": 0.8, "body_radius": 0.32,
			"bounds": "target-and-two-net-anchor-half-xz-diagonal-plus-body-radius"}, "version": 1},
		"pinned cup-chain routing recipe and zero paid live units")
	# Independently evaluate the source ClubPropertyGeometry route recipe in local coordinates.
	# Calling configure_candidate would install receiver/camera layers and is deliberately avoided.
	var expected: Array[Dictionary] = []
	for ends: Array in StadiumReceiverNetModels.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			expected.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	var models: Dictionary = _source_models(source)
	var target: Node3D = models["RECEIVER-PRIMARY"]
	var net: Node3D = models["RECEIVER-CATCH"]
	_append_bounds(expected, _relative(target, source) * StadiumTargetModels.ENVELOPE)
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			_append_bounds(expected, _relative(shape, source) * AABB(-size / 2, size))
	var routes: Array[Dictionary] = actual.route_obstacles()
	_check(routes == expected and routes.size() == 42 and StadiumDefenderRoutes.BODY_RADIUS == 0.32,
		"exact 39 cup discs plus target/two anchors, independent of zero paid live units")
	for from: Vector3 in [Vector3(0, 0, 8.5), Vector3(-5.5, 0, 8.5), Vector3(5.5, 0, 14)]:
		for to: Vector3 in [Vector3(0, 0, -6), Vector3(6, 0, -5), Vector3(0, 0, 25)]:
			_check(StadiumDefenderRoutes.clear(from, to, routes)
				== StadiumDefenderRoutes.clear(from, to, expected)
				and StadiumDefenderRoutes.clip(from, to, routes)
				== StadiumDefenderRoutes.clip(from, to, expected)
				and StadiumDefenderRoutes.step(from, to, 12, routes)
				== StadiumDefenderRoutes.step(from, to, 12, expected), "shared circle-route compatibility")
	_check(not StadiumDefenderRoutes.clear(Vector3(0, 0, -3), Vector3(0, 0, -6), routes)
		and StadiumDefenderRoutes.clear(Vector3(0, 0, -3), Vector3(0.5, 0, -3), routes)
		and StadiumDefenderRoutes.clear(Vector3(0, 0, 8.5), Vector3(0, 0, 25), routes),
		"net rear blocks while corrected empty cup and forward field corridor remain navigable")
	if not routes.is_empty():
		routes[0].radius = 999
		_check(actual.route_obstacles() == expected, "route return mutation cannot alter retained recipe")


func _append_bounds(rows: Array[Dictionary], bounds: AABB) -> void:
	rows.append({"center": bounds.get_center(), "radius": Vector2(bounds.size.x,
		bounds.size.z).length() / 2 + StadiumDefenderRoutes.BODY_RADIUS})


func _graph(actual: StadiumNpcClubV1, source: StadiumPropertyGeometry, value: Dictionary) -> void:
	var retained: StadiumNpcClubGraphV1 = actual.get_node("ClubBoundary").graph
	var independent: StadiumClubOffsetGraph = source.get_node("ClubBoundary").graph
	_check(retained.identity() == GRAPH_ID and retained.signature() == GRAPH_SHA256
		and retained.signature() == independent.signature() and retained.signature() == value.graph.sha256
		and retained.polygon().size() == 19 and retained.segments().size() == 19,
		"exact independent nineteen-edge composed graph and admitted signature")
	_check(var_to_bytes(retained.segments()) == var_to_bytes(independent.segments())
		and retained.polygon() == independent.polygon(), "all graph vertices/roles/heights/priorities")
	var ids: Dictionary = {}
	var backs: int = 0
	var openings: int = 0
	for row: Dictionary in independent.segments():
		_check(not ids.has(row.id), "uniquely owned composed edge " + row.id)
		ids[row.id] = true
		backs += int(row.role == "BACK_WALL_TERMINAL")
		openings += int(row.role == "DUGOUT_OPENING_DEAD")
		var normal: Vector2 = independent.inward(row)
		for fraction: float in [0.01, 0.25, 0.5, 0.75, 0.99]:
			var at: Vector2 = row.a.lerp(row.b, fraction)
			for height: float in [0.05, row.height, row.height + 0.001, row.height + 20]:
				var from: Vector3 = Vector3(at.x + normal.x * 0.05, height, at.y + normal.y * 0.05)
				var to: Vector3 = from - Vector3(normal.x, 0, normal.y) * 0.1
				var event: Dictionary = retained.crossing(from, to)
				_check(var_to_bytes(event) == var_to_bytes(independent.crossing(from, to)),
					"retained graph crossing " + row.id)
				var expected: String = row.role
				if height > row.height:
					if row.role == "BACK_WALL_TERMINAL":
						expected = "BACK_CLEAR"
					elif row.role in ["SIDE_RETURN_LIVE", "DUGOUT_FACE_LIVE"]:
						expected = "SIDE_EXIT_DEAD"
					elif row.role == "DUGOUT_OPENING_DEAD":
						expected = "DUGOUT_EXTERIOR_DEAD"
				_check(event.get("role") == expected, "pinned height-sensitive role " + row.id)
	_check(backs == 6 and openings == 2, "exact six shaped backs and two closed navigation apertures")
	_check(retained.contains(Vector2(2, 27)) and not retained.contains(Vector2(-8, 26))
		and retained.crossing(Vector3(2, 1, 22), Vector3(2, 1, 27)).is_empty(),
		"asymmetric gables and deep pocket replace old infinite back plane")
	for index in range(19):
		_check(retained.outer_vertex(index) == independent.outer_vertex(index),
			"exact joined outer miter")
	for from: Vector3 in [Vector3(0, 0, 10), Vector3(2, 0, 27), Vector3(-8, 0, 22),
		Vector3(21, 0, 22), Vector3(-21, 0, 22), Vector3(40, 0, 40)]:
		for to: Vector3 in [Vector3(0, 0, 100), Vector3(0, 0, -20),
			Vector3(-40, 0, 24), Vector3(40, 0, 24), Vector3(2, 0, 27)]:
			_check(retained.clip(from, to) == independent.clip(from, to), "retained swept route clipping")
	_check(is_equal_approx(retained.clip(Vector3(2, 0, 10), Vector3(2, 0, 100)).z, 27.46)
		and retained.crossing(Vector3.INF, Vector3.ZERO).is_empty(),
		"pinned 0.54m boundary clearance and nonfinite rejection")


func _prisms(actual: StadiumNpcClubV1, source: StadiumPropertyGeometry) -> void:
	var boundary: Node3D = actual.get_node("ClubBoundary")
	var retained: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumNpcClubV1.TemplateView.new())
	var independent: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		source.get_node("ClubBoundary").graph)
	_check(var_to_bytes(retained.walls) == var_to_bytes(independent.walls)
		and retained.walls.size() == 19, "shared nineteen-edge joined-prism compatibility")
	var rows: Array[Dictionary] = boundary.graph.segments()
	var slabs: int = 0
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		if row.role.begins_with("DUGOUT"):
			_check(not boundary.has_node(row.id), "no hidden continuous slab across dugout " + row.id)
			continue
		slabs += 1
		var body: StaticBody3D = boundary.get_node(row.id)
		var shape: CollisionShape3D = body.get_child(0)
		_check(shape.shape is ConvexPolygonShape3D and shape.shape.points.size() == 8
			and shape.shape.margin == 0 and body.collision_layer == 33 and body.collision_mask == 2
			and body.get_meta("club_surface") == row.id and body.get_meta("surface_role") == row.role
			and body.get_meta("surface_priority") == row.priority,
			"actual exact joined slab and physical layers/roles " + row.id)
		var points: PackedVector3Array = shape.shape.points
		for corner in range(4):
			var at: Vector2 = retained.walls[index].polygon[corner]
			_check(points[corner] == Vector3(at.x, 0, at.y)
				and points[corner + 4] == Vector3(at.x, row.height, at.y),
				"shared visibility prism matches actual slab vertices " + row.id)
	_check(slabs == 13, "thirteen joined slabs leave six dugout spans to genuine dugout bodies")
	# Visibility may use back-only prisms; aperture placeholders are not physical wall claims.
	for index in range(rows.size() - 1, -1, -1):
		if rows[index].role != "BACK_WALL_TERMINAL":
			retained.walls.remove_at(index)
			independent.walls.remove_at(index)
	_check(retained.walls.size() == 6 and retained.blocked(Vector3(2, 1, 27), Vector3(2, 1, 30), 0)
		and not retained.blocked(Vector3(0, 5, 0), Vector3(2, 1, 27), 0),
		"six physical back-prism controls block rear rays and leave deep pocket visible")
	for point: Vector3 in [Vector3(2, 1, 27), Vector3(-8, 1, 22), Vector3(22, 1, 24)]:
		_check(retained.margin(point) == independent.margin(point),
			"shared acute-miter visibility margin")


func _geometry(root: Node3D) -> Array[String]:
	# Hash actual serialized node data, never supplied model/source/manifest signatures.
	# Sorted node fingerprints preserve multiplicity and every composed physical transform while
	# allowing the two admitted roof hosts to replace their authoring sibling hierarchy.
	var result: Array[String] = []
	_collect(root, Transform3D.IDENTITY, true, result)
	result.sort()
	return result


func _collect(node: Node, parent_pose: Transform3D, parent_visible: bool,
	result: Array[String], records: Array[Dictionary] = [],
	path: String = "", diagnostic: bool = false) -> void:
	var pose: Transform3D = parent_pose
	var visible: bool = parent_visible
	var data: Dictionary = {"class": node.get_class()}
	if node is Node3D:
		pose = node.transform if node.top_level else parent_pose * node.transform
		visible = parent_visible and node.visible
		data["transform"] = _canonical_transform(pose)
		data["visible"] = visible
		data["top_level"] = node.top_level
	if node is GeometryInstance3D:
		for key: String in ["layers", "cast_shadow", "gi_mode", "transparency", "sorting_offset",
			"sorting_use_aabb_center", "extra_cull_margin", "custom_aabb", "lod_bias",
			"visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin",
			"visibility_range_end_margin", "visibility_range_fade_mode", "ignore_occlusion_culling"]:
			data[key] = _content(node.get(key))
		data["material_override"] = _resource(node.material_override)
		data["material_overlay"] = _resource(node.material_overlay)
	if node is MeshInstance3D:
		data["mesh"] = _mesh(node.mesh)
		data["surface_overrides"] = []
		if node.mesh != null:
			for index in range(node.mesh.get_surface_count()):
				data.surface_overrides.append(_resource(node.get_surface_override_material(index)))
	if node is MultiMeshInstance3D:
		data["multimesh"] = _resource(node.multimesh)
		data["multimesh_mesh"] = _mesh(node.multimesh.mesh) if node.multimesh != null else {}
	if node is Label3D:
		data["label"] = _stored(node)
	if node is CollisionObject3D:
		data["collision"] = [node.collision_layer, node.collision_mask, node.collision_priority]
	if node is StaticBody3D:
		data["body_material"] = _resource(node.physics_material_override)
		data["body_velocity"] = [node.constant_linear_velocity, node.constant_angular_velocity]
	if node is CollisionShape3D:
		data["disabled"] = node.disabled
		data["shape"] = _resource(node.shape)
	for key: String in META:
		if node.has_meta(key):
			data[key] = _content(node.get_meta(key))
	var fingerprint: String = _byte_hash(var_to_bytes(data))
	result.append(fingerprint)
	var node_path: String = path + "/" + String(node.name)
	if diagnostic:
		records.append({"path": node_path, "name": String(node.name),
			"fingerprint": fingerprint, "data": data})
	for child: Node in node.get_children():
		_collect(child, pose, visible, result, records, node_path, diagnostic)


func _byte_hash(bytes: PackedByteArray) -> String:
	# Hash the Variant serialization directly; never decode binary geometry as UTF-8.
	var context: HashingContext = HashingContext.new()
	var status: int = context.start(HashingContext.HASH_SHA256)
	_check(status == OK, "geometry SHA256 context starts")
	if status != OK:
		return ""
	status = context.update(bytes)
	_check(status == OK, "geometry SHA256 accepts complete serialized bytes")
	if status != OK:
		return ""
	var digest: PackedByteArray = context.finish()
	_check(digest.size() == 32, "geometry SHA256 yields a complete digest")
	return digest.hex_encode()


func _mesh(mesh: Mesh) -> Dictionary:
	if mesh == null:
		return {"null": true}
	var result: Dictionary = {"class": mesh.get_class(), "aabb": mesh.get_aabb(), "surfaces": []}
	for index in range(mesh.get_surface_count()):
		var row: Dictionary = {"arrays": mesh.surface_get_arrays(index),
			"blend_arrays": mesh.surface_get_blend_shape_arrays(index),
			"material": _resource(mesh.surface_get_material(index))}
		if mesh is ArrayMesh:
			row["primitive"] = mesh.surface_get_primitive_type(index)
		result.surfaces.append(row)
	return result


func _resource(value: Resource) -> Dictionary:
	return {"null": true} if value == null else {
		"class": value.get_class(), "properties": _stored(value)}


func _stored(value: Object) -> Dictionary:
	# All stored material parameters are covered, including shading/transparency/emission,
	# vertex-color/UV flags, texture resources, surface materials and null overrides.
	var result: Dictionary = {}
	for property: Dictionary in value.get_property_list():
		var key: String = property.name
		if int(property.usage) & PROPERTY_USAGE_STORAGE == 0 or SKIP_PROPERTIES.has(key) \
			or key.begins_with("metadata/"):
			continue
		result[key] = _content(value.get(key))
	return result


func _content(value: Variant) -> Variant:
	if value is Resource:
		return _resource(value)
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_content(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _content(value[key])
		return result
	if value is Object or value is RID or value is Callable:
		_check(false, "unreviewed opaque runtime value cannot pass actual resource correspondence")
		return "unreviewed-opaque-value"
	return value


func _mutations(actual: StadiumNpcClubV1) -> void:
	var target: Node3D = actual.objects[PREFIX + "RECEIVER-PRIMARY"]
	var baseline: Array[String] = _geometry(target)
	var mesh: BoxMesh = target.get_node("Visual/ST026_PANEL").mesh
	var size: Vector3 = mesh.size
	mesh.size.x += 0.01
	_check(_geometry(target) != baseline, "unchanged metadata cannot conceal real mesh mutation")
	mesh.size = size
	var collision: CollisionShape3D = target.get_node("Collision/ST026_PANEL").get_child(0)
	size = collision.shape.size
	collision.shape.size.z += 0.01
	_check(_geometry(target) != baseline, "unchanged metadata cannot conceal real collider mutation")
	collision.shape.size = size
	var material: StandardMaterial3D = target.get_node("Visual/ST026_PANEL").material_override
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_check(_geometry(target) != baseline, "material comparison covers transparency mode")
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.emission_enabled = true
	_check(_geometry(target) != baseline, "material comparison covers emission flags")
	material.emission_enabled = false
	var body: StaticBody3D = target.get_node("Collision/ST026_PANEL")
	body.collision_layer = 65
	_check(_geometry(target) != baseline, "physical collision layers are inspected")
	body.collision_layer = 33
	body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	_check(_geometry(target) != baseline, "physical contact roles are inspected")
	body.set_meta("surface_role", "RECEIVER_CONTAINMENT_FOUL")
	_check(_geometry(target) == baseline, "target geometry/material/collider controls restore exactly")
	var board: Node3D = actual.objects[PREFIX + BOARD_SITE]
	baseline = _geometry(board)
	var label: Label3D = board.get_node("Visual/ScoreDisplay").get_child(0)
	var original: String = label.text
	label.text = "ALTERED"
	_check(_geometry(board) != baseline, "actual score label content is inspected")
	label.text = original
	_check(_geometry(board) == baseline, "score label restoration is exact")
	var slab: StaticBody3D = actual.get_node("ClubBoundary/BACK-01")
	baseline = _geometry(slab)
	var shape: ConvexPolygonShape3D = slab.get_child(0).shape
	var points: PackedVector3Array = shape.points
	var changed: PackedVector3Array = points.duplicate()
	changed[0].x += 0.01
	shape.points = changed
	_check(_geometry(slab) != baseline, "real joined hull mutation cannot hide behind graph metadata")
	shape.points = points
	_check(_geometry(slab) == baseline, "joined hull control restores exactly")


func _isolation(actual: StadiumNpcClubV1, source: StadiumPropertyGeometry,
	baseline: Array[String]) -> void:
	var target: Node3D = actual.objects[PREFIX + "RECEIVER-PRIMARY"]
	target.position.x = 0.5
	target.get_node("Visual/ST026_PANEL").mesh.size.x += 0.1
	target.get_node("Visual/ST026_PANEL").material_override.albedo_color = Color.RED
	target.get_node("Collision/ST026_PANEL").get_child(0).shape.size.z += 0.1
	actual.field.safe_hit_z_m = 1
	var fresh: StadiumNpcClubV1 = StadiumNpcClubV1.build()
	var fresh_geometry: Array[String] = _geometry(fresh)
	var source_geometry: Array[String] = _geometry(source)
	if fresh_geometry != baseline or source_geometry != baseline:
		print("AC geometry isolation: fresh_matches_baseline=", fresh_geometry == baseline,
			" source_matches_baseline=", source_geometry == baseline)
		if fresh_geometry != source_geometry:
			_diagnose_geometry(fresh, source, "fresh retained/source")
	_check(fresh.field != actual.field and fresh.field.safe_hit_z_m == 11.25
		and fresh_geometry == baseline and source_geometry == baseline,
		"mutations affect neither fresh retained construction nor independent qualified source")
	fresh.free()


func _no_ownership(node: Node) -> void:
	for key: String in ["owned_copy", "candidate_instance", "candidate_site", "candidate_mount",
		"candidate_venue",
		"stadium_snapshot", "stadium_property", "property_signature", "wall_manifest",
		"stadium_candidate_only", "stadium_club_candidate", "boundary_signature"]:
		_check(not node.has_meta(key), "no human/candidate/installation metadata " + key)
	if node.has_meta("stadium_item"):
		_check(COUNTS.has(node.get_meta("stadium_item")), "no unauthorized catalog item in actual tree")
	for child: Node in node.get_children():
		_no_ownership(child)


func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			result = parent.transform * result
		parent = parent.get_parent()
	_check(parent == root, "every NPC instance descends from its exact field root")
	return result


func _components(value: Transform3D) -> Array:
	var result: Array = []
	for vector: Vector3 in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)


func _diagnose_geometry(actual: Node3D, source: Node3D, label: String) -> void:
	# Failure-only evidence. These records never replace or relax exact byte equality.
	var left: Array[Dictionary] = []
	var right: Array[Dictionary] = []
	var hashes: Array[String] = []
	_collect(actual, Transform3D.IDENTITY, true, hashes, left, "", true)
	hashes.clear()
	_collect(source, Transform3D.IDENTITY, true, hashes, right, "", true)
	var buckets: Dictionary = {}
	for row: Dictionary in right:
		if not buckets.has(row.fingerprint):
			buckets[row.fingerprint] = []
		buckets[row.fingerprint].append(row)
	var unmatched: Array[Dictionary] = []
	for row: Dictionary in left:
		if buckets.has(row.fingerprint) and not buckets[row.fingerprint].is_empty():
			buckets[row.fingerprint].pop_back()
		else:
			unmatched.append(row)
	var remaining: Array[Dictionary] = []
	for bucket: Array in buckets.values():
		for row: Dictionary in bucket:
			remaining.append(row)
	print("AC geometry diagnostic ", label, ": nodes=", left.size(), "/", right.size(),
		" unmatched=", unmatched.size(), "/", remaining.size())
	for index in range(mini(unmatched.size(), 8)):
		var row: Dictionary = unmatched[index]
		var match_index: int = -1
		for candidate in range(remaining.size()):
			var other: Dictionary = remaining[candidate]
			if row.data["class"] == other.data["class"] and row.data.get("transform") \
				== other.data.get("transform"):
				match_index = candidate
				if row.name == other.name:
					break
		if match_index < 0:
			print("AC unmatched retained node ", row.path, " ", _diagnostic_value(row.data))
			continue
		var other: Dictionary = remaining[match_index]
		remaining.remove_at(match_index)
		var differences: Array[String] = []
		_diagnostic_differences(row.data, other.data, "", differences)
		print("AC node pair ", row.path, " <> ", other.path)
		for difference: String in differences:
			print("AC property mismatch ", difference)
	for index in range(mini(remaining.size(), 4)):
		print("AC remaining source node ", remaining[index].path,
			" ", _diagnostic_value(remaining[index].data))


func _diagnostic_differences(left: Variant, right: Variant, path: String,
	result: Array[String]) -> void:
	if result.size() >= 4 or var_to_bytes(left) == var_to_bytes(right):
		return
	if left is Dictionary and right is Dictionary:
		var keys: Array = left.keys()
		for key: Variant in right:
			if not keys.has(key):
				keys.append(key)
		for key: Variant in keys:
			if not left.has(key) or not right.has(key):
				result.append(path + "." + str(key) + " missing key on one side")
			else:
				_diagnostic_differences(left[key], right[key], path + "." + str(key), result)
			if result.size() >= 4:
				return
	elif left is Array and right is Array:
		if left.size() != right.size():
			result.append(path + " array sizes " + str(left.size()) + "/" + str(right.size()))
		for index in range(mini(left.size(), right.size())):
			_diagnostic_differences(left[index], right[index], path + "[" + str(index) + "]", result)
			if result.size() >= 4:
				return
	elif typeof(left) >= TYPE_PACKED_BYTE_ARRAY and typeof(left) == typeof(right):
		if left.size() != right.size():
			result.append(path + " packed sizes " + str(left.size()) + "/" + str(right.size()))
		for index in range(mini(left.size(), right.size())):
			_diagnostic_differences(left[index], right[index], path + "[" + str(index) + "]", result)
			if result.size() >= 4:
				return
	else:
		result.append(path + " retained=" + _diagnostic_value(left)
			+ " source=" + _diagnostic_value(right))
	if result.is_empty():
		result.append(path + " serialized ordering/type differs: " + _diagnostic_value(left)
			+ " <> " + _diagnostic_value(right))


func _diagnostic_value(value: Variant) -> String:
	var bytes: PackedByteArray = var_to_bytes(value)
	return "type=" + str(typeof(value)) + " bytes=" + str(bytes.size()) + " sha=" \
		+ _byte_hash(bytes) + " value=" + str(value).left(160) \
		+ (" raw=" + bytes.hex_encode() if bytes.size() <= 64 else "")


func _canonical_transform(value: Transform3D) -> Transform3D:
	# Fingerprint representation only. Preserve every nonzero float32 bit, including subnormals.
	# Do not change the actual nodes or matrices used for child composition.
	var result: Transform3D = value
	for column in range(3):
		var vector: Vector3 = result.basis[column]
		for component in range(3):
			if is_finite(vector[component]) and vector[component] == 0.0:
				vector[component] = 0.0
		result.basis[column] = vector
	for component in range(3):
		if is_finite(result.origin[component]) and result.origin[component] == 0.0:
			result.origin[component] = 0.0
	return result


func _transform_representation_controls() -> void:
	var zero: Transform3D = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)
	var zero_bytes: PackedByteArray = var_to_bytes(zero)
	var negative_zero: float = PackedByteArray([0, 0, 0, 128]).decode_float(0)
	var smallest: float = PackedByteArray([1, 0, 0, 0]).decode_float(0)
	_check(smallest > 0.0, "smallest positive float32 control is genuinely nonzero")
	for index in range(12):
		var signed: Transform3D = _transform_component(zero, index, negative_zero)
		var signed_bytes: PackedByteArray = var_to_bytes(signed)
		_check(signed_bytes != zero_bytes
			and var_to_bytes(_canonical_transform(signed)) == zero_bytes
			and var_to_bytes(signed) == signed_bytes,
			"signed-zero transform equivalence without input mutation component " + str(index))
		for tiny: float in [smallest, -smallest]:
			var perturbed: Transform3D = _transform_component(zero, index, tiny)
			var raw: PackedByteArray = var_to_bytes(perturbed)
			var canonical: PackedByteArray = var_to_bytes(_canonical_transform(perturbed))
			_check(raw != zero_bytes and canonical == raw
				and _byte_hash(canonical) != _byte_hash(zero_bytes),
				"smallest signed nonzero float32 stays distinct component " + str(index))
	# The rule is confined to composed Transform3D fingerprints, never mesh/material arrays.
	_check(var_to_bytes(PackedFloat32Array([negative_zero]))
		!= var_to_bytes(PackedFloat32Array([0.0])),
		"non-transform arrays retain signed-zero bytes without normalization")


func _transform_component(value: Transform3D, index: int, component: float) -> Transform3D:
	var result: Transform3D = value
	if index < 9:
		var column: int = floori(float(index) / 3.0)
		var vector: Vector3 = result.basis[column]
		vector[index % 3] = component
		result.basis[column] = vector
	else:
		result.origin[index - 9] = component
	return result

class_name StadiumNpcExpandedCorrespondence
extends RefCounted
## Admission-only comparison of actual retained AE-01/r1 and current authoring construction.
## Does not install a receiver/camera, run physics, or grant runtime/environment qualification.
## Sources: ExpandedVenueStudy, PropertyGeometry, RecipeBoundary, WallRecipes and all five
## source model families. Shared FieldDefinition/DefenderRoutes/WallViewPrisms semantics are
## exercised explicitly below; source hashes alone do not freeze those execution dependencies.

const FIELD: Dictionary = {
	"id": &"field.starter_backyard", "display_name": "Yard Club Field", "environment_style": 0,
	"fair_half_angle_degrees": 42.0, "safe_hit_z_m": 11.25, "deep_air_z_m": 17.0,
	"back_wall_z_m": 23.4, "home_run_height_m": 3.25, "dead_ball_z_m": 29.0,
	"shallow_anchor_z_m": 8.5, "middle_anchor_z_m": 14.0, "middle_center_anchor_z_m": 17.0,
	"deep_anchor_z_m": 19.5, "side_anchor_x_m": 5.5,
	"shallow_center_available": false, "middle_center_available": false
}
const COUNTS: Dictionary = {"ST-024": 22, "ST-026": 1, "ST-025": 1, "ST-028": 2, "ST-039": 1}
const GRAPH_ID: String = "PERIM-BACKYARD-ANGLED-BX1-v1"
const GRAPH_SHA256: String = "569e73dd264710a582eae5ef96e7fb554657f06629ff77b3b401daa308c492e7"
const META: Array[String] = [
	"stadium_item", "ball_surface", "surface_role", "surface_id", "boundary_segment",
	"represented_seats", "represented_audience", "wall_item", "wall_span", "wall_model_version",
	"site", "net_rest_vertices", "net_pocket_weights"
]
const SKIP_PROPERTIES: Array[String] = [
	"script", "resource_path", "resource_name", "resource_local_to_scene", "resource_scene_unique_id",
	"name", "unique_name_in_owner", "owner", "scene_file_path", "editor_description"
]

var _failures: Array[String] = []


static func verify(value: Dictionary) -> Array[String]:
	var check: StadiumNpcExpandedCorrespondence = StadiumNpcExpandedCorrespondence.new()
	check._verify(value)
	return check._failures


func _verify(value: Dictionary) -> void:
	var original: PackedByteArray = var_to_bytes(value)
	var actual: StadiumNpcExpandedV1 = StadiumNpcExpandedV1.build()
	var source: StadiumExpandedProperty = StadiumExpandedVenueStudy.build()
	_check(actual != null and source != null, "two independent complete Expanded factories build")
	if actual == null or source == null:
		if actual != null:
			actual.free()
		if source != null:
			source.free()
		return
	_check(not actual.is_inside_tree() and actual.get_parent() == null
		and actual.transform == Transform3D.IDENTITY and not source.is_inside_tree(),
		"correspondence constructs detached identity-root scenes")
	for method: String in ["install", "install_bound", "bind_ball", "prepare_receiver"]:
		_check(not actual.has_method(method), "retained root exposes no runtime adapter " + method)
	_check(actual.tier == "expanded" and actual.objects.size() == 27
		and actual.get_child_count() == source.get_child_count(), "exact complete expanded assembly")
	_check(not actual.has_node("TemplateBackWall")
		and not actual.has_node("PitchReceiverPresentation"), "no stale wall or installed receiver")
	var baseline: PackedByteArray = var_to_bytes(_geometry(actual))
	_check(baseline == var_to_bytes(_geometry(source)),
		"all constructed mesh arrays, transforms, materials, text, colliders and surfaces correspond")
	_instances(actual, source, value)
	_no_ownership(actual)
	_fields(actual, source)
	_substrate(actual, source)
	_receiver(actual)
	_routes(actual, source)
	_graph(actual, source, value)
	_prisms(actual, source)
	_mutations(actual, baseline)
	_isolation(actual, source, baseline)
	_check(var_to_bytes(value) == original, "physical inspection never mutates the manifest")
	actual.free()
	source.free()


func _instances(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty,
	value: Dictionary) -> void:
	var rows: Dictionary = {}
	for row: Dictionary in value.instances:
		rows[row.site] = row
	var source_rows: Array[Dictionary] = StadiumWallRecipes.back("deeper_center", "ST-024")
	var panels: Node3D = actual.get_node("BoundaryGraph/PanelVisuals")
	var source_panels: Node3D = source.get_node("BoundaryGraph/PanelVisuals")
	_check(rows.size() == 27 and panels.get_child_count() == 22
		and source_panels.get_child_count() == 22, "all 27 unique sites and 22 back-only panels")
	var counts: Dictionary = {}
	for site: String in rows:
		var row: Dictionary = rows[site]
		var identity: String = "npc:AE-01:r1:" + site
		_check(actual.objects.has(identity), "constructed exact NPC instance " + site)
		if not actual.objects.has(identity):
			continue
		var model: Node3D = actual.objects[identity]
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		_check(row.instance == identity and row.host == "field"
			and model.get_meta("npc_instance", "") == identity
			and model.get_meta("npc_site", "") == site
			and model.get_meta("stadium_item", "") == row.item,
			"exact item, NPC identity, site and field host " + site)
		_check(_components(_relative(model, actual)) == row.transform,
			"real field-relative pose equals all 12 literal components " + site)
		if row.item == "ST-024":
			var index: int = int(site.right(2)) - 1
			_check(index >= 0 and index < source_rows.size(), "source panel index " + site)
			if index < 0 or index >= source_rows.size():
				continue
			var recipe: Dictionary = source_rows[index]
			_check(model.get_parent() == panels and panels.transform == Transform3D.IDENTITY
				and panels.get_parent().transform == Transform3D.IDENTITY
				and model == panels.get_child(index) and recipe.socket == site
				and model.transform == StadiumWallRecipes.placement(recipe)
				and model.transform == source_panels.get_child(index).transform,
				"panel hierarchy supplies exact authored field host and pose " + site)
			_check(not model.has_node("PanelCollision")
				and model.get_meta("wall_span") == recipe.span,
				"joined slabs replace overlapping per-panel collision " + site)
		else:
			var independent: Node3D = source.objects["npc-candidate:AE-01:" + site]
			_check(model.get_parent() == actual and model.transform == independent.transform
				and model.transform == StadiumExpandedVenueStudy.pose(site),
				"original fixture field host and authored pose " + site)
			_check(model.get_node("Collision").get_child_count() > 0,
				"fixture retains real collision members " + site)
	_check(counts == COUNTS, "exact 22/1/1/2/1 copy composition with no granted extra assets")
	var board: Node3D = actual.objects["npc:AE-01:r1:SCORE-SMALL"]
	_check(board.get_node("Visual/ScoreDisplay").get_child_count() == 6
		and board.find_children("*", "Label3D", true, false).size() == 7,
		"manual board retains all six score labels and its original header")


func _fields(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty) -> void:
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


func _substrate(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty) -> void:
	var expected: Dictionary = {"bounds": [-32, -16, 64, 54], "geometry": "flat",
		"grass": "default", "ground": "default", "id": "AE-01-default-expanded-v1",
		"lines": "default", "markings": "default", "physics": "unchanged-reference-field",
		"styles": [], "version": 1}
	_check(StadiumNpcExpandedV1.SURFACE == expected, "complete default flat surface contract")
	var authored: Dictionary = StadiumExpandedVenueStudy.canonical().surface
	for key: String in authored:
		_check(expected.has(key) and expected[key] == authored[key],
			"default surface corresponds to authoring source " + key)
	var ground: StaticBody3D = actual.get_node("PropertyGround")
	var collision: CollisionShape3D = ground.get_child(0)
	var visual: MeshInstance3D = ground.get_child(1)
	_check(ground.position == Vector3(0, -0.08, 11) and collision.shape is BoxShape3D
		and collision.shape.size == Vector3(64, 0.16, 54) and visual.mesh is BoxMesh
		and visual.mesh.size == collision.shape.size and ground.collision_layer == 1
		and ground.collision_mask == 2 and ground.get_meta("ball_surface") == &"ground",
		"real expanded substrate is the exact default flat ground volume")
	_check(actual.get_node("Mound").position == Vector3(0, 0.025, 13.716)
		and actual.get_node("Safe").position == Vector3(0, 0.016, 11.25)
		and actual.get_node("Deep").position == Vector3(0, 0.016, 17),
		"real mound, safe and deep markings retain field coordinates")
	for socket: Dictionary in StadiumFoulPoleSites.rows(source.get_node("BoundaryGraph").graph):
		var side: int = -1 if socket.site.ends_with("L") else 1
		var line: Node3D = actual.get_node("FoulLine" + str(side))
		var mesh: MeshInstance3D = line.get_child(0)
		_check(line.position == socket.position / 2 + Vector3(0, 0.02, 0)
			and line.basis == Basis.from_euler(Vector3(0,
				atan2(socket.position.x, socket.position.z), 0))
			and mesh.mesh.size == Vector3(0.055, 0.025, socket.position.length())
			and line.get_child_count() == 1 and not line is CollisionObject3D,
			"painted foul ray reaches exact shaped intersection without a physical pole")


func _receiver(actual: StadiumNpcExpandedV1) -> void:
	var recipe: Dictionary = StadiumNpcExpandedV1.RECEIVER
	var authored: Dictionary = StadiumExpandedVenueStudy.canonical().receiver
	for key: String in authored:
		_check(recipe.has(key) and recipe[key] == authored[key],
			"receiver contract corresponds to independent source " + key)
	_check(recipe.version == 1 and recipe.id == "RX-TARGET-NET-026025-v2"
		and recipe.blockout == "RX-CATCH025-BLOCKOUT-v2"
		and recipe.target_site == "RECEIVER-PRIMARY" and recipe.target_item == "ST-026"
		and recipe.net_item == "ST-025" and recipe.surface_role == "RECEIVER_CONTAINMENT_FOUL"
		and recipe.target_transform == [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -1.05]
		and recipe.net_transform == [1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, -2.20],
		"exact target/net-v2 recipe identity and terminal role")
	_check(recipe.target_envelope == [-0.6, 0, -0.675, 1.2, 1.645, 0.705]
		and recipe.net_envelope == [-1.9, 0, -0.85, 3.8, 2.7, 0.89]
		and recipe.cleanup_z == -3.10 and recipe.cleanup_z == StadiumPairedReceiver.PAIR_CLEANUP_Z
		and recipe.step == 1.0 / 240.0 and recipe.step == StadiumPitchReceiver.STEP
		and recipe.timeout == 0.24 and recipe.timeout == StadiumPitchReceiver.TIMEOUT
		and recipe.target_flex_duration == 0.18 and recipe.target_flex_depth == 0.03
		and recipe.net_pocket_duration == 0.24 and recipe.net_flex_depth == 0.16
		and recipe.net_flex_depth == StadiumNetModels.FLEX_DEPTH,
		"corrected envelopes and shared receiver timing/flex compatibility")
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var target: bool = site == "RECEIVER-PRIMARY"
		var model: Node3D = actual.objects["npc:AE-01:r1:" + site]
		var surfaces: Array[String] = StadiumTargetModels.surfaces() if target else (
			StadiumNetModels.surfaces())
		_check(recipe["target_surfaces" if target else "net_surfaces"] == surfaces
			and model.get_node("Collision").get_child_count() == 10
			and _components(model.transform) == _components(Transform3D(Basis.IDENTITY,
				Vector3(0, 0, -1.05 if target else -2.20))), "complete physical receiver " + site)
		_check(model.get_meta("site") == ("RECEIVER-PRIMARY" if target else "RECEIVER-NET"),
			"archival CATCH remains an explicit runtime NET alias")
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_check(surfaces.has(String(body.name)) and body.get_meta("surface_id") == String(body.name)
				and body.get_meta("surface_role") == "RECEIVER_CONTAINMENT_FOUL"
				and body.get_meta("ball_surface") == &"stadium_receiver"
				and body.get_meta("npc_instance") == "npc:AE-01:r1:" + site
				and body.collision_layer == 1 and body.collision_mask == 2,
				"actual detached receiver surface has exact role/layers " + String(body.name))
	var net: Node3D = actual.objects["npc:AE-01:r1:RECEIVER-CATCH"]
	var target: Node3D = actual.objects["npc:AE-01:r1:RECEIVER-PRIMARY"]
	var nb: AABB = net.transform * StadiumNetModels.ENVELOPE
	var tb: AABB = target.transform * StadiumTargetModels.ENVELOPE
	_check(is_equal_approx(nb.position.z, -3.05) and is_equal_approx(nb.end.z, -2.16)
		and is_equal_approx(tb.position.z - nb.end.z, 0.435), "real corrected receiver pair gap")


func _routes(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty) -> void:
	_check(StadiumNpcExpandedV1.ROUTING == {"boundary": GRAPH_ID, "defender_radius": 0.54,
		"live_obstacles": [], "receiver_avoidance": {"body_radius": 0.32,
			"coordinate_space": "field-local", "sites": ["RECEIVER-PRIMARY", "RECEIVER-CATCH"],
			"radius": "half-xz-envelope-diagonal-plus-body-radius"}, "version": 1},
		"pinned graph clearance and zero paid live obstacles with two receiver avoidance circles")
	# Current PropertyGeometry uses global_transform. Evaluate that exact envelope calculation
	# independently in identity-root local coordinates, avoiding a scene install just to read it.
	var expected: Array[Dictionary] = []
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var model: Node3D = source.objects["npc-candidate:AE-01:" + site]
		var envelope: AABB = StadiumTargetModels.ENVELOPE if site == "RECEIVER-PRIMARY" else (
			StadiumNetModels.ENVELOPE)
		var bounds: AABB = model.transform * envelope
		expected.append({"center": bounds.get_center(),
			"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2
				+ StadiumDefenderRoutes.BODY_RADIUS, "copy": "npc:AE-01:r1:" + site})
	var routes: Array[Dictionary] = actual.route_obstacles()
	_check(routes == expected and routes.size() == 2,
		"both actual receiver clearance circles survive independently of zero live-unit budget")
	_check(StadiumDefenderRoutes.BODY_RADIUS == 0.32, "shared route body radius remains pinned")
	for from: Vector3 in [Vector3(0, 0, 8.5), Vector3(-5.5, 0, 8.5), Vector3(5.5, 0, 14)]:
		for to: Vector3 in [Vector3(0, 0, -4), Vector3(6, 0, -5), Vector3(0, 0, 25)]:
			_check(StadiumDefenderRoutes.clear(from, to, routes)
				== StadiumDefenderRoutes.clear(from, to, expected)
				and StadiumDefenderRoutes.clip(from, to, routes)
				== StadiumDefenderRoutes.clip(from, to, expected)
				and StadiumDefenderRoutes.step(from, to, 12, routes)
				== StadiumDefenderRoutes.step(from, to, 12, expected),
				"shared circle-route clear/clip/step compatibility")
	_check(not StadiumDefenderRoutes.clear(Vector3(0, 0, 8.5), Vector3(0, 0, -4), routes)
		and StadiumDefenderRoutes.clear(Vector3(0, 0, 8.5), Vector3(0, 0, 25), routes),
		"real receiver avoidance blocks crossing and leaves forward field corridor clear")
	if not routes.is_empty():
		routes[0].radius = 999
		_check(actual.route_obstacles() == expected, "route returns cannot mutate future construction")


func _graph(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty,
	value: Dictionary) -> void:
	var retained: StadiumNpcExpandedGraphV1 = actual.get_node("BoundaryGraph").graph
	var independent: StadiumRecipeBoundary = source.get_node("BoundaryGraph").graph
	_check(retained.identity() == GRAPH_ID and retained.signature() == GRAPH_SHA256
		and retained.signature() == independent.signature()
		and retained.signature() == value.graph.sha256
		and retained.polygon().size() == 8 and retained.segments().size() == 8,
		"exact independent eight-edge joined graph and manifest signature")
	_check(var_to_bytes(retained.segments()) == var_to_bytes(independent.segments())
		and retained.polygon() == independent.polygon(), "all graph vertices/roles/heights/priorities")
	for row: Dictionary in independent.segments():
		var normal: Vector2 = independent.inward(row)
		for fraction: float in [0.01, 0.25, 0.5, 0.75, 0.99]:
			var at: Vector2 = row.a.lerp(row.b, fraction)
			for height: float in [0.05, row.height, row.height + 0.001, row.height + 20]:
				var from: Vector3 = Vector3(at.x + normal.x * 0.2, height, at.y + normal.y * 0.2)
				var to: Vector3 = from - Vector3(normal.x, 0, normal.y) * 100
				_check(var_to_bytes(retained.crossing(from, to))
					== var_to_bytes(independent.crossing(from, to)), "retained crossing " + row.id)
				var expected: String = row.role
				if height > row.height and row.role != "REAR_PERIMETER_DEAD":
					expected = "BACK_CLEAR" if row.role == "BACK_WALL_TERMINAL" else "SIDE_EXIT_DEAD"
				_check(retained.crossing(from, to).get("role") == expected,
					"exact graph cap semantics " + row.id)
	_check(retained.contains(Vector2(0, 25)) and not retained.contains(Vector2(22, 24))
		and retained.crossing(Vector3(0, 1, 22), Vector3(0, 1, 25)).is_empty(),
		"deeper pocket stays live with no stale infinite back plane")
	for index in range(8):
		_check(retained.outer_vertex(index) == independent.outer_vertex(index), "exact joined miter")
	for from: Vector3 in [Vector3(0, 0, 10), Vector3(0, 0, 23), Vector3(9, 0, 24),
		Vector3(-9, 0, 24), Vector3(21, 0, 22), Vector3(-21, 0, 22), Vector3(40, 0, 40)]:
		for to: Vector3 in [Vector3(0, 0, 100), Vector3(0, 0, -20),
			Vector3(-40, 0, 24), Vector3(40, 0, 24), Vector3(0, 0, 25)]:
			_check(retained.clip(from, to) == independent.clip(from, to), "retained swept route clipping")
	_check(is_equal_approx(retained.clip(Vector3(0, 0, 10), Vector3(0, 0, 100)).z, 25.46)
		and retained.clip(Vector3(0, 0, 23), Vector3(0, 0, 25)) == Vector3(0, 0, 25)
		and retained.crossing(Vector3.INF, Vector3.ZERO).is_empty(),
		"pinned 0.54m graph clearance, deeper-pocket entry and nonfinite rejection")


func _prisms(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty) -> void:
	var boundary: Node3D = actual.get_node("BoundaryGraph")
	var retained: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumNpcExpandedV1.TemplateView.new())
	var independent: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		source.get_node("BoundaryGraph").graph)
	_check(var_to_bytes(retained.walls) == var_to_bytes(independent.walls)
		and retained.walls.size() == 8
		and boundary.visibility_bounds() == source.get_node("BoundaryGraph").visibility_bounds(),
		"shared joined-prism visibility and all segmented broad bounds correspond")
	var rows: Array[Dictionary] = boundary.graph.segments()
	for index in range(rows.size()):
		var row: Dictionary = rows[index]
		var body: StaticBody3D = boundary.get_node(row.id)
		var shape: CollisionShape3D = body.get_child(0)
		var mesh: MeshInstance3D = body.get_node("TemplateWallVisual")
		_check(shape.shape is ConvexPolygonShape3D and shape.shape.points.size() == 8
			and body.collision_layer == 1 and body.collision_mask == 2
			and body.get_meta("boundary_segment") == row.id
			and body.get_meta("ball_surface") == &"stadium_boundary"
			and mesh.visible == (row.role != "BACK_WALL_TERMINAL"),
			"actual joined slab, exact physical layers and back-only art " + row.id)
		var points: PackedVector3Array = shape.shape.points
		for corner in range(4):
			var at: Vector2 = retained.walls[index].polygon[corner]
			_check(points[corner] == Vector3(at.x, 0, at.y)
				and points[corner + 4] == Vector3(at.x, row.height, at.y),
				"shared visibility prism exactly matches physical slab vertices " + row.id)
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		_check(vertices.size() == 36, "all six triangle faces of each joined slab")
		for vertex: Vector3 in vertices:
			_check(points.has(vertex), "slab render mesh lies on actual collider corners")
	_check(retained.blocked(Vector3(0, 1, 25), Vector3(0, 1, 28), 0)
		and not retained.blocked(Vector3(0, 5, 0), Vector3(0, 1, 25), 0),
		"visibility semantic controls: real back wall blocks and center-field corridor is clear")
	for ball: Vector3 in [Vector3(0, 1, 25), Vector3(9.9, 1, 25.9), Vector3(22, 1, 24)]:
		_check(retained.margin(ball) == independent.margin(ball), "shared acute-miter visibility margin")


func _geometry(node: Node) -> Dictionary:
	# Traverse actual constructed data, excluding supplied signatures and ownership metadata.
	# Names are intentionally excluded: anonymous native nodes carry construction-specific IDs.
	var result: Dictionary = {"class": node.get_class(), "children": []}
	if node is Node3D:
		result["transform"] = node.transform
		result["visible"] = node.visible
		result["top_level"] = node.top_level
	if node is GeometryInstance3D:
		for key: String in ["layers", "cast_shadow", "gi_mode", "transparency", "sorting_offset",
			"sorting_use_aabb_center", "extra_cull_margin", "custom_aabb", "lod_bias",
			"visibility_range_begin", "visibility_range_end", "visibility_range_begin_margin",
			"visibility_range_end_margin", "visibility_range_fade_mode", "ignore_occlusion_culling"]:
			result[key] = _content(node.get(key))
		result["material_override"] = _resource(node.material_override)
		result["material_overlay"] = _resource(node.material_overlay)
	if node is MeshInstance3D:
		result["mesh"] = _mesh(node.mesh)
		result["surface_overrides"] = []
		if node.mesh != null:
			for index in range(node.mesh.get_surface_count()):
				result.surface_overrides.append(_resource(node.get_surface_override_material(index)))
	if node is MultiMeshInstance3D:
		# No such node is needed for ST-024, but never silently omit actual instance geometry.
		result["multimesh"] = _resource(node.multimesh)
		result["multimesh_mesh"] = _mesh(node.multimesh.mesh) if node.multimesh != null else {}
	if node is Label3D:
		# Label3D is not MeshInstance3D; font/text/style are physical presentation, not metadata.
		result["label"] = _stored(node)
	if node is CollisionObject3D:
		result["collision"] = [node.collision_layer, node.collision_mask, node.collision_priority]
	if node is StaticBody3D:
		result["body_material"] = _resource(node.physics_material_override)
		result["body_velocity"] = [node.constant_linear_velocity, node.constant_angular_velocity]
	if node is CollisionShape3D:
		result["disabled"] = node.disabled
		result["shape"] = _resource(node.shape)
	for key: String in META:
		if node.has_meta(key):
			result[key] = _content(node.get_meta(key))
	for child: Node in node.get_children():
		result.children.append(_geometry(child))
	return result


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


func _mutations(actual: StadiumNpcExpandedV1, baseline: PackedByteArray) -> void:
	var target: Node3D = actual.objects["npc:AE-01:r1:RECEIVER-PRIMARY"]
	var mesh: BoxMesh = target.get_node("Visual/ST026_PANEL").mesh
	var size: Vector3 = mesh.size
	mesh.size.x += 0.01
	_check(var_to_bytes(_geometry(actual)) != baseline,
		"same metadata cannot conceal actual mesh change")
	mesh.size = size
	var collision: CollisionShape3D = target.get_node("Collision/ST026_PANEL").get_child(0)
	size = collision.shape.size
	collision.shape.size.z += 0.01
	_check(var_to_bytes(_geometry(actual)) != baseline,
		"same metadata cannot conceal actual collider change")
	collision.shape.size = size
	var material: StandardMaterial3D = target.get_node("Visual/ST026_PANEL").material_override
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_check(var_to_bytes(_geometry(actual)) != baseline,
		"material comparison includes transparency mode")
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.emission_enabled = true
	_check(var_to_bytes(_geometry(actual)) != baseline, "material comparison includes emission flags")
	material.emission_enabled = false
	var body: StaticBody3D = target.get_node("Collision/ST026_PANEL")
	body.collision_layer = 65
	_check(var_to_bytes(_geometry(actual)) != baseline, "actual physical layers are inspected")
	body.collision_layer = 1
	body.set_meta("surface_role", "DECORATIVE_AFTER_TERMINAL")
	_check(var_to_bytes(_geometry(actual)) != baseline, "actual physical role changes are inspected")
	body.set_meta("surface_role", "RECEIVER_CONTAINMENT_FOUL")
	var label: Label3D = actual.objects["npc:AE-01:r1:SCORE-SMALL"].get_node(
		"Visual/ScoreDisplay").get_child(0)
	var original: String = label.text
	label.text = "ALTERED"
	_check(var_to_bytes(_geometry(actual)) != baseline, "scoreboard Label3D text is inspected")
	label.text = original
	_check(var_to_bytes(_geometry(actual)) == baseline, "all real geometry controls restore exactly")


func _isolation(actual: StadiumNpcExpandedV1, source: StadiumExpandedProperty,
	baseline: PackedByteArray) -> void:
	var target: Node3D = actual.objects["npc:AE-01:r1:RECEIVER-PRIMARY"]
	target.position.x = 0.5
	target.get_node("Visual/ST026_PANEL").mesh.size.x += 0.1
	target.get_node("Visual/ST026_PANEL").material_override.albedo_color = Color.RED
	target.get_node("Collision/ST026_PANEL").get_child(0).shape.size.z += 0.1
	actual.field.safe_hit_z_m = 1
	var fresh: StadiumNpcExpandedV1 = StadiumNpcExpandedV1.build()
	_check(fresh.field != actual.field and fresh.field.safe_hit_z_m == 11.25
		and var_to_bytes(_geometry(fresh)) == baseline
		and var_to_bytes(_geometry(source)) == baseline,
		"mutated transforms/mesh/material/collider/field affect neither fresh retained nor source builds")
	fresh.free()


func _no_ownership(node: Node) -> void:
	for key: String in ["owned_copy", "candidate_instance", "candidate_site", "candidate_venue",
		"stadium_snapshot", "stadium_property", "property_signature", "wall_manifest",
		"stadium_candidate_only", "stadium_expanded_candidate", "boundary_signature"]:
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
	_check(parent == root, "every NPC instance descends from its exact field host")
	return result


func _components(value: Transform3D) -> Array:
	var result: Array = []
	for vector: Vector3 in [value.basis.x, value.basis.y, value.basis.z, value.origin]:
		result.append_array([vector.x, vector.y, vector.z])
	return result


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)

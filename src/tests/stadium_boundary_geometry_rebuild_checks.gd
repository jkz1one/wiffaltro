class_name StadiumBoundaryGeometryRebuildChecks
extends RefCounted
## Geometry support for the one shared boundary qualification; never starts a runner.
## Physics/contact qualification remains with the parent shared fixture.

const EPS: float = 0.0002
const EXPECTED_CHECKS: int = 272
const ITEMS: Array[String] = ["ST-032", "ST-074", "ST-021", "ST-064", "ST-020", "ST-071"]
const FROZEN: Dictionary = {
	"stadium_timber_dugout_models.gd":
	"e12ec8c7dd758229202a51d4f5111e0bbcf5dc55a49930495802e91977886566",
	"stadium_concrete_dugout_models.gd":
	"ac4ab6504e2c24b08e2693d1b0f821dcac2849b98b5a5be836eace0044c8ed21",
	"stadium_foul_pole_models.gd":
	"5e28063a3e8bc26412279df18861640c63604f8d3adbf8934f4363337d73eb53",
	"stadium_wall_panel_models.gd":
	"aa2cb103cf6998f81466c9173bdb3eb206a91835f84857e73380ca98e38ada7b",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_seating_models.gd": "56f1ed7ceb4576b6887a48ad785209bf964965e8eb9bbcd708345a8ee4aa03eb"
}


class GeometryProbe:
	extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"

	func _ready() -> void:
		pass


static func run(parent: Node3D, check: Callable) -> void:
	var probe: GeometryProbe = GeometryProbe.new()
	parent.add_child(probe)
	probe.position = Vector3(1500, 0, 0)
	_emit(
		check,
		StadiumBoundaryOwnedModels.ITEMS == ITEMS and StadiumBoundaryOwnedModels.VERSION == 1,
		"one owned boundary factory covers the six requested objects"
	)
	for file: String in FROZEN:
		var actual: String = FileAccess.get_sha256("res://src/presentation/stadium/" + file)
		_emit(
			check,
			actual == FROZEN[file],
			"every reused source factory stays byte-for-byte frozen",
			{"file": file, "actual": actual, "expected": FROZEN[file]}
		)
	var originals: Dictionary = {}
	var signatures: Dictionary = {}
	var regenerated_signatures: Dictionary = {}
	for item: String in ["ST-032", "ST-074", "ST-021", "ST-024"]:
		originals[item] = _original(item)
		signatures[item] = _branches(probe, originals[item])
		regenerated_signatures[item] = _regenerated_branches(probe, originals[item])
	for item: String in ["ST-032", "ST-074"]:
		for left: bool in [true, false]:
			var row: Dictionary = _placement(item, "DUGOUT-L" if left else "DUGOUT-R")
			var model: Node3D = await _model(probe, item, row, check)
			if model != null:
				_dugout(model, originals[item], item, left, check)
				model.free()
	for split: float in [1.2, 3.25]:
		var row: Dictionary = _placement("ST-021", "FOUL-POLE-" + str(split))
		row["split"] = split
		var model: Node3D = await _model(probe, "ST-021", row, check)
		if model != null:
			_pole(model, split, check)
			model.free()
	for item: String in ["ST-020", "ST-071"]:
		await _rear_modules(probe, item, check)
	await _panels(probe, check)
	_rejections(check)
	for item: String in ["ST-032", "ST-074", "ST-021", "ST-024"]:
		var fresh: Node3D = _original(item)
		var existing_equal: bool = _branches(probe, originals[item]) == signatures[item]
		var regenerated_equal: bool = (
			_regenerated_branches(probe, fresh) == regenerated_signatures[item]
		)
		_emit(
			check,
			existing_equal and regenerated_equal,
			"owned creation preserves existing and regenerated frozen factory geometry",
			{"item": item, "existing_equal": existing_equal, "regenerated_equal": regenerated_equal}
		)
		fresh.free()
		originals[item].free()
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"BOUNDARY_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _placement(item: String, site: String) -> Dictionary:
	return {
		"copy": "GEOMETRY:" + item + ":" + site, "site": site, "position": Vector3.ZERO, "yaw": 0.0
	}


static func _original(item: String) -> Node3D:
	match item:
		"ST-032":
			return StadiumTimberDugoutModels.create()
		"ST-074":
			return StadiumConcreteDugoutModels.create()
		"ST-021":
			return StadiumFoulPoleModels.create(3.25)
	return StadiumWallPanelModels.create("ST-024", "full")


static func _branches(probe: GeometryProbe, model: Node3D) -> String:
	var collision: Node = model.get_node_or_null("Collision")
	return (
		probe._grand_snapshot(model.get_node("Visual"))
		+ probe._grand_snapshot(
			collision if collision != null else model.get_node("PanelCollision")
		)
	)


static func _regenerated_branches(probe: GeometryProbe, model: Node3D) -> String:
	var collision: Node = model.get_node_or_null("Collision")
	return (
		_regenerated_snapshot(probe, model.get_node("Visual"))
		+ _regenerated_snapshot(
			probe, collision if collision != null else model.get_node("PanelCollision")
		)
	)


static func _regenerated_snapshot(probe: GeometryProbe, branch: Node) -> String:
	# Fresh unnamed wall meshes receive process-global Node name counters. Their
	# preorder identity is stable; keep every other captured state byte unchanged.
	# Existing originals still use the completely raw pre/post snapshot above.
	var state: Array = []
	probe._grand_node_state(branch, state)
	for index in range(state.size()):
		var entry: Array = state[index]
		if entry[1] == "MeshInstance3D" and str(entry[0]).begins_with("@MeshInstance3D@"):
			entry[0] = "@generated:%s:%d" % [entry[1], index]
	return var_to_bytes(state).hex_encode().sha256_text()


static func _model(probe: GeometryProbe, item: String, row: Dictionary, check: Callable) -> Node3D:
	var model: Node3D = StadiumBoundaryOwnedModels.create(item, row)
	_emit(
		check,
		model != null,
		"complete exact-copy boundary model exists",
		{"item": item, "site": row.site}
	)
	if model == null:
		return null
	probe.add_child(model)
	await probe.get_tree().process_frame
	var ownership: String = _owner_failure(model, item, row)
	_emit(
		check,
		ownership.is_empty(),
		"every root, branch, visual, body and shape binds the exact paid copy",
		{"item": item, "site": row.site, "node": ownership}
	)
	var transforms: bool = model.transform == Transform3D.IDENTITY
	for branch: String in ["Visual", "Collision"]:
		transforms = transforms and model.get_node(branch).transform == Transform3D.IDENTITY
	for node: Node3D in model.find_children("*", "Node3D", true, false):
		transforms = (
			transforms
			and node.transform.origin.is_finite()
			and node.basis.is_finite()
			and node.basis.determinant() > 0
			and not node.top_level
		)
	_emit(
		check,
		transforms,
		"factory roots and containers are identity with finite positive-handed members",
		{"item": item}
	)
	var bounds: AABB = _bounds(_points(probe, model), model.global_transform.affine_inverse())
	var reserve: AABB = model.get_meta("envelope", AABB())
	_emit(
		check,
		(
			reserve.grow(EPS).encloses(bounds)
			and StadiumBoundaryOwnedModels.envelope(item).grow(EPS).encloses(bounds)
		),
		"all mesh, instanced wire, collision and ready-label bounds fit the exact owned reserve",
		{"item": item, "site": row.site, "actual": str(bounds), "reserve": str(reserve)}
	)
	var collisions: String = _collision_failure(model, item, row)
	_emit(
		check,
		collisions.is_empty(),
		"all exact-copy colliders have one enabled zero-margin named shape and unique surface identity",
		{"item": item, "site": row.site, "node": collisions}
	)
	_emit(
		check,
		_roles_valid(model, item),
		"all model surfaces retain their explicit boundary semantic role",
		{"item": item}
	)
	return model


static func _owner_failure(root: Node3D, item: String, row: Dictionary) -> String:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node.get_meta("owned_copy", "") != row.copy
			or node.get_meta("paid_copy", "") != row.copy
			or node.get_meta("stadium_item", "") != item
			or node.get_meta("site", "") != row.site
			or node.get_meta("boundary_owned", false) != true
			or str(node.get_meta("surface_role", "")).is_empty()
		):
			return str(root.get_path_to(node))
		if (
			item == "ST-064"
			and (
				node.get_meta("host_copy", "") != row.host
				or node.get_meta("host_span", "") != "full"
			)
		):
			return str(root.get_path_to(node)) + ":host"
	return ""


static func _collision_failure(root: Node3D, item: String, row: Dictionary) -> String:
	var expected: int = (
		20 if item == "ST-032" else 12 if item == "ST-074" else 3 if item == "ST-064" else 1
	)
	var collision: Node = root.get_node("Collision")
	if collision.get_child_count() != expected:
		return "count:" + str(collision.get_child_count())
	var ids: Array[String] = []
	for body: StaticBody3D in collision.get_children():
		var id: String = str(body.get_meta("owned_surface_id", ""))
		if (
			ids.has(id)
			or id != str(row.copy) + ":" + str(body.name)
			or body.get_meta("surface_id", "") != str(body.name)
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.get_child_count() != 1
		):
			return str(body.name) + ":identity"
		ids.append(id)
		var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
		if (
			shape == null
			or shape.name != "Shape"
			or shape.disabled
			or shape.shape == null
			or shape.shape.margin != 0
			or shape.transform != Transform3D.IDENTITY
		):
			return str(body.name) + ":shape"
	return ""


static func _roles_valid(model: Node3D, item: String) -> bool:
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var role: String = str(body.get_meta("surface_role", ""))
		var expected: String = "DECORATIVE_AFTER_TERMINAL"
		if item in ["ST-020", "ST-071"]:
			expected = "REAR_PERIMETER_DEAD"
		elif item == "ST-021":
			expected = "FOUL_POLE_CONTACT"
		elif item == "ST-064":
			expected = "BACK_WALL_TERMINAL"
		elif str(body.name).begins_with("FrontBarrier"):
			expected = "DUGOUT_FACE_LIVE"
		elif item == "ST-074" and str(body.name).begins_with("Roof"):
			expected = "DUGOUT_ROOF_TERMINAL"
		if role != expected or body.get_child(0).get_meta("surface_role", "") != expected:
			return false
	return true


static func _points(probe: GeometryProbe, model: Node3D) -> PackedVector3Array:
	var points: PackedVector3Array = probe._all_points(model)
	for label: Label3D in model.find_children("*", "Label3D", true, false):
		for index in range(8):
			points.append(label.global_transform * label.get_aabb().get_endpoint(index))
	for node: MultiMeshInstance3D in model.find_children("*", "MultiMeshInstance3D", true, false):
		for instance in range(node.multimesh.instance_count):
			var pose: Transform3D = (
				node.global_transform * node.multimesh.get_instance_transform(instance)
			)
			for surface in range(node.multimesh.mesh.get_surface_count()):
				var vertices: PackedVector3Array = node.multimesh.mesh.surface_get_arrays(surface)[
					Mesh.ARRAY_VERTEX
				]
				for point: Vector3 in vertices:
					points.append(pose * point)
	return points


static func _bounds(points: PackedVector3Array, pose: Transform3D = Transform3D.IDENTITY) -> AABB:
	if points.is_empty():
		return AABB()
	var result: AABB = AABB(pose * points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(pose * point)
	return result


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _member(model: Node3D, id: String) -> AABB:
	var mesh: MeshInstance3D = model.get_node_or_null("Visual/" + id) as MeshInstance3D
	return (
		AABB()
		if mesh == null
		else model.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
	)


static func _geometry_same(actual: Node3D, original: Node3D) -> bool:
	for branch: String in ["Visual", "Collision"]:
		var a: Node = actual.get_node(branch)
		var b: Node = original.get_node(branch)
		if a.get_child_count() != b.get_child_count():
			return false
		for index in range(a.get_child_count()):
			var one: Node3D = a.get_child(index)
			var two: Node3D = b.get_child(index)
			if (
				one.name != two.name
				or one.transform != two.transform
				or one.get_class() != two.get_class()
			):
				return false
			if one is MeshInstance3D:
				var mesh_a: MeshInstance3D = one as MeshInstance3D
				var mesh_b: MeshInstance3D = two as MeshInstance3D
				if (
					(
						StadiumCurvedCanopySites._resource(mesh_a.mesh)
						!= StadiumCurvedCanopySites._resource(mesh_b.mesh)
					)
					or (
						StadiumCurvedCanopySites._resource(mesh_a.material_override)
						!= StadiumCurvedCanopySites._resource(mesh_b.material_override)
					)
				):
					return false
			else:
				if (
					one.get_child_count() != two.get_child_count()
					or one.get_child_count() != 1
					or (
						StadiumCurvedCanopySites._resource(one.get_child(0).shape)
						!= StadiumCurvedCanopySites._resource(two.get_child(0).shape)
					)
				):
					return false
	return true


static func _dugout(
	model: Node3D, original: Node3D, item: String, left: bool, check: Callable
) -> void:
	var concrete: bool = item == "ST-074"
	_emit(
		check,
		_geometry_same(model, original),
		"owned dugout preserves every original visual and collision volume",
		{"item": item, "left": left}
	)
	var opening: AABB = model.get_meta("opening_bounds", AABB())
	_emit(
		check,
		(
			_same_box(opening, AABB(Vector3(-1, 0, 0), Vector3(2, 2.4 if concrete else 1.3, 0)))
			and model.get_meta("roof_present", false) == concrete
		),
		"timber keeps the roofless 1.3m entry and concrete keeps the distinct 2.4m roof aperture",
		{"item": item, "opening": str(opening)}
	)
	var front: bool = true
	for side: int in [-1, 1]:
		front = (
			front
			and _same_box(
				_member(model, "FrontBarrier%d" % side),
				AABB(Vector3(side * 2 - 1, 0, 0), Vector3(2, 1.2, 0.2 if concrete else 0.18))
			)
		)
	var roof: bool = model.has_node("Visual/Roof") and model.has_node("Collision/Roof")
	if concrete:
		roof = (
			roof
			and _same_box(_member(model, "Roof"), AABB(Vector3(-3, 2.4, 0), Vector3(6, 0.3, 2.65)))
		)
	else:
		roof = (
			not roof
			and not model.has_node("Visual/RoofSupport-1")
			and not model.has_node("Visual/RoofSupport1")
		)
	_emit(
		check,
		front and roof,
		"actual full front barriers leave the complete two-metre aperture and the correct roof semantics",
		{"item": item}
	)
	var pose: Transform3D = StadiumDugoutRecipe.placement(left)
	model.transform = pose
	_emit(
		check,
		(
			model.basis.determinant() > 0.9999
			and model.scale.is_equal_approx(Vector3.ONE)
			and (
				(pose * Vector3(0, 0, 1)).distance_to(StadiumDugoutRecipe.rail_point(13, 1, left))
				< EPS
			)
		),
		"both handed dugouts retain positive unit-size frames with full depth outside play",
		{"item": item, "left": left}
	)


static func _pole(model: Node3D, split: float, check: Callable) -> void:
	var body: StaticBody3D = model.get_node("Collision/Pole")
	var shape: CollisionShape3D = body.get_node("Shape")
	var exact: bool = shape.shape is CylinderShape3D
	if exact:
		exact = (
			is_equal_approx(shape.shape.radius, 0.09)
			and is_equal_approx(shape.shape.height, 8.0)
			and body.position == Vector3(0, 4, 0)
		)
	_emit(
		check,
		exact,
		"pole uses one uninterrupted full-height cylinder without a physical split cap",
		{"split": split}
	)
	var lower: MeshInstance3D = model.get_node("Visual/Lower")
	var upper: MeshInstance3D = model.get_node("Visual/Upper")
	_emit(
		check,
		(
			lower.mesh is CylinderMesh
			and upper.mesh is CylinderMesh
			and is_equal_approx(lower.mesh.height, split)
			and is_equal_approx(upper.mesh.height, 8 - split)
			and is_equal_approx(lower.position.y + lower.mesh.height / 2, split)
			and is_equal_approx(upper.position.y - upper.mesh.height / 2, split)
		),
		"visual lower and upper pole regions meet at the actual wall-cap height",
		{"split": split}
	)
	_emit(
		check,
		(
			body.get_meta("wall_cap_height", -1) == split
			and StadiumFoulPoleModels.role_at(split, split) == "FOUL_POLE_LOWER"
			and StadiumFoulPoleModels.role_at(split + 0.001, split) == "FOUL_POLE_UPPER"
		),
		"exact cap belongs to the lower pole and only greater heights use upper role",
		{"split": split}
	)
	var original: Node3D = StadiumFoulPoleModels.create(split)
	_emit(
		check,
		_geometry_same(model, original),
		"owned pole retains original dimensions and unfinished source color",
		{"split": split}
	)
	original.free()


static func _rear_modules(probe: GeometryProbe, item: String, check: Callable) -> void:
	var models: Array[Node3D] = []
	var all_points: PackedVector3Array = []
	var rear_points: Array[PackedVector3Array] = []
	var miter: float = (
		0.35 * (29.4 / Vector2(16, 29.4).length()) / (1 + 16 / Vector2(16, 29.4).length())
	)
	for index in range(8):
		var row: Dictionary = _placement(item, "REAR-%02d" % index)
		row["index"] = index
		var model: Node3D = await _model(probe, item, row, check)
		if model == null:
			continue
		models.append(model)
		var body: StaticBody3D = model.get_node("Collision/RearFence")
		var shape: CollisionShape3D = body.get_node("Shape")
		var expected: PackedVector3Array = []
		var outline: PackedVector2Array = [
			Vector2(-1, 0),
			Vector2(1, 0),
			Vector2(1 + (miter if index == 7 else 0), -0.35),
			Vector2(-1 - (miter if index == 0 else 0), -0.35)
		]
		for y: float in [0.0, 1.2]:
			for point: Vector2 in outline:
				expected.append(Vector3(point.x, y, point.y))
		var exact: bool = (
			shape.shape is ConvexPolygonShape3D and body.transform == Transform3D.IDENTITY
		)
		var actual: PackedVector3Array = (
			shape.shape.points if shape.shape is ConvexPolygonShape3D else PackedVector3Array()
		)
		exact = exact and actual.size() == expected.size()
		if exact:
			for vertex in range(expected.size()):
				exact = exact and actual[vertex].distance_to(expected[vertex]) < EPS
		_emit(
			check,
			exact,
			(
				"each actual rear convex collider equals the complete two-metre prism with only its "
				+ "owned endpoint miter"
			),
			{"item": item, "index": index, "points": str(actual)}
		)
		var posts: bool = (
			model.has_node("Visual/OwnedPost-1") and model.has_node("Visual/OwnedPost1")
		)
		if posts:
			for side: int in [-1, 1]:
				var box: AABB = _member(model, "OwnedPost%d" % side)
				posts = (
					posts
					and absf(box.position.y) < EPS
					and absf(box.end.y - 1.2) < EPS
					and absf(box.position.z + 0.35) < EPS
					and absf(box.end.z) < EPS
				)
		_emit(
			check,
			posts,
			"each purchased rear module owns both grounded full-depth end posts",
			{"item": item, "index": index}
		)
		var chain: MultiMeshInstance3D = (
			model.get_node_or_null("Visual/ChainDiamondMesh") as MultiMeshInstance3D
		)
		var distinct: bool = (
			(
				chain != null
				and chain.multimesh.instance_count > 20
				and not model.has_node("Visual/WeatheredBoard0")
			)
			if item == "ST-071"
			else (
				chain == null
				and model.has_node("Visual/WeatheredBoard0")
				and model.has_node("Visual/WeatheredBoard7")
			)
		)
		_emit(
			check,
			distinct,
			"weathered wood boards and real open chain diamonds remain distinct full-size finishes",
			{"item": item, "index": index}
		)
		model.position = Vector3(-7 + index * 2, 0, -6)
		var world: PackedVector3Array = []
		for point: Vector3 in actual:
			world.append(model.transform * point)
		rear_points.append(world)
		all_points.append_array(world)
		var bounds: AABB = _bounds(world)
		_emit(
			check,
			(
				absf(bounds.position.y) < EPS
				and absf(bounds.end.y - 1.2) < EPS
				and absf(bounds.position.z + 6.35) < EPS
				and absf(bounds.end.z + 6) < EPS
			),
			"rear module keeps the original ground-zero 1.2m height and z minus6 to minus6.35 depth",
			{"item": item, "index": index}
		)
	var seams: bool = rear_points.size() == 8
	if seams:
		for index in range(7):
			for pair: Vector2i in [Vector2i(1, 0), Vector2i(2, 3), Vector2i(5, 4), Vector2i(6, 7)]:
				seams = (
					seams
					and rear_points[index][pair.x].distance_to(rear_points[index + 1][pair.y]) < EPS
				)
	_emit(
		check,
		seams,
		(
			"all eight full purchased rear modules meet at exact front and exterior seams without "
			+ "holes or duplicated volumes"
		),
		{"item": item}
	)
	var complete: AABB = _bounds(all_points)
	_emit(
		check,
		_same_box(
			complete, AABB(Vector3(-8 - miter, 0, -6.35), Vector3(16 + 2 * miter, 1.2, 0.35))
		),
		"complete eight-module rear replacement retains the exact existing mitred envelope",
		{"item": item, "actual": str(complete)}
	)
	var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create("straight")
	_emit(
		check,
		(
			graph.outer_vertex(0).distance_to(Vector2(-8 - miter, -6.35)) < EPS
			and graph.outer_vertex(1).distance_to(Vector2(8 + miter, -6.35)) < EPS
			and graph.segment("REAR-01").role == "REAR_PERIMETER_DEAD"
		),
		"owned rear endpoints and foul role agree with the unchanged canonical field perimeter",
		{"item": item}
	)
	for model: Node3D in models:
		model.free()


static func _panels(probe: GeometryProbe, check: Callable) -> void:
	for scenario in range(3):
		var shape: String = "deeper_center" if scenario == 2 else "straight"
		var rows: Array[Dictionary] = StadiumWallRecipes.back(shape, "ST-024")
		var full: Array[Dictionary] = []
		for row: Dictionary in rows:
			if row.span == "full":
				full.append(row)
		var host_row: Dictionary = full[0 if scenario == 0 else floori(full.size() * 0.5)]
		var pose: Transform3D = StadiumWallRecipes.placement(host_row)
		var distance: float = Vector2(pose.origin.x, pose.origin.z).length()
		var row: Dictionary = _placement("ST-064", "DISTANCE:HOST-%d" % scenario)
		row["host"] = "HOST-%d" % scenario
		row["host_span"] = "full"
		row["distance_m"] = distance
		var model: Node3D = await _model(probe, "ST-064", row, check)
		if model == null:
			continue
		_emit(
			check,
			(
				_same_box(
					_member(model, "DistancePanel"),
					AABB(Vector3(-0.7, -0.275, 0.02), Vector3(1.4, 0.55, 0.04))
				)
				and _same_box(
					model.get_meta("envelope"),
					AABB(Vector3(-0.7, -0.275, 0), Vector3(1.4, 0.55, 0.08))
				)
			),
			"panel remains the complete 1.4 by0.55m face within its exact shallow mount envelope",
			{"scenario": scenario}
		)
		var label: Label3D = model.get_node("Visual/DistanceMetres")
		var text: AABB = (
			model.global_transform.affine_inverse() * label.global_transform * label.get_aabb()
		)
		_emit(
			check,
			(
				label.text == "%.1f m" % distance
				and is_equal_approx(model.get_meta("distance_m"), distance)
				and text.size.x > 0
				and text.size.y > 0
				and not label.no_depth_test
				and not label.double_sided
				and label.rotation == Vector3.ZERO
				and label.position.z > 0.06
			),
			"ready field-facing panel label prints its actual full-wall host distance in metres",
			{"scenario": scenario, "distance": distance, "text": label.text}
		)
		_emit(
			check,
			(
				text.position.x >= -0.65 - EPS
				and text.end.x <= 0.65 + EPS
				and text.position.y >= -0.23 - EPS
				and text.end.y <= 0.23 + EPS
				and text.position.z > 0.068
				and text.end.z <= 0.08 + EPS
			),
			"actual distance glyph bounds fit the panel and sit forward of every border",
			{"scenario": scenario, "glyphs": str(text)}
		)
		var host: Node3D = StadiumWallPanelModels.create("ST-024", "full")
		probe.add_child(host)
		host.transform = pose
		model.transform = pose
		model.position.y = 1.8
		var anchor: Vector3 = host.global_transform.affine_inverse() * model.global_position
		_emit(
			check,
			(
				anchor.distance_to(Vector3(0, 1.8, 0)) < EPS
				and model.global_basis.is_equal_approx(host.global_basis)
				and absf(StadiumWallPanelModels.dimensions("ST-024", "full").x - 2) < EPS
			),
			(
				"full-size panel mounts at the explicit full two-metre host midpoint without moving "
				+ "or stretching that wall"
			),
			{"scenario": scenario, "anchor": str(anchor)}
		)
		host.free()
		model.free()


static func _rejections(check: Callable) -> void:
	var cases: Array[Dictionary] = [
		{"item": "ST-032", "row": {}},
		{"item": "ST-021", "row": {"copy": "BAD", "site": "BAD", "split": 0.0}},
		{"item": "ST-021", "row": {"copy": "BAD", "site": "BAD", "split": 8.0}},
		{
			"item": "ST-064",
			"row":
			{
				"copy": "BAD",
				"site": "BAD",
				"host": "HOST",
				"host_span": "straight_end",
				"distance_m": 30.0
			}
		},
		{"item": "ST-020", "row": {"copy": "BAD", "site": "BAD", "index": 8}}
	]
	for entry: Dictionary in cases:
		var invalid: Node3D = StadiumBoundaryOwnedModels.create(entry.item, entry.row)
		_emit(
			check,
			invalid == null,
			"factory rejects missing ownership, invalid cap, cut host or ninth rear socket",
			{"item": entry.item, "row": str(entry.row)}
		)
		if invalid != null:
			invalid.free()

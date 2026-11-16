class_name StadiumPracticeFacilityGeometryRebuildChecks
extends RefCounted
## One finite support helper for the shared practice fixture; never a runner.
## Successful path: 1 + 7 foreign + 2*5 frozen + 2*(1 create + 18 common
## + 14 anatomy + 3 native rays + 3 posed bounds) = 96 reachable assertions.

const M = preload("res://src/presentation/stadium/stadium_practice_facility_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const COMMON_CHECKS: int = 18
const ANATOMY_CHECKS: int = 14
const EXPECTED_CHECKS: int = 96
const ITEMS: Array[String] = ["ST-060", "ST-061"]
const FOREIGN: Array[String] = ["ST-025", "ST-072", "ST-073", "ST-052", "ST-059", "ST-062", ""]
const SOLID_COUNTS: Dictionary = {"ST-060": 52, "ST-061": 48}
const STRAND_COUNTS: Dictionary = {"ST-060": 315, "ST-061": 258}
const FROZEN: Dictionary = {
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_net_models.gd": "e54036913c3937c78d18cdfe857bd54a55ec883158f27eac13aa7e1080185398",
	"stadium_receiver_net_models.gd":
	"cec34955f5d8d52b9a7df68034667cb2ba10fab29aaf612f257f0fe20a2ad7ef",
	"stadium_ground_box_models.gd":
	"cfee2e08209f30c8cb989b733981931d56aceecc8fedbbd231888036e2fd52eb"
}


static func expected_checks() -> int:
	return (
		1
		+ FOREIGN.size()
		+ 2 * FROZEN.size()
		+ ITEMS.size() * (1 + COMMON_CHECKS + ANATOMY_CHECKS + 3 + 3)
	)


static func run(parent: Node3D, check: Callable) -> void:
	var probe: Node3D = Node3D.new()
	probe.name = "PracticeFacilityGeometryProbe"
	probe.position = Vector3(1900, 0, 0)
	parent.add_child(probe)
	_emit(
		check,
		M.ITEMS == ITEMS and M.VERSION == 1 and expected_checks() == EXPECTED_CHECKS,
		"one shared practice family owns only the two complete scenery facilities and exact check budget"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			foreign == null and M.envelope(item) == AABB() and M.visible_bounds(item) == AABB(),
			"receiver backstops and foreign objects cannot substitute for practice parents",
			{"item": item}
		)
		if foreign != null:
			foreign.free()
	_frozen(check)
	for item: String in ITEMS:
		var model: Node3D = M.create(item)
		_emit(check, model != null, "complete full-size practice facility creates", {"item": item})
		if model == null:
			continue
		probe.add_child(model)
		await _common(probe, model, item, check)
		_anatomy(model, item, check)
		await _physical_probes(model, item, check)
		_poses(model, item, check)
		model.free()
	_frozen(check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"PRACTICE_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"reused generic helpers and accepted legacy factories remain byte exact",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, item: String, check: Callable) -> void:
	var visible: AABB = AABB(Vector3(-2, 0, -5), Vector3(4, 3 if item == "ST-060" else 3.5, 10))
	var reserve: AABB = AABB(
		Vector3(-2.25, 0, -5.25), Vector3(4.5, 3.5 if item == "ST-060" else 4, 10.5)
	)
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"ground-centered full assembly has exactly two identity branches",
		{"item": item}
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == item
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and model.get_meta("static_geometry")
			and model.get_meta("scenery_only")
			and model.get_meta("lane_direction") == Vector3.BACK
			and model.get_meta("obstacle_units") == 0
			and model.get_meta("ambient_ball_count") == 0
			and model.get_meta("practice_figure_count") == 0
			and not model.get_meta("connected_pedestrian_route")
		),
		"full static plus-Z practice lane grants zero live objects, figures or connected paths",
		{"item": item}
	)
	_emit(
		check,
		SOLIDS._static_unit_scale(model),
		"every actual node is finite, visible, static, unit scale and free of animation scripts",
		{"item": item}
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and int(scan.meshes) == int(SOLID_COUNTS[item]) + 7
			and int(scan.vertices) > 2500
			and int(scan.vertices) < 4000
		),
		"bounded actual native arrays pass the retained complete vertex normal and index scanner",
		{"item": item, "scan": scan}
	)
	_emit(
		check,
		SOLIDS._indexed(model),
		"all stored meshes have explicit nonempty triangle index arrays",
		{"item": item}
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 5,
		"independent plain opaque lane, metal, white markings and strands remain readable",
		{"item": item}
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		(
			_same_box(actual, visible)
			and _same_box(M.visible_bounds(item), visible)
			and _same_box(M.envelope(item), reserve)
			and M.bounds(item) == reserve
			and model.get_meta("envelope") == reserve
			and model.get_meta("visible_bounds") == visible
			and reserve.grow(EPS).encloses(actual)
		),
		(
			"all actual vertices reach the complete approved dimensions inside the independently "
			+ "measured reserve"
		),
		{"item": item, "actual": str(actual), "reservation": str(reserve)}
	)
	_emit(
		check,
		_physical_match(model, item),
		"every exact named rigid solid has one matching enabled zero-margin scenery hull",
		{"item": item}
	)
	_emit(
		check,
		SOLIDS._solid_faces(model),
		"actual rigid indexed triangles wind outward on their complete convex collider hulls",
		{"item": item}
	)
	_emit(
		check,
		_roles(model, item),
		(
			"no scoring, receiver identity, sensors, benefits, inventory figures or live-play "
			+ "colliders exist"
		),
		{"item": item}
	)
	var second: Node3D = M.create(item)
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"all actual meshes, materials and shapes are independent between purchased parents",
		{"item": item}
	)
	var before: String = SOLIDS._signature(model)
	_emit(
		check,
		SOLIDS._signature(second) == before,
		"fresh full-size parents reproduce identical native arrays, materials and physical state",
		{"item": item}
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		SOLIDS._signature(model) == before and SOLIDS._signature(second) != before,
		"destructive mesh, material, shape and transform mutation stays within its independent copy",
		{"item": item}
	)
	second.free()
	var fresh: Node3D = M.create(item)
	_emit(
		check,
		SOLIDS._signature(fresh) == before,
		"regeneration remains deterministic after another copy is destructively mutated",
		{"item": item}
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		SOLIDS._signature(model) == before,
		"an idle rendered frame changes no visible strand, solid, material or collision",
		{"item": item}
	)
	_emit(
		check,
		_ungrounded(model).is_empty(),
		"every real rigid component has a measured contact chain to the full grounded pad",
		{"item": item, "unconnected": _ungrounded(model)}
	)
	_emit(
		check,
		_strands(model, item),
		(
			"seven bounded indexed strand panels are explicit visual-only artwork without "
			+ "invisible catch planes"
		),
		{"item": item}
	)
	_emit(
		check,
		(
			int(model.get_meta("strand_count")) == int(STRAND_COUNTS[item])
			and int(model.get_meta("strand_count")) <= M.MAX_STRANDS
			and model.find_children("*", "MultiMeshInstance3D", true, false).is_empty()
		),
		"actual finite strand count stays below 400 and needs no unsupported instancing scanner",
		{"item": item}
	)
	print(
		(
			"PRACTICE_GEOMETRY_MEASUREMENT "
			+ JSON.stringify(
				{
					"item": item,
					"meshes": scan.meshes,
					"vertices": scan.vertices,
					"solid_hulls": SOLID_COUNTS[item],
					"visual_strands": model.get_meta("strand_count"),
					"actual_bounds": str(actual),
					"reservation": str(reserve),
					"lane_direction": "+Z",
					"static": true
				},
				"",
				true,
				true
			)
		)
	)


static func _anatomy(model: Node3D, item: String, check: Callable) -> void:
	var cage: bool = item == "ST-061"
	var height: float = 3.5 if cage else 3.0
	_emit(
		check,
		_same_box(_member(model, "LaneBase"), AABB(Vector3(-2, 0, -5), Vector3(4, 0.08, 10))),
		"full four-by-ten-metre base rests on ground with its visible top eight centimetres above it",
		{"item": item}
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "PitchingPad"),
				AABB(Vector3(-0.75, 0.08, -4.4), Vector3(1.5, 0.04, 1.8))
			)
			and _same_box(
				_member(model, "BattingPad"),
				AABB(Vector3(-1.25, 0.08, 2.45), Vector3(2.5, 0.04, 2.1))
			)
		),
		"both actual working pads bear directly on the raised lane without coplanar top faces",
		{"item": item}
	)
	_emit(
		check,
		_same_box(
			_member(model, "PitchingRubber"),
			AABB(Vector3(-0.305, 0.12, -3.576), Vector3(0.61, 0.02, 0.152))
		),
		"real pitching rubber is supported above the minus-Z pitching pad",
		{"item": item}
	)
	var plate: PackedVector3Array = _hull(model, "HomePlate")
	_emit(
		check,
		(
			plate.size() == 10
			and _same_box(
				_member(model, "HomePlate"),
				AABB(Vector3(-0.215, 0.12, 3.20), Vector3(0.43, 0.012, 0.43))
			)
			and POINTS._has_point(plate, Vector3(0, 0.132, 3.20))
			and POINTS._has_point(plate, Vector3(-0.215, 0.132, 3.63))
			and POINTS._has_point(plate, Vector3(0.215, 0.132, 3.63))
		),
		"ten actual pentagonal plate vertices form a distinct supported plus-Z home-plate mark",
		{"item": item}
	)
	var markings: bool = SCAN._members(model, "BatterMark").size() == 8
	for member: MeshInstance3D in SCAN._members(model, "BatterMark"):
		var box: AABB = _member(model, str(member.name))
		markings = markings and absf(box.position.y - 0.12) < EPS and absf(box.end.y - 0.126) < EPS
	_emit(
		check,
		markings,
		"eight real thin batter-box markings sit above their pad with visible top separation",
		{"item": item}
	)
	var feet: bool = true
	var posts: bool = true
	for side: int in [-1, 1]:
		for index in range(5):
			var z: float = [-4.94, -2.47, 0.0, 2.47, 4.94][index]
			feet = (
				feet
				and _same_box(
					_member(model, "Foot%d_%d" % [side, index]),
					AABB(
						Vector3(side * 1.86 - 0.14, 0.08, clampf(z, -4.86, 4.86) - 0.14),
						Vector3(0.28, 0.04, 0.28)
					)
				)
			)
			posts = (
				posts
				and _same_box(
					_member(model, "Post%d_%d" % [side, index]),
					AABB(
						Vector3(side * 1.94 - 0.06, 0.12, z - 0.06),
						Vector3(0.12, height - 0.24, 0.12)
					)
				)
			)
	_emit(
		check,
		feet and SCAN._members(model, "Foot").size() == 10,
		"ten independent footplates stay within the full footprint and rest on the base",
		{"item": item}
	)
	_emit(
		check,
		posts and SCAN._members(model, "Post").size() == 10,
		"ten real columns rise from footplates to the complete upper frame",
		{"item": item}
	)
	var rails: bool = true
	for side: int in [-1, 1]:
		for level in range(2):
			rails = (
				rails
				and _same_box(
					_member(model, "SideRail%d_%d" % [side, level]),
					AABB(
						Vector3(side * 1.94 - 0.06, 0.08 if level == 0 else height - 0.12, -5),
						Vector3(0.12, 0.12, 10)
					)
				)
			)
	_emit(
		check,
		rails,
		"four complete side rails span the full ten-metre lane and connect every side support",
		{"item": item}
	)
	var ends: bool = _same_box(
		_member(model, "BackBottomRail"),
		AABB(Vector3(-1.88, 0.08, 4.88), Vector3(3.76, 0.12, 0.12))
	)
	for end: int in [-1, 1]:
		ends = (
			ends
			and _same_box(
				_member(model, "EndTopRail%d" % end),
				AABB(Vector3(-1.88, height - 0.12, end * 4.94 - 0.06), Vector3(3.76, 0.12, 0.12))
			)
		)
	_emit(
		check,
		ends,
		"rear lower rail and both end crossbars physically close the supported frame",
		{"item": item}
	)
	_emit(
		check,
		(
			_same_box(
				_member(model, "EntryHeader"),
				AABB(Vector3(-0.61, 2.21, -5), Vector3(1.22, 0.12, 0.12))
			)
			and absf(_member(model, "EntryJamb-1").end.x + 0.49) < EPS
			and absf(_member(model, "EntryJamb1").position.x - 0.49) < EPS
		),
		"visible front access frame leaves a real 0.98-metre opening below its header",
		{"item": item}
	)
	_emit(
		check,
		_panel_pattern(model, "diamond" if not cage else "square"),
		"bullpen diamond chain-link and cage square mesh are actual distinct repeated geometry",
		{"item": item}
	)
	var complete: bool = true
	if cage:
		for index in range(1, 4):
			complete = (
				complete
				and _same_box(
					_member(model, "RoofCross%d" % index),
					AABB(
						Vector3(-1.88, 3.38, [-4.94, -2.47, 0.0, 2.47, 4.94][index] - 0.06),
						Vector3(3.76, 0.12, 0.12)
					)
				)
			)
		complete = (
			complete
			and model.has_node("Visual/RoofStrands")
			and not model.has_node("Visual/GateStrands")
		)
	else:
		complete = model.has_node("Visual/GateStrands") and model.has_node("Visual/GateLatch")
		complete = complete and SCAN._members(model, "GateHinge").size() == 2
		complete = (
			complete
			and not model.has_node("Visual/RoofStrands")
			and SCAN._members(model, "RoofCross").is_empty()
		)
	_emit(
		check,
		complete,
		(
			"cage has a supported full overhead net while open-roof bullpen has a complete hinged "
			+ "access gate"
		),
		{"item": item}
	)
	_emit(
		check,
		_strand_attachment(model),
		"every actual net panel corner reaches a real frame support",
		{"item": item}
	)
	_emit(
		check,
		(
			_member(model, "LaneBase").position.y >= -EPS
			and _member(model, "LaneBase").end.y > 0.079
			and _member(model, "PitchingPad").end.y < _member(model, "PitchingRubber").end.y - 0.019
			and _member(model, "BattingPad").end.y < _member(model, "HomePlate").end.y - 0.011
		),
		"ground, pads and both principal marks have distinct visible top heights",
		{"item": item}
	)


static func _physical_probes(model: Node3D, item: String, check: Callable) -> void:
	await model.get_tree().physics_frame
	await model.get_tree().physics_frame
	var rubber: Dictionary = _ray(model, Vector3(0, 0.5, -3.5), Vector3(0, -0.2, -3.5))
	var plate: Dictionary = _ray(model, Vector3(0, 0.5, 3.5), Vector3(0, -0.2, 3.5))
	_emit(
		check,
		_hit(model, rubber, "PitchingRubber", 0.14) and _hit(model, plate, "HomePlate", 0.132),
		"native rays hit the real rubber and pentagonal plate at their exact distinct heights",
		{"item": item}
	)
	var base: Dictionary = _ray(model, Vector3(0, 0.5, 0), Vector3(0, -0.2, 0))
	var post: Dictionary = _ray(model, Vector3(1.7, 1.0, 0), Vector3(2.2, 1.0, 0))
	_emit(
		check,
		(
			_hit(model, base, "LaneBase", 0.08)
			and not post.is_empty()
			and model.is_ancestor_of(post.collider)
			and str(post.collider.name) == "Post1_2"
		),
		"native rays hit full raised lane and a real side post with no widened proxy",
		{"item": item}
	)
	_emit(
		check,
		(
			_ray(model, Vector3(1.7, 1, 1.1), Vector3(2.2, 1, 1.1)).is_empty()
			and _ray(model, Vector3(0, 1, 4.7), Vector3(0, 1, 5.2)).is_empty()
			and _ray(model, Vector3(0, 1, -5.2), Vector3(0, 1, -4.7)).is_empty()
		),
		"visual strand panels and access opening add no invisible catch plane or scoring collider",
		{"item": item}
	)


static func _poses(model: Node3D, item: String, check: Callable) -> void:
	for origin: Vector3 in [
		Vector3(-36.75, 0, 39.25), Vector3(-40.25, 0, 41.75), Vector3(-34.25, 0, 41.75)
	]:
		var pose: Transform3D = Transform3D(Basis.IDENTITY, origin)
		var visible: AABB = pose * SCAN._bounds(POINTS._points(model))
		var reserve: AABB = pose * M.envelope(item)
		_emit(
			check,
			(
				reserve.grow(EPS).encloses(visible)
				and absf(visible.size.x - 4) < EPS
				and absf(visible.size.z - 10) < EPS
				and pose.basis * Vector3.BACK == Vector3.BACK
				and absf(reserve.position.x - (origin.x - 2.25)) < EPS
				and absf(reserve.position.z - (origin.z - 5.25)) < EPS
			),
			"all three fixed world poses preserve full plus-Z geometry and complete unscaled reservation",
			{
				"item": item,
				"origin": str(origin),
				"actual": str(visible),
				"reservation": str(reserve)
			}
		)


static func _same_box(a: AABB, b: AABB) -> bool:
	return a.position.distance_to(b.position) < EPS and a.size.distance_to(b.size) < EPS


static func _hull(model: Node3D, id: String) -> PackedVector3Array:
	return model.get_node("Collision/" + id + "/Solid").shape.points


static func _member(model: Node3D, id: String) -> AABB:
	return SCAN._bounds(_hull(model, id))


static func _physical_match(model: Node3D, item: String) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != int(SOLID_COUNTS[item])
		or model.find_children("*", "CollisionShape3D", true, false).size() != bodies.size()
	):
		return false
	for body: StaticBody3D in bodies:
		if (
			body.get_parent() != model.get_node("Collision")
			or body.get_child_count() != 1
			or body.transform != Transform3D.IDENTITY
			or body.collision_layer != 1
			or body.collision_mask != 2
			or body.constant_linear_velocity != Vector3.ZERO
			or body.constant_angular_velocity != Vector3.ZERO
		):
			return false
		var collider: CollisionShape3D = body.get_child(0)
		if (
			str(collider.name) != "Solid"
			or not collider.shape is ConvexPolygonShape3D
			or collider.disabled
			or collider.shape.margin != 0
			or collider.transform != Transform3D.IDENTITY
		):
			return false
		var hull: PackedVector3Array = collider.shape.points
		var visible: PackedVector3Array = (
			model.get_node("Visual/" + str(body.name)).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not M.visible_bounds(item).grow(EPS).has_point(point)
				or not POINTS._has_point(visible, point)
			):
				return false
		for point: Vector3 in visible:
			if not POINTS._has_point(hull, point):
				return false
	return true


static func _roles(model: Node3D, item: String) -> bool:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		for forbidden: String in [
			"owned_copy",
			"receiver",
			"volume_id",
			"target_points",
			"water_scoring",
			"live_furnishing",
			"revenue",
			"income",
			"training",
			"stat_bonus",
			"capacity",
			"player_card",
			"receiver_id"
		]:
			if node.has_meta(forbidden):
				return false
		if node.has_meta("stadium_item") and node.get_meta("stadium_item") != item:
			return false
		if (
			node is StaticBody3D
			and (
				node.get_meta("stadium_item", "") != item
				or node.get_meta("surface_id", "") != str(node.name)
				or node.get_meta("ball_surface", "") != &"stadium_scenery"
				or node.get_meta("surface_role", "") != "DECORATIVE_AFTER_TERMINAL"
			)
		):
			return false
	return (
		model.get_meta("surface_role") == "DECORATIVE_AFTER_TERMINAL"
		and model.get_meta("physics_profile") == "DECORATIVE_AFTER_TERMINAL"
		and model.find_children("*", "Area3D", true, false).is_empty()
	)


static func _ungrounded(model: Node3D) -> Array[String]:
	var boxes: Dictionary = {}
	var connected: Dictionary = {}
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var id: String = str(body.name)
		boxes[id] = _member(model, id)
		if absf(boxes[id].position.y) < EPS:
			connected[id] = true
	var progress: bool = true
	while progress:
		progress = false
		for id: String in boxes:
			if connected.has(id):
				continue
			for support: String in connected.keys():
				if boxes[id].grow(EPS).intersects(boxes[support]):
					connected[id] = true
					progress = true
					break
	var missing: Array[String] = []
	for id: String in boxes:
		if not connected.has(id):
			missing.append(id)
	return missing


static func _strands(model: Node3D, item: String) -> bool:
	var panels: int = 0
	var total: int = 0
	for mesh: MeshInstance3D in model.get_node("Visual").get_children():
		if not mesh.get_meta("visual_strands", false):
			if not model.has_node("Collision/" + str(mesh.name)):
				return false
			continue
		panels += 1
		var count: int = int(mesh.get_meta("strand_count"))
		total += count
		if (
			count <= 0
			or model.has_node("Collision/" + str(mesh.name))
			or mesh.material_override.cull_mode != BaseMaterial3D.CULL_DISABLED
		):
			return false
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if vertices.size() != count * 6 or indices.size() != vertices.size():
			return false
		for index in range(indices.size()):
			if indices[index] != index:
				return false
		for index in range(0, vertices.size(), 3):
			var cross_value: Vector3 = -(vertices[index + 1] - vertices[index]).cross(
				vertices[index + 2] - vertices[index]
			)
			if (
				cross_value.length_squared() <= 1e-12
				or cross_value.normalized().dot(normals[index]) < 0.999
			):
				return false
	return panels == 7 and total == int(STRAND_COUNTS[item])


static func _panel_pattern(model: Node3D, pattern: String) -> bool:
	for mesh: MeshInstance3D in model.get_node("Visual").get_children():
		if mesh.get_meta("visual_strands", false) and mesh.get_meta("strand_pattern") != pattern:
			return false
	return true


static func _strand_attachment(model: Node3D) -> bool:
	# Net borders sit on real rail/post axes. Check actual vertices, not labels alone.
	var solids: Array[AABB] = []
	for body: StaticBody3D in model.get_node("Collision").get_children():
		solids.append(_member(model, str(body.name)).grow(0.01))
	for mesh: MeshInstance3D in model.get_node("Visual").get_children():
		if not mesh.get_meta("visual_strands", false):
			continue
		var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bounds: AABB = SCAN._bounds(points)
		var supported: int = 0
		for corner in range(8):
			var point: Vector3 = bounds.get_endpoint(corner)
			for solid: AABB in solids:
				if solid.has_point(point):
					supported += 1
					break
		# Planar AABBs repeat four corners. Every endpoint must have real support.
		if supported != 8:
			return false
	return true


static func _ray(model: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.to_global(from), model.to_global(to), 1
	)
	return model.get_world_3d().direct_space_state.intersect_ray(query)


static func _hit(model: Node3D, hit: Dictionary, name_value: String, y: float) -> bool:
	return (
		not hit.is_empty()
		and model.is_ancestor_of(hit.collider)
		and str(hit.collider.name) == name_value
		and absf(model.to_local(hit.position).y - y) < 0.003
	)

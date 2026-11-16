extends Node3D
## Detached retained 72-copy geometry, actual resources and installed collision controls.

const SOURCE: String = "res://src/tests/fixtures/npc_mogul_one_r1_authoring_source.json"
const PREFIX: String = "npc:AM-01:r1:"
const SOURCE_PREFIX: String = "npc-candidate:AM-01:deeper-center-v1:"
var _failures: int = 0


func _ready() -> void:
	var actual: StadiumNpcMogulOneV1 = StadiumNpcMogulOneV1.build()
	var source: StadiumPropertyGeometry = StadiumMogulOneStudy.build(
		self, StadiumPropertyGeometry.new())
	_check(actual != null and source != null, "independent retained and current authoring trees build")
	if actual == null or source == null:
		if actual != null:
			actual.free()
		if source != null:
			source.free()
		get_tree().quit(1)
		return
	remove_child(source)
	_check(actual.get_parent() == null and not actual.is_inside_tree()
		and source.get_parent() == null, "both comparison trees are detached")
	for method: String in ["install", "install_bound", "bind_ball", "prepare_receiver",
		"configure_candidate", "observe"]:
		_check(not actual.has_method(method), "no retained runtime entry point " + method)
	_check(not actual.get_node("ClubBoundary").has_method("bind_ball")
		and not actual.get_node("ClubBoundary").has_signal("contact_applied")
		and not actual.has_node("PitchReceiverPresentation"), "no gameplay adapter installed")
	_check(StadiumNpcMogulOneCorrespondence.matches(actual, source),
		"complete actual meshes, materials, labels, colliders, scripts and poses match source")
	_semantics(actual, source)
	_boundary_outcomes(actual, source)
	_mutations(source)
	_head_float32_step(actual, source)
	_display_policies(source)
	await _installed(actual, source)
	var fresh: StadiumNpcMogulOneV1 = StadiumNpcMogulOneV1.build()
	actual.field.safe_hit_z_m = 1
	actual.objects[PREFIX + "BASE-L1"].position.x = 0
	_check(StadiumNpcMogulOneCorrespondence.matches(fresh, source)
		and not StadiumNpcMogulOneCorrespondence.matches(actual, source),
		"returned construction cannot remodel future immutable copies")
	fresh.free()
	actual.free()
	source.free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro AM01 retained correspondence passed: exact 72-copy geometry and controls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _semantics(actual: StadiumNpcMogulOneV1, source: StadiumPropertyGeometry) -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var graph: StadiumNpcClubDugoutGraphV1 = actual.get_node("ClubBoundary").graph
	var original: StadiumDugoutBoundary = source.get_node("ClubBoundary").graph
	_check(graph.get_script() == StadiumNpcClubDugoutGraphV1 and graph._shape == "deeper_center"
		and graph.signature() == record.graph.signature and graph.identity() == record.graph.id
		and var_to_bytes(graph.segments()) == var_to_bytes(original.segments()),
		"complete original 16-edge graph identity, values, roles and priorities")
	_check(graph.segments().size() == 16 and actual.get_node("ClubBoundary").items.size() == 60,
		"complete authentic boundary item count with no filler panels")
	_check(var_to_bytes(actual.route_obstacles()) == var_to_bytes(_source_routes(source)),
		"exact target/anchor and cup-shaped net routing without a filled net disc")
	_check(StadiumNpcMogulOneV1.ROUTING.live_obstacles.is_empty()
		and StadiumNpcMogulOneV1.RECEIVER.net_model_version == 2
		and not StadiumNpcMogulOneV1.RECEIVER.installed,
		"corrected original receiver semantics remain uninstalled with zero live obstacles")
	for key: String in StadiumNpcMogulOneV1.FIELD:
		_check(actual.field.get(key) == source.field.get(key)
			and typeof(actual.field.get(key)) == typeof(source.field.get(key)),
			"original typed field value " + key)
	for index in range(-1, 10):
		_check(actual.field.fielder_anchor(index) == source.field.fielder_anchor(index)
			and actual.field.fielder_anchor_name(index) == source.field.fielder_anchor_name(index)
			and actual.field.is_fielder_anchor_available(index)
			== source.field.is_fielder_anchor_available(index), "field anchor and availability behavior")
		var start: Vector3 = actual.field.fielder_anchor(index)
		for end: Vector3 in [Vector3(-30, 0, 25), Vector3(30, 0, 25),
			Vector3(0, 0, -10), Vector3(0, 0, 35)]:
			_check(graph.clip(start, end) == original.clip(start, end),
				"original retained defender boundary clipping")
	for z: float in [-1, -0.5, 0, 11.25, 17, 23.4, 26, 29]:
		for x: float in [-30, -10, -0.45, 0, 0.45, 10, 30]:
			var point: Vector3 = Vector3(x, 1, z)
			_check(actual.field.is_fair_point(point) == source.field.is_fair_point(point),
				"fair-point behavior remains original")
	var retained: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumNpcMogulOneV1.TemplateView.new())
	var authored: StadiumWallViewPrisms = StadiumWallViewPrisms.new(original)
	_check(var_to_bytes(retained.walls) == var_to_bytes(authored.walls),
		"exact joined wall view prisms without a camera installation")
	var audience: int = 0
	for model: Node3D in actual.objects.values():
		audience += int(model.get_meta("represented_seats", 0))
	_check(audience == 208 and actual.find_children("*", "Light3D", true, false).is_empty(),
		"208 represented spectators and genuinely zero Light3D nodes")
	for tower: Dictionary in record.lighting.towers:
		var model: Node3D = actual.objects[PREFIX + tower.site]
		var reference: Node3D = source.objects[SOURCE_PREFIX + tower.site]
		var rays: Array = model.get_meta("candidate_head_rays")
		_check(rays.size() == 4 and model.get_node("Collision").get_child_count() == 3
			and not model.get_meta("night_qualified") and model.get_meta("obstacle_units") == 0,
			"genuine four-head standard tower remains dormant " + tower.site)
		for index in range(4):
			var ray: Dictionary = rays[index]
			var frozen: Dictionary = tower.heads[index]
			_check(ray.id == frozen.id
				and ray.origin == Vector3(frozen.origin[0], frozen.origin[1], frozen.origin[2])
				and ray.direction == Vector3(frozen.direction[0], frozen.direction[1], frozen.direction[2]),
				"canonical float32 original reference ray " + tower.site + str(index))
			var head: Node3D = model.get_node("Visual/Head%d" % index)
			var other: Node3D = reference.get_node("Visual/Head%d" % index)
			_check(head.transform == other.transform
				and not head.get_node("Lens").material_override.emission_enabled,
				"actual head transform and nonemissive lens exactly match genuine source")


func _source_routes(source: StadiumPropertyGeometry) -> Array[Dictionary]:
	# The original AM01 receiver route algorithm, evaluated detached with genuine source models.
	var result: Array[Dictionary] = []
	for ends: Array in StadiumReceiverNetModels.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			result.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	var target: Node3D = source.objects[SOURCE_PREFIX + "RECEIVER-PRIMARY"]
	var bounds: AABB = target.transform * StadiumTargetModels.ENVELOPE
	result.append({"center": bounds.get_center(),
		"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32})
	var net: Node3D = source.objects[SOURCE_PREFIX + "RECEIVER-CATCH"]
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			bounds = net.transform * body.transform * shape.transform * AABB(-size / 2, size)
			result.append({"center": bounds.get_center(),
				"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32})
	return result


func _boundary_outcomes(actual: StadiumNpcMogulOneV1, source: StadiumPropertyGeometry) -> void:
	var graph: StadiumNpcClubDugoutGraphV1 = actual.get_node("ClubBoundary").graph
	var original: StadiumDugoutBoundary = source.get_node("ClubBoundary").graph
	for row: Dictionary in original.segments():
		var midpoint: Vector2 = (row.a + row.b) / 2
		var inward: Vector2 = StadiumRecipeBoundary.inward(row)
		for height: float in [0.4, 2, 4]:
			var start: Vector3 = Vector3(midpoint.x + inward.x, height, midpoint.y + inward.y)
			var end: Vector3 = Vector3(midpoint.x - inward.x, height, midpoint.y - inward.y)
			var event: Dictionary = graph.crossing(start, end)
			_check(var_to_bytes(event) == var_to_bytes(original.crossing(start, end)),
				"exact retained boundary crossing " + row.id)
			for foul: bool in [false, true]:
				for grounded: bool in [false, true]:
					var first: BallPlayResolver = BallPlayResolver.new()
					var second: BallPlayResolver = BallPlayResolver.new()
					first.start_play(actual.field, foul)
					second.start_play(source.field, foul)
					first.state.has_grounded = grounded
					second.state.has_grounded = grounded
					var outputs: Array[Array] = [[], []]
					first.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
						outputs[0].append([outcome.result, outcome.reason,
							outcome.caught, outcome.resolution_position]))
					second.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
						outputs[1].append([outcome.result, outcome.reason,
							outcome.caught, outcome.resolution_position]))
					var one: bool = graph.apply(first, event)
					var two: bool = original.apply(second, original.crossing(start, end))
					_check(one == two and one and outputs[0] == outputs[1]
						and first.state.dead == second.state.dead
						and first.state.result_floor == second.state.result_floor
						and first.state.last_obstacle_contact == second.state.last_obstacle_contact
						and first.state.stadium_contacts == second.state.stadium_contacts,
						"original boundary outcome/reason/contact semantics " + row.id)


func _display_policies(source: StadiumPropertyGeometry) -> void:
	var original: StadiumScoreboardDisplay = source.objects[
		SOURCE_PREFIX + "SCORE-SMALL"].get_node("Visual/ScoreDisplay")
	_check(original.is_processing() and not original.is_physics_processing()
		and original._match == null, "original post-build manual display state is explicit")
	for edit in range(4):
		var actual: StadiumNpcMogulOneV1 = StadiumNpcMogulOneV1.build()
		var display: StadiumNpcClubDisplayV1 = actual.objects[
			PREFIX + "SCORE-SMALL"].get_node("Visual/ScoreDisplay")
		_check(not actual.is_inside_tree() and not actual.is_node_ready()
			and display.is_processing() and not display.is_physics_processing()
			and display._match == null and StadiumNpcMogulOneCorrespondence.matches(actual, source),
			"fresh detached exact baseline before each display policy control")
		match edit:
			0: display.set_process(false)
			1: display.set_physics_process(true)
			2: display._match = MatchState.new()
			3:
				var forged: GDScript = GDScript.new()
				forged.source_code = "extends StadiumNpcClubDisplayV1\n"
				_check(forged.reload() == OK, "same-valued forged display script compiles")
				display.set_script(forged)
		_check(not StadiumNpcMogulOneCorrespondence.matches(actual, source),
			"manual display process/physics/binding/script mutation is rejected " + str(edit))
		actual.free()


func _mutations(source: StadiumPropertyGeometry) -> void:
	for edit in range(43):
		var actual: StadiumNpcMogulOneV1 = StadiumNpcMogulOneV1.build()
		var model: Node3D = actual.objects[PREFIX + "MLIGHT-HL"]
		var head: Node3D = model.get_node("Visual/Head0")
		var pole: StaticBody3D = model.get_node("Collision/Mast")
		match edit:
			0: model.position.x += 0.0001
			1: model.scale.x = 1.0001
			2: model.set_meta("npc_host", PREFIX + "BASE-L1")
			3: model.set_meta("npc_instance", PREFIX + "BASE-L1")
			4: model.set_meta("stadium_item", "ST-090")
			5: model.get_node("Visual/Footing").mesh.size.x += 0.001
			6: pole.get_child(0).shape.radius += 0.001
			7: pole.get_child(0).disabled = true
			8: pole.collision_layer = 0
			9: pole.set_meta("surface_role", "LIVE_OBJECT")
			10: model.add_child(SpotLight3D.new())
			11: head.get_node("Lens").material_override.emission_enabled = true
			12: head.rotation.x += 0.001
			13: actual.field.safe_hit_z_m += 0.001
			14: actual.field.id = &"field.starter_backyard"
			15:
				var host: Node3D = Node3D.new()
				actual.add_child(host)
				actual.remove_child(model)
				host.add_child(model)
			16:
				var shape: ConvexPolygonShape3D = actual.get_node("ClubBoundary/BACK-01").get_child(0).shape
				var points: PackedVector3Array = shape.points
				points[0].x += 0.01
				shape.points = points
			17: model.process_mode = Node.PROCESS_MODE_DISABLED
			18: pole.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			19: pole.process_mode = Node.PROCESS_MODE_DISABLED
			20:
				var forged: GDScript = GDScript.new()
				forged.source_code = "extends Node3D\n"
				_check(forged.reload() == OK, "anonymous script control compiles")
				model.set_script(forged)
			21: actual.objects.erase(PREFIX + "MLIGHT-HR")
			22: pole.set_meta("npc_instance", PREFIX + "MLIGHT-HR")
			23: model.set_meta("owned_copy", "human:forged")
			24:
				var forged: FieldDefinition = preload(
					"res://src/tests/stadium_npc_candidate_v2_forged_field.gd").new()
				for key: String in StadiumNpcMogulOneV1.FIELD:
					forged.set(key, actual.field.get(key))
				actual.field = forged
			25: head.get_node("Lens").material_override.albedo_color = Color.RED
			26: actual.add_child(StaticBody3D.new())
			27: actual.get_node("ClubBoundary").process_mode = Node.PROCESS_MODE_DISABLED
			28: _attach_resource_script(pole.get_child(0).shape, "CylinderShape3D")
			29: _attach_resource_script(model.get_node("Visual/Footing").mesh, "BoxMesh")
			30: _attach_resource_script(head.get_node("Lens").material_override, "StandardMaterial3D")
			31: actual.objects[PREFIX + "BASE-L1"].get_node("Visual/FrontGuard").mesh.size.y = 1.0
			32: actual.objects[PREFIX + "BOWL-03"].get_node("Visual/SolidTerrace0").visible = false
			33:
				actual.objects[PREFIX + "SCORE-SMALL"].get_node(
					"Visual/ScoreDisplay").get_child(0).text = "BAD"
			34: actual.objects[PREFIX + "RECEIVER-PRIMARY"].get_node("Visual/ST026_PANEL").position.z -= 0.01
			35: actual.objects[PREFIX + "RECEIVER-CATCH"].get_node("Visual").visible = false
			36: model.set_meta("aim_profile", "MOGUL6-PREMIUM")
			37: model.set_meta("night_qualified", true)
			38: actual.objects[PREFIX + "ST-065-01"].position.x += 0.0001
			39: actual.objects[PREFIX + "FOUL-POLE-L"].get_node("Collision/Pole").collision_mask = 0
			40: actual.get_node("ClubBoundary").graph._shape = "straight"
			41: actual.get_node("ClubBoundary").items.reverse()
			42: actual.get_node("ClubBoundary").bodies.reverse()
		_check(not StadiumNpcMogulOneCorrespondence.matches(actual, source),
			"unchanged candidate cannot conceal actual physical/semantic edit " + str(edit))
		actual.free()
	var exact: StadiumNpcMogulOneV1 = StadiumNpcMogulOneV1.build()
	_check(StadiumNpcMogulOneCorrespondence.matches(exact, source),
		"fresh exact construction survives all negative controls")
	exact.free()


func _head_float32_step(actual: StadiumNpcMogulOneV1, source: StadiumPropertyGeometry) -> void:
	var head: Node3D = actual.objects[PREFIX + "MLIGHT-HL"].get_node("Visual/Head0")
	var original: Transform3D = head.transform
	var binary: PackedByteArray = PackedFloat32Array([head.position.y]).to_byte_array()
	var before: int = binary.decode_u32(0)
	binary.encode_u32(0, before + 1)
	head.position.y = binary.decode_float(0)
	var after: int = PackedFloat32Array([head.position.y]).to_byte_array().decode_u32(0)
	_check(after == before + 1 and head.position.y != original.origin.y,
		"negative control changes actual head pose by exactly one float32 ULP")
	_check(not StadiumNpcMogulOneCorrespondence.matches(actual, source),
		"one-float32-step actual optical pose rejected without tolerance")
	head.transform = original
	_check(StadiumNpcMogulOneCorrespondence.matches(actual, source),
		"exact head restoration restores strict independent correspondence")


func _attach_resource_script(resource: Resource, base: String) -> void:
	var before: PackedByteArray = var_to_bytes(StadiumNpcRetainedGeometry._resource(resource))
	var forged: GDScript = GDScript.new()
	forged.source_code = "extends " + base + "\n"
	_check(forged.reload() == OK, "same-valued resource script control compiles")
	resource.set_script(forged)
	_check(resource.get_script() == forged, "resource script really attached")
	_check(var_to_bytes(StadiumNpcRetainedGeometry._resource(resource)) == before,
		"same-valued script leaves original value-only resource serializer unchanged")


func _installed(actual: StadiumNpcMogulOneV1, source: StadiumPropertyGeometry) -> void:
	add_child(actual)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for site: String in StadiumNpcMogulOneTowerSitesV1.SITES:
		var model: Node3D = actual.objects[PREFIX + site]
		var point: Vector3 = model.position + Vector3(0, 2, 0)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + Vector3(0, 0, -1), point + Vector3(0, 0, 1), 1)
		var body: StaticBody3D = model.get_node("Collision/Mast")
		var hit: Dictionary = space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == body, "retained actual tower collider " + site)
	var model: Node3D = actual.objects[PREFIX + "MLIGHT-HL"]
	var body: StaticBody3D = model.get_node("Collision/Mast")
	var point: Vector3 = model.position + Vector3(0, 2, 0)
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3(0, 0, -1), point + Vector3(0, 0, 1), 1)
	for target: Node in [actual, body]:
		target.process_mode = Node.PROCESS_MODE_DISABLED
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(space.intersect_ray(ray).is_empty()
			and not StadiumNpcMogulOneCorrespondence.matches(actual, source),
			"disabled root/body removes real collision and fails correspondence")
		target.process_mode = Node.PROCESS_MODE_INHERIT
		await get_tree().physics_frame
		await get_tree().physics_frame
		var hit: Dictionary = space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == body
			and StadiumNpcMogulOneCorrespondence.matches(actual, source),
			"restored mode restores real collision and exact correspondence")
	remove_child(actual)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

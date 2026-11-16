extends Node3D
## Detached retained eight-copy correspondence and real installed collision controls.

const SOURCE: String = "res://src/tests/fixtures/npc_yard_three_r1_authoring_source.json"
const PREFIX: String = "npc:AY-03:r1:"
var _failures: int = 0


func _ready() -> void:
	var actual: StadiumNpcYardV1 = StadiumNpcYardThreeV1.build()
	var source: StadiumPropertyGeometry = StadiumYardThreeStudy.build()
	_check(actual != null and source != null, "both independently retained and authored trees build")
	if actual == null or source == null:
		if actual != null:
			actual.free()
		if source != null:
			source.free()
		get_tree().quit(1)
		return
	_check(StadiumNpcYardThreeCorrespondence.matches(actual, source),
		"all eight real meshes/materials/colliders/poses/hosts/optics match independent source")
	_semantics(actual, source)
	_boundary_outcomes(actual.field, source.field)
	_mutations(source)
	_beam_float32_step(actual, source)
	await _installed(actual, source)
	var fresh: StadiumNpcYardV1 = StadiumNpcYardThreeV1.build()
	actual.field.safe_hit_z_m = 1
	actual.objects[PREFIX + "SC-L1"].position.x = 0
	_check(StadiumNpcYardThreeCorrespondence.matches(fresh, source)
		and not StadiumNpcYardThreeCorrespondence.matches(actual, source),
		"mutated returned construction cannot remodel future immutable copies")
	fresh.free()
	actual.free()
	source.free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro AY03 retained correspondence passed: exact eight-copy geometry and controls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _semantics(actual: StadiumNpcYardV1, source: StadiumPropertyGeometry) -> void:
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var surface: Dictionary = StadiumNpcYardThreeV1.surface()
	_check(ClubCareer.same(surface, record.surface)
		and surface.id == StadiumNpcYardThreeCandidateV1.definition().presentation.profile
		and StadiumNpcYardV1.SURFACE.id == "AY-01-default-backyard-v1",
		"explicit AY03 surface recipe preserves AY01 historical semantic constant")
	_check(ClubCareer.same(StadiumNpcYardThreeV1.receiver(), record.receiver)
		and ClubCareer.same(StadiumNpcYardThreeV1.routing(), record.routing)
		and record.receiver.catalog_item.is_empty() and record.routing.live_obstacles.is_empty()
		and not actual.has_node("PitchReceiverPresentation")
		and actual.get_node("BoundaryGraph").get_child_count() == 6,
		"original free receiver/routing and complete six-slab boundary remain exact")
	_check(record.receiver.plane_z == PitchFlightActor.RECEIVER_PLANE_Z
		and record.receiver.min_travel == PitchFlightActor.MIN_RECEIVER_TRAVEL_SECONDS
		and record.receiver.max_travel == PitchFlightActor.MAX_RECEIVER_TRAVEL_SECONDS
		and record.receiver.hold == PitchFlightActor.RECEIVER_HOLD_SECONDS,
		"free receiver retains real original timing and plane behavior constants")
	surface.bounds[0] = 0
	var receiver: Dictionary = StadiumNpcYardThreeV1.receiver()
	receiver.pitch_surfaces.append("foreign")
	var routing: Dictionary = StadiumNpcYardThreeV1.routing()
	routing.live_obstacles.append("foreign")
	_check(ClubCareer.same(StadiumNpcYardThreeV1.surface(), record.surface)
		and ClubCareer.same(StadiumNpcYardThreeV1.receiver(), record.receiver)
		and ClubCareer.same(StadiumNpcYardThreeV1.routing(), record.routing),
		"semantic recipe returns are deeply isolated")
	for key: String in record.field.values:
		var stored: Variant = record.field.values[key]
		var observed: Variant = actual.field.get(key)
		var frozen_equal: bool = String(observed) == stored if key == "id" else observed == stored
		_check(typeof(observed) == typeof(source.field.get(key))
			and observed == source.field.get(key) and frozen_equal,
			"original typed field value " + key)
	for index in range(-1, 10):
		_check(actual.field.fielder_anchor(index) == source.field.fielder_anchor(index)
			and actual.field.fielder_anchor_name(index) == source.field.fielder_anchor_name(index)
			and actual.field.is_fielder_anchor_available(index)
			== source.field.is_fielder_anchor_available(index), "field anchor behavior including clamp")
		var start: Vector3 = actual.field.fielder_anchor(index)
		for end: Vector3 in [Vector3(-30, 0, 25), Vector3(30, 0, 25),
			Vector3(0, 0, -10), Vector3(0, 0, 35)]:
			_check(StadiumNpcYardGraphV1.clip(start, end) == StadiumBoundaryGraph.clip(start, end),
				"original retained defender boundary clipping")
	for z: float in [-1, -0.5, 0, 11.25, 17, 23.4, 29]:
		for x: float in [-30, -10, -0.45, 0, 0.45, 10, 30]:
			var point: Vector3 = Vector3(x, 1, z)
			_check(actual.field.is_fair_point(point) == source.field.is_fair_point(point),
				"fair-point behavior remains original")
	_check(StadiumNpcYardGraphV1.signature() == record.boundary.signature
		and var_to_bytes(StadiumNpcYardGraphV1.segments()) == var_to_bytes(
			StadiumBoundaryGraph.segments()), "exact boundary roles, priorities and graph identity")
	for row: Dictionary in StadiumBoundaryGraph.segments():
		var midpoint: Vector2 = (row.a + row.b) / 2
		var inward: Vector2 = StadiumBoundaryGraph.inward(row)
		for height: float in [0.4, 1.2, 2, 3.25, 4]:
			var start: Vector3 = Vector3(midpoint.x + inward.x, height, midpoint.y + inward.y)
			var end: Vector3 = Vector3(midpoint.x - inward.x, height, midpoint.y - inward.y)
			_check(var_to_bytes(StadiumNpcYardGraphV1.crossing(start, end)) == var_to_bytes(
				StadiumBoundaryGraph.crossing(start, end)), "retained boundary crossing " + row.id)
	var retained: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumNpcYardV1.TemplateView.new())
	var authored: StadiumWallViewPrisms = StadiumWallViewPrisms.new(
		StadiumYardFieldVisibility.TemplateView.new())
	_check(var_to_bytes(retained.walls) == var_to_bytes(authored.walls),
		"exact joined wall view prisms without installing a camera")
	for model: Node3D in actual.objects.values():
		if model.get_meta("stadium_item") == "ST-080":
			_check(model.get_node("Collision").get_child_count() == 6
				and model.get_node("Visual/CrowdAnchor0").get_child_count() == 4,
				"each actual occupied chair retains all solids and audience meshes")
		else:
			var beam: SpotLight3D = model.get_node("FieldLight")
			_check(not beam.visible and not model.get_node(
				"Visual/LampLens").material_override.emission_enabled,
				"every actual light and lens is dormant")
			var cylinder: CollisionShape3D = model.get_node("Collision/Pole").get_child(0)
			_check(cylinder.shape is CylinderShape3D
				and cylinder.shape.radius == float(PackedFloat32Array([0.085])[0]),
				"retained real pole cylinder, not a metadata envelope")


func _boundary_outcomes(actual: FieldDefinition, source: FieldDefinition) -> void:
	for row: Dictionary in StadiumBoundaryGraph.segments():
		var midpoint: Vector2 = (row.a + row.b) / 2
		var inward: Vector2 = StadiumBoundaryGraph.inward(row)
		for height: float in [0.4, 2, 4]:
			var start: Vector3 = Vector3(midpoint.x + inward.x, height, midpoint.y + inward.y)
			var end: Vector3 = Vector3(midpoint.x - inward.x, height, midpoint.y - inward.y)
			for foul: bool in [false, true]:
				for grounded: bool in [false, true]:
					var first: BallPlayResolver = BallPlayResolver.new()
					var second: BallPlayResolver = BallPlayResolver.new()
					first.start_play(actual, foul)
					second.start_play(source, foul)
					first.state.has_grounded = grounded
					second.state.has_grounded = grounded
					var outputs: Array[Array] = [[], []]
					first.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
						outputs[0].append([outcome.result, outcome.reason,
							outcome.caught, outcome.resolution_position]))
					second.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
						outputs[1].append([outcome.result, outcome.reason,
							outcome.caught, outcome.resolution_position]))
					var one: bool = StadiumNpcYardGraphV1.apply(first,
						StadiumNpcYardGraphV1.crossing(start, end))
					var two: bool = StadiumBoundaryGraph.apply(second,
						StadiumBoundaryGraph.crossing(start, end))
					_check(one == two and one and outputs[0] == outputs[1]
						and first.state.dead == second.state.dead
						and first.state.result_floor == second.state.result_floor
						and first.state.last_obstacle_contact == second.state.last_obstacle_contact
						and first.state.stadium_contacts == second.state.stadium_contacts,
						"original boundary outcome/reason/contact semantics " + row.id)


func _mutations(source: StadiumPropertyGeometry) -> void:
	for edit in range(37):
		var actual: StadiumNpcYardV1 = StadiumNpcYardThreeV1.build()
		var model: Node3D = actual.objects[PREFIX + "YLIGHT-FL"]
		var beam: SpotLight3D = model.get_node("FieldLight")
		var pole: StaticBody3D = model.get_node("Collision/Pole")
		match edit:
			0: model.position.x += 0.0001
			1: model.scale.x = 1.0001
			2: model.set_meta("npc_host", PREFIX + "SC-L1")
			3: model.set_meta("npc_instance", PREFIX + "SC-L1")
			4: model.set_meta("stadium_item", "ST-038")
			5: model.get_node("Visual/Footing").mesh.size.x += 0.001
			6: pole.get_child(0).shape.radius += 0.001
			7: pole.get_child(0).disabled = true
			8: pole.collision_layer = 0
			9: pole.set_meta("surface_role", "LIVE_OBJECT")
			10: beam.visible = true
			11: beam.light_energy += 0.001
			12: beam.spot_angle += 0.01
			13: beam.rotation.x += 0.001
			14: model.get_node("Visual/LampLens").material_override.emission_enabled = true
			15: actual.field.safe_hit_z_m += 0.001
			16: actual.field.id = &"field.starter_backyard"
			17:
				var host: Node3D = Node3D.new()
				actual.add_child(host)
				actual.remove_child(model)
				host.add_child(model)
			18:
				var shape: ConvexPolygonShape3D = actual.get_node(
					"BoundaryGraph").get_child(0).get_child(0).shape
				var points: PackedVector3Array = shape.points
				points[0].x += 0.01
				shape.points = points
			19: model.process_mode = Node.PROCESS_MODE_DISABLED
			20: pole.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			21: pole.process_mode = Node.PROCESS_MODE_DISABLED
			22:
				var forged: GDScript = GDScript.new()
				forged.source_code = "extends Node3D\n"
				_check(forged.reload() == OK, "anonymous script control compiles")
				model.set_script(forged)
			23: beam.shadow_enabled = false
			24: beam.spot_range += 1
			25: beam.spot_attenuation += 0.001
			26: actual.objects.erase(PREFIX + "YLIGHT-FR")
			27: pole.set_meta("npc_instance", PREFIX + "YLIGHT-FR")
			28: model.set_meta("owned_copy", "human:forged")
			29:
				var forged: FieldDefinition = preload(
					"res://src/tests/stadium_npc_candidate_v2_forged_field.gd").new()
				for key: String in StadiumNpcYardV1.FIELD:
					forged.set(key, actual.field.get(key))
				actual.field = forged
			30: model.get_node("Visual/LampLens").material_override.albedo_color = Color.RED
			31: actual.objects[PREFIX + "SC-L1"].get_node("Collision/SpectatorSeat").collision_mask = 0
			32: actual.add_child(StaticBody3D.new())
			33: actual.get_node("BoundaryGraph").process_mode = Node.PROCESS_MODE_DISABLED
			34: _attach_resource_script(pole.get_child(0).shape, "CylinderShape3D")
			35: _attach_resource_script(model.get_node("Visual/Footing").mesh, "BoxMesh")
			36: _attach_resource_script(model.get_node("Visual/LampLens").material_override,
				"StandardMaterial3D")
		_check(not StadiumNpcYardThreeCorrespondence.matches(actual, source),
			"unchanged candidate cannot conceal actual physical/semantic edit " + str(edit))
		actual.free()
	var exact: StadiumNpcYardV1 = StadiumNpcYardThreeV1.build()
	_check(StadiumNpcYardThreeCorrespondence.matches(exact, source),
		"independent fresh restore passes after all actual-node mutation controls")
	exact.free()


func _beam_float32_step(actual: StadiumNpcYardV1, source: StadiumPropertyGeometry) -> void:
	var beam: SpotLight3D = actual.objects[PREFIX + "YLIGHT-FL"].get_node("FieldLight")
	var original: Transform3D = beam.transform
	var before: int = PackedFloat32Array([beam.position.y]).to_byte_array().decode_u32(0)
	# Exact successor of the retained 6.2950000762939453125 float32 coordinate.
	beam.position.y = 6.295000553131103515625
	var after: int = PackedFloat32Array([beam.position.y]).to_byte_array().decode_u32(0)
	_check(after == before + 1 and beam.position.y != original.origin.y,
		"negative control changes actual beam pose by exactly one float32 ULP")
	_check(not StadiumNpcYardThreeCorrespondence.matches(actual, source),
		"one-float32-step actual optical pose is rejected without tolerance")
	beam.transform = original
	_check(StadiumNpcYardThreeCorrespondence.matches(actual, source),
		"exact beam pose restoration restores strict independent correspondence")


func _attach_resource_script(resource: Resource, base: String) -> void:
	var before: PackedByteArray = var_to_bytes(StadiumNpcRetainedGeometry._resource(resource))
	var forged: GDScript = GDScript.new()
	forged.source_code = "extends " + base + "\n"
	_check(forged.reload() == OK, "same-valued resource script control compiles")
	resource.set_script(forged)
	_check(resource.get_script() == forged, "resource script really attached")
	_check(var_to_bytes(StadiumNpcRetainedGeometry._resource(resource)) == before,
		"same-valued resource script leaves the old geometry serializer unchanged")


func _installed(actual: StadiumNpcYardV1, source: StadiumPropertyGeometry) -> void:
	add_child(actual)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for site: String in ["YLIGHT-FL", "YLIGHT-FR", "YLIGHT-RL", "YLIGHT-RR"]:
		var model: Node3D = actual.objects[PREFIX + site]
		var point: Vector3 = model.position + Vector3(0, 2, 0)
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + Vector3(0, 0, -1), point + Vector3(0, 0, 1), 1)
		var body: StaticBody3D = model.get_node("Collision/Pole")
		var hit: Dictionary = space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == body,
			"each retained dormant pole is really installed " + site)
		for target: Node in [actual, body]:
			target.process_mode = Node.PROCESS_MODE_DISABLED
			await get_tree().physics_frame
			await get_tree().physics_frame
			_check(space.intersect_ray(ray).is_empty()
				and not StadiumNpcYardThreeCorrespondence.matches(actual, source),
				"installed root/body disable genuinely removes collision and rejects correspondence")
			target.process_mode = Node.PROCESS_MODE_INHERIT
			await get_tree().physics_frame
			await get_tree().physics_frame
			hit = space.intersect_ray(ray)
			_check(not hit.is_empty() and hit.collider == body
				and StadiumNpcYardThreeCorrespondence.matches(actual, source),
				"restored execution mode restores real collision and strict correspondence")
	remove_child(actual)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

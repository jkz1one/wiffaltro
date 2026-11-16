extends Node3D
## Strict four-copy retained correspondence with real installed collision and mutation controls.

const SOURCE: String = "res://src/tests/fixtures/npc_yard_two_r1_authoring_source.json"
const PREFIX: String = "npc:AY-02:r1:"
var _failures: int = 0


func _ready() -> void:
	var actual: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.build()
	var source: StadiumYardTwoProperty = StadiumYardTwoStudy.build()
	_check(actual != null and source != null, "independent retained and genuine source trees build")
	if actual == null or source == null:
		if actual != null:
			actual.free()
		if source != null:
			source.free()
		get_tree().quit(1)
		return
	_check(StadiumNpcYardTwoCorrespondence.matches(actual, source),
		"complete actual nodes/resources/scripts/poses/modes match qualified source")
	_semantics(actual, source)
	_boundary_outcomes(actual.field, source.field)
	_mutations(source)
	_receiver_float32_step(actual, source)
	await _installed(actual, source)
	var fresh: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.build()
	actual.field.safe_hit_z_m = 1
	actual.objects[PREFIX + "O-R1"].position.x = 0
	_check(StadiumNpcYardTwoCorrespondence.matches(fresh, source)
		and not StadiumNpcYardTwoCorrespondence.matches(actual, source),
		"returned mutable scene cannot alter future immutable construction")
	fresh.free()
	actual.free()
	source.free()
	await get_tree().process_frame
	if _failures == 0:
		print("Wiffaltro AY02 retained correspondence passed: exact four-copy geometry and controls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _semantics(actual: StadiumNpcYardTwoV1, source: StadiumYardTwoProperty) -> void:
	var record: Dictionary = StadiumNpcYardTwoContractV1.canonical()
	var surface: Dictionary = StadiumNpcYardTwoV1.surface()
	_check(JSON.stringify(record, "", true, true) == FileAccess.get_file_as_string(SOURCE)
		and surface == record.surface and surface.id == "AY-02-default-backyard-v1"
		and StadiumNpcYardV1.SURFACE.id == "AY-01-default-backyard-v1",
		"complete contract and retained AY01 surface literal stay independently exact")
	_check(StadiumNpcYardTwoV1.receiver() == record.receiver
		and StadiumNpcYardTwoV1.routing() == record.routing
		and record.receiver.catalog_item == "ST-079" and record.receiver.catching_layer.is_empty()
		and record.routing.live_obstacles.size() == 1
		and not actual.has_node("PitchReceiverPresentation")
		and actual.get_node("BoundaryGraph").get_child_count() == 6,
		"chair-only receiver, cone-only live unit, six slabs and no runtime receiver installer")
	_check(record.receiver.cleanup_z == StadiumPitchReceiver.CLEANUP_Z
		and record.receiver.timeout == StadiumPitchReceiver.TIMEOUT
		and record.receiver.sweep_step == StadiumPitchReceiver.STEP
		and record.receiver.visual_settle == 0.28 and record.receiver.max_pitch_contacts == 1
		and record.receiver.pitch_surfaces == StadiumNpcYardTwoStarterV1.surfaces("ST-079")
		and record.receiver.batted_surfaces == StadiumStarterModels.surfaces("ST-079"),
		"literal receiver preserves every original rest-only surface and timing constant")
	surface.bounds[0] = 0
	var receiver: Dictionary = StadiumNpcYardTwoV1.receiver()
	receiver.pitch_surfaces.append("foreign")
	var routing: Dictionary = StadiumNpcYardTwoV1.routing()
	routing.live_obstacles.clear()
	_check(StadiumNpcYardTwoV1.surface() == record.surface
		and StadiumNpcYardTwoV1.receiver() == record.receiver
		and StadiumNpcYardTwoV1.routing() == record.routing, "semantic getters are deeply isolated")
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
	for site: String in ["SIDE-SEAT-L", "SIDE-SEAT-R"]:
		var model: Node3D = actual.objects[PREFIX + site]
		_check(model.get_meta("represented_seats") == 10,
			"each bleacher retains ten bundled audience anchors")
		for index in range(10):
			_check(model.get_node("Visual/CrowdAnchor" + str(index)).get_child_count() == 4,
				"complete original occupied bleacher audience geometry")
	var chair: Node3D = actual.objects[PREFIX + "RECEIVER-PRIMARY"]
	var cone: Node3D = actual.objects[PREFIX + "O-R1"]
	_check(chair.get_node("Collision").get_child_count() == 10
		and cone.get_node("Collision").get_child_count() == 2,
		"receiver retains ten named rest surfaces and cone retains two live solids")
	var detached_root: Node = actual
	_check(not detached_root is StadiumPropertyGeometry and not actual.has_method("bind_ball")
		and not actual.has_method("_ball_contact") and not actual.has_node("Camera3D")
		and not actual.has_node("YardTwoActorPresentation"),
		"detached root has no runtime contact, camera or actor installer")


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


func _mutations(source: StadiumYardTwoProperty) -> void:
	for edit in range(40):
		var actual: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.build()
		var model: Node3D = actual.objects[PREFIX + "RECEIVER-PRIMARY"]
		var body: StaticBody3D = model.get_node("Collision/ST079_BACK")
		var mesh: MeshInstance3D = model.get_node("Visual/ST079_BACK")
		var cone: Node3D = actual.objects[PREFIX + "O-R1"]
		match edit:
			0: model.position.x += 0.0001
			1: model.scale.x = 1.0001
			2: model.set_meta("npc_host", PREFIX + "O-R1")
			3: model.set_meta("npc_instance", PREFIX + "O-R1")
			4: model.set_meta("stadium_item", "ST-003")
			5: mesh.mesh.size.x += 0.001
			6: body.get_child(0).shape.size.x += 0.001
			7: body.get_child(0).disabled = true
			8: body.collision_layer = 0
			9: body.set_meta("surface_role", "LIVE_RICOCHET")
			10: model.get_node("Visual").visible = false
			11: mesh.material_override.roughness += 0.001
			12: mesh.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			13: model.get_node("Visual").rotation.z += 0.001
			14: mesh.material_override.emission_enabled = true
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
			20: body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
			21: body.process_mode = Node.PROCESS_MODE_DISABLED
			22:
				var forged: GDScript = GDScript.new()
				forged.source_code = "extends Node3D\n"
				_check(forged.reload() == OK, "anonymous node script control compiles")
				model.set_script(forged)
			23: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			24: body.collision_mask = 2
			25: cone.get_node("Visual/CONE_BODY").mesh.top_radius += 0.001
			26: actual.objects.erase(PREFIX + "SIDE-SEAT-R")
			27: body.set_meta("npc_instance", PREFIX + "O-R1")
			28: model.set_meta("owned_copy", "human:forged")
			29:
				var forged: FieldDefinition = preload(
					"res://src/tests/stadium_npc_candidate_v2_forged_field.gd").new()
				for key: String in StadiumNpcYardV1.FIELD:
					forged.set(key, actual.field.get(key))
				actual.field = forged
			30: mesh.material_override.albedo_color = Color.RED
			31: actual.objects[PREFIX + "SIDE-SEAT-L"].get_node(
				"Visual/CrowdAnchor0/Body").mesh.radius += 0.001
			32: actual.add_child(StaticBody3D.new())
			33: actual.get_node("BoundaryGraph").process_mode = Node.PROCESS_MODE_DISABLED
			34: _attach_resource_script(body.get_child(0).shape, "BoxShape3D")
			35: _attach_resource_script(mesh.mesh, "BoxMesh")
			36: _attach_resource_script(mesh.material_override, "StandardMaterial3D")
			37: model.set_process(true)
			38: model.set_physics_process(true)
			39: body.set_meta("ball_surface", &"ground")
		_check(not StadiumNpcYardTwoCorrespondence.matches(actual, source),
			"strict actual-resource/geometry/identity/process mutation rejected " + str(edit))
		actual.free()
	var exact: StadiumNpcYardTwoV1 = StadiumNpcYardTwoV1.build()
	_check(StadiumNpcYardTwoCorrespondence.matches(exact, source),
		"fresh exact build passes after every adversarial mutation")
	exact.free()


func _receiver_float32_step(actual: StadiumNpcYardTwoV1, source: StadiumYardTwoProperty) -> void:
	var model: Node3D = actual.objects[PREFIX + "RECEIVER-PRIMARY"]
	var original: Transform3D = model.transform
	var bytes: PackedByteArray = PackedFloat32Array([model.position.z]).to_byte_array()
	var before: int = bytes.decode_u32(0)
	bytes.encode_u32(0, before + 1)
	model.position.z = bytes.decode_float(0)
	_check(PackedFloat32Array([model.position.z]).to_byte_array().decode_u32(0) == before + 1
		and model.position.z != original.origin.z,
		"receiver negative changes actual physical pose by exactly one float32 ULP")
	_check(not StadiumNpcYardTwoCorrespondence.matches(actual, source),
		"adjacent float32 actual receiver pose rejected without tolerance")
	model.transform = original
	_check(StadiumNpcYardTwoCorrespondence.matches(actual, source),
		"exact receiver pose restore restores strict correspondence")


func _attach_resource_script(resource: Resource, base: String) -> void:
	var before: PackedByteArray = var_to_bytes(StadiumNpcRetainedGeometry._resource(resource))
	var forged: GDScript = GDScript.new()
	forged.source_code = "extends " + base + "\n"
	_check(forged.reload() == OK, "same-valued resource script control compiles")
	resource.set_script(forged)
	_check(resource.get_script() == forged, "resource script really attached")
	_check(var_to_bytes(StadiumNpcRetainedGeometry._resource(resource)) == before,
		"same-valued resource script leaves the old geometry serializer unchanged")


func _installed(actual: StadiumNpcYardTwoV1, source: StadiumYardTwoProperty) -> void:
	# Source routing reads global transforms. Attach the real original tree for that observation;
	# remove it before retained collision rays so original colliders cannot mask the controls.
	add_child(source)
	await get_tree().physics_frame
	var original_routes: Array[Dictionary] = source.route_obstacles()
	remove_child(source)
	var routes: Array[Dictionary] = actual.route_obstacles()
	_check(routes.size() == 2 and original_routes.size() == 2,
		"chair receiver clearance and one cone blocker are both retained")
	for index in range(routes.size()):
		var old: Dictionary = original_routes[index].duplicate(true)
		old.copy = String(old.copy).replace("npc-candidate:AY-02:", PREFIX)
		_check(var_to_bytes(routes[index]) == var_to_bytes(old),
			"exact original field-local routing radius/center and mapped copy identity")
	add_child(actual)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for site: String in ["RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R", "O-R1"]:
		var model: Node3D = actual.objects[PREFIX + site]
		var surface: String = "ST079_BACK" if site == "RECEIVER-PRIMARY" else (
			"CONE_BODY" if site == "O-R1" else "LowerBench")
		var body: StaticBody3D = model.get_node("Collision/" + surface)
		# x=1 stays inside the bench and avoids its x=0/+-2.65 diagonal/support solids.
		var offset: Vector3 = Vector3(1, 0, 0) if site.begins_with("SIDE-SEAT") else Vector3.ZERO
		var center: Vector3 = model.to_global(body.position + offset)
		var direction: Vector3 = Vector3.UP if site.begins_with("SIDE-SEAT") else Vector3.FORWARD
		var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			center - direction * 0.25, center + direction * 0.25, 1)
		var hit: Dictionary = space.intersect_ray(ray)
		_check(not hit.is_empty() and hit.collider == body,
			"each original retained assembly has a real installed collision witness " + site)
		for target: Node in [actual, body]:
			target.process_mode = Node.PROCESS_MODE_DISABLED
			await get_tree().physics_frame
			await get_tree().physics_frame
			_check(space.intersect_ray(ray).is_empty()
				and not StadiumNpcYardTwoCorrespondence.matches(actual, source),
				"root/body disable really removes collision and fails strict oracle")
			target.process_mode = Node.PROCESS_MODE_INHERIT
			await get_tree().physics_frame
			await get_tree().physics_frame
			hit = space.intersect_ray(ray)
			_check(not hit.is_empty() and hit.collider == body
				and StadiumNpcYardTwoCorrespondence.matches(actual, source),
				"exact process restoration restores physical witness and strict correspondence")
	remove_child(actual)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


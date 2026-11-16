extends RefCounted
## Every installed mutation starts with a fresh issued play and accepted authority.
const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
const Proof = preload("res://src/tests/stadium_npc_yard_two_installed_proof.gd")
const P: String = "npc:AY-02:r1:"
const IDS: Array[String] = [
	"INT-09/callback_positive",
	"INT-01/chair_identity",
	"INT-02/cone_identity",
	"INT-03/appended_body",
	"INT-03/missing_body",
	"INT-03/reparented_body",
	"INT-04/shape_resource",
	"INT-04/shape_node",
	"INT-05/model_script",
	"INT-05/shape_script",
	"INT-05/mesh_script",
	"INT-05/material_script",
	"INT-05/field_script",
	"INT-06/one_ulp_pose",
	"INT-06/one_ulp_dimension",
	"INT-06/wrapper_pose",
	"INT-06/construction_pose",
	"INT-06/model_pose",
	"INT-06/body_pose",
	"INT-06/shape_pose",
	"INT-06/boundary_pose",
	"INT-06/lab_pose",
	"INT-06/host_pose",
	"INT-07/layer",
	"INT-07/mask",
	"INT-07/disable_mode",
	"INT-07/process_mode",
	"INT-07/disabled",
	"INT-08/instance",
	"INT-08/alias",
	"INT-08/item",
	"INT-08/site",
	"INT-08/host",
	"INT-08/surface",
	"INT-08/role",
	"INT-09/field_identity",
	"INT-09/support_identity",
	"INT-09/motion_identity",
	"INT-09/visibility_identity",
	"INT-09/boundary_body",
	"INT-09/ball_callback",
	"INT-10/forged_payload",
	"INT-10/foreign_collider",
	"INT-12/foreign_tween",
	"INT-12/restoration",
]


static func run(owner: Node3D, ids: Array[String] = IDS) -> void:
	for id: String in ids:
		if id == "INT-09/callback_positive":
			var observer: bool = await _positive(owner, false)
			var manifold: bool = await _positive(owner, true)
			owner._assert(id, observer and manifold, "Separate ordinary issued observer/manifold triples")
		else:
			await _case(owner, id)
	for id: String in ids:
		if not owner._seen.has(id) or owner._seen[id].size() != 1:
			owner._failures += 1


static func _trace(_point: Vector3) -> void:
	pass


static func _case(owner: Node3D, id: String) -> void:
	var lab: PitchBatLab = owner._lab()
	var installed: bool = R.install(lab)
	if not installed:
		owner._assert(id, false, "Fresh independent fixture could not install")
		lab.free()
		return
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var strict: bool = id in ["INT-05/material_script", "INT-05/mesh_script",
		"INT-08/item", "INT-08/site", "INT-08/host"]
	if strict:
		lab._pitch_actor.trace_sampled.connect(_trace)
	var fresh: bool = Proof.fresh(owner, lab)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 3, 10)
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	if not is_instance_valid(ball):
		owner._assert(id, false, "Ordinary launch must issue a real ball")
		lab.free()
		return
	ball.freeze = true
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var state: BallPlayState = resolver.state
	var accepted: bool = fresh and property.callback_intact() and not state.dead
	accepted = accepted and property._play_state == state and property._play_ball == ball
	accepted = accepted and (not property.hot_eligible() if strict else property.hot_eligible())
	if id.begins_with("INT-10/"):
		owner._assert(id, accepted and _input_refusal(id, lab, property),
			"Invalid input on pristine accepted owner leaves exact history and authority intact")
		lab.free()
		await owner.get_tree().process_frame
		return
	var mutation: Dictionary = _mutate(id, lab, property)
	# Check actual intended admission BEFORE adding an outcome observer selects strict fallback.
	var direct_refused: bool = not R.installed(lab) if id == "INT-09/ball_callback" \
		else not property.callback_intact()
	var silent: bool = _silent_routes(lab, property)
	var restore: Callable = mutation.restore
	restore.call()
	var restored_geometry: bool = (
		property.geometry_intact() if id == "INT-12/restoration" else true)
	var sticky: bool = not property.callback_intact() and property.phase == &"retired" \
		and lab.has_meta("stadium_npc_runtime_interrupted")
	owner._assert(id, accepted and mutation.strength and direct_refused
		and silent and sticky and restored_geometry,
		"Independent issued-play mutation; " + ("strict" if strict else "hot")
		+ " accepted precondition, exact refusal, silent routes and sticky restored lifetime")
	print("CURRENT_INT_DETAIL ", JSON.stringify({"id": id, "strict": strict,
		"accepted": accepted, "strength": mutation.strength, "direct_refused": direct_refused,
		"silent_routes": silent, "sticky": sticky}))
	lab.free()
	await owner.get_tree().process_frame


static func _silent_routes(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1) -> bool:
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var state: BallPlayState = resolver.state
	var before: PackedByteArray = Proof.resolver_state(resolver)
	var history: PackedByteArray = var_to_bytes([property.provenance, property.boundary.contacts])
	var outcomes: Array = []
	var hook: Callable = func(value: BallPlayOutcome) -> void: outcomes.append(value.result)
	resolver.play_resolved.connect(hook)
	var event: Dictionary = property.observe(resolver, Vector3(0, 0.6, 22), Vector3(0, 0.6, 25))
	var batch: Array[Dictionary] = [{"body": property.boundary.get_node("BACK-TERMINAL-01"),
		"position": Vector3(0, 0.6, 23.4)}]
	property._boundary_contact_batch(lab._batted_ball, batch, resolver)
	resolver.play_resolved.disconnect(hook)
	return event.is_empty() and outcomes.is_empty() and resolver.state == state \
		and Proof.resolver_state(resolver) == before \
		and var_to_bytes([property.provenance, property.boundary.contacts]) == history


static func _mutate(id: String, lab: PitchBatLab,
	property: StadiumNpcYardTwoPropertyV1) -> Dictionary:
	var chair: Node3D = property.objects[P + "RECEIVER-PRIMARY"]
	var cone: Node3D = property.objects[P + "O-R1"]
	var body: StaticBody3D = chair.get_node("Collision/ST079_BACK")
	var shape: CollisionShape3D = body.get_child(0)
	var mesh: MeshInstance3D = chair.get_node("Visual/ST079_BACK")
	if id in ["INT-01/chair_identity", "INT-02/cone_identity"]:
		var key: String = P + ("RECEIVER-PRIMARY" if id.begins_with("INT-01") else "O-R1")
		var original: Node3D = property.objects[key]
		var replacement: Node3D = original.duplicate()
		property.objects[key] = replacement
		return {"strength": replacement != original, "restore": func() -> void:
			property.objects[key] = original
			replacement.free()}
	if id in ["INT-03/appended_body", "INT-03/missing_body", "INT-03/reparented_body"]:
		var container: Node = body.get_parent()
		var index: int = body.get_index()
		if id.ends_with("appended_body"):
			var extra: Node = body.duplicate()
			container.add_child(extra)
			return {"strength": extra != body and extra.get_parent() == container,
				"restore": func() -> void: extra.free()}
		container.remove_child(body)
		if id.ends_with("reparented_body"):
			chair.add_child(body)
		return {"strength": body.get_parent() != container, "restore": func() -> void:
			if body.get_parent() != null:
				body.get_parent().remove_child(body)
			container.add_child(body)
			container.move_child(body, index)}
	if id == "INT-04/shape_resource":
		return _replace_value(shape, "shape", shape.shape.duplicate(true))
	if id in ["INT-04/shape_node", "INT-09/boundary_body"]:
		var original: Node = shape if id == "INT-04/shape_node" else property.boundary.get_node(
			"BACK-TERMINAL-01")
		var container: Node = original.get_parent()
		var index: int = original.get_index()
		var replacement: Node = original.duplicate()
		container.remove_child(original)
		container.add_child(replacement)
		container.move_child(replacement, index)
		return {"strength": replacement != original and original.get_parent() == null,
			"restore": func() -> void:
				replacement.free()
				container.add_child(original)
				container.move_child(original, index)}
	if id.begins_with("INT-05/"):
		var targets: Dictionary = {"model_script": [chair, "Node3D"],
			"shape_script": [shape.shape, "BoxShape3D"], "mesh_script": [mesh.mesh, "BoxMesh"],
			"material_script": [mesh.material_override, "StandardMaterial3D"],
			"field_script": [property.field, "FieldDefinition"]}
		var row: Array = targets[id.get_slice("/", 1)]
		return _script(row[0], row[1], id.ends_with("field_script"))
	if id == "INT-06/one_ulp_dimension":
		var box: BoxShape3D = shape.shape
		var size: Vector3 = box.size
		box.size.x = Proof.next_f32(box.size.x)
		return {"strength": box.size != size, "restore": func() -> void: box.size = size}
	if id.begins_with("INT-06/"):
		var targets: Dictionary = {"one_ulp_pose": body, "wrapper_pose": property,
			"construction_pose": property.construction, "model_pose": cone, "body_pose": body,
			"shape_pose": shape, "boundary_pose": property.boundary,
			"lab_pose": lab, "host_pose": property.get_parent()}
		var target: Node3D = targets[id.get_slice("/", 1)]
		var pose: Transform3D = target.transform
		if id.ends_with("one_ulp_pose"):
			target.position.y = Proof.next_f32(target.position.y)
		else:
			target.position.x += 0.125
		return {"strength": target.transform != pose,
			"restore": func() -> void: target.transform = pose}
	if id.begins_with("INT-07/"):
		var values: Dictionary = {"layer": [body, "collision_layer", 0],
			"mask": [body, "collision_mask", 3],
			"disable_mode": [body, "disable_mode", CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE],
			"process_mode": [body, "process_mode", Node.PROCESS_MODE_DISABLED],
			"disabled": [shape, "disabled", true]}
		var row: Array = values[id.get_slice("/", 1)]
		return _replace_value(row[0], row[1], row[2])
	if id.begins_with("INT-08/"):
		var keys: Dictionary = {"instance": "npc_instance", "alias": "owned_copy",
			"item": "stadium_item", "site": "npc_site", "host": "npc_host",
			"surface": "surface_id", "role": "surface_role"}
		var suffix: String = id.get_slice("/", 1)
		var target: Node = body if suffix in ["surface", "role"] else chair
		var key: String = keys[suffix]
		var original: Variant = target.get_meta(key)
		target.set_meta(key, "foreign")
		return {"strength": original != "foreign",
			"restore": func() -> void: target.set_meta(key, original)}
	if id == "INT-09/field_identity":
		return _replace_value(property, "field", property.field.duplicate(true))
	if id == "INT-09/support_identity":
		return _replace_value(property, "camera", StadiumNpcYardTwoCameraV1.new())
	if id == "INT-09/motion_identity":
		return _replace_value(property, "motion", StadiumNpcYardTwoCameraMotionV1.new())
	if id == "INT-09/visibility_identity":
		return _replace_value(property, "visibility", StadiumNpcYardTwoVisibilityV1.new())
	if id == "INT-09/ball_callback":
		return _replace_value(lab._batted_ball, "physics_contact_router", Callable())
	if id.begins_with("INT-12/"):
		var visual: Node3D = chair.get_node("Visual")
		var pose: Transform3D = visual.transform
		var tween: Tween = lab.create_tween()
		tween.pause()
		tween.tween_property(visual, "rotation:z", 0.02, 0.1)
		tween.custom_step(0.05)
		return {"strength": visual.transform != pose, "restore": func() -> void:
			tween.kill()
			visual.transform = pose}
	return {"strength": false, "restore": func() -> void: pass}


static func _replace_value(target: Object, key: String, value: Variant) -> Dictionary:
	var original: Variant = target.get(key)
	target.set(key, value)
	return {"strength": target.get(key) != original, "restore": func() -> void:
		target.set(key, original)}


static func _script(target: Object, base: String, preserve_fields: bool) -> Dictionary:
	var original: Script = target.get_script()
	var values: Dictionary = {}
	if preserve_fields:
		for item: Dictionary in target.get_property_list():
			if int(item.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and item.name != "script":
				values[item.name] = target.get(item.name)
	var script: GDScript = GDScript.new()
	script.source_code = "extends " + base + "\n"
	var compiled: bool = script.reload() == OK
	target.set_script(script)
	for key: String in values:
		target.set(key, values[key])
	return {"strength": compiled and target.get_script() == script,
		"restore": func() -> void:
			target.set_script(original)
			for key: String in values:
				target.set(key, values[key])}


static func _input_refusal(id: String, lab: PitchBatLab,
	property: StadiumNpcYardTwoPropertyV1) -> bool:
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var before: PackedByteArray = Proof.resolver_state(resolver)
	var histories: PackedByteArray = var_to_bytes([
		property.provenance, property.boundary.contacts, property.receiver.contacts])
	var refused: bool = false
	if id == "INT-10/foreign_collider":
		var body: Node = property.receiver.chair.get_node("Collision/ST079_BACK")
		var fake: Node = body.duplicate()
		refused = property.contact_identity(fake).is_empty() and property.receiver._owned_hit(
			{"collider_id": fake.get_instance_id(), "point": Vector3.ZERO}, 0.0).is_empty()
		fake.free()
	else:
		var path: Dictionary = property.receiver.trace(
			Vector3(0, 0.65, 0), Vector3(0, 0, -10), 0.0365)
		if not path.has("hit") or path.hit.is_empty():
			return false
		property.receiver.present_contact(path.hit.duplicate(true), "pitch")
		property.receiver._finish(lab._pitch_actor, path.duplicate(true))
		refused = not property.receiver.route(
			lab._pitch_actor, Vector3(0, 0.65, 0), Vector3(0, 0, -10))
	return refused and property.callback_intact() \
		and not lab.has_meta("stadium_npc_runtime_interrupted") \
		and Proof.resolver_state(resolver) == before and var_to_bytes([
			property.provenance, property.boundary.contacts, property.receiver.contacts]) == histories


static func _positive(owner: Node3D, manifold: bool) -> bool:
	var lab: PitchBatLab = owner._lab()
	var original: Dictionary = owner._snapshot(lab)
	if not R.install(lab):
		lab.free()
		return false
	var property: StadiumNpcYardTwoPropertyV1 = lab.get_meta("stadium_property")
	var fresh: bool = Proof.fresh(owner, lab)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 3, 10)
	lab._start_ball_in_play(launch)
	var ball: BattedBallBody = lab._batted_ball
	if not is_instance_valid(ball):
		lab.free()
		return false
	ball.freeze = true
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var state: BallPlayState = resolver.state
	var generation: int = property.play_generation
	var accepted: bool = fresh and property.callback_intact() and property._play_ball == ball \
		and property._play_state == state and not state.dead and state.stadium_contacts.is_empty()
	var outcomes: Array = []
	var hook: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	resolver.play_resolved.connect(hook)
	var count: int = property.boundary.contacts.size()
	var event: Dictionary = {}
	if manifold:
		var batch: Array[Dictionary] = [{"body": property.boundary.get_node("BACK-TERMINAL-01"),
			"position": Vector3(0, 0.6, 23.4)}]
		ball.physics_contact_router.call(ball, batch)
	else:
		event = property.observe(resolver, Vector3(0, 0.6, 22), Vector3(0, 0.6, 25))
	resolver.play_resolved.disconnect(hook)
	var result: bool = accepted and state.dead and outcomes == [[
		BallPlayOutcome.Result.TRIPLE, &"back_wall_on_fly"]] and state.stadium_contacts.size() == 1 \
		and resolver.state == state and property._play_state == state and property._play_ball == ball \
		and property.play_generation == generation and property.callback_intact()
	result = result and (property.boundary.contacts.size() == count + 1 \
		and property.boundary.contacts[-1].segment == "BACK-TERMINAL-01" if manifold \
		else not event.is_empty())
	lab._cleanup_batted_ball()
	lab._pitch_actor.reset_pitch()
	lab._at_bat_cadence.stop()
	result = R.teardown(lab) and original == owner._snapshot(lab) and result
	lab.free()
	await owner.get_tree().process_frame
	return result

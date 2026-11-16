extends RefCounted
## Reversible whole-lab capture lock; fail closed for renderer-clock motion we cannot pause.


static func lock(lab: PitchBatLab) -> Dictionary:
	var state: Dictionary = {
		"paused": lab.get_tree().paused,
		"nodes": [],
		"tweens": [],
		"ancestors": [],
		"physics_before": physics_proof(lab)
	}
	var ancestor: Node = lab.get_parent()
	while ancestor != null:
		state.ancestors.append({"node": ancestor, "mode": ancestor.process_mode})
		ancestor = ancestor.get_parent()
	for node: Node in _nodes(lab):
		state.nodes.append(
			{
				"node": node,
				"mode": node.process_mode,
				"disable": node.disable_mode if node is CollisionObject3D else -1,
				"flags": _flags(node)
			}
		)
		# DISABLED detaches default-REMOVE CollisionObject3D bodies. Never change
		# process_mode, disable_mode, or ancestor modes. Pause callbacks instead.
		_set_flags(node, [false, false, false, false, false, false, false, false])
	for tween: Tween in lab.get_tree().get_processed_tweens():
		state.tweens.append(
			{
				"tween": tween,
				"running": tween.is_running(),
				"elapsed": tween.get_total_elapsed_time()
			}
		)
		tween.pause()
	# Godot ed1daf0bf pauses server stepping, but PAUSED does not detach bodies.
	# Actual server membership and queries must prove this at every lock boundary.
	lab.get_tree().paused = true
	return state


static func intact(lab: PitchBatLab, state: Dictionary) -> bool:
	if (
		not state.physics_before
		or not lab.get_tree().paused
		or _nodes(lab).size() != state.nodes.size()
		or not _modes_intact(state)
	):
		return false
	for row: Dictionary in state.nodes:
		if _flags(row.node) != [false, false, false, false, false, false, false, false]:
			return false
	var current: Array[Tween] = lab.get_tree().get_processed_tweens()
	if current.size() != state.tweens.size():
		return false
	for row: Dictionary in state.tweens:
		if (
			not row.tween.is_valid()
			or not current.has(row.tween)
			or row.tween.is_running()
			or row.tween.get_total_elapsed_time() != row.elapsed
		):
			return false
	return physics_proof(lab)


static func unlock(lab: PitchBatLab, state: Dictionary) -> bool:
	var restored: bool = _modes_intact(state)
	for row: Dictionary in state.nodes:
		if not is_instance_valid(row.node):
			restored = false
			continue
		_set_flags(row.node, row.flags)
		restored = restored and _flags(row.node) == row.flags
	lab.get_tree().paused = state.paused
	for row: Dictionary in state.tweens:
		if not row.tween.is_valid():
			restored = false
			continue
		if row.running:
			row.tween.play()
		restored = (
			restored
			and row.tween.is_running() == row.running
			and row.tween.get_total_elapsed_time() == row.elapsed
		)
	# Covers nested unlock while still paused and immediate outer role unlock.
	return restored and lab.get_tree().paused == state.paused and physics_proof(lab)


static func _flags(node: Node) -> Array[bool]:
	return [
		node.is_processing(),
		node.is_physics_processing(),
		node.is_processing_internal(),
		node.is_physics_processing_internal(),
		node.is_processing_input(),
		node.is_processing_shortcut_input(),
		node.is_processing_unhandled_input(),
		node.is_processing_unhandled_key_input()
	]


static func _set_flags(node: Node, flags: Array) -> void:
	node.set_process(flags[0])
	node.set_physics_process(flags[1])
	node.set_process_internal(flags[2])
	node.set_physics_process_internal(flags[3])
	node.set_process_input(flags[4])
	node.set_process_shortcut_input(flags[5])
	node.set_process_unhandled_input(flags[6])
	node.set_process_unhandled_key_input(flags[7])


static func _modes_intact(state: Dictionary) -> bool:
	for row: Dictionary in state.ancestors:
		if not is_instance_valid(row.node) or row.node.process_mode != row.mode:
			return false
	for row: Dictionary in state.nodes:
		if not is_instance_valid(row.node) or row.node.process_mode != row.mode:
			return false
		if row.node is CollisionObject3D and row.node.disable_mode != row.disable:
			return false
	return true


static func physics_proof(lab: PitchBatLab) -> bool:
	var world: World3D = lab.get_world_3d()
	var bodies: int = 0
	for node: Node in _nodes(lab):
		if node is PhysicsBody3D:
			bodies += 1
			if (
				node.get_world_3d().space != world.space
				or PhysicsServer3D.body_get_space(node.get_rid()) != world.space
			):
				print(
					"RETAINED_DAYLIGHT_PHYSICS_DETACHED body=",
					node.get_path(),
					" paused=",
					lab.get_tree().paused,
					" mode=",
					node.process_mode,
					" disable_mode=",
					node.disable_mode
				)
				return false
	if bodies == 0:
		return false
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var boundary: Node3D = (
		property.boundary.source if property.venue_id == "AC-01" else property.boundary
	)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		Vector3(0, 1.3, 4), Vector3(0, 1.3, 40), 1 << 25
	)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not boundary.is_ancestor_of(hit.collider):
		print("RETAINED_DAYLIGHT_PHYSICS_RAY_FAILED paused=", lab.get_tree().paused)
		return false
	var sphere: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	sphere.shape = SphereShape3D.new()
	sphere.shape.radius = 0.10
	sphere.collision_mask = 1 << 25
	sphere.transform.origin = hit.position
	for overlap: Dictionary in world.direct_space_state.intersect_shape(sphere, 32):
		if overlap.collider == hit.collider:
			return true
	print(
		"RETAINED_DAYLIGHT_PHYSICS_SPHERE_FAILED body=",
		hit.collider.get_path(),
		" paused=",
		lab.get_tree().paused
	)
	return false


static func snapshot(lab: PitchBatLab, ball: BattedBallBody) -> Dictionary:
	var seen: Dictionary = {}
	var unsupported: Array[String] = []
	var rows: Array = []
	for node: Node in _nodes(lab):
		if (
			node is GPUParticles3D
			or node is CPUParticles3D
			or node is GPUParticles2D
			or node is CPUParticles2D
			or node is VideoStreamPlayer
		):
			unsupported.append(str(node.get_path()) + ": renderer-driven particle/video source")
		# Snapshot only rendering nodes; nonrendering controller state is protected by the lock.
		if node is Node3D or node is CanvasItem or node is CanvasLayer or node is WorldEnvironment:
			var fields: Array = _fields(node, seen, unsupported, ball)
			if node is Skeleton3D:
				for bone in range(node.get_bone_count()):
					fields.append(["bone", bone, node.get_bone_pose(bone)])
			rows.append([node.get_instance_id(), node.get_parent().get_instance_id(), fields])
	var viewport: Viewport = lab.get_viewport()
	if viewport.use_taa or viewport.scaling_3d_mode != Viewport.SCALING_3D_MODE_BILINEAR:
		unsupported.append("temporal/scaled renderer is outside paired-readback qualification")
	rows.append(
		[
			viewport.get_visible_rect(),
			viewport.msaa_3d,
			viewport.use_taa,
			viewport.scaling_3d_mode,
			viewport.scaling_3d_scale,
			viewport.screen_space_aa
		]
	)
	return {"bytes": var_to_bytes(rows), "unsupported": unsupported, "nodes": rows.size()}


static func _nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child: Node in root.get_children(true):
		result.append_array(_nodes(child))
	return result


static func _fields(
	object: Object, seen: Dictionary, unsupported: Array[String], ball: Node
) -> Array:
	var result: Array = []
	for row: Dictionary in object.get_property_list():
		var key: String = String(row.name)
		if int(row.usage) & PROPERTY_USAGE_STORAGE == 0 or key == "script":
			continue
		# The ball's visible flag is the sole allowed intervention between paired frames.
		if object == ball and key == "visible":
			continue
		result.append([key, _value(object.get(key), seen, unsupported, ball)])
	return result


static func _value(
	value: Variant, seen: Dictionary, unsupported: Array[String], ball: Node
) -> Variant:
	if value is Resource:
		var identity: int = value.get_instance_id()
		if seen.has(identity):
			return ["resource-reference", identity]
		seen[identity] = true
		if (
			value is Shader
			and (value.code.contains("TIME") or value.code.contains("SCREEN_TEXTURE"))
		):
			unsupported.append("unfrozen time/screen shader: " + str(value.resource_path))
		if value is AnimatedTexture or value is ViewportTexture:
			unsupported.append("dynamic texture: " + value.get_class())
		if value is CameraAttributes and value.auto_exposure_enabled:
			unsupported.append("automatic camera exposure")
		if value is Script:
			return ["script-reference", identity]
		return ["resource", identity, value.get_class(), _fields(value, seen, unsupported, ball)]
	if value is Object:
		return ["object-reference", value.get_instance_id() if is_instance_valid(value) else 0]
	if value is Array:
		var values: Array = []
		for entry: Variant in value:
			values.append(_value(entry, seen, unsupported, ball))
		return values
	if value is Dictionary:
		var values: Array = []
		for key: Variant in value:
			values.append(
				[_value(key, seen, unsupported, ball), _value(value[key], seen, unsupported, ball)]
			)
		return values
	return value

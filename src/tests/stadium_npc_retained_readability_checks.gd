extends Node3D
## Independent projected-size and byte-exact physical noninterference controls.

# Float32 screen-coordinate rounding only; all physical/Transform3D checks remain byte-exact.
const PIXEL_PROJECTION_EPSILON: float = 0.0002

var failures: int = 0


func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.near = 0.05
	camera.far = 1000
	viewport.add_child(camera)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	viewport.add_child(ball)
	var visual: MeshInstance3D = ball.get_child(1)
	var original: Transform3D = visual.transform
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	resolver.state.elapsed_seconds = 1.234567890123
	resolver.state.defender_touched = true
	resolver.state.first_ground_position = Vector3(1.2, 0.3, 4.5)
	var captured_state: Dictionary = _stored(resolver.state)
	_check(captured_state.get("defender_touched") == true
		and captured_state.get("first_ground_position") == Vector3(1.2, 0.3, 4.5),
		"physical snapshot explicitly includes non-exported resolver script state")
	var unchanged: PackedByteArray = physical(ball, resolver)
	resolver.state.defender_touched = false
	_check(physical(ball, resolver) != unchanged,
		"strict invariant detects a changed resolver flag")
	resolver.state.defender_touched = true
	var collider: CollisionShape3D = ball.get_child(0)
	var radius: float = collider.shape.radius
	collider.shape.radius = radius + 0.000001
	_check(physical(ball, resolver) != unchanged,
		"strict invariant detects shape resource bytes even with identical resource identity")
	collider.shape.radius = radius
	_check(physical(ball, resolver) == unchanged, "control mutations restore exact physical bytes")
	ball.linear_velocity = Vector3(12.25, -3.75, 17.125)
	ball.angular_velocity = Vector3(1.5, 2.75, -3.25)
	var helper: StadiumNpcRetainedBallReadability = StadiumNpcRetainedBallReadability.new()
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE,
		Camera3D.PROJECTION_ORTHOGONAL, Camera3D.PROJECTION_FRUSTUM]:
		camera.projection = projection
		camera.size = 100 if projection == Camera3D.PROJECTION_ORTHOGONAL else 0.6
		for aspect: int in [Camera3D.KEEP_HEIGHT, Camera3D.KEEP_WIDTH]:
			camera.keep_aspect = aspect
			for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(700, 393), Vector2i(393, 700)]:
				viewport.size = dimensions
				await get_tree().process_frame
				_check(viewport.get_texture().get_size() == Vector2(dimensions),
					"pixel measurement uses requested actual native render-target dimensions")
				var prior_radius: float = 0
				for distance: float in [2, 20, 100, 300]:
					ball.position = Vector3(0, 0, -distance)
					var before: PackedByteArray = physical(ball, resolver)
					var baseline: float = _diameter(camera, visual)
					helper.update(ball, camera, true)
					var measured: float = _diameter(camera, visual)
					_audit_projection(helper, camera, visual, baseline, distance, dimensions)
					if baseline >= 3.0:
						_check(var_to_bytes(visual.transform) == var_to_bytes(original),
							"already-readable sphere keeps exact original local transform")
					_check(measured >= 3.0 - PIXEL_PROJECTION_EPSILON,
						"actual projected original sphere meets 3 native pixels: " + str(dimensions))
					_check(helper.effective_radius() >= prior_radius,
						"distance never decreases required visual radius at fixed projection")
					prior_radius = helper.effective_radius()
					_check(physical(ball, resolver) == before,
						"pixel floor leaves all physical/resolver bytes exactly unchanged")
					var shown: Transform3D = visual.transform
					var details: Dictionary = helper.diagnostics()
					helper.update(ball, camera, true)
					_check(helper.diagnostics() == details,
						"repeated update preserves exact measured diagnostics without oscillation")
					_check(var_to_bytes(shown) == var_to_bytes(visual.transform),
						"repeated readability update never compounds scale")
					helper.restore_all()
					_check(var_to_bytes(visual.transform) == var_to_bytes(original),
						"explicit restoration preserves exact original local Transform3D")
					_check(physical(ball, resolver) == before, "restoration preserves physical bytes")
			# Lower native resolution must require at least as much world-space visual radius.
			ball.position = Vector3(0, 0, -100)
			viewport.size = Vector2i(1280, 720)
			await get_tree().process_frame
			helper.update(ball, camera, true)
			var large_radius: float = helper.effective_radius()
			viewport.size = Vector2i(700, 393)
			await get_tree().process_frame
			helper.update(ball, camera, true)
			_check(helper.effective_radius() >= large_radius,
				"smaller native resolution cannot reduce the readability floor")
			helper.restore_all()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	ball.position = Vector3(0, 0, -300)
	helper.update(ball, camera, true)
	_check(visual.transform != original, "distant positive control genuinely requires helper scaling")
	helper.update(ball, camera, false)
	_check(var_to_bytes(visual.transform) == var_to_bytes(original),
		"non-live update restores exactly")
	for point: Vector3 in [Vector3(0, 0, 1), Vector3(0, 0, -0.06), Vector3(0, 0, -1001)]:
		ball.position = Vector3(0, 0, -300)
		helper.update(ball, camera, true)
		ball.position = point
		var before: PackedByteArray = physical(ball, resolver)
		helper.update(ball, camera, true)
		_check(var_to_bytes(visual.transform) == var_to_bytes(original)
			and physical(ball, resolver) == before,
			"behind/near/far guard restores original visual and preserves physics")
	ball.position = Vector3(0, 0, -300)
	helper.update(ball, camera, true)
	helper.update(ball, null, true)
	_check(var_to_bytes(visual.transform) == var_to_bytes(original), "missing camera restores exactly")
	# Reparenting a still-live visual must release it and select only an actual direct child.
	helper.update(ball, camera, true)
	var foreign: Node3D = Node3D.new()
	viewport.add_child(foreign)
	ball.remove_child(visual)
	foreign.add_child(visual)
	var current: MeshInstance3D = MeshInstance3D.new()
	current.mesh = SphereMesh.new()
	current.mesh.radius = 0.075
	current.mesh.height = 0.15
	current.material_override = visual.material_override
	ball.add_child(current)
	var current_original: Transform3D = current.transform
	var physical_before: PackedByteArray = physical(ball, resolver)
	helper.update(ball, camera, true)
	_check(var_to_bytes(visual.transform) == var_to_bytes(original)
		and current.transform != current_original,
		"old reparented sphere restores exactly while genuine new direct sphere gets its floor")
	_check(physical(ball, resolver) == physical_before,
		"visual replacement never changes collision resource or physical state")
	var new_source: SphereMesh = SphereMesh.new()
	new_source.radius = 0.03
	new_source.height = 0.06
	current.mesh = new_source
	helper.update(ball, camera, true)
	_check(absf(helper.diagnostics().base_radius - 0.03) < 0.00000001
		and _diameter(camera, current) >= 3.0 - PIXEL_PROJECTION_EPSILON,
		"same visual with replaced sphere Mesh uses fresh source size without compounded scaling")
	_check(_diameter(camera, current) >= 3.0,
		"replaced source sphere also meets the strict measured runtime floor")
	_check(helper.diagnostics().effective_diameter_px == _diameter(camera, current),
		"replacement-source diagnostics report actual postscale projection, not an estimate")
	helper.restore_all()
	_check(var_to_bytes(current.transform) == var_to_bytes(current_original),
		"source replacement still restores the exact pre-helper local transform")
	helper.update(ball, camera, true)
	ball.remove_child(current)
	foreign.add_child(current)
	helper.update(ball, camera, true)
	_check(var_to_bytes(current.transform) == var_to_bytes(current_original)
		and helper.diagnostics().reason == "no-original-sphere",
		"absent direct sphere restores old visual without scaling unrelated descendants")
	foreign.remove_child(visual)
	ball.add_child(visual)
	helper.update(ball, camera, true)
	_check(visual.transform != original, "missing-sphere update does not prevent later reacquisition")
	helper.restore_all()
	foreign.free()
	var next: BattedBallBody = BattedBallBody.new()
	next.freeze = true
	viewport.add_child(next)
	next.position = Vector3(0, 0, -300)
	helper.update(ball, camera, true)
	helper.update(next, camera, true)
	_check(var_to_bytes(visual.transform) == var_to_bytes(original),
		"ball replacement restores old mesh")
	helper.restore_all()
	viewport.free()


func _audit_projection(helper: StadiumNpcRetainedBallReadability, camera: Camera3D,
	visual: MeshInstance3D, baseline: float, distance: float, requested: Vector2i) -> void:
	var details: Dictionary = helper.diagnostics()
	var measured: float = _diameter(camera, visual)
	var native: Vector2 = Vector2(camera.get_viewport().get_texture().get_size())
	var logical: Vector2 = camera.get_viewport().get_visible_rect().size
	print("NPC_RETAINED_READABILITY_CASE ", JSON.stringify({
		"projection": camera.projection, "keep_aspect": camera.keep_aspect,
		"requested_size": [requested.x, requested.y], "native_size": [native.x, native.y],
		"logical_size": [logical.x, logical.y], "distance": distance,
		"fov": camera.fov, "near": camera.near, "far": camera.far,
		"camera_size": camera.size, "independent_baseline_px": baseline,
		"independent_measured_px": measured, "helper_diagnostics": details,
		"visual_transform_bytes": var_to_bytes(visual.transform).hex_encode()}, "", true, true))
	_check(measured >= 3.0, "actual applied sphere meets strict measured runtime pixel floor")
	_check(details.effective_diameter_px == measured,
		"diagnostic effective pixel diameter equals independent actual postscale measurement")
	_check(details.base_diameter_px == baseline,
		"diagnostic baseline pixel diameter equals unchanged original visual measurement")
	var attempts: int = int(details.get("attempt_count", -1))
	_check(attempts == 0 if baseline >= 3.0 else attempts >= 1 and attempts <= 2,
		"readable baseline needs zero attempts; expansion has at most one bounded correction")
	if baseline >= 3.0:
		_check(details.scale == 1.0 and details.reason == "base",
			"already-readable baseline retains original size without numerical-reserve expansion")
	_check(float(details.target_reserve_px) > 0 and float(details.target_reserve_px) < 0.001
		and float(details.target_diameter_px) == 3.0 + float(details.target_reserve_px),
		"numerical pixel reserve remains explicit and below one thousandth of a native pixel")
	_check(details.last_attempt_diameter_px == measured,
		"successful bounded attempt records the actual final measured projection")
	_check(is_finite(float(details.scale)) and float(details.scale) >= 1.0
		and float(details.scale) <= maxf(1.0, 3.01 / baseline) * 1.001,
		"readability correction stays within a tiny numerical allowance without runaway scaling")


func _diameter(camera: Camera3D, visual: MeshInstance3D) -> float:
	var sphere: SphereMesh = visual.mesh
	var axes: Vector3 = Vector3(visual.global_basis.x.length(),
		visual.global_basis.y.length(), visual.global_basis.z.length())
	var radius: float = minf(sphere.radius, sphere.height / 2) * minf(axes.x, minf(axes.y, axes.z))
	var center: Vector3 = visual.global_position
	var native: Vector2 = Vector2(camera.get_viewport().get_texture().get_size())
	var ratio: Vector2 = native / camera.get_viewport().get_visible_rect().size
	var right: Vector3 = camera.global_basis.x.normalized() * radius
	var up: Vector3 = camera.global_basis.y.normalized() * radius
	return minf(((camera.unproject_position(center + right)
		- camera.unproject_position(center - right)) * ratio).length(),
		((camera.unproject_position(center + up)
		- camera.unproject_position(center - up)) * ratio).length())


static func physical(ball: BattedBallBody, resolver: BallPlayResolver) -> PackedByteArray:
	var collision: CollisionShape3D = ball.get_child(0)
	return var_to_bytes({"shape_id": collision.shape.get_instance_id(),
		"shape": _stored(collision.shape), "shape_transform": collision.transform,
		"shape_disabled": collision.disabled, "radius": ball.radius_m,
		"body_transform": ball.transform, "linear": ball.linear_velocity,
		"angular": ball.angular_velocity, "mass": ball.mass,
		"ball_mass": ball.ball_mass_kg, "freeze": ball.freeze, "sleeping": ball.sleeping,
		"started": ball._started, "layer": ball.collision_layer, "mask": ball.collision_mask,
		"gravity": ball.gravity_scale, "drag": ball.aero_drag_coefficient,
		"magnus": ball.aero_magnus_scale, "perforation": ball.aero_perforation_force_scale,
		"hole_axis": ball.hole_axis_ball_local, "router": ball.physics_contact_router,
		"physics_material_id": ball.physics_material_override.get_instance_id(),
		"physics_material": _stored(ball.physics_material_override),
		"resolver_state_id": resolver.state.get_instance_id(), "resolver": _stored(resolver.state)})


static func _stored(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for row: Dictionary in object.get_property_list():
		if row.usage & (PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE) \
			and row.name != "script":
			var value: Variant = object.get(row.name)
			if not value is Object:
				result[row.name] = value
	return result


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

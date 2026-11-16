extends RefCounted
## Independent physical traversal and presentation snapshots for retained daylight evidence.

const MASK: int = 1 << 25


static func receiver_model(property: StadiumNpcRetainedProperty, body: Node) -> Node3D:
	if property.receiver == null:
		return null
	for model: Node3D in [property.receiver.chair, property.receiver.net]:
		if model == body or model.is_ancestor_of(body):
			return model
	return null


static func verified_receiver(
	property: StadiumNpcRetainedProperty, body: Node, state: String
) -> bool:
	var model: Node3D = receiver_model(property, body)
	if model == null or model.get_meta("receiver_render_state", "") != state:
		return false
	var visual: Node3D = model.get_node("Visual")
	if visual.visible != (state != "hidden") or (body as StaticBody3D).collision_layer & 1 == 0:
		return false
	var count: int = 0
	for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
		count += 1
		var material: StandardMaterial3D = mesh.material_override
		var faded: bool = state == "faded"
		if not mesh.visible or material == null:
			return false
		if not is_equal_approx(
			material.albedo_color.a, StadiumReceiverVisibility.FADED_ALPHA if faded else 1.0
		):
			return false
		if (
			material.transparency
			!= (
				BaseMaterial3D.TRANSPARENCY_ALPHA if faded else BaseMaterial3D.TRANSPARENCY_DISABLED
			)
		):
			return false
		if (
			mesh.cast_shadow
			!= (
				GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				if state == "visible"
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			)
		):
			return false
	return count > 0


static func trace(
	property: StadiumNpcRetainedProperty, from: Vector3, to: Vector3, state: String = "faded"
) -> Dictionary:
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, MASK)
	var ignored: Array[RID] = []
	var foreground: Array[String] = []
	var maximum: int = property.find_children("*", "StaticBody3D", true, false).size()
	for index in range(maximum + 1):
		query.exclude = ignored
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return {"clear": true, "foreground": foreground, "opaque": ""}
		var label: String = String(property.get_path_to(hit.collider))
		if not verified_receiver(property, hit.collider, state) or ignored.has(hit.rid):
			return {
				"clear": false,
				"foreground": foreground,
				"opaque": label,
				"boundary":
				(
					(
						property.boundary.source
						if property.venue_id == "AC-01"
						else property.boundary
					)
					. is_ancestor_of(hit.collider)
				)
			}
		foreground.append(label)
		ignored.append(hit.rid)
	return {"clear": false, "foreground": foreground, "opaque": "traversal-exhausted"}


static func presentation(lab: PitchBatLab) -> Array:
	var result: Array = []
	var roots: Array[Node3D] = [
		lab._batter_avatar, lab._pitcher_avatar, lab._bat_actor, lab._primary_fielder._avatar
	]
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	if property.receiver != null:
		roots.append_array([property.receiver.chair, property.receiver.net])
	for root: Node3D in roots:
		result.append([root.get_instance_id(), root.global_transform, root.visible])
		for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			var material: StandardMaterial3D = mesh.material_override
			result.append(
				[
					mesh.get_instance_id(),
					mesh.global_transform,
					mesh.visible,
					mesh.is_visible_in_tree(),
					mesh.transparency,
					mesh.cast_shadow,
					material.get_instance_id() if material != null else 0,
					material.albedo_color if material != null else Color(),
					material.transparency if material != null else -1
				]
			)
	return result


static func colliders(property: StadiumNpcRetainedProperty) -> Array:
	var result: Array = []
	for body: StaticBody3D in property.find_children("*", "StaticBody3D", true, false):
		result.append(
			[
				body.get_instance_id(),
				body.global_transform,
				body.collision_layer,
				body.collision_mask
			]
		)
		for shape: CollisionShape3D in body.find_children("*", "CollisionShape3D", true, false):
			result.append(
				[
					shape.get_instance_id(),
					shape.global_transform,
					shape.disabled,
					shape.shape.get_instance_id()
				]
			)
	return result


static func tracking_stop(
	property: StadiumNpcRetainedProperty, start: Vector3, requested: Vector3
) -> Dictionary:
	# AC uses its installed swept-contact/graph event ordering verbatim.
	if property.venue_id == "AC-01":
		return StadiumNpcRetainedClubSweep.event(property.boundary, start, requested)
	var crossing: Dictionary = (
		StadiumNpcYardGraphV1.crossing(start, requested)
		if property.venue_id == "AY-01"
		else property.boundary.graph.crossing(start, requested)
	)
	# AY/AE stop at the first real boundary-body sphere contact, or graph crossing
	# above an open wall. Never drive the inspection ball beyond that event.
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = SphereShape3D.new()
	query.shape.radius = 0.0365
	query.shape.margin = 0
	query.margin = 0
	query.collision_mask = MASK
	query.transform.origin = start
	var excluded: Array[RID] = []
	for body: StaticBody3D in property.find_children("*", "StaticBody3D", true, false):
		if not property.boundary.is_ancestor_of(body):
			excluded.append(body.get_rid())
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = property.get_world_3d().direct_space_state
	var fraction: float = 0
	if space.intersect_shape(query, 1).is_empty():
		query.motion = requested - start
		var motion: PackedFloat32Array = space.cast_motion(query)
		if motion.size() != 2 or motion[0] >= 1:
			return crossing
		fraction = motion[1]
	if not crossing.is_empty() and crossing.fraction < fraction:
		return crossing
	return {
		"position": start.lerp(requested, fraction),
		"fraction": fraction,
		"kind": "actual-boundary-sphere-contact"
	}


static func ball_visual(ball: BattedBallBody) -> MeshInstance3D:
	for node: Node in ball.get_children():
		if node is MeshInstance3D and node.mesh is SphereMesh:
			return node
	return null


static func mechanics(lab: PitchBatLab) -> Dictionary:
	var ball: BattedBallBody = lab._batted_ball
	if ball == null:
		return {}
	var shapes: Array = []
	for shape: CollisionShape3D in ball.find_children("*", "CollisionShape3D", true, false):
		shapes.append(
			[
				shape.get_instance_id(),
				shape.transform,
				shape.disabled,
				shape.shape.get_instance_id(),
				shape.shape.radius if shape.shape is SphereShape3D else -1,
				shape.shape.margin
			]
		)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var state_values: Array = []
	if resolver.state != null:
		for row: Dictionary in resolver.state.get_property_list():
			if int(row.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0 and row.name != "script":
				state_values.append([row.name, resolver.state.get(row.name)])
	return {
		"body": ball.get_instance_id(),
		"transform": ball.transform,
		"global_transform": ball.global_transform,
		"linear_velocity": ball.linear_velocity,
		"angular_velocity": ball.angular_velocity,
		"mass": ball.mass,
		"radius": ball.radius_m,
		"freeze": ball.freeze,
		"freeze_mode": ball.freeze_mode,
		"sleeping": ball.sleeping,
		"started": ball._started,
		"layer": ball.collision_layer,
		"mask": ball.collision_mask,
		"space": PhysicsServer3D.body_get_space(ball.get_rid()),
		"shapes": shapes,
		"aero":
		[
			ball.aero_drag_coefficient,
			ball.aero_magnus_scale,
			ball.aero_perforation_force_scale,
			ball.ball_mass_kg,
			ball.hole_axis_ball_local
		],
		"resolver": resolver.get_instance_id(),
		"state": resolver.state.get_instance_id() if resolver.state != null else 0,
		"field": resolver.field.get_instance_id() if resolver.field != null else 0,
		"state_values": var_to_bytes(state_values)
	}


static func native_pixel_proof(lab: PitchBatLab, image_extent: Vector2i) -> Dictionary:
	# Independent readback units: never trust WindowTexture.get_size or call the
	# runtime helper's projection/extent methods to validate their own answer.
	var property: StadiumNpcRetainedProperty = lab.get_meta("stadium_property")
	var details: Dictionary = property.ball_readability.diagnostics()
	var visual: MeshInstance3D = ball_visual(lab._batted_ball)
	var sphere: SphereMesh = visual.mesh
	var world: Transform3D = visual.global_transform
	var inner_radius: float = (
		minf(sphere.radius, sphere.height * 0.5)
		* minf(world.basis.x.length(), minf(world.basis.y.length(), world.basis.z.length()))
	)
	var camera: Camera3D = lab._camera
	var logical: Vector2 = camera.get_viewport().get_visible_rect().size
	var pixels_per_unit: Vector2 = Vector2(image_extent) / logical
	var right: Vector3 = camera.global_basis.x.normalized() * inner_radius
	var up: Vector3 = camera.global_basis.y.normalized() * inner_radius
	var horizontal: Vector2 = (
		(
			camera.unproject_position(world.origin + right)
			- camera.unproject_position(world.origin - right)
		)
		* pixels_per_unit
	)
	var vertical: Vector2 = (
		(
			camera.unproject_position(world.origin + up)
			- camera.unproject_position(world.origin - up)
		)
		* pixels_per_unit
	)
	var measured: float = minf(horizontal.length(), vertical.length())
	return {
		"actual_image_extent": image_extent,
		"actual_logical_extent": logical,
		"texture_reported_extent": camera.get_viewport().get_texture().get_size(),
		"helper_native_extent": details.get("native_size", Vector2.ZERO),
		"helper_extent_matches_image":
		details.get("native_size", Vector2.ZERO) == Vector2(image_extent),
		"helper_logical_matches_viewport": details.get("logical_size", Vector2.ZERO) == logical,
		"measured_equatorial_diameter_px": measured,
		"measured_axes_px": Vector2(horizontal.length(), vertical.length()),
		"helper_diameter_px": details.get("effective_diameter_px", -1.0),
		"helper_diameter_matches_measured": details.get("effective_diameter_px", -1.0) == measured,
		"actual_three_pixel_floor": is_finite(measured) and measured >= 3.0,
		"effective_inner_radius": inner_radius,
		"fov": camera.fov,
		"near": camera.near,
		"far": camera.far
	}

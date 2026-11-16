extends RefCounted
## Stateless operations for the original StadiumPropertyGeometry owner.


static func _source_private_capture_prop(_source_owner: StadiumPropertyGeometry, model: Node3D, \
	placement: Dictionary) -> void:
	if placement.item == "ST-046" and placement.site == StadiumWaterfallLiveSites.SITE:
		_source_owner._waterfall_traps[placement.copy] = (
			StadiumWaterfallAnimatedModels.capture_trap(model, _source_owner._retire_props)
			if _source_owner._waterfall_animation_copies.has(placement.copy)
			else StadiumWaterfallLiveRuntime.capture_trap(model, _source_owner._retire_props)
		)
	if placement.item == "ST-005":
		_source_owner._junk_car_traps[placement.copy] = StadiumJunkCarRuntime.capture_trap(model, \
			_source_owner._retire_props)
	if placement.item == "ST-007" and placement.role != "DECORATIVE_AFTER_TERMINAL":
		_source_owner._furnishing_water[placement.copy] = StadiumLiveFurnishingRuntime.capture_water(
			model, _source_owner._retire_props
		)
	var collision: Node3D = model.get_node_or_null("Collision")
	var row: Dictionary = {
		"node": model,
		"pose": model.transform,
		"item": placement.item,
		"site": placement.site,
		"collision": collision,
		"bodies": [],
		"supports": {}
	}
	if placement.item == "ST-047":
		row["fixed_count"] = collision.get_child_count()
	for key: String in [
		"recipe",
		"lower_copy",
		"concourse_copy",
		"upper_copy",
		"bowl_copy",
		"curved_copy",
		"base_copy",
		"straight_copy",
		"host_copy",
		"support_copy",
		"socket",
		"roof_state",
		"terrace_host_item",
		"terrace_host_copies",
		"dugout_copy",
		"player_tunnel_copy",
		"player_tunnel_adapter_version",
		"player_tunnel_host_profile",
		"player_tunnel_host_port"
	]:
		if model.has_meta(key):
			row.supports[key] = (
				model.get_meta(key).duplicate()
				if key == "terrace_host_copies"
				else model.get_meta(key)
			)
	for body: StaticBody3D in _source_owner._prop_bodies(model):
		var shapes: Array = []
		for child: Node in body.get_children():
			if child is CollisionShape3D:
				shapes.append(
					{
						"node": child,
						"pose": child.transform,
						"shape": child.shape,
						"margin": child.shape.margin
					}
				)
				if not child.shape.changed.is_connected(_source_owner._retire_props):
					child.shape.changed.connect(_source_owner._retire_props)
		var captured: Dictionary = {
			"node": body,
			"pose": body.transform,
			"shapes": shapes,
			"copy": placement.copy,
			"item": body.get_meta("stadium_item", ""),
			"surface": body.get_meta("surface_id", ""),
			"role": body.get_meta("surface_role", ""),
			"ball_surface": body.get_meta("ball_surface", &""),
			"layer": body.collision_layer,
			"mask": body.collision_mask,
			"material": body.physics_material_override,
			"children": body.get_child_count()
		}
		if placement.item == "ST-047":
			captured["parent"] = body.get_parent()
		row.bodies.append(captured)
		_source_owner._issued_contacts[body] = captured
	_source_owner._issued_props[placement.copy] = row


static func _source_private_retire_props(_source_owner: StadiumPropertyGeometry) -> void:
	_source_owner._props_live = false


static func _source_public_props_intact(_source_owner: StadiumPropertyGeometry) -> bool:
	if (
		(_source_owner._waterfall_animation != null and not \
			_source_owner._waterfall_animation.presentation_intact())
		or (not _source_owner._waterfall_animation_copies.is_empty() and \
			_source_owner._waterfall_animation == null)
	):
		return false
	if not _source_owner._infrastructure_intact():
		return false
	if not _source_owner._ground_props_family:
		return true
	return _source_owner._props_context_intact()


static func _source_private_props_context_intact(_source_owner: StadiumPropertyGeometry) -> bool:
	if _source_owner._props_lab != null:
		var lab: PitchBatLab = _source_owner._props_lab.get_ref()
		if (
			not is_instance_valid(lab)
			or lab._match_state != _source_owner._props_state
			or lab._stadium_ledger != _source_owner._props_paid
			or _source_owner._props_paid == null
			or _source_owner._props_paid.mutation_generation() != _source_owner._props_generation
			or (lab.has_meta("stadium_property") and lab.get_meta("stadium_property") != _source_owner)
		):
			return false
		if _source_owner.has_live_waterfall() and lab.has_meta("stadium_property"):
			if (
				lab._primary_fielder.stadium_waterfall_step != _source_owner.waterfall_step
				or lab._primary_fielder.stadium_waterfall_clip != _source_owner.waterfall_clip
				or not is_finite(lab._primary_fielder.reach_m)
				or lab._primary_fielder.reach_m > StadiumWaterfallLiveModels.MAX_DEFENDER_REACH
			):
				return false
			var live_boundary: StadiumBoundaryOwnedRuntime = (
				_source_owner.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
			)
			if (
				live_boundary != null
				and (
					not StadiumWaterfallLiveRoutes.legal(
						lab._primary_fielder.global_position, live_boundary.graph
					)
					or not StadiumWaterfallLiveRoutes.legal(
						lab._pitcher_marker.global_position, live_boundary.graph
					)
				)
			):
				return false
	if not _source_owner._props_live:
		return false
	var ordinary_count: int = _source_owner.objects.size()
	var boundary: StadiumBoundaryOwnedRuntime = (
		_source_owner.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	for copy: String in _source_owner.objects:
		if not _source_owner._issued_props.has(copy):
			if boundary == null or not boundary.owns_model(copy, _source_owner.objects[copy]):
				return false
			ordinary_count -= 1
	return _source_owner._props_inventory_intact(ordinary_count, boundary)


static func _source_private_props_inventory_intact(_source_owner: StadiumPropertyGeometry,
	ordinary_count: int,
	boundary: StadiumBoundaryOwnedRuntime
) -> bool:
	if ordinary_count != _source_owner._issued_props.size() or (boundary != null and not \
		boundary.intact()):
		return false
	return _source_owner._issued_props_intact()


static func _source_private_issued_props_intact(_source_owner: StadiumPropertyGeometry) -> bool:
	for copy: String in _source_owner._issued_props:
		if not _source_owner._issued_prop_intact(copy):
			return false
	return true


static func _source_private_issued_prop_intact(_source_owner: StadiumPropertyGeometry, copy: \
	String) -> bool:
	var row: Dictionary = _source_owner._issued_props[copy]
	if (
		not is_instance_valid(row.node)
		or _source_owner.objects.get(copy) != row.node
		or row.node.get_parent() != _source_owner
		or row.node.is_queued_for_deletion()
		or row.node.transform != row.pose
		or row.node.get_meta("owned_copy", "") != copy
		or row.node.get_meta("stadium_item", "") != row.item
		or row.node.get_meta("site", "") != row.site
	):
		return false
	if row.item == "ST-112":
		return true  # Complete resource/node seal checked above; no collision subtree.
	if row.item == "ST-046" and row.site == StadiumWaterfallLiveSites.SITE:
		if not StadiumWaterfallLiveRuntime.trap_intact(
			row.node, _source_owner._waterfall_traps.get(copy, {})
		):
			return false
	elif row.item == "ST-046":
		if (
			not (_source_owner._waterfall_animation != null and \
				_source_owner._waterfall_animation_copies.has(copy))
			and not StadiumWaterfallModels.valid(row.node)
		):
			return false
		return true  # Frozen collider-free model; all meshes additionally carry the infrastructure seal.
	return _source_owner._issued_prop_collision_intact(copy, row)


static func _source_private_issued_prop_collision_intact(_source_owner: StadiumPropertyGeometry, \
	copy: String, row: Dictionary) -> bool:
	if (
		not is_instance_valid(row.collision)
		or row.node.get_node_or_null("Collision") != row.collision
		or row.collision.transform != Transform3D.IDENTITY
		or (
			row.collision.get_child_count()
			!= (row.fixed_count if row.item == "ST-047" else row.bodies.size())
		)
	):
		return false
	if (
		row.item == "ST-005"
		and not StadiumJunkCarRuntime.trap_intact(row.node, _source_owner._junk_car_traps.get(copy, {}))
	):
		return false
	if (
		row.item == "ST-007"
		and not row.bodies.is_empty()
		and not StadiumLiveFurnishingRuntime.water_intact(
			row.node, _source_owner._furnishing_water.get(copy, {})
		)
	):
		return false
	for key: String in row.supports:
		if not row.node.has_meta(key) or row.node.get_meta(key) != row.supports[key]:
			return false
	if not _source_owner._issued_prop_bodies_intact(copy, row):
		return false
	return true


static func _source_private_issued_prop_bodies_intact(_source_owner: StadiumPropertyGeometry, \
	copy: String, row: Dictionary) -> bool:
	for captured: Dictionary in row.bodies:
		var body: StaticBody3D = captured.node
		if (
			not is_instance_valid(body)
			or body.is_queued_for_deletion()
			or body.get_parent() != (captured.parent if row.item == "ST-047" else row.collision)
			or body.transform != captured.pose
			or body.collision_layer != captured.layer
			or body.collision_mask != captured.mask
			or body.physics_material_override != captured.material
			or body.constant_linear_velocity != Vector3.ZERO
			or body.constant_angular_velocity != Vector3.ZERO
			or body.get_child_count() != captured.children
			or body.get_meta("owned_copy", "") != copy
			or body.get_meta("stadium_item", "") != captured.item
			or body.get_meta("surface_id", "") != captured.surface
			or body.get_meta("surface_role", "") != captured.role
			or body.get_meta("ball_surface", &"") != captured.ball_surface
		):
			return false
		for shape: Dictionary in captured.shapes:
			if (
				not is_instance_valid(shape.node)
				or shape.node.get_parent() != body
				or shape.node.is_queued_for_deletion()
				or shape.node.transform != shape.pose
				or shape.node.disabled
				or shape.node.shape != shape.shape
				or shape.shape.margin != shape.margin
				or not shape.shape.changed.is_connected(_source_owner._retire_props)
			):
				return false
	return true


static func _source_public_bind_props_context(_source_owner: StadiumPropertyGeometry, lab: \
	PitchBatLab) -> bool:
	if not _source_owner._ground_props_family:
		return true
	if (
		_source_owner._props_lab != null
		or not is_instance_valid(lab)
		or lab._match_state == null
		or lab._stadium_ledger == null
		or not StadiumLayoutSnapshot.matches(lab._match_state.stadium, lab._stadium_ledger)
	):
		return false
	_source_owner._props_lab = weakref(lab)
	_source_owner._props_state = lab._match_state
	_source_owner._props_paid = lab._stadium_ledger
	_source_owner._props_generation = _source_owner._props_paid.mutation_generation()
	return _source_owner.props_intact()


static func _source_public_attach_lighting_preview(_source_owner: StadiumPropertyGeometry,
	lease: StadiumLightingKitPreviewRuntime, kit: Node3D, poles: Array[Node3D]
) -> bool:
	if (
		_source_owner._lighting_preview != null
		or not is_instance_valid(lease)
		or lease.get_script() != StadiumLightingKitPreviewRuntime
		or lease.property_owner() != _source_owner
		or lease.kit_owner() != kit
		or lease.pole_owners() != poles
		or not lease.ready_for_attach()
	):
		return false
	var kit_sealed: bool = false
	for seal: Dictionary in _source_owner._infrastructure:
		kit_sealed = kit_sealed or seal.root == kit
	if not kit_sealed:
		return false
	var prior_count: int = _source_owner._infrastructure.size()
	for pole: Node3D in poles:
		var found: bool = false
		for seal: Dictionary in _source_owner._infrastructure:
			found = found or seal.root == pole
		if not found and not _source_owner._capture_infrastructure(pole):
			_source_owner._infrastructure.resize(prior_count)
			return false
	_source_owner._lighting_preview = lease
	return true


static func _source_public_detach_lighting_preview(_source_owner: StadiumPropertyGeometry, lease: \
	StadiumLightingKitPreviewRuntime) -> bool:
	if _source_owner._lighting_preview != lease:
		return false
	lease.invalidate_fixture_issue()
	_source_owner._lighting_preview = null
	return true


static func _source_public_has_live_waterfall(_source_owner: StadiumPropertyGeometry) -> bool:
	return (
		_source_owner.has_meta("waterfall_live_layout")
		and _source_owner.get_meta("waterfall_live_layout").get("live_waterfalls", []).size() == 1
	)


static func _source_public_waterfall_step(_source_owner: StadiumPropertyGeometry, from: Vector3, \
	target: Vector3, travel: float, actors: Array = []) -> Vector3:
	if not _source_owner.has_live_waterfall() or not _source_owner.props_intact():
		return from
	var boundary: StadiumBoundaryOwnedRuntime = (
		_source_owner.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	if boundary == null or not boundary.intact():
		return from
	var result: Dictionary = StadiumWaterfallLiveRoutes.step(
		from, target, travel, boundary.graph, actors
	)
	return result.position if result.ok else from


static func _source_public_waterfall_clip(_source_owner: StadiumPropertyGeometry, from: Vector3, \
	to: Vector3) -> Vector3:
	# Forced first-step guesses may be stopped, never redirected into a smarter heading.
	if not _source_owner.has_live_waterfall() or not _source_owner.props_intact():
		return from
	var boundary: StadiumBoundaryOwnedRuntime = (
		_source_owner.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	if (
		boundary == null
		or not boundary.intact()
		or not StadiumWaterfallLiveRoutes.legal(from, boundary.graph)
	):
		return from
	if StadiumWaterfallLiveRoutes.clear(from, to, boundary.graph):
		return to
	var low: float = 0.0
	var high: float = 1.0
	for iteration in range(24):
		var middle: float = (low + high) * 0.5
		if StadiumWaterfallLiveRoutes.clear(from, from.lerp(to, middle), boundary.graph):
			low = middle
		else:
			high = middle
	return from.lerp(to, low)

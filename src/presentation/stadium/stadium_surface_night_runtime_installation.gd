extends RefCounted
## Stateless installation operations for the existing surface-night runtime owner.


static func _install(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE:
		return StadiumSurfaceNightRuntime.installed_bound(lab, owner._snapshot)
	owner._install_step = "admission"
	if owner._phase != StadiumSurfaceNightRuntime.Phase.CONFIGURED or not owner._admissible(lab):
		owner._report_install_failure(lab)
		return false
	owner._install_step = "build-and-boundary"
	owner._property = StadiumPropertyGeometry.new()
	if (
		not owner._property.build(
			owner._snapshot.tier,
			owner._kit_physical_layout if owner._kit_mode else owner._snapshot.layout,
			StadiumLayoutSnapshot.ownership(owner._snapshot)
		)
		or StadiumBoundaryRuntime.assemble(owner._property) == null
		or not owner._admissible(lab)
	):
		owner._report_install_failure(lab)
		owner._property.free()
		owner._property = null
		return false
	owner._install_step = "capture"
	if not owner._capture(lab):
		owner._report_install_failure(lab)
		if is_instance_valid(owner._kit_lease):
			owner._kit_lease.restore()
			owner._kit_lease.free()
			owner._kit_lease = null
		owner._property.free()
		owner._property = null
		return false
	return _install_geometry(owner, lab)


static func _install_geometry(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._phase = StadiumSurfaceNightRuntime.Phase.GEOMETRY
	owner._viewport.set_meta(StadiumSurfaceNightRuntime.ATLAS, owner)
	for id: String in StadiumSurfaceNightRuntime.REMOVED:
		owner._install_step = "before-remove:" + id
		if not owner._context(lab) or not owner._operands():
			owner._report_install_failure(lab)
			owner._restore(lab)
			return false
		var node: Node = owner._host.get_node(NodePath(id))
		owner._old_nodes.append(node)
		owner._tree_transition = true
		owner._host.remove_child(node)
		owner._tree_transition = false
		owner._install_step = "after-remove:" + id
		# Wait for remove_child to complete before deciding ownership-safe rollback.
		if not owner._after_tree_transition(lab):
			owner._report_install_failure(lab)
			owner._restore(lab)
			return false
	owner._install_step = "before-attach"
	owner._property.name = "HomeProperty"
	owner._expected.attached = true  # Planned tree transition; no post-callback expectation adoption.
	owner._tree_transition = true
	owner._host.add_child(owner._property)
	owner._tree_transition = false
	owner._install_step = "after-attach"
	if not owner._after_tree_transition(lab):
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	return _install_metadata(owner, lab)


static func _install_metadata(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	for key: StringName in StadiumSurfaceNightRuntime.META:
		owner._install_step = "metadata:" + String(key)
		if not owner._context(lab) or not owner._operands():
			owner._report_install_failure(lab)
			owner._restore(lab)
			return false
		var value: Variant = (
			owner._property
			if key == &"stadium_property"
			else (
				owner._snapshot.duplicate(true)
				if key == &"stadium_snapshot"
				else (
					owner._snapshot.boundary
					if key == &"boundary_signature"
					else (owner._time_profile if owner._time_mode else "night")
				)
			)
		)
		lab.set_meta(key, value)
		owner._expected.metadata[key] = {"present": true, "value": value}
	if not owner._context(lab) or not owner._operands():
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	owner._install_step = "observer"
	var observer: Callable = (
		(owner._boundary as StadiumBoundaryOwnedRuntime).observe
		if owner._owned_boundary_mode()
		else StadiumBoundaryObserver.observe
	)
	owner._resolver.segment_observer = observer
	owner._expected.observer = observer
	if not owner._context(lab) or not owner._operands():
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	return _install_routes(owner, lab)


static func _install_routes(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._install_step = "clip"
	var clip: Callable = (
		(owner._boundary as StadiumBoundaryOwnedRuntime).graph.clip
		if owner._owned_boundary_mode()
		else StadiumBoundaryGraph.clip
	)
	owner._fielder.stadium_boundary_clip = clip
	owner._expected.clip = clip
	if not owner._context(lab) or not owner._operands():
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	owner._install_step = "obstacles"
	owner._fielder.stadium_obstacles = owner._property.route_obstacles()
	owner._expected.obstacles = owner._fielder.stadium_obstacles.duplicate(true)
	if not owner._context(lab) or not owner._operands():
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	owner._install_step = "tracking"
	owner._tracking.configure(owner._host)
	owner._expected.visibility = owner._visibility()
	if not owner._context(lab) or not owner._operands() or not owner._apply_presentation(lab):
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	owner._install_step = "active-final"
	owner._exit_callback = owner._on_exiting
	lab.tree_exiting.connect(owner._exit_callback)
	owner._phase = StadiumSurfaceNightRuntime.Phase.ACTIVE
	if (
		not StadiumSurfaceNightRuntime.installed_bound(lab, owner._snapshot)
		or (owner._kit_mode and not owner._issue_kit_state())
	):
		owner._report_install_failure(lab)
		owner._restore(lab)
		return false
	return true


static func _capture(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._install_step = "capture:nodes"
	if not owner._node_operands_valid(lab):
		return false
	var boundary: Variant = owner._property.get_node_or_null("BoundaryGraph")
	if (
		not is_instance_valid(boundary)
		or not boundary is Node3D
		or boundary.get_parent() != owner._property
		or boundary.is_queued_for_deletion()
		or (
			boundary.get_script() != StadiumBoundaryOwnedRuntime
			if owner._owned_boundary_mode()
			else boundary.get_script() != StadiumBoundaryPrototype
		)
	):
		return false
	owner._boundary = boundary
	var director: Variant = lab._camera_director
	if (
		not is_instance_valid(director)
		or not director is MatchCameraDirector
		or director.get_script() != MatchCameraDirector
	):
		return false
	var tracking: Variant = director.tracking_visibility
	if (
		not is_instance_valid(tracking)
		or not tracking is BallTrackingVisibility
		or tracking.get_script() != BallTrackingVisibility
	):
		return false
	owner._host = lab.get_node("StarterFieldGeometry")
	owner._parent = lab.get_parent()
	owner._viewport = lab.get_viewport()
	owner._world = owner._viewport.find_world_3d()
	owner._field = lab._field_definition
	if (
		not is_instance_valid(owner._field)
		or owner._field.get_script() != FieldDefinition
		or ContentDB.get_field(PitchBatLab.FIELD_ID) != owner._field
	):
		return false
	return _capture_bound_nodes(owner, lab, director, tracking)


static func _capture_bound_nodes(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, director: Variant, tracking: Variant
) -> bool:
	owner._field_fair = owner._field.fair_half_angle_degrees
	owner._field_safe = owner._field.safe_hit_z_m
	owner._field_deep = owner._field.deep_air_z_m
	owner._field_wall = owner._field.back_wall_z_m
	owner._field_home_run = owner._field.home_run_height_m
	owner._field_dead = owner._field.dead_ball_z_m
	if owner._owned_boundary_mode():
		owner._field_shallow_anchor = owner._field.shallow_anchor_z_m
		owner._field_middle_anchor = owner._field.middle_anchor_z_m
		owner._field_middle_center_anchor = owner._field.middle_center_anchor_z_m
		owner._field_deep_anchor = owner._field.deep_anchor_z_m
		owner._field_side_anchor = owner._field.side_anchor_x_m
	owner._property_field = owner._property.field
	owner._camera = lab._camera
	owner._pitch = lab._pitch_actor
	owner._resolver = lab._ball_play_resolver
	owner._fielder = lab._primary_fielder
	owner._director = director
	owner._tracking = tracking
	owner._environment_owner = lab._world_environment
	owner._sun = owner._host.get_node_or_null("Sun") as DirectionalLight3D
	owner._surface = (
		owner._property.get_node_or_null("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
		as MeshInstance3D
	)
	if (
		not is_instance_valid(owner._camera)
		or not is_instance_valid(owner._pitch)
		or not is_instance_valid(owner._resolver)
		or not is_instance_valid(owner._fielder)
		or owner._director == null
		or not is_instance_valid(owner._environment_owner)
		or not is_instance_valid(owner._sun)
		or owner._environment_owner.environment == null
		or (
			not owner._kit_mode
			and (
				not is_instance_valid(owner._surface)
				or not owner._surface.material_override is ShaderMaterial
			)
		)
	):
		return false
	return _capture_materials(owner, lab)


static func _capture_materials(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._install_step = "capture:world-environment"
	owner._environment = owner._environment_owner.environment
	if owner._world.environment != owner._environment:
		return false
	if owner._kit_mode:
		return owner._capture_kit(lab)
	owner._material = owner._surface.material_override as ShaderMaterial
	var pigment: Variant = owner._material.get_shader_parameter("vertex_pigment_scale")
	if not (pigment is float or pigment is int) or not is_finite(float(pigment)) or pigment <= 0:
		return false
	owner._working_environment = owner._environment.duplicate(not owner._time_mode) as Environment
	owner._working_material = owner._material.duplicate(true) as ShaderMaterial
	if owner._working_environment == null or owner._working_material == null:
		return false
	return _capture_presentation_state(owner, lab, pigment)


static func _capture_presentation_state(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, pigment: Variant
) -> bool:
	owner._before = {
		"environment": StadiumSurfaceNightRuntime._environment_values(owner._environment),
		"environment_meta": StadiumSurfaceNightRuntime._metadata(owner._environment),
		"material_meta": StadiumSurfaceNightRuntime._metadata(owner._material),
		"pigment": float(pigment),
		"sun": {"color": owner._sun.light_color, "energy": owner._sun.light_energy},
		"shadows": owner._shadows(),
		"observer": owner._resolver.segment_observer,
		"clip": owner._fielder.stadium_boundary_clip,
		"obstacles": owner._fielder.stadium_obstacles.duplicate(true),
		"visibility": owner._visibility(),
		"receiver": owner._pitch.receiver_router,
		"metadata": {}
	}
	for key: StringName in StadiumSurfaceNightRuntime.META:
		owner._before.metadata[key] = {
			"present": lab.has_meta(key), "value": lab.get_meta(key) if lab.has_meta(key) else null
		}
	owner._expected = owner._before.duplicate(true)
	owner._expected["environment_resource"] = owner._environment
	owner._expected["material_resource"] = owner._material
	owner._expected["attached"] = false
	owner._old_order.assign(owner._host.get_children())
	if owner._floodlight_mode:
		owner._install_step = "capture:floodlights"
		if not owner._capture_floodlights():
			return false
	else:
		for placement: Dictionary in owner._snapshot.layout.lights:
			var value: Variant = owner._property.objects.get(placement.copy)
			if not is_instance_valid(value) or not value is Node3D:
				return false
			var beam: SpotLight3D = value.get_node_or_null("FieldLight") as SpotLight3D
			var lens: MeshInstance3D = value.get_node_or_null("Visual/LampLens") as MeshInstance3D
			if beam == null or lens == null or not lens.material_override is StandardMaterial3D:
				return false
			var original: StandardMaterial3D = lens.material_override
			var working: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
			if working == null:
				return false
			var row: Dictionary = {
				"copy": placement.copy,
				"site": placement.site,
				"item": "ST-037",
				"model": value,
				"beam": beam,
				"lens": lens,
				"original": original,
				"working": working,
				"metadata": StadiumSurfaceNightRuntime._metadata(original),
				"visible": beam.visible,
				"emission": original.emission_enabled,
				"energy": original.emission_energy_multiplier,
				"expected_material": original,
				"expected_visible": beam.visible,
				"expected_emission": original.emission_enabled,
				"expected_energy": original.emission_energy_multiplier,
				"beam_energy": beam.light_energy,
				"expected_beam_energy": beam.light_energy
			}
			owner._lamps.append(row)
			owner._emitters.append(row)
		if owner._lamps.size() != 4:
			return false
	owner._install_step = "capture:time"
	return not owner._time_mode or owner._capture_time()


static func _owned_boundary_mode(owner: StadiumSurfaceNightRuntime) -> bool:
	return owner._floodlight_mode or owner._kit_mode


static func _capture_kit(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._install_step = "capture:kit"
	if (
		owner._time_mode
		or not StadiumLightingKitNightCandidate.target_matches(owner._kit_profile, owner._viewport)
		or not owner._property.props_intact()
		or owner._property.transform != Transform3D.IDENTITY
		or not StadiumSurfaceNightRuntime._kit_no_internal_children(owner._property)
	):
		return false
	owner._before = {
		"observer": owner._resolver.segment_observer,
		"clip": owner._fielder.stadium_boundary_clip,
		"obstacles": owner._fielder.stadium_obstacles.duplicate(true),
		"visibility": owner._visibility(),
		"receiver": owner._pitch.receiver_router,
		"metadata": {}
	}
	for key: StringName in StadiumSurfaceNightRuntime.META:
		owner._before.metadata[key] = {
			"present": lab.has_meta(key), "value": lab.get_meta(key) if lab.has_meta(key) else null
		}
	owner._expected = owner._before.duplicate(true)
	owner._expected["attached"] = false
	owner._old_order.assign(owner._host.get_children())
	owner._owned_property = {"objects": owner._property.objects.duplicate(), "metadata": {}}
	for key: StringName in owner._property.get_meta_list():
		var value: Variant = owner._property.get_meta(key)
		owner._owned_property.metadata[String(key)] = {
			"present": true,
			"value": value.duplicate(true) if value is Dictionary or value is Array else value
		}
	owner._kit_children.assign(owner._property.get_children(true))
	if not owner._pool_kit_boundary_visuals() or not owner._capture_kit_boundary_visuals():
		return false
	owner._kit_texture_seal = StadiumKitSurfaceTextureSeal.issue(owner, owner._property)
	if owner._kit_texture_seal == null:
		return false
	# Admission-only seal of untouched plain property geometry, including rough-dirt
	# floor materials and collision. No active recapture and no plate-sand requirement.
	for node: Node in owner._kit_children:
		if node == owner._boundary or owner._property.objects.values().has(node):
			continue
		var sealed: bool = false
		for row: Dictionary in owner._property._infrastructure:
			sealed = sealed or row.root == node
		if (
			not sealed
			and (
				not node is Node3D
				or not owner._property._capture_infrastructure(node, owner._kit_texture_seal)
			)
		):
			return false
	var kit: Node3D = owner._property.objects.get(owner._kit_profile.kit_copy) as Node3D
	var poles: Array[Node3D] = []
	for row: Dictionary in owner._kit_profile.rear_poles:
		var pole: Node3D = owner._property.objects.get(row.copy) as Node3D
		if not is_instance_valid(pole):
			return false
		poles.append(pole)
	owner._kit_lease = StadiumLightingKitPreviewRuntime.prepare_fixture(
		owner,
		owner._property,
		owner._environment_owner,
		owner._sun,
		kit,
		poles,
		owner._kit_profile.presentation_profile
	)
	return (
		is_instance_valid(owner._kit_lease)
		and owner._kit_lease.attach_fixture(owner)
		and owner._owned_property_intact()
	)


static func _kit_texture_issuance_allowed(
	owner: StadiumSurfaceNightRuntime, property: StadiumPropertyGeometry
) -> bool:
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	return (
		owner._kit_mode
		and not owner._time_mode
		and not owner._floodlight_mode
		and owner._phase == StadiumSurfaceNightRuntime.Phase.CONFIGURED
		and not owner._restoring
		and owner._kit_texture_seal == null
		and not owner._kit_issue_ever
		and is_same(property, owner._property)
		and is_instance_valid(property)
		and property.get_parent() == null
		and property.transform == Transform3D.IDENTITY
		and owner._identity_configured(lab)
		and StadiumSurfaceNightRuntime._data(owner._kit_profile) == owner._kit_profile_data
	)


static func _kit_lease_context(
	owner: StadiumSurfaceNightRuntime, lease: StadiumLightingKitPreviewRuntime, require_claim: bool
) -> bool:
	# Called by the property's presentation exception guard. Never calls props_intact
	# or _context recursively; transaction callbacks separately invoke the full guard.
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	if (
		not owner._kit_mode
		or StadiumSurfaceNightRuntime._data(owner._kit_profile) != owner._kit_profile_data
		or lease != owner._kit_lease
		or (
			owner._phase
			in [
				StadiumSurfaceNightRuntime.Phase.RETIRED, StadiumSurfaceNightRuntime.Phase.ABANDONED
			]
		)
		or not owner._identity_configured(lab)
		or not is_instance_valid(owner._property)
		or not is_instance_valid(owner._environment_owner)
		or not is_instance_valid(owner._sun)
		or not is_instance_valid(owner._viewport)
		or lab.get_viewport() != owner._viewport
		or owner._environment_owner != lease._environment
		or owner._sun != lease._sun
		or owner._viewport != lease._viewport
		or owner._property != lease.property_owner()
		or owner._world != owner._viewport.find_world_3d()
		or owner._world.environment != owner._environment_owner.environment
		or (
			owner._property.get_parent()
			!= (owner._host if owner._expected.get("attached", false) else null)
		)
	):
		return false
	if owner._phase == StadiumSurfaceNightRuntime.Phase.CONFIGURED:
		return not owner._viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
	return (
		(not require_claim or owner._attached_kit_lease(lease))
		and owner._viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
		and is_same(owner._viewport.get_meta(StadiumSurfaceNightRuntime.ATLAS), owner)
	)


static func _attached_kit_lease(
	owner: StadiumSurfaceNightRuntime, lease: StadiumLightingKitPreviewRuntime
) -> bool:
	return owner._property._lighting_preview == lease and lease._attached


static func _kit_toggle_allowed(
	owner: StadiumSurfaceNightRuntime, lease: StadiumLightingKitPreviewRuntime, enabled: bool
) -> bool:
	return (
		owner._kit_mode
		and is_same(lease, owner._kit_lease)
		and (
			(
				owner._phase == StadiumSurfaceNightRuntime.Phase.PRESENTATION
				and owner._palette_applying
				and not owner._restoring
			)
			if enabled
			else owner._restoring
		)
	)


static func _kit_transaction_intact(
	owner: StadiumSurfaceNightRuntime, lease: StadiumLightingKitPreviewRuntime
) -> bool:
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	return (
		lease == owner._kit_lease
		and owner._owned_transaction_configured(lab)
		and owner._context(lab)
		and owner._kit_operands()
	)


static func _kit_operands(owner: StadiumSurfaceNightRuntime) -> bool:
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	if (
		not is_instance_valid(lab)
		or not is_instance_valid(owner._kit_lease)
		or not StadiumLightingKitNightCandidate.target_matches(owner._kit_profile, owner._viewport)
		or not owner._kit_boundary_visuals_intact()
		or not owner._kit_lease.presentation_intact()
		or (
			owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
			and not owner._restoring
			and not owner._kit_lease.canonical_night_state()
		)
		or owner._kit_lease._palette_profile != owner._kit_profile.presentation_profile
		or owner._kit_lease._palette_signature != owner._kit_profile.presentation
		or owner._host.get_node_or_null("Sun") != owner._sun
		or (
			owner._host.get_node_or_null("HomeProperty") != owner._property
			if owner._expected.attached
			else owner._host.has_node("HomeProperty")
		)
		or owner._resolver.segment_observer != owner._expected.observer
		or owner._fielder.stadium_boundary_clip != owner._expected.clip
		or owner._fielder.stadium_obstacles != owner._expected.obstacles
		or owner._pitch.receiver_router != owner._expected.receiver
		or owner._visibility() != owner._expected.visibility
	):
		return false
	for key: StringName in StadiumSurfaceNightRuntime.META:
		var value: Dictionary = owner._expected.metadata[key]
		if (
			lab.has_meta(key) != value.present
			or (
				value.present
				and not StadiumSurfaceNightRuntime._kit_value_equal(lab.get_meta(key), value.value)
			)
		):
			return false
	for node: Variant in owner._old_order:
		if (
			not is_instance_valid(node)
			or not node is Node
			or node.is_queued_for_deletion()
			or node.get_parent() != (null if owner._old_nodes.has(node) else owner._host)
		):
			return false
	return owner._property.get_meta_list().size() == owner._owned_property.metadata.size()

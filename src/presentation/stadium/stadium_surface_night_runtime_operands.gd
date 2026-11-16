extends RefCounted
## Stateless operands operations for the existing surface-night runtime owner.


static func _context(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	return (
		owner._phase != StadiumSurfaceNightRuntime.Phase.ABANDONED
		and owner._phase != StadiumSurfaceNightRuntime.Phase.RETIRED
		and owner._identity_configured(lab)
		and (
			(not owner._kit_mode or owner._kit_inputs_intact())
			if owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE and not owner._restoring
			else (
				owner._owned_live_configured(lab)
				if owner._owned_boundary_mode()
				else owner._live_configured(lab)
			)
		)
		and owner._field_unchanged()
		and lab.is_inside_tree()
		and lab.global_transform == Transform3D.IDENTITY
		and owner._caller(lab)
		and lab.get_parent() == owner._parent
		and lab.get_node_or_null("StarterFieldGeometry") == owner._host
		and is_instance_valid(owner._host)
		and owner._host.global_transform == Transform3D.IDENTITY
		and lab._field_id == PitchBatLab.FIELD_ID
		and lab._field_definition == owner._field
		and lab._camera == owner._camera
		and lab._pitch_actor == owner._pitch
		and lab._ball_play_resolver == owner._resolver
		and lab._primary_fielder == owner._fielder
		and lab._camera_director == owner._director
		and is_instance_valid(owner._director)
		and is_instance_valid(owner._tracking)
		and owner._director.tracking_visibility == owner._tracking
		and lab._world_environment == owner._environment_owner
		and is_instance_valid(owner._viewport)
		and lab.get_viewport() == owner._viewport
		and owner._viewport.find_world_3d() == owner._world
		and owner._viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
		and is_same(owner._viewport.get_meta(StadiumSurfaceNightRuntime.ATLAS), owner)
		and is_instance_valid(owner._property)
		and owner._property.field == owner._property_field
		and is_instance_valid(owner._boundary)
		and (
			owner._boundary.get_script()
			== (
				StadiumBoundaryOwnedRuntime
				if owner._owned_boundary_mode()
				else StadiumBoundaryPrototype
			)
		)
		and not owner._boundary.is_queued_for_deletion()
		and owner._boundary.get_parent() == owner._property
		and owner._property.get_node_or_null("BoundaryGraph") == owner._boundary
		and owner._property.tier == owner._tier
		and owner._property.has_meta("property_signature")
		and (
			owner._property.get_meta("property_signature")
			== (owner._kit_physical_geometry if owner._kit_mode else owner._geometry_signature)
		)
		and owner._owned_property_intact()
		and is_instance_valid(owner._camera)
		and owner._camera.get_viewport() == owner._viewport
		and is_instance_valid(owner._environment_owner)
		and owner._environment_owner.get_parent() == lab
		and is_instance_valid(owner._pitch)
		and is_instance_valid(owner._resolver)
		and is_instance_valid(owner._fielder)
	)


static func _operands(owner: StadiumSurfaceNightRuntime, check_pigment: bool = true) -> bool:
	if owner._kit_mode:
		return check_pigment and owner._kit_operands()
	if (
		not check_pigment
		and (
			not owner._palette_applying
			or owner._phase != StadiumSurfaceNightRuntime.Phase.PRESENTATION
			or owner._expected.material_resource != owner._working_material
		)
	):
		return false
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	if (
		not is_instance_valid(lab)
		or not is_instance_valid(owner._sun)
		or not is_instance_valid(owner._surface)
		or owner._host.get_node_or_null("Sun") != owner._sun
		or (
			owner._property.get_node_or_null("OwnedSurfaceFinish/GroundTreatment/SurfaceVisual")
			!= owner._surface
		)
		or (
			owner._property.get_parent() != owner._host
			if owner._expected.attached
			else owner._property.get_parent() != null
		)
		or (
			owner._host.get_node_or_null("HomeProperty") != owner._property
			if owner._expected.attached
			else owner._host.has_node("HomeProperty")
		)
		or owner._environment_owner.environment != owner._expected.environment_resource
		or owner._world.environment != owner._expected.environment_resource
		or (
			StadiumSurfaceNightRuntime._environment_values(owner._environment)
			!= owner._before.environment
		)
		or (
			StadiumSurfaceNightRuntime._metadata(owner._environment)
			!= owner._before.environment_meta
		)
		or (
			StadiumSurfaceNightRuntime._environment_values(owner._expected.environment_resource)
			!= owner._expected.environment
		)
		or owner._surface.material_override != owner._expected.material_resource
		or owner._material.get_shader_parameter("vertex_pigment_scale") != owner._before.pigment
		or StadiumSurfaceNightRuntime._metadata(owner._material) != owner._before.material_meta
		or (
			check_pigment
			and (
				owner._expected.material_resource.get_shader_parameter("vertex_pigment_scale")
				!= owner._expected.pigment
			)
		)
		or owner._sun.light_color != owner._expected.sun.color
		or owner._sun.light_energy != owner._expected.sun.energy
		or owner._shadows() != owner._expected.shadows
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
	return _emitter_operands(owner)


static func _emitter_operands(owner: StadiumSurfaceNightRuntime) -> bool:
	for row: Dictionary in owner._emitters:
		if (
			not owner._member_model_intact(row)
			or not is_instance_valid(row.beam)
			or row.beam.visible != row.expected_visible
			or row.beam.light_energy != row.expected_beam_energy
		):
			return false
		if owner._floodlight_mode:
			if row.beam.get_parent() != row.parent or row.beam.transform != row.pose:
				return false
		elif row.model.get_node_or_null("FieldLight") != row.beam:
			return false
	return _lamp_operands(owner)


static func _lamp_operands(owner: StadiumSurfaceNightRuntime) -> bool:
	for row: Dictionary in owner._lamps:
		if (
			not owner._member_model_intact(row)
			or not is_instance_valid(row.lens)
			or not is_instance_valid(row.original)
			or not is_instance_valid(row.expected_material)
			or row.lens.material_override != row.expected_material
			or row.original.emission_enabled != row.emission
			or row.original.emission_energy_multiplier != row.energy
			or StadiumSurfaceNightRuntime._metadata(row.original) != row.metadata
			or row.expected_material.emission_enabled != row.expected_emission
			or row.expected_material.emission_energy_multiplier != row.expected_energy
		):
			return false
		if owner._floodlight_mode:
			if (
				row.lens.get_parent() != row.parent
				or row.lens.transform != row.pose
				or row.lens.mesh != row.mesh
				or row.lens.visible != row.expected_lens_visible
			):
				return false
		elif row.model.get_node_or_null("Visual/LampLens") != row.lens:
			return false
	return _glow_operands(owner)


static func _glow_operands(owner: StadiumSurfaceNightRuntime) -> bool:
	for row: Dictionary in owner._glow_resources:
		if not is_instance_valid(row.resource):
			return false
		for index in range(row.keys.size()):
			if row.resource.get(row.keys[index]) != row.values[index]:
				return false
	return not owner._time_mode or owner._time_operands()


static func _member_model_intact(owner: StadiumSurfaceNightRuntime, row: Dictionary) -> bool:
	return (
		is_instance_valid(row.model)
		and not row.model.is_queued_for_deletion()
		and owner._property.objects.get(row.copy) == row.model
		and row.model.get_parent() == owner._property
		and row.model.has_meta("owned_copy")
		and row.model.get_meta("owned_copy") == row.copy
		and row.model.has_meta("site")
		and row.model.get_meta("site") == row.site
		and row.model.has_meta("stadium_item")
		and row.model.get_meta("stadium_item") == row.item
	)


static func _after_tree_transition(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if owner._retire_requested:
		owner._retire_requested = false
		owner._restore(lab)
		return false
	return (
		(
			owner._owned_transaction_configured(lab)
			if owner._owned_boundary_mode()
			else owner._configured(lab)
		)
		and owner._context(lab)
		and owner._operands()
	)

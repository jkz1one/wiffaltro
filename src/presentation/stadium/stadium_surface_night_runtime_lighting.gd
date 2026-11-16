extends RefCounted
## Stateless lighting operations for the existing surface-night runtime owner.


static func _capture_floodlights(owner: StadiumSurfaceNightRuntime) -> bool:
	var entry: Dictionary = StadiumSurfaceNightSnapshot.entry(owner._snapshot)
	var profile: Dictionary = StadiumFloodlightOwnedItems.night_profile(entry)
	if (
		profile.is_empty()
		or profile.profile != owner._floodlight_profile
		or not owner._property.props_intact()
	):
		return false
	owner._owned_property = {"objects": owner._property.objects.duplicate(), "metadata": {}}
	for key: String in [
		"property_signature", "boundary_layout", "boundary_stock", "receiver_layout"
	]:
		owner._owned_property.metadata[key] = {
			"present": owner._property.has_meta(key),
			"value":
			(
				owner._property.get_meta(key).duplicate(true)
				if (
					owner._property.has_meta(key)
					and (
						owner._property.get_meta(key) is Dictionary
						or owner._property.get_meta(key) is Array
					)
				)
				else (owner._property.get_meta(key) if owner._property.has_meta(key) else null)
			)
		}
	for placement: Dictionary in profile.placements:
		if not _capture_floodlight_placement(owner, placement):
			return false
	for copy: String in owner._property.objects:
		var model: Node3D = owner._property.objects[copy] as Node3D
		if not is_instance_valid(model) or not model.has_meta("stadium_item"):
			return false
		if model.get_meta("stadium_item") in ["ST-029", "ST-053"]:
			var geometry: Dictionary = StadiumFloodlightOwnedModels.capture_geometry(model)
			if geometry.is_empty():
				return false
			owner._companions.append({"model": model, "geometry": geometry})
	owner._install_step = "capture:owned-property"
	return owner._towers.size() == profile.placements.size() and owner._owned_property_intact()


static func _capture_floodlight_placement(
	owner: StadiumSurfaceNightRuntime, placement: Dictionary
) -> bool:
	var model: Node3D = owner._property.objects.get(placement.copy) as Node3D
	if (
		not is_instance_valid(model)
		or model.get_parent() != owner._property
		or not StadiumSurfaceNightRuntime._placement_metadata(model, placement)
	):
		return false
	owner._install_step = "capture:rig:" + String(placement.site)
	var rig: Dictionary = StadiumFloodlightOwnedModels.install_owned_rig(model)
	if (
		rig.is_empty()
		or rig.emitters.is_empty()
		or rig.lenses.is_empty()
		or rig.geometry.is_empty()
	):
		return false
	owner._towers.append(
		{"model": model, "placement": placement.duplicate(true), "geometry": rig.geometry}
	)
	return _capture_floodlight_members(owner, placement, model, rig)


static func _capture_floodlight_members(
	owner: StadiumSurfaceNightRuntime, placement: Dictionary, model: Node3D, rig: Dictionary
) -> bool:
	for member: Dictionary in rig.emitters:
		var beam: SpotLight3D = member.beam as SpotLight3D
		if not is_instance_valid(beam):
			return false
		owner._emitters.append(
			{
				"copy": placement.copy,
				"site": placement.site,
				"item": placement.item,
				"model": model,
				"beam": beam,
				"parent": member.parent,
				"pose": member.pose,
				"visible": beam.visible,
				"expected_visible": beam.visible,
				"beam_energy": float(member.spec.energy),
				"restore_beam_energy": beam.light_energy,
				"expected_beam_energy": beam.light_energy
			}
		)
	for member: Dictionary in rig.lenses:
		var lens: MeshInstance3D = member.lens as MeshInstance3D
		if not is_instance_valid(lens) or not lens.material_override is StandardMaterial3D:
			return false
		var original: StandardMaterial3D = lens.material_override
		var working: StandardMaterial3D = original.duplicate(true) as StandardMaterial3D
		if working == null:
			return false
		# Disabled emission properties may be omitted by Resource.duplicate().
		# Initialize the owned clone before sealing; keep expectations from the source.
		working.emission_enabled = original.emission_enabled
		working.emission = original.emission
		working.emission_energy_multiplier = original.emission_energy_multiplier
		if not owner._capture_glow_materials(original, working):
			return false
		owner._lamps.append(
			{
				"copy": placement.copy,
				"site": placement.site,
				"item": placement.item,
				"model": model,
				"lens": lens,
				"parent": member.parent,
				"pose": member.pose,
				"mesh": member.mesh,
				"original": original,
				"working": working,
				"lens_visible": lens.visible,
				"expected_lens_visible": lens.visible,
				"metadata": StadiumSurfaceNightRuntime._metadata(original),
				"emission": original.emission_enabled,
				"energy": original.emission_energy_multiplier,
				"expected_material": original,
				"expected_emission": original.emission_enabled,
				"expected_energy": original.emission_energy_multiplier
			}
		)
	return true


static func _capture_glow_materials(
	owner: StadiumSurfaceNightRuntime, original: StandardMaterial3D, working: StandardMaterial3D
) -> bool:
	var rows: Array[Dictionary] = []
	var seen: Dictionary = {}
	if (
		not StadiumFloodlightOwnedModels._capture_resource(original, rows, seen)
		or not StadiumFloodlightOwnedModels._capture_resource(working, rows, seen)
	):
		return false
	for row: Dictionary in rows:
		# Disabled emission color may not be a stored property; guard both exact resources.
		if row.resource == original or row.resource == working:
			if not row.keys.has(&"emission"):
				row.keys.append(&"emission")
				row.values.append(row.resource.emission)
		if row.resource == working:
			for key: StringName in [&"emission_enabled", &"emission_energy_multiplier"]:
				var index: int = row.keys.find(key)
				if index >= 0:
					row.keys.remove_at(index)
					row.values.remove_at(index)
	owner._glow_resources.append_array(rows)
	return true


static func _placement_metadata(model: Node3D, placement: Dictionary) -> bool:
	return (
		model.has_meta("owned_copy")
		and model.get_meta("owned_copy") == placement.copy
		and model.has_meta("stadium_item")
		and model.get_meta("stadium_item") == placement.item
		and model.has_meta("site")
		and model.get_meta("site") == placement.site
		and model.has_meta("floodlight_profile")
		and model.get_meta("floodlight_profile") == placement.profile
	)


static func _owned_property_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	if not owner._owned_boundary_mode():
		return true
	if (
		not is_instance_valid(owner._property)
		or owner._property.get_script() != StadiumPropertyGeometry
		or owner._property.transform != Transform3D.IDENTITY
		or owner._owned_property.is_empty()
		or owner._property.objects != owner._owned_property.objects
	):
		return false
	var detached_restore: bool = (
		owner._restoring and not owner._expected.attached and owner._property.get_parent() == null
	)
	if (
		not detached_restore
		and (
			not owner._property._ground_props_family
			or owner._property.get_node_or_null("BoundaryGraph") != owner._boundary
			or not owner._property.props_intact()
		)
	):
		return false
	for key: String in owner._owned_property.metadata:
		var row: Dictionary = owner._owned_property.metadata[key]
		if (
			owner._property.has_meta(key) != row.present
			or (
				row.present
				and not StadiumSurfaceNightRuntime._kit_value_equal(
					owner._property.get_meta(key), row.value
				)
			)
		):
			return false
	return _owned_property_members_intact(owner)


static func _owned_property_members_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	if owner._kit_mode:
		if owner._property.get_children(true) != owner._kit_children:
			return false
		# Existing shared infrastructure guards deliberately remain historical. The
		# candidate3 local invariant additionally excludes hidden internal additions.
		for seal: Dictionary in owner._property._infrastructure:
			for row: Dictionary in seal.rows:
				if (
					not is_instance_valid(row.node)
					or row.node.is_queued_for_deletion()
					or row.node.get_child_count(true) != row.children.size()
				):
					return false
	var boundary: StadiumBoundaryOwnedRuntime = owner._boundary as StadiumBoundaryOwnedRuntime
	# props_intact already checked this exact in-tree BoundaryGraph synchronously.
	if (
		boundary == null
		or boundary.graph == null
		or boundary.graph.signature() != owner._snapshot.boundary
	):
		return false
	for row: Dictionary in owner._towers:
		if (
			not is_instance_valid(row.model)
			or row.model.get_parent() != owner._property
			or owner._property.objects.get(row.placement.copy) != row.model
			or not StadiumSurfaceNightRuntime._placement_metadata(row.model, row.placement)
			or not StadiumFloodlightOwnedModels.geometry_intact(row.model, row.geometry)
		):
			return false
	for row: Dictionary in owner._companions:
		if (
			not is_instance_valid(row.model)
			or row.model.get_parent() != owner._property
			or not StadiumFloodlightOwnedModels.geometry_intact(row.model, row.geometry)
		):
			return false
	return true


static func _apply_presentation(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if owner._kit_mode:
		owner._phase = StadiumSurfaceNightRuntime.Phase.PRESENTATION
		if not owner._context(lab) or not owner._operands():
			return false
		owner._palette_applying = true
		var applied: bool = owner._kit_lease.set_night(true)
		owner._palette_applying = false
		return applied and owner._configured(lab) and owner._context(lab) and owner._operands()
	if owner._time_mode:
		return owner._apply_time_presentation(lab)
	return _apply_fixed_presentation(owner, lab)


static func _apply_fixed_presentation(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._phase = StadiumSurfaceNightRuntime.Phase.PRESENTATION
	if not owner._context(lab) or not owner._operands():
		return false
	owner._environment_owner.environment = owner._working_environment
	owner._expected.environment_resource = owner._working_environment
	if not owner._context(lab) or not owner._operands():
		return false
	owner._surface.material_override = owner._working_material
	owner._expected.material_resource = owner._working_material
	return _apply_fixed_environment(owner, lab)


static func _apply_fixed_environment(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Direct family-owned writes: no prototype callback is ever installed.
	var night: Dictionary = {
		"background_mode": Environment.BG_COLOR,
		"background_color": Color("14263d"),
		"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR,
		"ambient_light_color": Color("92acc9"),
		"ambient_light_energy": 0.52,
		"reflected_light_source": Environment.REFLECTION_SOURCE_DISABLED
	}
	for field: String in night:
		if not owner._context(lab) or not owner._operands():
			return false
		owner._working_environment.set(field, night[field])
		owner._expected.environment[field] = owner._working_environment.get(field)
	if not owner._context(lab) or not owner._operands():
		return false
	owner._sun.light_color = Color("93accb")
	owner._expected.sun.color = owner._sun.light_color
	if not owner._context(lab) or not owner._operands():
		return false
	owner._sun.light_energy = 0.28
	owner._expected.sun.energy = owner._sun.light_energy
	return _apply_fixed_shadows(owner, lab)


static func _apply_fixed_shadows(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	for index in range(4):
		if not owner._context(lab) or not owner._operands():
			return false
		owner._viewport.set_positional_shadow_atlas_quadrant_subdiv(
			index, Viewport.SHADOW_ATLAS_QUADRANT_SUBDIV_1
		)
		owner._expected.shadows.quadrants[index] = (
			owner._viewport.get_positional_shadow_atlas_quadrant_subdiv(index)
		)
	if not owner._context(lab) or not owner._operands():
		return false
	owner._viewport.positional_shadow_atlas_size = 2048
	owner._expected.shadows.size = 2048
	if not owner._context(lab) or not owner._operands():
		return false
	owner._viewport.positional_shadow_atlas_16_bits = false
	owner._expected.shadows.precision = false
	return _apply_fixed_lighting(owner, lab)


static func _apply_fixed_lighting(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	for row: Dictionary in owner._emitters:
		if not owner._context(lab) or not owner._operands():
			return false
		row.expected_visible = true
		row.beam.visible = true
		if not owner._configured(lab) or not owner._context(lab) or not owner._operands():
			return false
	for row: Dictionary in owner._lamps:
		if not _apply_fixed_lamp(owner, lab, row):
			return false
	return _apply_fixed_palette(owner, lab)


static func _apply_fixed_palette(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if not owner._context(lab) or not owner._operands():
		return false
	owner._palette_applying = true
	var applied: bool = StadiumSurfaceNightPalette.apply(owner._property)
	# Only the pigment may have changed during this synchronous helper. Never bless replacements.
	if not owner._context(lab) or not owner._operands(false):
		return false
	var pigment: Variant = owner._working_material.get_shader_parameter("vertex_pigment_scale")
	owner._expected.pigment = pigment
	owner._palette_applying = false
	return (
		applied
		and (pigment is float or pigment is int)
		and is_finite(float(pigment))
		and owner._operands()
	)


static func _apply_fixed_lamp(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, row: Dictionary
) -> bool:
	if not owner._context(lab) or not owner._operands():
		return false
	row.lens.material_override = row.working
	row.expected_material = row.working
	if owner._floodlight_mode:
		if not owner._context(lab) or not owner._operands():
			return false
		row.expected_lens_visible = true
		row.lens.visible = true
		if not owner._configured(lab) or not owner._context(lab) or not owner._operands():
			return false
	row.working.emission_enabled = true
	row.expected_emission = true
	if not owner._context(lab) or not owner._operands():
		return false
	row.working.emission_energy_multiplier = 1.0
	row.expected_energy = 1.0
	return true

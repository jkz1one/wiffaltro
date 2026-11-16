extends RefCounted
## Stateless restoration operations for the existing surface-night runtime owner.


static func _restore(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	if owner._kit_mode:
		owner._revoke_kit_state()
	if (
		owner._restoring
		or (
			owner._phase
			in [
				StadiumSurfaceNightRuntime.Phase.RETIRED, StadiumSurfaceNightRuntime.Phase.ABANDONED
			]
		)
	):
		return
	if owner._tree_transition:
		owner._retire_requested = true
		return
	owner._restoring = true
	owner._disconnect(lab)
	if (
		owner._owned_boundary_mode()
		and (
			not is_instance_valid(lab)
			or not lab.is_inside_tree()
			or (
				owner._expected.get("attached", false)
				and (not is_instance_valid(owner._property) or not owner._property.is_inside_tree())
			)
		)
	):
		owner._abandon_restore()
		return
	if owner._phase == StadiumSurfaceNightRuntime.Phase.CONFIGURED:
		owner._phase = StadiumSurfaceNightRuntime.Phase.RETIRED
		owner._dispose_detached()
		return
	_restore_active(owner, lab)
	return


static func _restore_active(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	if not owner._configured(lab):
		owner._abandon_restore()
		return
	if not owner._restore_guard(lab):
		return
	if owner._kit_mode:
		if not owner._kit_lease.set_night(false) or not owner._restore_guard(lab):
			owner._abandon_restore()
			return
	else:
		if not _restore_lighting(owner, lab):
			return
	_restore_routes(owner, lab)
	return


static func _restore_routes(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	owner._resolver.segment_observer = owner._before.observer
	owner._expected.observer = owner._before.observer
	if not owner._restore_guard(lab):
		return
	owner._fielder.stadium_boundary_clip = owner._before.clip
	owner._expected.clip = owner._before.clip
	if not owner._restore_guard(lab):
		return
	owner._fielder.stadium_obstacles = owner._before.obstacles.duplicate(true)
	owner._expected.obstacles = owner._before.obstacles.duplicate(true)
	for key: StringName in StadiumSurfaceNightRuntime.VISIBILITY:
		if not owner._restore_guard(lab):
			return
		owner._tracking.set(key, owner._before.visibility[key])
		owner._expected.visibility[key] = owner._before.visibility[key]
	for key: StringName in StadiumSurfaceNightRuntime.META:
		if not owner._restore_guard(lab):
			return
		var value: Dictionary = owner._before.metadata[key]
		if value.present:
			lab.set_meta(key, value.value)
		else:
			lab.remove_meta(key)
		owner._expected.metadata[key] = value.duplicate(true)
	_restore_attachment(owner, lab)
	return


static func _restore_attachment(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	if owner._expected.attached:
		if not owner._restore_guard(lab):
			return
		owner._expected.attached = false
		owner._host.remove_child(owner._property)
		if not (
			owner._owned_transaction_configured(lab)
			if owner._owned_boundary_mode()
			else owner._configured(lab)
		):
			owner._abandon_restore()
			return
		if not owner._restore_guard(lab):
			return
	_restore_nodes(owner, lab)
	return


static func _restore_nodes(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	for node: Variant in owner._old_nodes.duplicate():
		if not owner._restore_guard(lab):
			return
		owner._old_nodes.erase(node)
		owner._host.add_child(node)
		if not (
			owner._owned_transaction_configured(lab)
			if owner._owned_boundary_mode()
			else owner._configured(lab)
		):
			owner._abandon_restore()
			return
		if not owner._restore_guard(lab):
			return
	for index in range(owner._old_order.size()):
		if not owner._restore_guard(lab):
			return
		owner._host.move_child(owner._old_order[index], index)
	if not owner._restore_guard(lab):
		return
	if not owner._configured(lab):
		owner._abandon_restore()
		return
	owner._viewport.remove_meta(StadiumSurfaceNightRuntime.ATLAS)
	owner._phase = StadiumSurfaceNightRuntime.Phase.RETIRED
	owner._dispose_detached()


static func _restore_lighting(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._surface.material_override = owner._material
	owner._expected.material_resource = owner._material
	owner._expected.pigment = owner._before.pigment
	for row: Dictionary in owner._lamps:
		if not owner._restore_guard(lab):
			return false
		row.lens.material_override = row.original
		row.expected_material = row.original
		row.expected_emission = row.emission
		row.expected_energy = row.energy
		if owner._floodlight_mode:
			if not owner._restore_guard(lab):
				return false
			row.expected_lens_visible = row.lens_visible
			row.lens.visible = row.lens_visible
			if not (
				owner._owned_transaction_configured(lab)
				if owner._owned_boundary_mode()
				else owner._configured(lab)
			):
				owner._abandon_restore()
				return false
	return _restore_emitters(owner, lab)


static func _restore_emitters(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	for row: Dictionary in owner._emitters:
		if not owner._restore_guard(lab):
			return false
		if owner._time_mode:
			row.beam.light_energy = row.get("restore_beam_energy", row.beam_energy)
			row.expected_beam_energy = row.beam.light_energy
		if not owner._restore_guard(lab):
			return false
		row.expected_visible = row.visible
		row.beam.visible = row.visible
		if not (
			owner._owned_transaction_configured(lab)
			if owner._owned_boundary_mode()
			else owner._configured(lab)
		):
			owner._abandon_restore()
			return false
	if not owner._restore_guard(lab):
		return false
	return _restore_environment(owner, lab)


static func _restore_environment(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._environment_owner.environment = owner._environment
	owner._expected.environment_resource = owner._environment
	owner._expected.environment = owner._before.environment.duplicate(true)
	if owner._time_mode:
		owner._time_expected.sky = owner._original_sky
	if not owner._restore_guard(lab):
		return false
	owner._sun.light_color = owner._before.sun.color
	owner._expected.sun.color = owner._before.sun.color
	if not owner._restore_guard(lab):
		return false
	owner._sun.light_energy = owner._before.sun.energy
	owner._expected.sun.energy = owner._before.sun.energy
	if not owner._restore_guard(lab):
		return false
	owner._viewport.positional_shadow_atlas_size = owner._before.shadows.size
	owner._expected.shadows.size = owner._before.shadows.size
	if not owner._restore_guard(lab):
		return false
	return _restore_shadows(owner, lab)


static func _restore_shadows(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	owner._viewport.positional_shadow_atlas_16_bits = owner._before.shadows.precision
	owner._expected.shadows.precision = owner._before.shadows.precision
	for index in range(4):
		if not owner._restore_guard(lab):
			return false
		owner._viewport.set_positional_shadow_atlas_quadrant_subdiv(
			index, owner._before.shadows.quadrants[index]
		)
		owner._expected.shadows.quadrants[index] = owner._before.shadows.quadrants[index]
	if not owner._restore_guard(lab):
		return false
	return true


static func _restore_guard(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	if owner._context(lab) and owner._operands():
		return true
	owner._report_install_failure(lab)
	owner._abandon_restore()
	return false


static func _abandon_restore(owner: StadiumSurfaceNightRuntime) -> void:
	if owner._kit_mode:
		owner._revoke_kit_state()
	owner._report_install_failure(owner._lab.get_ref() if owner._lab != null else null)
	owner._phase = StadiumSurfaceNightRuntime.Phase.ABANDONED
	# Historical restore ordering is unchanged. The new kit lease needs its exact
	# atlas marker during target-specific cleanup, then releases only its own marker.
	if (
		not owner._kit_mode
		and is_instance_valid(owner._viewport)
		and owner._viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
		and is_same(owner._viewport.get_meta(StadiumSurfaceNightRuntime.ATLAS), owner)
	):
		owner._viewport.remove_meta(StadiumSurfaceNightRuntime.ATLAS)
	owner._dispose_detached()
	if (
		owner._kit_mode
		and is_instance_valid(owner._viewport)
		and owner._viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
		and is_same(owner._viewport.get_meta(StadiumSurfaceNightRuntime.ATLAS), owner)
	):
		owner._viewport.remove_meta(StadiumSurfaceNightRuntime.ATLAS)


static func _dispose_detached(owner: StadiumSurfaceNightRuntime) -> void:
	if is_instance_valid(owner._kit_lease):
		owner._kit_lease.restore()
		owner._kit_lease.queue_free()  # May be releasing from a synchronous source-visibility callback.
		owner._kit_lease = null
	for node: Variant in owner._old_nodes:
		if (
			is_instance_valid(node)
			and node is Node
			and node.get_parent() == null
			and not node.is_queued_for_deletion()
		):
			node.queue_free()
	owner._old_nodes.clear()
	if is_instance_valid(owner._property) and owner._property.get_parent() == null:
		owner._property.queue_free()


static func _on_exiting(owner: StadiumSurfaceNightRuntime) -> void:
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	if owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE:
		if owner._owned_boundary_mode():
			owner._disconnect(lab)
			owner._abandon_restore()
		else:
			owner._restore(lab)


static func _disconnect(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	if (
		is_instance_valid(lab)
		and owner._exit_callback.is_valid()
		and lab.tree_exiting.is_connected(owner._exit_callback)
	):
		lab.tree_exiting.disconnect(owner._exit_callback)
	owner._exit_callback = Callable()


static func _visibility(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in StadiumSurfaceNightRuntime.VISIBILITY:
		var value: Variant = owner._tracking.get(key)
		result[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return result


static func _shadows(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	return StadiumSurfaceNightPreview._shadows(owner._viewport)


static func _metadata(value: Object) -> Dictionary:
	return StadiumSurfaceNightPreview._metadata(value)


static func _environment_values(value: Environment) -> Dictionary:
	return StadiumSurfaceNightPreview._environment_values(value)


static func _data(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)

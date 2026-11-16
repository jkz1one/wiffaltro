extends RefCounted
## Stateless authority operations for the existing surface-night runtime owner.


static func _report_install_failure(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> void:
	if not owner._diagnostics_enabled or owner._diagnostics_reported or not owner._floodlight_mode:
		return
	owner._diagnostics_reported = true
	var captured: bool = (
		is_instance_valid(owner._property)
		and is_instance_valid(owner._host)
		and is_instance_valid(owner._surface)
		and is_instance_valid(owner._environment_owner)
		and is_instance_valid(owner._sun)
		and is_instance_valid(owner._world)
		and not owner._expected.is_empty()
	)
	var live: bool = is_instance_valid(lab) and lab.is_inside_tree()
	var guards: Dictionary = {
		"configured": owner._configured(lab),
		"caller": live and owner._caller(lab),
		"field": owner._field_unchanged(),
		"captured": captured,
		"live": live,
		"property_inside_tree":
		is_instance_valid(owner._property) and owner._property.is_inside_tree(),
		"atlas_owner":
		(
			is_instance_valid(owner._viewport)
			and owner._viewport.has_meta(StadiumSurfaceNightRuntime.ATLAS)
			and is_same(owner._viewport.get_meta(StadiumSurfaceNightRuntime.ATLAS), owner)
		)
	}
	if captured:
		guards["context"] = live and owner._context(lab)
		guards["operands"] = owner._operands()
		guards["owned_property"] = owner._owned_property_intact()
		guards["property_props"] = (
			owner._property.props_intact() if owner._property.is_inside_tree() else "detached"
		)
		guards["boundary"] = (
			(owner._boundary as StadiumBoundaryOwnedRuntime).intact()
			if is_instance_valid(owner._boundary) and owner._boundary.is_inside_tree()
			else "detached"
		)
		guards["lab_pose"] = lab.global_transform == Transform3D.IDENTITY if live else false
		guards["host_pose"] = (
			owner._host.global_transform == Transform3D.IDENTITY
			if owner._host.is_inside_tree()
			else false
		)
	print(
		(
			"FLOODLIGHT_RUNTIME_FAILURE "
			+ StadiumSurfaceNightRuntime._data(
				{
					"profile": owner._floodlight_profile,
					"mode": owner._time_profile,
					"step": owner._install_step,
					"phase": int(owner._phase),
					"restoring": owner._restoring,
					"guards": guards,
					"counts": [owner._towers.size(), owner._emitters.size(), owner._lamps.size()],
					"first_difference": owner._first_cached_difference() if captured else {}
				}
			)
		)
	)


static func _first_cached_difference(owner: StadiumSurfaceNightRuntime) -> Dictionary:
	for tower: Dictionary in owner._towers + owner._companions:
		var mismatch: Dictionary = _tower_cached_difference(owner, tower)
		if not mismatch.is_empty():
			return mismatch
	for row: Dictionary in owner._glow_resources:
		var mismatch: Dictionary = StadiumSurfaceNightRuntime._resource_difference(
			row, "glow_resource"
		)
		if not mismatch.is_empty():
			return mismatch
	for row: Dictionary in owner._lamps:
		if (
			not is_instance_valid(row.lens)
			or not is_instance_valid(row.original)
			or not is_instance_valid(row.expected_material)
		):
			return {"kind": "glow_operand", "site": row.site, "field": "freed_lens_or_material"}
		for operand: Array in [
			["material", row.lens.material_override, row.expected_material],
			["original_emission", row.original.emission_enabled, row.emission],
			["original_energy", row.original.emission_energy_multiplier, row.energy],
			["emission", row.expected_material.emission_enabled, row.expected_emission],
			["energy", row.expected_material.emission_energy_multiplier, row.expected_energy],
			["visible", row.lens.visible, row.expected_lens_visible]
		]:
			if operand[1] != operand[2]:
				return StadiumSurfaceNightRuntime._difference(
					"glow_operand",
					String(row.site) + ":" + String(row.lens.name),
					operand[0],
					operand[1],
					operand[2]
				)
	for row: Array in [
		["world_environment", owner._world.environment, owner._expected.environment_resource],
		[
			"owner_environment",
			owner._environment_owner.environment,
			owner._expected.environment_resource
		],
		["surface_material", owner._surface.material_override, owner._expected.material_resource],
		["sun_color", owner._sun.light_color, owner._expected.sun.color],
		["sun_energy", owner._sun.light_energy, owner._expected.sun.energy],
		["atlas", owner._shadows(), owner._expected.shadows],
		["observer", owner._resolver.segment_observer, owner._expected.observer],
		["clip", owner._fielder.stadium_boundary_clip, owner._expected.clip],
		["visibility", owner._visibility(), owner._expected.visibility]
	]:
		if row[1] != row[2]:
			return StadiumSurfaceNightRuntime._difference(
				"presentation", "", row[0], row[1], row[2]
			)
	return {
		"kind": "no_cached_difference",
		"property_pose": str(owner._property.transform),
		"property_signature":
		(
			owner._property.get_meta("property_signature")
			if owner._property.has_meta("property_signature")
			else "missing"
		),
		"expected_signature": owner._geometry_signature
	}


static func _tower_cached_difference(
	owner: StadiumSurfaceNightRuntime, tower: Dictionary
) -> Dictionary:
	for row: Dictionary in tower.geometry.rows:
		var node: Node = row.node
		if not is_instance_valid(node):
			return {"kind": "freed_node", "name": String(row.name)}
		for identity: Array in [
			["parent", node.get_parent(), row.parent],
			["name", node.name, row.name],
			["children", node.get_children(), row.children]
		]:
			if identity[1] != identity[2]:
				return StadiumSurfaceNightRuntime._difference(
					"node_identity", String(row.name), identity[0], identity[1], identity[2]
				)
		for index in range(row.fields.size()):
			var current: Variant = node.get(row.fields[index])
			if current != row.values[index]:
				return StadiumSurfaceNightRuntime._difference(
					"node_field",
					String(row.name),
					String(row.fields[index]),
					current,
					row.values[index]
				)
		for key: String in row.metadata:
			var metadata: Dictionary = row.metadata[key]
			if node.has_meta(key) != metadata.present:
				return StadiumSurfaceNightRuntime._difference(
					"node_metadata_presence",
					String(row.name),
					key,
					node.has_meta(key),
					metadata.present
				)
			if (
				metadata.present
				and not StadiumSurfaceNightRuntime._kit_value_equal(
					node.get_meta(key), metadata.value
				)
			):
				return StadiumSurfaceNightRuntime._difference(
					"node_metadata", String(row.name), key, node.get_meta(key), metadata.value
				)
	return _tower_resource_difference(owner, tower)


static func _tower_resource_difference(
	_owner: StadiumSurfaceNightRuntime, tower: Dictionary
) -> Dictionary:
	for row: Dictionary in tower.geometry.resources:
		var mismatch: Dictionary = StadiumSurfaceNightRuntime._resource_difference(
			row, "tower_resource"
		)
		if not mismatch.is_empty():
			return mismatch
	return {}


static func _resource_difference(row: Dictionary, kind: String) -> Dictionary:
	if not is_instance_valid(row.resource):
		return {"kind": kind, "field": "freed_resource"}
	for index in range(row.keys.size()):
		var current: Variant = row.resource.get(row.keys[index])
		if current != row.values[index]:
			return StadiumSurfaceNightRuntime._difference(
				kind, row.resource.get_class(), String(row.keys[index]), current, row.values[index]
			)
	return {}


static func _difference(
	kind: String, node: String, field: String, current: Variant, expected: Variant
) -> Dictionary:
	return {
		"kind": kind,
		"node": node,
		"field": field,
		"current": StadiumSurfaceNightRuntime._brief(current),
		"expected": StadiumSurfaceNightRuntime._brief(expected)
	}


static func _brief(value: Variant) -> Variant:
	if value is Object:
		return (
			"null_object"
			if not is_instance_valid(value)
			else value.get_class() + ":" + str(value.get_instance_id())
		)
	if value is Array or value is Dictionary:
		return {"type": type_string(typeof(value)), "size": value.size()}
	var description: String = str(value)
	return description.left(220)


static func _kit_hot_context(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	return (
		owner._phase != StadiumSurfaceNightRuntime.Phase.ABANDONED
		and owner._phase != StadiumSurfaceNightRuntime.Phase.RETIRED
		and owner._identity_configured(lab)
		and (
			(not owner._kit_mode or owner._kit_current_authority_intact())
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
		and owner._kit_hot_property_intact()
		and is_instance_valid(owner._camera)
		and owner._camera.get_viewport() == owner._viewport
		and is_instance_valid(owner._environment_owner)
		and owner._environment_owner.get_parent() == lab
		and is_instance_valid(owner._pitch)
		and is_instance_valid(owner._resolver)
		and is_instance_valid(owner._fielder)
	)


static func _kit_hot_operands(owner: StadiumSurfaceNightRuntime) -> bool:
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	if (
		not is_instance_valid(lab)
		or not is_instance_valid(owner._kit_lease)
		or not StadiumLightingKitNightCandidate.target_matches(owner._kit_profile, owner._viewport)
		or not owner._kit_lease.issued_owner_intact(owner)
		or (
			owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
			and not owner._restoring
			and not owner._kit_lease.active
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


static func _kit_action_intact(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	# Fresh issued receipt identity/current paid authority and required native lifetime.
	# No cached frame result; historical and native field manifests stay deep-only.
	return (
		owner._kit_mode
		and owner._phase == StadiumSurfaceNightRuntime.Phase.ACTIVE
		and not owner._restoring
		and not owner._tree_transition
		and not owner._palette_applying
		and owner._kit_issue_live
		and not owner._kit_issue_invalid
		and owner._kit_required_nodes_intact(lab)
		and owner._kit_hot_context(lab)
		and owner._kit_hot_operands()
	)


static func _kit_hot_property_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	# Issued native identities, not a per-action reflection/resource anti-cheat walk.
	if (
		not is_instance_valid(owner._property)
		or owner._property.is_queued_for_deletion()
		or owner._property.get_script() != StadiumPropertyGeometry
		or owner._property.transform != Transform3D.IDENTITY
		or owner._property.objects != owner._owned_property.objects
		or not owner._property._ground_props_family
		or not owner._property._props_live
		or owner._property.get_children(true) != owner._kit_children
		or owner._property.get_node_or_null("BoundaryGraph") != owner._boundary
	):
		return false
	var boundary: StadiumBoundaryOwnedRuntime = owner._boundary as StadiumBoundaryOwnedRuntime
	if (
		boundary == null
		or not boundary._live
		or not boundary._sealed
		or boundary._property != owner._property
		or not is_same(boundary.graph, owner._kit_boundary_graph)
	):
		return false
	# Native deletion is checked before deferred tree-exit signals. Parent/order,
	# rename and visibility edits synchronously latch the installation watcher.
	for row: StadiumSurfaceNightRuntime.KitBoundaryNodeSeal in owner._kit_collision_nodes:
		if not is_instance_valid(row.node) or row.node.is_queued_for_deletion():
			return false
	return true


static func _issue_kit_state(owner: StadiumSurfaceNightRuntime) -> bool:
	if (
		not owner._kit_mode
		or owner._kit_issue_ever
		or owner._phase != StadiumSurfaceNightRuntime.Phase.ACTIVE
		or owner._restoring
	):
		return false
	owner._kit_issue_ever = true  # Sticky even when preparation refuses; no in-place reissue.
	owner._property._lighting_fixture_sealed = true
	# Own a detached deeply read-only active receipt. No mutable historic source
	# container is represented as immutable. Serialized paid bytes remain equal.
	owner._kit_issued_receipt = StadiumSurfaceNightRuntime._kit_frozen_copy(owner._state.stadium)
	owner._state.stadium = owner._kit_issued_receipt
	owner._snapshot = StadiumSurfaceNightRuntime._kit_frozen_copy(owner._snapshot)
	owner._proof = StadiumSurfaceNightRuntime._kit_frozen_copy(owner._proof)
	owner._kit_profile = StadiumSurfaceNightRuntime._kit_frozen_copy(owner._kit_profile)
	owner._kit_physical_layout = StadiumSurfaceNightRuntime._kit_frozen_copy(
		owner._kit_physical_layout
	)
	if not owner._capture_kit_absence() or not owner._capture_kit_export():
		return false
	owner._kit_issue_refs = {
		"snapshot": owner._snapshot,
		"proof": owner._proof,
		"profile": owner._kit_profile,
		"physical": owner._kit_physical_layout,
		"physical_geometry": owner._kit_physical_geometry,
		"absence": owner._kit_absence_manifest,
		"export": owner._kit_export_manifest
	}
	owner._kit_issue_refs.make_read_only()
	owner._kit_authority = StadiumLightingKitIssuedAuthority.capture(
		owner._paid, owner._replay_paid, owner._season, owner._state, owner._kit_issued_receipt
	)
	if owner._kit_authority == null:
		return false
	owner._kit_boundary_graph = (owner._boundary as StadiumBoundaryOwnedRuntime).graph
	return _issue_kit_collision_state(owner)


static func _issue_kit_collision_state(owner: StadiumSurfaceNightRuntime) -> bool:
	var required: Dictionary = {}
	var seen: Dictionary = {}
	for node: Node in owner._property.find_children("*", "", true, false):
		if node is CollisionObject3D or node is CollisionShape3D or node is Light3D:
			if node is CollisionObject3D and not node is StaticBody3D:
				return false
			var ancestor: Node = node
			while ancestor != owner._property and ancestor != null:
				if ancestor != owner._boundary:
					if not ancestor is Node3D or ancestor.get_script() != null:
						return false
					required[ancestor] = true
				ancestor = ancestor.get_parent()
			if node is CollisionShape3D:
				if (
					node.shape == null
					or not StadiumFloodlightOwnedModels._capture_resource(
						node.shape, owner._kit_collision_resources, seen, 0, true
					)
				):
					return false
			if node is StaticBody3D and node.physics_material_override != null:
				if not StadiumFloodlightOwnedModels._capture_resource(
					node.physics_material_override, owner._kit_collision_resources, seen, 0, true
				):
					return false
	return _issue_kit_watches(owner, required)


static func _issue_kit_watches(owner: StadiumSurfaceNightRuntime, required: Dictionary) -> bool:
	for row: Dictionary in owner._kit_collision_resources:
		row["metadata"] = StadiumSurfaceNightRuntime._metadata(row.resource)
	for node: Node3D in [owner._property, owner._boundary]:
		var values: Dictionary = {}
		for field: StringName in [
			&"transform",
			&"top_level",
			&"visible",
			&"process_mode",
			&"visibility_parent",
			&"physics_interpolation_mode"
		]:
			values[field] = node.get(field)
		owner._kit_root_rows.append({"node": node, "values": values})
	for node: Node in required:
		owner._kit_collision_nodes.append(StadiumSurfaceNightRuntime.KitBoundaryNodeSeal.new(node))
	for seal: Dictionary in owner._property._infrastructure:
		for row: Dictionary in seal.rows:
			if row.node is Light3D:
				owner._kit_light_rows.append(row)
	if (
		owner._kit_collision_nodes.is_empty()
		or owner._kit_light_rows.size() != int(owner._kit_profile.composition.source_count)
	):
		return false
	# Tree/visibility changes invalidate synchronously. Native material setters do
	# not reliably signal; they are deliberately checked at full transitions.
	var nodes: Array[Node] = [owner._property]
	nodes.append_array(owner._property.find_children("*", "", true, false))
	for node: Node in nodes:
		for signal_name: StringName in [&"tree_exiting", &"child_order_changed", &"renamed"]:
			if not owner._watch_kit_signal(node, signal_name):
				return false
		if node is Node3D and not owner._watch_kit_signal(node, &"visibility_changed"):
			return false
	owner._kit_issue_live = true
	return not owner._kit_issue_invalid and owner._kit_hot_property_intact()


static func _watch_kit_signal(
	owner: StadiumSurfaceNightRuntime, node: Node, signal_name: StringName
) -> bool:
	var callback: Callable = owner._invalidate_kit_issue
	if not node.has_signal(signal_name) or node.is_connected(signal_name, callback):
		return false
	if node.connect(signal_name, callback) != OK:
		return false
	owner._kit_issue_watch.append(
		{"node": weakref(node), "signal": signal_name, "callback": callback}
	)
	return true


static func _invalidate_kit_issue(owner: StadiumSurfaceNightRuntime) -> void:
	# Synchronous latch only. Never mutate the tree reentrantly from a foreign signal.
	if owner._kit_issue_ever and not owner._restoring:
		owner._kit_issue_invalid = true


static func _revoke_kit_state(owner: StadiumSurfaceNightRuntime) -> void:
	owner._kit_issue_live = false
	owner._kit_issue_invalid = true
	for row: Dictionary in owner._kit_issue_watch:
		var node: Variant = row.node.get_ref()
		if is_instance_valid(node) and node.is_connected(row.signal, row.callback):
			node.disconnect(row.signal, row.callback)
	owner._kit_issue_watch.clear()


static func _kit_required_nodes_intact(owner: StadiumSurfaceNightRuntime, lab: PitchBatLab) -> bool:
	for value: Object in [
		lab,
		owner._host,
		owner._property,
		owner._boundary,
		owner._sun,
		owner._environment_owner,
		owner._camera,
		owner._pitch,
		owner._resolver,
		owner._fielder,
		owner._director,
		owner._tracking,
		owner._viewport,
		owner._kit_lease
	]:
		if not is_instance_valid(value) or (value is Node and value.is_queued_for_deletion()):
			return false
	return true


static func _kit_current_authority_intact(owner: StadiumSurfaceNightRuntime) -> bool:
	return (
		owner._kit_authority != null
		and owner._kit_authority.intact()
		and is_same(owner._snapshot, owner._kit_issue_refs.snapshot)
		and is_same(owner._proof, owner._kit_issue_refs.proof)
		and is_same(owner._kit_profile, owner._kit_issue_refs.profile)
		and is_same(owner._kit_physical_layout, owner._kit_issue_refs.physical)
		and owner._kit_physical_geometry == owner._kit_issue_refs.physical_geometry
	)


static func _capture_kit_absence(owner: StadiumSurfaceNightRuntime) -> bool:
	# Called once after complete receipt/composition/property admission. Frozen
	# source layout and actual installed models must BOTH prove absence. Retain
	# original metadata/container identities without freezing mutable source aliases.
	if (
		not owner._kit_mode
		or not owner._kit_absence_manifest.is_empty()
		or not is_instance_valid(owner._property)
	):
		return false
	for model: Variant in owner._property.objects.values():
		if (
			not is_instance_valid(model)
			or not model is Node3D
			or model.get_meta("stadium_item", "") == "ST-005"
			or StadiumLiveFurnishingItems.PRICES.has(model.get_meta("stadium_item", ""))
		):
			return false
	var specs: Dictionary = {
		&"live_furnishings": [&"live_furnishing_layout", &"live_furnishings"],
		&"salvage_car": [&"salvage_car_layout", &"salvage_cars"]
	}
	var result: Dictionary = {"objects": owner._property.objects}
	for feature: StringName in specs:
		var meta_key: StringName = specs[feature][0]
		var array_key: StringName = specs[feature][1]
		var physical: Variant = owner._kit_physical_layout.get(array_key)
		if (
			not physical is Array
			or not physical.is_empty()
			or not owner._property.has_meta(meta_key)
		):
			return false
		var metadata: Variant = owner._property.get_meta(meta_key)
		if not metadata is Dictionary:
			return false
		var placements: Variant = metadata.get(array_key)
		if not placements is Array or not placements.is_empty():
			return false
		var row: Dictionary = {
			"meta_key": meta_key,
			"array_key": array_key,
			"metadata": metadata,
			"placements": placements
		}
		row.make_read_only()
		result[feature] = row
	result.make_read_only()
	owner._kit_absence_manifest = result
	return true


static func _kit_feature_absent(
	owner: StadiumSurfaceNightRuntime, property: StadiumPropertyGeometry, feature: StringName
) -> bool:
	# Fresh exact owner check for EACH lookup, no per-frame/pass cache. This is
	# not a new admission route and never authorizes a nonempty feature handler.
	if (
		feature not in [&"live_furnishings", &"salvage_car"]
		or not owner._kit_mode
		or not is_instance_valid(property)
		or property != owner._property
		or not owner._kit_absence_manifest.is_read_only()
		or not owner._kit_absence_manifest.has(feature)
		or not is_same(owner._kit_issue_refs.get("absence"), owner._kit_absence_manifest)
		or not is_same(property.objects, owner._kit_absence_manifest.objects)
	):
		return false
	var row: Dictionary = owner._kit_absence_manifest[feature]
	if (
		not property.has_meta(row.meta_key)
		or not is_same(property.get_meta(row.meta_key), row.metadata)
		or not is_same(row.metadata.get(row.array_key), row.placements)
		or not row.placements.is_empty()
	):
		return false
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	return owner._kit_action_intact(lab)


static func _capture_kit_export(owner: StadiumSurfaceNightRuntime) -> bool:
	# Install-derived immutable DATA, not a reusable authorization result. Full
	# installed_bound admission has just proved this receipt and physical fixture.
	var lab: PitchBatLab = owner._lab.get_ref() if owner._lab != null else null
	if (
		not owner._kit_mode
		or not owner._kit_export_manifest.is_empty()
		or not is_instance_valid(lab)
		or not lab.has_meta("stadium_snapshot")
		or not owner._snapshot.is_read_only()
		or not owner._kit_issued_receipt.is_read_only()
	):
		return false
	var metadata: Variant = lab.get_meta("stadium_snapshot")
	if (
		not metadata is Dictionary
		or not is_same(metadata, owner._expected.metadata[&"stadium_snapshot"].value)
		or not StadiumSurfaceNightRuntime._kit_value_equal(metadata, owner._snapshot)
		or not StadiumSurfaceNightRuntime._kit_value_equal(
			owner._kit_issued_receipt, owner._snapshot
		)
	):
		return false
	var canonical_key: String = StadiumLayoutSnapshot.key(owner._snapshot)
	if canonical_key.is_empty():
		return false
	owner._kit_export_manifest = {
		"metadata": metadata,
		"receipt": owner._kit_issued_receipt,
		"snapshot": owner._snapshot,
		"key": canonical_key
	}
	owner._kit_export_manifest.make_read_only()
	return true


static func _public_issued_export_key(lab: PitchBatLab, snapshot: Dictionary) -> String:
	# Candidate3 only. Never a generic normalized/key cache or admission bypass.
	var owner: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.current(lab)
	if owner == null or owner.get_script() != StadiumSurfaceNightRuntime or not owner._kit_mode:
		return ""
	return owner._kit_export_key(lab, snapshot)


static func _kit_export_identity(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, snapshot: Dictionary
) -> bool:
	return (
		owner._kit_action_intact(lab)
		and owner._kit_export_manifest.is_read_only()
		and owner._kit_issue_refs.is_read_only()
		and is_same(owner._kit_issue_refs.get("export"), owner._kit_export_manifest)
		and is_same(owner._kit_export_manifest.get("receipt"), owner._kit_issued_receipt)
		and is_same(owner._kit_export_manifest.get("snapshot"), owner._snapshot)
		and is_same(snapshot, owner._kit_export_manifest.get("metadata"))
		and lab.has_meta("stadium_snapshot")
		and is_same(lab.get_meta("stadium_snapshot"), snapshot)
		and is_same(owner._state.stadium, owner._kit_issued_receipt)
		and owner._kit_export_manifest.get("key") is String
		and not owner._kit_export_manifest.key.is_empty()
	)


static func _kit_export_key(
	owner: StadiumSurfaceNightRuntime, lab: PitchBatLab, snapshot: Dictionary
) -> String:
	# One synchronous finalization proof, not a retained successful check. The
	# complete raw authority rows, native property, presentation/resources and full
	# native wall fields are compared now. Their unchanged admitted inputs imply
	# the same pure canonical receipt/key; no historical replay per derived field.
	# Metadata aliases are NOT claimed immutable: compare them to the detached
	# frozen receipt now. Replacement fails both before and after this scope.
	if (
		not owner._kit_export_identity(lab, snapshot)
		or not StadiumSurfaceNightRuntime._kit_value_equal(snapshot, owner._snapshot)
		or not owner._context(lab)
		or not owner._kit_operands()
		or not owner._kit_boundary_visuals_intact(true)
	):
		return ""
	return owner._kit_export_manifest.key if owner._kit_export_identity(lab, snapshot) else ""

extends RefCounted
## Stateless operations for the original StadiumGrandIIILightingV1 script.


static func _atlas_matches(viewport: Viewport, expected: Dictionary) -> bool:
	if (
		not is_instance_valid(viewport)
		or viewport.positional_shadow_atlas_size != expected.size
		or viewport.positional_shadow_atlas_16_bits != expected.precision
	):
		return false
	for index in range(4):
		if viewport.get_positional_shadow_atlas_quadrant_subdiv(index) != expected.quadrants[index]:
			return false
	return true


static func _time_children(state: Dictionary) -> Array:
	var children: Array = []
	for row: Dictionary in state.lights:
		children.append(row.node)
	for row: Dictionary in state.heads:
		children.append(row.glow)
	return children


static func _detached_time_root(root: Variant, children: Array) -> bool:
	if (
		not is_instance_valid(root)
		or root.get_parent() != null
		or root.get_script() != null
		or not root.get_meta_list().is_empty()
		or root.get_children(true) != children
	):
		return false
	for child: Variant in children:
		if (
			not is_instance_valid(child)
			or child.get_script() != null
			or child.get_child_count(true) != 0
			or not child.get_meta_list().is_empty()
		):
			return false
	return true


static func _discard_time_root(root: Variant, property: Variant, children: Array) -> void:
	if is_instance_valid(root) and is_instance_valid(property) and root.get_parent() == property:
		property.remove_child(root)
		if StadiumGrandIIILightingV1._detached_time_root(root, children):
			root.free()


static func _public_time_restored(lab: PitchBatLab, lease: Dictionary) -> bool:
	var state: Dictionary = StadiumGrandIIILightingV1._state(lab, lease)
	if (
		state.is_empty()
		or not state.get("time_profile", false)
		or not state.restored
		or lease != state
	):
		return false
	var entry: Dictionary = StadiumGrandIIILightingV1._issued[lab.get_instance_id()]
	return (
		not entry.restoring
		and lab._match_state == entry.match
		and is_instance_valid(state.property)
		and state.property.bound_state == entry.match
		and not is_instance_valid(state.root)
		and StadiumGrandIIILightingV1._time_cleanup_owner(
			lab, state.property, entry.match, state.viewport, entry.sun
		)
		and StadiumGrandIIILightingV1._atlas_matches(state.viewport, state.before)
	)


static func _public_diagnose_guards(guards: Array, stage: String) -> bool:
	for guard: Dictionary in guards:
		if StadiumGrandIIILightingV1.diagnose_values(guard.object, guard.keys, guard.values, stage):
			return true
	return false


static func _public_diagnose_values(
	object: Object, keys: Array, expected: Array, stage: String
) -> bool:
	if not is_instance_valid(object):
		print(
			"GRAND_III_TIME_INSTALL_OPERAND ",
			JSON.stringify(
				{"stage": stage, "field": "object_live", "actual": false, "expected": true}
			)
		)
		return true
	for index in range(keys.size()):
		var actual: Variant = object.get(keys[index])
		if actual != expected[index]:
			print(
				"GRAND_III_TIME_INSTALL_OPERAND ",
				JSON.stringify(
					{
						"stage": stage,
						"class": object.get_class(),
						"field": String(keys[index]),
						"actual_type": typeof(actual),
						"expected_type": typeof(expected[index]),
						"actual": var_to_str(actual).left(512),
						"expected": var_to_str(expected[index]).left(512)
					},
					"",
					true,
					true
				)
			)
			return true
	return false

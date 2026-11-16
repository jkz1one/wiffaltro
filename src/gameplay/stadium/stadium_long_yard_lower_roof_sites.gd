class_name StadiumLongYardLowerRoofSites
# gdlint: disable=max-returns
extends RefCounted
## Narrow lower-only compatibility. Does not widen any original or upper-roof admission.

const INTERFACE: String = "ST029-guard-v2_LOWER-CANOPY-v2"
const SITES: Array[String] = ["BASE-L2", "BASE-R2"]
const T = preload("res://src/gameplay/stadium/stadium_transition_concourse_sites.gd")


static func valid_lower(lower: Node3D, site: String, camera_enrolled: bool = false) -> bool:
	if site not in StadiumBaselineSites.SITES or not _pose(lower, site):
		return false
	var state: Variant = lower.get_meta("assembly_state", "BASE-LOWER-v1")
	if typeof(state) != TYPE_STRING or state != "BASE-LOWER-v1":
		return false
	for forbidden: String in ["lower_instance", "upper_instance", "concourse_instance", "interface"]:
		if lower.has_meta(forbidden):
			return false
	var expected: Node3D = StadiumBaselineSightlineModels.lower()
	if expected == null:
		return false
	var valid: bool = _matches(lower, expected, camera_enrolled)
	expected.free()
	return valid


static func valid_roof(
	lower: Node3D, roof: Node3D, site: String, camera_enrolled: bool = false
) -> bool:
	if site not in SITES or not valid_lower(lower, site, camera_enrolled) or not _pose(roof, site):
		return false
	if roof.get_parent() != lower.get_parent() or not T.meta_matches(
		roof, "lower_instance", lower.get_instance_id()
	):
		return false
	if not T.meta_matches(roof, "site", site) or not T.meta_matches(roof, "interface", INTERFACE):
		return false
	for forbidden: String in ["upper_instance", "concourse_instance", "assembly_state", "roof_state"]:
		if roof.has_meta(forbidden):
			return false
	var expected: Node3D = StadiumLongYardLowerRoofModels.canopy_reference()
	if expected == null:
		return false
	var valid: bool = _matches(roof, expected, camera_enrolled)
	expected.free()
	return valid and supported(lower, roof) and vacant(lower, roof, site)


static func vacant(lower: Node3D, roof: Node3D, site: String) -> bool:
	if not is_instance_valid(lower) or lower.get_parent() == null or site not in SITES:
		return false
	for child: Node in lower.get_parent().get_children():
		if child == lower or child == roof:
			continue
		var item: Variant = child.get_meta("stadium_item", "")
		if typeof(item) != TYPE_STRING:
			return false
		for key: String in ["site", "candidate_site"]:
			if child.has_meta(key) and typeof(child.get_meta(key)) != TYPE_STRING:
				return false
		if child.has_meta("lower_instance") and typeof(child.get_meta("lower_instance")) != TYPE_INT:
			return false
		if item in ["ST-030", "ST-031", "ST-055", "ST-057"]:
			return false
		if T.meta_matches(child, "lower_instance", lower.get_instance_id()):
			return false
		if T.meta_matches(child, "site", site) or (
			child.get_meta("candidate_site", "") in [site, "ROOF:" + site]
		):
			return false
		if child is Node3D and child.transform == StadiumBaselineSites.pose(site):
			return false
	return true


static func _pose(piece: Node3D, site: String) -> bool:
	if not is_instance_valid(piece) or not piece.is_inside_tree() or piece.get_script() != null:
		return false
	var parent: Node3D = piece.get_parent() as Node3D
	return parent != null and parent.global_transform == Transform3D.IDENTITY \
		and piece.transform == StadiumBaselineSites.pose(site) \
		and piece.global_transform == StadiumBaselineSites.pose(site) \
		and not piece.top_level and piece.is_visible_in_tree() and piece.can_process()


static func _matches(actual: Node3D, reference: Node3D, camera_enrolled: bool) -> bool:
	if reference == null or actual.get_class() != reference.get_class() \
		or actual.process_mode != reference.process_mode:
		return false
	for key: StringName in reference.get_meta_list():
		if not T.meta_matches(actual, key, reference.get_meta(key)):
			return false
	if camera_enrolled:
		for body: StaticBody3D in reference.find_children("*", "StaticBody3D", true, false):
			body.collision_layer |= StadiumClubPropertyGeometry.CAMERA_LAYER
	var signature: String = T.geometry_signature(actual, reference)
	return not signature.is_empty() and signature == T.geometry_signature(reference, reference)


static func supported(lower: Node3D, roof: Node3D) -> bool:
	# Cover every cell of each actual post footprint partitioned by lower-solid edges,
	# not merely its center. The only tolerance is10micrometers for float32 arithmetic.
	if not is_instance_valid(lower) or not is_instance_valid(roof):
		return false
	var collision: Node3D = lower.get_node_or_null("Collision") as Node3D
	if collision == null:
		return false
	for side: int in [-1, 1]:
		var node: StaticBody3D = (
			roof.get_node_or_null("Collision/RearColumn" + str(side)) as StaticBody3D
		)
		if node == null or node.get_child_count() != 1:
			return false
		var shape: CollisionShape3D = node.get_child(0) as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D or shape.disabled:
			return false
		var bounds: AABB = node.transform * shape.transform * AABB(
			-shape.shape.size / 2, shape.shape.size
		)
		var surfaces: Array[AABB] = []
		var xs: Array[float] = [bounds.position.x, bounds.end.x]
		var zs: Array[float] = [bounds.position.z, bounds.end.z]
		for child: Node in collision.get_children():
			if not child is StaticBody3D or child.get_child_count() != 1:
				return false
			var body: StaticBody3D = child as StaticBody3D
			if not String(body.name).begins_with("SolidRow") \
				and not String(body.name).begins_with("EntryStep"):
				continue
			var solid: CollisionShape3D = body.get_child(0) as CollisionShape3D
			if solid == null or not solid.shape is BoxShape3D or solid.disabled:
				return false
			var deck: AABB = body.transform * solid.transform * AABB(
				-solid.shape.size / 2, solid.shape.size
			)
			if deck.end.y < bounds.position.y - 0.00001 \
				or deck.end.y > bounds.position.y + 0.15001:
				continue
			surfaces.append(deck)
			for x: float in [deck.position.x, deck.end.x]:
				if x > bounds.position.x and x < bounds.end.x:
					xs.append(x)
			for z: float in [deck.position.z, deck.end.z]:
				if z > bounds.position.z and z < bounds.end.z:
					zs.append(z)
		xs.sort()
		zs.sort()
		for x_index in range(xs.size() - 1):
			for z_index in range(zs.size() - 1):
				var center: Vector2 = Vector2(
					(xs[x_index] + xs[x_index + 1]) / 2,
					(zs[z_index] + zs[z_index + 1]) / 2
				)
				var found: bool = false
				for deck: AABB in surfaces:
					if center.x >= deck.position.x and center.x <= deck.end.x \
						and center.y >= deck.position.z and center.y <= deck.end.z:
						found = true
				if not found:
					return false
	return true

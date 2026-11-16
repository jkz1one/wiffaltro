class_name StadiumGrandThreeStackSites
extends RefCounted
## Additive guard-v2 stack and adjacent-roof contracts. Frozen admission stays unchanged.

const INTERFACE: String = "ST029-guard-v2_REAR-STAIR-SADDLE-v2"
const UPPER_INTERFACE: String = "ST031-guard-v2_STRAIGHT-CANTILEVER-v2"
const ROOF_INTERFACE: String = "ST030-guard-v2_PYLON-CAP-v2"
const TRANSITION_INTERFACE: String = "JOIN-v1_GUARD-v2_UPPER-ROOFS-v2"
const BOUNDS: AABB = AABB(Vector3(-3, 0, 0), Vector3(6, 13.65, 10))
const T = preload("res://src/gameplay/stadium/stadium_transition_concourse_sites.gd")
const L = preload("res://src/gameplay/stadium/stadium_lower_transition_sites.gd")
const MODEL_KEYS: Array[StringName] = [
	&"stadium_item", &"model_version", &"model_variant", &"authoring_status",
	&"represented_seats", &"baseline_end", &"access", &"roof_state", &"candidate_mount"
]
const BINDINGS: Array[StringName] = [
	&"lower_instance", &"concourse_instance", &"upper_instance", &"bowl_instance",
	&"curved_concourse_instance", &"baseline_instance", &"straight_concourse_instance"
]


static func fits(site: String, land: String) -> bool:
	return site in StadiumBaselineSites.SITES and land in ["club", "mogul"] \
		and StadiumProperty.contains(land, StadiumBaselineSites.pose(site) * BOUNDS)


static func valid_lower(lower: Node3D, site: String) -> bool:
	return site in StadiumBaselineSites.SITES \
		and _pose(lower, StadiumBaselineSites.pose(site)) \
		and _matches(lower, "ST-029", site) and _straight_state(lower)


static func valid_concourse(lower: Node3D, concourse: Node3D, site: String) -> bool:
	return valid_lower(lower, site) \
		and _layer(concourse, lower, "ST-031", site, INTERFACE)


static func valid_upper(lower: Node3D, concourse: Node3D, upper: Node3D,
	site: String) -> bool:
	return valid_concourse(lower, concourse, site) \
		and _straight_upper(lower, concourse, upper, site)


static func valid_roof(lower: Node3D, concourse: Node3D, upper: Node3D,
	roof: Node3D, site: String) -> bool:
	return valid_upper(lower, concourse, upper, site) \
		and _straight_roof(lower, concourse, upper, roof, site)


static func _straight_upper(lower: Node3D, concourse: Node3D, upper: Node3D,
	site: String) -> bool:
	return _layer(upper, lower, "ST-030", site, UPPER_INTERFACE) \
		and T.meta_matches(upper, "concourse_instance", concourse.get_instance_id())


static func _straight_roof(lower: Node3D, concourse: Node3D, upper: Node3D,
	roof: Node3D, site: String) -> bool:
	return _layer(roof, lower, "ST-053", site, ROOF_INTERFACE) \
		and T.meta_matches(roof, "concourse_instance", concourse.get_instance_id()) \
		and T.meta_matches(roof, "upper_instance", upper.get_instance_id())


static func _layer(piece: Node3D, lower: Node3D, id: String, site: String,
	interface: String, curved: bool = false) -> bool:
	var pose: Transform3D = StadiumCurvedLowerSites.pose(site) if curved \
		else StadiumBaselineSites.pose(site)
	return is_instance_valid(piece) and piece.get_parent() == lower.get_parent() \
		and _pose(piece, pose) and _bound(piece, lower, site, interface) \
		and _matches(piece, id, site)


static func _bound(piece: Node3D, lower: Node3D, site: String, interface: String) -> bool:
	return T.meta_matches(piece, "lower_instance", lower.get_instance_id()) \
		and T.meta_matches(piece, "site", site) and T.meta_matches(piece, "interface", interface)


static func vacant(lower: Node3D, site: String, allowed: Array[Node3D]) -> bool:
	# Callers separately prove every allowed host. An unknown related occupant never
	# becomes legal through item labels, missing bindings, or a different model version.
	if not is_instance_valid(lower) or not lower.is_inside_tree() \
		or site not in StadiumBaselineSites.SITES or lower not in allowed:
		return false
	for piece: Node3D in allowed:
		if not is_instance_valid(piece) or piece.get_parent() != lower.get_parent():
			return false
	var sites: Array[String] = [site]
	var poses: Array[Transform3D] = [StadiumBaselineSites.pose(site)]
	for child: Node in lower.get_parent().get_children():
		if child is Node3D and child in allowed:
			continue
		# A genuine neighboring JOIN uses another lower and another site. Its explicit
		# baseline dependency is not a second occupant of this independent BASE bay.
		if _related(child, sites, poses, allowed, false):
			return false
	return _straight_state(lower)


static func valid_transition_hosts(site: String, join: Node3D, bowl: Node3D,
	curved: Node3D, base: Node3D, straight: Node3D) -> bool:
	if site not in T.SITES or not _pose(join, Transform3D.IDENTITY):
		return false
	for host: Node3D in [bowl, curved, base, straight]:
		if not is_instance_valid(host) or host.get_parent() != join.get_parent():
			return false
	var bowl_site: String = T.bowl_site(site)
	if not _matches(join, L.item(site), site) \
		or not _pose(bowl, StadiumCurvedLowerSites.pose(bowl_site)) \
		or not _matches(bowl, "ST-081", bowl_site) \
		or not _curved_state(bowl) \
		or not _layer(curved, bowl, "ST-083", bowl_site,
			StadiumCurvedStackSites.INTERFACE, true) \
		or not valid_concourse(base, straight, T.base_site(site)):
		return false
	return _transition_neighbors(site, join, bowl, curved, base, straight)


static func _transition_neighbors(site: String, join: Node3D, bowl: Node3D,
	curved: Node3D, base: Node3D, straight: Node3D) -> bool:
	var hosts: Array[Node3D] = [join, bowl, curved, base, straight]
	var sites: Array[String] = [site, T.bowl_site(site), T.base_site(site)]
	var poses: Array[Transform3D] = [bowl.transform, base.transform]
	var neighbors: Dictionary = {}
	for child: Node in join.get_parent().get_children():
		if child is Node3D and child in hosts:
			continue
		var id: Variant = child.get_meta("stadium_item", "")
		var related: bool = _related(child, sites, poses, hosts) \
			or T.same_value(id, L.item(site)) or T.same_value(id, T.item(site))
		if not related:
			continue
		if not child is Node3D or typeof(id) != TYPE_STRING \
			or id not in ["ST-082", "ST-030", "ST-084", "ST-053"] or neighbors.has(id):
			return false
		neighbors[id] = child
	# Also catch a malformed duplicate which claims only a genuine upper/roof ID,
	# even if it omits its lower/site and has been moved away from the normal pose.
	var known: Array[Node3D] = hosts.duplicate()
	for child: Node3D in neighbors.values():
		known.append(child)
	for child: Node in join.get_parent().get_children():
		if (not child is Node3D or child not in known) \
			and _related(child, sites, poses, known):
			return false
	return _validate_neighbors(neighbors, bowl, curved, base, straight, site)


static func _validate_neighbors(neighbors: Dictionary, bowl: Node3D, curved: Node3D,
	base: Node3D, straight: Node3D, site: String) -> bool:
	var bowl_site: String = T.bowl_site(site)
	var base_site: String = T.base_site(site)
	var curved_upper: Node3D = neighbors.get("ST-082") as Node3D
	var straight_upper: Node3D = neighbors.get("ST-030") as Node3D
	if curved_upper != null and not _curved_upper(bowl, curved, curved_upper, bowl_site):
		return false
	if straight_upper != null \
		and not _straight_upper(base, straight, straight_upper, base_site):
		return false
	if neighbors.has("ST-084"):
		var roof: Node3D = neighbors["ST-084"] as Node3D
		if curved_upper == null or not _layer(roof, bowl, "ST-084", bowl_site,
			StadiumCurvedCanopySites.INTERFACE, true) \
			or not T.meta_matches(roof, "concourse_instance", curved.get_instance_id()) \
			or not T.meta_matches(roof, "upper_instance", curved_upper.get_instance_id()):
			return false
	if neighbors.has("ST-053") and (straight_upper == null \
		or not _straight_roof(base, straight, straight_upper,
			neighbors["ST-053"] as Node3D, base_site)):
		return false
	return true


static func _curved_upper(lower: Node3D, concourse: Node3D, upper: Node3D,
	site: String) -> bool:
	return _layer(upper, lower, "ST-082", site, StadiumCurvedStackSites.UPPER_INTERFACE, true) \
		and T.meta_matches(upper, "concourse_instance", concourse.get_instance_id())


static func _related(node: Node, sites: Array[String], poses: Array[Transform3D],
	hosts: Array[Node3D], all_bindings: bool = true) -> bool:
	var declared_site: Variant = node.get_meta("site", "")
	if typeof(declared_site) == TYPE_STRING and declared_site in sites:
		return true
	for key: StringName in BINDINGS:
		if not all_bindings and key not in [&"lower_instance", &"concourse_instance", &"upper_instance"]:
			continue
		var binding: Variant = node.get_meta(key, 0)
		if typeof(binding) != TYPE_INT:
			continue
		for host: Node3D in hosts:
			if binding == host.get_instance_id():
				return true
	# Exact structural frames belong to one explicitly enumerated assembly, even
	# when an impostor deletes or corrupts every identifying metadata field.
	if node is Node3D:
		for pose: Transform3D in poses:
			if node.transform.is_equal_approx(pose) or node.global_transform.is_equal_approx(pose):
				return true
	return false


static func _pose(piece: Node3D, expected: Transform3D) -> bool:
	if not is_instance_valid(piece) or not piece.is_inside_tree() \
		or piece.get_script() != null or piece.top_level or not piece.is_visible_in_tree() \
		or not piece.can_process() or not piece.transform.is_finite() \
		or not piece.global_transform.is_finite():
		return false
	var parent: Node3D = piece.get_parent() as Node3D
	return parent != null and parent.global_transform == Transform3D.IDENTITY \
		and piece.transform == expected and piece.global_transform == expected


static func _straight_state(lower: Node3D) -> bool:
	var state: Variant = lower.get_meta("assembly_state", "BASE-LOWER-v1")
	return typeof(state) == TYPE_STRING and state in ["BASE-LOWER-v1", "BASE-CONCOURSE-v1",
		"BASE-UPPER-v1", "BASE-UPPER-ROOF-v1"]


static func _curved_state(lower: Node3D) -> bool:
	var state: Variant = lower.get_meta("assembly_state", "BOWL-LOWER-v1")
	return typeof(state) == TYPE_STRING and state in ["BOWL-LOWER-v1", "BOWL-CONCOURSE-v1",
		"BOWL-UPPER-v1", "BOWL-UPPER-ROOF-v1"]


static func _matches(actual: Node3D, id: String, site: String) -> bool:
	if not is_instance_valid(actual) or not T.meta_matches(actual, "stadium_item", id) \
		or not _role_metadata(actual, id, site):
		return false
	for occupied: bool in [false, true]:
		var reference: Node3D = _reference(id, site, occupied)
		if reference == null:
			return false
		var valid: bool = actual.get_class() == reference.get_class() \
			and actual.process_mode == reference.process_mode \
			and actual.visible == reference.visible and actual.top_level == reference.top_level \
			and _execution(actual, reference)
		for key: StringName in MODEL_KEYS:
			if actual.has_meta(key) != reference.has_meta(key):
				valid = false
		for key: StringName in reference.get_meta_list():
			if not T.meta_matches(actual, key, reference.get_meta(key)):
				valid = false
		var signature: String = T.geometry_signature(actual, reference)
		valid = valid and not signature.is_empty() \
			and signature == T.geometry_signature(reference, reference)
		reference.free()
		if valid:
			return true
	return false


static func _role_metadata(actual: Node3D, id: String, site: String) -> bool:
	# Existing candidate annotations are harmless; structural metadata cannot invent
	# an attachment role the canonical model never supplies.
	if actual.has_meta("assembly_state") and id not in ["ST-029", "ST-081"]:
		return false
	if actual.has_meta("site") and not T.meta_matches(actual, "site", site):
		return false
	var allowed: Array[StringName] = []
	if id in ["ST-031", "ST-030", "ST-053", "ST-083", "ST-082", "ST-084"]:
		allowed.assign([&"lower_instance", &"interface"])
	if id in ["ST-030", "ST-053", "ST-082", "ST-084"]:
		allowed.append(&"concourse_instance")
	if id in ["ST-053", "ST-084"]:
		allowed.append(&"upper_instance")
		allowed.append(&"roof_state")
	if id == "ST-053":
		allowed.append(&"candidate_mount")
	for key: StringName in BINDINGS + [&"interface", &"roof_state", &"candidate_mount"]:
		if actual.has_meta(key) and key not in allowed:
			return false
	return true


static func _execution(node: Node, reference: Node) -> bool:
	if node.get_script() != null or not node.can_process() \
		or node.get_class() != reference.get_class() \
		or node.get_child_count() != reference.get_child_count():
		return false
	if node is CollisionShape3D:
		var shape_reference: CollisionShape3D = reference as CollisionShape3D
		if shape_reference == null or not _shape_matches(node.shape, shape_reference.shape):
			return false
	for index in range(node.get_child_count()):
		if not _execution(node.get_child(index), reference.get_child(index)):
			return false
	return true


static func _shape_matches(actual: Shape3D, reference: Shape3D) -> bool:
	# The frozen mesh/hull signature is retained verbatim. This additive check proves
	# every stored collider property as well, including custom_solver_bias and any
	# metadata, and rejects attached or nested unsupported resource behavior.
	if actual == null or reference == null or actual.get_class() != reference.get_class() \
		or actual.get_script() != null:
		return false
	var keys: Array[StringName] = actual.get_meta_list()
	var canonical_keys: Array[StringName] = reference.get_meta_list()
	keys.sort()
	canonical_keys.sort()
	if keys != canonical_keys:
		return false
	for key: StringName in keys:
		if not T.same_value(actual.get_meta(key), reference.get_meta(key)):
			return false
	for property: Dictionary in reference.get_property_list():
		var key: StringName = property.name
		if not (int(property.usage) & PROPERTY_USAGE_STORAGE) \
			or key in [&"resource_name", &"resource_path", &"resource_scene_unique_id"]:
			continue
		var value: Variant = actual.get(key)
		var canonical: Variant = reference.get(key)
		if value is Resource or canonical is Resource or not T.same_value(value, canonical):
			return false
	return true


static func _reference(id: String, site: String, occupied: bool) -> Node3D:
	match id:
		"ST-029": return StadiumBaselineSightlineModels.lower(occupied)
		"ST-031": return StadiumGrandThreeStackModels._concourse()
		"ST-030": return StadiumGrandThreeStackModels._upper(occupied)
		"ST-053": return StadiumGrandThreeStackModels._roof()
		"ST-081": return StadiumCurvedLowerModels.create(occupied)
		"ST-083": return StadiumCurvedStackModels._concourse()
		"ST-082": return StadiumCurvedStackModels._upper(occupied)
		"ST-084": return StadiumGrandThreeStackModels._curved_roof_reference()
		"ST-085", "ST-088":
			return StadiumLowerTransitionModels.create_right(occupied) if site == "JOIN-R" \
				else StadiumLowerTransitionModels.create_left(occupied)
	return null

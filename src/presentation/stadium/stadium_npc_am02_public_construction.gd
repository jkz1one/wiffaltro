class_name StadiumNpcAm02PublicConstruction
extends RefCounted
## Cold AM-02/r1 checks against the exact 91-copy Left Loft construction.
## Keeps tall-wall art, stack supports, dormant rays and every retained transform intact.
# gdlint: disable=max-returns

const WORKING_MODELS: Dictionary = {
	"npc:AM-02:r1:BASE-L1": ["ST-029", 2, "BASE-LOWER-SIGHTLINE-v2"],
	"npc:AM-02:r1:BASE-L1.CONCOURSE": ["ST-031", 2, "STRAIGHT-CONCOURSE-GUARD-v2"],
	"npc:AM-02:r1:BASE-L1.UPPER": ["ST-030", 2, "STRAIGHT-UPPER-GUARD-v2"],
	"npc:AM-02:r1:BASE-L1.ROOF-UPPER": ["ST-053", 2, "STRAIGHT-UPPER-CANOPY-v2"],
	"npc:AM-02:r1:BASE-L2": ["ST-029", 2, "BASE-LOWER-SIGHTLINE-v2"],
	"npc:AM-02:r1:BASE-L2.CONCOURSE": ["ST-031", 2, "STRAIGHT-CONCOURSE-GUARD-v2"],
	"npc:AM-02:r1:BASE-L2.UPPER": ["ST-030", 2, "STRAIGHT-UPPER-GUARD-v2"],
	"npc:AM-02:r1:BASE-L2.ROOF-UPPER": ["ST-053", 2, "STRAIGHT-UPPER-CANOPY-v2"],
	"npc:AM-02:r1:BASE-R1": ["ST-029", 2, "BASE-LOWER-SIGHTLINE-v2"],
	"npc:AM-02:r1:BASE-R1.CONCOURSE": ["ST-031", 2, "STRAIGHT-CONCOURSE-GUARD-v2"],
	"npc:AM-02:r1:BASE-R1.UPPER": ["ST-030", 2, "STRAIGHT-UPPER-GUARD-v2"],
	"npc:AM-02:r1:BASE-R1.ROOF-UPPER": ["ST-053", 2, "STRAIGHT-UPPER-CANOPY-v2"],
	"npc:AM-02:r1:BASE-R2": ["ST-029", 2, "BASE-LOWER-SIGHTLINE-v2"],
	"npc:AM-02:r1:BASE-R2.CONCOURSE": ["ST-031", 2, "STRAIGHT-CONCOURSE-GUARD-v2"],
	"npc:AM-02:r1:BASE-R2.UPPER": ["ST-030", 2, "STRAIGHT-UPPER-GUARD-v2"],
	"npc:AM-02:r1:BASE-R2.ROOF-UPPER": ["ST-053", 2, "STRAIGHT-UPPER-CANOPY-v2"],
	"npc:AM-02:r1:BOWL-01": ["ST-081", 1, ""],
	"npc:AM-02:r1:BOWL-02": ["ST-081", 1, ""],
	"npc:AM-02:r1:BOWL-03": ["ST-081", 1, ""],
	"npc:AM-02:r1:BOWL-04": ["ST-081", 1, ""],
	"npc:AM-02:r1:BOWL-05": ["ST-081", 1, ""],
	"npc:AM-02:r1:JOIN-R": ["ST-085", 1, ""],
	"npc:AM-02:r1:JOIN-L": ["ST-088", 1, ""]
}
const BASE_SITES: Array[String] = ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]
const SUPPORT_LINKS: Dictionary = {
	"lower_instance": "", "concourse_instance": ".CONCOURSE", "upper_instance": ".UPPER"
}


static func normalize_status_labels(property: StadiumNpcPublicProperty) -> bool:
	if property == null or property.venue_id != "AM-02" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumNpcMogulTwoV1 \
		or property.is_inside_tree() or property.objects.size() != 91 \
		or property.objects != property.construction.objects:
		return false
	for identity: String in WORKING_MODELS:
		if not _working_model(property, identity) \
			or not _exact_meta(property.objects[identity], "authoring_status", "Working"):
			return false
	# Validate the actual set of labeled nodes before touching any one of the 23 labels.
	for node: Node in property.find_children("*", "", true, false):
		if node.has_meta("authoring_status"):
			if not node.has_meta("npc_instance"):
				return false
			var identity: Variant = node.get_meta("npc_instance")
			if not identity is String or not WORKING_MODELS.has(identity) \
				or property.objects.get(identity) != node:
				return false
	if not _supports(property):
		return false
	for identity: String in WORKING_MODELS:
		property.objects[identity].remove_meta("authoring_status")
	# All private/raw origin markers still fail the unchanged shared checker.
	return StadiumMountedScoreboardContract._clean_tree(property)


static func _exact_meta(node: Node, key: String, expected: Variant) -> bool:
	return node.has_meta(key) and typeof(node.get_meta(key)) == typeof(expected) \
		and node.get_meta(key) == expected


static func _working_model(property: StadiumNpcPublicProperty, identity: String) -> bool:
	var model: Node3D = property.objects.get(identity)
	var expected: Array = WORKING_MODELS[identity]
	return is_instance_valid(model) and model.get_parent() == property.construction \
		and model.get_script() == null and _exact_meta(model, "npc_instance", identity) \
		and _exact_meta(model, "npc_site", identity.get_slice(":", 3)) \
		and _exact_meta(model, "npc_host", "field") \
		and _exact_meta(model, "stadium_item", expected[0]) \
		and _exact_meta(model, "model_version", expected[1]) \
		and model.has_meta("model_variant") == (not String(expected[2]).is_empty()) \
		and (String(expected[2]).is_empty() or _exact_meta(model, "model_variant", expected[2]))


static func _supports(property: StadiumNpcPublicProperty) -> bool:
	for site: String in BASE_SITES:
		var prefix: String = StadiumNpcMogulTwoV1.INSTANCE_PREFIX + site
		var lower: Node3D = property.objects.get(prefix)
		var concourse: Node3D = property.objects.get(prefix + ".CONCOURSE")
		var upper: Node3D = property.objects.get(prefix + ".UPPER")
		var roof: Node3D = property.objects.get(prefix + ".ROOF-UPPER")
		if not is_instance_valid(lower) or not is_instance_valid(concourse) \
			or not is_instance_valid(upper) or not is_instance_valid(roof) \
			or not _exact_meta(lower, "site", site) \
			or not _exact_meta(lower, "assembly_state", "BASE-UPPER-ROOF-v1"):
			return false
		for row: Array in [[concourse, "ST029-guard-v2_REAR-STAIR-SADDLE-v2"],
			[upper, "ST031-guard-v2_STRAIGHT-CANTILEVER-v2"],
			[roof, "ST030-guard-v2_PYLON-CAP-v2"]]:
			var layer: Node3D = row[0]
			if layer.get_parent() != property.construction or layer.transform != lower.transform \
				or not _exact_meta(layer, "lower_instance", lower.get_instance_id()) \
				or not _exact_meta(layer, "site", site) \
				or not _exact_meta(layer, "interface", row[1]):
				return false
		if not _exact_meta(upper, "concourse_instance", concourse.get_instance_id()) \
			or not _exact_meta(roof, "concourse_instance", concourse.get_instance_id()) \
			or not _exact_meta(roof, "upper_instance", upper.get_instance_id()) \
			or not _exact_meta(roof, "candidate_mount", "BASE-UPPER-ROOF-v1") \
			or not _exact_meta(roof, "roof_state", "BASE-UPPER-ROOF-v1") \
			or lower.has_meta("lower_instance") or concourse.has_meta("concourse_instance") \
			or concourse.has_meta("upper_instance") or upper.has_meta("upper_instance"):
			return false
	return true


static func _distinct_metadata(property: StadiumNpcPublicProperty) -> bool:
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		var item: String = model.get_meta("stadium_item", "")
		var site: String = model.get_meta("npc_site", "")
		if item in ["ST-065", "ST-065-T"]:
			if not _exact_meta(model, "art_only", true) \
				or not _exact_meta(model, "height_study_version", 1) \
				or not _exact_meta(model, "wall_item", "ST-065"):
				return false
		elif item == "ST-076":
			if not StadiumNpcMogulTwoTowerSitesV1.SITES.has(site) \
				or not _exact_meta(model, "geometry_version", 1) \
				or not _exact_meta(model, "night_qualified", false) \
				or not _exact_meta(model, "working_geometry_only", true) \
				or not _exact_meta(model, "obstacle_units", 0) \
				or not _exact_meta(model, "site", site) \
				or not _exact_meta(model, "candidate_preset", StadiumNpcMogulTwoTowerSitesV1.PRESET) \
				or not _exact_meta(model, "aim_profile", StadiumNpcMogulTwoTowerSitesV1.PROFILE) \
				or not _exact_meta(model, "reference_target", StadiumNpcMogulTwoTowerSitesV1.TARGETS[site]):
				return false
		elif item in ["ST-085", "ST-088"]:
			if not _exact_meta(model, "site", site) or not _exact_meta(model, "baseline_end",
				"stair" if item == "ST-085" else "solid"):
				return false
		elif item == "ST-021":
			var cap: float = 4.875 if site == "FOUL-POLE-L" else 3.25
			var body: StaticBody3D = model.get_node_or_null("Collision/Pole") as StaticBody3D
			if body == null or not _exact_meta(model, "wall_cap_height", cap) \
				or not _exact_meta(body, "wall_cap_height", cap):
				return false
	return true


static func valid(property: StadiumNpcPublicProperty) -> bool:
	var definition: Dictionary = StadiumNpcMogulTwoCandidateV1.definition()
	if property == null or property.venue_id != "AM-02" or property.field == null \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumNpcMogulTwoV1 \
		or not StadiumMountedScoreboardContract._clean_tree(property) \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.objects.size() != 91 or definition.instances.size() != 91 \
		or property.construction.objects != property.objects:
		return false
	for key: String in StadiumNpcMogulTwoV1.FIELD:
		# DefinitionBase stores only id as StringName; retained FIELD literals stay unchanged.
		var expected_type: int = TYPE_STRING_NAME if key == "id" else (
			typeof(StadiumNpcMogulTwoV1.FIELD[key]))
		if typeof(property.field.get(key)) != expected_type \
			or property.field.get(key) != StadiumNpcMogulTwoV1.FIELD[key]:
			return false
	for identity: String in WORKING_MODELS:
		if not _working_model(property, identity) \
			or property.objects[identity].has_meta("authoring_status"):
			return false
	var identities: Dictionary = {}
	var counts: Dictionary = {}
	for row: Dictionary in definition.instances:
		var model: Node3D = property.objects.get(row.instance)
		if not is_instance_valid(model) or not property.construction.is_ancestor_of(model) \
			or not _exact_meta(model, "npc_instance", row.instance) \
			or not _exact_meta(model, "owned_copy", row.instance) \
			or not _exact_meta(model, "npc_host", row.host) \
			or not _exact_meta(model, "npc_site", row.site) \
			or not _exact_meta(model, "stadium_item", row.item) \
			or model.transform != StadiumNpcMogulTwoContractV1.transform(row.transform):
			return false
		if row.host != "field" and model.get_parent() != property.objects.get(row.host):
			return false
		identities[row.instance] = model
		counts[row.item] = int(counts.get(row.item, 0)) + 1
	if counts != StadiumNpcMogulTwoV1.COUNTS or not _supports(property) \
		or not _distinct_metadata(property):
		return false
	for node: Node in property.find_children("*", "", true, false):
		if node is Light3D:
			return false
		for key: String in ["npc_instance", "owned_copy"]:
			if node.has_meta(key) and not identities.has(node.get_meta(key)):
				return false
		if node.has_meta("npc_instance") and node.has_meta("owned_copy") \
			and node.get_meta("npc_instance") != node.get_meta("owned_copy"):
			return false
	return true


static func _metadata(node: Node, property: StadiumNpcPublicProperty) -> Dictionary:
	# Compare every actual retained metadata key/value. Only validated support ObjectIDs
	# become their stable copy identity; receiver visibility has its existing bounded policy.
	var result: Dictionary = {"meta": {}, "children": []}
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		if key == &"receiver_render_state" and node in [property.receiver.chair, property.receiver.net]:
			continue
		var value: Variant = node.get_meta(key)
		if SUPPORT_LINKS.has(String(key)):
			var identity: String = node.get_meta("npc_instance", "")
			if property.objects.get(identity) == node:
				value = StadiumNpcMogulTwoV1.INSTANCE_PREFIX \
					+ String(node.get_meta("npc_site", "")).get_slice(".", 0) + SUPPORT_LINKS[String(key)]
		result.meta[String(key)] = value
	for child: Node in node.get_children():
		result.children.append(_metadata(child, property))
	return result


static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty) -> bool:
	# Same exact retained Club flex reproduction, with the public AM-02 receiver type.
	var receiver: StadiumNpcAm02PublicReceiver = actual.receiver as StadiumNpcAm02PublicReceiver
	var reference: StadiumNpcAm02PublicReceiver = expected.receiver as StadiumNpcAm02PublicReceiver
	if receiver == null or reference == null \
		or receiver._rest_meshes.keys() != reference._rest_meshes.keys():
		return false
	for surface: String in reference._rest_meshes:
		if not receiver._rest_meshes[surface] is Mesh \
			or var_to_bytes(StadiumNpcRetainedGeometry._mesh(receiver._rest_meshes[surface])) \
			!= var_to_bytes(StadiumNpcRetainedGeometry._mesh(reference._rest_meshes[surface])):
			return false
	if not receiver.flex_surface.is_empty():
		if not StadiumNpcClubNetV1.PANELS.has(receiver.flex_surface) \
			or not is_finite(receiver.flex_elapsed) or receiver.flex_elapsed < 0 \
			or receiver.flex_elapsed > StadiumNpcClubNetV1.SETTLE \
			or not receiver.flex_impact.is_finite() \
			or not StadiumNpcClubNetV1.flex(reference.net, receiver.flex_surface,
				receiver.flex_elapsed, receiver.flex_impact):
			return false
	return valid(actual) and valid(expected) \
		and var_to_bytes(_metadata(actual.construction, actual)) \
		== var_to_bytes(_metadata(expected.construction, expected)) \
		and StadiumNpcRetainedGeometry.same(actual, expected)

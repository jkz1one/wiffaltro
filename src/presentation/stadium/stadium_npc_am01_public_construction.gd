class_name StadiumNpcAm01PublicConstruction
extends RefCounted
## Cold AM-01/r1 checks against the frozen 72-copy definition and fresh retained geometry.
## The public facade leaves all copy identities, local transforms and dormant towers intact.


# Only these five retained component roots carry this descriptive Working-art label.
# No raw/private admission flag is removed, and the shared origin checker stays unchanged.
const WORKING_MODELS: Dictionary = {
	"npc:AM-01:r1:BASE-L1": ["ST-029", 2, "BASE-LOWER-SIGHTLINE-v2"],
	"npc:AM-01:r1:BASE-R1": ["ST-029", 2, "BASE-LOWER-SIGHTLINE-v2"],
	"npc:AM-01:r1:BOWL-02": ["ST-081", 1, ""],
	"npc:AM-01:r1:BOWL-03": ["ST-081", 1, ""],
	"npc:AM-01:r1:BOWL-04": ["ST-081", 1, ""]
}


static func normalize_status_labels(property: StadiumNpcPublicProperty) -> bool:
	if property == null or property.venue_id != "AM-01" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumNpcMogulOneV1 \
		or property.is_inside_tree() or property.objects.size() != 72 \
		or property.objects != property.construction.objects:
		return false
	for identity: String in WORKING_MODELS:
		if not _working_model(property, identity):
			return false
		var model: Node3D = property.objects[identity]
		if not model.has_meta("authoring_status") \
			or typeof(model.get_meta("authoring_status", null)) != TYPE_STRING \
			or model.get_meta("authoring_status", "") != "Working":
			return false
	# Apply only after all five exact input identities/model/status values are established.
	# A rejected off-tree candidate is discarded by the caller, never installed or repaired.
	for identity: String in WORKING_MODELS:
		property.objects[identity].remove_meta("authoring_status")
	return StadiumMountedScoreboardContract._clean_tree(property)


static func _working_model(property: StadiumNpcPublicProperty, identity: String) -> bool:
	var model: Node3D = property.objects.get(identity)
	var expected: Array = WORKING_MODELS[identity]
	return is_instance_valid(model) and model.get_parent() == property.construction \
		and model.get_script() == null and model.get_meta("npc_instance", "") == identity \
		and model.get_meta("npc_site", "") == identity.get_slice(":", 3) \
		and model.get_meta("npc_host", "") == "field" \
		and model.get_meta("stadium_item", "") == expected[0] \
		and model.has_meta("model_version") \
		and typeof(model.get_meta("model_version", null)) == TYPE_INT \
		and model.get_meta("model_version", -1) == expected[1] \
		and model.has_meta("model_variant") == (not String(expected[2]).is_empty()) \
		and model.get_meta("model_variant", "") == expected[2]


static func valid(property: StadiumNpcPublicProperty) -> bool:
	var definition: Dictionary = StadiumNpcMogulOneCandidateV1.definition()
	if property.venue_id != "AM-01" or property.field == null \
		or not StadiumMountedScoreboardContract._clean_tree(property) \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.objects.size() != 72 or definition.instances.size() != 72 \
		or property.construction.objects != property.objects:
		return false
	for key: String in StadiumNpcMogulOneV1.FIELD:
		if property.field.get(key) != StadiumNpcMogulOneV1.FIELD[key]:
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
			or model.get_meta("npc_instance", "") != row.instance \
			or model.get_meta("owned_copy", "") != row.instance \
			or model.get_meta("npc_host", "") != row.host \
			or model.get_meta("npc_site", "") != row.site \
			or model.get_meta("stadium_item", "") != row.item \
			or model.transform != StadiumNpcMogulOneContractV1.transform(row.transform):
			return false
		if row.host != "field" and model.get_parent() != property.objects.get(row.host):
			return false
		if row.item == "ST-038" and (model.get_meta("night_qualified") != false \
			or model.get_meta("working_geometry_only") != true \
			or model.get_meta("obstacle_units") != 0):
			return false
		identities[row.instance] = model
		counts[row.item] = int(counts.get(row.item, 0)) + 1
	if counts != StadiumNpcMogulOneV1.COUNTS:
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


static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty) -> bool:
	# Same exact retained Club flex reproduction, with the public AM-01 receiver type.
	var receiver: StadiumNpcAm01PublicReceiver = actual.receiver as StadiumNpcAm01PublicReceiver
	var reference: StadiumNpcAm01PublicReceiver = expected.receiver as StadiumNpcAm01PublicReceiver
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
	return StadiumNpcRetainedGeometry.same(actual, expected)

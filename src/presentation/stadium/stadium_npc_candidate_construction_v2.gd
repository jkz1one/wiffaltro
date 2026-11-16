class_name StadiumNpcCandidateConstructionV2
extends RefCounted
## Exact, finite identity transfer after authentic frozen r1 construction.
## Meshes, materials, shapes, scripts and transforms are never rebuilt or substituted.

const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")


static func remap(property: StadiumNpcRetainedProperty) -> bool:
	var definition: Dictionary = StadiumNpcCandidatesV2.definition(property.venue_id)
	var mapping: Dictionary = StadiumNpcCandidateIdentityV2.MAP.get(property.venue_id, {})
	if definition.is_empty() or mapping.size() != property.objects.size():
		return false
	var objects: Dictionary = {}
	for old: String in mapping:
		var model: Node3D = property.objects.get(old)
		if not is_instance_valid(model) or model.get_meta("npc_instance", "") != old:
			return false
		objects[mapping[old]] = model
	# Enumerate only three known metadata fields. A foreign identity fails; never replace substrings.
	for node: Node in property.find_children("*", "", true, false):
		for key: String in ["npc_instance", "owned_copy", "npc_host"]:
			if not node.has_meta(key):
				continue
			var previous: Variant = node.get_meta(key)
			if key == "npc_host" and previous == "field":
				continue
			if not previous is String or not mapping.has(previous):
				return false
			node.set_meta(key, mapping[previous])
	for row: Dictionary in definition.instances:
		objects[row.instance].set_meta("npc_host", row.host)
	property.objects = objects
	property.construction.objects = objects
	property.field = FIELD.duplicate(true) as FieldDefinition
	property.construction.field = property.field
	return valid(property)


static func valid(property: StadiumNpcRetainedProperty) -> bool:
	var definition: Dictionary = StadiumNpcCandidatesV2.definition(property.venue_id)
	if (
		definition.is_empty()
		or property.field == null
		or property.field == FIELD
		or property.field.get_script() != FIELD.get_script()
		or property.construction.field != property.field
		or property.objects.size() != definition.instances.size()
		or property.construction.objects != property.objects
	):
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		if property.field.get(key) != FIELD.get(key):
			return false
	var identities: Dictionary = {}
	for row: Dictionary in definition.instances:
		var model: Node3D = property.objects.get(row.instance)
		if (
			not is_instance_valid(model)
			or not property.construction.is_ancestor_of(model)
			or model.get_meta("npc_instance", "") != row.instance
			or model.get_meta("owned_copy", "") != row.instance
			or model.get_meta("npc_host", "") != row.host
			or model.get_meta("stadium_item", "") != row.item
		):
			return false
		if row.host != "field" and model.get_parent() != property.objects.get(row.host):
			return false
		var pose: Transform3D = model.transform
		var actual: Array = [
			pose.basis.x.x,
			pose.basis.x.y,
			pose.basis.x.z,
			pose.basis.y.x,
			pose.basis.y.y,
			pose.basis.y.z,
			pose.basis.z.x,
			pose.basis.z.y,
			pose.basis.z.z,
			pose.origin.x,
			pose.origin.y,
			pose.origin.z
		]
		if actual != row.transform:
			return false
		identities[row.instance] = model
	for node: Node in property.find_children("*", "", true, false):
		for key: String in ["npc_instance", "owned_copy"]:
			if node.has_meta(key) and not identities.has(node.get_meta(key)):
				return false
		if (
			node.has_meta("npc_instance")
			and node.has_meta("owned_copy")
			and node.get_meta("npc_instance") != node.get_meta("owned_copy")
		):
			return false
	return true

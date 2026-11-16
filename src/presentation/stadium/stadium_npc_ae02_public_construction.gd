class_name StadiumNpcAe02PublicConstruction
extends Node3D
## Identity-only AE-02 adapter around the unchanged retained expanded and authored leaf factories.
## No candidate installer, catalog lookup, human layout, or stock mutation is admitted.
# gdlint: disable=max-returns

const INSTANCE_PREFIX: String = "npc:AE-02:r1:"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const CONE_SITES: Array[String] = ["O-L1", "O-R1"]
const LIGHT_SITES: Array[String] = ["YLIGHT-FL", "YLIGHT-FR", "YLIGHT-RL", "YLIGHT-RR"]
const COUNTS: Dictionary = {
	"ST-024": 22, "ST-026": 1, "ST-025": 1, "ST-028": 2, "ST-039": 1, "ST-001": 2, "ST-037": 4
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "expanded"


static func build() -> StadiumNpcAe02PublicConstruction:
	var result: StadiumNpcAe02PublicConstruction = StadiumNpcAe02PublicConstruction.new()
	result.name = "AE02PublicRevision1"
	var retained: StadiumNpcExpandedV1 = StadiumNpcExpandedV1.build()
	# Move, do not rebuild or transform, the exact 27-copy expanded subtree.
	for child: Node in retained.get_children():
		retained.remove_child(child)
		result.add_child(child)
	for old: String in retained.objects:
		var model: Node3D = retained.objects[old]
		var site: String = old.trim_prefix("npc:AE-01:r1:")
		result._bind(model, site)
	retained.free()
	result.field = FIELD.duplicate(true) as FieldDefinition
	for site: String in CONE_SITES:
		var cone: Node3D = StadiumStarterModels.create("ST-001")
		cone.name = site
		cone.transform = Transform3D(Basis.IDENTITY, Vector3(-8 if site == "O-L1" else 8, 0, 14))
		result.add_child(cone)
		result._bind(cone, site)
	for site: String in LIGHT_SITES:
		var light: Node3D = StadiumYardLightModels.create()
		light.name = site
		if not StadiumYardLightModels.place(light, site):
			light.free()
			result.free()
			return null
		result.add_child(light)
		result._bind(light, site)
	return result


func _bind(model: Node3D, site: String) -> void:
	var identity: String = INSTANCE_PREFIX + site
	model.set_meta("npc_instance", identity)
	model.set_meta("npc_site", site)
	model.set_meta("npc_host", "field")
	model.set_meta("owned_copy", identity)
	objects[identity] = model
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		body.set_meta("npc_instance", identity)
		body.set_meta("owned_copy", identity)
		if site in CONE_SITES:
			body.set_meta("ball_surface", &"stadium_live_object")


func route_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var identity: String = INSTANCE_PREFIX + site
		var model: Node3D = objects[identity]
		var envelope: AABB = StadiumNpcExpandedNetV1.ENVELOPE if site == "RECEIVER-CATCH" else (
			StadiumNpcExpandedTargetV1.ENVELOPE)
		var bounds: AABB = model.transform * envelope
		result.append({"center": bounds.get_center(), "radius": Vector2(
			bounds.size.x, bounds.size.z).length() / 2 + StadiumDefenderRoutes.BODY_RADIUS,
			"copy": identity})
	for site: String in CONE_SITES:
		var identity: String = INSTANCE_PREFIX + site
		result.append({"center": objects[identity].position,
			"radius": Vector2(0.175, 0.175).length() + StadiumDefenderRoutes.BODY_RADIUS,
			"copy": identity})
	return result


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	return is_instance_valid(node) and node.has_meta(key) \
		and typeof(node.get_meta(key)) == typeof(value) and node.get_meta(key) == value


static func components(pose: Transform3D) -> Array:
	return [pose.basis.x.x, pose.basis.x.y, pose.basis.x.z,
		pose.basis.y.x, pose.basis.y.y, pose.basis.y.z,
		pose.basis.z.x, pose.basis.z.y, pose.basis.z.z,
		pose.origin.x, pose.origin.y, pose.origin.z]


static func valid(property: StadiumNpcPublicProperty) -> bool:
	if property == null or property.venue_id != "AE-02" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumNpcAe02PublicConstruction \
		or property.field == null or property.field == FIELD \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.objects != property.construction.objects or property.objects.size() != 33 \
		or property.tier != "expanded" or not StadiumMountedScoreboardContract._clean_tree(property):
		return false
	for key: String in StadiumNpcYardV1.FIELD:
		# DefinitionBase.id is declared StringName. Preserve real types, not JSON spelling.
		if typeof(property.field.get(key)) != typeof(FIELD.get(key)) \
			or property.field.get(key) != FIELD.get(key):
			return false
	var counts: Dictionary = {}
	var definition: Dictionary = StadiumNpcExpandedTwoDefinitionV1.payload()
	for row: Dictionary in definition.instances:
		var model: Node3D = property.objects.get(row.instance)
		if not is_instance_valid(model) or not property.construction.is_ancestor_of(model) \
			or not exact_meta(model, "npc_instance", row.instance) \
			or not exact_meta(model, "owned_copy", row.instance) \
			or not exact_meta(model, "npc_host", row.host) \
			or not exact_meta(model, "npc_site", row.site) \
			or not exact_meta(model, "stadium_item", row.item) \
			or components(model.transform) != Array(PackedFloat32Array(row.transform)):
			return false
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		if row.item != "ST-024" and model.get_parent() != property.construction:
			return false
		if row.item == "ST-037" and not _dormant_light(model):
			return false
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			if not exact_meta(body, "npc_instance", row.instance) \
				or not exact_meta(body, "owned_copy", row.instance):
				return false
	var lights: int = 0
	for node: Node in property.find_children("*", "", true, false):
		if node is Light3D:
			lights += 1
			if not node is SpotLight3D or node.visible or node.name != &"FieldLight" \
				or not property.objects.values().has(node.get_parent()):
				return false
		for key: String in ["npc_instance", "owned_copy"]:
			if node.has_meta(key) and (not node.get_meta(key) is String \
				or not property.objects.has(node.get_meta(key))):
				return false
	return counts == COUNTS and lights == 4


static func _dormant_light(model: Node3D) -> bool:
	var beam: SpotLight3D = model.get_node_or_null("FieldLight") as SpotLight3D
	var lens: MeshInstance3D = model.get_node_or_null("Visual/LampLens") as MeshInstance3D
	return beam != null and not beam.visible and lens != null \
		and lens.material_override is StandardMaterial3D \
		and not lens.material_override.emission_enabled


static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty) -> bool:
	if not valid(actual) or not valid(expected) \
		or actual.ae02_actors == null or expected.ae02_actors == null \
		or not actual.ae02_actors.owners_intact() or not expected.ae02_actors.owners_intact() \
		or not StadiumNpcRetainedGeometry._receiver_policies(actual) \
		or not StadiumNpcRetainedGeometry._receiver_policies(expected):
		return false
	var left: Dictionary = StadiumNpcRetainedGeometry._geometry(actual)
	var right: Dictionary = StadiumNpcRetainedGeometry._geometry(expected)
	if not _normalize_cones(actual, actual, left) or not _normalize_cones(expected, expected, right):
		return false
	return var_to_bytes(left) == var_to_bytes(right) \
		and var_to_bytes(_light_properties(actual)) == var_to_bytes(_light_properties(expected))


static func _normalize_cones(property: StadiumNpcPublicProperty, node: Node,
	data: Dictionary) -> bool:
	if node is MeshInstance3D and StadiumNpcAe02PublicActors.owns_mesh(property, node):
		if not StadiumNpcAe02PublicActors.normalize_geometry(property, node, data):
			return false
	for index in range(node.get_child_count()):
		if not _normalize_cones(property, node.get_child(index), data.children[index]):
			return false
	return true


static func _light_properties(property: StadiumNpcPublicProperty) -> Array:
	var result: Array = []
	for site: String in LIGHT_SITES:
		var model: Node3D = property.objects[INSTANCE_PREFIX + site]
		result.append(StadiumNpcRetainedGeometry._stored(model.get_node("FieldLight")))
	return result

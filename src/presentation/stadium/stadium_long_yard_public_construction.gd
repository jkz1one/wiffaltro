class_name StadiumLongYardPublicConstruction
extends Node3D
## Detached authored LONG-YARD v2 / public revision1; exact67 copies and no lights.
## Cold construction/audit only. Installation and issued callbacks belong to common authority.
# gdlint: disable=max-returns

const INSTANCE_PREFIX: String = "npc:LONG-YARD:r1:"
const OWNER: String = "finals-venue:long-yard:v2"
const BOARD_SITE: String = "SCORE-SMALL"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const BASE_SITES: Array[String] = ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]
const ROOF_HOSTS: Array[String] = ["BASE-L2", "BASE-R2"]
const COUNTS: Dictionary = {
	"ST-065": 22, "ST-022": 16, "ST-023": 16, "ST-074": 2, "ST-021": 2,
	"ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-053": 2, "ST-039": 1
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "club"


static func build() -> StadiumLongYardPublicConstruction:
	var result: StadiumLongYardPublicConstruction = StadiumLongYardPublicConstruction.new()
	result.name = "LongYardPublicRevision1"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	field = FIELD.duplicate(true) as FieldDefinition
	var template: StadiumNpcClubV1 = StadiumNpcClubV1.new()
	template.field = field
	template._surface()
	for child: Node in template.get_children():
		template.remove_child(child)
		add_child(child)
		# Original LY correction: center the 0.08 m guide within its exact Club footprint.
		if not child is Node3D:
			continue
		var edge: Node3D = child as Node3D
		if absf(edge.position.x) == 40:
			edge.position.x = signf(edge.position.x) * 39.96
		elif edge.position.z == -22:
			edge.position.z = -21.96
		elif edge.position.z == 46:
			edge.position.z = 45.96
	template.free()
	var boundary: StadiumLongYardPublicBoundarySource = StadiumLongYardPublicBoundarySource.new()
	boundary.name = "ClubBoundary"
	add_child(boundary)
	if not boundary.build():
		return false
	for socket: Dictionary in StadiumFoulPoleSites.rows(boundary.graph):
		var side: int = -1 if socket.site == "FOUL-POLE-L" else 1
		var line: Node3D = get_node("FoulLine" + str(side))
		var end: Vector3 = socket.position
		line.position = end / 2 + Vector3(0, 0.02, 0)
		line.rotation.y = atan2(end.x, end.z)
		var mesh: MeshInstance3D = line.get_child(0)
		(mesh.mesh as BoxMesh).size = Vector3(0.055, 0.025, end.length())
	for model: Node3D in boundary.items:
		if not model.has_meta("candidate_site") or not model.get_meta("candidate_site") is String:
			return false
		_register(model, model.get_meta("candidate_site"))
	for site: String in BASE_SITES:
		var stand: Node3D = StadiumBaselineSightlineModels.lower()
		if stand == null or not _normalize_working_model(stand, "ST-029", 2,
			"BASE-LOWER-SIGHTLINE-v2"):
			if stand != null:
				stand.free()
			return false
		add_child(stand)
		stand.transform = StadiumBaselineSites.pose(site)
		_register(stand, site)
		if site not in ROOF_HOSTS:
			continue
		var roof: Node3D = StadiumLongYardLowerRoofModels.canopy_reference()
		if roof == null or not _normalize_working_model(roof, "ST-053", 2,
			"BASE-LOWER-CANOPY-GUARD-v2"):
			if roof != null:
				roof.free()
			return false
		# Same original world pose; public mounted host uses exact local identity.
		# Stable host identity replaces the private factory's transient lower_instance integer.
		stand.add_child(roof)
		roof.transform = Transform3D.IDENTITY
		roof.set_meta("interface", StadiumLongYardLowerRoofSites.INTERFACE)
		if not StadiumLongYardLowerRoofSites.supported(stand, roof):
			return false
		_register(roof, "ROOF:" + site, INSTANCE_PREFIX + site)
	var board: Node3D = StadiumClubModels.create("ST-039")
	add_child(board)
	board.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
	_register(board, BOARD_SITE)
	return objects.size() == 67


static func _normalize_working_model(model: Node3D, item: String,
	version: int, variant: String) -> bool:
	# Only the six exact freshly built model roots lose the descriptive Working label.
	if not exact_meta(model, "stadium_item", item) \
		or not exact_meta(model, "model_version", version) \
		or not exact_meta(model, "model_variant", variant) \
		or not exact_meta(model, "authoring_status", "Working"):
		return false
	model.remove_meta("authoring_status")
	return true


func _register(model: Node3D, site: String, host: String = "field") -> void:
	var identity: String = INSTANCE_PREFIX + site
	for key: String in ["candidate_site", "candidate_instance", "candidate_mount"]:
		if model.has_meta(key):
			model.remove_meta(key)
	model.set_meta("npc_instance", identity)
	model.set_meta("npc_site", site)
	model.set_meta("npc_host", host)
	model.set_meta("site", "RECEIVER-NET" if site == "RECEIVER-CATCH" else site)
	objects[identity] = model
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		body.set_meta("npc_instance", identity)
		body.set_meta("owned_copy", identity)


func route_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ends: Array in StadiumReceiverNetModels.PANELS.values():
		var pieces: int = ceili(ends[0].distance_to(ends[1]) / 0.3)
		for index in range(pieces + 1):
			var point: Vector2 = ends[0].lerp(ends[1], float(index) / pieces)
			result.append({"center": Vector3(point.x, 0, point.y), "radius": 0.8})
	var target: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-PRIMARY"]
	StadiumNpcClubV1._bounds_obstacle(result, target.transform * StadiumTargetModels.ENVELOPE)
	var net: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-CATCH"]
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if body.has_meta("surface_id") \
			and String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			StadiumNpcClubV1._bounds_obstacle(result,
				net.transform * body.transform * shape.transform * AABB(-size / 2, size))
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
	if property == null or property.venue_id != "LONG-YARD" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumLongYardPublicConstruction \
		or property.field == null or property.field == FIELD \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.objects != property.construction.objects or property.objects.size() != 67 \
		or property.tier != "club" or not StadiumMountedScoreboardContract._clean_tree(property):
		return false
	for description: Dictionary in FIELD.get_property_list():
		if (int(description.usage) & PROPERTY_USAGE_STORAGE) == 0 or description.name in [
			"script", "resource_path", "resource_name", "resource_local_to_scene",
			"resource_scene_unique_id"]:
			continue
		var key: String = description.name
		if typeof(property.field.get(key)) != typeof(FIELD.get(key)) \
			or property.field.get(key) != FIELD.get(key):
			return false
	var source: StadiumLongYardPublicBoundarySource = property.construction.get_node_or_null(
		"ClubBoundary") as StadiumLongYardPublicBoundarySource
	if source == null or source.graph == null or source.graph.get_script() != StadiumDugoutBoundary \
		or source.graph.signature() != StadiumLongYardDefinitionV1.payload().graph.sha256:
		return false
	var counts: Dictionary = {}
	for row: Dictionary in StadiumLongYardDefinitionV1.payload().instances:
		var model: Node3D = property.objects.get(row.instance)
		if not is_instance_valid(model) or not property.construction.is_ancestor_of(model) \
			or not exact_meta(model, "npc_instance", row.instance) \
			or not exact_meta(model, "owned_copy", row.instance) \
			or not exact_meta(model, "npc_host", row.host) \
			or not exact_meta(model, "npc_site", row.site) \
			or not exact_meta(model, "stadium_item", row.item) \
			or components(model.transform) != Array(PackedFloat32Array(row.transform)):
			return false
		if row.host != "field" and model.get_parent() != property.objects.get(row.host):
			return false
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		if row.item == "ST-021" and (not exact_meta(model, "wall_cap_height", 3.25) \
			or not exact_meta(model.get_node("Collision/Pole"), "wall_cap_height", 3.25)):
			return false
		if row.item == "ST-029" and (not exact_meta(model, "model_version", 2) \
			or not exact_meta(model, "model_variant", "BASE-LOWER-SIGHTLINE-v2")):
			return false
		if row.item == "ST-053" and (not exact_meta(model, "model_version", 2) \
			or not exact_meta(model, "model_variant", "BASE-LOWER-CANOPY-GUARD-v2") \
			or not exact_meta(model, "interface", StadiumLongYardLowerRoofSites.INTERFACE) \
			or row.site not in ["ROOF:BASE-L2", "ROOF:BASE-R2"] \
			or not StadiumLongYardLowerRoofSites.supported(property.objects[row.host], model)):
			return false
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			if _model_owner(body, property) != model:
				continue
			if not exact_meta(body, "npc_instance", row.instance) \
				or not exact_meta(body, "owned_copy", row.instance):
				return false
	for node: Node in property.find_children("*", "", true, false):
		if node is Light3D or node.has_meta("candidate_instance") or node.has_meta("candidate_site"):
			return false
		for key: String in ["npc_instance", "owned_copy"]:
			if node.has_meta(key) and (not node.get_meta(key) is String \
				or not property.objects.has(node.get_meta(key))):
				return false
	return counts == COUNTS


static func _metadata(node: Node, property: StadiumNpcPublicProperty) -> Dictionary:
	var result: Dictionary = {"meta": {}, "children": []}
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		if key == &"receiver_render_state" and property.receiver != null \
			and node in [property.receiver.chair, property.receiver.net]:
			continue
		result.meta[String(key)] = node.get_meta(key)
	for child: Node in node.get_children():
		result.children.append(_metadata(child, property))
	return result


static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty) -> bool:
	# Cold admission/diagnostic only, never called from a per-frame issued callback.
	if not _align_display(actual, expected):
		return false
	var receiver: StadiumNpcRetainedClubReceiver = actual.receiver as StadiumNpcRetainedClubReceiver
	var reference: StadiumNpcRetainedClubReceiver = expected.receiver as StadiumNpcRetainedClubReceiver
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


static func _align_display(actual: StadiumNpcPublicProperty,
	expected: StadiumNpcPublicProperty) -> bool:
	# Original board art keeps its original display script. Match only its three numeric slots
	# on the fresh detached reference; actual display/phase/pending state is never changed.
	if actual == null or expected == null or expected.is_inside_tree() \
		or expected.get_parent() != null or expected.bound_state != null \
		or not _display_intact(actual) or not _display_intact(expected):
		return false
	var display: StadiumScoreboardDisplay = actual.display as StadiumScoreboardDisplay
	var reference: StadiumScoreboardDisplay = expected.display as StadiumScoreboardDisplay
	if reference._match != null or not reference._pending.is_empty() \
		or not ClubCareer.same(reference.shown, {"inning": 1, "home": 0, "away": 0}):
		return false
	if actual.is_inside_tree():
		if display._match != actual.bound_state:
			return false
	elif display._match != null:
		return false
	return reference.present(display.shown, false)


static func _display_intact(property: StadiumNpcPublicProperty) -> bool:
	var board: Node3D = property.objects.get(INSTANCE_PREFIX + BOARD_SITE)
	var display: StadiumScoreboardDisplay = property.display as StadiumScoreboardDisplay
	if not is_instance_valid(board) or display == null \
		or display.get_script() != StadiumScoreboardDisplay \
		or board.get_node_or_null("Visual/ScoreDisplay") != display \
		or display.get_child_count() != 6 \
		or not SeasonOwnership._keys(display._labels, ["inning", "home", "away"]) \
		or not _score_values(display.shown) \
		or (not display._pending.is_empty() and not _score_values(display._pending)):
		return false
	for index in range(3):
		var key: String = ["inning", "home", "away"][index]
		var caption: Label3D = display.get_child(index * 2) as Label3D
		var numeric: Label3D = display.get_child(index * 2 + 1) as Label3D
		if caption == null or numeric == null or caption.text != key.to_upper() \
			or display._labels[key] != numeric or numeric.text != str(display.shown[key]):
			return false
	return true


static func _score_values(value: Dictionary) -> bool:
	if not SeasonOwnership._keys(value, ["inning", "home", "away"]):
		return false
	for key: String in value:
		if not value[key] is int \
			or not SeasonOwnership._whole(value[key], 1 if key == "inning" else 0, 9999):
			return false
	return true


static func _model_owner(node: Node, property: StadiumNpcPublicProperty) -> Node3D:
	var current: Node = node
	while current != null and current != property:
		if current.has_meta("npc_instance"):
			var identity: Variant = current.get_meta("npc_instance")
			if identity is String and property.objects.get(identity) == current:
				return current as Node3D
		current = current.get_parent()
	return null

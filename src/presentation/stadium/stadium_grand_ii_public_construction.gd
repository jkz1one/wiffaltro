class_name StadiumGrandIIPublicConstruction
extends Node3D
## Exact authored GRAND-II v1 / public r1. Reuse Grand I infrastructure plus ten copies.
## Detached cold construction only; no qualification, install, callbacks or physics changes.
# gdlint: disable=max-returns

const BASE = preload("res://src/presentation/stadium/stadium_grand_i_public_construction.gd")
const INSTANCE_PREFIX: String = "npc:GRAND-II:r1:"
const OWNER: String = "npc-venue:grandstand-gardens:grand-ii-v1"
const BOARD_SITE: String = "SCORE-SMALL"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const COUNTS: Dictionary = {
	"ST-065": 23, "ST-022": 16, "ST-023": 16, "ST-074": 2, "ST-021": 2,
	"ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-081": 5, "ST-038": 6, "ST-039": 1,
	"ST-083": 3, "ST-082": 3, "ST-085": 1, "ST-088": 1
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "mogul"


static func build() -> StadiumGrandIIPublicConstruction:
	var result: StadiumGrandIIPublicConstruction = StadiumGrandIIPublicConstruction.new()
	result.name = "GrandIIPublicRevision1"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	# Transfer the unchanged detached 75-copy build, then release only its empty shell.
	var inherited: StadiumGrandIPublicConstruction = BASE.build()
	if inherited == null:
		return false
	field = inherited.field
	for child: Node in inherited.get_children():
		inherited.remove_child(child)
		add_child(child)
	for model: Node3D in inherited.objects.values():
		_register(model, String(model.get_meta("npc_site")))
	inherited.objects.clear()
	inherited.free()
	for site: String in ["BOWL-01", "BOWL-05"]:
		var lower: Node3D = StadiumCurvedLowerModels.create()
		if not _adopt(lower, "ST-081", site):
			return false
		lower.transform = StadiumCurvedLowerSites.pose(site)
	for site: String in StadiumCurvedStackSites.CENTRAL:
		# Public construction is detached. Reuse exact factory geometry primitives;
		# live-tree purchase guards are replaced by immutable support-identity guards.
		var concourse: Node3D = StadiumCurvedStackModels._concourse()
		if not _adopt(concourse, "ST-083", site + ":CONCOURSE"):
			return false
		concourse.transform = StadiumCurvedLowerSites.pose(site)
		concourse.set_meta("interface", StadiumCurvedStackSites.INTERFACE)
		concourse.set_meta("npc_supports", [INSTANCE_PREFIX + site])
		var upper: Node3D = StadiumCurvedStackModels._upper(true)
		if not _adopt(upper, "ST-082", site + ":UPPER"):
			return false
		upper.transform = StadiumCurvedLowerSites.pose(site)
		upper.set_meta("interface", StadiumCurvedStackSites.UPPER_INTERFACE)
		upper.set_meta("npc_supports", [INSTANCE_PREFIX + site,
			INSTANCE_PREFIX + site + ":CONCOURSE"])
	for site: String in StadiumLowerTransitionSites.SITES:
		var transition: Node3D = StadiumLowerTransitionModels.create_right() if site == "JOIN-R" \
			else StadiumLowerTransitionModels.create_left()
		if not _adopt(transition, StadiumLowerTransitionSites.item(site), site):
			return false
		transition.transform = StadiumLowerTransitionSites.pose(site)
	return objects.size() == 85


func _adopt(model: Node3D, item: String, site: String) -> bool:
	if not BASE.exact_meta(model, "stadium_item", item) \
		or not BASE.exact_meta(model, "model_version", 1) \
		or not BASE.exact_meta(model, "authoring_status", "Working"):
		if is_instance_valid(model):
			model.free()
		return false
	model.remove_meta("authoring_status")
	add_child(model)
	_register(model, site)
	return true



func _register(model: Node3D, site: String, host: String = "field") -> void:
	var identity: String = INSTANCE_PREFIX + site
	for key: String in ["candidate_site", "candidate_instance", "candidate_mount", "candidate_host",
		"candidate_model_version"]:
		if model.has_meta(key):
			model.remove_meta(key)
	model.set_meta("owned_copy", identity)
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
	BASE._bounds_obstacle(result, target.transform * StadiumTargetModels.ENVELOPE)
	var net: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-CATCH"]
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if body.has_meta("surface_id") \
			and String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			BASE._bounds_obstacle(result,
				net.transform * body.transform * shape.transform * AABB(-size / 2, size))
	return result



static func valid(property: StadiumNpcPublicProperty) -> bool:
	if not is_instance_valid(property) or property.get_script() != StadiumNpcPublicProperty \
		or property.venue_id != "GRAND-II" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumGrandIIPublicConstruction \
		or property.construction.get_parent() != property \
		or not is_instance_valid(property.field) or property.field == FIELD \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.construction.tier != "mogul" \
		or property.transform != Transform3D.IDENTITY \
		or property.objects != property.construction.objects or property.objects.size() != 85 \
		or property.tier != "mogul" or not StadiumMountedScoreboardContract._clean_tree(property):
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
	var source: StadiumGrandIPublicBoundarySource = property.construction.get_node_or_null(
		"ClubBoundary") as StadiumGrandIPublicBoundarySource
	if source == null or source.graph == null or source.graph.get_script() != StadiumDugoutBoundary \
		or source.graph.signature() != StadiumGrandIIDefinitionV1.payload().graph.sha256:
		return false
	var counts: Dictionary = {}
	for row: Dictionary in StadiumGrandIIDefinitionV1.payload().instances:
		var candidate: Variant = property.objects.get(row.instance)
		if not candidate is Node3D:
			return false
		var model: Node3D = candidate
		if not is_instance_valid(model) or not property.construction.is_ancestor_of(model) \
			or not BASE.exact_meta(model, "npc_instance", row.instance) \
			or not BASE.exact_meta(model, "owned_copy", row.instance) \
			or not BASE.exact_meta(model, "npc_host", row.host) \
			or not BASE.exact_meta(model, "npc_site", row.site) \
			or not BASE.exact_meta(model, "stadium_item", row.item) \
			or BASE.components(model.transform) != Array(PackedFloat32Array(row.transform)):
			return false
		if row.host != "field" or not BASE._identity_ancestors(model.get_parent(), property.construction):
			return false
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		if row.item == "ST-021" and (not BASE.exact_meta(model, "wall_cap_height", 3.25) \
			or not BASE.exact_meta(model.get_node_or_null("Collision/Pole"), "wall_cap_height", 3.25)):
			return false
		if row.item == "ST-029" and (not BASE.exact_meta(model, "model_version", 2) \
			or not BASE.exact_meta(model, "model_variant", "BASE-LOWER-SIGHTLINE-v2")):
			return false
		if row.item == "ST-081" and (not BASE.exact_meta(model, "model_version", 1) \
			or row.site not in StadiumCurvedLowerSites.SITES):
			return false
		if not _layers_intact(model, row, property):
			return false
		if row.item == "ST-038" and not BASE._tower_intact(model, row.site):
			return false
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			if BASE._model_owner(body, property) != model:
				continue
			if not BASE.exact_meta(body, "npc_instance", row.instance) \
				or not BASE.exact_meta(body, "owned_copy", row.instance):
				return false
	var members: Array[Node] = [property.construction]
	members.append_array(property.construction.find_children("*", "", true, false))
	for node: Node in members:
		if node is Light3D:
			return false
		for marker: StringName in node.get_meta_list():
			if String(marker).begins_with("candidate_"):
				return false
		for key: String in ["npc_instance", "owned_copy"]:
			if node.has_meta(key) and (not (node.get_meta(key) is String \
				or node.get_meta(key) is StringName) \
				or not property.objects.has(String(node.get_meta(key)))):
				return false
	return counts == COUNTS



static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty,
	lighting_root: Node = null) -> bool:
	# Cold admission/diagnostic only, never called from a per-frame issued callback.
	if not _align_display(actual, expected):
		return false
	var receiver: StadiumNpcRetainedClubReceiver = actual.receiver as StadiumNpcRetainedClubReceiver
	var reference: StadiumNpcRetainedClubReceiver = expected.receiver as StadiumNpcRetainedClubReceiver
	if not is_instance_valid(receiver) or not is_instance_valid(reference) \
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
		and var_to_bytes(BASE._metadata(actual.construction, actual)) \
		== var_to_bytes(BASE._metadata(expected.construction, expected)) \
		and _same_geometry(actual, expected, lighting_root)



static func _align_display(actual: StadiumNpcPublicProperty,
	expected: StadiumNpcPublicProperty) -> bool:
	# Original board art keeps its original display script. Match only its three numeric slots
	# on the fresh detached reference; actual display/phase/pending state is never changed.
	if not is_instance_valid(actual) or not is_instance_valid(expected) or expected.is_inside_tree() \
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
	if not is_instance_valid(property):
		return false
	var candidate: Variant = property.objects.get(INSTANCE_PREFIX + BOARD_SITE)
	if not candidate is Node3D:
		return false
	var board: Node3D = candidate
	var display: StadiumScoreboardDisplay = property.display as StadiumScoreboardDisplay
	if not is_instance_valid(board) or not is_instance_valid(display) \
		or display.get_script() != StadiumScoreboardDisplay \
		or board.get_node_or_null("Visual/ScoreDisplay") != display \
		or display.get_child_count() != 6 \
		or not SeasonOwnership._keys(display._labels, ["inning", "home", "away"]) \
		or not BASE._score_values(display.shown) \
		or (not display._pending.is_empty() and not BASE._score_values(display._pending)):
		return false
	for index in range(3):
		var key: String = ["inning", "home", "away"][index]
		var caption: Label3D = display.get_child(index * 2) as Label3D
		var numeric: Label3D = display.get_child(index * 2 + 1) as Label3D
		if caption == null or numeric == null or caption.text != key.to_upper() \
			or display._labels[key] != numeric or numeric.text != str(display.shown[key]):
			return false
	return true



static func _same_geometry(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty,
	lighting_root: Node) -> bool:
	if lighting_root == null:
		return StadiumNpcRetainedGeometry.same(actual, expected)
	# Caller first verifies the exact active_lighting lease. Only that single direct sibling
	# is separate from immutable geometry; every other root/member remains byte-compared.
	if not is_instance_valid(lighting_root) or lighting_root.get_parent() != actual \
		or lighting_root.name != &"GrandIIActiveLighting" or lighting_root.get_script() != null \
		or expected.has_node("GrandIIActiveLighting") \
		or not StadiumNpcRetainedGeometry._receiver_policies(actual) \
		or not StadiumNpcRetainedGeometry._receiver_policies(expected):
		return false
	var index: int = actual.get_children().find(lighting_root)
	var observed: Dictionary = StadiumNpcRetainedGeometry._geometry(actual)
	var reference: Dictionary = StadiumNpcRetainedGeometry._geometry(expected)
	if index < 0 or observed.children.size() != reference.children.size() + 1:
		return false
	observed.children.remove_at(index)
	return var_to_bytes(observed) == var_to_bytes(reference)



static func _layers_intact(model: Node3D, row: Dictionary,
	property: StadiumNpcPublicProperty) -> bool:
	if row.item in ["ST-085", "ST-088"]:
		return BASE.exact_meta(model, "model_version", 1) \
			and StadiumLowerTransitionSites.item(row.site) == row.item \
			and BASE.exact_meta(model, "baseline_end", "stair" if row.site == "JOIN-R" else "solid")
	if row.item not in ["ST-083", "ST-082"]:
		return true
	var lower_site: String = String(row.site).get_slice(":", 0)
	var supports: Array = [INSTANCE_PREFIX + lower_site]
	var interface: String = StadiumCurvedStackSites.INTERFACE
	if row.item == "ST-082":
		supports.append(INSTANCE_PREFIX + lower_site + ":CONCOURSE")
		interface = StadiumCurvedStackSites.UPPER_INTERFACE
	if lower_site not in StadiumCurvedStackSites.CENTRAL \
		or not BASE.exact_meta(model, "model_version", 1) \
		or not BASE.exact_meta(model, "interface", interface) \
		or not BASE.exact_meta(model, "npc_supports", supports) \
		or model.has_meta("lower_instance") or model.has_meta("concourse_instance"):
		return false
	for index in range(supports.size()):
		var support: Node3D = property.objects.get(supports[index]) as Node3D
		if not is_instance_valid(support) or support.get_parent() != model.get_parent() \
			or support.transform != model.transform \
			or not BASE.exact_meta(support, "stadium_item", "ST-081" if index == 0 else "ST-083"):
			return false
	return true


static func components(pose: Transform3D) -> Array:
	return BASE.components(pose)


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	return BASE.exact_meta(node, key, value)

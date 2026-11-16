class_name StadiumGrandIIIPublicConstruction
extends Node3D
## Exact authored GRAND-III-VIDEO-v2 / public r1. 107 copies, layout approval pending.
## Detached cold construction only; no qualification, install, callbacks or physics changes.
# gdlint: disable=max-returns,max-file-lines

const BASE = preload("res://src/presentation/stadium/stadium_grand_i_public_construction.gd")
const INHERITED = preload("res://src/presentation/stadium/stadium_grand_ii_public_construction.gd")
const INSTANCE_PREFIX: String = "npc:GRAND-III:r1:"
const OWNER: String = "npc-venue:grandstand-gardens:grand-iii-video-v2"
const BOARD_SITE: String = "BOARD-LARGE-v2"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const COUNTS: Dictionary = {
	"ST-065": 23, "ST-022": 16, "ST-023": 16, "ST-074": 2, "ST-021": 2,
	"ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-031": 4, "ST-030": 4,
	"ST-053": 4, "ST-081": 5, "ST-083": 5, "ST-082": 5, "ST-084": 5,
	"ST-085": 1, "ST-088": 1, "ST-086": 1, "ST-089": 1, "ST-040": 1,
	"ST-076": 4, "ST-046": 1
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "mogul"


static func build() -> StadiumGrandIIIPublicConstruction:
	var result: StadiumGrandIIIPublicConstruction = StadiumGrandIIIPublicConstruction.new()
	result.name = "GrandIIIPublicRevision1"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	# Reuse the exact detached II build; remove only its superseded six towers and board.
	var inherited: StadiumGrandIIPublicConstruction = INHERITED.build()
	if inherited == null:
		return false
	field = inherited.field
	for identity: String in inherited.objects.keys():
		var model: Node3D = inherited.objects[identity]
		if model.get_meta("stadium_item") in ["ST-038", "ST-039"]:
			inherited.objects.erase(identity)
			model.free()
	for child: Node in inherited.get_children():
		inherited.remove_child(child)
		add_child(child)
	for model: Node3D in inherited.objects.values():
		_register(model, String(model.get_meta("npc_site")))
	inherited.objects.clear()
	inherited.free()
	set_meta("layout_revision", StadiumGrandIIIDefinitionV1.source_layout())
	if not _structures() or not _exterior():
		return false
	return objects.size() == 107


func _structures() -> bool:
	for site: String in StadiumBaselineSites.SITES:
		for item: String in ["ST-031", "ST-030", "ST-053"]:
			var model: Node3D
			match item:
				"ST-031": model = StadiumGrandThreeStackModels._concourse()
				"ST-030": model = StadiumGrandThreeStackModels._upper(true)
				"ST-053": model = StadiumGrandThreeStackModels._roof()
			var suffix: String = {"ST-031": "CONCOURSE", "ST-030": "UPPER", "ST-053": "ROOF"}[item]
			if not _adopt(model, item, site + ":" + suffix, 2):
				return false
			model.transform = StadiumBaselineSites.pose(site)
	for site: String in StadiumCurvedLowerSites.SITES:
		if site in ["BOWL-01", "BOWL-05"]:
			var concourse: Node3D = StadiumCurvedStackModels._concourse()
			if not _adopt(concourse, "ST-083", site + ":CONCOURSE"):
				return false
			concourse.transform = StadiumCurvedLowerSites.pose(site)
			var upper: Node3D = StadiumCurvedStackModels._upper(true)
			if not _adopt(upper, "ST-082", site + ":UPPER"):
				return false
			upper.transform = StadiumCurvedLowerSites.pose(site)
		# Historical frozen primitive is byte-for-byte geometry-correspondent to ST084.create.
		var roof: Node3D = StadiumGrandThreeStackModels._curved_roof_reference()
		if not _adopt(roof, "ST-084", site + ":ROOF"):
			return false
		roof.transform = StadiumCurvedLowerSites.pose(site)
	for site: String in StadiumTransitionConcourseSites.SITES:
		var join: Node3D = StadiumGrandThreeStackModels._transition(site)
		if not _adopt(join, StadiumTransitionConcourseSites.item(site), site + ":CONCOURSE", 2):
			return false
		join.transform = Transform3D.IDENTITY
	return true


func _exterior() -> bool:
	var board: Node3D = StadiumScoreboardModels.create("ST-040", "video-v2")
	if not BASE.exact_meta(board, "stadium_item", "ST-040") \
		or not BASE.exact_meta(board, "scoreboard_owned_model", "video-v2") \
		or not BASE.exact_meta(board, "scoreboard_model_version", 2):
		if is_instance_valid(board):
			board.free()
		return false
	add_child(board)
	board.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(36.5, 0, 31.5))
	board.set_meta("surface_role", &"DECORATIVE_AFTER_TERMINAL")
	_register(board, BOARD_SITE)
	for site: String in StadiumPremiumLightTowerSites.SITES:
		var tower: Node3D = StadiumPremiumLightTowerModels.create()
		if tower == null:
			return false
		add_child(tower)
		if not StadiumPremiumLightTowerSites.place(tower, site) or not _public_tower(tower):
			return false
		_register(tower, site)
	var waterfall: Node3D = StadiumWaterfallModels.create()
	if not StadiumWaterfallModels.valid(waterfall):
		if is_instance_valid(waterfall):
			waterfall.free()
		return false
	add_child(waterfall)
	waterfall.transform = Transform3D(Basis.IDENTITY, StadiumWaterfallSites.CENTER)
	waterfall.remove_meta("working_geometry_only")
	waterfall.set_meta("immutable_geometry_only", true)
	_register(waterfall, "LANDMARK-A")
	return true


func _adopt(model: Node3D, item: String, site: String, version: int = 1) -> bool:
	if not BASE.exact_meta(model, "stadium_item", item) \
		or not BASE.exact_meta(model, "model_version", version) \
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
	var contract: Dictionary = _layer_contract(String(model.get_meta("stadium_item")), site)
	if not contract.is_empty():
		model.set_meta("interface", contract.interface)
		model.set_meta("npc_supports", contract.supports)
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
		or property.venue_id != "GRAND-III" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumGrandIIIPublicConstruction \
		or property.construction.get_parent() != property \
		or not is_instance_valid(property.field) or property.field == FIELD \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.construction.tier != "mogul" \
		or property.transform != Transform3D.IDENTITY \
		or property.objects != property.construction.objects or property.objects.size() != 107 \
		or property.tier != "mogul" or not StadiumMountedScoreboardContract._clean_tree(property):
		return false
	if not BASE.exact_meta(property.construction, "layout_revision",
		StadiumGrandIIIDefinitionV1.source_layout()):
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
		or source.graph.signature() != StadiumGrandIIIDefinitionV1.payload().graph.sha256:
		return false
	var counts: Dictionary = {}
	for row: Dictionary in StadiumGrandIIIDefinitionV1.payload().instances:
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
		if not _exterior_intact(model, row):
			return false
		if not _layers_intact(model, row, property):
			return false
		if row.item == "ST-076" and not _tower_intact(model, row.site):
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
	# Align only authorized readout text on the fresh detached reference, never actual state.
	if not is_instance_valid(actual) or not is_instance_valid(expected) or expected.is_inside_tree() \
		or expected.get_parent() != null or expected.bound_state != null \
		or not _display_intact(actual) or not _display_intact(expected):
		return false
	var display: StadiumScoreboardTierDisplay = actual.display as StadiumScoreboardTierDisplay
	var reference: StadiumScoreboardTierDisplay = expected.display as StadiumScoreboardTierDisplay
	if reference._match != null or not reference._pending.is_empty() \
		or not reference.shown.is_empty() or not reference.details.is_empty():
		return false
	if actual.is_inside_tree():
		if display._match != actual.bound_state:
			return false
	elif display._match != null:
		return false
	if not display.shown.is_empty() and not reference.present(display.shown, false):
		return false
	if not display.details.is_empty():
		reference.details = display.details.duplicate(true)
		for key: String in reference._detail_labels:
			var label: Label3D = reference._detail_labels[key]
			var slot: Dictionary = StadiumScoreboardTiers.detail_slots("video")[key]
			label.text = StadiumScoreboardTierDisplay._fit(reference.details[key], label, slot.width)
	return true


static func _display_intact(property: StadiumNpcPublicProperty) -> bool:
	if not is_instance_valid(property):
		return false
	var board: Node3D = property.objects.get(INSTANCE_PREFIX + BOARD_SITE) as Node3D
	var display: StadiumScoreboardTierDisplay = property.display as StadiumScoreboardTierDisplay
	if not is_instance_valid(board) or not is_instance_valid(display) \
		or display.get_script() != StadiumScoreboardTierDisplay or display.tier != "video" \
		or board.get_node_or_null("Visual/ScoreDisplay") != display \
		or display.get_child_count() != 14 \
		or not SeasonOwnership._keys(display._labels, ["inning", "home", "away"]) \
		or not SeasonOwnership._keys(display._detail_labels,
			StadiumScoreboardTiers.detail_slots("video").keys()) \
		or (not display.shown.is_empty() and not BASE._score_values(display.shown)) \
		or (not display._pending.is_empty() and not BASE._score_values(display._pending)):
		return false
	if not display.details.is_empty() and not SeasonOwnership._keys(display.details,
		StadiumScoreboardTiers.detail_slots("video").keys()):
		return false
	var ordered: Array = StadiumScoreboardTiers.readouts("video").keys()
	ordered.append_array(StadiumScoreboardTiers.detail_slots("video").keys())
	for index in range(ordered.size()):
		var key: String = ordered[index]
		var label: Label3D = display.get_child(index) as Label3D
		if label == null:
			return false
		if index < 3:
			if display._labels[key] != label \
				or label.text != ("—" if display.shown.is_empty() else str(display.shown[key])):
				return false
		else:
			if display._detail_labels[key] != label:
				return false
			var text: String = "—"
			if not display.details.is_empty():
				if not display.details[key] is String or display.details[key].length() > 512 \
					or StadiumScoreboardReadout.clean(display.details[key]) != display.details[key]:
					return false
				text = StadiumScoreboardTierDisplay._fit(display.details[key], label,
					StadiumScoreboardTiers.detail_slots("video")[key].width)
			if label.text != text:
				return false
	return true


static func _same_geometry(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty,
	lighting_root: Node) -> bool:
	if lighting_root == null:
		return StadiumNpcRetainedGeometry.same(actual, expected)
	# Caller first verifies the exact active_lighting lease. Only that single direct sibling
	# is separate from immutable geometry; every other root/member remains byte-compared.
	if not is_instance_valid(lighting_root) or lighting_root.get_parent() != actual \
		or lighting_root.name != &"GrandIIIActiveLighting" or lighting_root.get_script() != null \
		or expected.has_node("GrandIIIActiveLighting") \
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



static func _layer_contract(item: String, site: String) -> Dictionary:
	var base: String = site.get_slice(":", 0)
	var supports: Array = []
	var interface: String = ""
	if item in ["ST-031", "ST-030", "ST-053", "ST-083", "ST-082", "ST-084"]:
		supports.append(INSTANCE_PREFIX + base)
		if item in ["ST-030", "ST-053", "ST-082", "ST-084"]:
			supports.append(INSTANCE_PREFIX + base + ":CONCOURSE")
		if item in ["ST-053", "ST-084"]:
			supports.append(INSTANCE_PREFIX + base + ":UPPER")
		interface = {
			"ST-031": StadiumGrandThreeStackSites.INTERFACE,
			"ST-030": StadiumGrandThreeStackSites.UPPER_INTERFACE,
			"ST-053": StadiumGrandThreeStackSites.ROOF_INTERFACE,
			"ST-083": StadiumCurvedStackSites.INTERFACE,
			"ST-082": StadiumCurvedStackSites.UPPER_INTERFACE,
			"ST-084": StadiumCurvedCanopySites.INTERFACE}[item]
	elif item in ["ST-086", "ST-089"]:
		var bowl: String = StadiumTransitionConcourseSites.bowl_site(base)
		var straight: String = StadiumTransitionConcourseSites.base_site(base)
		supports = [INSTANCE_PREFIX + base, INSTANCE_PREFIX + bowl,
			INSTANCE_PREFIX + bowl + ":CONCOURSE", INSTANCE_PREFIX + straight,
			INSTANCE_PREFIX + straight + ":CONCOURSE"]
		interface = StadiumGrandThreeStackSites.TRANSITION_INTERFACE
	return {} if supports.is_empty() else {"supports": supports, "interface": interface}


static func _layers_intact(model: Node3D, row: Dictionary,
	property: StadiumNpcPublicProperty) -> bool:
	if row.item in ["ST-085", "ST-088"]:
		return BASE.exact_meta(model, "model_version", 1) \
			and StadiumLowerTransitionSites.item(row.site) == row.item \
			and BASE.exact_meta(model, "baseline_end", "stair" if row.site == "JOIN-R" else "solid")
	var contract: Dictionary = _layer_contract(row.item, row.site)
	if contract.is_empty():
		return true
	var variant: String = {"ST-031": "STRAIGHT-CONCOURSE-GUARD-v2",
		"ST-030": "STRAIGHT-UPPER-GUARD-v2", "ST-053": "STRAIGHT-UPPER-CANOPY-v2",
		"ST-086": "TRANSITION-ROOF-NEIGHBOR-v2", "ST-089": "TRANSITION-ROOF-NEIGHBOR-v2"
		}.get(row.item, "")
	if not BASE.exact_meta(model, "model_version", 1 if variant.is_empty() else 2) \
		or (not variant.is_empty() and not BASE.exact_meta(model, "model_variant", variant)) \
		or not BASE.exact_meta(model, "interface", contract.interface) \
		or not BASE.exact_meta(model, "npc_supports", contract.supports):
		return false
	for binding: StringName in StadiumGrandThreeStackSites.BINDINGS:
		if model.has_meta(binding):
			return false
	var expected_items: Array = ["ST-029", "ST-031", "ST-030"] \
		if row.item in ["ST-031", "ST-030", "ST-053"] else ["ST-081", "ST-083", "ST-082"]
	var transition: bool = row.item in ["ST-086", "ST-089"]
	if transition:
		expected_items = ["ST-085" if row.item == "ST-086" else "ST-088",
			"ST-081", "ST-083", "ST-029", "ST-031"]
	for index in range(contract.supports.size()):
		var support: Node3D = property.objects.get(contract.supports[index]) as Node3D
		if not is_instance_valid(support) or support.get_parent() != model.get_parent() \
			or not BASE.exact_meta(support, "stadium_item", expected_items[index]) \
			or (not transition and support.transform != model.transform):
			return false
	if row.item in ["ST-053", "ST-084"]:
		return BASE.exact_meta(model, "roof_state",
			"BASE-UPPER-ROOF-v1" if row.item == "ST-053" else "BOWL-UPPER-ROOF-v1")
	return true


static func _exterior_intact(model: Node3D, row: Dictionary) -> bool:
	if row.item == "ST-040":
		return row.site == BOARD_SITE \
			and BASE.exact_meta(model, "scoreboard_candidate", "video") \
			and BASE.exact_meta(model, "scoreboard_owned_model", "video-v2") \
			and BASE.exact_meta(model, "scoreboard_model_version", 2) \
			and BASE.exact_meta(model, "surface_role", &"DECORATIVE_AFTER_TERMINAL") \
			and model.find_children("*", "CollisionObject3D", true, false).is_empty()
	if row.item == "ST-046":
		return row.site == "LANDMARK-A" \
			and BASE.exact_meta(model, "geometry_version", 1) \
			and BASE.exact_meta(model, "immutable_geometry_only", true) \
			and BASE.exact_meta(model, "obstacle_units", 0) \
			and BASE.exact_meta(model, "night_qualified", false) \
			and not model.has_meta("working_geometry_only")
	return true




static func components(pose: Transform3D) -> Array:
	return BASE.components(pose)


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	return BASE.exact_meta(node, key, value)


static func _public_tower(tower: Node3D) -> bool:
	if not exact_meta(tower, "stadium_item", "ST-076") \
		or not exact_meta(tower, "geometry_version", 1) \
		or not exact_meta(tower, "working_geometry_only", true) \
		or not exact_meta(tower, "night_qualified", false) \
		or not exact_meta(tower, "candidate_preset", StadiumPremiumLightTowerSites.PRESET) \
		or not tower.has_meta("candidate_head_rays") \
		or not tower.get_meta("candidate_head_rays") is Array:
		return false
	# Copy metadata only. Shared factory, tower poses and head local transforms stay frozen.
	tower.set_meta("npc_head_rays", tower.get_meta("candidate_head_rays").duplicate(true))
	tower.set_meta("npc_lighting_preset", tower.get_meta("candidate_preset"))
	tower.set_meta("immutable_geometry_only", true)
	for marker: String in ["candidate_head_rays", "candidate_preset", "working_geometry_only"]:
		tower.remove_meta(marker)
	return true


static func _tower_intact(tower: Node3D, site: String) -> bool:
	if not StadiumPremiumLightTowerSites.SITES.has(site) \
		or not exact_meta(tower, "geometry_version", 1) \
		or not exact_meta(tower, "immutable_geometry_only", true) \
		or not exact_meta(tower, "night_qualified", false) \
		or not exact_meta(tower, "obstacle_units", 0) \
		or not exact_meta(tower, "aim_profile", StadiumPremiumLightTowerSites.PROFILE) \
		or not exact_meta(tower, "npc_lighting_preset", StadiumPremiumLightTowerSites.PRESET) \
		or not exact_meta(tower, "reference_target", StadiumPremiumLightTowerSites.TARGETS[site]) \
		or not tower.has_meta("npc_head_rays") or not tower.get_meta("npc_head_rays") is Array:
		return false
	var reference: Node3D = StadiumPremiumLightTowerModels.create()
	if reference == null:
		return false
	var valid_tower: bool = StadiumPremiumLightTowerSites.place(reference, site)
	if valid_tower:
		valid_tower = var_to_bytes(tower.get_meta("npc_head_rays")) \
			== var_to_bytes(reference.get_meta("candidate_head_rays"))
	for index in range(8):
		var head: Node3D = tower.get_node_or_null("Visual/Head%d" % index) as Node3D
		var expected: Node3D = reference.get_node_or_null("Visual/Head%d" % index) as Node3D
		if head == null or expected == null or head.transform != expected.transform:
			valid_tower = false
	reference.free()
	return valid_tower


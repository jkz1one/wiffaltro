class_name StadiumPoolPartyPublicConstruction
extends Node3D
## Immutable DB Pool Party: exact65 existing copies, one neutral fixed-pose live pool.
## Construction/cold audit only; no owned Backyard16 claim, admission or League rules.
# gdlint: disable=max-returns

const INSTANCE_PREFIX: String = "npc:POOL-PARTY:r1:"
const OWNER: String = "finals-venue:pool-party:v1"
const BOARD_SITE: String = "SCORE-SMALL"
const POOL_SITE: String = "OL-R"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const COUNTS: Dictionary = {
	"ST-024": 23, "ST-022": 16, "ST-023": 16, "ST-032": 2, "ST-021": 2,
	"ST-026": 1, "ST-025": 1, "ST-006": 1, "ST-027": 2, "ST-039": 1
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "expanded"
var pool_model: Node3D


static func build() -> StadiumPoolPartyPublicConstruction:
	var result: StadiumPoolPartyPublicConstruction = StadiumPoolPartyPublicConstruction.new()
	result.name = "PoolPartyPublicRevision1"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	field = FIELD.duplicate(true) as FieldDefinition
	var template: StadiumNpcExpandedV1 = StadiumNpcExpandedV1.new()
	template.field = field
	template._surface()
	for child: Node in template.get_children():
		template.remove_child(child)
		add_child(child)
		if not child is Node3D:
			continue
		var edge: Node3D = child as Node3D
		if absf(edge.position.x) == 32:
			edge.position.x = signf(edge.position.x) * 31.96
		elif edge.position.z == -16:
			edge.position.z = -15.96
		elif edge.position.z == 38:
			edge.position.z = 37.96
	template.free()
	var boundary: StadiumPoolPartyPublicBoundarySource = StadiumPoolPartyPublicBoundarySource.new()
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
	for site: String in ["SIDE-SEAT-L", "SIDE-SEAT-R"]:
		var stand: Node3D = StadiumSeatingModels.create("ST-027")
		if stand == null:
			return false
		add_child(stand)
		stand.transform = pose(site)
		_register(stand, site)
	var board: Node3D = StadiumClubModels.create("ST-039")
	if board == null:
		return false
	add_child(board)
	board.transform = pose(BOARD_SITE)
	_register(board, BOARD_SITE)
	var pool: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if pool == null:
		return false
	pool.transform = StadiumPoolContract.placement()
	add_child(pool)
	# Preserve the complete shared model tree. Neutral identity lives in this outer map only.
	# No owned_copy, npc_instance, authority or water-award metadata is injected into ST006.
	objects[INSTANCE_PREFIX + POOL_SITE] = pool
	pool_model = pool
	set_meta("layout_revision", StadiumPoolPartyDefinitionV1.source_layout())
	return objects.size() == 65


static func pose(site: String) -> Transform3D:
	match site:
		"SIDE-SEAT-L":
			return Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT),
				Vector3(-24, 0, 12.5))
		"SIDE-SEAT-R":
			return Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3.LEFT),
				Vector3(24, 0, 12.5))
		"SCORE-SMALL":
			return Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD),
				Vector3(-20, 0, 30))
		"OL-R":
			return StadiumPoolContract.placement()
	return Transform3D.IDENTITY


func _register(model: Node3D, site: String) -> void:
	var identity: String = INSTANCE_PREFIX + site
	for key: String in ["candidate_site", "candidate_instance", "candidate_mount"]:
		if model.has_meta(key):
			model.remove_meta(key)
	model.set_meta("owned_copy", identity)
	model.set_meta("npc_instance", identity)
	model.set_meta("npc_site", site)
	model.set_meta("npc_host", "field")
	model.set_meta("site", "RECEIVER-NET" if site == "RECEIVER-CATCH" else site)
	objects[identity] = model
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		body.set_meta("npc_instance", identity)
		body.set_meta("owned_copy", identity)


func route_obstacles() -> Array[Dictionary]:
	# Existing receiver/pool envelope route policy; never the larger site reservation.
	var result: Array[Dictionary] = []
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var model: Node3D = objects[INSTANCE_PREFIX + site]
		var envelope: AABB = StadiumNetModels.ENVELOPE if site == "RECEIVER-CATCH" \
			else StadiumTargetModels.ENVELOPE
		var bounds: AABB = model.transform * envelope
		result.append({"center": bounds.get_center(),
			"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32,
			"copy": INSTANCE_PREFIX + site})
	result.append({"center": pool_model.position,
		"radius": StadiumPoolContract.VISUAL_RADIUS + StadiumDefenderRoutes.BODY_RADIUS,
		"copy": INSTANCE_PREFIX + POOL_SITE})
	return result


static func valid(property: StadiumNpcPublicProperty) -> bool:
	if not is_instance_valid(property) or property.get_script() != StadiumNpcPublicProperty \
		or property.venue_id != "POOL-PARTY" or property.tier != "expanded" \
		or property.transform != Transform3D.IDENTITY \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumPoolPartyPublicConstruction \
		or property.construction.get_parent() != property \
		or property.construction.tier != "expanded" \
		or not is_instance_valid(property.field) or property.field == FIELD \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.construction.pool_model != property.objects.get(INSTANCE_PREFIX + POOL_SITE) \
		or property.objects != property.construction.objects or property.objects.size() != 65:
		return false
	if not exact_meta(property.construction, "layout_revision",
		StadiumPoolPartyDefinitionV1.source_layout()):
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
	var source: StadiumPoolPartyPublicBoundarySource = property.construction.get_node_or_null(
		"ClubBoundary") as StadiumPoolPartyPublicBoundarySource
	if source == null or source.graph == null \
		or source.graph.get_script() != StadiumTimberDugoutBoundary \
		or source.graph.signature() != StadiumPoolPartyDefinitionV1.payload().graph.sha256:
		return false
	var counts: Dictionary = {}
	for row: Dictionary in StadiumPoolPartyDefinitionV1.payload().instances:
		var candidate: Variant = property.objects.get(row.instance)
		if not candidate is Node3D:
			return false
		var model: Node3D = candidate
		if not is_instance_valid(model) or not property.construction.is_ancestor_of(model) \
			or row.host != "field" or not _identity_ancestors(model.get_parent(), property.construction) \
			or not exact_meta(model, "stadium_item", row.item) \
			or components(model.transform) != Array(PackedFloat32Array(row.transform)):
			return false
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		if row.item == "ST-006":
			if row.site != POOL_SITE or not _pool_intact(model):
				return false
			continue
		if not exact_meta(model, "npc_instance", row.instance) \
			or not exact_meta(model, "owned_copy", row.instance) \
			or not exact_meta(model, "npc_host", row.host) \
			or not exact_meta(model, "npc_site", row.site):
			return false
		if row.item == "ST-021" and (not exact_meta(model, "wall_cap_height", 3.25) \
			or not exact_meta(model.get_node_or_null("Collision/Pole"), "wall_cap_height", 3.25)):
			return false
		if row.item == "ST-032" and (not exact_meta(model, "geometry_version", 1) \
			or not exact_meta(model, "model_id", StadiumTimberDugoutContract.ID) \
			or not exact_meta(model, "runtime_adapter", "ST032_SPHERE_SWEEP_v1") \
			or model.has_meta("stadium_candidate_only")):
			return false
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			if not exact_meta(body, "npc_instance", row.instance) \
				or not exact_meta(body, "owned_copy", row.instance):
				return false
	return counts == COUNTS and clean_tree(property)


static func clean_tree(property: StadiumNpcPublicProperty) -> bool:
	# Only exact unchanged ST006 may retain its shared model's descriptive candidate labels.
	var pool: Node3D = property.objects.get(INSTANCE_PREFIX + POOL_SITE) as Node3D
	if not is_instance_valid(pool) or not _pool_intact(pool):
		return false
	return _clean_except_pool(property, pool, property)


static func _clean_except_pool(node: Node, pool: Node3D,
	property: StadiumNpcPublicProperty) -> bool:
	if node == pool:
		return true
	if node is Light3D or not StadiumMountedScoreboardContract._clean(node):
		return false
	for marker: StringName in node.get_meta_list():
		if String(marker).begins_with("candidate_"):
			return false
	for key: String in ["npc_instance", "owned_copy"]:
		if node.has_meta(key) and (not node.get_meta(key) is String \
			or not property.objects.has(node.get_meta(key))):
			return false
	for child: Node in node.get_children():
		if not _clean_except_pool(child, pool, property):
			return false
	return true


static func _pool_intact(model: Node3D) -> bool:
	if not is_instance_valid(model) or model.transform != StadiumPoolContract.placement() \
		or model.has_meta("owned_copy") or model.has_meta("npc_instance"):
		return false
	var reference: Node3D = StadiumPoolModelsV2.create(StadiumPoolContract.LIVE)
	if reference == null:
		return false
	reference.transform = StadiumPoolContract.placement()
	var result: bool = StadiumPoolPartyAssetIntegrity.same_tree(model, reference)
	reference.free()
	return result


static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty) -> bool:
	# Cold admission/diagnostic only. Shared retained geometry bounds paired target/net flex.
	return _align_display(actual, expected) and valid(actual) and valid(expected) \
		and var_to_bytes(StadiumLongYardPublicConstruction._metadata(
			actual.construction, actual)) \
		== var_to_bytes(StadiumLongYardPublicConstruction._metadata(
			expected.construction, expected)) \
		and StadiumNpcRetainedGeometry.same(actual, expected)


static func _align_display(actual: StadiumNpcPublicProperty,
	expected: StadiumNpcPublicProperty) -> bool:
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
	var board: Node3D = property.objects.get(INSTANCE_PREFIX + BOARD_SITE) as Node3D
	var display: StadiumScoreboardDisplay = property.display as StadiumScoreboardDisplay
	if not is_instance_valid(board) or not is_instance_valid(display) \
		or display.get_script() != StadiumScoreboardDisplay \
		or board.get_node_or_null("Visual/ScoreDisplay") != display \
		or display.get_child_count() != 6 \
		or not SeasonOwnership._keys(display._labels, ["inning", "home", "away"]) \
		or not StadiumLongYardPublicConstruction._score_values(display.shown) \
		or (not display._pending.is_empty() \
			and not StadiumLongYardPublicConstruction._score_values(display._pending)):
		return false
	for index in range(3):
		var key: String = ["inning", "home", "away"][index]
		var caption: Label3D = display.get_child(index * 2) as Label3D
		var numeric: Label3D = display.get_child(index * 2 + 1) as Label3D
		if caption == null or numeric == null or caption.text != key.to_upper() \
			or display._labels[key] != numeric or numeric.text != str(display.shown[key]):
			return false
	return true


static func _identity_ancestors(node: Node, construction: Node3D) -> bool:
	var current: Node = node
	while current != null and current != construction:
		if not current is Node3D or current.transform != Transform3D.IDENTITY:
			return false
		current = current.get_parent()
	return current == construction and construction.transform == Transform3D.IDENTITY


static func components(value: Transform3D) -> Array:
	return StadiumLongYardPublicConstruction.components(value)


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	return StadiumLongYardPublicConstruction.exact_meta(node, key, value)

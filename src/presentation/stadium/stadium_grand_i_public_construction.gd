class_name StadiumGrandIPublicConstruction
extends Node3D
## Detached authored GRAND-I v1 / public revision1; exact75 copies; dormant six-tower geometry.
## Cold construction/audit only. Installation and issued callbacks belong to common authority.
# gdlint: disable=max-returns

const INSTANCE_PREFIX: String = "npc:GRAND-I:r1:"
const OWNER: String = "npc-venue:grandstand-gardens:grand-i-v1"
const BOARD_SITE: String = "SCORE-SMALL"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const BASE_SITES: Array[String] = ["BASE-L1", "BASE-L2", "BASE-R1", "BASE-R2"]
const COUNTS: Dictionary = {
	"ST-065": 23, "ST-022": 16, "ST-023": 16, "ST-074": 2, "ST-021": 2,
	"ST-026": 1, "ST-073": 1, "ST-029": 4, "ST-081": 3, "ST-038": 6, "ST-039": 1
}
var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "mogul"


static func build() -> StadiumGrandIPublicConstruction:
	var result: StadiumGrandIPublicConstruction = StadiumGrandIPublicConstruction.new()
	result.name = "GrandIPublicRevision1"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	field = FIELD.duplicate(true) as FieldDefinition
	_surface()
	var boundary: StadiumGrandIPublicBoundarySource = StadiumGrandIPublicBoundarySource.new()
	boundary.name = "ClubBoundary"
	add_child(boundary)
	if not boundary.build():
		return false
	# Preserve original straight-field guide arithmetic; no deeper-center endpoint rewrite.
	for model: Node3D in boundary.items:
		if not model.has_meta("candidate_site") \
			or not (model.get_meta("candidate_site") is String \
			or model.get_meta("candidate_site") is StringName):
			return false
		_register(model, String(model.get_meta("candidate_site")))
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
	for site: String in StadiumCurvedLowerSites.GRAND_I:
		var bowl: Node3D = StadiumCurvedLowerModels.create()
		if bowl == null or not exact_meta(bowl, "stadium_item", "ST-081") \
			or not exact_meta(bowl, "model_version", 1) \
			or not exact_meta(bowl, "authoring_status", "Working"):
			if bowl != null:
				bowl.free()
			return false
		bowl.remove_meta("authoring_status")
		add_child(bowl)
		bowl.transform = StadiumCurvedLowerSites.pose(site)
		_register(bowl, site)
	for site: String in StadiumFourHeadTowerSites.SITES:
		var tower: Node3D = StadiumFourHeadTowerModels.create()
		if tower == null:
			return false
		add_child(tower)
		if not StadiumFourHeadTowerSites.place(tower, site) or not _public_tower(tower):
			return false
		_register(tower, site)
	var board: Node3D = StadiumClubModels.create("ST-039")
	add_child(board)
	board.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(-20, 0, 30))
	_register(board, BOARD_SITE)
	return objects.size() == 75


static func _normalize_working_model(model: Node3D, item: String,
	version: int, variant: String) -> bool:
	# Only exact freshly built stand roots lose the descriptive Working label.
	if not exact_meta(model, "stadium_item", item) \
		or not exact_meta(model, "model_version", version) \
		or not exact_meta(model, "model_variant", variant) \
		or not exact_meta(model, "authoring_status", "Working"):
		return false
	model.remove_meta("authoring_status")
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
	_bounds_obstacle(result, target.transform * StadiumTargetModels.ENVELOPE)
	var net: Node3D = objects[INSTANCE_PREFIX + "RECEIVER-CATCH"]
	for body: StaticBody3D in net.get_node("Collision").get_children():
		if body.has_meta("surface_id") \
			and String(body.get_meta("surface_id")).begins_with("ST073_ANCHOR"):
			var shape: CollisionShape3D = body.get_child(0)
			var size: Vector3 = (shape.shape as BoxShape3D).size
			_bounds_obstacle(result,
				net.transform * body.transform * shape.transform * AABB(-size / 2, size))
	return result


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	if not is_instance_valid(node) or not node.has_meta(key):
		return false
	var actual: Variant = node.get_meta(key)
	if (value is String or value is StringName) and (actual is String or actual is StringName):
		return String(actual) == String(value)
	return typeof(actual) == typeof(value) and actual == value


static func components(pose: Transform3D) -> Array:
	return [pose.basis.x.x, pose.basis.x.y, pose.basis.x.z,
		pose.basis.y.x, pose.basis.y.y, pose.basis.y.z,
		pose.basis.z.x, pose.basis.z.y, pose.basis.z.z,
		pose.origin.x, pose.origin.y, pose.origin.z]


static func valid(property: StadiumNpcPublicProperty) -> bool:
	if not is_instance_valid(property) or property.get_script() != StadiumNpcPublicProperty \
		or property.venue_id != "GRAND-I" \
		or not is_instance_valid(property.construction) \
		or property.construction.get_script() != StadiumGrandIPublicConstruction \
		or property.construction.get_parent() != property \
		or not is_instance_valid(property.field) or property.field == FIELD \
		or property.field.get_script() != FieldDefinition \
		or property.construction.field != property.field \
		or property.construction.tier != "mogul" \
		or property.transform != Transform3D.IDENTITY \
		or property.objects != property.construction.objects or property.objects.size() != 75 \
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
		or source.graph.signature() != StadiumGrandIDefinitionV1.payload().graph.sha256:
		return false
	var counts: Dictionary = {}
	for row: Dictionary in StadiumGrandIDefinitionV1.payload().instances:
		var candidate: Variant = property.objects.get(row.instance)
		if not candidate is Node3D:
			return false
		var model: Node3D = candidate
		if not is_instance_valid(model) or not property.construction.is_ancestor_of(model) \
			or not exact_meta(model, "npc_instance", row.instance) \
			or not exact_meta(model, "owned_copy", row.instance) \
			or not exact_meta(model, "npc_host", row.host) \
			or not exact_meta(model, "npc_site", row.site) \
			or not exact_meta(model, "stadium_item", row.item) \
			or components(model.transform) != Array(PackedFloat32Array(row.transform)):
			return false
		if row.host != "field" or not _identity_ancestors(model.get_parent(), property.construction):
			return false
		counts[row.item] = int(counts.get(row.item, 0)) + 1
		if row.item == "ST-021" and (not exact_meta(model, "wall_cap_height", 3.25) \
			or not exact_meta(model.get_node_or_null("Collision/Pole"), "wall_cap_height", 3.25)):
			return false
		if row.item == "ST-029" and (not exact_meta(model, "model_version", 2) \
			or not exact_meta(model, "model_variant", "BASE-LOWER-SIGHTLINE-v2")):
			return false
		if row.item == "ST-081" and (not exact_meta(model, "model_version", 1) \
			or row.site not in StadiumCurvedLowerSites.GRAND_I):
			return false
		if row.item == "ST-038" and not _tower_intact(model, row.site):
			return false
		for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
			if _model_owner(body, property) != model:
				continue
			if not exact_meta(body, "npc_instance", row.instance) \
				or not exact_meta(body, "owned_copy", row.instance):
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


static func _metadata(node: Node, property: StadiumNpcPublicProperty) -> Dictionary:
	var result: Dictionary = {"meta": {}, "children": []}
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		if key == &"receiver_render_state" and is_instance_valid(property.receiver) \
			and node in [property.receiver.chair, property.receiver.net]:
			continue
		result.meta[String(key)] = node.get_meta(key)
	for child: Node in node.get_children():
		result.children.append(_metadata(child, property))
	return result


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
		and var_to_bytes(_metadata(actual.construction, actual)) \
		== var_to_bytes(_metadata(expected.construction, expected)) \
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
			if (identity is String or identity is StringName) \
				and property.objects.get(String(identity)) == current:
				return current as Node3D
		current = current.get_parent()
	return null


static func _bounds_obstacle(result: Array[Dictionary], bounds: AABB) -> void:
	result.append({"center": bounds.get_center(),
		"radius": Vector2(bounds.size.x, bounds.size.z).length() / 2 + 0.32})


static func _identity_ancestors(node: Node, root: Node3D) -> bool:
	while is_instance_valid(node):
		if node is Node3D and node.transform != Transform3D.IDENTITY:
			return false
		if node == root:
			return true
		node = node.get_parent()
	return false


static func _public_tower(tower: Node3D) -> bool:
	if not exact_meta(tower, "stadium_item", "ST-038") \
		or not exact_meta(tower, "geometry_version", 1) \
		or not exact_meta(tower, "working_geometry_only", true) \
		or not exact_meta(tower, "night_qualified", false) \
		or not exact_meta(tower, "candidate_preset", StadiumFourHeadTowerSites.PRESET) \
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
	if not StadiumFourHeadTowerSites.SITES.has(site) \
		or not exact_meta(tower, "geometry_version", 1) \
		or not exact_meta(tower, "immutable_geometry_only", true) \
		or not exact_meta(tower, "night_qualified", false) \
		or not exact_meta(tower, "obstacle_units", 0) \
		or not exact_meta(tower, "aim_profile", StadiumFourHeadTowerSites.PROFILE) \
		or not exact_meta(tower, "npc_lighting_preset", StadiumFourHeadTowerSites.PRESET) \
		or not exact_meta(tower, "reference_target", StadiumFourHeadTowerSites.TARGETS[site]) \
		or not tower.has_meta("npc_head_rays") or not tower.get_meta("npc_head_rays") is Array:
		return false
	var reference: Node3D = StadiumFourHeadTowerModels.create()
	if reference == null:
		return false
	var valid_tower: bool = StadiumFourHeadTowerSites.place(reference, site)
	if valid_tower:
		valid_tower = var_to_bytes(tower.get_meta("npc_head_rays")) \
			== var_to_bytes(reference.get_meta("candidate_head_rays"))
	for index in range(4):
		var head: Node3D = tower.get_node_or_null("Visual/Head%d" % index) as Node3D
		var expected: Node3D = reference.get_node_or_null("Visual/Head%d" % index) as Node3D
		if head == null or expected == null or head.transform != expected.transform:
			valid_tower = false
	reference.free()
	return valid_tower


func _surface() -> void:
	var ground: AABB = AABB(Vector3(-52, -0.16, -30), Vector3(104, 0.16, 88))
	_box("PropertyGround", ground.get_center(), ground.size, Color("315640"), &"ground")
	_box("Plate", Vector3(0, 0.025, 0), Vector3(0.70, 0.05, 0.45), Color("e7e1cf"))
	_box("Mound", Vector3(0.0, 0.0, 13.716) + Vector3(0, 0.025, 0),
		Vector3(0.8, 0.05, 0.8), Color("927553"))
	for band: Array in [
		["Safe", field.safe_hit_z_m, Color("e4ca66")], ["Deep", field.deep_air_z_m, Color("70c0c3")]
	]:
		var half: float = float(band[1]) * tan(deg_to_rad(field.fair_half_angle_degrees))
		_box(band[0], Vector3(0, 0.016, band[1]), Vector3(half * 2, 0.025, 0.08), band[2])
	for side: int in [-1, 1]:
		var end: Vector3 = Vector3(
			side * field.back_wall_z_m * tan(deg_to_rad(field.fair_half_angle_degrees)),
			0,
			field.back_wall_z_m
		)
		var line: Node3D = _box(
			"FoulLine" + str(side),
			end / 2 + Vector3(0, 0.02, 0),
			Vector3(0.055, 0.025, end.length()),
			Color("d8ded0")
		)
		line.rotation.y = atan2(end.x, end.z)
	var bounds: Rect2 = Rect2(-52, -30, 104, 88)
	for edge: Array in [
		[
			Vector3(-51.96, 0.02, bounds.get_center().y),
			Vector3(0.08, 0.02, bounds.size.y)
		],
		[Vector3(51.96, 0.02, bounds.get_center().y), Vector3(0.08, 0.02, bounds.size.y)],
		[Vector3(0, 0.02, -29.96), Vector3(bounds.size.x, 0.02, 0.08)],
		[Vector3(0, 0.02, 57.96), Vector3(bounds.size.x, 0.02, 0.08)]
	]:
		_box("LandEdge", edge[0], edge[1], Color("84a67e"))


func _box(
	id: String, center: Vector3, size: Vector3, color: Color, surface: StringName = &""
) -> Node3D:
	var root: Node3D = Node3D.new() if surface.is_empty() else StaticBody3D.new()
	root.name = id
	root.position = center
	if root is StaticBody3D:
		root.collision_layer = 1
		root.collision_mask = 2
		root.set_meta("ball_surface", surface)
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = size
		root.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.mesh.size = size
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	root.add_child(mesh)
	add_child(root)
	return root


static func _same_geometry(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty,
	lighting_root: Node) -> bool:
	if lighting_root == null:
		return StadiumNpcRetainedGeometry.same(actual, expected)
	# Caller first verifies the exact active_lighting lease. Only that single direct sibling
	# is separate from immutable geometry; every other root/member remains byte-compared.
	if not is_instance_valid(lighting_root) or lighting_root.get_parent() != actual \
		or lighting_root.name != &"GrandIActiveLighting" or lighting_root.get_script() != null \
		or expected.has_node("GrandIActiveLighting") \
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

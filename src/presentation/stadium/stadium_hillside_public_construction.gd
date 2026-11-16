class_name StadiumHillsidePublicConstruction
extends Node3D
## DD exact eight retained copies on the accepted CV terrain. Detached prerequisite only.
## Geometry identity is not public admission, physical qualification or player ownership.
# gdlint: disable=max-returns

const INSTANCE_PREFIX: String = "npc:HILLSIDE:r1:"
const OWNER: String = "finals-venue:hillside:v1"
const FIELD: Resource = preload("res://src/content/fields/npc_venue_field.tres")
const COUNTS: Dictionary = {"ST-021": 2, "ST-025": 1, "ST-026": 1, "ST-027": 2, "ST-032": 2}
const SITES: Array[String] = ["DUGOUT-L", "DUGOUT-R", "FOUL-POLE-L", "FOUL-POLE-R",
	"RECEIVER-CATCH", "RECEIVER-PRIMARY", "SIDE-SEAT-L", "SIDE-SEAT-R"]
const ITEMS: Array[String] = ["ST-032", "ST-032", "ST-021", "ST-021",
	"ST-025", "ST-026", "ST-027", "ST-027"]

const CONTACT_ADAPTER: String = "HILLSIDE_ST032_FINITE_SPHERE_v1"

var objects: Dictionary = {}
var field: FieldDefinition
var tier: String = "expanded"
var terrain: Node3D
var boundary: StadiumHillsidePublicBoundarySource


var _contact_adapter: WeakRef


static func build() -> StadiumHillsidePublicConstruction:
	var result: StadiumHillsidePublicConstruction = StadiumHillsidePublicConstruction.new()
	result.name = "HillsidePublicRevision1Prerequisite"
	if not result._build():
		result.free()
		return null
	return result


func _build() -> bool:
	if get_script() != StadiumHillsidePublicConstruction or get_child_count() != 0 \
		or not objects.is_empty() or transform != Transform3D.IDENTITY:
		return false
	field = FIELD.duplicate(true) as FieldDefinition
	terrain = StadiumHillsideTerrainModels.create("hill")
	if field == null or terrain == null:
		return false
	terrain.name = "HillsideTerrain"
	add_child(terrain)
	boundary = StadiumHillsidePublicBoundarySource.new()
	boundary.name = "HillsideBoundary"
	add_child(boundary)
	if not boundary.build():
		return false
	for index in range(SITES.size()):
		var site: String = SITES[index]
		var model: Node3D = _model(ITEMS[index])
		if model == null:
			return false
		model.transform = pose(site)
		model.name = site
		add_child(model)
		_register(model, site)
		if ITEMS[index] in ["ST-025", "ST-026"]:
			model.process_mode = Node.PROCESS_MODE_PAUSABLE
			for body: StaticBody3D in model.get_node("Collision").get_children():
				body.collision_layer |= StadiumPitchReceiver.LAYER
	if not boundary.register_members(self):
		return false
	_flat_markers()
	_terrain_markings()
	set_meta("layout_revision", StadiumHillsideDefinitionV1.source_layout())
	set_meta("production_ready", false)
	return objects.size() == 8


static func _model(item: String) -> Node3D:
	match item:
		"ST-032":
			# Retain NOT_IMPLEMENTED and candidate-only metadata honestly. No sphere adapter is bound.
			return StadiumTimberDugoutModels.create()
		"ST-021":
			return StadiumFoulPoleModels.create(3.25)
		"ST-025":
			return StadiumNetModels.create()
		"ST-026":
			return StadiumTargetModels.create()
		"ST-027":
			return StadiumSeatingModels.create("ST-027")
	return null


static func pose(site: String) -> Transform3D:
	match site:
		"DUGOUT-L", "DUGOUT-R":
			return StadiumTimberDugoutContract.placement(site == "DUGOUT-L")
		"RECEIVER-PRIMARY":
			return Transform3D(Basis.IDENTITY, StadiumTargetModels.POSITION)
		"RECEIVER-CATCH":
			return Transform3D(Basis.IDENTITY, StadiumNetModels.POSITION)
		"SIDE-SEAT-L", "SIDE-SEAT-R":
			return StadiumNpcExpandedV1.pose(site)
		"FOUL-POLE-L", "FOUL-POLE-R":
			for row: Dictionary in StadiumFoulPoleSites.rows(
				StadiumRecipeBoundary.create("deeper_center")):
				if row.site == site:
					var at: Vector3 = row.position
					at.y = StadiumHillsideTerrain.support_height(Vector2(at.x, at.z), "hill")
					return Transform3D(Basis.IDENTITY, at)
	return Transform3D.IDENTITY


func _register(model: Node3D, site: String) -> void:
	var identity: String = INSTANCE_PREFIX + site
	# These neutral correspondence labels never represent a player's stock or unlocks.
	model.set_meta("owned_copy", identity)
	model.set_meta("npc_instance", identity)
	model.set_meta("npc_site", site)
	model.set_meta("npc_host", "field")
	model.set_meta("site", "RECEIVER-NET" if site == "RECEIVER-CATCH" else site)
	objects[identity] = model
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		# These four pinned families have 72 sole, previously anonymous colliders.
		if model.get_meta("stadium_item") in ["ST-021", "ST-025", "ST-026", "ST-027"] \
			and body.get_child_count() == 1 and body.get_child(0) is CollisionShape3D:
			body.get_child(0).name = "Shape"
		body.set_meta("npc_instance", identity)
		body.set_meta("owned_copy", identity)


func _flat_markers() -> void:
	# Reuse only the ordinary plate and mound. Never create/carry an invisible flat ground.
	var template: StadiumNpcExpandedV1 = StadiumNpcExpandedV1.new()
	template._box("Plate", Vector3(0, 0.025, 0), Vector3(0.70, 0.05, 0.45), Color("e7e1cf"))
	template._box("Mound", StadiumNpcExpandedV1.MOUND_ORIGIN + Vector3(0, 0.025, 0),
		Vector3(0.8, 0.05, 0.8), Color("927553"))
	for child: Node in template.get_children():
		# Only the two retained marker meshes need stable construction-local names.
		if child.name in [&"Plate", &"Mound"] and child.get_child_count() == 1 \
			and child.get_child(0) is MeshInstance3D:
			child.get_child(0).name = "Visual"
		template.remove_child(child)
		add_child(child)
	template.free()


func _terrain_markings() -> void:
	# Same retained terrain knots and named XZ scoring bands; visual markings only.
	var mesh: SurfaceTool = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_LINES)
	for z: float in [field.safe_hit_z_m, field.deep_air_z_m]:
		var half_width: float = z * tan(deg_to_rad(field.fair_half_angle_degrees))
		mesh.add_vertex(StadiumHillsideTerrain.point(-half_width, z) + Vector3(0, 0.01, 0))
		mesh.add_vertex(StadiumHillsideTerrain.point(half_width, z) + Vector3(0, 0.01, 0))
	for site: String in ["FOUL-POLE-L", "FOUL-POLE-R"]:
		var end: Vector3 = pose(site).origin
		var previous: Vector3 = Vector3(0, 0.01, 0)
		for z: float in StadiumHillsideTerrain.knots():
			if z <= 0 or z >= end.z:
				continue
			var at: Vector3 = StadiumHillsideTerrain.point(end.x * z / end.z, z) \
				+ Vector3(0, 0.01, 0)
			mesh.add_vertex(previous)
			mesh.add_vertex(at)
			previous = at
		mesh.add_vertex(previous)
		mesh.add_vertex(end + Vector3(0, 0.01, 0))
	var drawing: MeshInstance3D = MeshInstance3D.new()
	drawing.name = "HillsideOrdinaryMarkings"
	drawing.mesh = mesh.commit()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.9, 0.78)
	drawing.material_override = material
	add_child(drawing)


func cold_valid() -> bool:
	# Detached geometry/source correspondence only, never an issued or hot-path capability.
	if not _structure_valid() or not StadiumHillsideDefinitionV1.sources_valid():
		return false
	var reference: StadiumHillsidePublicConstruction = build()
	if reference == null:
		return false
	if _contact_adapter != null:
		var adapter: StadiumHillsidePublicContactAdapter = _contact_adapter.get_ref()
		if adapter == null or adapter.construction != self or adapter.source != boundary:
			reference.free()
			return false
		reference._contact_labels()
	var result: bool = _same_construction(self, reference)
	reference.free()
	return result


func _structure_valid() -> bool:
	if get_script() != StadiumHillsidePublicConstruction or is_queued_for_deletion() \
		or transform != Transform3D.IDENTITY or (is_inside_tree() \
		and global_transform != Transform3D.IDENTITY) or tier != "expanded" \
		or not is_instance_valid(field) or field == FIELD or field.get_script() != FieldDefinition \
		or not is_instance_valid(terrain) or terrain != get_node_or_null("HillsideTerrain") \
		or not is_instance_valid(boundary) or boundary != get_node_or_null("HillsideBoundary") \
		or boundary.get_script() != StadiumHillsidePublicBoundarySource \
		or not is_instance_valid(boundary.graph) \
		or boundary.graph.get_script() != StadiumHillsidePublicBoundary \
		or boundary.graph._shape != "deeper_center" \
		or boundary.graph.signature() != StadiumHillsideDefinitionV1.payload().graph.sha256 \
		or boundary.bodies.size() != 10 or boundary.get_children() != boundary.bodies \
		or objects.size() != 8 or boundary.items != objects.values() \
		or boundary.member_bodies.size() <= boundary.bodies.size():
		return false
	var actual_slices: int = 0
	for candidate_body: Variant in boundary.bodies:
		if typeof(candidate_body) != TYPE_OBJECT or not is_instance_valid(candidate_body) \
			or not candidate_body is StaticBody3D:
			return false
		var body: StaticBody3D = candidate_body
		actual_slices += body.get_child_count() - 1
	if actual_slices != boundary.slice_count or actual_slices <= 0 \
		or actual_slices > StadiumHillsideBoundaryBody.MAX_SLICES:
		return false
	for description: Dictionary in FIELD.get_property_list():
		if (int(description.usage) & PROPERTY_USAGE_STORAGE) == 0 or description.name in [
			"script", "resource_path", "resource_name", "resource_local_to_scene",
			"resource_scene_unique_id"]:
			continue
		var key: String = description.name
		if typeof(field.get(key)) != typeof(FIELD.get(key)) or field.get(key) != FIELD.get(key):
			return false
	var counts: Dictionary = {}
	for index in range(SITES.size()):
		var site: String = SITES[index]
		var identity: String = INSTANCE_PREFIX + site
		var candidate: Variant = objects.get(identity)
		if typeof(candidate) != TYPE_OBJECT or not is_instance_valid(candidate) \
			or not candidate is Node3D:
			return false
		var model: Node3D = candidate
		if model.get_parent() != self or model.is_queued_for_deletion() \
			or model.transform != pose(site) \
			or not exact_meta(model, "stadium_item", ITEMS[index]) \
			or not exact_meta(model, "npc_instance", identity) \
			or not exact_meta(model, "owned_copy", identity) \
			or not exact_meta(model, "npc_site", site) or not exact_meta(model, "npc_host", "field"):
			return false
		counts[ITEMS[index]] = int(counts.get(ITEMS[index], 0)) + 1
	return counts == COUNTS


static func valid(property: StadiumNpcPublicProperty) -> bool:
	return is_instance_valid(property) and property.get_script() == StadiumNpcPublicProperty \
		and property.venue_id == "HILLSIDE" and property.tier == "expanded" \
		and property.transform == Transform3D.IDENTITY and property.display == null \
		and is_instance_valid(property.construction) \
		and property.construction.get_script() == StadiumHillsidePublicConstruction \
		and property.construction.get_parent() == property \
		and property.field == property.construction.field \
		and property.objects == property.construction.objects and property.construction.cold_valid()


func geometry_report() -> Dictionary:
	return {"status": "WORKING_SOURCE_ONLY_PUBLIC_UNADMITTED", "catalog_copies": objects.size(),
		"counts": COUNTS.duplicate(true), "live_obstacles": 0, "score_display": "HUD-only",
		"bounds": [-32, -16, 32, 38], "time": "13:10", "weather": "clear",
		"terrain_signature": StadiumHillsideTerrain.signature("hill"),
		"perimeter": {} if boundary == null else boundary.geometry_report(),
		"timber_runtime_admitted": false, "production_ready": false, "progression_held": true}


static func components(value: Transform3D) -> Array:
	return StadiumLongYardPublicConstruction.components(value)


static func exact_meta(node: Node, key: String, value: Variant) -> bool:
	return StadiumLongYardPublicConstruction.exact_meta(node, key, value)


func route_obstacles() -> Array[Dictionary]:
	# These exact eight copies have no live-obstacle route reservation.
	return []


func qualify_contacts(adapter: StadiumHillsidePublicContactAdapter) -> bool:
	if adapter == null or adapter.get_script() != StadiumHillsidePublicContactAdapter \
		or adapter.construction != self or adapter.source != boundary \
		or adapter.bodies != boundary.member_bodies or _contact_adapter != null:
		return false
	_contact_adapter = weakref(adapter)
	_contact_labels()
	return true


func _contact_labels() -> void:
	# Only an exact configured delegate qualifies labels; authored asset geometry stays intact.
	for site: String in ["DUGOUT-L", "DUGOUT-R"]:
		var model: Node3D = objects[INSTANCE_PREFIX + site]
		model.remove_meta("stadium_candidate_only")
		model.set_meta("runtime_adapter", CONTACT_ADAPTER)


static func same(actual: StadiumNpcPublicProperty, expected: StadiumNpcPublicProperty) -> bool:
	# Strict fresh-tree comparison, including stable 72 collider and two marker child names.
	return valid(actual) and valid(expected) \
		and _same_construction(actual.construction, expected.construction) \
		and actual.construction.route_obstacles() == expected.construction.route_obstacles()


static func _same_construction(actual: StadiumHillsidePublicConstruction,
	expected: StadiumHillsidePublicConstruction) -> bool:
	# Preserve the strict full snapshot and every named child. Only the existing paired
	# receiver's independently bounded flex/fade fields normalize after their own audit.
	if not StadiumNpcRetainedGeometry._receiver_policies(actual) \
		or not StadiumNpcRetainedGeometry._receiver_policies(expected):
		return false
	var actual_tree: Dictionary = StadiumPoolPartyAssetIntegrity.snapshot(actual)
	var expected_tree: Dictionary = StadiumPoolPartyAssetIntegrity.snapshot(expected)
	for tree: Dictionary in [actual_tree, expected_tree]:
		tree.erase("name")
		tree.properties.erase("name")
	for site: String in ["RECEIVER-PRIMARY", "RECEIVER-CATCH"]:
		var a: Node3D = actual.objects[INSTANCE_PREFIX + site]
		var b: Node3D = expected.objects[INSTANCE_PREFIX + site]
		if not StadiumNpcRetainedGeometry.same(a, b):
			return false
		_normalize_receiver(a, actual_tree.children[a.get_index()],
			expected_tree.children[b.get_index()])
	return var_to_bytes(actual_tree) == var_to_bytes(expected_tree)


static func _normalize_receiver(node: Node, value: Dictionary, expected: Dictionary,
	visual: bool = false) -> void:
	# No child/name/geometry omissions: each normalized field has passed the existing
	# paired geometry/policy validator above. Extra metadata and stored fields stay exact.
	if node.has_meta("stadium_item"):
		value.metadata.erase("receiver_render_state")
		value.properties.erase("metadata/receiver_render_state")
		expected.metadata.erase("receiver_render_state")
		expected.properties.erase("metadata/receiver_render_state")
	visual = visual or node.name == &"Visual"
	if node.name == &"Visual":
		value.properties.visible = expected.properties.visible
	if visual and node is MeshInstance3D:
		value.properties.cast_shadow = expected.properties.cast_shadow
		var material: Dictionary = value.properties.material_override.properties
		var reference: Dictionary = expected.properties.material_override.properties
		material.albedo_color = reference.albedo_color
		material.transparency = reference.transparency
		if node.name == &"ST026_PANEL":
			for key: String in ["transform", "position"]:
				if value.properties.has(key):
					value.properties[key] = expected.properties[key]
		elif node.name == &"ST025_NET_STRANDS":
			# The retained validator checked every vertex/index/material and its one
			# bounded pocket displacement. Restore only the mesh surface data in the snapshot.
			var mesh: Dictionary = value.properties.mesh.properties
			var rest: Dictionary = expected.properties.mesh.properties
			for key: String in rest:
				if key.begins_with("surface_") or key in ["_surfaces", "custom_aabb"]:
					mesh[key] = rest[key]
	for index in range(node.get_child_count()):
		_normalize_receiver(node.get_child(index), value.children[index], expected.children[index],
			visual)

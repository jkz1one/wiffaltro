class_name StadiumFloodlightOwnedModels
extends RefCounted
## Exact fresh copies of the frozen tower factories. No stock or night authority.
## Separate, initially dark aggregates/glows retain every original lens and solid.
# gdlint: disable=max-returns,max-line-length

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-038", "ST-076"]
const PROFILES: Array[String] = ["CLUB4-LOW", "MOGUL6-STANDARD", "MOGUL4-PREMIUM"]
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const RIG: String = "OwnedFloodlightRig"
const BIND_KEYS: Array[StringName] = [&"stadium_item", &"paid_copy", &"owned_copy", &"site", &"floodlight_profile", &"floodlight_owned", &"surface_role"]


static func create(item: String, placement: Dictionary) -> Node3D:
	if not placement.get("copy") is String or String(placement.copy).is_empty() \
		or not placement.get("site") is String or not placement.get("profile") is String:
		return null
	var profile: String = placement.profile
	var site: String = placement.site
	if item != profile_item(profile) or not profile_sites(profile).has(site) \
		or placement.get("item", item) != item or placement.get("role", ROLE) != ROLE:
		return null
	var fixed: Transform3D = pose(profile, site)
	if placement.has("position") and placement.position != fixed.origin:
		return null
	if placement.has("yaw"):
		if not (placement.yaw is float or placement.yaw is int) or not is_finite(float(placement.yaw)) \
			or not Basis(Vector3.UP, deg_to_rad(float(placement.yaw))).is_equal_approx(fixed.basis):
			return null
	var root: Node3D
	var placed: bool = false
	match profile:
		"CLUB4-LOW":
			root = StadiumNpcAc02PublicLightSites.create(site)
			placed = root != null
		"MOGUL6-STANDARD":
			root = StadiumFourHeadTowerModels.create()
			placed = StadiumFourHeadTowerSites.place(root, site)
		"MOGUL4-PREMIUM":
			root = StadiumPremiumLightTowerModels.create()
			placed = StadiumPremiumLightTowerSites.place(root, site)
	if not placed:
		if root != null:
			root.free()
		return null
	root.name = item.replace("-", "") + "OwnedFloodlight"
	root.set_meta("model_factory", "StadiumFloodlightOwnedModels")
	root.set_meta("model_version", VERSION)
	root.set_meta("owned_geometry_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("art_acceptance", "OPEN")
	root.set_meta("source_factory", "StadiumPremiumLightTowerModels" if item == "ST-076" else "StadiumFourHeadTowerModels")
	root.set_meta("envelope", envelope(item))
	root.set_meta("floodlight_placement", placement.duplicate(true))
	_bind(root, item, placement)
	if not intern_source_materials(root, item):
		root.free()
		return null
	return root


static func intern_source_materials(root: Node3D, item: String) -> bool:
	# Only fresh owned source art, before attachment or authority capture. The pool
	# belongs to this call/model; meshes, shapes and later mutable rig materials stay unique.
	if not is_instance_valid(root) or root.is_inside_tree() or root.get_parent() != null \
		or root.is_queued_for_deletion() or root.get_script() != null \
		or item not in ["ST-038", "ST-076", "ST-029", "ST-053"] \
		or not root.has_meta("stadium_item") or root.get_meta("stadium_item") != item \
		or root.has_node(RIG):
		return false
	var visual: Node3D = root.get_node_or_null("Visual") as Node3D
	if visual == null or visual.get_script() != null:
		return false
	var members: Array[Node] = visual.find_children("*", "MeshInstance3D", true, false)
	if members.is_empty():
		return false
	var pool: Array[Dictionary] = []
	var assignments: Array[Dictionary] = []
	for member: MeshInstance3D in members:
		var material: StandardMaterial3D = member.material_override as StandardMaterial3D
		if member.get_script() != null or material == null or material.get_script() != null:
			return false
		var state: Dictionary = _source_material_state(material)
		var canonical: StandardMaterial3D = material
		var found: bool = false
		for entry: Dictionary in pool:
			if state == entry.state:
				canonical = entry.material
				found = true
				break
		if not found:
			pool.append({"material": material, "state": state})
		assignments.append({"node": member, "material": canonical})
	# Validation is complete before the first source override changes.
	for assignment: Dictionary in assignments:
		(assignment.node as MeshInstance3D).material_override = assignment.material
	return true


static func _source_material_state(material: StandardMaterial3D) -> Dictionary:
	var keys: Array[StringName] = []
	var values: Array = []
	for description: Dictionary in material.get_property_list():
		if (int(description.usage) & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP)) != 0:
			continue
		var key: StringName = StringName(description.name)
		var value: Variant = material.get(key)
		keys.append(key)
		values.append(value.duplicate(true) if value is Array or value is Dictionary else value)
	var metadata: Dictionary = {}
	for key: StringName in material.get_meta_list():
		var value: Variant = material.get_meta(key)
		metadata[key] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {"keys": keys, "values": values, "metadata": metadata}


static func profile_item(profile: String) -> String:
	if profile in ["CLUB4-LOW", "MOGUL6-STANDARD"]:
		return "ST-038"
	return "ST-076" if profile == "MOGUL4-PREMIUM" else ""


static func profile_sites(profile: String) -> Dictionary:
	match profile:
		"CLUB4-LOW": return StadiumNpcAc02PublicLightSites.SITES.duplicate()
		"MOGUL6-STANDARD": return StadiumFourHeadTowerSites.SITES.duplicate()
		"MOGUL4-PREMIUM": return StadiumPremiumLightTowerSites.SITES.duplicate()
	return {}


static func pose(profile: String, site: String) -> Transform3D:
	if not profile_sites(profile).has(site):
		return Transform3D.IDENTITY
	if profile == "CLUB4-LOW":
		return StadiumNpcAc02PublicLightSites.pose(site)
	var position: Vector3 = profile_sites(profile)[site]
	var target: Vector3 = StadiumFourHeadTowerSites.TARGETS[site] if profile == "MOGUL6-STANDARD" else StadiumPremiumLightTowerSites.TARGETS[site]
	var toward: Vector3 = target - position
	return Transform3D(Basis(Vector3.UP, atan2(toward.x, toward.z)), position)


static func envelope(item: String) -> AABB:
	if item not in ITEMS:
		return AABB()
	var radius: float = StadiumPremiumLightTowerModels.ENVELOPE_RADIUS if item == "ST-076" else StadiumFourHeadTowerModels.ENVELOPE_RADIUS
	var height: float = StadiumPremiumLightTowerModels.HEIGHT if item == "ST-076" else StadiumFourHeadTowerModels.HEIGHT
	return AABB(Vector3(-radius, 0, -radius), Vector3(radius * 2, height, radius * 2))


static func head_rays(profile: String, site: String) -> Array[Dictionary]:
	if not profile_sites(profile).has(site):
		return []
	match profile:
		"CLUB4-LOW": return StadiumNpcAc02PublicLightSites.head_rays(site)
		"MOGUL6-STANDARD": return StadiumGrandILightingV1.head_rays(site)
		"MOGUL4-PREMIUM": return StadiumGrandIIILightingV1.head_rays(site)
	return []


static func emitter_rows(profile: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if profile == "MOGUL6-STANDARD":
		result.assign(StadiumGrandILightingV1.contract().emitters.duplicate(true))
	elif profile == "MOGUL4-PREMIUM":
		result.assign(StadiumGrandIIILightingV1.contract().emitters.duplicate(true))
	elif profile == "CLUB4-LOW":
		for site: String in profile_sites(profile):
			var selected: int = 1 if site.ends_with("L") else 2
			var rays: Array[Dictionary] = head_rays(profile, site)
			# Use the established outer-site aggregate, replacing only its exact Club ray/site.
			var row: Dictionary = StadiumGrandILightingV1.contract().emitters[0].duplicate(true)
			row.site = site
			row.head = rays[selected].id
			row.origin = rays[selected].origin
			row.direction = rays[selected].direction
			result.append(row)
	for row: Dictionary in result:
		row["profile"] = profile
		row["item"] = profile_item(profile)
	return result


static func lens_rows(root: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(root) or not root.get_meta("floodlight_owned", false):
		return result
	var profile: String = root.get_meta("floodlight_profile", "")
	var site: String = root.get_meta("site", "")
	var rays: Array[Dictionary] = head_rays(profile, site)
	if rays.is_empty() or root.get_meta("stadium_item", "") != profile_item(profile) \
		or not root.transform.is_equal_approx(pose(profile, site)):
		return result
	var premium: bool = profile == "MOGUL4-PREMIUM"
	for index in range(rays.size()):
		var head: Node3D = root.get_node_or_null("Visual/Head%d" % index) as Node3D
		var lens: MeshInstance3D = root.get_node_or_null("Visual/Head%d/Lens" % index) as MeshInstance3D
		if head == null or lens == null or not lens.mesh is BoxMesh \
			or not lens.material_override is StandardMaterial3D:
			return []
		var direction: Vector3 = (root.basis * head.basis.z).normalized()
		var origin: Vector3 = root.transform * head.transform * Vector3(0, 0, 0.154 if premium else 0.139)
		if not direction.is_equal_approx(_vector(rays[index].direction)) \
			or not origin.is_equal_approx(_vector(rays[index].origin)):
			return []
		result.append({"head": head, "head_id": rays[index].id, "lens": lens,
			"parent": lens.get_parent(), "pose": lens.transform, "mesh": lens.mesh,
			"original": lens.material_override, "origin": origin, "direction": direction,
			"copy": root.get_meta("owned_copy", ""), "item": profile_item(profile),
			"site": site, "profile": profile,
			"glow_size": StadiumGrandIIILightingV1.GLOW_SIZE if premium else StadiumGrandILightingV1.GLOW_SIZE,
			"glow_forward": StadiumGrandIIILightingV1.GLOW_FORWARD if premium else StadiumGrandILightingV1.GLOW_FORWARD})
	return result


static func install_owned_rig(root: Node3D) -> Dictionary:
	# Pure authored presentation. The caller has already admitted an exact owned profile.
	# This function never switches light visibility, changes source lenses or qualifies night.
	var lenses: Array[Dictionary] = lens_rows(root)
	if lenses.is_empty() or root.has_node(RIG):
		return {}
	var source: Dictionary = {}
	for row: Dictionary in emitter_rows(lenses[0].profile):
		if row.site == lenses[0].site:
			source = row
	if source.is_empty():
		return {}
	var rig: Node3D = Node3D.new()
	rig.name = RIG
	var placement: Dictionary = root.get_meta("floodlight_placement")
	root.add_child(rig)
	var beam: SpotLight3D = SpotLight3D.new()
	beam.name = "Aggregate"
	rig.add_child(beam)
	beam.transform = root.transform.affine_inverse() * Transform3D(
		Basis.looking_at(_vector(source.direction), Vector3.UP), _vector(source.origin))
	beam.light_color = Color(source.color[0], source.color[1], source.color[2], source.color[3])
	beam.light_energy = source.energy
	beam.spot_range = source.range
	beam.spot_angle = source.angle
	beam.spot_attenuation = source.attenuation
	beam.spot_angle_attenuation = source.angle_attenuation
	beam.shadow_enabled = source.shadows
	beam.shadow_bias = source.shadow_bias
	beam.shadow_normal_bias = source.shadow_normal_bias
	beam.visible = false
	var glows: Array[Dictionary] = []
	for row: Dictionary in lenses:
		var glow: MeshInstance3D = MeshInstance3D.new()
		glow.name = "Glow" + row.head_id
		var mesh: QuadMesh = QuadMesh.new()
		mesh.size = row.glow_size
		glow.mesh = mesh
		var material: StandardMaterial3D = row.original.duplicate(true) as StandardMaterial3D
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = StadiumGrandILightingV1.GLOW_COLOR
		material.emission = StadiumGrandILightingV1.GLOW_COLOR
		material.emission_enabled = false
		material.emission_energy_multiplier = 0.0
		glow.material_override = material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.visible = false
		rig.add_child(glow)
		glow.transform = row.head.transform * Transform3D(Basis.IDENTITY, Vector3(0, 0, row.glow_forward))
		glows.append({"node": glow, "lens": glow, "parent": rig, "pose": glow.transform,
			"mesh": mesh, "original": material, "copy": row.copy, "item": row.item,
			"site": row.site, "profile": row.profile, "head": row.head,
			"source_lens": row.lens, "source_material": row.original})
	_bind(rig, profile_item(placement.profile), placement)
	var emitters: Array[Dictionary] = [{"node": beam, "beam": beam, "parent": rig,
		"pose": beam.transform, "copy": placement.copy, "item": profile_item(placement.profile),
		"site": placement.site, "profile": placement.profile, "spec": source.duplicate(true)}]
	return {"root": rig, "emitters": emitters, "lenses": glows, "geometry": capture_geometry(root)}


static func capture_geometry(root: Node3D) -> Dictionary:
	# Capture a finite native-node/resource manifest once; checking it never rescans the tree.
	if not is_instance_valid(root):
		return {}
	var companion: bool = root.get_meta("stadium_item", "") in ["ST-029", "ST-053"]
	if (not companion and lens_rows(root).is_empty()) or not root.has_node("Visual") or not root.has_node("Collision"):
		return {}
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	var rows: Array[Dictionary] = []
	var resources: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node: Node in nodes:
		if not node is Node3D or node.get_script() != null:
			return {}
		var mutable: bool = node is SpotLight3D or (node is MeshInstance3D and node.get_parent() == root.get_node_or_null(RIG))
		var fields: Array[StringName] = [&"transform", &"top_level", &"process_mode"]
		if not mutable:
			fields.append(&"visible")
		if node is MeshInstance3D:
			fields.append_array([&"mesh", &"material_overlay", &"cast_shadow", &"layers", &"transparency"])
			if not mutable:
				fields.append(&"material_override")
		elif node is StaticBody3D:
			fields.append_array([&"collision_layer", &"collision_mask", &"disable_mode"])
		elif node is CollisionShape3D:
			fields.append_array([&"shape", &"disabled"])
		elif node is SpotLight3D:
			fields = StadiumGrandILightingV1._light_keys(node)
			fields.erase(&"visible")
			fields.erase(&"light_energy")
		var values: Array = []
		for field: StringName in fields:
			var value: Variant = node.get(field)
			values.append(value.duplicate(true) if value is Array or value is Dictionary else value)
			if value is Resource and not _capture_resource(value, resources, seen, 0, true):
				return {}
		var metadata_present: Array[bool] = []
		var metadata_values: Array = []
		for key: StringName in BIND_KEYS:
			var present: bool = node.has_meta(key)
			metadata_present.append(present)
			metadata_values.append(node.get_meta(key) if present else null)
		fields.make_read_only()
		values.make_read_only()
		metadata_present.make_read_only()
		metadata_values.make_read_only()
		rows.append({"node": node, "parent": node.get_parent(), "name": node.name,
			"children": node.get_children(), "fields": fields, "values": values,
			"metadata_present": metadata_present, "metadata_values": metadata_values})
	# Every nonroot member must occur exactly once in its captured parent's ordered
	# child list. Those lists then prove descendant parent links on every live check.
	var parents: Dictionary = {}
	for row: Dictionary in rows:
		if parents.has(row.node):
			return {}
		parents[row.node] = row.parent
	var children: Dictionary = {}
	for row: Dictionary in rows:
		for child: Node in row.children:
			if child == root or not parents.has(child) or parents[child] != row.node or children.has(child):
				return {}
			children[child] = true
		(row.children as Array).make_read_only()
	if children.size() != rows.size() - 1:
		return {}
	for row: Dictionary in resources:
		(row.keys as Array).make_read_only()
		(row.values as Array).make_read_only()
	return {"root": root, "rows": rows, "resources": resources, "hierarchy_closed": true}


static func geometry_intact(root: Node3D, seal: Dictionary) -> bool:
	if not is_instance_valid(root) or seal.get("root") != root or seal.get("rows", []).is_empty() \
		or not seal.get("hierarchy_closed", false):
		return false
	var rows: Array[Dictionary] = seal.rows
	var resources: Array[Dictionary] = seal.resources
	if rows[0].node != root or root.get_parent() != rows[0].parent:
		return false
	for row: Dictionary in rows:
		var node: Node = row.node
		if not is_instance_valid(node) or node.is_queued_for_deletion() or node.get_script() != null \
			or node.name != row.name:
			return false
		var children: Array[Node] = row.children
		if children.is_empty():
			if node.get_child_count() != 0:
				return false
		elif node.get_children() != children:
			return false
		var fields: Array[StringName] = row.fields
		var values: Array = row.values
		for index in range(fields.size()):
			if node.get(fields[index]) != values[index]:
				return false
		var metadata_present: Array[bool] = row.metadata_present
		var metadata_values: Array = row.metadata_values
		for index in range(BIND_KEYS.size()):
			var key: StringName = BIND_KEYS[index]
			var present: bool = node.has_meta(key)
			if present != metadata_present[index] or (present and node.get_meta(key) != metadata_values[index]):
				return false
	for row: Dictionary in resources:
		var resource: Resource = row.resource
		if not is_instance_valid(resource):
			return false
		if row.has("metadata"):
			var metadata: Dictionary = row.metadata
			if resource.get_meta_list().size() != metadata.size():
				return false
			for key: StringName in metadata:
				if not resource.has_meta(key) or resource.get_meta(key) != metadata[key]:
					return false
		var keys: Array[StringName] = row.keys
		var values: Array = row.values
		for index in range(keys.size()):
			if resource.get(keys[index]) != values[index]:
				return false
	return true


static func _capture_resource(resource: Resource, rows: Array[Dictionary], seen: Dictionary, depth: int = 0, complete_source_materials: bool = false) -> bool:
	if seen.has(resource.get_instance_id()):
		return true
	if depth > 8:
		return false
	seen[resource.get_instance_id()] = true
	if complete_source_materials and resource is StandardMaterial3D:
		# Include disabled/non-storage native fields. Every value is still checked
		# synchronously on every guard, once per exact shared source resource.
		var state: Dictionary = _source_material_state(resource)
		for value: Variant in state.values:
			if value is Resource and not _capture_resource(value, rows, seen, depth + 1, complete_source_materials):
				return false
		rows.append({"resource": resource, "keys": state.keys, "values": state.values,
			"metadata": state.metadata})
		return true
	var keys: Array[StringName] = []
	var values: Array = []
	for description: Dictionary in resource.get_property_list():
		if (int(description.usage) & PROPERTY_USAGE_STORAGE) == 0 \
			or description.name in ["resource_name", "resource_path", "resource_local_to_scene"]:
			continue
		var value: Variant = resource.get(description.name)
		keys.append(StringName(description.name))
		values.append(value.duplicate(true) if value is Array or value is Dictionary else value)
		if value is Resource and not _capture_resource(value, rows, seen, depth + 1, complete_source_materials):
			return false
	rows.append({"resource": resource, "keys": keys, "values": values})
	return true


static func _bind(node: Node, item: String, placement: Dictionary) -> void:
	node.set_meta("stadium_item", item)
	node.set_meta("paid_copy", placement.copy)
	node.set_meta("owned_copy", placement.copy)
	node.set_meta("site", placement.site)
	node.set_meta("floodlight_profile", placement.profile)
	node.set_meta("floodlight_owned", true)
	node.set_meta("surface_role", ROLE)
	for child: Node in node.get_children():
		_bind(child, item, placement)


static func _vector(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])

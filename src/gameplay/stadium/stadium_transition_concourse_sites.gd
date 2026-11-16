class_name StadiumTransitionConcourseSites
extends RefCounted
## Additive exact-instance interface; no player registry or upper/canopy socket.

const INTERFACE: String = "JOIN-v1_ST081-083-v1_ST029-031-v1_CAP-CROSSING-v1"
const SITES: Array[String] = ["JOIN-R", "JOIN-L"]
const HEIGHT: float = 7.85
const L = preload("res://src/gameplay/stadium/stadium_lower_transition_sites.gd")


static func item(site: String) -> String:
	return "ST-086" if site == "JOIN-R" else ("ST-089" if site == "JOIN-L" else "")


static func bowl_site(site: String) -> String:
	return "BOWL-01" if site == "JOIN-R" else "BOWL-05"


static func base_site(site: String) -> String:
	return "BASE-R1" if site == "JOIN-R" else "BASE-L1"


static func valid_hosts(site: String, join: Node3D, bowl: Node3D, curved: Node3D,
	base: Node3D, straight: Node3D) -> bool:
	if site not in SITES:
		return false
	for host: Node3D in [join, bowl, curved, base, straight]:
		if not is_instance_valid(host) or not host.is_inside_tree():
			return false
	var parent: Node3D = join.get_parent() as Node3D
	if parent == null or not parent.global_transform.is_equal_approx(Transform3D.IDENTITY):
		return false
	for host: Node3D in [join, bowl, curved, base, straight]:
		if host.get_parent() != parent or host.top_level or not host.is_visible_in_tree() \
			or host.get_script() != null or not host.can_process():
			return false
	if not join.transform.is_equal_approx(Transform3D.IDENTITY) \
		or not join.global_transform.is_equal_approx(Transform3D.IDENTITY) \
		or not StadiumCurvedStackSites.valid_pose(bowl, bowl_site(site)) \
		or not StadiumCurvedStackSites.valid_pose(curved, bowl_site(site)) \
		or not StadiumStraightStackSites.valid_pose(base, base_site(site)) \
		or not StadiumStraightStackSites.valid_pose(straight, base_site(site)):
		return false
	if not _matches(join, L.item(site), site) or not _matches(bowl, "ST-081", site) \
		or not _matches(curved, "ST-083", site) or not _matches(base, "ST-029", site) \
		or not _matches(straight, "ST-031", site):
		return false
	var state: Variant = base.get_meta("assembly_state", "BASE-LOWER-v1")
	if typeof(state) != TYPE_STRING or state not in ["BASE-LOWER-v1", "BASE-CONCOURSE-v1"]:
		return false
	if not _bound(curved, bowl, bowl_site(site), StadiumCurvedStackSites.INTERFACE) \
		or not _bound(straight, base, base_site(site), StadiumStraightStackSites.INTERFACE):
		return false
	return _compatible_neighbors(parent, site, join, bowl, curved, base, straight)


static func _bound(piece: Node3D, lower: Node3D, site: String, interface: String) -> bool:
	return meta_matches(piece, "lower_instance", lower.get_instance_id()) \
		and meta_matches(piece, "site", site) and meta_matches(piece, "interface", interface)


static func _compatible_neighbors(parent: Node3D, site: String, join: Node3D,
	bowl: Node3D, curved: Node3D, base: Node3D, straight: Node3D) -> bool:
	var seen: Array[String] = []
	for child: Node in parent.get_children():
		if child in [join, bowl, curved, base, straight] or not child is Node3D:
			continue
		var id: String = str(child.get_meta("stadium_item", ""))
		var child_site: Variant = child.get_meta("site", "")
		var lower_id: Variant = child.get_meta("lower_instance", 0)
		var related: bool = (typeof(child_site) == TYPE_STRING \
			and child_site in [site, bowl_site(site), base_site(site)]) \
			or (typeof(lower_id) == TYPE_INT and lower_id in [join.get_instance_id(),
				bowl.get_instance_id(), base.get_instance_id()]) \
			or (id in ["ST-029", "ST-030", "ST-031", "ST-053", "ST-055", "ST-057"] \
				and child.transform.is_equal_approx(base.transform)) \
			or (id in ["ST-081", "ST-082", "ST-083", "ST-084"] \
				and child.transform.is_equal_approx(bowl.transform)) \
			or id in [L.item(site), item(site)]
		if not related:
			continue
		# This bounded v1 proves neighboring uppers only. Grand III neighboring roofs
		# require a later explicit compatibility revision, not a permanent roof prohibition.
		# No canonical upper-roof host exists at the frozen source used for this slice.
		if id not in ["ST-082", "ST-030"] or id in seen:
			return false
		seen.append(id)
		var is_curved: bool = id == "ST-082"
		var lower: Node3D = bowl if is_curved else base
		var concourse: Node3D = curved if is_curved else straight
		var target_site: String = bowl_site(site) if is_curved else base_site(site)
		var interface: String = StadiumCurvedStackSites.UPPER_INTERFACE if is_curved \
			else StadiumStraightStackSites.UPPER_INTERFACE
		if not child.transform.is_equal_approx(lower.transform) \
			or not child.global_transform.is_equal_approx(lower.global_transform) \
			or child.top_level or not child.visible or child.get_script() != null \
			or not child.can_process() \
			or not _bound(child, lower, target_site, interface) \
			or not meta_matches(child, "concourse_instance", concourse.get_instance_id()) \
			or not _matches(child, id, site):
			return false
	return true


static func _reference(id: String, _site: String, occupied: bool) -> Node3D:
	match id:
		"ST-085": return StadiumLowerTransitionModels.create_right(occupied)
		"ST-088": return StadiumLowerTransitionModels.create_left(occupied)
		"ST-081": return StadiumCurvedLowerModels.create(occupied)
		"ST-083": return StadiumCurvedStackModels._concourse()
		"ST-029": return StadiumBaselineStandModels.lower(occupied)
		"ST-031": return StadiumStraightStackModels._concourse()
		"ST-082": return StadiumCurvedStackModels._upper(occupied)
		"ST-030": return StadiumStraightStackModels._upper(occupied)
	return null


static func _matches(actual: Node3D, id: String, site: String) -> bool:
	if not meta_matches(actual, "stadium_item", id):
		return false
	for occupied: bool in [false, true]:
		var reference: Node3D = _reference(id, site, occupied)
		var valid: bool = actual.get_class() == reference.get_class() \
			and actual.process_mode == reference.process_mode
		for key: StringName in reference.get_meta_list():
			if not meta_matches(actual, key, reference.get_meta(key)):
				valid = false
		var signature: String = geometry_signature(actual, reference)
		valid = valid and not signature.is_empty() \
			and signature == geometry_signature(reference, reference)
		reference.free()
		if valid:
			return true
	return false


static func meta_matches(node: Node, key: StringName, expected: Variant) -> bool:
	if not node.has_meta(key):
		return false
	return same_value(node.get_meta(key), expected)


static func same_value(actual: Variant, expected: Variant) -> bool:
	# GDScript does not define ==/!= for all mixed Variant operand types. Reject
	# malformed raw types before comparison; never coerce IDs, versions or bindings.
	return typeof(actual) == typeof(expected) and actual == expected


static func geometry_signature(root: Node3D, canonical: Node3D) -> String:
	if root.get_child_count() != 2 or not root.has_node("Visual") or not root.has_node("Collision"):
		return ""
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for branch: String in ["Visual", "Collision"]:
		if not _hash_node(root.get_node(branch), canonical.get_node(branch), hash, branch, 0):
			return ""
	return hash.finish().hex_encode()


static func _hash_node(node: Node, reference: Node, hash: HashingContext,
	branch: String, depth: int) -> bool:
	if node.get_script() != null or reference == null or node.get_class() != reference.get_class() \
		or node.get_child_count() != reference.get_child_count():
		return false
	var name_value: String = "CollisionShape" if node is CollisionShape3D else str(node.name)
	hash.update(var_to_bytes([name_value, node.get_class(), node.get_child_count(),
		node.process_mode]))
	var keys: Array[StringName] = node.get_meta_list()
	keys.sort()
	for key: StringName in keys:
		hash.update(var_to_bytes([key, node.get_meta(key)]))
	if node is Node3D:
		var pose: Transform3D = node.transform
		if not pose.is_finite():
			return false
		if branch == "Visual" and depth == 1 and reference.get_meta("represented_audience", false):
			if absf(pose.origin.y - reference.position.y) > 0.04001:
				return false
			pose.origin.y = reference.position.y
		hash.update(var_to_bytes([pose, node.top_level, node.visible]))
	if node is MeshInstance3D:
		if node.mesh == null or node.mesh.get_script() != null or not _render_state(node, reference):
			return false
		hash.update(var_to_bytes([node.mesh.get_class(), node.mesh.get_surface_count()]))
		for surface in range(node.mesh.get_surface_count()):
			var primitive: int = node.mesh.surface_get_primitive_type(surface) \
				if node.mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
			hash.update(var_to_bytes([primitive, node.mesh.surface_get_arrays(surface)]))
	if node is CollisionObject3D:
		hash.update(var_to_bytes([node.collision_layer, node.collision_mask, node.disable_mode]))
	if node is CollisionShape3D:
		if node.shape is BoxShape3D:
			hash.update(var_to_bytes([node.disabled, "box", node.shape.size, node.shape.margin]))
		elif node.shape is ConvexPolygonShape3D:
			hash.update(var_to_bytes([node.disabled, "convex", node.shape.points, node.shape.margin]))
		else:
			return false
	for index in range(node.get_child_count()):
		if not _hash_node(node.get_child(index), reference.get_child(index), hash, branch, depth + 1):
			return false
	return true


static func _render_state(actual: MeshInstance3D, reference: MeshInstance3D) -> bool:
	if reference.mesh == null or actual.mesh.get_surface_count() != reference.mesh.get_surface_count():
		return false
	if actual.mesh is ArrayMesh and reference.mesh is ArrayMesh:
		if actual.mesh.get_blend_shape_count() != reference.mesh.get_blend_shape_count() \
			or actual.mesh.custom_aabb != reference.mesh.custom_aabb:
			return false
	# Compare every stored property defined by the three rendering classes. This
	# includes overlay/transparency, visibility ranges, GI, shadows, culling, skin
	# and skeleton state; Node3D pose/visibility is independently fingerprinted.
	for type: StringName in [&"VisualInstance3D", &"GeometryInstance3D", &"MeshInstance3D"]:
		for property: Dictionary in ClassDB.class_get_property_list(type, true):
			var key: StringName = property.name
			if key == &"mesh" or not (int(property.usage) & PROPERTY_USAGE_STORAGE):
				continue
			var value: Variant = actual.get(key)
			var canonical: Variant = reference.get(key)
			if value is Material or canonical is Material:
				if not _material_matches(value as Material, canonical as Material):
					return false
			elif not same_value(value, canonical):
				return false
	for surface in range(actual.mesh.get_surface_count()):
		if not _material_matches(actual.mesh.surface_get_material(surface),
			reference.mesh.surface_get_material(surface)) \
			or not _material_matches(actual.get_surface_override_material(surface),
				reference.get_surface_override_material(surface)):
			return false
	# Instance shader uniforms are dynamic rather than ClassDB properties.
	var actual_uniforms: Dictionary = {}
	var reference_uniforms: Dictionary = {}
	for property: Dictionary in actual.get_property_list():
		if str(property.name).begins_with("instance_shader_parameters/"):
			actual_uniforms[property.name] = actual.get(property.name)
	for property: Dictionary in reference.get_property_list():
		if str(property.name).begins_with("instance_shader_parameters/"):
			reference_uniforms[property.name] = reference.get(property.name)
	return actual_uniforms == reference_uniforms


static func _material_matches(actual: Material, reference: Material) -> bool:
	if actual == null or reference == null:
		return actual == reference
	if actual.get_class() != reference.get_class() or actual.get_script() != null:
		return false
	# Canonical constructors use self-contained StandardMaterial3D resources with
	# no texture or next-pass resource. Compare all stored material properties,
	# not a shortlist which could overlook alpha, overlay, grow or shader changes.
	for property: Dictionary in reference.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE:
			if not same_value(actual.get(property.name), reference.get(property.name)):
				return false
	return true


static func contains(site: String, point: Vector3) -> bool:
	if site not in SITES or not point.is_finite() or point.y < -0.001 or point.y > HEIGHT + 0.001:
		return false
	var main: PackedVector3Array = []
	var saddle: PackedVector3Array = []
	for pair: Vector2 in [Vector2(0, 7), Vector2(1, 7), Vector2(1, 10), Vector2(0, 10)]:
		main.append(L.point(site, pair.x, pair.y))
	for pair: Vector2 in [Vector2(0.45, 6.75), Vector2(0.55, 6.75),
		Vector2(0.55, 7.15), Vector2(0.45, 7.15)]:
		saddle.append(L.point(site, pair.x, pair.y))
	if _inside(main, point) or (point.y <= 6.151 and _inside(saddle, point)):
		return true
	# The convex chord strip is intentionally bounded, including its complete hull.
	if point.y >= 4.549 and point.y <= 5.501:
		var arc: PackedVector3Array = []
		# Outer intermediate arc vertices lie just outside the end-to-end chord;
		# use each explicitly owned authored segment instead of inflating the envelope.
		for limits: Vector2 in [Vector2(105, 106.3), Vector2(106, 106.3),
			Vector2(106.3, 106.8), Vector2(106.8, 107.3),
			Vector2(107.3, 107.8), Vector2(107.8, 108.3)]:
			arc.clear()
			for pair: Vector2 in [Vector2(26.2, limits.x), Vector2(27.4, limits.x),
				Vector2(27.4, limits.y), Vector2(26.2, limits.y)]:
				var vertex: Vector3 = StadiumCurvedLowerModels.polar(pair.x, pair.y, 0)
				if site == "JOIN-L":
					vertex.x = -vertex.x
				arc.append(vertex)
			if _inside(arc, point):
				return true
	var local: Vector3 = StadiumBaselineSites.pose(base_site(site)).affine_inverse() * point
	if local.y < 6.149 or local.y > 7.101:
		return false
	if site == "JOIN-R":
		return _range(local.x, 2.40, 3.05) and _range(local.z, 8.20, 8.45) \
			or _range(local.x, 2.40, 2.78) and _range(local.z, 8.45, 9.65)
	return _range(local.x, -3.05, -1.45) and _range(local.z, 8.30, 9.50)


static func _range(value: float, low: float, high: float) -> bool:
	return value >= low - 0.001 and value <= high + 0.001


static func _inside(vertices: PackedVector3Array, point: Vector3) -> bool:
	var polygon: PackedVector2Array = []
	for vertex: Vector3 in vertices:
		polygon.append(Vector2(vertex.x, vertex.z))
	var probe: Vector2 = Vector2(point.x, point.z)
	if Geometry2D.is_point_in_polygon(probe, polygon):
		return true
	for index in range(polygon.size()):
		if Geometry2D.get_closest_point_to_segment(probe, polygon[index],
			polygon[(index + 1) % polygon.size()]).distance_to(probe) <= 0.001:
			return true
	return false

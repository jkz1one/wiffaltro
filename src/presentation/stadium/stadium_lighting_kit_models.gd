class_name StadiumLightingKitModels
extends RefCounted
## Additive ST-111 whole-kit geometry. No inventory, season or Night authority.
## All coordinates are property-relative; a kit is always installed at identity.

const VERSION: int = 1
const ITEM: String = "ST-111"
const ROLE: String = "DECORATIVE_AFTER_TERMINAL"
const PATTERNS: Array[String] = ["PARALLEL", "ZIGZAG", "PERIMETER", "MIXED_EDGE"]
const CLEARANCE_RADIUS: float = 0.5
const CABLE_RADIUS: float = 0.018
const CABLE_CORRIDOR_CAP: float = 0.03
const BULB_RADIUS: float = 0.075
const BULB_DROP: float = 0.19
const CABLE_SEGMENTS: int = 48
const BULB_COUNT: int = 36
const SOURCE_ENERGY: float = 0.4
const SOURCE_RANGE: float = 65.0
const SOURCE_ANGLE: float = 78.0
const SPANS: Dictionary = {
	"PARALLEL":
	[
		[Vector3(-25.5, 10, 2), Vector3(25.5, 10, 2)],
		[Vector3(-25.5, 10, 14), Vector3(25.5, 10, 14)],
		[Vector3(-25.5, 10, 26), Vector3(25.5, 10, 26)]
	],
	"ZIGZAG":
	[
		[Vector3(-25.5, 10, 0), Vector3(25.5, 10, 10)],
		[Vector3(25.5, 10, 10), Vector3(-25.5, 10, 20)],
		[Vector3(-25.5, 10, 20), Vector3(25.5, 10, 29.4)]
	],
	"PERIMETER":
	[
		[Vector3(-25.5, 10, 0), Vector3(-25.5, 10, 29.4)],
		[Vector3(25.5, 10, 0), Vector3(25.5, 10, 29.4)],
		[Vector3(-25.5, 10, -9), Vector3(25.5, 10, -9)]
	],
	"MIXED_EDGE":
	[
		[Vector3(-25.5, 6, -7), Vector3(-25.5, 6, 7)],
		[Vector3(25.5, 6, -7), Vector3(25.5, 6, 7)],
		[Vector3(-7, 6, -9), Vector3(7, 6, -9)]
	]
}

static var _definitions_cache: Dictionary = {}
static var _materials_cache: Dictionary = {}


static func signature() -> String:
	# JSON primitives only, independent of engine resource IDs or instantiated copies.
	var patterns: Dictionary = {}
	for pattern: String in PATTERNS:
		var values: Array = []
		for pair: Array in SPANS[pattern]:
			values.append([_vector(pair[0]), _vector(pair[1])])
		patterns[pattern] = values
	return (
		JSON
		. stringify(
			{
				"version": VERSION,
				"item": ITEM,
				"patterns": patterns,
				"sag": {"MIXED_EDGE": 0.6, "other": 1.2},
				"support_top_offset": 0.2,
				"footing": [0.1, 0.2, 0.28],
				"mast_radius": 0.1,
				"clearance_radius": CLEARANCE_RADIUS,
				"cable": [CABLE_SEGMENTS, CABLE_RADIUS],
				"cable_corridor_cap": CABLE_CORRIDOR_CAP,
				"bulbs": [BULB_COUNT, BULB_RADIUS, BULB_DROP],
				"dropper": [0.14, 0.012],
				"socket": [0.035, 0.035],
				"material_roughness": 0.85,
				"colors": ["7d8981", "526b61", "323d38", "425a53", "fff0c8", "ffdc98"],
				"source": [SOURCE_ENERGY, SOURCE_RANGE, SOURCE_ANGLE, 0.65, 0.7, 0.05, 0.2],
				"source_target": [0, 0, 12],
				"source_color": "ffe4c2",
				"sources_per_span": 1,
				"source_dormant": true,
				"colliders": "exact-post-footing-and-mast-only",
				"overhead_interaction": false,
				"ownership": "single-kit-included-indivisible-supports",
				"mixed_rear_poles": "separate-ST-037-not-created",
				"night_qualified": false
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func geometry_signature() -> String:
	return signature()


static func support_positions(pattern: String) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for pair: Array in SPANS.get(pattern, []):
		for point: Vector3 in pair:
			var base: Vector3 = Vector3(point.x, 0, point.z)
			if not result.has(base):
				result.append(base)
	return result


static func components(pattern: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not SPANS.has(pattern):
		return result
	var height: float = _attachment(pattern) + 0.2
	for point: Vector3 in support_positions(pattern):
		result.append(
			{
				"id": "Post%02d" % result.size(),
				"kind": "post",
				"center": point,
				"radius": CLEARANCE_RADIUS,
				"bounds":
				AABB(
					point - Vector3(CLEARANCE_RADIUS, 0, CLEARANCE_RADIUS),
					Vector3(CLEARANCE_RADIUS * 2, height, CLEARANCE_RADIUS * 2)
				)
			}
		)
	for index in range(SPANS[pattern].size()):
		var pair: Array = SPANS[pattern][index]
		var a: Vector3 = pair[0]
		var b: Vector3 = pair[1]
		var low: float = _attachment(pattern) - _sag(pattern) - BULB_DROP - BULB_RADIUS
		# The box contains the actual droppers/globes plus cable thickness, not the field below.
		var minimum: Vector3 = Vector3(
			minf(a.x, b.x) - BULB_RADIUS, low, minf(a.z, b.z) - BULB_RADIUS
		)
		var maximum: Vector3 = Vector3(
			maxf(a.x, b.x) + BULB_RADIUS,
			_attachment(pattern) + CABLE_CORRIDOR_CAP,
			maxf(a.z, b.z) + BULB_RADIUS
		)
		result.append(
			{"id": "Span%02d" % index, "kind": "cable", "bounds": AABB(minimum, maximum - minimum)}
		)
	return result


static func envelope(item: String = ITEM, site: String = "PARALLEL") -> AABB:
	if item != ITEM or not SPANS.has(site):
		return AABB()
	var boxes: Array[Dictionary] = components(site)
	var result: AABB = boxes[0].bounds
	for index in range(1, boxes.size()):
		result = result.merge(boxes[index].bounds)
	return result


static func pose(_site: String) -> Transform3D:
	return Transform3D.IDENTITY


static func cable_point(pattern: String, span: int, t: float) -> Vector3:
	if (
		not SPANS.has(pattern)
		or span < 0
		or span >= SPANS[pattern].size()
		or not is_finite(t)
		or t < 0
		or t > 1
	):
		return Vector3.INF
	var pair: Array = SPANS[pattern][span]
	return (pair[0] as Vector3).lerp(pair[1], t) - Vector3(0, 4 * _sag(pattern) * t * (1 - t), 0)


static func create(item: String = ITEM, placement: Dictionary = {}) -> Node3D:
	if (
		item != ITEM
		or not placement.get("copy") is String
		or placement.copy.is_empty()
		or not placement.get("site") is String
		or not SPANS.has(placement.site)
	):
		return null
	var pattern: String = placement.site
	var root: Node3D = Node3D.new()
	root.name = "ST111LightingKit"
	var materials: Dictionary = {}
	var meshes: Dictionary = {}  # One live clone per canonical mesh, scoped to this owned kit.
	for branch: String in ["Visual", "Collision", "Sources"]:
		var child: Node3D = Node3D.new()
		child.name = branch
		root.add_child(child)
	for spec: Dictionary in _definitions(pattern):
		var node: Node3D
		if spec.kind == "mesh":
			var mesh: MeshInstance3D = MeshInstance3D.new()
			if not meshes.has(spec.mesh):
				meshes[spec.mesh] = (spec.mesh as Mesh).duplicate(true)
			mesh.mesh = meshes[spec.mesh]
			if not materials.has(spec.material):
				materials[spec.material] = (spec.material as Material).duplicate(true)
			mesh.material_override = materials[spec.material]
			node = mesh
		elif spec.kind == "post":
			var body: StaticBody3D = StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.set_meta("surface_id", spec.id)
			body.set_meta("ball_surface", &"stadium_scenery")
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.name = "Shape"
			shape.shape = (spec.shape as Shape3D).duplicate(true)
			body.add_child(shape)
			node = body
		else:
			var source: SpotLight3D = SpotLight3D.new()
			for field: String in spec.fields:
				source.set(field, spec.fields[field])
			source.set_meta("span_index", spec.span)
			node = source
		node.name = spec.id
		node.transform = spec.pose
		root.get_node(spec.branch).add_child(node)
	root.set_meta("geometry_version", VERSION)
	root.set_meta("model_version", VERSION)
	root.set_meta("model_variant", "WHOLE-LIGHTING-KIT-" + pattern + "-v1")
	root.set_meta("geometry_signature", signature())
	root.set_meta("night_qualified", false)
	root.set_meta("qualification_status", "CANDIDATE")
	root.set_meta("final_art_accepted", false)
	root.set_meta("authoring_status", "Working")
	root.set_meta("scenery_only", true)
	root.set_meta("static_geometry", true)
	root.set_meta("obstacle_units", 0)
	root.set_meta("included_supports", support_positions(pattern).size())
	root.set_meta("supports_separately_owned", false)
	root.set_meta("overhead_collision", false)
	root.set_meta("envelope", envelope(item, pattern))
	_bind(root, placement.copy, pattern)
	return root


static func valid(root: Node3D) -> bool:
	# Dormant installation guard. Production activation must own a separate sealed-state lease.
	if (
		not is_instance_valid(root)
		or root.is_queued_for_deletion()
		or root.get_class() != "Node3D"
		or not root.get_meta("owned_copy", null) is String
		or str(root.get_meta("owned_copy")).is_empty()
		or not root.get_meta("site", null) is String
	):
		return false
	var pattern: String = root.get_meta("site")
	var copy: String = root.get_meta("owned_copy")
	if (
		not SPANS.has(pattern)
		or not _clean(root, copy, pattern)
		or root.transform != Transform3D.IDENTITY
		or root.get_child_count() != 3
		or root.get_meta("geometry_version", -1) != VERSION
		or root.get_meta("model_version", -1) != VERSION
		or root.get_meta("geometry_signature", "") != signature()
		or root.get_meta("night_qualified", true) != false
		or root.get_meta("obstacle_units", -1) != 0
		or root.get_meta("included_supports", -1) != support_positions(pattern).size()
		or root.get_meta("supports_separately_owned", true) != false
		or root.get_meta("overhead_collision", true) != false
	):
		return false
	var counts: Dictionary = {"Visual": 0, "Collision": 0, "Sources": 0}
	var seen_resources: Dictionary = {}
	for spec: Dictionary in _definitions(pattern):
		var node: Node3D = root.get_node_or_null(spec.branch + "/" + spec.id) as Node3D
		if (
			node == null
			or not _clean(node, copy, pattern, spec.kind != "source")
			or node.transform != spec.pose
		):
			return false
		counts[spec.branch] += 1
		if spec.kind == "mesh":
			if (
				node.get_class() != "MeshInstance3D"
				or node.get_child_count() != 0
				or not _resource_matches(node.mesh, spec.mesh, seen_resources)
				or not _resource_matches(node.material_override, spec.material, seen_resources)
				or node.material_overlay != null
				or node.get_surface_override_material(0) != null
				or not _render_defaults(node)
			):
				return false
		elif spec.kind == "post":
			if (
				node.get_class() != "StaticBody3D"
				or node.get_child_count() != 1
				or node.collision_layer != 1
				or node.collision_mask != 0
				or node.disable_mode != 0
				or node.physics_material_override != null
				or node.constant_linear_velocity != Vector3.ZERO
				or node.constant_angular_velocity != Vector3.ZERO
				or node.get_meta("surface_id", "") != spec.id
				or node.get_meta("ball_surface", null) != &"stadium_scenery"
			):
				return false
			var shape: CollisionShape3D = node.get_node_or_null("Shape") as CollisionShape3D
			if (
				shape == null
				or shape.get_class() != "CollisionShape3D"
				or shape.get_child_count() != 0
				or not _clean(shape, copy, pattern)
				or shape.transform != Transform3D.IDENTITY
				or shape.disabled
				or not _resource_matches(shape.shape, spec.shape, seen_resources)
			):
				return false
		else:
			if (
				node.get_class() != "SpotLight3D"
				or node.get_child_count() != 0
				or node.get_meta("span_index", -1) != spec.span
			):
				return false
			for field: String in spec.fields:
				if node.get(field) != spec.fields[field]:
					return false
	for branch: String in counts:
		var node: Node3D = root.get_node_or_null(branch) as Node3D
		if (
			node == null
			or node.get_class() != "Node3D"
			or not _clean(node, copy, pattern)
			or node.transform != Transform3D.IDENTITY
			or node.get_child_count() != counts[branch]
		):
			return false
	return true


static func _definitions(pattern: String) -> Array[Dictionary]:
	if _definitions_cache.has(pattern):
		return _definitions_cache[pattern]
	var rows: Array[Dictionary] = []
	var posts: Array[Vector3] = support_positions(pattern)
	var height: float = _attachment(pattern) + 0.2
	for index in range(posts.size()):
		var point: Vector3 = posts[index]
		_cylinder(
			rows,
			"Post%02dFooting" % index,
			point + Vector3(0, 0.1, 0),
			0.2,
			0.28,
			Color("7d8981"),
			true
		)
		_cylinder(
			rows,
			"Post%02dMast" % index,
			point + Vector3(0, (height + 0.2) / 2, 0),
			height - 0.2,
			0.1,
			Color("526b61"),
			true
		)
	for span in range(SPANS[pattern].size()):
		for index in range(CABLE_SEGMENTS):
			var a: Vector3 = cable_point(pattern, span, float(index) / CABLE_SEGMENTS)
			var b: Vector3 = cable_point(pattern, span, float(index + 1) / CABLE_SEGMENTS)
			_cylinder(
				rows,
				"Span%02dCable%03d" % [span, index],
				(a + b) / 2,
				a.distance_to(b),
				CABLE_RADIUS,
				Color("323d38")
			)
			rows[-1].pose.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		for index in range(BULB_COUNT):
			var anchor: Vector3 = cable_point(pattern, span, (index + 0.5) / BULB_COUNT)
			_cylinder(
				rows,
				"Span%02dDropper%02d" % [span, index],
				anchor - Vector3(0, 0.07, 0),
				0.14,
				0.012,
				Color("323d38")
			)
			_cylinder(
				rows,
				"Span%02dSocket%02d" % [span, index],
				anchor - Vector3(0, 0.14, 0),
				0.035,
				0.035,
				Color("425a53")
			)
			var mesh: SphereMesh = SphereMesh.new()
			mesh.radius = BULB_RADIUS
			mesh.height = BULB_RADIUS * 2
			mesh.radial_segments = 16
			mesh.rings = 8
			var material: StandardMaterial3D = _material(Color("fff0c8"))
			material.emission = Color("ffdc98")
			material.emission_enabled = false
			material.emission_energy_multiplier = 0.0
			rows.append(
				{
					"kind": "mesh",
					"branch": "Visual",
					"id": "Span%02dBulb%02d" % [span, index],
					"pose": Transform3D(Basis.IDENTITY, anchor - Vector3(0, BULB_DROP, 0)),
					"mesh": mesh,
					"material": material
				}
			)
		var source_pose: Transform3D = Transform3D(Basis.IDENTITY, cable_point(pattern, span, 0.5))
		source_pose = source_pose.looking_at(Vector3(0, 0, 12), Vector3.FORWARD)
		var fields: Dictionary = {
			"visible": false,
			"light_color": Color("ffe4c2"),
			"light_energy": SOURCE_ENERGY,
			"spot_range": SOURCE_RANGE,
			"spot_angle": SOURCE_ANGLE,
			"spot_attenuation": 0.65,
			"spot_angle_attenuation": 0.7,
			"shadow_enabled": true,
			"shadow_bias": 0.05,
			"shadow_normal_bias": 0.2,
			"light_negative": false,
			"light_cull_mask": 1048575,
			"light_bake_mode": Light3D.BAKE_DISABLED
		}
		# Bind the engine's exact stored values and every other persisted source default.
		# This also rejects a foreign projector, changed shadow mode or distance fade.
		var expected_source: SpotLight3D = SpotLight3D.new()
		expected_source.name = "Span%02dSource" % span
		expected_source.transform = source_pose
		for field: String in fields:
			expected_source.set(field, fields[field])
		for property: Dictionary in expected_source.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				fields[property.name] = expected_source.get(property.name)
		expected_source.free()
		rows.append(
			{
				"kind": "source",
				"branch": "Sources",
				"id": "Span%02dSource" % span,
				"span": span,
				"pose": source_pose,
				"fields": fields
			}
		)
	# Pool only exact serialized geometry, never approximate dimensions or live resources.
	# Canonical identity is pooled too, preserving _resource_matches' alias consistency.
	var meshes: Dictionary = {}
	for spec: Dictionary in rows:
		if spec.kind != "mesh":
			continue
		var key: PackedByteArray = _mesh_key(spec.mesh)
		if key.is_empty():
			continue
		if not meshes.has(key):
			meshes[key] = spec.mesh
		spec.mesh = meshes[key]
	_definitions_cache[pattern] = rows
	return rows


static func _cylinder(
	rows: Array[Dictionary],
	id: String,
	center: Vector3,
	height: float,
	radius: float,
	color: Color,
	solid: bool = false
) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 16
	rows.append(
		{
			"kind": "mesh",
			"branch": "Visual",
			"id": id,
			"pose": Transform3D(Basis.IDENTITY, center),
			"mesh": mesh,
			"material": _material(color)
		}
	)
	if solid:
		var shape: CylinderShape3D = CylinderShape3D.new()
		shape.height = height
		shape.radius = radius
		shape.margin = 0
		rows.append(
			{
				"kind": "post",
				"branch": "Collision",
				"id": id,
				"pose": Transform3D(Basis.IDENTITY, center),
				"shape": shape
			}
		)


static func _material(color: Color) -> StandardMaterial3D:
	if _materials_cache.has(color):
		return _materials_cache[color]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	_materials_cache[color] = material
	return material


static func _bind(node: Node, copy: String, pattern: String) -> void:
	for key: String in ["owned_copy", "paid_copy"]:
		node.set_meta(key, copy)
	node.set_meta("stadium_item", ITEM)
	node.set_meta("site", pattern)
	node.set_meta("pattern", pattern)
	node.set_meta("surface_role", ROLE)
	node.set_meta("physics_profile", ROLE)
	for child: Node in node.get_children():
		_bind(child, copy, pattern)


static func _clean(node: Node3D, copy: String, pattern: String, visible: bool = true) -> bool:
	return (
		node.get_script() == null
		and not node.is_queued_for_deletion()
		and node.visible == visible
		and not node.top_level
		and node.process_mode == Node.PROCESS_MODE_INHERIT
		and node.get_meta("stadium_item", null) == ITEM
		and node.get_meta("owned_copy", null) == copy
		and node.get_meta("paid_copy", null) == copy
		and node.get_meta("site", null) == pattern
		and node.get_meta("pattern", null) == pattern
		and node.get_meta("surface_role", null) == ROLE
		and node.get_meta("physics_profile", null) == ROLE
	)


static func _resource_matches(actual: Resource, expected: Resource, seen: Dictionary = {}) -> bool:
	if actual == null or actual.get_class() != expected.get_class() or actual.get_script() != null:
		return false
	if seen.has(actual):
		return seen[actual] == expected
	for property: Dictionary in expected.get_property_list():
		if (
			int(property.usage)
			& (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP)
		):
			continue
		if (
			(
				not expected is StandardMaterial3D
				and not (int(property.usage) & PROPERTY_USAGE_STORAGE)
			)
			or property.name in ["resource_name", "resource_path", "resource_local_to_scene"]
		):
			continue
		var value: Variant = actual.get(property.name)
		var canonical: Variant = expected.get(property.name)
		if typeof(value) != typeof(canonical) or value != canonical:
			return false
	seen[actual] = expected
	return true


static func _render_defaults(node: MeshInstance3D) -> bool:
	return (
		node.layers == 1
		and node.transparency == 0.0
		and node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		and node.extra_cull_margin == 0
		and not node.ignore_occlusion_culling
		and node.lod_bias == 1.0
		and node.gi_mode == GeometryInstance3D.GI_MODE_STATIC
		and node.visibility_range_begin == 0
		and node.visibility_range_end == 0
		and node.visibility_range_begin_margin == 0
		and node.visibility_range_end_margin == 0
		and node.visibility_range_fade_mode == 0
		and node.custom_aabb == AABB()
		and node.sorting_offset == 0
		and node.sorting_use_aabb_center
	)


static func _attachment(pattern: String) -> float:
	return 6.0 if pattern == "MIXED_EDGE" else 10.0


static func _sag(pattern: String) -> float:
	return 0.6 if pattern == "MIXED_EDGE" else 1.2


static func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _mesh_key(mesh: Mesh) -> PackedByteArray:
	# Native primitive meshes with no attached resources/scripts/metadata only.
	if (
		mesh == null
		or mesh.get_class() not in ["CylinderMesh", "SphereMesh"]
		or mesh.get_script() != null
		or not mesh.get_meta_list().is_empty()
	):
		return PackedByteArray()
	var values: Dictionary = {"class": mesh.get_class()}
	for field: Dictionary in mesh.get_property_list():
		if (
			not (int(field.usage) & PROPERTY_USAGE_STORAGE)
			or (
				int(field.usage)
				& (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP)
			)
			or field.name in ["resource_name", "resource_path", "resource_local_to_scene"]
		):
			continue
		var value: Variant = mesh.get(field.name)
		if value is Object:
			return PackedByteArray()  # Never alias an attached resource by instance ID.
		values[field.name] = value
	return var_to_bytes(values)  # Exact bytes as key, no float rounding or digest collisions.

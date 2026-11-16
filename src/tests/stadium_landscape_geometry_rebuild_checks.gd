class_name StadiumLandscapeGeometryRebuildChecks
extends RefCounted
## Geometry support for the shared landscape fixture, never another runner.
## Every actual surface/vertex/native mesh resource is inspected, then copies are
## mutated independently. Successful-path count: 3 + 4*(1+18) + 8+7+9+7 + 4 = 114.

const ITEMS: Array[String] = ["ST-013", "ST-014", "ST-018", "ST-019"]
const COMMON_CHECKS: int = 18
const ANATOMY_CHECKS: Dictionary = {"ST-013": 8, "ST-014": 7, "ST-018": 9, "ST-019": 7}
const EXPECTED_CHECKS: int = 114
const EPS: float = 0.0002
const MESH_COUNTS: Dictionary = {"ST-013": 49, "ST-014": 26, "ST-018": 57, "ST-019": 37}
const NATIVE_TYPES: Dictionary = {
	"ST-013": ["ArrayMesh", "CylinderMesh", "SphereMesh"],
	"ST-014": ["ArrayMesh", "BoxMesh", "CylinderMesh", "SphereMesh"],
	"ST-018": ["ArrayMesh", "CylinderMesh", "SphereMesh", "TorusMesh"],
	"ST-019": ["ArrayMesh", "SphereMesh"]
}
const RESERVES: Dictionary = {
	"ST-013": AABB(Vector3(-3.5, 0, -3.5), Vector3(7, 7, 7)),
	"ST-014": AABB(Vector3(-1, 0, -0.5), Vector3(2, 1.8, 1)),
	"ST-018": AABB(Vector3(-2.75, 0, -2.75), Vector3(5.5, 1, 5.5)),
	"ST-019": AABB(Vector3(-2.5, 0, -2.25), Vector3(5, 1.8, 4.5))
}
const MINIMUM_VISIBLE: Dictionary = {
	"ST-013": Vector3(6.5, 6.9, 6.5),
	"ST-014": Vector3(1.99, 1.49, 0.59),
	"ST-018": Vector3(4.99, 0.38, 4.99),
	"ST-019": Vector3(4.49, 1.39, 3.49)
}


class GeometryProbe:
	extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"

	func _ready() -> void:
		pass


static func expected_checks() -> int:
	var count: int = 3 + ITEMS.size() * (1 + COMMON_CHECKS) + 4
	for item: String in ANATOMY_CHECKS:
		count += int(ANATOMY_CHECKS[item])
	return count


static func run(parent: Node3D, check: Callable) -> void:
	var probe: GeometryProbe = GeometryProbe.new()
	parent.add_child(probe)
	probe.position = Vector3(1800, 0, 0)
	_emit(
		check,
		(
			StadiumLandscapeModels.ITEMS == ITEMS
			and StadiumLandscapeModels.VERSION == 1
			and expected_checks() == EXPECTED_CHECKS
		),
		"one bounded four-item landscape family and exact check budget"
	)
	_emit(
		check,
		(
			(
				FileAccess.get_sha256(
					"res://src/presentation/stadium/stadium_ground_props_models.gd"
				)
				== "126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4"
			)
			and (
				FileAccess.get_sha256("res://src/presentation/stadium/stadium_starter_models.gd")
				== "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
			)
		),
		"reused ground-prop and primitive factories remain byte-for-byte frozen"
	)
	_emit(
		check,
		(
			StadiumLandscapeModels.create("ST-045") == null
			and StadiumLandscapeModels.create("") == null
			and StadiumLandscapeModels.bounds("ST-045") == AABB()
		),
		"unsupported IDs including treehouse do not create landscape or reserve"
	)
	for item: String in ITEMS:
		var model: Node3D = StadiumLandscapeModels.create(item)
		_emit(check, model != null, "complete full-size landscape model exists", {"item": item})
		if model == null:
			continue
		probe.add_child(model)
		await _common(probe, model, item, check)
		match item:
			"ST-013":
				_tree(model, check)
			"ST-014":
				_hedge(model, check)
			"ST-018":
				_pond(model, check)
			"ST-019":
				_rocks(model, check)
		model.free()
	_hedge_joins(probe, check)
	probe.free()


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"LANDSCAPE_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _common(probe: GeometryProbe, model: Node3D, item: String, check: Callable) -> void:
	var visual: Node3D = model.get_node_or_null("Visual") as Node3D
	var collision: Node3D = model.get_node_or_null("Collision") as Node3D
	_emit(
		check,
		(
			model.get_child_count() == 2
			and visual != null
			and collision != null
			and model.transform == Transform3D.IDENTITY
			and visual.transform == Transform3D.IDENTITY
			and collision.transform == Transform3D.IDENTITY
		),
		"landscape assembly has exactly two identity branches",
		{"item": item}
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item", "") == item
			and model.get_meta("geometry_version", 0) == 1
			and model.get_meta("model_version", 0) == 1
			and model.get_meta("scenery_only", false)
			and model.get_meta("static_geometry", false)
			and model.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
			and model.get_meta("physics_profile", "") == "DECORATIVE_AFTER_TERMINAL"
		),
		"item identity and explicit static scenery metadata are retained",
		{"item": item}
	)
	_emit(
		check,
		(
			StadiumLandscapeModels.bounds(item) == RESERVES[item]
			and StadiumLandscapeModels.envelope(item) == RESERVES[item]
			and model.get_meta("envelope") == RESERVES[item]
		),
		"factory reservation is the complete BN source envelope",
		{"item": item}
	)
	var static_failure: String = _static_failure(model)
	_emit(
		check,
		static_failure.is_empty(),
		"only static visible mesh descendants exist without scripts or hidden effects",
		{"item": item, "node": static_failure}
	)
	_emit(
		check,
		(
			collision.get_child_count() == 0
			and model.find_children("*", "CollisionObject3D", true, false).is_empty()
			and model.find_children("*", "CollisionShape3D", true, false).is_empty()
			and not model.get_meta("treehouse_support", true)
			and not model.get_meta("water_scoring", true)
		),
		"empty collision branch cannot yield live contacts, water scoring or treehouse support",
		{"item": item}
	)
	var transforms: bool = true
	for node: Node3D in model.find_children("*", "Node3D", true, false):
		transforms = (
			transforms
			and node.transform.origin.is_finite()
			and node.basis.is_finite()
			and node.basis.determinant() > 0.0
			and not node.top_level
		)
	_emit(check, transforms, "every member has finite positive-handed transforms", {"item": item})
	var scan: Dictionary = _scan(model)
	_emit(
		check,
		str(scan.failure).is_empty(),
		"all actual mesh surfaces, vertices, normals, indices and native resources validate",
		{"item": item, "member": scan.failure}
	)
	var points: PackedVector3Array = _points(model)
	var actual: AABB = _bounds(points)
	var reserve: AABB = RESERVES[item]
	_emit(
		check,
		not points.is_empty() and reserve.grow(EPS).encloses(actual),
		"all actual vertices fit the complete declared reservation",
		{"item": item, "actual": str(actual), "reserve": str(reserve)}
	)
	var radial: float = _radius(points)
	_emit(
		check,
		(item != "ST-013" or radial <= 3.5 + EPS) and (item != "ST-018" or radial <= 2.75 + EPS),
		"circular tree and pond reservations include every root, branch, crown and stone vertex",
		{"item": item, "radius": radial}
	)
	var minimum: Vector3 = MINIMUM_VISIBLE[item]
	_emit(
		check,
		actual.size.x >= minimum.x and actual.size.y >= minimum.y and actual.size.z >= minimum.z,
		"source-sized complete geometry cannot regress to a tiny proxy",
		{"item": item, "actual": str(actual.size), "minimum": str(minimum)}
	)
	_emit(
		check,
		scan.types == NATIVE_TYPES[item],
		"every authored native mesh type is covered by the surface scanner",
		{"item": item, "types": scan.types}
	)
	_emit(
		check,
		int(scan.meshes) == int(MESH_COUNTS[item]) and int(scan.vertices) > 300,
		"complete authored anatomy has the exact bounded mesh count",
		{"item": item, "meshes": scan.meshes, "vertices": scan.vertices}
	)
	var appearance: String = _appearance_failure(model)
	_emit(
		check,
		appearance.is_empty() and int(scan.colors) >= 5,
		(
			"opaque textured-by-geometry materials retain varied readable colors without shader or "
			+ "light gimmicks"
		),
		{"item": item, "member": appearance, "colors": scan.colors}
	)
	var before: String = probe._grand_snapshot(model)
	var second: Node3D = StadiumLandscapeModels.create(item)
	_emit(
		check,
		probe._grand_snapshot(second) == before,
		"fresh copies have identical actual geometry and appearance",
		{"item": item}
	)
	_emit(
		check,
		_independent(model, second),
		"every mesh and material resource is independent across paid copies",
		{"item": item}
	)
	_mutate(second)
	_emit(
		check,
		probe._grand_snapshot(model) == before and probe._grand_snapshot(second) != before,
		"mutating a copy's native resource, material and pose cannot alter its neighbor",
		{"item": item}
	)
	second.free()
	var fresh: Node3D = StadiumLandscapeModels.create(item)
	_emit(
		check,
		probe._grand_snapshot(fresh) == before,
		"regeneration stays deterministic after destructive copy mutation",
		{"item": item}
	)
	fresh.free()
	await probe.get_tree().process_frame
	_emit(
		check,
		probe._grand_snapshot(model) == before,
		"a rendered frame leaves all static scenery geometry and appearance unchanged",
		{"item": item}
	)


static func _static_failure(model: Node3D) -> String:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node.get_class() not in ["Node3D", "MeshInstance3D"]
			or node.get_script() != null
			or node.is_processing()
			or node.is_physics_processing()
		):
			return str(node.name)
		if node is Node3D and not node.visible:
			return str(node.name) + ":hidden"
	return ""


static func _scan(model: Node3D) -> Dictionary:
	var result: Dictionary = {"failure": "", "types": [], "meshes": 0, "vertices": 0, "colors": 0}
	var colors: Dictionary = {}
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		result.meshes += 1
		var mesh: Mesh = node.mesh
		if mesh == null or mesh.get_surface_count() == 0:
			result.failure = str(node.name) + ":missing-mesh"
			return result
		var type: String = mesh.get_class()
		if type not in result.types:
			result.types.append(type)
		var native: bool = mesh is ArrayMesh
		if mesh is BoxMesh:
			native = (
				mesh.size.is_finite() and mesh.size.x > 0 and mesh.size.y > 0 and mesh.size.z > 0
			)
		elif mesh is CylinderMesh:
			native = (
				mesh.height > 0
				and mesh.top_radius > 0
				and mesh.bottom_radius > 0
				and mesh.radial_segments >= 12
				and mesh.cap_top
				and mesh.cap_bottom
			)
		elif mesh is SphereMesh:
			native = (
				is_equal_approx(mesh.radius, 1.0)
				and is_equal_approx(mesh.height, 2.0)
				and mesh.radial_segments == 12
				and mesh.rings == 6
				and not mesh.is_hemisphere
			)
		elif mesh is TorusMesh:
			native = (
				mesh.inner_radius > 0
				and mesh.outer_radius > mesh.inner_radius
				and mesh.rings >= 20
				and mesh.ring_segments >= 4
			)
		if not native:
			result.failure = str(node.name) + ":native:" + type
			return result
		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var elements: int = indices.size() if not indices.is_empty() else vertices.size()
			if vertices.is_empty() or normals.size() != vertices.size() or elements % 3 != 0:
				result.failure = str(node.name) + ":surface-arrays"
				return result
			result.vertices += vertices.size()
			for index in range(vertices.size()):
				if (
					not vertices[index].is_finite()
					or not normals[index].is_finite()
					or absf(normals[index].length() - 1.0) > 0.001
				):
					result.failure = "%s:vertex:%d" % [node.name, index]
					return result
			for index: int in indices:
				if index < 0 or index >= vertices.size():
					result.failure = "%s:index:%d" % [node.name, index]
					return result
			if (
				mesh.surface_get_material(surface) != null
				or node.get_surface_override_material(surface) != null
			):
				result.failure = str(node.name) + ":unexpected-surface-material"
				return result
		var material: StandardMaterial3D = node.material_override as StandardMaterial3D
		if material != null:
			colors[material.albedo_color.to_html()] = true
	result.types.sort()
	result.colors = colors.size()
	return result


static func _appearance_failure(model: Node3D) -> String:
	for node: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = node.material_override as StandardMaterial3D
		if (
			material == null
			or material.albedo_color.a != 1.0
			or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			or material.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL
			or material.emission_enabled
			or material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED
			or material.grow
			or material.albedo_texture != null
			or material.roughness < 0.20
			or material.roughness > 0.90
			or node.transparency != 0.0
			or node.material_overlay != null
			or node.layers != 1
		):
			return str(node.name)
	return ""


static func _resources(model: Node3D) -> Array[Resource]:
	var result: Array[Resource] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		result.append(mesh.mesh)
		result.append(mesh.material_override)
	return result


static func _independent(first: Node3D, second: Node3D) -> bool:
	var resources: Array[Resource] = _resources(first)
	var seen: Array[Resource] = []
	for resource: Resource in _resources(second):
		if resource == null or resources.has(resource) or seen.has(resource):
			return false
		seen.append(resource)
	return true


static func _mutate(model: Node3D) -> void:
	for member: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if member.mesh is ArrayMesh:
			member.mesh.clear_surfaces()
		elif member.mesh is CylinderMesh:
			member.mesh.height += 0.125
		elif member.mesh is BoxMesh:
			member.mesh.size += Vector3(0.125, 0, 0)
		elif member.mesh is SphereMesh:
			member.mesh.radius += 0.125
		elif member.mesh is TorusMesh:
			member.mesh.outer_radius += 0.125
		member.material_override.albedo_color = Color("ff00ff")
		member.position += Vector3(0, 0.125, 0)
	model.position += Vector3(0.25, 0, 0)


static func _points(model: Node3D, prefix: String = "") -> PackedVector3Array:
	var result: PackedVector3Array = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not prefix.is_empty() and not str(mesh.name).begins_with(prefix):
			continue
		var pose: Transform3D = model.global_transform.affine_inverse() * mesh.global_transform
		for surface in range(mesh.mesh.get_surface_count()):
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				result.append(pose * point)
	return result


static func _bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var box: AABB = AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		box = box.expand(point)
	return box


static func _radius(points: PackedVector3Array) -> float:
	var result: float = 0.0
	for point: Vector3 in points:
		result = maxf(result, Vector2(point.x, point.z).length())
	return result


static func _members(model: Node3D, prefix: String) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(mesh.name).begins_with(prefix):
			result.append(mesh)
	return result


static func _member(model: Node3D, name: String) -> MeshInstance3D:
	return model.get_node_or_null("Visual/" + name) as MeshInstance3D


static func _same(actual: Vector3, expected: Vector3) -> bool:
	return actual.distance_to(expected) <= EPS


static func _tree(model: Node3D, check: Callable) -> void:
	var trunk: MeshInstance3D = _member(model, "TreeTrunk")
	_emit(
		check,
		(
			trunk.mesh is CylinderMesh
			and is_equal_approx(trunk.mesh.height, 3.9)
			and is_equal_approx(trunk.mesh.bottom_radius, 0.48)
			and is_equal_approx(trunk.mesh.top_radius, 0.24)
			and _same(trunk.position, Vector3(0, 1.95, 0))
		),
		"shade tree has a full tapered grounded trunk"
	)
	var roots: AABB = _bounds(_points(model, "TreeRoot"))
	_emit(
		check,
		(
			_members(model, "TreeRoot").size() == 6
			and absf(roots.position.y) < EPS
			and roots.end.y >= 0.679
			and _radius(_points(model, "TreeRoot")) >= 1.31
		),
		"six visible buttress roots meet the ground inside the complete tree envelope",
		{"bounds": str(roots)}
	)
	var joints: bool = (
		_members(model, "TreeBranch").size() == 6 and _members(model, "TreeFork").size() == 12
	)
	for index in range(6):
		var branch: MeshInstance3D = _member(model, "TreeBranch%d" % index)
		var start: Vector3 = branch.transform * Vector3(0, -branch.mesh.height * 0.5, 0)
		var end: Vector3 = branch.transform * Vector3(0, branch.mesh.height * 0.5, 0)
		joints = joints and _same(start, Vector3(0, 1.9 + 0.21 * index, 0))
		for hand in [-1, 1]:
			var fork: MeshInstance3D = _member(model, "TreeFork%d_%d" % [index, hand])
			joints = joints and _same(end, fork.transform * Vector3(0, -fork.mesh.height * 0.5, 0))
	_emit(
		check,
		joints,
		"six branching limbs and twelve tapered forks join the actual trunk and one another"
	)
	_emit(
		check,
		_members(model, "Crown").size() == 18 and _members(model, "BarkRidge").size() == 6,
		"complete shade tree includes layered crown and bark anatomy"
	)
	var crown: AABB = _bounds(_points(model, "Crown"))
	_emit(
		check,
		(
			crown.size.x >= 6.5
			and crown.size.z >= 6.5
			and crown.position.y >= 3.3
			and crown.end.y >= 6.9
			and crown.end.y <= 7.0
		),
		"broad shade crown occupies the source-scale width and height",
		{"crown": str(crown)}
	)
	var supported: bool = true
	for fork: MeshInstance3D in _members(model, "TreeFork"):
		var tip: Vector3 = fork.transform * Vector3(0, fork.mesh.height * 0.5, 0)
		var inside: bool = false
		for lobe: MeshInstance3D in _members(model, "Crown"):
			inside = inside or (lobe.transform.affine_inverse() * tip).length() <= 1.0
		supported = supported and inside
	_emit(
		check,
		supported,
		"every visible limb tip enters actual crown volume rather than floating below it"
	)
	var bark: Color = trunk.material_override.albedo_color
	var leaf: Color = _member(model, "CrownTop").material_override.albedo_color
	_emit(
		check,
		bark.r > bark.g and leaf.g > leaf.r,
		"bark and foliage retain distinct warm and green appearance"
	)
	_emit(
		check,
		not model.get_meta("treehouse_support", true) and _members(model, "Treehouse").is_empty(),
		"ST-013 is one complete shade tree without ST-045 mounts or inventory"
	)


static func _hedge(model: Node3D, check: Callable) -> void:
	var visible: AABB = _bounds(_points(model))
	_emit(
		check,
		_same(visible.position, Vector3(-1, 0, -0.3)) and _same(visible.size, Vector3(2, 1.5, 0.6)),
		"hedge visible section is exactly two metres by sixty centimetres by one and a half metres",
		{"visible": str(visible)}
	)
	_emit(
		check,
		(
			_member(model, "HedgeCore").mesh is ArrayMesh
			and _same(_bounds(_points(model, "HedgeCore")).size, Vector3(1.96, 1.38, 0.6))
		),
		"hedge core has fully closed bevelled actual foliage geometry"
	)
	var caps: bool = _members(model, "HedgeFinishedEnd").size() == 2
	for side in [-1, 1]:
		var cap: MeshInstance3D = _member(model, "HedgeFinishedEnd%d" % side)
		caps = caps and cap.mesh is BoxMesh and _same(cap.position, Vector3(side * 0.98, 0.80, 0))
		caps = caps and _same(cap.mesh.size, Vector3(0.04, 1.30, 0.54))
	_emit(check, caps, "both included finished end caps are exact and independently modeled")
	var left: AABB = _bounds(_points(model, "HedgeFinishedEnd-1"))
	var right: AABB = _bounds(_points(model, "HedgeFinishedEnd1"))
	_emit(
		check,
		absf(left.position.x + 1.0) < EPS and absf(right.end.x - 1.0) < EPS,
		"finished end faces stop flush at the two-metre neighbor join planes"
	)
	_emit(
		check,
		(
			_members(model, "HedgeStem").size() == 4
			and _bounds(_points(model, "HedgeStem")).position.y > 0.0
		),
		"four bounded stems ground the foliage without creating live colliders"
	)
	_emit(
		check,
		(
			_members(model, "HedgeLeaf").size() == 12
			and _members(model, "HedgeTop").size() == 6
			and absf(_bounds(_points(model, "HedgeTop")).end.y - 1.5) < EPS
		),
		"side foliage and trimmed upper edge remain inside the exact visible hedge dimensions"
	)
	_emit(
		check,
		(
			_same(_member(model, "HedgeSoil").mesh.size, Vector3(1.90, 0.06, 0.50))
			and (
				_member(model, "HedgeSoil").material_override.albedo_color.r
				> _member(model, "HedgeSoil").material_override.albedo_color.g
			)
		),
		"included brown soil base completes each independently storable section"
	)


static func _pond(model: Node3D, check: Callable) -> void:
	var visible: AABB = _bounds(_points(model))
	_emit(
		check,
		(
			absf(visible.size.x - 5.0) < EPS
			and absf(visible.size.z - 5.0) < EPS
			and visible.position.y >= -EPS
			and visible.end.y < 0.50
		),
		"complete pond occupies five-metre visible diameter below the one-metre limit",
		{"visible": str(visible)}
	)
	var basin: MeshInstance3D = _member(model, "PondBasin")
	_emit(
		check,
		(
			basin.mesh is CylinderMesh
			and is_equal_approx(basin.mesh.top_radius, 2.5)
			and is_equal_approx(basin.mesh.bottom_radius, 2.5)
			and is_equal_approx(basin.mesh.height, 0.08)
		),
		"pond has a complete grounded five-metre basin"
	)
	var water: MeshInstance3D = _member(model, "PondWater")
	_emit(
		check,
		(
			water.mesh is CylinderMesh
			and is_equal_approx(water.mesh.top_radius, 2.12)
			and _same(water.position, Vector3(0, 0.105, 0))
			and is_equal_approx(water.material_override.roughness, 0.22)
			and water.material_override.albedo_color.g > water.material_override.albedo_color.r
		),
		"large teal water surface remains visibly distinct from the stone edge"
	)
	var backing: MeshInstance3D = _member(model, "PondStoneBacking")
	_emit(
		check,
		(
			backing.mesh is TorusMesh
			and is_equal_approx(backing.mesh.inner_radius, 2.13)
			and is_equal_approx(backing.mesh.outer_radius, 2.43)
			and _members(model, "PondEdgeStone").size() == 24
		),
		"continuous annular stone backing and twenty-four faceted stones complete the pond edge"
	)
	var edge: bool = true
	for index in range(24):
		var stone: MeshInstance3D = _member(model, "PondEdgeStone%d" % index)
		edge = (
			edge
			and stone.mesh is ArrayMesh
			and absf(Vector2(stone.position.x, stone.position.z).length() - 2.20) < EPS
		)
		edge = edge and stone.basis.is_equal_approx(Basis(Vector3.UP, -TAU * index / 24.0))
	_emit(
		check,
		edge and _radius(_points(model, "PondEdgeStone")) <= 2.50,
		"all individual perimeter stones occupy the authored ring without extending the visible diameter"
	)
	var koi: bool = _members(model, "Koi").size() == 21
	for index in range(3):
		koi = (
			koi
			and _member(model, "Koi%dBody" % index).mesh is SphereMesh
			and _member(model, "Koi%dPatch" % index).mesh is SphereMesh
			and _member(model, "Koi%dTail" % index).mesh is ArrayMesh
		)
		for side in [-1, 1]:
			koi = (
				koi
				and _member(model, "Koi%dFin%d" % [index, side]).mesh is ArrayMesh
				and _member(model, "Koi%dEye%d" % [index, side]).mesh is SphereMesh
			)
	_emit(
		check,
		koi,
		"three individually visible koi have bodies, colored patches, tails, paired fins and eyes"
	)
	var fish: AABB = _bounds(_points(model, "Koi"))
	_emit(
		check,
		_radius(_points(model, "Koi")) < 2.10 and fish.position.y >= 0.11 and fish.end.y < 0.18,
		"actual fish geometry is visible at the water surface inside the pond",
		{"fish": str(fish)}
	)
	_emit(
		check,
		(
			_members(model, "PondRipple").size() == 3
			and _members(model, "LilyPad").size() == 3
			and _members(model, "LilyBloom").size() == 3
			and _bounds(_points(model, "Lily")).end.y < 0.20
		),
		"bounded static ripples and lilies add visible pond detail without particles"
	)
	_emit(
		check,
		(
			not model.get_meta("water_scoring", true)
			and model.get_node("Collision").get_child_count() == 0
			and model.find_children("*", "Area3D", true, false).is_empty()
		),
		"scenery water creates no scoring, trap, slowdown or retrieval trigger"
	)


static func _rocks(model: Node3D, check: Callable) -> void:
	var actual: AABB = _bounds(_points(model))
	_emit(
		check,
		(
			_same(actual.position, Vector3(-2.25, 0, -1.75))
			and _same(actual.size, Vector3(4.5, 1.4, 3.5))
		),
		(
			"complete rock garden matches the source four-and-a-half by three-and-a-half by "
			+ "one-point-four visible bounds"
		),
		{"actual": str(actual)}
	)
	var bed: MeshInstance3D = _member(model, "RockGravelBed")
	var unique: Dictionary = {}
	for point: Vector3 in _points(model, "RockGravelBed"):
		unique[point] = true
	_emit(
		check,
		(
			bed.mesh is ArrayMesh
			and unique.size() == 16
			and _same(_bounds(_points(model, "RockGravelBed")).size, Vector3(4.5, 0.08, 3.5))
		),
		"complete bevelled gravel bed is a closed sixteen-corner solid"
	)
	var boulders: Array[MeshInstance3D] = _members(model, "GardenBoulder")
	var shape_ok: bool = boulders.size() == 6
	var sizes: Dictionary = {}
	for boulder: MeshInstance3D in boulders:
		var local: AABB = boulder.mesh.get_aabb()
		shape_ok = (
			shape_ok
			and boulder.mesh is ArrayMesh
			and local.position.y >= -EPS
			and local.end.y >= 0.369
			and local.end.y <= 1.321
		)
		sizes[local.size] = true
	_emit(
		check,
		shape_ok and absf(_bounds(_points(model, "GardenBoulder0")).end.y - 1.4) < EPS,
		"six substantial faceted boulders are grounded on gravel with a full-height main rock"
	)
	_emit(
		check,
		sizes.size() == 6,
		"each boulder has independently authored size and faceted silhouette"
	)
	var pebbles: AABB = _bounds(_points(model, "GardenPebble"))
	_emit(
		check,
		(
			_members(model, "GardenPebble").size() == 18
			and pebbles.position.y >= 0.079
			and pebbles.end.y <= 0.151
			and RESERVES["ST-019"].encloses(pebbles)
		),
		"eighteen included gravel stones sit visibly on the bed inside the reserve"
	)
	_emit(
		check,
		(
			_members(model, "GardenGrass").size() == 12
			and _bounds(_points(model, "GardenGrass")).end.y < 0.40
		),
		"four restrained three-blade plant accents are static bundled art"
	)
	var quarters: bool = true
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		var turn: Basis = Basis(Vector3.UP, angle)
		for point: Vector3 in _points(model):
			var rotated: Vector3 = turn * point
			quarters = (
				quarters
				and absf(rotated.x) <= 2.5 + EPS
				and absf(rotated.z) <= 2.5 + EPS
				and rotated.y >= -EPS
				and rotated.y <= 1.8 + EPS
			)
	_emit(
		check,
		quarters,
		"all four approved quarter-turn orientations preserve bounded complete scenery geometry"
	)


static func _hedge_joins(probe: GeometryProbe, check: Callable) -> void:
	var row: Array[Node3D] = []
	for index in range(3):
		var model: Node3D = StadiumLandscapeModels.create("ST-014")
		probe.add_child(model)
		model.position.x = index * 2.0
		row.append(model)
	var end_faces: bool = true
	var no_overlap: bool = true
	for index in range(2):
		var first: AABB = _bounds(_points(row[index]))
		var next: AABB = _bounds(_points(row[index + 1]))
		end_faces = (
			end_faces
			and (
				absf(
					(
						first.end.x
						+ row[index].position.x
						- next.position.x
						- row[index + 1].position.x
					)
				)
				<= EPS
			)
		)
		no_overlap = (
			no_overlap
			and (
				first.end.x + row[index].position.x
				<= next.position.x + row[index + 1].position.x + EPS
			)
		)
	_emit(
		check, end_faces, "three two-metre hedge neighbors touch exactly at authored finished faces"
	)
	_emit(check, no_overlap, "complete adjacent hedge meshes have no interior overlap")
	_emit(
		check,
		_independent(row[0], row[1]) and _independent(row[1], row[2]),
		"adjacent hedge copies share no mutable mesh or material resource"
	)
	var left: String = probe._grand_snapshot(row[0])
	var right: String = probe._grand_snapshot(row[2])
	row[1].free()
	_emit(
		check,
		(
			probe._grand_snapshot(row[0]) == left
			and probe._grand_snapshot(row[2]) == right
			and _members(row[0], "HedgeFinishedEnd").size() == 2
			and _members(row[2], "HedgeFinishedEnd").size() == 2
		),
		"storing the middle hedge leaves both complete exposed end caps and neighbor poses unchanged"
	)
	row[0].free()
	row[2].free()

class_name StadiumBoundaryOwnedModels
extends RefCounted
## Owned boundary models only. Shared runtime owns admission and world placement.
## Frozen dugout/pole factories remain unchanged; their semantic contact roles survive.

const VERSION: int = 1
const ITEMS: Array[String] = ["ST-032", "ST-074", "ST-021", "ST-064", "ST-020", "ST-071"]
const FENCE_MITER: float = 0.2079973709282294
const FENCE_HEIGHT: float = 1.2
const FENCE_DEPTH: float = 0.35
const FENCE_ROLE: String = "REAR_PERIMETER_DEAD"
const PANEL_ROLE: String = "BACK_WALL_TERMINAL"
const PANEL_BOUNDS: AABB = AABB(Vector3(-0.7, -0.275, 0), Vector3(1.4, 0.55, 0.08))


static func create(item: String, placement: Dictionary) -> Node3D:
	if (
		not ITEMS.has(item)
		or not placement.get("copy") is String
		or str(placement.copy).is_empty()
		or not placement.get("site") is String
		or str(placement.site).is_empty()
	):
		return null
	var root: Node3D
	match item:
		"ST-032":
			root = StadiumTimberDugoutModels.create()
		"ST-074":
			root = StadiumConcreteDugoutModels.create()
		"ST-021":
			if not _finite_number(placement.get("split")):
				return null
			root = StadiumFoulPoleModels.create(float(placement.split))
		"ST-064":
			root = _distance_panel(placement)
		"ST-020", "ST-071":
			if (
				not placement.get("index") is int
				or int(placement.index) < 0
				or int(placement.index) > 7
			):
				return null
			root = _fence(item, int(placement.index))
	if root == null:
		return null
	root.name = item.replace("-", "") + "OwnedBoundary"
	root.set_meta("stadium_item", item)
	root.set_meta("model_factory", "StadiumBoundaryOwnedModels")
	root.set_meta("model_version", VERSION)
	root.set_meta("owned_geometry_version", VERSION)
	root.set_meta("authoring_status", "Working")
	root.set_meta("art_acceptance", "OPEN")
	root.set_meta("envelope", _placement_envelope(item, placement))
	root.set_meta("boundary_placement", placement.duplicate(true))
	root.set_meta("front_direction", Vector3.BACK)
	if item in ["ST-032", "ST-074"]:
		root.set_meta("front_direction", Vector3.FORWARD)
		root.set_meta(
			"opening_bounds",
			(
				StadiumTimberDugoutContract.OPENING
				if item == "ST-032"
				else AABB(Vector3(-1, 0, 0), Vector3(2, StadiumDugoutRecipe.ROOF_UNDERSIDE, 0))
			)
		)
		root.set_meta("roof_present", item == "ST-074")
		root.set_meta(
			"source_factory",
			"StadiumTimberDugoutModels" if item == "ST-032" else "StadiumConcreteDugoutModels"
		)
	elif item == "ST-021":
		root.set_meta("source_factory", "StadiumFoulPoleModels")
		root.set_meta("wall_cap_height", float(placement.split))
		root.get_node("Visual/Lower").set_meta("surface_role", "FOUL_POLE_LOWER")
		root.get_node("Visual/Upper").set_meta("surface_role", "FOUL_POLE_UPPER")
	_bind(root, root, item, placement, _default_role(item))
	return root


static func envelope(item: String) -> AABB:
	match item:
		"ST-032":
			return StadiumTimberDugoutContract.ENVELOPE
		"ST-074":
			return StadiumDugoutRecipe.ENVELOPE
		"ST-021":
			return AABB(
				Vector3(-StadiumFoulPoleSites.RADIUS, 0, -StadiumFoulPoleSites.RADIUS),
				Vector3(
					StadiumFoulPoleSites.RADIUS * 2,
					StadiumFoulPoleSites.HEIGHT,
					StadiumFoulPoleSites.RADIUS * 2
				)
			)
		"ST-064":
			return PANEL_BOUNDS
		"ST-020", "ST-071":
			# Conservative library envelope; each instance stores its exact end variant.
			return AABB(
				Vector3(-1 - FENCE_MITER, 0, -FENCE_DEPTH),
				Vector3(2 + FENCE_MITER * 2, FENCE_HEIGHT, FENCE_DEPTH)
			)
	return AABB()


static func _placement_envelope(item: String, placement: Dictionary) -> AABB:
	if item not in ["ST-020", "ST-071"]:
		return envelope(item)
	var index: int = int(placement.index)
	var left: float = FENCE_MITER if index == 0 else 0.0
	var right: float = FENCE_MITER if index == 7 else 0.0
	return AABB(
		Vector3(-1 - left, 0, -FENCE_DEPTH), Vector3(2 + left + right, FENCE_HEIGHT, FENCE_DEPTH)
	)


static func _default_role(item: String) -> String:
	match item:
		"ST-020", "ST-071":
			return FENCE_ROLE
		"ST-021":
			return "FOUL_POLE_CONTACT"
		"ST-064":
			return PANEL_ROLE
	return "DECORATIVE_AFTER_TERMINAL"


static func _bind(
	node: Node, root: Node3D, item: String, placement: Dictionary, inherited_role: String
) -> void:
	var role: String = str(node.get_meta("surface_role", inherited_role))
	if node.get_parent() == root.get_node("Visual"):
		var matching: Node = root.get_node_or_null("Collision/" + str(node.name))
		if matching != null:
			role = str(matching.get_meta("surface_role", role))
	node.set_meta("stadium_item", item)
	node.set_meta("paid_copy", placement.copy)
	node.set_meta("owned_copy", placement.copy)
	node.set_meta("site", placement.site)
	node.set_meta("boundary_owned", true)
	node.set_meta("surface_role", role)
	if placement.has("host"):
		node.set_meta("host_copy", placement.host)
		node.set_meta("host_span", placement.get("host_span", ""))
	if item == "ST-021":
		node.set_meta("wall_cap_height", float(placement.split))
	if node is StaticBody3D:
		node.set_meta("surface_id", str(node.name))
		node.set_meta("owned_surface_id", str(placement.copy) + ":" + str(node.name))
		node.set_meta("ball_surface", &"stadium_boundary_owned")
		(node as StaticBody3D).collision_layer = 1
		(node as StaticBody3D).collision_mask = 2
	if node is CollisionShape3D:
		node.name = "Shape"
		(node as CollisionShape3D).shape.margin = 0.0
	for child: Node in node.get_children():
		_bind(child, root, item, placement, role)


static func _root(item: String) -> Node3D:
	var root: Node3D = Node3D.new()
	root.set_meta("stadium_item", item)
	for branch: String in ["Visual", "Collision"]:
		var child: Node3D = Node3D.new()
		child.name = branch
		root.add_child(child)
	return root


static func _distance_panel(placement: Dictionary) -> Node3D:
	# Only an explicit full two-metre back-wall copy is an eligible mounting face.
	if (
		not placement.get("host") is String
		or str(placement.host).is_empty()
		or placement.get("host_span") != "full"
		or not _finite_number(placement.get("distance_m"))
		or float(placement.distance_m) <= 0
	):
		return null
	var root: Node3D = _root("ST-064")
	root.set_meta("distance_m", float(placement.distance_m))
	root.set_meta("distance_units", "metres")
	root.set_meta("mount_surface", "HOST-WALL-FIELD-FACE")
	for side: int in [-1, 1]:
		_box(
			root,
			"PanelMount%d" % side,
			Vector3(side * 0.50, 0, 0.01),
			Vector3(0.08, 0.40, 0.02),
			Color("627370"),
			PANEL_ROLE
		)
	_box(
		root,
		"DistancePanel",
		Vector3(0, 0, 0.04),
		Vector3(1.4, 0.55, 0.04),
		Color("294e48"),
		PANEL_ROLE
	)
	# Disjoint, shallow border bars stay inside the purchased panel envelope.
	for side: int in [-1, 1]:
		_art_box(
			root,
			"PanelBorderH%d" % side,
			Vector3(0, side * 0.255, 0.064),
			Vector3(1.36, 0.025, 0.008),
			Color("e6dfbc")
		)
		_art_box(
			root,
			"PanelBorderV%d" % side,
			Vector3(side * 0.67, 0, 0.064),
			Vector3(0.025, 0.485, 0.008),
			Color("e6dfbc")
		)
	var label: Label3D = Label3D.new()
	label.name = "DistanceMetres"
	label.text = "%.1f m" % float(placement.distance_m)
	label.position = Vector3(0, 0, 0.071)
	label.font_size = 56
	label.pixel_size = 0.0045
	label.modulate = Color("fff1cb")
	label.outline_size = 0
	label.no_depth_test = false
	label.double_sided = false
	root.get_node("Visual").add_child(label)
	return root


static func _fence(item: String, index: int) -> Node3D:
	var root: Node3D = _root(item)
	root.set_meta("rear_module_index", index)
	root.set_meta("rear_module_count", 8)
	root.set_meta("front_interval", Vector2(-1, 1))
	root.set_meta("fence_variant", "weathered_wood" if item == "ST-020" else "chain_link")
	var left: float = FENCE_MITER if index == 0 else 0.0
	var right: float = FENCE_MITER if index == 7 else 0.0
	var outline: PackedVector2Array = [
		Vector2(-1, 0),
		Vector2(1, 0),
		Vector2(1 + right, -FENCE_DEPTH),
		Vector2(-1 - left, -FENCE_DEPTH)
	]
	# One exact rear envelope keeps the existing dead-boundary semantics for both finishes.
	_prism_body(root, "RearFence", outline, 0, FENCE_HEIGHT, FENCE_ROLE)
	var post_color: Color = Color("725942") if item == "ST-020" else Color("718180")
	for side: int in [-1, 1]:
		var x0: float = -1.0 if side == -1 else 0.88
		var x1: float = -0.88 if side == -1 else 1.0
		var post: PackedVector2Array = [
			Vector2(x0, 0),
			Vector2(x1, 0),
			Vector2(x1 + (right if side == 1 else 0.0), -FENCE_DEPTH),
			Vector2(x0 - (left if side == -1 else 0.0), -FENCE_DEPTH)
		]
		_prism_art(root, "OwnedPost%d" % side, post, 0, FENCE_HEIGHT, post_color)
	if item == "ST-020":
		_wood_fence(root)
	else:
		_chain_fence(root)
	return root


static func _wood_fence(root: Node3D) -> void:
	var width: float = 1.76 / 8.0
	for board in range(8):
		_art_box(
			root,
			"WeatheredBoard%d" % board,
			Vector3(-0.88 + (board + 0.5) * width, 0.59, -0.04),
			Vector3(width - 0.006, 1.18, 0.08),
			Color("9a805f") if board % 3 == 0 else Color("8b7254")
		)
	for index in range(2):
		_art_box(
			root,
			"WoodRearRail%d" % index,
			Vector3(0, 0.22 + index * 0.75, -0.13),
			Vector3(1.76, 0.12, 0.10),
			Color("6d5840")
		)
	_art_box(
		root, "WoodTopCap", Vector3(0, 1.19, -0.07), Vector3(1.76, 0.02, 0.14), Color("a68c69")
	)


static func _chain_fence(root: Node3D) -> void:
	for index in range(2):
		_art_box(
			root,
			"ChainFrameRail%d" % index,
			Vector3(0, 0.035 + index * 1.13, -0.05),
			Vector3(1.76, 0.07, 0.10),
			Color("718180")
		)
	var transforms: Array[Transform3D] = []
	for slope: float in [-1.0, 1.0]:
		for index in range(-18, 19):
			var intercept: float = index * 0.12
			var low: float = maxf(
				-0.88, minf((0.07 - intercept) / slope, (1.13 - intercept) / slope)
			)
			var high: float = minf(
				0.88, maxf((0.07 - intercept) / slope, (1.13 - intercept) / slope)
			)
			if high <= low:
				continue
			var a: Vector3 = Vector3(low, slope * low + intercept, -0.055)
			var b: Vector3 = Vector3(high, slope * high + intercept, -0.055)
			var axis: Vector3 = a.direction_to(b)
			var basis: Basis = Basis(axis, Vector3(-axis.y, axis.x, 0), Vector3.BACK)
			transforms.append(
				Transform3D(
					basis.scaled_local(Vector3(a.distance_to(b), 0.008, 0.008)), (a + b) / 2
				)
			)
	StadiumWallPanelModels._batch(root.get_node("Visual"), transforms, "91a09b")
	root.get_node("Visual").get_child(root.get_node("Visual").get_child_count() - 1).name = \
		"ChainDiamondMesh"


static func _box(
	root: Node3D, id: String, point: Vector3, size: Vector3, color: Color, role: String
) -> void:
	StadiumStarterModels._box(root, id, point, size, color, role)


static func _art_box(root: Node3D, id: String, point: Vector3, size: Vector3, color: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	StadiumStarterModels._mesh(root, id, point, mesh, color)


static func _prism_body(
	root: Node3D, id: String, outline: PackedVector2Array, bottom: float, top: float, role: String
) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = id
	body.set_meta("surface_role", role)
	body.set_meta("footprint", outline)
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = _prism_points(outline, bottom, top)
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Shape"
	collider.shape = shape
	body.add_child(collider)
	root.get_node("Collision").add_child(body)


static func _prism_art(
	root: Node3D, id: String, outline: PackedVector2Array, bottom: float, top: float, color: Color
) -> void:
	var points: PackedVector3Array = _prism_points(outline, bottom, top)
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# A consistent outward winding preserves visible faces without two-sided materials.
	for triangle: Vector3i in [
		Vector3i(0, 1, 2),
		Vector3i(0, 2, 3),
		Vector3i(4, 6, 5),
		Vector3i(4, 7, 6),
		Vector3i(0, 4, 5),
		Vector3i(0, 5, 1),
		Vector3i(1, 5, 6),
		Vector3i(1, 6, 2),
		Vector3i(2, 6, 7),
		Vector3i(2, 7, 3),
		Vector3i(3, 7, 4),
		Vector3i(3, 4, 0)
	]:
		for index: int in [triangle.x, triangle.y, triangle.z]:
			tool.add_vertex(points[index])
	tool.generate_normals()
	StadiumStarterModels._mesh(root, id, Vector3.ZERO, tool.commit(), color)


static func _prism_points(
	outline: PackedVector2Array, bottom: float, top: float
) -> PackedVector3Array:
	var points: PackedVector3Array = []
	for y: float in [bottom, top]:
		for point: Vector2 in outline:
			points.append(Vector3(point.x, y, point.y))
	return points


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

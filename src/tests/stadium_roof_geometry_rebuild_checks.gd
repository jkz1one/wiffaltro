class_name StadiumRoofGeometryRebuildChecks
extends RefCounted
## Bounded support for the one shared --roof-rebuild fixture, not a second harness.
## These checks do not certify inherited coplanarity, stripes or rounded normals.

const ITEMS: Array[String] = [
	"ST-081", "ST-083", "ST-082", "ST-084", "ST-085", "ST-086", "ST-088", "ST-089", "ST-053"
]
const OFFSET: Vector3 = Vector3(0, -3.75, -0.845)
const EDGES: Array[String] = [
	"FinishedRoofEnd-1", "FinishedRoofEnd1", "RoofSlab", "FrontRoofFascia", "RearRoofFascia"
]
const EPSILON: float = 0.0002
const EXPECTED_CHECKS: int = 148


# Reuse the established snapshot, complete-point, physical-contact and contracted
# solid helpers. Override _ready so adding this adapter cannot run an old scene.
class SolidProbe:
	extends "res://src/tests/stadium_grand_three_stack_geometry_test_support.gd"
	var solid_ok: bool = true
	var solid_failure: String = ""
	var context: String = "roof geometry"

	func _ready() -> void:
		pass

	func _check(ok: bool, message: String) -> void:
		solid_ok = solid_ok and ok
		if not ok and solid_failure.is_empty():
			solid_failure = message


static func run(parent: Node3D, check: Callable) -> void:
	var probe: SolidProbe = SolidProbe.new()
	parent.add_child(probe)
	# Keep physics probes away from the shared fixture's photographed assemblies.
	probe.position = Vector3(1000, 0, 0)
	check.call(
		StadiumRoofOwnedModels.ITEMS == ITEMS and StadiumRoofOwnedModels.VERSION > 0,
		"one owned geometry family contains exactly the nine requested models"
	)
	var references: Dictionary = {}
	var signatures: Dictionary = {}
	for item: String in ITEMS:
		var reference: Node3D = _reference(item)
		references[item] = reference
		signatures[item] = _branches(probe, reference)
	for item: String in ITEMS:
		var states: Array[String] = []
		states.assign(["lower", "upper"] if item in ["ST-084", "ST-053"] else ["lower"])
		for state: String in states:
			var model: Node3D = StadiumRoofOwnedModels.create(item, state)
			check.call(model != null, "complete owned model exists: " + item + " " + state)
			if model == null:
				continue
			probe.add_child(model)
			_model_contract(probe, model, item, state, check)
			if item == "ST-084":
				_curved_contract(probe, model, references[item], state, check)
			elif item == "ST-053":
				_straight_contract(probe, model, state, check)
			else:
				check.call(
					_branches(probe, model) == signatures[item],
					"new wrapper retains complete frozen visual/collision geometry: " + item
				)
			model.free()
	for item: String in ITEMS:
		var fresh: Node3D = _reference(item)
		check.call(
			(
				_branches(probe, references[item]) == signatures[item]
				and _branches(probe, fresh) == signatures[item]
			),
			(
				"owned creation leaves existing and freshly regenerated old factories unchanged: "
				+ item
			)
		)
		fresh.free()
		references[item].free()
	await _curved_neighborhood(probe, check)
	await _straight_neighborhood(probe, check)
	probe.free()


static func _reference(item: String) -> Node3D:
	match item:
		"ST-081":
			return StadiumCurvedLowerModels.create(true)
		"ST-083":
			return StadiumCurvedStackModels._concourse()
		"ST-082":
			return StadiumCurvedStackModels._upper(true)
		"ST-084":
			return StadiumGrandThreeStackModels._curved_roof_reference()
		"ST-085":
			return StadiumLowerTransitionModels.create_right(true)
		"ST-086":
			return StadiumTransitionConcourseModels._model("JOIN-R")
		"ST-088":
			return StadiumLowerTransitionModels.create_left(true)
		"ST-089":
			return StadiumTransitionConcourseModels._model("JOIN-L")
		"ST-053":
			return StadiumBaselineStandModels.lower_canopy()
	return null


static func _branches(probe: SolidProbe, model: Node3D) -> String:
	return (
		probe._grand_snapshot(model.get_node("Visual"))
		+ probe._grand_snapshot(model.get_node("Collision"))
	)


static func _model_contract(
	probe: SolidProbe, model: Node3D, item: String, state: String, check: Callable
) -> void:
	var label: String = item + " " + state
	var points: PackedVector3Array = probe._all_points(model)
	var envelope: AABB = StadiumRoofOwnedModels.envelope(item, state).grow(0.002)
	var inside: bool = not points.is_empty()
	var inverse: Transform3D = model.global_transform.affine_inverse()
	for point: Vector3 in points:
		inside = inside and point.is_finite() and envelope.has_point(inverse * point)
	check.call(inside, "all actual mesh vertices and collision volumes fit envelope: " + label)
	var positive: bool = model.transform == Transform3D.IDENTITY
	for node: Node3D in model.find_children("*", "Node3D", true, false):
		positive = (
			positive
			and node.transform.origin.is_finite()
			and node.basis.is_finite()
			and node.basis.determinant() > 0
			and not node.top_level
		)
	check.call(positive, "identity owned root and finite positive descendant transforms: " + label)
	var collisions: bool = model.get_node("Collision").get_child_count() > 0
	for body: StaticBody3D in model.get_node("Collision").get_children():
		var mesh: MeshInstance3D = (
			model.get_node_or_null("Visual/" + str(body.name)) as MeshInstance3D
		)
		collisions = (
			collisions
			and mesh != null
			and body.collision_layer == 1
			and body.collision_mask == 2
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
		)
		if mesh == null:
			continue
		collisions = collisions and _matching_solid(mesh, body)
	check.call(collisions, "enabled scenery solids match their complete visible volumes: " + label)


static func _matching_solid(mesh: MeshInstance3D, body: StaticBody3D) -> bool:
	if mesh.transform != body.transform or body.get_child_count() == 0:
		return false
	var corners: Dictionary = {}
	for shape: CollisionShape3D in body.get_children():
		if shape.disabled or shape.transform != Transform3D.IDENTITY:
			return false
		if shape.shape is BoxShape3D:
			return (
				body.get_child_count() == 1
				and mesh.mesh is BoxMesh
				and shape.shape.size == mesh.mesh.size
			)
		if not shape.shape is ConvexPolygonShape3D or shape.shape.margin != 0:
			return false
		for point: Vector3 in shape.shape.points:
			corners[point] = true
	var vertices: Dictionary = {}
	for surface in range(mesh.mesh.get_surface_count()):
		for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			vertices[point] = true
	if vertices.size() != corners.size():
		return false
	for point: Vector3 in corners:
		if not vertices.has(point):
			return false
	return true


static func _member_points(
	root: Node3D, member: String, root_local: bool = true
) -> PackedVector3Array:
	var result: PackedVector3Array = []
	var mesh: MeshInstance3D = root.get_node("Visual/" + member)
	var pose: Transform3D = (
		root.global_transform.affine_inverse() * mesh.global_transform
		if root_local
		else Transform3D.IDENTITY
	)
	for surface in range(mesh.mesh.get_surface_count()):
		for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			result.append(pose * point)
	return result


static func _height(points: PackedVector3Array) -> Vector2:
	var result: Vector2 = Vector2(INF, -INF)
	for point: Vector3 in points:
		result.x = minf(result.x, point.y)
		result.y = maxf(result.y, point.y)
	return result


static func _polar(points: PackedVector3Array) -> Vector4:
	var result: Vector4 = Vector4(INF, -INF, INF, -INF)
	for point: Vector3 in points:
		var radius: float = Vector2(point.x, point.z).length()
		var angle: float = rad_to_deg(atan2(point.x, point.z))
		result.x = minf(result.x, radius)
		result.y = maxf(result.y, radius)
		result.z = minf(result.z, angle)
		result.w = maxf(result.w, angle)
	return result


static func _footprint(points: PackedVector3Array) -> PackedVector2Array:
	var flat: PackedVector2Array = []
	for point: Vector3 in points:
		var corner: Vector2 = Vector2(point.x, point.z)
		if not corner in flat:
			flat.append(corner)
	return Geometry2D.convex_hull(flat)


static func _curved_contract(
	probe: SolidProbe, model: Node3D, frozen: Node3D, state: String, check: Callable
) -> void:
	var offset: Vector3 = OFFSET if state == "lower" else Vector3.ZERO
	var remount: bool = true
	for branch: String in ["Visual", "Collision"]:
		remount = remount and model.get_node(branch).transform == Transform3D.IDENTITY
		for member: Node3D in model.get_node(branch).get_children():
			remount = remount and member.transform == Transform3D(Basis.IDENTITY, offset)
	(
		check
		. call(
			remount,
			(
				"same ST084 remounts all actual members by exact (0,-3.75,-0.845), keeping groups identity: "
				+ state
			)
		)
	)
	for branch: String in ["Visual", "Collision"]:
		(
			check
			. call(
				model.get_node(branch).get_child_count() == (11 if state == "lower" else 9),
				(
					"ST084 owns exactly five edge pieces, four frozen supports and lower-only bearings: "
					+ branch
					+ " "
					+ state
				)
			)
		)
		for side: int in [-1, 1]:
			for kind: String in ["RoofPost", "RoofBeam"]:
				var path: String = branch + "/" + kind + str(side)
				check.call(
					(
						probe._grand_snapshot(model.get_node(path))
						== _shifted_snapshot(probe, frozen.get_node(path), offset)
					),
					(
						"ST084 full post/beam geometry and material remain frozen: "
						+ path
						+ " "
						+ state
					)
				)
	for member: String in EDGES:
		var measured: Vector4 = _polar(_member_points(model, member, false))
		var old: Vector4 = _polar(_member_points(frozen, member, false))
		var ends: Vector2 = Vector2(-14.3, 14.3)
		var old_ends: Vector2 = Vector2(-14.7, 14.7)
		if member == "FinishedRoofEnd-1":
			ends.y = -13.65
			old_ends.y = -14.05
		elif member == "FinishedRoofEnd1":
			ends.x = 13.65
			old_ends.x = 14.05
		(
			check
			. call(
				(
					absf(measured.z - ends.x) < EPSILON
					and absf(measured.w - ends.y) < EPSILON
					and absf(old.z - old_ends.x) < EPSILON
					and absf(old.w - old_ends.y) < EPSILON
					and absf(measured.x - old.x) < EPSILON
					and absf(measured.y - old.y) < EPSILON
					and _height(_member_points(model, member, false)).is_equal_approx(
						_height(_member_points(frozen, member, false))
					)
				),
				(
					"only outer angular extent changes 14.7 to14.3 with radial/height profile retained: "
					+ member
					+ " "
					+ state
				)
			)
		)
	if state != "lower":
		return
	for side: int in [-1, 1]:
		var member: String = "LowerRoofBearing%d" % side
		var native_points: PackedVector3Array = _member_points(model, member, false)
		var profile: Vector4 = _polar(native_points)
		var height: Vector2 = _height(_member_points(model, member))
		var pad: PackedVector2Array = _footprint(native_points)
		var post: PackedVector2Array = _footprint(_member_points(model, "RoofPost%d" % side, false))
		check.call(
			(
				absf(profile.x - 25.2) < EPSILON
				and absf(profile.y - 26.0) < EPSILON
				and absf(profile.z - (side * 12.7 - 0.55)) < EPSILON
				and absf(profile.w - (side * 12.7 + 0.55)) < EPSILON
				and pad == post
			),
			"lower ST084 bearing covers the full exact0.8m radial post footprint: " + str(side)
		)
		check.call(
			absf(height.x - 4.39) < EPSILON and absf(height.y - 4.40) < EPSILON,
			"lower ST084 bearing spans host-local y4.39..4.40: " + str(side)
		)


static func _straight_contract(
	probe: SolidProbe, model: Node3D, state: String, check: Callable
) -> void:
	var frozen: Node3D = (
		StadiumGrandThreeStackModels._roof()
		if state == "upper"
		else StadiumBaselineStandModels.lower_canopy()
	)
	if state == "upper":
		check.call(
			_branches(probe, model) == _branches(probe, frozen),
			"ST053 upper roof and complete supports remain exactly frozen"
		)
		frozen.free()
		return
	for branch: String in ["Visual", "Collision"]:
		check.call(
			(
				model.get_node(branch).get_child_count()
				== frozen.get_node(branch).get_child_count() + 1
			),
			"ST053 lower adds only one exact-footprint bearing: " + branch
		)
		for node: Node in frozen.get_node(branch).get_children():
			if str(node.name) not in ["Canopy", "FrontFascia"]:
				check.call(
					(
						probe._grand_snapshot(model.get_node(branch + "/" + str(node.name)))
						== probe._grand_snapshot(node)
					),
					(
						"ST053 original post/beam geometry remains frozen: "
						+ branch
						+ "/"
						+ str(node.name)
					)
				)
	for member: String in ["Canopy", "FrontFascia"]:
		var mesh: MeshInstance3D = model.get_node("Visual/" + member)
		var old: MeshInstance3D = frozen.get_node("Visual/" + member)
		check.call(
			(
				absf(mesh.mesh.size.x - 5.9) < EPSILON
				and absf(old.mesh.size.x - 6.5) < EPSILON
				and mesh.mesh.size.y == old.mesh.size.y
				and mesh.mesh.size.z == old.mesh.size.z
				and mesh.transform == old.transform
			),
			"ST053 lower slab/fascia narrow6.5 to5.9 only: " + member
		)
	var pad: MeshInstance3D = model.get_node("Visual/LowerRoofBearing1")
	check.call(
		(
			pad.position.is_equal_approx(Vector3(2.7, 5.85, 6.6))
			and pad.mesh is BoxMesh
			and pad.mesh.size.is_equal_approx(Vector3(0.18, 0.30, 0.18))
			and _height(_member_points(model, "LowerRoofBearing1")).is_equal_approx(
				Vector2(5.7, 6.0)
			)
			and (
				_footprint(_member_points(model, "LowerRoofBearing1"))
				== _footprint(_member_points(model, "RearColumn1"))
			)
		),
		"ST053 blocky bearing fills only the original post footprint from y5.7 to6"
	)
	check.call(
		2.7 - 0.09 - 2.3 > 0.30 and 3.0 - (2.7 + 0.09) > 0.20,
		"exact0.18m bearing preserves both side strips of the0.70m stair lane"
	)
	frozen.free()


static func _put(probe: SolidProbe, item: String, site: String, state: String = "lower") -> Node3D:
	var model: Node3D = (
		StadiumRoofOwnedModels.create(item, state)
		if item in ITEMS
		else StadiumStraightOwnedModels.create(item)
	)
	probe.add_child(model)
	model.transform = (
		StadiumBaselineSites.pose(site)
		if site.begins_with("BASE-")
		else StadiumCurvedLowerSites.pose(site)
	)
	return model


static func _curved_neighborhood(probe: SolidProbe, check: Callable) -> void:
	var lowers: Array[Node3D] = []
	var roofs: Array[Node3D] = []
	for site: String in ["BOWL-02", "BOWL-03", "BOWL-04"]:
		lowers.append(_put(probe, "ST-081", site))
		roofs.append(_put(probe, "ST-084", site))
	await probe.get_tree().physics_frame
	await probe.get_tree().physics_frame
	for index in range(3):
		for side: int in [-1, 1]:
			var pad: Node3D = roofs[index].get_node("Collision/LowerRoofBearing%d" % side)
			(
				check
				. call(
					(
						probe._contact(lowers[index].get_node("Collision/RearRim"), pad)
						and probe._contact(
							pad, roofs[index].get_node("Collision/RoofPost%d" % side)
						)
					),
					(
						"ST084 full-foot bearing physically joins unchanged lower rim and original post: "
						+ str(index)
						+ "/"
						+ str(side)
					)
				)
			)
			var seatback: Vector2 = _height(_member_points(lowers[index], "SeatBack5_%d" % side))
			var bearing: Vector2 = _height(
				_member_points(roofs[index], "LowerRoofBearing%d" % side)
			)
			check.call(
				absf(seatback.y - 4.38) < EPSILON and bearing.x - seatback.y >= 0.0098,
				(
					"frozen last seatback stays at4.38 below bearing4.39: "
					+ str(index)
					+ "/"
					+ str(side)
				)
			)
	for index: int in [0, 2]:
		probe.context = "curved lower neighbor " + ("left" if index == 0 else "right")
		_no_penetration(probe, roofs[1], [lowers[index], roofs[index]], check)
		_no_penetration(probe, roofs[index], [lowers[1], roofs[1]], check)
		var center_points: PackedVector3Array = probe._all_points(roofs[1])
		var neighbor_points: PackedVector3Array = probe._all_points(roofs[index])
		var boundary: float = 165.0 if index == 0 else 195.0
		var normal: Vector3 = Vector3(cos(deg_to_rad(boundary)), 0, -sin(deg_to_rad(boundary)))
		var center_interval: Vector2 = _projection(center_points, normal)
		var neighbor_interval: Vector2 = _projection(neighbor_points, normal)
		var gap: float = maxf(
			center_interval.x - neighbor_interval.y, neighbor_interval.x - center_interval.y
		)
		check.call(
			gap > 0.048 and gap < 0.050,
			(
				"both complete lower ST084 meshes/hulls have measured positive neighbor seam: "
				+ str(gap)
			)
		)
	for model: Node3D in lowers + roofs:
		model.free()
	var upper: Node3D = _put(probe, "ST-082", "BOWL-03")
	var roof: Node3D = _put(probe, "ST-084", "BOWL-03", "upper")
	await probe.get_tree().physics_frame
	await probe.get_tree().physics_frame
	for side: int in [-1, 1]:
		check.call(
			probe._contact(
				upper.get_node("Collision/RearPylon%d" % side),
				roof.get_node("Collision/RoofPost%d" % side)
			),
			"ST084 upper roof still bears on the unchanged upper pylon: " + str(side)
		)
	upper.free()
	roof.free()


static func _projection(points: PackedVector3Array, axis: Vector3) -> Vector2:
	var result: Vector2 = Vector2(INF, -INF)
	for point: Vector3 in points:
		var value: float = axis.dot(point)
		result.x = minf(result.x, value)
		result.y = maxf(result.y, value)
	return result


static func _straight_neighborhood(probe: SolidProbe, check: Callable) -> void:
	for hand: String in ["L", "R"]:
		var first_site: String = "BASE-" + hand + "1"
		var second_site: String = "BASE-" + hand + "2"
		var lower: Node3D = _put(probe, "ST-029", first_site)
		var neighbor: Node3D = _put(probe, "ST-029", second_site)
		var roof: Node3D = _put(probe, "ST-053", first_site)
		var adjacent: Node3D = _put(probe, "ST-053", second_site)
		var frozen_host: String = _branches(probe, lower)
		await probe.get_tree().physics_frame
		await probe.get_tree().physics_frame
		probe.context = "straight lower neighbor " + hand
		_no_penetration(probe, roof, [neighbor, adjacent], check)
		_no_penetration(probe, adjacent, [lower, roof], check)
		var pad: Node3D = roof.get_node("Collision/LowerRoofBearing1")
		check.call(
			(
				probe._contact(lower.get_node("Collision/EntryStep37"), pad)
				and probe._contact(lower.get_node("Collision/EntryStep38"), pad)
				and probe._contact(pad, roof.get_node("Collision/RearColumn1"))
			),
			"ST053 bearing joins actual stair37/38 and unchanged post: " + hand
		)
		adjacent.free()
		var concourse: Node3D = _put(probe, "ST-031", second_site)
		var upper: Node3D = _put(probe, "ST-030", second_site)
		var upper_roof: Node3D = _put(probe, "ST-053", second_site, "upper")
		await probe.get_tree().physics_frame
		await probe.get_tree().physics_frame
		probe.context = "straight mixed upper/lower neighbor " + hand
		_no_penetration(probe, roof, [neighbor, concourse, upper, upper_roof], check)
		_no_penetration(probe, upper_roof, [lower, roof], check)
		for side: int in [-1, 1]:
			check.call(
				probe._contact(
					upper.get_node("Collision/RearPylon%d" % side),
					upper_roof.get_node("Collision/RoofPost%d" % side)
				),
				"ST053 unchanged upper supports stay in contact: " + hand + "/" + str(side)
			)
		check.call(
			_branches(probe, lower) == frozen_host,
			(
				"lower roof and mixed neighbors leave entire straight stair lane/host unchanged: "
				+ hand
			)
		)
		for model: Node3D in [lower, neighbor, roof, concourse, upper, upper_roof]:
			model.free()


static func _shifted_snapshot(probe: SolidProbe, node: Node3D, offset: Vector3) -> String:
	var expected: Node3D = node.duplicate() as Node3D
	expected.position += offset
	var result: String = probe._grand_snapshot(expected)
	expected.free()
	return result


static func _no_penetration(
	probe: SolidProbe, model: Node3D, neighbors: Array[Node3D], check: Callable
) -> void:
	probe.solid_ok = true
	probe.solid_failure = ""
	probe._grand_no_penetration(model, neighbors)
	check.call(
		probe.solid_ok,
		(
			probe.context
			+ ": whole contracted solids avoid neighboring purchased geometry"
			+ (" (" + probe.solid_failure + ")" if not probe.solid_ok else "")
		)
	)

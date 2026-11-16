class_name StadiumPlayerTunnelGeometryChecks
extends RefCounted
## Finite source-geometry checks for the single shared rendered fixture; no engine runner.
## Native installed passage/support/ball/camera checks remain in the combined fixture.

const M = preload("res://src/presentation/stadium/stadium_player_tunnel_models.gd")
const A = preload("res://src/presentation/stadium/stadium_player_tunnel_host_adapters.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EXPECTED_CHECKS: int = 71
const EPS: float = 0.0002
const FOREIGN: Array[String] = ["ST-074", "ST-029", "ST-032", "ST-087", ""]
const FROZEN: Dictionary = {
	"res://src/presentation/stadium/stadium_concrete_dugout_models.gd":
	"ac4ab6504e2c24b08e2693d1b0f821dcac2849b98b5a5be836eace0044c8ed21",
	"res://src/presentation/stadium/stadium_baseline_stand_models.gd":
	"75e3700469a43ac53c6e3778a8de614893d7b154e66d5c5295bca341fd4ac13a",
	"res://src/presentation/stadium/stadium_straight_owned_models.gd":
	"8ba317f7a48234c605131023f3cb4cc0d0dc96936be6265adcac42bc04d54a2b",
	"res://src/gameplay/stadium/stadium_dugout_recipe.gd":
	"9426ec13fc1ab673cafd856c0611dbd6aa6f90056d0315197cfb6313f6cc38a4",
	"res://src/gameplay/stadium/stadium_baseline_sites.gd":
	"e59935264c2da05b2e009048a089284006826094715e28f656c3f2b48450efff"
}


static func expected_checks() -> int:
	return EXPECTED_CHECKS


static func run(parent: Node3D, check: Callable) -> Dictionary:
	var report: Dictionary = {"checks": EXPECTED_CHECKS, "hands": [], "physics_queries": false}
	_emit(
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-058"
			and A.VERSION == 1
			and M.ENVELOPE == AABB(Vector3(-1, 0, 0), Vector3(2, 2.7, 4.6))
		),
		"one complete symmetric CI4 shell uses the settled reservation"
	)
	for item: String in FOREIGN:
		var foreign: Node3D = M.create(item)
		_emit(
			check,
			foreign == null and M.envelope(item) == AABB(),
			"foreign item cannot substitute for the covered tunnel"
		)
		if foreign != null:
			foreign.free()
	for path: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256(path) == FROZEN[path],
			"frozen capped host factory and original socket frame remain byte-exact"
		)
	for left: bool in [true, false]:
		report.hands.append(_hand(parent, check, left))
	return report


static func _hand(parent: Node3D, check: Callable, left: bool) -> Dictionary:
	var suffix: String = "L" if left else "R"
	var row: Dictionary = {
		"copy": "geometry:tunnel:" + suffix,
		"site": "TUNNEL-" + suffix,
		"dugout": "geometry:dugout:" + suffix,
		"lower": "geometry:lower:" + suffix,
		"left": left
	}
	var model: Node3D = M.create("ST-058", row)
	_emit(check, model != null, "exact owned tunnel creates for the selected rigid hand")
	if model == null:
		for index in range(29):
			_emit(check, false, "dependent tunnel geometry check cannot run without its model")
		return {"left": left, "error": "model creation"}
	var probe: Node3D = Node3D.new()
	probe.name = "TunnelGeometry" + suffix
	parent.add_child(probe)
	probe.add_child(model)
	_emit(
		check,
		(
			model.get_child_count() == 2
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"shell has two complete identity branches"
	)
	_emit(
		check,
		(
			_roles(model)
			and not model.get_meta("walkout_simulation")
			and not model.get_meta("new_live_passage")
		),
		"all shell solids stay decorative with no player or ball route"
	)
	var scan: Dictionary = SCAN._scan(model)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		str(scan.failure).is_empty() and scan.meshes == 7 and A._same(actual, M.ENVELOPE),
		"all seven visible members fit the exact full reservation",
		{"scan": scan, "actual": str(actual)}
	)
	_emit(
		check,
		_physical_match(model) and SOLIDS._indexed(model),
		"each visible indexed member has its matching enabled zero-margin physical solid"
	)
	_emit(
		check, _roof_support(model), "included roof bears on grounded side rear and entry members"
	)
	var active: String = M.PORT_CAPS[1 if left else 0]
	var closed: String = M.PORT_CAPS[0 if left else 1]
	_emit(
		check,
		(
			not model.has_node("Visual/" + active)
			and not model.has_node("Collision/" + active)
			and model.has_node("Visual/" + closed)
			and model.has_node("Collision/" + closed)
		),
		"only the active host-side cap opens"
	)
	var pose: Transform3D = StadiumPlayerTunnelItems.placement(left)
	_emit(
		check,
		(
			absf(pose.basis.determinant() - 1) < EPS
			and pose.basis.get_scale().is_equal_approx(Vector3.ONE)
			and StadiumProperty.contains("club", pose * M.ENVELOPE)
			and StadiumProperty.contains("mogul", pose * M.ENVELOPE)
		),
		"both placements are proper rigid transforms within Club and Mogul"
	)
	var sealed: Node3D = M.create()
	_emit(
		check,
		sealed.get_node("Collision").get_child_count() == 8 and _symmetric_source(sealed),
		"one symmetric source contains matching capped lateral interfaces"
	)
	_emit(
		check,
		_open_plane(model, 1 if left else -1),
		"actual active interface plane is clear over d5..7 and y0..2.4"
	)
	_emit(
		check,
		_segments_clear(
			model,
			PackedVector3Array(
				[
					Vector3(0, 1.2, 0.01),
					Vector3(0, 1.2, 3.6),
					Vector3(1.35 if left else -1.35, 1.2, 3.6)
				]
			)
		),
		"actual shell has a clear internal turn into its lateral port"
	)
	var fresh: Node3D = M.create("ST-058", row)
	_emit(
		check,
		POINTS._independent(model, fresh) and _signature(model) == _signature(fresh),
		"separate paid copies have independent deterministic native geometry"
	)
	fresh.free()
	sealed.free()
	var dugout: Node3D = _dugout(row)
	var stand: Node3D = _stand(row)
	var capped_dugout: String = _signature(dugout)
	var capped_stand: String = _signature(stand)
	var front: Dictionary = _capture_members(
		dugout,
		[
			"FrontBarrier-1",
			"FrontBarrier1",
			"RoofSupport-1",
			"RoofSupport1",
			"EndWall-1",
			"EndWall1"
		]
	)
	var roof: Dictionary = _capture_members(dugout, ["Roof"])
	var original_stand: Node3D = _stand(row)
	var dugout_ok: bool = A.apply_dugout(dugout, row)
	var stand_ok: bool = A.apply_stand(stand, row)
	_emit(check, dugout_ok, "exact paid ST074 receives its compatible rear port and bench approach")
	_emit(check, stand_ok, "exact BASE1 paid ST029 receives its supported end interface")
	var bad: Node3D = _stand(row)
	bad.set_meta("owned_copy", "different-owned-copy")
	_emit(
		check,
		not A.apply_stand(bad, row) and not bad.has_meta("player_tunnel_copy"),
		"a different owned host copy cannot be locally opened"
	)
	bad.free()
	var dx: float = -2 if left else 2
	_emit(
		check,
		_clear_box(dugout, AABB(Vector3(dx - 0.749, 0.001, 1.65), Vector3(1.498, 2.398, 1))),
		"full rear port column including the real bench approach is clear"
	)
	_emit(
		check,
		_capture_members(dugout, front.keys()) == front,
		"both live front barriers supports side enclosure and front aperture remain unchanged"
	)
	_emit(
		check,
		_capture_members(dugout, roof.keys()) == roof,
		"original live-terminal roof stays byte-exact"
	)
	_emit(
		check,
		_bench_supported(dugout, left),
		"retained bench is shortened only at the port and has a grounded end support"
	)
	var recess: AABB = AABB(
		Vector3(-2.999 if left else 2.301, 0.001, 1.501), Vector3(0.698, 2.398, 1.998)
	)
	_emit(
		check,
		_clear_box(stand, recess),
		"actual stand recess is 0.70 metres deep below the full 2.40 metre aperture"
	)
	_emit(
		check,
		_stairs_preserved(stand, original_stand, left),
		"all forty tread heights rises widths and landing positions survive the compatible hand"
	)
	_emit(
		check,
		_aisles_preserved(stand, original_stand, left),
		"true member reflection keeps stair landing and adjacent row aisle connected at original widths"
	)
	_emit(
		check,
		_seats_preserved(stand, original_stand, left),
		"all fifty seats and audience anchors retain source heights and spacing"
	)
	_emit(
		check,
		_crest_supported(stand),
		"unchanged crest socket remains backed by actual solid host surfaces"
	)
	_emit(
		check,
		(
			StadiumDugoutRecipe.ENVELOPE.grow(EPS).encloses(SCAN._bounds(POINTS._points(dugout)))
			and StadiumBaselineSites.LOWER_BOUNDS.grow(EPS).encloses(
				SCAN._bounds(POINTS._points(stand))
			)
		),
		"both complete adapted hosts remain inside their original reserved bounds"
	)
	_emit(
		check,
		_positive_static(model) and _positive_static(dugout) and _positive_static(stand),
		"every model and child uses finite positive unit scale without negative-scale mirroring"
	)
	_emit(
		check,
		_only_port_changes(stand, original_stand, left),
		"only three solid rows are port-cut after the approved whole circulation reflection"
	)
	_emit(
		check,
		_conserved(dugout) and _conserved(stand),
		"every removed host prism is exactly partitioned into its documented retained solids"
	)
	var restored_dugout: Node3D = _dugout(row)
	var restored_stand: Node3D = _stand(row)
	_emit(
		check,
		(
			_signature(restored_dugout) == capped_dugout
			and _signature(restored_stand) == capped_stand
			and not restored_dugout.has_meta("player_tunnel_copy")
			and not restored_stand.has_meta("player_tunnel_copy")
		),
		"Store reconstruction restores exact original caps bench rows and staircase"
	)
	_emit(
		check,
		(
			_roles(stand)
			and _roles(model)
			and stand.get_meta("represented_seats", 0) == 50
			and model.get_meta("obstacle_units") == 0
		),
		"host presentation adaptation adds no paid pieces seats gameplay bonus or live tunnel path"
	)
	var note: Dictionary = {
		"hand": suffix,
		"shell": str(actual),
		"active_local_x": 1 if left else -1,
		"rear_port_width": 1.5,
		"headroom": 2.4,
		"stand_recess_depth": 0.7,
		"stair_count": 40,
		"seats": 50,
		"stair_end": "+X" if left else "-X",
		"dugout_changes": str(dugout.get_meta("player_tunnel_host_changes", [])),
		"stand_changes": str(stand.get_meta("player_tunnel_host_changes", []))
	}
	print("PLAYER_TUNNEL_GEOMETRY_MEASUREMENT " + JSON.stringify(note, "", true, true))
	for node: Node3D in [dugout, stand, original_stand, restored_dugout, restored_stand]:
		node.free()
	probe.free()
	return note


static func _dugout(row: Dictionary) -> Node3D:
	return StadiumBoundaryOwnedModels.create(
		"ST-074", {"copy": row.dugout, "site": "DUGOUT-L" if row.left else "DUGOUT-R"}
	)


static func _stand(row: Dictionary) -> Node3D:
	var root: Node3D = StadiumStraightOwnedModels.create("ST-029")
	root.set_meta("owned_copy", row.lower)
	root.set_meta("site", "BASE-L1" if row.left else "BASE-R1")
	return root


static func _signature(root: Node3D) -> String:
	# Cross-instance geometry comparison only. Godot-generated anonymous shape names
	# are normalized; authored member identities, poses, shape type/data and roles are not.
	var physical: Array = []
	for body: StaticBody3D in root.find_children("*", "StaticBody3D", true, false):
		physical.append(
			[
				str(body.name),
				POINTS._local_pose(root, body),
				body.collision_layer,
				body.collision_mask,
				body.constant_linear_velocity,
				body.constant_angular_velocity,
				body.get_meta("surface_id"),
				body.get_meta("surface_role")
			]
		)
		for index in range(body.get_child_count()):
			var shape: CollisionShape3D = body.get_child(index)
			var name_value: String = str(shape.name)
			if name_value.begins_with("@CollisionShape3D@") or name_value == "CollisionShape3D":
				name_value = "CollisionShape3D#" + str(index)
			var data: Variant = (
				shape.shape.size if shape.shape is BoxShape3D else shape.shape.points
			)
			physical.append(
				[
					name_value,
					shape.transform,
					shape.disabled,
					shape.shape.margin,
					shape.shape.get_class(),
					data
				]
			)
	return POINTS._visual_signature(root) + var_to_bytes(physical).hex_encode().sha256_text()


static func _member(root: Node3D, id: String) -> AABB:
	var mesh: MeshInstance3D = root.get_node("Visual/" + id)
	return mesh.transform * mesh.mesh.get_aabb()


static func _body_box(body: StaticBody3D) -> AABB:
	var collider: CollisionShape3D = body.get_child(0)
	if collider.shape is BoxShape3D:
		return (
			body.transform
			* collider.transform
			* AABB(-collider.shape.size / 2, collider.shape.size)
		)
	return body.transform * collider.transform * SCAN._bounds(collider.shape.points)


static func _clear_box(root: Node3D, box: AABB) -> bool:
	for body: StaticBody3D in root.get_node("Collision").get_children():
		if _body_box(body).intersection(box).has_volume():
			return false
	return true


static func _segments_clear(root: Node3D, path: PackedVector3Array) -> bool:
	for index in range(path.size() - 1):
		for body: StaticBody3D in root.get_node("Collision").get_children():
			if _body_box(body).intersects_segment(path[index], path[index + 1]):
				return false
	return true


static func _physical_match(root: Node3D) -> bool:
	if root.get_node("Visual").get_child_count() != root.get_node("Collision").get_child_count():
		return false
	for body: StaticBody3D in root.get_node("Collision").get_children():
		if (
			body.get_child_count() != 1
			or body.get_child(0).disabled
			or body.get_child(0).shape.margin != 0
			or not A._same(_body_box(body), _member(root, str(body.name)))
		):
			return false
	return true


static func _roles(root: Node3D) -> bool:
	for body: StaticBody3D in root.get_node("Collision").get_children():
		if (
			body.get_meta("surface_role", "") != M.ROLE
			or body.collision_layer != 1
			or body.collision_mask != 2
		):
			return false
	return true


static func _roof_support(root: Node3D) -> bool:
	for id: String in ["SideWall-1", "SideWall1", "EntryJamb-1", "EntryJamb1", "RearWall"]:
		var box: AABB = _member(root, id)
		if absf(box.position.y) > EPS or absf(box.end.y - 2.4) > EPS:
			return false
	return A._same(_member(root, "Roof"), AABB(Vector3(-1, 2.4, 0), Vector3(2, 0.3, 4.6)))


static func _symmetric_source(root: Node3D) -> bool:
	for pair: Array in [["SideWall-1", "SideWall1"], ["EntryJamb-1", "EntryJamb1"], M.PORT_CAPS]:
		var a: AABB = _member(root, pair[0])
		var b: AABB = _member(root, pair[1])
		if not A._same(AABB(Vector3(-a.end.x, a.position.y, a.position.z), a.size), b):
			return false
	return true


static func _open_plane(root: Node3D, side: int) -> bool:
	for body: StaticBody3D in root.get_node("Collision").get_children():
		var collider: CollisionShape3D = body.get_child(0)
		var box: AABB = _body_box(body)
		if box.position.y >= 2.4 - EPS or box.end.z <= 2.6 + EPS:
			continue
		if collider.shape is ConvexPolygonShape3D:
			# Only the two bevel endpoints reach this outer plane, both at z=4.6.
			for point: Vector3 in collider.shape.points:
				if absf(point.x - side) < EPS and point.z < 4.6 - EPS:
					return false
		elif (side < 0 and box.position.x <= -1 + EPS) or (side > 0 and box.end.x >= 1 - EPS):
			return false
	return true


static func _capture_members(root: Node3D, ids: Array) -> Dictionary:
	var result: Dictionary = {}
	for id: String in ids:
		var mesh: MeshInstance3D = root.get_node("Visual/" + id)
		var body: StaticBody3D = root.get_node("Collision/" + id)
		result[id] = [
			mesh.transform,
			mesh.mesh.surface_get_arrays(0),
			mesh.material_override.albedo_color,
			body.transform,
			body.get_child(0).shape.size,
			body.get_meta("surface_role")
		]
	return result


static func _bench_supported(root: Node3D, left: bool) -> bool:
	var seat: AABB = _member(root, "BenchSeat")
	var leg: AABB = _member(root, "TunnelBenchEndSupport")
	return (
		A._same(seat, AABB(Vector3(-1.25 if left else -2.75, 0.45, 1.83), Vector3(4, 0.08, 0.44)))
		and absf(leg.position.y) < EPS
		and absf(leg.end.y - seat.position.y) < EPS
		and seat.position.x <= leg.position.x
		and seat.end.x >= leg.end.x
	)


static func _reflected(point: Vector3, left: bool) -> Vector3:
	return point if left else Vector3(-point.x, point.y, point.z)


static func _stairs_preserved(root: Node3D, source: Node3D, left: bool) -> bool:
	for index in range(40):
		var id: String = "EntryStep%d" % index
		var box: AABB = _member(root, id)
		var original: AABB = _member(source, id)
		if (
			not box.get_center().is_equal_approx(_reflected(original.get_center(), left))
			or not box.size.is_equal_approx(original.size)
			or absf(box.end.y - (index + 1) * 0.15) > EPS
		):
			return false
	return (
		absf(_member(root, "EntryStep39").end.y - _member(root, "SolidRow9").end.y) < EPS
		and absf(_member(root, "EntryStep39").end.z - 7) < EPS
	)


static func _aisles_preserved(root: Node3D, source: Node3D, left: bool) -> bool:
	for index in range(10):
		for stem: String in ["AislePost"] if index == 0 else ["AislePost", "AisleRail"]:
			var id: String = stem + str(index)
			var a: Node3D = root.get_node("Visual/" + id)
			var b: Node3D = source.get_node("Visual/" + id)
			if not a.position.is_equal_approx(_reflected(b.position, left)) or a.basis != b.basis:
				return false
	var stair: AABB = _member(root, "EntryStep39")
	var rear: AABB = _member(root, "SolidRow9")
	return (
		(
			absf(
				(
					(rear.end.x if left else rear.position.x)
					- (stair.position.x if left else stair.end.x)
				)
			)
			< EPS
		)
		and absf(rear.end.y - stair.end.y) < EPS
	)


static func _seats_preserved(root: Node3D, source: Node3D, left: bool) -> bool:
	for index in range(50):
		for stem: String in ["Seat", "SeatBase", "Back", "CrowdAnchor"]:
			var id: String = stem + str(index)
			var a: Node3D = root.get_node("Visual/" + id)
			var b: Node3D = source.get_node("Visual/" + id)
			if not a.position.is_equal_approx(_reflected(b.position, left)) or a.basis != b.basis:
				return false
	return root.find_children("CrowdAnchor*", "Node3D", true, false).size() == 50


static func _crest_supported(root: Node3D) -> bool:
	var supports: Array = root.get_meta("tunnel_crest_supports", [])
	var expected: Array = (
		["EntryStep20", "EntryStep21", "EntryStep22", "EntryStep23"]
		if root.get_meta("tunnel_stair_relocated", false)
		else ["SolidRow5"]
	)
	if (
		supports != expected
		or (
			root.get_meta("tunnel_crest_pose_preserved")
			!= StadiumStraightOwnedModels.socket("ST-029", "crest").transform
		)
	):
		return false
	var bounds: AABB = StadiumStraightOwnedModels.socket("ST-029", "crest").envelope
	for z: float in [bounds.position.z + 0.001, bounds.get_center().z, bounds.end.z - 0.001]:
		for y: float in [bounds.position.y + 0.001, bounds.end.y - 0.001]:
			var supported: bool = false
			for id: String in supports:
				var body: StaticBody3D = root.get_node_or_null("Collision/" + id)
				if body != null and _body_box(body).grow(EPS).has_point(Vector3(-2.999, y, z)):
					supported = true
			if not supported:
				return false
	return true


static func _positive_static(root: Node3D) -> bool:
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node is Node3D
			and (
				not node.position.is_finite()
				or not node.scale.is_equal_approx(Vector3.ONE)
				or absf(node.basis.determinant() - 1) > EPS
			)
		):
			return false
	return true


static func _only_port_changes(root: Node3D, source: Node3D, left: bool) -> bool:
	for member: Node3D in source.get_node("Visual").get_children():
		if str(member.name) in ["SolidRow2", "SolidRow3", "SolidRow4"]:
			continue
		var actual: Node3D = root.get_node("Visual/" + str(member.name))
		if (
			not actual.position.is_equal_approx(_reflected(member.position, left))
			or actual.basis != member.basis
		):
			return false
	return root.get_meta("player_tunnel_host_changes").size() == 3


static func _conserved(root: Node3D) -> bool:
	for change: Dictionary in root.get_meta("player_tunnel_host_changes"):
		var volume: float = change.removed.get_volume()
		for retained: AABB in change.retained:
			volume += retained.get_volume()
			if not _native_width_disjoint(retained, change.removed):
				var ab: Vector3 = change.removed.position - retained.position
				var ba: Vector3 = retained.position - change.removed.position
				print(
					(
						"PLAYER_TUNNEL_PARTITION_DIAGNOSTIC "
						+ JSON.stringify(
							{
								"member": change.member,
								"retained_size":
								[retained.size.x, retained.size.y, retained.size.z],
								"removed_size":
								[
									change.removed.size.x,
									change.removed.size.y,
									change.removed.size.z
								],
								"native_ab": [ab.x, ab.y, ab.z],
								"native_ba": [ba.x, ba.y, ba.z]
							},
							"",
							true,
							true
						)
					)
				)
				return false
		if absf(volume - change.original.get_volume()) > EPS:
			print(
				(
					"PLAYER_TUNNEL_PARTITION_DIAGNOSTIC "
					+ JSON.stringify(
						{
							"member": change.member,
							"retained_plus_removed_volume": volume,
							"original_volume": change.original.get_volume(),
							"unchanged_volume_epsilon": EPS
						},
						"",
						true,
						true
					)
				)
			)
			return false
	return true


static func _native_width_disjoint(a: AABB, b: AABB) -> bool:
	# Preserve the native Vector3 width domain used to author each retained prism.
	# Re-adding a rounded width to its origin can cross a shared plane by one ULP.
	# No epsilon is used: a width one native ULP beyond this exact difference fails.
	var ab: Vector3 = b.position - a.position
	var ba: Vector3 = a.position - b.position
	for axis in range(3):
		if a.size[axis] <= ab[axis] or b.size[axis] <= ba[axis]:
			return true
	return false


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"PLAYER_TUNNEL_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)

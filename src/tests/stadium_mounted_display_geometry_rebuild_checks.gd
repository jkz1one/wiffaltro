class_name StadiumMountedDisplayGeometryRebuildChecks
extends RefCounted
## Finite native geometry support for the shared rebuild fixture; never a separate runner.
## 1 contract + 7 foreign + 16 frozen + 3*(1 create+15 common+3 anatomy)
## + 8 clock poses + 8*7 socket + 10 bad socket + 3 support-clearance = 158 checks.

const M = preload("res://src/presentation/stadium/stadium_mounted_display_models.gd")
const SCAN = preload("res://src/tests/stadium_landscape_geometry_rebuild_checks.gd")
const POINTS = preload("res://src/tests/stadium_live_furnishing_geometry_rebuild_checks.gd")
const SOLIDS = preload("res://src/tests/stadium_ground_box_geometry_rebuild_checks.gd")
const EPS: float = 0.0002
const EXPECTED_CHECKS: int = 158
const FOREIGN: Array[String] = ["ST-030", "ST-031", "ST-035", "ST-039", "ST-040", "ST-047", ""]
const FROZEN: Dictionary = {
	"stadium_landmark_models.gd":
	"3e8e16c6a858fd89240faca6dbedd14e9b0ddcacdf503d445fbfa62b42e28f84",
	"stadium_straight_owned_models.gd":
	"8ba317f7a48234c605131023f3cb4cc0d0dc96936be6265adcac42bc04d54a2b",
	"stadium_straight_stack_models.gd":
	"205a6fac539b4de8b51e59b088274d6e6794e0f2725a23d22b1c0a681b5720ad",
	"stadium_baseline_stand_models.gd":
	"75e3700469a43ac53c6e3778a8de614893d7b154e66d5c5295bca341fd4ac13a",
	"stadium_club_models.gd": "c05a9a6c77791a12cbc9b5191240e3f96e94adec6aa239db5ce6e3f974eaa61f",
	"stadium_scoreboard_tiers.gd":
	"b8ffe92afcf58cd0ec684d42006f5a86ab4fddd7683d80480ca276c4323bb921",
	"stadium_ground_props_models.gd":
	"126baf347c349c39d62505a88651af9ccc4fc06beada0e5aedf6c3d9361ec6c4",
	"stadium_starter_models.gd": "c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
}


static func expected_checks() -> int:
	return (
		1
		+ FOREIGN.size()
		+ 2 * FROZEN.size()
		+ M.ITEMS.size() * 19
		+ 8
		+ M.SOCKETS.size() * 7
		+ 10
		+ 3
	)


static func run(parent: Node3D, check: Callable) -> Dictionary:
	var probe: Node3D = Node3D.new()
	probe.name = "MountedDisplayGeometryProbe"
	probe.position = Vector3(2700, 0, 0)
	parent.add_child(probe)
	var report: Dictionary = {
		"version": 1,
		"item_rows": [],
		"socket_rows": [],
		"source_hashes": FROZEN.duplicate(),
		"unsupported_production_sockets": ["PA-MANUAL-V2-RIGHT", "PA-VIDEO-RIGHT"],
		"support_clearance": {}
	}
	_emit(
		check,
		(
			M.ITEMS == ["ST-068", "ST-069", "ST-070"]
			and M.SOCKETS.size() == 8
			and expected_checks() == EXPECTED_CHECKS
		),
		"three complete models declare eight finite source sockets and an exact native check budget"
	)
	for item: String in FOREIGN:
		var rejected: Node3D = M.create(item)
		_emit(
			check,
			(
				rejected == null
				and M.envelope(item) == AABB()
				and M.visible_bounds(item) == AABB()
				and M.mesh_count(item) == 0
				and M.solid_count(item) == 0
				and M.support_points(item).is_empty()
			),
			"foreign inventory never creates a display or borrows its reservation",
			{"item": item}
		)
		if rejected != null:
			rejected.free()
	_frozen(check)
	for item: String in M.ITEMS:
		var model: Node3D = M.create(item)
		_emit(
			check,
			model != null,
			"complete ribbon clock or silent PA factory creates",
			{"item": item}
		)
		if model != null:
			probe.add_child(model)
			report.item_rows.append(await _common(probe, model, item, check))
			await _anatomy(model, item, check)
			if item == "ST-069":
				_clock_poses(model, check)
			model.free()
	for spec: Dictionary in M.SOCKETS:
		report.socket_rows.append(await _socket_check(probe, spec, check))
	for row: Array in [
		["ST-029", "ST-068", ""],
		["ST-032", "ST-068", ""],
		["ST-034", "ST-068", ""],
		["ST-040", "ST-068", "video-v2"],
		["ST-039", "ST-070", "invented"],
		["ST-040", "ST-070", ""],
		["ST-090", "ST-070", "electronic-v2"],
		["ST-035", "ST-069", "invented"],
		["ST-031", "ST-069", ""],
		["ST-040", "ST-069", "video-v2"]
	]:
		_emit(
			check,
			M.socket(row[0], row[1], row[2]).is_empty(),
			"unnamed surfaces curved stands clocks and foreign variants fail closed",
			{"row": row}
		)
	report.support_clearance = _stack_clearance(probe, check)
	_frozen(check)
	probe.free()
	# The complete report is returned for the fixture JSON; stdout keeps bounded counts only.
	var summary: Dictionary = {
		"models": report.item_rows.size(),
		"meshes": 0,
		"solids": 0,
		"sockets": report.socket_rows.size(),
		"triangle_contacts": 0,
		"native_contacts": 0,
		"overlaps": 0
	}
	for row: Dictionary in report.item_rows:
		summary.meshes += int(row.meshes)
		summary.solids += int(row.solids)
	for row: Dictionary in report.socket_rows:
		var support: Dictionary = row.get("support", {})
		var clearance: Dictionary = row.get("clearance", {})
		summary.triangle_contacts += int(support.get("triangle_contacts", 0))
		summary.native_contacts += int(support.get("native_contacts", 0))
		summary.overlaps += clearance.get("overlaps", []).size()
	print("MOUNTED_DISPLAY_GEOMETRY_SUMMARY " + JSON.stringify(summary, "", true, true))
	return report


static func _emit(check: Callable, ok: bool, message: String, operands: Dictionary = {}) -> void:
	if not ok:
		print(
			(
				"MOUNTED_DISPLAY_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)


static func _frozen(check: Callable) -> void:
	for filename: String in FROZEN:
		_emit(
			check,
			FileAccess.get_sha256("res://src/presentation/stadium/" + filename) == FROZEN[filename],
			"every measured source host and reused complete-solid primitive remains byte exact",
			{"file": filename}
		)


static func _common(probe: Node3D, model: Node3D, item: String, check: Callable) -> Dictionary:
	_emit(
		check,
		(
			model.get_child_count() == (4 if item == "ST-069" else 2)
			and model.transform == Transform3D.IDENTITY
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"complete mounted assembly has only fixed branches and the two approved visual clock pivots"
	)
	_emit(
		check,
		(
			model.get_meta("stadium_item") == item
			and model.get_meta("geometry_version") == 1
			and model.get_meta("model_version") == 1
			and not model.get_meta("final_art_accepted")
			and model.get_meta("scenery_only")
			and model.get_meta("obstacle_units") == 0
			and not model.get_meta("gameplay_benefit")
			and not model.get_meta("night_benefit")
			and not model.get_meta("audio_implemented")
			and not model.get_meta("machine_time")
			and model.get_meta("runtime_clock") == (item == "ST-069")
			and model.get_meta("fixed_collision")
		),
		"working complete geometry claims no final art audio gameplay or Night benefit"
	)
	_emit(
		check,
		_static_nodes(model),
		(
			"every actual node is script-free finite visible and unscaled with only authored "
			+ "clock-hand pose exceptions"
		)
	)
	var scan: Dictionary = SCAN._scan(model)
	_emit(
		check,
		(
			str(scan.failure).is_empty()
			and scan.types == ["ArrayMesh"]
			and scan.meshes == M.mesh_count(item)
			and int(scan.vertices) > 600
		),
		"all complete indexed native meshes have finite vertices normals and exact source-derived counts",
		{"scan": scan}
	)
	_emit(
		check,
		SOLIDS._indexed(model),
		"every material surface has explicit complete in-range native triangle indices"
	)
	_emit(
		check,
		SCAN._appearance_failure(model).is_empty() and int(scan.colors) >= 4,
		(
			"plain opaque independently owned materials are readable without emission animation or "
			+ "texture clocks"
		)
	)
	var actual: AABB = SCAN._bounds(POINTS._points(model))
	_emit(
		check,
		(
			SOLIDS._same_box(actual, M.visible_bounds(item))
			and M.envelope(item).grow(EPS).encloses(actual)
		),
		"every visible member fits the exact measured complete assembly bounds",
		{"actual": _box_array(actual), "expected": _box_array(M.visible_bounds(item))}
	)
	_emit(
		check,
		_physical_match(model, item),
		(
			"every physical member is its own enabled zero-margin exact convex hull and no hand "
			+ "owns a collider"
		)
	)
	_emit(
		check,
		SOLIDS._solid_faces(model),
		"all actual fixed-solid triangle faces wind outward around their matching convex hull"
	)
	_emit(
		check,
		_roles(model, item),
		(
			"every contact is strictly decorative-after-terminal without hidden scoring sensing "
			+ "light or audio authority"
		)
	)
	var second: Node3D = M.create(item)
	probe.add_child(second)
	_emit(
		check,
		POINTS._independent(model, second),
		"purchased complete copies share no mesh material or physics resource"
	)
	var before: String = SOLIDS._signature(model)
	_emit(
		check,
		SOLIDS._signature(second) == before,
		"fresh full models reproduce exact arrays material appearance and physical state"
	)
	SCAN._mutate(second)
	for shape: CollisionShape3D in second.find_children("*", "CollisionShape3D", true, false):
		shape.shape.points = PackedVector3Array(
			[Vector3.ZERO, Vector3.RIGHT, Vector3.UP, Vector3.BACK]
		)
	_emit(
		check,
		SOLIDS._signature(model) == before and SOLIDS._signature(second) != before,
		"destructive geometry material shape and pose mutations cannot affect another owned display"
	)
	second.free()
	var fresh: Node3D = M.create(item)
	_emit(
		check,
		SOLIDS._signature(fresh) == before,
		"fresh regeneration remains exact after destructive mutation of another copy"
	)
	fresh.free()
	await model.get_tree().process_frame
	_emit(
		check,
		SOLIDS._signature(model) == before,
		"idle presentation advances no ribbon PA clock or material animation"
	)
	return {
		"item": item,
		"meshes": scan.meshes,
		"solids": M.solid_count(item),
		"vertices": scan.vertices,
		"visible_bounds": _box_array(actual),
		"envelope": _box_array(M.envelope(item)),
		"support_count": M.support_points(item).size(),
		"appearance_signature": POINTS._visual_signature(model)
	}


static func _anatomy(model: Node3D, item: String, check: Callable) -> void:
	if item == "ST-068":
		_emit(
			check,
			(
				_named(model, "RibbonPixel*") == 96
				and _named(model, "RibbonModule*") == 4
				and _named(model, "RibbonBearing*") == 4
				and _named(model, "RibbonRiser*") == 4
			),
			(
				"one straight full-width section includes four real backing brackets four cabinets "
				+ "and ninety-six static color pixels"
			)
		)
		_emit(
			check,
			(
				model.get_meta("identity") == StadiumClubIdentity.current()
				and not model.get_meta("curved_variant")
				and (
					model.get_node("Visual/RibbonPixel0_0_0").material_override.albedo_color
					== Color(StadiumClubIdentity.current().palette[1])
				)
				and (
					model.get_node("Visual/RibbonPixel0_0_1").material_override.albedo_color
					== Color(StadiumClubIdentity.current().palette[0])
				)
			),
			(
				"exact existing club primary and accent colors make a frozen straight pattern without "
				+ "new identity or curved SKU"
			)
		)
		_emit(
			check,
			(
				_named(model, "RibbonFastener*") == 8
				and _named(model, "RibbonEndCap*") == 2
				and absf(SOLIDS._member(model, "RibbonHousing").size.x - 5.7) < EPS
				and absf(SOLIDS._member(model, "RibbonHousing").position.y - 0.08) < EPS
			),
			"finished end caps trim eight fixings and a real slim housing clear the immutable rear saddle"
		)
	elif item == "ST-069":
		_emit(
			check,
			(
				_named(model, "ClockBezel*") == 16
				and _named(model, "ClockHourMark*") == 12
				and model.has_node("HourHandPivot/ClockHourHand")
				and model.has_node("MinuteHandPivot/ClockMinuteHand")
			),
			(
				"complete analog clock includes closed case face sixteen-piece bezel twelve marks and "
				+ "independent visual hands"
			)
		)
		_emit(
			check,
			(
				not model.has_node("Collision/ClockHourHand")
				and not model.has_node("Collision/ClockMinuteHand")
				and model.get_node("HourHandPivot").transform == M.hand_pose("hour", 47400)
				and model.get_node("MinuteHandPivot").transform == M.hand_pose("minute", 47400)
			),
			"default clock reads existing thirteen-ten simulation time with no moving physical collision"
		)
		_emit(
			check,
			(
				SOLIDS._member(model, "ClockUpstand").position.z > 0.17
				and SOLIDS._member(model, "ClockClosedCase").position.z > 0.17
				and SOLIDS._member(model, "ClockStandOff").grow(EPS).intersects(
					SOLIDS._member(model, "ClockBearing")
				)
			),
			(
				"real rear plate standoff and upstand support the complete clock ahead of the "
				+ "unchanged gate cornice"
			)
		)
	else:
		_emit(
			check,
			(
				_named(model, "PAHornSide*") == 4
				and _named(model, "PAHornTopBottom*") == 4
				and _named(model, "PAHorn*Lip*") == 8
				and _named(model, "PADriver*") == 2
			),
			(
				"two complete tapered horn mouths contain eight real shell solids eight lip pieces "
				+ "and two rear drivers"
			)
		)
		_emit(
			check,
			(
				model.get_meta("silent_pa")
				and not model.get_meta("audio_implemented")
				and _named(model, "PAPivot*") == 4
				and _named(model, "PABearingBolt*") == 4
			),
			(
				"silent PA includes a physical yoke four pivots and four bearing fasteners with fixed "
				+ "host aiming"
			)
		)
		await model.get_tree().physics_frame
		await model.get_tree().physics_frame
		var upper: Dictionary = SOLIDS._ray(model, Vector3(0, 0.23, 0.9), Vector3(0, 0.23, 0.5))
		var throat: Dictionary = SOLIDS._ray(model, Vector3(0, 0.23, 0.9), Vector3(0, 0.23, 0.1))
		_emit(
			check,
			(
				upper.is_empty()
				and not throat.is_empty()
				and str(throat.collider.name) == "PAThroat1"
				and absf(model.to_local(throat.position).z - 0.315) < 0.003
			),
			(
				"native horn-mouth rays pass through real air and first hit the recessed throat "
				+ "without an invisible mouth-spanning proxy"
			)
		)


static func _clock_poses(model: Node3D, check: Callable) -> void:
	var fixed_before: String = (
		var_to_bytes(POINTS._physical_state(model)).hex_encode().sha256_text()
	)
	var metadata_before: Dictionary = {}
	for key: StringName in model.get_meta_list():
		metadata_before[key] = model.get_meta(key)
	for seconds: int in [0, 47400, 55800, 86399]:
		var ok: bool = M.set_clock_time(model, seconds)
		var hour: Node3D = model.get_node("HourHandPivot")
		var minute: Node3D = model.get_node("MinuteHandPivot")
		var expected_hour: Basis = Basis(Vector3.BACK, -TAU * float(seconds % 43200) / 43200.0)
		var expected_minute: Basis = Basis(Vector3.BACK, -TAU * float(seconds % 3600) / 3600.0)
		_emit(
			check,
			(
				ok
				and hour.basis == expected_hour
				and minute.basis == expected_minute
				and hour.position == Vector3(0, 0.56, 0.362)
				and minute.position == Vector3(0, 0.56, 0.374)
				and M.envelope("ST-069").grow(EPS).encloses(SCAN._bounds(POINTS._points(model)))
			),
			"exact finite simulation-time hand poses remain inside the full fixed clock reservation",
			{"seconds": seconds}
		)
	var metadata_after: Dictionary = {}
	for key: StringName in model.get_meta_list():
		metadata_after[key] = model.get_meta(key)
	_emit(
		check,
		(
			metadata_before == metadata_after
			and (
				fixed_before
				== var_to_bytes(POINTS._physical_state(model)).hex_encode().sha256_text()
			)
		),
		"every simulation-time pose leaves all metadata and every fixed physical hull byte-identical"
	)
	for seconds: int in [-1, 86400]:
		var before: String = SOLIDS._signature(model)
		_emit(
			check,
			not M.set_clock_time(model, seconds) and SOLIDS._signature(model) == before,
			"invalid simulation-time input cannot mutate the clock",
			{"seconds": seconds}
		)
	_emit(
		check,
		(
			M.hand_pose("foreign", 47400) == Transform3D.IDENTITY
			and M.hand_pose("hour", -1) == Transform3D.IDENTITY
		),
		"unknown hands and out-of-day times have no authored clock pose"
	)
	M.set_clock_time(model, 47400)


static func _socket_check(probe: Node3D, raw: Dictionary, check: Callable) -> Dictionary:
	var spec: Dictionary = M.socket(raw.host_item, raw.item, raw.host_model)
	var host: Node3D = (
		StadiumStraightOwnedModels.create(raw.host_item)
		if raw.host_model.is_empty()
		else StadiumScoreboardModels.create(raw.host_item, raw.host_model)
	)
	var mounted: Node3D = M.create(raw.item)
	_emit(
		check,
		host != null and mounted != null and spec.id == raw.id,
		"the exact named immutable host and its complete mounted item create",
		{"socket": raw.id}
	)
	if host == null or mounted == null:
		return {"id": raw.id, "error": "creation"}
	probe.add_child(host)
	probe.add_child(mounted)
	mounted.transform = spec.transform
	var before: String = POINTS._visual_signature(host)
	var adapter: StaticBody3D
	if str(spec.body).is_empty():
		adapter = _source_adapter(host, host.get_node(spec.surface))
		spec.body = str(host.get_path_to(adapter))
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var support: Dictionary = support_report(host, mounted, spec)
	_emit(
		check,
		support.triangle_contacts == 4,
		"all four real rear fixing contacts lie on triangles of the exact named source surface",
		support
	)
	_emit(
		check,
		support.native_contacts == 4 and support.supported,
		"all four native mount-interface rays hit the exact named host body instead of adjacent scenery",
		support
	)
	var actual: AABB = mounted.transform * SCAN._bounds(POINTS._points(mounted))
	_emit(
		check,
		(
			spec.envelope.grow(EPS).encloses(actual)
			and spec.envelope == spec.transform * M.envelope(raw.item)
		),
		"the full placed visible and contact assembly fits its exact host-relative mount reservation",
		{"actual": _box_array(actual)}
	)
	var clearance: Dictionary = separation_report(host, mounted, [str(spec.surface)])
	_emit(
		check,
		clearance.overlaps.is_empty(),
		"every unrelated actual host mesh clears every real mounted member without host mutation",
		clearance
	)
	_emit(
		check,
		(
			mounted.scale.is_equal_approx(Vector3.ONE)
			and mounted.basis.is_equal_approx(Basis(Vector3.UP, spec.yaw))
			and (
				(mounted.basis * Vector3.BACK).dot(
					Vector3.FORWARD if raw.item == "ST-068" else Vector3.BACK
				)
				> 0.99999
			)
		),
		"fixed source aiming uses one unit-scale rigid placement without per-item free rotation"
	)
	_emit(
		check,
		POINTS._visual_signature(host) == before,
		(
			"mount creation native support and frame advancement preserve exact host source "
			+ "geometry and appearance identity"
		)
	)
	var complete: AABB = SCAN._bounds(POINTS._points(host)).merge(actual)
	var result: Dictionary = {
		"id": raw.id,
		"item": raw.item,
		"host_item": raw.host_item,
		"host_model": raw.host_model,
		"source_surface": raw.surface,
		"source_body": raw.body,
		"support": support,
		"clearance": clearance,
		"mounted_bounds": _box_array(actual),
		"complete_assembly_bounds": _box_array(complete),
		"host_appearance_signature": before,
		"production_supported": raw.host_model.is_empty()
	}
	mounted.free()
	host.free()
	return result


static func support_report(host: Node3D, mounted: Node3D, spec: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"supported": false,
		"socket_id": spec.get("id", ""),
		"source_surface": spec.get("surface", ""),
		"source_body": spec.get("body", ""),
		"point_count": 0,
		"triangle_contacts": 0,
		"native_contacts": 0,
		"points": []
	}
	if (
		not is_instance_valid(host)
		or not is_instance_valid(mounted)
		or not host.is_inside_tree()
		or not mounted.is_inside_tree()
	):
		return result
	var surface: MeshInstance3D = (
		host.get_node_or_null(str(spec.get("surface", ""))) as MeshInstance3D
	)
	var expected_body: Node = host.get_node_or_null(str(spec.get("body", "")))
	if surface == null or not expected_body is StaticBody3D:
		return result
	var exclude: Array[RID] = []
	for body: StaticBody3D in mounted.find_children("*", "StaticBody3D", true, false):
		exclude.append(body.get_rid())
	var normal: Vector3 = mounted.global_basis * Vector3.BACK
	var contacts: PackedVector3Array = M.support_points(str(spec.get("item", "")))
	for index in range(contacts.size()):
		var point: Vector3 = mounted.to_global(contacts[index])
		var on_triangle: bool = point_on_mesh(surface, point)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			point + normal * 0.02, point - normal * 0.02, 1
		)
		query.exclude = exclude
		var hit: Dictionary = host.get_world_3d().direct_space_state.intersect_ray(query)
		var native: bool = (
			not hit.is_empty()
			and hit.collider == expected_body
			and hit.position.distance_to(point) < 0.003
		)
		result.triangle_contacts += int(on_triangle)
		result.native_contacts += int(native)
		result.points.append(
			{
				"index": index,
				"item_local": _vector_array(contacts[index]),
				"world": _vector_array(point),
				"triangle_contact": on_triangle,
				"native_contact": native,
				"hit_body": str(hit.collider.name) if not hit.is_empty() else ""
			}
		)
	result.point_count = contacts.size()
	result.supported = (
		contacts.size() == 4 and result.triangle_contacts == 4 and result.native_contacts == 4
	)
	return result


static func point_on_mesh(member: MeshInstance3D, world_point: Vector3) -> bool:
	var point: Vector3 = member.to_local(world_point)
	var faces: PackedVector3Array = member.mesh.get_faces()
	for index in range(0, faces.size(), 3):
		var a: Vector3 = faces[index]
		var b: Vector3 = faces[index + 1]
		var c: Vector3 = faces[index + 2]
		var normal: Vector3 = (b - a).cross(c - a)
		if normal.length_squared() < 0.000000000001:
			continue
		normal = normal.normalized()
		if absf(normal.dot(point - a)) > EPS:
			continue
		if (
			normal.dot((b - a).cross(point - a)) >= -EPS
			and normal.dot((c - b).cross(point - b)) >= -EPS
			and normal.dot((a - c).cross(point - c)) >= -EPS
		):
			return true
	return false


static func separation_report(
	host: Node3D, mounted: Node3D, allowed_paths: Array[String] = []
) -> Dictionary:
	var result: Dictionary = {
		"host_members": 0, "mounted_members": 0, "pairs_checked": 0, "overlaps": []
	}
	var mounted_members: Array[Node] = mounted.find_children("*", "MeshInstance3D", true, false)
	result.mounted_members = mounted_members.size()
	for other: MeshInstance3D in host.find_children("*", "MeshInstance3D", true, false):
		var path: String = str(host.get_path_to(other))
		if allowed_paths.has(path):
			continue
		result.host_members += 1
		var other_pose: Transform3D = (
			host.global_transform.affine_inverse() * other.global_transform
		)
		var other_box: AABB = other_pose * other.mesh.get_aabb()
		for member: MeshInstance3D in mounted_members:
			result.pairs_checked += 1
			var pose: Transform3D = host.global_transform.affine_inverse() * member.global_transform
			var box: AABB = pose * member.mesh.get_aabb()
			if box.grow(-EPS).intersects(other_box.grow(-EPS)):
				result.overlaps.append({"host": path, "mounted": str(mounted.get_path_to(member))})
	return result


static func _stack_clearance(probe: Node3D, check: Callable) -> Dictionary:
	var lower: Node3D = StadiumStraightOwnedModels.create("ST-029")
	var upper: Node3D = StadiumStraightOwnedModels.create("ST-030")
	var ribbon: Node3D = M.create("ST-068")
	probe.add_child(lower)
	probe.add_child(upper)
	probe.add_child(ribbon)
	ribbon.transform = M.socket("ST-031", "ST-068").transform
	var low: Dictionary = separation_report(lower, ribbon)
	var high: Dictionary = separation_report(upper, ribbon)
	_emit(
		check,
		(
			low.overlaps.is_empty()
			and low.host_members > 350
			and low.pairs_checked == low.host_members * 121
		),
		(
			"concourse ribbon clears every actual immutable required lower stand seat audience "
			+ "rail and stair member"
		),
		low
	)
	_emit(
		check,
		high.overlaps.is_empty() and high.host_members > 100,
		"concourse ribbon also clears every real upper pylon cantilever seat rail and access member",
		high
	)
	_emit(
		check,
		(
			lower.get_meta("represented_seats") == 50
			and upper.get_meta("represented_seats") == 16
			and (
				(
					lower
					. get_node("Visual")
					. find_children("CrowdAnchor*", "Node3D", false, false)
					. size()
				)
				== 50
			)
			and (
				(
					upper
					. get_node("Visual")
					. find_children("CrowdAnchor*", "Node3D", false, false)
					. size()
				)
				== 16
			)
		),
		(
			"required source hosts retain every original represented seat and audience member "
			+ "without clearance edits"
		)
	)
	var result: Dictionary = {
		"exact_relation": "ST-031.lower -> same-site exact ST-029 owned copy",
		"lower": low,
		"upper": high
	}
	lower.free()
	upper.free()
	ribbon.free()
	return result


static func _source_adapter(host: Node3D, surface: MeshInstance3D) -> StaticBody3D:
	# Test-only adapter for the two unsupported scoreboard factories with no production bodies.
	# The convex surface is copied exactly from the named box mesh, never its whole host reservation.
	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ExactNamedSurfaceProbe"
	body.collision_layer = 1
	body.collision_mask = 2
	host.add_child(body)
	body.transform = host.global_transform.affine_inverse() * surface.global_transform
	var collider: CollisionShape3D = CollisionShape3D.new()
	var shape: ConvexPolygonShape3D = ConvexPolygonShape3D.new()
	shape.points = surface.mesh.get_faces()
	shape.margin = 0.0
	collider.shape = shape
	body.add_child(collider)
	return body


static func _physical_match(model: Node3D, item: String) -> bool:
	var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
	if (
		bodies.size() != M.solid_count(item)
		or model.find_children("*", "CollisionShape3D", true, false).size() != bodies.size()
	):
		return false
	for body: StaticBody3D in bodies:
		if (
			body.get_parent() != model.get_node("Collision")
			or body.transform != Transform3D.IDENTITY
			or body.get_child_count() != 1
			or body.collision_layer != 1
			or body.collision_mask != 2
		):
			return false
		var collider: CollisionShape3D = body.get_child(0)
		if (
			not collider.shape is ConvexPolygonShape3D
			or collider.disabled
			or collider.shape.margin != 0.0
			or collider.transform != Transform3D.IDENTITY
		):
			return false
		var hull: PackedVector3Array = collider.shape.points
		var visible: PackedVector3Array = (
			model.get_node("Visual/" + str(body.name)).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		)
		for point: Vector3 in hull:
			if (
				not point.is_finite()
				or not M.envelope(item).grow(EPS).has_point(point)
				or not POINTS._has_point(visible, point)
			):
				return false
		for point: Vector3 in visible:
			if not POINTS._has_point(hull, point):
				return false
	return true


static func _static_nodes(model: Node3D) -> bool:
	var nodes: Array[Node] = [model]
	nodes.append_array(model.find_children("*", "", true, false))
	for node: Node in nodes:
		if (
			node.get_class() not in ["Node3D", "MeshInstance3D", "StaticBody3D", "CollisionShape3D"]
			or node.get_script() != null
			or node.is_processing()
			or node.is_physics_processing()
		):
			return false
		if (
			node is Node3D
			and (
				not node.visible
				or node.top_level
				or not node.position.is_finite()
				or not node.scale.is_equal_approx(Vector3.ONE)
			)
		):
			return false
	return true


static func _roles(model: Node3D, item: String) -> bool:
	for body: StaticBody3D in model.find_children("*", "StaticBody3D", true, false):
		if (
			body.get_meta("stadium_item", "") != item
			or body.get_meta("surface_id", "") != str(body.name)
			or body.get_meta("surface_role", "") != M.ROLE
			or body.get_meta("ball_surface", "") != &"stadium_scenery"
		):
			return false
	for node: Node in model.find_children("*", "", true, false):
		for key: String in [
			"owned_copy", "volume_id", "target_points", "live_furnishing", "revenue", "capacity"
		]:
			if node.has_meta(key):
				return false
	return true


static func _named(model: Node3D, pattern: String) -> int:
	return model.find_children(pattern, "MeshInstance3D", true, false).size()


static func _vector_array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _box_array(value: AABB) -> Array:
	return [
		value.position.x,
		value.position.y,
		value.position.z,
		value.size.x,
		value.size.y,
		value.size.z
	]

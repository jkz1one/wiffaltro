class_name StadiumStringLightGeometryChecks
extends Node3D
## Finite native geometry and collision checks. No rendered night/camera qualification.

const M = preload("res://src/presentation/stadium/stadium_string_light_models.gd")
const EPS: float = 0.0002
const EXPECTED_CHECKS: int = 156
const EXPECTED_SITES: Dictionary = {
	"STR-LF": [Vector3(-25, 0, -7), Vector3(-25, 0, 7)],
	"STR-LD": [Vector3(-25, 0, 17), Vector3(-25, 0, 31)],
	"STR-RF": [Vector3(25, 0, -7), Vector3(25, 0, 7)],
	"STR-RD": [Vector3(25, 0, 17), Vector3(25, 0, 31)],
	"STR-BL": [Vector3(-15, 0, -9), Vector3(-1, 0, -9)],
	"STR-BR": [Vector3(1, 0, -9), Vector3(15, 0, -9)],
	"STR-BC": [Vector3(-7, 0, -9), Vector3(7, 0, -9)],
}

@export var run_standalone: bool = false


func _ready() -> void:
	if not run_standalone:
		return
	var report: Dictionary = await run(self, func(_ok: bool, _message: String) -> void: pass)
	print("STRING_LIGHT_GEOMETRY_RESULT " + JSON.stringify(report, "", true, true))
	get_tree().quit(0 if report.failures == 0 and report.checks == expected_checks() else 1)


static func expected_checks() -> int:
	return EXPECTED_CHECKS


static func run(parent: Node3D, check: Callable) -> Dictionary:
	var report: Dictionary = {
		"checks": 0,
		"failures": 0,
		"physics_queries": 0,
		"engine": Engine.get_version_info().string,
		"night_qualified": false,
		"sites": []
	}
	var probe: Node3D = Node3D.new()
	probe.name = "StringLightGeometryProbe"
	probe.position = Vector3(2200, 0, 0)
	parent.add_child(probe)
	var model: Node3D = M.create()
	_emit(report, check, model != null, "the one complete ST036 assembly is created")
	if model == null:
		probe.free()
		return report
	probe.add_child(model)
	_source(model, report, check)
	_rejections(report, check)
	var original: String = _signature(model)
	var fresh: Node3D = M.create()
	_emit(
		report,
		check,
		_signature(fresh) == original and _independent(model, fresh),
		"separate assemblies have deterministic geometry and independent native resources"
	)
	(fresh.get_node("Visual/Bulb00").mesh as SphereMesh).radius = 0.03
	(fresh.get_node("Visual/PostAMast").material_override as StandardMaterial3D).albedo_color = (
		Color.RED
	)
	(fresh.get_node("Collision/PostAMast/Shape").shape as CylinderShape3D).radius = 0.2
	_emit(
		report,
		check,
		_signature(model) == original,
		"changing another copy cannot alter this assembly's mesh material or post solids"
	)
	fresh.free()
	model.free()
	for site: String in EXPECTED_SITES:
		await _site(probe, site, report, check)
	probe.free()
	return report


static func _source(model: Node3D, report: Dictionary, check: Callable) -> void:
	_emit(
		report,
		check,
		(
			model.transform == Transform3D.IDENTITY
			and model.get_child_count() == 2
			and model.get_node("Visual").transform == Transform3D.IDENTITY
			and model.get_node("Collision").transform == Transform3D.IDENTITY
		),
		"one local +X source has separate identity visual and collision branches"
	)
	_emit(
		report,
		check,
		(
			M.VERSION == 1
			and M.ITEM == "ST-036"
			and model.get_meta("stadium_item") == M.ITEM
			and model.get_meta("authoring_status") == "Working"
			and model.get_meta("qualification_status") == "CANDIDATE"
			and not model.get_meta("night_qualified")
			and not model.get_meta("final_art_accepted")
			and model.get_meta("obstacle_units") == 0
			and model.get_meta("included_supports") == 2
			and not model.get_meta("supports_separately_owned")
			and not model.has_meta("owned_copy")
		),
		"Working candidate grants no copies separate supports live budget or night approval"
	)
	var components: Array[Dictionary] = M.components()
	_emit(
		report,
		check,
		(
			components.size() == 3
			and components[0].radius == 0.25
			and components[1].radius == 0.25
			and components[0].bounds == AABB(Vector3(-0.25, 0, -0.25), Vector3(0.5, 6.15, 0.5))
			and components[1].bounds == AABB(Vector3(13.75, 0, -0.25), Vector3(0.5, 6.15, 0.5))
			and components[2].bounds == AABB(Vector3(-0.15, 5.2, -0.15), Vector3(14.3, 0.95, 0.3))
		),
		"DG separate post and cable reservations preserve their exact dimensions"
	)
	var clearance: Array[Dictionary] = M.clearance_components()
	_emit(
		report,
		check,
		(
			clearance.size() == 2
			and clearance[0].center == Vector3.ZERO
			and clearance[1].center == Vector3(14, 0, 0)
			and clearance[0].radius == 0.5
			and clearance[1].radius == 0.5
		),
		"installation clearance reserves two radius-half-metre ground circles only"
	)
	components[0].bounds = AABB()
	clearance[0].radius = 999
	_emit(
		report,
		check,
		M.components()[0].bounds != AABB() and M.clearance_components()[0].radius == 0.5,
		"callers cannot mutate future component and clearance records"
	)
	_emit(
		report,
		check,
		(
			M.cable_point(0).is_equal_approx(Vector3(0, 6, 0))
			and M.cable_point(1).is_equal_approx(Vector3(14, 6, 0))
			and M.cable_point(0.5).is_equal_approx(Vector3(7, 5.4, 0))
		),
		"fourteen-metre horizontal endpoints retain six-metre anchors and exact 0.60-metre sag"
	)
	var sag_ok: bool = true
	for index in range(1001):
		var t: float = index / 1000.0
		var point: Vector3 = M.cable_point(t)
		sag_ok = (
			sag_ok
			and point.is_equal_approx(Vector3(14 * t, 6 - 2.4 * t * (1 - t), 0))
			and point.y >= 5.4 - EPS
			and point.y <= 6.0 + EPS
		)
	_emit(report, check, sag_ok, "1001 analytic samples retain the prescribed fixed sag curve")
	var meshes: Array[Node] = model.find_children("*", "MeshInstance3D", true, false)
	_emit(
		report,
		check,
		(
			meshes.size() == 6 + 56 + 14 * 3
			and model.find_children("Cable*", "MeshInstance3D", true, false).size() == 56
			and model.find_children("Bulb*", "MeshInstance3D", true, false).size() == 14
		),
		"one assembly contains six post pieces one sampled cable and fourteen identical bulbs"
	)
	_emit(
		report,
		check,
		_solids(model),
		"only the six real visible post pieces have matching enabled zero-margin solids"
	)
	var points: PackedVector3Array = _vertices(model)
	var finite: bool = points.size() > 1000
	for point: Vector3 in points:
		finite = finite and point.is_finite()
	_emit(report, check, finite, "all generated native mesh vertices are finite and inspected")
	var actual: AABB = _bounds(points)
	report["local_bounds"] = str(actual)
	_emit(
		report,
		check,
		(
			M.envelope() == AABB(Vector3(-0.25, 0, -0.25), Vector3(14.5, 6.15, 0.5))
			and M.envelope().grow(EPS).encloses(actual)
			and absf(actual.position.y) < EPS
			and absf(actual.end.y - 6.15) < EPS
		),
		"complete visible geometry stays grounded inside the DG envelope with full-height posts"
	)
	var post_ok: bool = true
	var cable_ok: bool = true
	for mesh_node: MeshInstance3D in meshes:
		for point: Vector3 in _mesh_vertices(mesh_node):
			if str(mesh_node.name).begins_with("Post"):
				var x: float = 0 if str(mesh_node.name).begins_with("PostA") else 14
				post_ok = (
					post_ok
					and Vector2(point.x - x, point.z).length() <= 0.25 + EPS
					and point.y >= -EPS
					and point.y <= 6.15 + EPS
				)
			else:
				cable_ok = cable_ok and M.CABLE_ENVELOPE.grow(EPS).has_point(point)
	_emit(
		report,
		check,
		post_ok,
		"all real support vertices fit the radius-0.25 full-height post cylinders"
	)
	_emit(
		report,
		check,
		cable_ok,
		"all cable socket dropper and bulb vertices fit the protected lighting corridor"
	)
	_emit(
		report,
		check,
		(
			model.find_children("*", "Light3D", true, false).is_empty()
			and model.find_children("*", "AnimationPlayer", true, false).is_empty()
			and model.find_children("*", "RigidBody3D", true, false).is_empty()
			and model.find_children("*", "Area3D", true, false).is_empty()
			and _static(model)
		),
		"no individual lights animation sway physics simulation or clearance sensors exist"
	)
	_emit(
		report,
		check,
		_rigid(model),
		"every native transform uses finite positive unit scale without mirroring"
	)
	var centers: PackedVector3Array = M.bulb_points()
	for index in range(14):
		var bulb: MeshInstance3D = model.get_node("Visual/Bulb%02d" % index)
		var t: float = (index + 0.5) / 14.0
		var expected: Vector3 = Vector3(14 * t, 6 - 2.4 * t * (1 - t), 0)
		var globe: SphereMesh = bulb.mesh
		var material: StandardMaterial3D = bulb.material_override
		var bottom: float = bulb.position.y - globe.height / 2
		_emit(
			report,
			check,
			(
				centers.size() == 14
				and centers[index].is_equal_approx(bulb.position)
				and bulb.get_meta("bulb_index") == index
				and is_equal_approx(float(bulb.get_meta("cable_t")), t)
				and bulb.get_meta("cable_anchor").is_equal_approx(expected)
				and bulb.position.is_equal_approx(expected - Vector3(0, 0.105, 0))
				and is_equal_approx(globe.radius, 0.045)
				and is_equal_approx(globe.height, 0.09)
				and absf(bottom - (expected.y - 0.15)) < EPS
				and not material.emission_enabled
				and material.emission_energy_multiplier == 0
				and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			),
			"each identical dormant globe retains its exact DG index anchor and maximum hang",
			{"bulb": index}
		)
	for index in range(56):
		var segment: MeshInstance3D = model.get_node("Visual/Cable%02d" % index)
		var cylinder: CylinderMesh = segment.mesh
		var a: Vector3 = segment.transform * Vector3(0, -cylinder.height / 2, 0)
		var b: Vector3 = segment.transform * Vector3(0, cylinder.height / 2, 0)
		var t0: float = index / 56.0
		var t1: float = (index + 1) / 56.0
		_emit(
			report,
			check,
			(
				a.is_equal_approx(M.cable_point(t0))
				and b.is_equal_approx(M.cable_point(t1))
				and is_equal_approx(cylinder.top_radius, 0.012)
				and is_equal_approx(cylinder.bottom_radius, 0.012)
				and ((a + b) / 2).distance_to(M.cable_point((t0 + t1) / 2)) <= EPS
			),
			"sampled cable endpoints follow the analytic curve with sub-0.2mm chord deviation",
			{"segment": index}
		)


static func _rejections(report: Dictionary, check: Callable) -> void:
	for item: String in ["", "ST-037", "ST-035"]:
		var wrong: Node3D = M.create(item)
		_emit(
			report,
			check,
			(
				wrong == null
				and M.envelope(item) == AABB()
				and M.components(item).is_empty()
				and M.clearance_components(item).is_empty()
			),
			"foreign catalog identity cannot create or reserve a string span",
			{"item": item}
		)
		if wrong != null:
			wrong.free()
	for row: Dictionary in [
		{"site": "STR-LF"},
		{"copy": "copy"},
		{"copy": "", "site": "STR-LF"},
		{"copy": 1, "site": "STR-LF"},
		{"copy": "copy", "site": 1},
		{"copy": "copy", "site": ""},
		{"copy": "copy", "site": "YLIGHT-FL"},
		{"copy": "copy", "site": "STR-LX"}
	]:
		var wrong: Node3D = M.create("ST-036", row)
		_emit(
			report,
			check,
			wrong == null,
			"incomplete or foreign owned placement is rejected",
			{"placement": row}
		)
		if wrong != null:
			wrong.free()
	var foreign: Node3D = Node3D.new()
	foreign.set_meta("stadium_item", "ST-037")
	_emit(
		report,
		check,
		(
			not M.place(null, "STR-LF")
			and not M.place(foreign, "STR-LF")
			and foreign.transform == Transform3D.IDENTITY
		),
		"placement cannot convert another item or a null root"
	)
	foreign.free()


static func _site(parent: Node3D, site: String, report: Dictionary, check: Callable) -> void:
	var row: Dictionary = {"copy": "geometry:string:" + site, "site": site}
	var model: Node3D = M.create("ST-036", row)
	_emit(
		report, check, model != null, "owned span creates at each exact DG socket", {"site": site}
	)
	if model == null:
		return
	parent.add_child(model)
	var a: Vector3 = EXPECTED_SITES[site][0]
	var b: Vector3 = EXPECTED_SITES[site][1]
	var pose: Transform3D = M.pose(site)
	_emit(
		report,
		check,
		(
			a.distance_to(b) == 14
			and model.transform == pose
			and (pose * Vector3.ZERO).is_equal_approx(a)
			and (pose * Vector3(14, 0, 0)).is_equal_approx(b)
			and (pose * M.cable_point(0)).is_equal_approx(a + Vector3(0, 6, 0))
			and (pose * M.cable_point(1)).is_equal_approx(b + Vector3(0, 6, 0))
		),
		"one proper +X pose maps both ground and elevated endpoints exactly",
		{"site": site}
	)
	_emit(
		report,
		check,
		(
			pose.basis.get_scale().is_equal_approx(Vector3.ONE)
			and is_equal_approx(pose.basis.determinant(), 1)
			and pose.basis.y == Vector3.UP
			and _rigid(model)
			and _owned(model, row.copy, site)
		),
		"every site uses unit scale and recursively binds its one paid assembly",
		{"site": site}
	)
	var bounds: AABB = pose * M.envelope()
	var backyard: AABB = AABB(Vector3(-26, 0, -10), Vector3(52, 7, 42))
	var clearance_ok: bool = true
	for endpoint: Vector3 in [a, b]:
		clearance_ok = (
			clearance_ok
			and endpoint.x - 0.5 >= -26
			and endpoint.x + 0.5 <= 26
			and endpoint.z - 0.5 >= -10
			and endpoint.z + 0.5 <= 32
		)
	_emit(
		report,
		check,
		backyard.grow(EPS).encloses(bounds) and clearance_ok,
		"complete span and both ground clearances fit the reference Backyard",
		{"site": site}
	)
	await parent.get_tree().physics_frame
	await parent.get_tree().physics_frame
	var space: PhysicsDirectSpaceState3D = parent.get_world_3d().direct_space_state
	var hits_ok: bool = true
	for x: float in [0.0, 14.0]:
		hits_ok = _ray(space, model, Vector3(x, 3, -0.7), Vector3(x, 3, 0.7), report) and hits_ok
		hits_ok = (
			_ray(space, model, Vector3(x + 0.12, 0.14, -0.7), Vector3(x + 0.12, 0.14, 0.7), report)
			and hits_ok
		)
		hits_ok = (
			_ray(space, model, Vector3(x + 0.20, 0.06, -0.7), Vector3(x + 0.20, 0.06, 0.7), report)
			and hits_ok
		)
	_emit(
		report, check, hits_ok, "native rays hit each actual mast plate and footing", {"site": site}
	)
	var clear_ok: bool = true
	for x: float in [0.35, 13.65, 7.0]:
		for height: float in [0.06, 3.0, 5.4]:
			clear_ok = (
				not _ray(space, model, Vector3(x, height, -0.7), Vector3(x, height, 0.7), report)
				and clear_ok
			)
	_emit(
		report,
		check,
		clear_ok,
		"native rays miss empty clearance and the entire unblocked under-span",
		{"site": site}
	)
	var saved: Transform3D = model.transform
	var before: String = _signature(model)
	_emit(
		report,
		check,
		(
			not M.place(model, "STR-UNKNOWN")
			and model.transform == saved
			and _signature(model) == before
			and model.get_meta("site") == site
		),
		"invalid relocation leaves pose geometry and ownership intact",
		{"site": site}
	)
	model.scale = Vector3(2, 2, 2)
	_emit(
		report,
		check,
		(
			M.place(model, site)
			and model.transform == saved
			and _owned(model, row.copy, site)
			and not model.get_meta("night_qualified")
			and _signature(model) == before
		),
		(
			"authorized fixed placement restores unit scale without changing geometry ownership or "
			+ "night status"
		),
		{"site": site}
	)
	report.sites.append({"site": site, "bounds": str(bounds), "copy": row.copy})
	model.free()


static func _ray(
	space: PhysicsDirectSpaceState3D, model: Node3D, from: Vector3, to: Vector3, report: Dictionary
) -> bool:
	report.physics_queries += 1
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		model.global_transform * from, model.global_transform * to, 1
	)
	var hit: Dictionary = space.intersect_ray(query)
	return not hit.is_empty() and model.is_ancestor_of(hit.collider)


static func _solids(model: Node3D) -> bool:
	if (
		model.get_node("Collision").get_child_count() != 6
		or model.find_children("*", "CollisionShape3D", true, false).size() != 6
	):
		return false
	for body: StaticBody3D in model.get_node("Collision").get_children():
		if (
			not str(body.name).begins_with("Post")
			or body.collision_layer != 1
			or body.collision_mask != 0
			or body.get_meta("surface_role", "") != M.ROLE
			or body.get_child_count() != 1
		):
			return false
		var collider: CollisionShape3D = body.get_child(0)
		var mesh_node: MeshInstance3D = model.get_node("Visual/" + str(body.name))
		if (
			not collider.shape is CylinderShape3D
			or not mesh_node.mesh is CylinderMesh
			or collider.disabled
			or collider.shape.margin != 0
			or collider.transform != Transform3D.IDENTITY
			or body.transform != mesh_node.transform
		):
			return false
		var shape: CylinderShape3D = collider.shape
		var mesh: CylinderMesh = mesh_node.mesh
		if (
			not is_equal_approx(shape.height, mesh.height)
			or not is_equal_approx(shape.radius, mesh.top_radius)
			or not is_equal_approx(shape.radius, mesh.bottom_radius)
			or shape.radius > 0.25
		):
			return false
	return true


static func _static(node: Node) -> bool:
	if node.get_script() != null:
		return false
	for child: Node in node.get_children():
		if not _static(child):
			return false
	return true


static func _rigid(node: Node) -> bool:
	if node is Node3D:
		var spatial: Node3D = node
		if (
			not spatial.position.is_finite()
			or not spatial.basis.is_finite()
			or not spatial.scale.is_equal_approx(Vector3.ONE)
			or not is_equal_approx(spatial.basis.determinant(), 1)
		):
			return false
	for child: Node in node.get_children():
		if not _rigid(child):
			return false
	return true


static func _owned(node: Node, copy: String, site: String) -> bool:
	if (
		node.get_meta("owned_copy", "") != copy
		or node.get_meta("paid_copy", "") != copy
		or node.get_meta("stadium_item", "") != M.ITEM
		or node.get_meta("site", "") != site
		or node.get_meta("surface_role", "") != M.ROLE
	):
		return false
	for child: Node in node.get_children():
		if not _owned(child, copy, site):
			return false
	return true


static func _vertices(model: Node3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		result.append_array(_mesh_vertices(mesh))
	return result


static func _mesh_vertices(mesh_node: MeshInstance3D) -> PackedVector3Array:
	var result: PackedVector3Array = []
	for surface in range(mesh_node.mesh.get_surface_count()):
		var arrays: Array = mesh_node.mesh.surface_get_arrays(surface)
		for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			result.append(mesh_node.transform * vertex)
	return result


static func _bounds(points: PackedVector3Array) -> AABB:
	if points.is_empty():
		return AABB()
	var result: AABB = AABB(points[0], Vector3.ZERO)
	for point: Vector3 in points:
		result = result.expand(point)
	return result


static func _independent(a: Node3D, b: Node3D) -> bool:
	for mesh: MeshInstance3D in a.find_children("*", "MeshInstance3D", true, false):
		var peer: MeshInstance3D = b.get_node("Visual/" + str(mesh.name))
		if mesh.mesh == peer.mesh or mesh.material_override == peer.material_override:
			return false
	for body: StaticBody3D in a.get_node("Collision").get_children():
		if body.get_child(0).shape == b.get_node("Collision/" + str(body.name) + "/Shape").shape:
			return false
	return true


static func _signature(root: Node3D) -> String:
	var rows: Array = []
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var material: StandardMaterial3D = mesh.material_override
		rows.append(
			[
				str(mesh.name),
				mesh.transform,
				mesh.visible,
				material.albedo_color,
				material.emission_enabled,
				material.emission_energy_multiplier
			]
		)
		for surface in range(mesh.mesh.get_surface_count()):
			rows.append(mesh.mesh.surface_get_arrays(surface))
	for body: StaticBody3D in root.get_node("Collision").get_children():
		var shape: CylinderShape3D = body.get_child(0).shape
		rows.append(
			[
				str(body.name),
				body.transform,
				body.collision_layer,
				body.collision_mask,
				shape.height,
				shape.radius,
				shape.margin,
				body.get_child(0).disabled
			]
		)
	return var_to_bytes(rows).hex_encode().sha256_text()


static func _emit(
	report: Dictionary, check: Callable, ok: bool, message: String, operands: Dictionary = {}
) -> void:
	report.checks += 1
	if not ok:
		report.failures += 1
		print(
			(
				"STRING_LIGHT_GEOMETRY_FAILURE "
				+ JSON.stringify({"message": message, "operands": operands}, "", true, true)
			)
		)
	check.call(ok, message)

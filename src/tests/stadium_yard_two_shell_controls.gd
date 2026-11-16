extends RefCounted
## Canonical self-identity and normalized triangle-oracle regression controls.
const Shell = preload("res://src/tests/stadium_yard_two_shell_geometry.gd")


static func run(
	owner: Node, lab: PitchBatLab, cache: Dictionary, bound: Dictionary, audit_script: Variant
) -> void:
	Shell._supp_ray_controls(owner)
	owner._check(
		bound.ball_meshes.size() == 1,
		"supplementary shell has one authenticated direct-child visual"
	)
	if bound.ball_meshes.size() != 1:
		return
	var row: Dictionary = bound.ball_meshes.values()[0]
	var visual: MeshInstance3D = row.mesh
	owner._check(
		audit_script._self_intact(lab, visual, row),
		"supplementary authentic shell baseline is intact"
	)
	var original: Transform3D = visual.transform
	for changed: Transform3D in [
		Transform3D(Basis.IDENTITY, Vector3(0.01, 0, 0)),
		Transform3D(Basis(Vector3.UP, 0.1), Vector3.ZERO),
		Transform3D(Basis.IDENTITY.scaled(Vector3(1.01, 1, 1)), Vector3.ZERO)
	]:
		visual.transform = changed
		owner._check(
			(
				not audit_script._self_intact(lab, visual, row)
				and audit_script.audit(lab, cache).invalid > 0
			),
			"supplementary changed local transform revokes self before broad phase"
		)
		visual.transform = original
		owner._check(
			audit_script._self_intact(lab, visual, row),
			"supplementary transform restoration retains exact identity"
		)
	var original_mesh: Mesh = visual.mesh
	visual.mesh = null
	owner._check(
		audit_script.audit(lab, cache).invalid > 0,
		"supplementary removed shell resource fails closed without oracle exception"
	)
	visual.mesh = original_mesh
	owner._check(
		audit_script._self_intact(lab, visual, row),
		"supplementary null-mesh restoration retains original resource"
	)
	var discarded: MeshInstance3D = MeshInstance3D.new()
	row.mesh = discarded
	discarded.free()
	owner._check(
		audit_script.audit(lab, cache).invalid > 0,
		"supplementary freed pinned node fails closed without dereference"
	)
	row.mesh = visual
	owner._check(
		audit_script._self_intact(lab, visual, row),
		"supplementary pinned-node restoration is exact"
	)
	var material: StandardMaterial3D = visual.material_override
	visual.material_override = material.duplicate()
	owner._check(
		not audit_script._self_intact(lab, visual, row),
		"supplementary copied material cannot impersonate pinned material"
	)
	visual.material_override = material
	var color: Color = material.albedo_color
	material.albedo_color = Color.MAGENTA
	owner._check(
		not audit_script._self_intact(lab, visual, row),
		"supplementary in-place material change is detected"
	)
	material.albedo_color = color
	var old_aabb: AABB = visual.mesh.custom_aabb
	visual.mesh.custom_aabb = AABB(Vector3(100, 100, 100), Vector3.ONE)
	owner._check(
		(
			not audit_script._self_intact(lab, visual, row)
			and audit_script.audit(lab, cache).invalid > 0
		),
		"supplementary forged AABB cannot hide invalid shell before triangle scan"
	)
	visual.mesh.custom_aabb = old_aabb
	var surface_material: Material = visual.mesh.surface_get_material(0)
	visual.mesh.surface_set_material(0, StandardMaterial3D.new())
	owner._check(
		not audit_script._self_intact(lab, visual, row),
		"supplementary same-resource surface material change is detected"
	)
	visual.mesh.surface_set_material(0, surface_material)
	owner._check(
		audit_script._self_intact(lab, visual, row),
		"supplementary material and AABB restoration are exact"
	)
	var saved_camera: Transform3D = lab._camera.global_transform
	lab._camera.global_position = (
		lab._batted_ball.global_position + lab._batted_ball.global_basis.x.normalized()
	)
	var impostor: MeshInstance3D = MeshInstance3D.new()
	impostor.name = visual.name
	impostor.mesh = visual.mesh
	impostor.material_override = material
	lab.add_child(impostor)
	impostor.global_transform = visual.global_transform
	# Keep the exact R2 +X/1 m ray as an observation, not an assumed positive fixture.
	var observations: Array = []
	var old_ray: Dictionary = _supp_impostor_ray_measurement(
		lab, cache, bound, impostor, audit_script
	)
	old_ray["fixture"] = "original_pole_one_m"
	observations.append(old_ray)
	owner._check(
		old_ray.indexed.independent_hits > 0 and old_ray.actual_audit_blocked_count > 0,
		"original one-meter pole ray detects shared-resource impostor after normalization"
	)
	owner._check(
		(
			not bound.ball_meshes.has(impostor.get_instance_id())
			and not audit_script._self_intact(lab, impostor, row)
			and audit_script._classify(lab, bound, impostor, 0.0, 0.0).classification == "blocked"
		),
		"supplementary R3 shared-resource impostor has no self exemption independently of ray hits"
	)
	# Predeclared 2x2: pole/opaque-sector, 1 m/retained pre-control camera distance.
	# The retained distance comes from existing controls, not a search for a passing ray.
	var retained_distance: float = saved_camera.origin.distance_to(lab._batted_ball.global_position)
	var sector: Vector3 = Vector3(cos(0.84), sin(0.84) * cos(PI / 8.0), sin(0.84) * sin(PI / 8.0))
	var positive_ray: Dictionary = {}
	for fixture: Array in [
		["pole_retained_distance", Vector3.RIGHT, retained_distance],
		["opaque_sector_one_m", sector, 1.0],
		["opaque_sector_retained_distance", sector, retained_distance]
	]:
		lab._camera.global_position = (
			lab._batted_ball.global_position
			+ (impostor.global_basis * fixture[1]).normalized() * float(fixture[2])
		)
		var measured: Dictionary = _supp_impostor_ray_measurement(
			lab, cache, bound, impostor, audit_script
		)
		measured["fixture"] = fixture[0]
		observations.append(measured)
		if fixture[0] == "opaque_sector_retained_distance":
			positive_ray = measured
	print("AY02_SUPPLEMENTARY_IMPOSTOR_R3 ", JSON.stringify(observations))
	owner._check(
		(
			positive_ray.indexed.independent_hits > 0
			and positive_ray.indexed.all_independent_hits_blocked
		),
		"opaque-sector fixture has independent indexed hits, all blocked"
	)
	owner._check(
		audit_script._count(audit_script.audit(lab, cache), impostor, "blocked") > 0,
		"supplementary identical shared-resource shell on another node stays a blocker"
	)
	impostor.free()
	lab._camera.global_transform = saved_camera
	var faces: PackedVector3Array = Shell._supp_indexed_faces(visual.mesh)
	var aperture_baseline: Dictionary = Shell._supp_apertures(faces)
	(
		owner
		. _check(
			aperture_baseline.open == 8 and aperture_baseline.closed == 8,
			"supplementary front-shell aperture baseline distinguishes eight holes from eight opaque sectors"
		)
	)
	var bridged: PackedVector3Array = faces.duplicate()
	var direction: Vector3 = Vector3(cos(0.84), sin(0.84), 0)
	var center: Vector3 = direction * 0.075
	var axis_u: Vector3 = direction.cross(Vector3.UP).normalized() * 0.01
	var axis_v: Vector3 = direction.cross(axis_u).normalized() * 0.01
	bridged.append_array(
		PackedVector3Array([center + axis_u, center - axis_u + axis_v, center - axis_u - axis_v])
	)
	var aperture_negative: Dictionary = Shell._supp_apertures(bridged)
	owner._check(
		aperture_negative.open == 7 and aperture_negative.closed == 8,
		"triangle bridge closes one aperture and preserves the remaining sectors"
	)
	var empty_apertures: Dictionary = Shell._supp_apertures(PackedVector3Array())
	owner._check(
		empty_apertures.open == 8 and empty_apertures.closed == 0,
		"supplementary absent geometry cannot pass the combined aperture and opaque-sector contract"
	)
	var probe: WiffleBallVisual = WiffleBallVisual.create(0.78)
	var reference: WiffleBallVisual = WiffleBallVisual.create(0.78)
	var probe_row: Dictionary = audit_script._source_binding(probe, reference)
	owner._check(
		not probe_row.is_empty() and audit_script._resource_intact(probe, probe_row),
		"supplementary independent disposable shell has an intact baseline"
	)
	probe.mesh.clear_surfaces()
	owner._check(
		not Shell._supp_shell_geometry(probe).errors.is_empty(),
		"supplementary geometry gate rejects a deleted authored surface"
	)
	owner._check(
		not audit_script._resource_intact(probe, probe_row),
		"supplementary in-place topology deletion cannot reuse the pinned identity"
	)
	probe.free()
	reference.free()
	owner._check(
		audit_script._self_intact(lab, visual, row),
		"supplementary controls leave genuine shell intact"
	)


static func _supp_impostor_ray_measurement(
	lab: PitchBatLab,
	cache: Dictionary,
	bound: Dictionary,
	impostor: MeshInstance3D,
	audit_script: Variant
) -> Dictionary:
	var from: Vector3 = lab._camera.global_position
	var to: Vector3 = lab._batted_ball.global_position
	var inverse: Transform3D = impostor.global_transform.affine_inverse()
	var start: Vector3 = inverse * from
	var finish: Vector3 = inverse * to
	var distance: float = from.distance_to(to)
	var front: float = maxf(0.0, distance - lab._batted_ball.radius_m)
	var result: Dictionary = {
		"world_start": Shell._supp_v(from),
		"world_finish": Shell._supp_v(to),
		"local_start": Shell._supp_v(start),
		"local_finish": Shell._supp_v(finish),
		"distance_m": distance
	}
	var sources: Dictionary = {
		"indexed": Shell._supp_indexed_faces(impostor.mesh), "get_faces": impostor.mesh.get_faces()
	}
	for representation: String in sources:
		var faces: PackedVector3Array = sources[representation]
		var measured: Dictionary = {
			"triangles": faces.size() / 3,
			"independent_hits": 0,
			"independent_near_edge_hits": 0,
			"builtin_local_hits": 0,
			"builtin_normalized_hits": 0,
			"all_independent_hits_blocked": true,
			"first_independent_hit": {}
		}
		for offset in range(0, faces.size() - 2, 3):
			var a: Vector3 = faces[offset]
			var b: Vector3 = faces[offset + 1]
			var c: Vector3 = faces[offset + 2]
			if Geometry3D.segment_intersects_triangle(start, finish, a, b, c) != null:
				measured.builtin_local_hits += 1
			if (
				Geometry3D.segment_intersects_triangle(
					start / Shell._SUPP_OUTER,
					finish / Shell._SUPP_OUTER,
					a / Shell._SUPP_OUTER,
					b / Shell._SUPP_OUTER,
					c / Shell._SUPP_OUTER
				)
				!= null
			):
				measured.builtin_normalized_hits += 1
			var hit: Dictionary = Shell._supp_independent(
				start, finish, a, b, c, 1.0 / Shell._SUPP_OUTER
			)
			if not hit.is_empty():
				measured.independent_hits += 1
				if hit.near_edge:
					measured.independent_near_edge_hits += 1
				var classification: String = (
					audit_script
					. _classify(lab, bound, impostor, distance * float(hit.t), front)
					. classification
				)
				measured.all_independent_hits_blocked = (
					measured.all_independent_hits_blocked and classification == "blocked"
				)
				if measured.first_independent_hit.is_empty():
					hit["triangle"] = offset / 3
					hit["classification"] = classification
					measured.first_independent_hit = hit
		result[representation] = measured
	var generic: Array[Dictionary] = audit_script._intersections(impostor, from, to, cache)
	var actual: Dictionary = audit_script.audit(lab, cache)
	result["generic_intersection_count"] = generic.size()
	result["actual_audit_hit_count"] = audit_script._hit_rows(actual, impostor).size()
	result["actual_audit_blocked_count"] = audit_script._count(actual, impostor, "blocked")
	result["actual_audit_self_count"] = audit_script._count(actual, impostor, "self_hits")
	result["actual_audit_invalid"] = actual.invalid
	return result

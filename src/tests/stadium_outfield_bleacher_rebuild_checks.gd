class_name StadiumOutfieldBleacherRebuildChecks
extends "res://src/tests/stadium_outfield_bleacher_rebuild_checks_scenario_base.gd"
func _terrain_matrix() -> void:
	_phase = "actual-club-mogul-rough-leveled-full-footprint-and-grounded-members"
	_check(
		(
			FileAccess.get_sha256("res://src/gameplay/stadium/stadium_surface_terrain.gd")
			== INNER_SOURCE_SHA256
		),
		"inner deterministic terrain source remains byte exact"
	)
	var root: Node3D = _world()
	for tier: String in ["club", "mogul"]:
		for mode: String in ["rough", "leveled"]:
			var access: Array[String] = []
			if mode == "leveled":
				access.append("ground_prep")
			var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
				StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, false), access
			)
			var layout: Dictionary = StadiumOutfieldBleacherItems.place(
				terrain, _paid.construction(), _copies[0], SITE, 0.0, access
			)
			var checked: Dictionary = _checked(layout, tier)
			var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
			var built: bool = property.build(tier, layout, _paid.construction())
			_check(
				(
					checked.ok
					and built
					and checked.get("live_units", -1) == 0
					and not checked.get("night_qualified", true)
				),
				(
					"actual rough or leveled Club-plus property admits paid whole bleacher "
					+ tier
					+ ":"
					+ mode
				)
			)
			if not built:
				property.free()
				continue
			root.add_child(property)
			await get_tree().physics_frame
			await get_tree().physics_frame
			var terrain_node: Node3D = property.get_node("OwnedSurfaceTerrain")
			var visual: MeshInstance3D = terrain_node.get_node("TerrainVisual")
			var terrain_shape: CollisionShape3D = (
				terrain_node.get_node("TerrainCollision/ClosedTerrainShape") as CollisionShape3D
			)
			var shape: ConcavePolygonShape3D = terrain_shape.shape
			var geometry: Dictionary = StadiumSurfaceTerrain.geometry(mode)
			var front_points: Array[Vector3] = [Vector3(-25, 0, 32), Vector3(-9, 0, 32)]
			var edge_support: Array[Dictionary] = _front_edge_support(
				property, front_points, terrain_shape
			)
			var edges_supported: bool = edge_support.size() == 2
			for edge: Dictionary in edge_support:
				edges_supported = (
					edges_supported and edge.closed_top_contains and edge.inner_faces_meet
				)
			_operands = {"case": tier + ":" + mode, "front_edge_support": edge_support}
			_check(
				(
					ClubCareer.same(
						terrain_node.get_meta("terrain"), StadiumSurfaceTerrain.contract(mode)
					)
					and visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == geometry.faces
					and shape.get_faces() == geometry.faces
					and shape.margin == 0
					and edges_supported
				),
				(
					(
						"actual inner terrain retains exact faces meeting the closed physical outer-ground "
						+ "top at both nominal front reserve corners "
					)
					+ tier
					+ ":"
					+ mode
				)
			)
			_check(
				(
					not property.has_node("MoldedSeatPad")
					and property.objects.size() == 1
					and property.props_intact()
					and property.route_obstacles().is_empty()
				),
				"actual support property adds only one complete paid assembly and no obstacle budget"
			)
			var model: Node3D = property.objects[_copies[0]]
			var excludes: Array[RID] = _body_rids(model)
			var box: AABB = StadiumOutfieldBleacherItems.bounds(
				checked.outfield_bleacher_placements[0]
			)
			var points: Array[Vector3] = [
				model.position,
				box.position,
				Vector3(box.end.x, 0, box.position.z),
				Vector3(box.position.x, 0, box.end.z),
				Vector3(box.end.x, 0, box.end.z)
			]
			var measured: Array[Dictionary] = []
			for point: Vector3 in points:
				measured.append(
					_ground_ray(root, point, excludes, "full-reservation", tier + ":" + mode)
				)
			for point: Vector3 in StadiumOutfieldBleacherModels.support_points():
				measured.append(
					_ground_ray(
						root,
						model.global_transform * point,
						excludes,
						"actual-member-base",
						tier + ":" + mode
					)
				)
			_support_matrix.append(
				{
					"item": "ST-054",
					"site": SITE,
					"tier": tier,
					"mode": mode,
					"layout_version": layout.version,
					"inner_signature": StadiumSurfaceTerrain.signature(mode),
					"paid_parents": property.objects.size(),
					"optional_pad_adopted": false,
					"query_layer": 1,
					"owned_body_rids_excluded": excludes.size(),
					"front_edge_support": edge_support,
					"rays": measured
				}
			)
			property.free()
			await get_tree().physics_frame
	await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered shared outfield bleacher qualification has an explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty() and not _deeper_layout.is_empty():
			before = _checks
			_fit_and_conflicts()
			_phase_counts.fit = _checks - before
			before = _checks
			_detached_controls()
			_phase_counts.workshop_controls = _checks - before
			_phase = "complete-source-held-outfield-bleacher-parent"
			var model_root: Node3D = _world()
			before = _checks
			await StadiumOutfieldBleacherGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_check(
				_model_checks == StadiumOutfieldBleacherGeometryRebuildChecks.expected_checks(),
				"every complete outfield bleacher geometry assertion is reached"
			)
			await _close_view()
			before = _checks
			await _terrain_matrix()
			_phase_counts.terrain_support = _checks - before
			before = _checks
			await _sightlines()
			_phase_counts.seated_sightlines = _checks - before
			before = _checks
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["outfield-bleacher-overview.png", "outfield-bleacher-details.png"],
		"exactly two native 1280 by 720 originals and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS
		+ StadiumOutfieldBleacherGeometryRebuildChecks.expected_checks()
	)
	var payload: Dictionary = {
		"checks": _checks,
		"expected_checks": expected,
		"failures": _failures,
		"images": _images,
		"games": 0,
		"synthetic_funding": true,
		"synthetic_progression": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"whole_game_acceptance_claim": false,
		"final_art_acceptance_claim": false,
		"physical_performance_claim": false,
		"gameplay_bonus_claim": false,
		"night_qualification_claim": false,
		"crowd_claim": false,
		"pedestrian_claim": false,
		"full_field_visibility_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumOutfieldBleacherGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"inherited_paid_copies": _inherited,
		"wall_copy_ids": _wall_copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"purchase_receipts": _receipts,
		"layout": _layout,
		"deeper_layout": _deeper_layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"fit_cases": _fit_cases,
		"support_matrix": _support_matrix,
		"sightline_matrix": _sightline_matrix,
		"tree_visual_witness": _tree_witness,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"runtime": _runtime,
		"synthetic_metrics": StadiumCareerProgress.metrics(_progress, _progress.size()),
		"capture_layout":
		(
			"one independently paid complete ST-054 at OF-BLEACHER-A, current SCORE-SMALL "
			+ "retained, second paid ST-054 stored"
		),
		"visibility_limits":
		{
			"target_y_m": 0.02,
			"eyes": 12,
			"targets": ["plate", "mound"],
			"straight_raw_ground_blind_depth_m": [8.029412, 8.32],
			"straight_with_0_20m_margin_blind_depth_m": [8.871429, 9.329577],
			"blind_region_note":
			(
				"Current 3.25 m wall leaves roughly 8 to 9 m of near-wall ground unseen on straight "
				+ "profile; deeper-center shadow is piecewise. No full-field, crowd or pedestrian claim."
			)
		}
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("outfield-bleacher-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined outfield bleacher evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phase_counts}
	_check(
		_checks + 1 == expected and _phase_counts == EXPECTED_PHASE_CHECKS,
		"every bounded fixture assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined outfield bleacher evidence fully writes")
		file.close()
	print(
		(
			(
				"OUTFIELD_BLEACHER_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

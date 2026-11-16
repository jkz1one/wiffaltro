extends "res://src/tests/stadium_treehouse_rebuild_checks_scenario_base.gd"
func _terrain_matrix() -> void:
	_phase = "actual-rough-leveled-whole-property-support"
	_check(
		(
			FileAccess.get_sha256("res://src/gameplay/stadium/stadium_surface_terrain.gd")
			== INNER_SOURCE_SHA256
		),
		"inner deterministic terrain source remains byte exact"
	)
	var root: Node3D = _world()
	for mode: String in ["rough", "leveled"]:
		var access: Array[String] = []
		if mode == "leveled":
			access.append("ground_prep")
		var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, false), access
		)
		for tier: String in ["expanded", "club", "mogul"]:
			var layout: Dictionary = StadiumTreehouseItems.place(
				terrain, _paid.construction(), _copies[0], SITE, 0.0, access
			)
			var checked: Dictionary = _checked(layout, tier)
			var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
			var built: bool = property.build(tier, layout, _paid.construction())
			_operands = {
				"tier": tier, "mode": mode, "built": built, "error": checked.get("error", "")
			}
			_check(
				(
					checked.ok
					and built
					and checked.get("live_units", -1) == 0
					and not checked.get("night_qualified", true)
				),
				(
					"actual rough or leveled property admits the same off-field treehouse "
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
			var shape: ConcavePolygonShape3D = (
				(terrain_node.get_node("TerrainCollision/ClosedTerrainShape") as CollisionShape3D)
				. shape
			)
			var geometry: Dictionary = StadiumSurfaceTerrain.geometry(mode)
			_check(
				(
					ClubCareer.same(
						terrain_node.get_meta("terrain"), StadiumSurfaceTerrain.contract(mode)
					)
					and visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == geometry.faces
					and shape.get_faces() == geometry.faces
					and shape.margin == 0
				),
				(
					"actual inner terrain retains exact visual and collision source faces "
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
				(
					"actual dirt property adds only the selected complete paid parent "
					+ tier
					+ ":"
					+ mode
				)
			)
			var model: Node3D = property.objects[_copies[0]]
			var excludes: Array[RID] = _body_rids(model)
			var box: AABB = StadiumTreehouseItems.bounds(checked.treehouse_placements[0])
			var points: Array[Vector3] = [
				Vector3(-29, 0, 20),
				box.position,
				Vector3(box.end.x, 0, box.position.z),
				Vector3(box.position.x, 0, box.end.z),
				Vector3(box.end.x, 0, box.end.z),
				Vector3(-26.01, 0, 20),
				Vector3(-25.99, 0, 20)
			]
			var measured: Array[Dictionary] = []
			for index in range(points.size()):
				measured.append(
					_ground_ray(
						root,
						points[index],
						excludes,
						"center-corner" if index < 5 else "outer-inner-seam",
						tier + ":" + mode + ":" + str(index)
					)
				)
			_support_matrix.append(
				{
					"tier": tier,
					"mode": mode,
					"layout_version": layout.version,
					"inner_signature": StadiumSurfaceTerrain.signature(mode),
					"paid_parents": property.objects.size(),
					"optional_pad_adopted": false,
					"query_layer": 1,
					"owned_body_rids_excluded": excludes.size(),
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
		"one rendered shared treehouse qualification has an explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty():
			before = _checks
			_fit_and_conflicts()
			_phase_counts.fit = _checks - before
			before = _checks
			_detached_controls()
			_phase_counts.workshop_controls = _checks - before
			_phase = "complete-source-held-treehouse-parent"
			var model_root: Node3D = _world()
			before = _checks
			await StadiumTreehouseGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumTreehouseGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumTreehouseGeometryRebuildChecks.expected_checks(),
				"every complete treehouse geometry assertion is reached"
			)
			await _close_view()
			before = _checks
			await _terrain_matrix()
			_phase_counts.terrain_support = _checks - before
			before = _checks
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["treehouse-overview.png", "treehouse-details.png"],
		"exactly two native 1280 by 720 originals and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumTreehouseGeometryRebuildChecks.expected_checks()
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
		"connected_pedestrian_route_claim": false,
		"climbing_claim": false,
		"gameplay_bonus_claim": false,
		"night_qualification_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumTreehouseGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"inherited_paid_copies": _inherited,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"fit_cases": _fit_cases,
		"support_matrix": _support_matrix,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"runtime": _runtime,
		"synthetic_metrics": StadiumCareerProgress.metrics(_progress, _progress.size()),
		"capture_layout":
		(
			"one exact paid ST-045 at TREEHOUSE-A; bundled support tree, cabin, platform, ladder "
			+ "and railings"
		),
		"clearance_rule":
		(
			"complete 6 by 6 by 7 m reservation; selected pad overlap 15 square metres and ramp "
			+ "overlap 4; empty-pad removal is explicit"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("treehouse-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined treehouse evidence opens")
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
			_check(false, "combined treehouse evidence fully writes")
		file.close()
	print(
		(
			(
				"TREEHOUSE_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

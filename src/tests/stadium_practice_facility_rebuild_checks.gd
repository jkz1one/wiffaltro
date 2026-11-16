extends "res://src/tests/stadium_practice_facility_rebuild_checks_scenario_base.gd"
func _runtime_and_views() -> void:
	_phase = "ordinary-registered-family31-property"
	var root: Node3D = _world()
	var lab: PitchBatLab = PitchBatLab.new()
	root.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batter_avatar.set_process(false)
	lab._pitcher_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = _snapshot.duplicate(true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	_operands = {
		"installed": installed,
		"layout_version": _layout.get("version", -1),
		"snapshot_version": _snapshot.get("version", -1)
	}
	_check(installed, "ordinary frozen paid snapshot installs actual complete family31 property")
	if not installed:
		await _close_view()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var boundary: StadiumBoundaryOwnedRuntime = (
		property.get_node_or_null("BoundaryGraph") as StadiumBoundaryOwnedRuntime
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		(
			boundary != null
			and boundary.intact()
			and property.props_intact()
			and StadiumBoundaryRuntime.installed(lab, _snapshot)
		),
		"actual property and paid boundary identity seals remain intact"
	)
	var checked: Dictionary = _checked(_layout)
	var inspected: Array[Dictionary] = []
	for row: Dictionary in checked.practice_facility_placements:
		var model: Node3D = property.objects.get(row.copy)
		var exact: bool = (
			is_instance_valid(model)
			and model.get_meta("stadium_item", "") == row.item
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == row.site
		)
		_operands = {
			"copy": row.copy,
			"item": row.item,
			"site": row.site,
			"model_valid": is_instance_valid(model)
		}
		_check(
			(
				exact
				and model.position == row.position
				and is_zero_approx(model.rotation.y)
				and model.scale == Vector3.ONE
			),
			"actual complete purchased parent retains exact identity and full-size pose " + row.site
		)
		if not exact:
			continue
		var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
		var roles: bool = not bodies.is_empty()
		for body: Node in bodies:
			roles = (
				roles
				and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
				and body.get_meta("owned_copy", "") == row.copy
				and body.get_meta("ball_surface", &"") == &"stadium_scenery"
				and not body is Area3D
			)
		_check(
			roles,
			(
				"every real facility body is owned after-terminal scenery with no receiver Area "
				+ row.site
			)
		)
		_check(
			(
				property.route_obstacles().all(
					func(route: Dictionary) -> bool: return route.copy != row.copy
				)
				and StadiumPracticeFacilityItems._outside_play(
					StadiumPracticeFacilityItems.bounds(row),
					StadiumPracticeFacilityItems.graph_for(_layout)
				)
			),
			(
				"actual navigation obstacle list and whole footprint keep facility out of live play "
				+ row.site
			)
		)
		var static_only: bool = (
			model.find_children("*", "AnimationPlayer", true, false).is_empty()
			and model.find_children("*", "RigidBody3D", true, false).is_empty()
		)
		for child: Node in [model] + model.find_children("*", "", true, false):
			static_only = (
				static_only and not child.is_processing() and not child.is_physics_processing()
			)
		_check(
			static_only,
			(
				"complete facility has no active practice animation, live practice ball or actor process "
				+ row.site
			)
		)
		var surface: String = str(bodies[0].name) if not bodies.is_empty() else ""
		var events: Array = [
			{
				"source": "item",
				"id": row.copy,
				"surface": surface,
				"role": "LIVE_RICOCHET",
				"position": _v3(row.position + Vector3.UP * 0.5),
				"time": 0.1,
				"kind": "contact"
			}
		]
		_check(
			not PhysicalStadiumContacts.valid(
				[{"play": 0, "reason": "", "events": events}],
				[
					{
						"result": "single",
						"contact": ContactResult.Outcome.CONTACT,
						"exit_speed": 12.0
					}
				],
				_snapshot
			),
			(
				"ordinary contact report refuses fabricated live scoring against actual facility body "
				+ row.site
			)
		)
		inspected.append(
			{
				"copy": row.copy,
				"item": row.item,
				"site": row.site,
				"position": _v3(row.position),
				"physical_scenery_bodies": bodies.size(),
				"active_animation": not static_only,
				"live_route_obstacle": false,
				"false_live_surface": surface
			}
		)
	_check(
		(
			inspected.size() == 2
			and property.objects.size() == 2
			and checked.get("live_units", -1) == 0
		),
		"registered property contains precisely two independent paid parents and zero live units"
	)
	_check(
		(
			not property.has_node("MoldedSeatPad")
			and not _layout.has("molded_seats")
			and _layout.ground_boxes.is_empty()
		),
		"practice-only installation adds neither optional pad nor free ground boxes"
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = baseline.build("mogul", _empty, _paid.construction())
	_check(
		built and baseline.objects.is_empty() and not baseline.has_node("MoldedSeatPad"),
		"ordinary empty practice plan has no free parent or optional infrastructure"
	)
	_check(
		(
			built
			and property.route_obstacles() == baseline.route_obstacles()
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
		),
		"actual fielder keeps the unchanged empty-plan obstacle route"
	)
	baseline.free()
	var inherited_property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var inherited_built: bool = inherited_property.build(
		"club", _records[1].layout, _paid.construction()
	)
	_check(
		(
			inherited_built
			and inherited_property.has_node("MoldedSeatPad")
			and inherited_property.props_intact()
			and inherited_property.objects.size() == 3
			and inherited_property.objects.has(_inherited["ST-052"])
			and inherited_property.objects.has(_inherited["ST-051"])
			and inherited_property.objects.has(_copies[0])
		),
		(
			"actual preserved plan retains paid ground box, optional pad and seat alongside the "
			+ "complete Club facility"
		)
	)
	inherited_property.free()
	_check(
		(
			PhysicalStadiumContacts.valid([], [], _snapshot)
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		"zero-play native install invents no contact, scoring, training or performance result"
	)
	_runtime = {
		"ordinary_install": installed,
		"models": inspected,
		"paid_complete_parents": 2,
		"optional_pad_adopted": false,
		"live_units": checked.get("live_units", -1),
		"route_obstacles": property.route_obstacles().size(),
		"zero_play_report_valid": true,
		"false_live_surface_claims_rejected": 2
	}
	_camera_clearance(lab, checked.practice_facility_placements)
	await _preview_focus()
	await _views(root, property)
	_check(
		(
			property.props_intact()
			and boundary != null
			and boundary.intact()
			and lab._play_records.is_empty()
		),
		"native views and focus preserve complete registered installation without games"
	)
	await _close_view()


func _terrain_matrix() -> void:
	_phase = "actual-current-rough-and-leveled-ground-support"
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
		for tier: String in ["club", "mogul"]:
			var layout: Dictionary = StadiumPracticeFacilityItems.place(
				terrain,
				_paid.construction(),
				_copies[0],
				SITES[0] if tier == "club" else SITES[1],
				0.0,
				access
			)
			if tier == "mogul":
				layout = StadiumPracticeFacilityItems.place(
					layout, _paid.construction(), _copies[2], SITES[2], 0.0, access
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
					"actual dirt property admits only supported decorative practice parents "
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
					"actual inner visual and collision terrain retain exact source faces "
					+ tier
					+ ":"
					+ mode
				)
			)
			_check(
				(
					not property.has_node("MoldedSeatPad")
					and property.objects.size() == (1 if tier == "club" else 2)
					and property.props_intact()
					and property.route_obstacles().is_empty()
				),
				(
					"dirt property has only selected paid parents and no optional pad or live route obstacle "
					+ tier
					+ ":"
					+ mode
				)
			)
			var excludes: Array[RID] = []
			for model: Node3D in property.objects.values():
				for body: Node in model.find_children("*", "CollisionObject3D", true, false):
					excludes.append((body as CollisionObject3D).get_rid())
			var measured: Array[Dictionary] = []
			for row: Dictionary in checked.practice_facility_placements:
				var box: AABB = StadiumPracticeFacilityItems.bounds(row)
				var points: Array[Vector3] = [
					row.position,
					box.position,
					Vector3(box.end.x, 0, box.position.z),
					Vector3(box.position.x, 0, box.end.z),
					Vector3(box.end.x, 0, box.end.z)
				]
				for point: Vector3 in points:
					var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
						point + Vector3.UP * 8, point - Vector3.UP, 1, excludes
					)
					var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
						query
					)
					var ground: Node = hit.get("collider")
					_operands = {
						"tier": tier,
						"mode": mode,
						"site": row.site,
						"point": _v3(point),
						"actual_y": hit.position.y if not hit.is_empty() else null,
						"normal": _v3(hit.normal) if not hit.is_empty() else [],
						"collider": str(ground.name) if ground != null else ""
					}
					_check(
						(
							not hit.is_empty()
							and ground != null
							and ground.get_meta("ball_surface", &"") == &"ground"
							and str(ground.name).begins_with("OuterPropertyGround")
							and absf(hit.position.y) < 0.0003
							and hit.normal.is_equal_approx(Vector3.UP)
						),
						(
							"actual outer-property ground supports reserved center or corner "
							+ tier
							+ ":"
							+ mode
							+ ":"
							+ row.site
						)
					)
					measured.append(_operands.duplicate(true))
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
		"one rendered shared practice-facility qualification has an explicit output directory"
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
			_phase = "complete-source-held-practice-parents"
			var model_root: Node3D = _world()
			before = _checks
			await StadiumPracticeFacilityGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumPracticeFacilityGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumPracticeFacilityGeometryRebuildChecks.expected_checks(),
				"every complete parent geometry assertion is reached"
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
		_images == ["practice-facility-overview.png", "practice-facility-details.png"],
		"exactly two native 1280 by 720 originals and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS
		+ StadiumPracticeFacilityGeometryRebuildChecks.expected_checks()
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
		"training_stat_income_mechanics": false,
		"active_practice_animation": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumPracticeFacilityGeometryRebuildChecks.expected_checks(),
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
		"inner_terrain_source_sha256": INNER_SOURCE_SHA256,
		"capture_layout":
		"two independently paid complete parents: ST-060 at PRACTICE-M1 and ST-061 at PRACTICE-M2",
		"clearance_rule":
		(
			"complete 4.5 by 10.5 m reservations; Club conflicts with M1 by 8 and M2 by 16 square "
			+ "metres; Mogul lane gap 1.5 m"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("practice-facility-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined practice-facility evidence opens")
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
			_check(false, "combined practice-facility evidence fully writes")
		file.close()
	print(
		(
			(
				"PRACTICE_FACILITY_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

extends "res://src/tests/stadium_wall_top_terrace_rebuild_checks_scenario_base.gd"
func _view_capture(root: Node3D, property: StadiumPropertyGeometry, host: String) -> Dictionary:
	_phase = "two-native-whole-assembly-originals:" + host
	var overview: bool = host == "ST-065"
	# This root already contains the ordinary lab Sun/environment. _studio would
	# add a second directional source and overexpose the unchanged pale materials.
	var lights: Array[Node] = root.find_children("*", "DirectionalLight3D", true, false)
	var environments: Array[Node] = root.find_children("*", "WorldEnvironment", true, false)
	var sun: DirectionalLight3D = lights[0] as DirectionalLight3D if lights.size() == 1 else null
	var world: WorldEnvironment = (
		environments[0] as WorldEnvironment if environments.size() == 1 else null
	)
	var lighting: Dictionary = {
		"directional_lights": lights.size(),
		"world_environments": environments.size(),
		"sun_name": str(sun.name) if sun != null else "",
		"sun_energy": sun.light_energy if sun != null else -1.0,
		"environment_name": str(world.name) if world != null else "",
		"ambient_energy": world.environment.ambient_light_energy if world != null else -1.0,
		"tonemap_mode": world.environment.tonemap_mode if world != null else -1,
		"tonemap_exposure": world.environment.tonemap_exposure if world != null else -1.0,
		"studio_light_added": false,
		"heading_backing_rect": [10, 10, 1260, 94]
	}
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(72, 65, -62) if overview else Vector3(35, 16, 45)
	camera.look_at(Vector3(0, 1, 13) if overview else Vector3(15, 2.0, 26.9))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 76 if overview else 21
	camera.make_current()
	var heading: ColorRect = ColorRect.new()
	heading.position = Vector2(10, 10)
	heading.size = Vector2(1260, 94)
	heading.color = Color(0.06, 0.10, 0.13, 0.94)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	_label(
		root, "WALL-TOP TERRACE | Complete paid ST-087 + " + host + " hosts", Vector2(22, 18), 23
	)
	_label(
		root,
		(
			"Six exact hosts in a complete 23-copy paid wall | whole deck, guards, rear supports "
			+ "and local access"
		),
		Vector2(22, 50),
		16
	)
	_label(
		root,
		(
			"Working static scenery | synthetic funding and progression | no crowd, pedestrian or "
			+ "final-art claim"
		),
		Vector2(22, 77),
		16
	)
	camera.reset_physics_interpolation()
	camera.force_update_transform()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var model: Node3D = property.objects[_copies[0]]
	_operands = {"host_item": host, "capture_lighting": lighting}
	_check(
		(
			lights.size() == 1
			and environments.size() == 1
			and sun != null
			and world != null
			and str(sun.name) == "Sun"
			and str(world.name) == "LabWorldEnvironment"
			and _in_frame(
				camera, model.global_transform * StadiumWallTopTerraceModels.visible_bounds()
			)
			and property.props_intact()
		),
		(
			(
				"single ordinary lab lighting and native capture retain every complete-assembly "
				+ "corner and exact materials "
			)
			+ host
		)
	)
	if overview:
		var visible: bool = true
		for point: Vector2 in StadiumWallTopTerraceItems.graph_for(_layouts[host]).polygon():
			visible = (
				visible
				and not camera.is_position_behind(Vector3(point.x, 0, point.y))
				and Rect2(10, 105, 1260, 575).has_point(
					camera.unproject_position(Vector3(point.x, 0, point.y))
				)
			)
		_check(
			visible,
			"overview contains entire actual complete field boundary and paid terrace together"
		)
	await _capture("wall-top-terrace-overview.png" if overview else "wall-top-terrace-details.png")
	return lighting


func _runtime_and_views() -> void:
	for host: String in HOST_ITEMS:
		_phase = "ordinary-registered-install:" + host
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
		lab._match_state.stadium = _snapshots[host].duplicate(true)
		lab._stadium_ledger = _paid
		var installed: bool = StadiumPropertyRuntime.install_bound(lab)
		_check(
			installed, "ordinary frozen paid family36 snapshot installs complete terrace " + host
		)
		if not installed:
			await RenderingServer.frame_post_draw
			await _close_view()
			continue
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
				and StadiumBoundaryRuntime.installed(lab, _snapshots[host])
			),
			"actual complete owned wall and property identity seals remain intact " + host
		)
		if boundary == null:
			await RenderingServer.frame_post_draw
			await _close_view()
			continue
		var model: Node3D = property.objects[_copies[0]]
		var inspected: Dictionary = _runtime_model(root, lab, property, boundary, model, host)
		_check(
			(
				property.objects.size() == 1
				and property.route_obstacles().is_empty()
				and lab._primary_fielder.stadium_obstacles.is_empty()
				and not property.has_node("MoldedSeatPad")
			),
			(
				"ordinary install has only complete terrace and no new live-object fielder budget "
				+ host
			)
		)
		_check(
			(
				PhysicalStadiumContacts.valid([], [], _snapshots[host])
				and lab._play_records.is_empty()
				and lab._batted_ball == null
			),
			"zero-play installation invents no scoring or performance result " + host
		)
		await _camera_clearance(lab, model, host)
		await _preview_focus(host)
		var flights: Array[Dictionary] = []
		for above: bool in [false, true]:
			flights.append(await _moving_wall_ball(lab, property, model, host, above))
		var capture_lighting: Dictionary = await _view_capture(root, property, host)
		_check(
			boundary.intact() and property.props_intact() and lab._play_records.is_empty(),
			(
				"two native flight probes preserve complete installation without completing a game "
				+ host
			)
		)
		_runtime.append(
			{
				"host_item": host,
				"ordinary_install": installed,
				"paid_complete_parents": property.objects.size(),
				"complete_wall_copies": _layouts[host].walls.back.copies.size(),
				"model": inspected,
				"flights": flights,
				"capture_lighting": capture_lighting,
				"zero_play_report_valid": true,
				"full_match_wrapper_claim": false,
				"games": 0
			}
		)
		# A lab created and destroyed before a draw leaks GL resources on this runner.
		# Drain the completed frame before releasing the lab's containing viewport.
		await RenderingServer.frame_post_draw
		await _close_view()


func _body_rids(model: Node3D) -> Array[RID]:
	var result: Array[RID] = []
	for body: Node in model.find_children("*", "CollisionObject3D", true, false):
		result.append((body as CollisionObject3D).get_rid())
	return result


func _support_checks() -> void:
	_phase = "ordinary-flat-ground-and-six-native-host-saddles"
	_check(
		(
			FileAccess.get_sha256("res://src/gameplay/stadium/stadium_surface_terrain.gd")
			== INNER_SOURCE_SHA256
		),
		"deterministic inner terrain source remains byte exact"
	)
	var root: Node3D = _world()
	for host: String in HOST_ITEMS:
		for tier: String in SUPPORTED_TIERS:
			for copy: String in _copies:
				var layout: Dictionary = _place(
					StadiumWallTopTerraceItems.store_copy(_layouts[host], _copies[0]), copy
				)
				var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
				var built: bool = property.build(tier, layout, _paid.construction())
				_check(
					built and _checked(layout, tier).ok,
					(
						"ordinary flat property builds complete paid assembly and wall "
						+ host
						+ ":"
						+ tier
					)
				)
				if not built:
					property.free()
					continue
				root.add_child(property)
				var boundary: StadiumBoundaryOwnedRuntime = (
					StadiumBoundaryRuntime.assemble(property) as StadiumBoundaryOwnedRuntime
				)
				await get_tree().physics_frame
				await get_tree().physics_frame
				var model: Node3D = property.objects[copy]
				_check(
					(
						boundary != null
						and boundary.intact()
						and property.props_intact()
						and property.objects.size() == 1
						and property.route_obstacles().is_empty()
						and not property.has_node("MoldedSeatPad")
					),
					(
						(
							"complete flat-ground support fixture retains exact wall roles and no optional pad "
							+ "or live units "
						)
						+ host
						+ ":"
						+ tier
					)
				)
				var excludes: Array[RID] = _body_rids(model)
				var rays: Array[Dictionary] = []
				for index in range(GROUND_POINTS.size()):
					var point: Vector3 = model.global_transform * GROUND_POINTS[index]
					var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
						PhysicsRayQueryParameters3D.create(
							point + Vector3.UP * 0.1, point - Vector3.UP * 0.1, 1, excludes
						)
					)
					var body: Node = hit.get("collider")
					var supported: bool = (
						body != null
						and body.get_meta("ball_surface", &"") == &"ground"
						and absf(hit.position.y) < 0.0003
						and hit.normal.is_equal_approx(Vector3.UP)
					)
					var measured: Dictionary = {
						"kind": "representative-ground-access",
						"index": index,
						"point": _v3(point),
						"collider": str(body.name) if body != null else "",
						"normal": _v3(hit.normal) if body != null else [],
						"actual_y": hit.position.y if body != null else null,
						"supported": supported
					}
					_operands = {"host": host, "tier": tier, "ray": measured}
					_check(
						supported,
						(
							"actual rear foot or access base bears on native upward ground "
							+ host
							+ ":"
							+ tier
							+ ":"
							+ str(index)
						)
					)
					rays.append(measured)
				var placement: Dictionary = _checked(layout, tier).wall_top_terrace_placements[0]
				for index in range(6):
					var local: Vector3 = Vector3(
						-5 + index * 2, 3.25, 0.28 if host == "ST-065" else 0.185
					)
					var point: Vector3 = model.global_transform * local
					var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(
						PhysicsRayQueryParameters3D.create(
							point + Vector3.UP * 0.05, point - Vector3.UP * 0.05, 1, excludes
						)
					)
					var body: Node = hit.get("collider")
					var supported: bool = (
						body != null
						and body.get_meta("surface_role", "") == "BACK_WALL_TERMINAL"
						and absf(hit.position.y - 3.25) < 0.0003
						and hit.normal.is_equal_approx(Vector3.UP)
					)
					var saddle: Node3D = model.get_node("Collision/HostSaddle%d" % index)
					var measured: Dictionary = {
						"kind": "actual-host-saddle",
						"index": index,
						"point": _v3(point),
						"host_copy": placement.host_copies[5 - index],
						"host_socket": placement.host_sockets[5 - index],
						"saddle": str(saddle.name),
						"collider": str(body.name) if body != null else "",
						"role": body.get_meta("surface_role", "") if body != null else "",
						"normal": _v3(hit.normal) if body != null else [],
						"actual_y": hit.position.y if body != null else null,
						"supported": supported
					}
					_operands = {"host": host, "tier": tier, "ray": measured}
					_check(
						(
							supported
							and saddle.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
						),
						(
							"exact actual saddle meets native terminal host top with upward normal "
							+ host
							+ ":"
							+ tier
							+ ":"
							+ str(index)
						)
					)
					rays.append(measured)
				_support_matrix.append(
					{
						"host_item": host,
						"tier": tier,
						"terrace_copy": copy,
						"ground_mode": "ordinary-flat",
						"layout_version": 36,
						"paid_parents": property.objects.size(),
						"complete_wall_copies": layout.walls.back.copies.size(),
						"host_copies": placement.host_copies,
						"socket_profile": StadiumWallTopTerraceModels.socket_profile(host),
						"query_layer": 1,
						"owned_body_rids_excluded": excludes.size(),
						"rays": rays
					}
				)
				await RenderingServer.frame_post_draw
				property.free()
				await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered combined terrace qualification has an explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		var stage_started: int = _timing_mark("ownership", "begin")  # TERRACE_TIMING_ONLY
		_ownership()
		_timing_mark("ownership", "end", stage_started)  # TERRACE_TIMING_ONLY
		_phase_counts.ownership = _checks - before
		if _layouts.size() == 2 and _snapshots.size() == 2:
			before = _checks
			stage_started = _timing_mark("fit", "begin")  # TERRACE_TIMING_ONLY
			_fit_and_conflicts()
			_timing_mark("fit", "end", stage_started)  # TERRACE_TIMING_ONLY
			_phase_counts.fit = _checks - before
			before = _checks
			stage_started = _timing_mark("workshop", "begin")  # TERRACE_TIMING_ONLY
			_detached_controls()
			_timing_mark("workshop", "end", stage_started)  # TERRACE_TIMING_ONLY
			_phase_counts.workshop_controls = _checks - before
			_phase = "complete-indexed-terrace-geometry"
			var root: Node3D = _world()
			before = _checks
			stage_started = _timing_mark("geometry", "begin")  # TERRACE_TIMING_ONLY
			await StadiumWallTopTerraceGeometryRebuildChecks.run(root, _check)
			_timing_mark("geometry", "end", stage_started)  # TERRACE_TIMING_ONLY
			_model_checks = _checks - before
			_check(
				_model_checks == StadiumWallTopTerraceGeometryRebuildChecks.expected_checks(),
				"all finite detailed model assertions are reached"
			)
			await RenderingServer.frame_post_draw
			await _close_view()
			before = _checks
			stage_started = _timing_mark("support", "begin")  # TERRACE_TIMING_ONLY
			await _support_checks()
			_timing_mark("support", "end", stage_started)  # TERRACE_TIMING_ONLY
			_phase_counts.support = _checks - before
			before = _checks
			stage_started = _timing_mark("runtime-and-views", "begin")  # TERRACE_TIMING_ONLY
			await _runtime_and_views()
			_timing_mark("runtime-and-views", "end", stage_started)  # TERRACE_TIMING_ONLY
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["wall-top-terrace-overview.png", "wall-top-terrace-details.png"],
		"exactly two native 1280 by 720 originals and zero complete games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumWallTopTerraceGeometryRebuildChecks.expected_checks()
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
		"crowd_claim": false,
		"full_field_visibility_claim": false,
		"gameplay_bonus_claim": false,
		"night_qualification_claim": false,
		"new_terrain_admission_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumWallTopTerraceGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"wall_copy_ids": _wall_copies,
		"control_copy_ids": _controls,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"purchase_receipts": _receipts,
		"layouts": _layouts,
		"snapshots": _snapshots,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"fit_cases": _fit_cases,
		"support_matrix": _support_matrix,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"runtime": _runtime,
		"synthetic_metrics": StadiumCareerProgress.metrics(_progress, _progress.size()),
		"terrain_dispatch": _terrain_dispatch,
		"capture_layout":
		(
			"one exact paid ST-087 and complete 23-copy straight paid wall; six designated exact "
			+ "hosts; second terrace copy stored"
		),
		"support_scope":
		(
			"ordinary flat ground, Club/Mogul, both exact paid terrace copies, two uniform host "
			+ "profiles; four representative ground/access points and six actual saddle bearings each"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence remains within 128 KiB"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("wall-top-terrace-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined terrace evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phase_counts}
	_check(
		_checks + 1 == expected and _phase_counts == EXPECTED_PHASE_CHECKS,
		"every frozen bounded assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined terrace evidence fully writes")
		file.close()
	print(
		(
			(
				"WALL_TOP_TERRACE_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

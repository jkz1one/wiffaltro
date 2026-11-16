extends "res://src/tests/stadium_player_tunnel_rebuild_checks_fixture_base.gd"
func _passage_support(root: Node3D, property: StadiumPropertyGeometry, hand: String) -> Dictionary:
	_phase = "native-installed-passage-ground-and-restored-caps:" + hand
	var left: bool = hand == "L"
	var model: Node3D = property.objects[_copies[ITEM][HANDS.find(hand)]]
	var points: PackedVector3Array = StadiumPlayerTunnelModels.path_points(left)
	var paths: Array[Dictionary] = []
	var supports: Array[Dictionary] = []
	var caps: Array[Dictionary] = []
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	for height: float in [0.5, 2.05]:
		for index: int in range(points.size() - 1):
			var from: Vector3 = (
				model.global_transform * Vector3(points[index].x, height, points[index].z)
			)
			var to: Vector3 = (
				model.global_transform * Vector3(points[index + 1].x, height, points[index + 1].z)
			)
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			var sphere: SphereShape3D = SphereShape3D.new()
			sphere.radius = 0.30
			sphere.margin = 0
			query.shape = sphere
			query.margin = 0
			query.transform.origin = from
			query.motion = to - from
			query.collision_mask = 1
			var initial: Array[Dictionary] = space.intersect_shape(query, 1)
			var sweep: PackedFloat32Array = space.cast_motion(query)
			var clear: bool = initial.is_empty() and sweep[0] >= 0.9999
			_operands = {
				"hand": hand,
				"segment": index,
				"height": height,
				"initial_hits": initial.size(),
				"safe_fraction": sweep[0]
			}
			_check(
				clear,
				(
					"actual 0.60m diameter physical clearance through rear opening turn and stand port "
					+ hand
					+ ":"
					+ str(height)
					+ ":"
					+ str(index)
				)
			)
			paths.append(
				{
					"segment": index,
					"height": height,
					"radius": 0.30,
					"from": _v3(from),
					"to": _v3(to),
					"initial_hits": initial.size(),
					"safe_fraction": sweep[0],
					"clear": clear
				}
			)
	var excluded: Array[RID] = []
	for node: Node in property.objects.values():
		for body: Node in node.find_children("*", "CollisionObject3D", true, false):
			excluded.append((body as CollisionObject3D).get_rid())
	var ground_points: PackedVector3Array = points.duplicate()
	ground_points.append_array(StadiumPlayerTunnelModels.support_points())
	for index: int in range(ground_points.size()):
		var point: Vector3 = ground_points[index]
		var world: Vector3 = model.global_transform * Vector3(point.x, 0, point.z)
		var hit: Dictionary = space.intersect_ray(
			PhysicsRayQueryParameters3D.create(
				world + Vector3.UP * 0.12, world - Vector3.UP * 0.12, 1, excluded
			)
		)
		var body: Node = hit.get("collider")
		var supported: bool = (
			body != null
			and body.get_meta("ball_surface", &"") == &"ground"
			and absf(hit.position.y) < 0.0003
			and hit.normal.is_equal_approx(Vector3.UP)
		)
		_operands = {
			"hand": hand, "point": _v3(world), "collider": str(body.name) if body != null else ""
		}
		_check(
			supported,
			(
				"route and every authored shell support bear on native upward flat ground "
				+ hand
				+ ":"
				+ str(point)
			)
		)
		supports.append(
			{
				"kind": "presentation-route" if index < 4 else "shell-support",
				"index": index,
				"point": _v3(world),
				"collider": str(body.name) if body != null else "",
				"normal": _v3(hit.normal) if body != null else [],
				"actual_y": hit.position.y if body != null else null,
				"supported": supported
			}
		)
	for active: bool in [true, false]:
		var checked_left: bool = left if active else not left
		for port: String in ["dugout-rear", "stand-end"]:
			var from: Vector3 = (
				StadiumDugoutRecipe.rail_point(
					11 if port == "dugout-rear" else 11.7,
					2.2 if port == "dugout-rear" else 6,
					checked_left
				)
				+ Vector3.UP * 1.2
			)
			var to: Vector3 = (
				StadiumDugoutRecipe.rail_point(
					11 if port == "dugout-rear" else 12.5,
					2.8 if port == "dugout-rear" else 6,
					checked_left
				)
				+ Vector3.UP * 1.2
			)
			var hit: Dictionary = space.intersect_ray(
				PhysicsRayQueryParameters3D.create(from, to, 1)
			)
			var body: Node = hit.get("collider")
			_check(
				hit.is_empty() == active,
				(
					"actual active interface opens and opposite stored-host finished cap closes "
					+ hand
					+ ":"
					+ port
					+ ":"
					+ str(active)
				)
			)
			caps.append(
				{
					"port": port,
					"left": checked_left,
					"active": active,
					"from": _v3(from),
					"to": _v3(to),
					"blocked": not hit.is_empty(),
					"collider": str(body.name) if body != null else ""
				}
			)
	return {
		"paths": paths,
		"ground_support": supports,
		"interfaces": caps,
		"path_simulation_claim": false
	}


func _preview_focus(hand: String) -> void:
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(
		_layouts[hand], _paid.construction(), true, "mogul", null, null, _paid.surface_owned()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.night_eligible
		),
		"actual Workshop builds exact paid tunnel hosts and caps in daylight " + hand
	)
	var copy: String = _copies[ITEM][HANDS.find(hand)]
	preview.focus_copy(copy)
	preview.camera.reset_physics_interpolation()
	preview.camera.force_update_transform()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
	var box: AABB = preview.board_bounds.get(copy, AABB())
	var contained: bool = preview.board_bounds.has(copy) and rect.has_area()
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		contained = (
			contained
			and not preview.camera.is_position_behind(point)
			and rect.has_point(preview.camera.unproject_position(point))
		)
	_check(contained, "actual owned-copy focus contains all complete reservation corners " + hand)
	_focus.append(
		{
			"hand": hand,
			"copy": copy,
			"all_eight_corners_in_frame": contained,
			"night_eligible": preview.night_eligible
		}
	)
	await RenderingServer.frame_post_draw
	preview.queue_free()
	await get_tree().process_frame


func _runtime_model(
	lab: PitchBatLab, property: StadiumPropertyGeometry, model: Node3D, hand: String
) -> Dictionary:
	var row: Dictionary = _checked(_layouts[hand]).player_tunnel_placements[0]
	_check(
		(
			model.get_meta("stadium_item", "") == ITEM
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == row.site
			and model.position.is_equal_approx(row.position)
			and model.scale.is_equal_approx(Vector3.ONE)
			and model.transform.basis.determinant() > 0.9999
		),
		(
			"actual whole tunnel retains exact paid identity positive rigid frame and full scale "
			+ hand
		)
	)
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = not bodies.is_empty()
	for body: Node in bodies:
		roles = (
			roles
			and body is StaticBody3D
			and body.get_meta("owned_copy", "") == row.copy
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
		)
	_check(
		roles and model.find_children("*", "Area3D", true, false).is_empty(),
		"all tunnel solids are after-terminal scenery without scoring receiver Areas " + hand
	)
	var static_only: bool = (
		model.find_children("*", "AnimationPlayer", true, false).is_empty()
		and model.find_children("*", "RigidBody3D", true, false).is_empty()
	)
	for node: Node in [model] + model.find_children("*", "", true, false):
		static_only = static_only and not node.is_processing() and not node.is_physics_processing()
	_check(static_only, "whole assembly remains static with no walkout or crowd simulation " + hand)
	var old_position: Vector3 = model.position
	model.position.x += 0.01
	var moved_rejected: bool = not property.props_intact()
	model.position = old_position
	_check(
		moved_rejected and property.props_intact(),
		"current-copy seal rejects moved tunnel and accepts exact restoration " + hand
	)
	var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var tracked: bool = true
	var count: int = 0
	for node: Node in model.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		if box.size.y > 0.025:
			count += 1
			tracked = tracked and tracking._obstacles.has(box)
	_check(
		count > 0 and tracked and tracking._owned_receiver_models.is_empty(),
		"ordinary tracking contains every qualifying visible tunnel member " + hand
	)
	return {
		"copy": row.copy,
		"item": ITEM,
		"dugout": row.dugout,
		"lower": row.lower,
		"physical_scenery_bodies": bodies.size(),
		"static_only": static_only,
		"moved_seal_rejected": moved_rejected,
		"tracking_mesh_bounds": count,
		"tracking_collected": tracked
	}


func _in_frame(camera: Camera3D, box: AABB) -> bool:
	var readable: Rect2 = Rect2(12, 110, 1256, 565)
	for index: int in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if (
			camera.is_position_behind(point)
			or not readable.has_point(camera.unproject_position(point))
		):
			_operands = {"corner": _v3(point), "pixel": str(camera.unproject_position(point))}
			return false
	return true


func _view_capture(root: Node3D, property: StadiumPropertyGeometry, hand: String) -> Dictionary:
	_phase = "two-native-whole-assembly-originals:" + hand
	var overview: bool = hand == "R"
	# Ordinary PitchBatLab already supplies Sun and LabWorldEnvironment; no _studio.
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
	camera.position = (
		Vector3(52, 52, -52)
		if overview
		else StadiumDugoutRecipe.rail_point(6, 14, true) + Vector3.UP * 8
	)
	camera.look_at(
		(
			Vector3(0, 1, 10)
			if overview
			else StadiumDugoutRecipe.rail_point(12.5, 4.5, true) + Vector3.UP * 2.1
		)
	)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 68 if overview else 17
	camera.make_current()
	var heading: ColorRect = ColorRect.new()
	heading.position = Vector2(10, 10)
	heading.size = Vector2(1260, 94)
	heading.color = Color(0.06, 0.10, 0.13, 0.94)
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(heading)
	_label(
		root,
		"COVERED PLAYER TUNNEL | Exact paid ST-058 + ST-074 + BASE1 ST-029 | " + hand,
		Vector2(22, 18),
		23
	)
	_label(
		root,
		(
			"Complete roof, closed unused port, supported turn and named host openings | opposite "
			+ "hosts capped"
		),
		Vector2(22, 50),
		16
	)
	_label(
		root,
		(
			"Working static scenery | synthetic funding/progression | no walkout, crowd, game or "
			+ "final-art claim"
		),
		Vector2(22, 77),
		16
	)
	camera.reset_physics_interpolation()
	camera.force_update_transform()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var model: Node3D = property.objects[_copies[ITEM][HANDS.find(hand)]]
	_check(
		(
			lights.size() == 1
			and environments.size() == 1
			and sun != null
			and world != null
			and str(sun.name) == "Sun"
			and str(world.name) == "LabWorldEnvironment"
			and _in_frame(camera, model.global_transform * StadiumPlayerTunnelModels.ENVELOPE)
			and property.props_intact()
		),
		(
			"single ordinary lab lighting and capture contain complete untouched tunnel materials "
			+ hand
		)
	)
	await _capture("player-tunnel-overview.png" if overview else "player-tunnel-details.png")
	return lighting


func _runtime_and_views() -> void:
	for hand: String in HANDS:
		_phase = "ordinary-registered-installed-tunnel:" + hand
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
		lab._match_state.stadium = _snapshots[hand].duplicate(true)
		lab._stadium_ledger = _paid
		var installed: bool = StadiumPropertyRuntime.install_bound(lab)
		_check(
			installed, "ordinary frozen paid family37 snapshot installs exact handed tunnel " + hand
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
				and StadiumBoundaryRuntime.installed(lab, _snapshots[hand])
			),
			"complete current property and original live boundary identity remain intact " + hand
		)
		if boundary == null:
			await RenderingServer.frame_post_draw
			await _close_view()
			continue
		var copy: String = _copies[ITEM][HANDS.find(hand)]
		var model: Node3D = property.objects[copy]
		var model_evidence: Dictionary = _runtime_model(lab, property, model, hand)
		_check(
			(
				property.objects.size() == 6
				and property.route_obstacles().is_empty()
				and lab._primary_fielder.stadium_obstacles.is_empty()
			),
			"two exact host pairs one tunnel and one flag add no live fielder budget " + hand
		)
		_check(
			(
				PhysicalStadiumContacts.valid([], [], _snapshots[hand])
				and lab._play_records.is_empty()
				and lab._batted_ball == null
			),
			"zero-play installation invents no scoring or performance result " + hand
		)
		var passage: Dictionary = _passage_support(root, property, hand)
		await _camera_clearance(lab, model, hand)
		await _preview_focus(hand)
		var flights: Array[Dictionary] = []
		for kind: String in ["fair-opening", "foul-opening", "roof", "live-face"]:
			flights.append(await _moving_ball(lab, property, model, hand, kind))
		var lighting: Dictionary = await _view_capture(root, property, hand)
		_check(
			boundary.intact() and property.props_intact() and lab._play_records.is_empty(),
			"native front flight probes preserve exact assembly without completing a game " + hand
		)
		_runtime.append(
			{
				"hand": hand,
				"ordinary_install": installed,
				"paid_complete_parents": property.objects.size(),
				"model": model_evidence,
				"passage_support": passage,
				"flights": flights,
				"capture_lighting": lighting,
				"zero_play_report_valid": true,
				"games": 0
			}
		)
		await RenderingServer.frame_post_draw
		await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"combined tunnel qualification requires rendering and an explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phases.ownership = _checks - before
		if _layouts.size() == 2 and _snapshots.size() == 2:
			before = _checks
			_fit_checks()
			_phases.fit = _checks - before
			_phase = "complete-tunnel-and-compatible-host-geometry"
			var root: Node3D = _world()
			before = _checks
			_tunnel_geometry = await StadiumPlayerTunnelGeometryChecks.run(root, _check)
			_model_checks = _checks - before
			_check(
				_model_checks == StadiumPlayerTunnelGeometryChecks.expected_checks(),
				"all bounded detailed geometry assertions are reached"
			)
			await RenderingServer.frame_post_draw
			await _close_view()
			before = _checks
			await _runtime_and_views()
			_phases.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["player-tunnel-overview.png", "player-tunnel-details.png"],
		"exactly two native originals and zero complete games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumPlayerTunnelGeometryChecks.expected_checks()
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
		"player_walkout_claim": false,
		"crowd_claim": false,
		"gameplay_bonus_claim": false,
		"night_qualification_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumPlayerTunnelGeometryChecks.expected_checks(),
		"phase_checks": _phases,
		"paid_copy_ids": _copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"purchase_receipts": _receipts,
		"layouts": _layouts,
		"snapshots": _snapshots,
		"lifecycle": _lifecycle,
		"ownership_refusals": _refusals,
		"fit_cases": _fit,
		"geometry": _tunnel_geometry,
		"runtime": _runtime,
		"camera_cases": _cameras,
		"focus_cases": _focus,
		"synthetic_metrics": StadiumCareerProgress.metrics(_progress, _progress.size()),
		"capture_layout":
		(
			"exact paid ST-058 and same-side ST-074 plus BASE1 ST-029; opposite side compatible "
			+ "hosts retain finished caps; nonempty paid flag control"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence remains within 128 KiB"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("player-tunnel-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined tunnel evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phases}
	_check(
		_checks + 1 == expected and _phases == EXPECTED_PHASE_CHECKS,
		"every source-frozen bounded assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined tunnel evidence fully writes")
		file.close()
	print(
		(
			(
				"PLAYER_TUNNEL_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

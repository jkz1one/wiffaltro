class_name StadiumLandmarkRebuildChecks
extends "res://src/tests/stadium_landmark_rebuild_checks_fixture_base.gd"
func _camera_clearance(lab: PitchBatLab) -> void:
	_phase = "current-normal-zoom-pitcher-backdrop-clearance"
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	var old_pose: Transform3D = lab._camera.transform
	for left: bool in [false, true]:
		for zoom: bool in [false, true]:
			director.set_batter_handedness(left)
			director.set_shot(MatchCameraDirector.Shot.BATTING)
			director.set_presentation_motion(
				(
					MatchCameraDirector.PresentationMotion.ZOOM_IN
					if zoom
					else MatchCameraDirector.PresentationMotion.STILL
				),
				1.0
			)
			var pose: Transform3D = director._desired_transform(PitchBatLab.MOUND_ORIGIN, 0.0)
			lab._camera.transform = pose
			director._apply_projection(lab._camera)
			var protected: Rect2 = (
				_project_rect(
					lab._camera,
					AABB(PitchBatLab.MOUND_ORIGIN + Vector3(-1.6, 0, -0.8), Vector3(3.2, 3.6, 1.6))
				)
				. grow(16)
			)
			var blocked: bool = false
			var backdrop_clear: bool = true
			var models: Array[Dictionary] = []
			for index in range(3):
				for site: String in SITES:
					var row: Dictionary = StadiumLandmarkItems.row(
						_copies[index], ITEMS[index], site
					)
					var box: AABB = StadiumLandmarkItems.bounds(row)
					blocked = (
						blocked
						or box.has_point(pose.origin)
						or (
							box.intersects_segment(
								pose.origin, PitchBatLab.MOUND_ORIGIN + Vector3.UP
							)
							!= null
						)
					)
					var visible_box: AABB = (
						Transform3D(Basis.IDENTITY, row.position)
						* StadiumLandmarkModels.visible_bounds(row.item)
					)
					var projection: Rect2 = _project_rect(lab._camera, visible_box)
					var on_camera_side: bool = projection.has_area()
					var intersects: bool = on_camera_side and projection.intersects(protected)
					backdrop_clear = backdrop_clear and not intersects
					models.append(
						{
							"item": row.item,
							"site": site,
							"visible": on_camera_side,
							"projected_rect": _rect(projection),
							"intersects_pitcher_region": intersects
						}
					)
			_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"pitcher_target": _v3(PitchBatLab.MOUND_ORIGIN + Vector3.UP),
				"blocked": blocked,
				"backdrop_clear": backdrop_clear,
				"protected_pitcher_rect": _rect(protected),
				"models": models
			}
			_check(
				not blocked and backdrop_clear and protected.has_area(),
				(
					"actual current normal or zoom batting camera clears full reservations and protected "
					+ "projected pitcher backdrop"
				)
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress
	lab._camera.transform = old_pose


func _preview_focus() -> void:
	_phase = "actual-owned-copy-workshop-focus"
	var cases: Array[Dictionary] = []
	for pass_index in range(2):
		var layout: Dictionary = _layout if pass_index == 0 else _robot_layout
		var preview: StadiumDraftPreview = StadiumDraftPreview.new()
		add_child(preview)
		preview.size = Vector2(640, 360)
		preview.build(
			layout, _paid.construction(), true, "mogul", null, null, _paid.surface_owned()
		)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(
			(
				preview.preview_property != null
				and preview.preview_property.props_intact()
				and not preview.preview_property.has_node("MoldedSeatPad")
				and not preview.night_eligible
			),
			"actual Workshop preview builds current complete paid parents without optional pad in daylight"
		)
		for raw: Dictionary in layout.landmarks:
			preview.focus_copy(raw.copy)
			await get_tree().process_frame
			var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
			var box: AABB = preview.board_bounds.get(raw.copy, AABB())
			var contained: bool = (
				preview.board_bounds.has(raw.copy) and rect.size.x > 0 and rect.size.y > 0
			)
			for index in range(8):
				var point: Vector3 = box.get_endpoint(index)
				contained = (
					contained
					and not preview.camera.is_position_behind(point)
					and rect.has_point(preview.camera.unproject_position(point))
				)
			_check(
				contained,
				(
					"actual owned-copy preview focus contains all eight complete reservation corners "
					+ raw.copy
				)
			)
			cases.append(
				{"copy": raw.copy, "site": raw.site, "all_eight_corners_in_frame": contained}
			)
		preview.queue_free()
		await get_tree().process_frame
	_ui_cases.native_preview = true
	_ui_cases.focus_cases = cases
	_ui_cases.night_eligible = false


func _runtime_model(
	root: Node3D,
	lab: PitchBatLab,
	property: StadiumPropertyGeometry,
	boundary: StadiumBoundaryOwnedRuntime,
	row: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	var model: Node3D = property.objects.get(row.copy)
	var exact: bool = (
		is_instance_valid(model)
		and model.get_meta("stadium_item", "") == row.item
		and model.get_meta("owned_copy", "") == row.copy
		and model.get_meta("site", "") == row.site
	)
	_check(
		(
			exact
			and model.position == row.position
			and is_zero_approx(model.rotation.y)
			and model.scale == Vector3.ONE
		),
		"actual complete paid landmark retains exact identity and full-size fixed pose " + row.item
	)
	if not exact:
		return {}
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = bodies.size() == StadiumLandmarkModels.solid_count(row.item)
	for body: Node in bodies:
		roles = (
			roles
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
			and body.get_meta("owned_copy", "") == row.copy
			and body.get_meta("ball_surface", &"") == &"stadium_scenery"
			and not body is Area3D
		)
	_check(
		roles and model.find_children("*", "Area3D", true, false).is_empty(),
		(
			(
				"every actual landmark body is owned after-terminal scenery with no receiver or "
				+ "water-entry Area "
			)
			+ row.item
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
		(
			static_only
			and not model.get_meta("water_entry_enabled", true)
			and not model.get_meta("ball_award_enabled", true)
			and model.get_meta("obstacle_units", -1) == 0
		),
		(
			"complete model remains static scenery without live water double or obstacle effects "
			+ row.item
		)
	)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	resolver.segment_observer = boundary.observe
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	root.add_child(ball)
	ball.position = row.position + Vector3.UP
	property.bind_ball(ball, resolver)
	for body: Node in bodies:
		property._ball_contact(body, ball, resolver)
	_check(
		(
			resolver.state.stadium_contacts.is_empty()
			and not resolver.state.dead
			and resolver.state.result_floor == BallPlayState.ResultFloor.NONE
			and resolver.state.last_obstacle_contact == &""
		),
		(
			(
				"real bound decorative body contact callbacks issue no contact scoring Double or "
				+ "terminal authority "
			)
			+ row.item
		)
	)
	ball.free()
	var surface: String = (
		str(bodies[0].get_meta("surface_id", bodies[0].name)) if not bodies.is_empty() else ""
	)
	for role: String in ["LIVE_RICOCHET", "DECORATIVE_AFTER_TERMINAL"]:
		var events: Array = [
			{
				"source": "item",
				"id": row.copy,
				"surface": surface,
				"role": role,
				"position": _v3(row.position + Vector3.UP),
				"time": 0.1,
				"kind": "contact"
			}
		]
		_check(
			not PhysicalStadiumContacts.valid(
				[{"play": 0, "reason": "", "events": events}],
				[
					{
						"result": "double",
						"contact": ContactResult.Outcome.CONTACT,
						"exit_speed": 12.0
					}
				],
				snapshot
			),
			(
				"ordinary report refuses fabricated landmark contact and Double authority "
				+ row.item
				+ ":"
				+ role
			)
		)
	var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var bounds_count: int = 0
	var collected: bool = true
	for mesh: Node in model.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (
			(mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		)
		if box.size.y > 0.025:
			bounds_count += 1
			collected = collected and tracking._obstacles.has(box)
	_check(
		collected and bounds_count > 0 and tracking._owned_receiver_models.is_empty(),
		(
			(
				"ordinary dynamic tracking collects every current visible landmark mesh without "
				+ "receiver exclusion "
			)
			+ row.item
		)
	)
	return {
		"copy": row.copy,
		"item": row.item,
		"site": row.site,
		"position": _v3(row.position),
		"physical_scenery_bodies": bodies.size(),
		"active_animation": not static_only,
		"actual_contact_callbacks": bodies.size(),
		"contact_events": resolver.state.stadium_contacts.size(),
		"terminal": resolver.state.dead,
		"result_floor": int(resolver.state.result_floor),
		"tracking_mesh_bounds": bounds_count,
		"tracking_collected": collected
	}


func _in_frame(camera: Camera3D, box: AABB) -> bool:
	var readable: Rect2 = Rect2(12, 110, 1256, 565)
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if (
			camera.is_position_behind(point)
			or not readable.has_point(camera.unproject_position(point))
		):
			_operands = {
				"corner": _v3(point),
				"pixel": str(camera.unproject_position(point)),
				"readable": str(readable)
			}
			return false
	return true


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-native-readable-complete-landmark-originals"
	var camera: Camera3D = _studio(root, Vector3(96, 92, -110), Vector3(9, 1, 14), 90)
	_label(
		root,
		"PARK LANDMARKS | Two exact paid complete copies in the current field",
		Vector2(22, 18),
		23
	)
	_label(
		root,
		"ST-048 at LANDMARK-A + ST-050 at ODDITY-PLAZA | synthetic funding and progression",
		Vector2(22, 50),
		17
	)
	await get_tree().process_frame
	for row: Dictionary in _checked(_layout).landmark_placements:
		_check(
			_in_frame(camera, StadiumLandmarkItems.bounds(row)),
			(
				"overview contains full installed landmark reservation clear of heading and bottom HUD "
				+ row.item
			)
		)
	var field_visible: bool = true
	for point: Vector2 in StadiumLandmarkItems.graph_for(_layout).polygon():
		field_visible = (
			field_visible
			and not camera.is_position_behind(Vector3(point.x, 0, point.y))
			and Rect2(10, 90, 1260, 590).has_point(
				camera.unproject_position(Vector3(point.x, 0, point.y))
			)
		)
	_check(
		field_visible, "overview contains current complete field alongside both installed landmarks"
	)
	await _capture("landmark-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	var details: Array[Node3D] = []
	for index in range(3):
		var model: Node3D = StadiumLandmarkModels.create(ITEMS[index])
		root.add_child(model)
		model.position = Vector3(900 + (index - 1) * 7.4, 0, 0)
		details.append(model)
	camera.position = Vector3(900, 10, -24)
	camera.look_at(Vector3(900, 3, 0))
	camera.size = 13
	_label(
		root,
		"THREE COMPLETE LANDMARKS | One full-size owned assembly per purchase",
		Vector2(22, 18),
		23
	)
	_label(
		root,
		(
			"ST-050 TIKI FOUNTAIN                         ST-049 PITCHING ROBOT                    "
			+ "     ST-048 WIFFLE SCULPTURE"
		),
		Vector2(35, 58),
		17
	)
	_label(
		root,
		(
			"Static off-field scenery | bounded fountain artwork | no live water, Double, gameplay "
			+ "bonus or Night claim"
		),
		Vector2(35, 86),
		15
	)
	await get_tree().process_frame
	for index in range(3):
		_check(
			(
				_in_frame(
					camera,
					details[index].transform * StadiumLandmarkModels.visible_bounds(ITEMS[index])
				)
				and property.props_intact()
			),
			(
				"detail montage contains whole unscaled complete model while paid installation stays intact "
				+ ITEMS[index]
			)
		)
	await _capture("landmark-details.png")
	for model: Node3D in details:
		model.free()


func _runtime_and_views() -> void:
	_phase = "ordinary-registered-family33-property"
	var inspected: Array[Dictionary] = []
	var installs: Array[Dictionary] = []
	for pass_index in range(2):
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
		var snapshot: Dictionary = _snapshot if pass_index == 0 else _robot_snapshot
		var layout: Dictionary = _layout if pass_index == 0 else _robot_layout
		lab._match_state.stadium = snapshot.duplicate(true)
		lab._stadium_ledger = _paid
		var installed: bool = StadiumPropertyRuntime.install_bound(lab)
		_check(
			installed,
			"ordinary frozen paid snapshot installs complete family33 property " + str(pass_index)
		)
		if not installed:
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
				and StadiumBoundaryRuntime.installed(lab, snapshot)
			),
			"actual property and paid boundary identity seals remain intact"
		)
		var checked: Dictionary = _checked(layout)
		for row: Dictionary in checked.landmark_placements:
			inspected.append(_runtime_model(root, lab, property, boundary, row, snapshot))
		_check(
			(
				property.objects.size() == (2 if pass_index == 0 else 1)
				and not property.has_node("MoldedSeatPad")
				and not layout.has("molded_seats")
				and layout.treehouses.is_empty()
				and layout.ground_boxes.is_empty()
				and layout.practice_facilities.is_empty()
			),
			"ordinary landmark installation invents no optional infrastructure or unpurchased parents"
		)
		var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
		var built: bool = baseline.build("mogul", _empty, _paid.construction())
		_check(
			(
				built
				and baseline.objects.is_empty()
				and property.route_obstacles() == baseline.route_obstacles()
				and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
			),
			"actual fielder preserves empty-plan route with no added obstacle budget"
		)
		baseline.free()
		_check(
			(
				PhysicalStadiumContacts.valid([], [], snapshot)
				and lab._play_records.is_empty()
				and lab._batted_ball == null
			),
			"zero-play native install invents no contacts scoring or performance result"
		)
		installs.append(
			{
				"case": "two-site-overview" if pass_index == 0 else "robot-primary",
				"ordinary_install": installed,
				"paid_complete_parents": property.objects.size(),
				"optional_pad_adopted": false,
				"live_units": checked.get("live_units", -1),
				"route_obstacles": property.route_obstacles().size(),
				"zero_play_report_valid": true
			}
		)
		if pass_index == 0:
			_camera_clearance(lab)
			await _preview_focus()
			await _views(root, property)
		_check(
			(
				property.props_intact()
				and boundary != null
				and boundary.intact()
				and lab._play_records.is_empty()
			),
			"native checks and views preserve current registered installation without games"
		)
		await _close_view()
	_runtime = {
		"installs": installs,
		"models": inspected,
		"false_live_surface_claims_rejected": 6,
		"actual_contact_callbacks_executed": true,
		"live_water": false,
		"double_award": false,
		"games": 0
	}


func _body_rids(model: Node3D) -> Array[RID]:
	var result: Array[RID] = []
	for body: Node in model.find_children("*", "CollisionObject3D", true, false):
		result.append((body as CollisionObject3D).get_rid())
	return result


func _ground_ray(
	root: Node3D, point: Vector3, excludes: Array[RID], kind: String, label: String
) -> Dictionary:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		point + Vector3.UP * 12, point - Vector3.UP, 1, excludes
	)
	var hit: Dictionary = root.get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Node = hit.get("collider")
	var supported: bool = (
		not hit.is_empty()
		and ground != null
		and ground.get_meta("ball_surface", &"") == &"ground"
		and absf(hit.position.y) < 0.0003
		and hit.normal.is_equal_approx(Vector3.UP)
	)
	var measured: Dictionary = {
		"kind": kind,
		"point": _v3(point),
		"actual_y": hit.position.y if not hit.is_empty() else null,
		"normal": _v3(hit.normal) if not hit.is_empty() else [],
		"collider": str(ground.name) if ground != null else "",
		"supported": supported
	}
	_operands = {"case": label, "ray": measured}
	_check(supported, "actual native ground supports whole footprint and assembly base " + label)
	return measured


func _terrain_matrix() -> void:
	_phase = "actual-mogul-rough-leveled-whole-footprint-support"
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
		for index in range(3):
			for site: String in SITES:
				var layout: Dictionary = StadiumLandmarkItems.place(
					terrain, _paid.construction(), _copies[index], site, 0.0, access
				)
				var checked: Dictionary = _checked(layout)
				var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
				var built: bool = property.build("mogul", layout, _paid.construction())
				_check(
					(
						checked.ok
						and built
						and checked.get("live_units", -1) == 0
						and not checked.get("night_qualified", true)
					),
					(
						"actual rough or leveled Mogul property admits paid whole landmark "
						+ ITEMS[index]
						+ ":"
						+ site
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
					(
						terrain_node.get_node("TerrainCollision/ClosedTerrainShape")
						as CollisionShape3D
					)
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
						"actual inner terrain retains exact visual and collision faces "
						+ ITEMS[index]
						+ ":"
						+ site
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
					"actual property adds only selected complete paid parent and no obstacle budget"
				)
				var model: Node3D = property.objects[_copies[index]]
				var excludes: Array[RID] = _body_rids(model)
				var box: AABB = StadiumLandmarkItems.bounds(checked.landmark_placements[0])
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
						_ground_ray(
							root,
							point,
							excludes,
							"full-reservation-center-corner",
							ITEMS[index] + ":" + site + ":" + mode
						)
					)
				for point: Vector3 in StadiumLandmarkModels.support_points(ITEMS[index]):
					measured.append(
						_ground_ray(
							root,
							model.global_transform * point,
							excludes,
							"actual-assembly-base",
							ITEMS[index] + ":" + site + ":" + mode
						)
					)
				_support_matrix.append(
					{
						"item": ITEMS[index],
						"site": site,
						"tier": "mogul",
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
		"one rendered shared landmark qualification has an explicit output directory"
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
			_phase = "complete-source-held-landmark-parents"
			var model_root: Node3D = _world()
			before = _checks
			await StadiumLandmarkGeometryRebuildChecks.run(model_root, _check)
			_model_checks = _checks - before
			_check(
				_model_checks == StadiumLandmarkGeometryRebuildChecks.expected_checks(),
				"every complete landmark geometry assertion is reached"
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
		_images == ["landmark-overview.png", "landmark-details.png"],
		"exactly two native 1280 by 720 originals and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumLandmarkGeometryRebuildChecks.expected_checks()
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
		"live_water_claim": false,
		"double_claim": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumLandmarkGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"inherited_paid_copies": _inherited,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"purchase_receipts": _receipts,
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
			"one paid ST-048 at LANDMARK-A and one paid ST-050 at ODDITY-PLAZA; all three complete "
			+ "models shown once in detail montage"
		),
		"clearance_rule":
		(
			"whole fixed site reservation; Club CLIGHT-OR conflict rejects both orders; Mogul "
			+ "standard and premium outer-right lights clear"
		)
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined evidence is finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("landmark-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined landmark evidence opens")
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
			_check(false, "combined landmark evidence fully writes")
		file.close()
	print(
		(
			(
				"LANDMARK_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true synthetic_progression=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

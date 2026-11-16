extends "res://src/tests/stadium_rising_apple_rebuild_checks_scenario_base.gd"


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
	_phase = "actual-rough-leveled-whole-site-support"
	_check(
		_apple_terrain_source_matches(),
		"inner deterministic terrain source is original or the exact profiled format-only successor"
	)
	var root: Node3D = _world()
	for mode: String in ["rough", "leveled"]:
		var access: Array[String] = []
		if mode == "leveled":
			access.append("ground_prep")
		var terrain: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), access, false), access
		)
		var layout: Dictionary = StadiumRisingAppleItems.place(
			terrain, _paid.construction(), _copies[0], SITE, 0.0, access
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
			"actual rough or leveled Mogul property admits the complete paid apple " + mode
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
			(terrain_node.get_node("TerrainCollision/ClosedTerrainShape") as CollisionShape3D).shape
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
			"actual inner terrain retains exact visual and collision faces " + mode
		)
		_check(
			(
				not property.has_node("MoldedSeatPad")
				and property.objects.size() == 1
				and property.props_intact()
				and property.route_obstacles().is_empty()
			),
			"property adds only one complete paid apple and no obstacle budget " + mode
		)
		var model: Node3D = property.objects[_copies[0]]
		var excludes: Array[RID] = _body_rids(model)
		var box: AABB = StadiumRisingAppleItems.bounds(checked.rising_apple_placements[0])
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
				_ground_ray(root, point, excludes, "full-reservation-center-corner", mode)
			)
		for point: Vector3 in StadiumRisingAppleModels.support_points():
			measured.append(
				_ground_ray(
					root, model.global_transform * point, excludes, "actual-fixed-plinth", mode
				)
			)
		_support_matrix.append(
			{
				"item": ITEM,
				"site": SITE,
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


func _preview_focus() -> void:
	_phase = "actual-owned-copy-workshop-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(_layout, _paid.construction(), true, "mogul", null, null, _paid.surface_owned())
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.preview_property.has_node("MoldedSeatPad")
			and not preview.night_eligible
		),
		"actual Workshop preview builds current complete paid apple without optional pad in daylight"
	)
	preview.focus_copy(_copies[0])
	await get_tree().process_frame
	var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
	var box: AABB = preview.board_bounds.get(_copies[0], AABB())
	var contained: bool = (
		preview.board_bounds.has(_copies[0]) and rect.size.x > 0 and rect.size.y > 0
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
		"actual owned-copy preview focus contains all eight complete swept reservation corners"
	)
	_ui_cases.native_preview = true
	_ui_cases.focus_cases = [
		{"copy": _copies[0], "site": SITE, "all_eight_corners_in_frame": contained}
	]
	preview.queue_free()
	await get_tree().process_frame


func _camera_clearance(lab: PitchBatLab) -> void:
	_phase = "normal-zoom-pitcher-backdrop-clearance"
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
	var old_pose: Transform3D = lab._camera.transform
	var reserve: AABB = StadiumRisingAppleItems.bounds(
		StadiumRisingAppleItems.row(_copies[0], ITEM, SITE)
	)
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var model: Node3D = property.objects[_copies[0]]
	var moving_visual: Node3D = model.get_node("RisingAssembly/Visual")
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
			var blocked: bool = (
				reserve.has_point(pose.origin)
				or (
					reserve.intersects_segment(pose.origin, PitchBatLab.MOUND_ORIGIN + Vector3.UP)
					!= null
				)
			)
			var projected: Rect2 = _project_rect(
				lab._camera,
				(
					Transform3D(Basis.IDENTITY, Vector3(36.5, 0, 44))
					* StadiumRisingAppleModels.swept_bounds()
				)
			)
			var overlap: bool = projected.has_area() and projected.intersects(protected)
			var tracking_swept_count: int = 0
			var tracking_swept_exact: bool = true
			for raw_mesh: Node in moving_visual.find_children("*", "MeshInstance3D", true, false):
				var mesh: MeshInstance3D = raw_mesh as MeshInstance3D
				var down: AABB = mesh.global_transform * mesh.get_aabb()
				var lift: Vector3 = (
					model.global_basis * Vector3.UP * StadiumRisingAppleModels.MAX_RISE
				)
				var raised: AABB = AABB(down.position + lift, down.size)
				var swept: AABB = down.merge(raised)
				tracking_swept_count += 1
				tracking_swept_exact = (
					tracking_swept_exact and director.tracking_visibility._obstacles.has(swept)
				)
			_check(
				(
					not blocked
					and not overlap
					and protected.has_area()
					and tracking_swept_count == 10
					and tracking_swept_exact
				),
				(
					"actual batting pose clears swept reserve and pitcher backdrop while tracking covers "
					+ "all ten exact swept moving mesh bounds"
				)
			)
			_camera_cases.append(
				{
					"left_handed": left,
					"zoom_in": zoom,
					"eye": _v3(pose.origin),
					"blocked": blocked,
					"backdrop_clear": not overlap,
					"protected_pitcher_rect": _rect(protected),
					"swept_projected_rect": _rect(projected),
					"tracking_swept_count": tracking_swept_count,
					"tracking_swept_exact": tracking_swept_exact
				}
			)
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress
	lab._camera.transform = old_pose


func _runtime_and_views() -> void:
	_phase = "actual-confirmed-result-motion"
	var root: Node3D = _world()
	var lab: PitchBatLab = _installed_lab(root, "actual-confirmed-result-motion")
	var controller: StadiumRisingAppleRuntime = StadiumRisingAppleRuntime.current(lab)
	if controller == null:
		await _close_view()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var model: Node3D = property.objects[_copies[0]]
	var moving: Node3D = model.get_node("RisingAssembly")
	var fixed_visual: Transform3D = (model.get_node("Visual") as Node3D).global_transform
	var fixed_collision: Transform3D = (model.get_node("Collision") as Node3D).global_transform
	var reset_concealed: bool = _reset_concealed(model)
	var collision_exact: bool = _retained_apple_hulls(model)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		(
			controller.intact()
			and property.props_intact()
			and controller.phase == StadiumRisingAppleRuntime.Phase.IDLE
			and controller.accepted_events == 0
			and is_zero_approx(controller.height())
			and _reset_concealed(model)
		),
		(
			"new ordinary owned installation hides all ten moving meshes in the tree while "
			+ "retaining exact identity"
		)
	)
	_check(
		(
			model.get_meta("owned_copy", "") == _copies[0]
			and model.get_meta("stadium_item", "") == ITEM
			and model.get_meta("site", "") == SITE
			and model.position == Vector3(36.5, 0, 44)
			and model.scale == Vector3.ONE
		),
		"actual complete full-size model retains exact paid copy and fixed site"
	)
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = bodies.size() == StadiumRisingAppleModels.solid_count()
	for body: Node in bodies:
		roles = (
			roles
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
			and body.get_meta("owned_copy", "") == _copies[0]
			and body.get_meta("ball_surface", &"") == &"stadium_scenery"
			and not body is Area3D
		)
	_check(
		(
			roles
			and model.find_children("*", "Area3D", true, false).is_empty()
			and not model.get_meta("ball_award_enabled", true)
			and _retained_apple_hulls(model)
		),
		(
			"all fixed and moving bodies retain after-terminal collision even while visually "
			+ "concealed, with no scoring or receiver authority"
		)
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	_check(
		(
			baseline.build("mogul", _empty, _paid.construction())
			and baseline.objects.is_empty()
			and property.route_obstacles() == baseline.route_obstacles()
			and lab._primary_fielder.stadium_obstacles == property.route_obstacles()
		),
		"actual fielder preserves empty-plan route with no new obstacle budget"
	)
	baseline.free()
	var outcomes: Array[BallPlayOutcome] = []
	lab._ball_play_resolver.play_resolved.connect(
		func(value: BallPlayOutcome) -> void: outcomes.append(value)
	)
	for result: int in [
		BallPlayOutcome.Result.HOME_RUN,
		BallPlayOutcome.Result.OUT,
		BallPlayOutcome.Result.FOUL,
		BallPlayOutcome.Result.SINGLE
	]:
		var unconfirmed: BallPlayOutcome = BallPlayOutcome.new()
		unconfirmed.result = result as BallPlayOutcome.Result
		controller._on_resolved(unconfirmed)
		_check(
			(
				controller.accepted_events == 0
				and controller.phase == StadiumRisingAppleRuntime.Phase.IDLE
				and is_zero_approx(controller.height())
			),
			"unconfirmed or non-home-run event cannot start a predicted celebration " + str(result)
		)
	_camera_clearance(lab)
	await _preview_focus()
	# The installed PitchBatLab already owns its one Sun and LabWorldEnvironment.
	# Only a disposable capture camera and backed headings are added here.
	var capture_lighting: Dictionary = _apple_capture_lighting(root)
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(49.5, 10, 28)
	camera.look_at(Vector3(36.5, 3.6, 44))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.make_current()
	camera.reset_physics_interpolation()
	camera.force_update_transform()
	var heading: Control = _apple_capture_heading(
		root,
		"RISING HOME-RUN APPLE | Exact paid LANDMARK-A installation",
		"Ordinary reset: complete top hat; all ten moving fruit meshes concealed at exact height 0"
	)
	var capture_views: Array[Dictionary] = []
	var ordinary_reset: Dictionary = await _apple_capture_view(
		"rising-apple-overview.png", camera, model, controller, property
	)
	capture_views.append(ordinary_reset)
	_check(
		(
			_apple_lighting_exact(capture_lighting)
			and ordinary_reset.whole_reservation_in_frame
			and ordinary_reset.height == 0.0
			and ordinary_reset.reset_concealed
			and ordinary_reset.owned_guard_intact
		),
		(
			"ordinary single-lit reset original contains the complete top hat with all ten moving "
			+ "meshes concealed"
		)
	)
	heading.queue_free()
	await get_tree().process_frame
	camera.position = Vector3(36.5, 22, 44)
	camera.look_at(Vector3(36.5, 0, 44), Vector3.FORWARD)
	camera.size = 16.0
	camera.make_current()
	camera.reset_physics_interpolation()
	camera.force_update_transform()
	heading = _apple_capture_heading(
		root,
		"DIRECTLY OVERHEAD RESET | Exact paid top hat at height 0",
		(
			"Actual overhead rendered frame; all ten moving meshes hidden in tree; owned guard and "
			+ "collision intact"
		)
	)
	var overhead_reset: Dictionary = await _apple_capture_view(
		"rising-apple-overhead.png", camera, model, controller, property
	)
	capture_views.append(overhead_reset)
	_check(
		(
			_apple_lighting_exact(capture_lighting)
			and overhead_reset.directly_overhead
			and overhead_reset.whole_reservation_in_frame
			and overhead_reset.whole_model_in_frame
			and overhead_reset.height == 0.0
			and overhead_reset.reset_concealed
			and overhead_reset.moving_mesh_count == 10
			and overhead_reset.hidden_moving_mesh_count == 10
			and overhead_reset.owned_guard_intact
			and overhead_reset.retained_collision_exact
			and overhead_reset.camera_current
		),
		(
			"actual directly overhead native reset frame contains the whole top hat with exact "
			+ "zero height, ten hidden moving meshes and live owned guard"
		)
	)
	heading.queue_free()
	await get_tree().process_frame
	var score_before: Vector2i = Vector2i(
		lab._match_state.away_team.runs, lab._match_state.home_team.runs
	)
	lab._active_play_record = PlayRecord.new()
	_check(lab._match_state.begin_pitch(), "actual bounded HR probe starts an ordinary pitch state")
	await get_tree().process_frame
	_check(
		(
			controller.accepted_events == 0
			and is_zero_approx(controller.height())
			and _reset_concealed(model)
		),
		"deciding pitch remains fully down before the actual launched flight"
	)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 1, 0.28)
	launch.velocity = Vector3(-4, 18, 30)
	launch.orientation = Quaternion.IDENTITY
	launch.angular_velocity = Vector3.ZERO
	lab._start_ball_in_play(launch)
	_check(
		(
			lab._batted_ball != null
			and not lab._ball_play_resolver.state.dead
			and controller.accepted_events == 0
			and is_zero_approx(controller.height())
			and _reset_concealed(model)
		),
		"ordinary actual unconfirmed ball launch cannot move the apple"
	)
	var deciding_frames: int = 0
	var deciding_down: bool = true
	var native_frames: int = 0
	var saw_rise: bool = false
	var saw_hold: bool = false
	var saw_lower: bool = false
	var fixed_exact: bool = true
	var seals_exact: bool = true
	var pause_checked: bool = false
	var duplicate_checked: bool = false
	var raised_captured: bool = false
	var peak: float = 0.0
	var previous_height: float = 0.0
	var trace: Array[Dictionary] = []
	var last_phase: int = -1
	for frame in range(720):
		await get_tree().physics_frame
		native_frames += 1
		var h: float = controller.height()
		peak = maxf(peak, h)
		if outcomes.is_empty():
			deciding_frames += 1
			deciding_down = (
				deciding_down
				and is_zero_approx(h)
				and controller.accepted_events == 0
				and _reset_concealed(model)
			)
		else:
			saw_rise = saw_rise or h > previous_height + 0.001
			saw_lower = saw_lower or h < previous_height - 0.001
			saw_hold = saw_hold or h == Vector3(0, StadiumRisingAppleModels.MAX_RISE, 0).y
		fixed_exact = (
			fixed_exact
			and (model.get_node("Visual") as Node3D).global_transform == fixed_visual
			and (model.get_node("Collision") as Node3D).global_transform == fixed_collision
		)
		seals_exact = (
			seals_exact
			and controller.intact()
			and property.props_intact()
			and moving.position == Vector3(0, h, 0)
			and moving.visible == (h > 0.0)
		)
		collision_exact = collision_exact and _retained_apple_hulls(model)
		if controller.phase != last_phase:
			trace.append(
				{
					"phase": int(controller.phase),
					"native_frame": frame,
					"home_run_clock": lab._home_run.elapsed,
					"height": h,
					"moving_visible": moving.visible,
					"accepted_events": controller.accepted_events,
					"terminal": lab._ball_play_resolver.state.dead
				}
			)
			last_phase = controller.phase
		if not outcomes.is_empty() and not duplicate_checked and h > 0.05:
			var elapsed_before: float = lab._home_run.elapsed
			var events_before: int = controller.accepted_events
			controller._on_resolved(outcomes[0])
			_check(
				(
					controller.accepted_events == events_before
					and controller.height() == h
					and lab._home_run.elapsed == elapsed_before
				),
				"duplicate same-play confirmed event does not restart clock or motion"
			)
			duplicate_checked = true
		if not pause_checked and h > 0.10 and h < 2.8:
			var clock_before: float = lab._home_run.elapsed
			var pose_before: Transform3D = moving.transform
			get_tree().paused = true
			for pause_frame in range(4):
				await get_tree().process_frame
			_check(
				(
					moving.transform == pose_before
					and lab._home_run.elapsed == clock_before
					and controller.height() == h
				),
				"real SceneTree pause freezes ordinary HR clock and complete moving assembly"
			)
			get_tree().paused = false
			pause_checked = true
		if saw_hold and not raised_captured:
			get_tree().paused = true
			camera.position = Vector3(49.5, 10, 28)
			camera.look_at(Vector3(36.5, 3.6, 44))
			camera.size = 16.0
			camera.make_current()
			camera.reset_physics_interpolation()
			camera.force_update_transform()
			heading = _apple_capture_heading(
				root,
				"CONFIRMED HOME RUN | Complete apple raised by the ordinary result clock",
				"Actual fair-ball terminal event; visual and collision move together | paused native detail"
			)
			var raised_view: Dictionary = await _apple_capture_view(
				"rising-apple-details.png", camera, model, controller, property
			)
			capture_views.append(raised_view)
			_check(
				(
					_apple_lighting_exact(capture_lighting)
					and raised_view.whole_model_in_frame
					and raised_view.height == Vector3(0, StadiumRisingAppleModels.MAX_RISE, 0).y
					and raised_view.accepted_events == 1
					and raised_view.moving_visible_in_tree
					and raised_view.owned_guard_intact
				),
				"single-lit detail contains complete truly raised installed apple and unchanged paid parent"
			)
			get_tree().paused = false
			raised_captured = true
		previous_height = h
		if raised_captured and not lab._home_run.active and is_zero_approx(h):
			break
	_check(
		deciding_frames > 0 and deciding_down,
		"every observed deciding-flight frame remained down until actual terminal home run"
	)
	_check(
		(
			outcomes.size() == 1
			and outcomes[0].result == BallPlayOutcome.Result.HOME_RUN
			and controller.accepted_events == 1
		),
		"actual native flight confirms exactly one home run and one celebration"
	)
	var score_after: Vector2i = Vector2i(
		lab._match_state.away_team.runs, lab._match_state.home_team.runs
	)
	_check(
		(
			score_after.x + score_after.y == score_before.x + score_before.y + 1
			and lab._play_records.size() == 1
			and lab._play_records[0].result == &"home_run"
		),
		"apple creates no scoring authority beyond the one ordinary scored home run"
	)
	_check(
		(
			saw_rise
			and saw_hold
			and saw_lower
			and peak == Vector3(0, StadiumRisingAppleModels.MAX_RISE, 0).y
			and pause_checked
			and duplicate_checked
			and raised_captured
		),
		"actual native clock reaches rise hold lower with pause and duplicate-event witnesses"
	)
	_check(
		(
			fixed_exact
			and seals_exact
			and collision_exact
			and controller.intact()
			and property.props_intact()
		),
		(
			"authorized pose and visibility preserve fixed geometry resources paid identity native "
			+ "seals and all retained after-terminal hulls"
		)
	)
	_check(
		(
			not lab._home_run.active
			and is_zero_approx(controller.height())
			and StadiumRisingAppleRuntime.before_pitch(lab)
			and _reset_concealed(model)
		),
		"ordinary HR hold returns fully down before the next pitch may begin"
	)
	var accepted: int = controller.accepted_events
	controller._on_resolved(outcomes[0] if not outcomes.is_empty() else BallPlayOutcome.new())
	_check(
		controller.accepted_events == accepted and is_zero_approx(controller.height()),
		"late duplicate of already completed play cannot restart the apple"
	)
	_runtime = {
		"ordinary_install": true,
		"actual_native_flight": true,
		"synthetic_launch": [-4, 18, 30],
		"deciding_frames": deciding_frames,
		"deciding_down": deciding_down,
		"native_frames": native_frames,
		"actual_outcomes": outcomes.size(),
		"accepted_events": accepted,
		"peak_height": peak,
		"pause_exact": pause_checked,
		"duplicate_suppressed": duplicate_checked,
		"fixed_geometry_exact": fixed_exact,
		"seals_exact": seals_exact,
		"returned_before_next_pitch": is_zero_approx(controller.height()),
		"reset_concealed_all_views_including_overhead":
		(
			reset_concealed
			and _reset_concealed(model)
			and ordinary_reset.reset_concealed
			and overhead_reset.reset_concealed
			and overhead_reset.directly_overhead
		),
		"visibility_rule":
		(
			"only RisingAssembly.visible is false at exact stored height0 and true above0; all "
			+ "children retain their own flags"
		),
		"collision_retained_when_hidden": collision_exact,
		"collision_rule":
		(
			"all ten moving after-terminal hulls stay enabled with unchanged layer1 mask2 and zero "
			+ "margin; no live obstacle is added"
		),
		"capture_lighting": capture_lighting,
		"capture_views": capture_views,
		"score_before": [score_before.x, score_before.y],
		"score_after": [score_after.x, score_after.y],
		"trace": trace,
		"tamper_cases": []
	}
	await _close_view()

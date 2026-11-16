extends "res://src/tests/stadium_small_yard_scenery_rebuild_checks_fixture_base.gd"
func _ownership() -> void:
	_phase = "unchanged-paid-stock-gates-and-prefix"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5})
	_paid = ClubAssetLedger.new(SEED, _credits, _progress)
	var prefix: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"scenery adds no starter grant or new copy identity"
	)
	for item: String in ITEMS:
		var entry: Dictionary = StadiumCatalog.item(item)
		_check(
			(
				entry.blueprint_price == PRICES[item][0]
				and entry.copy_price == PRICES[item][1]
				and ClubCareer.same(entry.requires, GATES[item])
			),
			"existing price and progression gate stay exact " + item
		)
		_check(
			(
				StadiumPurchases
				. quote(
					_paid.construction(),
					item,
					1,
					"eligible:" + item,
					_price_version(item),
					GATES[item]
				)
				. ok
			),
			"old exact progression gate still permits purchase " + item
		)
		if not GATES[item].is_empty():
			var below: Dictionary = GATES[item].duplicate(true)
			below.seasons -= 1
			_check(
				not (
					StadiumPurchases
					. quote(
						_paid.construction(), item, 1, "locked:" + item, _price_version(item), below
					)
					. ok
				),
				"one season below unchanged gate stays locked " + item
			)
		_buy(item)
		if not _copies.has(item):
			return
	_buy("ST-002")
	if not _copies.has("ST-002"):
		return
	_check(
		_paid.construction().copies.size() == 9 and StadiumLayoutSnapshot.matches(prefix, _paid),
		"only six paid copies are added and the old snapshot prefix remains authenticated"
	)
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		cold != null and ClubCareer.same(cold.to_data(), _paid.to_data()),
		"unchanged-price purchase-only journal cold replays"
	)
	var land: Dictionary = _paid.commit(
		{
			"id": "small-yard-expanded",
			"rev": _paid.revision(),
			"op": "stadium_land",
			"tier": "expanded",
			"through": 40,
			"progress_through": 40,
			"price_version": StadiumLand.VERSION
		}
	)
	_check(land.ok, "ordinary Expanded grounds purchase preserves the field scale")
	_empty27 = StadiumLiveFurnishingItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	_empty27.receiver = "starter-v1:ST-079"
	_check(
		_empty27.version == 27 and _checked(_empty27).ok,
		"old family27 retains the selected inherited receiver"
	)
	_sites_and_yaws()
	_same_copy_modes()
	_conflicts()
	if not _copies.has("ST-081"):
		return
	_base27 = _empty27.duplicate(true)
	_base27.obstacles = [
		{"copy": "starter-v1:ST-001", "site": "O-L1", "yaw": 0},
		{"copy": "starter-v1:ST-003", "site": "O-R1", "yaw": 90}
	]
	_base27 = StadiumLiveFurnishingItems.place(
		_base27, _paid.construction(), _copies["ST-002"], "O-L2", 0
	)
	_check(
		_checked(_base27).ok and _apply(_base27),
		"three inherited live units and receiver apply in unchanged family27"
	)
	_record("inherited-three-live-base27", _base27)
	_layout = _base27.duplicate(true)
	var selected_sites: Array[String] = ["YS-L1", "YS-L2", "YS-L3", "YS-R1", "YS-R2"]
	for index in range(ITEMS.size()):
		_layout = _placed(_layout, ITEMS[index], selected_sites[index])
	var checked: Dictionary = _checked(_layout)
	_check(
		(
			checked.ok
			and checked.get("live_units", -1) == 3
			and checked.get("yard_scenery_placements", []).size() == 5
		),
		"five scenery copies consume zero units beside three live inherited objects"
	)
	_check(
		(
			ClubCareer.same(StadiumSmallYardSceneryItems.base(_layout), _base27)
			and ClubCareer.same(StadiumSmallYardSceneryItems.prune(_layout), _layout)
		),
		"scenery wrapper and pruning preserve all inherited channels exactly"
	)
	_negatives()
	var balance: int = _paid.balance()
	_check(
		(
			_apply(_layout)
			and _paid.balance() == balance
			and _paid.to_data().version == 36
			and _paid.construction().copies.size() == 10
		),
		"ordinary free family28 draft/apply uses ledger36 without any purchase migration"
	)
	_record("five-small-yard-scenery28", _layout)
	_snapshot = StadiumLayoutSnapshot.capture(_paid)
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshot, SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshot)
			and environment.mode == "day"
			and not checked.get("night_qualified", true)
		),
		"ordinary owned fixture stays explicitly daylight-only"
	)
	_night_recovery()


func _actor_route(
	lab: PitchBatLab, routes: Array[Dictionary], old_routes: Array[Dictionary]
) -> void:
	_phase = "real-fielder-route-equivalence"
	var actor: FielderController = lab._primary_fielder
	var original_anchor: Vector3 = actor.anchor_position
	var original_pitcher: float = actor.pitcher_lane_z
	var original_delay: float = actor.reaction_delay_seconds
	actor.pitcher_lane_z = INF
	var start: Vector3 = Vector3(-12, 0, 14)
	var target: Vector3 = Vector3(-4, 0, 14)
	var traces: Array = []
	for source: Array[Dictionary] in [old_routes, routes]:
		actor.stadium_obstacles = source
		actor.set_anchor(start)
		actor.begin_play(false)
		actor.reaction_delay_seconds = 0
		actor.target_position = target
		var trace: Array[Vector3] = []
		var legal: bool = true
		for frame in range(240):
			var previous: Vector3 = actor.global_position
			actor._physics_process(1.0 / 60.0)
			legal = legal and StadiumDefenderRoutes.clear(previous, actor.global_position, source)
			trace.append(actor.global_position)
			if actor.global_position.distance_to(target) <= 0.06:
				break
		_operands = {
			"old_route": traces.is_empty(),
			"ticks": trace.size(),
			"from": _v3(start),
			"target": _v3(target),
			"finish": _v3(actor.global_position),
			"legal": legal
		}
		_check(
			legal and actor.global_position.distance_to(target) <= 0.06,
			"actual FielderController completes the existing live-cone detour without scenery interference"
		)
		traces.append(trace)
		actor.end_play()
	_check(
		traces[0] == traces[1],
		"real controller movement is identical before and after installing all five scenery copies"
	)
	_route_cases.append(
		{
			"case": "actual-controller-equivalence",
			"ticks": traces[0].size(),
			"from": _v3(start),
			"to": _v3(target),
			"identical_complete_trace": traces[0] == traces[1]
		}
	)
	actor.set_anchor(original_anchor)
	actor.pitcher_lane_z = original_pitcher
	actor.reaction_delay_seconds = original_delay
	actor.stadium_obstacles = routes


func _camera_clearance(lab: PitchBatLab, rows: Array) -> void:
	_phase = "existing-batting-camera-extrema"
	var director: MatchCameraDirector = lab._camera_director
	var old_side: float = director._batter_side
	var old_shot: MatchCameraDirector.Shot = director.shot
	var old_motion: MatchCameraDirector.PresentationMotion = director._presentation_motion
	var old_progress: float = director._presentation_progress
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
			var blocked: Array[String] = []
			for row: Dictionary in rows:
				var cell: AABB = StadiumSmallYardSceneryItems.reservation()
				cell.position += row.position
				if (
					cell.has_point(pose.origin)
					or (
						cell.intersects_segment(pose.origin, PitchBatLab.MOUND_ORIGIN + Vector3.UP)
						!= null
					)
				):
					blocked.append(row.site)
			_operands = {
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"blocked_cells": blocked
			}
			_check(
				blocked.is_empty(),
				"actual batting camera origin and pitcher sightline clear every complete reserved yard cell"
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress


func _pass_throughs(
	root: Node3D,
	boundary: StadiumBoundaryOwnedRuntime,
	property: StadiumPropertyGeometry,
	rows: Array
) -> void:
	_phase = "registered-native-pass-through-every-scenery-model"
	for row: Dictionary in rows:
		var model: Node3D = property.objects[row.copy]
		var from: Vector3 = model.global_position + Vector3(-2, 0.25, 0)
		var resolver: BallPlayResolver = BallPlayResolver.new()
		resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
		resolver.segment_observer = boundary.observe
		_outcomes.clear()
		resolver.play_resolved.connect(
			func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
		)
		var ball: BattedBallBody = BattedBallBody.new()
		ball.gravity_scale = 0
		ball.aero_drag_coefficient = 0
		ball.aero_magnus_scale = 0
		ball.aero_perforation_force_scale = 0
		root.add_child(ball)
		ball.position = from
		property.bind_ball(ball, resolver)
		boundary.bind_ball(ball, resolver)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = from
		launch.velocity = Vector3(12, 0, 0)
		ball.launch(launch)
		for frame in range(22):
			await get_tree().physics_frame
		_operands = {
			"item": row.item,
			"copy": row.copy,
			"site": row.site,
			"from": _v3(from),
			"finish": _v3(ball.global_position),
			"velocity": _v3(ball.linear_velocity),
			"events": resolver.state.stadium_contacts
		}
		_check(
			(
				PhysicsServer3D.body_get_space(ball.get_rid()) == root.get_world_3d().space
				and ball.physics_contact_router.is_valid()
				and ball.global_position.x > model.global_position.x + 1.4
			),
			"registered native ball physically passes through selected scenery " + row.item
		)
		_check(
			(
				resolver.state.stadium_contacts.is_empty()
				and not resolver.state.dead
				and _outcomes.is_empty()
				and ball.linear_velocity.x > 11
			),
			(
				"actual scenery traversal causes no collider rebound scoring event or terminal outcome "
				+ row.item
			)
		)
		_contact_cases.append(
			{
				"item": row.item,
				"copy": row.copy,
				"site": row.site,
				"native_moving_ball": true,
				"events": resolver.state.stadium_contacts.duplicate(true),
				"from": _v3(from),
				"finish": _v3(ball.global_position),
				"post_velocity": _v3(ball.linear_velocity),
				"terminal": resolver.state.dead
			}
		)
		ball.free()
		await get_tree().physics_frame


func _preview_focus() -> void:
	_phase = "actual-paid-workshop-focus"
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(
		_layout, _paid.construction(), true, "expanded", null, null, _paid.surface_owned()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.night_eligible
		),
		"ordinary Workshop preview builds the exact daylight-only paid scenery layout"
	)
	var cases: Array[Dictionary] = []
	for item: String in ITEMS:
		var copy: String = _copies[item]
		preview.focus_copy(copy)
		await get_tree().process_frame
		var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
		var bounds: AABB = preview.board_bounds.get(copy, AABB())
		var contained: bool = preview.board_bounds.has(copy) and rect.size.x > 0 and rect.size.y > 0
		for index in range(8):
			var point: Vector3 = bounds.get_endpoint(index)
			contained = (
				contained
				and not preview.camera.is_position_behind(point)
				and rect.has_point(preview.camera.unproject_position(point))
			)
		_operands = {
			"item": item,
			"copy": copy,
			"bounds": str(bounds),
			"viewport": [rect.size.x, rect.size.y],
			"eye": _v3(preview.camera.position)
		}
		_check(
			contained,
			(
				"actual owned-copy preview focus contains all eight complete model-envelope corners "
				+ item
			)
		)
		cases.append({"item": item, "copy": copy, "all_eight_corners_in_frame": contained})
	_ui_cases.merge(
		{"native_preview": true, "focus_cases": cases, "night_eligible": preview.night_eligible}
	)
	preview.queue_free()
	await get_tree().process_frame


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-readable-native-small-yard-originals"
	var bounds: Rect2 = StadiumProperty.BOUNDS["expanded"]
	var target: Vector3 = Vector3(bounds.get_center().x, 0.7, bounds.get_center().y)
	var camera: Camera3D = _studio(root, target + Vector3(42, 59, -67), target, 76)
	_label(
		root, "OWNED SMALL-YARD SCENERY | Existing models, exact paid copies", Vector2(22, 18), 22
	)
	await _capture("small-yard-scenery-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	var canvas: Image = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("16232e"))
	var names: Array[String] = [
		"TRAFFIC CONE", "WOVEN LAWN CHAIR", "OLD PUSH MOWER", "KETTLE BBQ", "PICNIC COOLER"
	]
	var sizes: Array[float] = [1.35, 1.9, 2.1, 1.9, 1.6]
	for index in range(ITEMS.size()):
		var item: String = ITEMS[index]
		var model: Node3D = property.objects.get(_copies[item])
		_check(
			is_instance_valid(model),
			"readable close-up uses the actual installed paid scenery " + item
		)
		if not is_instance_valid(model):
			continue
		var tile_size: Vector2i = Vector2i(640, 360) if index < 2 else Vector2i(426, 360)
		_view.size = tile_size
		var focus: Vector3 = (
			model.global_position
			+ Vector3(0, StadiumSmallYardSceneryItems.envelope(item).size.y * 0.46, 0)
		)
		camera.position = focus + Vector3(2.3, 1.7, -3.0)
		camera.look_at(focus)
		camera.size = sizes[index]
		_label(root, names[index] + " | Scenery", Vector2(12, 12), 17)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var tile: Image = _view.get_texture().get_image()
		_check(
			not tile.is_empty() and tile.get_size() == tile_size,
			"actual native bounded item-detail tile " + item
		)
		if not tile.is_empty():
			tile.convert(Image.FORMAT_RGBA8)
			canvas.blit_rect(
				tile,
				Rect2i(Vector2i.ZERO, tile_size),
				Vector2i(index * 640, 0) if index < 2 else Vector2i((index - 2) * 426, 360)
			)
		for child: Node in root.get_children():
			if child is Label:
				child.queue_free()
	_check(
		(
			canvas.get_size() == SIZE
			and canvas.save_png(_capture_dir.path_join("small-yard-scenery-details.png")) == OK
		),
		"five native readable details save one bounded 1280 by 720 original without footer overlays"
	)
	_images.append("small-yard-scenery-details.png")


func _runtime_and_views() -> void:
	_phase = "ordinary-owned-family28-installation"
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
	_check(installed, "ordinary frozen owned snapshot installs the complete family28 property")
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
		"ordinary exact property and boundary identity seals remain intact"
	)
	if boundary == null:
		await _close_view()
		return
	var checked: Dictionary = _checked(_layout)
	var rows: Array = checked.get("yard_scenery_placements", [])
	var scene_ids: Array[String] = []
	var inspected: Array[Dictionary] = []
	for row: Dictionary in rows:
		var model: Node3D = property.objects.get(row.copy)
		var exact: bool = (
			is_instance_valid(model)
			and model.get_meta("stadium_item", "") == row.item
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == row.site
		)
		_operands = {
			"item": row.item, "copy": row.copy, "site": row.site, "found": is_instance_valid(model)
		}
		_check(
			(
				exact
				and model.position.is_equal_approx(row.position)
				and is_equal_approx(model.rotation.y, deg_to_rad(float(row.yaw)))
			),
			(
				"actual installed scenery retains exact paid identity and authored full-size pose "
				+ row.item
			)
		)
		if not exact:
			continue
		var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
		var shapes: Array[Node] = model.find_children("*", "CollisionShape3D", true, false)
		_check(
			(
				bodies.is_empty()
				and shapes.is_empty()
				and model.get_node("Collision").get_child_count() == 0
				and model.get_meta("scenery_only", false)
			),
			(
				"complete descendant traversal finds no scenery collider shape or physical callback target "
				+ row.item
			)
		)
		scene_ids.append(row.copy)
		inspected.append(
			{
				"item": row.item,
				"copy": row.copy,
				"site": row.site,
				"yaw": row.yaw,
				"collision_objects": bodies.size(),
				"collision_shapes": shapes.size()
			}
		)
	_check(
		inspected.size() == 5 and property.objects.size() == checked.placements.size(),
		"installed inventory has precisely five selected scenery copies and inherited objects"
	)
	var all_bodies: Array[Node] = property.find_children("*", "CollisionObject3D", true, false)
	var leak: bool = false
	for body: Node in all_bodies:
		leak = leak or scene_ids.has(str(body.get_meta("owned_copy", "")))
	_check(
		not all_bodies.is_empty() and not leak,
		"whole-property physical traversal finds real live bodies and no scenery-owned body anywhere"
	)
	var baseline: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	var built: bool = baseline.build("expanded", _base27, _paid.construction())
	root.add_child(baseline)
	baseline.visible = false
	_check(built, "ordinary old family27 builds the exact route comparison source")
	var routes: Array[Dictionary] = property.route_obstacles()
	var old_routes: Array[Dictionary] = baseline.route_obstacles()
	_check(
		(
			routes == old_routes
			and routes.size() == 4
			and lab._primary_fielder.stadium_obstacles == routes
		),
		"actual fielder receives exactly three inherited live objects plus receiver and no scenery"
	)
	for row: Dictionary in rows:
		var from: Vector3 = row.position + Vector3(-2, 0, 0)
		var to: Vector3 = row.position + Vector3(2, 0, 0)
		var old_step: Vector3 = StadiumDefenderRoutes.step(from, to, 0.6, old_routes)
		var step: Vector3 = StadiumDefenderRoutes.step(from, to, 0.6, routes)
		_check(
			(
				StadiumDefenderRoutes.clear(from, to, routes)
				and StadiumDefenderRoutes.clip(from, to, routes) == to
				and step == old_step
			),
			"actual route kernel gains no stop or detour from scenery " + row.item
		)
		_route_cases.append(
			{
				"item": row.item,
				"site": row.site,
				"from": _v3(from),
				"to": _v3(to),
				"old_step": _v3(old_step),
				"new_step": _v3(step),
				"scenery_obstacles": 0
			}
		)
	_actor_route(lab, routes, old_routes)
	baseline.free()
	_check(
		PhysicalStadiumContacts.valid([], [], _snapshot),
		"ordinary report accepts exact installed layout with zero games and no invented events"
	)
	for row: Dictionary in rows:
		var surfaces: Array[String] = (
			StadiumStarterModels.surfaces(row.item)
			if row.item in ["ST-001", "ST-003"]
			else StadiumGroundPropsModels.surfaces(row.item)
		)
		var events: Array = [
			{
				"source": "item",
				"id": row.copy,
				"surface": surfaces[0],
				"role": "LIVE_RICOCHET",
				"position": _v3(row.position + Vector3.UP * 0.25),
				"time": 0.1,
				"kind": "contact"
			}
		]
		var evidence: Array = [{"play": 0, "reason": "", "events": events}]
		_check(
			not PhysicalStadiumContacts.valid(
				evidence,
				[
					{
						"result": "single",
						"contact": ContactResult.Outcome.CONTACT,
						"exit_speed": 12.0
					}
				],
				_snapshot
			),
			"report rejects a real old live-surface name claimed for the scenery copy " + row.item
		)
	_physical = {
		"ordinary_install": installed,
		"models": inspected,
		"whole_property_collision_objects": all_bodies.size(),
		"scenery_collision_objects": 0 if not leak else -1,
		"old_route_copies": old_routes.map(func(row: Dictionary) -> String: return row.copy),
		"installed_route_copies": routes.map(func(row: Dictionary) -> String: return row.copy),
		"zero_play_report_valid": true,
		"false_live_surface_claims_rejected": ITEMS
	}
	_camera_clearance(lab, rows)
	await _preview_focus()
	await _pass_throughs(root, boundary, property, rows)
	_check(
		(
			property.props_intact()
			and boundary.intact()
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		"registered scenery flights preserve the ordinary installation without starting a game"
	)
	await _views(root, property)
	await _close_view()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered combined small-yard qualification with explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		var before: int = _checks
		_ownership()
		_phase_counts.ownership = _checks - before
		if not _layout.is_empty() and not _snapshot.is_empty():
			before = _checks
			_detached_controls()
			_phase_counts.workshop_controls = _checks - before
			_phase = "source-held-geometry-parity"
			var root: Node3D = _world()
			before = _checks
			await StadiumSmallYardGeometryRebuildChecks.run(root, _check)
			_model_checks = _checks - before
			_operands = {
				"reached": _model_checks,
				"expected": StadiumSmallYardGeometryRebuildChecks.expected_checks()
			}
			_check(
				_model_checks == StadiumSmallYardGeometryRebuildChecks.expected_checks(),
				"every bounded source-held visible geometry assertion is reached"
			)
			await _close_view()
			before = _checks
			await _runtime_and_views()
			_phase_counts.runtime_and_views = _checks - before
	_phase = "completion"
	_check(
		_images == ["small-yard-scenery-overview.png", "small-yard-scenery-details.png"],
		"exactly two readable native originals at most 1280 by 720 and zero games"
	)
	var expected: int = (
		EXPECTED_NON_GEOMETRY_CHECKS + StadiumSmallYardGeometryRebuildChecks.expected_checks()
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
		"new_mechanics": false,
		"model_checks": _model_checks,
		"model_expected_checks": StadiumSmallYardGeometryRebuildChecks.expected_checks(),
		"phase_checks": _phase_counts,
		"paid_copy_ids": _copies,
		"paid_inventory": _paid.construction().to_data() if _paid != null else {},
		"base27": _base27,
		"layout": _layout,
		"snapshot": _snapshot,
		"layout_snapshots": _records,
		"ownership_cases": _ownership_cases,
		"contact_cases": _contact_cases,
		"route_cases": _route_cases,
		"camera_cases": _camera_cases,
		"workshop_preview": _ui_cases,
		"physical_traversal": _physical,
		"capture_layout":
		"one installed-yard native overview and five native item-detail tiles in one 1280x720 original"
	}
	_check(
		JSON.stringify(payload, "", true, true).to_utf8_buffer().size() <= 131072,
		"combined small-yard evidence stays finite and bounded"
	)
	var file: FileAccess = FileAccess.open(
		directory.path_join("small-yard-scenery-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "combined small-yard evidence opens")
	_operands = {"reached": _checks + 1, "expected": expected, "phases": _phase_counts}
	_check(
		(
			_checks + 1 == expected
			and _phase_counts.get("ownership", 0) == 299
			and _phase_counts.get("workshop_controls", 0) == 11
			and _phase_counts.get("runtime_and_views", 0) == 64
		),
		"every bounded shared fixture assertion is reached exactly"
	)
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "combined small-yard evidence fully writes")
		file.close()
	print(
		(
			(
				"SMALL_YARD_SCENERY_REBUILD checks=%d failures=%d model_checks=%d images=%d games=0 "
				+ "synthetic_funding=true"
			)
			% [_checks, _failures, _model_checks, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}

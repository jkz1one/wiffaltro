extends "res://src/tests/stadium_live_furnishing_rebuild_checks_fixture_base.gd"
func _report_contact(resolver: BallPlayResolver, initially_foul: bool, label: String) -> void:
	var names: Array[String] = ["out", "foul", "single", "double", "triple", "home_run"]
	var result: String = "out" if _outcomes.is_empty() else names[_outcomes[0].result]
	var reason: String = "" if _outcomes.is_empty() else String(_outcomes[0].reason)
	var plays: Array = [
		{
			"result": result,
			"contact":
			ContactResult.Outcome.FOUL if initially_foul else ContactResult.Outcome.CONTACT,
			"exit_speed": 12.0
		}
	]
	var events: Array = resolver.state.stadium_contacts.duplicate(true)
	var rows: Array = [{"play": 0, "reason": reason, "events": events}]
	var accepted: bool = (
		not events.is_empty() and PhysicalStadiumContacts.valid(rows, plays, _snapshot)
	)
	_operands = {"case": label, "events": events, "result": result, "reason": reason}
	_check(accepted, "actual resolver event survives ordinary report provenance " + label)
	var altered: Array = rows.duplicate(true)
	if not events.is_empty():
		altered[0].events[0].surface = "INVENTED_FURNISHING_SURFACE"
	_check(
		not events.is_empty() and not PhysicalStadiumContacts.valid(altered, plays, _snapshot),
		"ordinary report rejects forged surface on actual flight " + label
	)
	altered = rows.duplicate(true)
	if not events.is_empty():
		altered[0].events[0].id = _copies["ST-007"][1]
	_check(
		not events.is_empty() and not PhysicalStadiumContacts.valid(altered, plays, _snapshot),
		"ordinary report rejects substituting a scenery-owned copy " + label
	)
	var water_negatives: Dictionary = {}
	if label.begins_with("water-"):
		var inverted: Array = plays.duplicate(true)
		inverted[0].contact = (
			ContactResult.Outcome.CONTACT if initially_foul else ContactResult.Outcome.FOUL
		)
		var classification_rejected: bool = not PhysicalStadiumContacts.valid(
			rows, inverted, _snapshot
		)
		_operands = {
			"case": label,
			"original_contact": plays[0].contact,
			"forged_contact": inverted[0].contact,
			"unchanged_result": result,
			"unchanged_reason": reason,
			"events": events
		}
		_check(
			classification_rejected,
			"water report refuses inverted original fair or foul classification " + label
		)
		var dry: Array = rows.duplicate(true)
		var center: Vector3 = (
			StadiumLiveFurnishingItems.row(_copies["ST-007"][0], "ST-007", "OL-L").position
		)
		var forged_center: Vector3 = (
			center + Vector3(0, StadiumLiveFurnishingModels.TUB_WATER + 0.049, 0)
		)
		if not events.is_empty():
			dry[0].events[0].position = _v3(forged_center)
		var dry_rejected: bool = (
			not events.is_empty() and not PhysicalStadiumContacts.valid(dry, plays, _snapshot)
		)
		_operands = {
			"case": label,
			"forged_center": _v3(forged_center),
			"height_above_water_m": 0.049,
			"supported_ball_radius_m": 0.0365,
			"dry_gap_m": 0.0125,
			"events": dry
		}
		_check(
			dry_rejected,
			"water report rejects a forged dry center 0.049 m above the water plane " + label
		)
		water_negatives = {
			"inverted_original_contact": inverted[0].contact,
			"original_contact": plays[0].contact,
			"classification_rejected": classification_rejected,
			"forged_dry_center": _v3(forged_center),
			"height_above_water_m": 0.049,
			"supported_ball_radius_m": 0.0365,
			"dry_gap_m": 0.0125,
			"dry_center_rejected": dry_rejected
		}
	_report_cases.append(
		{
			"case": label,
			"result": result,
			"reason": reason,
			"accepted": accepted,
			"forged_surface_rejected": true,
			"scenery_copy_rejected": true,
			"water_negatives": water_negatives
		}
	)


func _terminal_home_run(root: Node3D, boundary: StadiumBoundaryOwnedRuntime, tub: Node3D) -> void:
	var from: Vector3 = tub.global_position + Vector3(0, 1.65, 0)
	var context: Dictionary = _bound(root, boundary, from, false)
	context.resolver.state.raise_result_floor(BallPlayState.ResultFloor.HOME_RUN)
	context.resolver._resolve_floor(&"fixture_preexisting_home_run", from)
	var previous: Array = context.resolver.state.stadium_contacts.duplicate(true)
	await _launch(context, from, Vector3(0, -8, 0))
	for frame in range(12):
		await get_tree().physics_frame
	_check(
		(
			context.ball.global_position.y < from.y - 0.3
			and context.resolver.state.dead
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.HOME_RUN
		),
		"already-terminal Home Run remains the sole result during real physical water traversal"
	)
	_check(
		(
			context.resolver.state.stadium_contacts == previous
			and (
				boundary
				. observe(context.resolver, from, tub.global_position + Vector3(0, 0.5, 0))
				. is_empty()
			)
		),
		"already-terminal Home Run records no later hot-tub entry"
	)
	_contact_cases.append(
		{
			"case": "already-terminal-home-run",
			"native_moving_ball": true,
			"result": BallPlayOutcome.Result.HOME_RUN,
			"water_entries": 0,
			"events_unchanged": context.resolver.state.stadium_contacts == previous
		}
	)
	context.ball.free()
	await get_tree().physics_frame


func _moving_flights(
	root: Node3D, boundary: StadiumBoundaryOwnedRuntime, property: StadiumPropertyGeometry
) -> void:
	_phase = "registered-native-moving-ball-distinct-live-and-water-cases"
	var beach: Node3D = property.objects[_copies["ST-002"][0]]
	var tub: Node3D = property.objects[_copies["ST-007"][0]]
	var cases: Array = [
		[
			"beach",
			beach,
			Vector3(-1.2, 0.4, 0),
			Vector3(12, 0, 0),
			false,
			BallPlayState.ResultFloor.NONE,
			"LIVE_RICOCHET",
			-1,
			"BEACH_BALL"
		],
		[
			"rim",
			tub,
			Vector3(0, 0.95, -1.9),
			Vector3(0, 0, 12),
			false,
			BallPlayState.ResultFloor.NONE,
			"LIVE_RICOCHET",
			-1,
			"HOT_TUB_SHELL"
		],
		[
			"water-fair",
			tub,
			Vector3(0, 1.65, 0),
			Vector3(0, -8, 0),
			false,
			BallPlayState.ResultFloor.NONE,
			"HOT_TUB_WATER",
			BallPlayOutcome.Result.DOUBLE,
			"ST007_WATER_VOLUME_v1"
		],
		[
			"water-foul",
			tub,
			Vector3(0, 1.65, 0),
			Vector3(0, -8, 0),
			true,
			BallPlayState.ResultFloor.NONE,
			"HOT_TUB_WATER",
			BallPlayOutcome.Result.FOUL,
			"ST007_WATER_VOLUME_v1"
		],
		[
			"water-preearned-triple",
			tub,
			Vector3(0, 1.65, 0),
			Vector3(0, -8, 0),
			false,
			BallPlayState.ResultFloor.TRIPLE,
			"HOT_TUB_WATER",
			BallPlayOutcome.Result.TRIPLE,
			"ST007_WATER_VOLUME_v1"
		]
	]
	for row: Array in cases:
		var model: Node3D = row[1]
		var from: Vector3 = model.global_position + row[2]
		var context: Dictionary = _bound(root, boundary, from, row[4])
		context.resolver.state.raise_result_floor(row[5])
		var body: Node3D = model.get_node(
			"WaterVolume" if row[6] == "HOT_TUB_WATER" else "Collision/" + str(row[8])
		)
		var body_pose: Transform3D = body.global_transform
		var root_pose: Transform3D = model.global_transform
		var prior_boundary_contacts: int = boundary.contacts.size()
		await _launch(context, from, row[3])
		var start: Vector3 = context.ball.global_position
		for frame in range(45):
			await get_tree().physics_frame
			if not context.resolver.state.stadium_contacts.is_empty():
				break
		# Observe the solver response on two later native ticks, including duplicate suppression.
		await get_tree().physics_frame
		await get_tree().physics_frame
		var events: Array = context.resolver.state.stadium_contacts.duplicate(true)
		var contact: Dictionary = {} if events.is_empty() else events[0]
		var issued: Dictionary = (
			{} if boundary.contacts.size() <= prior_boundary_contacts else boundary.contacts[-1]
		)
		var terminal: bool = int(row[7]) >= 0
		_operands = {
			"case": row[0],
			"events": events,
			"issued": issued,
			"from": _v3(from),
			"launch": _v3(row[3]),
			"actual_start": _v3(start),
			"actual_current": _v3(context.ball.global_position),
			"velocity": _v3(context.ball.linear_velocity),
			"outcomes": _outcomes.size(),
			"body_id": body.get_instance_id()
		}
		_check(
			(
				context.ball.global_position.distance_to(start) > 0.15
				and (
					PhysicsServer3D.body_get_space(context.ball.get_rid())
					== root.get_world_3d().space
				)
				and context.ball.physics_contact_router.is_valid()
			),
			"fresh registered physical ball actually travels into " + str(row[0])
		)
		_check(
			(
				events.size() == 1
				and contact.get("source", "") == "item"
				and contact.get("id", "") == model.get_meta("owned_copy")
				and contact.get("role", "") == row[6]
				and contact.get("surface", "") == row[8]
			),
			"actual flight emits one exact-copy distinct surface event " + str(row[0])
		)
		_check(
			(
				(
					context.resolver.state.dead
					and _outcomes.size() == 1
					and _outcomes[0].result == row[7]
				)
				if terminal
				else (not context.resolver.state.dead and _outcomes.is_empty())
			),
			"actual live or terminal outcome preserves foul and earned floor " + str(row[0])
		)
		_check(
			(
				issued.get("body_id", -1) == body.get_instance_id()
				and issued.get("owned_copy", "") == model.get_meta("owned_copy")
				and body.global_transform == body_pose
				and model.global_transform == root_pose
			),
			(
				"actual event identifies the current immutable physical body or water carrier "
				+ str(row[0])
			)
		)
		if terminal:
			context.resolver.record_clean_control(
				&"late-defender", context.ball.global_position, true
			)
			_check(
				(
					(
						boundary
						. observe(context.resolver, context.ball.global_position, from)
						. is_empty()
					)
					and context.resolver.state.stadium_contacts == events
					and _outcomes.size() == 1
				),
				"terminal water entry cannot rebound or become a later catch " + str(row[0])
			)
		else:
			_check(
				context.ball.linear_velocity.dot(row[3]) < 0 and body.global_transform == body_pose,
				"real native body ricochets while the obstacle stays fixed " + str(row[0])
			)
		_report_contact(context.resolver, row[4], row[0])
		_contact_cases.append(
			{
				"case": row[0],
				"native_moving_ball": true,
				"ball_id": context.ball.get_instance_id(),
				"body_id": body.get_instance_id(),
				"copy": model.get_meta("owned_copy"),
				"surface": row[8],
				"events": events,
				"initial_foul": row[4],
				"preearned_floor": row[5],
				"terminal": terminal,
				"result": int(row[7]),
				"launch": _v3(row[3]),
				"finish": _v3(context.ball.global_position),
				"post_contact_velocity": _v3(context.ball.linear_velocity)
			}
		)
		context.ball.free()
		await get_tree().physics_frame
	await _terminal_home_run(root, boundary, tub)


func _preview_focus() -> void:
	_phase = "actual-paid-workshop-preview-focus"
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
		"actual Workshop preview builds the exact paid daylight-only layout"
	)
	var cases: Array[Dictionary] = []
	for item: String in ITEMS:
		var copy: String = _copies[item][0]
		preview.focus_copy(copy)
		await get_tree().process_frame
		var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
		var box: AABB = preview.board_bounds.get(copy, AABB())
		var contained: bool = preview.board_bounds.has(copy) and rect.size.x > 0 and rect.size.y > 0
		for index in range(8):
			var point: Vector3 = box.get_endpoint(index)
			contained = (
				contained
				and not preview.camera.is_position_behind(point)
				and rect.has_point(preview.camera.unproject_position(point))
			)
		_operands = {
			"item": item,
			"copy": copy,
			"viewport": [rect.size.x, rect.size.y],
			"bounds": str(box),
			"eye": _v3(preview.camera.position)
		}
		_check(
			contained,
			"actual Workshop focus includes all eight complete model-envelope corners " + item
		)
		cases.append(
			{
				"item": item,
				"copy": copy,
				"all_eight_corners_in_frame": contained,
				"eye": _v3(preview.camera.position)
			}
		)
	_ui_cases.merge(
		{"native_preview": true, "focus_cases": cases, "night_eligible": preview.night_eligible}
	)
	preview.queue_free()
	await get_tree().process_frame


func _scenery_flights(
	root: Node3D, boundary: StadiumBoundaryOwnedRuntime, property: StadiumPropertyGeometry
) -> void:
	_phase = "real-moving-ball-scenery-absence"
	for item: String in ITEMS:
		var model: Node3D = property.objects[_copies[item][1]]
		var from: Vector3 = model.global_position + Vector3(-2.0, 0.4, 0)
		var context: Dictionary = _bound(root, boundary, from, false)
		await _launch(context, from, Vector3(12, 0, 0))
		for frame in range(22):
			await get_tree().physics_frame
		_operands = {
			"item": item,
			"site": model.get_meta("site"),
			"start": _v3(from),
			"finish": _v3(context.ball.global_position),
			"contacts": context.resolver.state.stadium_contacts
		}
		_check(
			(
				context.ball.global_position.x > model.global_position.x + 1.4
				and context.resolver.state.stadium_contacts.is_empty()
				and not context.resolver.state.dead
				and _outcomes.is_empty()
			),
			"registered moving ball passes through scenery without contact or scoring " + item
		)
		_contact_cases.append(
			{
				"case": "scenery-pass-through:" + item,
				"native_moving_ball": true,
				"copy": model.get_meta("owned_copy"),
				"site": model.get_meta("site"),
				"events": context.resolver.state.stadium_contacts.duplicate(true),
				"from": _v3(from),
				"finish": _v3(context.ball.global_position)
			}
		)
		context.ball.free()
		await get_tree().physics_frame


func _aperture_guards(
	root: Node3D, boundary: StadiumBoundaryOwnedRuntime, property: StadiumPropertyGeometry
) -> void:
	_phase = "actual-water-aperture-and-earliest-rim-ordering"
	var tub: Node3D = property.objects[_copies["ST-007"][0]]
	var center: Vector3 = tub.global_position
	_check(
		(
			StadiumLiveFurnishingRuntime
			. water_entry(
				tub, center + Vector3(1.31, 1.5, 0), center + Vector3(1.31, 0.5, 0), 0.0365
			)
			. is_empty()
		),
		"outside the actual inner polygon cannot become water through outer-rim volume"
	)
	_check(
		(
			StadiumLiveFurnishingRuntime
			. water_entry(
				tub, center + Vector3(0, 0.8165, -0.2), center + Vector3(0, 0.8165, 0.2), 0.0365
			)
			. is_empty()
		),
		"water-plane tangent-only sphere travel creates no entry"
	)
	var context: Dictionary = _bound(root, boundary, center + Vector3(-1.9, 0.70, 0), false, true)
	var above: Dictionary = boundary.event(
		center + Vector3(-1.9, 1.20, 0), center + Vector3(1.9, 1.20, 0), 0.0365, context.resolver
	)
	_check(
		above.is_empty() and context.resolver.state.stadium_contacts.is_empty(),
		"above-rim pass remains outside shell and actual water aperture"
	)
	var rim: Dictionary = boundary.observe(
		context.resolver, center + Vector3(-1.9, 0.70, 0), center + Vector3(0, 0.70, 0)
	)
	var same_frame: Dictionary = boundary.observe(
		context.resolver, center + Vector3(0, 1.2, 0), center + Vector3(0, 0.65, 0)
	)
	_check(
		(
			same_frame.is_empty()
			and rim.get("kind", "") == "furnishing_solid"
			and rim.get("surface", "") == "HOT_TUB_SHELL"
			and not context.resolver.state.dead
			and context.resolver.state.stadium_contacts.size() == 1
		),
		"earliest real shell sweep blocks later same-segment water entry"
	)
	await get_tree().physics_frame
	var water: Dictionary = boundary.observe(
		context.resolver, center + Vector3(0, 1.2, 0), center + Vector3(0, 0.65, 0)
	)
	_check(
		(
			water.get("kind", "") == "furnishing_water"
			and context.resolver.state.dead
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.DOUBLE
			and context.resolver.state.stadium_contacts.size() == 2
		),
		"later legitimate aperture entry can terminate after an earlier live rim contact"
	)
	_contact_cases.append(
		{
			"case": "issued-sweeps-rim-then-later-water",
			"native_moving_ball": false,
			"registered_native_sphere_queries": true,
			"same_segment_rim_first": rim.get("kind", "") == "furnishing_solid",
			"later_water": water.get("kind", "") == "furnishing_water",
			"events": context.resolver.state.stadium_contacts.duplicate(true)
		}
	)
	context.ball.free()


func _token_guards(
	root: Node3D, boundary: StadiumBoundaryOwnedRuntime, property: StadiumPropertyGeometry
) -> void:
	_phase = "exact-event-copy-ball-flight-and-single-use-guards"
	var model: Node3D = property.objects[_copies["ST-002"][0]]
	var from: Vector3 = model.global_position + Vector3(-1.0, 0.4, 0)
	var to: Vector3 = model.global_position + Vector3(0, 0.4, 0)
	var context: Dictionary = _bound(root, boundary, from, false, true)
	var issued: Dictionary = boundary.event(from, to, 0.0365, context.resolver)
	_check(
		(
			issued.get("kind", "") == "furnishing_solid"
			and issued.get("owned_copy", "") == _copies["ST-002"][0]
			and issued.get("body_id", 0) > 0
		),
		"ordinary issued token names exact live copy and native body"
	)
	var forged: Dictionary = issued.duplicate(true)
	forged["owned_copy"] = _copies["ST-002"][1]
	_check(
		(
			not boundary.apply_event(context.resolver, forged)
			and context.resolver.state.stadium_contacts.is_empty()
		),
		"altered exact-copy token cannot authorize another owned or scenery copy"
	)
	var foreign: BallPlayResolver = BallPlayResolver.new()
	foreign.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	_check(
		not boundary.apply_event(foreign, issued) and foreign.state.stadium_contacts.is_empty(),
		"issued token cannot be moved to a foreign resolver"
	)
	_check(
		(
			boundary.apply_event(context.resolver, issued)
			and not boundary.apply_event(context.resolver, issued)
			and context.resolver.state.stadium_contacts.size() == 1
			and not context.resolver.state.dead
		),
		"one exact issued live token applies once and never duplicates contact"
	)
	var stale: Dictionary = boundary.event(from, to, 0.0365, context.resolver)
	var substitute: BattedBallBody = BattedBallBody.new()
	substitute.freeze = true
	root.add_child(substitute)
	substitute.position = from
	property.bind_ball(substitute, context.resolver)
	boundary.bind_ball(substitute, context.resolver)
	_check(
		(
			not boundary.apply_event(context.resolver, stale)
			and context.resolver.state.stadium_contacts.size() == 1
		),
		"same resolver and play cannot transfer an issued token to a replacement physical ball"
	)
	substitute.free()
	property.bind_ball(context.ball, context.resolver)
	boundary.bind_ball(context.ball, context.resolver)
	stale = boundary.event(from, to, 0.0365, context.resolver)
	context.resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	property.bind_ball(context.ball, context.resolver)
	boundary.bind_ball(context.ball, context.resolver)
	_check(
		(
			not boundary.apply_event(context.resolver, stale)
			and context.resolver.state.stadium_contacts.is_empty()
		),
		"same physical ball rejects a token from the preceding play"
	)
	stale = boundary.event(from, to, 0.0365, context.resolver)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = Vector3.ZERO
	context.ball.launch(launch)
	_check(
		(
			not boundary.apply_event(context.resolver, stale)
			and context.resolver.state.stadium_contacts.is_empty()
		),
		"relaunch serial prevents old same-ball same-play token reuse"
	)
	context.ball.free()
	await _aperture_guards(root, boundary, property)


func _views(root: Node3D, property: StadiumPropertyGeometry) -> void:
	_phase = "two-readable-native-installed-originals"
	var bounds: Rect2 = StadiumProperty.BOUNDS["expanded"]
	var target: Vector3 = Vector3(bounds.get_center().x, 0.6, bounds.get_center().y)
	var camera: Camera3D = _studio(root, target + Vector3(42, 59, -67), target, 76)
	_label(
		root, "PAID LIVE FURNISHINGS | Installed property and scenery sites", Vector2(22, 18), 22
	)
	await _capture("live-furnishing-overview.png")
	for child: Node in root.get_children():
		if child is Label:
			child.queue_free()
	await get_tree().process_frame
	_view.size = Vector2i(640, 720)
	var canvas: Image = Image.create(1280, 720, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("16232e"))
	var details: Array = [
		[
			"ST-002",
			Vector3(0, 0.4, 0),
			Vector3(2.5, 1.7, -3),
			1.8,
			"STRIPED BEACH BALL",
			"Diameter 0.8 m | Fixed center | Contact wobble only"
		],
		[
			"ST-007",
			Vector3(0, 0.45, 0),
			Vector3(4, 4.8, -5),
			4.5,
			"WOOD-SIDED HOT TUB",
			"Outer radius 1.3 m | Open rim | Actual water aperture"
		]
	]
	for index in range(details.size()):
		var detail: Array = details[index]
		var model: Node3D = property.objects.get(_copies[detail[0]][0])
		_check(
			is_instance_valid(model),
			"detail uses the actual installed paid model " + str(detail[0])
		)
		if not is_instance_valid(model):
			continue
		if detail[0] == "ST-002":
			var pivot: StadiumLiveFurnishingWobble = (
				model.get_node("Visual/BallPivot") as StadiumLiveFurnishingWobble
			)
			pivot.apply_elapsed(StadiumLiveFurnishingWobble.DURATION)
		var focus: Vector3 = model.global_position + detail[1]
		camera.position = focus + detail[2]
		camera.look_at(focus)
		camera.size = detail[3]
		_label(root, detail[4], Vector2(16, 18), 23)
		_label(root, detail[5], Vector2(16, 680), 16)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var tile: Image = _view.get_texture().get_image()
		_check(
			not tile.is_empty() and tile.get_size() == Vector2i(640, 720),
			"actual native full-height detail tile " + str(detail[0])
		)
		if not tile.is_empty():
			tile.convert(Image.FORMAT_RGBA8)
			canvas.blit_rect(
				tile, Rect2i(Vector2i.ZERO, Vector2i(640, 720)), Vector2i(index * 640, 0)
			)
		for child: Node in root.get_children():
			if child is Label:
				child.queue_free()
	_check(
		(
			canvas.get_size() == SIZE
			and canvas.save_png(_capture_dir.path_join("live-furnishing-details.png")) == OK
		),
		"two native close-up tiles save one readable bounded 1280 by 720 original"
	)
	_images.append("live-furnishing-details.png")


func _runtime_and_views() -> void:
	_phase = "ordinary-frozen-snapshot-installation"
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
		"snapshot_version": _snapshot.get("version", -1),
		"layout_version": _layout.get("version", -1)
	}
	_check(installed, "ordinary frozen-snapshot startup installs complete family27 property")
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
		"ordinary property and boundary retain exact sealed identities"
	)
	if boundary == null:
		await _close_view()
		return
	var checked: Dictionary = _checked(_layout)
	var rows: Array = checked.get("live_furnishing_placements", [])
	var inspected: Array[Dictionary] = []
	var scenery_copies: Array[String] = []
	for placed: Dictionary in rows:
		var model: Node3D = property.objects.get(placed.copy)
		var live: bool = placed.site.begins_with("O")
		var exact: bool = (
			is_instance_valid(model)
			and model.get_meta("stadium_item", "") == placed.item
			and model.get_meta("owned_copy", "") == placed.copy
			and model.get_meta("site", "") == placed.site
		)
		_operands = {
			"copy": placed.copy,
			"item": placed.item,
			"site": placed.site,
			"model_found": is_instance_valid(model)
		}
		_check(
			(
				exact
				and model.position.is_equal_approx(placed.position)
				and is_zero_approx(model.rotation.y)
			),
			"installed exact paid model keeps its full-scale fixed pose " + placed.site
		)
		if not exact:
			continue
		var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
		var shapes: Array[Node] = model.find_children("*", "CollisionShape3D", true, false)
		var expected_shapes: int = 1 if placed.item == "ST-002" else 65
		_check(
			(
				(
					bodies.size() == 1
					and shapes.size() == expected_shapes
					and model.has_node("WaterVolume") == (placed.item == "ST-007")
				)
				if live
				else (
					bodies.is_empty()
					and shapes.is_empty()
					and not model.has_node("WaterVolume")
					and model.get_meta("scenery_only", false)
				)
			),
			(
				(
					"actual descendant traversal distinguishes live physical model from absent scenery "
					+ "collision and water "
				)
				+ placed.site
			)
		)
		if not live:
			scenery_copies.append(placed.copy)
		inspected.append(
			{
				"copy": placed.copy,
				"item": placed.item,
				"site": placed.site,
				"live": live,
				"position": _v3(model.position),
				"bodies": bodies.size(),
				"shapes": shapes.size(),
				"water_volume": model.has_node("WaterVolume")
			}
		)
	_check(
		inspected.size() == 4 and property.objects.size() == checked.placements.size(),
		"ordinary installed inventory has exactly four paid furnishings plus the inherited receiver"
	)
	var scene_leak: bool = false
	var all_bodies: Array[Node] = property.find_children("*", "CollisionObject3D", true, false)
	for body: Node in all_bodies:
		scene_leak = scene_leak or scenery_copies.has(str(body.get_meta("owned_copy", "")))
	_check(
		not all_bodies.is_empty() and not scene_leak,
		"whole-property physical traversal contains no scenery-owned collision object"
	)
	var routes: Array[Dictionary] = property.route_obstacles()
	var route_ids: Array = routes.map(func(row: Dictionary) -> String: return str(row.copy))
	route_ids.sort()
	var expected_ids: Array = [_copies["ST-002"][0], _copies["ST-007"][0], "starter-v1:ST-079"]
	expected_ids.sort()
	_check(
		route_ids == expected_ids and lab._primary_fielder.stadium_obstacles == routes,
		"real installed fielder receives live furnishings and inherited receiver only"
	)
	_physical = {
		"ordinary_install": installed,
		"models": inspected,
		"whole_property_collision_objects": all_bodies.size(),
		"scenery_collision_objects": 0 if not scene_leak else -1,
		"route_copy_ids": route_ids
	}
	_actor_routes(lab, rows, routes)
	_camera_clearance(lab, rows)
	await _preview_focus()
	await _moving_flights(root, boundary, property)
	await _scenery_flights(root, boundary, property)
	await _token_guards(root, boundary, property)
	_check(
		(
			property.props_intact()
			and boundary.intact()
			and lab._play_records.is_empty()
			and lab._batted_ball == null
		),
		"bounded registered flights leave installed property intact without starting a game"
	)
	await _views(root, property)
	_current_water_guard(property)
	_current_body_guard(root, boundary, property)
	await _close_view()

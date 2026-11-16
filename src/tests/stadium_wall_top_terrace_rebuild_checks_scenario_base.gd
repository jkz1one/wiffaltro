extends "res://src/tests/stadium_wall_top_terrace_rebuild_checks_fixture_base.gd"
func _terrain_dispatch_check() -> void:
	var started: int = _timing_mark("terrain-dispatch-equivalence", "begin")
	_terrain_dispatch = {
		"case_count": 99,
		"cases": [],
		"all_equal": true,
		"legacy_method_sha256": "f2da44515dfc345ffc22c1099f97d7f80095ea6ac8c4999eb9ee82834bcf8d0c",
		"classification_only": false,
		"legacy_usec": 0,
		"current_usec": 0,
		"equivalence_case_count": 97,
		"rejection_case_count": 2,
		"malformed_rejections": [],
		"all_rejected": true
	}
	# Every supported18..36 classifier, raw17, both ordinary/terrain selectors,
	# and both existing ground-box base28/29 routes. This does not validate a layout.
	for version: int in range(17, 37):
		for base_version: int in [12, 17]:
			for ground_box_base: int in [28, 29]:
				var layout: Dictionary = {
					"version": version,
					"base_version": base_version,
					"ground_box_base_version": ground_box_base
				}
				_terrain_dispatch_case(
					"layout:%d:base:%d:ground-box:%d" % [version, base_version, ground_box_base],
					[{"layout": layout}],
					version == 17 or base_version == 17
				)
	_terrain_dispatch_case("null-events", null, false)
	_terrain_dispatch_case("string-events", "", false)
	_terrain_dispatch_case("dictionary-events", {}, false)
	_terrain_dispatch_case("non-dictionary-event-rows", [null, false, 17, "layout", []], false)
	_terrain_dispatch_case("missing-layout", [{}], false)
	_terrain_dispatch_case(
		"non-dictionary-layouts", [{"layout": []}, {"layout": null}, {"layout": "36"}], false
	)
	_terrain_dispatch_case(
		"missing-version", [{"layout": {"base_version": 17, "ground_box_base_version": 28}}], false
	)
	_terrain_public_rejection("string-version", "36")
	_terrain_dispatch_case(
		"nonwhole-version",
		[{"layout": {"version": 35.5, "base_version": 17, "ground_box_base_version": 28}}],
		false
	)
	_terrain_dispatch_case(
		"unknown-version",
		[{"layout": {"version": 37, "base_version": 17, "ground_box_base_version": 28}}],
		false
	)
	_terrain_public_rejection("boolean-version", true)
	_terrain_dispatch_case(
		"nonfinite-versions", [{"layout": {"version": NAN}}, {"layout": {"version": INF}}], false
	)
	_terrain_dispatch_case(
		"missing-ground-box-base", [{"layout": {"version": 36, "base_version": 17}}], false
	)
	_terrain_dispatch_case(
		"invalid-ground-box-bases",
		[
			{"layout": {"version": 36, "base_version": 17, "ground_box_base_version": 27}},
			{"layout": {"version": 36, "base_version": 17, "ground_box_base_version": 30}},
			{"layout": {"version": 36, "base_version": 17, "ground_box_base_version": "28"}},
			{"layout": {"version": 36, "base_version": 17, "ground_box_base_version": 28.5}},
			{"layout": {"version": 36, "base_version": 17, "ground_box_base_version": true}}
		],
		false
	)
	_terrain_dispatch_case(
		"missing-terrain-base", [{"layout": {"version": 36, "ground_box_base_version": 28}}], false
	)
	_terrain_dispatch_case(
		"invalid-terrain-bases",
		[
			{"layout": {"version": 36, "base_version": "17", "ground_box_base_version": 28}},
			{"layout": {"version": 36, "base_version": 17.5, "ground_box_base_version": 28}},
			{"layout": {"version": 36, "base_version": true, "ground_box_base_version": 28}}
		],
		false
	)
	_terrain_dispatch_case("raw17-no-subselectors", [{"layout": {"version": 17}}], true)
	_terrain_dispatch_case("raw17-json-float", [{"layout": {"version": 17.0}}], true)
	_terrain_dispatch_case(
		"classification-ignores-family-label",
		[
			{
				"layout":
				{
					"version": 36,
					"family": "not-a-valid-layout",
					"base_version": 17,
					"ground_box_base_version": 28
				}
			}
		],
		true
	)
	var first_difference: Dictionary = {}
	for row: Dictionary in _terrain_dispatch.cases:
		if not row.same:
			first_difference = row
			break
	_operands = {
		"equivalence_cases": _terrain_dispatch.cases.size(),
		"first_difference": first_difference,
		"malformed_rejections": _terrain_dispatch.malformed_rejections
	}
	_check(
		(
			_terrain_dispatch.cases.size() == 97
			and _terrain_dispatch.all_equal
			and _terrain_dispatch.malformed_rejections.size() == 2
			and _terrain_dispatch.all_rejected
		),
		(
			"97 valid-domain legacy classifications remain exact and two malformed versions are "
			+ "rejected by the normal public transaction without mutation"
		)
	)
	_timing_mark("terrain-dispatch-equivalence", "end", started)


func _ownership() -> void:
	_phase = "exact-paid-hosts-gates-and-store-first-lifecycle"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 10, "hits": 4})
	_terrain_dispatch_check()
	_check(
		StadiumCareerProgress.valid(_progress, _credits),
		"explicit synthetic closed metrics qualify without an earned-career claim"
	)
	_paid = ClubAssetLedger.new_club(SEED, _credits, _progress)
	var starter: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"adoption grants no terrace or paid wall panels"
	)
	var entry: Dictionary = StadiumCatalog.item(ITEM)
	var gate: Dictionary = {"seasons": 14, "wins": 44}
	_check(
		(
			entry.blueprint_price == 950
			and entry.copy_price == 280
			and ClubCareer.same(entry.requires, gate)
		),
		"unchanged ST-087 prices and exact S14 W44 unlock operands"
	)
	_check(
		StadiumPurchases.quote(_paid.construction(), ITEM, 2, "terrace-exact-gate", 27, gate).ok,
		"current price27 accepts exact terrace threshold"
	)
	for key: String in gate:
		var below: Dictionary = gate.duplicate(true)
		below[key] -= 1
		_check(
			not (
				StadiumPurchases
				. quote(_paid.construction(), ITEM, 2, "terrace-below:" + key, 27, below)
				. ok
			),
			"each just-below unlock operand refuses " + key
		)
	_check(
		not StadiumPurchases.quote(_paid.construction(), ITEM, 2, "terrace-old-price", 26, gate).ok,
		"older price26 route cannot buy terrace"
	)
	_wall_copies["ST-065"] = _buy("ST-065", 8, 23, 1325)
	_wall_copies["ST-077"] = _buy("ST-077", 8, 23, 1735)
	_copies = _buy(ITEM, 27, 2, 1510)
	var trees: Array[String] = _buy("ST-013", 18, 1, 340)
	var hedges: Array[String] = _buy("ST-014", 18, 1, 245)
	if _copies.size() != 2 or trees.size() != 1 or hedges.size() != 1:
		return
	_controls = {"ST-013": trees[0], "ST-014": hedges[0]}
	_check(
		(
			_wall_copies["ST-065"].size() == 23
			and _wall_copies["ST-077"].size() == 23
			and _paid.construction().copies.size() == 53
			and StadiumLayoutSnapshot.matches(starter, _paid)
		),
		"five normal purchases create exactly fifty paid copies and preserve authenticated starter prefix"
	)
	# TERRACE_TIMING_ONLY
	var land_started: int = _timing_mark("ownership:land-and-empty-families", "begin")
	for tier: String in ["expanded", "club", "mogul"]:
		var result: Dictionary = _paid.commit(
			{
				"id": "terrace-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(
			result.ok and _paid.construction().copies.size() == 53,
			"ordinary land purchase grants no construction copies " + tier
		)
	var inherited: Dictionary = StadiumRisingAppleItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	_check(
		_checked(inherited).ok and _apply(inherited),
		"accepted empty family35 applies before terrace adoption"
	)
	_record("inherited-family35", inherited)
	_old_prefix = StadiumLayoutSnapshot.capture(_paid)
	_empty = StadiumWallTopTerraceItems.upgrade(inherited, _paid.surface_owned())
	_check(
		(
			_empty.version == 36
			and _empty.wall_top_terrace.is_empty()
			and ClubCareer.same(StadiumWallTopTerraceItems.base(_empty), inherited)
			and _checked(_empty).ok
			and _apply(_empty)
		),
		"empty family36 preserves every inherited channel without granting hosts"
	)
	_record("empty-terrace-family", _empty)
	_timing_mark("ownership:land-and-empty-families", "end", land_started)  # TERRACE_TIMING_ONLY
	_check(
		_place(_empty, _copies[0]).wall_top_terrace.is_empty(),
		"terrace cannot mount on an unpaid template back wall"
	)
	var balance: int = _paid.balance()
	for host: String in HOST_ITEMS:
		var host_started: int = _timing_mark("ownership:host:" + host, "begin")  # TERRACE_TIMING_ONLY
		var supported: Dictionary = _wall(_empty, host)
		var info: Dictionary = StadiumWallTopTerraceItems.host_info(supported, _paid.construction())
		_check(
			(
				info.ok
				and supported.walls.back.copies.size() == 23
				and info.host_copies.size() == 6
				and ClubCareer.same(info.host_copies, supported.walls.back.copies.slice(1, 7))
				and info.host_sockets.size() == 6
			),
			"ordinary full wall proposal designates exactly six paid full-panel hosts " + host
		)
		_check(
			_checked(supported).ok and _apply(supported),
			"complete paid straight host run applies with terrace stored " + host
		)
		_record("complete-host-run:" + host, supported)
		var mounted: Dictionary = _place(supported, _copies[0])
		_check(
			_checked(mounted).ok and _apply(mounted) and _paid.balance() == balance,
			"exact paid terrace mounts on the selected host profile without extra charge " + host
		)
		_record("mounted-profile:" + host, mounted)
		_layouts[host] = mounted.duplicate(true)
		_snapshots[host] = StadiumLayoutSnapshot.capture(_paid)
		var stored: Dictionary = StadiumWallTopTerraceItems.store_copy(mounted, _copies[0])
		_check(
			(
				ClubCareer.same(stored, supported)
				and _checked(stored).stored.has(_copies[0])
				and _apply(stored)
			),
			(
				"Store removes only terrace placement while retaining all paid hosts and both terrace copies "
				+ host
			)
		)
		_record("stored-profile:" + host, stored)
		var removed: Dictionary = _wall(stored, "")
		_check(
			_checked(removed).ok and _apply(removed) and removed.wall_top_terrace.is_empty(),
			"host removal succeeds after explicit terrace Store " + host
		)
		var restored: Dictionary = _wall(removed, host)
		_check(
			(
				_checked(restored).ok
				and _apply(restored)
				and restored.wall_top_terrace.is_empty()
				and _checked(restored).stored.has(_copies[0])
			),
			"restoring complete hosts never auto-remounts stored terrace " + host
		)
		_check(
			(
				ClubCareer.same(_place(restored, _copies[0]), mounted)
				and _apply(mounted)
				and _paid.balance() == balance
			),
			"same paid terrace remounts with exact same six host identities " + host
		)
		_check(_apply(stored), "explicit Store separates successive host profiles " + host)
		_timing_mark("ownership:host:" + host, "end", host_started)  # TERRACE_TIMING_ONLY
	var first: Dictionary = _layouts["ST-065"]
	_check(_apply(first), "first profile restored for dependency refusals")
	_negatives(first)
	var swap: Dictionary = _place(
		StadiumWallTopTerraceItems.store_copy(first, _copies[0]), _copies[1]
	)
	_check(
		(
			_checked(swap).ok
			and _checked(swap).stored.has(_copies[0])
			and _apply(StadiumWallTopTerraceItems.store_copy(first, _copies[0]))
			and _apply(swap)
		),
		"explicit Store first swaps independently paid terrace copies"
	)
	_record("independent-terrace-copy-swap", swap)
	_check(
		(
			_apply(StadiumWallTopTerraceItems.store_copy(swap, _copies[1]))
			and _apply(first)
			and _paid.balance() == balance
			and _paid.to_data().version == 44
			and _paid.construction().copies.size() == 53
		),
		"final exact current copy applies on ledger44 with no extra inventory or charge"
	)
	var retry_before: Dictionary = _paid.to_data().duplicate(true)
	_check(
		(
			_paid.commit(_last_draft).get("replayed", false)
			and _paid.commit(_last_apply).get("replayed", false)
			and ClubCareer.same(retry_before, _paid.to_data())
		),
		"immutable exact draft and apply retries preserve entire paid journal"
	)
	_record("final-padded-current-copy", first)
	_snapshots["ST-065"] = StadiumLayoutSnapshot.capture(_paid)
	# TERRACE_TIMING_ONLY
	var cold_started: int = _timing_mark("ownership:cold-and-four-prefixes", "begin")
	var cold: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(_paid.to_data())), SEED, _credits, _progress
	)
	_check(
		(
			cold != null
			and ClubCareer.same(cold.to_data(), _paid.to_data())
			and StadiumLayoutSnapshot.matches(_old_prefix, _paid)
			and StadiumLayoutSnapshot.matches(_old_prefix, cold)
			and StadiumLayoutSnapshot.matches(_snapshots["ST-065"], cold)
			and StadiumLayoutSnapshot.matches(_snapshots["ST-077"], cold)
		),
		"accepted family35 prefix remains authenticated warm and cold"
	)
	_timing_mark("ownership:cold-and-four-prefixes", "end", cold_started)  # TERRACE_TIMING_ONLY
	var environment: Dictionary = StadiumFixtureEnvironment.capture(_snapshots["ST-065"], SEED, 2)
	_check(
		(
			StadiumFixtureEnvironment.valid(environment, _snapshots["ST-065"])
			and environment.mode == "day"
			and not _checked(first).get("night_qualified", true)
		),
		"frozen terrace fixture remains explicitly daylight-only"
	)


func _project_rect(camera: Camera3D, box: AABB) -> Rect2:
	var result: Rect2 = Rect2()
	var started: bool = false
	for index in range(8):
		var point: Vector3 = box.get_endpoint(index)
		if camera.is_position_behind(point):
			continue
		var pixel: Vector2 = camera.unproject_position(point)
		result = result.expand(pixel) if started else Rect2(pixel, Vector2.ZERO)
		started = true
	return result


func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _camera_clearance(lab: PitchBatLab, model: Node3D, host: String) -> void:
	_phase = "actual-current-normal-zoom-both-handed-camera:" + host
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
			lab._camera.reset_physics_interpolation()
			lab._camera.force_update_transform()
			await RenderingServer.frame_post_draw
			var protected: Rect2 = (
				_project_rect(
					lab._camera,
					AABB(PitchBatLab.MOUND_ORIGIN + Vector3(-1.6, 0, -0.8), Vector3(3.2, 3.6, 1.6))
				)
				. grow(16)
			)
			var reserve: AABB = StadiumWallTopTerraceItems.bounds(
				StadiumWallTopTerraceItems.row(_copies[0], ITEM, SITE)
			)
			var target: Vector3 = PitchBatLab.MOUND_ORIGIN + Vector3.UP
			var blocked: bool = (
				reserve.has_point(pose.origin)
				or reserve.intersects_segment(pose.origin, target) != null
			)
			var clear: bool = true
			var visible: int = 0
			for node: Node in model.get_node("Visual").find_children(
				"*", "MeshInstance3D", true, false
			):
				var mesh: MeshInstance3D = node as MeshInstance3D
				var projected: Rect2 = _project_rect(
					lab._camera, mesh.global_transform * mesh.get_aabb()
				)
				if projected.has_area():
					visible += 1
					clear = clear and not projected.intersects(protected)
			_operands = {
				"host_item": host,
				"left_handed": left,
				"zoom_in": zoom,
				"eye": _v3(pose.origin),
				"pitcher_target": _v3(target),
				"blocked": blocked,
				"backdrop_clear": clear,
				"protected_pitcher_rect": _rect(protected),
				"visible_meshes": visible,
				"checked_meshes": 152
			}
			_check(
				not blocked and clear and protected.has_area() and visible > 0,
				"actual current camera clears full reservation and every visible member from pitcher backdrop"
			)
			_camera_cases.append(_operands.duplicate(true))
	director._batter_side = old_side
	director.shot = old_shot
	director._presentation_motion = old_motion
	director._presentation_progress = old_progress
	lab._camera.transform = old_pose
	director._apply_projection(lab._camera)
	lab._camera.reset_physics_interpolation()
	lab._camera.force_update_transform()


func _ball(lab: PitchBatLab, at: Vector3) -> Dictionary:
	# Accepted receiver fixture's fresh moving-body registration contract.
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	resolver.segment_observer = lab._ball_play_resolver.segment_observer
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	lab.add_child(ball)
	ball.position = at
	_check(
		(
			resolver.segment_observer.is_valid()
			and StadiumPropertyRuntime.bind_ball(lab, ball, resolver)
		),
		"ordinary router binds fresh dynamic ball and installed segment observer"
	)
	return {"ball": ball, "resolver": resolver}


func _moving_wall_ball(
	lab: PitchBatLab, property: StadiumPropertyGeometry, model: Node3D, host: String, above: bool
) -> Dictionary:
	_phase = "native-wall-terminal-precedence:" + host + (":above" if above else ":low")
	# x=15 hits the exact center front guard post. Its field face is z=23.45:
	# sphere center crosses the 23.4 wall plane before its native terrace contact.
	var at: Vector3 = Vector3(15, 4.45 if above else 2.0, 21.5)
	var context: Dictionary = _ball(lab, at)
	var native_contacts: Array[Dictionary] = []
	context.ball.body_entered.connect(
		func(body: Node) -> void:
			if body.get_meta("owned_copy", "") == _copies[0]:
				native_contacts.append(
					{
						"body": str(body.name),
						"role": body.get_meta("surface_role", ""),
						"position": _v3(context.ball.global_position),
						"frame": Engine.get_physics_frames(),
						"already_terminal": context.resolver.state.dead,
						"outcome_count": _outcomes.size()
					}
				)
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = at
	launch.velocity = Vector3(0, 0, 8)
	context.ball.launch(launch)
	for frame in range(48):
		await get_tree().physics_frame
		context.resolver.advance_time(1.0 / 60.0)
		if context.resolver.state.dead and (not above or not native_contacts.is_empty()):
			break
	var expected: BallPlayOutcome.Result = (
		BallPlayOutcome.Result.HOME_RUN if above else BallPlayOutcome.Result.TRIPLE
	)
	var events: Array = context.resolver.state.stadium_contacts.duplicate(true)
	var role: String = "BACK_CLEAR" if above else "BACK_WALL_TERMINAL"
	var terminal_ok: bool = (
		_outcomes.size() == 1
		and _outcomes[0].result == expected
		and context.resolver.state.dead
		and events.size() == 1
		and events[0].source == "boundary"
		and events[0].role == role
	)
	_operands = {
		"host": host,
		"above": above,
		"events": events,
		"native_terrace_contacts": native_contacts,
		"outcomes": _outcomes.size(),
		"position": _v3(context.ball.global_position)
	}
	_check(
		terminal_ok,
		(
			"real registered flight resolves existing native wall Triple or above-wall HR before "
			+ "terrace authority"
		)
	)
	if above:
		var ordered: bool = not native_contacts.is_empty()
		for contact: Dictionary in native_contacts:
			ordered = (
				ordered
				and contact.already_terminal
				and contact.outcome_count == 1
				and contact.role == "DECORATIVE_AFTER_TERMINAL"
			)
		_check(
			ordered,
			"above-wall native terrace collision occurs only after the one actual home-run outcome"
		)
	var before_result: int = int(_outcomes[0].result) if _outcomes.size() == 1 else -1
	for body: Node in model.get_node("Collision").get_children():
		property._ball_contact(body, context.ball, context.resolver)
	_check(
		(
			context.resolver.state.dead
			and _outcomes.size() == 1
			and int(_outcomes[0].result) == before_result
			and ClubCareer.same(events, context.resolver.state.stadium_contacts)
			and context.resolver.state.last_obstacle_contact == &""
		),
		(
			"later issued terrace callbacks preserve existing outcome and cannot raise score or "
			+ "spend live units"
		)
	)
	var result_name: String = "home_run" if above else "triple"
	var reason: String = str(_outcomes[0].reason) if _outcomes.size() == 1 else ""
	var rows: Array = [{"play": 0, "reason": reason, "events": events}]
	var plays: Array = [
		{"result": result_name, "contact": ContactResult.Outcome.CONTACT, "exit_speed": 8.0}
	]
	var accepted: bool = (
		terminal_ok and PhysicalStadiumContacts.valid(rows, plays, _snapshots[host])
	)
	_check(
		accepted,
		"ordinary report consumer accepts exact seven-field actual boundary event and existing outcome"
	)
	var forged: Array = rows.duplicate(true)
	if not events.is_empty():
		forged[0].events[0].surface = "INVENTED-TERRACE-SCORE"
	_check(
		(
			not events.is_empty()
			and not PhysicalStadiumContacts.valid(forged, plays, _snapshots[host])
		),
		"same native outcome report refuses invented terrace surface"
	)
	var evidence: Dictionary = {
		"case": "above-wall" if above else "low-wall",
		"launch_position": _v3(at),
		"launch_velocity": _v3(launch.velocity),
		"registration_physics_frames": 2,
		"installed_segment_observer": true,
		"moving_body": true,
		"expected_result": result_name,
		"actual_result": before_result,
		"reason": reason,
		"events": events,
		"terminal": context.resolver.state.dead,
		"native_terrace_contacts": native_contacts,
		"later_issued_terrace_callbacks": model.get_node("Collision").get_child_count(),
		"late_callback_outcome_unchanged":
		_outcomes.size() == 1 and int(_outcomes[0].result) == before_result,
		"report_accepted": accepted,
		"forged_surface_rejected":
		(
			not events.is_empty()
			and not PhysicalStadiumContacts.valid(forged, plays, _snapshots[host])
		),
		"complete_game_claim": false
	}
	context.ball.free()
	await get_tree().physics_frame
	return evidence


func _preview_focus(host: String) -> void:
	_phase = "actual-owned-workshop-focus:" + host
	var preview: StadiumDraftPreview = StadiumDraftPreview.new()
	add_child(preview)
	preview.size = Vector2(640, 360)
	preview.build(
		_layouts[host], _paid.construction(), true, "mogul", null, null, _paid.surface_owned()
	)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(
		(
			preview.preview_property != null
			and preview.preview_property.props_intact()
			and not preview.night_eligible
		),
		"actual Workshop builds exact paid terrace and host profile in daylight " + host
	)
	preview.focus_copy(_copies[0])
	preview.camera.reset_physics_interpolation()
	preview.camera.force_update_transform()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var rect: Rect2 = preview.camera.get_viewport().get_visible_rect()
	var box: AABB = preview.board_bounds.get(_copies[0], AABB())
	var contained: bool = preview.board_bounds.has(_copies[0]) and rect.has_area()
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
			"actual owned-copy focus contains every full-reservation corner after renderer transform sync "
			+ host
		)
	)
	_ui_cases.native_preview = true
	_ui_cases.focus_cases.append(
		{
			"copy": _copies[0],
			"host_item": host,
			"site": SITE,
			"all_eight_corners_in_frame": contained
		}
	)
	await RenderingServer.frame_post_draw
	preview.queue_free()
	await get_tree().process_frame


func _runtime_model(
	root: Node3D,
	lab: PitchBatLab,
	property: StadiumPropertyGeometry,
	boundary: StadiumBoundaryOwnedRuntime,
	model: Node3D,
	host: String
) -> Dictionary:
	var row: Dictionary = _checked(_layouts[host]).wall_top_terrace_placements[0]
	_check(
		(
			model.get_meta("stadium_item", "") == ITEM
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == SITE
			and model.get_meta("host_item", "") == host
			and model.position == row.position
			and model.rotation == Vector3.ZERO
			and model.scale == Vector3.ONE
		),
		"actual complete model retains exact paid identity host and full-size pose " + host
	)
	var bound_hosts: Array = model.get_meta("terrace_host_copies")
	var original_hosts: Array = bound_hosts.duplicate()
	var original_item: String = model.get_meta("terrace_host_item")
	var baseline_seal: bool = property.props_intact()
	bound_hosts[0] = "purchase:forged-host:0"
	var host_array_rejected: bool = not property.props_intact()
	bound_hosts[0] = original_hosts[0]
	var array_restored: bool = property.props_intact()
	model.set_meta("terrace_host_item", "ST-077" if host == "ST-065" else "ST-065")
	var host_item_rejected: bool = not property.props_intact()
	model.set_meta("terrace_host_item", original_item)
	var metadata_restored: bool = property.props_intact()
	_check(
		(
			baseline_seal
			and host_array_rejected
			and array_restored
			and host_item_rejected
			and metadata_restored
		),
		(
			(
				"current-copy seal rejects in-place host-array and host-material edits and accepts "
				+ "exact restoration "
			)
			+ host
		)
	)
	var bodies: Array[Node] = model.find_children("*", "CollisionObject3D", true, false)
	var roles: bool = bodies.size() == 152
	for body: Node in bodies:
		roles = (
			roles
			and body is StaticBody3D
			and body.get_meta("owned_copy", "") == row.copy
			and body.get_meta("surface_role", "") == "DECORATIVE_AFTER_TERMINAL"
			and body.get_meta("ball_surface", &"") == &"stadium_scenery"
		)
	_check(
		roles and model.find_children("*", "Area3D", true, false).is_empty(),
		(
			"all 152 actual terrace solids are after-terminal scenery without receiver or water Areas "
			+ host
		)
	)
	var static_only: bool = (
		model.find_children("*", "AnimationPlayer", true, false).is_empty()
		and model.find_children("*", "RigidBody3D", true, false).is_empty()
	)
	for node: Node in [model] + model.find_children("*", "", true, false):
		static_only = static_only and not node.is_processing() and not node.is_physics_processing()
	_check(
		(
			static_only
			and model.get_meta("represented_audience_count", -1) == 0
			and not model.get_meta("connected_pedestrian_route", true)
			and model.get_meta("obstacle_units", -1) == 0
		),
		"assembly remains static scenery without crowd route bonus or obstacle effects " + host
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
		"issued decorative callbacks grant no scoring Double receiver or terminal authority " + host
	)
	ball.free()
	var surface: String = str(bodies[0].get_meta("surface_id", bodies[0].name))
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
				_snapshots[host]
			),
			"existing report rejects fabricated terrace scoring authority " + host + ":" + role
		)
	var tracking: BallTrackingVisibility = lab._camera_director.tracking_visibility
	var count: int = 0
	var collected: bool = true
	for mesh: Node in model.get_node("Visual").find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (
			(mesh as MeshInstance3D).global_transform * (mesh as MeshInstance3D).get_aabb()
		)
		if box.size.y > 0.025:
			count += 1
			collected = collected and tracking._obstacles.has(box)
	_check(
		count > 0 and collected and tracking._owned_receiver_models.is_empty(),
		(
			(
				"actual current tracking contains all qualifying visible member bounds without "
				+ "receiver exception "
			)
			+ host
		)
	)
	return {
		"copy": row.copy,
		"item": ITEM,
		"host_item": host,
		"physical_scenery_bodies": bodies.size(),
		"active_animation": not static_only,
		"issued_decorative_callbacks": bodies.size(),
		"callback_score_events": resolver.state.stadium_contacts.size(),
		"callback_terminal": resolver.state.dead,
		"tracking_mesh_bounds": count,
		"tracking_collected": collected,
		"false_scoring_reports_rejected": 2,
		"host_array_edit_rejected": host_array_rejected,
		"host_item_edit_rejected": host_item_rejected,
		"host_metadata_exactly_restored": metadata_restored
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

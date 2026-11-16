extends "res://src/tests/stadium_yard_tracking_test.gd"
## Actual unchanged pitch/batted visuals against each finish, relative to the original flat field.

var _native_pairs: int = 0
var _minimum_ratio: float = INF
var _pitch_samples: int = 0
var _group: String = "all"
var _terrain_checks: int = 0
var _terrain_launches: int = 0
var _terrain_samples: int = 0
var _terrain_installs: int = 0


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--surface-terrain-contact"):
		await _terrain_contacts()
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--surface-group="):
			_group = argument.trim_prefix("--surface-group=")
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	get_window().size = Vector2i(1280, 720)
	var profiles: Array = [
		["rough_dirt", "short", "", "", true], ["maintained_dirt", "short", "", "", true]
	]
	for length: String in StadiumGrassFinish.HEIGHTS:
		profiles.append(["grass", length, "ST-063b", "ST-063g", true])
	for pattern: String in ["", "ST-063a", "ST-063c", "ST-063d"]:
		profiles.append(["grass", "short", pattern, "ST-063g", false])
	for ground: String in ["ST-063h", "ST-063j"]:
		profiles.append(["grass", "long", "ST-063b", ground, false])
	_check(_group in ["all", "ground", "grass"], "known bounded readability group")
	var expected: int = 0
	for row: Array in profiles:
		var ground_group: bool = row[0] != "grass" or row[3] in ["ST-063h", "ST-063j"]
		if (_group == "ground" and not ground_group) or (_group == "grass" and ground_group):
			continue
		expected += (ContentDB.pitch_by_id.size() if row[4] else 1) * 12 + 24
		await _profile(row)
		if _failures > 0:
			break
	if DisplayServer.get_name() != "headless" and _failures == 0:
		_check(_native_pairs == expected, "complete native paired-readability matrix")
	print(
		"SURFACE_BALL pairs=",
		_native_pairs,
		" minimum_ratio=",
		_minimum_ratio,
		" pitch_samples=",
		_pitch_samples
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			(
				"Wiffaltro surface ball checks passed: original flight; "
				+ "native mode also checks readability."
			)
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _profile(row: Array) -> void:
	print("SURFACE_PROFILE ", row)
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(
		StadiumPropertyRuntime._install(lab, StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"unchanged isolated ground collision"
	)
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumOffsetBoundaryBody = StadiumOffsetBoundaryBody.new()
	boundary.name = "BoundaryGraph"
	property.add_child(boundary)
	_check(boundary.build("offset_gables", "ST-024"), "same field geometry throughout comparison")
	StadiumWallRenderQuality.attach(boundary)
	_check(
		StadiumRecipeFieldStyles.apply(
			property, boundary.graph, {"line": "", "grass": ""}, "", StadiumStock.new_club()
		),
		"correct finite foul endpoints"
	)
	lab._camera_director.tracking_visibility.configure(lab.get_node("StarterFieldGeometry"))
	var finish: Node3D = StadiumSurfaceFinish.build(boundary.graph, row[0], row[1], row[2], row[3])
	property.add_child(finish)
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = (
			PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
		)
		PitchBatLabPresentation.sync_players(lab)
		lab._camera_director.set_batter_handedness(left)
		await _pitches(lab, finish, left, row[4])
		await _rolling(lab, finish)
	lab.queue_free()
	await get_tree().process_frame


func _pitches(lab: PitchBatLab, finish: Node3D, left: bool, exhaustive: bool) -> void:
	var actor: PitchFlightActor = PitchFlightActor.new()
	lab.add_child(actor)
	actor.set_physics_process(false)
	var setup: BallSetupDefinition = ContentDB.get_ball_setup(&"ball_setup.fresh")
	var player: PlayerDefinition = ContentDB.get_player(&"player.debug_pitcher")
	var pitches: Array = ContentDB.pitch_by_id.values()
	if not exhaustive:
		pitches = pitches.slice(0, 1)
	for defense: bool in [false, true]:
		lab._camera_director.set_shot(
			MatchCameraDirector.Shot.PITCHING if defense else MatchCameraDirector.Shot.BATTING
		)
		lab._camera_director.snap(lab._camera)
		for pitch: PitchDefinition in pitches:
			var launch: PitchLaunchParameters = PitchAimSolver.solve(
				MatchLabSupport.rated_pitch(pitch, player, 1.0),
				setup,
				PitchBatLab.MOUND_ORIGIN,
				Vector3(0, 1.05, 0),
				left,
				41
			)
			_check(launch != null, "original authored pitch solves")
			if launch == null:
				continue
			var baseline: Array[Vector3] = []
			for visible: bool in [false, true]:
				finish.visible = visible
				actor.start_pitch(launch)
				var points: Array[Vector3] = []
				var depths: Array[float] = [8, 4, 1]
				while actor.running:
					actor._physics_process(1.0 / 240)
					if not actor.running:
						break
					points.append(actor.global_position)
					_pitch_samples += 1
					_check(
						(
							not lab._camera.is_position_behind(actor.global_position)
							and lab._camera.get_viewport().get_visible_rect().has_point(
								lab._camera.unproject_position(actor.global_position)
							)
						),
						"real pitch stays framed"
					)
					if visible and not depths.is_empty() and actor.position.z <= depths[0]:
						depths.pop_front()
						await _pair(lab._camera, finish, actor)
				if visible:
					_check(
						points == baseline, "surface appearance preserves every real pitch sample"
					)
				else:
					baseline = points
				actor.reset_pitch()
	finish.visible = true
	actor.queue_free()
	await get_tree().process_frame


func _rolling(lab: PitchBatLab, finish: Node3D) -> void:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	_check(
		ball.radius_m == 0.0365 and ball.scale == Vector3.ONE,
		"physical body and original in-game visual are never resized for the finish"
	)
	var director: MatchCameraDirector = lab._camera_director
	for defense: bool in [false, true]:
		for end: Vector3 in [
			Vector3(-7, 0.0365, 18),
			Vector3(7, 0.0365, 18),
			Vector3(0, 0.0365, 27.4),
			Vector3(-8, 0.0365, 21.8),
			Vector3(8.15, 0.0365, 9.0),
			Vector3(0, 0.0365, 7)
		]:
			director.clear_presentation_motion()
			director.set_shot(
				MatchCameraDirector.Shot.PITCHING if defense else MatchCameraDirector.Shot.BATTING
			)
			director.snap(lab._camera)
			director.prepare_ball_in_play(defense, Vector3(0, 1, 0), end - Vector3(0, 1, 0))
			director.set_shot(MatchCameraDirector.Shot.BALL_IN_PLAY)
			for frame in range(180):
				ball.position = Vector3(0, 1, 0).lerp(end, minf(1, frame / 120.0))
				director.update(lab._camera, 1.0 / 60, true, ball.position)
				_check(
					(
						not lab._camera.is_position_behind(ball.position)
						and Rect2(24, 24, 1232, 672).has_point(
							lab._camera.unproject_position(ball.position)
						)
					),
					"ground ball stays framed"
				)
			await _pair(lab._camera, finish, ball)
	ball.queue_free()
	await get_tree().process_frame


func _pair(camera: Camera3D, finish: Node3D, ball: Node3D) -> void:
	if DisplayServer.get_name() == "headless":
		return
	finish.visible = false
	var baseline: float = await _contrast(camera, ball)
	finish.visible = true
	var current: float = await _contrast(camera, ball)
	if (baseline < 0.03 or current < maxf(0.03, baseline * 0.65)) and _failures == 0:
		print(
			"SURFACE_CONTRAST_FAILURE baseline=",
			baseline,
			" finish=",
			current,
			" ball=",
			ball.global_position,
			" camera=",
			camera.global_position
		)
		await _shot("surface-ball-visibility-failure")
	_check(baseline >= 0.03, "original field comparison has a readable ball")
	_check(
		current >= maxf(0.03, baseline * 0.65),
		"finish retains actual ball contrast relative to the original field"
	)
	_minimum_ratio = minf(_minimum_ratio, current / maxf(0.00001, baseline))
	_native_pairs += 1


func _terrain_check(ok: bool, message: String) -> bool:
	_terrain_checks += 1
	_check(ok, message)
	return ok


func _terrain_contacts() -> void:
	_terrain_check(
		Engine.physics_ticks_per_second == 60,
		"terrain contacts use the existing 60 Hz physics cadence"
	)
	var results: Dictionary = {}
	for mode: String in StadiumSurfaceTerrain.MODES:
		var ctx: Dictionary = await _terrain_context(mode)
		if ctx.is_empty():
			break
		if _failures > 0:
			ctx.lab.free()
			break
		var histories: Dictionary = {}
		for row: Array in [
			["drop", Vector3(2, 0.5, 11.5), Vector3.ZERO, 120, true],
			["grounder", Vector3(0.5, 0.06, 11.5), Vector3(2.4, 0, 0), 120, true],
			["airborne", Vector3(2, 4, 11.5), Vector3(1, 1, 0), 20, false]
		]:
			var trace: Array = await _terrain_flight(ctx, row)
			if trace.is_empty():
				break
			histories[row[0]] = trace
			if _failures > 0:
				break
		if histories.size() == 3 and _failures == 0:
			_terrain_controller(ctx)
			_terrain_check(
				StadiumSurfaceTerrainRuntime.installed_bound(ctx.lab, ctx.snapshot),
				"full original paid and geometry authority after physical observations"
			)
			await _terrain_negative(ctx)
		results[mode] = histories
		var lab: PitchBatLab = ctx.lab
		lab.free()
		await get_tree().physics_frame
		await get_tree().physics_frame
		_terrain_check(not is_instance_valid(lab), "exact captured test lab is disposed")
		if _failures > 0:
			break
	if _failures == 0 and results.size() == 2:
		_terrain_check(
			results.rough.airborne == results.leveled.airborne,
			"matched airborne native poses and velocities are unchanged before any ground contact"
		)
		_terrain_check(
			results.rough.grounder != results.leveled.grounder,
			"actual ground-contact response distinguishes the fixed rough patch from leveled dirt"
		)
		print(
			"SURFACE_TERRAIN_RESPONSE ",
			JSON.stringify(
				{
					"grounder_max_position_difference":
					_terrain_difference(results.rough.grounder, results.leveled.grounder),
					"drop_max_position_difference":
					_terrain_difference(results.rough.drop, results.leveled.drop),
					"airborne_exact": results.rough.airborne == results.leveled.airborne
				},
				"",
				true,
				true
			)
		)
	_terrain_check(
		_terrain_checks + 1 == 46 and _terrain_launches == 6 and _terrain_samples == 520,
		"exact focused terrain assertion, launch and native sample inventory"
	)
	print(
		(
			"SURFACE_TERRAIN_CONTACT checks=%d failures=%d installs=%d launches=%d samples=%d games=0"
			% [_terrain_checks, _failures, _terrain_installs, _terrain_launches, _terrain_samples]
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _terrain_context(mode: String) -> Dictionary:
	# Closed synthetic earned income, followed by the real owned journal and runtime APIs.
	var paid: ClubAssetLedger = ClubAssetLedger.new_club(21, [300])
	var purchased: bool = true
	if mode == "leveled":
		purchased = (
			paid
			. commit(
				{
					"id": "prep",
					"rev": paid.revision(),
					"op": "stadium_surface",
					"through": 1,
					"price_version": 1,
					"item": "ground_prep"
				}
			)
			. ok
		)
	if not _terrain_check(
		purchased and paid.balance() == (220 if mode == "leveled" else 300),
		"real existing preparation price; synthetic earned-income fixture only"
	):
		return {}
	var layout: Dictionary = StadiumSurfaceLayout.terrain_upgrade(
		paid.view().stadium_active, paid.surface_owned()
	)
	if mode == "leveled":
		layout.surface.condition = "prepared"
	var drafted: Dictionary = paid.commit(
		{"id": "draft", "rev": paid.revision(), "op": "stadium_draft", "layout": layout}
	)
	var applied: Dictionary = (
		paid.commit(
			{
				"id": "apply",
				"rev": paid.revision(),
				"op": "stadium_apply",
				"layout": layout,
				"geometry": StadiumSurfaceLayout.terrain_geometry("backyard", layout)
			}
		)
		if drafted.ok
		else {}
	)
	var entry: Dictionary = StadiumLayoutSnapshot.capture(paid)
	var snapshot: Dictionary = StadiumLayoutSnapshot.terrain_fixture(entry, 77, 0)
	if not _terrain_check(
		drafted.ok and applied.get("ok", false) and StadiumLayoutSnapshot.matches(snapshot, paid),
		"actual free draft/apply and immutable terrain fixture"
	):
		return {}
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME
	)
	state.stadium = snapshot.duplicate(true)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = state
	lab._stadium_ledger = paid
	var configured: bool = StadiumSurfaceTerrainRuntime.configure(lab, paid)
	var owner: StadiumSurfaceTerrainRuntime = StadiumSurfaceTerrainRuntime.current(lab)
	if configured:
		add_child(lab)
	if not _terrain_check(
		(
			configured
			and is_instance_valid(lab)
			and lab._match_state == state
			and StadiumSurfaceTerrainRuntime.current(lab) == owner
			and StadiumSurfaceTerrainRuntime.installed_bound(lab, snapshot)
		),
		"ordinary configured lab installs its exact terrain owner before delivery"
	):
		StadiumSurfaceTerrainRuntime.retire_captured(lab, owner)
		if is_instance_valid(lab):
			lab.free()
		return {}
	var helper: Node = load("res://src/tests/stadium_surface_night_gameplay_a_test.gd").new()
	helper._pause(lab)
	helper.free()
	lab._primary_fielder.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._active_play_record = PlayRecord.new()
	_terrain_installs += 1
	await get_tree().physics_frame
	await get_tree().physics_frame
	var ctx: Dictionary = {
		"lab": lab,
		"owner": owner,
		"snapshot": snapshot,
		"mode": mode,
		"body": owner._body,
		"shape": owner._shape,
		"mesh": owner._mesh,
		"ball": null,
		"anchor": lab._primary_fielder.anchor_position
	}
	_terrain_check(
		_terrain_shape_agrees(owner, mode),
		"same outward triangles define mesh, closed collision and support"
	)
	var record: Dictionary = owner.support_record(Vector2(2, 11.5))
	_terrain_check(
		(
			not record.is_empty()
			and record.position == StadiumSurfaceTerrain.support(Vector2(2, 11.5), mode).position
		),
		"native support ray hits the exact captured terrain body at the shared sampled height"
	)
	var flat: bool = true
	for point: Vector2 in [
		Vector2.ZERO,
		Vector2(0, PitchBatLab.MOUND_ORIGIN.z),
		Vector2(-26, -10),
		Vector2(26, 32),
		Vector2(0, lab._field_definition.safe_hit_z_m),
		Vector2(0, lab._field_definition.deep_air_z_m)
	]:
		flat = flat and StadiumSurfaceTerrain.support(point, mode).position.y == 0.0
	_terrain_check(
		(
			flat
			and not owner._property.has_node("PropertyGround")
			and not owner._property.has_node("OwnedSurfaceFinish")
		),
		"plate, mound, scoring bands and perimeter stay flat without a hidden flat underlay"
	)
	return ctx


func _terrain_shape_agrees(owner: StadiumSurfaceTerrainRuntime, mode: String) -> bool:
	var data: Dictionary = StadiumSurfaceTerrain.geometry(mode)
	if (
		owner._shape.get_faces() != data.faces
		or owner._mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] != data.faces
		or owner._mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL] != owner._normals
	):
		return false
	for index in range(0, data.faces.size(), 3):
		var a: Vector3 = data.faces[index]
		var b: Vector3 = data.faces[index + 1]
		var c: Vector3 = data.faces[index + 2]
		var normal: Vector3 = (c - a).cross(b - a).normalized()
		if normal != data.normals[index]:
			return false
		if a.y >= 0 and b.y >= 0 and c.y >= 0:
			var middle: Vector3 = (a + b + c) / 3.0
			var support: Dictionary = StadiumSurfaceTerrain.support(
				Vector2(middle.x, middle.z), mode
			)
			if (
				normal.y <= 0
				or support.is_empty()
				or absf(support.position.y - middle.y) > 0.000001
			):
				return false
	return true


func _terrain_flight(ctx: Dictionary, row: Array) -> Array:
	var lab: PitchBatLab = ctx.lab
	var owner: StadiumSurfaceTerrainRuntime = ctx.owner
	if is_instance_valid(ctx.ball):
		ctx.ball.free()
		lab._batted_ball = null
		await get_tree().physics_frame
		await get_tree().physics_frame
	lab._ball_play_resolver.start_play(lab._field_definition, false)
	var play: BallPlayState = lab._ball_play_resolver.state
	var ball: BattedBallBody = BattedBallBody.new()
	ball.configure_aero(ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID))
	lab._batted_ball = ball
	ctx.ball = ball
	var contacts: Array = []
	ball.surface_contact.connect(lab._on_batted_surface_contact)
	if not owner.claim_ball(lab, ball, play):
		_terrain_check(false, "captured diagnostic ball is claimed before attachment")
		ball.free()
		return []
	lab.add_child(ball)
	ball.body_entered.connect(
		func(body: Node) -> void:
			if body == ctx.body:
				contacts.append(
					{
						"frame": Engine.get_physics_frames(),
						"ball": ball.get_instance_id(),
						"body": body.get_instance_id(),
						"position": _terrain_v(ball.global_position),
						"grounded": play.has_grounded
					}
				)
	)
	if not _terrain_check(
		(
			StadiumPropertyRuntime.bind_ball(lab, ball, lab._ball_play_resolver)
			and ball.radius_m == 0.0365
			and ball.scale == Vector3.ONE
			and ball.physics_material_override.bounce == PackedFloat32Array([0.52])[0]
			and ball.physics_material_override.friction == PackedFloat32Array([0.42])[0]
		),
		"original native ball and material bind to the captured terrain play"
	):
		return []
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = row[1]
	launch.velocity = row[2]
	launch.angular_velocity = Vector3.ZERO
	ball.launch(launch)
	if not owner.ball_context(lab, ball, play):
		_terrain_check(false, "original launch callback preserves captured candidate and play")
		return []
	_terrain_launches += 1
	var history: Array = []
	var finite: bool = true
	var first_frame: int = Engine.get_physics_frames()
	for index in range(int(row[3])):
		await get_tree().physics_frame
		var sample: Array = _terrain_v(ball.global_position) + _terrain_v(ball.linear_velocity)
		history.append(sample)
		finite = finite and ball.global_position.is_finite() and ball.linear_velocity.is_finite()
		_terrain_samples += 1
		print(
			"SURFACE_TERRAIN_SAMPLE ",
			JSON.stringify(
				{
					"mode": ctx.mode,
					"case": row[0],
					"index": index,
					"frame": Engine.get_physics_frames(),
					"state": play.get_instance_id(),
					"ball": ball.get_instance_id(),
					"values": sample
				},
				"",
				true,
				true
			)
		)
	_terrain_check(
		(
			finite
			and history.size() == int(row[3])
			and Engine.get_physics_frames() - first_frame == int(row[3])
			and owner.ball_context(lab, ball, play)
		),
		"bounded native physics frames retain original body and play"
	)
	_terrain_check(
		(
			(not contacts.is_empty()) == bool(row[4])
			and play.has_grounded == bool(row[4])
			and (contacts.is_empty() or bool(contacts[0].grounded))
		),
		(
			"actual engine ground contact reaches the ordinary baseball callback; airborne control "
			+ "stays untouched"
		)
	)
	print(
		"SURFACE_TERRAIN_FLIGHT ",
		JSON.stringify(
			{
				"mode": ctx.mode,
				"case": row[0],
				"ticks": row[3],
				"physical_contacts": contacts.size(),
				"first_contact": {} if contacts.is_empty() else contacts[0],
				"grounded": play.has_grounded,
				"initial_position": _terrain_v(row[1]),
				"initial_velocity": _terrain_v(row[2]),
				"final": history[-1]
			},
			"",
			true,
			true
		)
	)
	return history


func _terrain_controller(ctx: Dictionary) -> void:
	var lab: PitchBatLab = ctx.lab
	var owner: StadiumSurfaceTerrainRuntime = ctx.owner
	var fielder: FielderController = lab._primary_fielder
	fielder.active = false
	owner.set_anchor(fielder, Vector3(0.5, 0, 11.5))
	fielder.begin_play()
	fielder._play_elapsed_seconds = fielder.reaction_delay_seconds
	fielder.target_position = Vector3(3.5, 0, 11.5)
	fielder.pitcher_lane_z = INF
	var distance: float = 0.0
	var supported: bool = true
	for index in range(90):
		var before: Vector3 = fielder.global_position
		fielder._physics_process(1.0 / 60.0)
		distance += before.distance_to(fielder.global_position)
		var record: Dictionary = owner.support_record(
			Vector2(fielder.global_position.x, fielder.global_position.z)
		)
		supported = (
			supported and not record.is_empty() and fielder.global_position == record.position
		)
	_terrain_check(
		(
			supported
			and fielder.global_position.x > 3.4
			and distance <= 90.0 * fielder.move_speed_mps / 60.0 + 0.00001
		),
		"actual controller crosses the patch on native-supported feet within the unchanged speed budget"
	)
	fielder.end_play()
	owner.set_anchor(fielder, Vector3(1.2, 0, 11.5))
	var before: Vector3 = fielder.global_position
	FielderFirstStep.advance(fielder, Vector3.RIGHT, 0.12)
	var record: Dictionary = owner.support_record(
		Vector2(fielder.global_position.x, fielder.global_position.z)
	)
	_terrain_check(
		(
			not record.is_empty()
			and fielder.global_position == record.position
			and (
				before.distance_to(fielder.global_position)
				<= fielder.move_speed_mps * 0.12 + 0.00001
			)
		),
		"forced first step retains its direction and bounded supported distance"
	)
	var frame: Dictionary = PitchBatLabDefenseSupport.control_frame(
		lab, fielder, fielder.global_position + Vector3.UP * 0.2
	)
	_terrain_check(
		(
			not frame.is_empty()
			and absf(float(frame.height_m) - 0.2) < 0.000001
			and owner.reset_pitcher(lab)
			and lab._pitcher_marker.global_position == PitchBatLab.MOUND_ORIGIN
		),
		"control height is relative to supported feet and pitcher reset keeps the original mound"
	)
	fielder.pitcher_lane_z = PitchBatLab.MOUND_ORIGIN.z
	fielder.active = false
	owner.set_anchor(fielder, ctx.anchor)


func _terrain_negative(ctx: Dictionary) -> void:
	var owner: StadiumSurfaceTerrainRuntime = ctx.owner
	var lab: PitchBatLab = ctx.lab
	if ctx.mode == "rough":
		var foreign: StaticBody3D = StaticBody3D.new()
		foreign.collision_layer = StadiumSurfaceTerrain.QUERY_LAYER
		foreign.collision_mask = 0
		var shape: CollisionShape3D = CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		shape.shape.size = Vector3(0.4, 0.1, 0.4)
		foreign.add_child(shape)
		foreign.position = Vector3(2, 0.25, 11.5)
		add_child(foreign)
		await get_tree().physics_frame
		await get_tree().physics_frame
		_terrain_check(
			(
				owner.support_record(Vector2(2, 11.5)).is_empty()
				and owner.phase == StadiumSurfaceTerrainRuntime.Phase.ABANDONED
				and foreign.position == Vector3(2, 0.25, 11.5)
			),
			"foreign layer-512 support refuses without adopting or moving its body"
		)
		foreign.free()
	else:
		# Use the sixth flight's genuinely live body, without an extra launch or forged contact.
		var captured: BattedBallBody = ctx.ball
		var play: BallPlayState = lab._ball_play_resolver.state
		var replacement: BattedBallBody = BattedBallBody.new()
		lab._match_state = MatchState.new()
		lab._batted_ball = replacement
		_terrain_check(
			(
				not owner.ball_context(lab, captured, play)
				and captured.freeze
				and not replacement.freeze
				and not replacement.has_meta(StadiumSurfaceTerrainRuntime.BALL)
				and owner.phase == StadiumSurfaceTerrainRuntime.Phase.ABANDONED
			),
			"captured original body is held after state/slot replacement; replacement remains untouched"
		)
		replacement.free()


func _terrain_v(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


func _terrain_difference(a: Array, b: Array) -> float:
	var maximum: float = 0.0
	for index in range(mini(a.size(), b.size())):
		maximum = maxf(
			maximum,
			Vector3(a[index][0], a[index][1], a[index][2]).distance_to(
				Vector3(b[index][0], b[index][1], b[index][2])
			)
		)
	return maximum

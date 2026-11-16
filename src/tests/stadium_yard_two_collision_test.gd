extends "res://src/tests/stadium_boundary_lab_test.gd"
## Real gravity-on cone/receiver/boundary outcomes, exact membership and full routes.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_two_lab_only", true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	if not StadiumYardTwoLab.install(lab):
		_check(false, "complete AY-02 installation")
		lab.queue_free()
		await get_tree().process_frame
		await TestAudioDrain.finish(get_tree())
		get_tree().quit(1)
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	for sample: Array in [
		[Vector3(23, 2, 22.7), Vector3(0, 0, 36), false, BallPlayOutcome.Result.SINGLE],
		[Vector3(23, 2, 22.7), Vector3(0, 0, 36), true, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 2, -5.5), Vector3(0, 0, -36), false, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 2, -0.5), Vector3(0, 0, -36), false, BallPlayOutcome.Result.FOUL],
		[Vector3(0, 4, 22.7), Vector3(0, 0, 36), false, BallPlayOutcome.Result.HOME_RUN],
		[Vector3(0, 0.05, 23), Vector3(0, 0, 12), false, BallPlayOutcome.Result.DOUBLE]
	]:
		await _lab_flight(lab, sample)
	await _cone(lab)
	await _routes_in_graph()
	_routes_around_cone(lab)
	await _bleachers(lab.get_meta("stadium_property"))
	_receiver_sweeps(lab)
	await _identity_controls(lab)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame
	for height: float in [0.65, 1.3, 0.47]:
		for left: bool in [false, true]:
			await _called_pitch(height, left)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro yard-two collision passed: live cone, chair routing and full template outcomes."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _cone(lab: PitchBatLab) -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(8, 0.42, 15.2)
	launch.velocity = Vector3(0, 0, -6)
	lab._start_ball_in_play(launch)
	var contacts: Array[Dictionary] = []
	lab._batted_ball.body_entered.connect(
		func(body: Node) -> void:
			if body.get_meta("candidate_instance", "") == StadiumYardTwoStudy.PREFIX + "O-R1":
				contacts.append(
					{
						"velocity": lab._batted_ball.linear_velocity,
						"gravity": lab._batted_ball.gravity_scale
					}
				)
	)
	for frame in range(60):
		await get_tree().physics_frame
		lab._physics_process(1.0 / 60.0)
		if not lab._ball_play_resolver.state.last_obstacle_contact.is_empty():
			break
	_check(
		(
			not contacts.is_empty()
			and contacts[0].gravity > 0
			and (
				lab._ball_play_resolver.state.last_obstacle_contact
				== StringName(StadiumYardTwoStudy.PREFIX + "O-R1")
			)
			and not lab._ball_play_resolver.state.dead
		),
		"actual gravity-on cone collision ricochets live with authentic candidate identity"
	)
	lab._cleanup_batted_ball()
	await get_tree().physics_frame


func _routes_around_cone(lab: PitchBatLab) -> void:
	var obstacles: Array[Dictionary] = lab._primary_fielder.stadium_obstacles
	_check(obstacles.size() == 2, "one cone plus receiver route obstacle, never bleachers")
	for fps: int in [30, 60, 120]:
		var point: Vector3 = Vector3(8, 0, 11)
		var goal: Vector3 = Vector3(8, 0, 17)
		for frame in range(fps * 4):
			var next: Vector3 = StadiumDefenderRoutes.step(point, goal, 5.0 / fps, obstacles)
			next = StadiumBoundaryGraph.clip(point, next)
			_check(
				(
					StadiumDefenderRoutes.clear(point, next, obstacles)
					and next.distance_to(point) <= 5.0 / fps + 0.00001
				),
				"every real route segment clears cone/receiver within its movement budget"
			)
			_assert_contained(next)
			point = next
		_check(point.distance_to(goal) < 0.05, "route reaches far side of the live cone")
	lab._pitcher_marker.global_position = Vector3(8, 0, 11)
	var step: Vector3 = StadiumPropertyRuntime.pitcher_step(
		lab, Vector3(8, 0, 17), 0.25, Vector3(8, 0, 17)
	)
	_check(
		StadiumDefenderRoutes.clear(lab._pitcher_marker.global_position, step, obstacles),
		"ordinary pitcher adapter also uses complete candidate routes"
	)


func _bleachers(property: StadiumYardTwoProperty) -> void:
	for side: int in [-1, 1]:
		var resolver: BallPlayResolver = BallPlayResolver.new()
		resolver.start_play(property.field)
		var ball: BattedBallBody = BattedBallBody.new()
		ball.aero_drag_coefficient = 0
		ball.aero_magnus_scale = 0
		ball.aero_perforation_force_scale = 0
		add_child(ball)
		property.bind_ball(ball, resolver)
		var contacts: Array[bool] = []
		ball.body_entered.connect(
			func(body: Node) -> void:
				if body.get_meta("stadium_item", "") == "ST-027":
					contacts.append(resolver.state.dead)
		)
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(side * 17, 1.35, 12.5)
		launch.velocity = Vector3(side * 18, 0, 0)
		ball.launch(launch)
		var previous: Vector3 = launch.position
		for frame in range(120):
			await get_tree().physics_frame
			StadiumBoundaryObserver.observe(resolver, previous, ball.global_position)
			previous = ball.global_position
			if not contacts.is_empty():
				break
		_check(
			not contacts.is_empty() and contacts[0],
			"actual bleacher contact occurs only after finite side boundary ends play"
		)
		ball.queue_free()
		await get_tree().physics_frame


func _receiver_sweeps(lab: PitchBatLab) -> void:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var receiver: StadiumYardTwoReceiver = property.get_node("PitchReceiverPresentation")
	_check(
		lab._pitch_actor.receiver_router == receiver.route and receiver._actor == lab._pitch_actor,
		"actual pitch callback belongs to the candidate receiver and correct actor"
	)
	for sample: Array in [
		[Vector3(0, 0.65, 0), "ST079_BACK"],
		[Vector3(0, 0.47, 0), "ST079_SEAT"],
		[Vector3(0.27, 0.60, 0), "ST079_ARM"],
		[Vector3(0.22, 0.22, 0), "ST079_FRONT_LEG"]
	]:
		var path: Dictionary = receiver.trace(sample[0], Vector3(0, 0, -10), 0.0365)
		_check(
			(
				not path.hit.is_empty()
				and String(path.hit.get("surface", "")).begins_with(sample[1])
				and path.hit.get("copy") == StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"
				and path.times[-1] <= 0.24
			),
			"same shared sweep finds first genuine named chair surface"
		)
	for start: Vector3 in [Vector3(0, 1.3, 0), Vector3(0.7, 0.7, 0)]:
		var path: Dictionary = receiver.trace(start, Vector3(0, 0, -10), 0.0365)
		_check(
			(
				path.hit.is_empty()
				and path.reason == "receiver_cleanup"
				and is_equal_approx(path.points[-1].z, -1.4)
			),
			"chair miss has silent nonphysical cleanup"
		)
	var slow: Dictionary = receiver.trace(Vector3(0, 1.3, 0), Vector3(0, 0, -0.5), 0.0365)
	_check(
		(
			slow.hit.is_empty()
			and slow.reason == "receiver_presentation_timeout"
			and is_equal_approx(slow.times[-1], 0.24)
		),
		"slow miss preserves inherited timeout"
	)


func _identity_controls(lab: PitchBatLab) -> void:
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var receiver: StadiumYardTwoReceiver = property.get_node("PitchReceiverPresentation")
	var chair: Node3D = receiver.chair
	var body: StaticBody3D = chair.get_node("Collision/ST079_BACK")
	var identity: String = StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"
	var fifth: Node3D = StadiumStarterModels.create("ST-079")
	fifth.set_meta("candidate_instance", "starter-v1:ST-079")
	fifth.set_meta("candidate_site", "RECEIVER-PRIMARY")
	fifth.set_meta("candidate_host", "field")
	property.add_child(fifth)
	property.objects["starter-v1:ST-079"] = fifth
	_check(
		not property.bind_model("starter-v1:ST-079", fifth) and not fifth.has_meta("owned_copy"),
		"first-time foreign fifth identity cannot acquire an authentic NPC or human alias"
	)
	property.objects.erase("starter-v1:ST-079")
	fifth.free()
	var fake: StaticBody3D = StaticBody3D.new()
	for key: StringName in body.get_meta_list():
		fake.set_meta(key, body.get_meta(key))
	chair.get_node("Collision").add_child(fake)
	_check(
		property.contact_identity(fake).is_empty(),
		"cloned metadata cannot create genuine membership"
	)
	var rejected: BallPlayResolver = BallPlayResolver.new()
	rejected.start_play(property.field)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	property.bind_ball(ball, rejected)
	var found: bool = false
	for connection: Dictionary in ball.body_entered.get_connections():
		found = found or connection.callable.get_object() == property
	_check(found, "batted callback targets the actual installed candidate property")
	property._ball_contact(fake, ball, rejected)
	_check(
		not rejected.state.dead and rejected.state.last_obstacle_contact.is_empty(),
		"forged collider metadata cannot forward a gameplay outcome"
	)
	ball.free()
	_check(
		not property.bind_model(identity, chair) and property.contact_identity(fake).is_empty(),
		"one-shot model registration cannot bless a cloned collider"
	)
	fake.free()
	var container: Node3D = chair.get_node("Collision")
	var original_index: int = body.get_index()
	container.remove_child(body)
	_check(
		not receiver.bound() and not property.bind_model(identity, chair),
		"missing genuine body cannot pass vacuously or be re-registered away"
	)
	container.add_child(body)
	container.move_child(body, original_index)
	_check(receiver.bound(), "restoring original collider object restores exact membership")
	for key: String in ["candidate_instance", "owned_copy"]:
		body.remove_meta(key)
		_check(
			property.contact_identity(body).is_empty() and not receiver.bound(),
			"missing candidate identity closes actual receiver callback"
		)
		body.set_meta(key, "starter-v1:ST-079")
		_check(
			property.contact_identity(body).is_empty() and not receiver.bound(),
			"forged human key cannot stand in for candidate identity"
		)
		body.set_meta(key, identity)
	for target: Node in [chair, body]:
		for key: String in ["candidate_instance", "owned_copy", "stadium_item"]:
			var original: Variant = target.get_meta(key)
			for wrong: Variant in [[], {}, true, 1]:
				target.set_meta(key, wrong)
				_check(
					property.contact_identity(body).is_empty() and not receiver.bound(),
					"wrong-type authoritative tag refuses without invalid Variant comparisons"
				)
			target.set_meta(key, original)
	for key: String in ["surface_id", "surface_role"]:
		var original: Variant = body.get_meta(key)
		for wrong: Variant in [[], {}, true, 1]:
			body.set_meta(key, wrong)
			_check(
				property.contact_identity(body).is_empty() and not receiver.bound(),
				"wrong-type surface identity refuses before shared contact forwarding"
			)
		body.set_meta(key, original)
	var malformed_count: int = receiver.contacts.size()
	for key: String in ["copy", "surface", "position", "elapsed"]:
		var bad: Dictionary = {
			"copy": identity, "surface": "ST079_BACK", "position": Vector3.ZERO, "elapsed": 0.0
		}
		bad[key] = []
		receiver.present_contact(bad, "pitch")
	_check(
		receiver.contacts.size() == malformed_count and receiver.bound(),
		"malformed contact headers cleanly refuse without scheduling a presentation"
	)
	var foreign: Node3D = StadiumStarterModels.create("ST-079")
	foreign.set_meta("owned_copy", identity)
	property.add_child(foreign)
	_check(
		not receiver.configure(foreign) and not receiver.configure_candidate(property, lab._sounds),
		"receiver cannot be rebound through either configuration entry"
	)
	receiver.chair = foreign
	_check(
		not receiver.route(lab._pitch_actor, Vector3(0, 0.65, 0), Vector3(0, 0, -10)),
		"substituted model closes an otherwise genuine callback"
	)
	receiver.chair = chair
	property.objects[identity] = foreign
	_check(
		not property.bind_model(identity, foreign),
		"foreign model cannot rebind registered identity"
	)
	_check(not receiver.bound(), "object-map substitution cannot redirect physical membership")
	property.objects[identity] = chair
	var actor: PitchFlightActor = PitchFlightActor.new()
	property.add_child(actor)
	actor.receiver_router = receiver.route
	_check(
		not receiver.route(actor, Vector3(0, 0.65, 0), Vector3(0, 0, -10)),
		"foreign actor cannot borrow the bound candidate callback"
	)
	actor.free()
	var path: Dictionary = receiver.trace(Vector3(0, 0.65, 0), Vector3(0, 0, -10), 0.0365)
	_check(not path.hit.is_empty(), "mid-tween guard starts from a genuine actual chair sweep")
	if not path.hit.is_empty():
		receiver.present_contact(path.hit, "pitch")
		receiver.chair = foreign
		var rest: Transform3D = foreign.get_node("Visual").transform
		for frame in range(24):
			await get_tree().process_frame
			_check(
				foreign.get_node("Visual").transform == rest,
				"a deferred rock cannot animate a substituted foreign chair"
			)
		receiver.chair = chair
		receiver._animate(0.28, 0.0, 0)
	var before_finish: int = receiver.contacts.size()
	var original_callback: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = Callable()
	receiver._finish(lab._pitch_actor, path)
	_check(
		receiver.contacts.size() == before_finish,
		"deferred finish cannot present through a rebound or missing actor callback"
	)
	lab._pitch_actor.receiver_router = original_callback
	foreign.free()
	var count: int = receiver.contacts.size()
	receiver.present_contact(
		{
			"copy": "starter-v1:ST-079",
			"surface": "ST079_BACK",
			"position": Vector3.ZERO,
			"elapsed": 0.0
		},
		"pitch"
	)
	_check(
		receiver.contacts.size() == count and receiver.bound(),
		"spoofed impact does not animate or persist and authentic binding remains"
	)


func _called_pitch(height: float, left: bool) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab.set_meta("stadium_yard_two_lab_only", true)
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
	lab._match_state.batter().definition.bats = (
		PlayerDefinition.Handedness.LEFT if left else PlayerDefinition.Handedness.RIGHT
	)
	PitchBatLabPresentation.sync_players(lab)
	_check(lab._batter_avatar.bats_left == left, "actual receiver view uses the chosen batter hand")
	if not StadiumYardTwoLab.install(lab):
		_check(false, "real AY-02 called-pitch installation")
		lab.queue_free()
		await get_tree().process_frame
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var receiver: StadiumPitchReceiver = property.get_node("PitchReceiverPresentation")
	var actor: PitchFlightActor = lab._pitch_actor
	actor.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	lab._match_state.begin_pitch()
	actor.start_pitch(_parameters(height))
	actor._physics_process(0.2)  # One large update crosses the logical call and receiver distance.
	var calls: Vector2i = Vector2i(lab._match_state.balls, lab._match_state.strikes)
	_check(
		calls == (Vector2i(1, 0) if height < 0.55 else Vector2i(0, 1)),
		"logical call is decided at z=0 before any chair presentation"
	)
	var paused_position: Vector3 = actor.global_position
	get_tree().paused = true
	for frame in range(4):
		await get_tree().process_frame
	_check(
		actor.global_position == paused_position and receiver.contacts.is_empty(),
		"pause cannot advance the receiver path or emit a hidden contact"
	)
	get_tree().paused = false
	var expected: int = 0 if height > 1 else 1
	var chair: Node3D = property.objects[StadiumYardTwoStudy.PREFIX + "RECEIVER-PRIMARY"]
	var collider: Transform3D = chair.get_node("Collision/ST079_BACK").transform
	var largest_rock: float = 0
	for frame in range(40):
		await get_tree().process_frame
		_check(
			chair.get_node("Collision/ST079_BACK").transform == collider,
			"visual rocking never changes the actual collider"
		)
		largest_rock = maxf(largest_rock, absf(chair.get_node("Visual").rotation.z))
		_check(largest_rock <= deg_to_rad(6.001), "rock stays bounded")
	_check(
		receiver.contacts.size() == expected and not actor.visible,
		"called pitch emits at most one real chair contact and disappears"
	)
	_check(
		Vector2i(lab._match_state.balls, lab._match_state.strikes) == calls,
		"chair hit or miss cannot revise the earlier call"
	)
	_check(is_zero_approx(chair.get_node("Visual").rotation.z), "chair recovers its rest pose")
	_check(
		largest_rock > deg_to_rad(0.2) if expected == 1 else is_zero_approx(largest_rock),
		"only a real impact visibly rocks the chair"
	)
	if expected == 1:
		_check(
			lab._sounds.last_cue == (&"chair_seat" if height < 0.55 else &"chair_back"),
			"actual hit chooses its named plastic cue"
		)
	var before: int = receiver.contacts.size()
	actor.visible = true
	actor._begin_plate_follow_through(Vector3(0, 0.65, 0), Vector3(0, 0, -10))
	actor.reset_pitch()
	for frame in range(20):
		await get_tree().process_frame
	_check(
		receiver.contacts.size() == before and not actor.visible,
		"cancelled follow-through cannot emit a delayed phantom impact"
	)
	var batted: BattedBallBody = BattedBallBody.new()
	lab.add_child(batted)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(lab._field_definition)
	property.bind_ball(batted, resolver)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(0, 0.75, 0.2)
	launch.velocity = Vector3(0, 0, -6)
	batted.launch(launch)
	for frame in range(60):
		await get_tree().physics_frame
		if resolver.state.dead:
			break
	_check(
		(
			resolver.state.dead
			and receiver.contacts.size() == before + 1
			and receiver.contacts[-1].kind == "batted"
		),
		"actual batted receiver collision emits one matching physical presentation"
	)
	batted.queue_free()
	lab.queue_free()
	await get_tree().process_frame


func _parameters(height: float) -> PitchLaunchParameters:
	var value: PitchLaunchParameters = PitchLaunchParameters.new()
	value.pitch_id = &"pitch.overhand_four_seam"
	value.position = Vector3(0, height, 0.4)
	value.velocity = Vector3(0, 0, -10)
	value.drag_coefficient = 0
	value.magnus_scale = 0
	value.perforation_force_scale = 0
	value.seed = 51
	return value

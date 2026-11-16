extends "res://src/tests/stadium_target_receiver_test.gd"
## New net pair has its own routing fixture, without enabling any production saved field.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _traces()
	await _actor_clearance()
	for left in [false, true]:
		var baseline: Array = await _calls(false, left)
		var candidate: Array = await _calls(true, left)
		_check(baseline == candidate and baseline.size() == 13,
			"stadium net pair preserves all thirteen calls for each batter hand")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro club pitch receiver passed: camera cut, physical net and unchanged plate calls.")
	get_tree().quit(0 if _failures == 0 else 1)


func _model(net: bool, copy: String) -> Node3D:
	var model: Node3D = StadiumReceiverNetModels.create() if net else StadiumTargetModels.create()
	model.position = Vector3.ZERO if net else StadiumTargetModels.POSITION
	model.set_meta("owned_copy", copy)
	for body: Node in model.get_node("Collision").get_children():
		body.set_meta("owned_copy", copy)
	return model


func _traces() -> void:
	var target: Node3D = _model(false, "npc-study:target")
	var net: Node3D = _model(true, "npc-study:net")
	add_child(target)
	add_child(net)
	var receiver: StadiumClubPitchReceiver = StadiumClubPitchReceiver.new()
	add_child(receiver)
	_check(not receiver.configure(target) and not receiver.configure_pair(null, net),
		"complete explicit target/net pair is required")
	_check(receiver.configure_pair(target, net), "corrected stadium pair configured")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for radius: float in [0, -1, INF, NAN]:
		_check(receiver.trace(Vector3.ZERO, Vector3.BACK, radius).is_empty(),
			"invalid sphere radius is rejected before physics")
	_check(receiver.trace(Vector3(NAN, 0, 0), Vector3.BACK, 0.0365).is_empty(),
		"nonfinite start is rejected before physics")
	for speed: float in [15, 40, 120]:
		for row: Array in [[Vector3(0, 1.3, 0), "ST026_PANEL"],
			[Vector3(1.5, 1.3, 0), "ST073_CENTER_NET"],
			[Vector3(3, 1.3, 0), "ST073_NET_R"], [Vector3(-3, 1.3, 0), "ST073_NET_L"]]:
			var path: Dictionary = receiver.trace(row[0], Vector3(0, 0, -speed), 0.0365)
			_check(path.hit.get("surface") == row[1] and path.times[-1] <= 0.38,
				"corrected pair physically reaches " + row[1] + " speed=" + str(speed))
			if row[1] == "ST073_CENTER_NET":
				_check(path.hide_at > 0 and path.hide_at < path.times[-1],
					"camera visual cutoff does not erase later physical net containment")
	var miss: Dictionary = receiver.trace(Vector3(0, 8, 0), Vector3(0, 0, -40), 0.0365)
	_check(miss.hit.is_empty() and miss.reason == "receiver_cleanup"
		and is_equal_approx(miss.points[-1].z, -5.2), "above-net miss remains physically uncontained")
	var slow: Dictionary = receiver.trace(Vector3(1.5, 1.3, 0), Vector3(0, 0, -1), 0.0365)
	_check(slow.hit.is_empty() and slow.reason == "receiver_presentation_timeout",
		"slow miss times out without a fabricated net hit")
	_check(receiver.contacts.is_empty(), "queries never emit duplicate presentation events")
	await _visual_flow(receiver)
	target.queue_free()
	net.queue_free()
	receiver.queue_free()
	await get_tree().process_frame


func _visual_flow(receiver: StadiumClubPitchReceiver) -> void:
	var actor: PitchFlightActor = PitchFlightActor.new()
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(actor)
	actor.set_physics_process(false)
	actor.visible = true
	actor.global_position = Vector3(1.5, 1.3, 0)
	receiver.camera_protection = func() -> bool: return true
	_check(receiver.route(actor, actor.global_position, Vector3(0, 0, -40)), "post-call route begins")
	var hidden_before_contact: bool = false
	for frame in range(60):
		await get_tree().process_frame
		if not actor.visible and receiver.contacts.is_empty():
			hidden_before_contact = true
		if not receiver.contacts.is_empty():
			break
	_check(hidden_before_contact and receiver.contacts.size() == 1
		and receiver.contacts[0].surface == "ST073_CENTER_NET" and not actor.visible,
		"actual actor hides before the camera, then still produces one later physical net response")
	receiver.contacts.clear()
	actor.visible = true
	actor.global_position = Vector3(1.5, 1.3, 0)
	receiver.route(actor, actor.global_position, Vector3(0, 0, -40))
	actor.global_position = Vector3(3, 1.3, 0)
	receiver.route(actor, actor.global_position, Vector3(0, 0, -40))
	_check(actor.visible, "same-actor replacement preserves the new visible flight")
	for frame in range(40):
		await get_tree().process_frame
	_check(receiver.contacts.size() == 1 and receiver.contacts[0].surface == "ST073_NET_R",
		"replacing a pending route cancels its old future contact")
	receiver.contacts.clear()
	actor.visible = true
	actor.global_position = Vector3(1.5, 1.3, 0)
	receiver.route(actor, actor.global_position, Vector3(0, 0, -40))
	remove_child(receiver)
	for frame in range(40):
		await get_tree().process_frame
	_check(receiver.contacts.is_empty() and not actor.visible and actor._plate_follow_tween == null,
		"removing the receiver cancels hidden follow-through with no stale visible ball or late contact")
	add_child(receiver)
	actor.visible = true
	receiver.route(actor, Vector3(1.5, 1.3, 0), Vector3(0, 0, -40))
	actor._cancel_plate_follow_through()
	var newer: Tween = actor.create_tween().bind_node(actor)
	newer.tween_interval(1)
	actor._plate_follow_tween = newer
	remove_child(receiver)
	_check(actor.visible and actor._plate_follow_tween == newer and newer.is_valid(),
		"removing stale receiver cannot cancel or hide a newer owner's tween")
	actor._cancel_plate_follow_through()
	add_child(receiver)
	actor.visible = true
	receiver.route(actor, Vector3(1.5, 1.3, 0), Vector3(0, 0, -40))
	var replacement: PitchFlightActor = PitchFlightActor.new()
	add_child(replacement)
	replacement.visible = true
	receiver.route(replacement, Vector3(3, 1.3, 0), Vector3(0, 0, -40))
	_check(not actor.visible and actor._plate_follow_tween == null and replacement.visible,
		"different actor replacement cancels only the old owned flight")
	receiver._cancel_active()
	receiver.contacts.clear()
	replacement.visible = true
	replacement.global_position = Vector3(1.5, 2, -4.5)
	_check(receiver.route(replacement, replacement.global_position, Vector3(0, 0, -40))
		and not replacement.visible, "already-contacting start hides immediately without interpolation")
	for frame in range(8):
		await get_tree().process_frame
	_check(replacement.global_position.is_finite() and receiver.contacts.size() == 1,
		"zero-duration physical contact has a finite point and exactly one response")
	replacement.queue_free()
	actor.queue_free()
	await get_tree().process_frame


func _install_target(lab: PitchBatLab, property: StadiumPropertyGeometry) -> StadiumTargetReceiver:
	var target: Node3D = _model(false, "npc-study:target")
	var net: Node3D = _model(true, "npc-study:net")
	property.add_child(target)
	property.add_child(net)
	# Keep the old obstacle adapter scoped to its supported target, not an unknown new net type.
	property.objects["npc-study:target"] = target
	var receiver: StadiumClubPitchReceiver = StadiumClubPitchReceiver.new()
	receiver.name = "PitchReceiverPresentation"
	property.add_child(receiver)
	_check(receiver.configure_pair(target, net, lab._sounds), "explicit stadium pair fixture")
	receiver.camera_protection = func() -> bool:
		return lab._camera_director.shot == MatchCameraDirector.Shot.BATTING
	lab._pitch_actor.receiver_router = receiver.route
	return receiver


func _actor_clearance() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._bat_actor.set_process(false)
	lab._batter_avatar.set_process(false)
	var target: AABB = StadiumReceiverNetModels.ENVELOPE
	var samples: int = 0
	var collisions: int = 0
	for left: bool in [false, true]:
		lab._match_state.batter().definition = lab._match_state.batter().definition.duplicate(true)
		lab._match_state.batter().definition.bats = PlayerDefinition.Handedness.LEFT if left \
			else PlayerDefinition.Handedness.RIGHT
		PitchBatLabPresentation.sync_players(lab)
		_check(lab._batter_avatar.bats_left == left, "actual chosen batter hand")
		for id: StringName in [PitchBatLab.CONTACT_SWING_ID, PitchBatLab.POWER_SWING_ID]:
			var profile: SwingProfileDefinition = ContentDB.get_swing(id)
			for x in [-1, 0, 1]:
				for y in [-1, 0, 1]:
					lab._bat_actor.reset_swing()
					lab._batter_avatar.reset_pose()
					lab._bat_actor.set_aim_pose(Vector2(x, y))
					lab._batter_avatar.set_batting_aim_pose(Vector2(x, y))
					lab._bat_actor.play_swing(profile)
					lab._batter_avatar.play_batting_swing(profile)
					for step in range(131):
						var time: float = step * profile.swing_duration_seconds / 130
						lab._bat_actor._apply_swing_pose(time)
						lab._batter_avatar._apply_batting_swing_pose(time)
						for root: Node3D in [lab._bat_actor, lab._batter_avatar]:
							for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
								var box: AABB = mesh.global_transform * mesh.get_aabb()
								if target.intersects(box):
									collisions += 1
									if collisions < 5:
										print("STADIUM_NET_ACTOR_OVERLAP ", left, " ", id, " ", Vector2(x, y),
											" t=", time, " ", mesh.name, " ", box)
						samples += 1
	print("STADIUM_NET_ACTOR_SAMPLES ", samples, " overlap_count=", collisions)
	_check(samples == 4716 and collisions == 0, "both hands, profiles and nine aim poses clear net")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	lab.queue_free()
	await get_tree().process_frame

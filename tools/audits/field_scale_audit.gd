extends Node

# Diagnostic only: uncaught contact fixtures, not match balance or human F3 data.
const VARIANTS: Array[String] = ["current", "wall_110", "wall_130", "scoring_depths_130"]
var _cases: Array[Dictionary] = []
var _elapsed: float = 0.0


func _ready() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.set_meta(&"ball_surface", &"ground")
	ground.position = Vector3(0, -0.08, 25)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(180, 0.16, 150)
	shape.shape = box
	ground.add_child(shape)
	add_child(ground)
	for swing_id in [&"swing.contact", &"swing.power"]:
		for power in [3, 6, 9]:
			for incoming in [14.0, 20.0, 26.0]:
				for vertical in [-0.4, 0.0, 0.3, 0.6]:
					for timing in [-0.3, 0.0, 0.3]:
						_spawn(swing_id, power, incoming, vertical, timing)
	# All bodies share a ground plane but cannot collide with each other.
	# Virtual scoring walls observe the same physical trajectory at different depths.
	for frame in range(720):
		await get_tree().physics_frame
		_elapsed += 1.0 / 60.0
		for entry in _cases:
			var body: BattedBallBody = entry["body"]
			var at: Vector3 = body.global_position
			entry["max_z"] = maxf(entry["max_z"], at.z)
			for resolver: BallPlayResolver in entry["resolvers"]:
				resolver.advance_time(1.0 / 60.0)
				resolver.observe_segment(entry["previous"], at)
			entry["previous"] = at
	var rows: Array[Dictionary] = []
	for entry in _cases:
		for resolver: BallPlayResolver in entry["resolvers"]:
			if not resolver.state.dead:
				resolver.resolve_settled(entry["previous"])
		rows.append({"swing": entry["swing"], "power": entry["power"],
			"incoming_mps": entry["incoming"], "vertical_error": entry["vertical"],
			"timing_error": entry["timing"], "exit_speed_scale": entry["speed_scale"],
			"quality": entry["quality"], "exit_mps": entry["exit_mps"],
			"landing_z_m": entry["landing_z"], "landing_seconds": entry["landing_seconds"],
			"max_z_m": entry["max_z"], "outcomes": entry["outcomes"]})
	var result: Dictionary = {"engine": Engine.get_version_info()["string"],
		"scope": "Synthetic uncaught contact; no defenders, obstacles, AI or win rates",
		"variants": VARIANTS, "rows": rows, "avatar": _avatar_dimensions(),
		"single_floor_control": _single_floor_control()}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("Field scale audit completed: ", rows.size(), " Jolt trajectories.")
	for entry in _cases:
		for resolver: BallPlayResolver in entry["resolvers"]:
			for connection in resolver.play_resolved.get_connections():
				resolver.play_resolved.disconnect(connection["callable"])
		entry.clear()
	_cases.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	get_tree().quit()


func _spawn(
	swing_id: StringName, power: int, incoming: float, vertical: float, timing: float
) -> void:
	var profile: SwingProfileDefinition = ContentDB.get_swing(swing_id)
	var pitch: PitchState = PitchState.new()
	pitch.velocity = Vector3(0, 0, -incoming)
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = swing_id
	var factor: float = ContactResolver._contact_factor(6)
	var contact: Vector3 = Vector3(0, 1.05, ContactResolver.CONTACT_PLANE_Z
		+ timing * profile.contact_depth_m * factor)
	var center: Vector3 = contact - Vector3(0, vertical * profile.contact_radius_y_m * factor, 0)
	var hit: ContactResult = ContactResolver._resolve_at_contact(
		pitch, contact, center, intent, profile, 6, power)
	assert(hit.outcome in [ContactResult.Outcome.CONTACT, ContactResult.Outcome.PERFECT])
	for speed_scale in [1.0, 1.3]:
		var entry: Dictionary = {"swing": String(swing_id), "power": power,
			"incoming": incoming, "vertical": vertical, "timing": timing,
			"speed_scale": speed_scale, "quality": hit.quality,
			"exit_mps": hit.exit_velocity.length() * speed_scale,
			"landing_z": -1.0, "landing_seconds": -1.0,
			"max_z": contact.z, "previous": contact, "resolvers": [], "outcomes": {}}
		for index in range(VARIANTS.size()):
			var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID).duplicate()
			field.back_wall_z_m *= [1.0, 1.1, 1.3, 1.3][index]
			field.dead_ball_z_m = field.back_wall_z_m + 8
			if index == 3:
				field.safe_hit_z_m *= 1.3
				field.deep_air_z_m *= 1.3
			var resolver: BallPlayResolver = BallPlayResolver.new()
			resolver.start_play(field)
			resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
				entry["outcomes"][VARIANTS[index]] = outcome.display_name())
			entry["resolvers"].append(resolver)
		var body: BattedBallBody = BattedBallBody.new()
		body.configure_aero(ContentDB.get_ball_setup(&"ball_setup.fresh"))
		add_child(body)
		body.surface_contact.connect(func(surface: StringName, point: Vector3) -> void:
			if surface != &"ground":
				return
			if entry["landing_z"] < 0:
				entry["landing_z"] = point.z
				entry["landing_seconds"] = _elapsed
			for resolver: BallPlayResolver in entry["resolvers"]:
				resolver.record_ground_contact(point))
		var launch: BattedBallLaunch = BattedBallLaunch.from_contact(hit, pitch)
		launch.velocity *= speed_scale
		body.launch(launch)
		entry["body"] = body
		_cases.append(entry)


func _avatar_dimensions() -> Dictionary:
	var avatar: PlayerAvatar = PlayerAvatar.new()
	add_child(avatar)
	var body: MeshInstance3D = avatar._body_root.get_child(0)
	var head: MeshInstance3D = avatar._body_root.get_child(1)
	return {"torso_width_m": body.get_aabb().size.x,
		"torso_height_m": body.get_aabb().size.y,
		"head_height_m": head.get_aabb().size.y,
		"top_y_m": head.position.y + head.get_aabb().end.y,
		"separate_legs": false}


func _single_floor_control() -> Dictionary:
	var results: Dictionary = {}
	for scale_factor in [1.0, 1.3]:
		var field: FieldDefinition = ContentDB.get_field(PitchBatLab.FIELD_ID).duplicate()
		field.safe_hit_z_m *= scale_factor
		var resolver: BallPlayResolver = BallPlayResolver.new()
		resolver.start_play(field)
		resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void:
			results[str(scale_factor)] = outcome.display_name())
		resolver.record_ground_contact(Vector3(5, 0.04, 8))
		resolver.observe_segment(Vector3(5, 0.04, 8), Vector3(5, 0.04, 13))
		resolver.record_clean_control(&"primary", Vector3(5, 0.04, 13), false)
	return results

extends RefCounted
## New reconstruction evidence, never a recovered historical log. Production Jolt/aero at 60 Hz.
## Camera replay linearly resamples these actual physical positions; no analytic flight is used.

const CASES: Array[Dictionary] = [
	{"id": "center-low", "launch": Vector3(0, 0, 18)},
	{"id": "left-low", "launch": Vector3(-5, 1, 18)},
	{"id": "right-low", "launch": Vector3(5, 1, 18)},
	{"id": "cone-corridor-low", "launch": Vector3(12, 2, 22)},
	{"id": "cone-corridor-air", "launch": Vector3(10, 6, 18)},
	{"id": "left-deep", "launch": Vector3(-13, 7, 24)},
	{"id": "right-deep", "launch": Vector3(13, 7, 24)},
	{"id": "center-high", "launch": Vector3(0, 22, 18)},
	{"id": "left-side", "launch": Vector3(-22, 3, 10)},
	{"id": "right-side", "launch": Vector3(22, 3, 10)},
	{"id": "back-foul", "launch": Vector3(-6, 3, -10)},
	{"id": "chair-foul", "launch": Vector3(0, 0, -10)},
	{"id": "cone-ricochet-control", "launch": Vector3(0, 0, -6), "start": Vector3(8, 0.42, 15.2)}
]


static func record(
	owner: Node, lab: PitchBatLab, selected: Array[String] = []
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var property: StadiumYardTwoProperty = lab.get_meta("stadium_property")
	var boundary: StadiumBoundaryPrototype = property.get_node("BoundaryGraph")
	owner._check(
		Engine.physics_ticks_per_second == 60, "physical source histories use unchanged 60 Hz"
	)
	for recipe: Dictionary in CASES:
		if not selected.is_empty() and not selected.has(recipe.id):
			continue
		var resolver: BallPlayResolver = BallPlayResolver.new()
		resolver.start_play(property.field, recipe.launch.z < 0 and not recipe.has("start"))
		resolver.segment_observer = StadiumBoundaryObserver.observe
		var ball: BattedBallBody = BattedBallBody.new()
		lab.add_child(ball)
		property.bind_ball(ball, resolver)
		boundary.bind_ball(ball, resolver)
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = recipe.get("start", Vector3(0, 1, 0))
		launch.velocity = recipe.launch
		var events: Array[Dictionary] = []
		ball.body_entered.connect(
			func(body: Node) -> void:
				events.append(
					{
						"path": String(property.get_path_to(body)),
						"surface": String(body.get_meta("ball_surface", "")),
						"item": String(body.get_meta("stadium_item", "")),
						"position": ball.global_position,
						"velocity": ball.linear_velocity,
						"time": resolver.state.elapsed_seconds,
						"gravity": ball.gravity_scale
					}
				)
		)
		ball.launch(launch)
		var positions: Array[Vector3] = [launch.position]
		var velocities: Array[Vector3] = [launch.velocity]
		var times: Array[float] = [0.0]
		for frame in range(240):
			await owner.get_tree().physics_frame
			resolver.advance_time(1.0 / 60.0)
			resolver.observe_segment(positions[-1], ball.global_position)
			positions.append(ball.global_position)
			velocities.append(ball.linear_velocity)
			times.append(float(frame + 1) / 60.0)
			if resolver.state.dead or (frame > 30 and ball.sleeping):
				break
		owner._check(
			positions.size() > 2 and ball.gravity_scale == 1.0,
			"genuine production gravity-on history " + recipe.id
		)
		if recipe.id == "cone-ricochet-control":
			owner._check(
				(
					resolver.state.last_obstacle_contact
					== StringName(StadiumYardTwoStudy.PREFIX + "O-R1")
				),
				"real cone contact occurs in controlled history"
			)
		var history: Dictionary = {
			"id": recipe.id,
			"start": launch.position,
			"launch": launch.velocity,
			"positions": positions,
			"velocities": velocities,
			"times": times,
			"duration": times[-2] if resolver.state.dead else times[-1],
			"terminal_sample":
			(
				{"position": positions[-1], "velocity": velocities[-1], "time": times[-1]}
				if resolver.state.dead
				else {}
			),
			"events": events,
			"dead": resolver.state.dead,
			"grounded": resolver.state.has_grounded,
			"last_obstacle": resolver.state.last_obstacle_contact,
			"source_hz": 60,
			"gravity_scale": ball.gravity_scale,
			"physical_radius": ball.radius_m,
			"controlled_start": recipe.has("start")
		}
		result.append(history)
		print("AY02_NEW_PHYSICS_HISTORY ", JSON.stringify(_json_value(history), "", true, true))
		ball.queue_free()
		await owner.get_tree().physics_frame
		# Complete ordinary receiver visual settling between physical fixtures.
		await owner.get_tree().create_timer(0.62).timeout
	return result


static func sample(history: Dictionary, time: float) -> Vector3:
	var step: float = clampf(time * 60.0, 0, history.positions.size() - 1)
	var low: int = int(floor(step))
	var high: int = mini(low + 1, history.positions.size() - 1)
	return (history.positions[low] as Vector3).lerp(history.positions[high], step - low)


static func _json_value(value: Variant) -> Variant:
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Array:
		var rows: Array = []
		for entry: Variant in value:
			rows.append(_json_value(entry))
		return rows
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _json_value(value[key])
		return result
	return value

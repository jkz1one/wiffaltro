extends Node3D
## Engine-contact data audit; does not certify prototype event ordering or activate any field.

var _failures: int = 0


func _ready() -> void:
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	add_child(property)
	_check(property.build("backyard", StadiumStarterLayout.empty(), StadiumStock.new_club()),
		"isolated actual property ground")
	property.get_node("TemplateBackWall").free()
	var boundary: StadiumBoundaryPrototype = StadiumBoundaryPrototype.new()
	property.add_child(boundary)
	_check(boundary.build(), "actual joined boundary geometry")
	await get_tree().physics_frame
	await get_tree().physics_frame
	for speed: float in [6.0, 36.0]:
		for index in range(StadiumBoundaryGraph.VERTICES.size()):
			var corner: Vector2 = StadiumBoundaryGraph.VERTICES[index]
			var inside: Vector2 = corner.lerp(Vector2(0, 10), 0.08)
			var direction: Vector2 = (corner - inside).normalized()
			await _trial(boundary, "corner:%d:%d" % [index, int(speed)],
				Vector3(inside.x, 0.8, inside.y), Vector3(direction.x, 0, direction.y) * speed)
	for height: float in [0.037, 0.04, 0.05, 0.08]:
		await _trial(boundary, "ground-wall:%.3f" % height,
			Vector3(0, height, 23), Vector3(0, 0, 12))
	await _trial(boundary, "ground-wall:simultaneous",
		Vector3(0, 0.05, 23.34), Vector3(0, 0, 12))
	property.queue_free()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro boundary contact data checks passed: "
			+ "actual manifold and callback data captured.")
	get_tree().quit(0 if _failures == 0 else 1)


func _trial(boundary: StadiumBoundaryPrototype, label: String, from: Vector3,
	velocity: Vector3) -> void:
	var ball: BattedBallBody = load("res://src/tests/stadium_contact_probe_ball.gd").new()
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
	boundary.bind_ball(ball, resolver)
	var before: int = boundary.contacts.size()
	var outcomes: Array[BallPlayOutcome] = []
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome))
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = from
	launch.velocity = velocity
	ball.launch(launch)
	for frame in range(120):
		await get_tree().physics_frame
		if not ball.batches.is_empty():
			await get_tree().physics_frame
			break
	_check(not ball.batches.is_empty() and not ball.entered.is_empty(), "engine contact data " + label)
	var frames: Array = []
	for event: Dictionary in boundary.contacts.slice(before):
		_check(not frames.has(event.frame), "one named boundary event per contact batch")
		frames.append(event.frame)
	if label == "ground-wall:simultaneous":
		var ids: Array = []
		for contact: Dictionary in ball.batches[0].contacts:
			ids.append(contact.id)
		_check(ids.has("ground") and ids.has("BACK-TERMINAL-01"),
			"real ground and back-wall contacts share the initial manifold")
	if label.begins_with("ground-wall:"):
		_check(outcomes.size() == 1 and outcomes[0].result == (
			BallPlayOutcome.Result.DOUBLE if from.y < 0.06 else BallPlayOutcome.Result.TRIPLE),
			"real ground history is recorded before wall classification")
	print("BOUNDARY_CONTACT_DATA ", JSON.stringify({"sample": label,
		"batches": ball.batches, "entered": ball.entered,
		"prototype_events": boundary.contacts.slice(before)}, "", true, true))
	ball.queue_free()
	await get_tree().physics_frame


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

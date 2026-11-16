extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## Shared bounded paid-model, actual-contact, route and original-image checks. Zero games.

const ITEMS: Array[String] = [
	"ST-015", "ST-016", "ST-017", "ST-004", "ST-008", "ST-009", "ST-010", "ST-011", "ST-012"
]
const LIVE: Array[String] = ["ST-004", "ST-008", "ST-009", "ST-010", "ST-011", "ST-012"]
var _histories: Array[Dictionary] = []
var _operands: Dictionary = {}


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"GROUND_PROPS_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func _mesh_bounds(root: Node3D, node: Node) -> AABB:
	var result: AABB
	var first: bool = true
	if node is MeshInstance3D:
		result = root.global_transform.affine_inverse() * node.global_transform * node.get_aabb()
		first = false
	for child: Node in node.get_children():
		var box: AABB = _mesh_bounds(root, child)
		if box.size.is_zero_approx():
			continue
		result = box if first else result.merge(box)
		first = false
	return result


func _models() -> void:
	_phase = "nine-model-contract"
	var root: Node3D = _world()
	for item: String in ITEMS:
		var model: Node3D = StadiumGroundPropsModels.create(item)
		root.add_child(model)
		var envelope: AABB = StadiumGroundPropsModels.envelope(item)
		var visible: AABB = _mesh_bounds(model, model)
		_operands = {"item": item, "envelope": str(envelope), "visible": str(visible)}
		_check(
			(
				model.get_meta("stadium_item", "") == item
				and envelope.grow(0.001).encloses(visible)
				and visible.size.length() > 0.1
			),
			"distinct complete visible model fits its declared envelope"
		)
		var surfaces: Array[String] = StadiumGroundPropsModels.surfaces(item)
		var bodies: Array[Node] = model.find_children("*", "StaticBody3D", true, false)
		var names: Array[String] = []
		var physical: bool = true
		for body: StaticBody3D in bodies:
			names.append(str(body.get_meta("surface_id", "")))
			physical = (
				physical
				and body.get_meta("stadium_item", "") == item
				and body.get_meta("surface_role", "") == "LIVE_RICOCHET"
				and body.collision_layer == 1
				and body.get_child_count() == 1
			)
			var collision: CollisionShape3D = body.get_child(0) as CollisionShape3D
			physical = physical and collision != null and collision.shape != null
			if collision != null and collision.shape != null:
				var box: AABB = (
					model.global_transform.affine_inverse()
					* collision.global_transform
					* collision.shape.get_debug_mesh().get_aabb()
				)
				physical = physical and envelope.grow(0.001).encloses(box)
		names.sort()
		surfaces.sort()
		_operands["surfaces"] = names
		_check(
			physical and names == surfaces and (not bodies.is_empty()) == LIVE.has(item),
			"only six live props have complete named fixed colliders; plants are cosmetic"
		)
		model.queue_free()
	await _close_view()


func _routes(property: StadiumPropertyGeometry, checked: Dictionary) -> void:
	_phase = "paid-defender-routes"
	var obstacles: Array[Dictionary] = property.route_obstacles()
	for row: Dictionary in checked.placements:
		if not LIVE.has(row.item):
			continue
		var obstacle: Dictionary = {}
		for candidate: Dictionary in obstacles:
			if candidate.copy == row.copy:
				obstacle = candidate
		_operands = {"item": row.item, "copy": row.copy, "obstacle": str(obstacle)}
		_check(
			not obstacle.is_empty(), "actual paid solid contributes an exact-copy route obstacle"
		)
		if obstacle.is_empty():
			continue
		var center: Vector3 = obstacle.center
		center.y = 0
		var start: Vector3 = center + Vector3(0, 0, -float(obstacle.radius) - 1.0)
		var goal: Vector3 = center + Vector3(0, 0, float(obstacle.radius) + 1.0)
		var fielder: FielderController = FielderController.new()
		property.add_child(fielder)
		fielder.set_physics_process(false)
		fielder.stadium_obstacles = obstacles
		fielder.set_anchor(start)
		fielder.reaction_delay_seconds = 0
		fielder.begin_play()
		fielder.target_position = goal
		var safe: bool = true
		for frame in range(360):
			var previous: Vector3 = fielder.global_position
			fielder._physics_process(1.0 / 60.0)
			safe = (
				safe and StadiumDefenderRoutes.clear(previous, fielder.global_position, obstacles)
			)
		_operands["finish"] = str(fielder.global_position)
		_operands["goal"] = str(goal)
		_check(
			safe and fielder.global_position.distance_to(goal) < 0.06,
			"real fielder controller reaches the opposite side without penetrating paid solids"
		)
		var clipped: Vector3 = StadiumDefenderRoutes.clip(start, goal, obstacles)
		_check(
			(
				StadiumDefenderRoutes.clear(start, clipped, obstacles)
				and clipped.distance_to(goal) > 0.1
			),
			"forced direct travel clips instead of tunnelling through a live prop"
		)
		fielder.free()


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_phase = "entry"
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"ground props qualification uses native rendering and an explicit output folder"
	)
	if _failures == 0:
		_check(
			DirAccess.make_dir_recursive_absolute(directory) == OK, "bounded capture folder opens"
		)
		var owned: Node = load("res://src/tests/stadium_displays_ui_test.gd").new()
		await get_tree().process_frame
		var result: Dictionary = await owned.run_owned()
		_checks += int(result.checks)
		_failures += int(result.failures)
		var paid: Array = result.paid
		owned.free()
		_check(
			paid.size() == 3 and not paid.has(null),
			"three legal same-inventory paid arrangements are available"
		)
		if paid.size() == 3 and not paid.has(null):
			await _models()
			for index in range(paid.size()):
				await _arrangement(paid[index], index == 0)
			await _sheet()
	_phase = "completion"
	_check(
		_images == ["ground-props-models.png"] and _histories.size() == 6,
		"one nine-item original and six actual native contact histories; no game claim"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"histories": _histories,
		"games": 0,
		"synthetic_funding": true,
		"inaccessible_volumes": [],
		"trapped_ball_claim": false,
		"earned_career_claim": false,
		"live_game_claim": false
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("ground-props-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "finite native evidence file opens")
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "native evidence fully written")
		file.close()
	print(
		(
			"GROUND_PROPS_REBUILD checks=%d failures=%d images=%d contacts=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size(), _histories.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _arrangement(paid: ClubAssetLedger, authority: bool) -> void:
	_phase = "paid-property"
	var before: String = JSON.stringify(paid.to_data(), "", true, true)
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(paid)
	var layout: Dictionary = paid.view().stadium_active
	var stock: StadiumStock = paid.construction()
	var checked: Dictionary = StadiumHomeLayout.validate(layout, stock, paid.view().land)
	_operands = {
		"balance": paid.view().balance,
		"snapshot_version": snapshot.get("version", -1),
		"layout_version": layout.get("version", -1),
		"valid": checked.get("ok", false),
		"error": checked.get("error", "")
	}
	_check(
		not snapshot.is_empty() and checked.ok and checked.live_units <= 4,
		"current paid snapshot preserves exact budget and source ownership"
	)
	if snapshot.is_empty() or not checked.ok:
		return
	var root: Node3D = _world()
	var property: StadiumPropertyGeometry = StadiumPropertyGeometry.new()
	# Surface terrain applies only to the complete off-tree property.
	var built: bool = property.build(snapshot.tier, snapshot.layout, stock)
	var boundary: Node3D = StadiumBoundaryRuntime.assemble(property) if built else null
	_check(built and boundary != null, "full current property and ordinary boundary assemble")
	if not built or boundary == null:
		property.free()
		await _close_view()
		return
	root.add_child(property)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var all_owned: bool = true
	var plant_copies: Array[String] = []
	for row: Dictionary in checked.placements:
		if not ITEMS.has(row.item):
			continue
		var model: Node3D = property.objects.get(row.copy)
		all_owned = (
			all_owned
			and is_instance_valid(model)
			and model.get_meta("owned_copy", "") == row.copy
			and model.get_meta("site", "") == row.site
			and model.position == row.position
		)
		if not LIVE.has(row.item):
			plant_copies.append(row.copy)
	var obstacles: Array[Dictionary] = property.route_obstacles()
	for obstacle: Dictionary in obstacles:
		all_owned = all_owned and not plant_copies.has(obstacle.copy)
	_check(
		all_owned,
		"installed exact copies and sites match; cosmetic plants add no defender obstacles"
	)
	if authority:
		_authority(property, checked)
	_routes(property, checked)
	for row: Dictionary in checked.placements:
		if LIVE.has(row.item):
			await _flight_owned(property, boundary, row, checked)
	_check(
		JSON.stringify(paid.to_data(), "", true, true) == before,
		"models, routes and native contacts never mutate the paid journal"
	)
	await _close_view()


func _flight_owned(
	property: StadiumPropertyGeometry, boundary: Node3D, row: Dictionary, checked: Dictionary
) -> void:
	_phase = "native-flight-" + row.item
	var model: Node3D = property.objects[row.copy]
	var envelope: AABB = StadiumGroundPropsModels.envelope(row.item)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	# One foul-labelled launch proves the same live contact cannot make it fair.
	var foul: bool = row.item == "ST-009"
	resolver.start_play(property.field, foul)
	resolver.segment_observer = (
		boundary.graph.observe
		if boundary is StadiumRecipeBoundaryBody
		else StadiumBoundaryObserver.observe
	)
	var outcomes: Array[BallPlayOutcome] = []
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome))
	var ball: BattedBallBody = BattedBallBody.new()
	property.add_child(ball)
	property.bind_ball(ball, resolver)
	boundary.bind_ball(ball, resolver)
	var native: Array[Dictionary] = []
	ball.body_entered.connect(
		func(body: Node) -> void:
			if body.get_meta("ball_surface", "") == &"ground":
				resolver.record_ground_contact(ball.global_position)
			if property.is_ancestor_of(body) and body.get_meta("owned_copy", "") == row.copy:
				native.append(
					{
						"body": str(body.get_path()),
						"surface": body.get_meta("surface_id", ""),
						"time": resolver.state.elapsed_seconds,
						"position": _point(ball.global_position),
						"dead": resolver.state.dead,
						"floor": int(resolver.state.result_floor),
						"foul": resolver.state.is_foul_play,
						"grounded": resolver.state.has_grounded,
						"owned_contact": str(resolver.state.last_obstacle_contact)
					}
				)
	)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = model.to_global(Vector3(0, envelope.end.y + 0.45, 0))
	launch.velocity = Vector3(0, -6, 0)
	if row.item == "ST-011":
		launch.position = model.to_global(Vector3(0.65, envelope.end.y + 0.45, 0.2))
	# The shed's broad closed front allows a real forward Single-plane crossing.
	# This launch earns the floor from observed physics, never by assigning state.
	if row.item == "ST-012":
		launch.position = Vector3(row.position.x * 0.70, 1.7, property.field.safe_hit_z_m - 0.25)
		var inner_x: float = -signf(row.position.x)
		var target: Vector3 = model.to_global(Vector3(inner_x, 1.1, -1.25))
		var duration: float = 0.65
		launch.velocity = (target - launch.position) / duration + Vector3.UP * 9.8 * duration * 0.5
	ball.launch(launch)
	var previous: Vector3 = launch.position
	var settled: float = 0.0
	var frames: int = 0
	var before_settlement: int = -1
	var terminal_criterion: String = ""
	# Match the ordinary lab's speed/hold OR timeout rule. One extra frame permits
	# elapsed-time accumulation to reach the unchanged timeout despite rounding.
	var max_frames: int = ceili(PitchBatLab.BATTED_BALL_TIMEOUT_SECONDS * 60.0) + 1
	for frame in range(max_frames):
		await get_tree().physics_frame
		frames = frame + 1
		resolver.advance_time(1.0 / 60.0)
		resolver.observe_segment(previous, ball.global_position)
		previous = ball.global_position
		if resolver.state.dead:
			terminal_criterion = "observed_terminal"
			break
		settled = (
			settled + 1.0 / 60.0
			if ball.linear_velocity.length() <= PitchBatLab.SETTLED_SPEED_MPS
			else 0.0
		)
		if (
			settled >= PitchBatLab.SETTLED_HOLD_SECONDS
			or resolver.state.elapsed_seconds >= PitchBatLab.BATTED_BALL_TIMEOUT_SECONDS
		):
			before_settlement = int(resolver.state.result_floor)
			terminal_criterion = (
				"speed_hold"
				if settled >= PitchBatLab.SETTLED_HOLD_SECONDS
				else "production_timeout"
			)
			resolver.resolve_settled(ball.global_position)
			break
	_operands = {
		"item": row.item,
		"copy": row.copy,
		"native": native,
		"frames": frames,
		"position": _point(ball.global_position),
		"velocity": _point(ball.linear_velocity),
		"elapsed_seconds": resolver.state.elapsed_seconds,
		"settled_seconds": settled,
		"terminal_criterion": terminal_criterion,
		"floor": int(resolver.state.result_floor),
		"before_settlement": before_settlement,
		"dead": resolver.state.dead,
		"events": resolver.state.stadium_contacts,
		"outcomes": outcomes.size()
	}
	_check(
		(
			ball.gravity_scale == 1.0
			and not native.is_empty()
			and native[0].dead == false
			and native[0].foul == foul
			and native[0].owned_contact == row.copy
		),
		"gravity-on ball touches the actual owned solid and remains a live attributed ricochet"
	)
	var placements: Dictionary = {}
	for placed: Dictionary in checked.placements:
		placements[placed.copy] = placed
	var event_ok: bool = not resolver.state.stadium_contacts.is_empty()
	for event: Dictionary in resolver.state.stadium_contacts:
		event_ok = (
			event_ok
			and PhysicalStadiumContacts._event(
				event, placements, boundary.graph if boundary is StadiumRecipeBoundaryBody else null
			)
		)
	_check(
		(
			event_ok
			and not native.is_empty()
			and StadiumGroundPropsModels.surfaces(row.item).has(native[0].surface)
		),
		"current codec admits only the actual paid copy and authored contact surface"
	)
	var expected: int = (
		BallPlayOutcome.Result.FOUL
		if foul
		else (
			BallPlayOutcome.Result.DOUBLE
			if (before_settlement == BallPlayState.ResultFloor.DOUBLE)
			else BallPlayOutcome.Result.SINGLE
		)
	)
	_check(
		(
			outcomes.size() == 1
			and outcomes[0].result == expected
			and resolver.state.dead
			and (
				(
					terminal_criterion == "speed_hold"
					and settled >= PitchBatLab.SETTLED_HOLD_SECONDS
					and ball.linear_velocity.length() <= PitchBatLab.SETTLED_SPEED_MPS
				)
				or (
					terminal_criterion == "production_timeout"
					and resolver.state.elapsed_seconds >= PitchBatLab.BATTED_BALL_TIMEOUT_SECONDS
				)
				or (terminal_criterion == "observed_terminal" and foul)
			)
			and (foul or before_settlement >= 0)
			and (row.item != "ST-012" or before_settlement >= BallPlayState.ResultFloor.SINGLE)
		),
		"actual contact history uses the normal settlement/timeout rule and earned floor or assigned foul"
	)
	var terminal: String = JSON.stringify(resolver.state.stadium_contacts)
	var floor: int = int(resolver.state.result_floor)
	var applied: bool = StadiumSurfaceRules.apply(
		resolver,
		"LIVE_RICOCHET",
		row.copy,
		ball.global_position,
		StadiumGroundPropsModels.surfaces(row.item)[0]
	)
	resolver.resolve_settled(ball.global_position)
	_check(
		(
			not applied
			and outcomes.size() == 1
			and int(resolver.state.result_floor) == floor
			and JSON.stringify(resolver.state.stadium_contacts) == terminal
		),
		"post-terminal contact and repeated settlement cannot replace result or provenance"
	)
	_operands["result"] = int(outcomes[0].result) if outcomes.size() == 1 else -1
	_operands["reason"] = str(outcomes[0].reason) if outcomes.size() == 1 else ""
	_histories.append(_operands.duplicate(true))
	ball.queue_free()
	await get_tree().physics_frame


func _authority(property: StadiumPropertyGeometry, checked: Dictionary) -> void:
	_phase = "captured-copy-and-play-authority"
	var row: Dictionary = {}
	for candidate: Dictionary in checked.placements:
		if LIVE.has(candidate.item):
			row = candidate
			break
	var model: Node3D = property.objects[row.copy]
	var collision: Node3D = model.get_node("Collision")
	var body: StaticBody3D = collision.get_child(0)
	var old: BallPlayResolver = BallPlayResolver.new()
	old.start_play(property.field)
	old.segment_observer = StadiumBoundaryObserver.observe
	var first: BattedBallBody = BattedBallBody.new()
	first.freeze = true
	property.add_child(first)
	first.global_position = body.global_position
	property.bind_ball(first, old)
	model.set_meta("owned_copy", "foreign-copy")
	var changed_copy: bool = not property.props_intact()
	property._ball_contact(body, first, old)
	changed_copy = changed_copy and old.state.stadium_contacts.is_empty()
	model.set_meta("owned_copy", row.copy)
	var restored_copy: bool = property.props_intact()
	var replacement: StaticBody3D = body.duplicate() as StaticBody3D
	collision.remove_child(body)
	collision.add_child(replacement)
	var changed_body: bool = not property.props_intact()
	property._ball_contact(replacement, first, old)
	changed_body = changed_body and old.state.stadium_contacts.is_empty()
	collision.remove_child(replacement)
	replacement.free()
	collision.add_child(body)
	collision.move_child(body, 0)
	_operands = {
		"copy": row.copy,
		"changed_copy": changed_copy,
		"restored_copy": restored_copy,
		"changed_body": changed_body,
		"restored_body": property.props_intact()
	}
	_check(
		changed_copy and restored_copy and changed_body and property.props_intact(),
		"copied ownership metadata and a substituted same-metadata body cannot acquire contact authority"
	)
	var current: BallPlayResolver = BallPlayResolver.new()
	current.start_play(property.field)
	current.segment_observer = StadiumBoundaryObserver.observe
	var second: BattedBallBody = BattedBallBody.new()
	second.freeze = true
	property.add_child(second)
	second.global_position = body.global_position
	property.bind_ball(second, current)
	property._ball_contact(body, first, old)
	var old_ball_refused: bool = old.state.stadium_contacts.is_empty()
	current.start_play(property.field)
	property._ball_contact(body, second, current)
	var old_play_refused: bool = current.state.stadium_contacts.is_empty()
	property.bind_ball(second, current)
	property._ball_contact(body, second, current)
	_operands = {
		"copy": row.copy,
		"old_ball_refused": old_ball_refused,
		"old_play_refused": old_play_refused,
		"current_events": current.state.stadium_contacts
	}
	_check(
		(
			old_ball_refused
			and old_play_refused
			and current.state.stadium_contacts.size() == 1
			and current.state.last_obstacle_contact == StringName(row.copy)
		),
		"prior-ball and prior-play callbacks refuse while the exact freshly captured pair remains live"
	)
	first.free()
	second.free()


func _point(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


func _sheet() -> void:
	_phase = "nine-model-original"
	var root: Node3D = _world()
	var camera: Camera3D = _studio(root, Vector3(0, 18, 18), Vector3(0, 1, 0), 11.5)
	# Tall models sit in the back row; low plants cannot hide the live props.
	var order: Array[String] = [
		"ST-004", "ST-011", "ST-012", "ST-008", "ST-010", "ST-009", "ST-015", "ST-017", "ST-016"
	]
	var labels: Array[Dictionary] = []
	for index in range(order.size()):
		var item: String = order[index]
		var model: Node3D = StadiumGroundPropsModels.create(item)
		root.add_child(model)
		model.position = Vector3((index % 3 - 1) * 5.0, 0, (index / 3 - 1) * 4.0)
		labels.append({"item": item, "model": model})
	await get_tree().process_frame
	for entry: Dictionary in labels:
		var model: Node3D = entry.model
		var envelope: AABB = StadiumGroundPropsModels.envelope(entry.item)
		var point: Vector3 = model.to_global(Vector3(0, envelope.end.y, 0))
		var caption: Label = Label.new()
		caption.text = entry.item + "  " + str(StadiumCatalog.ROWS[entry.item][0])
		caption.position = camera.unproject_position(point) - Vector2(140, 26)
		caption.size = Vector2(280, 38)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", 15)
		root.add_child(caption)
	_label(
		root,
		"GROUND PROPS | Nine authored models at native scale | Display only, not one legal arrangement",
		Vector2(20, 16),
		18
	)
	await _capture("ground-props-models.png")
	await _close_view()

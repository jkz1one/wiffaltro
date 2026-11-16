extends Node3D
## Bounded headless runtime/report proofs plus native moving-body probes, not a game or visual
## qualification.

var _checks: int = 0
var _failures: int = 0
var _property: StadiumPropertyGeometry
var _boundary: StadiumBoundaryOwnedRuntime
var _model: Node3D
var _snapshot: Dictionary
var _outcomes: Array[BallPlayOutcome] = []


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("JUNK_CAR_RUNTIME_FAILURE " + label)


func _ready() -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.new_club(175, [1000])
	_snapshot = StadiumLayoutSnapshot.capture(ledger)
	_property = StadiumPropertyGeometry.new()
	add_child(_property)
	_check(
		_property.build("backyard", ledger.view().stadium_active, ledger.construction()),
		"complete fixed-car property builds"
	)
	_boundary = StadiumBoundaryRuntime.assemble(_property) as StadiumBoundaryOwnedRuntime
	_check(
		_boundary != null and _property.props_intact(), "sealed ordinary boundary owns car routing"
	)
	if _boundary == null:
		_finish()
		return
	_model = _property.objects[StadiumStock.SALVAGE_COPY]
	await get_tree().physics_frame
	await get_tree().physics_frame
	_geometry_and_admission()
	for foul: bool in [false, true]:
		for floor_value: int in [
			BallPlayState.ResultFloor.NONE,
			BallPlayState.ResultFloor.SINGLE,
			BallPlayState.ResultFloor.DOUBLE,
			BallPlayState.ResultFloor.TRIPLE,
			BallPlayState.ResultFloor.HOME_RUN
		]:
			_terminal(foul, floor_value)
	await _stale_and_rebound()
	await _native_probe("body-ricochet", Vector3(-1.8, 0.55, 0), Vector3(7, 0, 0), false)
	await _native_probe("underbody-pass-through", Vector3(-1.1, 0.10, 0), Vector3(7, 0, 0), false)
	await _native_probe("settled-underbody", Vector3(-0.67, 0.10, 0), Vector3(0.8, 0, 0), true)
	_seals()
	await TestAudioDrain.finish(get_tree())
	_finish()


func _finish() -> void:
	print(
		(
			"JUNK_CAR_RUNTIME_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"games": 0,
					"visual_qualified": false,
					"synthetic_controls": true
				}
			)
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _context(local: Vector3, foul: bool = false) -> Dictionary:
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.segment_observer = _boundary.observe
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	add_child(ball)
	ball.global_position = _model.to_global(local)
	_property.bind_ball(ball, resolver)
	_boundary.bind_ball(ball, resolver)
	# Explicit synthetic state controls do not claim an ordinary hit trajectory.
	ball._started = true
	ball.sleeping = true
	return {"ball": ball, "resolver": resolver}


func _sample(
	context: Dictionary,
	previous: Vector3,
	current: Vector3,
	delta: float = 0.05,
	apply: bool = true
) -> Dictionary:
	context.ball.global_position = _model.to_global(current)
	context.resolver.advance_time(delta)
	var selected: Dictionary = _boundary.event(
		_model.to_global(previous),
		_model.to_global(current),
		context.ball.radius_m,
		context.resolver
	)
	if apply and not selected.is_empty():
		_boundary.apply_event(context.resolver, selected)
	return selected


func _hold(context: Dictionary, local: Vector3, apply: bool = true) -> Dictionary:
	var selected: Dictionary = {}
	for step in range(8):
		selected = _sample(context, local, local, 0.05, apply)
		if not selected.is_empty():
			break
	return selected


func _geometry_and_admission() -> void:
	var radius: float = 0.0365
	var hit: Dictionary = _boundary.event(
		_model.to_global(Vector3(-2, 0.55, 0)), _model.to_global(Vector3(0, 0.55, 0)), radius
	)
	_check(
		(
			hit.get("kind") == "junk_car_solid"
			and hit.get("swept_contact", false)
			and hit.get("surface") == StadiumJunkCarModels.SURFACE
		),
		"actual closed car convex body supplies live native sweep witness"
	)
	var context: Dictionary = _context(Vector3(-1, 0.1, 0))
	_check(
		(
			_sample(context, Vector3(-1, 0.1, 0), Vector3(0, 0.1, 0)).is_empty()
			and not context.resolver.state.dead
		),
		"full-sphere aperture entry alone never awards a hit"
	)
	context.ball.free()
	context = _context(Vector3(0, 0.1, 0))
	_check(
		_hold(context, Vector3(0, 0.1, 0)).is_empty() and not context.resolver.state.dead,
		"initially overlapped ball has no witnessed admission"
	)
	context.ball.free()
	context = _context(Vector3(-1, 0.1, 0))
	context.ball.linear_velocity = Vector3(20, 0, 0)
	_check(
		(
			_sample(context, Vector3(-1, 0.1, 0), Vector3(1, 0.1, 0)).is_empty()
			and not context.resolver.state.dead
		),
		"fast complete underbody passage stays live"
	)
	context.ball.free()
	context = _context(Vector3(-1, 0.26, 0))
	_check(
		(
			(
				_sample(context, Vector3(-1, 0.26, 0), Vector3(0, 0.26, 0)).get("kind")
				== "junk_car_solid"
			)
			and not context.resolver.state.dead
		),
		"sphere touching underbody ceiling is a ricochet, not admitted cavity"
	)
	context.ball.free()
	context = _context(Vector3(-1, 0.1, 0))
	_sample(context, Vector3(-1, 0.1, 0), Vector3(-0.5, 0.1, 0))
	context.ball.linear_velocity = Vector3(0.04, 0, 0)
	var from: Vector3 = Vector3(-0.5, 0.1, 0)
	for step in range(40):
		var next: Vector3 = from + Vector3(0.002, 0, 0)
		_sample(context, from, next)
		from = next
	_check(
		not context.resolver.state.dead,
		"sustained slow underbody motion never masquerades as settled dwell"
	)
	context.ball.free()
	var solid: Dictionary = {
		"fraction": 1.0, "priority": 400, "segment": "car", "swept_contact": true
	}
	var trap: Dictionary = {
		"fraction": 1.0, "priority": -1, "segment": "trap", "swept_contact": false
	}
	_check(
		StadiumTimberDugoutBoundary.precedes(solid, trap, 1),
		"existing ordering puts real solids before coincident trap completion"
	)


func _terminal(foul: bool, floor_value: int) -> void:
	var local: Vector3 = Vector3(0, 0.10, 0)
	var context: Dictionary = _context(Vector3(-1, 0.1, 0), foul)
	context.resolver.state.raise_result_floor(floor_value)
	_sample(context, Vector3(-1, 0.1, 0), local)
	var selected: Dictionary = _hold(context, local)
	var expected: int = (
		BallPlayOutcome.Result.FOUL
		if foul
		else [
			BallPlayOutcome.Result.SINGLE,
			BallPlayOutcome.Result.SINGLE,
			BallPlayOutcome.Result.DOUBLE,
			BallPlayOutcome.Result.TRIPLE,
			BallPlayOutcome.Result.HOME_RUN
		][floor_value]
	)
	var label: String = "foul=%s floor=%d" % [foul, floor_value]
	_check(
		(
			selected.get("kind") == "junk_car_trap"
			and context.resolver.state.dead
			and _outcomes.size() == 1
			and _outcomes[0].result == expected
		),
		"admitted settled ball has minimumSingle, preserving higher and foul: " + label
	)
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"terminal exact event is single-use: " + label
	)
	var names: Array[String] = ["out", "foul", "single", "double", "triple", "home_run"]
	var plays: Array = [
		{
			"result": names[expected],
			"contact": ContactResult.Outcome.FOUL if foul else ContactResult.Outcome.CONTACT,
			"exit_speed": 7.0
		}
	]
	var rows: Array = [
		{
			"play": 0,
			"reason": String(_outcomes[0].reason) if not _outcomes.is_empty() else "",
			"events": context.resolver.state.stadium_contacts.duplicate(true)
		}
	]
	_check(
		PhysicalStadiumContacts.valid(rows, plays, _snapshot),
		"actual runtime record validates against exact owned snapshot: " + label
	)
	if not rows[0].events.is_empty():
		for field: String in ["id", "surface", "role", "position", "time"]:
			var altered: Array = rows.duplicate(true)
			var values: Dictionary = {
				"id": "stored-or-foreign",
				"surface": StadiumJunkCarModels.SURFACE,
				"role": "HOT_TUB_WATER",
				"position": [-16.2, 1.0, 18.0],
				"time": 0.0
			}
			altered[0].events[-1][field] = values[field]
			_check(
				not PhysicalStadiumContacts.valid(altered, plays, _snapshot),
				"report rejects forged " + field + ": " + label
			)
	context.ball.free()


func _stale_and_rebound() -> void:
	var local: Vector3 = Vector3(0, 0.1, 0)
	var context: Dictionary = _context(Vector3(-1, 0.1, 0))
	_sample(context, Vector3(-1, 0.1, 0), local)
	_sample(context, local, Vector3(-1, 0.1, 0))
	_check(
		_hold(context, local).is_empty() and not context.resolver.state.dead,
		"exit clears admission, so a later interior teleport cannot score"
	)
	context.ball.free()
	context = _context(Vector3(-1, 0.1, 0))
	_sample(context, Vector3(-1, 0.1, 0), local)
	_sample(context, local, local, StadiumJunkCarRuntime.OBSERVATION_EXPIRY + 0.01)
	_check(_hold(context, local).is_empty(), "unobserved gap expires admission")
	context.ball.free()
	context = _context(Vector3(-1, 0.1, 0))
	_sample(context, Vector3(-1, 0.1, 0), local)
	var selected: Dictionary = _hold(context, local, false)
	context.resolver.advance_time(0.01)
	_check(
		not selected.is_empty() and not _boundary.apply_event(context.resolver, selected),
		"issued trap event expires when play time advances"
	)
	selected = _sample(context, local, local, 0.01, false)
	_boundary.bind_ball(context.ball, context.resolver)
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"new flight serial rejects prior trap issuance"
	)
	_check(_hold(context, local).is_empty(), "new current flight cannot inherit prior admission")
	context.ball.free()
	context = _context(Vector3(-1, 0.1, 0))
	_sample(context, Vector3(-1, 0.1, 0), local)
	selected = _hold(context, local, false)
	context.ball.physics_contact_router = Callable()
	await get_tree().physics_frame
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"issued trap cannot be replayed on a later physics frame"
	)
	context.ball.free()
	context = _context(Vector3(-1, 0.1, 0))
	_sample(context, Vector3(-1, 0.1, 0), local)
	selected = _hold(context, local, false)
	context.ball.global_position += Vector3(0.1, 0, 0)
	_check(
		not _boundary.apply_event(context.resolver, selected),
		"moved current ball invalidates an issued trap"
	)
	context.ball.free()


func _native_probe(label: String, local: Vector3, velocity: Vector3, settle: bool) -> void:
	var context: Dictionary = _context(local)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if settle:
		# Native damping isolates genuine rest inside the cavity; this is not a calibrated game
		# trajectory.
		context.ball.linear_damp = 4.0
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = _model.to_global(local)
	launch.velocity = velocity
	context.ball.launch(launch)
	var start: Vector3 = context.ball.global_position
	var previous: Vector3 = start
	for frame in range(100 if settle else 30):
		await get_tree().physics_frame
		context.resolver.advance_time(1.0 / 60.0)
		_boundary.observe(context.resolver, previous, context.ball.global_position)
		previous = context.ball.global_position
		if context.resolver.state.dead:
			break
	var events: Array = context.resolver.state.stadium_contacts
	_check(
		start.distance_to(context.ball.global_position) > 0.05,
		"registered native ball moves: " + label
	)
	if label == "body-ricochet":
		_check(
			(
				not context.resolver.state.dead
				and not events.is_empty()
				and events[0].role == "LIVE_RICOCHET"
				and context.ball.linear_velocity.x < 0
			),
			"native closed body rebounds without terminal rule"
		)
	elif settle:
		_check(
			(
				context.resolver.state.dead
				and not events.is_empty()
				and events[-1].role == StadiumJunkCarRuntime.TRAP_ROLE
			),
			"native full-sphere entry and sustained contained rest produce trapped event"
		)
	else:
		_check(
			(
				not context.resolver.state.dead
				and events.is_empty()
				and _model.to_local(context.ball.global_position).x > 0.8
			),
			"native fast underbody crossing exits alive without a contact or trap"
		)
	if settle and not context.resolver.state.dead:
		print(
			(
				"JUNK_CAR_NATIVE_DIAGNOSTIC "
				+ str(
					{
						"position": _model.to_local(context.ball.global_position),
						"velocity": context.ball.linear_velocity,
						"flight": _boundary._flights.get(context.resolver.get_instance_id(), {})
					}
				)
			)
		)
	context.ball.free()
	await get_tree().physics_frame


func _seals() -> void:
	var carrier: Node3D = _model.get_node("UnderbodyTrap")
	carrier.set_meta("height", 1.4)
	_check(not _property.props_intact(), "expanded trap metadata fails exact authored seal")
	carrier.set_meta("height", StadiumJunkCarModels.TRAP_HEIGHT)
	_check(_property.props_intact(), "restored canonical trap seal remains exact")
	var body: StaticBody3D = _model.get_node("Collision/" + StadiumJunkCarModels.SURFACE)
	body.set_meta("owned_copy", "foreign")
	_check(
		StadiumJunkCarRuntime.native_event(_property, body, _model.global_position).is_empty(),
		"foreign copy cannot emit live contact"
	)
	body.set_meta("owned_copy", StadiumStock.SALVAGE_COPY)
	var mesh: MeshInstance3D = _model.find_children("*", "MeshInstance3D", true, false)[0]
	mesh.position.y += 0.01
	_check(not _property.props_intact(), "moving visible bodywork retires exact trap authority")
	mesh.position.y -= 0.01
	var shape: CollisionShape3D = body.get_child(0)
	shape.shape.margin += 0.01
	_check(
		not _property.props_intact(),
		"changed actual convex collision resource retires the property"
	)

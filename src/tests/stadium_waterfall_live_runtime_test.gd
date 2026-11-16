extends "res://src/tests/stadium_waterfall_live_runtime_test_fixture_base.gd"
func _native_ricochet() -> void:
	var context: Dictionary = _context(Vector3(0, 0.4, -2.2))
	context.ball.linear_velocity = Vector3(0, 0, 4)
	var previous: Vector3 = context.ball.global_position
	var ricochet: bool = false
	for frame in range(30):
		await get_tree().physics_frame
		var selected: Dictionary = _sample(context, previous, context.ball.global_position)
		ricochet = ricochet or selected.get("kind") == "waterfall_solid"
		previous = context.ball.global_position
	_check(
		ricochet and context.ball.linear_velocity.z < 0 and not context.resolver.state.dead,
		"actual native exterior stone rebound remains live without unreachable-ball award"
	)
	context.ball.free()


func _ordinary_cadence() -> void:
	_native_drops_count += 1
	var context: Dictionary = _context(Vector3(0, 1.1, -1.075), false, true)
	_boundary.bind_ball(context.ball, context.resolver)
	context["previous"] = context.ball.global_position
	_ordinary = context
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = context.ball.global_position
	launch.velocity = Vector3.ZERO
	context.ball.launch(launch)
	var rebound: bool = false
	var floor_seen: bool = false
	for frame in range(240):
		await get_tree().physics_frame
		floor_seen = floor_seen or _model.to_local(context.ball.global_position).y < 0.25
		rebound = rebound or (floor_seen and context.ball.linear_velocity.y > 0.1)
		if context.resolver.state.dead:
			break
	_ordinary = {}
	var records: Array = context.resolver.state.stadium_contacts
	_check(
		(
			context.resolver.state.dead
			and _outcomes.size() == 1
			and _outcomes[0].reason == &"waterfall_basin_minimum_single"
			and rebound
		),
		"ordinary dual native-router/observer cadence finishes witnessed drop through sleeping support"
	)
	if not records.is_empty() and records[-1].has("waterfall_proof"):
		var proof: Dictionary = Runtime.proof_from_data(records[-1].waterfall_proof)
		_check(
			not proof.is_empty() and Witness.replay(proof),
			"ordinary cadence emits one monotone sample per frame and replayable native evidence"
		)
	else:
		_check(
			false,
			"ordinary cadence retains bound replayable proof rather than generic settled reason"
		)
	_validate_record(context, BallPlayOutcome.Result.SINGLE, "ordinary-cadence")
	context.ball.free()


func _seal_controls() -> void:
	for mode: String in [
		"valid",
		"detached",
		"carrier",
		"mesh",
		"material",
		"shape",
		"shape-owner",
		"transform",
		"copy",
		"decorative"
	]:
		var model: Node3D = Geometry.create()
		model.set_meta("owned_copy", COPY)
		model.set_meta("site", StadiumWaterfallLiveSites.SITE)
		if mode != "detached":
			add_child(model)
		var retire: Callable = func() -> void: pass
		var seal: Dictionary = Runtime.capture_trap(model, retire)
		_check(
			not seal.is_empty() and Runtime.trap_intact(model, seal),
			"canonical model sealed " + mode
		)
		match mode:
			"carrier":
				model.get_node("BasinTrap").set_meta("maximum_reach", 0.1)
			"mesh":
				model.get_node("Visual/RockLower").mesh.size.y += 0.01
			"material":
				model.get_node("Visual/Pool").material_override.no_depth_test = true
			"shape":
				model.get_node("Collision/WATERFALL_STONE/BasinFloor").shape.size.y += 0.01
			"shape-owner":
				model.get_node("Collision/WATERFALL_STONE").shape_owner_set_transform(
					0, Transform3D.IDENTITY
				)
			"transform":
				model.position.x += 0.1
			"copy":
				model.set_meta("owned_copy", "replacement-copy")
			"decorative":
				model.set_meta("site", "LANDMARK-A")
		_check(
			Runtime.trap_intact(model, seal) == (mode in ["valid", "detached"]),
			"exact cached model seal rejects " + mode
		)
		model.free()


func _ready() -> void:
	_codec_controls()
	_seal_controls()
	if "--waterfall-codec-only" in OS.get_cmdline_user_args():
		_finish()
		return
	if not _build():
		_finish()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_geometry()
	await _admission_controls()
	await _native_drop(false, BallPlayState.ResultFloor.NONE, "minimum-single")
	await _native_drop(false, BallPlayState.ResultFloor.TRIPLE, "preserved-triple")
	await _native_drop(false, BallPlayState.ResultFloor.NONE, "observer-earned-double", true, true)
	await _native_drop(true, BallPlayState.ResultFloor.HOME_RUN, "foul-first")
	await _ordinary_cadence()
	await _issued_controls()
	await _native_ricochet()
	await TestAudioDrain.finish(get_tree())
	_finish()


func _physics_process(delta: float) -> void:
	if _ordinary.is_empty() or _ordinary.resolver.state.dead:
		return
	var current: Vector3 = _ordinary.ball.global_position
	# Match the lab order exactly: native contact router remains enabled;
	# ordinary observer executes before elapsed time advances. This observer also
	# continues when the rigid body sleeps and _integrate_forces is no longer called.
	_ordinary.resolver.observe_segment(_ordinary.previous, current)
	_ordinary.previous = current
	if not _ordinary.resolver.state.dead:
		_ordinary.resolver.advance_time(delta)

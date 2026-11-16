extends Node3D
## Manual interface/cap negatives only. These calls are not engine chronology evidence.

const OBSERVER: Script = preload("res://src/tests/helpers/pool_controller_shadow_lab.gd")
var _checks: int = 0
var _failures: int = 0
var _source: String
var _mutation_label: String
var _mutating_launch: BattedBallLaunch


func _ready() -> void:
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	_numeric_cases()
	await _ground_cases()
	for label: String in [
		"sealed",
		"oriented",
		"negative_identity",
		"wrong_owner",
		"return_without_entry",
		"wrong_segment",
		"reentrant",
		"duplicate_pass",
		"generation",
		"router",
		"disconnect",
		"foul_mutation",
		"scaled_parent",
		"property_route",
		"actor_scale",
		"history_mutation",
		"history_before_sample",
		"ready_twice",
		"launch_twice",
		"exit",
		"foreign_router_detach",
		"signal_detach",
		"primary_replaced",
		"freed_primary",
		"freed_pitcher",
		"resolver_replaced",
		"state_script_swap",
		"launch_state_script",
		"primary_route",
		"resolver_observer",
		"duplicate_early",
		"missing_pitcher",
		"twice_pitcher",
		"wrong_history_return",
		"seal_primary_flags",
		"seal_primary_position",
		"launch_position",
		"launch_orientation",
		"launch_freeze",
		"launch_started_flag",
		"launch_callbacks",
		"launch_request",
		"launch_dead",
		"launch_touched",
		"launch_floor",
		"launch_elapsed",
		"launch_anchor",
		"launch_queued_free"
	]:
		await _lifecycle_case(label)
	_check(StadiumPoolPartyAssetIntegrity.source_sha256() == _source, "runtime source unchanged")
	print(
		(
			"POOL_CONTROLLER_UNIT checks=%d failures=%d active_awards=false physics_qualified=false"
			% [_checks, _failures]
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _numeric_cases() -> void:
	var inputs: Dictionary = {
		"pitcher_attempted": false,
		"defender_touched": false,
		"cooldown_seconds": 0.0,
		"elapsed_seconds": 1.0,
		"delta": 1.0 / 60.0,
		"move_speed_mps": StadiumPoolPitcherCapV1.normal_move_speed_mps(),
		"velocity": Vector3(4, -1, 5),
		"velocity_provenance": "controller_entry_observed"
	}
	var mound: Vector3 = PitchBatLab.MOUND_ORIGIN
	var primary: Vector3 = Vector3(-5.5, 0, 19.5)
	var result: Dictionary = StadiumPoolPitcherCapV1.evaluate(
		Vector3(12, 1, 18), Vector3(12.2, 1, 18), mound, primary, inputs
	)
	_check(
		result.valid and result.supported and result.excluded,
		"moving distant endpoint box excluded"
	)
	_check(not result.early_award_authority and result.shadow_only, "cap has no early authority")
	var far: Dictionary = StadiumPoolPitcherCapV1.evaluate(
		Vector3(12, 1, 18), Vector3(12.2, 1, 18), Vector3(24, 0, 13.716), primary, inputs
	)
	_check(
		far.displacement_upper_m > result.displacement_upper_m and not far.supported,
		"far actual pitcher expands cap, never assumed inside target circle"
	)
	for delta: float in [0.0, 1.0 / 60.0, 1.0, 1000000.0, 1.0e308]:
		inputs.delta = delta
		var with_delta: Dictionary = StadiumPoolPitcherCapV1.evaluate(
			Vector3(12, 1, 18), Vector3(12.2, 1, 18), mound, primary, inputs
		)
		_check(
			with_delta.displacement_upper_m == result.displacement_upper_m,
			"all finite delta cap constant"
		)
	for pitcher: Vector3 in [mound, Vector3(24, 0, 13.716), Vector3(-64, 0, -64)]:
		for target: Vector3 in [mound, mound + Vector3(4.9, 0, 0), mound + Vector3(0, 0, 4.9)]:
			for offset: Vector3 in [
				Vector3.ZERO, Vector3(0.0004, 0, 0), Vector3(-0.0004, 0, 0), Vector3(1.56, 0, 0)
			]:
				var fielder: Vector3 = target + offset
				var cap: Dictionary = StadiumPoolPitcherCapV1.evaluate(
					Vector3(12, 1, 18), Vector3(12.2, 1, 18), pitcher, fielder, inputs
				)
				var step: Vector3 = DefenderSpacing.step_around_mound(
					pitcher, target, fielder, 1.0e30
				)
				_check(
					cap.valid and step.distance_to(pitcher) <= cap.displacement_upper_m,
					"actual separation/fallback/rotation movement obeys outward cap"
				)
	inputs.velocity_provenance = "router_cached_node_velocity"
	_check(
		(
			(
				StadiumPoolPitcherCapV1
				. evaluate(Vector3(12, 1, 18), Vector3(12, 1, 18), mound, primary, inputs)
				. reason
			)
			== &"POST_AERO_DOMAIN_UNPROVEN"
		),
		"early moving sample unsupported"
	)
	inputs.velocity_provenance = "controller_entry_observed"
	_check(
		not (
			StadiumPoolPitcherCapV1
			. evaluate(Vector3(65, 1, 18), Vector3(12, 1, 18), mound, primary, inputs)
			. valid
		),
		"coordinate domain rejection"
	)
	inputs.velocity = Vector3(4097, 0, 0)
	_check(
		not (
			StadiumPoolPitcherCapV1
			. evaluate(Vector3(12, 1, 18), Vector3(12, 1, 18), mound, primary, inputs)
			. valid
		),
		"velocity domain rejection"
	)
	inputs.velocity = Vector3(4, -1, 5)
	_check(
		not StadiumPoolPitcherCapV1.evaluate(mound, mound, mound, primary, inputs).supported,
		"valid near catch remains unsupported, never suppressed"
	)
	inputs.pitcher_attempted = true
	var closed: Dictionary = StadiumPoolPitcherCapV1.evaluate(mound, mound, mound, primary, inputs)
	_check(closed.excluded and not closed.has_displacement_bound, "actual closed attempt gate")


func _ground_cases() -> void:
	var lab: PitchBatLab = OBSERVER.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	var ground: StaticBody3D = lab.find_child("Ground", true, false) as StaticBody3D
	_check(StadiumPoolLabGroundProfile.matches(ground), "genuine Ground shape plus mesh accepted")
	_check(ground.get_child_count() == 2, "original Ground retains two children")
	var shape: CollisionShape3D = ground.get_child(0) as CollisionShape3D
	var old_size: Vector3 = shape.shape.size
	shape.shape.size += Vector3(0.01, 0, 0)
	_check(not StadiumPoolLabGroundProfile.matches(ground), "altered ground shape rejected")
	shape.shape.size = old_size
	var mesh: MeshInstance3D = ground.get_child(1) as MeshInstance3D
	var old_color: Color = mesh.material_override.albedo_color
	mesh.material_override.albedo_color = Color.RED
	_check(not StadiumPoolLabGroundProfile.matches(ground), "altered ground material rejected")
	mesh.material_override.albedo_color = old_color
	ground.position.x = 0.001
	_check(not StadiumPoolLabGroundProfile.matches(ground), "translated ground rejected")
	ground.position.x = 0
	var extra: Node3D = Node3D.new()
	ground.add_child(extra)
	_check(not StadiumPoolLabGroundProfile.matches(ground), "extra ground child rejected")
	ground.remove_child(extra)
	extra.free()
	_check(StadiumPoolLabGroundProfile.matches(ground), "restored exact ground accepted")
	shape.name = &"DeliberatelyRenamed"
	_check(not StadiumPoolLabGroundProfile.matches(ground), "authored ground leaf rename rejected")
	lab.queue_free()
	await get_tree().process_frame


func _lifecycle_case(label: String) -> void:
	var lab: PitchBatLab = OBSERVER.new()
	add_child(lab)
	lab._match_mode = false
	lab.set_process(false)
	lab.set_physics_process(false)
	_mutation_label = label
	if label.begins_with("launch_") and label not in ["launch_twice", "launch_state_script"]:
		lab.child_entered_tree.connect(_mutation_birth)
	var adapter: StadiumPoolControllerShadow = StadiumPoolControllerShadow.new()
	_check(adapter.prepare(lab, null, "NO_POOL", _source), label + " symmetric preflight")
	_check(adapter.install(lab, null, "NO_POOL", _source), label + " install")
	if label == "launch_state_script":
		# Connect after owner-ready so mutation occurs after its launch signal handlers.
		lab.child_entered_tree.connect(_mutation_birth)
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(12, 2, 18)
	launch.velocity = Vector3(0, 1, 3)
	if label == "oriented":
		launch.orientation = Quaternion(Vector3.UP, 0.2)
	elif label == "negative_identity":
		launch.orientation = Quaternion(0, 0, 0, -1)
	_mutating_launch = launch
	lab._start_ball_in_play(launch)
	var body: BattedBallBody = lab._batted_ball
	if label.begins_with("launch_") and label != "launch_twice":
		_check(
			not adapter.valid() and not adapter.errors.is_empty(),
			label + " genuine launch-listener mutation rejected"
		)
		if label == "launch_state_script":
			_check(
				"LAUNCH_STATE_SCRIPT_MUTATED" in adapter.errors,
				"state script checked before field access"
			)
		adapter.detach()
		lab.queue_free()
		await get_tree().process_frame
		return
	_check(
		adapter.phase == &"LIVE_INITIALIZED" and adapter.valid(), label + " ordinary launch sealed"
	)
	_check(body.linear_velocity == launch.velocity, label + " requested velocity retained")
	var signals: Array[Dictionary] = []
	for row: Dictionary in adapter.records:
		if row.event == "launch.signal":
			signals.append(row)
	_check(signals.size() == 1, label + " exactly one owned launch signal")
	if signals.size() == 1:
		_check(
			not signals[0].history_initialization_complete, label + " signal cannot seal history"
		)
	var batch: Array[Dictionary] = []
	if label in ["sealed", "oriented", "negative_identity"]:
		body.physics_contact_router.call(body, batch)
		lab._physics_process(1.0 / 60.0)
		_check(
			adapter.errors.is_empty(),
			"manual one-pass interface sequence accepts exact ordinary calls"
		)
		var exact_ticket_seen: bool = false
		for row: Dictionary in adapter.records:
			if row.event == "controller.numeric_shadow" and row.early_ticket_exact:
				exact_ticket_seen = true
				break
		_check(exact_ticket_seen, "exact history ticket consumed")
	elif label == "wrong_owner":
		adapter.controller_enter(null, 1.0 / 60.0)
	elif label == "return_without_entry":
		adapter.controller_return(lab)
	elif label == "wrong_segment":
		adapter.controller_enter(lab, 1.0 / 60.0)
		adapter.pitcher_enter(lab, Vector3.ZERO, body.global_position)
	elif label == "reentrant":
		adapter.controller_enter(lab, 1.0 / 60.0)
		adapter.controller_enter(lab, 1.0 / 60.0)
	elif label == "duplicate_pass":
		lab._physics_process(1.0 / 60.0)
		lab._physics_process(1.0 / 60.0)
	elif label == "generation":
		adapter.guard.generation += 1
	elif label == "router":
		body.physics_contact_router = _foreign_router
	elif label == "disconnect":
		body.launch_started.disconnect(adapter._launch_signal)
	elif label == "foul_mutation":
		lab._ball_play_resolver.state.is_foul_play = true
	elif label == "scaled_parent":
		lab.scale = Vector3(1.01, 1, 1)
	elif label == "property_route":
		var unsupported_route: Dictionary = {"private_test_unsupported_route": true}
		lab.set_meta(&"stadium_property", unsupported_route)
		_check(lab.has_meta(&"stadium_property"), "property route fixture retains its key")
		_check(
			lab.get_meta(&"stadium_property", {}) == unsupported_route,
			"property route fixture retains its exact value"
		)
	elif label == "actor_scale":
		lab._pitcher_marker.scale = Vector3(1.01, 1, 1)
	elif label == "history_mutation":
		body.physics_contact_router.call(body, batch)
		lab._previous_batted_position += Vector3(0.01, 0, 0)
		lab._physics_process(1.0 / 60.0)
		var closure_unproven_seen: bool = false
		for row: Dictionary in adapter.unsupported:
			if row.reason == "EARLY_TO_CONTROLLER_CLOSURE_UNPROVEN":
				closure_unproven_seen = true
				break
		_check(closure_unproven_seen, "changed history stays unsupported")
	elif label == "history_before_sample":
		lab._previous_batted_position += Vector3(0.01, 0, 0)
		body.physics_contact_router.call(body, batch)
	elif label == "ready_twice":
		adapter._ready_body(body)
	elif label == "launch_twice":
		body.launch(launch)
	elif label == "exit":
		lab.remove_child(body)
	elif label == "foreign_router_detach":
		body.physics_contact_router = _foreign_router
		adapter.detach()
		_check(body.physics_contact_router == _foreign_router, "detach preserves foreign router")
	elif label == "signal_detach":
		body.launch_started.connect(_foreign_launch)
		adapter.detach()
		_check(
			body.launch_started.is_connected(_foreign_launch), "detach preserves foreign connection"
		)
	elif label == "primary_replaced":
		lab._primary_fielder = null
	elif label == "freed_primary":
		lab._primary_fielder.free()
	elif label == "freed_pitcher":
		lab._pitcher_marker.free()
	elif label == "resolver_replaced":
		var replacement: BallPlayResolver = BallPlayResolver.new()
		replacement.state = lab._ball_play_resolver.state
		lab._ball_play_resolver = replacement
	elif label == "state_script_swap":
		lab._ball_play_resolver.state.set_script(null)
	elif label == "primary_route":
		lab._primary_fielder.stadium_boundary_clip = _foreign_route
	elif label == "resolver_observer":
		lab._ball_play_resolver.segment_observer = _foreign_router
	elif label == "duplicate_early":
		body.physics_contact_router.call(body, batch)
		body.physics_contact_router.call(body, batch)
	elif label == "missing_pitcher":
		adapter.controller_enter(lab, 1.0 / 60.0)
		adapter.controller_return(lab)
	elif label == "twice_pitcher":
		adapter.controller_enter(lab, 1.0 / 60.0)
		adapter.pitcher_enter(lab, lab._previous_batted_position, body.global_position)
		adapter.pitcher_return(lab)
		adapter.pitcher_enter(lab, lab._previous_batted_position, body.global_position)
	elif label == "wrong_history_return":
		adapter.controller_enter(lab, 1.0 / 60.0)
		adapter.pitcher_enter(lab, lab._previous_batted_position, body.global_position)
		adapter.pitcher_return(lab)
		lab._previous_batted_position = Vector3.ZERO
		adapter.controller_return(lab)
	elif label in ["seal_primary_flags", "seal_primary_position"]:
		# Explicit synthetic interface state: exercise final sealing predicates.
		adapter.phase = &"LAUNCHED_PENDING_HISTORY"
		adapter._launching = true
		if label == "seal_primary_flags":
			lab._primary_fielder.active = false
		else:
			lab._primary_fielder.global_position += Vector3(0.01, 0, 0)
		adapter.launch_return(lab, launch)
	if label not in ["sealed", "oriented", "negative_identity", "history_mutation"]:
		_check(not adapter.valid(), label + " binding or phase invalidated")
	adapter.detach()
	_check(
		not adapter.valid() and adapter.phase == &"DETACHED", label + " revoked before disconnect"
	)
	if body.get_parent() == null:
		body.free()
	lab.queue_free()
	await get_tree().process_frame


func _foreign_router(_body: BattedBallBody, _batch: Array[Dictionary]) -> void:
	pass


func _foreign_launch(_position: Vector3) -> void:
	pass


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _mutation_birth(child: Node) -> void:
	if child is BattedBallBody:
		child.ready.connect(_mutation_ready.bind(child, _mutation_label), CONNECT_ONE_SHOT)


func _mutation_ready(body: BattedBallBody, label: String) -> void:
	body.launch_started.connect(_mutation_launch.bind(body, label))


func _mutation_launch(_position: Vector3, body: BattedBallBody, label: String) -> void:
	if label == "launch_position":
		body.global_position += Vector3(0.01, 0, 0)
	elif label == "launch_orientation":
		body.quaternion = Quaternion(Vector3.UP, 0.2)
	elif label == "launch_freeze":
		body.freeze = true
	elif label == "launch_started_flag":
		body._started = false
	elif label == "launch_callbacks":
		body.launch_started.connect(_foreign_launch)
	elif label == "launch_request":
		_mutating_launch.position += Vector3(0.01, 0, 0)
	elif label == "launch_state_script":
		(body.get_parent() as PitchBatLab)._ball_play_resolver.state.set_script(null)
	elif label == "launch_dead":
		(body.get_parent() as PitchBatLab)._ball_play_resolver.state.dead = true
	elif label == "launch_touched":
		(body.get_parent() as PitchBatLab)._ball_play_resolver.state.defender_touched = true
	elif label == "launch_floor":
		(body.get_parent() as PitchBatLab)._ball_play_resolver.state.result_floor = (
			BallPlayState.ResultFloor.SINGLE
		)
	elif label == "launch_elapsed":
		(body.get_parent() as PitchBatLab)._ball_play_resolver.state.elapsed_seconds = 1.0
	elif label == "launch_queued_free":
		body.queue_free()
	elif label == "launch_anchor":
		(body.get_parent() as PitchBatLab)._primary_fielder.anchor_position += Vector3(1, 0, 0)


func _foreign_route(_previous: Vector3, current: Vector3) -> Vector3:
	return current

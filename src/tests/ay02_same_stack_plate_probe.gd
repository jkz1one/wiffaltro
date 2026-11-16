extends "res://src/tests/ay02_public_issued_test.gd"
const Proof = preload("res://src/tests/stadium_npc_yard_two_installed_proof.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run_probe.call_deferred()


func _run_probe() -> void:
	var prepared: SeasonState = FIXTURE.season()
	var season: SeasonState = (
		SeasonSave._decode(
			JSON.parse_string(JSON.stringify(SeasonSave.snapshot(prepared), "", true, true))
		)
		if prepared != null
		else null
	)
	_check(season != null, "actual fixture season cold reload")
	var rows: Array = []
	if season != null:
		var saved: Dictionary = SeasonSave.snapshot(season)
		for mode: String in ["control", "detach", "free"]:
			var row: Dictionary = await _plate_case(season, mode)
			rows.append(row)
			_check(
				row.get("immediate_silent", false) and row.get("deferred_silent", false),
				mode + ": no extra gameplay outcome or history"
			)
			if mode == "control":
				_check(
					row.immediate_tween.running and row.deferred_tween.running,
					"control: ordinary follow-through remains"
				)
				_check(
					row.immediate_visible and row.deferred_visible and not row.deferred_interrupted,
					"control: remains visible and not quarantined"
				)
			else:
				_check(
					not row.immediate_tween.exists and not row.deferred_tween.exists,
					mode + ": no same-stack fallback tween allocated"
				)
				_check(
					not row.immediate_visible and not row.deferred_visible,
					mode + ": interrupted actor stays hidden"
				)
				_check(
					row.immediate_disabled and row.deferred_disabled and row.deferred_interrupted,
					mode + ": stays disabled and quarantined"
				)
				_check(
					(
						row.observations.size() == 1
						and row.observations[0].get("route_swallowed", false)
					),
					mode + ": exact interrupted continuation swallowed"
				)
		_check(
			ClubCareer.same(saved, SeasonSave.snapshot(season)), "unchanged season save and history"
		)
	await TestAudioDrain.finish(get_tree())
	print(
		"SAME_STACK_PLATE_REPORT ",
		JSON.stringify({"rows": rows, "prerequisite_failures": _failures, "diagnostic_only": false})
	)
	get_tree().quit(0 if _failures == 0 and rows.size() == 3 else 1)


func _tween_state(actor: PitchFlightActor) -> Dictionary:
	var tween: Tween = actor._plate_follow_tween
	return {
		"exists": tween != null,
		"valid": tween != null and tween.is_valid(),
		"running": tween != null and tween.is_valid() and tween.is_running()
	}


func _plate_case(season: SeasonState, mode: String) -> Dictionary:
	var lab: PitchBatLab = _lab(season)
	var row: Dictionary = {"mode": mode}
	if lab == null:
		row.blocker = "public fixture did not install"
		return row
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var actor: PitchFlightActor = lab._pitch_actor
	actor.set_physics_process(false)
	var histories: Array = [
		property.provenance, property.boundary.contacts, property.receiver.contacts
	]
	var outcomes: Array = []
	var outcome_hook: Callable = func(value: BallPlayOutcome) -> void:
		outcomes.append([value.result, value.reason])
	lab._ball_play_resolver.play_resolved.connect(outcome_hook)
	var observations: Array = []
	var plate_hook: Callable = func(point: Vector3, speed: float, seconds: float) -> void:
		var entry: Dictionary = {
			"point": point,
			"speed": speed,
			"seconds": seconds,
			"score_after_legitimate_handler": _score(lab),
			"before_remove_tween": _tween_state(actor)
		}
		if mode == "detach":
			property.get_parent().remove_child(property)
		elif mode == "free":
			property.free()
		entry.after_removal_game = Proof.game_state(lab).hex_encode()
		entry.after_removal_history = var_to_bytes(histories).hex_encode()
		entry.after_removal_outcomes = var_to_bytes(outcomes).hex_encode()
		entry.after_removal_tween = _tween_state(actor)
		entry.actor_visible = actor.visible
		entry.interrupted = lab.has_meta("stadium_npc_runtime_interrupted")
		entry.process_disabled = lab.process_mode == Node.PROCESS_MODE_DISABLED
		var route: Callable = actor.receiver_router
		entry.route_valid = route.is_valid()
		entry.route_method = String(route.get_method()) if route.is_valid() else ""
		entry.route_probe_called = false
		if route.is_valid() and route.get_method() == &"_interrupted_route":
			entry.route_probe_called = true
			entry.route_swallowed = route.call(actor, point, actor.state.velocity) == true
		observations.append(entry)
	actor.plate_crossed.connect(plate_hook)
	var connections: Array = actor.plate_crossed.get_connections()
	row.handler_order = (
		connections.size() == 2
		and connections[0].callable == lab._on_plate_crossed
		and connections[1].callable == plate_hook
	)
	row.prelaunch_admitted = property.callback_intact() and not property.hot_eligible()
	_check(
		row.handler_order and row.prelaunch_admitted,
		mode + ": appended observer follows legitimate handler and strict prerequisite accepts"
	)
	lab._throw_pitch()
	row.ordinary_launch = (
		actor.running
		and actor.state != null
		and property._play_kind == &"pitch"
		and property._play_pitch == actor.state
		and property.callback_intact()
	)
	_check(row.ordinary_launch, mode + ": ordinary _throw_pitch issues exact live actor")
	if row.ordinary_launch:
		for frame in range(240):
			actor._physics_process(1.0 / 60.0)
			if not observations.is_empty():
				break
			if not actor.running:
				break
			await get_tree().physics_frame
	row.crossings = observations.size()
	_check(row.crossings == 1, mode + ": one actual physical plate crossing")
	row.observations = observations
	row.immediate_tween = _tween_state(actor)
	row.immediate_visible = actor.visible
	row.immediate_disabled = lab.process_mode == Node.PROCESS_MODE_DISABLED
	if not observations.is_empty():
		var observed: Dictionary = observations[0]
		row.immediate_silent = (
			observed.after_removal_game == Proof.game_state(lab).hex_encode()
			and observed.after_removal_history == var_to_bytes(histories).hex_encode()
			and observed.after_removal_outcomes == var_to_bytes(outcomes).hex_encode()
		)
	await get_tree().process_frame
	row.deferred_tween = _tween_state(actor)
	row.deferred_visible = actor.visible
	row.deferred_disabled = lab.process_mode == Node.PROCESS_MODE_DISABLED
	row.deferred_interrupted = lab.has_meta("stadium_npc_runtime_interrupted")
	if not observations.is_empty():
		var observed: Dictionary = observations[0]
		row.deferred_silent = (
			observed.after_removal_game == Proof.game_state(lab).hex_encode()
			and observed.after_removal_history == var_to_bytes(histories).hex_encode()
			and observed.after_removal_outcomes == var_to_bytes(outcomes).hex_encode()
		)
	print("SAME_STACK_PLATE_ROW ", JSON.stringify(row))
	if mode == "detach" and is_instance_valid(property):
		property.free()
	lab.free()
	await get_tree().process_frame
	return row

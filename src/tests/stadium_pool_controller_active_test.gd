extends Node3D
## Manual semantic/decline controls are separate from fresh ordinary physics cases.
# gdlint: disable=max-returns,max-file-lines


class SchedulingProbe:
	extends RefCounted
	var thread_id: int = -1
	var completed: bool = false

	func record() -> void:
		thread_id = OS.get_thread_caller_id()
		completed = true


var _checks: int = 0
var _failures: int = 0
var _source: String
var _outcomes: int = 0
var _last_outcome: BallPlayOutcome
var _mode: String = "unit"

# V20 paired history is a late physics state machine; no gameplay await continuations.
var _pair_arm: String = ""
var _pair_path: String = ""
var _pair_execution: String = ""
var _pair_nonce: String = ""
var _pair_phase: String = ""
var _pair_wait: int = 2
var _pair_lab: PitchBatLab
var _pair_model: Node3D
var _pair_adapter: StadiumPoolControllerActive
var _pair_receipt: StadiumPoolActiveReceipt
var _pair_launches: Array = []
var _pair_ordinal: int = 0
var _pair_ids: Array = []
var _pair_bases: Array = []
var _pair_commits: int = 0
var _pair_process: Array = []
var _pair_field: PackedByteArray
var _pair_start_checks: int = 0
var _pair_start_failures: int = 0

# V24 unit-only native clean-catch state; existing six paired modes are unchanged.
var _defense_case: Dictionary = {}
var _bound_controls: StadiumPoolBoundControls


func _ready() -> void:
	if not _scheduling_epoch_valid():
		push_error("Pool active V22 scheduling configuration or startup dispatch probe failed")
		get_tree().quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool-active-case="):
			_mode = arg.trim_prefix("--pool-active-case=")
	if _mode == "scheduling":
		print("POOL_CONTROLLER_ACTIVE_V22_SCHEDULING_OK")
		get_tree().quit(0)
		return
	PitchBatLabSettings.path = "user://pool-active-v19-unwritten.cfg"
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	seed(704716)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool-active-arm="):
			_pair_start()
			return
	if _mode == "unit":
		await _unit()
		await TestAudioDrain.finish(get_tree())
	elif _mode == "bound":
		_bound_controls = StadiumPoolBoundControls.new()
		await _bound_controls.run(self)
		_bound_controls = null
		await TestAudioDrain.finish(get_tree())
	elif _mode == "bound-diagnostic":
		_bound_controls = StadiumPoolBoundControls.new()
		await _bound_controls.run_diagnostic(self)
		_bound_controls = null
		await TestAudioDrain.finish(get_tree())
	else:
		await _physical()
	print(
		(
			"POOL_CONTROLLER_ACTIVE_V19 case=%s checks=%d failures=%d source=%s"
			% [_mode, _checks, _failures, _source]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


# One pre-gameplay dispatch sample; neither a pool-size nor future pump-growth guarantee.
func _scheduling_epoch_valid() -> bool:
	var settings: Dictionary = {
		"threading/worker_pool/max_threads": 1,
		"physics/2d/run_on_separate_thread": false,
		"physics/3d/run_on_separate_thread": false,
		"rendering/driver/threads/thread_model": 1,
	}
	for setting: String in settings:
		if not ProjectSettings.has_setting(setting):
			return false
		var actual: Variant = ProjectSettings.get_setting_with_override(setting)
		if typeof(actual) != typeof(settings[setting]) or actual != settings[setting]:
			return false
	var caller: int = OS.get_thread_caller_id()
	if caller != OS.get_main_thread_id():
		return false
	var probe: SchedulingProbe = SchedulingProbe.new()
	var task: int = WorkerThreadPool.add_task(probe.record, true, "pool-active-v22-startup")
	if task < 0:
		return false
	var wait_error: Error = WorkerThreadPool.wait_for_task_completion(task)
	return wait_error == OK and probe.completed and probe.thread_id != caller


func _unit() -> void:
	var lab: PitchBatLab = _lab()
	lab.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._ball_play_resolver.play_resolved.connect(_outcome)
	for foul: bool in [false, true]:
		for occupancy: int in range(8):
			for floor_value: int in [0, 1, 2]:
				lab._ball_play_resolver.start_play(lab._field_definition, foul)
				var state: BallPlayState = lab._ball_play_resolver.state
				state.result_floor = floor_value
				state.defender_touched = occupancy % 2 == 1
				_set_bases(lab._base_state, occupancy)
				var before: Array = _bases(lab._base_state)
				var count_before: int = _outcomes
				_check(
					lab._ball_play_resolver.resolve_pool_water(state, Vector3(12, 1, 18), foul),
					"semantic water entry accepted"
				)
				_check(_outcomes == count_before + 1 and state.dead, "ordinary outcome once")
				_check(not _last_outcome.caught, "water does not fabricate catch")
				var expected: int = (
					BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.DOUBLE
				)
				_check(_last_outcome.result == expected, "immutable foul / ordinary Double")
				var expected_bases: Array = (
					before
					if foul
					else [&"", StringName("batter.%d" % lab._throw_number), before[0]]
				)
				_check(
					_bases(lab._base_state) == expected_bases, "all eight ordinary base occupancies"
				)
				_check(state.result_floor == (floor_value if foul else 2), "monotone earned floor")
				_check(
					not lab._ball_play_resolver.resolve_pool_water(state, Vector3(12, 1, 18), foul),
					"duplicate terminal rejected"
				)
				_check(
					_outcomes == count_before + 1 and _bases(lab._base_state) == expected_bases,
					"no duplicate base advance"
				)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	resolver.start_play(lab._field_definition)
	var old: BallPlayState = resolver.state
	resolver.start_play(lab._field_definition)
	var current: BallPlayState = resolver.state
	var snapshot: PackedByteArray = var_to_bytes(StadiumPoolWaterGuard._state_parameters(current))
	_check(not resolver.resolve_pool_water(old, Vector3(12, 1, 18), false), "stale state declined")
	_check(not resolver.resolve_pool_water(current, Vector3.INF, false), "nonfinite declined")
	_check(
		not resolver.resolve_pool_water(current, Vector3(12, 1, 18), true), "foul mismatch declined"
	)
	_check(
		snapshot == var_to_bytes(StadiumPoolWaterGuard._state_parameters(current)), "declines no-op"
	)
	current.result_floor = BallPlayState.ResultFloor.HOME_RUN
	_check(
		not resolver.resolve_pool_water(current, Vector3(12, 1, 18), false),
		"higher result preserved"
	)
	_geometry_controls(lab._field_definition)
	_freeflight_geometry_controls()
	lab._ball_play_resolver.play_resolved.disconnect(_outcome)
	lab.queue_free()
	await _ticks(3)
	await _decline_controls()
	await _decline_controls(true)
	await _freeflight_latch_controls()
	await _retirement_controls()
	await _defense_history_controls()
	await _defense_catch_controls()
	await _primary_history_controls()


func _geometry_controls(field: FieldDefinition) -> void:
	var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
	_check(not adapter.enabled, "default disabled")
	var above: Vector3 = Vector3(12, 2.2, 18)
	var wet: Vector3 = Vector3(12, 1, 18)
	_check(
		StadiumPoolControllerActive.column_step(above, wet, Vector3(0, -4, 0), Vector3.ZERO),
		"vertical descent admitted"
	)
	for position: Vector3 in [
		Vector3(12.01, 1, 18),
		Vector3(12, 1, 18.01),
		Vector3(12, -0.1, 18),
		Vector3(12, 2.3, 18),
		Vector3.INF
	]:
		_check(
			not StadiumPoolControllerActive.column_step(
				above, position, Vector3(0, -4, 0), Vector3.ZERO
			),
			"reflection/rim/ground/nonfinite path rejected"
		)
	_check(
		not StadiumPoolControllerActive.column_step(above, wet, Vector3(0.01, -4, 0), Vector3.ZERO),
		"horizontal rejected"
	)
	_check(
		not StadiumPoolControllerActive.column_step(above, wet, Vector3(0, -4, 0), Vector3.UP),
		"spin rejected"
	)
	_check(
		StadiumPoolControllerActive.terminal_planes_excluded(field, above, wet),
		"bound pre-wall column"
	)
	var changed: FieldDefinition = field.duplicate()
	changed.back_wall_z_m = 18
	_check(
		not StadiumPoolControllerActive.terminal_planes_excluded(changed, above, wet),
		"segment-only wall/HR rejected"
	)
	changed.back_wall_z_m = field.back_wall_z_m
	changed.dead_ball_z_m = 18
	_check(
		not StadiumPoolControllerActive.terminal_planes_excluded(changed, above, wet),
		"out-of-play plane rejected"
	)


# Twenty-one finite geometry assertions. These are semantic probes, not batted trajectories.
func _freeflight_geometry_controls() -> void:
	var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
	_check(not adapter.freeflight_enabled, "freeflight separately default disabled")
	var radius: float = 0.0365
	for points: Array in [
		[Vector3(11.7, 1.25, 17.8), Vector3(12.3, 0.9, 18.2)],
		[Vector3(12.3, 1.25, 18.2), Vector3(11.7, 0.9, 17.8)],
		[Vector3(13.88, 1.2, 18), Vector3(13.88, 1.0, 18)]
	]:
		var entry: Dictionary = StadiumPoolControllerActive.FreeflightEntry.evaluate(
			points[0], points[1], radius
		)
		_check(entry.status == "ENTRY", "bounded oblique or near-edge entry")
		_check(
			(
				0.0 < entry.tangent_fraction
				and entry.tangent_fraction < entry.fraction
				and entry.fraction < 1.0
			),
			"normalized positive witness before endpoint"
		)
		_check(
			(
				entry.position != points[1]
				and (
					StadiumPoolInteriorV2
					. sample_local(
						StadiumPoolControllerActive.FreeflightEntry.to_local(entry.position), radius
					)
					. positive_overlap
				)
			),
			"actual authored positive witness differs from endpoint"
		)
	for points: Array in [
		[Vector3(13.94, 1.2, 18), Vector3(13.94, 1.0, 18)],
		[Vector3(14.02, 1.15, 18), Vector3(13.8, 1.0, 18)],
		[Vector3(14.2, 1.5, 18), Vector3(13.8, 1.0, 18)],
		[Vector3(10, 1.2, 18), Vector3(14, 1.0, 18)],
		[Vector3(12, 1.0, 18), Vector3(12, 0.9, 18)],
		[Vector3(12, 1.2, 18), Vector3(12, 1.08648, 18)],
		[Vector3(12, 1.2, 18), Vector3(12, 0, 18)],
		[Vector3(12, 6.0, 18), Vector3(12, 1.0, 18)]
	]:
		_check(
			(
				(
					StadiumPoolControllerActive
					. FreeflightEntry
					. evaluate(points[0], points[1], radius)
					. status
				)
				== "DECLINED"
			),
			"edge dry-to-dry false endpoint shallow ground or domain declined"
		)
	_check(
		StadiumPoolControllerActive.FreeflightEntry.path_clear(
			Vector3(9, 3, 16), Vector3(11, 4, 19), radius
		),
		"above-rim rising approach history admitted"
	)
	_check(
		StadiumPoolControllerActive.FreeflightEntry.path_clear(
			Vector3(11.8, 1.12, 18), Vector3(12.1, 1.6, 18.2), radius
		),
		"interior ascending history admitted"
	)

	_check(
		not StadiumPoolControllerActive.FreeflightEntry.path_clear(
			Vector3(14.2, 1.4, 17.9), Vector3(14.2, 1.4, 18.1), radius
		),
		"above-rim ladder history explicitly declined"
	)


func _decline_controls(freeflight: bool = false) -> void:
	for fault: String in [
		"positive",
		"reentrant",
		"disabled",
		"ground",
		"terminal",
		"contact",
		"capacity",
		"missing",
		"stale",
		"field",
		"listener",
		"pitcher",
		"rim",
		"foul",
		"floor"
	]:
		var lab: PitchBatLab = _lab()
		var model: Node3D = StadiumPoolWaterTestSupport.model(self, StadiumPoolContract.LIVE)
		var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
		_check(adapter.install(lab, model, StadiumPoolContract.LIVE, _source), "manual binding")
		adapter.enabled = fault != "disabled"
		adapter.freeflight_enabled = freeflight
		_launch(lab, false)
		# Explicit positioned semantic probe, never labeled an ordinary physics history.
		var ball: BattedBallBody = lab._batted_ball
		ball.global_position = Vector3(12, 1, 18)
		lab._previous_batted_position = Vector3(12, 1.2, 18)
		if freeflight:
			ball.global_position = Vector3(12.3, 0.9, 18.2)
			ball.linear_velocity = Vector3(2, -4, 1)
			ball.angular_velocity = Vector3(1, 2, 3)
			lab._previous_batted_position = Vector3(11.7, 1.25, 17.8)
		adapter._guard.route(ball, [])
		_check(adapter.decline.is_empty(), "manual precondition admitted before " + fault)
		match fault:
			"reentrant":
				adapter._busy = true
			"ground":
				lab._ball_play_resolver.state.has_grounded = true
			"terminal":
				lab._ball_play_resolver.state.dead = true
			"contact":
				adapter._guard.route(ball, [{"body": model.get_node("Collision").get_child(0)}])
			"capacity":
				var contacts: Array[Dictionary] = []
				for index: int in range(ball.max_contacts_reported):
					contacts.append({"body": null})
				adapter._guard.route(ball, contacts)
			"missing":
				adapter._early_frame = -1
			"stale":
				lab._ball_play_resolver.start_play(lab._field_definition)
			"field":
				lab._ball_play_resolver.field = lab._field_definition.duplicate()
			"listener":
				lab._ball_play_resolver.play_resolved.connect(_outcome)
			"pitcher":
				lab._pitcher_marker.global_position = Vector3(12, 0, 18)
			"rim":
				ball.global_position.x += 0.1
			"foul":
				lab._ball_play_resolver.state.is_foul_play = true
			"floor":
				lab._ball_play_resolver.state.result_floor = -1
		var before: Array = _gameplay(lab)
		if fault == "reentrant":
			_launch(lab, false)
			lab._cleanup_batted_ball()
			adapter.detach()
			_check(lab.pool_controller_active == adapter, "reentrant detach retains ownership")
			_check(lab._batted_ball == ball, "reentrant launch/cleanup leaves current ball")
		var committed: bool = adapter.try_resolve(
			lab, lab._previous_batted_position, ball.global_position
		)
		if fault == "positive":
			_check(committed and adapter.commits == 1, "manual positive full adapter path")
			_check(
				lab._ball_play_resolver.state.dead and ball.linear_velocity == Vector3.ZERO,
				"manual ordinary stop"
			)
			await get_tree().process_frame
			_check(ball.freeze, "ordinary deferred freeze")
			if freeflight:
				_check(
					(
						adapter.last_commit.entry_fraction > 0.0
						and adapter.last_commit.entry_fraction < 1.0
					),
					"freeflight actual normalized commit fraction"
				)
				_check(
					adapter.last_commit.position != before[1].origin,
					"freeflight witness differs from saved pre-call endpoint"
				)
				_check(
					ball.global_position == adapter.last_commit.position,
					"ordinary stopped body equals freeflight witness"
				)
		else:
			_check(not committed, "decline " + fault)
			_check(
				_gameplay(lab) == before and adapter.commits == 0, "no gameplay mutation " + fault
			)
		adapter._busy = false
		adapter.detach()
		lab.queue_free()
		model.queue_free()
		await _ticks(3)


# Explicit positioned semantic sequences, not ordinary physics trajectory claims.
# Sampling timestamps are reset only here so each source branch can be exercised
# synchronously; the dry control proves the final ENTRY branch is otherwise live.
func _freeflight_latch_controls() -> void:
	for mode: String in ["dry", "shallow", "uncertain"]:
		var lab: PitchBatLab = _lab()
		var model: Node3D = StadiumPoolWaterTestSupport.model(self, StadiumPoolContract.LIVE)
		var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
		_check(adapter.install(lab, model, StadiumPoolContract.LIVE, _source), "latch binding")
		adapter.enabled = true
		adapter.freeflight_enabled = true
		_launch(lab, false)
		var ball: BattedBallBody = lab._batted_ball
		var first_y: float = 1.3 if mode == "dry" else (1.08648 if mode == "shallow" else 1.086495)
		ball.global_position = Vector3(12, first_y, 18)
		ball.linear_velocity = Vector3(2, -4, 1)
		ball.angular_velocity = Vector3(1, 2, 3)
		var previous: Vector3 = Vector3(12, 1.4 if mode == "dry" else 1.2, 18)
		adapter._guard.route(ball, [])
		_check(adapter._owned() and adapter.decline.is_empty(), "latch precondition live")
		var before: Array = _gameplay(lab)
		_check(not adapter.try_resolve(lab, previous, ball.global_position), "first path no award")
		_check(_gameplay(lab) == before and adapter.commits == 0, "first decline is gameplay no-op")
		_check(adapter.decline.is_empty() == (mode == "dry"), "only dry flight remains eligible")
		var held_reason: String = adapter.decline
		previous = ball.global_position
		ball.global_position = Vector3(12, 1.4 if mode == "dry" else 1.2, 18)
		adapter._early_frame = -1
		adapter._guard.route(ball, [])
		before = _gameplay(lab)
		_check(not adapter.try_resolve(lab, previous, ball.global_position), "ascent no award")
		_check(
			_gameplay(lab) == before and adapter.decline == held_reason,
			"ascent preserves eligibility or permanent decline without mutation"
		)
		previous = Vector3(12, 1.2, 18)
		ball.global_position = Vector3(12, 1.0, 18)
		adapter._early_frame = -1
		adapter._guard.route(ball, [])
		_check(
			(
				(
					StadiumPoolControllerActive
					. FreeflightEntry
					. evaluate(previous, ball.global_position, adapter._guard._physical_radius)
					. status
				)
				== "ENTRY"
			),
			"later geometric entry is independently positive"
		)
		before = _gameplay(lab)
		var committed: bool = adapter.try_resolve(lab, previous, ball.global_position)
		_check(committed == (mode == "dry"), "later entry only after supported dry history")
		_check(
			(
				(lab._ball_play_resolver.state.dead and adapter.commits == 1)
				if mode == "dry"
				else (
					_gameplay(lab) == before
					and adapter.commits == 0
					and adapter.decline == held_reason
				)
			),
			"dry commits once; ambiguous wet history remains a permanent gameplay no-op"
		)
		adapter.detach()
		lab.queue_free()
		model.queue_free()
		await _ticks(3)


func _retirement_controls() -> void:
	var lab: PitchBatLab = _lab()
	var model: Node3D = StadiumPoolWaterTestSupport.model(self, StadiumPoolContract.LIVE)
	var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
	_check(adapter.install(lab, model, StadiumPoolContract.LIVE, _source), "retirement fixture")
	_launch(lab, false)
	var old: BattedBallBody = lab._batted_ball
	_launch(lab, false)
	_check(old.is_queued_for_deletion() and adapter._owned(), "owned queued prior ball excluded")
	old.process_physics_priority += 1
	_check(not adapter._owned(), "changed retired subtree rejected")
	old.process_physics_priority -= 1
	_check(adapter._owned(), "exact retirement restored only in manual negative fixture")
	var extra: Node = Node.new()
	lab.add_child(extra)
	extra.queue_free()
	_check(not adapter._owned(), "unowned queued node rejected")
	adapter.detach()
	lab.queue_free()
	model.queue_free()
	await _ticks(3)


# Positioned semantic controls only, not native trajectory proof. Each defense
# result comes from the ordinary pitcher helper and FieldingResolver. Only the
# later adversarial flag reset and synthetic geometric entry are fixture writes.
func _defense_history_controls() -> void:
	var saved_priority: int = process_physics_priority
	process_physics_priority = 1000
	for mode: String in ["early_bobble", "final_bobble", "miss", "clean"]:
		var lab: PitchBatLab = _lab()
		var model: Node3D = StadiumPoolWaterTestSupport.model(self, StadiumPoolContract.LIVE)
		var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
		var receipt: StadiumPoolActiveReceipt = StadiumPoolActiveReceipt.new()
		_check(receipt.attach(lab), "semantic defense receipt attached")
		_check(adapter.install(lab, model, StadiumPoolContract.LIVE, _source), "defense binding")
		adapter.enabled = true
		adapter.freeflight_enabled = true
		_set_bases(lab._base_state, 7)
		receipt.begin(Engine.get_physics_frames())
		_launch(lab, false)
		receipt.bind_owners()
		var ball: BattedBallBody = lab._batted_ball
		var state: BallPlayState = lab._ball_play_resolver.state
		ball.global_position = Vector3(12, 1.3, 18)
		ball.linear_velocity = Vector3(
			50 if mode == "miss" else (4 if mode == "clean" else 32), 0, 0
		)
		lab._pitcher_marker.global_position = Vector3(12, 0, 18)
		_check(adapter._owned() and receipt.owned(), "semantic ordinary defense owners")
		if mode == "final_bobble":
			adapter._guard.route(ball, [])
			_check(adapter.decline.is_empty(), "final-boundary control starts eligible")
		var expected: FieldingResolver.Outcome = FieldingResolver.Outcome.BOBBLE
		if mode == "miss":
			expected = FieldingResolver.Outcome.MISS
		elif mode == "clean":
			expected = FieldingResolver.Outcome.CLEAN
		_check(
			(
				PitcherDefense.resolve(
					ball.global_position,
					ball.linear_velocity,
					lab._pitcher_marker.global_position,
					false,
					MatchLabSupport.pitcher_fielding_rating(lab)
				)
				== expected
			),
			"semantic positioned ordinary resolver outcome " + mode
		)
		lab._try_pitcher_defense(ball.global_position, ball.global_position)
		_check(lab._pitcher_attempted, "ordinary pitcher attempt executed " + mode)
		if mode in ["early_bobble", "final_bobble"]:
			_check(
				state.defender_touched and state.bobbled and not state.caught and not state.dead,
				"ordinary bobble leaves physically touched play live"
			)
			_check(
				(
					(
						ball.linear_velocity
						== DeflectionModel.velocity_after_bobble(
							Vector3(32, 0, 0),
							lab._pitcher_marker.global_position,
							ball.global_position
						)
					)
					and ball.angular_velocity == DeflectionModel.spin_after_bobble(Vector3.ZERO)
					and lab._fielding_cooldown_seconds == 0.55
				),
				"ordinary bobble uses exact unmodified deflection, spin and cooldown"
			)
			var before: Array = _gameplay(lab)
			if mode == "early_bobble":
				adapter._guard.route(ball, [])
			else:
				_check(
					not adapter.try_resolve(lab, Vector3(12, 1.5, 18), ball.global_position),
					"intervening ordinary bobble declined at final boundary"
				)
			_check(
				adapter.decline == "PRIOR_DEFENSE_HISTORY_UNSUPPORTED",
				"ordinary bobble permanently closes launch authority " + mode
			)
			_check(
				_gameplay(lab) == before and adapter.commits == 0 and receipt.outcomes.is_empty(),
				"prior-defense rejection is complete gameplay no-op"
			)
			# Adversarial semantic reset cannot undo previously observed ordinary contact.
			state.defender_touched = false
			state.bobbled = false
			state.caught = false
			ball.global_position = Vector3(12, 1, 18)
			ball.linear_velocity = Vector3(2, -4, 1)
			ball.angular_velocity = Vector3(1, 2, 3)
			adapter._early_frame = -1
			before = _gameplay(lab)
			adapter._guard.route(ball, [])
			_check(
				(
					(
						StadiumPoolControllerActive
						. FreeflightEntry
						. evaluate(
							Vector3(12, 1.2, 18),
							ball.global_position,
							adapter._guard._physical_radius
						)
						. status
					)
					== "ENTRY"
				),
				"reset control has independently positive synthetic entry"
			)
			_check(
				not adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position),
				"reset defense flags cannot reopen latched launch"
			)
			_check(
				(
					adapter.decline == "PRIOR_DEFENSE_HISTORY_UNSUPPORTED"
					and _gameplay(lab) == before
					and adapter.commits == 0
					and receipt.outcomes.is_empty()
				),
				"permanent decline survives later early sample and final entry without mutation"
			)
		elif mode == "miss":
			_check(
				(
					state.last_defender_touch == &"pitcher"
					and not state.defender_touched
					and not state.bobbled
					and not state.caught
					and not state.dead
					and lab._fielding_cooldown_seconds > 0.0
				),
				"ordinary MISS records attempted defender without physical contact"
			)
			ball.global_position = Vector3(12, 1, 18)
			ball.linear_velocity = Vector3(2, -4, 1)
			ball.angular_velocity = Vector3(1, 2, 3)
			adapter._guard.route(ball, [])
			_check(adapter.decline.is_empty(), "ordinary MISS does not latch prior contact")
			_check(
				adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position),
				"synthetic entry remains eligible after ordinary MISS"
			)
			_check(
				(
					adapter.commits == 1
					and state.dead
					and receipt.outcomes.size() == 1
					and (
						_bases(lab._base_state)
						== [&"", StringName("batter.%d" % lab._throw_number), &"runner.first"]
					)
				),
				"ordinary MISS control commits and advances bases once"
			)
		else:
			_check(
				state.dead and state.caught and state.defender_touched and not state.bobbled,
				"ordinary clean control owns terminal catch"
			)
			_check(
				(
					receipt.outcomes.size() == 1
					and receipt.outcomes[0][2] == BallPlayOutcome.Result.OUT
					and receipt.outcomes[0][3] == "fly_catch"
					and receipt.outcomes[0][4]
				),
				"ordinary clean control emitted exactly one fly-catch outcome"
			)
			var before: Array = _gameplay(lab)
			_check(
				not adapter.try_resolve(lab, Vector3(12, 1.5, 18), ball.global_position),
				"clean terminal cannot be superseded by water"
			)
			_check(
				_gameplay(lab) == before and adapter.commits == 0 and receipt.outcomes.size() == 1,
				"clean terminal remains authoritative and adapter no-op"
			)
		_check(receipt.failure.is_empty(), "semantic defense outcome receipt valid")
		# Ordinary cleanup/relaunch creates a new state and resets decline eligibility.
		var commits_before: int = adapter.commits
		lab._pitcher_marker.global_position = PitchBatLab.MOUND_ORIGIN
		receipt.begin(Engine.get_physics_frames())
		_launch(lab, false)
		receipt.bind_owners()
		_check(
			(
				lab._batted_ball != ball
				and not ball.physics_contact_router.is_valid()
				and adapter.generation == 2
				and adapter.decline.is_empty()
			),
			"ordinary cleanup detaches prior router and relaunch resets defense latch"
		)
		state = lab._ball_play_resolver.state
		_check(
			(
				not state.dead
				and not state.defender_touched
				and not state.bobbled
				and not state.caught
			),
			"fresh ordinary state carries no previous defender history"
		)
		ball = lab._batted_ball
		ball.global_position = Vector3(12, 1, 18)
		adapter._guard.route(ball, [])
		_check(
			(
				adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position)
				and adapter.commits == commits_before + 1
				and receipt.outcomes.size() == 1
			),
			"new launch admits supported synthetic entry exactly once"
		)
		adapter.detach()
		_check(not ball.physics_contact_router.is_valid(), "semantic defense final router cleanup")
		lab.pool_active_receipt = null
		lab.queue_free()
		model.queue_free()
		await _ticks(3)
	process_physics_priority = saved_priority


# Same-process native unit integration, not independent fresh-process baselines.
# The fixed existing receipt supplies raw gameplay values, without owner IDs or
# absolute frame epochs. A/B/S each have two 180-tick launches and exact equality.
func _defense_catch_controls() -> void:
	var saved_priority: int = process_physics_priority
	process_physics_priority = 1000
	var baseline: PackedByteArray
	for arm: String in ["a", "b", "s"]:
		var lab: PitchBatLab = _lab()
		var model: Node3D = StadiumPoolWaterTestSupport.model(self, StadiumPoolContract.LIVE)
		var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
		var receipt: StadiumPoolActiveReceipt = StadiumPoolActiveReceipt.new()
		_check(receipt.attach(lab), "native defense receipt attached " + arm)
		if arm != "a":
			_check(adapter.install(lab, model, StadiumPoolContract.LIVE, _source), "catch binding")
		adapter.enabled = arm == "s"
		adapter.freeflight_enabled = true
		_set_bases(lab._base_state, 7)
		_defense_case = {
			"lab": lab,
			"adapter": adapter,
			"receipt": receipt,
			"arm": arm,
			"phase": "settle",
			"wait": 2,
			"ordinal": 0,
			"launches": [],
			"bases": []
		}
		while _defense_case.phase != "done":
			await get_tree().process_frame
		var actual: PackedByteArray = var_to_bytes(_defense_case.launches)
		if arm == "a":
			baseline = actual
		else:
			_check(actual == baseline, "native clean-catch full-window exact A=" + arm.to_upper())
		adapter.detach()
		_check(
			lab._batted_ball != null and not lab._batted_ball.physics_contact_router.is_valid(),
			"native catch final router detached " + arm
		)
		_defense_case = {}
		lab.pool_active_receipt = null
		lab.queue_free()
		model.queue_free()
		await _ticks(3)
	process_physics_priority = saved_priority


func _defense_catch_tick() -> void:
	if _defense_case.phase == "settle":
		_defense_case.wait -= 1
		if _defense_case.wait == 0:
			_defense_catch_launch()
	elif _defense_case.phase == "play":
		var receipt: StadiumPoolActiveReceipt = _defense_case.receipt
		receipt.capture_late(_defense_case.lab)
		if Engine.get_physics_frames() - receipt.launch_frame == 180:
			_defense_catch_finish()


func _defense_catch_launch() -> void:
	var lab: PitchBatLab = _defense_case.lab
	var adapter: StadiumPoolControllerActive = _defense_case.adapter
	var receipt: StadiumPoolActiveReceipt = _defense_case.receipt
	var retired: BattedBallBody = lab._batted_ball
	_defense_case.ordinal += 1
	_defense_case.bases = StadiumPoolActiveReceipt.bases(lab)
	var launch: BattedBallLaunch = _pair_batted_launch(false)
	_check(launch != null, "native catch genuine ordinary bat-generated launch")
	if launch == null:
		_defense_case.phase = "done"
		return
	receipt.begin(Engine.get_physics_frames())
	lab._start_ball_in_play(launch)
	# Ordinary launch cleanup resets the marker. Install the declared initial
	# arrangement only after that reset, before the first physics step.
	# Pursuit and defense remain unchanged; no ball or outcome value is replaced.
	lab._pitcher_marker.global_position = Vector3(13, 0, 17.0)
	_check(
		lab._pitcher_marker.global_position == Vector3(13, 0, 17.0),
		"native catch actual initial pitcher survives ordinary launch reset"
	)
	receipt.bind_owners()
	_check(
		launch.is_foul and launch.angular_velocity != Vector3.ZERO,
		"native catch retains resolver foul and nonzero spin"
	)
	_check(
		(
			receipt.owned()
			and (
				lab.pool_controller_active == null
				if _defense_case.arm == "a"
				else (adapter._owned() and adapter.decline.is_empty())
			)
		),
		"native catch fixed receipt and installed adapter own eligible launch"
	)
	if retired != null:
		_check(retired != lab._batted_ball, "native catch relaunch gets fresh ball")
		_check(not retired.physics_contact_router.is_valid(), "native catch prior router released")
	_check(
		(
			not lab._ball_play_resolver.state.dead
			and not lab._ball_play_resolver.state.defender_touched
			and not lab._ball_play_resolver.state.bobbled
			and not lab._ball_play_resolver.state.caught
		),
		"native catch launches with fresh ordinary defender state"
	)
	_defense_case.phase = "play"


func _defense_catch_finish() -> void:
	var lab: PitchBatLab = _defense_case.lab
	var adapter: StadiumPoolControllerActive = _defense_case.adapter
	var receipt: StadiumPoolActiveReceipt = _defense_case.receipt
	var ball: BattedBallBody = lab._batted_ball
	var state: BallPlayState = lab._ball_play_resolver.state
	_check(receipt.owned() and receipt.failure.is_empty(), "native catch bounded receipt valid")
	var first: Array = receipt.rows[0] if not receipt.rows.is_empty() else []
	var first_present: bool = (
		first.size() == 5
		and first[0] == 1
		and first[1] == "decision"
		and typeof(first[3]) == TYPE_BOOL
		and first[3]
		and typeof(first[4]) == TYPE_ARRAY
		and first[4].size() == 16
		and typeof(first[4][7]) == TYPE_ARRAY
		and first[4][7].size() == 4
		and typeof(first[4][7][3]) == TYPE_VECTOR3
	)
	var first_pitcher: Variant = first[4][7][3] if first_present else null
	_check(
		first_present and first_pitcher == Vector3(13, 0, 17.0),
		"native catch first actual decision records declared pitcher placement"
	)
	var diagnostic_outcome: Array = receipt.outcomes[0] if receipt.outcomes.size() == 1 else []
	print(
		(
			"POOL_DEFENSE_CATCH_V24 "
			+ JSON.stringify(
				{
					"arm": _defense_case.arm,
					"launch": _defense_case.ordinal,
					"first_pitcher": str(first_pitcher) if first_present else "MISSING",
					"outcome_tick": diagnostic_outcome[0] if diagnostic_outcome.size() == 8 else -1,
					"outcome_reason":
					diagnostic_outcome[3] if diagnostic_outcome.size() == 8 else "MISSING",
					"pool_commits": adapter.commits
				}
			)
		)
	)
	_check(
		lab.is_physics_processing() and lab._primary_fielder.is_physics_processing(),
		"native catch ordinary controller and primary remain enabled"
	)
	var late_count: int = 0
	var late_sequence: bool = true
	for row: Array in receipt.rows:
		if row[1] == "late":
			late_count += 1
			late_sequence = late_sequence and row[0] == late_count
	_check(late_count == 180 and late_sequence, "native catch exact 180-tick late window")
	_check(
		receipt.decision_count > 0 and receipt.decision_count < 180,
		"native catch ordinary decision stream ends at prior terminal"
	)
	_check(
		(
			state.dead
			and state.caught
			and state.defender_touched
			and not state.bobbled
			and not state.has_grounded
			and state.last_defender_touch == &"pitcher"
		),
		"native ordinary pitcher clean fly catch is terminal authority"
	)
	_check(
		(
			state.is_foul_play
			and state.catch_position.y > StadiumPoolContract.WATER_HEIGHT + ball.radius_m
		),
		"native spinning foul is caught before water entry"
	)
	_check(adapter.commits == 0, "native caught foul never commits pool award")
	_check(
		(
			ball.freeze
			and ball.linear_velocity == Vector3.ZERO
			and ball.angular_velocity == Vector3.ZERO
		),
		"native ordinary catch stops and freezes ball through observation window"
	)
	_check(receipt.outcomes.size() == 1, "native ordinary catch exactly one outcome")
	var outcome: Array = receipt.outcomes[0] if receipt.outcomes.size() == 1 else []
	_check(
		(
			outcome.size() == 8
			and outcome[2] == BallPlayOutcome.Result.OUT
			and outcome[3] == "fly_catch"
			and outcome[4]
			and outcome[5] == state.catch_position
		),
		"native outcome is genuine ordinary fly catch"
	)
	var expected_bases: BaseState = BaseState.new()
	expected_bases.first = StringName(_defense_case.bases[0])
	expected_bases.second = StringName(_defense_case.bases[1])
	expected_bases.third = StringName(_defense_case.bases[2])
	TagAdvanceResolver.resolve(
		expected_bases, state.catch_position, MatchLabSupport.pitcher_fielding_rating(lab)
	)
	var after_bases: Array = [
		String(expected_bases.first), String(expected_bases.second), String(expected_bases.third)
	]
	_check(
		(
			outcome.size() == 8
			and outcome[6] == _defense_case.bases
			and outcome[7] == after_bases
			and StadiumPoolActiveReceipt.bases(lab) == after_bases
		),
		"native outcome applies ordinary catch base handling exactly once"
	)
	_check(
		adapter.generation == (0 if _defense_case.arm == "a" else _defense_case.ordinal),
		"native catch generation tracks ordinary cleanup and relaunch"
	)
	_defense_case.launches.append([receipt.rows, receipt.outcomes])
	if _defense_case.ordinal == 1:
		_defense_catch_launch()
	else:
		_defense_case.phase = "done"


# Positioned semantic controls only. Ball/defender placement, gate inputs and the
# later synthetic entry are declared fixture writes, never native trajectory proof.
# Outcomes are produced by the real primary helper with unchanged default skill.
func _primary_history_controls() -> void:
	var saved_priority: int = process_physics_priority
	process_physics_priority = 1000
	for mode: String in ["early_bobble", "final_bobble", "miss", "clean"]:
		var lab: PitchBatLab = _lab()
		var model: Node3D = StadiumPoolWaterTestSupport.model(self, StadiumPoolContract.LIVE)
		var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
		var receipt: StadiumPoolActiveReceipt = StadiumPoolActiveReceipt.new()
		_check(receipt.attach(lab), "primary semantic receipt attached " + mode)
		_check(adapter.install(lab, model, StadiumPoolContract.LIVE, _source), "primary binding")
		adapter.enabled = true
		adapter.freeflight_enabled = true
		_set_bases(lab._base_state, 7)
		receipt.begin(Engine.get_physics_frames())
		_launch(lab, false)
		receipt.bind_owners()
		var ball: BattedBallBody = lab._batted_ball
		var state: BallPlayState = lab._ball_play_resolver.state
		var primary: FielderController = lab._primary_fielder
		var incoming: Vector3 = Vector3(
			50 if mode == "miss" else (4 if mode == "clean" else 32), 0, 0
		)
		ball.global_position = Vector3(12, 1.3, 18)
		ball.linear_velocity = incoming
		primary.global_position = Vector3(12, 0, 18)
		_check(
			(
				primary.fielding_rating == 6
				and primary.handling_scale == 1.0
				and primary.reach_m == 0.66
				and primary.last_reaction_margin_seconds == 0.0
				and not primary.stationary
				and primary.first_step == Vector3.ZERO
				and lab._primary_attempts == 0
				and lab._fielding_cooldown_seconds == 0.0
				and not state.has_grounded
				and not state.dead
			),
			"primary semantic uses unmodified default rating handling reach and reaction " + mode
		)
		_check(
			(
				adapter._owned()
				and receipt.owned()
				and not _primary_semantic_snapshot(receipt, lab).is_empty()
			),
			"primary semantic owned finite complete initial snapshot"
		)
		if mode == "final_bobble":
			adapter._guard.route(ball, [])
			_check(adapter.decline.is_empty(), "primary final-boundary starts eligible")
		var expected: FieldingResolver.Outcome = FieldingResolver.Outcome.BOBBLE
		if mode == "miss":
			expected = FieldingResolver.Outcome.MISS
		elif mode == "clean":
			expected = FieldingResolver.Outcome.CLEAN
		_check(
			(
				FieldingResolver.resolve(
					primary.horizontal_distance_to(ball.global_position),
					ball.linear_velocity.length(),
					ball.global_position.y,
					state.has_grounded,
					primary.fielding_rating,
					primary.last_reaction_margin_seconds,
					primary.handling_scale,
					0.0
				)
				== expected
			),
			"primary semantic source-bound positioned resolver oracle " + mode
		)
		lab._try_primary_fielder()
		_check(
			(
				lab._primary_attempts == 1
				and not lab._pitcher_attempted
				and state.last_defender_touch == &"primary_fielder"
			),
			"real primary helper owns one attempt and defender identity " + mode
		)
		if mode in ["early_bobble", "final_bobble"]:
			_check(
				(
					state.defender_touched
					and state.bobbled
					and not state.caught
					and not state.dead
					and state.result_floor == BallPlayState.ResultFloor.SINGLE
				),
				"ordinary primary bobble remains live with earned Single floor"
			)
			_check(
				(
					(
						ball.linear_velocity
						== DeflectionModel.velocity_after_bobble(
							incoming, Vector3(12, 0, 18), ball.global_position
						)
					)
					and ball.angular_velocity == DeflectionModel.spin_after_bobble(Vector3.ZERO)
					and lab._fielding_cooldown_seconds == 0.55
					and not ball.freeze
				),
				"ordinary primary bobble exact deflection spin and cooldown"
			)
			var before: Array = _primary_semantic_snapshot(receipt, lab)
			lab._try_primary_fielder()
			_check(
				(
					not before.is_empty()
					and _primary_semantic_snapshot(receipt, lab) == before
					and lab._primary_attempts == 1
					and receipt.outcomes.is_empty()
				),
				"actual primary bobble cooldown rejects another attempt without mutation"
			)
			if mode == "early_bobble":
				adapter._guard.route(ball, [])
			else:
				_check(
					not adapter.try_resolve(lab, Vector3(12, 1.5, 18), ball.global_position),
					"intervening ordinary primary bobble declined at final boundary"
				)
			_check(
				adapter.decline == "PRIOR_DEFENSE_HISTORY_UNSUPPORTED",
				"ordinary primary bobble permanently closes launch authority " + mode
			)
			_check(
				(
					not before.is_empty()
					and _primary_semantic_snapshot(receipt, lab) == before
					and adapter.commits == 0
					and receipt.outcomes.is_empty()
				),
				"primary defense rejection is full receipt gameplay no-op"
			)
			# Adversarial semantic reset, not a repair or a generated trajectory.
			state.defender_touched = false
			state.bobbled = false
			state.caught = false
			ball.global_position = Vector3(12, 1, 18)
			ball.linear_velocity = Vector3(2, -4, 1)
			ball.angular_velocity = Vector3(1, 2, 3)
			adapter._early_frame = -1
			before = _primary_semantic_snapshot(receipt, lab)
			adapter._guard.route(ball, [])
			_check(
				(
					(
						StadiumPoolControllerActive
						. FreeflightEntry
						. evaluate(
							Vector3(12, 1.2, 18),
							ball.global_position,
							adapter._guard._physical_radius
						)
						. status
					)
					== "ENTRY"
				),
				"primary reset has independently positive synthetic entry"
			)
			_check(
				not adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position),
				"reset primary flags cannot reopen launch authority"
			)
			_check(
				(
					adapter.decline == "PRIOR_DEFENSE_HISTORY_UNSUPPORTED"
					and not before.is_empty()
					and _primary_semantic_snapshot(receipt, lab) == before
					and adapter.commits == 0
					and receipt.outcomes.is_empty()
				),
				"primary latch survives later early sample and final entry with no mutation"
			)
		elif mode == "miss":
			_check(
				(
					not state.defender_touched
					and not state.bobbled
					and not state.caught
					and not state.dead
					and state.result_floor == BallPlayState.ResultFloor.NONE
					and ball.linear_velocity == incoming
					and ball.angular_velocity == Vector3.ZERO
					and lab._fielding_cooldown_seconds == 0.35
				),
				"ordinary primary MISS records attempt without contact or deflection"
			)
			var before: Array = _primary_semantic_snapshot(receipt, lab)
			lab._try_primary_fielder()
			_check(
				(
					not before.is_empty()
					and _primary_semantic_snapshot(receipt, lab) == before
					and lab._primary_attempts == 1
					and receipt.outcomes.is_empty()
				),
				"actual primary MISS cooldown rejects repeated attempt without mutation"
			)
			ball.global_position = Vector3(12, 1, 18)
			ball.linear_velocity = Vector3(2, -4, 1)
			ball.angular_velocity = Vector3(1, 2, 3)
			adapter._guard.route(ball, [])
			_check(adapter.decline.is_empty(), "ordinary primary MISS does not latch contact")
			_check(
				(
					(
						StadiumPoolControllerActive
						. FreeflightEntry
						. evaluate(
							Vector3(12, 1.2, 18),
							ball.global_position,
							adapter._guard._physical_radius
						)
						. status
					)
					== "ENTRY"
				),
				"primary MISS later synthetic entry independently positive"
			)
			_check(
				adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position),
				"synthetic entry eligible after ordinary primary MISS"
			)
			_check(
				(
					adapter.commits == 1
					and state.dead
					and not state.caught
					and _primary_semantic_outcome(
						receipt,
						BallPlayOutcome.Result.DOUBLE,
						"private_pool_controller_water_double",
						false
					)
					and (
						_bases(lab._base_state)
						== [&"", StringName("batter.%d" % lab._throw_number), &"runner.first"]
					)
				),
				"ordinary primary MISS allows one water Double and one base advance"
			)
		else:
			_check(
				(
					state.dead
					and state.caught
					and state.defender_touched
					and not state.bobbled
					and ball.sleeping
					and ball.linear_velocity == Vector3.ZERO
					and ball.angular_velocity == Vector3.ZERO
					and lab._fielding_cooldown_seconds == 0.0
				),
				"ordinary primary CLEAN owns terminal catch and immediate stopped sleeping ball"
			)
			_check(
				_primary_semantic_outcome(receipt, BallPlayOutcome.Result.OUT, "fly_catch", true),
				"ordinary primary CLEAN emits exactly one well-formed fly-catch outcome"
			)
			var before: Array = _primary_semantic_snapshot(receipt, lab)
			_check(
				not adapter.try_resolve(lab, Vector3(12, 1.5, 18), ball.global_position),
				"primary clean terminal cannot be superseded by water"
			)
			_check(
				(
					not before.is_empty()
					and _primary_semantic_snapshot(receipt, lab) == before
					and adapter.commits == 0
					and receipt.outcomes.size() == 1
				),
				"primary clean outcome remains authoritative with adapter gameplay no-op"
			)
		_check(receipt.failure.is_empty(), "primary semantic outcome receipt valid " + mode)
		var commits_before: int = adapter.commits
		var retired_state: BallPlayState = state
		receipt.begin(Engine.get_physics_frames())
		_launch(lab, false)
		receipt.bind_owners()
		_check(
			(
				lab._batted_ball != ball
				and ball.is_queued_for_deletion()
				and not ball.physics_contact_router.is_valid()
				and adapter.generation == 2
				and adapter.decline.is_empty()
				and receipt.owned()
				and adapter._owned()
			),
			"ordinary primary cleanup detaches prior ball router and relaunch resets latch"
		)
		state = lab._ball_play_resolver.state
		_check(
			(
				state != retired_state
				and not state.dead
				and not state.defender_touched
				and not state.bobbled
				and not state.caught
				and state.last_defender_touch == &""
				and lab._primary_attempts == 0
				and not lab._pitcher_attempted
				and lab._fielding_cooldown_seconds == 0.0
				and primary.active
				and primary.global_position == primary.anchor_position
			),
			"fresh ordinary primary state resets identity attempts cooldown and position"
		)
		ball = lab._batted_ball
		ball.global_position = Vector3(12, 1, 18)
		adapter._guard.route(ball, [])
		_check(
			(
				adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position)
				and adapter.commits == commits_before + 1
				and _primary_semantic_outcome(
					receipt,
					BallPlayOutcome.Result.DOUBLE,
					"private_pool_controller_water_double",
					false
				)
			),
			"fresh primary semantic launch admits supported synthetic entry once"
		)
		var resolved: Array = _primary_semantic_snapshot(receipt, lab)
		_check(
			(
				not adapter.try_resolve(lab, Vector3(12, 1.2, 18), ball.global_position)
				and not resolved.is_empty()
				and _primary_semantic_snapshot(receipt, lab) == resolved
				and adapter.commits == commits_before + 1
				and receipt.outcomes.size() == 1
				and receipt.failure.is_empty()
			),
			"fresh primary semantic terminal cannot duplicate outcome or base advance"
		)
		adapter.detach()
		_check(not ball.physics_contact_router.is_valid(), "primary semantic final router cleanup")
		lab.pool_active_receipt = null
		lab.queue_free()
		model.queue_free()
		await _ticks(3)
	await _primary_eligibility_controls()
	process_physics_priority = saved_priority


# Finite positioned precondition probes. These invoke the real helper; rejecting
# a gate must not manufacture a MISS, consume an attempt, or change gameplay.
func _primary_eligibility_controls() -> void:
	for mode: String in [
		"attempt_cap",
		"cooldown",
		"stationary_reaction",
		"first_step_reaction",
		"negative_height",
		"air_height",
		"ground_height",
		"reach"
	]:
		var lab: PitchBatLab = _lab()
		var receipt: StadiumPoolActiveReceipt = StadiumPoolActiveReceipt.new()
		_check(receipt.attach(lab), "primary eligibility receipt attached " + mode)
		receipt.begin(Engine.get_physics_frames())
		_launch(lab, false)
		receipt.bind_owners()
		var ball: BattedBallBody = lab._batted_ball
		var state: BallPlayState = lab._ball_play_resolver.state
		var primary: FielderController = lab._primary_fielder
		ball.global_position = Vector3(12, 1.3, 18)
		ball.linear_velocity = Vector3(4, 0, 0)
		primary.global_position = Vector3(12, 0, 18)
		_check(
			(
				primary.fielding_rating == 6
				and primary.handling_scale == 1.0
				and primary.reach_m == 0.66
				and primary.last_reaction_margin_seconds == 0.0
				and not lab._match_mode
				and not lab.has_meta(&"stadium_property")
				and lab._primary_attempts == 0
				and lab._fielding_cooldown_seconds == 0.0
			),
			"primary eligibility retains default isolated configuration " + mode
		)
		_check(
			(
				FieldingResolver.resolve(
					0.0,
					4.0,
					1.3,
					false,
					primary.fielding_rating,
					primary.last_reaction_margin_seconds,
					primary.handling_scale,
					0.0
				)
				== FieldingResolver.Outcome.CLEAN
			),
			"primary eligibility otherwise catchable finite baseline " + mode
		)
		match mode:
			"attempt_cap":
				# The cap is reached by two ordinary MISS outcomes. Clearing only
				# cooldown isolates the cap gate without pretending time elapsed.
				ball.linear_velocity = Vector3(50, 0, 0)
				lab._try_primary_fielder()
				lab._fielding_cooldown_seconds = 0.0
				lab._try_primary_fielder()
				_check(
					(
						lab._primary_attempts == 2
						and lab._fielding_cooldown_seconds == 0.35
						and state.last_defender_touch == &"primary_fielder"
						and not state.defender_touched
						and not state.bobbled
						and not state.dead
						and receipt.outcomes.is_empty()
					),
					"primary attempt cap established by two real helper MISS results"
				)
				lab._fielding_cooldown_seconds = 0.0
				ball.linear_velocity = Vector3(4, 0, 0)
			"cooldown":
				lab._fielding_cooldown_seconds = 0.25
			"stationary_reaction":
				primary.begin_play(true)
				primary.global_position = Vector3(12, 0, 18)
			"first_step_reaction":
				primary.begin_play(false, Vector3.RIGHT)
				primary.global_position = Vector3(12, 0, 18)
			"negative_height":
				ball.global_position.y = -0.05
			"air_height":
				ball.global_position.y = FieldingResolver.MAX_AIR_CONTROL_HEIGHT_M + 0.05
			"ground_height":
				lab._ball_play_resolver.record_ground_contact(Vector3(12, 0, 18))
				ball.global_position.y = FieldingResolver.MAX_GROUND_CONTROL_HEIGHT_M + 0.05
			"reach":
				primary.global_position.x = 12.75
		var before: Array = _primary_semantic_snapshot(receipt, lab)
		_check(
			receipt.owned() and not before.is_empty() and receipt.failure.is_empty(),
			"primary eligibility owned complete finite pre-attempt snapshot " + mode
		)
		lab._try_primary_fielder()
		_check(
			(
				not before.is_empty()
				and _primary_semantic_snapshot(receipt, lab) == before
				and lab._primary_attempts == (2 if mode == "attempt_cap" else 0)
				and not state.defender_touched
				and not state.bobbled
				and not state.caught
				and not state.dead
				and not lab._pitcher_attempted
				and receipt.outcomes.is_empty()
				and receipt.failure.is_empty()
			),
			"primary eligibility rejection preserves every receipt field " + mode
		)
		# Clearing a gate is not needed: ordinary cleanup/relaunch must reset it.
		var retired: BattedBallBody = ball
		var retired_state: BallPlayState = state
		receipt.begin(Engine.get_physics_frames())
		_launch(lab, false)
		receipt.bind_owners()
		ball = lab._batted_ball
		state = lab._ball_play_resolver.state
		ball.global_position = Vector3(12, 1.3, 18)
		ball.linear_velocity = Vector3(4, 0, 0)
		primary.global_position = Vector3(12, 0, 18)
		_check(
			(
				ball != retired
				and retired.is_queued_for_deletion()
				and state != retired_state
				and lab._primary_attempts == 0
				and lab._fielding_cooldown_seconds == 0.0
				and not primary.stationary
				and primary.first_step == Vector3.ZERO
				and not state.has_grounded
				and state.last_defender_touch == &""
			),
			"primary eligibility ordinary relaunch clears earlier gate inputs " + mode
		)
		lab._try_primary_fielder()
		_check(
			(
				lab._primary_attempts == 1
				and state.last_defender_touch == &"primary_fielder"
				and state.dead
				and state.caught
				and state.defender_touched
				and not state.bobbled
				and _primary_semantic_outcome(
					receipt, BallPlayOutcome.Result.OUT, "fly_catch", true
				)
				and receipt.failure.is_empty()
			),
			"primary eligibility fresh ordinary helper CLEAN remains reachable " + mode
		)
		lab.pool_active_receipt = null
		lab.queue_free()
		await _ticks(3)


# Guard fixed raw receipt shapes before any indexing or equality. Empty or
# nonfinite snapshots cannot satisfy a no-mutation assertion by matching each other.
func _primary_semantic_snapshot(receipt: StadiumPoolActiveReceipt, lab: PitchBatLab) -> Array:
	if (
		receipt == null
		or not is_instance_valid(lab)
		or not is_instance_valid(lab._batted_ball)
		or not receipt.owned()
	):
		return []
	var sample: Array = receipt.snapshot(
		lab, lab._batted_ball.global_position, lab._batted_ball.global_position
	)
	if sample.size() != 16 or not sample[5] is Array or sample[5].size() != 15:
		return []
	if not sample[13] is Array or sample[13].size() != 17:
		return []
	for pose: Variant in [sample[0], sample[7], sample[13][0]]:
		if not pose is Array or pose.size() != 4:
			return []
		for component: Variant in pose:
			if not component is Vector3 or not component.is_finite():
				return []
	return sample if _primary_semantic_finite(sample) and receipt.failure.is_empty() else []


func _primary_semantic_outcome(
	receipt: StadiumPoolActiveReceipt, result: BallPlayOutcome.Result, reason: String, caught: bool
) -> bool:
	if receipt.outcomes.size() != 1 or not receipt.outcomes[0] is Array:
		return false
	var outcome: Array = receipt.outcomes[0]
	if outcome.size() != 8 or not _primary_semantic_finite(outcome):
		return false
	return outcome[2] == result and outcome[3] == reason and outcome[4] == caught


func _primary_semantic_finite(value: Variant) -> bool:
	match typeof(value):
		TYPE_ARRAY:
			for item: Variant in value:
				if not _primary_semantic_finite(item):
					return false
			return true
		TYPE_VECTOR3:
			return value.is_finite()
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME:
			return true
	return false


func _physical() -> void:
	var role: String = StadiumPoolContract.LIVE
	if _mode == "scenery":
		role = StadiumPoolContract.SCENERY
	elif _mode == "no_pool":
		role = "NO_POOL"
	var lab: PitchBatLab = _lab()
	var model: Node3D = StadiumPoolWaterTestSupport.model(self, role)
	var adapter: StadiumPoolControllerActive = StadiumPoolControllerActive.new()
	_check(adapter.install(lab, model, role, _source), "ordinary adapter installed")
	adapter.enabled = _mode != "disabled"
	_set_bases(lab._base_state, 7)
	await _ticks(2)
	var far: bool = _mode == "far"
	var foul: bool = _mode == "foul"
	_launch(lab, foul)
	if far:
		lab._pitcher_marker.global_position = Vector3(24, 0, 13.716)
	var first_ball: BattedBallBody = lab._batted_ball
	_check(
		lab.is_physics_processing() and lab._primary_fielder.is_physics_processing(),
		"ordinary controller and primary physics enabled"
	)
	await _ticks(36)
	var should_commit: bool = role == StadiumPoolContract.LIVE and adapter.enabled
	_check(adapter.commits == (1 if should_commit else 0), "ordinary physics water count")
	if should_commit:
		_check(
			lab._ball_play_resolver.state.dead and first_ball.freeze, "ordinary outcome stops ball"
		)
		_check(first_ball.linear_velocity == Vector3.ZERO, "ordinary stop zeros motion")
		_check(
			(
				lab._base_state.second
				== (&"runner.second" if foul else StringName("batter.%d" % lab._throw_number))
			),
			"ordinary base advancement / foul hold"
		)
		var count_before: int = adapter.commits
		await _ticks(3)
		_check(adapter.commits == count_before, "no repeated terminal")
		_launch(lab, false)
		_check(
			lab._batted_ball != first_ball and adapter.generation == 2, "fresh relaunch identity"
		)
		await _ticks(36)
		_check(adapter.commits == count_before + 1, "ordinary relaunch commits once")
	adapter.detach()
	_check(not lab._batted_ball.physics_contact_router.is_valid(), "router cleanup")
	lab.queue_free()
	if model != null:
		model.queue_free()
	await _ticks(3)


func _lab() -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_mode = false
	add_child(lab)
	lab._match_mode = false
	lab.set_process(false)
	return lab


func _launch(lab: PitchBatLab, foul: bool) -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(12, 2.2, 18)
	launch.velocity = Vector3(0, -4, 0)
	launch.angular_velocity = Vector3.ZERO
	launch.orientation = Quaternion(0.5, 0.5, 0.5, 0.5)
	launch.is_foul = foul
	lab._start_ball_in_play(launch)


func _gameplay(lab: PitchBatLab) -> Array:
	return [
		var_to_bytes(StadiumPoolWaterGuard._state_parameters(lab._ball_play_resolver.state)),
		lab._batted_ball.global_transform,
		lab._batted_ball.linear_velocity,
		lab._batted_ball.angular_velocity,
		lab._pitcher_marker.global_transform,
		_bases(lab._base_state),
		lab._pitcher_attempted,
		lab._primary_attempts,
		lab._fielding_cooldown_seconds
	]


func _set_bases(bases: BaseState, occupancy: int) -> void:
	bases.first = &"runner.first" if occupancy & 1 else &""
	bases.second = &"runner.second" if occupancy & 2 else &""
	bases.third = &"runner.third" if occupancy & 4 else &""


func _bases(bases: BaseState) -> Array:
	return [bases.first, bases.second, bases.third]


func _outcome(outcome: BallPlayOutcome) -> void:
	_outcomes += 1
	_last_outcome = outcome


func _ticks(count: int) -> void:
	for index: int in range(count):
		await get_tree().physics_frame
		await get_tree().process_frame


func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error("POOL_ACTIVE_V19 " + label)


func _pair_start() -> void:
	process_physics_priority = 1000
	var options: Dictionary = {}
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--physical-in-process":
			continue
		var split: int = arg.find("=")
		if split < 0 or options.has(arg.substr(0, split)):
			_check(false, "paired duplicate or malformed arguments")
			get_tree().quit(1)
			return
		options[arg.substr(0, split)] = arg.substr(split + 1)
	if options.size() != 5:
		_check(false, "paired exact five arguments")
		get_tree().quit(1)
		return
	_pair_arm = options.get("--pool-active-arm", "")
	_pair_path = options.get("--pool-active-receipt", "")
	_pair_execution = options.get("--pool-active-execution", "")
	_pair_nonce = options.get("--pool-active-nonce", "")
	_check(_pair_arm in ["a", "b", "s"], "paired arm")
	_check(_mode in ["wet", "far", "foul", "dry", "scenery", "no_pool"], "paired case")
	_check(_hex_text(_pair_execution, 64) and _hex_text(_pair_nonce, 32), "paired pins")
	_check(
		_pair_path.is_absolute_path() and not FileAccess.file_exists(_pair_path), "fresh receipt"
	)
	_check(Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0, "ordinary clock")
	_check(
		ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "ordinary Jolt"
	)
	_check(not FileAccess.file_exists(PitchBatLabSettings.path), "fresh settings")
	if _failures > 0:
		get_tree().quit(1)
		return
	_pair_lab = _lab()
	var role: String = StadiumPoolContract.LIVE
	if _mode == "scenery":
		role = StadiumPoolContract.SCENERY
	elif _mode == "no_pool":
		role = "NO_POOL"
	_pair_model = StadiumPoolWaterTestSupport.model(self, role)
	_pair_adapter = StadiumPoolControllerActive.new()
	_pair_receipt = StadiumPoolActiveReceipt.new()
	_check(_pair_receipt.attach(_pair_lab), "fixed receipt attached")
	if _pair_arm != "a":
		_check(_pair_adapter.install(_pair_lab, _pair_model, role, _source), "paired installed")
	_pair_adapter.enabled = _pair_arm == "s"
	_pair_adapter.freeflight_enabled = _mode in ["foul", "dry", "scenery", "no_pool"]
	_set_bases(_pair_lab._base_state, 7)
	_check(
		_pair_lab._field_definition.resource_path == "res://src/content/fields/starter_field.tres",
		"field source"
	)
	_pair_field = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_pair_lab._field_definition))
	_pair_process = _process_values()
	_check(_pair_process.size() == 8, "process lifetime")
	_pair_phase = "settle"


func _physics_process(_delta: float) -> void:
	if _bound_controls != null:
		_bound_controls.tick()
		return
	if not _defense_case.is_empty():
		_defense_catch_tick()
		return
	if _pair_phase == "settle":
		_pair_wait -= 1
		if _pair_wait == 0:
			_pair_launch()
	elif _pair_phase == "play":
		_pair_receipt.capture_late(_pair_lab)
		if Engine.get_physics_frames() - _pair_receipt.launch_frame == 180:
			_pair_finish_launch()
	elif _pair_phase == "drain":
		_pair_wait -= 1
		if _pair_wait == 0:
			_pair_save()


func _pair_launch() -> void:
	var retired: BattedBallBody = _pair_lab._batted_ball
	_pair_ordinal += 1
	_pair_start_checks = _checks
	_pair_start_failures = _failures
	_pair_bases = StadiumPoolActiveReceipt.bases(_pair_lab)
	_pair_commits = _pair_adapter.commits
	_pair_receipt.begin(Engine.get_physics_frames())
	var launch: BattedBallLaunch
	if _mode in ["foul", "dry", "scenery", "no_pool"]:
		launch = _pair_batted_launch(_mode == "dry")
	else:
		# Inherited vertical Double regressions, not labeled bat-generated flight.
		launch = BattedBallLaunch.new()
		launch.position = Vector3(12, 2.2, 18)
		launch.velocity = Vector3(0, -4, 0)
		launch.angular_velocity = Vector3.ZERO
		launch.orientation = Quaternion(0.5, 0.5, 0.5, 0.5)
	_check(launch != null, "legal fixed launch construction")
	if launch == null:
		get_tree().quit(1)
		return
	_pair_lab._start_ball_in_play(launch)
	if _mode == "far":
		_pair_lab._pitcher_marker.global_position = Vector3(24, 0, 13.716)
	if retired != null:
		_check(retired != _pair_lab._batted_ball, "fresh relaunch body")
		_check(not retired.physics_contact_router.is_valid(), "ordinary prior router cleanup")
		_pair_launches[0][5][5] = not retired.physics_contact_router.is_valid()
	_check(_pair_lab.is_physics_processing(), "ordinary controller enabled")
	_check(_pair_lab._primary_fielder.is_physics_processing(), "ordinary primary enabled")
	_pair_ids = [
		_pair_lab.get_instance_id(),
		_pair_lab._batted_ball.get_instance_id(),
		_pair_lab._primary_fielder.get_instance_id(),
		_pair_lab._ball_play_resolver.get_instance_id(),
		_pair_lab._ball_play_resolver.state.get_instance_id(),
		_pair_adapter.get_instance_id(),
	]
	_pair_receipt.bind_owners()
	_check(_pair_receipt.owned(), "bound current receipt owners")
	_pair_phase = "play"


# The fixture supplies legal pitch/swing inputs to the ordinary public resolver.
# No ContactResult, contact position, exit velocity, spin or launch outcome override.
# This is bat-generated free flight, not a full pitched-at-bat input simulation.
func _pair_batted_launch(dry: bool) -> BattedBallLaunch:
	var profile: SwingProfileDefinition = load("res://src/content/swings/power_swing.tres")
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = profile.id
	intent.aim_point = Vector2(-0.020532, 1.2394542983688768)
	intent.handedness_left = true
	intent.start_time_seconds = 0.8763333333333333
	if SwingIntent.reachable_aim(intent.aim_point) != intent.aim_point:
		return null
	var pitch: PitchState = PitchState.new()
	pitch.position = Vector3(0, 1.5, 0.25)
	pitch.velocity = Vector3(0, 0, -12)
	pitch.elapsed_time = 1.0166666666666666
	pitch.orientation = (
		Quaternion(0, 0, 0.5, 0.8660254037844386)
		if dry
		else Quaternion(0, 0, -0.8660254037844386, 0.5)
	)
	var contact: ContactResult = ContactResolver.resolve_swept_segment(
		Vector3(0, 1.5, 0.45), 1.0, pitch, intent, profile, 10, 10
	)
	if contact == null or contact.outcome != ContactResult.Outcome.FOUL:
		return null
	var launch: BattedBallLaunch = BattedBallLaunch.from_contact(contact, pitch)
	if (
		not launch.is_foul
		or not launch.position.is_finite()
		or launch.position.x != 0.0
		or launch.position.y != 1.5
		or launch.position.z <= 0.25
		or launch.position.z >= 0.45
		or launch.velocity.x <= 0.0
		or launch.velocity.y <= 0.0
		or launch.velocity.z <= 0.0
		or launch.angular_velocity == Vector3.ZERO
	):
		return null
	return launch


func _pair_finish_launch() -> void:
	var supported: bool = _pair_arm == "s" and _mode in ["wet", "far", "foul"]
	var ball: BattedBallBody = _pair_lab._batted_ball
	_check(_pair_receipt.owned(), "final receipt owners")
	_check(_pair_receipt.failure.is_empty(), "bounded receipt complete")
	_check(_pair_adapter.commits == _pair_commits + (1 if supported else 0), "paired commit count")
	_check(_pair_receipt.outcomes.size() <= 1, "ordinary outcome at most once")
	_check(
		(
			_pair_field
			== var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_pair_lab._field_definition))
		),
		"unchanged bound field"
	)
	if supported:
		_check(_pair_receipt.outcomes.size() == 1, "supported ordinary outcome once")
		_check(_pair_lab._ball_play_resolver.state.dead and ball.freeze, "ordinary terminal stop")
		_check(
			ball.linear_velocity == Vector3.ZERO and ball.angular_velocity == Vector3.ZERO,
			"ordinary stopped motion"
		)
		var expected: Array = (
			_pair_bases
			if _mode == "foul"
			else ["", "batter.%d" % _pair_lab._throw_number, _pair_bases[0]]
		)
		_check(
			StadiumPoolActiveReceipt.bases(_pair_lab) == expected,
			"ordinary fair advance or foul hold"
		)
	var detached: bool = false
	if _pair_ordinal == 2:
		_pair_adapter.detach()
		detached = not ball.physics_contact_router.is_valid()
		_check(detached, "final router detach")
	var lifecycle: Array = [
		_pair_adapter.generation,
		_pair_commits,
		_pair_adapter.commits,
		_pair_lab._ball_play_resolver.state.dead,
		ball.freeze,
		detached,
		StadiumPoolActiveReceipt.bases(_pair_lab),
		_pair_adapter.decline,
		_pair_receipt.decision_count,
		_checks - _pair_start_checks,
		_failures - _pair_start_failures,
	]
	(
		_pair_launches
		. append(
			[
				_pair_ordinal,
				_pair_ids,
				_pair_bases,
				_pair_receipt.rows,
				_pair_receipt.outcomes,
				lifecycle,
			]
		)
	)
	if _pair_ordinal == 1:
		_pair_launch()
	else:
		_pair_lab.pool_active_receipt = null
		_pair_lab.queue_free()
		if _pair_model != null:
			_pair_model.queue_free()
		_pair_wait = 3
		_pair_phase = "drain"


func _pair_save() -> void:
	_pair_phase = "done"
	_check(_process_values() == _pair_process, "same process lifetime")
	var packet: Array = [
		"POOL-ACTIVE-PAIRED-v20",
		_pair_arm,
		_mode,
		_source,
		_pair_execution,
		_pair_process,
		_pair_launches,
		_checks,
		_failures,
	]
	var bytes: PackedByteArray = var_to_bytes(packet)
	if bytes.size() > 32 * 1024 * 1024:
		_check(false, "receipt file budget")
	else:
		var file: FileAccess = FileAccess.open(_pair_path, FileAccess.WRITE)
		if file == null:
			_check(false, "receipt open")
		else:
			file.store_buffer(bytes)
			file.close()
	print(
		(
			"POOL_ACTIVE_PAIRED_V20 arm=%s case=%s checks=%d failures=%d source=%s"
			% [
				_pair_arm,
				_mode,
				_checks,
				_failures,
				_source,
			]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _process_values() -> Array:
	var file: FileAccess = FileAccess.open("/proc/self/stat", FileAccess.READ)
	if file == null:
		return []
	var stat: String = file.get_line()
	var opening: int = stat.find("(")
	var closing: int = stat.rfind(")")
	if opening < 1 or closing <= opening:
		return []
	var fields: PackedStringArray = stat.substr(closing + 2).split(" ", false)
	if fields.size() < 20 or not fields[1].is_valid_int() or not fields[19].is_valid_int():
		return []
	file = FileAccess.open("/proc/sys/kernel/random/boot_id", FileAccess.READ)
	if file == null:
		return []
	var boot: String = file.get_line().strip_edges()
	if not _hex_text(boot.replace("-", ""), 32):
		return []
	if int(stat.substr(0, opening).strip_edges()) != OS.get_process_id():
		return []
	return [
		OS.get_process_id(),
		_pair_nonce,
		704716,
		_engine_version(),
		int(fields[1]),
		int(fields[19]),
		boot,
		FileAccess.get_sha256("res://src/content/fields/starter_field.tres"),
	]


static func _hex_text(value: String, size: int) -> bool:
	if value.length() != size:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func _engine_version() -> String:
	var value: Dictionary = Engine.get_version_info()
	return (
		"%d.%d.%d.%s.%s.%s"
		% [
			value.major,
			value.minor,
			value.patch,
			value.status,
			value.build,
			String(value.hash).substr(0, 9),
		]
	)

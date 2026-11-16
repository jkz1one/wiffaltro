extends Node3D
## Explicit manual semantic controls. Actual physics callback histories are a separate stage.

var _checks: int = 0
var _failures: int = 0
var _source: String
var _floor: StaticBody3D
var _outcomes: Array[BallPlayOutcome] = []


func _ready() -> void:
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	_floor = StadiumPoolWaterTestSupport.ground(self)
	for foul: bool in [false, true]:
		for floor_value: int in [0, 1, 2]:
			for touched: bool in [false, true]:
				var fixture: Dictionary = _fixture(StadiumPoolContract.LIVE, true, foul)
				fixture.resolver.state.result_floor = floor_value
				fixture.resolver.state.defender_touched = touched
				fixture.resolver.state.is_fair = not foul
				_start(fixture)
				_manual_wet(fixture)
				_check(_outcomes.size() == 1, "exactly one water result")
				var expected: int = (
					BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.DOUBLE
				)
				_check(
					_outcomes[0].result == expected and not _outcomes[0].caught,
					"immutable fair/foul water result"
				)
				_check(fixture.resolver.state.is_foul_play == foul, "assignment preserved")
				_check(
					fixture.resolver.state.result_floor == (floor_value if foul else 2),
					"earned floor preserved/monotonic Double"
				)
				_check(
					(
						not fixture.resolver.state.has_grounded
						and fixture.resolver.state.defender_touched == touched
					),
					"no fabricated ground or defender touch"
				)
				_route(fixture)
				fixture.resolver.record_clean_control(&"late", fixture.ball.global_position, true)
				fixture.resolver.record_ground_contact(fixture.ball.global_position)
				_check(
					_outcomes.size() == 1 and not fixture.resolver.state.caught,
					"later callbacks cannot restart terminal result"
				)
				_check(
					fixture.guard.receipts.size() == 1 and fixture.guard.unsupported.is_empty(),
					"one supported receipt"
				)
				_clear(fixture)
	_assignment_controls()
	_prior_and_ground()
	_decorative_and_reentrant()
	_binding_and_ambiguity()
	_earned_floor_negative()
	_advancement()
	_pitcher_bounds()
	_callback_negatives()
	_shape_negatives()
	_static_owner_negatives()
	_terminal_contact_negative()
	_check(
		StadiumPoolPartyAssetIntegrity.source_sha256() == _source,
		"source unchanged across unit stage"
	)
	_floor.free()
	print(
		(
			(
				"POOL_WATER_GUARD_UNIT checks=%d failures=%d "
				+ "manual_semantic_controls=true physics_qualified=false source=%s"
			)
			% [_checks, _failures, _source]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(
	role: String,
	active: bool,
	foul: bool = false,
	pitcher: Node3D = null,
	pending: float = 0,
	downstream: Callable = Callable()
) -> Dictionary:
	_outcomes.clear()
	var model: Node3D = StadiumPoolWaterTestSupport.model(self, role)
	var ball: BattedBallBody = StadiumPoolWaterTestSupport.ball(self, Vector3(12, 2, 18))
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), foul)
	resolver.play_resolved.connect(_on_outcome)
	var guard: StadiumPoolWaterGuard = StadiumPoolWaterGuard.new()
	ball.physics_contact_router = downstream
	_check(
		guard.bind(
			ball,
			resolver,
			model,
			role,
			_source,
			StadiumPoolWaterTestSupport.registry(model, _floor),
			active,
			downstream,
			pitcher,
			pending
		),
		"exact private fixture bind"
	)
	return {"model": model, "ball": ball, "resolver": resolver, "guard": guard}


func _start(fixture: Dictionary, velocity: Vector3 = Vector3(0, -4, 0)) -> void:
	StadiumPoolWaterTestSupport.launch(fixture.ball, Vector3(12, 2, 18), velocity)
	_check(
		fixture.guard.generation == 1 and fixture.guard.valid(),
		"public launch binds first generation"
	)


func _manual_wet(fixture: Dictionary, contacts: Array[Dictionary] = []) -> void:
	# Unit-only positioned sample, not a simulated path or synthetic reflection.
	fixture.ball.global_position = Vector3(12, 0.8, 18)
	_route(fixture, contacts)


func _route(fixture: Dictionary, contacts: Array[Dictionary] = []) -> void:
	var guard: StadiumPoolWaterGuard = fixture.guard
	var ball: BattedBallBody = fixture.ball
	guard.route(ball, contacts)


func _bind_live_fixture(fixture: Dictionary, bodies: Array[Dictionary]) -> bool:
	var guard: StadiumPoolWaterGuard = fixture.guard
	var ball: BattedBallBody = fixture.ball
	var resolver: BallPlayResolver = fixture.resolver
	var model: Node3D = fixture.model
	return guard.bind(ball, resolver, model, StadiumPoolContract.LIVE, _source, bodies, true)


func _clear(fixture: Dictionary) -> void:
	for connection: Dictionary in fixture.guard.observed.get_connections():
		fixture.guard.observed.disconnect(connection.callable)
	fixture.guard.detach()
	fixture.ball.free()
	if fixture.model != null:
		fixture.model.free()


func _on_outcome(outcome: BallPlayOutcome) -> void:
	_outcomes.append(outcome)


func _assignment_controls() -> void:
	for foul: bool in [false, true]:
		var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true, foul)
		f.resolver.state.is_fair = foul
		_start(f)
		_manual_wet(f)
		_check(
			(
				_outcomes.size() == 1
				and (
					_outcomes[0].result
					== (BallPlayOutcome.Result.FOUL if foul else BallPlayOutcome.Result.DOUBLE)
				)
			),
			"water uses immutable assignment even when mutable geometric is_fair disagrees"
		)
		_check(f.resolver.state.is_fair == foul, "water does not rewrite geometric classification")
		_clear(f)


func _prior_and_ground() -> void:
	var prior: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	prior.resolver.record_clean_control(&"earlier", Vector3.ZERO, true)
	_start(prior)
	_manual_wet(prior)
	_check(
		(
			_outcomes.size() == 1
			and _outcomes[0].reason == &"fly_catch"
			and prior.guard.receipts.is_empty()
		),
		"prior terminal remains exact"
	)
	_clear(prior)
	var grounded: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	grounded.resolver.record_ground_contact(Vector3(12, 0, 18))
	_start(grounded)
	_manual_wet(grounded, [{"body": _floor, "position": Vector3(12, 0, 18)}])
	_check(
		_outcomes.size() == 1 and grounded.resolver.state.has_grounded,
		"prior ground retained through water"
	)
	_clear(grounded)
	var central: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	_start(central, Vector3(0, -120, 0))
	_manual_wet(central, [{"body": _floor, "position": Vector3(12, 0, 18)}])
	_check(
		_outcomes.size() == 1 and not central.resolver.state.has_grounded,
		"bounded first vertical water-before-floor control"
	)
	_clear(central)
	var ambiguous: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	_start(ambiguous, Vector3(3, -4, 0))
	_manual_wet(ambiguous, [{"body": _floor, "position": Vector3(12.2, 0, 18)}])
	_check(
		_outcomes.is_empty() and _has_reason(ambiguous, "SAME_STEP_GROUND_ORDER_UNPROVEN"),
		"outside/mixed ground history not silently ordered"
	)
	ambiguous.resolver.record_clean_control(
		&"valid_control_not_disabled", ambiguous.ball.global_position, true
	)
	_check(
		_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.OUT,
		"unsupported case does not disable ordinary valid control"
	)
	_clear(ambiguous)


func _decorative_and_reentrant() -> void:
	for role: String in [StadiumPoolContract.SCENERY, "NO_POOL"]:
		var f: Dictionary = _fixture(role, true)
		_start(f)
		_manual_wet(f)
		_check(
			_outcomes.is_empty() and f.guard.receipts.is_empty(), "decorative/no-pool cannot award"
		)
		_clear(f)
	var shadow: Dictionary = _fixture(StadiumPoolContract.LIVE, false)
	_start(shadow)
	_manual_wet(shadow)
	_check(_outcomes.is_empty() and not shadow.resolver.state.dead, "shadow does not change rules")
	_clear(shadow)
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	f.guard.observed.connect(
		func(event: String, _row: Dictionary) -> void:
			if event == "water_commit":
				_route(f)
				f.resolver.record_clean_control(&"reentrant", f.ball.global_position, true)
	)
	_start(f)
	_manual_wet(f)
	_check(
		_outcomes.size() == 1 and f.guard.receipts.size() == 1 and not f.resolver.state.caught,
		"terminal latch precedes reentrant callbacks"
	)
	_clear(f)


func _binding_and_ambiguity() -> void:
	for mutation: String in [
		"state",
		"assignment",
		"floor",
		"scale",
		"ball_scale",
		"radius",
		"shape_radius",
		"nominal_same_shape",
		"router",
		"volume",
		"owner_ground"
	]:
		var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
		_start(f)
		match mutation:
			"state":
				f.resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
			"assignment":
				f.resolver.state.is_foul_play = true
			"floor":
				f.resolver.state.result_floor = BallPlayState.ResultFloor.TRIPLE
			"scale":
				f.model.scale = Vector3(1.01, 1, 1)
			"ball_scale":
				f.ball.scale = Vector3(1.01, 1, 1)
			"radius":
				f.ball.radius_m *= 1.01
			"shape_radius":
				var physical_before: float = _shape(f.ball).shape.radius
				_shape(f.ball).shape.radius += 0.000000004
				_check(
					_shape(f.ball).shape.radius != physical_before,
					"actual shape negative really changes the stored float32 radius"
				)
			"nominal_same_shape":
				var nominal_before: float = f.ball.radius_m
				var unchanged_physical: float = _shape(f.ball).shape.radius
				f.ball.radius_m += 0.000000000001
				_check(f.ball.radius_m != nominal_before, "nominal negative really changes double")
				_check(
					(
						PackedFloat32Array([f.ball.radius_m])[0] == unchanged_physical
						and _shape(f.ball).shape.radius == unchanged_physical
					),
					"nominal mutation preserves float32 conversion and actual shape radius"
				)
			"router":
				f.ball.physics_contact_router = _foreign_router
			"owner_ground":
				_floor.shape_owner_set_disabled(_floor.get_shape_owners()[0], true)
			"volume":
				f.model.get_node(StadiumPoolInteriorV2.VOLUME_ID).position.x = 0.001
		_manual_wet(f)
		_check(
			_outcomes.is_empty() and not f.guard.unsupported.is_empty(),
			"negative altered binding " + mutation
		)
		if mutation == "owner_ground":
			_floor.shape_owner_set_disabled(_floor.get_shape_owners()[0], false)
		_clear(f)
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	_start(f)
	StadiumPoolWaterTestSupport.launch(f.ball, Vector3(12, 2, 18), Vector3.DOWN)
	_check(_has_reason(f, "RELAUNCH_REQUIRES_NEW_RESOLVER_STATE"), "same-state relaunch rejected")
	_manual_wet(f)
	_check(_outcomes.is_empty(), "rejected launch invalidates obsolete generation")
	f.resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), true)
	StadiumPoolWaterTestSupport.launch(f.ball, Vector3(12, 2, 18), Vector3.DOWN)
	_check(f.guard.generation == 2, "new state public launch creates new generation")
	_manual_wet(f)
	_check(
		_outcomes.size() == 1 and _outcomes[0].result == BallPlayOutcome.Result.FOUL,
		"reused unfrozen body honors new foul assignment"
	)
	_clear(f)
	f = _fixture(StadiumPoolContract.LIVE, true)
	_start(f)
	f.ball.global_position = Vector3(12, StadiumPoolContract.WATER_HEIGHT + f.ball.radius_m, 18)
	_route(f)
	_check(
		_outcomes.is_empty() and _has_reason(f, "WATER_BOUNDARY_UNCERTAIN"),
		"tangent uncertainty is explicit"
	)
	_clear(f)
	f = _fixture(StadiumPoolContract.LIVE, true)
	_start(f)
	f.ball.global_position = Vector3(9, .8, 18)
	_route(f)
	f.ball.global_position = Vector3(15, .8, 18)
	_route(f)
	_check(_outcomes.is_empty(), "dry endpoint does not manufacture chord water")
	var considered: Dictionary = f.guard.records[-1]
	_check(
		not considered.detail.dry_to_dry_completeness_qualified,
		"dry-to-dry completeness explicitly false"
	)
	_clear(f)


func _earned_floor_negative() -> void:
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	f.resolver.state.result_floor = BallPlayState.ResultFloor.SINGLE
	_start(f)
	f.resolver.state.result_floor = BallPlayState.ResultFloor.NONE
	_manual_wet(f)
	_check(
		_outcomes.is_empty() and _has_reason(f, "EARNED_FLOOR_REGRESSED"),
		"already earned floor regression invalidates generation"
	)
	f.resolver.state.result_floor = BallPlayState.ResultFloor.SINGLE
	_manual_wet(f)
	_check(_outcomes.is_empty(), "restoring a regressed floor cannot revive contaminated history")
	_clear(f)


func _advancement() -> void:
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	_start(f)
	_manual_wet(f)
	for mask: int in range(8):
		var bases: BaseState = BaseState.new()
		bases.first = &"one" if mask & 1 else &""
		bases.second = &"two" if mask & 2 else &""
		bases.third = &"three" if mask & 4 else &""
		var runs: int = bases.advance_for_hit(_outcomes[0].result, &"batter")
		_check(
			runs == int(bool(mask & 2)) + int(bool(mask & 4)),
			"ordinary Double scoring occupancy " + str(mask)
		)
		_check(
			(
				bases.first == &""
				and bases.second == &"batter"
				and bases.third == (&"one" if mask & 1 else &"")
			),
			"ordinary Double runners occupancy " + str(mask)
		)
	_clear(f)


func _pitcher_bounds() -> void:
	var actor: Node3D = Node3D.new()
	actor.position = Vector3(0, 0, 13.716)
	add_child(actor)
	var wet: Vector3 = Vector3(12, .8, 18)
	var bound: Dictionary = StadiumPoolWaterGuard.pitcher_exclusion(
		wet + Vector3.UP, wet, actor, .1, .0365
	)
	_check(
		not bound.excluded and bound.conditional_chord_excluded and bound.pending_m == .1,
		"actual actor bound stays conditional without controller segment identity"
	)
	actor.position.x = 7
	bound = StadiumPoolWaterGuard.pitcher_exclusion(wet + Vector3(4, 1, 0), wet, actor, .3, .0365)
	_check(
		not bound.excluded and bound.five_metre_target_is_not_actor_bound,
		"detouring actor invalidates assumed 5m proof"
	)
	actor.position = wet
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true, false, actor)
	_start(f)
	_manual_wet(f)
	_check(
		_outcomes.is_empty() and _has_reason(f, "HISTORICAL_PITCHER_ORDER_UNPROVEN"),
		"unbound controller historical catch remains unsupported"
	)
	_clear(f)
	actor.free()


func _callback_negatives() -> void:
	for mutation: String in [
		"recursive",
		"bobbled",
		"ground_position",
		"catch_position",
		"catch_time",
		"contacts",
		"assignment",
		"floor",
		"state",
		"pose",
		"velocity",
		"shape",
		"router",
		"relaunch"
	]:
		var holder: Dictionary = {"calls": 0}
		var downstream: Callable = func(_ball: BattedBallBody, _batch: Array[Dictionary]) -> void:
			var f: Dictionary = holder.fixture
			holder.calls += 1
			if holder.calls > 1:
				return
			match mutation:
				"recursive":
					_route(f)
				"bobbled":
					f.resolver.state.bobbled = true
				"ground_position":
					f.resolver.state.first_ground_position = Vector3.ONE
				"catch_position":
					f.resolver.state.catch_position = Vector3.ONE
				"catch_time":
					f.resolver.state.catch_time = 1.0
				"contacts":
					f.resolver.state.stadium_contacts.append({"injected": true})
				"assignment":
					f.resolver.state.is_foul_play = true
				"floor":
					f.resolver.state.result_floor = BallPlayState.ResultFloor.SINGLE
				"state":
					f.resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
				"pose":
					f.ball.position.x += .01
				"velocity":
					f.ball.linear_velocity.x += .01
				"shape":
					_shape(f.ball).position.x += .01
				"router":
					f.ball.physics_contact_router = _foreign_router
				"relaunch":
					StadiumPoolWaterTestSupport.launch(f.ball, Vector3(12, 2, 18), Vector3.DOWN)
		var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true, false, null, 0, downstream)
		holder.fixture = f
		_start(f)
		_manual_wet(f)
		if mutation == "recursive":
			_check(
				_outcomes.size() == 1 and f.guard.receipts.size() == 1,
				"observational downstream recursion blocked without losing one award"
			)
		else:
			_check(
				_outcomes.is_empty() and _has_reason(f, "DOWNSTREAM_NOT_OBSERVATIONAL"),
				"downstream mutation fails closed " + mutation
			)
			_manual_wet(f)
			_check(_outcomes.is_empty(), "one-shot mutation invalidates later wet routes")
		_clear(f)
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	var attempts: Array[int] = [0]
	f.guard.observed.connect(
		func(event: String, _record: Dictionary) -> void:
			if event == "considered":
				attempts[0] += 1
				f.resolver.state.is_foul_play = true
				f.resolver.state.result_floor = BallPlayState.ResultFloor.HOME_RUN
	)
	_start(f)
	_manual_wet(f)
	_check(
		(
			attempts[0] == 0
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.DOUBLE
		),
		"no considered callback exists in atomic decision interval"
	)
	_clear(f)
	f = _fixture(StadiumPoolContract.LIVE, true)
	f.guard.observed.connect(
		func(event: String, _record: Dictionary) -> void:
			if event == "water_commit":
				f.resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), true)
				StadiumPoolWaterTestSupport.launch(f.ball, Vector3(12, 2, 18), Vector3.DOWN)
	)
	_start(f)
	_manual_wet(f)
	_check(
		(
			_outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.DOUBLE
			and f.guard.generation == 1
			and not f.resolver.state.dead
			and _has_reason(f, "REENTRANT_LAUNCH_REJECTED")
		),
		"postterminal relaunch cannot redirect old receipt into new resolver state"
	)
	_manual_wet(f)
	_check(_outcomes.size() == 1, "reentrant replacement generation remains invalid")
	_clear(f)


func _shape_negatives() -> void:
	for before_bind: bool in [true, false]:
		for mutation: String in [
			"offset",
			"scaled",
			"body_scale",
			"disabled",
			"extra",
			"replacement",
			"owner_pose",
			"owner_disabled"
		]:
			var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
			if before_bind:
				f.guard.detach()
				f.guard = StadiumPoolWaterGuard.new()
			var shape: CollisionShape3D = _shape(f.ball)
			match mutation:
				"offset":
					shape.position.x = .001
				"scaled":
					shape.scale.x = 1.01
				"body_scale":
					f.ball.scale = Vector3(1.01, 1, 1)
				"disabled":
					shape.disabled = true
				"extra":
					var extra: CollisionShape3D = CollisionShape3D.new()
					extra.shape = SphereShape3D.new()
					f.ball.add_child(extra)
				"owner_pose":
					f.ball.shape_owner_set_transform(
						f.ball.get_shape_owners()[0],
						Transform3D(Basis.IDENTITY, Vector3(.001, 0, 0))
					)
				"owner_disabled":
					f.ball.shape_owner_set_disabled(f.ball.get_shape_owners()[0], true)
				"replacement":
					shape.shape = SphereShape3D.new()
					shape.shape.radius = f.ball.radius_m
			if before_bind:
				var accepted: bool = _bind_live_fixture(
					f, StadiumPoolWaterTestSupport.registry(f.model, _floor)
				)
				# Equal fresh SphereShape bytes before capture are a legitimate initial body.
				_check(accepted == (mutation == "replacement"), "initial shape layout " + mutation)
			else:
				_start_after_mutation(f)
				_manual_wet(f)
				_check(_outcomes.is_empty(), "altered captured shape rejects " + mutation)
			_clear(f)


func _shape(ball: BattedBallBody) -> CollisionShape3D:
	for child: Node in ball.get_children():
		if child is CollisionShape3D:
			return child
	return null


func _start_after_mutation(f: Dictionary) -> void:
	StadiumPoolWaterTestSupport.launch(f.ball, Vector3(12, 2, 18), Vector3.DOWN)


func _static_owner_negatives() -> void:
	for target: String in ["ground", "pool"]:
		for mutation: String in ["pose", "disabled", "extra"]:
			var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
			f.guard.detach()
			f.guard = StadiumPoolWaterGuard.new()
			var body: StaticBody3D = (
				_floor if target == "ground" else f.model.get_node("Collision/POOL_INNER_WALL")
			)
			var owner: int = body.get_shape_owners()[0]
			var old_transform: Transform3D = body.shape_owner_get_transform(owner)
			var extra_owner: int = -1
			match mutation:
				"pose":
					body.shape_owner_set_transform(
						owner, Transform3D(Basis.IDENTITY, Vector3(.001, 0, 0))
					)
				"disabled":
					body.shape_owner_set_disabled(owner, true)
				"extra":
					extra_owner = body.create_shape_owner(body)
					body.shape_owner_add_shape(extra_owner, SphereShape3D.new())
			_check(
				not _bind_live_fixture(f, StadiumPoolWaterTestSupport.registry(f.model, _floor)),
				"prebind actual static owner mutation rejected " + target + ":" + mutation
			)
			body.shape_owner_set_transform(owner, old_transform)
			body.shape_owner_set_disabled(owner, false)
			if extra_owner >= 0:
				body.remove_shape_owner(extra_owner)
			_clear(f)


func _terminal_contact_negative() -> void:
	var f: Dictionary = _fixture(StadiumPoolContract.LIVE, true)
	f.guard.detach()
	f.guard = StadiumPoolWaterGuard.new()
	var registry: Array[Dictionary] = StadiumPoolWaterTestSupport.registry(f.model, _floor)
	for entry: Dictionary in registry:
		if entry.body == _floor:
			entry.kind = "terminal"
	_check(_bind_live_fixture(f, registry), "explicit terminal registry bind")
	_start(f)
	_manual_wet(f, [{"body": _floor, "position": Vector3(12, 0, 18)}])
	_check(
		_outcomes.is_empty() and _has_reason(f, "EARLIER_TERMINAL_SOLID_ORDER_UNPROVEN"),
		"unresolved terminal solid cannot be silently outranked by current wet"
	)
	_route(f)
	_check(_outcomes.is_empty(), "terminal history ambiguity persists beyond contact batch")
	_clear(f)


func _foreign_router(_ball: BattedBallBody, _batch: Array[Dictionary]) -> void:
	pass


func _has_reason(fixture: Dictionary, reason: String) -> bool:
	for row: Dictionary in fixture.guard.unsupported:
		if row.reason == reason:
			return true
	return false


func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(label)

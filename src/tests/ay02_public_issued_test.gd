extends Node3D
## Public v3 saved-context controls, reusing the accepted actual fixture and lifecycle APIs.
## Source-only until this scene is run; no fabricated pitches, results, or settlement.
# gdlint: disable=max-returns

const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _cases: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_check(OS.get_cmdline_user_args().is_empty(), "no selectable test arguments")
	var prepared: SeasonState = FIXTURE.season()
	var season: SeasonState = SeasonSave._decode(JSON.parse_string(
		JSON.stringify(SeasonSave.snapshot(prepared), "", true, true))) if prepared != null else null
	_check(season != null and season.npc_venues.version == 3,
		"actual saved v3 five-host season reload")
	if season != null:
		var saved: Dictionary = SeasonSave.snapshot(season)
		await _dynamic_writer(season)
		await _resource(season)
		await _custom(season)
		await _pending(season)
		await _cold(season)
		_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
			"all probes preserve save assignments stock rewards and result history")
	_check(_installs == 5 and _cases == 5, "exact five installed and completed cases")
	await TestAudioDrain.finish(get_tree())
	print("AY02_PUBLIC_ISSUED_REPORT ", JSON.stringify({"schema": "ay02-public-issued-v1",
		"count": _checks, "failures": _failures, "installs": _installs, "cases": _cases,
		"completed_games": 0}))
	if _failures == 0:
		print("AY02_PUBLIC_ISSUED_PASS")
	get_tree().quit(0 if _failures == 0 else 1)


func _lab(season: SeasonState) -> PitchBatLab:
	var fixture: Dictionary = FIXTURE.fixture(season, "AY-02")
	_check(not fixture.is_empty(), "actual AY02 human-away schedule row")
	if fixture.is_empty():
		return null
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	if not lab.yard_bound_startup_failed:
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._at_bat_cadence.stop()
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var valid: bool = not lab.yard_bound_startup_failed and property != null \
		and property.public_bound and property.phase == &"ready" \
		and property.ordinary_callbacks() and property.hot_eligible() and property.callback_intact() \
		and property.public_context_issued() and property.public_snapshot.is_read_only() \
		and property.public_snapshot.binding.is_read_only() \
		and property.public_assignments.is_read_only() \
		and property.public_assignments.assignments.is_read_only() \
		and property.public_fixture.is_read_only() \
		and not lab._match_state.stadium.is_read_only() \
		and not lab._match_state.stadium.binding.is_read_only() \
		and not season.npc_venues.is_read_only() and not season.npc_venues.assignments.is_read_only()
	_check(valid, "genuine public issued ordinary startup")
	if not valid:
		lab.free()
		return null
	_installs += 1
	return lab


func _dynamic_writer(season: SeasonState) -> void:
	var before: int = _failures
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var score: Array = _score(lab)
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		lab._match_state.stadium.binding[key] += 1
		_check(not R._public_context(lab, property, false), "fresh snapshot binding refuses " + key)
		lab._match_state.stadium = snapshot.duplicate(true)
	var seed: int = season.season_seed
	season.season_seed += 1
	_check(not R._public_context(lab, property, false), "fresh season seed refuses")
	season.season_seed = seed
	var run: int = season.career.current
	season.career.current += 1
	_check(not R._public_context(lab, property, false), "fresh career run refuses")
	season.career.current = run
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.assignments.erase(str(snapshot.binding.owner_club))
	_check(not R._public_context(lab, property, false), "removed saved owner refuses")
	season.npc_venues = assignments.duplicate(true)
	season.npc_venues.assignments[str(snapshot.binding.owner_club)].manifest.revision += 1
	_check(not R._public_context(lab, property, false), "changed saved owner snapshot refuses")
	season.npc_venues = assignments.duplicate(true)
	season.npc_venues.environments[str(snapshot.binding.fixture)].seed += 1
	_check(not R._public_context(lab, property, false), "changed saved fixture environment refuses")
	season.npc_venues = assignments
	for row: Dictionary in season.schedule:
		if row.id == snapshot.binding.fixture:
			var home: int = row.home
			row.home = 0
			_check(not R._public_context(lab, property, false), "changed actual schedule row refuses")
			row.home = home
			break
	var state: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, FIXTURE.fixture(season, "AY-02"))
	_check(not R.binding_valid(lab, property, true, false), "replacement MatchState refuses")
	lab._match_state = state
	var actor: PitchFlightActor = lab._pitch_actor
	lab._pitch_actor = PitchFlightActor.new()
	_check(not R.binding_valid(lab, property, true, false), "replacement actor refuses")
	lab._pitch_actor.free()
	lab._pitch_actor = actor
	var camera: Camera3D = lab._camera
	lab._camera = Camera3D.new()
	_check(not R.binding_valid(lab, property, true, false), "replacement camera refuses")
	lab._camera.free()
	lab._camera = camera
	var resolver: BallPlayResolver = lab._ball_play_resolver
	lab._ball_play_resolver = BallPlayResolver.new()
	_check(not R.binding_valid(lab, property, true, false), "replacement resolver refuses")
	lab._ball_play_resolver = resolver
	var router: Callable = actor.receiver_router
	actor.receiver_router = Callable()
	_check(not property.routing_intact(), "removed real receiver callback refuses")
	actor.receiver_router = router
	var observer: Callable = resolver.segment_observer
	resolver.segment_observer = Callable()
	_check(not property.routing_intact(), "removed real resolver callback refuses")
	resolver.segment_observer = observer
	_check(property.callback_intact() and property.ordinary_callbacks()
		and _score(lab) == score, "restored exact context retains ordinary callbacks and score")
	property.retire_installation("test supported static writer")
	_check(property.phase == &"retired", "supported writer retires before changing geometry")
	var body: StaticBody3D = property.receiver.chair.get_node("Collision/ST079_BACK")
	var layer: int = body.collision_layer
	body.collision_layer = 0
	body.collision_layer = layer
	_sticky(lab, property, score, "supported writer")
	await _dispose(lab, before)


func _resource(season: SeasonState) -> void:
	var before: int = _failures
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var score: Array = _score(lab)
	var body: StaticBody3D = property.receiver.chair.get_node("Collision/ST079_BACK")
	var shape: BoxShape3D = (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
	_check(shape != null, "actual receiver collision box exists")
	if shape != null:
		var size: Vector3 = shape.size
		shape.size.x += 0.01
		_check(property.phase == &"retired", "actual Resource.changed retires synchronously")
		shape.size = size
		_sticky(lab, property, score, "resource")
	await _dispose(lab, before)


func _custom(season: SeasonState) -> void:
	var before: int = _failures
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var score: Array = _score(lab)
	lab._pitch_actor.trace_sampled.connect(_custom_trace)
	_check(not property.ordinary_callbacks() and not property.hot_eligible()
		and property.callback_intact(), "extra observer takes valid strict fallback")
	var material: StandardMaterial3D = property.receiver.chair.get_node(
		"Visual/ST079_BACK").material_override
	var roughness: float = material.roughness
	material.roughness = 0.33
	_check(not property.callback_intact(), "custom callback strict audit detects actual material edit")
	material.roughness = roughness
	lab._pitch_actor.trace_sampled.disconnect(_custom_trace)
	_sticky(lab, property, score, "custom callback")
	await _dispose(lab, before)


func _pending(season: SeasonState) -> void:
	var before: int = _failures
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var score: Array = _score(lab)
	_check(R.launch_pitch(lab) and property._play_kind == &"pitch_pending"
		and property.hot_eligible(), "cold launch issues public pending pitch context")
	var old_generation: int = property.play_generation
	R.abandon_launch(lab, old_generation, property)
	_check(R.launch_pitch(lab), "new supported launch supersedes abandoned pending generation")
	var generation: int = property.play_generation
	_check(generation > old_generation and not R.validate_play(lab, old_generation, property)
		and not R.bind_live_pitch(lab, old_generation, property)
		and property.play_generation == generation and property.phase == &"playing"
		and _score(lab) == score, "stale pending continuation cannot mutate current generation")
	_check(R.validate_play(lab, generation, property), "current pending continuation remains valid")
	var state: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, FIXTURE.fixture(season, "AY-02"))
	_check(not R.validate_play(lab, generation, property),
		"pending replacement owner retires before spend")
	lab._match_state = state
	_sticky(lab, property, score, "pending owner")
	await _dispose(lab, before)


func _cold(season: SeasonState) -> void:
	var before: int = _failures
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	var score: Array = _score(lab)
	var material: StandardMaterial3D = property.receiver.chair.get_node(
		"Visual/ST079_BACK").material_override
	var roughness: float = material.roughness
	material.roughness = 0.33
	_check(not R.installed(lab), "explicit installed boundary still performs full material audit")
	material.roughness = roughness
	_sticky(lab, property, score, "cold installed audit")
	await _dispose(lab, before)


func _sticky(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	score: Array, label: String) -> void:
	_check(not property.callback_intact() and property.phase == &"retired"
		and lab.has_meta(R.PUBLIC_BOUND) and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED, "sticky public refusal " + label)
	_check(not R.install_bound(lab) and not R.rebind_match(lab)
		and not R.launch_pitch(lab) and not R.outcome_gate(lab, &"plate"),
		"retired installation cannot reissue launch or score " + label)
	_check(_score(lab) == score and lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "refusal manufactures no gameplay " + label)


func _dispose(lab: PitchBatLab, before: int) -> void:
	var score: Array = _score(lab)
	await get_tree().process_frame
	_check(_score(lab) == score and not lab._pitch_actor.running,
		"deferred interruption preserves score and leaves actor stopped")
	if _failures == before:
		_cases += 1
	lab.free()
	await get_tree().process_frame


func _custom_trace(_point: Vector3) -> void:
	pass


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number, state.pitcher().stamina_remaining]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AY02_PUBLIC_ISSUED " + label)
	print("AY02_PUBLIC_ISSUED_ASSERT ", JSON.stringify(
		{"index": _checks, "name": label, "passed": ok}))

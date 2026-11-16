extends Node3D
## Two practical real installations. No pitches, completed games or per-copy cold rebuild matrix.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const AM = preload("res://src/presentation/stadium/stadium_npc_am01_public_construction.gd")
const FIXTURE = preload("res://src/tests/am01_public_fixture.gd")
var _checks: int = 0
var _failures: int = 0
var _installs: int = 0
var _cases: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_check(not R.install_bound(null) and not R.installed_bound(null, {})
		and not R.bind_ball(null, null, null) and not R.teardown(null),
		"null public operations fail closed")
	_check(R.source_qualified(), "current concrete source family qualifies")
	_status_labels()
	var season: SeasonState = FIXTURE.season()
	_check(season != null, "real explicit ordinal2 saved fixture is available")
	if season != null:
		var saved: Dictionary = SeasonSave.snapshot(season)
		await _lifecycle(season)
		await _writer_retirement(season)
		_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
			"probes preserve actual save, stock, rewards and result history")
	await TestAudioDrain.finish(get_tree())
	print("AM01_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print("AM01_PUBLIC_RUNTIME_COVERAGE installs=%d completed_cases=%d completed_games=0" %
		[_installs, _cases])
	get_tree().quit(0 if _failures == 0 and _installs == 2 and _cases == 2 else 1)


func _status_labels() -> void:
	# One detached retained graph covers malformed inputs; no extra live install is created.
	var property: StadiumNpcPublicProperty = StadiumNpcPublicProperty.new()
	property.venue_id = "AM-01"
	property.construction = StadiumNpcMogulOneV1.build()
	_check(property.construction != null, "status seam has one actual retained construction")
	if property.construction == null:
		property.free()
		return
	property.add_child(property.construction)
	property.objects = property.construction.objects
	var model: Node3D = property.objects["npc:AM-01:r1:BASE-L1"]
	model.set_meta("authoring_status", "Unexpected")
	_check(not AM.normalize_status_labels(property), "unexpected status value refuses")
	model.set_meta("authoring_status", &"Working")
	_check(not AM.normalize_status_labels(property), "unexpected status type refuses")
	model.set_meta("authoring_status", "Working")
	model.set_meta("stadium_item", "ST-081")
	_check(not AM.normalize_status_labels(property), "unexpected Working model refuses")
	model.set_meta("stadium_item", "ST-029")
	model.remove_meta("model_version")
	_check(not AM.normalize_status_labels(property), "missing model version refuses quietly")
	model.set_meta("model_version", 2)
	model.set_meta("npc_instance", "npc:AM-02:r1:BASE-L1")
	_check(not AM.normalize_status_labels(property), "unexpected Working identity refuses")
	model.set_meta("npc_instance", "npc:AM-01:r1:BASE-L1")
	model.set_meta("stadium_candidate_only", false)
	_check(not AM.normalize_status_labels(property), "private marker survives and refuses")
	_check(model.has_meta("stadium_candidate_only"), "normalization never scrubs private authority")
	model.remove_meta("stadium_candidate_only")
	# That rejected candidate had its five known labels removed before the strict origin refusal.
	for identity: String in AM.WORKING_MODELS:
		property.objects[identity].set_meta("authoring_status", "Working")
	_check(AM.normalize_status_labels(property)
		and StadiumMountedScoreboardContract._clean_tree(property),
		"exact five descriptive labels normalize to unchanged strict clean origin")
	for identity: String in AM.WORKING_MODELS:
		_check(not property.objects[identity].has_meta("authoring_status"),
			"only expected installed status label removed " + identity)
	_check(not AM.normalize_status_labels(property), "normalization cannot re-admit missing labels")
	property.free()


func _lab(season: SeasonState) -> PitchBatLab:
	var fixture: Dictionary = FIXTURE.fixture(season)
	_check(not fixture.is_empty(), "actual scheduled AM01 human-away fixture")
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
	var property: StadiumNpcPublicProperty = R._property(lab)
	var positive: bool = not lab.yard_bound_startup_failed and property != null \
		and property.issued and property.ordinary_callbacks() and property.callback_intact()
	_check(positive, "genuine AM01 issued public startup")
	if not positive:
		lab.free()
		return null
	_installs += 1
	return lab


func _lifecycle(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	_check(property.venue_id == "AM-01" and property.tier == "mogul"
		and property.objects.size() == 72 and property.public_bound
		and property.field == lab._field_definition and property.construction.field == property.field
		and property.field.id == &"field.npc_venue", "72-copy AM01 has actual public sport resource")
	_check(not lab.has_meta("stadium_npc_retained_lab_only")
		and not lab.has_meta("stadium_candidate_only") and lab._stadium_ledger == null,
		"public authority has no private marker or human inventory")
	for identity: String in AM.WORKING_MODELS:
		_check(not property.objects[identity].has_meta("authoring_status"),
			"installed exact Working label normalized " + identity)
	var towers: int = 0
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects.get(row.instance)
		_check(model != null and property.construction.is_ancestor_of(model)
			and model.get_meta("npc_instance", "") == row.instance
			and model.get_meta("stadium_item", "") == row.item, "existing exact copy " + row.instance)
		if model != null and row.item == "ST-038":
			towers += 1
			_check(model.get_meta("night_qualified", true) == false
				and model.find_children("*", "Light3D", true, false).is_empty(),
				"existing tower stays dormant " + row.instance)
	_check(towers == 6 and lab._match_state.stadium.environment.mode == "day"
		and lab._match_state.stadium.environment.profile.is_empty(), "six dormant towers and saved day")
	_check(lab._ball_play_resolver.segment_observer == property.observe
		and lab._primary_fielder.stadium_boundary_clip == property.clip
		and lab._primary_fielder.stadium_obstacles == property.route_obstacles(),
		"actual resolver and fielder routes own the installed AM01 boundary")
	_dynamic_refusals(lab, property, season)
	await get_tree().physics_frame
	_receiver_camera(lab, property)
	_check(not R.install_bound(lab) and not R.bind_ball(lab, null, lab._ball_play_resolver),
		"duplicate installation and absent ball refuse")
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(property.field, false)
	_check(R.bind_ball(lab, ball, lab._ball_play_resolver)
		and ball.physics_contact_router.is_valid(), "actual public ball receives AM01 contact router")
	var provenance: Array[Dictionary] = property.provenance.duplicate(true)
	var fake: StaticBody3D = StaticBody3D.new()
	fake.set_meta("npc_instance", "npc:AC-01:r2:RECEIVER-PRIMARY")
	fake.set_meta("surface_id", "ST026_PANEL")
	lab.add_child(fake)
	property._ball_contact(fake, ball, lab._ball_play_resolver)
	_check(property.provenance == provenance and _score(lab) == score,
		"unowned cross-venue body cannot manufacture provenance or a result")
	fake.free()
	_check(property.callback_intact() and R.installed_bound(lab, lab._match_state.stadium),
		"issued callbacks and cold final installation agree")
	_check(not R.teardown(lab), "active actual ball prevents explicit teardown")
	# Keep the real ball alive outside the lab so cleanup of its former route is observable.
	ball.reparent(self)
	lab._batted_ball = null
	_check(R.teardown(lab), "explicit idle public teardown succeeds")
	await get_tree().process_frame
	_check(not ball.physics_contact_router.is_valid() and not R.installed(lab)
		and lab.has_meta(R.PUBLIC_BOUND) and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and not lab.has_meta("stadium_snapshot") and not R.install_bound(lab)
		and PhysicalMatchReport.capture(lab).is_empty() and _score(lab) == score,
		"teardown disconnects actual ball, stays sticky and creates no gameplay evidence")
	_complete_case("lifecycle", before)
	ball.free()
	lab.free()
	await get_tree().process_frame


func _dynamic_refusals(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	season: SeasonState) -> void:
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for key: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		lab._match_state.stadium.binding[key] += 1
		_check(not R.callback_bound(lab, property), "fresh binding refuses " + key)
		lab._match_state.stadium = snapshot.duplicate(true)
	var state: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, FIXTURE.fixture(season))
	_check(not R.callback_bound(lab, property), "replacement MatchState cannot borrow issued owner")
	lab._match_state = state
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.assignments.erase(str(snapshot.binding.owner_club))
	_check(not R.callback_bound(lab, property), "removed saved owner revokes callback authority")
	season.npc_venues = assignments
	for marker: String in ["stadium_candidate_only", "stadium_npc_retained_lab_only"]:
		lab.set_meta(marker, false)
		_check(not R.callback_bound(lab, property), "private marker presence refuses " + marker)
		lab.remove_meta(marker)
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = Callable()
	_check(not R.callback_bound(lab, property), "missing actual resolver route refuses")
	lab._ball_play_resolver.segment_observer = observer
	var router: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = Callable()
	_check(not R.callback_bound(lab, property), "missing actual receiver route refuses")
	lab._pitch_actor.receiver_router = router
	property.display.bind_match(null)
	_check(not R.callback_bound(lab, property), "detached live scoreboard refuses")
	property.display.bind_match(state)
	var mask: int = lab._camera.cull_mask
	lab._camera.cull_mask = 0
	_check(not R.callback_bound(lab, property), "changed actual camera mask refuses")
	lab._camera.cull_mask = mask
	_check(property.callback_intact(), "restored dynamic operands retain valid issued installation")


func _receiver_camera(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	_check(property.receiver != null and property.display != null
		and property.display._match == lab._match_state and property.receiver.sounds == lab._sounds
		and lab._pitch_actor.receiver_router == property.receiver_route
		and lab._camera_director.get_script() == StadiumNpcAm01PublicCamera,
		"actual AM01 receiver, camera and scoreboard are paired")
	for sample: Array in [[Vector3(0, 1.3, 0), "ST026_PANEL"],
		[Vector3(1.5, 1.3, 0), "ST073_CENTER_NET"]]:
		var path: Dictionary = property.receiver.trace(sample[0], Vector3(0, 0, -40), 0.0365)
		_check(path.hit.get("surface") == sample[1]
			and String(path.hit.get("copy", "")).begins_with("npc:AM-01:r1:"),
			"real earliest receiver surface has exact r1 copy identity")
	_check(lab._camera_director.tracking_visibility != null
		and lab._camera_director.tracking_visibility.property == property,
		"actual camera visibility refers to installed AM01 property")


func _writer_retirement(season: SeasonState) -> void:
	var before: Array[int] = [_checks, _failures]
	var lab: PitchBatLab = _lab(season)
	if lab == null:
		return
	var property: StadiumNpcPublicProperty = R._property(lab)
	var score: Array = _score(lab)
	property.retire_installation("AM01 test supported writer")
	_check(property.suspended and not property.issued and not property.callback_intact()
		and lab.has_meta(R.PUBLIC_BOUND) and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED, "supported writer retires issued authority")
	_check(not R.rebind_match(lab) and not R.install_bound(lab)
		and PhysicalMatchReport.capture(lab).is_empty() and _score(lab) == score
		and lab._throw_number == 0 and lab._play_records.is_empty(),
		"retired AM01 cannot silently reissue, fall back or produce a report")
	_complete_case("writer-retirement", before)
	lab.free()
	await get_tree().process_frame


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AM01_PUBLIC_RUNTIME " + label)


func _complete_case(label: String, before: Array[int]) -> void:
	if _checks > before[0] and _failures == before[1]:
		_cases += 1
	print("AM01_PUBLIC_CASE case=%s checks=%d failures=%d" %
		[label, _checks - before[0], _failures - before[1]])

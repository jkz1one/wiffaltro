extends Node3D
## Focused actual public startup/physical ownership/lifecycle checks; no pitches or full games.

const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
const FORGED_BODY = preload("res://src/tests/stadium_npc_bound_forged_body.gd")
const IDS: Array[String] = ["AY-01", "AE-01", "AC-01"]
const COUNTS: Dictionary = {"AY-01": 4, "AE-01": 27, "AC-01": 72}
var _checks: int = 0
var _failures: int = 0
var _installed_families: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	_check(not R.install_bound(null) and not R.installed_bound(null, {})
		and not R.teardown(null), "null public operations fail closed")
	_check(R.source_qualified(), "current concrete retained mechanics/source pins qualify")
	var season: SeasonState = _season()
	if season.npc_venues.is_empty():
		_check(false, "new Base map required before runtime startup")
		_finish()
		return
	var saved: Dictionary = SeasonSave.snapshot(season)
	for id: String in IDS:
		await _lifecycle(season, id)
	for id: String in IDS:
		await _sticky_integrity(season, id)
	await _interrupted(season)
	_raw_private_refusal(season)
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"all focused probes preserve actual save, stock, rewards and result history")
	await TestAudioDrain.finish(get_tree())
	_finish()


func _season() -> SeasonState:
	var season: SeasonState = SeasonState.create(10, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "actual career starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = SeasonVenues.capture_five(10, season.career.current, 0)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "actual draft choice %d" % pick)
	return season


func _fixture(season: SeasonState, id: String) -> Dictionary:
	for fixture: Dictionary in season.schedule:
		if fixture.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season, fixture)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return fixture.duplicate(true)
	return {}


func _lab(season: SeasonState, fixture: Dictionary) -> PitchBatLab:
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
	return lab


func _lifecycle(season: SeasonState, id: String) -> void:
	var fixture: Dictionary = _fixture(season, id)
	_check(not fixture.is_empty(), "actual scheduled human-away fixture " + id)
	if fixture.is_empty():
		return
	var lab: PitchBatLab = _lab(season, fixture)
	var property: StadiumNpcPublicProperty = R._property(lab)
	# Positive installation first: an all-negative suite must never hide failed admission.
	_check(not lab.yard_bound_startup_failed and property != null
		and R.installed_bound(lab, lab._match_state.stadium), "ordinary public startup " + id)
	if property == null or not R.installed(lab):
		lab.free()
		return
	_installed_families += 1
	_identity(lab, property)
	_context(lab, property, season, fixture)
	_geometry(lab, property)
	_callbacks(lab, property)
	if id != "AY-01":
		_receiver_camera_board(lab, property)
	_check(not R.install_bound(lab), "duplicate public installation refuses " + id)
	_check(lab._throw_number == 0 and lab._play_records.is_empty()
		and PhysicalMatchReport.capture(lab).is_empty(), "startup/probes create no result evidence")
	var score: Array = _score(lab)
	_check(R.teardown(lab), "idle public teardown " + id)
	await get_tree().process_frame
	_check(lab.has_meta(R.PUBLIC_BOUND) and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and not lab.has_meta("stadium_snapshot") and not R.installed(lab)
		and not R.install_bound(lab) and PhysicalMatchReport.capture(lab).is_empty()
		and _score(lab) == score, "public teardown is sticky interruption, never fallback " + id)
	lab.free()
	await get_tree().process_frame


func _identity(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var id: String = property.venue_id
	_check(property.public_bound and property.objects.size() == COUNTS[id]
		and property.callback_intact(), "concrete family and current callback ownership " + id)
	_check(not lab.has_meta("stadium_npc_retained_lab_only")
		and not lab.has_meta("stadium_candidate_only") and lab._stadium_ledger == null,
		"no private qualification or human ownership " + id)
	_check(property.field == lab._field_definition
		and property.construction.field == property.field
		and property.field.id == &"field.npc_venue", "actual installed sport resource " + id)
	for row: Dictionary in lab._match_state.stadium.manifest.instances:
		var model: Node3D = property.objects.get(row.instance)
		_check(model != null and property.construction.is_ancestor_of(model)
			and model.get_meta("npc_instance", "") == row.instance
			and model.get_meta("stadium_item", "") == row.item, "actual revision2 model " + row.instance)
	_check(lab._ball_play_resolver.segment_observer == property.observe
		and lab._primary_fielder.stadium_boundary_clip == property.clip
		and lab._primary_fielder.stadium_obstacles == property.route_obstacles(),
		"real resolver/fielder routes bind installed property " + id)
	if id == "AY-01":
		_check(property.receiver == null and property.display == null
			and property.route_obstacles().is_empty()
			and not lab._pitch_actor.receiver_router.is_valid(), "AY01 free receiver/zero obstacles")


func _context(lab: PitchBatLab, property: StadiumNpcPublicProperty,
	season: SeasonState, fixture: Dictionary) -> void:
	_check(R._public_context(lab, property) and R._public_context(lab, property, false),
		"cold and fresh callback authority agree")
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for field: String in ["owner_club", "fixture", "match_seed", "environment_seed", "career_run"]:
		lab._match_state.stadium.binding[field] += 1
		_check(not R._public_context(lab, property, false), "changed live binding refuses " + field)
		lab._match_state.stadium = snapshot.duplicate(true)
	lab._match_state.stadium.environment.seed = snapshot.binding.match_seed
	_check(not R._public_context(lab, property), "saved environment cannot borrow match seed")
	lab._match_state.stadium = snapshot.duplicate(true)
	var actual: MatchState = lab._match_state
	lab._match_state = SeasonPhysicalFixtures.match_for(season, fixture)
	_check(not R.installed_bound(lab, snapshot), "same bytes on replacement MatchState refuse")
	lab._match_state = actual
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.assignments.erase(str(fixture.home))
	_check(not R._public_context(lab, property, false), "removed saved owner revokes hot authority")
	season.npc_venues = assignments
	for marker: String in ["stadium_npc_retained_lab_only", "stadium_candidate_only"]:
		lab.set_meta(marker, false)
		_check(not R._public_context(lab), "private marker presence refuses " + marker)
		lab.remove_meta(marker)
	if property.venue_id == "AE-01":
		for other: Dictionary in season.schedule:
			var other_snapshot: Dictionary = SeasonVenues.for_fixture(season, other)
			if other.away == 0 and other.home != fixture.home and not other_snapshot.is_empty() \
				and other_snapshot.manifest.id == "AE-01":
				lab._match_state.stadium = other_snapshot
				_check(not R.installed_bound(lab, other_snapshot),
					"same AE01 geometry from second club cannot inherit runtime authority")
				break
	lab._match_state.stadium = snapshot.duplicate(true)
	_check(R.installed_bound(lab, snapshot), "exact original authority restores after probes")


func _geometry(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var model: Node3D = property.objects.values()[0]
	var pose: Transform3D = model.transform
	model.position.x += 0.01
	_check(not R.installed(lab), "actual model transform mutation refuses")
	model.transform = pose
	var ground: StaticBody3D = property.construction.get_node("PropertyGround")
	var layer: int = ground.collision_layer
	ground.collision_layer = 0
	_check(not R.installed(lab), "disabled actual collision layer refuses")
	ground.collision_layer = layer
	_check(R.installed(lab) and property.callback_intact(), "exact physical geometry restores")


func _callbacks(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var observer: Callable = lab._ball_play_resolver.segment_observer
	lab._ball_play_resolver.segment_observer = Callable()
	_check(not R.installed(lab), "missing live observer refuses")
	lab._ball_play_resolver.segment_observer = observer
	var clip: Callable = lab._primary_fielder.stadium_boundary_clip
	lab._primary_fielder.stadium_boundary_clip = Callable()
	_check(not R.installed(lab), "missing live defender clip refuses")
	lab._primary_fielder.stadium_boundary_clip = clip
	_check(property.callback_intact(), "actual live callback ownership restores")


func _receiver_camera_board(lab: PitchBatLab, property: StadiumNpcPublicProperty) -> void:
	var club: bool = property.venue_id == "AC-01"
	var script: Script = StadiumClubCameraDirector if club else StadiumExpandedCameraDirector
	_check(property.receiver != null and property.display != null
		and property.display._match == lab._match_state
		and property.receiver.sounds == lab._sounds
		and lab._pitch_actor.receiver_router == property.receiver_route
		and lab._camera_director.get_script() == script, "real paired receiver/camera/board")
	var prefix: String = "npc:" + property.venue_id + ":r2:"
	var samples: Array = [[Vector3(0, 1.3, 0), "ST026_PANEL"],
		[Vector3(1.5 if club else 1.0, 1.3, 0), "ST073_CENTER_NET" if club else "ST025_NET"]]
	for sample: Array in samples:
		var path: Dictionary = property.receiver.trace(sample[0], Vector3(0, 0, -40), 0.0365)
		_check(path.hit.get("surface") == sample[1]
			and String(path.hit.get("copy", "")).begins_with(prefix),
			"actual earliest receiver surface and revision2 identity")
	var visibility: StadiumNpcRetainedVisibility = lab._camera_director.tracking_visibility
	_check(visibility != null and visibility.property == property
		and visibility._recipe.segments() == property.view_graph().segments(),
		"actual camera visibility uses exact family graph")
	var receiver: Callable = lab._pitch_actor.receiver_router
	lab._pitch_actor.receiver_router = Callable()
	_check(not R.installed(lab), "missing real receiver callback refuses")
	lab._pitch_actor.receiver_router = receiver
	property.display.bind_match(null)
	_check(not R.installed(lab), "detached scoreboard match binding refuses")
	property.display.bind_match(lab._match_state)
	_check(R.installed(lab), "actual receiver and scoreboard restore")


func _sticky_integrity(season: SeasonState, id: String) -> void:
	# One destructive failure per family; revoked public installations are never repaired in place.
	var fixture: Dictionary = _fixture(season, id)
	if fixture.is_empty():
		return
	var lab: PitchBatLab = _lab(season, fixture)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(property != null and R.installed(lab), "destructive integrity positive control " + id)
	if property == null or not R.installed(lab):
		lab.free()
		return
	var before: Array = _score(lab)
	var ground: StaticBody3D = property.construction.get_node("PropertyGround")
	if id == "AY-01":
		var shape: CollisionShape3D = ground.get_child(0)
		var size: Vector3 = (shape.shape as BoxShape3D).size
		(shape.shape as BoxShape3D).size.x = _next_float32(size.x)
		_check(not R.installed(lab), "one-float32-ULP actual collision mutation refuses")
		(shape.shape as BoxShape3D).size = size
	elif id == "AE-01":
		var original: Variant = ground.get_script()
		ground.set_script(FORGED_BODY)
		_check(not R.installed(lab), "equal-value body with untrusted behavior script refuses")
		ground.set_script(original)
	else:
		var observer: Callable = lab._ball_play_resolver.segment_observer
		lab._ball_play_resolver.segment_observer = Callable()
		_check(not property.callback_intact(), "hot callback mutation revokes public authority")
		lab._ball_play_resolver.segment_observer = observer
	_check(property.suspended and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED and not R.installed(lab)
		and not R.rebind_match(lab) and not R.install_bound(lab)
		and PhysicalMatchReport.capture(lab).is_empty() and _score(lab) == before,
		"restoring bytes cannot resume revoked public authority " + id)
	lab.free()
	await get_tree().process_frame


func _interrupted(season: SeasonState) -> void:
	var fixture: Dictionary = _fixture(season, "AC-01")
	if fixture.is_empty():
		return
	var lab: PitchBatLab = _lab(season, fixture)
	var property: StadiumNpcPublicProperty = R._property(lab)
	_check(property != null and R.installed(lab), "separate genuine interruption positive control")
	if property == null or not R.installed(lab):
		lab.free()
		return
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._batted_ball = ball
	lab._ball_play_resolver.start_play(property.field, false)
	_check(R.bind_ball(lab, ball, lab._ball_play_resolver)
		and ball.physics_contact_router.is_valid(), "actual lab ball receives public contact router")
	var before: Array = _score(lab)
	var provenance: Array[Dictionary] = property.provenance.duplicate(true)
	var fake: StaticBody3D = StaticBody3D.new()
	fake.set_meta("npc_instance", property.objects.keys()[0])
	fake.set_meta("surface_id", "SpectatorSeat")
	lab.add_child(fake)
	property._ball_contact(fake, ball, lab._ball_play_resolver)
	_check(property.provenance == provenance and _score(lab) == before,
		"forged noncolliding body cannot manufacture provenance or a baseball outcome")
	fake.free()
	ball.reparent(self)
	lab._batted_ball = null
	property.get_parent().remove_child(property)
	await get_tree().process_frame
	_check(lab.has_meta(R.PUBLIC_BOUND) and lab.has_meta("stadium_npc_runtime_interrupted")
		and lab.process_mode == Node.PROCESS_MODE_DISABLED
		and not ball.physics_contact_router.is_valid()
		and not R.install_bound(lab) and PhysicalMatchReport.capture(lab).is_empty()
		and _score(lab) == before, "unexpected property removal disconnects ball and forbids fallback")
	property.free()
	ball.free()
	lab.free()
	await get_tree().process_frame


func _raw_private_refusal(season: SeasonState) -> void:
	var fixture: Dictionary = _fixture(season, "AY-01")
	if fixture.is_empty():
		return
	for marker: String in ["", "stadium_candidate_only", "stadium_npc_retained_lab_only"]:
		var lab: PitchBatLab = PitchBatLab.new()
		lab._sky_backdrop_enabled = false
		lab._configured_match = SeasonPhysicalFixtures.match_for(season, fixture)
		lab._npc_season = season
		lab._managed_match = true
		lab._field_id = &"field.npc_venue"
		if marker.is_empty():
			lab._configured_match.stadium = StadiumNpcSnapshot.raw_entry("AY-01", 2)
		else:
			lab.set_meta(marker, true)
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		_check(R._property(lab) == null and not R.install_bound(lab)
			and PhysicalMatchReport.capture(lab).is_empty(), "raw/private origin cannot authorize public")
		lab.free()


func _next_float32(value: float) -> float:
	var bytes: PackedByteArray = PackedFloat32Array([value]).to_byte_array()
	bytes.encode_u32(0, bytes.decode_u32(0) + 1)
	return bytes.decode_float(0)


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("BASE_PUBLIC_RUNTIME " + label)


func _finish() -> void:
	print("BASE_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	print("BASE_PUBLIC_COVERAGE_RUNTIME installed_families=%d" % _installed_families)
	get_tree().quit(0 if _failures == 0 else 1)

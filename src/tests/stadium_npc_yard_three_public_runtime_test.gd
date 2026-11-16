extends Node3D
## Small R13-style startup/context/teardown checks. No pitch, terminal match or camera suite.

const R = preload("res://src/presentation/stadium/stadium_npc_yard_three_runtime_v1.gd")
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check(not R.install_bound(null) and not R.installed_bound(null, {}), "null public refusal")
	var season: SeasonState = _season()
	var fixture: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.away == 0 and row.home == 3:
			fixture = row.duplicate(true)
			break
	_check(not fixture.is_empty(), "seed443 actual saved AY03 human-away fixture")
	if fixture.is_empty():
		_finish()
		return
	var saved: Dictionary = SeasonSave.snapshot(season)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab._configured_match = _state(season, fixture)
	lab._npc_season = season
	lab._field_id = &"field.npc_venue"
	lab._managed_match = true
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	if not lab.yard_bound_startup_failed:
		PitchBatLabFeelSupport.skip_match_presentation(lab)
		lab._at_bat_cadence.stop()
	var property: StadiumNpcYardThreePropertyV1 = R._property(lab)
	_check(not lab.yard_bound_startup_failed and property != null
		and R.installed_bound(lab, lab._match_state.stadium), "ordinary startup installs public AY03")
	if property != null:
		_check(property.public_bound and property.objects.size() == 8
			and property.route_obstacles().is_empty() and lab._primary_fielder.stadium_obstacles.is_empty()
			and property.receiver == null and property.display == null
			and not lab._pitch_actor.receiver_router.is_valid(),
			"eight decorative copies, zero obstacles and ordinary free receiver")
		_check(not lab.has_meta(R.OPT_IN) and not lab.has_meta(R.RETAINED_OPT_IN)
			and not lab.has_meta("stadium_candidate_only"), "public install needs no private flags")
		_check(lab._throw_number == 0 and lab._play_records.is_empty()
			and StadiumNpcYardThreeReport.capture(lab).is_empty(), "startup creates no result evidence")
		_dormant_lights(property)
		_context(lab, property, season)
		var original: MatchState = lab._match_state
		lab._match_state = _state(season, fixture)
		_check(not R.installed_bound(lab, original.stadium) and not R.rebind_match(lab),
			"same-fixture replacement MatchState cannot inherit public installation")
		lab._match_state = original
		_check(R.installed_bound(lab, original.stadium), "original bound state remains installed")
		_check(not R.install(lab) and not R.install_bound(lab), "private and public reentry refuse")
		var before: Array = _score(lab)
		_check(R.teardown(lab), "idle public teardown succeeds")
		await get_tree().process_frame
		_check(lab.has_meta("stadium_npc_runtime_interrupted") and lab.has_meta(R.PUBLIC_BOUND)
			and not lab.has_meta("stadium_snapshot") and lab.process_mode == Node.PROCESS_MODE_DISABLED
			and not R.install_bound(lab) and _score(lab) == before,
			"public removal stays interrupted without inventing an outcome")
	_check(ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"startup and teardown preserve real save, assignment, stock and rewards")
	lab.free()
	await get_tree().process_frame
	_private_quarantine()
	await TestAudioDrain.finish(get_tree())
	_finish()


func _dormant_lights(property: StadiumNpcYardThreePropertyV1) -> void:
	var lights: int = 0
	for identity: String in property.objects:
		var model: Node3D = property.objects[identity]
		if model.get_meta("stadium_item", "") != "ST-037":
			continue
		lights += 1
		var beam: SpotLight3D = model.get_node("FieldLight")
		var lens: MeshInstance3D = model.get_node("Visual/LampLens")
		var material: StandardMaterial3D = lens.material_override as StandardMaterial3D
		_check(not beam.visible and material != null and not material.emission_enabled,
			"public day leaves retained lamp dormant " + identity)
	_check(lights == 4, "all four dormant lamps inspected")


func _season() -> SeasonState:
	var season: SeasonState = SeasonState.create(443, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "actual working career starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = SeasonVenues.capture(season.season_seed, season.career.current)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "actual draft choice %d" % pick)
	return season


func _state(season: SeasonState, fixture: Dictionary) -> MatchState:
	var state: MatchState = MatchState.create(
		season._make_team(int(fixture.away)), season._make_team(int(fixture.home)))
	state.stadium = SeasonVenues.for_fixture(season, fixture)
	return state


func _context(lab: PitchBatLab, property: StadiumNpcYardThreePropertyV1,
	season: SeasonState) -> void:
	_check(R._public_context(lab, property) and R._public_context(lab, property, false),
		"cold and hot public context both match actual saved assignment")
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for field: String in ["fixture", "match_seed", "owner_club", "career_run"]:
		lab._match_state.stadium.binding[field] += 1
		_check(not R._public_context(lab, property, false), "hot changed binding refuses " + field)
		lab._match_state.stadium = snapshot.duplicate(true)
	lab._match_state.stadium.binding.venue_id = "AY-02"
	_check(not R._public_context(lab), "public binding cannot borrow AY02 identity")
	lab._match_state.stadium = snapshot.duplicate(true)
	lab._match_state.stadium = StadiumNpcSnapshot.raw_entry("AY-01", 2)
	_check(not R._public_context(lab), "raw16 cannot enter public adapter")
	lab._match_state.stadium = snapshot.duplicate(true)
	lab._match_state.stadium.environment.mode = "night"
	_check(not R._public_context(lab), "public adapter refuses unqualified night")
	lab._match_state.stadium = snapshot.duplicate(true)
	for flag: String in [R.OPT_IN, R.RETAINED_OPT_IN, "stadium_candidate_only"]:
		lab.set_meta(flag, false)
		_check(not R._public_context(lab), "private-origin flag presence refuses " + flag)
		lab.remove_meta(flag)
	var map: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.clear()
	_check(not R._public_context(lab, property, false), "saved assignment removal refuses hot")
	season.npc_venues = map
	lab._npc_season = null
	_check(not R._public_context(lab), "missing saved season refuses")
	lab._npc_season = season
	_check(R._public_context(lab, property), "exact context restores after non-mutating negatives")


func _private_quarantine() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab.set_meta(R.OPT_IN, true)
	lab.set_meta(R.RETAINED_OPT_IN, true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	lab._at_bat_cadence.stop()
	_check(R.install(lab) and R.installed(lab), "private explicit-opt-in adapter still installs")
	_check(not R.install_bound(lab) and not R.installed_bound(lab, {})
		and PhysicalMatchReport.capture(lab).is_empty(),
		"private installation cannot produce public report")
	_check(R.teardown(lab) and lab.get_meta(R.OPT_IN) == true
		and lab.get_meta(R.RETAINED_OPT_IN) == true and PhysicalMatchReport.capture(lab).is_empty(),
		"private-origin report quarantine survives teardown")
	lab.free()


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number]


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("AY03_PUBLIC_RUNTIME " + label)


func _finish() -> void:
	print("AY03_PUBLIC_RUNTIME checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

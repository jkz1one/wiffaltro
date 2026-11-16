extends Node3D
## Focused public/private admission and context/lifecycle regression, no fabricated outcome.

const R = preload("res://src/presentation/stadium/stadium_npc_yard_two_runtime_v1.gd")
var _checks: Array[Dictionary] = []
var _failures: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check(not R.install_bound(null) and not R.installed_bound(null, {}), "null bound refusal")
	var season: SeasonState = _season()
	var fixture: Dictionary = _fixture(season)
	_check(not fixture.is_empty(), "genuine saved AY02 away fixture exists")
	if fixture.is_empty():
		_finish()
		return
	var lab: PitchBatLab = _public_lab(season, fixture)
	_check(not lab.yard_bound_startup_failed and R.installed_bound(lab, lab._match_state.stadium),
		"managed public startup installs before delivery")
	var property: StadiumNpcYardTwoPropertyV1 = R._property(lab)
	if property != null:
		_check(property.public_bound and lab._field_id == &"field.npc_venue",
			"public property uses exact NPC field")
		_check(not lab.has_meta(R.OPT_IN) and not lab.has_meta(R.RETAINED_OPT_IN) \
			and not lab.has_meta("stadium_candidate_only"), "no private authority laundering")
		_context_guards(lab, property, season, fixture)
		_check(not R.install(lab) and not R.install_bound(lab), "reentrant private/public refuse")
		var state: MatchState = lab._match_state
		var replacement: MatchState = _state(season, fixture)
		lab._match_state = replacement
		_check(not R.binding_valid(lab, property), "replacement MatchState cannot reuse installation")
		lab._match_state = state
		_check(R.installed_bound(lab, state.stadium), "non-mutating refusal preserves real owner")
		lab._at_bat_cadence.stop()
		lab._throw_pitch()
		_check(lab._pitch_actor.running and property.phase == &"playing",
			"ordinary public pitch obtains live owner and play ticket")
		var before: Array = _score(lab)
		var assignments: Dictionary = season.npc_venues.duplicate(true)
		season.npc_venues.clear()
		_check(not R.outcome_gate(lab, &"plate") and _score(lab) == before,
			"live lost assignment interrupts before recording an outcome")
		await get_tree().process_frame
		_check(not lab._pitch_actor.running and property.phase == &"retired" \
			and _score(lab) == before, "deferred live cleanup does not manufacture result")
		season.npc_venues = assignments
		_check(R.teardown(lab), "idle public teardown cleans physical installation")
		await get_tree().process_frame
		_check(lab.has_meta("stadium_npc_runtime_interrupted") \
			and lab.process_mode == Node.PROCESS_MODE_DISABLED \
			and not lab.has_meta("stadium_snapshot"), "public removal cannot resume on starter host")
		_check(not R.launch_pitch(lab) and not R.outcome_gate(lab, &"plate") \
			and _score(lab) == before, "interrupted fixture cannot invent pitch or outcome")
	lab.free()
	await get_tree().process_frame
	_private_control()
	await _ai_start_control(season)
	await TestAudioDrain.finish(get_tree())
	_finish()


func _season() -> SeasonState:
	var season: SeasonState = SeasonState.create(4, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	season.career = ClubCareer.new()
	_check(ClubPlayerDraft.apply(season, ClubPlayers.owned(season.career)), "actual starter access")
	_check(season.career.start(season), "real working career starts")
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(season.career))
	season.npc_venues = SeasonVenues.capture(season.season_seed, season.career.current)
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "genuine draft pick %d" % pick)
	return season


func _fixture(season: SeasonState) -> Dictionary:
	for row: Dictionary in season.schedule:
		if row.away == 0 and SeasonVenues.for_fixture(season, row).get(
			"manifest", {}).get("id") == "AY-02":
			return row.duplicate(true)
	return {}


func _state(season: SeasonState, fixture: Dictionary) -> MatchState:
	var state: MatchState = MatchState.create(
		season._make_team(int(fixture.away)), season._make_team(int(fixture.home)))
	state.stadium = SeasonVenues.for_fixture(season, fixture)
	return state


func _public_lab(season: SeasonState, fixture: Dictionary) -> PitchBatLab:
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
	return lab


func _context_guards(lab: PitchBatLab, property: StadiumNpcYardTwoPropertyV1,
	season: SeasonState, fixture: Dictionary) -> void:
	_check(R._public_context(lab, property, false), "fresh public hot context is exact")
	var snapshot: Dictionary = lab._match_state.stadium.duplicate(true)
	for field: String in ["fixture", "match_seed", "owner_club", "career_run"]:
		lab._match_state.stadium.binding[field] += 1
		_check(not R._public_context(lab, property, false), "changed binding refused: " + field)
		lab._match_state.stadium = snapshot.duplicate(true)
	for version: int in [16, 17, 18]:
		lab._match_state.stadium.version = version
		_check(not R._public_context(lab, property), "nonfixture19 version refused: %d" % version)
		lab._match_state.stadium = snapshot.duplicate(true)
	lab._match_state.stadium.environment.mode = "night"
	_check(not R._public_context(lab, property), "unqualified night mode refused")
	lab._match_state.stadium = snapshot.duplicate(true)
	lab._npc_season = null
	_check(not R._public_context(lab, property), "missing saved season authority refused")
	lab._npc_season = season
	var assignments: Dictionary = season.npc_venues.duplicate(true)
	season.npc_venues.clear()
	_check(not R._public_context(lab, property, false), "saved assignment removal refused hot")
	season.npc_venues = assignments
	lab.set_meta(R.OPT_IN, false)
	_check(not R._public_context(lab, property), "even false private-origin marker refused")
	lab.remove_meta(R.OPT_IN)
	lab._player_home = true
	_check(not R._public_context(lab, property), "wrong managed batting side refused")
	lab._player_home = false
	lab._automation = MatchAutomation.new()
	lab._automation.seed = int(snapshot.binding.match_seed)
	_check(R._public_context(lab), "managed input automation has exact fresh seed context")
	_check(not R._public_context(lab, property, false),
		"adding automation after installation still refuses pinned lifetime")
	lab._automation.seed += 1
	_check(not R._public_context(lab), "managed input automation wrong seed refused")
	lab._automation = null
	_check(R._public_context(lab, property) \
		and StadiumNpcSnapshot.matches_fixture(snapshot, season, fixture),
		"exact saved context restored after non-mutating checks")


func _ai_start_control(season: SeasonState) -> void:
	var fixture: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.away != 0 and row.home != 0 and SeasonVenues.for_fixture(season, row).get(
			"manifest", {}).get("id") == "AY-02":
			fixture = row.duplicate(true)
			break
	_check(not fixture.is_empty(), "genuine scheduled AI AY02 host fixture exists")
	if fixture.is_empty():
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	_check(not before.is_empty() and before.get("version") == 61,
		"AI startup comparison begins with actual complete save61")
	if before.is_empty():
		return
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	_check(state != null and state.stadium.get("manifest", {}).get("id") == "AY-02",
		"selected AI fixture really carries exact AY02 manifest")
	var seed: int = SeasonPhysicalFixtures.seed_for(season, fixture)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	_check(not runner.start(state, seed, &"field.npc_venue"),
		"AI AY02 start requires saved season authority")
	_check(not runner.start(state, seed + 1, &"field.npc_venue", null, {}, season),
		"AI AY02 start rejects wrong fixture seed")
	var started: bool = runner.start(state, seed, &"field.npc_venue", null, {}, season)
	_check(started and runner._lab != null and not runner._lab._managed_match
		and R.installed_bound(runner._lab, state.stadium),
		"actual PhysicalMatchRunner installs selected AI away venue")
	var live: WeakRef = weakref(runner._lab) if runner._lab != null else null
	runner.cancel()
	await get_tree().process_frame
	_check(not runner._running and runner._lab == null and runner._viewport == null
		and (live == null or live.get_ref() == null)
		and ClubCareer.same(before, SeasonSave.snapshot(season)),
		"cancelled AI startup leaves saved season and results unchanged")
	runner.free()


func _private_control() -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._sky_backdrop_enabled = false
	lab.set_meta(R.OPT_IN, true)
	lab.set_meta(R.RETAINED_OPT_IN, true)
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	_check(R.install(lab) and R.installed(lab), "private opt-in installation remains valid")
	_check(not R.installed_bound(lab, {}) and not R.install_bound(lab),
		"private installation cannot become public evidence")
	_check(R.teardown(lab) and lab.get_meta(R.RETAINED_OPT_IN) == true \
		and lab.get_meta(R.OPT_IN) == true, "private teardown keeps report quarantine")
	lab.free()


func _score(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [state.phase, state.inning, state.top_half, state.balls, state.strikes, state.outs,
		state.away_team.runs, state.home_team.runs, state.plate_appearance_number,
		lab._play_records.size(), lab._throw_number]


func _check(ok: bool, label: String) -> void:
	_checks.append({"name": label, "passed": ok})
	if not ok:
		_failures += 1
		push_error(label)
	print("AY02_PUBLIC_RUNTIME_ASSERT ", JSON.stringify(_checks[-1]))


func _finish() -> void:
	print("AY02_PUBLIC_RUNTIME_REPORT ", JSON.stringify({
		"checks": _checks, "failures": _failures, "count": _checks.size()}))
	if _failures == 0:
		print("AY02_PUBLIC_RUNTIME_PASS")
	get_tree().quit(0 if _failures == 0 else 1)

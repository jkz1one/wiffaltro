extends Node
## Admission-only setup: two neutral participant orientations, no earned bracket or played game.
## Reuse the explicit pre-draft record; never save synthetic final phase/participants.

const FIXTURE = preload("res://src/tests/long_yard_public_fixture.gd")
const R = preload("res://src/presentation/stadium/stadium_npc_public_runtime.gd")
var _checks: int = 0
var _failures: int = 0
var _starts: int = 0
var _refusals: int = 0
var _admitted: int = 0
var _app: SeasonApp


func _ready() -> void:
	var save_path: String = SeasonSave.path
	var settings_path: String = PitchBatLabSettings.path
	SeasonSave.path = "user://long-yard-admission-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://long-yard-admission-%d.cfg" % OS.get_process_id()
	_check(not FileAccess.file_exists(SeasonSave.path)
		and not FileAccess.file_exists(SeasonSave.path + ".bak"), "isolated absent save inputs")
	if _failures == 0:
		await _run()
	if is_instance_valid(_app):
		_app._close_match()
		_app.queue_free()
		await get_tree().process_frame
	_check(not FileAccess.file_exists(SeasonSave.path)
		and not FileAccess.file_exists(SeasonSave.path + ".bak"),
		"admission-only phase/participants were never saved or activated through new-season UI")
	SeasonSave.path = save_path
	PitchBatLabSettings.path = settings_path
	await TestAudioDrain.finish(get_tree())
	_check(_starts == 2 and _admitted == 2 and _refusals == 16,
		"exact two successful installations and sixteen pre-install refusals")
	print("LONG_YARD_NEUTRAL_ENTRY checks=%d failures=%d starts=%d admitted=%d refusals=%d games=0" %
		[_checks, _failures, _starts, _admitted, _refusals])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	_app = SeasonApp.new()
	add_child(_app)
	_app.set_process(false)
	_app.child_entered_tree.connect(func(node: Node) -> void:
		if node is PitchBatLab:
			_starts += 1)
	for player_home: bool in [true, false]:
		var season: SeasonState = FIXTURE.season()
		_check(season != null, "actual draft and explicit fixed final record exist")
		if season == null:
			return
		# Admission-only authoring seam. This does not claim earned semifinal results or save62 replay.
		FIXTURE.fixture(season, player_home)
		season.phase = SeasonState.Phase.FINAL
		_app.season = season
		_app._fixture_id = 32
		var state: MatchState = season.make_match()
		_check(state != null and state.stadium.get("version") == 20
			and StadiumNpcSnapshot.matches_fixture(state.stadium, season, season.pending_fixture()),
			"exact synthetic participant fixture binds saved neutral snapshot20")
		if state == null or _failures != 0:
			return
		var opening: String = "You pitch first" if player_home else "You bat first"
		_check(SeasonPages.venue(season.pending_fixture(), season)
			== "Neutral final • Long Yard • " + opening
			and StadiumFixtureEnvironment.label(season, season.pending_fixture()) == "16:10 • Clear",
			"season-aware final label names actual Long Yard and retains independent batting order")
		_reject(state, not player_home, true, &"field.npc_venue", "flipped player role")
		if player_home and _failures == 0:
			_common_refusals(season, state)
		if _failures != 0:
			return
		var before: Dictionary = _season_data(season)
		_app.notice = ""
		_app._open_match(state, player_home, true, &"field.npc_venue")
		var lab: PitchBatLab = _app.lab
		_check(lab != null and not lab.yard_bound_startup_failed,
			"actual SeasonApp entry admits exact neutral participant orientation")
		if lab == null:
			return
		_check(StadiumPropertyRuntime.npc_installed_bound(lab, state.stadium),
			"public installed wrapper accepts exact saved neutral snapshot20 for both player roles")
		lab.set_process(false)
		lab.set_physics_process(false)
		lab._at_bat_cadence.stop()
		var property: StadiumNpcPublicProperty = R._property(lab)
		_check(lab._managed_match and lab._npc_season == season and lab._player_home == player_home
			and lab._stadium_ledger == null and property != null and property.issued
			and property.objects.size() == 67 and property.venue_id == "LONG-YARD"
			and R.installed_bound(lab, state.stadium) and _app._played_field_matches(),
			"managed app owns issued neutral field without borrowing player-owned inventory")
		_check(state.stadium.binding.venue_owner == SeasonFinalVenue.OWNER
			and state.stadium.binding.batting_home == (0 if player_home else 1)
			and state.stadium.binding.away == (1 if player_home else 0)
			and state.stadium.environment.profile == StadiumLongYardEnvironmentV1.PROFILE
			and StadiumNpcYardTwoHumanEvidence.expected(season, season.pending_fixture())
			and PhysicalStadiumReport.npc_resolver(state.stadium) == StadiumLongYardPublicReport.RESOLVER,
			"same saved final binding selects human evidence2 and report18 routes for both roles")
		_check(ClubCareer.same(before, _season_data(season)) and lab._play_records.is_empty()
			and PhysicalMatchReport.capture(lab).is_empty()
			and StadiumNpcYardTwoHumanEvidence.capture(lab, season).is_empty(),
			"admission leaves results, reports, ledgers and saved assignments unchanged")
		if _failures == 0:
			_admitted += 1
		var live: WeakRef = weakref(lab)
		_app._close_match()
		await get_tree().process_frame
		_check(_app.lab == null and live.get_ref() == null,
			"ordinary app close disposes each admitted lab before the next case")
		if _failures != 0:
			return


func _common_refusals(season: SeasonState, state: MatchState) -> void:
	_reject(state, true, false, &"field.npc_venue", "exhibition cannot borrow final record")
	_reject(state, true, true, PitchBatLab.FIELD_ID, "wrong field cannot borrow final record")
	_app.season = null
	_reject(state, true, true, &"field.npc_venue", "missing season refuses")
	_app.season = season
	var final_record: Dictionary = season.final_venue.duplicate(true)
	season.final_venue = {}
	var commons: String = ContentDB.get_field(SeasonState.AWAY_FIELD_ID).display_name
	_check(SeasonPages.venue(season.pending_fixture(), season)
		== "Neutral final • %s • You pitch first" % commons
		and SeasonPages.venue(season.pending_fixture())
		== "Neutral final • %s • You pitch first" % commons,
		"absent final record and legacy no-season call retain exact Commons label")
	_reject(state, true, true, &"field.npc_venue", "missing explicit final record refuses")
	season.final_venue = final_record.duplicate(true)
	season.final_venue.environment.profile = "foreign"
	_check(SeasonPages.venue(season.pending_fixture(), season)
		== "Neutral final • Unavailable venue • You pitch first",
		"invalid saved final record cannot borrow Long Yard label")
	_reject(state, true, true, &"field.npc_venue", "changed saved profile refuses")
	season.final_venue = final_record
	var snapshot: Dictionary = state.stadium.duplicate(true)
	for operand: String in ["venue_owner", "fixture", "batting_home", "neutral", "manifest_key",
		"profile", "sun"]:
		match operand:
			"venue_owner": state.stadium.binding.venue_owner = "npc-owner:1"
			"fixture": state.stadium.binding.fixture = 31
			"batting_home": state.stadium.binding.batting_home = 1
			"neutral": state.stadium.binding.neutral = false
			"manifest_key": state.stadium.manifest_key = "0".repeat(64)
			"profile": state.stadium.environment.profile = ""
			"sun": state.stadium.environment.lighting.sun_energy = 2
		_reject(state, true, true, &"field.npc_venue", "changed final " + operand)
		state.stadium = snapshot.duplicate(true)
		if _failures != 0:
			return
	var fixture: Dictionary = season.final_fixture.duplicate(true)
	season.final_fixture = {"id": 32, "round": 11, "home": 1, "away": 2, "neutral": true}
	var spectator: MatchState = season.make_match()
	_check(spectator != null and StadiumNpcSnapshot.matches_fixture(
		spectator.stadium, season, season.pending_fixture()), "non-player final control is fully bound")
	if spectator != null:
		_reject(spectator, false, true, &"field.npc_venue", "non-player final cannot open human slot")
	season.final_fixture = fixture
	season.phase = SeasonState.Phase.REGULAR
	var ordinary: MatchState = season.make_match()
	_check(ordinary != null and ordinary.stadium.get("version") == 19
		and season.pending_fixture().away == 0, "ordinary-away control retains exact snapshot19")
	if ordinary != null:
		_check(SeasonPages.venue(season.pending_fixture(), season)
			== "Away • %s • You bat first" % ContentDB.get_field(&"field.npc_venue").display_name,
			"ordinary public-away label is byte-for-byte unchanged")
		_reject(ordinary, true, true, &"field.npc_venue", "ordinary public home remains forbidden")
	season.phase = SeasonState.Phase.FINAL


func _reject(state: MatchState, player_home: bool, managed: bool,
	field_id: StringName, label: String) -> void:
	if _failures != 0:
		return
	var before: Dictionary = _season_data(_app.season)
	var children: Array[Node] = _app.get_children()
	var starts: int = _starts
	var prior_season: SeasonState = _app.season
	_app.notice = ""
	_app._open_match(state, player_home, managed, field_id)
	var refused: bool = _app.lab == null and _starts == starts and not _app.notice.is_empty()
	_check(refused and _app.season == prior_season and _app.get_children() == children
		and ClubCareer.same(before, _season_data(_app.season)),
		"entry refuses before installing or mutating season: " + label)
	if refused:
		_refusals += 1


func _season_data(season: SeasonState) -> Dictionary:
	if season == null:
		return {}
	return {"final_venue": season.final_venue.duplicate(true),
		"npc_venues": season.npc_venues.duplicate(true),
		"home_property": season.home_property.duplicate(true),
		"fixture": season.final_fixture.duplicate(true), "phase": season.phase,
		"results": season.results.duplicate(true),
		"player_results": season.player_results.duplicate(true),
		"physical": season.physical.to_data(), "career": season.career.to_data(),
		"build": season.build.to_data(), "opponents": season.opponents.to_data()}


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("LONG_YARD_NEUTRAL_ENTRY " + label)

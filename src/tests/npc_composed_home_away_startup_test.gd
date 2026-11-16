extends Node3D
## Genuine scheduled fixtures, no fixture/result mutation or synthetic contact evidence.

const FIXTURE = preload("res://src/tests/ac02_public_fixture.gd")
var failures: int = 0
var starts: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var season: SeasonState = FIXTURE.season()
	if season == null:
		push_error("COMPOSED_STARTUP genuine season unavailable")
		get_tree().quit(1)
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	var away: Dictionary = FIXTURE.fixture(season)
	var home: Dictionary = {}
	for scheduled: Dictionary in season.schedule:
		if scheduled.home == 0:
			home = scheduled.duplicate(true)
			break
	for fixture: Dictionary in [home, away]:
		if fixture.is_empty():
			failures += 1
			continue
		var player_home: bool = fixture.home == 0
		var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
		var lab: PitchBatLab = PitchBatLab.new()
		lab._sky_backdrop_enabled = false
		lab._configured_match = state
		lab._npc_season = null if player_home else season
		lab._stadium_ledger = ClubPlayers.assets(season.career) if player_home else null
		lab._field_id = SeasonState.field_for_fixture(fixture, season).id
		lab._player_home = player_home
		lab._managed_match = true
		add_child(lab)
		lab.set_process(false)
		lab.set_physics_process(false)
		var installed: bool = not lab.yard_bound_startup_failed and lab._match_state == state
		if player_home:
			installed = installed and lab.has_meta("stadium_snapshot") \
				and lab.get_meta("stadium_snapshot") == state.stadium
		else:
			installed = installed and StadiumNpcPublicRuntime.installed_bound(lab, state.stadium)
		if not installed or lab._throw_number != 0 or not lab._play_records.is_empty() \
			or not PhysicalMatchReport.capture(lab).is_empty():
			failures += 1
		else:
			starts += 1
		print("COMPOSED_STARTUP side=", "home" if player_home else "away", " installed=", installed)
		lab.free()
		await get_tree().process_frame
	if not ClubCareer.same(before, SeasonSave.snapshot(season)):
		failures += 1
	await TestAudioDrain.finish(get_tree())
	print("COMPOSED_STARTUP starts=%d failures=%d completed_games=0" % [starts, failures])
	get_tree().quit(0 if starts == 2 and failures == 0 else 1)

extends "res://src/tests/stadium_mounted_scoreboard_celebration_test.gd"
## Genuine HR/pause/restart after ordinary _ready installed an actual earned mounted fixture.

const EarnedFixture = preload("res://src/tests/stadium_mounted_scoreboard_season_fixture.gd")
var _earned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SeasonSave.path = "user://mounted-normal-celebration-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://mounted-normal-celebration-%d.cfg" % OS.get_process_id()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await get_tree().process_frame
	var data: EarnedFixture = EarnedFixture.new()
	data.prepare(app, _check)
	var fixture: Dictionary = {}
	for candidate: Dictionary in app.season.schedule:
		if candidate.home == 0:
			fixture = candidate
			break
	_earned = {"ledger": ClubPlayers.assets(app.season.career),
		"entry": app.season.home_property.duplicate(true),
		"fixture": StadiumLayoutSnapshot.for_fixture(app.season, fixture)}
	var held: Dictionary = SeasonSave.snapshot(app.season)
	app.menu.hide()
	await _real_carry(false)
	await _real_carry(true)
	_check(_carries == 2 and ClubCareer.same(held, SeasonSave.snapshot(app.season)),
		"two real normal-startup HR lifecycles cannot settle or reward the earned career")
	app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted normal celebration passed: earned startup, actual HR and pause/restart.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(_shape: String) -> Dictionary:
	return _earned


func _carry_lab(data: Dictionary, managed: bool) -> PitchBatLab:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = MatchLabSupport.create_match(PitchBatLab.DEBUG_PLAYER_ID, "RIVETS", "YARD")
	lab._configured_match.stadium = data.fixture.duplicate(true)
	lab._stadium_ledger = data.ledger
	lab._automation = MatchAutomation.new()
	lab._automation.seed = int(data.fixture.environment.seed)
	lab._managed_match = managed
	lab._sky_backdrop_enabled = false
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	_check(lab._at_bat_cadence.state == AtBatCadenceController.State.DELIVERY
		and not lab._pitch_actor.running and StadiumBoundaryRuntime.installed(lab, data.fixture),
		"ordinary startup binds earned proof, complete world and scorer before real HR flight")
	return lab


func _carry_public_check(lab: PitchBatLab, _managed: bool) -> void:
	_check(lab._stadium_ledger == _earned.ledger
		and StadiumBoundaryRuntime.installed(lab, _earned.fixture),
		"actual HR and pause retain the whole paid prefix through public installed-world checks")


func _valid(lab: PitchBatLab, data: Dictionary) -> bool:
	return StadiumBoundaryRuntime.installed(lab, data.fixture)

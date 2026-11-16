extends Node
## Admission-owner predicates only; no paid stadium construction or physical game.
const MainScene = preload("res://src/presentation/season/season_app.tscn")
const Startup = preload("res://src/presentation/stadium/stadium_npc_ac02_startup_preparing_v1.gd")
const Night = preload("res://src/presentation/stadium/stadium_surface_night_runtime_inputs.gd")
class ForeignApp extends SeasonApp:
	pass
var checks: int = 0
var failures: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func _ready() -> void:
	_case(SeasonApp.new(), true, "original owner")
	_case(MainScene.instantiate(), true, "actual main scene")
	_case(ForeignApp.new(), false, "unqualified subclass")
	print("MAIN_RUNTIME_IDENTITY: %d checks, %d failures; physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

func _case(app: SeasonApp, admitted: bool, label: String) -> void:
	# Keep nodes detached so no UI, save, world, or match startup is invoked.
	var lab: PitchBatLab = PitchBatLab.new()
	app.season = SeasonState.new()
	app.lab = lab
	app._season_game = true
	app._fixture_id = 7
	lab._managed_match = true
	lab._npc_season = app.season
	lab._configured_match = MatchState.new()
	check((app.get_script() == SeasonApp) == admitted, label + " exact native app identity")
	check(Startup._enrollment_owners(app, lab) == admitted, label + " AC02 detached enrollment owner")
	app.add_child(lab)
	var night: StadiumSurfaceNightRuntime = StadiumSurfaceNightRuntime.new()
	night._season = app.season
	night._fixture_id = 7
	check(Night._caller(night, lab) == admitted, label + " managed night caller")
	app._fixture_id = 8
	check(not Night._caller(night, lab), label + " wrong fixture remains refused")
	app._fixture_id = 7
	app._season_game = false
	check(not Night._caller(night, lab), label + " nonseason caller remains refused")
	night = null
	app.free()

extends Node
## Bounded malformed-envelope controls; no authoring of physical evidence.
const Home = preload("res://src/gameplay/season/dynasty_league_home_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	for input: Variant in [null, [], "save", {}, {"home_property": []}, {"home_property": null}]:
		check(Home.qualify(input, {}).is_empty(), "malformed envelope denied")
	var season: SeasonState = SeasonState.create(96001, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season._league_home_context = {"grant": [], "home_property": {}}
	check(Home.capture(season).is_empty(), "wrong-type grant fails without script error")
	check(not season.league_context_consistent(), "wrong-type grant cannot admit gameplay context")
	season._league_home_context = {"grant": {}, "home_property": []}
	check(Home.capture(season).is_empty(), "wrong-type frozen home fails without script error")
	print("DYNASTY_LEAGUE_HOME_SHAPE: %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

extends Node
## Bounded shared seating/appearance/light/receiver allowlist and unchanged public admission gates.
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	for version: int in range(1, 70):
		for operation: String in ["stadium_draft", "stadium_apply"]:
			check(Assets.supported({"op": operation, "layout": {"version": version}}) == (version in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 14, 15]), "only explicitly adapted shared families")
	for version: Variant in [null, false, true, "2", 2.5, -1, 70]:
		check(not Assets.supported({"op": "stadium_draft", "layout": {"version": version}}), "malformed or unknown family rejects")
	var season: SeasonState = SeasonState.new()
	season.phase = SeasonState.Phase.COMPLETE
	var draft: Dictionary = {"op": "stadium_draft", "layout": {"version": 2}}
	var apply: Dictionary = {"op": "stadium_apply", "layout": {"version": 2}}
	check(Assets.allowed(season, {"op": "stadium_draft", "layout": {"version": 3}})
		and Assets.allowed(season, {"op": "stadium_apply", "layout": {"version": 3}}), "completed shared season permits staged appearance")
	check(Assets.allowed(season, draft) and Assets.allowed(season, apply), "completed shared season permits staged seating")
	for version: int in [6, 7, 8, 9]:
		check(Assets.allowed(season, {"op": "stadium_draft", "layout": {"version": version}})
			and Assets.allowed(season, {"op": "stadium_apply", "layout": {"version": version}}),
			"completed shared season permits explicitly adapted light/receiver family")
	season.phase = SeasonState.Phase.DRAFT
	check(Assets.allowed(season, draft) and not Assets.allowed(season, apply), "ordinary physical access apply requirement retained")
	season.physical = SeasonPhysicalFixtures.new()
	season.player_access.append("probe")
	check(not Assets.allowed(season, apply), "legacy field cannot apply seating without complete boundary")
	season.home_property = {"boundary": {}}
	check(Assets.allowed(season, draft) and Assets.allowed(season, apply), "complete-boundary pre-draft shared seating passes pure gate")
	for version: int in [4, 5, 10]:
		check(Assets.allowed(season, {"op": "stadium_draft", "layout": {"version": version}})
			and Assets.allowed(season, {"op": "stadium_apply", "layout": {"version": version}}), "complete-boundary pre-draft display and ground use public admission")
	season.picks.append("probe")
	check(not Assets.allowed(season, draft) and not Assets.allowed(season, apply), "first pick locks both operations")
	for version: int in [6, 7, 8, 9]:
		check(not Assets.allowed(season, {"op": "stadium_draft", "layout": {"version": version}})
			and not Assets.allowed(season, {"op": "stadium_apply", "layout": {"version": version}}),
			"first pick locks light/receiver family")
	season.picks.clear()
	season.physical.pending = {"fixture": 0}
	check(not Assets.allowed(season, draft) and not Assets.allowed(season, apply), "physical pending locks both operations")
	check(season.career == null, "pure shared gates never install a sequential career")
	check(not Assets.allowed(null, draft) and not Assets.allowed(null, apply), "absent season fails controlled")
	print("SHARED_SEATING_CONTRACT checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

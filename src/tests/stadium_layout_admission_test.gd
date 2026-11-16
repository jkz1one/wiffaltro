extends Node
## Pure public layout gates only. No owner admission, save or physical game claim.
var checks: int = 0
var failures: int = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _ready() -> void:
	for phase: int in range(5):
		for admitted: bool in [false, true]:
			for picked: bool in [false, true]:
				var season: SeasonState = SeasonState.new()
				season.phase = phase
				if picked: season.picks.append("probe")
				var editing: bool = phase == SeasonState.Phase.COMPLETE or (phase == SeasonState.Phase.DRAFT and not picked)
				check(ClubConstruction.draft_admission(season, {"version": 1}, admitted).ok == (admitted and editing), "draft phase/owner window")
				check(not ClubConstruction.editable(season), "pure phase does not invent ordinary career")
				check(ClubConstruction.apply_admission(season, {"version": 1}, admitted).ok == (admitted and phase == SeasonState.Phase.COMPLETE), "apply requires complete or physical access")
				season.physical = SeasonPhysicalFixtures.new()
				season.player_access.append("probe")
				check(ClubConstruction.apply_admission(season, {"version": 1}, admitted).ok == (admitted and editing), "physical draft apply window")
				season.physical.pending = {"fixture": 0}
				check(not ClubConstruction.draft_admission(season, {"version": 1}, admitted).ok, "pending blocks draft")
				check(not ClubConstruction.apply_admission(season, {"version": 1}, admitted).ok, "pending blocks apply")
	var season: SeasonState = SeasonState.new()
	season.phase = SeasonState.Phase.COMPLETE
	check(ClubConstruction.draft_admission(season, {"version": 13}, true).ok == StadiumAdvancedWallLayout.RUNTIME_READY, "advanced draft public flag")
	check(ClubConstruction.apply_admission(season, {"version": 13}, true).ok == StadiumAdvancedWallLayout.RUNTIME_READY, "advanced apply public flag")
	check(ClubConstruction.apply_admission(season, {"version": 12}, true).ok == StadiumSurfaceLayout.RUNTIME_READY, "surface apply public flag")
	season.owned_surface_night = {"probe": true}
	check(not ClubConstruction.draft_admission(season, {"version": 17}, true).ok, "night terrain draft refusal")
	check(not ClubConstruction.apply_admission(season, {"version": 17}, true).ok, "night terrain apply refusal")
	check(not ClubConstruction.draft_admission(null, {"version": 1}, true).ok, "null draft fails controlled")
	check(not ClubConstruction.apply_admission(null, {"version": 1}, true).ok, "null apply fails controlled")
	print("LAYOUT_ADMISSION checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

class_name AISwingPlanTimingProbe
extends OpponentTacticalProbe
## Observes original paid physical swings, without changing decisions or outcomes.

var seen: Dictionary = {}
var samples: Array[Dictionary] = []


func observe(lab: PitchBatLab, check: Callable) -> void:
	super.observe(lab, check)
	if lab == null or lab._match_state == null or not lab._swing_tracker.active:
		return
	var state: MatchState = lab._match_state
	var locked: StringName = state.batting_team().tactics.locked_swing(state)
	if locked == &"" or lab._batter_approach._plan.is_empty():
		return
	var key: int = lab._batter_approach._delivery_seed
	if seen.has(key):
		return
	seen[key] = true
	var plan: Dictionary = lab._batter_approach._plan
	var profile: SwingProfileDefinition = ContentDB.get_swing(locked)
	var delta: float = plan.start_time + profile.sweet_spot_seconds - plan.contact_time
	samples.append({"seed": key, "lock": String(locked), "use_power": plan.use_power,
		"timing_mismatch_seconds": delta, "pa": state.plate_appearance_number})
	check.call(is_zero_approx(delta), "paid locked swing schedules its own sweet spot")

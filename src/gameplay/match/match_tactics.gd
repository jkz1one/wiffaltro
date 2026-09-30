class_name MatchTactics
extends RefCounted
# gdlint: disable=max-returns
## Detached pregame copies. Only completed results settle their use into the season.

const COMBO: String = "A10+C03"

var held: Array[Dictionary] = []
var consumed: Array[Dictionary] = []
var insured_receipt: String = ""
var track_walks: bool = false
var checkout: MatchLateCheckout = MatchLateCheckout.new()
var _combo_used: bool = false
var _recovered: Array[String] = []
var _used_pa: int = 0
var _active_pa: int = 0
var _active: String = ""
var _swing: StringName = &""
var _heat_pitcher: PlayerMatchState


func reason(
	state: MatchState, team: TeamMatchState, receipt: String, swing: StringName = &""
) -> String:
	if state.phase != MatchState.Phase.PRE_PITCH or not state.between_batters:
		return "Use only before the first pitch of a plate appearance."
	if team.tactics != self or (team != state.away_team and team != state.home_team):
		return "Choose a club playing this game."
	if _used_pa == state.plate_appearance_number:
		return "This club already used a supply this plate appearance."
	var id: String = _item(receipt)
	if id.is_empty():
		return "That tactical copy is no longer held."
	if id in ["C02", SeasonTacticalCatalog.HEAT]:
		if team != state.defensive_team():
			return "Recovery Pack and Extra Heat are used by the defending club."
		if state.pitcher().pitching_finished:
			return "This pitcher has been removed."
	elif team != state.batting_team():
		return "This supply is used by the batting club."
	if id == "C02":
		var pitcher: PlayerMatchState = state.pitcher()
		if pitcher.pitching_finished or _recovered.has(String(pitcher.definition.id)):
			return "This pitcher cannot use another Recovery Pack this game."
		if pitcher.stamina_remaining >= pitcher.stamina_max:
			return "The active pitcher already has full stamina."
	if id == SeasonTacticalCatalog.BASE and TacticalBaseAdvance.target(state.bases).is_empty():
		return TacticalBaseAdvance.describe(state, {})
	if id == "C03" and swing not in [&"swing.contact", &"swing.power"]:
		return "Choose Contact or Power for this entire plate appearance."
	if id != "C03" and swing != &"":
		return "Only Swing Plan locks a swing."
	return ""


func activate(
	state: MatchState, team: TeamMatchState, receipt: String, swing: StringName = &""
) -> bool:
	if not reason(state, team, receipt, swing).is_empty():
		return false
	checkout.clear()
	var id: String = _item(receipt)
	var player: PlayerMatchState = (
		state.pitcher() if id in ["C02", SeasonTacticalCatalog.HEAT] else state.batter()
	)
	if id == "C02":
		player.stamina_remaining = minf(
			player.stamina_max, player.stamina_remaining + 0.10 * player.stamina_max
		)
		_recovered.append(String(player.definition.id))
	if id == SeasonTacticalCatalog.HEAT:
		_heat_pitcher = player
	_active = id
	_active_pa = state.plate_appearance_number
	_used_pa = _active_pa
	_swing = swing
	consumed.append(
		{
			"receipt": receipt,
			"player": String(player.definition.id),
			"pa": _active_pa,
			"swing": String(swing)
		}
	)
	_insure(team, receipt)
	if id == SeasonTacticalCatalog.BASE:
		consumed[-1]["advance"] = TacticalBaseAdvance.apply(state)
	for index in range(held.size()):
		if held[index].id == receipt:
			held.remove_at(index)
			break
	return true


func active(state: MatchState) -> String:
	if _active == SeasonTacticalCatalog.HEAT and state.pitcher() != _heat_pitcher:
		pitcher_changed()
	return (
		_active
		if _active_pa == state.plate_appearance_number and state.phase != MatchState.Phase.GAME_END
		else ""
	)


func locked_swing(state: MatchState) -> StringName:
	return _swing if active(state) in ["C03", COMBO] else &""


func _item(receipt: String) -> String:
	for copy: Dictionary in held:
		if copy.id == receipt and SeasonTacticalCatalog.catalog().has(copy.item):
			return copy.item
	return ""


static func swing(profile: SwingProfileDefinition, state: MatchState) -> SwingProfileDefinition:
	var effect: String = state.batting_team().tactics.active(state)
	if effect in ["A10", COMBO]:
		profile.contact_radius_x_m *= 1.08
		profile.contact_radius_y_m *= 1.08
		profile.gear_fair_exit_scale *= 0.95
	if effect in ["C03", COMBO] and profile.id == state.batting_team().tactics.locked_swing(state):
		profile.tactical_quality_exit_scale = 1.06
	return profile


func pitcher_changed() -> void:
	if _active == SeasonTacticalCatalog.HEAT:
		_active = ""
		_heat_pitcher = null


static func pitch(source: PitchDefinition, state: MatchState) -> PitchDefinition:
	if state.defensive_team().tactics.active(state) != SeasonTacticalCatalog.HEAT:
		return source
	var result: PitchDefinition = source.duplicate() as PitchDefinition
	result.nominal_velocity_mps *= 1.05
	return result


func combo_copies() -> Array[String]:
	var pair: Array[String] = []
	for id: String in ["A10", "C03"]:
		for copy: Dictionary in held:
			if copy.item == id:
				pair.append(copy.id)
				break
	return pair


func combo_reason(
	state: MatchState, team: TeamMatchState, pair: Array[String], swing: StringName
) -> String:
	if pair.size() != 2 or _item(pair[0]) != "A10" or _item(pair[1]) != "C03":
		return "Double Booking needs one owned Tape and one owned Plan."
	if not team.current_batter().definition.season_sponsors.get("E07", false):
		return "Double Booking must be active."
	if _combo_used:
		return "Double Booking was already used this game."
	var error: String = reason(state, team, pair[0])
	return error if not error.is_empty() else reason(state, team, pair[1], swing)


func activate_combo(
	state: MatchState, team: TeamMatchState, pair: Array[String], swing: StringName
) -> bool:
	if not combo_reason(state, team, pair, swing).is_empty():
		return false
	activate(state, team, pair[0])
	consumed[-1]["combo"] = true
	consumed.append(
		{
			"receipt": pair[1],
			"player": String(state.batter().definition.id),
			"pa": _active_pa,
			"swing": String(swing),
			"combo": true
		}
	)
	_insure(team, pair[1])
	for index in range(held.size()):
		if held[index].id == pair[1]:
			held.remove_at(index)
			break
	_active = COMBO
	_swing = swing
	_combo_used = true
	return true


func _insure(team: TeamMatchState, receipt: String) -> void:
	if (
		receipt == insured_receipt
		and team.current_batter().definition.season_sponsors.get("E04", false)
	):
		consumed[-1]["insured"] = true

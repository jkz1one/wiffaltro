class_name MatchTactics
extends RefCounted
# gdlint: disable=max-returns
## Detached pregame copies. Only completed results settle their use into the season.

var held: Array[Dictionary] = []
var consumed: Array[Dictionary] = []
var _recovered: Array[String] = []
var _used_pa: int = 0
var _active_pa: int = 0
var _active: String = ""
var _swing: StringName = &""


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
	if id == "C02":
		if team != state.defensive_team():
			return "Recovery Pack is used by the defending club."
		var pitcher: PlayerMatchState = state.pitcher()
		if pitcher.pitching_finished or _recovered.has(String(pitcher.definition.id)):
			return "This pitcher cannot use another Recovery Pack this game."
		if pitcher.stamina_remaining >= pitcher.stamina_max:
			return "The active pitcher already has full stamina."
	elif team != state.batting_team():
		return "Grip Tape and Swing Plan are used by the batting club."
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
	var id: String = _item(receipt)
	var player: PlayerMatchState = state.pitcher() if id == "C02" else state.batter()
	if id == "C02":
		player.stamina_remaining = minf(
			player.stamina_max, player.stamina_remaining + 0.10 * player.stamina_max
		)
		_recovered.append(String(player.definition.id))
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
	for index in range(held.size()):
		if held[index].id == receipt:
			held.remove_at(index)
			break
	return true


func active(state: MatchState) -> String:
	return (
		_active
		if _active_pa == state.plate_appearance_number and state.phase != MatchState.Phase.GAME_END
		else ""
	)


func locked_swing(state: MatchState) -> StringName:
	return _swing if active(state) == "C03" else &""


func _item(receipt: String) -> String:
	for copy: Dictionary in held:
		if copy.id == receipt and SeasonTacticalCatalog.ITEMS.has(copy.item):
			return copy.item
	return ""


static func swing(profile: SwingProfileDefinition, state: MatchState) -> SwingProfileDefinition:
	var effect: String = state.batting_team().tactics.active(state)
	if effect == "A10":
		profile.contact_radius_x_m *= 1.08
		profile.contact_radius_y_m *= 1.08
		profile.gear_fair_exit_scale *= 0.95
	elif effect == "C03" and profile.id == state.batting_team().tactics.locked_swing(state):
		profile.tactical_quality_exit_scale = 1.06
	return profile

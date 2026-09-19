class_name TeamMatchState
extends RefCounted

const ROSTER_SIZE: int = 4

var display_name: String = "Team"
var roster: Array[PlayerMatchState] = []
var batting_index: int = 0
var pitcher_index: int = 0
var fielder_index: int = 1
var runs: int = 0

static func create(
	team_name: String,
	player_definitions: Array[PlayerDefinition]
) -> TeamMatchState:
	var result: TeamMatchState = TeamMatchState.new()
	result.display_name = team_name
	for definition in player_definitions:
		result.roster.append(PlayerMatchState.create(definition))
	return result

func is_valid_roster() -> bool:
	return roster.size() == ROSTER_SIZE

func current_batter() -> PlayerMatchState:
	if roster.is_empty():
		return null
	return roster[batting_index]

func on_deck_batter() -> PlayerMatchState:
	if roster.is_empty():
		return null
	return roster[(batting_index + 1) % roster.size()]

func current_pitcher() -> PlayerMatchState:
	if roster.is_empty():
		return null
	return roster[pitcher_index]

func current_fielder() -> PlayerMatchState:
	if roster.is_empty():
		return null
	return roster[fielder_index]

func advance_batter() -> void:
	if not roster.is_empty():
		batting_index = (batting_index + 1) % roster.size()

func cycle_pitcher(direction: int = 1) -> void:
	if roster.is_empty():
		return
	select_pitcher(posmod(pitcher_index + direction, roster.size()))

func select_pitcher(index: int) -> bool:
	if index < 0 or index >= roster.size():
		return false
	pitcher_index = index
	if fielder_index == pitcher_index:
		cycle_fielder(1)
	return true

func cycle_fielder(direction: int = 1) -> void:
	if roster.size() <= 1:
		return
	var candidate: int = fielder_index
	for _attempt in range(roster.size()):
		candidate = posmod(candidate + direction, roster.size())
		if candidate != pitcher_index:
			fielder_index = candidate
			return

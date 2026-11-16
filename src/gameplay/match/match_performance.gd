class_name MatchPerformance
extends RefCounted

const KEYS: Array[String] = [
	"pa", "h", "double", "triple", "hr", "bb", "k", "rbi", "outs", "p_h", "p_bb", "p_k", "pitches"
]

var players: Dictionary = {}
# Opt-in only for new human-club career seasons. Old match/report schemas stay exact.
var track_fielding: bool = false
var fielding_players: Dictionary = {}


func fielding_play(player_id: StringName) -> void:
	if track_fielding and not player_id.is_empty():
		fielding_players[String(player_id)] = true


static func empty_line() -> Dictionary:
	var line: Dictionary = {}
	for key in KEYS:
		line[key] = 0
	return line


func complete(batter_id: StringName, pitcher_id: StringName, outcome: String, runs: int) -> void:
	var batting: Dictionary = _line(batter_id)
	var pitching: Dictionary = _line(pitcher_id)
	batting["pa"] += 1
	batting["rbi"] += runs
	if outcome == "walk":
		batting["bb"] += 1
		pitching["p_bb"] += 1
	elif outcome in ["single", "double", "triple", "hr"]:
		batting["h"] += 1
		pitching["p_h"] += 1
		if outcome != "single":
			batting[outcome] += 1
	else:
		pitching["outs"] += 1
		if outcome == "strikeout":
			batting["k"] += 1
			pitching["p_k"] += 1


func snapshot(state: MatchState) -> Dictionary:
	var result: Dictionary = players.duplicate(true)
	for team in [state.away_team, state.home_team]:
		for player: PlayerMatchState in team.roster:
			var id: String = String(player.definition.id)
			if not result.has(id):
				result[id] = empty_line()
			result[id]["pitches"] = player.pitch_count
			if track_fielding:
				result[id]["fielding_v1"] = fielding_players.has(id)
	return result


func _line(id: StringName) -> Dictionary:
	var key: String = String(id)
	if not players.has(key):
		players[key] = empty_line()
	return players[key]

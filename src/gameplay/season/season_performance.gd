class_name SeasonPerformance
extends RefCounted


static func valid(snapshot: Variant, roster: Array) -> bool:
	if not snapshot is Dictionary or snapshot.size() != roster.size():
		return false
	for id: Variant in snapshot:
		if not id is String or not roster.has(id) or not snapshot[id] is Dictionary:
			return false
		var line: Dictionary = snapshot[id]
		if line.size() != MatchPerformance.KEYS.size():
			return false
		for key in MatchPerformance.KEYS:
			if not SeasonSave._integer(line.get(key), 0, 1000000):
				return false
		if line["h"] + line["bb"] + line["k"] > line["pa"]:
			return false
		if line["double"] + line["triple"] + line["hr"] > line["h"]:
			return false
		if line["p_k"] > line["outs"]:
			return false
	var total: Dictionary = MatchPerformance.empty_line()
	for line: Dictionary in snapshot.values():
		for key in total:
			total[key] += int(line[key])
	return (
		total["h"] == total["p_h"]
		and total["bb"] == total["p_bb"]
		and total["k"] == total["p_k"]
		and total["pa"] == total["h"] + total["bb"] + total["outs"]
	)


static func totals(season: SeasonState) -> Dictionary:
	var result: Dictionary = {}
	for id: String in season.teams[0]["roster"]:
		result[id] = MatchPerformance.empty_line()
	for game in season.player_results:
		var snapshot: Dictionary = game.get("performance", {})
		for id: String in result:
			if not snapshot.has(id):
				continue
			for key in MatchPerformance.KEYS:
				result[id][key] += int(snapshot[id][key])
	return result


static func coverage(season: SeasonState) -> String:
	var count: int = 0
	for game in season.player_results:
		if game.has("performance"):
			count += 1
	return "Recorded games: %d / %d • Includes playoffs" % [count, season.player_results.size()]


static func highlights(stats: Dictionary, roster: Array) -> Array[String]:
	var lines: Array[String] = []
	for category in ["h", "p_k"]:
		var leaders: PackedStringArray = []
		var best: int = 0
		for id: String in roster:
			var value: int = int(stats.get(id, {}).get(category, 0))
			if value > best:
				best = value
				leaders.clear()
			if value == best and best > 0:
				leaders.append(ContentDB.get_player(StringName(id)).display_name)
		if best > 0:
			lines.append(
				(
					"%s: %s • %d"
					% [
						"Hits" if category == "h" else "Pitching strikeouts",
						", ".join(leaders),
						best
					]
				)
			)
	return lines

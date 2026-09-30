class_name ClubSeasonRecord
extends RefCounted
# gdlint: disable=max-returns
## Compact score evidence, independent of future player/economy catalog revisions.


static func capture(season: SeasonState) -> Dictionary:
	var scores: Array = []
	for result: Dictionary in season.results:
		scores.append([result.id, result.away, result.home, result.away_runs, result.home_runs])
	scores.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return {
		"draws": season.teams.map(func(team: Dictionary) -> float: return team.draw),
		"scores": scores
	}


static func analyze(value: Variant) -> Dictionary:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["draws", "scores"]):
		return {}
	if not value.draws is Array or value.draws.size() != 6 or not value.scores is Array:
		return {}
	var count: int = value.scores.size()
	if count > 33 or (count < 30 and count % 3 != 0) or count == 31:
		return {}
	var season: SeasonState = SeasonState.new()
	for index in range(6):
		var draw: Variant = value.draws[index]
		if not (draw is float or draw is int) or not is_finite(draw) or draw < 0 or draw > 1:
			return {}
		season.teams.append({"draw": draw})
	season._build_schedule()
	var seeds: Array = []
	var finalists: Array = []
	for index in range(count):
		var score: Variant = value.scores[index]
		if not score is Array or score.size() != 5:
			return {}
		for field in range(5):
			var limit: int = 32 if field == 0 else (5 if field < 3 else 9999)
			if not SeasonOwnership._whole(score[field], 0, limit):
				return {}
		if score[0] != index or score[3] == score[4]:
			return {}
		var fixture: Dictionary
		if index < 30:
			fixture = season.schedule.filter(func(row: Dictionary) -> bool: return row.id == index)[0]
		else:
			if index == 30:
				seeds = season.standings().slice(0, 4).map(
					func(row: Dictionary) -> int: return row.team
				)
			if index < 32:
				fixture = {"away": seeds[3 - (index - 30)], "home": seeds[index - 30]}
			else:
				finalists.sort_custom(
					func(a: int, b: int) -> bool: return seeds.find(a) < seeds.find(b)
				)
				fixture = {"away": finalists[1], "home": finalists[0]}
		if score[1] != fixture.away or score[2] != fixture.home:
			return {}
		var result: Dictionary = {
			"id": index,
			"away": int(score[1]),
			"home": int(score[2]),
			"away_runs": int(score[3]),
			"home_runs": int(score[4])
		}
		season.results.append(result)
		if index in [30, 31]:
			finalists.append(SeasonState._winner(result))
	var wins: int = 0
	var games: int = 0
	for result: Dictionary in season.results:
		if result.id < 30 and 0 in [result.home, result.away]:
			games += 1
			wins += int(SeasonState._winner(result) == 0)
	var finish: String = "unfinished"
	if count == 33:
		finish = "missed"
		if seeds.has(0):
			finish = "semifinal"
		if finalists.has(0):
			finish = "runner_up"
		if SeasonState._winner(season.results[-1]) == 0:
			finish = "champion"
	return {"finish": finish, "wins": wins, "games": games}


static func receipt(proof: Dictionary, first_title: bool) -> Dictionary:
	var result: Dictionary = analyze(proof)
	if result.is_empty() or result.finish == "unfinished":
		return {}
	# Working reward version1. Only Standard/Base is playable in this slice.
	var finish_award: int = {"missed": 35, "semifinal": 65, "runner_up": 95, "champion": 180}[
		result.finish
	]
	var record_bonus: int = int(15 * int(result.wins) / 10.0)
	var first_bonus: int = 25 if result.finish == "champion" and first_title else 0
	return {
		"version": 1,
		"finish": result.finish,
		"wins": result.wins,
		"finish_award": finish_award,
		"record_bonus": record_bonus,
		"first_bonus": first_bonus,
		"total": finish_award + record_bonus + first_bonus
	}

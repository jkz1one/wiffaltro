class_name SeasonState
extends RefCounted

enum Phase { DRAFT, REGULAR, SEMIFINAL, FINAL, COMPLETE }
const TEAM_NAMES: Array[String] = ["Yard Club", "Rivets", "Kites", "Lanterns", "Comets", "Switches"]
var season_seed: int = 0
var phase: Phase = Phase.DRAFT
var round_index: int = 0
var draft_pool: Array[String] = []
var picks: Array[String] = []
var teams: Array[Dictionary] = []
var schedule: Array[Dictionary] = []
var results: Array[Dictionary] = []
var player_results: Array[Dictionary] = []
var playoff_seeds: Array[int] = []
var semifinals: Array[Dictionary] = []
var final_fixture: Dictionary = {}
var champion: int = -1
var starter_index: int = 0
var fielder_index: int = 1


static func create(seed_value: int) -> SeasonState:
	var season: SeasonState = SeasonState.new()
	season.season_seed = seed_value
	for id: StringName in ContentDB.player_by_id:
		if id != PitchBatLab.DEBUG_PLAYER_ID:
			season.draft_pool.append(String(id))
	season.draft_pool.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(season.draft_pool.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: String = season.draft_pool[index]
		season.draft_pool[index] = season.draft_pool[other]
		season.draft_pool[other] = held
	for index in range(6):
		season.teams.append({"name": TEAM_NAMES[index], "roster": [], "draw": rng.randf()})
	season._build_schedule()
	return season


func offers() -> Array[String]:
	var result: Array[String] = []
	if phase == Phase.DRAFT:
		for index in range(picks.size() * 3, picks.size() * 3 + 3):
			result.append(draft_pool[index])
	return result


func choose_player(id: String) -> bool:
	if phase != Phase.DRAFT or not offers().has(id):
		return false
	picks.append(id)
	if picks.size() == 4:
		teams[0]["roster"] = picks.duplicate()
		var remaining: Array[String] = []
		for candidate in draft_pool:
			if not picks.has(candidate):
				remaining.append(candidate)
		for team in range(1, 6):
			teams[team]["roster"] = remaining.slice((team - 1) * 4, team * 4)
		phase = Phase.REGULAR
	return true


func pending_fixture() -> Dictionary:
	if phase == Phase.REGULAR:
		for fixture in schedule:
			if fixture["round"] == round_index and (fixture["home"] == 0 or fixture["away"] == 0):
				return fixture
	elif phase == Phase.SEMIFINAL:
		for fixture in semifinals:
			if fixture["home"] == 0 or fixture["away"] == 0:
				return fixture
	elif phase == Phase.FINAL:
		return final_fixture
	return {}


func make_match() -> MatchState:
	var fixture: Dictionary = pending_fixture()
	if fixture.is_empty():
		return null
	var match_state: MatchState = MatchState.create(
		_make_team(fixture["away"]), _make_team(fixture["home"])
	)
	var player: TeamMatchState = (
		match_state.home_team if fixture["home"] == 0 else match_state.away_team
	)
	player.pitcher_index = starter_index
	player.fielder_index = fielder_index
	return match_state


func record_player_result(fixture_id: int, away_runs: int, home_runs: int) -> bool:
	var fixture: Dictionary = pending_fixture()
	if fixture.is_empty() or fixture["id"] != fixture_id or away_runs == home_runs:
		return false
	if mini(away_runs, home_runs) < 0 or maxi(away_runs, home_runs) > 9999:
		return false
	var result: Dictionary = fixture.duplicate(true)
	result["away_runs"] = away_runs
	result["home_runs"] = home_runs
	results.append(result)
	player_results.append(result.duplicate(true))
	if phase == Phase.REGULAR:
		for game in schedule:
			if game["round"] == round_index and game["id"] != fixture_id:
				results.append(_simulate(game))
		round_index += 1
		if round_index == 10:
			_begin_playoffs()
	elif phase == Phase.SEMIFINAL:
		for game in semifinals:
			if game["id"] != fixture_id:
				results.append(_simulate(game))
		_prepare_final()
	else:
		champion = _winner(result)
		phase = Phase.COMPLETE
	return true


func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for team in range(6):
		rows.append({"team": team, "wins": 0, "losses": 0, "rf": 0, "ra": 0})
	for game in results:
		if game["id"] >= 30:
			continue
		var away: Dictionary = rows[game["away"]]
		var home: Dictionary = rows[game["home"]]
		away["rf"] += game["away_runs"]
		away["ra"] += game["home_runs"]
		home["rf"] += game["home_runs"]
		home["ra"] += game["away_runs"]
		rows[_winner(game)]["wins"] += 1
		rows[game["home"] if _winner(game) == game["away"] else game["away"]]["losses"] += 1
	rows.sort_custom(_rank_before)
	return rows


func swap_batters(first: int, second: int) -> void:
	if phase == Phase.DRAFT or mini(first, second) < 0 or maxi(first, second) >= 4:
		return
	var roster: Array = teams[0]["roster"]
	var held: String = roster[first]
	roster[first] = roster[second]
	roster[second] = held
	if starter_index == first or starter_index == second:
		starter_index = second if starter_index == first else first
	if fielder_index == first or fielder_index == second:
		fielder_index = second if fielder_index == first else first


func select_starter(index: int) -> void:
	if index < 0 or index >= 4:
		return
	starter_index = index
	if fielder_index == index:
		fielder_index = (index + 1) % 4


func _build_schedule() -> void:
	var rotation: Array[int] = [0, 1, 2, 3, 4, 5]
	for round_number in range(5):
		for pair in range(3):
			var away: int = rotation[pair]
			var home: int = rotation[5 - pair]
			if (round_number + pair) % 2 == 1:
				var held: int = away
				away = home
				home = held
			schedule.append(
				{"id": round_number * 3 + pair, "round": round_number, "away": away, "home": home}
			)
			# Return leg swaps venues exactly once.
			schedule.append(
				{
					"id": (round_number + 5) * 3 + pair,
					"round": round_number + 5,
					"away": home,
					"home": away
				}
			)
		rotation.insert(1, rotation.pop_back())


func _make_team(index: int) -> TeamMatchState:
	var roster: Array[PlayerDefinition] = []
	for id: String in teams[index]["roster"]:
		roster.append(ContentDB.get_player(StringName(id)))
	return TeamMatchState.create(teams[index]["name"], roster)


func _rank_before(a: Dictionary, b: Dictionary) -> bool:
	for stat in ["wins", "difference", "rf"]:
		var left: int = a["rf"] - a["ra"] if stat == "difference" else a[stat]
		var right: int = b["rf"] - b["ra"] if stat == "difference" else b[stat]
		if left != right:
			return left > right
	return teams[a["team"]]["draw"] > teams[b["team"]]["draw"]


func _begin_playoffs() -> void:
	var rows: Array[Dictionary] = standings()
	for index in range(4):
		playoff_seeds.append(rows[index]["team"])
	for pair in range(2):
		semifinals.append(
			{
				"id": 30 + pair,
				"round": 10,
				"home": playoff_seeds[pair],
				"away": playoff_seeds[3 - pair]
			}
		)
	phase = Phase.SEMIFINAL
	if not playoff_seeds.has(0):
		for game in semifinals:
			results.append(_simulate(game))
		_prepare_final()


func _prepare_final() -> void:
	var winners: Array[int] = []
	for game in results:
		if game["id"] in [30, 31]:
			winners.append(_winner(game))
	winners.sort_custom(
		func(a: int, b: int) -> bool: return playoff_seeds.find(a) < playoff_seeds.find(b)
	)
	final_fixture = {"id": 32, "round": 11, "home": winners[0], "away": winners[1], "neutral": true}
	phase = Phase.FINAL
	if not winners.has(0):
		var final_result: Dictionary = _simulate(final_fixture)
		results.append(final_result)
		champion = _winner(final_result)
		phase = Phase.COMPLETE


func _simulate(fixture: Dictionary) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = season_seed + int(fixture["id"]) * 104729
	var result: Dictionary = fixture.duplicate(true)
	var away: float = _strength(fixture["away"])
	var home: float = _strength(fixture["home"])
	result["away_runs"] = _poisson(rng, clampf(3.2 + (away - home) * 0.45, 1.0, 6.0))
	result["home_runs"] = _poisson(rng, clampf(3.2 + (home - away) * 0.45, 1.0, 6.0))
	# Abstract extra innings; no ties and no rubber-banding from player results.
	if result["away_runs"] == result["home_runs"]:
		result["away_runs" if rng.randf() < 0.5 else "home_runs"] += 1
	return result


func _strength(team: int) -> float:
	var total: float = 0.0
	for id: String in teams[team]["roster"]:
		var player: PlayerDefinition = ContentDB.get_player(StringName(id))
		total += (
			(
				player.contact
				+ player.power
				+ player.fielding
				+ player.velocity
				+ player.break_rating
				+ player.control
				+ player.stamina
			)
			/ 7.0
		)
	return total / 4.0


static func _poisson(rng: RandomNumberGenerator, mean: float) -> int:
	var product: float = 1.0
	var count: int = -1
	while product > exp(-mean):
		product *= rng.randf()
		count += 1
	return maxi(0, count)


static func _winner(result: Dictionary) -> int:
	return result["away"] if result["away_runs"] > result["home_runs"] else result["home"]

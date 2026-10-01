class_name SeasonState
extends RefCounted

enum Phase { DRAFT, REGULAR, SEMIFINAL, FINAL, COMPLETE }
const TEAM_NAMES: Array[String] = ["Yard Club", "Rivets", "Kites", "Lanterns", "Comets", "Switches"]
const AWAY_FIELD_ID: StringName = &"field.commons_park"
const LEGACY_IDS: Array[String] = [
	"player.alex_finch",
	"player.ari_banks",
	"player.ash_cole",
	"player.cal_mercer",
	"player.dev_lin",
	"player.drew_sato",
	"player.eli_frost",
	"player.frankie_bell",
	"player.gray_west",
	"player.harper_fox",
	"player.indy_shaw",
	"player.jo_lane",
	"player.jules_moss",
	"player.kai_soto",
	"player.kit_rowan",
	"player.lee_stone",
	"player.mika_reed",
	"player.morgan_pike",
	"player.nico_vega",
	"player.noel_hart",
	"player.remy_cruz",
	"player.ren_ellis",
	"player.sam_park",
	"player.tess_vale"
]
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
var difficulty: int = 1
var ownership: SeasonOwnership = SeasonOwnership.new()
var build: SeasonBuild
var opponents: SeasonOpponents
var career: ClubCareer


static func field_for_fixture(fixture: Dictionary) -> FieldDefinition:
	var home: bool = fixture.get("home", -1) == 0 and not fixture.get("neutral", false)
	return ContentDB.get_field(PitchBatLab.FIELD_ID if home else AWAY_FIELD_ID)


static func create(
	seed_value: int,
	legacy: bool = false,
	working_progression: bool = false,
	paid_opponents: bool = false
) -> SeasonState:
	var season: SeasonState = SeasonState.new()
	season.season_seed = seed_value
	if working_progression:
		season.build = SeasonBuild.new(seed_value)
		if paid_opponents:
			season.opponents = SeasonOpponents.new()
	for id: StringName in ContentDB.player_by_id:
		if id != PitchBatLab.DEBUG_PLAYER_ID and (not legacy or String(id) in LEGACY_IDS):
			season.draft_pool.append(String(id))
	season.draft_pool.sort()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(season.draft_pool.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var held: String = season.draft_pool[index]
		season.draft_pool[index] = season.draft_pool[other]
		season.draft_pool[other] = held
	if not legacy:
		season._limit_specialist_offers()
	for index in range(6):
		season.teams.append({"name": TEAM_NAMES[index], "roster": [], "draw": rng.randf()})
	season._build_schedule()
	return season


func _limit_specialist_offers() -> void:
	var special_seen: bool = false
	for index in range(12):
		if ContentDB.get_player(StringName(draft_pool[index])).starting_pitches.size() < 4:
			continue
		if not special_seen:
			special_seen = true
			continue
		for other in range(12, draft_pool.size()):
			if ContentDB.get_player(StringName(draft_pool[other])).starting_pitches.size() < 4:
				var held: String = draft_pool[index]
				draft_pool[index] = draft_pool[other]
				draft_pool[other] = held
				break


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
		if build != null:
			var progress: SeasonGearProgress = build._gear_progress.fork()
			var sponsor_progress: SeasonSponsorProgress = build._sponsor_progress.fork()
			var order_start: Variant = build._order_start
			var rain_start: Variant = build._rain_start
			var transfer_start: Variant = build._transfer_start
			var checkout_start: Variant = build._checkout_start
			var association_start: Variant = build._association_start
			var freezer_start: Variant = build._freezer_start
			var sides_start: Variant = build._sides_start
			var jump_start: Variant = build._jump_start
			var supply_start: Variant = build._supply_start
			build = SeasonBuild.new(season_seed, picks, draft_pool, recruit_blocked())
			build._gear_progress = progress
			build._sponsor_progress = sponsor_progress
			build._order_start = order_start
			build._rain_start = rain_start
			build._transfer_start = transfer_start
			build._supply_start = supply_start
			build._checkout_start = checkout_start
			build._association_start = association_start
			build._freezer_start = freezer_start
			build._sides_start = sides_start
			build._jump_start = jump_start
		if opponents != null:
			opponents.initialize(self)
		for team in range(6):
			teams[team]["strength"] = _strength(team)
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
	match_state.ai_tactical_quality = clampf(
		0.15 + difficulty * 0.25 + minf(round_index, 9) * 0.025, 0.0, 1.0
	)
	var player: TeamMatchState = (
		match_state.home_team if fixture["home"] == 0 else match_state.away_team
	)
	player.pitcher_index = starter_index
	player.fielder_index = fielder_index
	if build != null:
		match_state.gear_usage.equipped = SeasonReclamation.receipts(build.view().wallet)
		player.scouted_recipe = SeasonFilmRoom.target(self)
		player.tactics.held = SeasonTacticalCatalog.held(build.view().wallet)
		player.tactics.track_walks = build._format >= 27 and build._checkout_start != null
		player.tactics.insured_receipt = SeasonSecondChance.target(build, int(fixture.id))
	return match_state


func record_player_result(
	fixture_id: int,
	away_runs: int,
	home_runs: int,
	performance: Dictionary = {},
	used_gear: Array = [],
	tactics: Array = [],
	batting: Dictionary = {},
	stances: Array = [],
	fielding: Array = []
) -> bool:
	var fixture: Dictionary = pending_fixture()
	if fixture.is_empty() or fixture["id"] != fixture_id or away_runs == home_runs:
		return false
	if (
		mini(away_runs, home_runs) < 0
		or maxi(away_runs, home_runs) > 9999
		or not SeasonLeftRight.own_halves(stances, fixture.home == 0)
		or not SeasonLeftRight.own_halves(fielding, fixture.home != 0)
	):
		return false
	var roster: Array = teams[fixture["away"]]["roster"] + teams[fixture["home"]]["roster"]
	if not performance.is_empty() and not SeasonPerformance.valid(performance, roster):
		return false
	var command: Dictionary = {
		"id": "game:%d" % fixture_id,
		"rev": ownership.revision() if build == null else build.revision(),
		"op": "reward",
		"game": fixture_id,
		"win": (home_runs > away_runs) == (fixture["home"] == 0)
	}
	if build != null and build.to_data().version >= 6:
		command["performance"] = performance.duplicate(true)
	if build != null and build.to_data().version >= 10 and not used_gear.is_empty():
		command["used_gear"] = used_gear.duplicate()
	if not tactics.is_empty():
		if build == null or build.to_data().version < 14:
			return false
		command["tactics"] = tactics.duplicate(true)
	if not batting.is_empty():
		command["batting"] = batting.duplicate(true)
	if not stances.is_empty():
		command["stances"] = stances.duplicate(true)
	if not fielding.is_empty():
		command["fielding"] = fielding.duplicate(true)
	var reward: Dictionary = ownership.commit(command) if build == null else build.commit(command)
	if not reward.ok:
		return false
	var result: Dictionary = fixture.duplicate(true)
	result["away_runs"] = away_runs
	result["home_runs"] = home_runs
	if build != null:
		result["club_roster"] = teams[0]["roster"].duplicate()
		result.club_roster.sort()
	if not performance.is_empty():
		result["performance"] = performance.duplicate(true)
	if command.has("used_gear"):
		result["used_gear"] = used_gear.duplicate()
	if command.has("tactics"):
		result["tactics"] = tactics.duplicate(true)
	if command.has("batting"):
		result["batting"] = batting.duplicate(true)
	if command.has("stances"):
		result["stances"] = stances.duplicate(true)
	if command.has("fielding"):
		result["fielding"] = fielding.duplicate(true)
	results.append(result)
	player_results.append(result.duplicate(true))
	if phase == Phase.REGULAR:
		for game in schedule:
			if game["round"] == round_index and game["id"] != fixture_id:
				results.append(_simulate(game))
		if opponents != null:
			var played: Array = results.filter(
				func(row: Dictionary) -> bool: return row["round"] == round_index
			)
			var survivors: Array = [1, 2, 3, 4, 5]
			if round_index == 9:
				survivors = standings().slice(0, 4).map(
					func(row: Dictionary) -> int: return row.team
				)
			opponents.settle(played, survivors)
		round_index += 1
		if round_index == 10:
			_begin_playoffs()
	elif phase == Phase.SEMIFINAL:
		for game in semifinals:
			if game["id"] != fixture_id:
				results.append(_simulate(game))
		_settle_semifinals()
		_prepare_final()
	else:
		if opponents != null:
			opponents.settle([result], [])
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
		roster.append(player_definition(id))
	var team: TeamMatchState = TeamMatchState.create(teams[index]["name"], roster)
	if opponents != null and index > 0:
		var role: Dictionary = opponents.clubs[str(index)].roles
		team.pitcher_index = teams[index].roster.find(role.pitcher)
		team.fielder_index = teams[index].roster.find(role.fielder)
	return team


func opposing_starter(fixture: Dictionary) -> String:
	var index: int = fixture.away if fixture.home == 0 else fixture.home
	if opponents != null:
		return opponents.clubs[str(index)].roles.pitcher
	return teams[index].roster[0]


func player_definition(id: String) -> PlayerDefinition:
	if opponents != null:
		var opponent: PlayerDefinition = opponents.definition(id)
		if opponent != null:
			return opponent
	return ContentDB.get_player(StringName(id)) if build == null else build.definition(id)


func cash() -> int:
	return ownership.cash() if build == null else build.cash()


func shop_available() -> bool:
	return build != null and not player_results.is_empty() and not pending_fixture().is_empty()


func recruit_blocked() -> Array[String]:
	var blocked: Array[String] = []
	for index in range(1, teams.size()):
		blocked.append_array(teams[index].roster)
	return blocked


func adopt_build(next: SeasonBuild) -> void:
	var incoming: Array[String] = next.roster()
	var current: Array = teams[0].roster
	for id: String in current:
		incoming.erase(id)
	var ordered: Array = current.duplicate()
	for index in range(ordered.size()):
		if not next.roster().has(ordered[index]):
			ordered[index] = incoming.pop_front()
	teams[0].roster = ordered
	build = next


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
		_settle_semifinals()
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
		if opponents != null:
			opponents.settle([final_result], [])
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
	if opponents == null and teams[team].has("strength"):
		return float(teams[team]["strength"])
	var total: float = 0.0
	for id: String in teams[team]["roster"]:
		var player: PlayerDefinition = player_definition(id)
		if build != null:
			total += (player.contact + player.power + player.fielding + player.control) / 4.0
			continue
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


func _settle_semifinals() -> void:
	if opponents == null:
		return
	var played: Array = results.filter(func(row: Dictionary) -> bool: return row.id in [30, 31])
	var survivors: Array = played.map(func(row: Dictionary) -> int: return _winner(row))
	opponents.settle(played, survivors)

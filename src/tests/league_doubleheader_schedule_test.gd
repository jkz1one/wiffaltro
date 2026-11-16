extends Node
## Synthetic schedule/profile checks against the unchanged ordinary constructor.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	_profiles()
	_schedule()
	print("Doubleheader schedule checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _profiles() -> void:
	var rules: Dictionary = LeagueRules.capture("doubleheader")
	var exact: Dictionary = {
		"version": 1,
		"league": "doubleheader",
		"tier": 0,
		"profile": "league-doubleheader-candidate-sweep6-v1"
	}
	check(rules == exact and rules.size() == 4, "exact four-field candidate identity")
	check(LeagueRules.doubleheader(rules), "Doubleheader predicate")
	check(
		LeagueRules.normalized(JSON.parse_string(JSON.stringify(rules))) == exact, "JSON identity"
	)
	check(LeagueRules.capacities(rules) == {"held": 2, "sponsors": 5}, "ordinary capacities")
	check(not LeagueRules.public_activation_enabled("doubleheader"), "no public admission")
	check(LeagueRules.capture("doubleheader", 1).is_empty(), "tier one unavailable")
	check(LeagueRules.capture("doubleheader", -1).is_empty(), "negative tier unavailable")
	check(LeagueRules.capture("doubleheader", 0, 443).is_empty(), "no seed field in v1")
	for field: String in exact:
		var missing: Dictionary = exact.duplicate(true)
		missing.erase(field)
		check(LeagueRules.normalized(missing).is_empty(), "missing profile field " + field)
	for extra: String in ["season_seed", "sweep_bonus", "amount", "schedule"]:
		var added: Dictionary = exact.duplicate(true)
		added[extra] = 6
		check(LeagueRules.normalized(added).is_empty(), "extra profile field " + extra)
	for changed: Dictionary in [
		{"version": 2},
		{"version": true},
		{"tier": 1},
		{"tier": false},
		{"profile": LeagueRules.PROFILE},
		{"profile": "league-doubleheader-candidate-sweep7-v1"}
	]:
		var bad: Dictionary = exact.duplicate(true)
		bad.merge(changed, true)
		check(
			LeagueRules.normalized(bad).is_empty() and not LeagueRules.doubleheader(bad),
			"wrong identity rejects"
		)
	var profiles: Dictionary = {
		"standard": LeagueRules.PROFILE,
		"dugout": LeagueRules.PROFILE,
		"sponsorship": LeagueRules.SPONSORSHIP_PROFILE,
		"earnings": LeagueRules.EARNINGS_PROFILE,
		"academy": LeagueRules.ACADEMY_PROFILE,
		"equipment": LeagueRules.EQUIPMENT_PROFILE
	}
	for league: String in profiles:
		var old: Dictionary = LeagueRules.capture(league)
		check(
			old == {"version": 1, "league": league, "tier": 0, "profile": profiles[league]},
			"old exact profile " + league
		)
		check(not LeagueRules.doubleheader(old), "old predicate false " + league)
		old["season_seed"] = 443
		check(LeagueRules.normalized(old).is_empty(), "old profile still rejects seed " + league)
	var scramble: Dictionary = LeagueRules.capture("scramble", 0, 443)
	check(
		(
			scramble
			== {
				"version": 2,
				"league": "scramble",
				"tier": 0,
				"profile": LeagueRules.SCRAMBLE_PROFILE,
				"season_seed": 443
			}
		),
		"Scramble exact five-field seeded profile"
	)
	check(not LeagueRules.doubleheader(scramble), "Scramble remains distinct")


func _schedule() -> void:
	var ordinary: SeasonState = SeasonState.create(443, false, true, true)
	var fixtures: Array[Dictionary] = SeasonDoubleheaderRules.schedule()
	check(fixtures.size() == 30 and ordinary.schedule.size() == 30, "thirty regular fixtures")
	var ids: Dictionary = {}
	for index in range(fixtures.size()):
		var fixture: Dictionary = fixtures[index]
		var old: Dictionary = ordinary.schedule[index]
		var original_round: int = int(old.round) % 5
		var return_leg: bool = int(old.round) >= 5
		var expected: Dictionary = {
			"id": original_round * 6 + int(old.id) % 3 + (3 if return_leg else 0),
			"round": original_round * 2 + (1 if return_leg else 0),
			"away": old.away,
			"home": old.home
		}
		check(fixture == expected, "preserved old pairing, array order and venue " + str(index))
		check(not ids.has(fixture.id), "unique fixture identity")
		ids[fixture.id] = true
		check(
			fixture.home != fixture.away and fixture.size() == 4,
			"distinct clubs and exact fixture shape"
		)
		check(
			SeasonDoubleheaderRules.first(fixture.id) == (fixture.id - 3 if return_leg else -1),
			"exact first-leg relation"
		)
	for id in range(30):
		check(ids.has(id), "no missing fixture ID " + str(id))
	for round_number in range(10):
		var appearances: Dictionary = {}
		var count: int = 0
		for fixture: Dictionary in fixtures:
			if fixture.round != round_number:
				continue
			count += 1
			check(
				not appearances.has(fixture.home) and not appearances.has(fixture.away),
				"one game per club per round"
			)
			appearances[fixture.home] = true
			appearances[fixture.away] = true
		check(count == 3 and appearances.size() == 6, "six clubs in every round")
	for club in range(6):
		var games: Array[Dictionary] = []
		var opponents: Dictionary = {}
		var home_count: int = 0
		for fixture: Dictionary in fixtures:
			if club not in [fixture.home, fixture.away]:
				continue
			games.append(fixture)
			var opponent: int = fixture.away if fixture.home == club else fixture.home
			opponents[opponent] = int(opponents.get(opponent, 0)) + 1
			home_count += int(fixture.home == club)
		games.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.round < b.round)
		check(
			games.size() == 10 and home_count == 5 and opponents.size() == 5,
			"ten games, five home, five opponents"
		)
		for count: int in opponents.values():
			check(count == 2, "exactly two fixtures per opponent")
		for index in range(0, 10, 2):
			var first_game: Dictionary = games[index]
			var second_game: Dictionary = games[index + 1]
			check(
				first_game.home == second_game.away and first_game.away == second_game.home,
				"consecutive reversed venues"
			)
			check(
				(
					second_game.round == first_game.round + 1
					and SeasonDoubleheaderRules.first(second_game.id) == first_game.id
				),
				"consecutive exact pair identity"
			)
	for invalid: Variant in [-1, 30, 31, 32, 33, 1.5, true, false, "3", null, INF, NAN]:
		check(SeasonDoubleheaderRules.first(invalid) == -1, "invalid/playoff is not a return leg")
	check(SeasonDoubleheaderRules.first(3.0) == 0, "integral JSON game accepted")
	var untouched: Array[Dictionary] = SeasonDoubleheaderRules.schedule()
	fixtures[0].home = 99
	check(SeasonDoubleheaderRules.schedule() == untouched, "fresh schedule owns its dictionaries")
	var candidate: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("doubleheader"), true
	)
	check(candidate != null, "closed candidate constructor")
	if candidate != null:
		check(candidate.schedule == untouched, "constructor installs schedule before draft")
		check(
			candidate.draft_pool == ordinary.draft_pool and candidate.teams == ordinary.teams,
			"no draft or tie-break RNG changes"
		)

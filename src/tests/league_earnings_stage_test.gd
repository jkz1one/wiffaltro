extends Node
## Synthetic transaction tests; actual completed-score authority is qualified separately.
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var rules: Dictionary = LeagueRules.capture("earnings")
	check(
		not rules.is_empty() and not LeagueRules.public_activation_enabled("earnings"),
		"closed candidate"
	)
	check(LeagueRules.capacities(rules) == {"held": 2, "sponsors": 5}, "baseline capacities")
	check(LeagueRules.capture("earnings", 1).is_empty(), "no tier composition")
	for pair: Array in [
		[1, 0, 16],
		[3, 0, 18],
		[6, 0, 21],
		[9, 0, 24],
		[99, 0, 24],
		[0, 1, 14],
		[0, 3, 12],
		[0, 5, 10],
		[0, 99, 10]
	]:
		var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
		check(bank.enable_league_rules(rules), "wallet profile")
		var win: bool = pair[0] > pair[1]
		var command: Dictionary = OwnershipFixtures.request(
			bank, "reward", {"game": 0, "win": win, "own_runs": pair[0], "opponent_runs": pair[1]}
		)
		check(bank.commit(command).ok and bank.cash() == pair[2], "margin formula " + str(pair))
		var before: Dictionary = bank.to_data()
		var replay: Dictionary = bank.commit(JSON.parse_string(JSON.stringify(command)))
		check(replay.ok and replay.replayed and bank.to_data() == before, "JSON retry exactly once")
		check(
			(
				not (
					bank
					. commit(
						OwnershipFixtures.request(
							bank,
							"reward",
							{"game": 0, "win": win, "own_runs": pair[0], "opponent_runs": pair[1]}
						)
					)
					. ok
				)
				and bank.to_data() == before
			),
			"new identity cannot repay fixture"
		)
		var restored: SeasonOwnership = SeasonOwnership.from_data(
			JSON.parse_string(JSON.stringify(before)), SeasonSponsorCatalog.ownership_catalog()
		)
		check(restored != null and restored.to_data() == before, "cold wallet")
		check(
			(
				bank.commit(OwnershipFixtures.request(bank, "sponsor_income", {"amount": 21})).ok
				and bank.cash() == pair[2] + 21
			),
			"separate sponsor income"
		)
	_invalid()
	_builds()
	_preserve()
	print("Earnings candidate checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _invalid() -> void:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	bank.enable_league_rules(LeagueRules.capture("earnings"))
	var before: Dictionary = bank.to_data()
	var rows: Array = [
		{"win": true},
		{"win": true, "own_runs": 1},
		{"win": true, "own_runs": 1, "opponent_runs": 1},
		{"win": false, "own_runs": 2, "opponent_runs": 1}
	]
	for score: Variant in [-1, 0.5, 10000, true, "2", null, INF, NAN]:
		rows.append({"win": true, "own_runs": score, "opponent_runs": 0})
		rows.append({"win": true, "own_runs": 2, "opponent_runs": score})
	rows.append({"win": true, "own_runs": 2, "opponent_runs": 0, "amount": 999})
	for row: Dictionary in rows:
		row["game"] = 0
		check(
			(
				not bank.commit(OwnershipFixtures.request(bank, "reward", row)).ok
				and bank.to_data() == before
			),
			"invalid scores atomic " + str(row)
		)
	for league: String in ["standard", "dugout", "sponsorship"]:
		var old: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
		old.enable_league_rules(LeagueRules.capture(league))
		check(
			not (
				old
				. commit(
					OwnershipFixtures.request(
						old, "reward", {"game": 0, "win": true, "own_runs": 2, "opponent_runs": 0}
					)
				)
				. ok
			),
			"old profile strict reward shape"
		)
		check(
			(
				old.commit(OwnershipFixtures.request(old, "reward", {"game": 0, "win": true})).ok
				and old.cash() == (16 if league == "sponsorship" else 18)
			),
			"old income unchanged"
		)


func _builds() -> void:
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	for market: int in [0, 12]:
		var build: SeasonBuild = SeasonBuild.new(551, roster)
		build._market = market
		check(build.enable_league_rules(LeagueRules.capture("earnings")), "human/AI build profile")
		var before: Dictionary = build.to_data()
		check(
			(
				not (
					build
					. commit(
						SeasonOpponentPolicy.command(build, "reward", {"game": 0, "win": true})
					)
					. ok
				)
				and build.to_data() == before
			),
			"missing build scores atomic"
		)
		var command: Dictionary = SeasonOpponentPolicy.command(
			build, "reward", {"game": 0, "win": true, "own_runs": 4, "opponent_runs": 1}
		)
		check(build.commit(command).ok and build.cash() == 18, "build oriented margin payment")
		before = build.to_data()
		var replay: Dictionary = build.commit(JSON.parse_string(JSON.stringify(command)))
		check(replay.ok and replay.replayed and build.to_data() == before, "build cold JSON retry")
		check(
			(
				(
					build
					. commit(
						SeasonOpponentPolicy.command(
							build,
							"reward",
							{"game": 1, "win": false, "own_runs": 1, "opponent_runs": 2}
						)
					)
					. ok
				)
				and build.cash() == 32
			),
			"build loss floor formula"
		)
		var restored: SeasonBuild = SeasonBuild.from_data(
			JSON.parse_string(JSON.stringify(build.to_data())), 551, roster
		)
		check(
			restored != null and restored.to_data() == build.to_data(), "Build45 cold score journal"
		)
		check(build._fork().to_data() == build.to_data(), "fork score journal")
	var season: SeasonState = SeasonState.create_closed_league(
		551, LeagueRules.capture("earnings"), true
	)
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "candidate draft")
	check(
		SeasonSave._decode(JSON.parse_string(JSON.stringify(SeasonSave.snapshot(season)))) != null,
		"cold live draft"
	)
	check(PhysicalMatchRequest.capture(season.make_match()) != null, "physical candidate capture")


func _preserve() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--retained="):
			var data: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(argument.trim_prefix("--retained="))
			)
			var season: SeasonState = SeasonSave._decode(data)
			check(
				season != null and ClubCareer.same(SeasonSave.snapshot(season), data),
				"retained previous completed round unchanged"
			)

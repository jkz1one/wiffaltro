extends Node
## Synthetic closed-wallet authority. Live completed-match evidence is tested separately.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func cold(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))


func _ready() -> void:
	_exhaustive()
	_pairs()
	_atomic_and_replay()
	_old_profiles()
	print("Doubleheader reward checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _bank() -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new()
	check(bank.enable_league_rules(LeagueRules.capture("doubleheader")), "candidate wallet context")
	return bank


func _reward(bank: SeasonOwnership, game: int, win: bool) -> Dictionary:
	return OwnershipFixtures.request(bank, "reward", {"game": game, "win": win})


func _club_games(club: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for fixture: Dictionary in SeasonDoubleheaderRules.schedule():
		if club in [fixture.home, fixture.away]:
			result.append(fixture)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.round < b.round)
	return result


func _exhaustive() -> void:
	var games: Array[Dictionary] = _club_games(0)
	var cash_totals: Array[int] = []
	var seen_bonuses: Dictionary = {}
	for mask in range(1024):
		var bank: SeasonOwnership = _bank()
		var ordinary: int = 0
		var expected_bonus: int = 0
		for index in range(10):
			var win: bool = (mask & (1 << index)) != 0
			var sweep: bool = index % 2 == 1 and win and (mask & (1 << (index - 1))) != 0
			var bonus: int = SeasonDoubleheaderRules.bonus(
				bank._league_rules, games[index].id, win, bank.view().rewards
			)
			check(
				bonus == (6 if sweep else 0), "derived pair bonus " + str(mask) + ":" + str(index)
			)
			ordinary += 18 if win else 12
			expected_bonus += 6 if sweep else 0
			check(
				bank.commit(_reward(bank, games[index].id, win)).ok,
				"completed fixture pays " + str(mask) + ":" + str(index)
			)
			check(
				bank.cash() == ordinary + expected_bonus,
				"exact prefix cash " + str(mask) + ":" + str(index)
			)
		check(
			expected_bonus >= 0 and expected_bonus <= 30 and expected_bonus % 6 == 0,
			"bounded full-season bonus"
		)
		check(
			bank.view().rewards.size() == 10 and bank.revision() == 10,
			"one record per game, no bonus command"
		)
		cash_totals.append(bank.cash())
		seen_bonuses[expected_bonus] = true
	check(
		cash_totals.size() == 1024 and cash_totals[0] == 120 and cash_totals[1023] == 210,
		"all 1024 W/L sequences and extremes"
	)
	for amount in range(0, 31, 6):
		check(seen_bonuses.has(amount), "attainable bonus " + str(amount))
	for mask in range(1024):
		for index in range(10):
			if (mask & (1 << index)) == 0:
				var improvement: int = cash_totals[mask | (1 << index)] - cash_totals[mask]
				check(
					improvement in [6, 12],
					"loss-to-win never lowers cash " + str(mask) + ":" + str(index)
				)


func _pairs() -> void:
	for round_number in range(5):
		for pair in range(3):
			var first_game: int = round_number * 6 + pair
			var second_game: int = first_game + 3
			for outcomes: Array in [
				[true, true, 42], [true, false, 30], [false, true, 30], [false, false, 24]
			]:
				var bank: SeasonOwnership = _bank()
				check(
					bank.commit(_reward(bank, first_game, outcomes[0])).ok,
					"first-leg ordinary payment"
				)
				check(bank.cash() == (18 if outcomes[0] else 12), "no first-leg bonus")
				check(
					bank.commit(_reward(bank, second_game, outcomes[1])).ok,
					"exact second-leg payment"
				)
				check(bank.cash() == outcomes[2], "sweep/split/loss payout for every fixture pair")
			for win: bool in [false, true]:
				var missing: SeasonOwnership = _bank()
				var before: Dictionary = missing.to_data()
				check(
					(
						not missing.commit(_reward(missing, second_game, win)).ok
						and missing.to_data() == before
						and missing.cash() == 0
					),
					"unsettled first leg rejects all second-leg payment atomically"
				)
	var wrong_first: SeasonOwnership = _bank()
	check(wrong_first.commit(_reward(wrong_first, 0, true)).ok, "other pair first fixture")
	var before: Dictionary = wrong_first.to_data()
	check(
		(
			not wrong_first.commit(_reward(wrong_first, 4, true)).ok
			and wrong_first.to_data() == before
		),
		"another pair's win cannot qualify"
	)
	for game in [30, 31, 32]:
		var playoff: SeasonOwnership = _bank()
		check(
			playoff.commit(_reward(playoff, game, true)).ok and playoff.cash() == 18,
			"playoff ordinary win without pair"
		)
		check(
			(
				SeasonDoubleheaderRules.bonus(
					playoff._league_rules, game, true, {str(game - 3): true}
				)
				== 0
			),
			"no playoff sweep bonus"
		)
	var rules: Dictionary = LeagueRules.capture("doubleheader")
	for invalid: Variant in [null, false, 1, "win", [], {}, {"0": 1}, {0: true}, {"1": true}]:
		check(
			SeasonDoubleheaderRules.bonus(rules, 3, true, invalid) == 0,
			"only exact string-key paid boolean win qualifies"
		)
	for win: Variant in [false, null, 1, "true"]:
		check(
			SeasonDoubleheaderRules.bonus(rules, 3, win, {"0": true}) == 0,
			"only completed win boolean qualifies"
		)
	for game: Variant in [-1, 0, 1, 2, 3.5, true, "3", 30, 31, 32, null, INF, NAN]:
		check(
			SeasonDoubleheaderRules.bonus(rules, game, true, {"0": true}) == 0,
			"non-second-leg bonus is zero"
		)


func _atomic_and_replay() -> void:
	var bank: SeasonOwnership = _bank()
	var before: Dictionary = bank.to_data()
	for field: String in [
		"amount", "bonus", "sweep_bonus", "own_runs", "opponent_runs", "first_game", "completed"
	]:
		var forged: Dictionary = _reward(bank, 0, true)
		forged[field] = 6
		check(
			not bank.commit(forged).ok and bank.to_data() == before,
			"caller override rejects atomically " + field
		)
	for op: String in ["doubleheader_bonus", "sweep_bonus", "unfinished", "abandon"]:
		check(
			(
				not bank.commit(OwnershipFixtures.request(bank, op, {"game": 3, "win": true})).ok
				and bank.to_data() == before
			),
			"no independent or incomplete payout operation " + op
		)
	var first_command: Dictionary = _reward(bank, 0, true)
	check(bank.commit(first_command).ok and bank.cash() == 18, "first completed win")
	var preview: Dictionary = bank.preview(_reward(bank, 3, true))
	check(
		preview.ok and preview.after.cash == 42 and bank.cash() == 18,
		"unfinished preview changes no cash"
	)
	var restored_first: SeasonOwnership = SeasonOwnership.from_data(cold(bank.to_data()))
	check(restored_first != null and restored_first.cash() == 18, "cold restore between pair legs")
	var second_command: Dictionary = _reward(bank, 3, true)
	check(bank.commit(second_command).ok and bank.cash() == 42, "one derived sweep reward")
	if restored_first != null:
		check(
			(
				restored_first.commit(cold(second_command)).ok
				and restored_first.to_data() == bank.to_data()
			),
			"cold continuation exact"
		)
	before = bank.to_data()
	for original: Dictionary in [first_command, second_command]:
		var replay: Dictionary = bank.commit(cold(original))
		check(
			replay.ok and replay.replayed and bank.to_data() == before and bank.cash() == 42,
			"JSON retry cannot repay"
		)
		var conflict: Dictionary = original.duplicate(true)
		conflict.win = not conflict.win
		check(
			not bank.commit(conflict).ok and bank.to_data() == before,
			"same identity changed result rejects"
		)
	for game in [0, 3]:
		check(
			not bank.commit(_reward(bank, game, true)).ok and bank.to_data() == before,
			"new identity cannot repay same fixture"
		)
	var restored: SeasonOwnership = SeasonOwnership.from_data(cold(before))
	check(
		restored != null and restored.to_data() == before and restored.cash() == 42,
		"cold journal derives same sweep"
	)
	check(
		bank.fork().to_data() == before and bank.fork().cash() == 42,
		"fork preserves paid pair evidence"
	)
	var tampered: Dictionary = cold(before)
	tampered.events[1]["bonus"] = 6
	check(SeasonOwnership.from_data(tampered) == null, "saved caller bonus rejects")
	tampered = cold(before)
	tampered.events.remove_at(0)
	tampered.events[0].rev = 0
	check(SeasonOwnership.from_data(tampered) == null, "stripped first-leg journal rejects")
	tampered = cold(before)
	tampered.events[0].game = 1
	check(SeasonOwnership.from_data(tampered) == null, "wrong pair first-leg journal rejects")
	check(
		(
			bank.commit(OwnershipFixtures.request(bank, "sponsor_income", {"amount": 21})).ok
			and bank.cash() == 63
		),
		"ordinary separate sponsor income unchanged"
	)


func _old_profiles() -> void:
	for league: String in [
		"", "standard", "dugout", "sponsorship", "earnings", "academy", "equipment", "scramble"
	]:
		var bank: SeasonOwnership = SeasonOwnership.new()
		var rules: Dictionary = {}
		if not league.is_empty():
			rules = (
				LeagueRules.capture(league, 0, 443)
				if league == "scramble"
				else LeagueRules.capture(league)
			)
			check(bank.enable_league_rules(rules), "old wallet profile " + league)
		for pair: Array in [[3, true], [4, false], [0, true], [6, true], [9, true]]:
			var command: Dictionary = _reward(bank, pair[0], pair[1])
			if league == "earnings":
				command["own_runs"] = 3 if pair[1] else 0
				command["opponent_runs"] = 0 if pair[1] else 3
			var before_cash: int = bank.cash()
			var expected: int = (
				(16 if pair[1] else 10) if league == "sponsorship" else (18 if pair[1] else 12)
			)
			check(
				bank.commit(command).ok and bank.cash() == before_cash + expected,
				"old ordinary reward and order " + league
			)
			check(
				SeasonDoubleheaderRules.bonus(rules, pair[0], pair[1], bank.view().rewards) == 0,
				"old rules never sweep " + league
			)
		var restored: SeasonOwnership = SeasonOwnership.from_data(cold(bank.to_data()))
		check(
			restored != null and restored.to_data() == bank.to_data(),
			"old reward JSON replay " + league
		)

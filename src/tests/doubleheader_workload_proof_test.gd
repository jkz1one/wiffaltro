extends Node
## Controlled chronological proof contracts; actual paired physical games are separate.

var checks: int = 0
var failures: int = 0
var roster: Array = []
var bank: SeasonOwnership
var wallet: Dictionary
var receipt: String


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	roster = SeasonPlayerCatalog.ids().slice(0, 4)
	bank = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(
		bank.enable_league_rules(LeagueRules.capture("doubleheader")), "explicit workload profile"
	)
	for game in range(3):
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})).ok,
			"fixture credits"
		)
	check(
		(
			bank
			. commit(
				OwnershipFixtures.request(
					bank, "stock", {"offers": {"recovery": "C02", "sponsor": "B03"}}
				)
			)
			. ok
		),
		"fixture stock"
	)
	check(bank.commit(OwnershipFixtures.buy(bank, "sponsor")).ok, "paid Strikecraft")
	check(bank.commit(OwnershipFixtures.buy(bank, "recovery")).ok, "paid Recovery Pack")
	wallet = bank.view()
	receipt = wallet.held[0].id
	var row: Dictionary = _case()
	var before: Dictionary = row.duplicate(true)
	check(_valid(row), "release, paid recovery and earned refund reconcile")
	check(row == before, "proof validation is read-only")
	check(
		PhysicalWorkloadEvidence.net_cost(row.proof)[roster[0]] == 8.625,
		"net absolute workload8.625"
	)
	var preserved: Dictionary = {"player.retired-fixture": 77.0}
	check(
		(
			PhysicalWorkloadEvidence.net_debt(row.proof, preserved).get("player.retired-fixture")
			== 77.0
		),
		"debt projection never drops inactive identities"
	)
	var bad: Dictionary
	for key: String in ["paid", "before", "after"]:
		bad = row.duplicate(true)
		bad.proof.events[0][key] += 1.0
		check(not _valid(bad), "single-field release " + key + " tamper rejected")
	bad = row.duplicate(true)
	# Coherent lower paid/after values still cannot bypass the recorded release-cost equation.
	bad.proof.events[0].paid -= 1.0
	bad.proof.events[0].after += 1.0
	bad.proof.events[1].before += 1.0
	check(not _valid(bad), "coordinated lower cost and repaired chronology rejected")
	bad = row.duplicate(true)
	bad.proof.events[0].effort = 0.0
	check(not _valid(bad), "out-of-range physical effort rejected")
	bad = row.duplicate(true)
	bad.proof.remaining[roster[0]] += 1.0
	check(not _valid(bad), "remaining stamina cannot invent healing")
	bad = row.duplicate(true)
	bad.proof.events[1].receipt = "unowned"
	check(not _valid(bad), "recovery exact paid receipt required")
	bad = row.duplicate(true)
	bad.proof.events[1].player = roster[1]
	check(not _valid(bad), "recovery identity substitution refused")
	bad = row.duplicate(true)
	bad.proof.events[1].pa = 1
	check(not _valid(bad), "recovery cannot occur after a released pitch in same PA")
	bad = row.duplicate(true)
	bad.proof.events[-1].amount += 1.0
	check(not _valid(bad), "refund amount bounded by actual three-recipe costs")
	bad = row.duplicate(true)
	bad.proof.events[3].recipe = bad.proof.events[2].recipe
	bad.pitching.releases[2].recipe = bad.pitching.releases[1].recipe
	check(not _valid(bad), "three distinct recipes required for refund")
	bad = row.duplicate(true)
	bad.pitching.strikeouts.clear()
	bad.performance[roster[0]].p_k = 0
	check(not _valid(bad), "refund requires actual strikeout")
	bad = row.duplicate(true)
	bad.tactics.append({"receipt": "another-supply", "player": roster[0], "pa": 2, "swing": ""})
	check(not _valid(bad), "Recovery cannot share its PA with another supply")
	bad = row.duplicate(true)
	bad.tactics.append(bad.tactics[0].duplicate(true))
	check(not _valid(bad), "duplicate consumed receipt rejects")
	bad = row.duplicate(true)
	bad.tactics.clear()
	check(not _valid(bad), "recovery must link actual consumed action")
	check(not _valid(row, 1), "sale cutoff before refund denies credit")
	check(_valid(row, 2), "sale during refund PA retains effect through that PA")
	bad = row.duplicate(true)
	bad.proof.events.pop_back()
	bad.proof.remaining[roster[0]] = 88.5
	check(_valid(bad, 1), "retired sponsor has no later automatic refund")
	check(not _valid(bad, 2), "eligible automatic refund cannot disappear")
	bad = row.duplicate(true)
	bad.proof.events.pop_at(0)
	check(not _valid(bad), "release omission rejected")
	bad = row.duplicate(true)
	bad.pair = {"game": 3, "first": 0, "debt": {roster[0]: 20.0}}
	check(not _valid(bad), "second game cannot reset prior debt")
	bad = _empty_case({"game": 3, "first": 0, "debt": {roster[0]: 120.0}}, 100.0)
	check(_valid(bad), "over-capacity debt produces zero, not scaled stamina")
	check(
		PhysicalWorkloadEvidence.net_debt(bad.proof, bad.pair.debt)[roster[0]] == 120.0,
		"overflow debt preserved even when remaining is zero"
	)
	bad.proof.initial[roster[0]].initial = 1.0
	bad.proof.remaining[roster[0]] = 1.0
	check(not _valid(bad), "one-point overflow healing refused")
	bad = _empty_case({"game": 3, "first": 0, "debt": {roster[0]: 40.0}}, 150.0)
	check(
		_valid(bad) and bad.proof.initial[roster[0]].initial == 110.0,
		"capacity gain preserves absolute40 debt"
	)
	check(
		not PhysicalWorkloadEvidence.pair_valid({"game": 3, "first": -1, "debt": {roster[0]: 1.0}}),
		"reset leg cannot conceal debt"
	)
	check(
		not PhysicalWorkloadEvidence.pair_valid({"game": 4, "first": 0, "debt": {}}),
		"wrong predecessor rejected"
	)
	var malformed: TeamMatchState = TeamMatchState.new()
	malformed.league_rules = LeagueRules.capture("doubleheader")
	malformed.league_ownership = bank.to_data()
	malformed.league_pair = {"game": 0, "first": -1, "debt": {}}
	malformed.roster.assign([null, null, null, null])
	check(
		not PhysicalLeagueReport.team_valid(malformed),
		"four null players reject without dereference"
	)
	check(
		not PhysicalWorkloadEvidence.valid_for_team(
			row.proof, malformed, row.performance, row.pitching, row.tactics, 99999
		),
		"direct malformed proof team rejects"
	)
	var unfinished: MatchState = MatchState.new()
	unfinished.away_team = malformed
	malformed.recovery.workload_initial = row.proof.initial.duplicate(true)
	check(
		PhysicalWorkloadEvidence.capture_human(unfinished, malformed).is_empty(),
		"unfinished game cannot issue completed human proof"
	)
	unfinished.phase = MatchState.Phase.GAME_END
	check(
		PhysicalWorkloadEvidence.capture_human(unfinished, TeamMatchState.new()).is_empty(),
		"unrelated team cannot issue proof"
	)
	var stripped: MatchState = MatchState.new()
	stripped.away_team = TeamMatchState.new()
	stripped.home_team = TeamMatchState.new()
	stripped.away_team.league_pair = {"game": 0, "first": -1, "debt": {}}
	check(
		not PhysicalLeagueReport.capture_context_valid(stripped),
		"stripped rules and ownership cannot hide a retained Doubleheader pair"
	)
	stripped.away_team.league_pair.clear()
	stripped.home_team.recovery.workload_initial = row.proof.initial.duplicate(true)
	check(
		not PhysicalLeagueReport.capture_context_valid(stripped),
		"stripped headers cannot hide Doubleheader workload recorder"
	)
	var other_bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(
		other_bank.enable_league_rules(LeagueRules.capture("dugout")), "replacement profile fixture"
	)
	stripped.league_rules = LeagueRules.capture("dugout")
	for team: TeamMatchState in [stripped.away_team, stripped.home_team]:
		team.league_rules = stripped.league_rules.duplicate(true)
		team.league_ownership = other_bank.to_data()
	check(
		not PhysicalLeagueReport.capture_context_valid(stripped),
		"replacing Doubleheader headers with another valid profile cannot launder recorder"
	)
	var terminal: Dictionary = _case()
	terminal.proof.events.resize(2)
	terminal.proof.remaining[roster[0]] = 100.0
	terminal.performance[roster[0]] = {"pa": 1, "pitches": 1, "p_k": 0}
	terminal.pitching.releases.resize(1)
	terminal.pitching.strikeouts.clear()
	check(_valid(terminal), "terminal pre-release C02 proof accepts live integers")
	check(
		_valid(JSON.parse_string(JSON.stringify(terminal, "", true, true))),
		"terminal pre-release C02 proof accepts cold numeric halves"
	)
	var switched: Dictionary = _empty_case({"game": 3, "first": 0, "debt": {roster[0]: 20.0}})
	switched.proof.events.append(
		{
			"kind": "recovery",
			"pa": 1,
			"half": 0,
			"player": roster[0],
			"receipt": receipt,
			"before": 80.0,
			"after": 90.0
		}
	)
	var switched_release: Dictionary = _release(roster[1], 1, "pitch.two", 5.0, 100.0)
	switched.proof.events.append(switched_release)
	switched.proof.remaining[roster[0]] = 90.0
	switched.proof.remaining[roster[1]] = 95.0
	switched.performance[roster[1]] = {"pa": 1, "pitches": 1, "p_k": 0}
	switched.pitching.releases.append(_release_row(switched_release))
	switched.tactics = [{"receipt": receipt, "player": roster[0], "pa": 1, "swing": ""}]
	check(_valid(switched), "C02 then different pitcher releases same PA live")
	check(
		_valid(JSON.parse_string(JSON.stringify(switched, "", true, true))),
		"C02 then different pitcher releases same PA cold"
	)
	check(
		ClubCareer.same(
			PhysicalWorkloadEvidence.net_cost(switched.proof),
			PhysicalWorkloadEvidence.net_cost(
				JSON.parse_string(JSON.stringify(switched.proof, "", true, true))
			)
		),
		"C02 net debt projects identically live and cold"
	)
	_projection_cold_cycles()
	_cost_binding()
	_b03_limit()
	print("Doubleheader workload proof checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _valid(row: Dictionary, through: int = 99999) -> bool:
	return PhysicalWorkloadEvidence.valid(
		row.proof, roster, row.performance, row.pitching, row.tactics, wallet, row.pair, through
	)


func _empty_case(pair: Dictionary, capacity: float = 100.0) -> Dictionary:
	var proof: Dictionary = {"version": 1, "initial": {}, "events": [], "remaining": {}}
	var performance: Dictionary = {}
	for id: String in roster:
		var initial: float = maxf(0.0, capacity - float(pair.debt.get(id, 0.0)))
		proof.initial[id] = {"capacity": capacity, "initial": initial}
		proof.remaining[id] = initial
		performance[id] = {"pa": 0, "pitches": 0, "p_k": 0}
	return {
		"pair": pair,
		"proof": proof,
		"performance": performance,
		"pitching": {"releases": [], "strikeouts": [], "calls": []},
		"tactics": []
	}


func _case() -> Dictionary:
	var row: Dictionary = _empty_case({"game": 0, "first": -1, "debt": {}})
	var id: String = roster[0]
	row.performance[id] = {"pa": 2, "pitches": 4, "p_k": 1}
	row.proof.events = [
		_release(id, 1, "pitch.two", 5.0, 100.0),
		{
			"kind": "recovery",
			"pa": 2,
			"half": 0,
			"player": id,
			"receipt": receipt,
			"before": 95.0,
			"after": 100.0
		},
		_release(id, 2, "pitch.one", 4.0, 100.0),
		_release(id, 2, "pitch.two", 5.0, 96.0),
		_release(id, 2, "pitch.three", 2.5, 91.0),
		{
			"kind": "refund",
			"pa": 2,
			"half": 0,
			"player": id,
			"amount": 2.875,
			"before": 88.5,
			"after": 91.375
		}
	]
	row.proof.remaining[id] = 91.375
	for event: Dictionary in row.proof.events:
		if event.kind == "release":
			row.pitching.releases.append(_release_row(event))
	row.pitching.strikeouts = [{"pa": 2, "half": 0, "player": id}]
	row.tactics = [{"receipt": receipt, "player": id, "pa": 2, "swing": ""}]
	return row


func _release(id: String, pa: int, recipe: String, paid: float, before: float) -> Dictionary:
	var recipes: Dictionary = {
		"pitch.one": "pitch.knuckleball",
		"pitch.two": "pitch.overhand_four_seam",
		"pitch.three": "pitch.eephus"
	}
	var actual: String = recipes.get(recipe, recipe)
	var pitch: PitchDefinition = ContentDB.get_pitch(StringName(actual))
	return {
		"kind": "release",
		"pa": pa,
		"half": 0,
		"player": id,
		"recipe": actual,
		"paid": paid,
		"before": before,
		"after": before - paid,
		"effort": 1.0,
		"overdrive": 0.0,
		"base_cost": pitch.stamina_cost,
		"gear_scale": 1.0,
		"sponsor_scale": 1.0
	}


func _release_row(event: Dictionary) -> Dictionary:
	return {"pa": event.pa, "half": event.half, "player": event.player, "recipe": event.recipe}


func _b03_limit() -> void:
	var row: Dictionary = _empty_case({"game": 0, "first": -1, "debt": {}})
	var id: String = roster[0]
	var current: float = 100.0
	for pa in range(1, 4):
		for recipe: String in ["pitch.knuckleball", "pitch.overhand_four_seam", "pitch.eephus"]:
			var cost: float = ContentDB.get_pitch(StringName(recipe)).stamina_cost
			var event: Dictionary = _release(id, pa, recipe, cost, current)
			row.proof.events.append(event)
			row.pitching.releases.append(_release_row(event))
			current -= cost
		row.pitching.strikeouts.append({"pa": pa, "half": 0, "player": id})
		if pa <= 2:
			row.proof.events.append(
				{
					"kind": "refund",
					"pa": pa,
					"half": 0,
					"player": id,
					"amount": 2.875,
					"before": current,
					"after": current + 2.875
				}
			)
			current += 2.875
	row.performance[id] = {"pa": 3, "pitches": 9, "p_k": 3}
	row.proof.remaining[id] = current
	check(_valid(row), "two B03 refunds remain valid across three strikeouts")
	row.proof.events.append(
		{
			"kind": "refund",
			"pa": 3,
			"half": 0,
			"player": id,
			"amount": 2.875,
			"before": current,
			"after": current + 2.875
		}
	)
	row.proof.remaining[id] += 2.875
	check(not _valid(row), "third B03 refund remains forbidden")


func _cost_binding() -> void:
	var team: TeamMatchState = TeamMatchState.new()
	team.league_rules = LeagueRules.capture("doubleheader")
	team.league_pair = {"game": 0, "first": -1, "debt": {}}
	team.league_ownership = bank.to_data()
	for id: String in roster:
		var definition: PlayerDefinition = ContentDB.get_player(StringName(id)).duplicate(true)
		definition.starting_pitches.assign(
			[
				ContentDB.get_pitch(&"pitch.knuckleball"),
				ContentDB.get_pitch(&"pitch.overhand_four_seam"),
				ContentDB.get_pitch(&"pitch.eephus")
			]
		)
		var player: PlayerMatchState = PlayerMatchState.create(definition)
		player.stamina_max = 100.0
		player.stamina_remaining = 100.0
		team.roster.append(player)
	var row: Dictionary = _case()
	check(
		PhysicalWorkloadEvidence.valid_for_team(
			row.proof, team, row.performance, row.pitching, row.tactics, 99999
		),
		"immutable definitions bind actual release cost"
	)
	var bad: Dictionary = row.duplicate(true)
	bad.proof.events[0].gear_scale = 0.8
	bad.proof.events[0].paid = 4.0
	bad.proof.events[0].after = 96.0
	bad.proof.events[1].before = 96.0
	check(_valid(bad), "coherent forged factor is structurally self-consistent")
	check(
		not PhysicalWorkloadEvidence.valid_for_team(
			bad.proof, team, bad.performance, bad.pitching, bad.tactics, 99999
		),
		"authoritative definitions reject forged cheaper gear factor"
	)
	# Two pitchers participate in PA1. Both leave their D02 first-batter state at PA2.
	row = _empty_case(team.league_pair)
	for index in range(2):
		team.roster[index].definition.season_gear["misc"] = "D02"
	for pa in range(1, 3):
		for index in range(2):
			var id: String = roster[index]
			var before: float = row.proof.remaining[id]
			var scale: float = 0.85 if pa == 1 else 1.1
			var event: Dictionary = _release(id, pa, "pitch.two", 5.0 * scale, before)
			event.gear_scale = scale
			row.proof.events.append(event)
			row.pitching.releases.append(_release_row(event))
			row.proof.remaining[id] = event.after
			row.performance[id].pitches += 1
	row.performance[roster[0]].pa = 2
	check(
		PhysicalWorkloadEvidence.valid_for_team(
			row.proof, team, row.performance, row.pitching, [], 99999
		),
		"D02 completes first batter for all PA release participants"
	)
	var definitions: Dictionary = {}
	for player: PlayerMatchState in team.roster:
		var definition: PlayerDefinition = player.definition.duplicate(true)
		definition.season_gear.clear()
		definitions[String(definition.id)] = definition
	# Sale during PA1 keeps its old cost through PA1, and removes it in PA2.
	for index in range(2):
		var event: Dictionary = row.proof.events[index + 2]
		event.gear_scale = 1.0
		event.paid = 5.0
		event.after = event.before - 5.0
		row.proof.remaining[event.player] = event.after
	check(
		PhysicalWorkloadEvidence.valid_for_team(
			row.proof,
			team,
			row.performance,
			row.pitching,
			[],
			99999,
			[{"after": 1, "definitions": definitions}]
		),
		"cost sale boundary remains inclusive and applies next PA"
	)
	check(
		not PhysicalWorkloadEvidence.valid_for_team(
			row.proof, team, row.performance, row.pitching, [], 99999
		),
		"missing authoritative sale transition rejects changed costs"
	)
	# Higher mastery stays bound to the actual definition. Gear/B02 sales can share a
	# boundary or occur at distinct boundaries; snapshots are cumulative.
	for player: PlayerMatchState in team.roster:
		player.definition.season_gear.clear()
		player.definition.season_sponsors.clear()
	var mastered: PitchDefinition = PitchMastery.apply(
		ContentDB.get_pitch(&"pitch.overhand_four_seam"), 2
	)
	team.roster[0].definition.starting_pitches.assign([mastered])
	team.roster[0].definition.natural_delivery = mastered.delivery_profile
	team.roster[0].definition.season_gear["misc"] = "D02"
	team.roster[0].definition.season_sponsors["B02"] = 4
	for retirement in [1, 2]:
		var gear_sold: Dictionary = {}
		var sponsor_sold: Dictionary = {}
		for player: PlayerMatchState in team.roster:
			var definition: PlayerDefinition = player.definition.duplicate(true)
			definition.season_gear.clear()
			gear_sold[String(definition.id)] = definition
			var after: PlayerDefinition = definition.duplicate(true)
			after.season_sponsors.erase("B02")
			sponsor_sold[String(after.id)] = after
		row = _empty_case(team.league_pair)
		var id: String = roster[0]
		for pa in range(1, 4):
			var gear_scale: float = 0.85 if pa == 1 else 1.0
			var sponsor_scale: float = 0.88 if pa <= retirement else 1.0
			var event: Dictionary = _release(
				id,
				pa,
				String(mastered.id),
				mastered.stamina_cost * gear_scale * sponsor_scale,
				row.proof.remaining[id]
			)
			event.base_cost = mastered.stamina_cost
			event.gear_scale = gear_scale
			event.sponsor_scale = sponsor_scale
			row.proof.events.append(event)
			row.pitching.releases.append(_release_row(event))
			row.proof.remaining[id] = event.after
		row.performance[id] = {"pa": 3, "pitches": 3, "p_k": 0}
		var timeline: Array = [
			{"after": 1, "definitions": gear_sold},
			{"after": retirement, "definitions": sponsor_sold}
		]
		check(
			PhysicalWorkloadEvidence.valid_for_team(
				row.proof, team, row.performance, row.pitching, [], 99999, timeline
			),
			"mastery2 and B02 cumulative sale cutoff " + str(retirement)
		)
		timeline[1].after = 0
		check(
			not PhysicalWorkloadEvidence.valid_for_team(
				row.proof, team, row.performance, row.pitching, [], 99999, timeline
			),
			"out-of-order B02 cost timeline rejects"
		)


# Exact pre-fix projection retained solely to expose the cancellation regression.
func _old_net_cost(proof: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in proof.initial:
		result[id] = 0.0
	for event: Dictionary in proof.events:
		result[event.player] += float(event.before) - float(event.after)
	return result


func _projection_cold_cycles() -> void:
	var row: Dictionary = _empty_case({"game": 0, "first": -1, "debt": {}}, 210.6)
	var id: String = roster[0]
	var current: float = 210.6
	for index in range(8):
		row.proof.events.append(_release(id, 1, "pitch.two", 5.0, current))
		current -= 5.0
	row.proof.remaining[id] = current
	var cold: Dictionary = JSON.parse_string(JSON.stringify(row.proof, "", true, true))
	print(
		"WORKLOAD_OLD_PROJECTION live=",
		JSON.stringify(_old_net_cost(row.proof), "", true, true),
		" cold=",
		JSON.stringify(_old_net_cost(cold), "", true, true)
	)
	var build: SeasonBuild = SeasonBuild.new(1, roster)
	check(
		build.enable_league_rules(LeagueRules.capture("doubleheader")),
		"drift fixture uses actual Build profile"
	)
	var actual_capacity: float = PlayerMatchState.create(build.definition(id)).stamina_max
	var actual: Dictionary = _empty_case({"game": 0, "first": -1, "debt": {}}, actual_capacity)
	var actual_current: float = actual_capacity
	for index in range(8):
		actual.proof.events.append(_release(id, 1, "pitch.two", 5.0, actual_current))
		actual_current -= 5.0
	actual.proof.remaining[id] = actual_current
	var actual_cold: Dictionary = JSON.parse_string(JSON.stringify(actual.proof, "", true, true))
	print(
		"WORKLOAD_OLD_BUILD_PROJECTION live=",
		JSON.stringify(_old_net_cost(actual.proof), "", true, true),
		" cold=",
		JSON.stringify(_old_net_cost(actual_cold), "", true, true),
		" capacity=",
		JSON.stringify(actual_capacity, "", true, true)
	)
	check(
		(
			PhysicalWorkloadEvidence.net_cost(actual.proof)[id] == 40.0
			and PhysicalWorkloadEvidence.net_cost(actual_cold)[id] == 40.0
		),
		"actual Build-derived fractional capacity retains exact40 charge live and cold"
	)
	var expected: Dictionary = PhysicalWorkloadEvidence.net_cost(row.proof)
	check(expected[id] == 40.0, "eight exact paid5 releases retain exact debt40")
	# Add clipped Recovery with fractional balances, then repeatedly cold-save it.
	cold.events.append(
		{
			"kind": "recovery",
			"pa": 2,
			"half": 0,
			"player": id,
			"receipt": receipt,
			"before": current,
			"after": current + 21.06
		}
	)
	cold.remaining[id] = current + 21.06
	expected = PhysicalWorkloadEvidence.net_cost(cold)
	var stable: bool = true
	for cycle in range(100):
		var next: Dictionary = JSON.parse_string(JSON.stringify(cold, "", true, true))
		stable = (
			stable
			and ClubCareer.same(cold, next)
			and ClubCareer.same(expected, PhysicalWorkloadEvidence.net_cost(next))
		)
		cold = next
	check(stable, "100 full-precision cold cycles preserve canonical C02 debt exactly")

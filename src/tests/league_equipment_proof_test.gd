extends Node
## Closed Equipment contracts. Synthetic funding/credited samples are not earned season play.
## No production edits, public admission, canonical saves, or implicit active fourth slot.

var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	_inactive_effects()
	_zero_budget()
	_cold_swap_history()
	print("Equipment proof checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func paid_bank(sponsors: Array = [], active: Array = [], spare: String = "") -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(
		bank.enable_league_rules(LeagueRules.capture("equipment")), "paid fixture Equipment header"
	)
	for game: int in range(8):
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})).ok,
			"explicit synthetic funding"
		)
	for item: String in sponsors + active:
		check(buy_bank(bank, item).ok, "paid fixture catalog purchase " + item)
	if not spare.is_empty():
		check(buy_bank(bank, spare, true).ok, "paid fixture inactive spare purchase")
	return bank


func buy_bank(bank: SeasonOwnership, item: String, spare: bool = false) -> Dictionary:
	var offer: String = "equipment-proof:%d" % bank.revision()
	var stocked: Dictionary = bank.commit(
		OwnershipFixtures.request(bank, "stock", {"offers": {offer: item}})
	)
	check(stocked.ok, "stock exact real catalog offer")
	return bank.commit(
		OwnershipFixtures.request(
			bank, "spare_buy" if spare else "buy", {"offer": offer, "replace": "", "discard": []}
		)
	)


func detached_request(human_bank: SeasonOwnership, ai_bank: SeasonOwnership) -> MatchState:
	# Real draft/team builders, but detached synthetic paid journals; never save this season.
	var season: SeasonState = SeasonState.create_closed_league(
		443, LeagueRules.capture("equipment"), true
	)
	for pick: int in range(4):
		check(season.choose_player(season.offers()[0]), "detached draft")
	season.build._bank = human_bank
	season.opponents.clubs["1"].build._bank = ai_bank
	var state: MatchState = MatchState.create(season._make_team(1, 8), season._make_team(0, 8))
	state.league_rules = LeagueRules.capture("equipment")
	state.home_team.track_bases = true
	state.gear_usage.equipped = SeasonReclamation.receipts(human_bank.view())
	return state


func player_signature(player: PlayerDefinition) -> Dictionary:
	var stats: Array = []
	for key: String in [
		"contact", "power", "fielding", "velocity", "break_rating", "control", "stamina"
	]:
		stats.append(player.get(key))
	var factors: Dictionary = {}
	for key: String in [
		"radius",
		"exit",
		"timing",
		"velocity",
		"movement",
		"command",
		"workload",
		"speed",
		"handling",
		"reaction"
	]:
		factors[key] = SeasonGearCatalog.factor(player, key)
	var pitches: Array = []
	for pitch: PitchDefinition in player.starting_pitches:
		pitches.append(String(pitch.id))
	return {
		"stats": stats,
		"gear": player.season_gear.duplicate(true),
		"factors": factors,
		"pitches": pitches,
		"sponsors": player.season_sponsors.duplicate(true),
		"abilities": player.season_abilities.duplicate()
	}


func _inactive_effects() -> void:
	for spare_item: String in ["BAT-POW-01", "BALL-VEL-01", "MISC-BAT-01"]:
		var bank: SeasonOwnership = paid_bank([], ["BAT-CON-01", "BALL-MOV-01", "MISC-PIT-03"])
		var ai: SeasonOwnership = paid_bank()
		var before_state: MatchState = detached_request(bank, ai)
		var before: Array = []
		for player: PlayerMatchState in before_state.home_team.roster:
			before.append(player_signature(player.definition))
		var active_ids: Array[String] = SeasonReclamation.receipts(bank.view())
		var active_receipts: Dictionary = bank.view().gear.duplicate(true)
		check(buy_bank(bank, spare_item, true).ok, "buy paid inactive " + spare_item)
		var wallet: Dictionary = bank.view()
		check(
			wallet.gear.keys() == ["bat", "ball", "misc"] and wallet.gear == active_receipts,
			"spare does not become a fourth active slot or replace any active receipt"
		)
		check(
			(
				wallet.spare.item == spare_item
				and wallet.spare.paid == SeasonGearCatalog.item(spare_item).price
			),
			"spare retains exact independently paid identity"
		)
		var state: MatchState = detached_request(bank, ai)
		var captured: MatchState = PhysicalMatchRequest.capture(state)
		check(captured != null, "paid spare request admitted")
		if captured == null:
			continue
		for index: int in range(4):
			check(
				player_signature(state.home_team.roster[index].definition) == before[index],
				"inactive spare changes no rating, recipe, ability, sponsor or active Gear factor"
			)
			check(
				player_signature(captured.home_team.roster[index].definition) == before[index],
				"immutable physical request carries active effects only"
			)
		check(
			(
				(
					PhysicalLeagueReport
					. wallet(captured.league_rules, captured.home_team.league_ownership)
					. spare
				)
				== wallet.spare
			),
			"request separately retains full inactive paid journal"
		)
		check(
			(
				captured.gear_usage.equipped == active_ids
				and not captured.gear_usage.equipped.has(wallet.spare.id)
			),
			"first-release candidate list contains only three active paid receipts"
		)
		var original_gear: Dictionary = state.home_team.roster[0].definition.season_gear.duplicate(
			true
		)
		state.home_team.roster[0].definition.season_gear["spare"] = wallet.spare.item
		check(
			PhysicalMatchRequest.capture(state) == null,
			"request rejects injected fourth active spare effect"
		)
		state.home_team.roster[0].definition.season_gear = original_gear.duplicate(true)
		var slot: String = SeasonGearCatalog.item(wallet.spare.item).slot
		state.home_team.roster[0].definition.season_gear[slot] = wallet.spare.item
		check(
			PhysicalMatchRequest.capture(state) == null,
			"request rejects substituting spare for paid active effect"
		)
		state.home_team.roster[0].definition.season_gear = original_gear
		state.gear_usage.equipped.append(wallet.spare.id)
		check(
			PhysicalMatchRequest.capture(state) == null,
			"request rejects inactive first-release receipt injection"
		)
		state.gear_usage.equipped.pop_back()
		captured.begin_pitch()
		captured.cancel_pitch()
		captured.note_pitch_released(&"pitch.overhand_four_seam", 0.0)
		check(not captured.gear_usage.started, "canceled release never starts equipment use")
		captured.begin_pitch()
		captured.note_pitch_released()
		check(
			not captured.gear_usage.started, "recipe-less notification never starts equipment use"
		)
		captured.note_pitch_released(&"pitch.overhand_four_seam", 0.0)
		check(
			(
				captured.gear_usage.first_pitch == active_ids
				and not captured.gear_usage.first_pitch.has(wallet.spare.id)
			),
			"first actual release excludes inactive spare"
		)
		captured.gear_usage.equipped.clear()
		captured.note_pitch_released(&"pitch.overhand_slider", 0.0)
		check(
			captured.gear_usage.first_pitch == active_ids,
			"later notifications cannot rewrite first-release identities"
		)
		var cold: SeasonOwnership = SeasonOwnership.from_data(
			JSON.parse_string(JSON.stringify(bank.to_data())),
			SeasonSponsorCatalog.ownership_catalog()
		)
		check(
			cold != null and ClubCareer.same(cold.view(), bank.view()),
			"paid active/spare ownership cold replay"
		)


func zero_budget_bank() -> SeasonOwnership:
	var bank: SeasonOwnership = paid_bank(["E08", "F09"])
	check(
		bank.commit(OwnershipFixtures.request(bank, "charge", {"amount": bank.cash() - 4})).ok,
		"zero-capacity fixture has exact four Cash"
	)
	return bank


func _zero_budget() -> void:
	var bank: SeasonOwnership = zero_budget_bank()
	var state: MatchState = detached_request(paid_bank(), bank)
	var row: Dictionary = {
		"version": 4,
		"budget": state.away_team.ai_budget.duplicate(true),
		"initial": state.away_team.ai_tactical_initial.duplicate(true)
	}
	check(
		bank.view().capacity.held == 0 and bank.view().held.is_empty(),
		"Equipment plus Double Major has zero shared carry"
	)
	check(
		(
			row.budget.active
			and row.budget.cash == 4
			and row.budget.outcome == "full"
			and row.budget.before.is_empty()
			and row.initial.is_empty()
		),
		"E08 at zero capacity captures no grant"
	)
	check(
		PhysicalBudgetEvidence.league_shape(row, state.league_rules, bank.to_data()),
		"zero-capacity no-grant proof binds paid journal"
	)
	check(
		not PhysicalBudgetEvidence.shape(row, 12),
		"legacy capacity-two proof does not silently accept zero-capacity full"
	)
	check(
		PhysicalMatchRequest.capture(state) != null, "zero-capacity E08 physical request admitted"
	)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify({"row": row, "bank": bank.to_data()}))
	check(
		PhysicalBudgetEvidence.league_shape(parsed.row, state.league_rules, parsed.bank),
		"zero-capacity no-grant cold JSON replay"
	)
	var forged: Dictionary = row.duplicate(true)
	forged.budget.outcome = "granted"
	forged.initial.append({"id": "budget:8", "item": "C03", "paid": 0, "kind": "held"})
	check(
		not PhysicalBudgetEvidence.league_shape(forged, state.league_rules, bank.to_data()),
		"invented zero-capacity grant rejected"
	)
	var before: Dictionary = bank.to_data()
	check(
		(
			not bank.commit({"id": "budget:8", "rev": bank.revision(), "op": "budget_grant"}).ok
			and bank.to_data() == before
		),
		"direct zero-capacity grant rejected atomically"
	)
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var build: SeasonBuild = SeasonBuild.new(443, roster)
	check(build.enable_league_rules(state.league_rules), "controlled Budget build header")
	build._bank = bank
	var command: Dictionary = SeasonOpponentPolicy.command(build, "pregame", {"game": 8})
	check(
		build.commit(command).ok and build._pregames["8"] == {"cash": 4, "outcome": "full"},
		"pregame records no-grant rather than failing or queuing a copy"
	)
	var committed: Dictionary = build.to_data()
	check(
		(
			build.commit(command).replayed
			and build.to_data() == committed
			and build._bank.to_data() == before
		),
		"same no-grant pregame command cannot create a deferred receipt"
	)


func _sample(roster: Array[String]) -> Dictionary:
	# A balanced credited-event sample, deliberately not a completed physical game.
	var sample: MatchPerformance = MatchPerformance.new()
	for player: String in roster:
		sample.players[player] = MatchPerformance.empty_line()
	sample.complete(StringName(roster[0]), &"equipment.fixture.rival", "strikeout", 0)
	return sample.players.duplicate(true)


func _history_fixture() -> SeasonBuild:
	# Find ordinary deterministic stock across synthetic postgame visits. Never inject offers,
	# cash, sponsors, receipts or usage flags: the complete Build journal must replay cold.
	var roster: Array[String] = []
	roster.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	for seed_value: int in range(64):
		var build: SeasonBuild = SeasonBuild.new(seed_value, roster)
		if not build.enable_league_rules(LeagueRules.capture("equipment")):
			return null
		for game: int in range(24):
			if not (
				build
				. commit(
					SeasonOpponentPolicy.command(
						build, "reward", {"game": game, "win": true, "performance": _sample(roster)}
					)
				)
				. ok
			):
				break
			if not build.commit(SeasonOpponentPolicy.command(build, "open")).ok:
				break
			for offer: String in build.view().shop.offers:
				var item: String = build.view().shop.offers[offer]
				var fields: Dictionary = {"offer": offer, "replace": ""}
				var op: String = ""
				if item == "F05" and SeasonSchoolSponsors.active(build, "F05").is_empty():
					op = "sponsor_buy"
				elif item == "BAT-CON-01" and build.view().wallet.gear.bat.is_empty():
					op = "equip"
				elif item == "BAT-POW-01" and build.view().wallet.spare.is_empty():
					op = "spare_buy"
					fields.erase("replace")
				if not op.is_empty() and build.cash() >= (6 if item == "F05" else 10):
					if not build.commit(SeasonOpponentPolicy.command(build, op, fields)).ok:
						return null
			if (
				not build.view().wallet.gear.bat.is_empty()
				and not build.view().wallet.spare.is_empty()
				and not SeasonSchoolSponsors.active(build, "F05").is_empty()
			):
				print(
					"EQUIPMENT_HISTORY_FIXTURE seed=",
					seed_value,
					" synthetic_rewards=",
					game + 1,
					" build_events=",
					build.revision()
				)
				return build
	return null


func _cold(build: SeasonBuild, label: String) -> SeasonBuild:
	var data: Dictionary = build.to_data()
	var restored: SeasonBuild = SeasonBuild.from_data(
		JSON.parse_string(JSON.stringify(data)), build._seed, build._initial_roster
	)
	check(restored != null, label + " restores Build45")
	if restored != null:
		check(
			(
				ClubCareer.same(restored.to_data(), data)
				and ClubCareer.same(restored.view(), build.view())
				and ClubCareer.same(restored._bank.to_data(), build._bank.to_data())
			),
			label + " retains full exact receipt/use journals"
		)
	return restored


func _swap(build: SeasonBuild) -> Dictionary:
	var wallet: Dictionary = build.view().wallet
	return SeasonOpponentPolicy.command(
		build, "spare_swap", {"spare": wallet.spare.id, "active": wallet.gear.bat.id}
	)


func _cold_swap_history() -> void:
	var build: SeasonBuild = _history_fixture()
	check(build != null, "reachable deterministic paid active/spare/Reclamation fixture")
	if build == null:
		return
	var active: Dictionary = build.view().wallet.gear.bat.duplicate(true)
	var spare: Dictionary = build.view().wallet.spare.duplicate(true)
	check(build.view().used_gear.is_empty(), "synthetic funding did not invent Gear usage")
	check(
		(
			active.item == "BAT-CON-01"
			and spare.item == "BAT-POW-01"
			and active.paid == 10
			and spare.paid == 10
		),
		"real shop journal contains two exact full-price Bat receipts"
	)
	var initial_stats: Dictionary = build.player(build.roster()[0]).duplicate(true)
	var cash: int = build.cash()
	check(
		build.commit(_swap(build)).ok and build.commit(_swap(build)).ok,
		"round-trip exchanges commit without purchasing or selling either copy"
	)
	check(
		(
			build.cash() == cash
			and build.view().wallet.gear.bat == active
			and build.view().wallet.spare == spare
			and build.view().used_gear.is_empty()
			and build.player(build.roster()[0]) == initial_stats
		),
		"round-trip preserves cash, paid identities, stats and non-use"
	)
	build = _cold(build, "unused round-trip")
	if build == null:
		return
	var unused: SeasonBuild = build._fork()
	check(
		unused.commit(SeasonOpponentPolicy.command(unused, "sell_gear", {"receipt": spare.id})).ok,
		"unused spare can be sold between games"
	)
	check(
		(
			unused.cash() == cash + 5
			and SeasonReclamation.credit(unused.view().shop) == 0
			and unused.view().used_gear.is_empty()
		),
		"unused spare earns ordinary half refund and no Reclamation"
	)
	_cold(unused, "unused spare sale")
	var used: Array[String] = SeasonReclamation.receipts(build.view().wallet)
	check(used == [active.id], "controlled completed-use evidence excludes spare")
	var command: Dictionary = SeasonOpponentPolicy.command(
		build,
		"reward",
		{"game": 24, "win": true, "performance": _sample(build.roster()), "used_gear": used}
	)
	check(build.commit(command).ok, "synthetic credited completion settles exact active receipt")
	check(
		build.view().used_gear == used and not build.view().used_gear.has(spare.id),
		"only active receipt qualifies"
	)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "open")).ok,
		"next shop opens for legal exchange"
	)
	var before_swap: Dictionary = build.to_data()
	var swap_command: Dictionary = _swap(build)
	check(build.commit(swap_command).ok, "previously used active moves into spare")
	check(
		(
			build.view().wallet.spare == active
			and build.view().wallet.gear.bat == spare
			and build.view().used_gear == used
		),
		"exchange retains receipt-specific historical qualification"
	)
	check(
		(
			is_equal_approx(
				SeasonGearCatalog.factor(build.definition(build.roster()[0]), "exit"), 1.05
			)
			and build.player(build.roster()[0]) == initial_stats
		),
		"new active effect applies without changing developed ratings"
	)
	build = _cold(build, "used active moved to spare")
	if build == null:
		return
	var both: SeasonBuild = build._fork()
	check(
		(
			both
			. commit(
				SeasonOpponentPolicy.command(
					both,
					"reward",
					{
						"game": 25,
						"win": true,
						"performance": _sample(both.roster()),
						"used_gear": [spare.id]
					}
				)
			)
			. ok
		),
		"second controlled completion uses newly active receipt"
	)
	check(
		both.commit(SeasonOpponentPolicy.command(both, "open")).ok and both.commit(_swap(both)).ok,
		"both historically used copies can exchange again"
	)
	check(
		(
			both.view().used_gear.size() == 2
			and both.view().used_gear.has(active.id)
			and both.view().used_gear.has(spare.id)
		),
		"all historical use identities survive multiple exchanges"
	)
	_cold(both, "both-used round-trip")
	var sold: SeasonBuild = build._fork()
	var before_cash: int = sold.cash()
	var sale: Dictionary = SeasonOpponentPolicy.command(sold, "sell_gear", {"receipt": active.id})
	check(sold.commit(sale).ok, "sell previously used active from inactive spare")
	check(
		(
			sold.cash() == before_cash + 5
			and SeasonReclamation.credit(sold.view().shop) == 2
			and sold.view().wallet.spare.is_empty()
			and sold.view().wallet.gear.bat == spare
			and sold.view().used_gear.is_empty()
		),
		"used spare earns half refund and exact Reclamation credit, retiring its qualification"
	)
	var sold_data: Dictionary = sold.to_data()
	check(
		sold.commit(sale).replayed and sold.to_data() == sold_data,
		"sale retry never refunds or credits twice"
	)
	_cold(sold, "used spare sale")
	var bad: Dictionary = build.to_data()
	for event: Dictionary in bad.events:
		if event.id == swap_command.id:
			event.active = "foreign-active-receipt"
	check(
		SeasonBuild.from_data(bad, build._seed, build._initial_roster) == null,
		"cold journal rejects changed exchange receipt"
	)
	bad = before_swap.duplicate(true)
	for event: Dictionary in bad.events:
		if event.op == "reward" and event.game == 24:
			event.used_gear = [spare.id]
	check(
		SeasonBuild.from_data(bad, build._seed, build._initial_roster) == null,
		"cold reward rejects spare impersonating first-release active receipt"
	)
	check(
		build.view().wallet.spare == active and build.view().used_gear == used,
		"rejection probes preserve owning build"
	)

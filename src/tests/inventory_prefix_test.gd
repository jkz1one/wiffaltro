extends Node
## Controlled actual state/event plumbing, not a full physical gameplay qualification.

var checks: int = 0
var failures: int = 0
var anchor: Dictionary = {"id": "attempt:controlled", "rev": 20, "game": 0}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var fixture: Dictionary = _fixture([])
	var state: MatchState = fixture.state
	for index in range(3):
		_out(state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(state, state.home_team, anchor)
	check(_matches(proof, fixture), "three completed actual out records earn unused exact Tape")
	check(
		_matches(JSON.parse_string(JSON.stringify(proof, "", true, true)), fixture),
		"full precision cold prefix replay"
	)
	check(not PhysicalMatchReport.valid(proof), "prefix cannot masquerade as full physical report")
	var old_flow: Dictionary = proof.base.duplicate(true)
	old_flow.version = 1
	old_flow.final = MatchBaseFlow.snapshot(state)
	check(
		not PhysicalBaseFlow.valid(old_flow, proof.rosters, proof.performance),
		"historical terminal validator still rejects partial game"
	)
	var bad: Dictionary
	for key: String in ["version", "resolver", "inventory_rule", "anchor", "league_rules"]:
		bad = proof.duplicate(true)
		bad.erase(key)
		check(not _matches(bad, fixture), "header stripping rejected: " + key)
	bad = proof.duplicate(true)
	bad.anchor.rev += 1
	check(not _matches(bad, fixture), "different attempt revision rejects stale proof")
	bad = proof.duplicate(true)
	bad.field_state.grant.after_pa = 2
	check(not _matches(bad, fixture), "forged early clean tally cannot mint grant")
	bad = proof.duplicate(true)
	bad.field_state.fielding.pop_front()
	check(not _matches(bad, fixture), "omitted earlier out rejects delayed-grant forgery")
	bad = proof.duplicate(true)
	bad.field_state.fielding[0].half = 1
	check(not _matches(bad, fixture), "wrong defensive parity rejects")
	bad = proof.duplicate(true)
	bad.field_state.fielding[0].pitcher = proof.rosters[1][1]
	check(not _matches(bad, fixture), "clean out binds final released pitcher")
	bad = proof.duplicate(true)
	bad.releases[0].half = false
	check(not _matches(bad, fixture), "release half must be numeric integer, not boolean")
	bad = proof.duplicate(true)
	bad.releases.pop_back()
	check(not _matches(bad, fixture), "missing completed PA release rejects")
	bad = proof.duplicate(true)
	bad.base.results[0].outs = 2
	check(not _matches(bad, fixture), "base occupancy and outs chronology cannot be fabricated")
	bad = proof.duplicate(true)
	bad.field_state.pa += 1
	check(not _matches(bad, fixture), "unfinished current PA cannot count toward frontier")
	bad = proof.duplicate(true)
	bad.held[0].paid = 3
	check(not _matches(bad, fixture), "immutable generated copy basis cannot become purchased")
	bad = proof.duplicate(true)
	bad.held.clear()
	check(not _matches(bad, fixture), "current exact unused receipt required")
	check(
		not PhysicalInventoryPrefix.matches(
			proof, fixture.own, proof.rosters[1], 0, anchor, fixture.bank.to_data(), [], 1, false
		),
		"opponent roster independently binds"
	)
	check(
		not PhysicalInventoryPrefix.matches(
			proof, fixture.own, proof.rosters[0], 0, anchor, fixture.bank.to_data(), [], 0, false
		),
		"fixture orientation independently binds"
	)
	check(
		not PhysicalInventoryPrefix.matches(
			proof, fixture.own, proof.rosters[0], 0, anchor, fixture.bank.to_data(), [], 1, true
		),
		"prior-attempt tombstone suppresses payout"
	)
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	check(
		PhysicalInventoryPrefix.capture(state, state.home_team, anchor).is_empty(),
		"active unfinished pitch cannot capture sale proof"
	)
	state.phase = MatchState.Phase.INNING_TRANSITION
	state.league_rules.clear()
	check(
		PhysicalInventoryPrefix.capture(state, state.home_team, anchor).is_empty(),
		"live header stripping refuses capture"
	)
	_terminal()
	_unused()
	_capacity()
	_rewrite_frontier()
	_insurance_retirement()
	_b03_recovery()
	_same_pa_discard()
	_retirement(proof, fixture)
	_ledger_once(proof, fixture)
	print("Inventory prefix checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _bank(items: Array) -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	check(bank.enable_league_rules(LeagueRules.capture("dugout")), "closed paid fixture profile")
	check(
		(
			bank
			. commit({"id": "rules", "rev": bank.revision(), "op": SeasonInventoryResale.ENABLE_OP})
			. ok
		),
		"explicit inventory capability"
	)
	for game in range(20, 24):
		check(
			bank.commit(OwnershipFixtures.request(bank, "reward", {"game": game, "win": true})).ok,
			"synthetic fixture preparation credit"
		)
	var offers: Dictionary = {"sponsor": "B01"}
	for index in range(items.size()):
		offers["item%d" % index] = items[index]
	check(
		bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": offers})).ok,
		"actual catalog stock"
	)
	check(bank.commit(OwnershipFixtures.buy(bank, "sponsor")).ok, "paid Field Supply sponsor")
	for index in range(items.size()):
		check(
			bank.commit(OwnershipFixtures.buy(bank, "item%d" % index)).ok, "actual paid held copy"
		)
	return bank


func _team(ids: Array, bank: SeasonOwnership) -> TeamMatchState:
	var definitions: Array[PlayerDefinition] = []
	for id: String in ids:
		var definition: PlayerDefinition = ContentDB.get_player(StringName(id)).duplicate(true)
		definition.season_sponsors["B01"] = true
		definitions.append(definition)
	var team: TeamMatchState = TeamMatchState.create("Controlled prefix fixture", definitions)
	team.league_rules = LeagueRules.capture("dugout")
	team.league_ownership = bank.to_data()
	team.track_bases = true
	team.tactics.held = SeasonTacticalCatalog.held(bank.view())
	team.field_supply.receipt = SeasonFieldGrant.receipt(0)
	MatchFieldSupply.sync_capacity(team, bank.view())
	return team


func _fixture(items: Array) -> Dictionary:
	var bank: SeasonOwnership = _bank(items)
	var all_ids: Array = SeasonPlayerCatalog.ids()
	var away: TeamMatchState = _team(all_ids.slice(4, 8), bank)
	var home: TeamMatchState = _team(all_ids.slice(0, 4), bank)
	var state: MatchState = MatchState.create(away, home)
	state.league_rules = LeagueRules.capture("dugout")
	state.home_team.field_supply.receipt = SeasonFieldGrant.receipt(0)
	return {
		"state": state,
		"own": _team(all_ids.slice(0, 4), bank),
		"bank": bank,
		"opponent": all_ids.slice(4, 8)
	}


func _out(state: MatchState, dirty: bool = false) -> void:
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	state.base_flow.prepare(state)
	var pitch: PitchDefinition = state.pitcher().definition.starting_pitches[0]
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	state.pitcher().spend_stamina(pitch.stamina_cost)
	state.note_pitch_released(pitch.id, pitch.stamina_cost)
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(&"field.starter_backyard"), false)
	if dirty:
		resolver.record_bobble(&"primary_fielder", Vector3(0, 1, 15))
	var outcomes: Array = []
	resolver.play_resolved.connect(func(outcome: BallPlayOutcome) -> void: outcomes.append(outcome))
	resolver.record_clean_control(&"primary_fielder", Vector3(0, 1, 15), false)
	state.clean_outs.record(state, resolver.state, outcomes[0])
	state.record_ball_in_play_out()


func _matches(proof: Dictionary, fixture: Dictionary, sales: Array = []) -> bool:
	return PhysicalInventoryPrefix.matches(
		proof, fixture.own, fixture.opponent, 0, anchor, fixture.bank.to_data(), sales, 1, false
	)


func _capacity() -> void:
	for items: Array in [["A10", "C03", "C02"], ["A10", "C03", "development.contact"]]:
		var full: Dictionary = _fixture(items)
		for index in range(3):
			_out(full.state)
		var proof: Dictionary = PhysicalInventoryPrefix.capture(
			full.state, full.state.home_team, anchor
		)
		check(
			proof.field_state.grant.outcome == "full" and not _matches(proof, full),
			"full shared bag including development occupancy cannot mint Tape cash"
		)
		proof.field_state.grant.outcome = "granted"
		proof.held = [SeasonFieldGrant.copy(0)]
		check(not _matches(proof, full), "later free room cannot rescue forfeited grant")
	var used: Dictionary = _fixture(["C02", "A10", "C03"])
	_out(used.state)
	used.state.phase = MatchState.Phase.PRE_PITCH
	var receipt: String = used.state.home_team.tactics.held[0].id
	check(
		used.state.home_team.tactics.activate(used.state, used.state.home_team, receipt),
		"actual paid Recovery creates legal bag space before third out"
	)
	_out(used.state)
	_out(used.state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		used.state, used.state.home_team, anchor
	)
	check(_matches(proof, used), "exact initial receipt use permits later earned grant")
	var duplicate: Dictionary = proof.duplicate(true)
	duplicate.field_state.uses.append(duplicate.field_state.uses[0].duplicate(true))
	check(not _matches(duplicate, used), "duplicate use cannot create extra capacity")
	duplicate = proof.duplicate(true)
	duplicate.field_state.uses[0]["combo"] = 1
	check(not _matches(duplicate, used), "optional activation flags require explicit booleans")


func _retirement(proof: Dictionary, fixture: Dictionary) -> void:
	var before: Dictionary = fixture.bank.view()
	var copy: Dictionary = before.sponsors[0]
	var sold: SeasonOwnership = SeasonOwnership.from_data(
		fixture.bank.to_data(), SeasonSponsorCatalog.ownership_catalog()
	)
	check(
		(
			sold
			. commit(
				{
					"id": "sold-sponsor",
					"rev": sold.revision(),
					"op": SeasonInventoryResale.SALE_OP,
					"receipt": copy.id
				}
			)
			. ok
		),
		"actual sponsor retirement fixture"
	)
	var sale: Dictionary = {
		"pa": 4,
		"boundary": 3,
		"discard": [],
		"capacity": sold.view().capacity.held,
		"retired": true,
		"sold_receipt": copy.id,
		"before": before,
		"after": sold.view(),
		"uses": [],
		"field_state": proof.field_state.duplicate(true)
	}
	check(
		_matches(proof, fixture, [sale]),
		"retired sponsor retains already completed third-clean entitlement"
	)
	sale.pa = 3
	sale.boundary = 2
	check(not _matches(proof, fixture, [sale]), "retired before third clean out cannot grant")
	sale.pa = 5
	sale.boundary = 4
	check(
		not _matches(proof, fixture, [sale]), "older prefix cannot precede accepted sale frontier"
	)


func _ledger_once(proof: Dictionary, fixture: Dictionary) -> void:
	check(_matches(proof, fixture), "mint command is gated by authenticated prefix")
	var bank: SeasonOwnership = SeasonOwnership.from_data(
		fixture.bank.to_data(), SeasonSponsorCatalog.ownership_catalog()
	)
	var before: int = bank.cash()
	var command: Dictionary = {
		"id": "field-payout-attempt",
		"rev": bank.revision(),
		"op": SeasonInventoryResale.FIELD_OP,
		"game": 0
	}
	check(
		bank.commit(command).ok and bank.cash() == before + 1,
		"generated Tape refunds half normal3 once"
	)
	check(
		bank.commit(command).ok and bank.cash() == before + 1,
		"same retry request never doubles cash"
	)
	var cold: SeasonOwnership = SeasonOwnership.from_data(
		JSON.parse_string(JSON.stringify(bank.to_data(), "", true, true)),
		SeasonSponsorCatalog.ownership_catalog()
	)
	check(
		cold != null and SeasonInventoryResale.field_retired(cold, 0),
		"cold save retains retired identity"
	)
	check(
		(
			not (
				cold
				. commit(
					{
						"id": "retry-new-attempt",
						"rev": cold.revision(),
						"op": SeasonInventoryResale.FIELD_OP,
						"game": 0
					}
				)
				. ok
			)
			and cold.cash() == before + 1
		),
		"cancel/restart with new command cannot pay retired identity again"
	)
	check(
		not (
			cold
			. commit(
				{
					"id": SeasonFieldGrant.receipt(0),
					"rev": cold.revision(),
					"op": "field_grant",
					"game": 0
				}
			)
			. ok
		),
		"settlement cannot remint a sold runtime identity"
	)


func _unused() -> void:
	var fixture: Dictionary = _fixture(["A10"])
	var receipt: String = fixture.bank.view().held[0].id
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		fixture.state, fixture.state.home_team, anchor
	)
	check(
		not proof.is_empty() and proof.completed == 0,
		"safe zero-PA capture has empty completed chronology"
	)
	check(
		not (
			PhysicalInventoryPrefix
			. unused_receipt(
				proof,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				fixture.bank.to_data(),
				[],
				1,
				false,
				receipt
			)
			. is_empty()
		),
		"ordinary purchased supply can be proved unused before first PA"
	)
	check(
		not _matches(proof, fixture), "zero-PA unused authority never authorizes earned Field grant"
	)
	var bad: Dictionary = proof.duplicate(true)
	bad.performance[fixture.opponent[0]].pa = 1
	check(
		(
			PhysicalInventoryPrefix
			. unused_receipt(
				bad,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				fixture.bank.to_data(),
				[],
				1,
				false,
				receipt
			)
			. is_empty()
		),
		"zero-PA prefix rejects fabricated performance"
	)
	for index in range(3):
		_out(fixture.state)
	fixture.state.continue_after_dead_ball()
	check(
		fixture.state.home_team.tactics.activate(fixture.state, fixture.state.home_team, receipt),
		"actual original Tape consumed on home batting PA"
	)
	_out(fixture.state)
	proof = PhysicalInventoryPrefix.capture(fixture.state, fixture.state.home_team, anchor)
	check(not proof.is_empty(), "completed consumed-action prefix captured")
	check(
		(
			PhysicalInventoryPrefix
			. unused_receipt(
				proof,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				fixture.bank.to_data(),
				[],
				1,
				false,
				receipt
			)
			. is_empty()
		),
		"consumed purchased supply cannot be sold"
	)
	check(
		_matches(proof, fixture),
		"unused earned Tape remains separately authenticated after original Tape use"
	)

	var forged_walk: Dictionary = proof.duplicate(true)
	forged_walk.field_state.uses[0]["walked"] = true
	check(not _matches(forged_walk, fixture), "walk marker cannot be added to a completed out")
	var walking: Dictionary = _fixture(["A10"])
	for index in range(3):
		_out(walking.state)
	walking.state.continue_after_dead_ball()
	walking.state.home_team.tactics.track_walks = true
	var walking_receipt: String = walking.state.home_team.tactics.held[0].id
	check(
		walking.state.home_team.tactics.activate(
			walking.state, walking.state.home_team, walking_receipt
		),
		"Tape activation before actual four-ball walk"
	)
	walking.state.base_flow.prepare(walking.state)
	for pitch_index in range(4):
		var pitch: PitchDefinition = walking.state.pitcher().definition.starting_pitches[0]
		walking.state.phase = MatchState.Phase.PITCH_IN_FLIGHT
		walking.state.pitcher().spend_stamina(pitch.stamina_cost)
		walking.state.note_pitch_released(pitch.id, pitch.stamina_cost)
		walking.state.record_ball()
	var walking_proof: Dictionary = PhysicalInventoryPrefix.capture(
		walking.state, walking.state.home_team, anchor
	)
	check(
		walking_proof.field_state.uses[0].get("walked", false) and _matches(walking_proof, walking),
		"actual A10 walked=true consumption marker retains valid Field grant prefix"
	)


func _same_pa_discard() -> void:
	var fixture: Dictionary = _fixture(["C02", "A10"])
	check(
		(
			fixture
			. bank
			. commit(OwnershipFixtures.request(fixture.bank, "stock", {"offers": {"extra": "B03"}}))
			. ok
		),
		"same-PA fixture extra sponsor stock"
	)
	check(
		fixture.bank.commit(OwnershipFixtures.buy(fixture.bank, "extra")).ok,
		"same-PA fixture paid extra sponsor"
	)
	var home_ids: Array = fixture.own.roster.map(
		func(player: PlayerMatchState) -> String: return String(player.definition.id)
	)
	fixture.own = _team(home_ids, fixture.bank)
	fixture.state.home_team.league_ownership = fixture.bank.to_data()
	_out(fixture.state)
	fixture.state.phase = MatchState.Phase.PRE_PITCH
	var receipt: String = fixture.state.home_team.tactics.held[0].id
	check(
		fixture.state.home_team.tactics.activate(fixture.state, fixture.state.home_team, receipt),
		"same-PA fixture actual Recovery use"
	)
	var accepted_uses: Array = fixture.state.home_team.tactics.consumed.duplicate(true)
	_out(fixture.state)
	var before: Dictionary = fixture.bank.view()
	var sponsor: Dictionary = before.sponsors.filter(func(copy: Dictionary) -> bool: return \
		copy.item == "B03")[0]
	var sold: SeasonOwnership = SeasonOwnership.from_data(
		fixture.bank.to_data(), SeasonSponsorCatalog.ownership_catalog()
	)
	check(
		(
			sold
			. commit(
				{
					"id": "discard-used-at-sale",
					"rev": sold.revision(),
					"op": "sell",
					"receipt": sponsor.id,
					"discard": [receipt]
				}
			)
			. ok
		),
		"accepted same-PA used discard with unrelated sponsor sale"
	)
	var sale: Dictionary = {
		"pa": 2,
		"boundary": 2,
		"discard": [receipt],
		"capacity": sold.view().capacity.held,
		"retired": false,
		"sold_receipt": sponsor.id,
		"before": before,
		"after": sold.view(),
		"uses": accepted_uses,
		"field_state":
		{
			"pa": 2,
			"boundary": 2,
			"grant": {},
			"uses": accepted_uses.duplicate(true),
			"fielding":
			fixture.state.clean_outs.evidence(fixture.state.home_team).filter(
				func(row: Dictionary) -> bool: return row.pa < 2
			)
		}
	}
	_out(fixture.state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		fixture.state, fixture.state.home_team, anchor
	)
	check(
		_matches(proof, fixture, [sale]),
		"same-PA discarded use must be present in accepted sale frontier"
	)
	sale.uses.clear()
	sale.field_state.uses.clear()
	check(
		not _matches(proof, fixture, [sale]),
		"discarded copy cannot invent a later same-PA activation"
	)


func _rewrite_frontier() -> void:
	var fixture: Dictionary = _fixture(["C02", "A10", "C03"])
	for index in range(3):
		_out(fixture.state)
	var accepted: Dictionary = SeasonFieldSales.capture(fixture.state, fixture.state.home_team)
	check(accepted.grant.outcome == "full", "real third-clean delivery forfeited at full bag")
	var before: Dictionary = fixture.bank.view()
	var receipt: String = before.held[0].id
	var sold: SeasonOwnership = SeasonOwnership.from_data(
		fixture.bank.to_data(), SeasonSponsorCatalog.ownership_catalog()
	)
	check(
		(
			sold
			. commit(
				{
					"id": "later-unused-sale",
					"rev": sold.revision(),
					"op": SeasonInventoryResale.SALE_OP,
					"receipt": receipt
				}
			)
			. ok
		),
		"later unused sale opens bag after forfeiture"
	)
	fixture.state.home_team.tactics.held.remove_at(0)
	var sale: Dictionary = {
		"pa": 4,
		"boundary": 3,
		"discard": [],
		"capacity": sold.view().capacity.held,
		"retired": false,
		"sold_receipt": receipt,
		"before": before,
		"after": sold.view(),
		"uses": [],
		"field_state": accepted
	}
	fixture.state.continue_after_dead_ball()
	for index in range(3):
		_out(fixture.state)
	fixture.state.continue_after_dead_ball()
	_out(fixture.state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		fixture.state, fixture.state.home_team, anchor
	)
	var remaining: String = fixture.state.home_team.tactics.held[0].id
	check(
		not (
			PhysicalInventoryPrefix
			. unused_receipt(
				proof,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				fixture.bank.to_data(),
				[sale],
				1,
				false,
				remaining
			)
			. is_empty()
		),
		"ordinary unused receipt remains legal while old Field delivery stays forfeited"
	)
	var forged: Dictionary = proof.duplicate(true)
	forged.field_state.fielding[0].clean = false
	forged.field_state.grant = {"after_pa": 7, "outcome": "granted"}
	forged.held.append(SeasonFieldGrant.copy(0))
	check(
		not _matches(forged, fixture, [sale]),
		"cannot rewrite accepted earlier clean flags to defer forfeiture"
	)
	forged = proof.duplicate(true)
	forged.field_state.grant = {"after_pa": 3, "outcome": "granted"}
	forged.held.append(SeasonFieldGrant.copy(0))
	check(
		not _matches(forged, fixture, [sale]),
		"accepted full outcome cannot be replaced after later bag sale"
	)


func _b03_recovery() -> void:
	var fixture: Dictionary = _fixture(["C02", "A10"])
	check(
		(
			fixture
			. bank
			. commit(OwnershipFixtures.request(fixture.bank, "stock", {"offers": {"extra": "B03"}}))
			. ok
		),
		"B03 eligibility regression stock"
	)
	check(
		fixture.bank.commit(OwnershipFixtures.buy(fixture.bank, "extra")).ok,
		"B03 eligibility paid sponsor"
	)
	var ids: Array = fixture.own.roster.map(
		func(player: PlayerMatchState) -> String: return String(player.definition.id)
	)
	fixture.own = _team(ids, fixture.bank)
	fixture.state.home_team.league_ownership = fixture.bank.to_data()
	fixture.state.pitcher().definition.season_sponsors["B03"] = true
	fixture.state.base_flow.prepare(fixture.state)
	var recipes: Array = fixture.state.pitcher().definition.starting_pitches
	check(recipes.size() >= 3, "B03 fixture has three distinct actual recipes")
	for index in range(3):
		var pitch: PitchDefinition = recipes[index]
		fixture.state.phase = MatchState.Phase.PITCH_IN_FLIGHT
		fixture.state.pitcher().spend_stamina(pitch.stamina_cost)
		fixture.state.note_pitch_released(pitch.id, pitch.stamina_cost)
	fixture.state.strikes = 2
	fixture.state.record_strike()
	check(
		(
			fixture.state.home_team.strikecraft_refunded > 0.0
			and fixture.state.pitcher().stamina_remaining < fixture.state.pitcher().stamina_max
		),
		"actual B03 refund remains below total paid cost and cannot restore full stamina"
	)
	fixture.state.phase = MatchState.Phase.PRE_PITCH
	var recovery: String = fixture.state.home_team.tactics.held[0].id
	check(
		fixture.state.home_team.tactics.activate(fixture.state, fixture.state.home_team, recovery),
		"first C02 is genuinely legal after B03 refund"
	)
	_out(fixture.state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		fixture.state, fixture.state.home_team, anchor
	)
	var tape: String = fixture.state.home_team.tactics.held[0].id
	check(
		not (
			PhysicalInventoryPrefix
			. unused_receipt(
				proof,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				fixture.bank.to_data(),
				[],
				1,
				false,
				tape
			)
			. is_empty()
		),
		"prefix accepts legal prior C02 after bounded B03 refund without weakening workload proofs"
	)


func _insurance_retirement() -> void:
	var fixture: Dictionary = _fixture(["A10"])
	check(
		(
			fixture
			. bank
			. commit(OwnershipFixtures.request(fixture.bank, "stock", {"offers": {"extra": "E04"}}))
			. ok
		),
		"insurance retirement stock"
	)
	check(
		fixture.bank.commit(OwnershipFixtures.buy(fixture.bank, "extra")).ok,
		"paid insurance sponsor"
	)
	var ids: Array = fixture.own.roster.map(
		func(player: PlayerMatchState) -> String: return String(player.definition.id)
	)
	fixture.own = _team(ids, fixture.bank)
	fixture.state.home_team.league_ownership = fixture.bank.to_data()
	var receipt: String = fixture.state.home_team.tactics.held[0].id
	fixture.own.tactics.insured_receipt = receipt
	fixture.state.home_team.tactics.insured_receipt = receipt
	for player: PlayerMatchState in fixture.state.home_team.roster:
		player.definition.season_sponsors["E04"] = true
	for index in range(3):
		_out(fixture.state)
	var before_use: Dictionary = SeasonFieldSales.capture(fixture.state, fixture.state.home_team)
	fixture.state.continue_after_dead_ball()
	check(
		fixture.state.home_team.tactics.activate(fixture.state, fixture.state.home_team, receipt),
		"actual marked Tape activates while E04 owned"
	)
	_out(fixture.state)
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		fixture.state, fixture.state.home_team, anchor
	)
	check(proof.field_state.uses[0].get("insured", false), "runtime records insured activation")
	var before: Dictionary = fixture.bank.view()
	var sponsor: Dictionary = before.sponsors.filter(func(copy: Dictionary) -> bool: return \
		copy.item == "E04")[0]
	var sold: SeasonOwnership = SeasonOwnership.from_data(
		fixture.bank.to_data(), SeasonSponsorCatalog.ownership_catalog()
	)
	check(
		(
			sold
			. commit(
				{
					"id": "insurance-retired",
					"rev": sold.revision(),
					"op": SeasonInventoryResale.SALE_OP,
					"receipt": sponsor.id
				}
			)
			. ok
		),
		"actual insurance retirement journal"
	)
	var sale: Dictionary = {
		"pa": 5,
		"boundary": 4,
		"discard": [],
		"capacity": sold.view().capacity.held,
		"retired": false,
		"sold_receipt": sponsor.id,
		"before": before,
		"after": sold.view(),
		"uses": proof.field_state.uses.duplicate(true),
		"field_state": proof.field_state.duplicate(true)
	}
	check(
		_matches(proof, fixture, [sale]),
		"earlier insured use remains valid after later sponsor sale"
	)
	sale.pa = 4
	sale.boundary = 3
	sale.uses = []
	sale.field_state = before_use
	check(
		not _matches(proof, fixture, [sale]),
		"insured use after E04 retirement rejects despite retained mark"
	)


func _terminal() -> void:
	var fixture: Dictionary = _fixture([])
	for half in range(9):
		for index in range(3):
			_out(fixture.state)
		fixture.state.continue_after_dead_ball()
	var proof: Dictionary = PhysicalInventoryPrefix.capture(
		fixture.state, fixture.state.home_team, anchor
	)
	check(_matches(proof, fixture), "late nonterminal earned prefix remains valid")
	fixture.state.base_flow.prepare(fixture.state)
	var pitch: PitchDefinition = fixture.state.pitcher().definition.starting_pitches[0]
	fixture.state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	fixture.state.pitcher().spend_stamina(pitch.stamina_cost)
	fixture.state.note_pitch_released(pitch.id, pitch.stamina_cost)
	fixture.state.record_hit(BallPlayOutcome.Result.HOME_RUN)
	check(
		fixture.state.phase == MatchState.Phase.GAME_END,
		"controlled bottom-fifth walkoff reaches terminal state"
	)
	check(
		PhysicalInventoryPrefix.capture(fixture.state, fixture.state.home_team, anchor).is_empty(),
		"terminal boundary cannot capture immediate live-sale proof"
	)
	proof.completed = fixture.state.plate_appearance_number - 1
	proof.base.ready = fixture.state.base_flow.ready.duplicate(true)
	proof.base.results = fixture.state.base_flow.results.duplicate(true)
	proof.base.tags = fixture.state.base_flow.tags.duplicate(true)
	proof.base.advances = fixture.state.base_flow.advances.duplicate(true)
	proof.performance = fixture.state.performance.snapshot(fixture.state)
	proof.releases = fixture.state.sure_shot.releases.duplicate(true)
	proof.field_state = SeasonFieldSales.capture(fixture.state, fixture.state.home_team)
	check(
		not _matches(proof, fixture),
		"direct complete-game evidence cannot relabel itself as live prefix"
	)

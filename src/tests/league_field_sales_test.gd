extends "res://src/tests/season_small_batch_test.gd"
## Controlled paid fixtures, not full physical-game or save76 acceptance.


func _ready() -> void:
	var build: SeasonBuild = _league_build()
	var owned: Array = build.view().wallet.held
	_check(owned.size() == 4 and build.view().wallet.capacity.held == 4,
		"Dugout plus paid Small Batch starts with four supplies")
	_check(build.commit(_command(build, "match_inventory", {"game": 8})).ok, "bound attempt")
	var uses: Array = []
	var pas: Array = [1, 7, 8, 9]
	for index in range(4):
		uses.append({"receipt": owned[index].id, "player": ROSTER[index],
			"pa": pas[index], "swing": ""})
	uses.append({"receipt": SeasonFieldGrant.receipt(8), "player": ROSTER[0],
		"pa": 13, "swing": ""})
	var fielding: Array = []
	for index in range(3):
		fielding.append({"pa": 4 + index, "half": 1, "player": ROSTER[index + 1],
			"pitcher": ROSTER[0], "primary": true, "air": true, "clean": true})
	var proof: Dictionary = {"pa": 14, "boundary": 13,
		"grant": {"after_pa": 6, "outcome": "granted"},
		"uses": uses, "fielding": fielding}
	var before: Dictionary = build.to_data()
	_check(SeasonFieldSales.valid(build, proof), "five exact uses accepted with bound capacity")
	_check(build.to_data() == before, "sale proof validation is read-only")
	var command: Dictionary = {"game": 8, "tactics": uses, "fielding": fielding,
		"field_supply": proof.grant}
	var prepared: SeasonBuild = build._fork()
	_check(SeasonFieldGrant.prepare(prepared, command).is_empty(),
		"first use makes room before third clean out grants Tape")
	_check(SeasonFieldGrant.finish(prepared, command).is_empty()
		and prepared.view().wallet.held.size() == 4, "used generated Tape never persists")
	var forged: Dictionary = proof.duplicate(true)
	forged.uses.append(forged.uses[-1].duplicate(true))
	_check(not SeasonFieldSales.valid(build, forged), "duplicate sixth use rejected")
	forged = proof.duplicate(true)
	forged.uses[-1].pa = 6
	_check(not SeasonFieldSales.valid(build, forged), "generated copy cannot precede delivery")
	forged = proof.duplicate(true)
	forged.grant.outcome = "full"
	_check(not SeasonFieldSales.valid(build, forged), "forfeited copy cannot be used")
	var sale: Dictionary = _command(build, "match_sell", {"game": 8,
		"receipt": SeasonSchoolSponsors.active(build, "B01").id,
		"first_pitch": null, "field_state": proof})
	var sold: Dictionary = build.commit(sale)
	_check(sold.ok, "live sponsor sale accepts five-use proof: " + sold.get("error", ""))
	_check(SeasonSchoolSponsors.active(build, "B01").is_empty(), "sale retires sponsor")
	_full_forfeits()
	print("League field-sales checks complete; failures: ", _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _league_build() -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	_check(build.enable_league_rules(LeagueRules.capture("dugout")), "league before transactions")
	# Same controlled eligibility/stock fixture as the existing field-capacity suite.
	for game in range(8):
		_check(build.commit(_command(build, "reward", {"game": game, "win": true})).ok,
			"completed fixture reward")
	_check(build.commit(_command(build, "open")).ok, "open fixture shop")
	build._field_start = true
	build._batch_start = SeasonSmallBatch.TYPES.duplicate()
	for id: String in ["G02", "B01"]:
		_check(build.commit(_command(build, "sponsor_buy",
			{"offer": _unit_offer(build, id), "replace": ""})).ok, "paid capacity/generator sponsor")
	for index in range(4):
		_check(build.commit(_hold(build, "A10")).ok, "paid fourth-capacity tactical copy")
	return build


func _full_forfeits() -> void:
	var build: SeasonBuild = _league_build()
	_check(build.commit(_command(build, "match_inventory", {"game": 8})).ok, "full attempt")
	var state: MatchState = MatchState.new()
	state.between_batters = true
	var own: TeamMatchState = TeamMatchState.new()
	own.tactics.held.assign(SeasonTacticalCatalog.held(build.view().wallet))
	MatchFieldSupply.sync_capacity(own, build.view().wallet)
	own.field_supply.receipt = SeasonFieldGrant.receipt(8)
	# Isolate the already-qualified third-out delivery boundary, with all four slots occupied.
	own.field_supply.clean = 3
	own.field_supply._pending = 6
	own.field_supply.deliver(state, own)
	_check(own.field_supply.evidence() == {"after_pa": 6, "outcome": "full"},
		"four-copy bag full at delivery forfeits Tape")
	own.tactics.held.pop_back()
	own.field_supply.deliver(state, own)
	_check(own.tactics.held.size() == 3 and own.field_supply.evidence().outcome == "full",
		"later consumption does not queue a delayed grant")
	var fielding: Array = []
	for index in range(3):
		fielding.append({"pa": 4 + index, "clean": true})
	var action: Dictionary = {"receipt": build.view().wallet.held[0].id,
		"player": ROSTER[0], "pa": 7, "swing": ""}
	var command: Dictionary = {"game": 8, "tactics": [action], "fielding": fielding,
		"field_supply": {"after_pa": 6, "outcome": "full"}}
	_check(SeasonFieldGrant.prepare(build._fork(), command).is_empty(),
		"replay uses full bag at delivery, not later smaller bag")
	command.field_supply.outcome = "granted"
	_check(not SeasonFieldGrant.prepare(build._fork(), command).is_empty(),
		"forged delayed grant rejected")

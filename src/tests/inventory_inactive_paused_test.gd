extends "res://src/tests/inventory_paused_test.gd"
## Inactive development receipts never enter runtime tactics or gain an activation path.


func _ready() -> void:
	var fixture: Dictionary = _fixture(["development.contact", "C03", "A10"])
	var state: MatchState = fixture.state
	state.base_flow.prepare(state)
	var lab: PitchBatLab = _lab_for(state)
	var receipt: String = fixture.bank.view().held[0].id
	var proof: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(_inactive(proof, fixture, receipt), "initial inactive development receipt authenticates")
	check(
		state.home_team.field_supply.reserved == 1 and state.home_team.tactics.held.size() == 2,
		"development still occupies shared capacity without tactical activation"
	)
	check(
		not state.home_team.tactics.activate(state, state.home_team, receipt),
		"development has no live action path"
	)
	check(not _unused_paused(proof, fixture, receipt), "tactical-only unused API unchanged")
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
		"completed-v1 admission unchanged"
	)
	_release_ball(state)
	proof = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		_inactive(proof, fixture, receipt), "between-pitch inactive development sale authenticates"
	)
	check(
		_inactive(JSON.parse_string(JSON.stringify(proof, "", true, true)), fixture, receipt),
		"inactive proof full precision cold"
	)
	check(not _inactive(proof, fixture, "invented-receipt"), "unknown held identity rejects")
	check(
		not _inactive(proof, fixture, state.home_team.tactics.held[0].id),
		"tactical copy cannot use inactive path"
	)
	check(
		not _inactive(proof, fixture, SeasonFieldGrant.receipt(0)),
		"generated Field copy cannot use paid inactive path"
	)
	var bad: Dictionary = proof.duplicate(true)
	bad.field_state.uses.append(
		{"receipt": receipt, "player": String(state.pitcher().definition.id), "pa": 1, "swing": ""}
	)
	check(not _inactive(bad, fixture, receipt), "invented development activation rejects")
	bad = proof.duplicate(true)
	bad.held.append(fixture.bank.view().held[0])
	check(
		not _inactive(bad, fixture, receipt),
		"inactive copy cannot be injected into runtime tactical bag"
	)
	var before: Dictionary = fixture.bank.view()
	var paid: int = int(before.held[0].paid)
	var sale: Dictionary = {
		"id": "inactive-sale",
		"rev": fixture.bank.revision(),
		"op": SeasonInventoryResale.SALE_OP,
		"receipt": receipt
	}
	check(
		fixture.bank.commit(sale).ok and fixture.bank.cash() == int(before.cash) + int(paid / 2),
		"purchased inactive card pays half exact acquisition"
	)
	var after: Dictionary = fixture.bank.view()
	var accepted: Dictionary = {
		"pa": proof.field_state.pa,
		"boundary": proof.field_state.boundary,
		"discard": [receipt],
		"capacity": after.capacity.held,
		"retired": false,
		"sold_receipt": receipt,
		"before": before,
		"after": after,
		"uses": proof.field_state.uses,
		"field_state": proof.field_state
	}
	var initial_bank: Dictionary = fixture.own.league_ownership
	check(
		(
			PhysicalInventoryPaused
			. unused_inactive_receipt(
				proof,
				fixture.own,
				fixture.opponent,
				0,
				anchor,
				initial_bank,
				[accepted],
				1,
				false,
				receipt
			)
			. is_empty()
		),
		"accepted prior sale removes inactive receipt permanently"
	)
	check(
		(
			fixture.bank.commit(sale).get("replayed", false)
			and fixture.bank.cash() == int(before.cash) + int(paid / 2)
		),
		"exact sale retry cannot pay twice"
	)
	lab.free()
	_space_at_delivery(false)
	_space_at_delivery(true)
	print("Inventory inactive paused checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _inactive(proof: Dictionary, fixture: Dictionary, receipt: String) -> bool:
	return not (
		PhysicalInventoryPaused
		. unused_inactive_receipt(
			proof,
			fixture.own,
			fixture.opponent,
			0,
			anchor,
			fixture.own.league_ownership,
			[],
			1,
			false,
			receipt
		)
		. is_empty()
	)


func _space_at_delivery(after_forfeiture: bool) -> void:
	var fixture: Dictionary = _fixture(["development.contact", "C03", "A10"])
	var state: MatchState = fixture.state
	var initial: Dictionary = fixture.bank.to_data()
	var receipt: String = fixture.bank.view().held[0].id
	if after_forfeiture:
		for index in range(3):
			_out(state)
		state.continue_after_dead_ball()
		check(
			state.home_team.field_supply.evidence().get("outcome") == "full",
			"shared development occupancy causes actual full-at-third forfeiture"
		)
	state.base_flow.prepare(state)
	var lab: PitchBatLab = _lab_for(state)
	var accepted: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	check(
		_inactive(accepted, fixture, receipt), "inactive sale eligible at exact delivery chronology"
	)
	var before: Dictionary = fixture.bank.view()
	check(
		(
			fixture
			. bank
			. commit(
				{
					"id": "room-sale",
					"rev": fixture.bank.revision(),
					"op": SeasonInventoryResale.SALE_OP,
					"receipt": receipt
				}
			)
			. ok
		),
		"inactive bag-opening sale commits"
	)
	var after: Dictionary = fixture.bank.view()
	# Match the lead-owned direct inactive sale update: reserved only, never capacity or grant.
	state.home_team.field_supply.reserved = (
		after.held.size() - SeasonTacticalCatalog.held(after).size()
	)
	var sale: Dictionary = {
		"pa": accepted.field_state.pa,
		"boundary": accepted.field_state.boundary,
		"discard": [receipt],
		"capacity": after.capacity.held,
		"retired": false,
		"sold_receipt": receipt,
		"before": before,
		"after": after,
		"uses": accepted.field_state.uses,
		"field_state": accepted.field_state
	}
	if not after_forfeiture:
		for index in range(3):
			_out(state)
		state.continue_after_dead_ball()
	else:
		_out(state)
		state.phase = MatchState.Phase.PRE_PITCH
		state.between_batters = true
	state.base_flow.prepare(state)
	var proof: Dictionary = PhysicalInventoryPaused.capture(lab, state.home_team, anchor)
	var outcome: String = "full" if after_forfeiture else "granted"
	check(
		state.home_team.field_supply.evidence().get("outcome") == outcome,
		(
			"opening capacity after forfeiture never queues; before delivery permits grant: "
			+ str(after_forfeiture)
		)
	)
	var tactical: String = state.home_team.tactics.held[0].id
	check(
		not (
			PhysicalInventoryPaused
			. unused_receipt(
				proof, fixture.own, fixture.opponent, 0, anchor, initial, [sale], 1, false, tactical
			)
			. is_empty()
		),
		"exact shared bag and grant chronology survives inactive sale"
	)
	lab.free()

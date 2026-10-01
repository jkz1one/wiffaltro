class_name SeasonFieldSales
extends RefCounted
# gdlint: disable=max-returns
## Live sale evidence includes the attempt-only copy without persisting it on restart.


static func capture(state: MatchState, own: TeamMatchState) -> Dictionary:
	var boundary: bool = (
		state.between_batters
		and state.phase not in [MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY]
		and state.sure_shot.current(state).is_empty()
	)
	return {
		"pa": state.plate_appearance_number,
		"boundary": state.plate_appearance_number - (1 if boundary else 0),
		"grant": own.field_supply.evidence(),
		"uses": own.tactics.consumed.duplicate(true),
		"fielding": state.clean_outs.evidence(own)
	}


static func begin(build: SeasonBuild, command: Dictionary) -> Dictionary:
	var request: Dictionary = command.duplicate(true)
	if build._format < 34:
		return request
	var proof: Variant = command.get("field_state")
	if proof == null:
		# Old callers without B01 can still sell; gameplay always records the full timeline.
		var owned: bool = build._match_inventory.get("sponsors", []).any(
			func(row: Dictionary) -> bool: return row.item == "B01"
		)
		return {} if owned else request
	if not valid(build, proof):
		return {}
	var id: String = SeasonFieldGrant.receipt(int(command.game))
	var selected: Variant = command.get("discard", [])
	if not selected is Array or not command.get("discarded_use", []) is Array:
		return {}
	var distinct: Array = []
	for value: Variant in selected:
		if not value is String or distinct.has(value):
			return {}
		distinct.append(value)
	if selected.has(id):
		if proof.grant.get("outcome") != "granted":
			return {}
		for sale: Dictionary in build._match_inventory.get("field_sales", []):
			if sale.discard.has(id):
				return {}
		for action: Variant in command.get("discarded_use", []):
			if not action is Dictionary:
				return {}
			if (
				action.get("receipt") == id
				and not proof.uses.any(
					func(use: Dictionary) -> bool: return ClubCareer.same(use, action)
				)
			):
				return {}
		request.discard = selected.filter(func(value: Variant) -> bool: return value != id)
		request.discarded_use = command.get("discarded_use", []).filter(
			func(action: Variant) -> bool:
				return not action is Dictionary or action.get("receipt") != id
		)
	return request


static func finish(build: SeasonBuild, command: Dictionary, before: Dictionary) -> String:
	if build._format < 34 or not command.has("field_state"):
		return ""
	if not build._match_inventory.get("sponsors", []).any(
		func(row: Dictionary) -> bool: return row.item == "B01"
	):
		return ""
	var proof: Dictionary = command.field_state
	var wallet: Dictionary = build._bank.view()
	var id: String = SeasonFieldGrant.receipt(int(command.game))
	var selected: Array = command.get("discard", [])
	var used: Array = proof.uses.map(func(row: Dictionary) -> String: return row.receipt)
	var held: Array = wallet.held.filter(func(row: Dictionary) -> bool: return not used.has(row.id))
	var discarded: bool = selected.has(id)
	for sale: Dictionary in build._match_inventory.get("field_sales", []):
		discarded = discarded or sale.discard.has(id)
	if proof.grant.get("outcome") == "granted" and not used.has(id) and not discarded:
		held.append(SeasonFieldGrant.copy(int(command.game)))
	if held.size() > wallet.capacity.held:
		return "Resolve current match bag capacity, including generated Tape, with explicit discards."
	var retired: bool = false
	for sponsor: Dictionary in before.sponsors:
		if sponsor.item == "B01" and SeasonOwnership._owned(wallet, sponsor.id).is_empty():
			retired = true
	if not build._match_inventory.has("field_sales"):
		build._match_inventory["field_sales"] = []
	build._match_inventory.field_sales.append(
		{
			"state": proof.duplicate(true),
			"discard": selected.duplicate(),
			"capacity": wallet.capacity.held,
			"retired": retired
		}
	)
	return ""


static func valid(build: SeasonBuild, proof: Variant) -> bool:
	if (
		not proof is Dictionary
		or not SeasonOwnership._keys(proof, ["pa", "boundary", "grant", "uses", "fielding"])
	):
		return false
	if not SeasonOwnership._whole(proof.pa, 1, 99999):
		return false
	if not SeasonOwnership._whole(proof.boundary, int(proof.pa) - 1, int(proof.pa)):
		return false
	var sales: Array = build._match_inventory.get("field_sales", [])
	if not sales.is_empty():
		if proof.pa < sales[-1].state.pa or proof.boundary < sales[-1].state.boundary:
			return false
	if not proof.grant is Dictionary or not proof.uses is Array or not proof.fielding is Array:
		return false
	if proof.uses.size() > 4 or proof.fielding.size() > 9999:
		return false
	if not proof.grant.is_empty():
		if not SeasonOwnership._keys(proof.grant, ["after_pa", "outcome"]):
			return false
		if not SeasonOwnership._whole(proof.grant.after_pa, 1, int(proof.pa) - 1):
			return false
		if proof.grant.outcome not in ["granted", "full"]:
			return false
	for row: Variant in proof.fielding:
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row, ["pa", "half", "player", "pitcher", "primary", "air", "clean"]
			)
		):
			return false
		if not SeasonOwnership._whole(row.pa, 1, int(proof.pa) - 1):
			return false
	var seen: Array = []
	for action: Variant in proof.uses:
		if not action is Dictionary or not action.get("receipt") is String:
			return false
		var item: Dictionary = SeasonTacticalDiscard.copy_for(
			build, action.receipt, int(build._match_inventory.game)
		)
		if action.receipt == SeasonFieldGrant.receipt(int(build._match_inventory.game)):
			if (
				proof.grant.get("outcome") != "granted"
				or action.get("pa", 0) <= proof.grant.after_pa
			):
				return false
			item = SeasonFieldGrant.copy(int(build._match_inventory.game))
		if item.is_empty() or not SeasonTacticalDiscard._valid_action(build, action, item):
			return false
		if action.pa > proof.pa or seen.has(action.receipt):
			return false
		seen.append(action.receipt)
	return true

class_name SeasonFieldGrant
extends RefCounted
# gdlint: disable=max-returns
## Reconstruct delivery from the original bag, actual activations and exact live sales.


static func receipt(game: int) -> String:
	return "field-supply:%d" % game


static func copy(game: int) -> Dictionary:
	return {"id": receipt(game), "item": "A10", "paid": 0, "kind": "held"}


static func prepare(build: SeasonBuild, command: Dictionary) -> String:
	if build._format < 34 or build._field_start == null:
		return "Field Supply tracking starts next season." if command.has("field_supply") else ""
	var actions: Variant = command.get("tactics", [])
	if not actions is Array:
		return "Invalid generated-supply activations."
	for action: Variant in actions:
		if not action is Dictionary or not action.get("receipt") is String:
			return "Invalid generated-supply activation."
		if not SeasonOwnership._whole(action.get("pa"), 1, 99999):
			return "Invalid generated-supply activation PA."
	var attempt: Dictionary = build._match_inventory
	var sponsors: Array = attempt.get("sponsors", build._bank.view().sponsors)
	var active: bool = sponsors.any(func(row: Dictionary) -> bool: return row.item == "B01")
	if active and not command.has("fielding"):
		for player: String in build.roster():
			var line: Dictionary = command.get("performance", {}).get(player, {})
			if int(line.get("outs", 0)) > int(line.get("p_k", 0)):
				return "Owned Field Supply requires complete fielded-out evidence."
	var end: int = 99999
	for sale: Dictionary in attempt.get("field_sales", []):
		if sale.retired:
			end = mini(end, int(sale.state.boundary))
	var clean: Array = command.get("fielding", []).filter(
		func(row: Dictionary) -> bool: return row.clean and row.pa <= end
	)
	var expected: Dictionary = {}
	if active and clean.size() >= 3:
		var pa: int = int(clean[2].pa)
		var held: Array = attempt.get("field_held", build._bank.view().held).duplicate(true)
		var capacity: int = int(attempt.get("held_capacity", build._bank.view().capacity.held))
		for sale: Dictionary in attempt.get("field_sales", []):
			if sale.state.boundary <= pa and sale.state.pa <= pa:
				capacity = int(sale.capacity)
			if sale.state.pa <= pa:
				held = held.filter(
					func(row: Dictionary) -> bool: return not sale.discard.has(row.id)
				)
		for action: Dictionary in command.get("tactics", []):
			if action.pa <= pa:
				held = held.filter(func(row: Dictionary) -> bool: return row.id != action.receipt)
		expected = {"after_pa": pa, "outcome": "full" if held.size() >= capacity else "granted"}
	if not ClubCareer.same(expected, command.get("field_supply", {})):
		return "Field Supply delivery must match clean outs and the bag at that boundary."
	var id: String = receipt(int(command.game))
	for sale: Dictionary in attempt.get("field_sales", []):
		if not _matches(sale.state, command):
			return "Field Supply live evidence changed before completion."
		var at_sale: Dictionary = (
			expected if not expected.is_empty() and expected.after_pa < sale.state.pa else {}
		)
		if not ClubCareer.same(sale.state.grant, at_sale):
			return "Field Supply delivery evidence changed."
		for action: Dictionary in command.get("tactics", []):
			if (
				sale.discard.has(id)
				and action.receipt == id
				and not sale.state.uses.any(func(use: Dictionary) -> bool: return use.receipt == id)
			):
				return "A discarded generated copy cannot be activated later."
	if expected.get("outcome") == "granted":
		attempt["game"] = int(command.game)
		attempt["field_grant"] = expected.duplicate(true)
		for action: Dictionary in command.get("tactics", []):
			if action.receipt == id and action.pa <= expected.after_pa:
				return "Generated Tape cannot be used before delivery."
	return ""


static func finish(build: SeasonBuild, command: Dictionary) -> String:
	if build._match_inventory.get("field_grant", {}).get("outcome") != "granted":
		return ""
	var id: String = receipt(int(command.game))
	for action: Dictionary in command.get("tactics", []):
		if action.receipt == id:
			return ""
	for sale: Dictionary in build._match_inventory.get("field_sales", []):
		if sale.discard.has(id):
			return ""
	var outcome: Dictionary = build._bank.commit(
		{"id": id, "rev": build._bank.revision(), "op": "field_grant", "game": command.game}
	)
	return "" if outcome.ok else outcome.error


static func grant(next: Dictionary, command: Dictionary) -> String:
	if not SeasonOwnership._keys(command, ["id", "rev", "op", "game"]):
		return "Invalid generated Tape receipt."
	if not SeasonOwnership._whole(command.game, 0, 32) or command.id != receipt(int(command.game)):
		return "Invalid generated Tape identity."
	next.held.append(copy(int(command.game)))
	return ""


static func _matches(partial: Dictionary, command: Dictionary) -> bool:
	var total: int = 0
	for line: Dictionary in command.get("performance", {}).values():
		total += int(line.get("pa", 0))
	if partial.pa > total:
		return false
	var rows: Array = command.get("fielding", []).filter(
		func(row: Dictionary) -> bool: return row.pa < partial.pa
	)
	if partial.fielding.size() != rows.size():
		return false
	for index in range(partial.fielding.size()):
		if not ClubCareer.same(partial.fielding[index], rows[index]):
			return false
	for action: Dictionary in command.get("tactics", []):
		if (
			action.pa < partial.pa
			and not partial.uses.any(
				func(use: Dictionary) -> bool: return use.receipt == action.receipt
			)
		):
			return false
	for use: Dictionary in partial.uses:
		var found: bool = false
		for action: Dictionary in command.get("tactics", []):
			var settled: Dictionary = action.duplicate(true)
			if not use.has("walked"):
				settled.erase("walked")
			if ClubCareer.same(use, settled):
				found = true
		if not found:
			return false
	return true

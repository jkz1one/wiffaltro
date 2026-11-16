class_name PhysicalBaseBag
extends RefCounted
## Exact paid-copy selection around the already validated base occupancy chronology.
# gdlint: disable=max-returns


static func preempted(row: Dictionary, parity: int) -> Variant:
	if not row.get("consumed") is Array or not row.get("remaining") is Array \
		or row.consumed.size() > row.initial.size():
		return null
	var held: Array = row.initial.duplicate(true)
	var cursor: int = 0
	var result: Array = []
	var advances: Dictionary = PhysicalBaseFlow._indexed(row.base.advances, true)
	for ready: Dictionary in row.base.ready:
		var action: Dictionary = {}
		if cursor < row.consumed.size():
			var value: Variant = row.consumed[cursor]
			if not value is Dictionary or not SeasonOwnership._whole(value.get("pa"), 1, 99999) \
				or value.pa < ready.pa:
				return null
			if value.pa == ready.pa:
				action = value
		var own: bool = int(ready.half) % 2 == parity
		var bases: BaseState = BaseState.new()
		bases.first = StringName(ready.bases[0])
		bases.second = StringName(ready.bases[1])
		bases.third = StringName(ready.bases[2])
		var selected: Dictionary = SeasonOpponentBase.select(held, bases) if own else {}
		if not selected.is_empty():
			if not advances.has(int(ready.pa)):
				return null
			var advance: Dictionary = advances[int(ready.pa)]
			if advance.receipt != selected.id or not ClubCareer.same(action, {
				"receipt": selected.id, "player": ready.player, "pa": ready.pa,
				"swing": "", "advance": advance.advance}):
				return null
			result.append(int(ready.pa))
		elif (own and advances.has(int(ready.pa))) or action.has("advance"):
			return null
		if action.is_empty():
			continue
		var keys: Array = ["receipt", "player", "pa", "swing"]
		if not selected.is_empty():
			keys.append("advance")
		if not SeasonOwnership._keys(action, keys) or not action.receipt is String \
			or not action.player is String or not action.swing is String:
			return null
		var owned: Array = held.filter(func(copy: Dictionary) -> bool:
			return copy.id == action.receipt)
		if owned.size() != 1 or (selected.is_empty() and owned[0].item == SeasonTacticalCatalog.BASE):
			return null
		PhysicalRecoveryFlow.remove(held, action.receipt)
		cursor += 1
	return result if cursor == row.consumed.size() and ClubCareer.same(held, row.remaining) else null


static func recovery(row: Dictionary, normalize: bool = false) -> Dictionary:
	var result: Dictionary = row.duplicate()
	result.erase("base")
	result.erase("budget")
	result.version = 3
	result = result.duplicate(true)
	for key: String in ["initial", "remaining"]:
		result[key] = result[key].filter(func(copy: Dictionary) -> bool:
			return copy.item != SeasonTacticalCatalog.BASE)
		if normalize:
			for copy: Dictionary in result[key]:
				if copy.paid == 0 and copy.item == "C03":
					copy.paid = 3 # Historical validator adapter only; actual receipts stay zero-paid.
	result.consumed = result.consumed.filter(func(action: Dictionary) -> bool:
		return not action.has("advance"))
	return result

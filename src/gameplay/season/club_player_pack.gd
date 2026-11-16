extends RefCounted
## Player-pack business rules shared by the real asset ledger and isolated component tests.
## Context is borrowed internal state, never independent income or save authority.
const Catalog = preload("res://src/gameplay/season/club_player_catalog.gd")


static func prepare(context: Dictionary, event: Dictionary) -> Dictionary:
	# The ledger validates schema, numeric fields, global request identity and revision first.
	if event.op == "player_pack_open":
		return _open(context, event)
	if event.op != "player_pack_pick":
		return _error("Unknown permanent-asset action.")
	if context.pending.is_empty() or event.pack != context.pending.id or not \
		context.pending.choices.has(event.player):
		return _error("Select an unowned player from the saved pack.")
	return {"ok": true, "replayed": false, "error": "", "event": event,
		"balance_after": _income(context.credits, context.credits.size()) - context.spent}


static func _open(context: Dictionary, event: Dictionary) -> Dictionary:
	if not context.pending.is_empty():
		return _error("Finish choosing the already-paid player pack first.")
	var price: int = Catalog.price(event.price_version)
	if price < 0 or (not context.loading and event.price_version != \
		Catalog.PRICE_VERSION):
		return _error("The quoted player-pack price is no longer current.")
	if event.through < context.through or event.through == 0 or \
		context.credits[event.through - 1] == 0:
		return _error("A completed earning record is required.")
	if _income(context.credits, event.through) - context.spent < price:
		return _error("Not enough earned Club Bucks.")
	var choices: Array[String] = Catalog.offers(_owned(context.pack_owned), \
		context.seed, context.opened)
	if choices.is_empty():
		return _error(
			"Every pack character is owned; remaining characters have achievement routes."
		)
	return {
		"ok": true,
		"replayed": false,
		"error": "",
		"event": event,
		"price": price,
		"choices": choices,
		"balance_after": _income(context.credits, context.credits.size()) - context.spent - price
	}


static func _apply_prepared(context: Dictionary, prepared: Dictionary) -> void:
	# Internal reducer: only an immediate successful prepare result enters here.
	var event: Dictionary = prepared.event
	if event.op == "player_pack_open":
		context.spent += prepared.price
		context.through = event.through
		context.pending = {
			"id": event.id, "sequence": context.opened, "paid": prepared.price,
			"price_version": event.price_version, "choices": prepared.choices.duplicate()
		}
		context.opened += 1
	else:
		context.pack_owned.append(event.player)
		context.pack_owned.sort()
		context.pending = {}


static func _income(credits: Array, through: int) -> int:
	var total: int = 0
	for index in range(through):
		total += credits[index]
	return total


static func _owned(pack_owned: Array) -> Array[String]:
	var result: Array[String] = Catalog.initial_owned()
	result.append_array(pack_owned)
	result.sort()
	return result


static func _error(message: String) -> Dictionary:
	return {"ok": false, "replayed": false, "error": message}

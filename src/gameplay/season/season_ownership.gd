# gdlint: disable=max-returns
# Validation uses early exits before publishing any candidate state.
class_name SeasonOwnership
extends RefCounted
## Approved equipped-only ownership. Prices/capacities and income remain Working.
## Catalog/stock commands are issued by trusted shop code, never loaded as balances.

const VERSION: int = 1
const MAX_EVENTS: int = 4096
const GEAR_SLOTS: Array[String] = ["bat", "ball", "misc"]
var _catalog: Dictionary = {}
var _events: Array[Dictionary] = []
var _requests: Dictionary = {}
var _state: Dictionary = {
	"cash": 0,
	"gear": {"bat": {}, "ball": {}, "misc": {}},
	"sponsors": [],
	"held": [],
	"stock": {},
	"seen_offers": [],
	"rewards": {}
}


func _init(catalog: Dictionary = {}) -> void:
	_catalog = catalog.duplicate(true)


func revision() -> int:
	return _events.size()


func cash() -> int:
	return int(_state.cash)


func fork() -> SeasonOwnership:
	var result: SeasonOwnership = SeasonOwnership.new(_catalog)
	result._state = _state.duplicate(true)
	result._events = _events.duplicate(true)
	result._requests = _requests.duplicate(true)
	return result


func view() -> Dictionary:
	var result: Dictionary = _state.duplicate(true)
	result["revision"] = revision()
	result["capacity"] = _capacity(_state)
	return result


func to_data() -> Dictionary:
	return {
		"version": VERSION,
		"catalog": JSON.stringify(_catalog).sha256_text(),
		"events": _events.duplicate(true)
	}


static func from_data(value: Variant, catalog: Dictionary = {}) -> SeasonOwnership:
	if not value is Dictionary or value.size() != 3 or value.get("version") != VERSION:
		return null
	if not value.get("events") is Array or value.events.size() > MAX_EVENTS:
		return null
	if value.get("catalog") != JSON.stringify(catalog).sha256_text():
		return null
	var result: SeasonOwnership = SeasonOwnership.new(catalog)
	for event: Variant in value.events:
		if not event is Dictionary:
			return null
		var outcome: Dictionary = result.commit(event)
		if not outcome.ok or outcome.replayed:
			return null
	return result


func preview(command: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare(command)
	if not prepared.ok:
		return prepared
	var result: Dictionary = prepared.duplicate(true)
	result.erase("command")
	result["before_cash"] = cash()
	return result


func commit(command: Dictionary) -> Dictionary:
	var prepared: Dictionary = _prepare(command)
	if not prepared.ok:
		return prepared
	if prepared.replayed:
		return {"ok": true, "replayed": true}
	_state = prepared.after
	var normalized: Dictionary = prepared.command
	_events.append(normalized.duplicate(true))
	_requests[normalized.id] = normalized.duplicate(true)
	return {"ok": true, "replayed": false}


func _prepare(command: Dictionary) -> Dictionary:
	if not _text(command.get("id")) or not _whole(command.get("rev"), 0, MAX_EVENTS):
		return _failure("Invalid transaction identity or revision.")
	var normalized: Dictionary = command.duplicate(true)
	normalized.rev = int(normalized.rev)
	if normalized.has("game") and _whole(normalized.game, 0, 32):
		normalized.game = int(normalized.game)
	if _requests.has(normalized.id):
		if JSON.stringify(_requests[normalized.id]) != JSON.stringify(normalized):
			return _failure("Transaction identity was already used for another action.")
		return {"ok": true, "replayed": true, "after": _state.duplicate(true)}
	if normalized.rev != revision() or revision() >= MAX_EVENTS:
		return _failure("The loadout changed. Review a fresh transaction.")
	var next: Dictionary = _state.duplicate(true)
	var error: String = _apply(next, normalized)
	if not error.is_empty():
		return _failure(error)
	var capacity: Dictionary = _capacity(next)
	if next.held.size() > capacity.held or next.sponsors.size() > capacity.sponsors:
		return _failure("Resolve all capacity changes explicitly before confirming.")
	if next.cash < 0 or next.cash > 1000000:
		return _failure("Insufficient Season Cash or invalid balance.")
	return {"ok": true, "replayed": false, "after": next, "command": normalized}


func _apply(next: Dictionary, command: Dictionary) -> String:
	match command.get("op"):
		"charge":
			# Internal service debit. The owning shop derives the amount from its
			# fixed contract; player-facing commands never accept a price override.
			if not _keys(command, ["id", "rev", "op", "amount"]):
				return "Invalid service debit."
			if not _whole(command.amount, 0, 1000000):
				return "Invalid service debit."
			next.cash -= int(command.amount)
		"sponsor_income":
			# Internal aggregate credit, derived from completed-game evidence.
			if not _keys(command, ["id", "rev", "op", "amount"]):
				return "Invalid sponsor income."
			if not _whole(command.amount, 1, 21):
				return "Invalid sponsor income."
			next.cash += int(command.amount)
		"reward":
			if not _keys(command, ["id", "rev", "op", "game", "win"]):
				return "Invalid game reward."
			if not _whole(command.game, 0, 32) or not command.win is bool:
				return "Invalid game reward."
			var game: String = str(int(command.game))
			if next.rewards.has(game):
				return "This game already paid its reward."
			next.rewards[game] = command.win
			next.cash += 18 if command.win else 12
		"stock":
			if (
				not _keys(command, ["id", "rev", "op", "offers"])
				or not command.offers is Dictionary
			):
				return "Invalid stock."
			if command.offers.size() > 32:
				return "Too many offers."
			for offer: Variant in command.offers:
				if not _text(offer) or next.seen_offers.has(offer):
					return "Offer identities cannot be reused."
				if not _valid_item(command.offers[offer]):
					return "Unsupported item."
				next.seen_offers.append(offer)
			next.stock = command.offers.duplicate(true)
		"buy":
			var fields: Array = ["id", "rev", "op", "offer", "replace", "discard"]
			if command.has("discount"):
				fields.append("discount")
			if not _keys(command, fields):
				return "Invalid purchase."
			var error: String = _discard(next, command.discard)
			if not error.is_empty():
				return error
			return _buy(next, command)
		"sell":
			if not _keys(command, ["id", "rev", "op", "receipt", "discard"]):
				return "Invalid sale."
			var error: String = _discard(next, command.discard)
			if not error.is_empty():
				return error
			return _sell(next, command.receipt)
		"discard":
			if not _keys(command, ["id", "rev", "op", "receipts"]):
				return "Invalid discard."
			return _discard(next, command.receipts)
		_:
			return "Unsupported transaction."
	return ""


func _buy(next: Dictionary, command: Dictionary) -> String:
	if (
		not _text(command.offer)
		or not next.stock.has(command.offer)
		or not command.replace is String
	):
		return "Offer unavailable or invalid replacement."
	var item_id: String = next.stock[command.offer]
	var item: Dictionary = _catalog[item_id]
	var discount: Variant = command.get("discount", 0)
	if not _whole(discount, 0, mini(3, item.price)) or (discount > 0 and item.kind != "held"):
		return "Invalid held-card acquisition credit."
	if not command.replace.is_empty():
		var old: Dictionary = _owned(next, command.replace)
		if old.is_empty() or old.kind != item.kind or item.kind == "held":
			return "Choose an owned item in the same category."
		if item.kind == "gear" and _catalog[old.item].slot != item.slot:
			return "Choose the equipped item in this Gear slot."
		var error: String = _sell(next, command.replace)
		if not error.is_empty():
			return error
	var receipt: Dictionary = {
		"id": command.id,
		"item": item_id,
		"kind": item.kind,
		"paid": int(item.price) - int(discount)
	}
	if item.kind == "gear":
		if not next.gear[item.slot].is_empty():
			return "Select the equipped Gear explicitly for replacement."
		next.gear[item.slot] = receipt
	elif item.kind == "sponsor":
		for active: Dictionary in next.sponsors:
			if active.item == item_id:
				return "This sponsor is already active."
		next.sponsors.append(receipt)
	else:
		next.held.append(receipt)
	next.cash -= receipt.paid
	next.stock.erase(command.offer)
	return ""


func _sell(next: Dictionary, receipt_id: Variant) -> String:
	if not _text(receipt_id):
		return "Choose an owned receipt."
	var owned: Dictionary = _owned(next, receipt_id)
	if owned.is_empty() or owned.kind == "held":
		return "This item cannot be sold."
	var item: Dictionary = _catalog[owned.item]
	if item.sale == "blocked":
		return "This item's sale contract is not supported."
	var credit: int = int(owned.paid / 2) if item.sale == "half" else 0
	next.cash += credit
	if owned.kind == "gear":
		next.gear[item.slot] = {}
	else:
		next.sponsors.erase(owned)
	return ""


static func _discard(next: Dictionary, receipts: Variant) -> String:
	if not receipts is Array:
		return "Choose the exact held cards to discard."
	var found: Array = []
	for id: Variant in receipts:
		if not _text(id) or found.has(id):
			return "Invalid or repeated discard selection."
		var owned: Dictionary = _owned(next, id)
		if owned.is_empty() or owned.kind != "held":
			return "Only an owned held card can be discarded."
		found.append(id)
		next.held.erase(owned)
	return ""


static func _owned(state: Dictionary, receipt_id: String) -> Dictionary:
	for owned: Dictionary in state.gear.values() + state.sponsors + state.held:
		if owned.get("id") == receipt_id:
			return owned
	return {}


func _capacity(state: Dictionary) -> Dictionary:
	var held: int = 2
	var sponsors: int = 5
	for active: Dictionary in state.sponsors:
		var item: Dictionary = _catalog[active.item]
		held += int(item.get("held_delta", 0))
		sponsors += int(item.get("sponsor_delta", 0))
	return {"held": maxi(0, held), "sponsors": maxi(0, sponsors)}


func _valid_item(id: Variant) -> bool:
	if not _text(id) or not _catalog.has(id) or not _catalog[id] is Dictionary:
		return false
	var item: Dictionary = _catalog[id]
	if not _whole(item.get("price"), 0, 1000000):
		return false
	if item.get("kind") not in ["gear", "sponsor", "held"]:
		return false
	if item.get("sale") not in ["half", "zero", "blocked"]:
		return false
	if item.kind == "gear":
		return item.get("slot") in GEAR_SLOTS and item.sale == "half"
	if item.kind == "held":
		return item.sale == "zero"
	return (
		_whole(item.get("held_delta", 0), -2, 10) and _whole(item.get("sponsor_delta", 0), -5, 10)
	)


static func _keys(value: Dictionary, allowed: Array) -> bool:
	if value.size() != allowed.size():
		return false
	for key: String in allowed:
		if not value.has(key):
			return false
	return true


static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= minimum
		and value <= maximum
		and float(value) == floorf(float(value))
	)


static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 120


static func _failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "replayed": false}

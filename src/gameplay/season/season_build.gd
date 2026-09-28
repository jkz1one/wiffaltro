class_name SeasonBuild
extends RefCounted
## Atomic Working-season wallet, held-card, development and shop aggregate.
## Only this journal is saved: independent wallet/growth blobs cannot disagree.
# gdlint: disable=max-returns

const VERSION: int = 6
const MAX_EVENTS: int = 512
const SHOP_OPS: Array[String] = [
	"open",
	"buy",
	"use",
	"discard",
	"reroll",
	"pack_open",
	"pack_pick",
	"pack_skip",
	"sign",
	"equip",
	"sell_gear",
	"sponsor_buy",
	"sponsor_sell"
]

var last_error: String = ""
var _seed: int
var _roster: Array[String] = []
var _initial_roster: Array[String] = []
var _pool: Array[String] = []
var _blocked: Array[String] = []
var _contracts: Dictionary = {}
var _recruits: Array[Dictionary] = []
var _game_rosters: Dictionary = {}
var _appeared: bool = false
var _format: int = VERSION
var _recruit_from: int = 1
var _gear_from: int = 1
var _misc_from: int = 1
var _mapped_gear_from: int = 1
var _sponsor_from: int = 1
var _income_by_game: Dictionary = {}
var _bank: SeasonOwnership
var _book: SeasonDevelopment
var _visit: Dictionary = {"number": 0, "open": false}
var _events: Array[Dictionary] = []
var _requests: Dictionary = {}


func _init(
	seed_value: int = 0,
	roster: Array[String] = [],
	pool: Array[String] = [],
	blocked: Array[String] = []
) -> void:
	_seed = seed_value
	_roster = roster.duplicate()
	_initial_roster = roster.duplicate()
	_pool = SeasonPlayerCatalog.ids() if pool.is_empty() else pool.duplicate()
	_pool.sort()
	_blocked = blocked.duplicate()
	_blocked.sort()
	for id: String in roster:
		_contracts[id] = RecruitCatalog.contract(id).prices[0]
	_bank = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	_book = SeasonDevelopment.new("season:%d" % _seed)


func revision() -> int:
	return _events.size()


func cash() -> int:
	return _bank.cash()


func roster() -> Array[String]:
	return _roster.duplicate()


func roster_for_game(game: int) -> Array:
	return _game_rosters.get(game, []).duplicate()


func migrate_recruitment() -> void:
	if _format == 1:
		_format = 2
		# Never create an extra offer or reroll an already saved legacy visit.
		_recruit_from = int(_visit.number) + 1


func player(player_id: String) -> Dictionary:
	return _book.player(player_id)


func definition(player_id: String) -> PlayerDefinition:
	var result: PlayerDefinition = ProgressionMatchAdapter.player(_book, player_id)
	if result != null and _roster.has(player_id):
		return SeasonGearCatalog.equip(result, _bank.view().gear)
	return result


func targets(item_id: String) -> Array[Dictionary]:
	return DevelopmentShopCatalog.targets(_book, _roster, item_id)


func pack_pending() -> bool:
	return _visit.get("pack_status") == "open"


func view() -> Dictionary:
	var visit: Dictionary = _visit.duplicate(true)
	if visit.get("pack_status") == "sealed":
		visit["choice_count"] = _pack_choices().size()
		visit.erase("cards")
	return {"revision": revision(), "wallet": _bank.view(), "shop": visit, "roster": roster()}


func to_data() -> Dictionary:
	var data: Dictionary = {
		"version": _format,
		"seed": _seed,
		"roster": _initial_roster.duplicate(),
		"catalog": _signature(_format),
		"events": _events.duplicate(true)
	}
	if _format >= 2:
		data.merge(
			{
				"pool": _pool.duplicate(),
				"blocked": _blocked.duplicate(),
				"recruit_from": _recruit_from,
				"recruits": _recruits.duplicate(true)
			}
		)
	if _format >= 3:
		data["gear_from"] = _gear_from
	if _format >= 4:
		data["misc_from"] = _misc_from
	if _format >= 5:
		data["mapped_gear_from"] = _mapped_gear_from
	if _format >= 6:
		data["sponsor_from"] = _sponsor_from
	return data


static func from_data(
	value: Variant,
	seed_value: int,
	roster: Array[String],
	pool: Array[String] = [],
	blocked: Array[String] = []
) -> SeasonBuild:
	if not value is Dictionary or not SeasonOwnership._whole(value.get("version"), 1, VERSION):
		return null
	var keys: Array = ["version", "seed", "roster", "catalog", "events"]
	if value.version >= 2:
		keys.append_array(["pool", "blocked", "recruit_from", "recruits"])
	if value.version >= 3:
		keys.append("gear_from")
	if value.version >= 4:
		keys.append("misc_from")
	if value.version >= 5:
		keys.append("mapped_gear_from")
	if value.version >= 6:
		keys.append("sponsor_from")
	if not SeasonOwnership._keys(value, keys):
		return null
	if value.seed != seed_value or value.roster != roster:
		return null
	if (
		value.catalog != _signature(int(value.version))
		or not value.events is Array
		or value.events.size() > MAX_EVENTS
	):
		return null
	var result: SeasonBuild = SeasonBuild.new(seed_value, roster, pool, blocked)
	result._format = int(value.version)
	if value.version >= 2:
		if (
			value.pool != result._pool
			or value.blocked != result._blocked
			or not SeasonOwnership._whole(value.recruit_from, 1, 13)
			or not value.recruits is Array
		):
			return null
		result._recruit_from = int(value.recruit_from)
	if value.version >= 3:
		if not SeasonOwnership._whole(value.gear_from, 1, 13):
			return null
		result._gear_from = int(value.gear_from)
	if value.version >= 4:
		if not SeasonOwnership._whole(value.misc_from, 1, 13):
			return null
		result._misc_from = int(value.misc_from)
	if value.version >= 5:
		if not SeasonOwnership._whole(value.mapped_gear_from, 1, 13):
			return null
		result._mapped_gear_from = int(value.mapped_gear_from)
	if value.version >= 6:
		if not SeasonOwnership._whole(value.sponsor_from, 1, 13):
			return null
		result._sponsor_from = int(value.sponsor_from)
	for event: Variant in value.events:
		if not event is Dictionary:
			return null
		var applied: Dictionary = result.commit(event)
		if not applied.ok or applied.replayed:
			return null
	if value.version >= 2:
		# Godot JSON reads every number as float; normalize both quote snapshots
		# before deep comparison without accepting a different value or field.
		var expected: Variant = JSON.parse_string(JSON.stringify(result._recruits))
		var saved: Variant = JSON.parse_string(JSON.stringify(value.recruits))
		if expected != saved:
			return null
	return result


func preview(command: Dictionary) -> Dictionary:
	var next: SeasonBuild = candidate(command)
	if next == null:
		return {"ok": false, "error": last_error}
	return {
		"ok": true,
		"before_cash": cash(),
		"after": next.view(),
		"player": next.player(command.get("player", ""))
	}


func commit(command: Dictionary) -> Dictionary:
	var next: SeasonBuild = candidate(command)
	if next == null:
		return {"ok": false, "error": last_error, "replayed": false}
	var replayed: bool = next.revision() == revision()
	_bank = next._bank
	_book = next._book
	_visit = next._visit
	_events = next._events
	_requests = next._requests
	_roster = next._roster
	_contracts = next._contracts
	_recruits = next._recruits
	_game_rosters = next._game_rosters
	_income_by_game = next._income_by_game
	_appeared = next._appeared
	return {"ok": true, "replayed": replayed}


func candidate(command: Dictionary) -> SeasonBuild:
	last_error = ""
	if (
		not SeasonOwnership._text(command.get("id"))
		or not SeasonOwnership._whole(command.get("rev"), 0, MAX_EVENTS)
	):
		last_error = "Invalid shop transaction identity."
		return null
	var normalized: Dictionary = command.duplicate(true)
	normalized.rev = int(normalized.rev)
	if normalized.has("game") and SeasonOwnership._whole(normalized.game, 0, 32):
		normalized.game = int(normalized.game)
	var serialized: String = JSON.stringify(normalized)
	if _requests.has(normalized.id):
		if _requests[normalized.id] == serialized:
			return _fork()
		last_error = "This transaction ID was already used for another action."
		return null
	if normalized.rev != revision() or revision() >= MAX_EVENTS:
		last_error = "The build changed. Review a fresh purchase."
		return null
	var next: SeasonBuild = _fork()
	last_error = next._apply(normalized)
	if not last_error.is_empty():
		return null
	next._events.append(normalized)
	next._requests[normalized.id] = serialized
	return next


func _fork() -> SeasonBuild:
	var result: SeasonBuild = SeasonBuild.new(_seed, _initial_roster, _pool, _blocked)
	result._roster = _roster.duplicate()
	result._contracts = _contracts.duplicate(true)
	result._recruits = _recruits.duplicate(true)
	result._game_rosters = _game_rosters.duplicate(true)
	result._appeared = _appeared
	result._format = _format
	result._recruit_from = _recruit_from
	result._gear_from = _gear_from
	result._misc_from = _misc_from
	result._mapped_gear_from = _mapped_gear_from
	result._sponsor_from = _sponsor_from
	result._income_by_game = _income_by_game.duplicate(true)
	result._bank = _bank.fork()
	result._book = _book.fork()
	result._visit = _visit.duplicate(true)
	result._events = _events.duplicate(true)
	result._requests = _requests.duplicate(true)
	return result


func _apply(command: Dictionary) -> String:
	var op: String = str(command.get("op", ""))
	if pack_pending() and op not in ["pack_pick", "pack_skip"]:
		return "Choose or skip the open pack before leaving or doing other shopping."
	if op == "reward":
		var fields: Array = ["game", "win"]
		if _format >= 6 and command.has("performance"):
			fields.append("performance")
		if not _keys(command, fields) or _roster.size() != 4:
			return "Invalid season reward."
		var result: Dictionary = _bank.commit(
			{
				"id": "game:%s" % str(command.game),
				"rev": _bank.revision(),
				"op": "reward",
				"game": command.game,
				"win": command.win
			}
		)
		if not result.ok or result.replayed:
			return "This fixture cannot pay again."
		var error: String = _settle_sponsors(command)
		if not error.is_empty():
			return error
		_game_rosters[int(command.game)] = roster()
		_visit = {"number": _visit.number + 1, "open": false}
		return ""
	if op == "open":
		if not _keys(command, []) or _visit.open or _visit.number < 1:
			return "No new postgame shop is available."
		_visit = {
			"number": _visit.number,
			"open": true,
			"rerolls": 0,
			"offers": _offers(0),
			"cards": DevelopmentShopCatalog.pack(_book, _roster, _rng(-1)),
			"pack_status": "sealed"
		}
		if _format >= 2 and _visit.number >= _recruit_from:
			_visit["recruit"] = _recruit_offer()
		return ""
	if not _visit.open:
		return "Open the current postgame shop first."
	match op:
		"sponsor_buy", "sponsor_sell":
			return _sponsor_transaction(command)
		"equip", "sell_gear":
			return _gear_transaction(command)
		"sign":
			return _sign(command)
		"buy":
			return _buy(command)
		"use":
			return _use(command)
		"discard":
			if not _keys(command, ["receipt"]) or not command.receipt is String:
				return "Choose a held card to discard."
			var result: Dictionary = _bank.commit(
				{
					"id": "discard:%d" % revision(),
					"rev": _bank.revision(),
					"op": "discard",
					"receipts": [command.receipt]
				}
			)
			return "" if result.ok else result.error
		"reroll":
			if not _keys(command, []):
				return "Invalid reroll."
			var error: String = _charge(4 + 2 * int(_visit.rerolls))
			if not error.is_empty():
				return error
			_visit.rerolls += 1
			_visit.offers = _offers(_visit.rerolls)
		"pack_open":
			if (
				not _keys(command, [])
				or _visit.pack_status != "sealed"
				or _pack_choices().is_empty()
			):
				return "No eligible unopened pack."
			var error: String = _charge(DevelopmentShopCatalog.PACK_PRICE)
			if not error.is_empty():
				return error
			_visit.pack_status = "open"
			_visit.cards = _pack_choices()
		"pack_pick":
			if not _keys(command, ["item", "player", "pitch", "replace"]) or not pack_pending():
				return "No revealed pack choice is pending."
			if not command.item is String or not _visit.cards.has(command.item):
				return "Choose one revealed card."
			var error: String = _develop(command.item, command)
			if not error.is_empty():
				return error
			_visit.pack_status = "used"
		"pack_skip":
			if not _keys(command, []) or not pack_pending():
				return "No revealed pack to skip."
			_visit.pack_status = "skipped"
		_:
			return "Unsupported shop operation."
	return ""


func _buy(command: Dictionary) -> String:
	if not _keys(command, ["offer", "mode", "player", "pitch", "replace"]):
		return "Invalid purchase fields."
	if not command.offer is String or not _visit.offers.has(command.offer):
		return "This exact offer is no longer available."
	var item_id: String = _visit.offers[command.offer]
	var item: Dictionary = DevelopmentShopCatalog.item(item_id)
	if command.mode == "hold":
		if (
			not DevelopmentShopCatalog.CARDS.has(item_id)
			or command.player != ""
			or (command.pitch != "" or command.replace != "")
		):
			return "Only loose development cards can be held, without a preassigned target."
		if targets(item_id).is_empty():
			return "This card has no eligible current roster target."
		var quote: String = "quote:%d" % revision()
		var stock: Dictionary = _bank.commit(
			{"id": quote, "rev": _bank.revision(), "op": "stock", "offers": {quote: item_id}}
		)
		if not stock.ok:
			return stock.error
		var purchase: Dictionary = _bank.commit(
			{
				"id": "purchase:%d" % revision(),
				"rev": _bank.revision(),
				"op": "buy",
				"offer": quote,
				"replace": "",
				"discard": []
			}
		)
		if not purchase.ok:
			return purchase.error
	elif command.mode == "use":
		var error: String = _develop(item_id, command)
		if error.is_empty():
			error = _charge(item.price)
		if not error.is_empty():
			return error
	else:
		return "Choose Buy and Hold or Buy and Use."
	_visit.offers.erase(command.offer)
	return ""


func _use(command: Dictionary) -> String:
	if (
		not _keys(command, ["receipt", "player", "pitch", "replace"])
		or not command.receipt is String
	):
		return "Invalid held-card use."
	var receipt: Dictionary = SeasonOwnership._owned(_bank.view(), command.receipt)
	if receipt.is_empty() or receipt.kind != "held":
		return "Choose a card you still hold."
	var error: String = _develop(receipt.item, command)
	if not error.is_empty():
		return error
	var result: Dictionary = _bank.commit(
		{
			"id": "use:%d" % revision(),
			"rev": _bank.revision(),
			"op": "discard",
			"receipts": [command.receipt]
		}
	)
	return "" if result.ok else result.error


func _develop(item_id: String, command: Dictionary) -> String:
	for key: String in ["player", "pitch", "replace"]:
		if not command.get(key) is String:
			return "Choose an exact legal player and recipe."
	var target: Dictionary = {
		"player": command.player, "pitch": command.pitch, "replace": command.replace
	}
	if not targets(item_id).has(target):
		return "That player/recipe is no longer an eligible target."
	var item: Dictionary = DevelopmentShopCatalog.item(item_id)
	var request: Dictionary = {
		"id": "growth:%d" % revision(),
		"rev": _book.revision(),
		"player": command.player,
		"op": item.op,
		"target": command.pitch
	}
	if item.op == "stat":
		request.target = item.family
	elif item.op == "learn":
		request.target = item.recipe
		request.replace = command.replace
	var result: Dictionary = _book.commit(request)
	return "" if result.ok else result.error


func _charge(amount: int) -> String:
	var result: Dictionary = _bank.commit(
		{"id": "charge:%d" % revision(), "rev": _bank.revision(), "op": "charge", "amount": amount}
	)
	return "" if result.ok else result.error


func _offers(rerolls: int) -> Dictionary:
	if _format >= 3 and _visit.number >= _gear_from:
		return SeasonGearCatalog.offers(
			_book,
			_roster,
			_bank.view().gear,
			_rng(rerolls),
			"visit:%d:roll:%d" % [_visit.number, rerolls],
			(
				3
				if _format >= 5 and _visit.number >= _mapped_gear_from
				else (2 if _format >= 4 and _visit.number >= _misc_from else 1)
			),
			(
				SeasonSponsorCatalog.eligible(_bank.view().sponsors)
				if _format >= 6 and _visit.number >= _sponsor_from
				else {}
			)
		)
	return DevelopmentShopCatalog.offers(
		_book, _roster, _rng(rerolls), "visit:%d:roll:%d" % [_visit.number, rerolls]
	)


func _pack_choices() -> Array:
	var result: Array = []
	for item_id: String in _visit.get("cards", []):
		if not targets(item_id).is_empty():
			result.append(item_id)
	return result


func _rng(roll: int) -> RandomNumberGenerator:
	var result: RandomNumberGenerator = RandomNumberGenerator.new()
	result.seed = _seed * 1009 + int(_visit.number) * 104729 + roll * 7919
	return result


static func _keys(command: Dictionary, extra: Array) -> bool:
	return SeasonOwnership._keys(command, ["id", "rev", "op"] + extra)


static func _signature(format_version: int = VERSION) -> String:
	var base: String = SeasonPlayerCatalog.signature() + ":" + DevelopmentShopCatalog.signature()
	if format_version >= 2:
		base += ":" + RecruitCatalog.signature()
	if format_version >= 3:
		base += (
			":"
			+ SeasonGearCatalog.signature(
				3 if format_version >= 5 else (2 if format_version >= 4 else 1)
			)
		)
	if format_version >= 6:
		base += ":" + SeasonSponsorCatalog.signature()
	return base


func _recruit_offer() -> Dictionary:
	var chance: float = RecruitCatalog.appearance_chance(_visit.number, _appeared)
	var offer: Dictionary = {}
	var rng: RandomNumberGenerator = _rng(1000)
	var eligible: Array[String] = []
	for id: String in _pool:
		if not _roster.has(id) and not _blocked.has(id):
			eligible.append(id)
	if rng.randf() < chance and not eligible.is_empty():
		var id: String = eligible[rng.randi_range(0, eligible.size() - 1)]
		var stage: String = RecruitCatalog.stage_for_visit(_visit.number)
		var returning: bool = _contracts.has(id)
		var profile: Dictionary = player(id) if returning else RecruitCatalog.fresh(id, stage)
		var price: int = _contracts[id] if returning else profile.catchup.price
		offer = {
			"id": "recruit:%d" % _visit.number,
			"player": id,
			"stage": stage,
			"price": price,
			"returning": returning,
			"profile": profile,
			"signed": false
		}
		_appeared = true
	# Exact immutable offer snapshots accompany the replayable commands.
	_recruits.append({"visit": _visit.number, "chance": chance, "offer": offer.duplicate(true)})
	return offer


func _sign(command: Dictionary) -> String:
	var offer: Dictionary = _visit.get("recruit", {})
	if (
		_format < 2
		or not _keys(command, ["offer", "replace"])
		or not command.offer is String
		or not command.replace is String
	):
		return "Choose a quoted recruit and the player they replace."
	if (
		offer.is_empty()
		or offer.signed
		or command.offer != offer.id
		or _visit.number > 6
		or _roster.size() != 4
		or not _roster.has(command.replace)
		or _roster.has(offer.player)
		or _blocked.has(offer.player)
	):
		return "This offer or roster replacement is no longer legal."
	var error: String = _charge(offer.price)
	if not error.is_empty():
		return error
	if not offer.returning:
		var result: Dictionary = _book.commit(
			{
				"id": "recruit:%d" % revision(),
				"rev": _book.revision(),
				"op": "recruit",
				"player": offer.player,
				"target": offer.stage
			}
		)
		if not result.ok:
			return result.error
		_contracts[offer.player] = offer.price
	_roster[_roster.find(command.replace)] = offer.player
	_visit.recruit.signed = true
	return ""


func migrate_gear() -> void:
	if _format < 3:
		_format = 3
		_gear_from = int(_visit.number) + 1


func _gear_transaction(command: Dictionary) -> String:
	if _format < 3 or _visit.number < _gear_from:
		return "Gear starts at your next shop visit."
	if command.op == "sell_gear":
		if not _keys(command, ["receipt"]) or not command.receipt is String:
			return "Choose an equipped item to sell."
		var owned: Dictionary = SeasonOwnership._owned(_bank.view(), command.receipt)
		if owned.is_empty() or owned.kind != "gear":
			return "Only equipped paid Gear can be sold here."
		var sale: Dictionary = _bank.commit(
			{
				"id": "sale:%d" % revision(),
				"rev": _bank.revision(),
				"op": "sell",
				"receipt": command.receipt,
				"discard": []
			}
		)
		return "" if sale.ok else sale.error
	if (
		not _keys(command, ["offer", "replace"])
		or not command.offer is String
		or not command.replace is String
	):
		return "Review an exact Gear offer and replacement receipt."
	var item_id: String = _visit.offers.get(command.offer, "")
	var item: Dictionary = SeasonGearCatalog.item(item_id)
	if item.is_empty():
		return "This Gear offer is no longer available."
	if _bank.view().gear[item.slot].get("item", "") == item_id:
		return "That exact Gear is already equipped."
	var quote: String = "gear:%d" % revision()
	var stocked: Dictionary = _bank.commit(
		{"id": quote, "rev": _bank.revision(), "op": "stock", "offers": {quote: item_id}}
	)
	if not stocked.ok:
		return stocked.error
	var bought: Dictionary = _bank.commit(
		{
			"id": "purchase:%d" % revision(),
			"rev": _bank.revision(),
			"op": "buy",
			"offer": quote,
			"replace": command.replace,
			"discard": []
		}
	)
	if not bought.ok:
		return bought.error
	_visit.offers.erase(command.offer)
	return ""


func migrate_misc() -> void:
	if _format < 4:
		_format = 4
		_misc_from = int(_visit.number) + 1


func migrate_mapped_gear() -> void:
	if _format < 5:
		_format = 5
		_mapped_gear_from = int(_visit.number) + 1


func migrate_sponsors() -> void:
	if _format < 6:
		_format = 6
		_sponsor_from = int(_visit.number) + 1


func income_for_game(game: int) -> Dictionary:
	return _income_by_game.get(game, {}).duplicate(true)


func _settle_sponsors(command: Dictionary) -> String:
	var active: Array = _bank.view().sponsors
	if not active.is_empty() and not command.has("performance"):
		return "Sponsor income requires the completed game's statistics."
	var performance: Variant = command.get("performance", {})
	if not performance is Dictionary:
		return "Invalid sponsor performance."
	if not performance.is_empty():
		if not SeasonPerformance.valid(performance, performance.keys()):
			return "Invalid sponsor performance."
		for id: String in _roster:
			if not active.is_empty() and not performance.has(id):
				return "Missing current player statistics."
	var income: Dictionary = SeasonSponsorCatalog.earnings(active, _roster, performance)
	var amount: int = 0
	for value: int in income.values():
		amount += value
	if amount > 0:
		var paid: Dictionary = _bank.commit(
			{
				"id": "sponsor-income:%d" % int(command.game),
				"rev": _bank.revision(),
				"op": "sponsor_income",
				"amount": amount
			}
		)
		if not paid.ok:
			return paid.error
	if not income.is_empty():
		_income_by_game[int(command.game)] = income
	return ""


func _sponsor_transaction(command: Dictionary) -> String:
	if _format < 6 or _visit.number < _sponsor_from:
		return "Sponsors are not available at this visit."
	if command.op == "sponsor_sell":
		if not _keys(command, ["receipt"]) or not command.receipt is String:
			return "Choose an active sponsor."
		var owned: Dictionary = SeasonOwnership._owned(_bank.view(), command.receipt)
		if owned.get("kind") != "sponsor":
			return "Choose an active sponsor."
		var sold: Dictionary = _bank.commit(
			{
				"id": "sponsor-sale:%d" % revision(),
				"rev": _bank.revision(),
				"op": "sell",
				"receipt": command.receipt,
				"discard": []
			}
		)
		return "" if sold.ok else sold.error
	if not _keys(command, ["offer", "replace"]) or not command.offer is String:
		return "Review an exact sponsor offer."
	var item_id: String = _visit.offers.get(command.offer, "")
	if not SeasonSponsorCatalog.ITEMS.has(item_id):
		return "This sponsor offer is no longer available."
	# Reject same-identity replacement before sale can temporarily remove it.
	if not SeasonSponsorCatalog.eligible(_bank.view().sponsors).has(item_id):
		return "That sponsor is already active."
	var quote: String = "sponsor:%d" % revision()
	var stock: Dictionary = _bank.commit(
		{"id": quote, "rev": _bank.revision(), "op": "stock", "offers": {quote: item_id}}
	)
	if not stock.ok:
		return stock.error
	var bought: Dictionary = _bank.commit(
		{
			"id": "sponsor-purchase:%d" % revision(),
			"rev": _bank.revision(),
			"op": "buy",
			"offer": quote,
			"replace": command.replace,
			"discard": []
		}
	)
	if not bought.ok:
		return bought.error
	_visit.offers.erase(command.offer)
	return ""

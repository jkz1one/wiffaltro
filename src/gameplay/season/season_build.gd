class_name SeasonBuild
extends RefCounted
## Atomic Working-season wallet, held-card, development and shop aggregate.
## Only this journal is saved: independent wallet/growth blobs cannot disagree.
# gdlint: disable=max-returns

const VERSION: int = 24
const MAX_EVENTS: int = 512
const SHOP_OPS: Array[String] = [
	"open",
	"leave_shop",
	"lesson_pair",
	"wholesale",
	"tactical_buy",
	"tactical_exchange",
	"buy",
	"use",
	"discard",
	"reroll",
	"focused_reroll",
	"reserve_offer",
	"release_reservation",
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
var _market: int = 0
var _gear_progress: SeasonGearProgress = SeasonGearProgress.new()
var _sponsor_progress: SeasonSponsorProgress = SeasonSponsorProgress.new()
var _legends: Dictionary = {}
var _order_start: Variant = null
var _paid_rerolls: int = 0
var _rain_start: Variant = null
var _rain_earned: bool = false
var _reservation: Dictionary = {}
var _recruit_from: int = 1
var _gear_from: int = 1
var _misc_from: int = 1
var _mapped_gear_from: int = 1
var _sponsor_from: int = 1
var _gameplay_sponsor_from: int = 1
var _sequence_sponsor_from: int = 1
var _field_sponsor_from: int = 1
var _shop_sponsor_from: int = 1
var _school_sponsor_from: int = 1
var _anchor_sponsor_from: int = 1
var _wholesale_from: int = 1
var _tactical_from: int = 1
var _expanded_tactical_from: int = 1
var _tactical_sponsor_from: int = 1
var _budget_from: int = 1
var _film_from: int = 1
var _scouts: Dictionary = {}
var _pregames: Dictionary = {}
var _match_inventory: Dictionary = {}
var _scholarships: Dictionary = {}
var _used_gear: Dictionary = {}
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


func player(player_id: String) -> Dictionary:
	return _book.player(player_id)


func definition(player_id: String) -> PlayerDefinition:
	var result: PlayerDefinition = ProgressionMatchAdapter.player(_book, player_id)
	if result != null and _roster.has(player_id):
		result = SeasonGearCatalog.equip(result, _bank.view().gear)
		result.season_sponsors = SeasonSponsorEffects.snapshot(
			_bank.view().sponsors, _book, _roster, _legends
		)
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
	return {
		"pregames": _pregames.duplicate(true),
		"scouts": _scouts.duplicate(true),
		"revision": revision(),
		"wallet": _bank.view(),
		"shop": visit,
		"roster": roster(),
		"used_gear": _used_gear.keys(),
		"reservation": _reservation.duplicate(true),
		"scholarships": _scholarships.duplicate(true)
	}


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
	if _format >= 7:
		data["gameplay_sponsor_from"] = _gameplay_sponsor_from
	if _format >= 8:
		data["sequence_sponsor_from"] = _sequence_sponsor_from
	if _format >= 9:
		data["field_sponsor_from"] = _field_sponsor_from
	if _format >= 10:
		data["shop_sponsor_from"] = _shop_sponsor_from
	if _format >= 11:
		data["school_sponsor_from"] = _school_sponsor_from
	if _format >= 12:
		data["anchor_sponsor_from"] = _anchor_sponsor_from
	if _format >= 13:
		data["wholesale_from"] = _wholesale_from
	if _format >= 14:
		data["tactical_from"] = _tactical_from
	if _format >= 15:
		data["expanded_tactical_from"] = _expanded_tactical_from
	if _format >= 16:
		data["tactical_sponsor_from"] = _tactical_sponsor_from
	if _format >= 17:
		data["budget_from"] = _budget_from
	if _format >= 18:
		data["film_from"] = _film_from
	if _format >= 19:
		data["market"] = _market
	if _format >= 20:
		data["gear_start"] = _gear_progress.start.duplicate() if _gear_progress.enabled else null
	if _format >= 21:
		data["sponsor_start"] = (
			_sponsor_progress.start.duplicate(true) if _sponsor_progress.enabled else null
		)
	if _format >= 23:
		data["order_start"] = _order_start
	if _format >= 24:
		data["rain_start"] = _rain_start
	return data


static func from_data(
	value: Variant,
	seed_value: int,
	roster: Array[String],
	pool: Array[String] = [],
	blocked: Array[String] = []
) -> SeasonBuild:
	return SeasonBuildRestore.restore(value, seed_value, roster, pool, blocked)


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
	_scholarships = next._scholarships
	_used_gear = next._used_gear
	_gear_progress = next._gear_progress
	_sponsor_progress = next._sponsor_progress
	_legends = next._legends
	_order_start = next._order_start
	_paid_rerolls = next._paid_rerolls
	_rain_start = next._rain_start
	_rain_earned = next._rain_earned
	_reservation = next._reservation
	_income_by_game = next._income_by_game
	_pregames = next._pregames
	_match_inventory = next._match_inventory
	_scouts = next._scouts
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
	if _order_start != null and normalized.op == "reroll" and next.cash() < cash():
		next._paid_rerolls += 1
	SeasonRaincheck.after(self, next, normalized)
	SeasonLegends.prune(next)
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
	result._market = _market
	result._gear_progress = _gear_progress.fork()
	result._sponsor_progress = _sponsor_progress.fork()
	result._legends = _legends.duplicate(true)
	result._order_start = _order_start
	result._paid_rerolls = _paid_rerolls
	result._rain_start = _rain_start
	result._rain_earned = _rain_earned
	result._reservation = _reservation.duplicate(true)
	result._recruit_from = _recruit_from
	result._gear_from = _gear_from
	result._misc_from = _misc_from
	result._mapped_gear_from = _mapped_gear_from
	result._sponsor_from = _sponsor_from
	result._gameplay_sponsor_from = _gameplay_sponsor_from
	result._sequence_sponsor_from = _sequence_sponsor_from
	result._field_sponsor_from = _field_sponsor_from
	result._shop_sponsor_from = _shop_sponsor_from
	result._school_sponsor_from = _school_sponsor_from
	result._anchor_sponsor_from = _anchor_sponsor_from
	result._wholesale_from = _wholesale_from
	result._tactical_from = _tactical_from
	result._expanded_tactical_from = _expanded_tactical_from
	result._tactical_sponsor_from = _tactical_sponsor_from
	result._budget_from = _budget_from
	result._film_from = _film_from
	result._scouts = _scouts.duplicate(true)
	result._pregames = _pregames.duplicate(true)
	result._match_inventory = _match_inventory.duplicate(true)
	result._scholarships = _scholarships.duplicate(true)
	result._used_gear = _used_gear.duplicate()
	result._income_by_game = _income_by_game.duplicate(true)
	result._bank = _bank.fork()
	result._book = _book.fork()
	result._visit = _visit.duplicate(true)
	result._events = _events.duplicate(true)
	result._requests = _requests.duplicate(true)
	return result


func _apply(command: Dictionary) -> String:
	var op: String = str(command.get("op", ""))
	if pack_pending() and op not in ["pack_pick", "pack_skip", "leave_shop"]:
		return "Choose or skip the open pack before leaving or doing other shopping."
	if op in ["match_inventory", "match_sell"]:
		return SeasonMatchInventory.commit(self, command)
	if op == "scout":
		return SeasonFilmRoom.commit(self, command)
	if op == "pregame":
		return SeasonBudgetBites.commit(self, command)
	if op == "reward":
		if not _match_inventory.is_empty() and command.get("game") != _match_inventory.game:
			return "Complete the current inventory attempt first."
		var fields: Array = ["game", "win"]
		if _format >= 6 and command.has("performance"):
			fields.append("performance")
		if _format >= 10 and command.has("used_gear"):
			fields.append("used_gear")
		if _format >= 14 and command.has("tactics"):
			fields.append("tactics")
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
		if _format >= 10:
			error = SeasonReclamation.settle(
				self, command.get("used_gear", []), command.get("performance", {})
			)
			if not error.is_empty():
				return error
		if _format >= 14:
			error = SeasonTacticalPurchase.settle(
				self, command.get("tactics", []), command.get("performance", {})
			)
			if not error.is_empty():
				return error
		_gear_progress.settle(self, command)
		_match_inventory.clear()
		_sponsor_progress.settle(self, command)
		SeasonLegends.settle(self, command.get("performance", {}))
		_game_rosters[int(command.game)] = roster()
		_visit = {"number": _visit.number + 1, "open": false}
		if (
			_format >= 11
			and SeasonSchoolSponsors.qualifies_union(self, command.get("performance", {}))
		):
			_visit["union_earned"] = true
		return ""
	if op == "open":
		if not _keys(command, []) or _visit.open or _visit.number < 1:
			return "No new postgame shop is available."
		var union_earned: bool = _visit.get("union_earned", false)
		_visit = {
			"number": _visit.number,
			"open": true,
			"rerolls": 0,
			"offers": _offers(0),
			"cards":
			(
				SeasonOpponentMarket.pack(self)
				if _market == 1
				else DevelopmentShopCatalog.pack(_book, _roster, _rng(-1))
			),
			"pack_status": "sealed"
		}
		SeasonRaincheck.deliver(self)
		if union_earned:
			_visit["union_credit"] = 3
		if _market == 0 and _format >= 2 and _visit.number >= _recruit_from:
			_visit["recruit"] = _recruit_offer()
		return ""
	if not _visit.open:
		return "Open the current postgame shop first."
	match op:
		"reserve_offer", "release_reservation":
			return SeasonRaincheck.commit(self, command)
		"focused_reroll":
			return SeasonSpecialOrder.commit(self, command)
		"tactical_exchange":
			return SeasonTacticalExchange.exchange(self, command)
		"tactical_buy":
			return SeasonTacticalPurchase.buy(self, command)
		"wholesale":
			return SeasonWholesale.purchase(self, command)
		"lesson_pair":
			return SeasonSchoolSponsors.pair(self, command)
		"leave_shop":
			if _format < 10 or not _keys(command, []):
				return "Invalid shop departure."
			_visit["reroll_credit"] = 0
			if _format >= 11:
				_visit["union_credit"] = 0
		"sponsor_buy", "sponsor_sell":
			return _sponsor_transaction(command)
		"equip", "sell_gear":
			return _gear_transaction(command)
		"sign":
			return _sign(command)
		"buy":
			return SeasonDevelopmentPurchase.buy(self, command)
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
			var error: String = _charge(SeasonReclamation.price(_visit))
			if not error.is_empty():
				return error
			if _format >= 10:
				_visit["reroll_credit"] = 0
			_visit.rerolls += 1
			var protected: Dictionary = SeasonRaincheck.protected_offer(self)
			_visit.offers = _offers(_visit.rerolls)
			SeasonRaincheck.preserve(self, protected)
			_visit.erase("unavailable_slots")
			_visit.erase("focused_category")
		"pack_open":
			if (
				not _keys(command, [])
				or _visit.pack_status != "sealed"
				or _pack_choices().is_empty()
			):
				return "No eligible unopened pack."
			var error: String = _charge(
				maxi(0, DevelopmentShopCatalog.PACK_PRICE - int(_visit.get("union_credit", 0)))
			)
			if not error.is_empty():
				return error
			if _format >= 11:
				_visit["union_credit"] = 0
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


func _develop(item_id: String, command: Dictionary, suffix: String = "") -> String:
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
		"id": "growth:%d%s" % [revision(), suffix],
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
	if _market == 1:
		return SeasonOpponentMarket.offers(self, rerolls)
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
				SeasonEarnedSponsors.eligible(self)
				if _format >= 6 and _visit.number >= _sponsor_from
				else {}
			),
			(
				SeasonTacticalCatalog.weights(_tactical_catalog_version())
				if _format >= 14 and _visit.number >= _tactical_from
				else {}
			),
			_gear_progress.eligible()
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
		base += ":" + SeasonSponsorCatalog.signature(SeasonSponsorCatalog.for_build(format_version))
	if format_version >= 14:
		base += ":" + SeasonTacticalCatalog.signature(2 if format_version >= 15 else 1)
	if format_version >= 20:
		base += ":" + JSON.stringify(SeasonEarnedGear.ITEMS).sha256_text()
	if format_version >= 21:
		base += ":" + JSON.stringify(SeasonEarnedSponsors.ITEMS).sha256_text()
	if format_version >= 23:
		base += ":" + JSON.stringify(SeasonSpecialOrder.ITEMS).sha256_text()
	if format_version >= 24:
		base += ":" + JSON.stringify(SeasonRaincheck.ITEMS).sha256_text()
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
	return SeasonSchoolSponsors.departure(self, command.replace)


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
		if sale.ok and _format >= 10:
			SeasonReclamation.sold(self, owned)
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
	var replaced: Dictionary = SeasonOwnership._owned(_bank.view(), command.replace)
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
	if _format >= 10:
		SeasonReclamation.sold(self, replaced)
	_visit.offers.erase(command.offer)
	return ""


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
		if sold.ok:
			_scholarships.erase(command.receipt)
		return "" if sold.ok else sold.error
	if not command.get("offer") is String:
		return "Review an exact sponsor offer."
	var item_id: String = _visit.offers.get(command.offer, "")
	if not SeasonEarnedSponsors.eligible(self).has(item_id):
		return "This sponsor offer is no longer available."
	var fields: Array = ["offer", "replace"]
	if item_id == "J10":
		fields.append("student")
		if (
			not command.get("student") is String
			or not SeasonSchoolSponsors.eligible_student(self, command.student)
		):
			return "Choose an eligible undeveloped student (unapproved Proposal)."
	if not _keys(command, fields):
		return "Review the exact sponsor and nomination."
	# Reject same-identity replacement before sale can temporarily remove it.
	if not SeasonEarnedSponsors.eligible(self).has(item_id):
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
	_scholarships.erase(command.replace)
	if item_id == "J10":
		_scholarships["sponsor-purchase:%d" % revision()] = {"player": command.student, "uses": 3}
	_visit.offers.erase(command.offer)
	return ""


func _sponsor_catalog_version() -> int:
	return SeasonSponsorCatalog.for_visit(self)


func _tactical_catalog_version() -> int:
	return 2 if _format >= 15 and _visit.number >= _expanded_tactical_from else 1


func migrate() -> void:
	SeasonBuildMigration.apply(self)

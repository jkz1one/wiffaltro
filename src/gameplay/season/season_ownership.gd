# gdlint: disable=max-returns
# Validation uses early exits before publishing any candidate state.
class_name SeasonOwnership
extends RefCounted
## Approved equipped-only ownership. Prices/capacities and income remain Working.
## Catalog/stock commands are issued by trusted shop code, never loaded as balances.

const VERSION: int = 1
const TERMS_VERSION: int = 2
const SHORT_TERM_VERSION: int = 3
const LEAGUE_VERSION: int = 4
const LEAGUE_TIER_VERSION: int = 5
const _LEAGUE_TIER_ECONOMY = preload("res://src/gameplay/season/league_tier_economy.gd")
const MAX_EVENTS: int = 4096
const GEAR_SLOTS: Array[String] = ["bat", "ball", "misc"]
var _catalog: Dictionary = {}
var _format: int = VERSION
var _league_rules: Dictionary = {}
var _sponsor_rule: String = ""
var _term_seed: int = 0
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


func enable_league_rules(value: Variant) -> bool:
	var rules: Dictionary = LeagueRules.normalized(value)
	if rules.is_empty() or int(rules.tier) != 0 \
		or not _events.is_empty() or not _requests.is_empty():
		return false
	if _format == LEAGUE_VERSION:
		return league_rules_valid() and _league_rules == rules
	if _format != VERSION or not context_valid():
		return false
	var empty: SeasonOwnership = SeasonOwnership.new(_catalog)
	if _state != empty._state:
		return false
	_format = LEAGUE_VERSION
	_league_rules = rules.duplicate(true)
	if LeagueRules.equipment(_league_rules):
		_state["spare"] = {}
	return true


func enable_league_tier(value: Variant, seed_value: Variant) -> bool:
	var rules: Dictionary = LeagueRules.normalized(value)
	var rule: String = _LEAGUE_TIER_ECONOMY.sponsor_rule(rules)
	if not _LEAGUE_TIER_ECONOMY.valid(rules, rule, seed_value) \
		or not _events.is_empty() or not _requests.is_empty():
		return false
	if _format == LEAGUE_TIER_VERSION:
		return league_rules_valid() and _league_rules == rules and _term_seed == int(seed_value)
	if _format != VERSION or not context_valid():
		return false
	var empty: SeasonOwnership = SeasonOwnership.new(_catalog)
	if _state != empty._state:
		return false
	_format = LEAGUE_TIER_VERSION
	_league_rules = rules.duplicate(true)
	_sponsor_rule = rule
	_term_seed = int(seed_value)
	if LeagueRules.equipment(rules):
		_state["spare"] = {}
	if rule == SeasonSponsorCatalog.D4_RULE:
		_state["sponsor_pending"] = {}
	return true


func league_rules_valid() -> bool:
	if _format == LEAGUE_TIER_VERSION:
		return _LEAGUE_TIER_ECONOMY.valid(_league_rules, _sponsor_rule, _term_seed)
	return (
		_format == LEAGUE_VERSION
		and _sponsor_rule.is_empty()
		and _term_seed == 0
		and not LeagueRules.normalized(_league_rules).is_empty()
		and int(_league_rules.tier) == 0
	)


func enable_sponsor_terms(rule: String, seed_value: Variant) -> bool:
	if (
		not _events.is_empty()
		or not _requests.is_empty()
		or rule not in [SeasonSponsorCatalog.D3_RULE, SeasonSponsorCatalog.D4_RULE]
		or not _whole(seed_value, 0, 2147483647)
	):
		return false
	if sponsor_terms_valid() or d4_sponsors_valid():
		return _sponsor_rule == rule and _term_seed == int(seed_value)
	if _format != VERSION or not context_valid():
		return false
	var empty: SeasonOwnership = SeasonOwnership.new(_catalog)
	if _state != empty._state:
		return false
	_format = SHORT_TERM_VERSION if rule == SeasonSponsorCatalog.D4_RULE else TERMS_VERSION
	if _format == SHORT_TERM_VERSION:
		_state["sponsor_pending"] = {}
	_sponsor_rule = rule
	_term_seed = int(seed_value)
	return true


func sponsor_terms_valid() -> bool:
	if _format == LEAGUE_TIER_VERSION:
		return league_rules_valid() and _sponsor_rule == SeasonSponsorCatalog.D3_RULE
	return (
		_format == TERMS_VERSION
		and _sponsor_rule == SeasonSponsorCatalog.D3_RULE
		and _whole(_term_seed, 0, 2147483647)
	)


func d4_sponsors_valid() -> bool:
	if _format == LEAGUE_TIER_VERSION:
		return league_rules_valid() and _sponsor_rule == SeasonSponsorCatalog.D4_RULE
	return (
		_format == SHORT_TERM_VERSION
		and _sponsor_rule == SeasonSponsorCatalog.D4_RULE
		and _whole(_term_seed, 0, 2147483647)
	)


func completion_closed() -> bool:
	return not d4_sponsors_valid() or _state.get("sponsor_pending") == {}


func context_valid() -> bool:
	if _format in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		return league_rules_valid()
	return (
		_league_rules.is_empty()
		and (
			d4_sponsors_valid()
			or sponsor_terms_valid()
			or (_format == VERSION and _sponsor_rule.is_empty() and _term_seed == 0)
		)
	)


func empty_fork() -> SeasonOwnership:
	var result: SeasonOwnership = SeasonOwnership.new(_catalog)
	result._format = _format
	result._league_rules = _league_rules.duplicate(true)
	if LeagueRules.equipment(_league_rules):
		result._state["spare"] = {}
	result._sponsor_rule = _sponsor_rule
	result._term_seed = _term_seed
	if d4_sponsors_valid():
		result._state["sponsor_pending"] = {}
	return result


func source_metadata(item_id: String, offer: String) -> Dictionary:
	if (
		(sponsor_terms_valid() or d4_sponsors_valid())
		and SeasonSponsorCatalog.D3_ITEMS.has(item_id)
	):
		# Empty normalization remains mandatory metadata and is rejected by _buy.
		return {"source_offer": SeasonSponsorCatalog.original_offer(offer)}
	return {}


func _source_valid(command: Dictionary, item_id: String) -> bool:
	if not context_valid():
		return false
	if (
		not (sponsor_terms_valid() or d4_sponsors_valid())
		or not SeasonSponsorCatalog.D3_ITEMS.has(item_id)
	):
		return not command.has("source_offer")
	var source: Variant = command.get("source_offer")
	return (
		source is String
		and not source.is_empty()
		and SeasonSponsorCatalog.original_offer(source) == source
	)


func revision() -> int:
	return _events.size()


func cash() -> int:
	return int(_state.cash)


func fork() -> SeasonOwnership:
	var result: SeasonOwnership = empty_fork()
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
	# Public snapshots describe completed journals. Detached settlement candidates
	# remain readable and forkable until their terminal close has been accepted.
	if not context_valid() or not completion_closed():
		return {}
	var data: Dictionary = {
		"version": _format,
		"catalog": JSON.stringify(_catalog).sha256_text(),
		"events": _events.duplicate(true)
	}
	if (sponsor_terms_valid() or d4_sponsors_valid()) or _format == LEAGUE_TIER_VERSION:
		data["sponsor_rule"] = _sponsor_rule
		data["term_seed"] = _term_seed
	if _format in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		data["league_rules"] = _league_rules.duplicate(true)
	return data


static func from_data(value: Variant, catalog: Dictionary = {}) -> SeasonOwnership:
	if not value is Dictionary or not _whole(value.get("version"), VERSION, LEAGUE_TIER_VERSION):
		return null
	var fields: Array = ["version", "catalog", "events"]
	if int(value.version) in [TERMS_VERSION, SHORT_TERM_VERSION, LEAGUE_TIER_VERSION]:
		fields.append_array(["sponsor_rule", "term_seed"])
	if int(value.version) in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		fields.append("league_rules")
	if not _keys(value, fields) or not value.events is Array or value.events.size() > MAX_EVENTS:
		return null
	if value.catalog != JSON.stringify(catalog).sha256_text():
		return null
	var result: SeasonOwnership = SeasonOwnership.new(catalog)
	if value.version == TERMS_VERSION or value.version == SHORT_TERM_VERSION:
		if (
			not value.sponsor_rule is String
			or not result.enable_sponsor_terms(value.sponsor_rule, value.term_seed)
			or result._format != int(value.version)
		):
			return null
	if value.version == LEAGUE_VERSION and not result.enable_league_rules(value.league_rules):
		return null
	if value.version == LEAGUE_TIER_VERSION:
		if not value.sponsor_rule is String \
			or not result.enable_league_tier(value.league_rules, value.term_seed) \
			or result._sponsor_rule != value.sponsor_rule:
			return null
	for event: Variant in value.events:
		if not event is Dictionary:
			return null
		var outcome: Dictionary = result.commit(event)
		if not outcome.ok or outcome.replayed:
			return null
	return result if result.completion_closed() else null


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
	# Reserve every generated receipt identity, including after it is sold. A later
	# ordinary request must not recreate an identity owned by this grouped event.
	if normalized.op == "sponsor_set":
		for index in range(normalized.purchases.size()):
			_requests[SeasonSponsorSet.receipt_id(normalized.id, index)] = {"set": normalized.id}
	if normalized.op == SeasonInventoryResale.FIELD_OP:
		_requests[SeasonFieldGrant.receipt(int(normalized.game))] = {"field_sale": normalized.id}
	return {"ok": true, "replayed": false}


func _prepare(command: Dictionary) -> Dictionary:
	if not context_valid():
		return _failure("Invalid sponsor acquisition context.")
	if not _text(command.get("id")) or not _whole(command.get("rev"), 0, MAX_EVENTS):
		return _failure("Invalid transaction identity or revision.")
	var normalized: Dictionary = command.duplicate(true)
	normalized.rev = int(normalized.rev)
	if normalized.has("game") and _whole(normalized.game, 0, 32):
		normalized.game = int(normalized.game)
	if LeagueRules.earnings(_league_rules) and normalized.get("op") == "reward":
		for score: String in ["own_runs", "opponent_runs"]:
			if SeasonOwnership._whole(normalized.get(score), 0, 9999):
				normalized[score] = int(normalized[score])
	if normalized.get("op") == "sponsor_set":
		SeasonSponsorSet.normalize(normalized)
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
	var sponsor_error: String = SeasonSponsorSet.validate_peers(next, _catalog)
	if not sponsor_error.is_empty():
		return _failure(sponsor_error)
	if next.cash < 0 or next.cash > 1000000:
		return _failure("Insufficient Season Cash or invalid balance.")
	return {"ok": true, "replayed": false, "after": next, "command": normalized}


func _apply(next: Dictionary, command: Dictionary) -> String:
	if (
		d4_sponsors_valid()
		and not next.sponsor_pending.is_empty()
		and (
			command.get("op")
			not in [
				"sponsor_game_end", "sponsor_income", "field_grant", "insurance_grant", "discard"
			]
		)
	):
		return "Complete this game's sponsor settlement before another transaction."
	match command.get("op"):
		SeasonInventoryResale.ENABLE_OP:
			return SeasonInventoryResale.enable(next, command)
		SeasonInventoryResale.SALE_OP:
			return SeasonInventoryResale.apply(self, next, command)
		SeasonInventoryResale.FIELD_OP:
			return SeasonInventoryResale.apply_field(self, next, command)
		"sponsor_game_end":
			return _sponsor_game_end(next, command)
		"sponsor_set":
			return SeasonSponsorSet.apply(self, next, command)
		"field_grant":
			return SeasonFieldGrant.grant(next, command)
		"insurance_grant":
			return SeasonSecondChance.grant(next, command)
		"budget_grant":
			return SeasonBudgetBites.grant(next, command)
		"tactical_exchange":
			return SeasonTacticalExchange.apply(next, command)
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
			var fields: Array = ["id", "rev", "op", "game", "win"]
			if LeagueRules.earnings(_league_rules):
				fields.append_array(["own_runs", "opponent_runs"])
			if not _keys(command, fields):
				return "Invalid game reward."
			if not _whole(command.game, 0, 32) or not command.win is bool:
				return "Invalid game reward."
			if (
				LeagueRules.earnings(_league_rules)
				and not LeagueRules.final_scores_valid(
					command.own_runs, command.opponent_runs, command.win
				)
			):
				return "Invalid completed game scores."
			var game: String = str(int(command.game))
			if next.rewards.has(game):
				return "This game already paid its reward."
			if LeagueRules.doubleheader(_league_rules):
				var first_game: int = SeasonDoubleheaderRules.first(command.game)
				if first_game >= 0 and not next.rewards.get(str(first_game)) is bool:
					return "Complete and settle the first game of this doubleheader first."
			if d4_sponsors_valid():
				var covered: Array[String] = []
				for active: Dictionary in next.sponsors:
					if active.get("terms", {}).get("rule") == SeasonSponsorCatalog.D4_RULE:
						covered.append(active.id)
				next.sponsor_pending = {"game": int(command.game), "receipts": covered}
			next.rewards[game] = command.win
			next.cash += (
				LeagueRules.game_income(
					_league_rules,
					command.win,
					command.get("own_runs"),
					command.get("opponent_runs")
				)
				if (_format in [LEAGUE_VERSION, LEAGUE_TIER_VERSION])
				else (18 if command.win else 12)
			)
			# Derived from this exact pair's paid result, never a caller amount.
			next.cash += SeasonDoubleheaderRules.bonus(
				_league_rules, command.game, command.win, next.rewards
			)
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
		"spare_buy":
			if (
				not LeagueRules.equipment(_league_rules)
				or not _keys(command, ["id", "rev", "op", "offer", "replace", "discard"])
				or command.replace != ""
				or command.discard != []
				or not next.get("spare", {}).is_empty()
			):
				return "Choose an empty inactive spare destination."
			return _buy(next, command, true)
		"spare_swap":
			if (
				not LeagueRules.equipment(_league_rules)
				or not _keys(command, ["id", "rev", "op", "spare", "active"])
			):
				return "Invalid spare exchange."
			if not command.spare is String or not command.active is String:
				return "Review the exact owned spare and active receipts."
			var spare: Dictionary = next.get("spare", {})
			if spare.is_empty() or spare.id != command.spare:
				return "The inactive spare changed."
			var slot: String = _catalog[spare.item].slot
			var active: Dictionary = next.gear[slot]
			if active.get("id", "") != command.active or command.active == command.spare:
				return "Exchange only with the exact matching-category active receipt."
			next.gear[slot] = spare.duplicate(true)
			next.spare = active.duplicate(true)
		"buy":
			var fields: Array = ["id", "rev", "op", "offer", "replace", "discard"]
			if command.has("discount"):
				fields.append("discount")
			if command.has("wholesale_discount"):
				fields.append("wholesale_discount")
			if (
				(sponsor_terms_valid() or d4_sponsors_valid())
				and SeasonSponsorCatalog.D3_ITEMS.has(next.stock.get(command.get("offer"), ""))
			):
				fields.append("source_offer")
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


func _buy(next: Dictionary, command: Dictionary, spare_destination: bool = false) -> String:
	if (
		not _text(command.offer)
		or not next.stock.has(command.offer)
		or not command.replace is String
	):
		return "Offer unavailable or invalid replacement."
	var item_id: String = next.stock[command.offer]
	var item: Dictionary = _catalog[item_id]
	if spare_destination and item.kind != "gear":
		return "Only eligible Gear may occupy the inactive spare."
	if LeagueRules.equipment(_league_rules) and item.kind == "gear":
		for copy: Dictionary in next.gear.values() + [next.get("spare", {})]:
			if copy.get("item", "") == item_id:
				return "That exact Gear is already owned."
	if not _source_valid(command, item_id):
		return "Review the original generated sponsor offer."
	var discount: Variant = command.get("discount", 0)
	if not _whole(discount, 0, mini(3, item.price)) or (discount > 0 and item.kind != "held"):
		return "Invalid held-card acquisition credit."
	if command.has("wholesale_discount"):
		if (
			command.has("discount")
			or (
				item.kind not in ["gear", "sponsor"]
				and not SeasonTacticalCatalog.catalog().has(item_id)
			)
		):
			return "Wholesale cannot stack or discount held development."
		discount = command.wholesale_discount
		if not _whole(discount, 0, mini(4, int(item.price / 4))):
			return "Invalid wholesale receipt discount."

	if not command.replace.is_empty():
		var old: Dictionary = _owned(next, command.replace)
		if old.is_empty() or old.kind != item.kind or item.kind == "held":
			return "Choose an owned item in the same category."
		if (
			item.kind == "gear"
			and (
				_catalog[old.item].slot != item.slot or old.id != next.gear[item.slot].get("id", "")
			)
		):
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
	if (
		(sponsor_terms_valid() or d4_sponsors_valid())
		and item.kind == "sponsor"
		and SeasonSponsorCatalog.D3_ITEMS.has(item_id)
	):
		var terms: Dictionary = SeasonSponsorCatalog.offer_terms(
			_sponsor_rule, _term_seed, command.source_offer, item_id
		)
		if not terms.is_empty():
			receipt["terms"] = terms
			if terms.rule == SeasonSponsorCatalog.D4_RULE:
				receipt["games_remaining"] = SeasonSponsorCatalog.D4_DURATION
	if spare_destination:
		next.spare = receipt
	elif item.kind == "gear":
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
	if (
		(sponsor_terms_valid() or d4_sponsors_valid())
		and owned.kind == "sponsor"
		and item.sale == "half"
	):
		credit = SeasonSponsorCatalog.resale(owned)
	next.cash += credit
	if owned.kind == "gear":
		if next.get("spare", {}).get("id", "") == receipt_id:
			next.spare = {}
		else:
			next.gear[item.slot] = {}
	else:
		next.sponsors.erase(owned)
	return ""


func _sponsor_game_end(next: Dictionary, command: Dictionary) -> String:
	if (
		not d4_sponsors_valid()
		or not _keys(command, ["id", "rev", "op", "game"])
		or not _whole(command.game, 0, 32)
	):
		return "Invalid completed-game sponsor closure."
	var pending: Dictionary = next.sponsor_pending
	if (
		pending.is_empty()
		or pending.game != int(command.game)
		or not next.rewards.has(str(int(command.game)))
	):
		return "Close only the exact pending paid game once."
	for receipt_id: String in pending.receipts:
		var active: Dictionary = _owned(next, receipt_id)
		if (
			active.is_empty()
			or active.get("kind") != "sponsor"
			or not SeasonSponsorCatalog.D3_ITEMS.has(active.get("item"))
			or not SeasonSponsorCatalog.terms_valid(active.get("terms"))
			or active.terms.rule != SeasonSponsorCatalog.D4_RULE
			or not _whole(active.get("games_remaining"), 1, SeasonSponsorCatalog.D4_DURATION)
		):
			return "The covered sponsor receipt changed before final settlement."
		active.games_remaining = int(active.games_remaining) - 1
		if active.games_remaining == 0:
			next.sponsors.erase(active)
	next.sponsor_pending = {}
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
	for owned: Dictionary in (
		state.gear.values() + state.sponsors + state.held + [state.get("spare", {})]
	):
		if owned.get("id") == receipt_id:
			return owned
	return {}


func _capacity(state: Dictionary) -> Dictionary:
	var held: int = 2
	var sponsors: int = 5
	if _format in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		var base: Dictionary = LeagueRules.capacities(_league_rules)
		if base.is_empty():
			return {"held": 0, "sponsors": 0}
		held = base.held
		sponsors = base.sponsors
	for active: Dictionary in state.sponsors:
		var item: Dictionary = _catalog[active.item]
		held += int(item.get("held_delta", 0))
		sponsors += int(item.get("sponsor_delta", 0))
	for active: Dictionary in state.sponsors:
		sponsors = mini(sponsors, int(_catalog[active.item].get("sponsor_cap", sponsors)))
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
	if item.get("rarity", "") not in ["", "Common", "Uncommon", "Rare"]:
		return false
	if item.get("peer_rarity", "") not in ["", "Common", "Uncommon", "Rare"]:
		return false
	return (
		_whole(item.get("held_delta", 0), -2, 10)
		and _whole(item.get("sponsor_delta", 0), -5, 10)
		and _whole(item.get("sponsor_cap", 32), 0, 32)
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

class_name SeasonBuild
extends "res://src/gameplay/season/season_build_context.gd"
## Atomic Working-season wallet, held-card, development and shop aggregate.
## Only this journal is saved: independent wallet/growth blobs cannot disagree.
# gdlint: disable=max-returns

const DYNASTY_PROFILE_SCRIPT_PATH: String = _CONTEXT_DYNASTY_PROFILE_SCRIPT_PATH
const VERSION: int = _CONTEXT_VERSION
const D1_VERSION: int = _CONTEXT_D1_VERSION
const D3_VERSION: int = _CONTEXT_D3_VERSION
const D4_VERSION: int = _CONTEXT_D4_VERSION
const LEAGUE_VERSION: int = _CONTEXT_LEAGUE_VERSION
const LEAGUE_TIER_VERSION: int = _CONTEXT_LEAGUE_TIER_VERSION
const D1_PRICE_RULE: String = _CONTEXT_D1_PRICE_RULE
const MAX_EVENTS: int = _CONTEXT_MAX_EVENTS
const SHOP_OPS: Array[String] = _CONTEXT_SHOP_OPS


func _init(
	seed_value: int = 0,
	roster: Array[String] = [],
	pool: Array[String] = [],
	blocked: Array[String] = [],
	_fork_only: bool = false
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
	if _fork_only:
		return
	_bank = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	_book = SeasonDevelopment.new("season:%d" % _seed)


func enable_pitch_catalog() -> bool:
	if revision() != 0 or _bank.revision() != 0 or int(_visit.number) != 0 \
		or _format < VERSION or _legacy_gap_name:
		return false
	return _book.enable_pitch_catalog()


func enable_expanded_pitch_catalog() -> bool:
	if revision() != 0 or _bank.revision() != 0 or int(_visit.number) != 0 \
		or _format != VERSION or _legacy_gap_name or not _league_rules.is_empty() \
		or not _dynasty_start.is_empty():
		return false
	return _book.enable_expanded_pitch_catalog()


func pitch_catalog_expanded() -> bool:
	return _book != null and _book._pitch_catalog_version == ExpandedSeasonCatalog.VERSION


func pitch_catalog_signature() -> String:
	if pitch_catalog_expanded():
		return ExpandedSeasonCatalog.signature()
	return WorkingPitchCatalog.signature() if pitch_catalog_current() else ""


func pitch_catalog_current() -> bool:
	return _book != null and _book._pitch_catalog_version == WorkingPitchCatalog.VERSION


func shop_item(id: String) -> Dictionary:
	return DevelopmentShopCatalog.item(id, _book._pitch_catalog_version)


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
		result.season_abilities = _abilities.ids(player_id)
		result = SeasonGearCatalog.equip(result, _bank.view().gear, _format >= 40)
		result.season_sponsors = SeasonSponsorEffects.snapshot(
			_bank.view().sponsors, _book, _roster, _legends
		)
	return result


func targets(item_id: String) -> Array[Dictionary]:
	return DevelopmentShopCatalog.targets(_book, _roster, item_id)


func pack_base_price() -> int:
	return 12 if LeagueRules.academy(_league_rules) else DevelopmentShopCatalog.PACK_PRICE


func pack_price() -> int:
	return maxi(0, pack_base_price() - int(_visit.get("union_credit", 0)))


func pack_pending() -> bool:
	return _visit.get("pack_status") == "open"


func view() -> Dictionary:
	var visit: Dictionary = _visit.duplicate(true)
	if visit.get("pack_status") == "sealed":
		visit["choice_count"] = _pack_choices().size()
		visit.erase("cards")
	if LeagueRules.academy(_league_rules):
		visit["pack_base_price"] = pack_base_price()
		visit["pack_quote"] = pack_price()
		if pack_pending():
			visit["available_cards"] = _pack_choices()
			visit["picks_remaining"] = maxi(0, 2 - _visit.get("pack_picked", []).size())
	return {
		"pregames": _pregames.duplicate(true),
		"scouts": _scouts.duplicate(true),
		"insurance": _insurance.duplicate(true),
		"revision": revision(),
		"wallet": _bank.view(),
		"shop": visit,
		"roster": roster(),
		"used_gear": _used_gear.keys(),
		"reservation": _reservation.duplicate(true),
		"scholarships": _scholarships.duplicate(true)
	}


func to_data() -> Dictionary:
	if not pricing_context_valid() or not _bank.completion_closed():
		return {}
	var data: Dictionary = {
		"version": _format,
		"seed": _seed,
		"roster": _initial_roster.duplicate(),
		"catalog":
		_signature(_format, _league_rules if not _league_rules.is_empty() else null, _legacy_gap_name),
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
	if _format >= 25:
		data["transfer_start"] = _transfer_start
	if _format >= 26:
		data["supply_start"] = _supply_start
	if _format >= 27:
		data["checkout_start"] = _checkout_start
	if _format >= 28:
		data["association_start"] = _association_start
	if _format >= 29:
		data["freezer_start"] = _freezer_start
	if _format >= 30:
		data["sides_start"] = _sides_start
	if _format >= 36:
		data["ability_from"] = _abilities.from_visit
		data["ability_start"] = _abilities.start
	if _format >= 37:
		data["major_start"] = _major.start
	if _format >= 38:
		data["retraining_enabled"] = _retraining_enabled
	if _format >= 40:
		data["alley_from"] = _gear_progress.alley_from
	if _format >= 35:
		data["copy_start"] = _copy.start
	if _format >= 34:
		data["field_start"] = _field_start
	if _format >= 33:
		data["sure_start"] = _sure_start
	if _format >= 31:
		data["jump_start"] = _jump_start
	if _format >= 32:
		data["batch_start"] = _batch_start.duplicate() if _batch_start != null else null
	if _format in [D1_VERSION, D3_VERSION, D4_VERSION, LEAGUE_TIER_VERSION]:
		data["pricing_rule"] = _pricing_rule
	if _format in [D3_VERSION, D4_VERSION, LEAGUE_TIER_VERSION]:
		data["sponsor_rule"] = _sponsor_rule
	if _format in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		data["league_rules"] = _league_rules.duplicate(true)
		if LeagueRules.dynasty(_league_rules):
			data["dynasty_start"] = _dynasty_start.duplicate(true)
	if pitch_catalog_expanded():
		var helper: Script = load("res://src/gameplay/season/season_build_context.gd")
		return helper.call("_wrap_v6_owner", self, data) as Dictionary
	return WorkingPitchProgression.wrap_build(data, _book._exotic_start) if pitch_catalog_current() else data


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
	_league_rules = next._league_rules.duplicate(true)
	_dynasty_start = next._dynasty_start
	_pricing_rule = next._pricing_rule
	_sponsor_rule = next._sponsor_rule
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
	_transfer_start = next._transfer_start
	_transfer_earned = next._transfer_earned
	_checkout_start = next._checkout_start
	_checkout_earned = next._checkout_earned
	_association_start = next._association_start
	_freezer_start = next._freezer_start
	_sides_start = next._sides_start
	_major = next._major
	_abilities = next._abilities
	_copy = next._copy
	_field_start = next._field_start
	_field_outs = next._field_outs
	_sure_start = next._sure_start
	_sure_earned = next._sure_earned
	_jump_start = next._jump_start
	_batch_start = next._batch_start
	_batch_used = next._batch_used.duplicate()
	_association_earned = next._association_earned
	_freezer_earned = next._freezer_earned
	_sides_earned = next._sides_earned
	_jump_earned = next._jump_earned
	_supply_start = next._supply_start
	_supply_used = next._supply_used
	_insurance = next._insurance
	_reservation = next._reservation
	_income_by_game = next._income_by_game
	_pregames = next._pregames
	_match_inventory = next._match_inventory
	_scouts = next._scouts
	_appeared = next._appeared
	return {"ok": true, "replayed": replayed}


func candidate(command: Dictionary) -> SeasonBuild:
	last_error = ""
	if not pricing_context_valid() or not _bank.completion_closed():
		last_error = "Invalid immutable reroll pricing context."
		return null
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
	if LeagueRules.earnings(_league_rules) and normalized.get("op") == "reward":
		for score: String in ["own_runs", "opponent_runs"]:
			if SeasonOwnership._whole(normalized.get(score), 0, 9999):
				normalized[score] = int(normalized[score])
	if (
		normalized.get("op") == SeasonInventoryRules.CLOSE_OP
		and normalized.get("attempt") is Dictionary
	):
		for field: String in ["game", "rev"]:
			if SeasonOwnership._whole(normalized.attempt.get(field), 0, MAX_EVENTS):
				normalized.attempt[field] = int(normalized.attempt[field])
	var serialized: String = JSON.stringify(normalized)
	if (
		(normalized.get("op") == "exotic_admit" and (pitch_catalog_current() or pitch_catalog_expanded()))
		or (LeagueRules.doubleheader(_league_rules) and normalized.get("op") == "reward")
		or (
			SeasonInventoryResale.enabled(_bank)
			and (
				(
					normalized.get("op")
					in ["match_sell", "match_supply_sell", SeasonInventoryRules.CLOSE_OP]
				)
				or (normalized.get("op") == "reward" and normalized.has("inventory_final"))
			)
		)
	):
		# New workload proofs retain float precision while normalizing integral JSON values.
		serialized = JSON.stringify(
			JSON.parse_string(JSON.stringify(normalized, "", true, true)), "", true, true
		)
	if _requests.has(normalized.id):
		if _requests[normalized.id] == serialized:
			return _fork()
		last_error = "This transaction ID was already used for another action."
		return null
	if normalized.rev != revision() or revision() >= MAX_EVENTS:
		last_error = "The build changed. Review a fresh purchase."
		return null
	var next: SeasonBuild = _fork()
	last_error = next._major.apply(next, normalized)
	if not last_error.is_empty():
		return null
	if _order_start != null and normalized.op == "reroll" and next.cash() < cash():
		next._paid_rerolls += 1
	SeasonRaincheck.after(self, next, normalized)
	if next._transfer_start != null and SeasonTransfer.learners(next) >= 2:
		next._transfer_earned = true
	SeasonAssociation.earn(next, normalized)
	SeasonCarbonCopy.earn(next, normalized)
	SeasonLegends.prune(next)
	if not next._bank.completion_closed():
		last_error = "Incomplete completed-game sponsor settlement."
		return null
	next._events.append(normalized)
	next._requests[normalized.id] = serialized
	return next


func _fork() -> SeasonBuild:
	var result: SeasonBuild = SeasonBuild.new(_seed, _initial_roster, _pool, _blocked, true)
	result._roster = _roster.duplicate()
	result._contracts = _contracts.duplicate(true)
	result._recruits = _recruits.duplicate(true)
	result._game_rosters = _game_rosters.duplicate(true)
	result._appeared = _appeared
	result._format = _format
	result._legacy_gap_name = _legacy_gap_name
	result._market = _market
	result._league_rules = _league_rules.duplicate(true)
	result._dynasty_start = _dynasty_start
	result._pricing_rule = _pricing_rule
	result._sponsor_rule = _sponsor_rule
	result._retraining_enabled = _retraining_enabled
	result._gear_progress = _gear_progress.fork()
	result._sponsor_progress = _sponsor_progress.fork()
	result._legends = _legends.duplicate(true)
	result._order_start = _order_start
	result._paid_rerolls = _paid_rerolls
	result._rain_start = _rain_start
	result._rain_earned = _rain_earned
	result._transfer_start = _transfer_start
	result._transfer_earned = _transfer_earned
	result._checkout_start = _checkout_start
	result._checkout_earned = _checkout_earned
	result._association_start = _association_start
	result._freezer_start = _freezer_start
	result._sides_start = _sides_start
	result._major = _major.fork()
	result._abilities = _abilities.fork()
	result._copy = _copy.fork()
	result._field_start = _field_start
	result._field_outs = _field_outs
	result._sure_start = _sure_start
	result._sure_earned = _sure_earned
	result._jump_start = _jump_start
	result._batch_start = _batch_start.duplicate() if _batch_start != null else null
	result._batch_used = _batch_used.duplicate()
	result._association_earned = _association_earned
	result._freezer_earned = _freezer_earned
	result._sides_earned = _sides_earned
	result._jump_earned = _jump_earned
	result._supply_start = _supply_start
	result._supply_used = _supply_used
	result._insurance = _insurance.duplicate(true)
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
	if op == SeasonInventoryResale.ENABLE_OP:
		return SeasonInventoryRules.build_enable(self, command)
	if op == SeasonInventoryRules.CLOSE_OP:
		return SeasonInventoryRules.close_attempt(self, command)
	if op == "inventory_sell":
		return SeasonInventoryRules.sell(self, command)
	if op in ["match_inventory", "match_sell", "match_supply_sell"]:
		return SeasonMatchInventory.commit(self, command)
	if op == "copy_select":
		return SeasonCarbonCopy.commit(self, command)
	if op == "insure":
		return SeasonSecondChance.commit(self, command)
	if op == "scout":
		return SeasonFilmRoom.commit(self, command)
	if op == "pregame":
		return SeasonBudgetBites.commit(self, command)
	if op == "exotic_admit":
		return ExpandedExoticAccess.settle(self, command) if pitch_catalog_expanded() else WorkingExoticAccess.settle(self, command)
	if op == "reward":
		return SeasonBuildReward.settle(self, command)
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
				if _market != 0
				else DevelopmentShopCatalog.pack(_book, _roster, _rng(-1))
			),
			"pack_status": "sealed"
		}
		SeasonRaincheck.deliver(self)
		if union_earned:
			_visit["union_credit"] = 3
		if (
			_market == 0
			and _format >= 2
			and _visit.number >= _recruit_from
			and not LeagueRules.dynasty(_league_rules)
		):
			_visit["recruit"] = _recruit_offer()
		return ""
	if not _visit.open:
		return "Open the current postgame shop first."
	match op:
		"transfer_pitch":
			return SeasonTransfer.commit(self, command)
		"reserve_offer", "release_reservation":
			return SeasonRaincheck.commit(self, command)
		"focused_reroll":
			return SeasonSpecialOrder.commit(self, command)
		"tactical_exchange":
			return SeasonTacticalExchange.exchange(self, command)
		"major_assign":
			return "" if _format >= 37 and _keys(command, []) else "Invalid Double Major choice."
		"ability_buy":
			return _abilities.buy(self, command)
		"retrain_buy":
			return SeasonRetraining.buy(self, command)
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
			return SeasonSponsorPurchase.commit(self, command)
		"spare_buy", "spare_swap":
			return SeasonEquipment.commit(self, command)
		"equip", "sell_gear":
			return _gear_transaction(command)
		"sign":
			if LeagueRules.dynasty(_league_rules):
				return "Dynasty replacement is not available in this closed bridge."
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
			var error: String = _charge(reroll_price())
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
			var paid: int = pack_price()
			var error: String = _charge(paid)
			if not error.is_empty():
				return error
			if _format >= 11:
				_visit["union_credit"] = 0
			_visit.pack_status = "open"
			_visit.cards = _pack_choices()
			if LeagueRules.academy(_league_rules):
				_visit["pack_paid"] = paid
				_visit["pack_picked"] = []
		"pack_pick":
			if not _keys(command, ["item", "player", "pitch", "replace"]) or not pack_pending():
				return "No revealed pack choice is pending."
			if not command.item is String or not _visit.cards.has(command.item):
				return "Choose one revealed card."
			if LeagueRules.academy(_league_rules) and not _pack_choices().has(command.item):
				return "Choose a distinct remaining eligible card from this fixed reveal."
			var error: String = _develop(command.item, command)
			if not error.is_empty():
				return error
			if LeagueRules.academy(_league_rules):
				_visit.pack_picked.append(command.item)
				if _visit.pack_picked.size() >= 2 or _pack_choices().is_empty():
					_visit.pack_status = "used"
			else:
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
	var item: Dictionary = shop_item(item_id)
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
	return SeasonBuildShop.offers(self, rerolls)


func _pack_choices() -> Array:
	var result: Array = []
	for item_id: String in _visit.get("cards", []):
		if LeagueRules.academy(_league_rules) and _visit.get("pack_picked", []).has(item_id):
			continue
		if not targets(item_id).is_empty():
			result.append(item_id)
	return result


func _rng(roll: int) -> RandomNumberGenerator:
	var result: RandomNumberGenerator = RandomNumberGenerator.new()
	result.seed = _seed * 1009 + int(_visit.number) * 104729 + roll * 7919
	return result


static func _keys(command: Dictionary, extra: Array) -> bool:
	return SeasonOwnership._keys(command, ["id", "rev", "op"] + extra)


static func _signature(
	format_version: int = VERSION, rules: Variant = null, legacy_gap_name: bool = false
) -> String:
	var base: String = SeasonPlayerCatalog.signature() + ":" + DevelopmentShopCatalog.signature()
	if format_version in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		var profile: String = LeagueRules.PROFILE
		if rules != null:
			var normalized: Dictionary = LeagueRules.normalized(rules)
			if normalized.is_empty():
				return ""
			if format_version == LEAGUE_VERSION and int(normalized.tier) != 0:
				return ""
			profile = normalized.profile
		if format_version == LEAGUE_TIER_VERSION:
			if _LEAGUE_TIER_ECONOMY.tier(rules) < 1:
				return ""
			profile += ":" + _LEAGUE_TIER_ECONOMY.PROFILE + ":" \
				+ JSON.stringify(LeagueRules.normalized(rules), "", true, true).sha256_text()
		base += ":" + profile
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
	if format_version >= 25:
		base += ":" + JSON.stringify(SeasonTransfer.ITEMS).sha256_text()
	if format_version >= 26:
		base += ":" + JSON.stringify(SeasonSecondChance.ITEMS).sha256_text()
	if format_version >= 27:
		base += ":" + JSON.stringify(SeasonLateCheckout.ITEMS).sha256_text()
	if format_version >= 28:
		base += ":" + JSON.stringify(SeasonAssociation.ITEMS).sha256_text()
	if format_version >= 29:
		base += ":" + JSON.stringify(SeasonFreezers.ITEMS).sha256_text()
	if format_version >= 30:
		base += ":" + JSON.stringify(SeasonLeftRight.ITEMS).sha256_text()
	if format_version >= 31:
		base += ":" + JSON.stringify(SeasonJumpstart.ITEMS).sha256_text()
	if format_version >= 32:
		base += ":" + JSON.stringify(SeasonSmallBatch.ITEMS).sha256_text()
	if format_version >= 33:
		base += ":" + JSON.stringify(SeasonSureShot.ITEMS).sha256_text()
	if format_version >= 34:
		base += ":" + JSON.stringify(SeasonFieldSupply.ITEMS).sha256_text()
	if format_version >= 35:
		base += ":" + JSON.stringify(SeasonCarbonCopy.ITEMS).sha256_text()
	if format_version >= 36:
		base += ":" + JSON.stringify(SeasonAbilities.ITEMS).sha256_text()
	if format_version >= 37:
		base += ":" + JSON.stringify(SeasonDoubleMajor.ITEMS).sha256_text()
	if format_version >= 38:
		base += ":" + JSON.stringify(SeasonRetraining.ITEM).sha256_text()
	if format_version >= 40:
		var alley: Dictionary = SeasonAlleyGear.ITEMS
		if format_version == 40 or legacy_gap_name:
			# Build40 stays canonical; newer old-name journals retain exact provenance.
			alley = alley.duplicate(true)
			alley[SeasonAlleyGear.GAP].name = "Gap Driver"
		base += ":" + JSON.stringify(alley).sha256_text()
	if format_version >= 41:
		base += ":" + JSON.stringify(SeasonFrozenRope.ITEMS).sha256_text()
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
		var profile: Dictionary = player(id) if returning else _book.recruit_profile(id, stage)
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
		if (
			SeasonEquipment.is_spare(self, command.receipt)
			and not SeasonEquipment.between_games(self)
		):
			return "Inactive spare sales are between games only."
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
	if (
		_bank.view().gear[item.slot].get("item", "") == item_id
		or (LeagueRules.equipment(_league_rules) and SeasonEquipment.owns(_bank.view(), item_id))
	):
		return (
			"That exact Gear is already owned."
			if LeagueRules.equipment(_league_rules)
			else "That exact Gear is already equipped."
		)
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


func _sponsor_catalog_version() -> int:
	return SeasonSponsorCatalog.for_visit(self)


func _tactical_catalog_version() -> int:
	return 2 if _format >= 15 and _visit.number >= _expanded_tactical_from else 1


func migrate() -> void:
	if _format in [LEAGUE_VERSION, LEAGUE_TIER_VERSION]:
		return  # Closed profiles cannot migrate into legacy Standard.
	# Legacy migration only knows versions41/42; current D3/D4 journals are complete.
	if d3_sponsors_valid() or d4_sponsors_valid():
		return
	SeasonBuildMigration.apply(self)

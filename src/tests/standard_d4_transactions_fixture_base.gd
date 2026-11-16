extends Node
## Focused authored fixtures; no physical games, earned unlocks or public seed search.
const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]
const RULE: String = "standard-d4-short-term-v1"
const D3: String = "standard-d3-nonrefundable-v1"
const SHORT: Dictionary = {
	"A07": "visit:6:roll:2:0",
	"B02": "visit:6:roll:0:0",
	"B03": "visit:6:roll:4:0",
	"F01": "visit:6:roll:11:0",
	"F03": "visit:6:roll:24:0"
}
const FLEXIBLE: Dictionary = {
	"A07": "visit:6:roll:0:0",
	"B02": "visit:6:roll:3:0",
	"B03": "visit:6:roll:0:0",
	"F01": "visit:6:roll:2:0",
	"F03": "visit:6:roll:0:0"
}
const NONREFUND: Dictionary = {
	"A07": "visit:6:roll:3:0",
	"B02": "visit:6:roll:1:0",
	"B03": "visit:6:roll:2:0",
	"F01": "visit:6:roll:0:0",
	"F03": "visit:6:roll:9:0"
}
const DIGESTS: Dictionary = {
	"A07": "06b0424812cff45807f3b1d865cb4b395f218ff5428b9012e15b3020adf827c3",
	"B02": "29f47e3350724a872825270c091f427cec70e142c7cf4a03361b1415555a2c87",
	"B03": "0ea22a43e36d78cf866547fc362e76d45293fbc311bb7b713ba4580d5d19ac5f",
	"F01": "2b9f8aad3c418b7dac27653758562eaf0a50f3ffa8868e1c7cdc38b75bb843b3",
	"F03": "1784e7f9e8d4ebd19c33c51011f31a632ff6c4da6cecec55242155360f6db03b"
}
var _checks: int = 0
var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("D4_TRANSACTION_FAIL " + label)


func _command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"id": "d4-build:%d" % build.revision(), "rev": build.revision(), "op": op
	}
	result.merge(fields)
	return result


func _build(market: int = 0) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	build._market = market
	_check(build.enable_d4_sponsors(), "fresh Build44 context")
	for game in range(6):
		_check(
			build.commit(_command(build, "reward", {"game": game, "win": true})).ok,
			"authored six-game funding"
		)
	_check(build.commit(_command(build, "open")).ok, "open funded fixture shop")
	return build


func _performance() -> Dictionary:
	var result: Dictionary = {}
	for player_id: String in ROSTER:
		result[player_id] = MatchPerformance.empty_line()
	return result


func _receipt(build: SeasonBuild, item: String) -> Dictionary:
	return SeasonSchoolSponsors.active(build, item)


func _ai_expiry() -> void:
	var ai: SeasonBuild = _build(12)
	var human: SeasonBuild = _build()
	ai._visit.offers = {SHORT.F03: "F03"}
	human._visit.offers = {SHORT.F03: "F03"}
	var club: Dictionary = {
		"profile": "Distributed", "decisions": [], "roles": {"pitcher": ROSTER[0]}
	}
	var cash: int = ai.cash()
	_check(
		SeasonOpponentSponsors.purchase(ai, club, 6),
		"unchanged policy13 buys eligible short-term sponsor"
	)
	_check(
		human.commit(_command(human, "sponsor_buy", {"offer": SHORT.F03, "replace": ""})).ok,
		"human buys same original offer"
	)
	_check(
		(
			ai.cash() == cash - 10
			and human.cash() == ai.cash()
			and _receipt(ai, "F03").get("terms") == _receipt(human, "F03").get("terms")
		),
		"AI and human actual wallets and terms equal"
	)
	_check(
		(
			club.decisions.size() == 1
			and club.decisions[0].paid == 10
			and club.decisions[0].reason == "qualified team sponsor"
		),
		"policy13 decision identity unchanged"
	)
	for game in [6, 7]:
		cash = ai.cash()
		_check(
			(
				(
					ai
					. commit(
						_command(
							ai,
							"reward",
							{"game": game, "win": false, "performance": _performance()}
						)
					)
					. ok
				)
				and ai.cash() == cash + 12
			),
			"AI shared terminal settlement no refund"
		)
		_check(
			(
				_receipt(ai, "F03").get("games_remaining", 0) == (1 if game == 6 else 0)
				and _receipt(human, "F03").get("games_remaining") == 2
			),
			"only owning club games consume duration"
		)
	_check(ai.commit(_command(ai, "open")).ok, "AI next ordinary shop")
	ai._visit.offers = {SHORT.F03: "F03"}
	_check(
		(
			SeasonOpponentSponsors.purchase(ai, club, 8)
			and _receipt(ai, "F03").get("games_remaining") == 2
		),
		"unchanged AI policy can reacquire expired identity"
	)
func _request(bank: SeasonOwnership, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"id": "d4-bank:%d" % bank.revision(), "rev": bank.revision(), "op": op
	}
	result.merge(fields)
	return result


func _bank() -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	_check(bank.enable_sponsor_terms(RULE, 112), "fresh Ownership3 header")
	for game in range(2):
		_check(
			bank.commit(_request(bank, "reward", {"game": game, "win": true})).ok,
			"authored bank funding"
		)
		_check(
			bank.commit(_request(bank, "sponsor_game_end", {"game": game})).ok,
			"funding has terminal close even with no sponsor"
		)
	return bank


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _same(a: Variant, b: Variant) -> bool:
	return ClubCareer.same(a, b)


func _bank_expiry(item: String) -> void:
	var bank: SeasonOwnership = _bank()
	_check(
		bank.commit(_request(bank, "stock", {"offers": {"quote": item}})).ok,
		"controlled offer stock"
	)
	var fields: Dictionary = {
		"offer": "quote", "replace": "", "discard": [], "source_offer": SHORT[item]
	}
	var purchase: Dictionary = _request(bank, "buy", fields)
	var before: Dictionary = bank.to_data().duplicate(true)
	_check(bank.preview(purchase).ok and bank.to_data() == before, "preview cannot age or buy")
	_check(bank.commit(purchase).ok and bank.commit(purchase).replayed, "one acquisition")
	var active: Dictionary = bank.view().sponsors[0] if not bank.view().sponsors.is_empty() else {}
	_check(
		(
			active.get("games_remaining") == 2
			and active.get("terms") == {"rule": RULE, "source_offer": SHORT[item], "duration": 2}
		),
		"bank derives immutable terms and initial count"
	)
	if active.is_empty():
		return
	_check(
		(
			SeasonSponsorCatalog.receipt_label(active).contains("2 club games remaining")
			and SeasonSponsorCatalog.resale(active) == int(active.paid / 2)
		),
		"visible actual-paid early refund"
	)
	for game in [2, 3]:
		var paid: Dictionary = _request(bank, "reward", {"game": game, "win": false})
		var previous: int = int(bank.view().sponsors[0].games_remaining)
		_check(
			(
				bank.commit(paid).ok
				and bank.commit(paid).replayed
				and bank.view().sponsors[0].games_remaining == previous
			),
			"reward entry and retry preserve final-game effect"
		)
		var raw: Dictionary = {
			"version": 3,
			"catalog": JSON.stringify(bank._catalog).sha256_text(),
			"events": bank._events.duplicate(true),
			"sponsor_rule": RULE,
			"term_seed": 112
		}
		_check(
			(
				bank.to_data().is_empty()
				and SeasonOwnership.from_data(_json(raw), bank._catalog) == null
			),
			"unfinished paid journal rejected"
		)
		var pending: Dictionary = bank.view().duplicate(true)
		_check(
			(
				not bank.commit(_request(bank, "reward", {"game": game + 10, "win": true})).ok
				and bank.view() == pending
			),
			"cannot open second reward before closure"
		)
		_check(
			(
				not bank.commit(_request(bank, "sell", {"receipt": active.id, "discard": []})).ok
				and bank.view() == pending
			),
			"cannot remove covered receipt during settlement"
		)
		_check(
			(
				not bank.commit(_request(bank, "sponsor_game_end", {"game": game + 1})).ok
				and bank.view() == pending
			),
			"wrong game closure rejected atomically"
		)
		_check(
			bank.commit(_request(bank, "sponsor_income", {"amount": 1})).ok,
			"existing internal income allowed while pending"
		)
		var cash: int = bank.cash()
		var close: Dictionary = _request(bank, "sponsor_game_end", {"game": game})
		_check(
			bank.preview(close).ok and bank.cash() == cash and not bank.completion_closed(),
			"close preview has no tick"
		)
		_check(
			bank.commit(close).ok and bank.cash() == cash and bank.completion_closed(),
			"one completed owner game ticks for zero Cash"
		)
		_check(
			bank.commit(close).replayed and bank.cash() == cash,
			"exact end retry cannot tick or credit twice"
		)
		_check(
			not bank.commit(_request(bank, "sponsor_game_end", {"game": game})).ok,
			"new identity duplicate end rejected"
		)
		_check(
			(
				bank.view().sponsors.size() == (1 if game == 2 else 0)
				and (game != 2 or bank.view().sponsors[0].games_remaining == 1)
			),
			"two completed games release slot"
		)
		var restored: SeasonOwnership = SeasonOwnership.from_data(
			_json(bank.to_data()), bank._catalog
		)
		_check(
			restored != null and _same(restored.view(), bank.view()),
			"closed bank count reconstructed from events"
		)
	_check(
		bank.cash() == 62 - int(active.paid) and bank.view().capacity.sponsors == 5,
		"expiry never refunds and capacity unchanged"
	)


func _bank_refusals() -> void:
	var bank: SeasonOwnership = _bank()
	_check(
		not bank.commit(_request(bank, "sponsor_game_end", {"game": 9})).ok,
		"unpaid closure rejected"
	)
	_check(
		bank.commit(_request(bank, "stock", {"offers": {"quote": "A07"}})).ok, "negative test stock"
	)
	var valid: Dictionary = {
		"offer": "quote", "replace": "", "discard": [], "source_offer": SHORT.A07
	}
	for kind: String in ["missing", "alias", "terms", "remaining", "refund"]:
		var fields: Dictionary = valid.duplicate(true)
		if kind == "missing":
			fields.erase("source_offer")
		if kind == "alias":
			fields.source_offer = "rain:7:" + SHORT.A07
		if kind == "terms":
			fields.terms = {"rule": RULE, "source_offer": SHORT.A07, "duration": 2}
		if kind == "remaining":
			fields.games_remaining = 99
		if kind == "refund":
			fields.refund = 7
		var before: Dictionary = bank.to_data().duplicate(true)
		_check(
			not bank.commit(_request(bank, "buy", fields)).ok and bank.to_data() == before,
			"reject caller receipt/term override " + kind
		)
	_check(bank.commit(_request(bank, "buy", valid)).ok, "valid buy after refusals")
	_check(
		bank.commit(_request(bank, "reward", {"game": 2, "win": true})).ok,
		"open refusal fixture reward"
	)
	for kind: String in ["remaining", "expired", "refund", "fractional", "bool", "unknown"]:
		var fields: Dictionary = {"game": 2}
		if kind == "remaining":
			fields.games_remaining = 0
		if kind == "expired":
			fields.receipts = ["anything"]
		if kind == "refund":
			fields.refund = 7
		if kind == "fractional":
			fields.game = 2.5
		if kind == "bool":
			fields.game = true
		if kind == "unknown":
			fields.rule = "wrong"
		var before: Dictionary = bank.view().duplicate(true)
		_check(
			(
				not bank.commit(_request(bank, "sponsor_game_end", fields)).ok
				and bank.view() == before
			),
			"strict internal end shape " + kind
		)
	_check(
		bank.commit(_request(bank, "sponsor_game_end", {"game": 2})).ok,
		"valid close after refusals"
	)
	var original: Dictionary = bank.to_data().duplicate(true)
	for kind: String in [
		"version", "rule", "duration", "count", "stripped", "unclosed", "duplicate", "extra"
	]:
		var changed: Dictionary = original.duplicate(true)
		if kind == "version":
			changed.version = 2
		if kind == "rule":
			changed.sponsor_rule = D3
		if kind == "duration":
			changed.events[5].terms = {"rule": RULE, "duration": 1}
		if kind == "count":
			changed.events[5].games_remaining = 1
		if kind == "stripped":
			changed.events[5].erase("source_offer")
		if kind == "unclosed":
			changed.events.pop_back()
		if kind == "duplicate":
			changed.events.append(changed.events.back().duplicate(true))
		if kind == "extra":
			changed.sponsor_pending = {}
		_check(
			SeasonOwnership.from_data(_json(changed), bank._catalog) == null,
			"strict cold journal refusal " + kind
		)


func _context_and_legacy() -> void:
	for value: Variant in [true, -1, 2147483648, 0.5, INF, NAN]:
		var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
		var before: Dictionary = bank.to_data().duplicate(true)
		_check(
			not bank.enable_sponsor_terms(RULE, value) and bank.to_data() == before,
			"invalid seed cannot mutate context"
		)
	for version in [1, 2, 3]:
		var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
		if version > 1:
			_check(
				bank.enable_sponsor_terms(D3 if version == 2 else RULE, 112),
				"version-specific empty bank header"
			)
		var request: Dictionary = _request(bank, "reward", {"game": 0, "win": true})
		_check(
			bank.commit(request).ok and bank.commit(request).replayed,
			"reward retry exact in each generation"
		)
		if version == 3:
			_check(
				bank.to_data().is_empty() and bank.fork().view() == bank.view(),
				"pending serialization refused but private fork readable"
			)
			_check(
				bank.commit(_request(bank, "sponsor_game_end", {"game": 0})).ok,
				"D4 closes authored reward"
			)
		else:
			_check(
				not bank.commit(_request(bank, "sponsor_game_end", {"game": 0})).ok,
				"legacy cannot receive new end command"
			)
		var data: Dictionary = bank.to_data()
		_check(
			(
				data.version == version
				and bank.cash() == 18
				and data.events.size() == (2 if version == 3 else 1)
			),
			"legacy reward cash and journal remain exact"
		)
		var restored: SeasonOwnership = SeasonOwnership.from_data(_json(data), bank._catalog)
		_check(
			(
				restored != null
				and _same(restored.to_data(), data)
				and _same(restored.view(), bank.view())
			),
			"bank generation exact cold replay"
		)
	for mode in [0, 1, 3, 4]:
		var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
		var installed: bool = true
		if mode == 1:
			installed = build.enable_d1_pricing()
		if mode == 3:
			installed = build.enable_d3_sponsors()
		if mode == 4:
			installed = build.enable_d4_sponsors()
		_check(
			installed and build._format == {0: 41, 1: 42, 3: 43, 4: 44}[mode],
			"exact Build generation"
		)
		_check(
			build.d3_sponsors_valid() == (mode == 3) and build.d4_sponsors_valid() == (mode == 4),
			"D3 and D4 exact predicates"
		)
		_check(
			(
				build.commit(_command(build, "reward", {"game": 0, "win": false})).ok
				and build.cash() == 12
			),
			"unchanged first reward"
		)
		var before: Dictionary = build.to_data().duplicate(true)
		_check(
			not build.enable_d4_sponsors() and build.to_data() == before,
			"late D4 installation refused atomically"
		)


func _generated_expiry() -> void:
	# Approved bounded unit-only lookup: first eligible seed in 0..63, six
	# authored funding rewards; zero physical games and no stock overrides.
	var selected: SeasonBuild
	var offer: String = ""
	var item: String = ""
	for candidate_seed in range(64):
		var candidate: SeasonBuild = SeasonBuild.new(candidate_seed, ROSTER)
		if not candidate.enable_d4_sponsors():
			break
		var valid: bool = true
		for game in range(6):
			valid = (
				candidate.commit(_command(candidate, "reward", {"game": game, "win": true})).ok
				and valid
			)
		if not valid or not candidate.commit(_command(candidate, "open")).ok:
			break
		for key: String in candidate._visit.offers:
			var identity: String = candidate._visit.offers[key]
			if (
				SeasonSponsorCatalog.offer_terms(RULE, candidate_seed, key, identity).get("rule")
				== RULE
			):
				selected = candidate
				offer = key
				item = identity
				break
		if selected != null:
			break
	_check(selected != null, "first generated short-term offer in approved finite unit lookup")
	if selected == null:
		return
	print(
		(
			"D4_UNIT_GENERATED seed=%d offer=%s item=%s funding_rewards=6 physical_games=0"
			% [selected._seed, offer, item]
		)
	)
	var request: Dictionary = _command(selected, "sponsor_buy", {"offer": offer, "replace": ""})
	var before: Dictionary = selected.to_data().duplicate(true)
	_check(
		selected.preview(request).ok and selected.to_data() == before,
		"generated short-term purchase preview exact"
	)
	_check(
		selected.commit(request).ok and _receipt(selected, item).get("games_remaining") == 2,
		"generated short-term acquisition has full duration"
	)
	for game in [6, 7]:
		_check(
			selected.definition(ROSTER[0]).season_sponsors.has(item),
			"real generated receipt effect covers final game"
		)
		var cash: int = selected.cash()
		_check(
			(
				(
					selected
					. commit(
						_command(
							selected,
							"reward",
							{"game": game, "win": true, "performance": _performance()}
						)
					)
					. ok
				)
				and selected.cash() == cash + 18
			),
			"generated two-game expiry has no refund"
		)
	var data: Dictionary = selected.to_data().duplicate(true)
	var restored: SeasonBuild = SeasonBuild.from_data(_json(data), selected._seed, ROSTER)
	_check(
		(
			restored != null
			and _same(restored.to_data(), data)
			and _same(restored._bank.to_data(), selected._bank.to_data())
		),
		"complete generated expiry journal cold replay"
	)
	_check(
		(
			restored != null
			and _receipt(restored, item).is_empty()
			and not restored.definition(ROSTER[0]).season_sponsors.has(item)
		),
		"cold next-game effects remove expired sponsor"
	)
	for game in [6, 7]:
		var historical: SeasonBuild = SeasonBuildRestore.restore(
			_json(data), selected._seed, ROSTER, [], [], game
		)
		_check(
			(
				historical != null
				and _receipt(historical, item).get("games_remaining") == 8 - game
				and historical.definition(ROSTER[0]).season_sponsors.has(item)
				and not historical._bank.view().rewards.has(str(game))
			),
			"historical covered report retains pre-expiry receipt and effect"
		)
	_check(
		(
			ClubPlayerProgress._sponsor_counts(selected).get(6) == 1
			and ClubPlayerProgress._sponsor_counts(selected).get(7) == 1
		),
		"both covered generated games retain sponsor count"
	)
	var bad: Dictionary = data.duplicate(true)
	bad.events[7].offer = "visit:99:roll:99:0"
	_check(
		SeasonBuild.from_data(_json(bad), selected._seed, ROSTER) == null,
		"cold replay rejects substituted generated offer"
	)


func _generation_replay() -> void:
	for market in [0, 12]:
		var build: SeasonBuild = _build(market)
		var legacy: SeasonBuild = SeasonBuild.new(112, ROSTER)
		legacy._market = market
		_check(legacy.enable_d3_sponsors(), "parallel exact D3 generator context")
		for game in range(6):
			_check(
				legacy.commit(_command(legacy, "reward", {"game": game, "win": true})).ok,
				"parallel D3 fixture reward"
			)
		_check(legacy.commit(_command(legacy, "open")).ok, "parallel D3 shop")
		_check(
			(
				build._visit.offers == legacy._visit.offers
				and build._visit.cards == legacy._visit.cards
				and build.cash() == legacy.cash()
			),
			"human and AI generator and wallets unchanged"
		)
		for roll in range(4):
			_check(build._offers(roll) == legacy._offers(roll), "D4 does not perturb generator RNG")
		var data: Dictionary = build.to_data().duplicate(true)
		var restored: SeasonBuild = SeasonBuild.from_data(_json(data), 112, ROSTER)
		_check(
			(
				restored != null
				and restored.d4_sponsors_valid()
				and _same(restored.to_data(), data)
				and _same(restored._bank.to_data(), build._bank.to_data())
			),
			"Build44 genuine generated journal cold replay"
		)
		if restored != null:
			restored.migrate()
		_check(
			restored != null and _same(restored.to_data(), data) and restored._format == 44,
			"D4 migration preserves immutable rules"
		)
		var historical: SeasonBuild = SeasonBuildRestore.restore(
			_json(data), 112, ROSTER, [], [], 5
		)
		_check(
			(
				historical != null
				and historical.d4_sponsors_valid()
				and not historical._bank.view().rewards.has("5")
				and historical._bank.completion_closed()
			),
			"historical replay stops before requested reward"
		)
		for kind: String in ["version", "rule", "pricing", "extra"]:
			var bad: Dictionary = data.duplicate(true)
			if kind == "version":
				bad.version = 43
			if kind == "rule":
				bad.sponsor_rule = D3
			if kind == "pricing":
				bad.pricing_rule = ""
			if kind == "extra":
				bad.games_remaining = 1
			_check(
				SeasonBuild.from_data(_json(bad), 112, ROSTER) == null,
				"Build44 mixed context rejected " + kind
			)


func _buy(build: SeasonBuild, item: String, offer: String, fields: Dictionary = {}) -> Dictionary:
	build._visit.offers = {offer: item}
	var body: Dictionary = {"offer": offer, "replace": ""}
	body.merge(fields, true)
	return build.commit(_command(build, "sponsor_buy", body))


func _live_removal(grouped: bool) -> void:
	var build: SeasonBuild = _build()
	_check(_buy(build, "A07", SHORT.A07).ok, "short-term live removal setup")
	var owned: Dictionary = _receipt(build, "A07")
	_check(build.commit(_command(build, "match_inventory", {"game": 6})).ok, "capture live attempt")
	var attempt: Dictionary = build._match_inventory.duplicate(true)
	var fields: Dictionary = {"game": 6, "receipt": owned.get("id", "missing"), "first_pitch": null}
	if grouped:
		fields.sales = []
	var cash: int = build.cash()
	_check(
		(
			build.commit(_command(build, "match_sell", fields)).ok
			and build.cash() == cash + 7
			and _receipt(build, "A07").is_empty()
		),
		"legal live early cancellation"
	)
	_check(_same(build._match_inventory.sponsors, attempt.sponsors), "live use snapshot preserved")


func _raincheck() -> void:
	var build: SeasonBuild = _build()
	build._rain_start = true  # Authored access fixture, not an earned unlock.
	_check(_buy(build, "G01", "unit:raincheck").ok, "controlled Raincheck sponsor")
	build._visit.offers = {SHORT.A07: "A07"}
	_check(
		build.commit(_command(build, "reserve_offer", {"offer": SHORT.A07})).ok,
		"reserve original short-term offer"
	)
	_check(
		(
			(
				build
				. commit(
					_command(
						build, "reward", {"game": 6, "win": true, "performance": _performance()}
					)
				)
				. ok
			)
			and build.commit(_command(build, "open")).ok
		),
		"deliver next visit without aging unowned stock"
	)
	var carried: String = build._visit.get("rain_carried", "")
	_check(carried == "rain:7:" + SHORT.A07, "Raincheck alias retains original source")
	_check(
		(
			build.commit(_command(build, "sponsor_buy", {"offer": carried, "replace": ""})).ok
			and _receipt(build, "A07").get("games_remaining") == 2
			and _receipt(build, "A07").get("terms", {}).get("source_offer") == SHORT.A07
		),
		"carried acquisition starts at full duration"
	)


func _removal(grouped: bool) -> void:
	var build: SeasonBuild = _build()
	var extra: Dictionary = {"sales": []} if grouped else {}
	_check(_buy(build, "A07", SHORT.A07, extra).ok, "direct/grouped short-term purchase")
	var old: Dictionary = _receipt(build, "A07")
	_check(
		(
			old.get("games_remaining") == 2
			and SeasonSponsorCatalog.offer_label(build, SHORT.A07, "A07").contains("next 2")
		),
		"terms visible before and after purchase"
	)
	var cash: int = build.cash()
	extra["replace"] = old.get("id", "missing")
	_check(
		(
			_buy(build, "B02", NONREFUND.B02, extra).ok
			and build.cash() == cash + 7 - 12
			and _receipt(build, "A07").is_empty()
		),
		"early replacement half actual paid"
	)
	old = _receipt(build, "B02")
	cash = build.cash()
	extra["replace"] = old.get("id", "missing")
	_check(
		(
			_buy(build, "F03", FLEXIBLE.F03, extra).ok
			and build.cash() == cash - 10
			and _receipt(build, "B02").is_empty()
		),
		"inherited D3 removal remains zero"
	)
	old = _receipt(build, "F03")
	cash = build.cash()
	var fields: Dictionary = {"receipt": old.get("id", "missing")}
	if grouped:
		fields.sales = []
	_check(
		build.commit(_command(build, "sponsor_sell", fields)).ok and build.cash() == cash + 5,
		"ordinary flexible half unchanged"
	)
	_check(
		_buy(build, "A07", SHORT.A07, {"sales": []} if grouped else {}).ok,
		"fresh stock can reacquire after legal removal"
	)
	_check(build._charge(build.cash() - 1).is_empty(), "controlled insufficient-cash boundary")
	old = _receipt(build, "A07")
	build._visit.offers = {NONREFUND.B02: "B02"}
	var before: Dictionary = build.to_data().duplicate(true)
	var wallet: Dictionary = build._bank.view().duplicate(true)
	fields = {"offer": NONREFUND.B02, "replace": old.get("id", "missing")}
	if grouped:
		fields.sales = []
	_check(
		(
			not build.commit(_command(build, "sponsor_buy", fields)).ok
			and build.to_data() == before
			and build._bank.view() == wallet
		),
		"failed replacement rolls back sale count and cash"
	)


func _selector() -> void:
	_check(
		(
			SeasonSponsorCatalog.D4_RULE == RULE
			and SeasonSponsorCatalog.D4_DURATION == 2
			and SeasonSponsorCatalog.D3_ITEMS == SHORT.keys()
		),
		"exact approved rule duration subset"
	)
	for item: String in SHORT:
		var wanted: Dictionary = {"rule": RULE, "source_offer": SHORT[item], "duration": 2}
		var raw: String = JSON.stringify([RULE, 112, SHORT[item], item], "", true, true)
		_check(raw.sha256_text() == DIGESTS[item], "fixed full-precision D4 hash " + item)
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, SHORT[item], item) == wanted,
			"short-term selection " + item
		)
		_check(
			SeasonSponsorCatalog.offer_terms(D3, 112, SHORT[item], item).is_empty(),
			"short-term was D3 flexible " + item
		)
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, FLEXIBLE[item], item).is_empty(),
			"ordinary flexible preserved " + item
		)
		var prior: Dictionary = {"rule": D3, "source_offer": NONREFUND[item]}
		_check(
			(
				SeasonSponsorCatalog.offer_terms(RULE, 112, NONREFUND[item], item) == prior
				and SeasonSponsorCatalog.offer_terms(D3, 112, NONREFUND[item], item) == prior
			),
			"D3 priority exact " + item
		)
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, "rain:7:" + SHORT[item], item) == wanted,
			"Raincheck selector stable " + item
		)
		_check(
			(
				SeasonSponsorCatalog.terms_valid(wanted)
				and SeasonSponsorCatalog.terms_valid(_json(wanted))
			),
			"strict terms admit parsed whole duration " + item
		)
	for bad: Variant in [
		null,
		{},
		{"rule": RULE, "source_offer": SHORT.A07},
		{"rule": RULE, "source_offer": SHORT.A07, "duration": true},
		{"rule": RULE, "source_offer": SHORT.A07, "duration": 1.5},
		{"rule": RULE, "source_offer": SHORT.A07, "duration": 3},
		{"rule": RULE, "source_offer": SHORT.A07, "duration": 2, "refund": 7},
		{"rule": D3, "source_offer": NONREFUND.A07, "duration": 2}
	]:
		_check(not SeasonSponsorCatalog.terms_valid(bad), "reject malformed or combined term shape")
	for item: String in ["D01", "J02", "J10", "F02", "G01", "E01", "E04"]:
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, SHORT.A07, item).is_empty(),
			"excluded identity unchanged " + item
		)
	seed(1739)
	var expected: int = randi()
	seed(1739)
	SeasonSponsorCatalog.offer_terms(RULE, 112, SHORT.A07, "A07")
	_check(randi() == expected, "D4 classification consumes no global RNG")

extends Node
## Bounded pricing contracts. Controlled operands below are not career-unlock proof.

const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]
const SEED: int = 27
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_quote_matrix()
	_ordinary_and_replay()
	_focused_credit_and_raincheck()
	_failed_transactions()
	_strict_headers()
	_all_five_ai()
	_budget_boundary()
	print("STANDARD_D1_PRICE_RESULT checks=%d failures=%d" % [_checks, _failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("STANDARD_D1_PRICE: " + label)


func _command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "d1-price:%d" % build.revision(),
		"rev": build.revision(), "op": op}
	result.merge(fields)
	return result


func _fresh(d1: bool, market: int = 0) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(SEED, ROSTER)
	build._market = market
	if d1:
		_check(build.enable_d1_pricing(), "fresh D1 pricing admitted")
	return build


func _funded(d1: bool, games: int = 3, market: int = 0) -> SeasonBuild:
	var build: SeasonBuild = _fresh(d1, market)
	for game in range(games):
		_check(build.commit(_command(build, "reward", {
			"game": game, "win": true, "performance": {}})).ok, "bounded reward journal")
	_check(build.commit(_command(build, "open")).ok, "open earned shop")
	return build


func _restore(build: SeasonBuild, data: Dictionary) -> SeasonBuild:
	return SeasonBuild.from_data(data, build._seed, build._initial_roster,
		build._pool, build._blocked)


func _unchanged(build: SeasonBuild, data: Dictionary, view: Dictionary, label: String) -> void:
	_check(build.to_data() == data and build.view() == view, label)


func _quote_matrix() -> void:
	_check(SeasonBuild.VERSION == 41 and SeasonBuild.D1_VERSION == 42,
		"legacy and additive versions are separate")
	_check(SeasonBuild.D1_PRICE_RULE == "standard-d1-reroll-v1", "immutable Working rule identity")
	# Isolated operands exercise credit arithmetic without claiming earned credit.
	for market: int in [0, 12]:
		var base: SeasonBuild = _fresh(false, market)
		var d1: SeasonBuild = _fresh(true, market)
		for rolls: int in [0, 1, 3, 8]:
			for credit: int in [0, 2, 4, 100]:
				base._visit = {"number": 1, "open": true, "rerolls": rolls, "reroll_credit": credit}
				d1._visit = base._visit.duplicate(true)
				var payable: int = maxi(0, 4 + 2 * rolls - credit)
				_check(base.reroll_price() == payable, "Base keeps exact credit/escalation")
				_check(d1.reroll_price() == payable + (1 if payable > 0 else 0),
					"D1 adds one only to positive payable")
				var before: Dictionary = d1.view()
				d1.reroll_price()
				_check(d1.view() == before, "quote is pure")
	for version: int in [1, 9, 10, 19, 41]:
		var legacy: SeasonBuild = _fresh(false)
		legacy._format = version
		legacy._visit = {"number": 1, "open": true, "rerolls": 3, "reroll_credit": 2}
		_check(legacy.reroll_price() == 8 and legacy._pricing_rule.is_empty(),
			"historical build retains its exact quote")
	for market: int in [-1, 1, 11, 13]:
		var invalid: SeasonBuild = _fresh(false, market)
		var data: Dictionary = invalid.to_data()
		var view: Dictionary = invalid.view()
		_check(not invalid.enable_d1_pricing(), "unsupported market cannot enable D1")
		_unchanged(invalid, data, view, "failed enable preserves fresh identity and state")


func _ordinary_and_replay() -> void:
	var base: SeasonBuild = _funded(false)
	var d1: SeasonBuild = _funded(true)
	for roll in range(3):
		_check(base._visit.offers == d1._visit.offers, "D1 does not retune ordinary RNG")
		var command: Dictionary = _command(d1, "reroll")
		var prior: Dictionary = d1.view()
		var quote: int = d1.reroll_price()
		var preview: Dictionary = d1.preview(command)
		_check(preview.ok and preview.after.wallet.cash == d1.cash() - quote,
			"ordinary review uses shared exact charge")
		_check(d1.view() == prior, "ordinary preview leaves wallet and stock unchanged")
		_check(d1.commit(command).ok and d1.cash() == prior.wallet.cash - quote,
			"ordinary commit matches quote")
		_check(base.commit(_command(base, "reroll")).ok,
			"legacy ordinary commit remains available")
		_check(base.cash() - d1.cash() == roll + 1 and d1._visit.rerolls == roll + 1,
			"only one extra Cash per paid reroll; same escalation count")
		var after: Dictionary = d1.view()
		_check(d1.commit(command).replayed and d1.view() == after,
			"identical transaction retry does not double-charge")
	var saved: Dictionary = d1.to_data()
	var restored: SeasonBuild = _restore(d1, saved)
	_check(restored != null, "D1 journal restores")
	if restored == null:
		return
	_check(restored.to_data() == saved and restored.view() == d1.view()
		and restored.reroll_price() == d1.reroll_price(), "rule exists before journal replay")
	var next: Dictionary = _command(d1, "reroll")
	_check(d1.commit(next).ok and restored.commit(next).ok
		and restored.to_data() == d1.to_data() and restored.view() == d1.view(),
		"next post-restore charge and stock are deterministic")
	var old: SeasonBuild = _restore(base, base.to_data())
	_check(old != null and old.view() == base.view() and old.to_data() == base.to_data()
		and not old.to_data().has("pricing_rule"), "Base41 remains exact with no new header")


func _paid_sponsor(build: SeasonBuild, item: String) -> void:
	# Existing ownership transactions isolate sponsor pricing integration. These bank
	# events are intentionally not presented as a replayable SeasonBuild journal.
	var offer: String = "unit-sponsor:" + item
	_check(build._bank.commit({"id": offer + ":stock", "rev": build._bank.revision(),
		"op": "stock", "offers": {offer: item}}).ok, "controlled sponsor stock")
	_check(build._bank.commit({"id": offer + ":buy", "rev": build._bank.revision(),
		"op": "buy", "offer": offer, "replace": "", "discard": []}).ok,
		"controlled sponsor paid through ownership")


func _focused_credit_and_raincheck() -> void:
	for d1: bool in [false, true]:
		var source: SeasonBuild = _funded(d1, 5)
		_paid_sponsor(source, "J01")
		_paid_sponsor(source, "G01")
		var offer: String = ""
		for key: String in source._visit.offers:
			if not SeasonRaincheck.quote(source, source._visit.offers[key]).is_empty():
				offer = key
				break
		_check(not offer.is_empty(), "fixed seed has a generated reservable offer")
		if offer.is_empty():
			continue
		_check(source.commit(_command(source, "reserve_offer", {"offer": offer})).ok,
			"real generated offer reserved")
		_check(source.commit(_command(source, "reward", {
			"game": 5, "win": true, "performance": {}})).ok, "next destination reward")
		_check(source.commit(_command(source, "open")).ok, "deliver real reservation")
		var protected: Dictionary = SeasonRaincheck.protected_offer(source)
		_check(not protected.is_empty(), "Raincheck destination has protected stock")
		for credit: int in [0, 2, 4, 100]:
			for focused: bool in [false, true]:
				var build: SeasonBuild = source._fork()
				build._visit.reroll_credit = credit # Isolated credit operand.
				var prior: Dictionary = build.view()
				var pack: Array = build._visit.cards.duplicate()
				var quote: int = maxi(0, 4 - credit)
				quote += 1 if d1 and quote > 0 else 0
				var op: String = "focused_reroll" if focused else "reroll"
				var fields: Dictionary = {"category": "tactical"} if focused else {}
				var command: Dictionary = _command(build, op, fields)
				var preview: Dictionary = build.preview(command)
				_check(build.reroll_price() == quote and preview.ok
					and preview.after.wallet.cash == prior.wallet.cash - quote,
					"ordinary/focused credit review matches exact shared price")
				_check(build.view() == prior, "credit review is pure")
				_check(build.commit(command).ok and build.cash() == prior.wallet.cash - quote,
					"ordinary/focused positive or free charge matches quote")
				_check(build._visit.reroll_credit == 0 and build._visit.rerolls == 1,
					"free and paid rerolls consume credit and advance once")
				_check(SeasonRaincheck.protected_offer(build) == protected
					and build._visit.cards == pack
					and build._visit.get("recruit") == prior.shop.get("recruit"),
					"rerolls preserve carried offer, pack and recruit")
				var after: Dictionary = build.view()
				_check(build.commit(command).replayed and build.view() == after,
					"free/focused retry has no second effect")
		if d1:
			var invalid: SeasonBuild = source._fork()
			invalid._pricing_rule = "standard-d1-reroll-v2"
			var data: Dictionary = invalid.to_data()
			var view: Dictionary = invalid.view()
			_check(invalid.reroll_price() == -1 and not SeasonSpecialOrder.commit(
				invalid, _command(invalid, "focused_reroll", {"category": "tactical"})).is_empty(),
				"direct focused helper rejects malformed rule and negative sentinel")
			_unchanged(invalid, data, view, "direct failed focused charge cannot mutate state")


func _failed_transactions() -> void:
	var build: SeasonBuild = _funded(true, 1)
	_check(build._charge(build.cash() - 4).is_empty(), "isolated affordability operand")
	var before: Dictionary = build.to_data()
	var view: Dictionary = build.view()
	var command: Dictionary = _command(build, "reroll")
	_check(build.reroll_price() == 5 and not build.preview(command).ok
		and not build.commit(command).ok, "four Cash cannot pay D1 first reroll")
	_unchanged(build, before, view, "insufficient funds preserves complete state")
	command.rev += 1
	_check(not build.commit(command).ok, "stale revision rejected")
	_unchanged(build, before, view, "stale revision preserves complete state")
	command = _command(build, "focused_reroll", {"category": "unknown"})
	_check(not build.commit(command).ok, "unsupported focused category rejected")
	_unchanged(build, before, view, "failed focused transaction preserves complete state")
	_check(not build.enable_d1_pricing(), "pricing cannot be enabled again after journal activity")
	_unchanged(build, before, view, "failed re-enable cannot rewrite rule or journal")
	var paid: SeasonBuild = _funded(true)
	var first: Dictionary = _command(paid, "reroll")
	_check(paid.commit(first).ok, "duplicate-identity setup")
	before = paid.to_data()
	view = paid.view()
	first.op = "leave_shop"
	_check(not paid.commit(first).ok, "same transaction identity with different action rejected")
	_unchanged(paid, before, view, "changed duplicate preserves complete state")
	paid._pricing_rule = "standard-d1-reroll-v2"
	before = paid.to_data()
	view = paid.view()
	_check(not paid.pricing_context_valid() and not paid.d1_pricing_valid()
		and not paid.commit(_command(paid, "reroll")).ok, "live retuned rule fails closed")
	_unchanged(paid, before, view, "invalid rule cannot spend or redraw")


func _strict_headers() -> void:
	var build: SeasonBuild = _funded(true)
	_check(build.commit(_command(build, "reroll")).ok, "strict-header replay fixture")
	var valid: Dictionary = build.to_data()
	_check(valid.version == 42 and valid.pricing_rule == SeasonBuild.D1_PRICE_RULE,
		"new format writes required immutable context")
	for kind: String in ["missing", "empty", "retuned", "type", "market1", "market11",
		"market13", "old_header", "fractional", "future"]:
		var bad: Dictionary = valid.duplicate(true)
		match kind:
			"missing": bad.erase("pricing_rule")
			"empty": bad.pricing_rule = ""
			"retuned": bad.pricing_rule = "standard-d1-reroll-v2"
			"type": bad.pricing_rule = true
			"market1": bad.market = 1
			"market11": bad.market = 11
			"market13": bad.market = 13
			"old_header":
				bad.version = 41
				bad.catalog = SeasonBuild._signature(41)
			"fractional": bad.version = 42.5
			"future": bad.version = 43
		_check(_restore(build, bad) == null, "reject malformed D1 context: " + kind)
	_check(_restore(build, valid) != null and build.to_data() == valid,
		"bad decode attempts preserve valid journal")
	var base: SeasonBuild = _funded(false)
	var legacy: Dictionary = base.to_data()
	legacy["pricing_rule"] = SeasonBuild.D1_PRICE_RULE
	_check(_restore(base, legacy) == null, "legacy format rejects new pricing header")


func _season(d1: bool) -> SeasonState:
	# Low-level initialization test only; lifecycle fixture owns earned entry proof.
	var season: SeasonState = SeasonState.create(91, false, true, true)
	season.opponents._format = 13
	if d1:
		_check(season.build.enable_d1_pricing(), "D1 context installed before draft")
	for pick in range(4):
		_check(season.choose_player(season.offers()[0]), "choose actual draft offer")
	return season


func _all_five_ai() -> void:
	var season: SeasonState = _season(true)
	var base: SeasonState = _season(false)
	_check(season.build.d1_pricing_valid() and season.build._market == 0,
		"fourth pick retains human D1 context")
	_check(season.opponents.clubs.size() == 5 and season.opponents._format == 13,
		"exact five current-policy AI clubs")
	for index in range(1, 6):
		var club: Dictionary = season.opponents.clubs[str(index)]
		var build: SeasonBuild = club.build
		var old: SeasonBuild = base.opponents.clubs[str(index)].build
		_check(build.d1_pricing_valid() and build._market == 12 and build.revision() == 0,
			"each AI has immutable D1 rule before any journal event")
		_check(build._seed == old._seed and build.roster() == old.roster()
			and build.view() == old.view() and club.profile == base.opponents.clubs[str(index)].profile,
			"AI seeds, rosters, profiles and starting wallets unchanged")
		for candidate: SeasonBuild in [build, old]:
			_check(candidate.commit(_command(candidate, "reward", {
				"game": 0, "win": true, "performance": {}})).ok, "AI reward journal")
			_check(candidate.commit(_command(candidate, "open")).ok, "AI opens real stock")
			var cash: int = candidate.cash()
			var price: int = candidate.reroll_price()
			_check(candidate.commit(_command(candidate, "reroll")).ok
				and candidate.cash() == cash - price, "AI quote equals actual shared charge")
		_check(build.cash() == 13 and old.cash() == 14
			and build._visit.offers == old._visit.offers, "AI pays surcharge without RNG compensation")
		var legacy_data: Dictionary = old.to_data()
		var legacy: SeasonBuild = _restore(old, legacy_data)
		_check(legacy != null and legacy.to_data() == legacy_data and legacy.view() == old.view()
			and legacy_data.version == 41 and not legacy_data.has("pricing_rule"),
			"each Base policy13 journal roundtrips canonically without new fields")
		_check(legacy_data.events == [
			{"id": "d1-price:0", "rev": 0, "op": "reward", "game": 0, "win": true, "performance": {}},
			{"id": "d1-price:1", "rev": 1, "op": "open"},
			{"id": "d1-price:2", "rev": 2, "op": "reroll"}],
			"Base policy13 command journal retains exact legacy shape")
		var restored: SeasonBuild = _restore(build, build.to_data())
		_check(restored != null, "each AI pricing journal restores")
		if restored != null:
			_check(restored.d1_pricing_valid() and restored.to_data() == build.to_data()
				and restored.view() == build.view(), "AI rule restored before paid replay")
			var next: Dictionary = _command(build, "reroll")
			_check(build.commit(next).ok and restored.commit(next).ok
				and restored.view() == build.view() and restored.to_data() == build.to_data(),
				"each AI next charge and stock deterministic after restore")


func _budget_boundary() -> void:
	# Controlled cash operands isolate existing Distributed Budget Bites predicate.
	var club: Dictionary = {"profile": "Distributed"}
	for cash: int in [14, 15, 18, 19, 20]:
		var base: SeasonBuild = _funded(false, 2, 12)
		var d1: SeasonBuild = _funded(true, 2, 12)
		_check(base._charge(base.cash() - cash).is_empty()
			and d1._charge(d1.cash() - cash).is_empty(), "bounded reserve setup")
		_check(SeasonOpponentBudget.reroll_useful(base, club) == (cash - 4 in range(10, 15)),
			"Base Budget Bites retains exact post-charge boundary")
		_check(SeasonOpponentBudget.reroll_useful(d1, club) == (cash - 5 in range(10, 15)),
			"D1 Budget Bites uses same surcharge before reserve decision")

extends Node
## Controlled economy fixtures only, not earned unlocks or completed physical games.
const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]
const IDS: Array[String] = [
	"dugout", "sponsorship", "academy", "doubleheader", "equipment", "earnings", "scramble"
]
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	for id: String in IDS:
		_headers(id)
	_prices()
	_atomic()
	_purchase(3, "visit:6:roll:3:0", 0)
	_purchase(3, "visit:6:roll:0:0", 7)
	_purchase(4, "visit:6:roll:2:0", 0)
	_expiry()
	print("LEAGUE_TIER_ECONOMY checks=%d failures=%d physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _rules(id: String, tier: int) -> Dictionary:
	return LeagueRules.capture_tier(id, tier, 8107 if id == "scramble" else null)


func _build(id: String, tier: int) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	check(build.enable_league_rules(_rules(id, tier)), "enable " + id + str(tier))
	return build


func _restore(build: SeasonBuild, data: Dictionary) -> SeasonBuild:
	return SeasonBuild.from_data(JSON.parse_string(JSON.stringify(data)), build._seed,
		build._initial_roster, build._pool, build._blocked)


func _bank_restore(data: Dictionary) -> SeasonOwnership:
	return SeasonOwnership.from_data(JSON.parse_string(JSON.stringify(data)),
		SeasonSponsorCatalog.ownership_catalog())


func _headers(id: String) -> void:
	var base: SeasonBuild = SeasonBuild.new(112, ROSTER)
	check(base.enable_league_rules(LeagueRules.capture(id, 0,
		8107 if id == "scramble" else null)), "Base enabled")
	var old: Dictionary = base.to_data()
	check(old.get("version") == 45 and not old.has("pricing_rule")
		and not old.has("sponsor_rule"), "Base header remains45")
	var old_bank: Dictionary = base._bank.to_data()
	check(old_bank.version == 4 and not old_bank.has("term_seed")
		and not old_bank.has("sponsor_rule"), "Base wallet header remains4")
	var restored: SeasonBuild = _restore(base, old)
	check(restored != null and ClubCareer.same(restored.to_data(), old), "Base exact replay")
	for tier in range(1, 5):
		var build: SeasonBuild = _build(id, tier)
		var data: Dictionary = build.to_data()
		check(data.get("version") == 46 and data.get("pricing_rule") ==
			"standard-d1-reroll-v1", "composed version and price header")
		restored = _restore(build, data)
		check(restored != null and ClubCareer.same(restored.to_data(), data),
			"composed exact replay " + id + str(tier))
		var bank_data: Dictionary = build._bank.to_data()
		check(bank_data.version == 5 and bank_data.term_seed == 112,
			"shop seed distinct from Scramble root seed")
		check((tier > 2) == (not bank_data.sponsor_rule.is_empty()), "explicit empty tier1/2 rule")
		var bank: SeasonOwnership = _bank_restore(bank_data)
		check(bank != null and ClubCareer.same(bank.to_data(), bank_data), "bank exact replay")
		_cross_headers(build, data, old, bank_data, old_bank)


func _cross_headers(build: SeasonBuild, data: Dictionary, old: Dictionary,
	bank_data: Dictionary, old_bank: Dictionary) -> void:
	var forged: Dictionary = data.duplicate(true)
	forged.version = 45
	check(_restore(build, forged) == null, "46 cannot masquerade as45")
	forged = old.duplicate(true)
	forged.version = 46
	check(_restore(build, forged) == null, "45 lacks46 header")
	forged = data.duplicate(true)
	forged.seed = 113
	check(_restore(build, forged) == null, "build seed mismatch rejected")
	forged = bank_data.duplicate(true)
	forged.version = 4
	check(_bank_restore(forged) == null, "bank5 cannot masquerade as4")
	forged = old_bank.duplicate(true)
	forged.version = 5
	check(_bank_restore(forged) == null, "bank4 lacks5 header")
	forged = bank_data.duplicate(true)
	forged.sponsor_rule = "forged"
	check(_bank_restore(forged) == null, "wrong sponsor rule rejected")
	forged = bank_data.duplicate(true)
	forged.term_seed = -1
	check(_bank_restore(forged) == null, "invalid term seed rejected")


func _prices() -> void:
	for tier in range(1, 5):
		var build: SeasonBuild = _build("dugout", tier)
		for rolls in [0, 1, 3]:
			for credit in [0, 2, 100]:
				build._visit = {"number": 1, "open": true,
					"rerolls": rolls, "reroll_credit": credit}
				var payable: int = maxi(0, 4 + 2 * rolls - credit)
				check(build.reroll_price() == payable + (1 if payable > 0 else 0),
					"cumulative tier paid+1/free0 quote")


func _atomic() -> void:
	var build: SeasonBuild = SeasonBuild.new(112, ROSTER)
	var before: Dictionary = build.to_data()
	var bad: Dictionary = _rules("dugout", 1)
	bad.tier = 9
	check(not build.enable_league_rules(bad) and build.to_data() == before,
		"invalid enable preserves entire build")
	var bank: SeasonOwnership = build._bank
	before = bank.to_data()
	check(not bank.enable_league_tier(_rules("dugout", 1), -1)
		and bank.to_data() == before, "invalid bank seed is atomic")
	check(build.enable_league_rules(_rules("dugout", 1)), "first enable")
	before = build.to_data()
	check(not build.enable_league_rules(_rules("dugout", 2)) and build.to_data() == before,
		"enabled context cannot silently change tier")


func _request(bank: SeasonOwnership, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"id": "league-economy:%d" % bank.revision(),
		"rev": bank.revision(), "op": op}
	result.merge(fields)
	return result


func _funded(tier: int) -> SeasonOwnership:
	var bank: SeasonOwnership = _build("dugout", tier)._bank
	for game in range(2):
		check(bank.commit(_request(bank, "reward", {"game": game, "win": true})).ok,
			"synthetic funding")
		if tier == 4:
			check(bank.commit(_request(bank, "sponsor_game_end", {"game": game})).ok,
				"funding completion closed")
	return bank


func _buy(bank: SeasonOwnership, source: String) -> Dictionary:
	check(bank.commit(_request(bank, "stock", {"offers": {"quote": "A07"}})).ok,
		"controlled stock")
	var fields: Dictionary = {"offer": "quote", "replace": "", "discard": []}
	var before: Dictionary = bank.to_data()
	check(not bank.commit(_request(bank, "buy", fields)).ok and bank.to_data() == before,
		"missing original source offer rejected atomically")
	fields.source_offer = source
	check(bank.commit(_request(bank, "buy", fields)).ok, "source-bound purchase")
	return bank.view().sponsors[0] if not bank.view().sponsors.is_empty() else {}


func _purchase(tier: int, source: String, refund: int) -> void:
	var bank: SeasonOwnership = _funded(tier)
	var receipt: Dictionary = _buy(bank, source)
	if receipt.is_empty():
		return
	var rule: String = SeasonSponsorCatalog.D4_RULE if tier == 4 else SeasonSponsorCatalog.D3_RULE
	check(receipt.get("terms", {}) == SeasonSponsorCatalog.offer_terms(rule, 112, source, "A07"),
		"exact existing seeded terms")
	var restored: SeasonOwnership = _bank_restore(bank.to_data())
	check(restored != null and ClubCareer.same(restored.view(), bank.view()), "owned terms replay")
	var cash: int = bank.cash()
	check(bank.commit(_request(bank, "sell", {"receipt": receipt.id, "discard": []})).ok,
		"early cancellation")
	check(bank.cash() == cash + refund and bank.view().sponsors.is_empty(), "exact refund")


func _expiry() -> void:
	var bank: SeasonOwnership = _funded(4)
	var receipt: Dictionary = _buy(bank, "visit:6:roll:2:0")
	if receipt.is_empty():
		return
	check(receipt.get("games_remaining") == 2, "authored two-game duration")
	for game in [2, 3]:
		var cash: int = bank.cash()
		check(bank.commit(_request(bank, "reward", {"game": game, "win": true})).ok,
			"paid game opens pending closure")
		check(not bank.completion_closed() and _bank_restore(bank.to_data()) == null,
			"pending completion cannot restore")
		# Pending completion has no public save envelope; observe actual state and journals.
		var before: Dictionary = bank._state.duplicate(true)
		var view_before: Dictionary = bank.view().duplicate(true)
		var events_before: Array = bank._events.duplicate(true)
		var requests_before: Dictionary = bank._requests.duplicate(true)
		var revision_before: int = bank.revision()
		check(not bank.commit(_request(bank, "sell", {"receipt": receipt.id, "discard": []})).ok
			and bank._state == before and bank.view() == view_before
			and bank._events == events_before and bank._requests == requests_before
			and bank.revision() == revision_before and not bank.completion_closed(),
			"pending blocks sale without state or journal mutation")
		check(bank.commit(_request(bank, "sponsor_game_end", {"game": game})).ok,
			"exact game closes")
		check(bank.cash() == cash + 18, "expiry grants no refund")
		check(bank.completion_closed() and _bank_restore(bank.to_data()) != null,
			"closed completion restores")
		check(bank.view().sponsors.size() == (1 if game == 2 else 0), "expires after second game")

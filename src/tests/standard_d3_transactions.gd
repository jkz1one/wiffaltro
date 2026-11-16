extends Node
## Focused synthetic transaction contracts. Controlled stock is not earned-game evidence.
const ROSTER: Array[String] = [
	"player.alex_finch", "player.rowan_chase", "player.nico_vega", "player.ari_banks"
]
const RULE: String = "standard-d3-nonrefundable-v1"
const TAGGED: Dictionary = {
	"A07": "visit:6:roll:3:0",
	"B02": "visit:6:roll:1:0",
	"B03": "visit:6:roll:2:0",
	"F01": "visit:6:roll:0:0",
	"F03": "visit:6:roll:9:0"
}
const FLEXIBLE: Dictionary = {
	"A07": "visit:6:roll:0:0",
	"B02": "visit:6:roll:0:0",
	"B03": "visit:6:roll:0:0",
	"F01": "visit:6:roll:2:0",
	"F03": "visit:6:roll:0:0"
}
const DIGESTS: Dictionary = {
	"A07": "3a1cf70110f417087210f51de009e0158f82bbb1f900919bfd725b4be7489aa2",
	"B02": "15d44d6049c3d9422889f3ccd97e344947e7793dba6cddafbecc00fcae70fa2e",
	"B03": "1a5f82ad1288ded8e37176c0e441588700690a6273465ec19ef6bda763a1b876",
	"F01": "2409652a67a5f27c584d61037ebbdb888cf6b7a7d883d191c57c6e47c7e1e445",
	"F03": "3a28300322d7afc770a5da8ef5e9e44476eb8659d0f0121ce9e23dd5f0ab729d"
}
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_selector()
	_context()
	for item: String in TAGGED:
		_bank_case(item, true)
		_bank_case(item, false)
	_bank_refusals()
	_ordinary_and_grouped()
	_wholesale(false)
	_wholesale(true)
	_live_removal(false)
	_live_removal(true)
	_raincheck()
	_generation_and_ai()
	_generated_purchase()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"STANDARD_D3_TRANSACTIONS checks=%d failures=%d controlled_stock=true physical_games=0"
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("D3_TRANSACTION_FAIL " + label)


func _same(a: Variant, b: Variant) -> bool:
	return ClubCareer.same(a, b)


func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _request(bank: SeasonOwnership, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"id": "d3-bank:%d" % bank.revision(), "rev": bank.revision(), "op": op
	}
	result.merge(fields)
	return result


func _command(build: SeasonBuild, op: String, fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"id": "d3-build:%d" % build.revision(), "rev": build.revision(), "op": op
	}
	result.merge(fields)
	return result


func _bank(d3: bool = true) -> SeasonOwnership:
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	if d3:
		_check(bank.enable_sponsor_terms(RULE, 112), "fresh bank2 context")
	for game in range(2):
		_check(
			bank.commit(_request(bank, "reward", {"game": game, "win": true})).ok,
			"synthetic bank funding"
		)
	return bank


func _build(d3: bool = true, market: int = 0, seed_value: int = 112) -> SeasonBuild:
	var build: SeasonBuild = SeasonBuild.new(seed_value, ROSTER)
	build._market = market
	_check(
		build.enable_d3_sponsors() if d3 else build.enable_d1_pricing(),
		"fresh immutable build rule"
	)
	for game in range(6):
		_check(
			build.commit(_command(build, "reward", {"game": game, "win": true})).ok,
			"synthetic six-game funding"
		)
	_check(build.commit(_command(build, "open")).ok, "open synthetic funded shop")
	return build


func _receipt(build: SeasonBuild, item: String) -> Dictionary:
	return SeasonSchoolSponsors.active(build, item)


func _put_buy(
	build: SeasonBuild, item: String, offer: String, fields: Dictionary = {}
) -> Dictionary:
	# Controlled stock exercises the existing transaction seam; never replayed as generated history.
	build._visit.offers = {offer: item}
	var body: Dictionary = {"offer": offer, "replace": ""}
	body.merge(fields, true)
	return build.commit(_command(build, "sponsor_buy", body))


func _selector() -> void:
	_check(
		SeasonSponsorCatalog.D3_RULE == RULE and SeasonSponsorCatalog.D3_ITEMS == TAGGED.keys(),
		"exact Working rule and five-item subset"
	)
	for item: String in TAGGED:
		var raw: String = JSON.stringify([RULE, 112, TAGGED[item], item], "", true, true)
		_check(raw.sha256_text() == DIGESTS[item], "fixed selector canonical bytes " + item)
		var wanted: Dictionary = {"rule": RULE, "source_offer": TAGGED[item]}
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, TAGGED[item], item) == wanted,
			"tagged vector " + item
		)
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, FLEXIBLE[item], item).is_empty(),
			"flexible vector " + item
		)
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, "rain:7:" + TAGGED[item], item) == wanted,
			"Raincheck preserves selector " + item
		)
		_check(
			SeasonSponsorCatalog.offer_terms("wrong", 112, TAGGED[item], item).is_empty(),
			"unsupported rule cannot tag " + item
		)
	for item: String in ["D01", "J02", "J10", "F02", "G01"]:
		_check(
			SeasonSponsorCatalog.offer_terms(RULE, 112, TAGGED.A07, item).is_empty(),
			"untargeted sponsor unchanged " + item
		)
	for offer: String in [
		"",
		"visit:0:roll:0:0",
		"visit:1:roll:0:4",
		"visit:01:roll:0:0",
		"visit:1:roll:-1:0",
		"rain:7:rain:6:visit:1:roll:0:0",
		"rain:x:visit:1:roll:0:0"
	]:
		_check(
			SeasonSponsorCatalog.original_offer(offer).is_empty(),
			"malformed source rejected " + offer
		)
	seed(1739)
	var expected: int = randi()
	seed(1739)
	SeasonSponsorCatalog.offer_terms(RULE, 112, TAGGED.A07, "A07")
	_check(randi() == expected, "selector consumes no global RNG")


func _context() -> void:
	for value: Variant in [true, -1, 2147483648, 0.5, INF, NAN]:
		var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
		var before: Dictionary = bank.to_data().duplicate(true)
		_check(
			not bank.enable_sponsor_terms(RULE, value) and bank.to_data() == before,
			"invalid seed is atomic"
		)
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	_check(
		bank.enable_sponsor_terms(RULE, 112.0) and bank.enable_sponsor_terms(RULE, 112),
		"whole parsed seed and same empty identity accepted"
	)
	var before: Dictionary = bank.to_data().duplicate(true)
	_check(
		not bank.enable_sponsor_terms(RULE, 113) and bank.to_data() == before,
		"cannot replace installed seed"
	)
	_check(
		not bank.enable_sponsor_terms("wrong", 112) and bank.to_data() == before,
		"cannot replace installed rule"
	)
	var build: SeasonBuild = _build(false)
	before = build.to_data().duplicate(true)
	var original_bank: SeasonOwnership = build._bank
	_check(
		(
			not build.enable_d3_sponsors()
			and build._bank == original_bank
			and build.to_data() == before
		),
		"late build enable leaves state and identity exact"
	)


func _bank_case(item: String, tagged: bool) -> void:
	var bank: SeasonOwnership = _bank()
	var source: String = TAGGED[item] if tagged else FLEXIBLE[item]
	_check(
		bank.commit(_request(bank, "stock", {"offers": {"quote": item}})).ok,
		"controlled bank stock"
	)
	var fields: Dictionary = {"offer": "quote", "replace": "", "discard": []}
	fields.merge(bank.source_metadata(item, source))
	var request: Dictionary = _request(bank, "buy", fields)
	var before: Dictionary = bank.to_data().duplicate(true)
	var cash: int = bank.cash()
	_check(bank.preview(request).ok and bank.to_data() == before, "bank preview does not mutate")
	_check(bank.commit(request).ok and bank.commit(request).replayed, "once-only bank acquisition")
	var owned: Dictionary = bank.view().sponsors[0] if not bank.view().sponsors.is_empty() else {}
	_check(
		(
			not owned.is_empty()
			and owned.has("terms") == tagged
			and bank.cash() == cash - SeasonSponsorCatalog.item(item).price
		),
		"computed terms and ordinary debit"
	)
	if owned.is_empty():
		return  # Prior failed prerequisite remains visible; no invalid receipt dereference.
	var copy: SeasonOwnership = SeasonOwnership.from_data(_json(bank.to_data()), bank._catalog)
	_check(
		copy != null and _same(copy.to_data(), bank.to_data()) and _same(copy.view(), bank.view()),
		"bank2 native JSON replay"
	)
	_check(
		bank._events.back().get("source_offer") == source and not bank._events.back().has("terms"),
		"event carries source but no trusted caller terms"
	)
	var credit: int = 0 if tagged else int(SeasonSponsorCatalog.item(item).price / 2)
	_check(
		(
			SeasonSponsorCatalog.resale(owned) == credit
			and (not SeasonSponsorCatalog.receipt_label(owned).is_empty()) == tagged
		),
		"owned disclosure equals refund authority"
	)
	request = _request(bank, "sell", {"receipt": owned.get("id", "missing"), "discard": []})
	cash = bank.cash()
	before = bank.to_data().duplicate(true)
	_check(
		bank.preview(request).ok and bank.to_data() == before,
		"zero-credit removal preview remains legal"
	)
	_check(
		(
			bank.commit(request).ok
			and bank.cash() == cash + credit
			and bank.view().sponsors.is_empty()
		),
		"removal applies exact tagged or ordinary credit"
	)
	_check(
		bank.commit(request).replayed and bank.cash() == cash + credit,
		"sale retry cannot pay again"
	)


func _bank_refusals() -> void:
	var bank: SeasonOwnership = _bank()
	_check(
		bank.commit(_request(bank, "stock", {"offers": {"quote": "A07"}})).ok,
		"negative purchase stock"
	)
	var valid: Dictionary = {
		"offer": "quote", "replace": "", "discard": [], "source_offer": TAGGED.A07
	}
	for kind: String in ["missing", "alias", "terms", "refund"]:
		var fields: Dictionary = valid.duplicate(true)
		if kind == "missing":
			fields.erase("source_offer")
		if kind == "alias":
			fields.source_offer = "rain:7:" + TAGGED.A07
		if kind == "terms":
			fields.terms = {"rule": RULE, "source_offer": TAGGED.A07}
		if kind == "refund":
			fields.refund = 7
		var before: Dictionary = bank.to_data().duplicate(true)
		_check(
			not bank.commit(_request(bank, "buy", fields)).ok and bank.to_data() == before,
			"reject caller override " + kind
		)
	_check(
		bank.commit(_request(bank, "buy", valid)).ok, "valid acquisition after refused candidates"
	)
	var original: Dictionary = bank.to_data().duplicate(true)
	for kind: String in ["version", "rule", "seed", "source", "extra"]:
		var changed: Dictionary = original.duplicate(true)
		if kind == "version":
			changed.version = true
		if kind == "rule":
			changed.sponsor_rule = "wrong"
		if kind == "seed":
			changed.term_seed = 112.5
		if kind == "source":
			changed.events.back().erase("source_offer")
		if kind == "extra":
			changed.terms = {"rule": RULE}
		_check(
			SeasonOwnership.from_data(_json(changed), bank._catalog) == null,
			"reject malformed bank envelope/event " + kind
		)
	var legacy: SeasonOwnership = _bank(false)
	_check(
		legacy.commit(_request(legacy, "stock", {"offers": {"quote": "A07"}})).ok,
		"legacy controlled stock"
	)
	var request: Dictionary = _request(legacy, "buy", valid)
	_check(not legacy.commit(request).ok, "bank1 rejects new metadata")
	valid.erase("source_offer")
	_check(
		(
			legacy.commit(_request(legacy, "buy", valid)).ok
			and not legacy.view().sponsors.is_empty()
			and not legacy.view().sponsors[0].has("terms")
		),
		"legacy eligible purchase remains flexible"
	)
	_check(
		(
			legacy.to_data().keys() == ["version", "catalog", "events"]
			and legacy.to_data().version == 1
		),
		"bank1 exact three-key envelope"
	)
	var roundtrip: SeasonOwnership = SeasonOwnership.from_data(
		_json(legacy.to_data()), legacy._catalog
	)
	_check(roundtrip != null and _same(roundtrip.view(), legacy.view()), "bank1 replay stays exact")


func _ordinary_and_grouped() -> void:
	for grouped: bool in [false, true]:
		var build: SeasonBuild = _build()
		build._visit.offers = {TAGGED.A07: "A07"}
		var fields: Dictionary = {"offer": TAGGED.A07, "replace": ""}
		if grouped:
			fields.sales = []
		_check(
			not SeasonSponsorCatalog.offer_label(build, TAGGED.A07, "A07").is_empty(),
			"tag disclosed before offer/confirmation"
		)
		var request: Dictionary = _command(build, "sponsor_buy", fields)
		var before: Dictionary = build.to_data().duplicate(true)
		_check(
			build.preview(request).ok and build.to_data() == before,
			"ordinary/grouped preview exact"
		)
		_check(
			build.commit(request).ok and build.commit(request).replayed,
			"ordinary/grouped tagged buy and retry"
		)
		var old: Dictionary = _receipt(build, "A07")
		_check(
			old.get("terms") == {"rule": RULE, "source_offer": TAGGED.A07},
			"original source survives ordinary/grouped restock"
		)
		var cash: int = build.cash()
		_check(
			(
				_put_buy(
					build,
					"B02",
					FLEXIBLE.B02,
					(
						{"replace": old.get("id", ""), "sales": []}
						if grouped
						else {"replace": old.get("id", "")}
					)
				)
				. ok
			),
			"tagged replacement remains legal"
		)
		_check(
			(
				build.cash() == cash - 12
				and _receipt(build, "A07").is_empty()
				and not _receipt(build, "B02").has("terms")
			),
			"tagged replacement contributes zero credit"
		)
		var counts: Dictionary = ClubPlayerProgress._sponsor_counts(build)
		_check(
			counts == {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
			"progress reconstruction preserves bank2 context"
		)
		var owned: Dictionary = _receipt(build, "B02")
		cash = build.cash()
		fields = {"receipt": owned.get("id", "missing")}
		if grouped:
			fields.sales = []
		_check(
			build.commit(_command(build, "sponsor_sell", fields)).ok and build.cash() == cash + 6,
			"untagged ordinary/grouped sale still refunds half"
		)
	# Selected zero-credit sale cannot finance a new acquisition. Candidate rolls back all steps.
	var build: SeasonBuild = _build()
	_check(_put_buy(build, "A07", TAGGED.A07).ok, "financing setup tagged copy")
	_check(build._charge(build.cash() - 5).is_empty(), "controlled cash boundary")
	var old: Dictionary = _receipt(build, "A07")
	build._visit.offers = {FLEXIBLE.B02: "B02"}
	var before: Dictionary = build.to_data().duplicate(true)
	var wallet: Dictionary = build._bank.view().duplicate(true)
	var result: Dictionary = build.commit(
		_command(
			build,
			"sponsor_buy",
			{"offer": FLEXIBLE.B02, "replace": "", "sales": [old.get("id", "missing")]}
		)
	)
	_check(
		not result.ok and build.to_data() == before and build._bank.view() == wallet,
		"zero resale cannot finance grouped purchase; exact rollback"
	)


func _wholesale(grouped: bool) -> void:
	var build: SeasonBuild = _build()
	_check(_put_buy(build, "J02", "unit:wholesale").ok, "controlled existing Wholesale sponsor")
	build._visit.offers = {TAGGED.A07: "A07", FLEXIBLE.B02: "B02"}
	var fields: Dictionary = {
		"first": {"offer": TAGGED.A07, "replace": ""},
		"second": {"offer": FLEXIBLE.B02, "replace": ""},
		"discounted": FLEXIBLE.B02
	}
	if grouped:
		fields.sales = []
	var request: Dictionary = _command(build, "wholesale", fields)
	var before: Dictionary = build.to_data().duplicate(true)
	var cash: int = build.cash()
	_check(
		build.preview(request).ok and build.to_data() == before,
		"Wholesale direct/grouped preview exact"
	)
	_check(
		build.commit(request).ok and build.commit(request).replayed,
		"Wholesale direct/grouped one purchase"
	)
	var first: Dictionary = _receipt(build, "A07")
	var second: Dictionary = _receipt(build, "B02")
	_check(
		(
			first.get("terms") == {"rule": RULE, "source_offer": TAGGED.A07}
			and not second.has("terms")
		),
		"Wholesale keeps each original selector independently"
	)
	_check(
		build.cash() == cash - 23 and first.get("paid") == 14 and second.get("paid") == 9,
		"existing cheaper discount and total unchanged"
	)
	if first.is_empty() or second.is_empty():
		return  # Keep failure evidence without calling resale on an absent receipt.
	_check(
		SeasonSponsorCatalog.resale(first) == 0 and SeasonSponsorCatalog.resale(second) == 4,
		"Wholesale owned refunds use actual paid price"
	)
	before = build.to_data().duplicate(true)
	_check(
		not build.commit(_command(build, "wholesale", fields)).ok and build.to_data() == before,
		"Wholesale cannot be consumed twice"
	)


func _live_removal(grouped: bool) -> void:
	var build: SeasonBuild = _build()
	_check(_put_buy(build, "A07", TAGGED.A07).ok, "live removal tagged setup")
	var owned: Dictionary = _receipt(build, "A07")
	_check(
		build.commit(_command(build, "match_inventory", {"game": 6})).ok,
		"ordinary live inventory entry"
	)
	var attempt: Dictionary = build._match_inventory.duplicate(true)
	var fields: Dictionary = {"game": 6, "receipt": owned.get("id", "missing"), "first_pitch": null}
	if grouped:
		fields.sales = []
	var cash: int = build.cash()
	_check(
		(
			build.commit(_command(build, "match_sell", fields)).ok
			and build.cash() == cash
			and _receipt(build, "A07").is_empty()
		),
		"live direct/grouped zero-credit cancellation legal"
	)
	_check(
		_same(build._match_inventory.sponsors, attempt.sponsors),
		"existing match-use snapshot retains captured copy"
	)


func _raincheck() -> void:
	var build: SeasonBuild = _build()
	# Isolated authored access operand, not a claim of earned Raincheck eligibility.
	build._rain_start = true
	_check(_put_buy(build, "G01", "unit:raincheck").ok, "controlled Raincheck sponsor")
	build._visit.offers = {TAGGED.A07: "A07"}
	_check(
		build.commit(_command(build, "reserve_offer", {"offer": TAGGED.A07})).ok,
		"ordinary reserve controlled eligible offer"
	)
	_check(
		(
			build.commit(_command(build, "reward", {"game": 6, "win": true, "performance": {}})).ok
			and build.commit(_command(build, "open")).ok
		),
		"ordinary next-visit delivery"
	)
	var carried: String = build._visit.get("rain_carried", "")
	_check(
		carried == "rain:7:" + TAGGED.A07 and build._visit.offers.get(carried) == "A07",
		"actual Raincheck wrapper retains original identity"
	)
	var before: Dictionary = build.to_data().duplicate(true)
	_check(
		(
			not build.commit(_command(build, "reserve_offer", {"offer": carried})).ok
			and build.to_data() == before
		),
		"repeat carry remains refused"
	)
	_check(
		(
			build.commit(_command(build, "sponsor_buy", {"offer": carried, "replace": ""})).ok
			and _receipt(build, "A07").get("terms") == {"rule": RULE, "source_offer": TAGGED.A07}
		),
		"carried purchase preserves original acquisition terms"
	)


func _generation_and_ai() -> void:
	for market in [0, 12]:
		var build: SeasonBuild = _build(true, market)
		var legacy: SeasonBuild = _build(false, market)
		_check(
			(
				build._visit.offers == legacy._visit.offers
				and build._visit.cards == legacy._visit.cards
			),
			"shared generator offers/cards exact"
		)
		for roll in range(4):
			_check(
				build._offers(roll) == legacy._offers(roll),
				"same seed ordinary/AI generator does not consume new RNG"
			)
		var data: Dictionary = build.to_data().duplicate(true)
		var restored: SeasonBuild = SeasonBuild.from_data(_json(data), 112, ROSTER)
		_check(
			restored != null and _same(restored.to_data(), data) and restored.d3_sponsors_valid(),
			"actual generated build43 journal native replay"
		)
		if restored != null:
			restored.migrate()
		_check(
			restored != null and restored._format == 43 and _same(restored.to_data(), data),
			"valid D3 migration has no side effects"
		)
		var poisoned: Dictionary = data.duplicate(true)
		poisoned.sponsor_rule = "wrong"
		_check(
			SeasonBuild.from_data(_json(poisoned), 112, ROSTER) == null,
			"mixed build rule rejected before replay"
		)
		poisoned = data.duplicate(true)
		poisoned.version = 42
		_check(
			SeasonBuild.from_data(_json(poisoned), 112, ROSTER) == null,
			"lower envelope rejects D3 context"
		)
	var ai: SeasonBuild = _build(true, 12)
	var human: SeasonBuild = _build()
	var offer: String = TAGGED.F03
	ai._visit.offers = {offer: "F03"}
	human._visit.offers = {offer: "F03"}
	var club: Dictionary = {
		"profile": "Distributed", "decisions": [], "roles": {"pitcher": ROSTER[0]}
	}
	var cash: int = ai.cash()
	_check(
		SeasonOpponentSponsors.purchase(ai, club, 6),
		"policy13 actual purchase route accepts tagged sponsor"
	)
	_check(
		human.commit(_command(human, "sponsor_buy", {"offer": offer, "replace": ""})).ok,
		"same human acquisition"
	)
	_check(
		(
			ai.cash() == cash - 10
			and human.cash() == ai.cash()
			and _receipt(ai, "F03").get("terms") == _receipt(human, "F03").get("terms")
		),
		"AI/human price and owned terms parity"
	)
	_check(
		(
			club.decisions.size() == 1
			and club.decisions[0].paid == 10
			and club.decisions[0].reason == "qualified team sponsor"
		),
		"existing AI decision policy evidence unchanged"
	)


func _generated_purchase() -> void:
	# Bounded real-generator lookup. Funding is authored unit evidence; offer identity is genuine.
	var selected: SeasonBuild
	var offer: String = ""
	var item: String = ""
	for candidate_seed in range(64):
		var candidate: SeasonBuild = SeasonBuild.new(candidate_seed, ROSTER)
		if not candidate.enable_d3_sponsors():
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
			var id: String = candidate._visit.offers[key]
			if not SeasonSponsorCatalog.offer_terms(RULE, candidate_seed, key, id).is_empty():
				selected = candidate
				offer = key
				item = id
				break
		if selected != null:
			break
	_check(selected != null, "tagged eligible actual generated offer within64 seeds")
	if selected == null:
		return
	var before: Dictionary = selected.to_data().duplicate(true)
	var request: Dictionary = _command(selected, "sponsor_buy", {"offer": offer, "replace": ""})
	_check(
		selected.preview(request).ok and selected.to_data() == before,
		"generated purchase preview is exact"
	)
	_check(selected.commit(request).ok, "purchase real generated tagged identity")
	var owned: Dictionary = _receipt(selected, item)
	_check(
		owned.get("terms") == {"rule": RULE, "source_offer": offer},
		"generated source binds owned zero-resale terms"
	)
	var data: Dictionary = selected.to_data().duplicate(true)
	var restored: SeasonBuild = SeasonBuild.from_data(_json(data), selected._seed, ROSTER)
	_check(
		(
			restored != null
			and _same(data, restored.to_data())
			and _same(selected._bank.to_data(), restored._bank.to_data())
		),
		"complete generated purchase journal cold replay"
	)
	_check(
		restored != null and _same(owned, _receipt(restored, item)),
		"cold owned receipt recomputed from generated identity"
	)
	var bad: Dictionary = data.duplicate(true)
	bad.events.back().offer = "visit:99:roll:99:0"
	_check(
		SeasonBuild.from_data(_json(bad), selected._seed, ROSTER) == null,
		"full build replay refuses substituted offer identity"
	)
	bad = data.duplicate(true)
	bad.sponsor_rule = ""
	_check(
		SeasonBuild.from_data(_json(bad), selected._seed, ROSTER) == null,
		"full build replay refuses stripped rule"
	)

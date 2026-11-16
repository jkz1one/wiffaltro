extends Node
## Synthetic tier/save fixtures only. No genuine unlock, physical game or earned award claim.
## Reuses accepted D2 lifecycle machinery; sponsor transactions have a separate focused fixture.
# gdlint: disable=max-file-lines

var _checks: int = 0
var _failures: int = 0
var _prefix: ClubCareer


func _ready() -> void:
	_prefix = _synthetic_prefix("champion")
	_check(
		(
			_prefix != null
			and _prefix.cleared()
			and _prefix.cleared(1)
			and _prefix.cleared(2)
			and not _prefix.cleared(3)
		),
		"synthetic validated Base/d1/d2 prefix unlocks d3 only"
	)
	if _prefix != null:
		_eligibility()
		_receipts()
		_synthetic_d3_receipt_replay()
		_serialization()
		await _app_atomicity()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"STANDARD_D3_LIFECYCLE checks=%d failures=%d synthetic_history=true physical_games=0"
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("STANDARD_D3_LIFECYCLE: " + label)


func _synthetic_completed(finish: String) -> SeasonState:
	# Frozen score-only policy2 exercises history serialization, not public progression.
	var season: SeasonState = SeasonState.create(51, false, true, true)
	season.career = ClubCareer.new()
	if not season.career.start(season):
		return null
	for pick: int in range(4):
		if not season.choose_player(season.offers()[0]):
			return null
	for game: int in range(12):
		if season.phase == SeasonState.Phase.COMPLETE:
			break
		var win: bool = finish != "missed"
		if season.phase == SeasonState.Phase.SEMIFINAL and finish == "semifinal":
			win = false
		if season.phase == SeasonState.Phase.FINAL and finish == "runner_up":
			win = false
		var fixture: Dictionary = season.pending_fixture()
		var home_wins: bool = (fixture.home == 0) == win
		if not season.record_player_result(
			fixture.id, 0 if home_wins else 1, 1 if home_wins else 0
		):
			return null
	if season.phase != SeasonState.Phase.COMPLETE or not season.career.sync(season):
		return null
	return season


func _synthetic_history(finish: String) -> ClubCareer:
	var season: SeasonState = _synthetic_completed(finish)
	if season == null:
		return null
	var career: ClubCareer = season.career.fork()
	if not career.close(season):
		return null
	return ClubCareer.from_data(career.to_data())


func _synthetic_d1_prefix(finish: String) -> ClubCareer:
	# Author structural prior-title evidence only; this is never an earned-title claim.
	var club: ClubCareer = _synthetic_history("champion")
	var completed: SeasonState = _synthetic_completed(finish)
	if club == null or completed == null:
		return null
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 2
	row.tier = 1
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 1)
	club.runs.append(row)
	club._assets = {}
	return ClubCareer.from_data(club.to_data())


func _synthetic_prefix(finish: String) -> ClubCareer:
	# Three authored structural title rows; no actual season result is manufactured in D3.
	var club: ClubCareer = _synthetic_d1_prefix("champion")
	var completed: SeasonState = _synthetic_completed(finish)
	if club == null or completed == null:
		return null
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 3
	row.tier = 2
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 2)
	club.runs.append(row)
	club._assets = {}
	return ClubCareer.from_data(club.to_data())


func _fresh(career: ClubCareer, tier: int, seed_value: int = 6) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	var club: ClubCareer = career.fork()
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) or not club.start(season, tier):
		return null
	season.career = club
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(club), true)
	season.npc_venues = SeasonVenues.capture_five(seed_value, club.current, tier)
	if tier == 3:
		season.final_venue = SeasonFinalVenue.capture_standard_d3(season)
	elif tier == 2:
		season.final_venue = SeasonFinalVenue.capture_standard_d2(season)
	elif tier == 1:
		season.final_venue = SeasonFinalVenue.capture_standard_d1(season)
	else:
		season.final_venue = SeasonFinalVenue.capture_standard_base(season)
	return (
		null
		if (
			season.home_property.is_empty()
			or season.npc_venues.is_empty()
			or season.final_venue.is_empty()
		)
		else season
	)


func _refused_start(career: ClubCareer, tier: int, rule: String, label: String) -> void:
	var season: SeasonState = SeasonState.create(7, false, true, true)
	season.opponents._format = 13
	season.opponents.draft_rule = rule
	var before: Dictionary = career.to_data().duplicate(true)
	var build_before: Dictionary = season.build.to_data().duplicate(true)
	var opponents_before: Dictionary = season.opponents.to_data().duplicate(true)
	_check(
		(
			not career.start(season, tier)
			and ClubCareer.same(before, career.to_data())
			and ClubCareer.same(build_before, season.build.to_data())
			and ClubCareer.same(opponents_before, season.opponents.to_data())
		),
		label
	)


func _eligibility() -> void:
	for tier: int in [-1, 4]:
		_refused_start(_prefix.fork(), tier, "", "unsupported tier refuses atomically: %d" % tier)
	for finish: String in ["missed", "semifinal", "runner_up"]:
		var locked: ClubCareer = _synthetic_prefix(finish)
		_check(locked != null, "synthetic nonchampion d2 prefix exists: " + finish)
		if locked != null:
			_refused_start(locked, 3, "", "prior nonchampion d2 cannot unlock d3: " + finish)
	_refused_start(ClubCareer.new(), 3, "", "empty history cannot unlock d3")
	_refused_start(_synthetic_history("champion"), 3, "", "Base title alone cannot unlock d3")
	var d1: ClubCareer = _synthetic_d1_prefix("champion")
	_refused_start(d1.fork(), 3, "", "d1 title alone cannot unlock d3")
	var abandoned: SeasonState = _fresh(d1, 2)
	_check(
		abandoned != null and abandoned.career.close(abandoned), "synthetic d2 abandonment closes"
	)
	if abandoned != null:
		_refused_start(abandoned.career, 3, "", "abandoned d2 cannot unlock d3")
	_refused_start(_prefix.fork(), 3, "retuned", "unknown draft rule refuses before mutation")
	for tier: int in [0, 1]:
		_refused_start(
			_prefix.fork(),
			tier,
			SeasonOpponentDraft.D2_RULE,
			"lower tier refuses inherited d2 draft rule atomically: %d" % tier
		)
	for tier: int in [0, 1, 2]:
		var season: SeasonState = SeasonState.create(7, false, true, true)
		season.opponents._format = 13
		_check(season.build.enable_d3_sponsors(), "prepare term-aware disposable candidate")
		var build: Dictionary = season.build.to_data().duplicate(true)
		var bank: Dictionary = season.build._bank.to_data().duplicate(true)
		var career: ClubCareer = _prefix.fork()
		var before: Dictionary = career.to_data().duplicate(true)
		_check(
			(
				not career.start(season, tier)
				and ClubCareer.same(before, career.to_data())
				and ClubCareer.same(build, season.build.to_data())
				and ClubCareer.same(bank, season.build._bank.to_data())
			),
			"lower selected tier refuses preinstalled D3 sponsor context: %d" % tier
		)
	var malformed: Dictionary = _prefix.to_data().duplicate(true)
	malformed.runs[2].receipt.total += 1
	var before: Dictionary = malformed.duplicate(true)
	_check(
		ClubCareer.from_data(malformed) == null and ClubCareer.same(before, malformed),
		"failed prior-title decode leaves malformed input untouched"
	)
	var invalid: ClubCareer = _prefix.fork()
	invalid.runs[2].receipt.total += 1
	_refused_start(invalid, 3, "", "authored d2 title with bad receipt cannot unlock")
	malformed = _prefix.to_data().duplicate(true)
	malformed.runs[2].tier = 3
	malformed.runs[2].receipt = ClubSeasonRecord.receipt(malformed.runs[2].proof, true, 3)
	malformed.version = 25
	_check(
		ClubCareer.from_data(malformed) == null, "d3 title cannot supply its own prior d2 unlock"
	)
	malformed = _prefix.to_data().duplicate(true)
	malformed.version = 25
	_check(ClubCareer.from_data(malformed) == null, "career25 without a D3 history row refuses")
	var validated: ClubCareer = ClubCareer.from_data(_prefix.to_data())
	_check(
		validated != null and validated.cleared(2) and not validated.cleared(3),
		"successful decode independently validates all earlier titles"
	)


func _receipts() -> void:
	for finish: String in ["missed", "semifinal", "runner_up", "champion"]:
		var season: SeasonState = _synthetic_completed(finish)
		_check(season != null, "synthetic receipt proof exists: " + finish)
		if season == null:
			continue
		var proof: Dictionary = ClubSeasonRecord.capture(season)
		var base: Dictionary = ClubSeasonRecord.receipt(proof, true)
		var d1: Dictionary = ClubSeasonRecord.receipt(proof, true, 1)
		var d2: Dictionary = ClubSeasonRecord.receipt(proof, true, 2)
		var d3: Dictionary = ClubSeasonRecord.receipt(proof, true, 3)
		var repeated: Dictionary = ClubSeasonRecord.receipt(proof, false, 3)
		var base_award: int = {"missed": 35, "semifinal": 65, "runner_up": 95, "champion": 180}[finish]
		var d1_award: int = {"missed": 36, "semifinal": 68, "runner_up": 99, "champion": 189}[finish]
		var d2_award: int = {"missed": 38, "semifinal": 71, "runner_up": 104, "champion": 198}[finish]
		_check(
			(
				base.version == 1
				and base.finish_award == base_award
				and d1.version == 2
				and d1.finish_award == d1_award
			),
			"frozen receipt1/2 awards remain exact: " + finish
		)
		_check(
			(
				d2.version == 3
				and d2.finish_award == d2_award
				and d2.record_bonus == base.record_bonus
				and d2.first_bonus == base.first_bonus
			),
			"receipt3 Working award and unchanged regular/first bonuses: " + finish
		)
		var d3_award: int = {"missed": 40, "semifinal": 74, "runner_up": 109, "champion": 207}[finish]
		_check(
			(
				d3.version == 4
				and d3.finish_award == d3_award
				and d3.record_bonus == base.record_bonus
				and d3.first_bonus == base.first_bonus
			),
			"receipt4 integer115/100 award with unchanged bonuses: " + finish
		)
		_check(
			(
				repeated.first_bonus == 0
				and d3.total - repeated.total == (25 if finish == "champion" else 0)
			),
			"first d3 title pays25 only once: " + finish
		)
		_check(
			ClubSeasonRecord.receipt(proof, true, 4).is_empty(), "unsupported receipt tier refuses"
		)
		var before: Dictionary = season.career.to_data().duplicate(true)
		_check(
			(
				season.career.sync(season)
				and season.career.sync(season)
				and ClubCareer.same(before, season.career.to_data())
			),
			"completed Base receipt1 sync remains idempotent: " + finish
		)


func _synthetic_d3_receipt_replay() -> void:
	var completed: SeasonState = _synthetic_completed("champion")
	if completed == null:
		_check(false, "synthetic d3 receipt source proof")
		return
	var club: ClubCareer = _prefix.fork()
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 4
	row.tier = 3
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 3)
	club.runs.append(row)
	club._assets = {}
	var validated: ClubCareer = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.cleared(3),
		"synthetic receipt4 validates against prior d2 title"
	)
	if validated == null:
		return
	var legacy: SeasonState = SeasonState.create(13)
	legacy.career = validated
	var before: int = validated.balance()
	var replayed: SeasonState = _roundtrip(legacy, "completed synthetic d3 career in legacy mode")
	_check(
		replayed != null and replayed.career.balance() == before,
		"replaying completed receipt4 grants no second award"
	)
	row = row.duplicate(true)
	row.id = 5
	row.receipt = ClubSeasonRecord.receipt(row.proof, false, 3)
	club.runs.append(row)
	club._assets = {}
	validated = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.runs[-1].receipt.first_bonus == 0,
		"repeat d3 championship has no second first-title bonus"
	)
	var invalid: Dictionary = club.to_data()
	invalid.runs[-1].receipt = ClubSeasonRecord.receipt(row.proof, true, 3)
	_check(ClubCareer.from_data(invalid) == null, "repeat d3 first-title repayment refuses")
	invalid = club.to_data()
	invalid.runs[3].receipt.version = 3
	_check(ClubCareer.from_data(invalid) == null, "tier3 cannot relabel receipt4 as d2 receipt3")


func _roundtrip(season: SeasonState, label: String) -> SeasonState:
	var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_check(not data.is_empty(), label + " snapshot")
	if data.is_empty():
		return null
	var restored: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(data, "", true, true))
	)
	_check(restored != null, label + " exact JSON decode")
	if restored != null:
		_check(ClubCareer.same(data, SeasonSave.snapshot(restored)), label + " canonical roundtrip")
	return restored


func _serialization() -> void:
	var season: SeasonState = _fresh(_prefix, 3)
	_check(
		season != null,
		"eligible d3 freezes sponsor/draft/price rules ordinal3 GrandII before pick1"
	)
	if season == null:
		return
	var initial_final: Dictionary = season.final_venue.duplicate(true)
	var initial_venues: Dictionary = season.npc_venues.duplicate(true)
	for count: int in [0, 3, 4]:
		while season.picks.size() < count:
			var chosen: bool = season.choose_player(season.offers()[0])
			_check(chosen, "actual draft choice")
			if not chosen:
				return
		var restored: SeasonState = _roundtrip(season, "d3 pick%d" % count)
		if restored == null:
			return
		season = restored
		var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
		_check(
			(
				data.version == 70
				and data.career.version == 25
				and data.build.version == 43
				and data.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
				and data.build.market == 0
				and data.sponsor_rule == SeasonSponsorCatalog.D3_RULE
				and data.build.sponsor_rule == SeasonSponsorCatalog.D3_RULE
				and data.draft_rule == SeasonOpponentDraft.D2_RULE
				and data.opponents.draft_rule == SeasonOpponentDraft.D2_RULE
				and data.opponents.policy == 13
				and data.npc_venues.venue_ordinal == 3
				and data.final_venue.version == 3
				and data.final_venue.selection == SeasonFinalVenue.STANDARD_D3_SELECTION
			),
			"save70 joins exact active D3 cumulative context"
		)
		_check(
			_bank_context(season.build, 2) and season.build.d3_sponsors_valid(),
			"human bank2 context is installed before replay and preserved through pick4"
		)
		_check(
			(
				ClubCareer.same(initial_final, season.final_venue)
				and ClubCareer.same(initial_venues, season.npc_venues)
			),
			"draft never rerolls frozen venues"
		)
		if count < 4:
			_check(data.opponents.clubs.is_empty(), "partial draft has no AI builds")
		else:
			_check(data.opponents.clubs.size() == 5, "pick4 initializes exactly five D3 opponents")
			for key: String in data.opponents.clubs:
				var club: Dictionary = data.opponents.clubs[key]
				_check(
					(
						club.build.version == 43
						and club.build.market == 12
						and club.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
						and club.build.sponsor_rule == SeasonSponsorCatalog.D3_RULE
						and _bank_context(season.opponents.clubs[key].build, 2)
					),
					"each regenerated AI inherits all three rules and exact bank2 context"
				)
		if count == 3:
			_rule_refusals(season)
	_tamper(SeasonSave.snapshot(season).duplicate(true))
	_final_guard(season)
	var career: ClubCareer = season.career.fork()
	_check(career.close(season), "abandoning D3 closes only disposable career")
	for tier: int in [0, 1, 2]:
		var lower: SeasonState = _fresh(career, tier, 8)
		var old_tier: SeasonState = _fresh(_prefix, tier, 8)
		_check(
			lower != null and old_tier != null,
			"old-tier replay remains available after D3: %d" % tier
		)
		if lower == null or old_tier == null:
			continue
		for pick: int in range(4):
			_check(
				(
					lower.choose_player(lower.offers()[0])
					and old_tier.choose_player(old_tier.offers()[0])
				),
				"same actual old-tier draft choices with or without an abandoned D3 row"
			)
		var restored: SeasonState = _roundtrip(lower, "tier%d after D3" % tier)
		_check(restored != null, "lower tier after D3 persists: %d" % tier)
		if restored != null:
			var saved: Dictionary = SeasonSave.snapshot(restored).duplicate(true)
			var rule: String = SeasonOpponentDraft.D2_RULE if tier == 2 else ""
			_check(
				(
					saved.version == 70
					and saved.career.version == 25
					and saved.draft_rule == rule
					and saved.sponsor_rule == ""
					and not saved.build.has("sponsor_rule")
					and saved.npc_venues.venue_ordinal == tier
					and saved.build.version == (42 if tier > 0 else 41)
					and (
						(saved.build.get("pricing_rule", "") == SeasonBuild.D1_PRICE_RULE)
						== (tier > 0)
					)
					and _bank_context(restored.build, 1)
				),
				"retained career25 does not retrofit D3 terms onto selected old tier"
			)
			_check(
				(
					ClubCareer.same(restored.build.to_data(), old_tier.build.to_data())
					and ClubCareer.same(restored.opponents.to_data(), old_tier.opponents.to_data())
					and ClubCareer.same(restored.teams, old_tier.teams)
				),
				"Base/d1/d2 human build all AI journals and drafted order retain exact old outputs"
			)
			for opponent: Dictionary in restored.opponents.clubs.values():
				_check(
					(
						opponent.build._format == (42 if tier > 0 else 41)
						and opponent.build._market == 12
						and _bank_context(opponent.build, 1)
						and opponent.build._sponsor_rule.is_empty()
					),
					"old-tier AI remains old untagged bank1"
				)
			_final_guard(restored)


func _bank_context(build: SeasonBuild, version: int) -> bool:
	var bank: Dictionary = build._bank.to_data().duplicate(true)
	if version == 1:
		return SeasonOwnership._keys(bank, ["version", "catalog", "events"]) and bank.version == 1
	return (
		SeasonOwnership._keys(bank, ["version", "catalog", "events", "sponsor_rule", "term_seed"])
		and bank.version == 2
		and bank.sponsor_rule == SeasonSponsorCatalog.D3_RULE
		and bank.term_seed == build._seed
	)


func _rule_refusals(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	for replacement: String in ["", "retuned"]:
		season.opponents.draft_rule = replacement
		var picks: Array[String] = season.picks.duplicate()
		var build: Dictionary = season.build.to_data().duplicate(true)
		var opponents: Dictionary = season.opponents.to_data().duplicate(true)
		var career: Dictionary = season.career.to_data().duplicate(true)
		_check(
			(
				not season.choose_player(season.offers()[0])
				and season.picks == picks
				and ClubCareer.same(build, season.build.to_data())
				and ClubCareer.same(opponents, season.opponents.to_data())
				and ClubCareer.same(career, season.career.to_data())
				and SeasonSave.snapshot(season).is_empty()
			),
			"replaced d2 rule refuses without mutation"
		)
	season.opponents.draft_rule = SeasonOpponentDraft.D2_RULE
	for field: String in ["sponsor", "bank_rule", "bank_seed", "pricing"]:
		var sponsor: String = season.build._sponsor_rule
		var bank_rule: String = season.build._bank._sponsor_rule
		var bank_seed: int = season.build._bank._term_seed
		var price: String = season.build._pricing_rule
		match field:
			"sponsor":
				season.build._sponsor_rule = "retuned"
			"bank_rule":
				season.build._bank._sponsor_rule = "retuned"
			"bank_seed":
				season.build._bank._term_seed += 1
			"pricing":
				season.build._pricing_rule = "retuned"
		var picks: Array[String] = season.picks.duplicate()
		var build: Dictionary = season.build.to_data().duplicate(true)
		var bank: Dictionary = season.build._bank.to_data().duplicate(true)
		var career: Dictionary = season.career.to_data().duplicate(true)
		_check(
			(
				not season.choose_player(season.offers()[0])
				and season.picks == picks
				and ClubCareer.same(build, season.build.to_data())
				and ClubCareer.same(bank, season.build._bank.to_data())
				and ClubCareer.same(career, season.career.to_data())
				and SeasonSave.snapshot(season).is_empty()
			),
			"invalid D3 context refuses before pick4: " + field
		)
		season.build._sponsor_rule = sponsor
		season.build._bank._sponsor_rule = bank_rule
		season.build._bank._term_seed = bank_seed
		season.build._pricing_rule = price
	_check(
		ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"refused rule edits leave checkpoint intact"
	)


func _tamper(data: Dictionary) -> void:
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(data, "", true, true))
	_check(
		SeasonSave._decode(parsed) != null,
		"whole-number parsed JSON headers admit exact D3 context"
	)
	for field: String in [
		"old_envelope",
		"career24",
		"missing_top_draft",
		"top_draft",
		"missing_opponent_draft",
		"opponent_draft",
		"missing_top_sponsor",
		"top_sponsor",
		"missing_human_sponsor",
		"human_sponsor",
		"ai_sponsor",
		"human_price",
		"ai_price",
		"human42",
		"ai42",
		"policy",
		"market",
		"ordinal",
		"selection",
		"final_version",
		"extra",
		"fractional_save",
		"fractional_career",
		"fractional_human",
		"fractional_ai",
		"fractional_policy",
		"fractional_market",
		"fractional_ordinal",
		"fractional_final"
	]:
		var bad: Dictionary = parsed.duplicate(true)
		match field:
			"old_envelope":
				bad.version = 69
			"career24":
				bad.career.version = 24
			"missing_top_draft":
				bad.erase("draft_rule")
			"top_draft":
				bad.draft_rule = ""
			"missing_opponent_draft":
				bad.opponents.erase("draft_rule")
			"opponent_draft":
				bad.opponents.draft_rule = "retuned"
			"missing_top_sponsor":
				bad.erase("sponsor_rule")
			"top_sponsor":
				bad.sponsor_rule = ""
			"missing_human_sponsor":
				bad.build.erase("sponsor_rule")
			"human_sponsor":
				bad.build.sponsor_rule = "retuned"
			"ai_sponsor":
				bad.opponents.clubs["1"].build.sponsor_rule = "retuned"
			"human_price":
				bad.build.pricing_rule = "retuned"
			"ai_price":
				bad.opponents.clubs["1"].build.pricing_rule = "retuned"
			"human42":
				bad.build.version = 42
			"ai42":
				bad.opponents.clubs["1"].build.version = 42
			"policy":
				bad.opponents.policy = 12
			"market":
				bad.opponents.clubs["1"].build.market = 11
			"ordinal":
				bad.npc_venues.venue_ordinal = 2
			"selection":
				bad.final_venue.selection = SeasonFinalVenue.STANDARD_D2_SELECTION
			"final_version":
				bad.final_venue.version = 4
			"extra":
				bad["refund"] = 10
			"fractional_save":
				bad.version = 69.5
			"fractional_career":
				bad.career.version = 24.5
			"fractional_human":
				bad.build.version = 42.5
			"fractional_ai":
				bad.opponents.clubs["1"].build.version = 42.5
			"fractional_policy":
				bad.opponents.policy = 12.5
			"fractional_market":
				bad.opponents.clubs["1"].build.market = 11.5
			"fractional_ordinal":
				bad.npc_venues.venue_ordinal = 2.5
			"fractional_final":
				bad.final_venue.version = 2.5
		var before: Dictionary = bad.duplicate(true)
		_check(
			SeasonSave._decode(bad) == null and ClubCareer.same(before, bad),
			"strict70 immutable refusal: " + field
		)


func _final_guard(season: SeasonState) -> void:
	var phase: SeasonState.Phase = season.phase
	var round_index: int = season.round_index
	season.final_fixture = {"id": 32, "round": 11, "home": 0, "away": 1, "neutral": true}
	season.phase = SeasonState.Phase.FINAL
	season.round_index = 10
	_check(
		(
			SeasonFinalVenue.for_fixture(season, season.final_fixture).is_empty()
			and not SeasonFinalVenue.standard_base_final_ready(season, season.final_fixture)
		),
		"normal Base/d1/d2/d3 final selection cannot bypass genuine settled-history guard"
	)
	season.final_fixture = {}
	season.phase = phase
	season.round_index = round_index


func _app_atomicity() -> void:
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://standard-d3-lifecycle-%d.json" % OS.get_process_id()
	_cleanup()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = SeasonState.create(13)
	app.season.career = _prefix.fork()
	var previous: SeasonState = app.season
	var before: Dictionary = previous.career.to_data().duplicate(true)
	app.ask_progression_season(3)
	_check(
		(
			app._dialog.visible
			and app._dialog.dialog_text.contains("+1 Cash")
			and app._dialog.dialog_text.contains("40/74/109/207")
			and app._dialog.dialog_text.contains("1 Backyard, 0 Expanded, 2 Club, 2 Mogul")
			and app._dialog.dialog_text.contains("Grandstand Gardens II")
			and app._dialog.dialog_text.contains("0 Cash on cancellation or replacement")
		),
		"existing confirmation discloses exact Working d3 price/reward/quota/final"
	)
	app._dialog.hide()
	_check(
		(
			app.season == previous
			and ClubCareer.same(before, previous.career.to_data())
			and not FileAccess.file_exists(SeasonSave.path)
		),
		"cancel changes no season/history/save"
	)
	for tier: int in [4]:
		app.begin_season(6, true, true, true, true, true, tier)
		_check(
			app.season == previous and ClubCareer.same(before, previous.career.to_data()),
			"unsupported app tier preserves live season: %d" % tier
		)
	var good_path: String = SeasonSave.path
	SeasonSave.path = good_path + "/absent/season.json"
	app.begin_season(6, true, true, true, true, true, 3)
	_check(
		app.season == previous and ClubCareer.same(before, previous.career.to_data()),
		"failed checkpoint rolls back candidate and prefix close"
	)
	SeasonSave.path = good_path
	app.begin_season(6, true, true, true, true, true, 3)
	_check(
		(
			app.season != previous
			and app.season.career.active_tier() == 3
			and app.notice.contains("Standard d3")
			and app.notice.contains("Frozen away parks")
		),
		"app commits selected d3 with frozen assignment notice before draft"
	)
	if app.season != previous:
		var saved: SeasonState = SeasonSave.restore()
		_check(
			(
				saved != null
				and saved.build.d3_sponsors_valid()
				and saved.build._format == 43
				and _bank_context(saved.build, 2)
			),
			"Continue preserves exact build43 and bank2 context"
		)
		var d3: SeasonState = app.season
		var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
		var rule: String = d3.build._pricing_rule
		d3.build._pricing_rule = "invalid"
		app.begin_season(8, false)
		_check(
			app.season == d3 and FileAccess.get_file_as_string(SeasonSave.path) == bytes,
			"invalid live price context cannot close history or overwrite save"
		)
		d3.build._pricing_rule = rule
		var balance: int = d3.career.balance()
		app.begin_season(8, false)
		_check(
			(
				app.season != d3
				and app.season.build == null
				and app.season.career.current == 0
				and app.season.career.balance() == balance
			),
			"d3 to existing non-progression choice preserves career without payout"
		)
		var legacy_data: Dictionary = SeasonSave.snapshot(app.season).duplicate(true)
		_check(
			(
				legacy_data.get("version") == 70
				and legacy_data.career.version == 25
				and legacy_data.draft_rule == ""
				and legacy_data.sponsor_rule == ""
				and not legacy_data.has("build")
				and not legacy_data.has("npc_venues")
				and not legacy_data.has("opponents")
			),
			"explicit70 legacy shape has no d3 context"
		)
		var legacy: SeasonState = _roundtrip(app.season, "d3 to legacy mode")
		_check(
			legacy != null and legacy.build == null and legacy.career.balance() == balance,
			"legacy70 retains prior rewards exactly"
		)
		for field: String in ["build", "opponents", "npc_venues", "final_venue", "physical"]:
			var bad: Dictionary = legacy_data.duplicate(true)
			bad[field] = {}
			_check(SeasonSave._decode(bad) == null, "legacy70 mixed context refuses: " + field)
		var vanilla: Dictionary = legacy_data.duplicate(true)
		vanilla.version = 4
		vanilla.erase("career")
		vanilla.erase("draft_rule")
		vanilla.erase("sponsor_rule")
		_check(
			ClubCareer.same(vanilla, SeasonSave.snapshot(SeasonState.create(8))),
			"legacy70 underlying old save4 payload remains exact under native canonical JSON"
		)
		for field: String in ["draft_rule", "sponsor_rule"]:
			var bad: Dictionary = legacy_data.duplicate(true)
			bad[field] = SeasonSponsorCatalog.D3_RULE
			_check(SeasonSave._decode(bad) == null, "legacy70 rejects active rule: " + field)
		var old: Dictionary = legacy_data.duplicate(true)
		old.version = 4
		_check(SeasonSave._decode(old) == null, "career25 cannot smuggle into old save4")
		app.begin_season(8, true, true, true, true, true, 0)
		_check(
			(
				app.season.build != null
				and app.season.build._format == 41
				and app.season.career.active_tier() == 0
				and app.season.career.balance() == balance
				and SeasonSave.snapshot(app.season).get("version") == 70
			),
			"Base to d3 to legacy to Base preserves history/assets and returns Base rule"
		)
	app.queue_free()
	await get_tree().process_frame
	_cleanup()
	SeasonSave.path = original_path


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SeasonSave.path + suffix):
			DirAccess.remove_absolute(SeasonSave.path + suffix)

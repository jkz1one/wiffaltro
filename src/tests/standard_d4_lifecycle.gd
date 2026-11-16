extends Node
## Authored structural eligibility only. No physical game or genuine promotion claim.
## Production public activation remains false throughout this focused fixture.
# gdlint: disable=max-file-lines,max-returns

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
			and _prefix.cleared(3)
			and not _prefix.cleared(4)
		),
		"authored validated Base/d1/d2/d3 prefix permits structural d4 eligibility"
	)
	if _prefix != null:
		_eligibility()
		_receipts()
		_serialization()
		await _public_gate()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			(
				"STANDARD_D4_LIFECYCLE checks=%d failures=%d synthetic_history=true physical_games=0 "
				+ "public_activation=false"
			)
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("STANDARD_D4_LIFECYCLE: " + label)


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


func _synthetic_d2_prefix(finish: String) -> ClubCareer:
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


func _synthetic_prefix(finish: String) -> ClubCareer:
	# Four authored structural title rows, never a genuine promotion claim.
	var club: ClubCareer = _synthetic_d2_prefix("champion")
	var completed: SeasonState = _synthetic_completed(finish)
	if club == null or completed == null:
		return null
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 4
	row.tier = 3
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 3)
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
	if tier == 4:
		season.final_venue = SeasonFinalVenue.capture_standard_d4(season)
	elif tier == 3:
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
	for tier: int in [-1, 5]:
		_refused_start(_prefix.fork(), tier, "", "unsupported tier refuses atomically: %d" % tier)
	for finish: String in ["missed", "semifinal", "runner_up"]:
		var locked: ClubCareer = _synthetic_prefix(finish)
		_check(locked != null, "authored nonchampion d3 exists: " + finish)
		if locked != null:
			_refused_start(locked, 4, "", "nonchampion d3 cannot unlock d4: " + finish)
	_refused_start(ClubCareer.new(), 4, "", "empty history cannot unlock d4")
	_refused_start(_synthetic_history("champion"), 4, "", "Base alone cannot unlock d4")
	_refused_start(_synthetic_d1_prefix("champion"), 4, "", "d1 alone cannot unlock d4")
	_refused_start(_synthetic_d2_prefix("champion"), 4, "", "d2 alone cannot unlock d4")
	var abandoned: SeasonState = _fresh(_synthetic_d2_prefix("champion"), 3)
	_check(
		abandoned != null and abandoned.career.close(abandoned), "authored d3 abandonment closes"
	)
	if abandoned != null:
		_refused_start(abandoned.career, 4, "", "abandoned d3 cannot unlock d4")
	_refused_start(_prefix.fork(), 4, "retuned", "unknown draft rule refuses before mutation")
	for tier: int in [0, 1, 2, 3]:
		var season: SeasonState = SeasonState.create(7, false, true, true)
		season.opponents._format = 13
		_check(season.build.enable_d4_sponsors(), "prepare disposable D4 candidate")
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
			"lower selected tier refuses installed D4 context atomically: %d" % tier
		)
	for field: String in [
		"receipt",
		"missing_prior",
		"future_prior",
		"active_prior",
		"fractional_tier",
		"wrong_version"
	]:
		var bad: Dictionary = _prefix.to_data().duplicate(true)
		match field:
			"receipt":
				bad.runs[3].receipt.total += 1
			"missing_prior":
				bad.runs[3].tier = 4
				bad.runs[3].receipt = ClubSeasonRecord.receipt(bad.runs[3].proof, true, 4)
				bad.version = 26
			"future_prior":
				var prior: Dictionary = bad.runs[2]
				bad.runs[2] = bad.runs[3]
				bad.runs[3] = prior
				bad.runs[2].id = 3
				bad.runs[3].id = 4
			"active_prior":
				bad.runs[3].status = "active"
			"fractional_tier":
				bad.runs[3].tier = 3.5
			"wrong_version":
				bad.version = 26
		var before: Dictionary = bad.duplicate(true)
		_check(
			ClubCareer.from_data(bad) == null and ClubCareer.same(before, bad),
			"strict validated earlier D3 prefix refuses: " + field
		)
	var invalid: ClubCareer = _prefix.fork()
	invalid.runs[3].receipt.total += 1
	_refused_start(invalid, 4, "", "in-memory forged title cannot bypass prefix validation")


func _receipts() -> void:
	var awards: Array = [
		[35, 65, 95, 180],
		[36, 68, 99, 189],
		[38, 71, 104, 198],
		[40, 74, 109, 207],
		[42, 78, 114, 216]
	]
	var finishes: Array[String] = ["missed", "semifinal", "runner_up", "champion"]
	for index: int in range(finishes.size()):
		var finish: String = finishes[index]
		var season: SeasonState = _synthetic_completed(finish)
		_check(season != null, "authored complete proof: " + finish)
		if season == null:
			continue
		var proof: Dictionary = ClubSeasonRecord.capture(season)
		for tier: int in range(5):
			var receipt: Dictionary = ClubSeasonRecord.receipt(proof, true, tier)
			_check(
				(
					receipt.version == tier + 1
					and receipt.finish_award == awards[tier][index]
					and receipt.record_bonus == (15 if finish != "missed" else 0)
					and receipt.first_bonus == (25 if finish == "champion" else 0)
				),
				"exact frozen receipt and record bonus: %d/%s" % [tier, finish]
			)
		var repeated: Dictionary = ClubSeasonRecord.receipt(proof, false, 4)
		_check(
			(
				repeated.first_bonus == 0
				and repeated.total == awards[4][index] + repeated.record_bonus
			),
			"D4 repeat receipt never grants a second first-title award: " + finish
		)
		_check(ClubSeasonRecord.receipt(proof, true, 5).is_empty(), "unknown receipt tier refuses")
	var completed: SeasonState = _synthetic_completed("champion")
	if completed == null:
		_check(false, "authored D4 receipt source")
		return
	var club: ClubCareer = _prefix.fork()
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 5
	row.tier = 4
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 4)
	club.runs.append(row)
	club._assets = {}
	var validated: ClubCareer = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.cleared(4) and validated.to_data().version == 26,
		"authored receipt5 validates only after prior D3 champion"
	)
	if validated == null:
		return
	var legacy: SeasonState = SeasonState.create(13)
	legacy.career = validated
	var balance: int = validated.balance()
	var replayed: SeasonState = _roundtrip(legacy, "completed authored D4 in legacy mode")
	_check(
		replayed != null and replayed.career.balance() == balance,
		"cold receipt5 replay grants no duplicate award"
	)
	row = row.duplicate(true)
	row.id = 6
	row.receipt = ClubSeasonRecord.receipt(row.proof, false, 4)
	club.runs.append(row)
	club._assets = {}
	validated = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.runs[-1].receipt.first_bonus == 0,
		"second authored D4 title has no first-title bonus"
	)
	var invalid: Dictionary = club.to_data()
	invalid.runs[-1].receipt = ClubSeasonRecord.receipt(row.proof, true, 4)
	_check(ClubCareer.from_data(invalid) == null, "duplicate first-title payment refuses")
	invalid = club.to_data()
	invalid.runs[4].receipt.version = 4
	_check(ClubCareer.from_data(invalid) == null, "tier4 cannot relabel receipt5 as receipt4")


func _roundtrip(season: SeasonState, label: String) -> SeasonState:
	var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	_check(not data.is_empty(), label + " snapshot")
	if data.is_empty():
		return null
	var restored: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(data, "", true, true))
	)
	_check(restored != null, label + " full-precision JSON decode")
	if restored != null:
		_check(
			ClubCareer.same(data, SeasonSave.snapshot(restored)),
			label + " whole parsed canonical equality"
		)
	return restored


func _serialization() -> void:
	var season: SeasonState = _fresh(_prefix, 4)
	_check(season != null, "structural D4 freezes ordinal4 GrandIII and rules before pick1")
	if season == null:
		return
	var initial_final: Dictionary = season.final_venue.duplicate(true)
	var initial_venues: Dictionary = season.npc_venues.duplicate(true)
	for count: int in [0, 3, 4]:
		while season.picks.size() < count:
			var chosen: bool = season.choose_player(season.offers()[0])
			_check(chosen, "ordinary draft choice")
			if not chosen:
				return
		var restored: SeasonState = _roundtrip(season, "D4 pick%d" % count)
		if restored == null:
			return
		season = restored
		var data: Dictionary = SeasonSave.snapshot(season).duplicate(true)
		_check(
			(
				data.version == 71
				and data.career.version == 26
				and data.build.version == 44
				and data.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
				and data.build.market == 0
				and data.sponsor_rule == SeasonSponsorCatalog.D4_RULE
				and data.build.sponsor_rule == SeasonSponsorCatalog.D4_RULE
				and data.draft_rule == SeasonOpponentDraft.D2_RULE
				and data.opponents.draft_rule == SeasonOpponentDraft.D2_RULE
				and data.opponents.policy == 13
				and data.npc_venues.venue_ordinal == 4
				and data.final_venue.version == 4
				and data.final_venue.selection == SeasonFinalVenue.STANDARD_D4_SELECTION
			),
			"Save71 joins exact active D4 contexts"
		)
		_check(
			(
				_bank_context(season.build, 3)
				and season.build.d4_sponsors_valid()
				and not season.build.d3_sponsors_valid()
			),
			"human exact Ownership3 before replay and after pick4"
		)
		_check(
			(
				ClubCareer.same(initial_final, season.final_venue)
				and ClubCareer.same(initial_venues, season.npc_venues)
			),
			"draft retains frozen venues"
		)
		if count < 4:
			_check(data.opponents.clubs.is_empty(), "partial draft has no AI events")
		else:
			_check(data.opponents.clubs.size() == 5, "pick4 initializes exactly five D4 opponents")
			for key: String in data.opponents.clubs:
				var opponent: SeasonBuild = season.opponents.clubs[key].build
				_check(
					(
						opponent._format == 44
						and opponent._market == 12
						and opponent.d4_sponsors_valid()
						and opponent.d1_pricing_valid()
						and _bank_context(opponent, 3)
					),
					"each AI receives exact D4 rules before roster events"
				)
		if count == 3:
			_rule_refusals(season)
	_tamper(SeasonSave.snapshot(season).duplicate(true))
	_reward_evidence_refusal(season)
	_final_guard(season)
	var career: ClubCareer = season.career.fork()
	_check(career.close(season), "abandon authored D4 without payout")
	for tier: int in [0, 1, 2, 3]:
		var lower: SeasonState = _fresh(career, tier, 8)
		var historical: SeasonState = _fresh(_prefix, tier, 8)
		_check(lower != null and historical != null, "lower-tier replay after D4: %d" % tier)
		if lower == null or historical == null:
			continue
		for pick: int in range(4):
			_check(
				(
					lower.choose_player(lower.offers()[0])
					and historical.choose_player(historical.offers()[0])
				),
				"identical lower-tier draft choices"
			)
		var restored: SeasonState = _roundtrip(lower, "tier%d after D4" % tier)
		_check(restored != null, "lower-tier retained history cold replay")
		if restored == null:
			continue
		var saved: Dictionary = SeasonSave.snapshot(restored).duplicate(true)
		_check(
			(
				saved.version == 71
				and saved.career.version == 26
				and saved.draft_rule == (SeasonOpponentDraft.D2_RULE if tier >= 2 else "")
				and saved.sponsor_rule == (SeasonSponsorCatalog.D3_RULE if tier == 3 else "")
				and saved.npc_venues.venue_ordinal == tier
				and saved.build.version == (43 if tier == 3 else (42 if tier > 0 else 41))
				and _bank_context(restored.build, 2 if tier == 3 else 1)
			),
			"Career26 retains selected lower-tier exact serialized rules"
		)
		_check(
			(
				ClubCareer.same(restored.build.to_data(), historical.build.to_data())
				and ClubCareer.same(restored.opponents.to_data(), historical.opponents.to_data())
				and ClubCareer.same(restored.teams, historical.teams)
			),
			"all six lower-tier journals and drafted order equal prior outputs"
		)
		for opponent: Dictionary in restored.opponents.clubs.values():
			_check(
				(
					opponent.build._format == (43 if tier == 3 else (42 if tier > 0 else 41))
					and opponent.build._market == 12
					and _bank_context(opponent.build, 2 if tier == 3 else 1)
					and not opponent.build.d4_sponsors_valid()
				),
				"lower-tier AI is never retrofitted with short terms"
			)
		_final_guard(restored)
	_legacy(career)


func _reward_evidence_refusal(season: SeasonState) -> void:
	# A consistent synthetic Build44 journal is not physical-result authority.
	var before: Dictionary = SeasonSave.snapshot(season).duplicate(true)
	var candidate: SeasonBuild = season.build._fork()
	var reward: Dictionary = {
		"id": "d4-unbacked-reward",
		"rev": candidate.revision(),
		"op": "reward",
		"game": season.pending_fixture().id,
		"win": true,
		"performance": {}
	}
	_check(candidate.commit(reward).ok, "authored standalone Build44 reward fixture")
	_check(
		not SeasonSave._build_history_valid(season, candidate),
		"valid build reward still requires a matching accepted human result"
	)
	var unbacked: Dictionary = before.duplicate(true)
	unbacked.build = candidate.to_data()
	_check(
		(
			SeasonSave._decode(JSON.parse_string(JSON.stringify(unbacked, "", true, true))) == null
			and ClubCareer.same(before, SeasonSave.snapshot(season))
		),
		"Save71 rejects unbacked reward without touching the actual draft checkpoint"
	)


func _bank_context(build: SeasonBuild, version: int) -> bool:
	var bank: Dictionary = build._bank.to_data().duplicate(true)
	if version == 1:
		return SeasonOwnership._keys(bank, ["version", "catalog", "events"]) and bank.version == 1
	return (
		SeasonOwnership._keys(bank, ["version", "catalog", "events", "sponsor_rule", "term_seed"])
		and bank.version == version
		and (
			bank.sponsor_rule
			== (SeasonSponsorCatalog.D4_RULE if version == 3 else SeasonSponsorCatalog.D3_RULE)
		)
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
			"invalid D4 context refuses before pick4: " + field
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
		"whole-number parsed JSON headers admit exact D4 context"
	)
	for field: String in [
		"old_envelope",
		"career25",
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
		"human43",
		"ai43",
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
				bad.version = 70
			"career25":
				bad.career.version = 25
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
			"human43":
				bad.build.version = 43
			"ai43":
				bad.opponents.clubs["1"].build.version = 43
			"policy":
				bad.opponents.policy = 12
			"market":
				bad.opponents.clubs["1"].build.market = 11
			"ordinal":
				bad.npc_venues.venue_ordinal = 3
			"selection":
				bad.final_venue.selection = SeasonFinalVenue.STANDARD_D3_SELECTION
			"final_version":
				bad.final_venue.version = 3
			"extra":
				bad["refund"] = 10
			"fractional_save":
				bad.version = 70.5
			"fractional_career":
				bad.career.version = 25.5
			"fractional_human":
				bad.build.version = 43.5
			"fractional_ai":
				bad.opponents.clubs["1"].build.version = 43.5
			"fractional_policy":
				bad.opponents.policy = 12.5
			"fractional_market":
				bad.opponents.clubs["1"].build.market = 11.5
			"fractional_ordinal":
				bad.npc_venues.venue_ordinal = 3.5
			"fractional_final":
				bad.final_venue.version = 3.5
		var before: Dictionary = bad.duplicate(true)
		_check(
			SeasonSave._decode(bad) == null and ClubCareer.same(before, bad),
			"strict71 immutable refusal: " + field
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
		"normal Base/d1/d2/d3/d4 final selection cannot bypass genuine settled-history guard"
	)
	season.final_fixture = {}
	season.phase = phase
	season.round_index = round_index


func _legacy(career: ClubCareer) -> void:
	var legacy: SeasonState = SeasonState.create(8)
	legacy.career = career.fork()
	var balance: int = legacy.career.balance()
	var restored: SeasonState = _roundtrip(legacy, "D4 history in legacy mode")
	_check(
		(
			restored != null
			and restored.build == null
			and restored.career.current == 0
			and restored.career.balance() == balance
		),
		"legacy71 retains prior rewards without payout"
	)
	var data: Dictionary = SeasonSave.snapshot(legacy).duplicate(true)
	_check(
		(
			data.version == 71
			and data.career.version == 26
			and data.draft_rule == ""
			and data.sponsor_rule == ""
			and not data.has("build")
			and not data.has("opponents")
			and not data.has("npc_venues")
		),
		"explicit71 legacy has no active D4 context"
	)
	for field: String in ["build", "opponents", "npc_venues", "final_venue", "physical"]:
		var bad: Dictionary = data.duplicate(true)
		bad[field] = {}
		_check(SeasonSave._decode(bad) == null, "legacy71 mixed context refuses: " + field)
	for field: String in ["draft_rule", "sponsor_rule"]:
		var bad: Dictionary = data.duplicate(true)
		bad[field] = SeasonSponsorCatalog.D4_RULE
		_check(SeasonSave._decode(bad) == null, "legacy71 nonempty rule refuses: " + field)
	for version: int in [4, 68, 69, 70]:
		var bad: Dictionary = data.duplicate(true)
		bad.version = version
		_check(SeasonSave._decode(bad) == null, "Career26 refuses old envelope: %d" % version)
	var vanilla: Dictionary = data.duplicate(true)
	vanilla.version = 4
	vanilla.erase("career")
	vanilla.erase("draft_rule")
	vanilla.erase("sponsor_rule")
	_check(
		ClubCareer.same(vanilla, SeasonSave.snapshot(SeasonState.create(8))),
		"legacy71 underlying old save4 payload retains whole parsed equality"
	)


func _public_gate() -> void:
	_check(not ClubCareer.D4_PUBLIC_ACTIVATION_ENABLED, "public D4 activation stays held")
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://standard-d4-lifecycle-%d.json" % OS.get_process_id()
	_cleanup()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = SeasonState.create(13)
	app.season.career = _prefix.fork()
	var previous: SeasonState = app.season
	var before: Dictionary = previous.career.to_data().duplicate(true)
	app.ask_progression_season(4)
	_check(
		(
			not app._dialog.visible
			and app.season == previous
			and ClubCareer.same(before, previous.career.to_data())
			and not FileAccess.file_exists(SeasonSave.path)
		),
		"public D4 request denied before confirmation or writes"
	)
	app.begin_season(6, true, true, true, true, true, 4)
	_check(
		(
			app.season == previous
			and ClubCareer.same(before, previous.career.to_data())
			and not FileAccess.file_exists(SeasonSave.path)
		),
		"direct public D4 entry denied before candidate mutation"
	)
	app.ask_progression_season(3)
	_check(
		(
			app._dialog.visible
			and app._dialog.dialog_text.contains("40/74/109/207")
			and app._dialog.dialog_text.contains("Grandstand Gardens II")
		),
		"lower-tier D3 confirmation remains reachable and exact"
	)
	app._dialog.hide()
	var terms: String = app._progression_terms(4)
	_check(
		(
			terms.contains("42/78/114/216")
			and terms.contains("two completed games")
			and terms.contains("half paid")
			and terms.contains("0 Cash")
			and terms.contains("Grandstand Gardens III")
		),
		"authored D4 terms disclose exact duration/refund/reward/final"
	)
	_check(ClubCareerUI.tier_label(4) == "Standard/d4", "retained D4 history has explicit label")
	app.queue_free()
	await get_tree().process_frame
	_cleanup()
	SeasonSave.path = original_path


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SeasonSave.path + suffix):
			DirAccess.remove_absolute(SeasonSave.path + suffix)

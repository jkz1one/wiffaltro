extends Node
## Synthetic serialization fixtures only. No genuine title or physical-game claim.
## Reuses the accepted D1 score-proof and roundtrip helpers for one D2 lifecycle.

var _checks: int = 0
var _failures: int = 0
var _prefix: ClubCareer


func _ready() -> void:
	_prefix = _synthetic_prefix("champion")
	_check(
		_prefix != null and _prefix.cleared() and _prefix.cleared(1) and not _prefix.cleared(2),
		"synthetic validated prior Base/d1 titles unlock d2 only"
	)
	if _prefix != null:
		_eligibility()
		_receipts()
		_synthetic_d2_receipt_replay()
		_serialization()
		await _app_atomicity()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"STANDARD_D2_LIFECYCLE checks=%d failures=%d synthetic_history=true physical_games=0"
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("STANDARD_D2_LIFECYCLE: " + label)


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


func _synthetic_prefix(finish: String) -> ClubCareer:
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
	if tier == 2:
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
	var before: Dictionary = career.to_data()
	var build_before: Dictionary = season.build.to_data()
	var opponents_before: Dictionary = season.opponents.to_data()
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
	for tier: int in [-1, 3]:
		_refused_start(_prefix.fork(), tier, "", "unsupported tier refuses atomically: %d" % tier)
	for finish: String in ["missed", "semifinal", "runner_up"]:
		var locked: ClubCareer = _synthetic_prefix(finish)
		_check(locked != null, "synthetic nonchampion d1 prefix exists: " + finish)
		if locked != null:
			_refused_start(locked, 2, "", "prior nonchampion d1 cannot unlock d2: " + finish)
	_refused_start(ClubCareer.new(), 2, "", "empty history cannot unlock d2")
	var base: ClubCareer = _synthetic_history("champion")
	_refused_start(base.fork(), 2, "", "Base title alone cannot unlock d2")
	var abandoned: SeasonState = _fresh(base, 1)
	_check(
		abandoned != null and abandoned.career.close(abandoned), "synthetic d1 abandonment closes"
	)
	if abandoned != null:
		_refused_start(abandoned.career, 2, "", "abandoned d1 cannot unlock d2")
	_refused_start(_prefix.fork(), 2, "retuned", "unknown draft rule refuses before mutation")
	for tier: int in [0, 1]:
		_refused_start(
			_prefix.fork(),
			tier,
			SeasonOpponentDraft.D2_RULE,
			"lower tier refuses d2 rule atomically: %d" % tier
		)
	var malformed: Dictionary = _prefix.to_data()
	malformed.runs[1].receipt.total += 1
	var before: Dictionary = malformed.duplicate(true)
	_check(
		ClubCareer.from_data(malformed) == null and ClubCareer.same(before, malformed),
		"failed decode leaves malformed input untouched"
	)
	var invalid: ClubCareer = _prefix.fork()
	invalid.runs[1].receipt.total += 1
	_refused_start(invalid, 2, "", "authored title claim with bad receipt cannot unlock")
	malformed = _prefix.to_data()
	malformed.runs[1].tier = 2
	malformed.runs[1].receipt = ClubSeasonRecord.receipt(malformed.runs[1].proof, true, 2)
	malformed.version = 24
	_check(
		ClubCareer.from_data(malformed) == null, "d2 title cannot supply its own prior d1 unlock"
	)
	var validated: ClubCareer = ClubCareer.from_data(_prefix.to_data())
	_check(
		validated != null and validated.cleared(1) and not validated.cleared(2),
		"successful decode independently validates prior titles"
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
		var repeated: Dictionary = ClubSeasonRecord.receipt(proof, false, 2)
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
		_check(
			(
				repeated.first_bonus == 0
				and d2.total - repeated.total == (25 if finish == "champion" else 0)
			),
			"first d2 title pays25 only once: " + finish
		)
		_check(
			ClubSeasonRecord.receipt(proof, true, 3).is_empty(), "unsupported receipt tier refuses"
		)
		var before: Dictionary = season.career.to_data()
		_check(
			(
				season.career.sync(season)
				and season.career.sync(season)
				and ClubCareer.same(before, season.career.to_data())
			),
			"completed Base receipt1 sync remains idempotent: " + finish
		)


func _synthetic_d2_receipt_replay() -> void:
	var completed: SeasonState = _synthetic_completed("champion")
	if completed == null:
		_check(false, "synthetic d2 receipt source proof")
		return
	var club: ClubCareer = _prefix.fork()
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 3
	row.tier = 2
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 2)
	club.runs.append(row)
	club._assets = {}
	var validated: ClubCareer = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.cleared(2),
		"synthetic receipt3 validates against prior d1 title"
	)
	if validated == null:
		return
	var legacy: SeasonState = SeasonState.create(13)
	legacy.career = validated
	var before: int = validated.balance()
	var replayed: SeasonState = _roundtrip(legacy, "completed synthetic d2 career in legacy mode")
	_check(
		replayed != null and replayed.career.balance() == before,
		"replaying completed receipt3 grants no second award"
	)
	row = row.duplicate(true)
	row.id = 4
	row.receipt = ClubSeasonRecord.receipt(row.proof, false, 2)
	club.runs.append(row)
	club._assets = {}
	validated = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.runs[-1].receipt.first_bonus == 0,
		"repeat d2 championship has no second first-title bonus"
	)
	var invalid: Dictionary = club.to_data()
	invalid.runs[-1].receipt = ClubSeasonRecord.receipt(row.proof, true, 2)
	_check(ClubCareer.from_data(invalid) == null, "repeat d2 first-title repayment refuses")
	invalid = club.to_data()
	invalid.runs[2].receipt.version = 2
	_check(ClubCareer.from_data(invalid) == null, "tier2 cannot relabel receipt3 as d1 receipt2")


func _roundtrip(season: SeasonState, label: String) -> SeasonState:
	var data: Dictionary = SeasonSave.snapshot(season)
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
	var season: SeasonState = _fresh(_prefix, 2)
	_check(
		season != null, "eligible d2 freezes draft/price rule, ordinal2 and Grand II before draft"
	)
	if season == null:
		return
	var initial_final: Dictionary = season.final_venue.duplicate(true)
	var initial_venues: Dictionary = season.npc_venues.duplicate(true)
	for count: int in [0, 3, 4]:
		while season.picks.size() < count:
			_check(season.choose_player(season.offers()[0]), "actual draft choice")
		var restored: SeasonState = _roundtrip(season, "d2 pick%d" % count)
		if restored == null:
			return
		season = restored
		var data: Dictionary = SeasonSave.snapshot(season)
		_check(
			(
				data.version == 69
				and data.career.version == 24
				and data.build.version == 42
				and data.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
				and data.build.market == 0
				and data.draft_rule == SeasonOpponentDraft.D2_RULE
				and data.opponents.draft_rule == SeasonOpponentDraft.D2_RULE
				and data.opponents.policy == 13
				and data.npc_venues.venue_ordinal == 2
				and data.final_venue.version == 3
				and data.final_venue.selection == SeasonFinalVenue.STANDARD_D2_SELECTION
			),
			"save69 joins exact active d2 context"
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
			_check(data.opponents.clubs.size() == 5, "pick4 initializes exactly five d2 opponents")
			for club: Dictionary in data.opponents.clubs.values():
				_check(
					(
						club.build.version == 42
						and club.build.market == 12
						and club.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
					),
					"each regenerated AI inherits same captured42 price rule"
				)
		if count == 3:
			_rule_refusals(season)
	_tamper(SeasonSave.snapshot(season))
	_final_guard(season)
	var career: ClubCareer = season.career.fork()
	_check(career.close(season), "abandoning d2 closes only disposable career")
	for tier: int in [0, 1]:
		var lower: SeasonState = _fresh(career, tier, 8)
		_check(lower != null, "lower-tier replay remains available after d2: %d" % tier)
		if lower == null:
			continue
		for pick: int in range(4):
			_check(lower.choose_player(lower.offers()[0]), "lower-tier replay actual draft choice")
		var restored: SeasonState = _roundtrip(lower, "tier%d after d2" % tier)
		_check(restored != null, "lower tier after d2 persists: %d" % tier)
		if restored != null:
			var saved: Dictionary = SeasonSave.snapshot(restored)
			_check(
				(
					saved.version == 69
					and saved.career.version == 24
					and saved.draft_rule == ""
					and not saved.opponents.has("draft_rule")
					and saved.npc_venues.venue_ordinal == tier
					and saved.build.version == 41 + tier
					and (
						(saved.build.get("pricing_rule", "") == SeasonBuild.D1_PRICE_RULE)
						== (tier == 1)
					)
				),
				"later lower tier retains career24 with its exact old draft/price/venue context"
			)
			for opponent: Dictionary in saved.opponents.clubs.values():
				_check(
					(
						opponent.build.version == 41 + tier
						and opponent.build.market == 12
						and (
							(opponent.build.get("pricing_rule", "") == SeasonBuild.D1_PRICE_RULE)
							== (tier == 1)
						)
					),
					"later lower-tier AI uses exact inherited rule"
				)
			_final_guard(restored)


func _rule_refusals(season: SeasonState) -> void:
	var saved: Dictionary = SeasonSave.snapshot(season)
	for replacement: String in ["", "retuned"]:
		season.opponents.draft_rule = replacement
		var picks: Array[String] = season.picks.duplicate()
		var build: Dictionary = season.build.to_data()
		var opponents: Dictionary = season.opponents.to_data()
		var career: Dictionary = season.career.to_data()
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
	_check(
		ClubCareer.same(saved, SeasonSave.snapshot(season)),
		"refused rule edits leave checkpoint intact"
	)


func _tamper(data: Dictionary) -> void:
	for field: String in [
		"old_envelope",
		"career23",
		"missing_top_rule",
		"top_rule",
		"missing_opponent_rule",
		"opponent_rule",
		"human_rule",
		"ai_rule",
		"policy",
		"ordinal",
		"selection",
		"final_version"
	]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"old_envelope":
				bad.version = 68
			"career23":
				bad.career.version = 23
			"missing_top_rule":
				bad.erase("draft_rule")
			"top_rule":
				bad.draft_rule = ""
			"missing_opponent_rule":
				bad.opponents.erase("draft_rule")
			"opponent_rule":
				bad.opponents.draft_rule = "retuned"
			"human_rule":
				bad.build.pricing_rule = "retuned"
			"ai_rule":
				bad.opponents.clubs["1"].build.pricing_rule = "retuned"
			"policy":
				bad.opponents.policy = 12
			"ordinal":
				bad.npc_venues.venue_ordinal = 1
			"selection":
				bad.final_venue.selection = SeasonFinalVenue.STANDARD_D1_SELECTION
			"final_version":
				bad.final_venue.version = 2
		_check(SeasonSave._decode(bad) == null, "strict69 refusal: " + field)


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
		"normal Base/d1/d2 final selection cannot bypass genuine settled-history guard"
	)
	season.final_fixture = {}
	season.phase = phase
	season.round_index = round_index


func _app_atomicity() -> void:
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://standard-d2-lifecycle-%d.json" % OS.get_process_id()
	_cleanup()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = SeasonState.create(13)
	app.season.career = _prefix.fork()
	var previous: SeasonState = app.season
	var before: Dictionary = previous.career.to_data()
	app.ask_progression_season(2)
	_check(
		(
			app._dialog.visible
			and app._dialog.dialog_text.contains("+1 Cash")
			and app._dialog.dialog_text.contains("38/71/104/198")
			and app._dialog.dialog_text.contains("1 Backyard, 1 Expanded, 2 Club, 1 Mogul")
			and app._dialog.dialog_text.contains("Grandstand Gardens II")
		),
		"existing confirmation discloses exact Working d2 price/reward/quota/final"
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
	for tier: int in [3]:
		app.begin_season(6, true, true, true, true, true, tier)
		_check(
			app.season == previous and ClubCareer.same(before, previous.career.to_data()),
			"unsupported app tier preserves live season: %d" % tier
		)
	var good_path: String = SeasonSave.path
	SeasonSave.path = good_path + "/absent/season.json"
	app.begin_season(6, true, true, true, true, true, 2)
	_check(
		app.season == previous and ClubCareer.same(before, previous.career.to_data()),
		"failed checkpoint rolls back candidate and prefix close"
	)
	SeasonSave.path = good_path
	app.begin_season(6, true, true, true, true, true, 2)
	_check(
		(
			app.season != previous
			and app.season.career.active_tier() == 2
			and app.notice.contains("Standard d2")
			and app.notice.contains("Frozen away parks")
		),
		"app commits selected d2 with frozen assignment notice before draft"
	)
	if app.season != previous:
		var saved: SeasonState = SeasonSave.restore()
		_check(saved != null and saved.build.d1_pricing_valid(), "saved d2 app candidate restores")
		var d2: SeasonState = app.season
		var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
		var rule: String = d2.build._pricing_rule
		d2.build._pricing_rule = "invalid"
		app.begin_season(8, false)
		_check(
			app.season == d2 and FileAccess.get_file_as_string(SeasonSave.path) == bytes,
			"invalid live price context cannot close history or overwrite save"
		)
		d2.build._pricing_rule = rule
		var balance: int = d2.career.balance()
		app.begin_season(8, false)
		_check(
			(
				app.season != d2
				and app.season.build == null
				and app.season.career.current == 0
				and app.season.career.balance() == balance
			),
			"d2 to existing non-progression choice preserves career without payout"
		)
		var legacy_data: Dictionary = SeasonSave.snapshot(app.season)
		_check(
			(
				legacy_data.get("version") == 69
				and legacy_data.career.version == 24
				and legacy_data.draft_rule == ""
				and not legacy_data.has("build")
				and not legacy_data.has("npc_venues")
				and not legacy_data.has("opponents")
			),
			"explicit69 legacy shape has no d2 context"
		)
		var legacy: SeasonState = _roundtrip(app.season, "d2 to legacy mode")
		_check(
			legacy != null and legacy.build == null and legacy.career.balance() == balance,
			"legacy69 retains prior rewards exactly"
		)
		for field: String in ["build", "opponents", "npc_venues", "final_venue", "physical"]:
			var bad: Dictionary = legacy_data.duplicate(true)
			bad[field] = {}
			_check(SeasonSave._decode(bad) == null, "legacy69 mixed context refuses: " + field)
		var old: Dictionary = legacy_data.duplicate(true)
		old.version = 4
		_check(SeasonSave._decode(old) == null, "career24 cannot smuggle into old save4")
		app.begin_season(8, true, true, true, true, true, 0)
		_check(
			(
				app.season.build != null
				and app.season.build._format == 41
				and app.season.career.active_tier() == 0
				and app.season.career.balance() == balance
				and SeasonSave.snapshot(app.season).get("version") == 69
			),
			"Base to d2 to legacy to Base preserves history/assets and returns Base rule"
		)
	app.queue_free()
	await get_tree().process_frame
	_cleanup()
	SeasonSave.path = original_path


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SeasonSave.path + suffix):
			DirAccess.remove_absolute(SeasonSave.path + suffix)

extends Node
## Synthetic serialization fixtures only. No earned public-final claim or physics run.
## An actual d1 physical round and paid-journal replay remain a separate native gate.

var _checks: int = 0
var _failures: int = 0
var _prefix: ClubCareer


func _ready() -> void:
	_prefix = _synthetic_history("champion")
	_check(
		_prefix != null and _prefix.cleared() and not _prefix.cleared(1),
		"synthetic validated Base title unlocks d1 only"
	)
	if _prefix != null:
		_eligibility()
		_receipts()
		_synthetic_d1_receipt_replay()
		_serialization()
		await _app_atomicity()
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"STANDARD_D1_LIFECYCLE checks=%d failures=%d synthetic_history=true physical_games=0"
			% [_checks, _failures]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("STANDARD_D1_LIFECYCLE: " + label)


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


func _fresh(career: ClubCareer, tier: int, seed_value: int = 6) -> SeasonState:
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	var club: ClubCareer = career.fork()
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)):
		return null
	if tier == 1 and not season.build.enable_d1_pricing():
		return null
	if not club.start(season, tier):
		return null
	season.career = club
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(club), true)
	season.npc_venues = SeasonVenues.capture_five(seed_value, club.current, tier)
	season.final_venue = (
		SeasonFinalVenue.capture_standard_d1(season)
		if tier == 1
		else SeasonFinalVenue.capture_standard_base(season)
	)
	return (
		null
		if (
			season.home_property.is_empty()
			or season.npc_venues.is_empty()
			or season.final_venue.is_empty()
		)
		else season
	)


func _eligibility() -> void:
	for tier: int in [-1, 2, 3, 4]:
		var candidate: SeasonState = SeasonState.create(7, false, true, true)
		candidate.opponents._format = 13
		var club: ClubCareer = _prefix.fork()
		var before: Dictionary = club.to_data()
		var build_before: Dictionary = candidate.build.to_data()
		_check(
			(
				not club.start(candidate, tier)
				and ClubCareer.same(before, club.to_data())
				and ClubCareer.same(build_before, candidate.build.to_data())
			),
			"unsupported tier refuses atomically: %d" % tier
		)
	for finish: String in ["missed", "semifinal", "runner_up"]:
		var locked: ClubCareer = _synthetic_history(finish)
		_check(
			locked != null and _fresh(locked, 1) == null,
			"nonchampion synthetic prefix stays locked: " + finish
		)
	_check(_fresh(ClubCareer.new(), 1) == null, "empty career cannot select d1")
	var abandoned: SeasonState = SeasonState.create(9, false, true, true)
	abandoned.career = ClubCareer.new()
	_check(
		(
			abandoned.career.start(abandoned)
			and abandoned.career.close(abandoned)
			and _fresh(abandoned.career, 1) == null
		),
		"abandoned Base season cannot unlock d1"
	)
	var malformed: Dictionary = _prefix.to_data()
	malformed.runs[0].receipt.total += 1
	_check(ClubCareer.from_data(malformed) == null, "malformed championship receipt refuses")


func _receipts() -> void:
	for finish: String in ["missed", "semifinal", "runner_up", "champion"]:
		var season: SeasonState = _synthetic_completed(finish)
		_check(season != null, "synthetic receipt proof exists: " + finish)
		if season == null:
			continue
		var proof: Dictionary = ClubSeasonRecord.capture(season)
		var base: Dictionary = ClubSeasonRecord.receipt(proof, true)
		var d1: Dictionary = ClubSeasonRecord.receipt(proof, true, 1)
		var repeated: Dictionary = ClubSeasonRecord.receipt(proof, false, 1)
		var award: int = {"missed": 36, "semifinal": 68, "runner_up": 99, "champion": 189}[finish]
		_check(
			(
				base.version == 1
				and d1.version == 2
				and d1.finish_award == award
				and d1.record_bonus == base.record_bonus
				and d1.first_bonus == base.first_bonus
			),
			"receipt2 Working award and unchanged record/first bonus: " + finish
		)
		_check(
			(
				repeated.first_bonus == 0
				and d1.total - repeated.total == (25 if finish == "champion" else 0)
			),
			"first d1 title pays25 only once: " + finish
		)
		_check(
			ClubSeasonRecord.receipt(proof, true, 2).is_empty(), "unsupported receipt tier refuses"
		)
		var before: Dictionary = season.career.to_data()
		_check(
			(
				season.career.sync(season)
				and season.career.sync(season)
				and ClubCareer.same(before, season.career.to_data())
			),
			"completed Base receipt1 sync is idempotent: " + finish
		)


func _synthetic_d1_receipt_replay() -> void:
	# Explicit serialization fixture: no live season or physical-earned claim is authored.
	var completed: SeasonState = _synthetic_completed("champion")
	if completed == null:
		_check(false, "synthetic d1 receipt source proof")
		return
	var club: ClubCareer = _prefix.fork()
	var row: Dictionary = completed.career.runs[0].duplicate(true)
	row.id = 2
	row.tier = 1
	row.receipt = ClubSeasonRecord.receipt(row.proof, true, 1)
	club.runs.append(row)
	club._assets = {}
	var validated: ClubCareer = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.cleared(1),
		"synthetic receipt2 validates against Base prefix"
	)
	if validated == null:
		return
	var legacy: SeasonState = SeasonState.create(13)
	legacy.career = validated
	var before: int = validated.balance()
	var replayed: SeasonState = _roundtrip(legacy, "completed synthetic d1 career in legacy mode")
	_check(
		replayed != null and replayed.career.balance() == before,
		"replaying completed receipt2 grants no second award"
	)
	row = row.duplicate(true)
	row.id = 3
	row.receipt = ClubSeasonRecord.receipt(row.proof, false, 1)
	club.runs.append(row)
	club._assets = {}
	validated = ClubCareer.from_data(club.to_data())
	_check(
		validated != null and validated.runs[-1].receipt.first_bonus == 0,
		"repeat d1 championship has no second first-title bonus"
	)
	var invalid: Dictionary = club.to_data()
	invalid.runs[-1].receipt = ClubSeasonRecord.receipt(row.proof, true, 1)
	_check(ClubCareer.from_data(invalid) == null, "repeat d1 first-title repayment refuses")
	invalid = club.to_data()
	invalid.runs[1].receipt.version = 1
	_check(ClubCareer.from_data(invalid) == null, "tier1 cannot relabel receipt2 as Base receipt1")


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
	var season: SeasonState = _fresh(_prefix, 1)
	_check(season != null, "eligible d1 freezes rule, ordinal1 and Grand I before draft")
	if season == null:
		return
	var initial_final: Dictionary = season.final_venue.duplicate(true)
	var initial_venues: Dictionary = season.npc_venues.duplicate(true)
	for count: int in [0, 3, 4]:
		while season.picks.size() < count:
			_check(season.choose_player(season.offers()[0]), "actual draft choice")
		var restored: SeasonState = _roundtrip(season, "d1 pick%d" % count)
		if restored == null:
			return
		season = restored
		var data: Dictionary = SeasonSave.snapshot(season)
		_check(
			(
				data.version == 68
				and data.career.version == 23
				and data.build.version == 42
				and data.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
				and data.build.market == 0
				and data.opponents.policy == 13
				and data.npc_venues.venue_ordinal == 1
				and data.final_venue.version == 2
				and data.final_venue.selection == SeasonFinalVenue.STANDARD_D1_SELECTION
			),
			"save68 joins exact active d1 context"
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
			_check(data.opponents.clubs.size() == 5, "pick4 initializes exactly five d1 opponents")
			for club: Dictionary in data.opponents.clubs.values():
				_check(
					(
						club.build.version == 42
						and club.build.market == 12
						and club.build.pricing_rule == SeasonBuild.D1_PRICE_RULE
					),
					"each regenerated AI uses same captured42 rule"
				)
	var data: Dictionary = SeasonSave.snapshot(season)
	_tamper(data)
	_final_guard(season)
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "abandoning d1 closes only disposable career")
	var base: SeasonState = _fresh(club, 0, 8)
	_check(base != null, "Base replay remains available after d1")
	if base == null:
		return
	for pick: int in range(4):
		_check(base.choose_player(base.offers()[0]), "Base replay actual draft choice")
	var base_restored: SeasonState = _roundtrip(base, "Base after d1")
	_check(base_restored != null, "Base after d1 persists")
	if base_restored != null:
		var saved: Dictionary = SeasonSave.snapshot(base_restored)
		_check(
			(
				saved.version == 68
				and saved.career.version == 23
				and saved.build.version == 41
				and not saved.build.has("pricing_rule")
				and saved.npc_venues.venue_ordinal == 0
				and saved.final_venue.selection == SeasonFinalVenue.STANDARD_BASE_SELECTION
			),
			"later Base keeps career23/assets while restoring exact Base rule and selection"
		)
		for opponent: Dictionary in saved.opponents.clubs.values():
			_check(
				(
					opponent.build.version == 41
					and opponent.build.market == 12
					and not opponent.build.has("pricing_rule")
				),
				"later Base AI remains41 without d1 rule"
			)
		_final_guard(base_restored)


func _tamper(data: Dictionary) -> void:
	for field: String in [
		"old_envelope",
		"career22",
		"human41",
		"human_rule",
		"human_market",
		"missing_rule",
		"ai41",
		"ai_rule",
		"ai_market",
		"extra_ai",
		"missing_ai",
		"policy",
		"ordinal",
		"selection",
		"explicit",
		"final_version",
		"missing_physical"
	]:
		var bad: Dictionary = data.duplicate(true)
		match field:
			"old_envelope":
				bad.version = 63
			"career22":
				bad.career.version = 22
			"human41":
				bad.build.version = 41
			"human_rule":
				bad.build.pricing_rule = "retuned"
			"human_market":
				bad.build.market = 12
			"missing_rule":
				bad.build.erase("pricing_rule")
			"ai41":
				bad.opponents.clubs["1"].build.version = 41
			"ai_rule":
				bad.opponents.clubs["1"].build.pricing_rule = "retuned"
			"ai_market":
				bad.opponents.clubs["1"].build.market = 11
			"extra_ai":
				bad.opponents.clubs["6"] = bad.opponents.clubs["1"].duplicate(true)
			"missing_ai":
				bad.opponents.clubs.erase("1")
			"policy":
				bad.opponents.policy = 12
			"ordinal":
				bad.npc_venues.venue_ordinal = 0
			"selection":
				bad.final_venue.selection = SeasonFinalVenue.STANDARD_BASE_SELECTION
			"explicit":
				bad.final_venue.selection = SeasonFinalVenue.SELECTION
			"final_version":
				bad.final_venue.version = 3
			"missing_physical":
				bad.erase("physical")
		_check(SeasonSave._decode(bad) == null, "strict68 refusal: " + field)
	for version: int in range(1, 68):
		var old: Dictionary = data.duplicate(true)
		old.version = version
		_check(SeasonSave._decode(old) == null, "new d1 context cannot enter save%d" % version)


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
		"normal Base/d1 final selection cannot bypass genuine settled-history guard"
	)
	season.final_fixture = {}
	season.phase = phase
	season.round_index = round_index


func _app_atomicity() -> void:
	var original_path: String = SeasonSave.path
	SeasonSave.path = "user://standard-d1-lifecycle-%d.json" % OS.get_process_id()
	_cleanup()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.set_process(false)
	app.season = _synthetic_completed("champion")
	var previous: SeasonState = app.season
	var before: Dictionary = previous.career.to_data()
	app.ask_progression_season(1)
	_check(
		(
			app._dialog.visible
			and app._dialog.dialog_text.contains("+1 Cash")
			and app._dialog.dialog_text.contains("36/68/99/189")
			and app._dialog.dialog_text.contains("2 Backyard, 1 Expanded, 2 Club")
			and app._dialog.dialog_text.contains("Grandstand Gardens I")
		),
		"existing confirmation discloses exact Working d1 price/reward/quota/final"
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
	for tier: int in [2, 3, 4]:
		app.begin_season(6, true, true, true, true, true, tier)
		_check(
			app.season == previous and ClubCareer.same(before, previous.career.to_data()),
			"unsupported app tier preserves live season: %d" % tier
		)
	var good_path: String = SeasonSave.path
	SeasonSave.path = good_path + "/absent/season.json"
	app.begin_season(6, true, true, true, true, true, 1)
	_check(
		app.season == previous and ClubCareer.same(before, previous.career.to_data()),
		"failed checkpoint rolls back candidate and prefix close"
	)
	SeasonSave.path = good_path
	app.begin_season(6, true, true, true, true, true, 1)
	_check(
		(
			app.season != previous
			and app.season.career.active_tier() == 1
			and app.notice.contains("Standard d1")
			and app.notice.contains("Frozen away parks")
		),
		"app commits selected d1 with frozen assignment notice before draft"
	)
	if app.season != previous:
		var saved: SeasonState = SeasonSave.restore()
		_check(saved != null and saved.build.d1_pricing_valid(), "saved d1 app candidate restores")
		var d1: SeasonState = app.season
		var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
		var rule: String = d1.build._pricing_rule
		d1.build._pricing_rule = "invalid"
		app.begin_season(8, false)
		_check(
			app.season == d1 and FileAccess.get_file_as_string(SeasonSave.path) == bytes,
			"invalid live price context cannot close history or overwrite save"
		)
		d1.build._pricing_rule = rule
		var balance: int = d1.career.balance()
		app.begin_season(8, false)
		_check(
			(
				app.season != d1
				and app.season.build == null
				and app.season.career.current == 0
				and app.season.career.balance() == balance
			),
			"d1 to existing non-progression choice preserves career without payout"
		)
		var legacy_data: Dictionary = SeasonSave.snapshot(app.season)
		_check(
			(
				legacy_data.get("version") == 68
				and legacy_data.career.version == 23
				and not legacy_data.has("build")
				and not legacy_data.has("npc_venues")
				and not legacy_data.has("opponents")
			),
			"explicit68 legacy shape has no d1 context"
		)
		var legacy: SeasonState = _roundtrip(app.season, "d1 to legacy mode")
		_check(
			legacy != null and legacy.build == null and legacy.career.balance() == balance,
			"legacy68 retains prior rewards exactly"
		)
		for field: String in ["build", "opponents", "npc_venues", "final_venue", "physical"]:
			var bad: Dictionary = legacy_data.duplicate(true)
			bad[field] = {}
			_check(SeasonSave._decode(bad) == null, "legacy68 mixed context refuses: " + field)
		var old: Dictionary = legacy_data.duplicate(true)
		old.version = 4
		_check(SeasonSave._decode(old) == null, "career23 cannot smuggle into old save4")
		app.begin_season(8, true, true, true, true, true, 0)
		_check(
			(
				app.season.build != null
				and app.season.build._format == 41
				and app.season.career.active_tier() == 0
				and app.season.career.balance() == balance
				and SeasonSave.snapshot(app.season).get("version") == 68
			),
			"Base to d1 to legacy to Base preserves history/assets and returns Base rule"
		)
	app.queue_free()
	await get_tree().process_frame
	_cleanup()
	SeasonSave.path = original_path


func _cleanup() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(SeasonSave.path + suffix):
			DirAccess.remove_absolute(SeasonSave.path + suffix)

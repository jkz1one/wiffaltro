class_name StadiumPennantRewardRebuildChecks
extends RefCounted
## Reusable source-cohort checks. Fixtures are simulated scores, never real played games.

var _checks: int = 0
var _failures: Array[String] = []
var _report: Callable


static func run(check: Callable = Callable()) -> Dictionary:
	var suite: StadiumPennantRewardRebuildChecks = StadiumPennantRewardRebuildChecks.new()
	suite._report = check
	suite._lifecycle()
	suite._legacy()
	suite._non_titles()
	return {
		"ok": suite._failures.is_empty(),
		"checks": suite._checks,
		"failures": suite._failures.duplicate()
	}


static func fixture(completed_seasons: int = 6) -> Dictionary:
	if completed_seasons < 1 or completed_seasons > 12:
		return {"ok": false, "error": "Use one to twelve simulated championship seasons."}
	var career: ClubCareer = ClubCareer.new()
	var season: SeasonState
	for index in range(completed_seasons):
		season = _new(career)
		if season == null or not _finish(season) or not career.sync(season):
			return {"ok": false, "error": "Simulated championship fixture did not validate."}
		if index + 1 < completed_seasons and not career.close(season):
			return {"ok": false, "error": "Completed fixture season could not close."}
	var validated: ClubCareer = ClubCareer.from_data(_json(career.to_data()))
	if validated == null:
		return {"ok": false, "error": "Simulated championship career did not cold-validate."}
	season.career = validated
	var ledger: ClubAssetLedger = ClubPlayers.assets(validated)
	return {
		"ok": ledger != null,
		"error": "" if ledger != null else "Missing validated ledger.",
		"season": season,
		"career": validated,
		"ledger": ledger,
		"credits": ClubPlayers.income(validated),
		"progress": StadiumCareerProgress.capture(validated),
		"pennants_authority": StadiumPennantRewards.awards(validated),
		"kind": "deterministic simulated score-only championship fixture"
	}


static func _new(career: ClubCareer) -> SeasonState:
	var season: SeasonState = SeasonState.create(51, false, true, true)
	season.career = career
	if not career.start(season):
		return null
	for pick in range(4):
		if season.offers().is_empty() or not season.choose_player(season.offers()[0]):
			return null
	return season


static func _finish(season: SeasonState, champion: bool = true) -> bool:
	for index in range(12):
		if season.phase == SeasonState.Phase.COMPLETE:
			return true
		var row: Dictionary = season.pending_fixture()
		var win: bool = champion or season.phase != SeasonState.Phase.FINAL
		var home_wins: bool = (row.home == 0) == win
		if not season.record_player_result(row.id, 0 if home_wins else 1, 1 if home_wins else 0):
			return false
	return season.phase == SeasonState.Phase.COMPLETE


static func _json(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value, "", true, true))


func _lifecycle() -> void:
	var source: Dictionary = fixture(1)
	_check(source.ok, "pennant: ordinary simulated championship fixture validates")
	if not source.ok:
		return
	var career: ClubCareer = source.career
	var season: SeasonState = source.season
	var ledger: ClubAssetLedger = source.ledger
	var id: String = StadiumPennantRewards.key(1)
	var stock: StadiumStock = ledger.construction()
	_check(
		(
			stock.earned_count() == 1
			and stock.copies.has(id)
			and stock.copies[id].item == "ST-044"
			and stock.copies[id].paid == 0
		),
		"pennant: one free persistent ST-044 for the validated title"
	)
	_check(
		(
			ledger.view().spent == 0
			and ledger.balance() == 220
			and stock.blueprints == StadiumCatalog.STARTERS
		),
		"pennant: championship income, starter entitlement and purchase prices stay unchanged"
	)
	_check(
		not stock.quote("ST-044", 1, {"seasons": 99, "wins": 999}, "illegal-sale").ok,
		"pennant: earned identity never becomes a purchasable blueprint"
	)
	_check(
		(
			ledger.revision() == 1
			and ledger.prefix(0) != null
			and ledger.prefix(0).construction().earned_count() == 0
			and ledger.prefix(0).to_data().version == ClubAssetLedger.VERSION
		),
		"pennant: pre-award journal prefix retains old stock and old header"
	)
	_check(
		(
			ledger.view().stadium_active.obstacles.is_empty()
			and ledger.view().stadium_active.receiver == ""
			and stock.earned_count() == 1
		),
		"pennant: no host or display space is required to store the reward"
	)
	var before: Dictionary = career.to_data()
	_check(
		career.sync(season) and career.sync(season) and ClubCareer.same(before, career.to_data()),
		"pennant: duplicate completion sync neither duplicates nor repaints history"
	)
	var event: Dictionary = ledger.to_data().events[-1]
	_check(
		ledger.commit(event).replayed and ledger.revision() == 1,
		"pennant: exact reward journal replay is idempotent"
	)
	var save: Dictionary = SeasonSave.snapshot(season)
	var restored: SeasonState = SeasonSave._decode(_json(save))
	_check(
		(
			not save.is_empty()
			and restored != null
			and ClubCareer.same(restored.career.to_data(), career.to_data())
		),
		"pennant: complete normal season save envelope round-trips frozen title history"
	)
	_check(
		ClubAssetLedger.from_data(ledger.to_data(), 51, source.credits, source.progress) == null,
		"pennant: journal alone cannot manufacture championship authority"
	)
	var frozen: Dictionary = stock.copies[id].duplicate(true)
	stock.copies[id].earned.era.name = "Changed isolated view"
	_check(
		ClubCareer.same(ledger.construction().copies[id], frozen),
		"pennant: returned inventory cannot mutate ledger historical identity"
	)
	var bad: Dictionary = before.duplicate(true)
	bad.pennants.eras["1"].name = "Repainted history"
	_check(
		ClubCareer.from_data(bad) == null,
		"pennant: changed career era cannot rewrite the frozen award journal"
	)
	bad = before.duplicate(true)
	bad.assets.events[-1].earned.era.palette[0] = "ffffff"
	_check(
		ClubCareer.from_data(bad) == null,
		"pennant: altered reward payload cannot disagree with validated career era"
	)
	bad = before.duplicate(true)
	bad.runs[-1].receipt.finish = "runner_up"
	_check(
		ClubCareer.from_data(bad) == null,
		"pennant: false title receipt cannot authorize an earned instance"
	)
	bad = ledger.to_data()
	bad.version = ClubAssetLedger.VERSION
	bad.erase("pennant_catalog")
	_check(
		(
			ClubAssetLedger.from_data(
				bad, 51, source.credits, source.progress, source.pennants_authority
			)
			== null
		),
		"pennant: legacy journal cannot hide reward events"
	)
	for field: String in ["paid", "key", "number", "version", "crest"]:
		bad = ledger.construction().to_data()
		match field:
			"paid":
				bad.copies[id].paid = 1
			"key":
				bad.copies["another"] = bad.copies[id]
				bad.copies.erase(id)
			"number":
				bad.copies[id].earned.season_number = 2
			"version":
				bad.version = StadiumStock.VERSION
			"crest":
				bad.copies[id].earned.era.crest = "missing.crest"
		_check(StadiumStock.from_data(bad) == null, "pennant: reject malformed stock " + field)
	_check(career.close(season), "pennant: completed title can close normally")
	var next: SeasonState = _new(career)
	_check(next != null, "pennant: ordinary next season adopts the reward contract")
	if next == null:
		return
	career._pennants.eras["2"].name = "Later Club Era"
	career._pennants.eras["2"].palette = ["2468ac", "f0e0d0"]
	_check(_finish(next) and career.sync(next), "pennant: second distinct season validates")
	ledger = ClubPlayers.assets(career)
	_check(
		(
			ledger != null
			and ledger.construction().earned_count() == 2
			and ClubCareer.same(ledger.construction().copies[id], frozen)
			and (
				ledger.construction().copies[StadiumPennantRewards.key(2)].earned.era.name
				== "Later Club Era"
			)
		),
		"pennant: repeat same-seed title creates a second item without recoloring the first"
	)
	_check(
		ledger != null and ledger.prefix(1).construction().earned_count() == 1,
		"pennant: second reward never leaks into the first title's journal prefix"
	)
	_check(
		ClubCareer.from_data(_json(career.to_data())) != null,
		"pennant: multiple distinct historical eras cold-validate"
	)


func _legacy() -> void:
	var legacy: SeasonState = _new(ClubCareer.new())
	_check(legacy != null, "pennant: legacy-control season starts")
	if legacy == null:
		return
	# An existing save has no era provenance. Loading it does not invent that provenance.
	var old: Dictionary = legacy.career.to_data()
	old.erase("pennants")
	legacy.career = ClubCareer.from_data(old)
	_check(
		legacy.career != null and legacy.career._pennants.is_empty(),
		"pennant: old active career remains unadopted on reload"
	)
	if legacy.career == null:
		return
	_check(
		(
			_finish(legacy)
			and legacy.career.sync(legacy)
			and ClubPlayers.assets(legacy.career).construction().earned_count() == 0
		),
		"pennant: legacy completion creates no invented championship-era backfill"
	)
	var career: ClubCareer = legacy.career
	_check(career.close(legacy), "pennant: legacy season closes normally")
	var next: SeasonState = _new(career)
	_check(
		next != null and career._pennants.from_season == 2,
		"pennant: prospective adoption begins only at the ordinary next-season boundary"
	)
	if next == null:
		return
	_check(_finish(next) and career.sync(next), "pennant: first adopted title completes")
	var ledger: ClubAssetLedger = ClubPlayers.assets(career)
	_check(
		(
			ledger != null
			and ledger.construction().earned_count() == 1
			and ledger.construction().copies.has(StadiumPennantRewards.key(2))
			and not ledger.construction().copies.has(StadiumPennantRewards.key(1))
		),
		"pennant: new title earned while older identity-free title stays untouched"
	)


func _non_titles() -> void:
	var active: SeasonState = _new(ClubCareer.new())
	_check(
		active != null and ClubPlayers.assets(active.career).construction().earned_count() == 0,
		"pennant: active season receives no achievement"
	)
	if active == null:
		return
	_check(
		(
			active.career.close(active)
			and ClubPlayers.assets(active.career).construction().earned_count() == 0
		),
		"pennant: abandonment receives no achievement"
	)
	var runner: SeasonState = _new(ClubCareer.new())
	_check(
		(
			runner != null
			and _finish(runner, false)
			and runner.career.sync(runner)
			and runner.career.runs[-1].receipt.finish == "runner_up"
			and ClubPlayers.assets(runner.career).construction().earned_count() == 0
		),
		"pennant: completed runner-up season receives no championship reward"
	)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)
	if _report.is_valid():
		_report.call(ok, label)

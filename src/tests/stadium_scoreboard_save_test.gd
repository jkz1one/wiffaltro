extends "res://src/tests/club_career_test.gd"
## Actual career-backed storage and failure/retry; no new physical layout/shop activation.


func _ready() -> void:
	SeasonSave.path = "user://scoreboard-save-%d.json" % OS.get_process_id()
	var season: SeasonState = _fund_boards()
	var expected_stock: Dictionary = _funded_copies(season)
	var expected_boards: Dictionary = {}
	var path: String = SeasonSave.path
	for id: String in StadiumScoreboardCatalog.IDS:
		var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
		var request: Dictionary = _request(season, id)
		var saved: Dictionary = SeasonSave.snapshot(season)
		var bytes: String = FileAccess.get_file_as_string(path)
		var backup: String = FileAccess.get_file_as_string(path + ".bak")
		var price: Dictionary = ledger.preview(request)
		_check(price.ok, "earned synthetic history qualifies the actual paid transaction")
		SeasonSave.path = path + "/missing/file.json"
		_check(not ClubPlayers.transact(season, request).ok,
			"failed write does not publish a purchased board")
		_check(ClubCareer.same(saved, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(path) == bytes
			and FileAccess.get_file_as_string(path + ".bak") == backup,
			"write failure preserves career, wallet, primary and backup")
		SeasonSave.path = path
		_check(ClubPlayers.transact(season, request).ok
			and ClubPlayers.assets(season.career).balance() == ledger.balance() - price.price,
			"same request can retry successfully after failed persistence")
		var copy: Dictionary = {"item": id,
			"paid": int(StadiumScoreboardCatalog.item(id).copy_price),
			"source": "purchase-v1"}
		if id == StadiumScoreboardCatalog.ELECTRONIC:
			copy.source = "purchase-scoreboard-v1"
			expected_boards["scoreboard:%s:0" % request.id] = copy
		else:
			expected_stock["purchase:%s:0" % request.id] = copy
		var paid: Dictionary = SeasonSave.snapshot(season)
		_check(ClubPlayers.transact(season, request).replayed
			and ClubCareer.same(paid, SeasonSave.snapshot(season)),
			"successful duplicate does not charge or mint another copy")
		var loaded: SeasonState = SeasonSave.restore()
		_check(loaded != null and ClubCareer.same(paid, SeasonSave.snapshot(loaded)),
			"saved ownership and money restore exactly")
		season = loaded
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(ClubCareer.same(ledger.construction().copies, expected_stock)
		and ClubCareer.same(ledger.scoreboards().copies, expected_boards),
		"exact paid boards restore with unchanged starter copies and earned title pennants")
	_check(ledger.view().stadium_active.version == 1,
		"buying stored boards does not silently change active field or model")
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard save passed: actual career payment, failed-write retry and restore.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund_boards() -> SeasonState:
	var season: SeasonState = _new(731)
	for index in range(22):
		_finish(season, "champion")
		_check(SeasonSave.save(season), "synthetic scheduled season earns its ordinary receipt")
		if index < 21:
			var club: ClubCareer = season.career.fork()
			_check(club.close(season), "completed proof survives next season")
			season = _new(732 + index, club)
	return season


func _request(season: SeasonState, id: String) -> Dictionary:
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	return {"id": "scoreboard-save-%d" % ledger.revision(), "rev": ledger.revision(),
		"op": "stadium_scoreboard", "item": id, "quantity": 1,
		"price_version": StadiumScoreboardPurchases.VERSION,
		"through": ClubPlayers.income_through(season.career),
		"progress_through": StadiumCareerProgress.capture(season.career).size()}


func _funded_copies(season: SeasonState) -> Dictionary:
	# Funding wins titles: their earned copies are separate from purchased scoreboards.
	var expected: Dictionary = {}
	for id: String in ["ST-001", "ST-003", "ST-079"]:
		expected["starter-v1:" + id] = {"item": id, "paid": 0, "source": "starter-v1"}
	var awards: Dictionary = StadiumPennantRewards.awards(season.career)
	_check(awards.size() == 22, "funding earns exactly one pennant per championship season")
	for season_id in range(1, 23):
		var key: String = "championship-v1:%d" % season_id
		var record: Dictionary = awards.get(key, {})
		_check(StadiumPennantRewards.valid_record(record)
			and record.get("season_id") == season_id,
			"funding pennant retains its validated championship provenance: " + key)
		expected[key] = {"item": "ST-044", "paid": 0,
			"source": "championship-v1", "earned": record.duplicate(true)}
	_check(ClubCareer.same(ClubPlayers.assets(season.career).construction().copies, expected)
		and ClubPlayers.assets(season.career).scoreboards().copies.is_empty(),
		"funding stores only the three original starters and 22 earned pennants, no paid boards")
	return expected

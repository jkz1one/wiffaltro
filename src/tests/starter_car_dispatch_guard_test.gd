extends Node
## Negative guard only: a non-pending home fixture must not acquire paid owner authority.
var _checks: int = 0
var _failures: int = 0
var _app: SeasonApp


func _check(ok: bool, label: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		print("STARTER_CAR_DISPATCH_GUARD_FAILURE " + label)
	return ok


func _frames() -> void:
	for frame in range(12):
		await get_tree().process_frame


func _ready() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://src/presentation/season/season_app.gd"
	)
	var pieces: PackedStringArray = source.split("func _mounted_match_ledger(", false)
	if not _check(pieces.size() == 2, "owner helper uniquely present"):
		await _finish()
		return
	var body: String = pieces[1].split("\n\nfunc finish_game()", false)[0]
	_check(
		body.sha256_text() == "207eb82f807d86607cb922ed7dd87af527fc1a3d5b43bb4e4288ed7470a08ed9",
		"original owner-helper body byte-identical"
	)
	SeasonSave.path = "user://starter-car-dispatch-guard-%d.json" % OS.get_process_id()
	for suffix: String in ["", ".bak", ".tmp"]:
		if not _check(
			not FileAccess.file_exists(SeasonSave.path + suffix), "isolated fresh save " + suffix
		):
			await _finish()
			return
	_app = SeasonApp.new()
	add_child(_app)
	await _frames()
	_app.begin_season(175, true, true, true, true, true)
	var season: SeasonState = _app.season
	if not _check(season != null and season.career != null, "authentic public pristine entry"):
		await _finish()
		return
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	if not _check(ledger != null, "pristine ledger valid"):
		await _finish()
		return
	await _exercise(season, ledger)


func _exercise(season: SeasonState, ledger: ClubAssetLedger) -> void:
	_check(
		(
			ledger.balance() == 0
			and ledger.revision() == 0
			and ClubAssetLedger._fixed_salvage_present(season.home_property.get("layout", {}))
		),
		"unfunded untouched starter car"
	)
	for index in range(4):
		if not _check(not season.offers().is_empty(), "actual draft offer"):
			await _finish()
			return
		_app.choose_player(season.offers()[0])
		if not _check(season.picks.size() == index + 1, "actual draft pick accepted"):
			await _finish()
			return
	var fixture: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.home == 0:
			fixture = row.duplicate(true)
			break
	if not _check(
		not fixture.is_empty() and season.pending_fixture().get("home", -1) != 0,
		"non-pending home operand and genuine away pending fixture"
	):
		await _finish()
		return
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	if not _check(state != null, "real scheduled home match operand"):
		await _finish()
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var pending: Dictionary = season.pending_fixture().duplicate(true)
	var fixture_id: int = _app._fixture_id
	_check(_app.lab == null, "no preexisting match allocation")
	_check(
		_app._mounted_match_ledger(state, true, true) == null,
		"unchanged owner helper rejects wrong pending fixture"
	)
	_app._open_match(state, true, true)
	await _frames()
	_check(
		_app.lab == null and _app.find_children("ActiveMatch", "", true, false).is_empty(),
		"dispatch refuses before managed lab allocation"
	)
	_check(
		_app.notice == "This home fixture does not match its paid field. Your season is unchanged.",
		"exact paid-fixture refusal rather than late installation failure"
	)
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and bytes == FileAccess.get_file_as_string(SeasonSave.path)
		),
		"state and saved bytes unchanged"
	)
	_check(
		ClubCareer.same(pending, season.pending_fixture()) and _app._fixture_id == fixture_id,
		"pending fixture and app authority unchanged"
	)
	await _finish()


func _finish() -> void:
	if is_instance_valid(_app):
		if is_instance_valid(_app.lab):
			_app._close_match()
		_app.queue_free()
		await _frames()
	print(
		(
			"STARTER_CAR_DISPATCH_GUARD_RESULT "
			+ JSON.stringify(
				{
					"checks": _checks,
					"failures": _failures,
					"positive_startup_qualified": false,
					"completed_games": 0,
					"synthetic_funding": false
				}
			)
		)
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

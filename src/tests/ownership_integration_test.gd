extends Node

var _failures: int = 0
var _path: String


func _ready() -> void:
	_path = "user://ownership-integration-%d.json" % OS.get_process_id()
	SeasonSave.path = _path
	_season_income()
	_journal_files()
	await _lab_preview()
	await _failed_save_retry()
	for suffix in ["", ".bak", ".tmp", ".lab", ".lab.bak", ".lab.tmp"]:
		DirAccess.remove_absolute(_path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro ownership integration checks passed: income, migration, UI and retry.")
	get_tree().quit(0 if _failures == 0 else 1)


func _draft() -> SeasonState:
	var result: SeasonState = SeasonState.create(731)
	for index in range(4):
		result.choose_player(result.offers()[0])
	return result


func _season_income() -> void:
	var season: SeasonState = _draft()
	_check(season.ownership.cash() == 0, "zero starting Season Cash")
	var expected: int = 0
	for win in [true, false, true]:
		var fixture: Dictionary = season.pending_fixture()
		var home_win: bool = (fixture.home == 0) == win
		_check(
			season.record_player_result(fixture.id, 1 if home_win else 6, 6 if home_win else 1),
			"valid fixture pays"
		)
		expected += 18 if win else 12
		_check(season.ownership.cash() == expected, "Working win/loss income")
		_check(not season.record_player_result(fixture.id, 1, 6), "duplicate result rejects")
		_check(season.ownership.cash() == expected, "duplicate result cannot pay twice")
		_check(SeasonSave.save(season), "schema4 save")
		var restored: SeasonState = SeasonSave.restore()
		_check(restored != null and restored.ownership.cash() == expected, "save/reload balance")
	var original: String = FileAccess.get_file_as_string(_path)
	var data: Dictionary = JSON.parse_string(original)
	for version in [2, 3]:
		var legacy: Dictionary = data.duplicate(true)
		legacy.version = version
		legacy.erase("ownership")
		var restored: SeasonState = SeasonSave._decode(legacy)
		_check(
			restored != null and restored.ownership.cash() == expected,
			"legacy score history reconstructs base income without writing the original"
		)
	_check(FileAccess.get_file_as_string(_path) == original, "migration read preserves source")
	var changed: Dictionary = data.duplicate(true)
	changed.ownership.events[0].win = not changed.ownership.events[0].win
	_check(SeasonSave._decode(changed) == null, "reward journal must match actual results")
	changed = data.duplicate(true)
	changed["spare_gear"] = ["unknown.old.item"]
	_check(SeasonSave._decode(changed) == null, "unknown legacy ownership requires migration")
	changed = data.duplicate(true)
	changed.version = 3
	_check(SeasonSave._decode(changed) == null, "version downgrade cannot discard ownership")
	season.ownership.commit(
		{
			"id": "invented",
			"rev": season.ownership.revision(),
			"op": "reward",
			"game": 32,
			"win": true
		}
	)
	_check(not SeasonSave.save(season), "invalid in-memory reward cannot replace save")
	_check(FileAccess.get_file_as_string(_path) == original, "failed validation keeps save bytes")


func _journal_files() -> void:
	var catalog: Dictionary = OwnershipFixtures.catalog()
	var bank: SeasonOwnership = SeasonOwnership.new(catalog)
	bank.commit(OwnershipFixtures.request(bank, "reward", {"game": 0, "win": true}))
	bank.commit(OwnershipFixtures.request(bank, "stock", {"offers": {"bat": "fixture.bat6"}}))
	_check(SeasonOwnershipStore.save(bank, _path + ".lab", catalog), "isolated journal save")
	var purchase: Dictionary = OwnershipFixtures.buy(bank, "bat")
	bank.commit(purchase)
	_check(SeasonOwnershipStore.save(bank, _path + ".lab", catalog), "journal atomic replacement")
	var restored: SeasonOwnership = SeasonOwnershipStore.restore(_path + ".lab", catalog)
	_check(
		restored != null and restored.view() == bank.view(), "owned receipt survives file reload"
	)
	if restored != null:
		_check(
			restored.commit(purchase).replayed and restored.cash() == 12,
			"loaded request identity cannot repeat payment"
		)
	var file: FileAccess = FileAccess.open(_path + ".lab", FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	restored = SeasonOwnershipStore.restore(_path + ".lab", catalog)
	_check(restored != null and restored.cash() == 18, "recover valid backup checkpoint")
	_check(FileAccess.get_file_as_string(_path + ".lab") == "broken", "corrupt primary preserved")
	DirAccess.remove_absolute(_path + ".lab.bak")
	_check(
		SeasonOwnershipStore.restore(_path + ".lab", catalog) == null,
		"invalid journal never becomes an empty successful load"
	)


func _lab_preview() -> void:
	var original: String = FileAccess.get_file_as_string(_path)
	var lab: OwnershipLab = OwnershipLab.new()
	lab.save_path = _path + ".lab"
	add_child(lab)
	lab.popup_centered()
	await get_tree().process_frame
	var command: Dictionary = OwnershipFixtures.buy(lab.bank, "bat6")
	lab._preview(command)
	_check(lab.bank.cash() == 18 and lab._confirm.visible, "preview does not charge")
	lab._confirm.canceled.emit()
	lab._confirm.hide()
	_check(lab.bank.cash() == 18 and lab._pending.is_empty(), "cancel preserves test funds")
	lab._preview(command)
	lab._confirm.confirmed.emit()
	lab._confirm.hide()
	_check(lab.bank.cash() == 12, "confirm purchases once")
	lab._save()
	lab._reset()
	lab._restore()
	_check(lab.bank.cash() == 12, "screen reload restores actual receipt journal")
	_check(FileAccess.get_file_as_string(_path) == original, "lab never touches season save")
	lab.queue_free()
	await get_tree().process_frame


func _failed_save_retry() -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	app.season = _draft()
	var fixture: Dictionary = app.season.pending_fixture()
	var lab: PitchBatLab = PitchBatLab.new()
	lab._match_state = app.season.make_match()
	lab._match_state.home_team.runs = 1
	lab._match_state.away_team.runs = 0
	app.lab = lab
	app._season_game = true
	app._fixture_id = fixture.id
	_check(not app._commit_result(), "unfinished match cannot settle income")
	lab._match_state.phase = MatchState.Phase.GAME_END
	# State-flow fixture only; no physical match or performance evidence is claimed.
	SeasonSave.path = "user://nonexistent-dir-%d/save.json" % OS.get_process_id()
	_check(not app._commit_result(), "failed disk write blocks completion")
	var paid: int = app.season.ownership.cash()
	_check(app._result_recorded and not app._result_saved, "recorded and persisted are distinct")
	_check(app._continue.text == "RETRY SAVE", "failed persistence offers an explicit retry")
	SeasonSave.path = _path
	_check(app._commit_result(), "retry can persist recorded result")
	_check(
		app.season.player_results.size() == 1 and app.season.ownership.cash() == paid,
		"retry never repeats result or payment"
	)
	_check(SeasonSave.restore().ownership.cash() == paid, "retry result survives reload")
	app.lab = null
	lab.free()
	app.queue_free()
	await get_tree().process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

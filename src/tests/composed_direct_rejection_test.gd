extends "res://src/tests/starter_car_dispatch_guard_test.gd"
## Direct isolated lab rejection; exercises cleanup independently of earlier SeasonApp refusal.


func _exercise(season: SeasonState, ledger: ClubAssetLedger) -> void:
	_check(ledger.balance() == 0 and ledger.revision() == 0, "untouched unfunded club")
	for index in range(4):
		_app.choose_player(season.offers()[0])
		_check(season.picks.size() == index + 1, "ordinary draft pick")
	var fixture: Dictionary = {}
	for row: Dictionary in season.schedule:
		if row.home == 0:
			fixture = row.duplicate(true)
			break
	if not _check(
		not fixture.is_empty() and season.pending_fixture().home != 0,
		"real home operand is not current pending fixture"
	):
		await _finish()
		return
	var before: Dictionary = SeasonSave.snapshot(season)
	var saved: String = FileAccess.get_file_as_string(SeasonSave.path)
	await _frames()
	var rows: Array[Dictionary] = []
	for attempt in range(3):
		var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
		_check(
			state != null and _app._mounted_match_ledger(state, true, true) == null,
			"original helper refuses unearned current-home authority"
		)
		var count: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		var refused: PitchBatLab = PitchBatLab.new()
		refused._configured_match = state
		refused._field_id = PitchBatLab.FIELD_ID
		add_child(refused)
		_check(not refused.has_meta("stadium_property"), "unowned property never attached")
		refused.free()
		await _frames()
		var after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
		rows.append({"attempt": attempt, "before": count, "after": after, "delta": after - count})
		_check(_app.lab == null, "app remains uninvolved in standalone rejection")

		_check(after == count, "rejected installation leaves no orphan nodes")
		_check(
			(
				ClubCareer.same(before, SeasonSave.snapshot(season))
				and FileAccess.get_file_as_string(SeasonSave.path) == saved
			),
			"saved season and current authority unchanged"
		)
	print("COMPOSED_DIRECT_REJECTION_ORPHANS " + JSON.stringify(rows))
	await _finish()

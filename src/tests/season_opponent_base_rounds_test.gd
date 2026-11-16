extends "res://src/tests/season_opponent_recovery_visible_test.gd"
# Historical full-roster fixture; permanent-player defaults have separate integration tests.
## Two complete physical rounds and exact policy13 save/restart/round replay.


func _ready() -> void:
	SeasonSave.path = "user://base-rounds-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://base-rounds-%d.cfg" % OS.get_process_id()
	_app = SeasonApp.new()
	add_child(_app)
	await get_tree().process_frame
	_app.begin_season(443, true, false)
	_app.season.opponents._format = 13 # Explicit new-policy integration before default rollout.
	_check(SeasonSave.save(_app.season), "policy13 partial draft saves as57")
	for pick in range(4):
		_app.choose_player(_app.season.offers()[0])
	for round_number in range(2):
		var fixture: Dictionary = _app.season.pending_fixture()
		var report: Dictionary = await _human_report(_app.season, fixture)
		if report.is_empty():
			break
		var row: Dictionary = _opponent_row(report, fixture)
		var before: Dictionary = SeasonSave.snapshot(_app.season)
		var bad: Dictionary = row.duplicate(true)
		bad.base.final.away += 1
		var fork: SeasonState = SeasonSave._decode(before)
		fork.physical.projecting = true
		_check(not fork.record_player_result(fixture.id, report.away_runs, report.home_runs,
			report.performance, [], [], {}, [], [], {}, {}, [], bad), "changed score proof rejects")
		_check(ClubCareer.same(before, SeasonSave.snapshot(_app.season)),
			"failed proposal changes no owner")
		_app.round_ui.begin([fixture.id, report.away_runs, report.home_runs, report.performance,
			[], [], {}, [], [], {}, {}, [], row])
		await _wait_sponsor_round()
		if _app.season.player_results.size() != round_number + 1:
			var projection: Dictionary = SeasonRoundSettlement.project(_app.season)
			print("BASE_ROUND_PROJECTION ", projection.keys(), " ", projection.get("error", ""))
			break
		_audit_season()
		var snapshot: Dictionary = SeasonSave.snapshot(_app.season)
		_check(snapshot.version == 57, "completed policy13 keeps save57")
		bad = snapshot.duplicate(true)
		var key: String = bad.results[-1].ai_tactics.keys()[0]
		bad.results[-1].ai_tactics[key].base.ready[0].away += 1
		_check(SeasonSave._decode(bad) == null, "altered saved occupancy readiness rejects")
		print("NPC_BASE_ROUND ", round_number + 1, " saved_bytes=",
			FileAccess.get_file_as_bytes(SeasonSave.path).size())
	_check(_app.season.player_results.size() == 2 and _app.season.physical.reports.size() == 4,
		"two exact physical rounds settle six real games")
	_app.queue_free()
	await get_tree().process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro opponent Base round checks passed: six games and exact save57 replay.")
	get_tree().quit(0 if _failures == 0 else 1)


func _opponent_row(report: Dictionary, fixture: Dictionary) -> Dictionary:
	return PhysicalBaseEvidence.enriched(report.tactics.teams[0 if fixture.home == 0 else 1],
		report.tactics.base)

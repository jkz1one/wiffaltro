extends Node
var _checks: int = 0
var _failures: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(label)


func _read(path: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(data is Dictionary, "actual retained evidence exists " + path)
	return data if data is Dictionary else {}


func _ready() -> void:
	var root: String = OS.get_environment("LINEUP_EVIDENCE")
	var baseline: bool = OS.get_environment("EXPECT_BASELINE_REJECTION") == "1"
	var sources: Array[String] = [
		"plaque-evidence/season-3593/projected-3.json", "save57-evidence/completed-save57.json"
	]
	for source: String in sources:
		var original: Dictionary = _read(root.path_join(source))
		if original.is_empty():
			continue
		var before: String = JSON.stringify(original, "", true, true)
		var cold: SeasonState = SeasonSave._decode(original)
		_check(
			(cold == null) == baseline,
			"baseline rejects / candidate accepts genuine reordered " + source
		)
		_check(
			before == JSON.stringify(original, "", true, true),
			"decode never edits original evidence"
		)
		if cold != null:
			_check(
				cold.player_results.size() == 1 and cold.results.size() == 3,
				"actual first round survives"
			)
			_check(
				ClubCareer.same(SeasonSave.snapshot(cold), original),
				"exact snapshot roundtrip retains receipts and evidence"
			)
			SeasonSave.path = "user://lineup-replay-%d.json" % int(original.version)
			_check(SeasonSave.save(cold), "durable primary writes actual reordered save")
			var primary: String = FileAccess.get_file_as_string(SeasonSave.path)
			var restored: SeasonState = SeasonSave.restore()
			_check(
				restored != null and ClubCareer.same(SeasonSave.snapshot(restored), original),
				"fresh disk parse retains progress without backup fallback"
			)
			_check(
				primary == FileAccess.get_file_as_string(SeasonSave.path),
				"restore does not rewrite primary"
			)
		var key: String = original.results[0].ai_tactics.keys()[0]
		for mutation: String in [
			"duplicate",
			"foreign",
			"missing",
			"wrong_type",
			"wrong_order",
			"stance",
			"score",
			"performance"
		]:
			var bad: Dictionary = original.duplicate(true)
			var row: Dictionary = bad.results[0].ai_tactics[key]
			match mutation:
				"duplicate":
					row.opposition.roster[1] = row.opposition.roster[0]
				"foreign":
					row.opposition.roster[0] = "player.missing"
				"missing":
					row.erase("opposition")
				"wrong_type":
					row.opposition.roster = {"not": "an array"}
				"wrong_order":
					row.opposition.roster.reverse()
				"stance":
					row.opposition.stances[0].player = row.opposition.roster[1]
				"score":
					bad.results[0].away_runs += 1
				"performance":
					var id: String = bad.results[0].performance.keys()[0]
					bad.results[0].performance[id].pa += 1
			_check(
				SeasonSave._decode(bad) == null,
				"exact membership and chronology reject " + mutation
			)
	var legacy: Dictionary = _read(
		root.path_join("plaque-evidence/original-two-season-origin.json")
	)
	_check(
		SeasonSave._decode(legacy) != null,
		"unchanged genuine older-format two-season source restores"
	)
	print(
		"PLAIN_LINEUP_REPLAY_RESULT checks=",
		_checks,
		" failures=",
		_failures,
		" baseline=",
		baseline
	)
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)

extends Node
var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func payload(data: Dictionary) -> Dictionary:
	var body: Dictionary = data
	while body.has("checkpoint"):
		body = body.checkpoint
	return body


func digest(value: Variant) -> String:
	return JSON.stringify(value, "", true, true).sha256_text()


func _ready() -> void:
	var input: String = ""
	var output: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):
			input = arg.trim_prefix("--input=")
		if arg.begins_with("--output="):
			output = arg.trim_prefix("--output=")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(input))
	var input_hash: String = digest(data)
	var rows: Array = []
	var start: int = Time.get_ticks_usec()
	var season: SeasonState = SeasonSave._decode(data)
	rows.append({"case": "decode", "accepted": season != null, "us": Time.get_ticks_usec() - start})
	print("STEP ", JSON.stringify(rows[-1]))
	check(season != null, "retained snapshot restores")
	if season != null:
		var before: String = digest(SeasonSave.snapshot(season))
		rows[-1]["snapshot"] = before
		check(
			ClubCareer.same(SeasonSave.snapshot(season), data), "exact retained snapshot preserved"
		)
		start = Time.get_ticks_usec()
		var projected: Dictionary = SeasonRoundSettlement.project(season)
		var projection: Dictionary = {
			"error": projected.get("error"), "fixture": projected.get("fixture")
		}
		if projected.has("candidate"):
			projection["snapshot"] = digest(SeasonSave.snapshot(projected.candidate))
		rows.append({"case": "project", "us": Time.get_ticks_usec() - start, "result": projection})
		print("STEP ", JSON.stringify(rows[-1]))
		check(not projected.has("error"), "ordinary projector accepts retained pending")
		check(digest(SeasonSave.snapshot(season)) == before, "projection leaves source unchanged")
		SeasonSave.path = "user://isolated-save.json"
		start = Time.get_ticks_usec()
		var saved: bool = SeasonSave.save(season)
		rows.append({"case": "save_new", "accepted": saved, "us": Time.get_ticks_usec() - start})
		print("STEP ", JSON.stringify(rows[-1]))
		check(saved, "new durable checkpoint")
		start = Time.get_ticks_usec()
		saved = SeasonSave.save(season)
		rows.append(
			{"case": "save_existing", "accepted": saved, "us": Time.get_ticks_usec() - start}
		)
		print("STEP ", JSON.stringify(rows[-1]))
		check(saved, "repeat save with validated backup")
		check(
			ClubCareer.same(
				JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path)), data
			),
			"saved payload exact"
		)
		check(
			ClubCareer.same(
				JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path + ".bak")), data
			),
			"backup exact"
		)
		var file: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
		file.store_string("{broken")
		file.close()
		start = Time.get_ticks_usec()
		var restored: SeasonState = SeasonSave.restore()
		rows.append(
			{
				"case": "recover_backup",
				"accepted": restored != null,
				"us": Time.get_ticks_usec() - start
			}
		)
		print("STEP ", JSON.stringify(rows[-1]))
		check(
			restored != null and ClubCareer.same(SeasonSave.snapshot(restored), data),
			"corrupt primary recovers exact backup"
		)
		check(
			digest(SeasonSave.snapshot(season)) == before,
			"save and recovery do not mutate live source"
		)
	for mode: String in ["wrong_fixture", "bad_score", "duplicate_report", "tampered_settled"]:
		var bad: Dictionary = data.duplicate(true)
		var body: Dictionary = payload(bad)
		if mode == "wrong_fixture":
			body.physical.pending.human[0] = 32
		elif mode == "bad_score":
			body.physical.pending.human[1] = -1
		elif mode == "duplicate_report":
			if body.physical.pending.reports.is_empty():
				continue
			body.physical.pending.reports.append(body.physical.pending.reports[0].duplicate(true))
		elif mode == "tampered_settled":
			if body.results.is_empty():
				continue
			body.results[0].away_runs += 1
		start = Time.get_ticks_usec()
		var invalid: SeasonState = SeasonSave._decode(bad)
		rows.append(
			{"case": mode, "accepted": invalid != null, "us": Time.get_ticks_usec() - start}
		)
		print("STEP ", JSON.stringify(rows[-1]))
		check(invalid == null, "reject " + mode)
	check(digest(data) == input_hash, "input unchanged")
	var result: Dictionary = {
		"input": input,
		"input_digest": input_hash,
		"rows": rows,
		"checks": checks,
		"failures": failures,
		"engine": Engine.get_version_info()
	}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true, true))
	file.close()
	print("SAVE_DIFFERENTIAL ", JSON.stringify(result))
	get_tree().quit(0 if failures == 0 else 1)

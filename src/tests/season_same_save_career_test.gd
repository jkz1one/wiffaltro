extends Node
## Synthetic score-only fixtures; no gameplay or performance claims.
var checks: int = 0
var failures: Array[String] = []


func check(ok: bool, label: String) -> bool:
	checks += 1
	print("SAME_SAVE_CHECK " + JSON.stringify({"ok": ok, "label": label}))
	if not ok:
		failures.append(label)
		push_error(label)
	return ok


func raw(career: ClubCareer) -> String:
	return JSON.stringify(
		[career.current, career.runs, career._assets, career._pennants, career._plaques],
		"",
		true,
		true
	)


func _ready() -> void:
	_run()
	print("SAME_SAVE_RESULT " + JSON.stringify({"checks": checks, "failures": failures}))
	get_tree().quit(0 if failures.is_empty() else 1)


func _run() -> void:
	var season: SeasonState = StadiumPennantRewardRebuildChecks._new(ClubCareer.new())
	if not check(season != null, "new ordinary score-only season"):
		return
	SeasonSave.path = "user://same-save-career-%d.json" % OS.get_process_id()
	var data: Dictionary = SeasonSave.snapshot(season)
	var decoded: SeasonState = SeasonSave._decode(data)
	if not check(decoded != null, "full cold decode remains required"):
		return
	var old_result: ClubCareer = ClubCareer.from_data(data.career)
	check(
		SeasonSave._same_save_career(data.career, decoded.career) == decoded.career,
		"exact modern validated career eligible"
	)
	check(raw(old_result) == raw(decoded.career), "reuse equals old fresh reconstruction")
	var owner: ClubCareer = season.career
	check(
		SeasonSave.save(season) and season.career != owner,
		"day save still replaces owner rather than retaining live original"
	)
	var cold: SeasonState = SeasonSave.restore()
	check(
		(
			cold != null
			and JSON.parse_string(raw(cold.career)) == JSON.parse_string(raw(season.career))
		),
		"cold replay exact after publication"
	)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var before: String = raw(season.career)
	owner = season.career
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/save.json"
	check(
		(
			not SeasonSave.save(season)
			and season.career == owner
			and raw(owner) == before
			and (
				SeasonSave.last_error
				== "Could not save season. Your current session is still available."
			)
		),
		"failed write keeps owner, values and original error"
	)
	SeasonSave.path = path
	check(
		FileAccess.get_file_as_string(path) == bytes, "failed write preserves prior durable bytes"
	)
	check(
		SeasonSave.save(season) and FileAccess.get_file_as_string(path + ".bak") == bytes,
		"retry validates and backs up exact prior checkpoint"
	)
	var bad: Dictionary = data.duplicate(true)
	bad.career.runs[-1].seed += 1
	check(SeasonSave._decode(bad) == null, "forged career seed rejected before any reuse")
	bad = data.duplicate(true)
	bad.career["wallet"] = 999
	check(SeasonSave._decode(bad) == null, "forged extra career field rejected")
	var changed: ClubCareer = decoded.career.fork()
	changed.runs[-1].seed += 1
	check(
		SeasonSave._same_save_career(data.career, changed) == null,
		"same-call proof rejects changed nested historical values"
	)
	changed = decoded.career.fork()
	changed._assets["extra"] = true
	check(
		SeasonSave._same_save_career(data.career, changed) == null,
		"same-call proof rejects changed asset backing"
	)
	for schema in range(22, 27):
		var header: Dictionary = data.career.duplicate(true)
		header.version = schema
		check(
			SeasonSave._same_save_career(header, decoded.career) == decoded.career,
			"private proof modern schema guard accepts %d after caller validation" % schema
		)
	for schema in [0, 21, 27, 999]:
		var header: Dictionary = data.career.duplicate(true)
		header.version = schema
		check(
			SeasonSave._same_save_career(header, decoded.career) == null,
			"private proof schema guard refuses %d" % schema
		)
	for field: String in ["_pennants", "_plaques"]:
		changed = decoded.career.fork()
		changed.set(field, {"forged": true})
		check(
			SeasonSave._same_save_career(data.career, changed) == null,
			"reward backing mutation refuses proof " + field
		)
	_legacy(season)
	_supported_write()
	var replacement: ClubCareer = season.career.fork()
	season.career = replacement
	check(
		SeasonSave.save(season) and season.career != replacement,
		"later owner replacement gets a fresh validation and publication"
	)
	check(SeasonSave.restore() != null, "final replaced-owner checkpoint cold-valid")


func _legacy(season: SeasonState) -> void:
	var legacy: Dictionary = SeasonSave.snapshot(season)
	legacy.career.version = 21
	legacy.career.erase("assets")
	legacy.career.erase("pennants")
	legacy.career.erase("plaques")
	for row: Dictionary in legacy.career.runs:
		row.erase("player_progress")
	var recovered: SeasonState = SeasonSave._decode(legacy)
	if not check(recovered != null, "legacy21 remains cold-readable"):
		return
	var old_result: ClubCareer = ClubCareer.from_data(legacy.career)
	check(
		(
			old_result.runs[-1].player_progress == null
			and recovered.career.runs[-1].player_progress != null
		),
		"legacy decode still recovers current progress beyond raw career replay"
	)
	check(
		SeasonSave._same_save_career(legacy.career, recovered.career) == null,
		"legacy recovery cannot take modern reuse branch"
	)
	check(
		SeasonSave.save(recovered) and SeasonSave.restore() != null,
		"recovered legacy season still resaves and cold-replays"
	)


func _supported_write() -> void:
	var fixture: Dictionary = StadiumPennantRewardRebuildChecks.fixture(1)
	if not check(fixture.ok, "one synthetic championship funds writer test"):
		return
	var season: SeasonState = fixture.season
	var before: Dictionary = SeasonSave.snapshot(season)
	var paid: ClubAssetLedger = ClubPlayers.assets(season.career)
	var generation: int = paid.mutation_generation()
	var event: Dictionary = {
		"id": "same-save-wall",
		"rev": paid.revision(),
		"op": "stadium_draft",
		"layout": paid.view().stadium_active
	}
	var applied: Dictionary = paid.commit(event)
	if not check(
		applied.ok and paid.mutation_generation() != generation,
		"supported paid write advances its generation"
	):
		return
	season.career._assets = paid.to_data()
	check(
		SeasonSave._same_save_career(before.career, season.career) == null,
		"paid mutation is not equivalent to prior save proof"
	)
	check(SeasonSave.save(season), "new paid input fully revalidates on next save")
	var cold: SeasonState = SeasonSave.restore()
	check(
		(
			cold != null
			and JSON.parse_string(raw(cold.career)) == JSON.parse_string(raw(season.career))
		),
		"supported paid write cold-replays exactly"
	)

extends Node
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("OWNER_HISTORY ", ok, " ", label)
func _ready() -> void:
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--owner-history-file="): path = arg.trim_prefix("--owner-history-file=")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		get_tree().quit(2)
		return
	var authority: Dictionary = value.owner.career
	var grant: Dictionary = Grant.capture(authority)
	check(grant.get("version") == 3 and grant.get("history", {}).get("version") == 28, "explicit owner history grant")
	if grant.is_empty():
		get_tree().quit(1)
		return
	check(not Grant.qualify(grant, authority).is_empty(), "exact authority qualifies")
	check(not Grant._claim(JSON.parse_string(JSON.stringify(grant, "", true, true))).is_empty(), "cold claim")
	check(ClubCareer.from_data(grant.history) == null, "ordinary parser rejects28")
	var legacy: Dictionary = grant.history.duplicate(true)
	legacy.version = 27
	check(ClubCareer.from_data(legacy) == null, "ordinary27 rejects session-bearing rows")
	for version in [2, 3.5, 4]:
		var bad: Dictionary = grant.duplicate(true)
		bad.version = version
		check(Grant._claim(bad).is_empty(), "wrong grant version " + str(version))
	var index: int = -1
	for i in range(grant.history.runs.size()):
		if grant.history.runs[i].league == "dynasty": index = i; break
	for mutation in ["session", "owner", "seed", "tier", "receipt", "extra", "missing"]:
		var bad: Dictionary = grant.duplicate(true)
		var row: Dictionary = bad.history.runs[index]
		match mutation:
			"session": row.dynasty_session.session_id = "forged"
			"owner": row.dynasty_session.owner_id = "another-owner"
			"seed": row.seed += 1
			"tier": row.tier += 1
			"receipt": row.receipt = {"fake": true}
			"extra": row.extra = true
			"missing": row.erase("dynasty_session")
		bad.history_reference = Save.snapshot_reference(bad.history)
		check(Grant.qualify(bad, authority).is_empty(), mutation + " cannot qualify")
		if mutation != "session": check(Grant._claim(bad).is_empty(), mutation + " claim refused")
	var swapped: Dictionary = grant.duplicate(true)
	swapped.history.version = 27
	swapped.history_reference = Save.snapshot_reference(swapped.history)
	check(Grant._claim(swapped).is_empty(), "grant3 refuses history27")
	var duplicate: Dictionary = grant.history.duplicate(true)
	duplicate.runs.append(duplicate.runs[index].duplicate(true))
	duplicate.runs[-1].id = duplicate.runs.size()
	check(Grant.history_club(duplicate) == null, "duplicate Dynasty session refused")
	var no_rows: Dictionary = grant.history.duplicate(true)
	no_rows.runs = no_rows.runs.filter(func(row: Dictionary) -> bool: return row.league != "dynasty")
	check(Grant.history_club(no_rows) == null, "owner28 requires Dynasty evidence")
	print("OWNER_HISTORY_RESULT %d checks, %d failures" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

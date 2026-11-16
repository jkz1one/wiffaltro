extends "res://src/tests/dynasty_standard_qualified_reuse_test.gd"
## One new/old boundary each, same retained owner and qualified source. No writes.
var output: String = ""
var expected_revision: int = -1
func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--owner="): path = arg.trim_prefix("--owner=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--revision="): expected_revision = int(arg.trim_prefix("--revision="))
	if not path.is_absolute_path() or not output.is_absolute_path() \
		or FileAccess.file_exists(output) or FileAccess.file_exists(path + ".intent"):
		get_tree().quit(2)
		return
	var before: Dictionary = _hashes(path.get_base_dir())
	if not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(3)
		return
	var found: Dictionary = Store.inspect(path)
	if found.get("status") != "ready" or found.get("revision") != expected_revision \
		or found.owner.get("selected") != "other":
		get_tree().quit(4)
		return
	var snapshot: Dictionary = Store.read_snapshot(path, found.owner.other.reference)
	if not SeasonOwnership._whole(snapshot.get("version"), 89, 89):
		get_tree().quit(5)
		return
	var started: int = Time.get_ticks_msec()
	var season: SeasonState = Owner.validate_selected(found.owner, snapshot)
	var reused_ms: int = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	var legacy_ok: bool = _legacy_selected(found.owner, snapshot)
	var legacy_ms: int = Time.get_ticks_msec() - started
	var exact: bool = season != null and ClubCareer.same(Bound._raw(season, season._dynasty_career_session), snapshot.checkpoint)
	var unchanged: bool = ClubCareer.same(before, _hashes(path.get_base_dir()))
	var result: Dictionary = {"revision": expected_revision, "new_ms": reused_ms,
		"prior_duplicate_path_ms": legacy_ms, "new_exact": exact, "prior_accepts": legacy_ok,
		"all_owner_files_unchanged": unchanged, "physical_games": 0, "order": "new then prior; one pass each",
		"isolated_benchmark": false, "context": "Concurrent work may affect timings; same input and qualified candidate source.", "files_before": before}
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t", true, true))
	file.close()
	print("QUALIFIED_REUSE_BENCHMARK new_ms=", reused_ms, " prior_ms=", legacy_ms,
		" exact=", exact, " prior=", legacy_ok, " unchanged=", unchanged)
	get_tree().quit(0 if exact and legacy_ok and unchanged else 1)
func _hashes(root: String) -> Dictionary:
	var result: Dictionary = {}
	for name: String in DirAccess.get_files_at(root): result[name] = FileAccess.get_sha256(root.path_join(name))
	for name: String in DirAccess.get_directories_at(root): result[name] = _hashes(root.path_join(name))
	return result

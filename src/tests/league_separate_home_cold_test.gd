extends Node
## Read-only reuse of the exact completed paid fixtures; never resumes or plays a game.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok
func _ready() -> void:
	var input: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--special-home-input="): input = arg.trim_prefix("--special-home-input=")
	if not input.is_absolute_path() or not DirAccess.dir_exists_absolute(input):
		get_tree().quit(2)
		return
	var cases: int = 0
	for name: String in DirAccess.get_files_at(input):
		if not name.ends_with(".json") or name == "summary.json": continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(input.path_join(name)))
		if not check(data is Dictionary and data.get("authority") is Dictionary and data.get("snapshot") is Dictionary, name + " exact operands"): continue
		var replay: Dictionary = Live.qualify(data.snapshot, data.authority)
		if not check(not replay.is_empty(), name + " complete paid cold replay"): continue
		var season: SeasonState = replay.season
		check(ClubCareer.same(Save.snapshot_reference(data.snapshot), Save.snapshot_reference(Live.capture(season))), name + " exact reference")
		check(SeasonPhysicalFixtures.match_for(season, season.pending_fixture()) != null, name + " actual pending match")
		var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
		var field: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
		var expected: int = {14: 13, 15: 15, 17: 29, 47: 35}[int(season.home_property.layout.version)]
		check(field.get("version") == expected and field.environment.mode == "day" and field.environment.profile == ""
			and StadiumLayoutSnapshot.matches(field, season._pool_replay_ledger), name + " exact versioned future fixture")
		cases += 1
	check(cases == 5, "all five retained complete field cases")
	print("SEPARATE_HOME_COLD checks=", checks, " failures=", failures, " cases=", cases, " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)

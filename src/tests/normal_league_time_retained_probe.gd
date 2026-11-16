extends Node
## A separate cold process checks a retained authored paid25 checkpoint, no games.
func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(2)
		return
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--snapshot="): path = arg.trim_prefix("--snapshot=")
	if not path.is_absolute_path() or not FileAccess.file_exists(path):
		get_tree().quit(2)
		return
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var season: SeasonState = SeasonSave._decode(raw)
	var valid: bool = season != null and raw is Dictionary and raw.get("version") == 94
	if valid:
		valid = season.home_property.get("layout", {}).get("version") == 25 \
			and season.owned_surface_night.get("mode") == "night" \
			and load("res://src/gameplay/season/normal_league_time_candidate.gd").matches(season) \
			and ClubCareer.same(SeasonSave.snapshot(season), raw)
	print("RETAINED_TIME94_COLD ", JSON.stringify({"valid": valid, "sha256": FileAccess.get_sha256(path),
		"authored_prerequisites": true, "games": 0}))
	get_tree().quit(0 if valid else 1)

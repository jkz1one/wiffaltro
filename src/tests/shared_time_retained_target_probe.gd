extends Node
## Read the original failed96 intent/objects only. Never recover, repair or write them.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")

func _files(root: String, relative: String = "") -> Dictionary:
	var result: Dictionary = {}
	var here: String = root.path_join(relative)
	for name: String in DirAccess.get_files_at(here):
		var key: String = relative.path_join(name) if not relative.is_empty() else name
		result[key] = FileAccess.get_sha256(root.path_join(key))
	for name: String in DirAccess.get_directories_at(here):
		result.merge(_files(root, relative.path_join(name) if not relative.is_empty() else name))
	return result

func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(2)
		return
	var root: String = ""
	var manifest: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--retained-owner-root="): root = arg.trim_prefix("--retained-owner-root=")
		if arg.begins_with("--evidence-manifest="): manifest = arg.trim_prefix("--evidence-manifest=")
	if not root.is_absolute_path() or not DirAccess.dir_exists_absolute(root) \
		or not manifest.is_absolute_path() or not FileAccess.file_exists(manifest):
		get_tree().quit(2)
		return
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	var before: Dictionary = _files(root)
	if not expected is Dictionary or expected.is_empty() or not ClubCareer.same(expected, before):
		get_tree().quit(2)
		return
	var path: String = root.path_join("season.json.dynasty-owner")
	var intent: Dictionary = Store._read_intent(path)
	var facts: Dictionary = {"intent_valid": not intent.is_empty(), "target_read": false,
		"qualified": false, "exact_capture": false, "local_integer_format": false}
	if not intent.is_empty() and intent.before.is_empty() and intent.after.owner.selected == "dynasty":
		var owner: Dictionary = intent.after.owner
		var target: Dictionary = Store._read_object(path, owner.dynasty.reference)
		facts.target_read = target.get("ok", false) and target.get("snapshot", {}).get("version") == 96
		if facts.target_read:
			var season: SeasonState = Owner.validate_selected(owner, target.snapshot)
			facts.qualified = season != null
			if season != null:
				facts.exact_capture = ClubCareer.same(Save.snapshot_reference(TimeHome.capture(season)), owner.dynasty.reference)
				facts.local_integer_format = typeof(season._league_home_context.format) == TYPE_INT
	var after: Dictionary = _files(root)
	var unchanged: bool = ClubCareer.same(before, after) and ClubCareer.same(expected, after)
	var valid: bool = unchanged
	for value: Variant in facts.values(): valid = valid and value == true
	print("SHARED_TIME_RETAINED_TARGET ", JSON.stringify({"valid": valid, "facts": facts,
		"evidence_unchanged": unchanged, "before_sha256": before, "after_sha256": after,
		"writes": 0, "recovery_attempts": 0, "physical_games": 0}, "", true, true))
	get_tree().quit(0 if valid else 1)

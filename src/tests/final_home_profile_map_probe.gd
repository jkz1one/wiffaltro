extends Node
## Native literal maps only, with normal project autoloads and no owner/game input.
func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(2)
		return
	var path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map-output="): path = arg.trim_prefix("--map-output=")
	if not path.is_absolute_path() or FileAccess.file_exists(path):
		get_tree().quit(2)
		return
	var profile: GDScript = load("res://src/presentation/stadium/stadium_npc_current_source_profile.gd")
	var constants: Dictionary = profile.get_script_constant_map()
	var result: Dictionary = {}
	for name: String in ["PROFILE_ID", "REVIEW_STATUS", "BASELINE_SHA256", "REPLACEMENTS", "DEPENDENCIES"]:
		result[name] = constants.get(name)
	for name: String in ["REPLACEMENTS", "DEPENDENCIES"]:
		if not result[name] is Dictionary:
			get_tree().quit(1)
			return
		for key: Variant in result[name]:
			if typeof(key) != TYPE_STRING or typeof(result[name][key]) != TYPE_STRING:
				get_tree().quit(1)
				return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(result, "", true, true))
	file.close()
	print("FINAL_HOME_NATIVE_MAPS_EXPORTED String_keys_and_values=true games=0")
	get_tree().quit(0)

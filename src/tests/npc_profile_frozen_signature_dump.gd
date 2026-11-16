extends Node
var result: Dictionary = {}


func _ready() -> void:
	_scan("res://src/gameplay")
	for version in range(1, 33):
		result["purchase-price-" + str(version)] = StadiumPurchases.signature(version)
	result["starter-stock"] = StadiumStock.new_club().to_data()
	result["starter-layout"] = StadiumStarterLayout.empty()
	result["catalog-rows"] = StadiumCatalog.ROWS
	result["legacy-string-sites"] = var_to_str(StadiumStringLightItems.SITES)
	result["legacy-string-presets"] = StadiumStringLightItems.PRESETS
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dump-signatures="):
			output = argument.trim_prefix("--dump-signatures=")
	var file: FileAccess = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write signature fixture")
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	print("FROZEN_SIGNATURE_DUMP " + str(result.size()))
	get_tree().quit()


func _scan(root: String) -> void:
	for name: String in DirAccess.get_files_at(root):
		if not name.ends_with(".gd"):
			continue
		var path: String = root.path_join(name)
		var source: String = FileAccess.get_file_as_string(path)
		for method: String in [
			"signature",
			"price_signature",
			"grant_signature",
			"mastery_signature",
			"salvage_origin_signature"
		]:
			if source.contains("static func " + method + "() -> String:"):
				var script: GDScript = load(path)
				result[path + "::" + method] = script.call(method)
	for directory: String in DirAccess.get_directories_at(root):
		_scan(root.path_join(directory))

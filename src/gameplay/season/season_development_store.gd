class_name SeasonDevelopmentStore
extends RefCounted
## Standalone playtest checkpoint; never reads or replaces the active season save.

static var last_error: String = ""


static func save(book: SeasonDevelopment, path: String, season_key: String) -> bool:
	last_error = "The previous development checkpoint was preserved."
	if SeasonDevelopment.from_data(book.to_data(), season_key) == null:
		return false
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(book.to_data()))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return false
	if FileAccess.file_exists(path) and _read(path, season_key) != null:
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return false
	last_error = ""
	return true


static func restore(path: String, season_key: String) -> SeasonDevelopment:
	last_error = ""
	var primary: SeasonDevelopment = _read(path, season_key)
	if primary != null:
		return primary
	var backup: SeasonDevelopment = _read(path + ".bak", season_key)
	last_error = (
		"Recovered the previous test checkpoint; unreadable primary preserved."
		if backup != null
		else "No valid development snapshot. Session and files were preserved."
	)
	return backup


static func _read(path: String, season_key: String) -> SeasonDevelopment:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	if file.get_length() > 2000000:
		file.close()
		return null
	var text: String = file.get_as_text()
	file.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return SeasonDevelopment.from_data(json.data, season_key)

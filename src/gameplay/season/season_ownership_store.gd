class_name SeasonOwnershipStore
extends RefCounted
## Isolated journal persistence for the transaction lab, not a second season wallet.

static var last_error: String = ""


static func save(bank: SeasonOwnership, path: String, catalog: Dictionary) -> bool:
	if SeasonOwnership.from_data(bank.to_data(), catalog) == null:
		return false
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(bank.to_data()))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return false
	if FileAccess.file_exists(path) and _read(path, catalog) != null:
		if DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK


static func restore(path: String, catalog: Dictionary) -> SeasonOwnership:
	last_error = ""
	var primary: SeasonOwnership = _read(path, catalog)
	if primary != null:
		return primary
	var backup: SeasonOwnership = _read(path + ".bak", catalog)
	if backup != null:
		last_error = "Recovered the previous test checkpoint; unreadable primary preserved."
	else:
		last_error = "No valid test snapshot. Current session and files were preserved."
	return backup


static func _read(path: String, catalog: Dictionary) -> SeasonOwnership:
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
	return SeasonOwnership.from_data(json.data, catalog)

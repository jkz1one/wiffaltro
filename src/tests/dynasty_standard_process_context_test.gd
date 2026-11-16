extends "res://src/tests/dynasty_standard_owner_test.gd"
## Synthetic domain owner only. No physical fixtures or source qualification claim.
func _step(op: String, operands: Dictionary) -> Dictionary:
	if op == "close":
		_transport_controls()
	return super._step(op, operands)

func _transport_controls() -> void:
	print("STANDARD_PROCESS_CONTEXT begin read-only controls")
	check(SeasonSave.bind_dynasty_owner(path), "bind actual isolated owner")
	var season: SeasonState = SeasonSave.restore()
	check(season != null, "restore actual binding for transport")
	if season == null:
		return
	var input: Dictionary = PhysicalRoundProcess.request_for(season, "test-token", "test-key", 0)
	check(input.get("version") == 2, "Standard transport version2")
	if input.is_empty():
		return
	var ordinary: SeasonState = SeasonState.create(38101, false, false, false)
	var legacy: Dictionary = PhysicalRoundProcess.request_for(ordinary, "ordinary", "key", 0)
	check(legacy.get("version") == 1 and PhysicalRoundProcess.decode_request(legacy, "ordinary") != null, "ordinary version1 remains supported")
	var before: Dictionary = _files(path.get_base_dir())
	var cold: Dictionary = JSON.parse_string(JSON.stringify(input, "", true, true))
	var decoded: SeasonState = PhysicalRoundProcess.decode_request(cold, "test-token")
	check(decoded != null and ClubCareer.same(SeasonSave.snapshot(decoded), input.season), "cold transport exact selected checkpoint")
	check(decoded != null and ClubCareer.same(decoded._dynasty_owner_binding, season._dynasty_owner_binding), "binding comes from real inspected owner")
	for key: String in ["path", "owner_id", "revision", "session_id", "reference"]:
		var bad: Dictionary = cold.duplicate(true)
		if key == "revision":
			bad.owner[key] += 1
		elif key == "reference":
			bad.owner[key] = {}
		else:
			bad.owner[key] += "-wrong"
		check(PhysicalRoundProcess.decode_request(bad, "test-token") == null, "reject modified " + key)
	var bad: Dictionary = cold.duplicate(true)
	bad.season.session.session_id += "-wrong"
	check(PhysicalRoundProcess.decode_request(bad, "test-token") == null, "reject changed envelope")
	bad = cold.duplicate(true)
	bad.version = 1
	bad.erase("owner")
	check(PhysicalRoundProcess.decode_request(bad, "test-token") == null, "v1 standalone Standard refused")
	bad = cold.duplicate(true)
	bad.erase("owner")
	check(PhysicalRoundProcess.decode_request(bad, "test-token") == null, "v2 absent owner refused")
	check(PhysicalRoundProcess.decode_request(cold, "wrong-token") == null, "wrong job token refused")
	var binding: Dictionary = season._dynasty_owner_binding
	season._dynasty_owner_binding = {}
	check(PhysicalRoundProcess.request_for(season, "test", "key", 0).is_empty(), "unbound parent refused")
	season._dynasty_owner_binding = binding
	var intent: FileAccess = FileAccess.open(path + ".intent", FileAccess.WRITE)
	intent.store_string("unresolved test intent")
	intent.close()
	check(PhysicalRoundProcess.decode_request(cold, "test-token") == null, "unresolved intent refused without repair")
	check(PhysicalRoundProcess.request_for(season, "test", "key", 0).is_empty(), "parent refuses unresolved intent")
	DirAccess.remove_absolute(path + ".intent")
	check(ClubCareer.same(before, _files(path.get_base_dir())), "transport validation writes no owner files")
	print("STANDARD_PROCESS_CONTEXT controls complete")

func _files(root: String) -> Dictionary:
	var result: Dictionary = {}
	for file: String in DirAccess.get_files_at(root):
		result[file] = FileAccess.get_sha256(root.path_join(file))
	for folder: String in DirAccess.get_directories_at(root):
		result[folder] = _files(root.path_join(folder))
	return result

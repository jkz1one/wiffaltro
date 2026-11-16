extends "res://src/tests/shared_time_retained_target_probe.gd"
## Read-only selected92/95/96 worker serialization. No owner switch, recovery or game.
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
	var found: Dictionary = Store.inspect(path)
	var facts: Dictionary = {"ready_selected_owner": false, "qualified": false,
		"request": false, "cold_wire": false, "exact_reference": false, "malformed_refused": false}
	var format: int = 0
	if found.get("status") == "ready" and not FileAccess.file_exists(path + ".intent"):
		var owner: Dictionary = found.owner
		var slot: Dictionary = owner.get(owner.get("selected", ""), {})
		format = int(slot.get("snapshot_version", 0))
		facts.ready_selected_owner = Save.Owned.version_in(slot.get("snapshot_version"), [92, 95, 96])
		if facts.ready_selected_owner:
			var target: Dictionary = Store._read_object(path, slot.reference)
			var season: SeasonState = Owner.validate_selected(owner, target.snapshot) if target.get("ok", false) else null
			facts.qualified = season != null
			if season != null:
				# Derived process-local binding only, exactly as the read-only worker decoder.
				SeasonSave._dynasty_owner_path = path
				SeasonSave._bind_owner_season(season, found)
				var request: Dictionary = PhysicalRoundProcess.request_for(season, "retained-time", "read-only", 1)
				facts.request = request.get("version") == (4 if format == 92 else (6 if format == 96 else 5))
				if facts.request:
					var wire: Dictionary = JSON.parse_string(JSON.stringify(request, "", true, true))
					var decoded: SeasonState = PhysicalRoundProcess.decode_request(wire, "retained-time")
					facts.cold_wire = typeof(wire.version) == TYPE_FLOAT and typeof(wire.season.version) == TYPE_FLOAT and decoded != null
					facts.exact_reference = decoded != null and ClubCareer.same(Save.snapshot_reference(SeasonSave.snapshot(decoded)), slot.reference)
					facts.malformed_refused = true
					for field: String in ["transport", "season"]:
						var exact: int = int(wire.version if field == "transport" else wire.season.version)
						for malformed: Variant in [float(exact) + 0.5, str(exact), true]:
							var bad: Dictionary = wire.duplicate(true)
							if field == "transport": bad.version = malformed
							else: bad.season.version = malformed
							facts.malformed_refused = facts.malformed_refused and PhysicalRoundProcess.decode_request(bad, "retained-time") == null
					var cross: Dictionary = wire.duplicate(true)
					cross.version = 3.0 if format == 92 else (5.0 if format == 96 else 6.0)
					facts.malformed_refused = facts.malformed_refused and PhysicalRoundProcess.decode_request(cross, "retained-time") == null
	SeasonSave._dynasty_owner_path = ""
	var after: Dictionary = _files(root)
	var unchanged: bool = ClubCareer.same(before, after) and ClubCareer.same(expected, after)
	var valid: bool = unchanged
	for value: Variant in facts.values(): valid = valid and value == true
	print("SHARED_TIME_RETAINED_TRANSPORT ", JSON.stringify({"valid": valid, "format": format, "facts": facts,
		"evidence_unchanged": unchanged, "before_sha256": before, "after_sha256": after,
		"writes": 0, "recovery_attempts": 0, "physical_games": 0}, "", true, true))
	get_tree().quit(0 if valid else 1)

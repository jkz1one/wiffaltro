extends Node
## Isolated same-call pending-validation differential; no writes, UI, or physics jobs.
var _failures: int = 0
var _checks: int = 0
var _fixture_root: String = ""


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--fixture-root="):
			_fixture_root = argument.trim_prefix("--fixture-root=")
	_check(not _fixture_root.is_empty(), "explicit environment-local fixture root supplied")
	if _fixture_root.is_empty():
		get_tree().quit(1)
		return
	for filename: String in [
		"long-doubleheader-pending77.json",
		"owner-queued-human80.json",
		"ai-pending-2-79.json",
		"league-pending76.json"
	]:
		_fixture(filename)
	_legacy()
	_nested_metadata()
	print("PENDING_FORK_RESULT checks=%d failures=%d" % [_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _fixture(filename: String) -> void:
	var path: String = _fixture_root.path_join(filename)
	var raw: String = FileAccess.get_file_as_string(path)
	var value: Variant = JSON.parse_string(raw)
	var input_before: String = JSON.stringify(value, "", true, true)
	var source: SeasonState = SeasonSave._decode(value)
	_check(source != null, filename + " decodes")
	if source == null:
		return
	_check(not source.physical.pending.is_empty(), filename + " contains pending work")
	var before: String = _fingerprint(source)
	var fork: SeasonState = SeasonRoundSettlement._fork_replayed_league(source)
	_check(fork != null, filename + " qualifies narrow fast scope")
	if fork == null:
		return
	# Check every copied object/container before projecting, including private
	# journals and progress state not represented independently in save snapshots.
	_audit_isolation(source, fork, filename, ["physical"])
	_audit_isolation(source.physical.reports, fork.physical.reports, filename + ".reports")
	_check(
		(
			fork.physical.pending.is_empty()
			and fork.physical.needed.is_empty()
			and fork.physical.error.is_empty()
		),
		filename + " transient state reset"
	)
	var pending: Dictionary = source.physical.pending.duplicate(true)
	var fast: Dictionary = SeasonRoundSettlement._project_candidate(fork, pending)
	var old: Dictionary = SeasonRoundSettlement.project(source)
	_check(fast.keys() == old.keys(), filename + " projection result kind identical")
	_check(fast.get("error", "") == old.get("error", ""), filename + " error identical")
	_check(
		ClubCareer.same(fast.get("fixture", {}), old.get("fixture", {})),
		filename + " next fixture identical"
	)
	if fast.has("candidate") and old.has("candidate"):
		_check(
			ClubCareer.same(
				SeasonSave.snapshot(fast.candidate), SeasonSave.snapshot(old.candidate)
			),
			filename + " projected save identical"
		)
		_check(
			_fingerprint(fast.candidate.physical) == _fingerprint(old.candidate.physical),
			filename + " cursor and transient physical state identical"
		)
	_check(_fingerprint(source) == before, filename + " source raw object graph unchanged")
	_check(
		JSON.stringify(value, "", true, true) == input_before,
		filename + " parsed backing unchanged"
	)
	_check(FileAccess.get_file_as_string(path) == raw, filename + " fixture bytes unchanged")
	print("PENDING_FORK_FIXTURE_DONE " + filename)


func _legacy() -> void:
	var source: SeasonState = SeasonState.create(74123, false, true, true)
	source.opponents._format = 3
	source.physical = SeasonPhysicalFixtures.new()
	for index in range(4):
		_check(source.choose_player(source.offers()[0]), "legacy pick")
	var game: Dictionary = source.pending_fixture()
	source.physical.pending = {
		"human": [game.id, 1, 2, {}, [], [], {}, [], [], {}, {}, []], "reports": []
	}
	_check(SeasonRoundSettlement._fork_replayed_league(source) == null, "legacy outside fast scope")
	var before: String = _fingerprint(source)
	_check(
		SeasonRoundSettlement.valid_pending(source),
		"legacy fixture accepted by historical validator"
	)
	_check(
		(
			SeasonRoundSettlement._valid_pending_replayed(source)
			== SeasonRoundSettlement.valid_pending(source)
		),
		"legacy fallback agrees with historical validator"
	)
	_check(_fingerprint(source) == before, "legacy fallback unchanged")


func _nested_metadata() -> void:
	# Synthetic fork-only probe, never admitted as saved evidence. Exercise the
	# container-valued start fields even when retained fixtures use scalar starts.
	var build: SeasonBuild = SeasonBuild.new()
	for field: String in [
		"_dynasty_start",
		"_order_start",
		"_rain_start",
		"_transfer_start",
		"_checkout_start",
		"_association_start",
		"_freezer_start",
		"_sides_start",
		"_field_start",
		"_sure_start",
		"_jump_start",
		"_batch_start",
		"_supply_start"
	]:
		build.set(field, {"nested": [{"value": 17}]})
	build._abilities.start = {"nested": [1, 2]}
	build._major.start = {"nested": [1, 2]}
	build._copy.start = {"nested": [1, 2]}
	var before: String = _fingerprint(build)
	var fork: SeasonBuild = SeasonRoundSettlement._fork_build(build)
	_audit_isolation(build, fork, "synthetic metadata")
	_check(_fingerprint(build) == before, "nested metadata remains unchanged")


func _audit_isolation(source: Variant, copy: Variant, path: String, omit: Array = []) -> void:
	if source is Array:
		_check(copy is Array and not is_same(source, copy), path + " array detached")
		if not copy is Array or is_same(source, copy):
			return
		_check(source.size() == copy.size(), path + " array size")
		if not copy.is_read_only():
			var saved: Array = copy.duplicate()
			copy.clear()
			_check(source.size() == saved.size(), path + " array mutation isolated")
			copy.assign(saved)
		for index in range(mini(source.size(), copy.size())):
			_audit_isolation(source[index], copy[index], path + "[%d]" % index)
	elif source is Dictionary:
		_check(copy is Dictionary and not is_same(source, copy), path + " dictionary detached")
		if not copy is Dictionary or is_same(source, copy):
			return
		_check(source.size() == copy.size(), path + " dictionary size")
		if not copy.is_read_only():
			var saved: Dictionary = copy.duplicate()
			copy.clear()
			_check(source.size() == saved.size(), path + " dictionary mutation isolated")
			copy.merge(saved)
		for key: Variant in source:
			if copy.has(key):
				_audit_isolation(source[key], copy[key], path + "." + str(key))
	elif source is Object and not source is Resource:
		_check(copy is Object and not is_same(source, copy), path + " object detached")
		if not copy is Object or is_same(source, copy):
			return
		for property: Dictionary in source.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE and not omit.has(property.name):
				_audit_isolation(
					source.get(property.name),
					copy.get(property.name),
					path + "." + str(property.name)
				)


func _raw(value: Variant) -> Variant:
	if value is Array:
		var rows: Array = []
		for child: Variant in value:
			rows.append(_raw(child))
		return rows
	if value is Dictionary:
		var rows: Dictionary = {}
		for key: Variant in value:
			rows[str(key)] = _raw(value[key])
		return rows
	if value is Object:
		if value is Resource:
			return value.resource_path
		var rows: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				rows[str(property.name)] = _raw(value.get(property.name))
		return rows
	return value


func _fingerprint(value: Variant) -> String:
	return JSON.stringify(_raw(value), "", true, true).sha256_text()


func _check(ok: bool, description: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		printerr("PENDING_FORK_FAIL " + description)

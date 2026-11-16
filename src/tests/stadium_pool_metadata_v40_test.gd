extends Node
## Finite native metadata parity. Nodes never enter the SceneTree; no gameplay setup.
# gdlint: disable=max-returns,max-file-lines

const EXPECTED_CHECKS: int = 605
const EXPECTED_CASES: int = 155
const SUMMARY_CAP: int = 128 * 1024
const NATIVE_BYTES_CAP: int = 8192
const ALIAS_CAP: int = 32 * 1024
const ALIAS_DESCRIPTOR_CAP: int = 384
const ALIAS_PACKED_CAP: int = 64
const KEYS: Array[StringName] = [
	&"surface_id", &"surface_role", &"stadium_item", &"owned_copy", &"ball_surface",
	&"boundary_segment", &"geometry_version", &"model_id", &"placement_role",
	&"water_geometry_id", &"water_source_sha256", &"water_award_active", &"runtime_adapter",
	&"volume_id", &"volume_role", &"descriptor"
]
const IEEE: Array[Dictionary] = [
	{"label": "negative_zero", "ieee64": "0000000000000080", "variant": "0300000000000080"},
	{"label": "positive_zero", "ieee64": "0000000000000000", "variant": "0300000000000000"},
	{"label": "positive_infinity", "ieee64": "000000000000f07f", "variant": "030000000000807f"},
	{"label": "negative_infinity", "ieee64": "000000000000f0ff", "variant": "03000000000080ff"},
	{"label": "quiet_nan_payload1", "ieee64": "010000000000f87f",
		"variant": "03000100010000000000f87f"}
]

var _checks: int = 0
var _failures: int = 0
var _failed: Array[String] = []
var _output: String = ""
var _expected_runtime: String = ""
var _runtime: String = ""
var _execution: String = ""
var _nonce: String = ""
var _admitted: bool = false
var _candidate: GDScript
var _oracle: GDScript
var _cases: Array[Dictionary] = []
var _ieee: Array[Dictionary] = []
var _groups: Dictionary = {}
var _created: int = 0
var _freed: int = 0
var _physics_start: int = 0
var _physics_end: int = 0
var _alias_phases: Array[Dictionary] = []
var _alias_bytes: int = 0
var _alias_overflow: bool = false

class ScriptedNode extends Node3D:
	var fixture_tag: int = 40


func _ready() -> void:
	_physics_start = Engine.get_physics_frames()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-metadata-v40-dir="):
			_output = argument.trim_prefix("--pool-metadata-v40-dir=")
		if argument.begins_with("--pool-metadata-v40-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-metadata-v40-runtime=")
		if argument.begins_with("--pool-metadata-v40-execution="):
			_execution = argument.trim_prefix("--pool-metadata-v40-execution=")
		if argument.begins_with("--pool-metadata-v40-nonce="):
			_nonce = argument.trim_prefix("--pool-metadata-v40-nonce=")
	_run()
	_physics_end = Engine.get_physics_frames()
	_check(_physics_start == _physics_end, "no physics frame advances during synchronous unit")
	_check(_created == _freed and _created == 2 and get_child_count() == 0,
		"both disposable native nodes freed without tree attachment")
	_check(_alias_phases.size() == 8 and not _alias_overflow
		and _alias_bytes > 0 and _alias_bytes <= ALIAS_CAP, "eight bounded native alias phase records")
	_check(_checks + 1 == EXPECTED_CHECKS and _cases.size() == EXPECTED_CASES,
		"exact finite metadata assertion and case counts")
	var summary: Dictionary = {
		"version": 1, "pid": OS.get_process_id(), "runtime": _runtime,
		"execution": _execution, "nonce": _nonce,
		"checks": _checks, "expected_checks": EXPECTED_CHECKS,
		"failures": _failures, "failed": _failed,
		"status": "PASS" if _failures == 0 else "FAILED", "groups": _groups,
		"cases": _cases, "ieee": _ieee, "created": _created, "freed": _freed,
		"alias_phases": _alias_phases, "alias_bytes": _alias_bytes, "alias_overflow": _alias_overflow,
		"physics_frame_start": _physics_start, "physics_frame_end": _physics_end,
		"starts": 0, "releases": 0, "plays": 0,
		"hash_encoding": "SHA256_OF_LOWERCASE_HEX_NATIVE_BYTES",
		"getter_prefix_scope": "Exact source-order proof; native Node getters are not overridden",
		"null_scope": "Native set_meta null removes the key; no present-null claim",
		"performance_qualified": false, "production_qualified": false}
	_write(summary)
	print("POOL_METADATA_V40 checks=%d failures=%d cases=%d status=%s source=%s" % [
		_checks, _failures, _cases.size(), summary.status, _runtime])
	get_tree().quit(0 if _failures == 0 else 1)


func _run() -> void:
	if not _check(_output.is_absolute_path() and not _output.is_empty()
		and OS.get_cmdline_user_args().has("--physical-in-process"), "explicit isolated unit output"):
		return
	if not _check(DirAccess.make_dir_recursive_absolute(_output) == OK
		and DirAccess.get_files_at(_output).is_empty(), "fresh empty unit output directory"):
		return
	_admitted = true
	# Deferred resource loading preserves the established preflight/autoload lifecycle.
	_candidate = load("res://src/gameplay/stadium/stadium_pool_owned_integrity.gd") as GDScript
	_oracle = load("res://src/tests/stadium_pool_metadata_v40_oracle.gd") as GDScript
	var integrity: GDScript = load(
		"res://src/gameplay/stadium/stadium_pool_party_asset_integrity.gd") as GDScript
	if not _check(_candidate != null and _oracle != null and integrity != null
		and _candidate.can_instantiate() and _oracle.can_instantiate()
		and _candidate.has_method("_metadata") and _oracle.has_method("_metadata"),
		"deferred production and exact oracle resources are callable"):
		return
	_runtime = integrity.call("source_sha256")
	if not _check(_hex(_runtime, 64) and _runtime == _expected_runtime
		and _hex(_execution, 64) and _hex(_nonce, 32), "native source and execution identity"):
		return
	var node: Node = Node.new()
	_created += 1
	var start: int = _checks
	_scalar_controls(node)
	_groups["scalar_keys"] = _checks - start
	start = _checks
	_key_rejections(node)
	_groups["key_rejections"] = _checks - start
	start = _checks
	_descriptor_controls(node)
	_groups["descriptors"] = _checks - start
	start = _checks
	_ieee_controls(node)
	_groups["ieee"] = _checks - start
	start = _checks
	_alias_controls(node)
	_groups["aliases"] = _checks - start
	node.free()
	_freed += 1


func _scalar_controls(node: Node) -> void:
	_parity(node, "absent", 16)
	for index: int in range(KEYS.size()):
		node.set_meta(KEYS[index], _descriptor() if index == 15 else 7)
		node.set_meta(KEYS[index], null)
		_check(not node.has_meta(KEYS[index]), "native null removes key%d" % index)
		_parity(node, "null_removed_%02d" % index, 16)
	var values: Array = [false, 42, 1.25, "same", &"same"]
	for index: int in range(15):
		for value_index: int in range(values.size()):
			node.set_meta(KEYS[index], values[value_index])
			_parity(node, "scalar_%02d_%d" % [index, value_index], 16)
			node.remove_meta(KEYS[index])
	for index: int in range(15):
		node.set_meta(KEYS[index], values[index % values.size()])
	node.set_meta(&"descriptor", _descriptor())
	_parity(node, "all_keys", 16)
	_clear(node)
	var scripted: ScriptedNode = ScriptedNode.new()
	_created += 1
	scripted.set_meta(&"geometry_version", &"scripted")
	_check(scripted.get_script() != null and scripted.fixture_tag == 40,
		"actual scripted Node3D inherits native metadata methods")
	_parity(scripted, "scripted_native_node", 16)
	scripted.free()
	_freed += 1


func _key_rejections(node: Node) -> void:
	for index: int in range(KEYS.size()):
		# All later keys are also present. Source proof establishes no reads after rejection.
		for key: StringName in KEYS:
			node.set_meta(key, _descriptor() if key == &"descriptor" else 7)
		node.set_meta(KEYS[index], [])
		_parity(node, "key_reject_%02d" % index, 0)
		_clear(node)


func _descriptor_controls(node: Node) -> void:
	node.set_meta(&"descriptor", _descriptor())
	_parity(node, "descriptor_valid_types", 16)
	for size: int in [11, 13]:
		var value: Dictionary = {}
		for index: int in range(size):
			value["k%02d" % index] = true
		node.set_meta(&"descriptor", value)
		_parity(node, "descriptor_size_%d" % size, 0)
	node.set_meta(&"descriptor", true)
	_parity(node, "descriptor_not_dictionary", 0)
	for index: int in range(12):
		var bad_key: Dictionary = {}
		for item: int in range(12):
			var key: Variant = "k%02d" % item
			if item == index:
				key = StringName(key)
			bad_key[key] = true
		node.set_meta(&"descriptor", bad_key)
		_parity(node, "descriptor_key_%02d" % index, 0)
	for index: int in range(12):
		var bad_value: Dictionary = _descriptor()
		bad_value["k%02d" % index] = []
		node.set_meta(&"descriptor", bad_value)
		_parity(node, "descriptor_value_%02d" % index, 0)
	var unsupported: Array = [null, &"unsupported", {}, Vector2(1, 2), PackedByteArray(), node]
	for index: int in range(unsupported.size()):
		var value: Dictionary = _descriptor()
		value["k06"] = unsupported[index]
		node.set_meta(&"descriptor", value)
		_parity(node, "descriptor_type_%d" % index, 0)
	_clear(node)


func _ieee_controls(node: Node) -> void:
	for index: int in range(IEEE.size()):
		var expected: Dictionary = IEEE[index]
		var source: PackedByteArray = PackedByteArray()
		source.resize(8)
		source.fill(0)
		if index == 0:
			source[7] = 128
		elif index == 2 or index == 3:
			source[6] = 240
			source[7] = 127 if index == 2 else 255
		elif index == 4:
			source[0] = 1
			source[6] = 248
			source[7] = 127
		var value: float = source.decode_double(0)
		var roundtrip: String = _float_bytes(value)
		var native_bytes: String = var_to_bytes(value).hex_encode()
		_check(typeof(value) == TYPE_FLOAT and source.hex_encode() == expected.ieee64
			and roundtrip == expected.ieee64, "runtime IEEE64 roundtrip " + expected.label)
		_check(native_bytes == expected.variant, "pinned native Variant envelope " + expected.label)
		node.set_meta(&"geometry_version", value)
		var metadata: Variant = node.get_meta(&"geometry_version")
		_check(node.has_meta(&"geometry_version") and typeof(metadata) == TYPE_FLOAT
			and _float_bytes(metadata) == expected.ieee64,
			"actual native metadata preserves IEEE64 " + expected.label)
		var pair: Dictionary = _parity(node, "ieee_" + expected.label, 16)
		var candidate: Dictionary = _leaf(pair.candidate)
		var oracle: Dictionary = _leaf(pair.oracle)
		_check(_ieee_leaf_ok(candidate, expected) and _ieee_leaf_ok(oracle, expected),
			"both actual collected leaves preserve native type and bytes " + expected.label)
		_ieee.append({"label": expected.label, "input_type": typeof(value),
			"input_ieee64": source.hex_encode(), "roundtrip_ieee64": roundtrip,
			"input_variant": native_bytes, "expected_ieee64": expected.ieee64,
			"expected_variant": expected.variant, "metadata_type": typeof(metadata),
			"metadata_ieee64": _float_bytes(metadata),
			"metadata_variant": var_to_bytes(metadata).hex_encode(),
			"candidate_leaf": candidate, "oracle_leaf": oracle})
	node.remove_meta(&"geometry_version")


func _alias_controls(node: Node) -> void:
	var first: Dictionary = _parity(node, "fresh_first", 16)
	var second: Dictionary = _parity(node, "fresh_second", 16)
	var candidate_before: PackedByteArray = var_to_bytes(second.candidate)
	var oracle_before: PackedByteArray = var_to_bytes(second.oracle)
	first.candidate[0][1] = true
	first.oracle[0][1] = true
	_check(var_to_bytes(second.candidate) == candidate_before
		and var_to_bytes(second.oracle) == oracle_before, "separate calls have fresh nested rows")
	_check(not node.has_meta(KEYS[0]), "returned-row mutation leaves native metadata absent")
	_check(not first.candidate[1][1] and not first.oracle[1][1], "nested rows are separately fresh")
	first.candidate.append([])
	first.oracle.append([])
	_check(first.candidate.size() == 17 and first.oracle.size() == 17
		and second.candidate.size() == 16 and second.oracle.size() == 16,
		"fresh untyped outer results remain independently mutable")
	var descriptor: Dictionary = _descriptor()
	var original: Dictionary = descriptor.duplicate(true)
	var original_bytes: PackedByteArray = var_to_bytes(original)
	var initial_packed: String = var_to_bytes(original["k04"]).hex_encode()
	var shared_packed: String = var_to_bytes(
		PackedVector2Array([Vector2(9, 9), Vector2(3, 4)])).hex_encode()
	var isolated_packed: String = var_to_bytes(
		PackedVector2Array([Vector2(13, 17), Vector2(3, 4)])).hex_encode()
	node.set_meta(&"descriptor", descriptor)
	var pair: Dictionary = _parity(node, "descriptor_alias_base", 16)
	_alias_phase("original_descriptor", node, pair, original)
	_assert_alias_views(node, pair, original, original_bytes, true,
		initial_packed, initial_packed, "original")
	pair.candidate[15][2]["k00"] = "changed"
	_alias_phase("after_descriptor_scalar_write", node, pair, original)
	_assert_alias_views(node, pair, original, original_bytes, "changed",
		initial_packed, initial_packed, "scalar_write")
	_parity(node, "descriptor_alias_changed", 16)
	var packed: PackedVector2Array = pair.candidate[15][2]["k04"]
	var observed: Dictionary = _alias_phase("before_local_packed_write", node, pair, original, packed)
	_assert_alias_views(node, pair, original, original_bytes, "changed",
		initial_packed, initial_packed, "before_local")
	_check(observed["local"]["hex"] == initial_packed, "local native bytes before shared write")
	packed[0] = Vector2(9, 9)
	observed = _alias_phase("after_local_packed_write", node, pair, original, packed)
	_assert_alias_views(node, pair, original, original_bytes, "changed",
		shared_packed, shared_packed, "shared_local")
	_check(observed["local"]["hex"] == shared_packed, "local native bytes after shared write")
	var isolated: PackedVector2Array = packed.duplicate()
	observed = _alias_phase("after_explicit_duplicate_creation", node, pair, original,
		packed, isolated)
	_assert_alias_views(node, pair, original, original_bytes, "changed",
		shared_packed, shared_packed, "duplicate_created")
	_check(observed["local"]["hex"] == shared_packed, "local unchanged after explicit duplicate")
	_check(observed["duplicate"]["hex"] == shared_packed,
		"duplicate starts with actual shared value bytes")
	isolated[0] = Vector2(13, 17)
	observed = _alias_phase("after_duplicate_write", node, pair, original, packed, isolated)
	_assert_alias_views(node, pair, original, original_bytes, "changed",
		shared_packed, shared_packed, "duplicate_written")
	_check(observed["local"]["hex"] == shared_packed, "local unaffected by explicit duplicate write")
	_check(observed["duplicate"]["hex"] == isolated_packed,
		"duplicate retains independent native bytes")
	pair.candidate[15][2]["k04"] = isolated
	observed = _alias_phase("after_descriptor_packed_replacement", node, pair, original,
		packed, isolated)
	_assert_alias_views(node, pair, original, original_bytes, "changed",
		isolated_packed, shared_packed, "packed_replaced")
	_check(observed["local"]["hex"] == shared_packed,
		"old local retained after descriptor replacement")
	_check(observed["duplicate"]["hex"] == isolated_packed,
		"replacement retains duplicate native bytes")
	_parity(node, "descriptor_packed_replaced", 16)
	for key: String in original:
		descriptor[key] = original[key]
	observed = _alias_phase("after_exact_descriptor_restoration", node, pair, original,
		packed, isolated)
	_assert_alias_views(node, pair, original, original_bytes, true,
		initial_packed, initial_packed, "restored")
	_check(observed["local"]["hex"] == shared_packed,
		"old local survives exact descriptor byte restoration")
	_check(observed["duplicate"]["hex"] == isolated_packed,
		"duplicate survives descriptor byte restoration")
	_check(var_to_bytes(node.get_meta(&"descriptor")) == original_bytes,
		"exact original native descriptor bytes restored")
	_parity(node, "descriptor_alias_restored", 16)
	_clear(node)


func _descriptor() -> Dictionary:
	var values: Array = [true, 7, 1.25, "descriptor",
		PackedVector2Array([Vector2(1, 2), Vector2(3, 4)])]
	var result: Dictionary = {}
	for index: int in range(12):
		result["k%02d" % index] = values[index % values.size()]
	return result


func _parity(node: Node, label: String, expected_rows: int) -> Dictionary:
	var candidate: Array = _candidate.call("_metadata", node)
	var oracle: Array = _oracle.call("_metadata", node)
	var candidate_bytes: PackedByteArray = var_to_bytes(candidate)
	var oracle_bytes: PackedByteArray = var_to_bytes(oracle)
	var equal: bool = candidate_bytes == oracle_bytes
	var candidate_shape: bool = _rows_ok(candidate, expected_rows)
	var oracle_shape: bool = _rows_ok(oracle, expected_rows)
	_cases.append({"label": label, "expected_rows": expected_rows,
		"candidate_rows": candidate.size(), "oracle_rows": oracle.size(), "equal": equal,
		"candidate_shape": candidate_shape, "oracle_shape": oracle_shape,
		"candidate_types": _row_types(candidate), "oracle_types": _row_types(oracle),
		"candidate_sha256": candidate_bytes.hex_encode().sha256_text(),
		"oracle_sha256": oracle_bytes.hex_encode().sha256_text(),
		"candidate_bytes": candidate_bytes.size(), "oracle_bytes": oracle_bytes.size()})
	_check(equal and candidate_bytes.size() <= NATIVE_BYTES_CAP
		and oracle_bytes.size() <= NATIVE_BYTES_CAP, "exact bounded native metadata parity " + label)
	_check(candidate.size() == expected_rows and oracle.size() == expected_rows,
		"exact finite returned row count " + label)
	_check(candidate_shape and oracle_shape, "fresh untyped mutable ordered native rows " + label)
	return {"candidate": candidate, "oracle": oracle}


func _rows_ok(rows: Array, expected: int) -> bool:
	if rows.size() != expected or rows.is_typed() or rows.is_read_only():
		return false
	for index: int in range(rows.size()):
		var row: Variant = rows[index]
		if not row is Array or row.size() != 3 or row.is_typed() or row.is_read_only():
			return false
		if typeof(row[0]) != TYPE_STRING_NAME or row[0] != KEYS[index] or not row[1] is bool:
			return false
	return true


func _row_types(rows: Array) -> Array[int]:
	var result: Array[int] = []
	for row: Variant in rows:
		result.append(typeof(row[2]) if row is Array and row.size() == 3 else -1)
	return result


func _leaf(rows: Array) -> Dictionary:
	for row: Variant in rows:
		if row is Array and row.size() == 3 and row[0] == &"geometry_version":
			return {"found": true, "key_type": typeof(row[0]), "key": String(row[0]),
				"type": typeof(row[2]), "ieee64": _float_bytes(row[2]) if row[2] is float else "",
				"variant": var_to_bytes(row[2]).hex_encode()}
	return {"found": false, "key_type": -1, "key": "", "type": -1, "ieee64": "", "variant": ""}


func _ieee_leaf_ok(leaf: Dictionary, expected: Dictionary) -> bool:
	return leaf.found and leaf.key_type == TYPE_STRING_NAME and leaf.key == "geometry_version" \
		and leaf.type == TYPE_FLOAT and leaf.ieee64 == expected.ieee64 \
		and leaf.variant == expected.variant


func _float_bytes(value: float) -> String:
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(8)
	raw.encode_double(0, value)
	return raw.hex_encode()


func _clear(node: Node) -> void:
	for key: StringName in KEYS:
		if node.has_meta(key):
			node.remove_meta(key)


func _hex(value: String, size: int) -> bool:
	if value.length() != size:
		return false
	for character: String in value:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _check(condition: bool, label: String) -> bool:
	_checks += 1
	if not condition:
		_failures += 1
		_failed.append(label)
		push_error("POOL_METADATA_V40 " + label)
	return condition


func _write(value: Dictionary) -> void:
	var encoded: String = JSON.stringify(value, "", true, true)
	if not _admitted or encoded.to_utf8_buffer().size() > SUMMARY_CAP \
		or _alias_overflow or _alias_bytes > ALIAS_CAP:
		_check(false, "summary unavailable or exceeds finite byte cap")
		return
	var path: String = _output.path_join("pool-metadata-v40-summary.json")
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		_check(false, "summary temporary file could not open")
		return
	file.store_string(encoded)
	var error: Error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		_check(false, "summary write or atomic replacement failed")


func _alias_phase(phase: String, node: Node, pair: Dictionary, original: Dictionary,
	local: Variant = null, duplicate: Variant = null) -> Dictionary:
	# Snapshot actual finite views before any assertion or later mutation.
	var node_view: Dictionary = node.get_meta(&"descriptor")
	var candidate_view: Dictionary = pair.candidate[15][2]
	var oracle_view: Dictionary = pair.oracle[15][2]
	var node_bytes: PackedByteArray = var_to_bytes(node_view)
	var candidate_bytes: PackedByteArray = var_to_bytes(candidate_view)
	var oracle_bytes: PackedByteArray = var_to_bytes(oracle_view)
	var original_bytes: PackedByteArray = var_to_bytes(original)
	var local_bytes: PackedByteArray = var_to_bytes(local) if local != null else PackedByteArray()
	var duplicate_bytes: PackedByteArray = var_to_bytes(duplicate) \
		if duplicate != null else PackedByteArray()
	var row: Dictionary = {"phase": phase,
		"node": {"type": typeof(node_view), "hex": node_bytes.hex_encode()},
		"candidate": {"type": typeof(candidate_view), "hex": candidate_bytes.hex_encode()},
		"oracle": {"type": typeof(oracle_view), "hex": oracle_bytes.hex_encode()},
		"original": {"type": typeof(original), "hex": original_bytes.hex_encode()},
		"local": {"available": local != null, "type": typeof(local), "hex": local_bytes.hex_encode()},
		"duplicate": {"available": duplicate != null, "type": typeof(duplicate),
			"hex": duplicate_bytes.hex_encode()}}
	_alias_phases.append(row)
	_alias_bytes = JSON.stringify(_alias_phases, "", true, true).to_utf8_buffer().size()
	_alias_overflow = _alias_overflow or _alias_phases.size() > 8 or _alias_bytes > ALIAS_CAP
	for bytes: PackedByteArray in [node_bytes, candidate_bytes, oracle_bytes, original_bytes]:
		_alias_overflow = _alias_overflow or bytes.size() > ALIAS_DESCRIPTOR_CAP
	_alias_overflow = _alias_overflow or local_bytes.size() > ALIAS_PACKED_CAP \
		or duplicate_bytes.size() > ALIAS_PACKED_CAP
	return row


func _assert_alias_views(node: Node, pair: Dictionary, original: Dictionary,
	original_bytes: PackedByteArray, scalar: Variant, first: String, second: String,
	label: String) -> void:
	# Three fixed native descriptor views, each with three separately labeled checks.
	var views: Array[Dictionary] = [node.get_meta(&"descriptor"),
		pair.candidate[15][2], pair.oracle[15][2]]
	var names: Array[String] = ["node", "candidate", "oracle"]
	for index: int in range(3):
		_check(var_to_bytes(views[index]["k00"]) == var_to_bytes(scalar),
			label + " " + names[index] + " exact scalar bytes")
		_check(var_to_bytes(views[index]["k04"]).hex_encode() == first,
			label + " " + names[index] + " exact k04 packed bytes")
		_check(var_to_bytes(views[index]["k09"]).hex_encode() == second,
			label + " " + names[index] + " exact k09 packed bytes")
	_check(var_to_bytes(original) == original_bytes, label + " original restoration bytes immutable")

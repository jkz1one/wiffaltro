extends Node
## Finite compact metadata and synthetic collector checks; paid integration runs separately.
# gdlint: disable=max-returns,max-file-lines

const EXPECTED_CHECKS: int = 1151
const EXPECTED_CASES: int = 161
const SUMMARY_CAP: int = 256 * 1024
const NATIVE_BYTES_CAP: int = 8192
const ALIAS_CAP: int = 40 * 1024
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
var _extra: Dictionary = {}

class ScriptedNode extends Node3D:
	var fixture_tag: int = 40


func _ready() -> void:
	_physics_start = Engine.get_physics_frames()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-compact-v43-dir="):
			_output = argument.trim_prefix("--pool-compact-v43-dir=")
		if argument.begins_with("--pool-compact-v43-runtime="):
			_expected_runtime = argument.trim_prefix("--pool-compact-v43-runtime=")
		if argument.begins_with("--pool-compact-v43-execution="):
			_execution = argument.trim_prefix("--pool-compact-v43-execution=")
		if argument.begins_with("--pool-compact-v43-nonce="):
			_nonce = argument.trim_prefix("--pool-compact-v43-nonce=")
	_run()
	_physics_end = Engine.get_physics_frames()
	_check(_physics_start == _physics_end, "no physics frame advances during synchronous unit")
	_check(_created == _freed and _created == 10 and get_child_count() == 0,
		"all ten disposable native nodes freed; synthetic tree detached")
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
		"extra": _extra,
		"alias_phases": _alias_phases, "alias_bytes": _alias_bytes, "alias_overflow": _alias_overflow,
		"physics_frame_start": _physics_start, "physics_frame_end": _physics_end,
		"starts": 0, "releases": 0, "plays": 0,
		"hash_encoding": "SHA256_OF_LOWERCASE_HEX_NATIVE_BYTES",
		"getter_prefix_scope": "Exact source-order proof; native Node getters are not overridden",
		"null_scope": "Native set_meta null removes the key; no present-null claim",
		"performance_qualified": false, "production_qualified": false}
	_write(summary)
	print("POOL_COMPACT_METADATA_V43 checks=%d failures=%d cases=%d status=%s source=%s" % [
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
	_oracle = load("res://src/tests/stadium_pool_compact_metadata_v43_oracle.gd") as GDScript
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
	start = _checks
	_typed_controls(node)
	_groups["typed"] = _checks - start
	start = _checks
	_relation_controls(node)
	_groups["relations"] = _checks - start
	start = _checks
	_collector_controls()
	_groups["collectors"] = _checks - start
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
	var compact: Array = _candidate.call("_metadata_compact", node)
	var candidate: Array = _candidate.call("_metadata_expand", compact) \
		if not compact.is_empty() else []
	var oracle: Array = _oracle.call("_metadata", node)
	var candidate_bytes: PackedByteArray = var_to_bytes(candidate)
	var oracle_bytes: PackedByteArray = var_to_bytes(oracle)
	var compact_bytes: PackedByteArray = var_to_bytes(compact)
	var compact_shape: bool = _compact_ok(compact, expected_rows)
	var equal: bool = candidate_bytes == oracle_bytes
	var candidate_shape: bool = _rows_ok(candidate, expected_rows)
	var oracle_shape: bool = _rows_ok(oracle, expected_rows)
	_cases.append({"label": label, "expected_rows": expected_rows,
		"candidate_rows": candidate.size(), "oracle_rows": oracle.size(), "equal": equal,
		"compact_slots": compact.size(), "compact_shape": compact_shape,
		"compact_bytes": compact_bytes.size(),
		"compact_sha256": compact_bytes.hex_encode().sha256_text(),
		"bytes_removed": oracle_bytes.size() - compact_bytes.size(),
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
	_check(compact_shape and compact_bytes.size() <= NATIVE_BYTES_CAP
		and oracle_bytes.size() - compact_bytes.size() == (484 if expected_rows == 16 else 0),
		"compact shape and exact structural byte difference " + label)
	return {"candidate": candidate, "oracle": oracle, "compact": compact}


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
		push_error("POOL_COMPACT_METADATA_V43 " + label)
	return condition


func _write(value: Dictionary) -> void:
	var encoded: String = JSON.stringify(value, "", true, true)
	if not _admitted or encoded.to_utf8_buffer().size() > SUMMARY_CAP \
		or _alias_overflow or _alias_bytes > ALIAS_CAP:
		_check(false, "summary unavailable or exceeds finite byte cap")
		return
	var path: String = _output.path_join("pool-compact-v43-summary.json")
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
	var compact_view: Dictionary = pair.compact[31]
	var node_bytes: PackedByteArray = var_to_bytes(node_view)
	var candidate_bytes: PackedByteArray = var_to_bytes(candidate_view)
	var oracle_bytes: PackedByteArray = var_to_bytes(oracle_view)
	var original_bytes: PackedByteArray = var_to_bytes(original)
	var compact_bytes: PackedByteArray = var_to_bytes(compact_view)
	var local_bytes: PackedByteArray = var_to_bytes(local) if local != null else PackedByteArray()
	var duplicate_bytes: PackedByteArray = var_to_bytes(duplicate) \
		if duplicate != null else PackedByteArray()
	var row: Dictionary = {"phase": phase,
		"node": {"type": typeof(node_view), "hex": node_bytes.hex_encode()},
		"candidate": {"type": typeof(candidate_view), "hex": candidate_bytes.hex_encode()},
		"oracle": {"type": typeof(oracle_view), "hex": oracle_bytes.hex_encode()},
		"compact": {"type": typeof(compact_view), "hex": compact_bytes.hex_encode()},
		"original": {"type": typeof(original), "hex": original_bytes.hex_encode()},
		"local": {"available": local != null, "type": typeof(local), "hex": local_bytes.hex_encode()},
		"duplicate": {"available": duplicate != null, "type": typeof(duplicate),
			"hex": duplicate_bytes.hex_encode()}}
	_alias_phases.append(row)
	_alias_bytes = JSON.stringify(_alias_phases, "", true, true).to_utf8_buffer().size()
	_alias_overflow = _alias_overflow or _alias_phases.size() > 8 or _alias_bytes > ALIAS_CAP
	for bytes: PackedByteArray in [node_bytes, candidate_bytes, oracle_bytes, compact_bytes,
		original_bytes]:
		_alias_overflow = _alias_overflow or bytes.size() > ALIAS_DESCRIPTOR_CAP
	_alias_overflow = _alias_overflow or local_bytes.size() > ALIAS_PACKED_CAP \
		or duplicate_bytes.size() > ALIAS_PACKED_CAP
	return row


func _assert_alias_views(node: Node, pair: Dictionary, original: Dictionary,
	original_bytes: PackedByteArray, scalar: Variant, first: String, second: String,
	label: String) -> void:
	# Four fixed native descriptor views, each with three separately labeled checks.
	var views: Array[Dictionary] = [node.get_meta(&"descriptor"),
		pair.candidate[15][2], pair.oracle[15][2], pair.compact[31]]
	var names: Array[String] = ["node", "candidate", "oracle", "compact"]
	for index: int in range(4):
		_check(var_to_bytes(views[index]["k00"]) == var_to_bytes(scalar),
			label + " " + names[index] + " exact scalar bytes")
		_check(var_to_bytes(views[index]["k04"]).hex_encode() == first,
			label + " " + names[index] + " exact k04 packed bytes")
		_check(var_to_bytes(views[index]["k09"]).hex_encode() == second,
			label + " " + names[index] + " exact k09 packed bytes")
	_check(var_to_bytes(original) == original_bytes, label + " original restoration bytes immutable")


func _compact_ok(rows: Array, expected: int) -> bool:
	if rows.size() != expected * 2 or rows.is_typed() or rows.is_read_only():
		return false
	for index: int in range(expected):
		if not rows[index * 2] is bool:
			return false
		if not rows[index * 2] and typeof(rows[index * 2 + 1]) != TYPE_NIL:
			return false
	return true


func _typed_controls(node: Node) -> void:
	var records: Array[Dictionary] = []
	var dictionaries: Array[Dictionary] = []
	var labels: Array[String] = ["typed_string_keys", "typed_string_int", "typed_string_float",
		"readonly_descriptor", "reversed_descriptor", "packed_nonfinite"]
	dictionaries.append(Dictionary(_descriptor(), TYPE_STRING, "", null, TYPE_NIL, "", null))
	var integers: Dictionary = {}
	var floats: Dictionary = {}
	for index: int in range(12):
		integers["k%02d" % index] = index - 6
		floats["k%02d" % index] = float(index) + 0.25
	dictionaries.append(Dictionary(integers, TYPE_STRING, "", null, TYPE_INT, "", null))
	dictionaries.append(Dictionary(floats, TYPE_STRING, "", null, TYPE_FLOAT, "", null))
	var readonly: Dictionary = _descriptor()
	readonly.make_read_only()
	dictionaries.append(readonly)
	var original: Dictionary = _descriptor()
	var reversed: Dictionary = {}
	for index: int in range(11, -1, -1):
		reversed["k%02d" % index] = original["k%02d" % index]
	dictionaries.append(reversed)
	var unusual: Dictionary = _descriptor()
	var infinity: float = _runtime_float("000000000000f07f")
	var nan_value: float = _runtime_float("010000000000f87f")
	unusual["k04"] = PackedVector2Array([Vector2(infinity, nan_value), Vector2(-infinity, 0)])
	dictionaries.append(unusual)
	for index: int in range(dictionaries.size()):
		var descriptor: Dictionary = dictionaries[index]
		node.set_meta(&"descriptor", descriptor)
		var pair: Dictionary = _parity(node, labels[index], 16)
		var compact_leaf: Dictionary = pair.compact[31]
		var candidate_leaf: Dictionary = pair.candidate[15][2]
		var oracle_leaf: Dictionary = pair.oracle[15][2]
		var original_hex: String = var_to_bytes(descriptor).hex_encode()
		var row: Dictionary = {"label": labels[index], "typed": descriptor.is_typed(),
			"key_type": descriptor.get_typed_key_builtin(),
			"value_type": descriptor.get_typed_value_builtin(),
			"readonly": descriptor.is_read_only(), "keys": descriptor.keys(),
			"node_hex": var_to_bytes(node.get_meta(&"descriptor")).hex_encode(),
			"compact_hex": var_to_bytes(compact_leaf).hex_encode(),
			"expanded_hex": var_to_bytes(candidate_leaf).hex_encode(),
			"legacy_hex": var_to_bytes(oracle_leaf).hex_encode()}
		records.append(row)
		_check(row.node_hex == original_hex and row.compact_hex == original_hex
			and row.expanded_hex == original_hex and row.legacy_hex == original_hex,
			"exact typed ordered dictionary leaf envelopes " + labels[index])
		_check(compact_leaf.is_typed() == descriptor.is_typed()
			and compact_leaf.get_typed_key_builtin() == descriptor.get_typed_key_builtin()
			and compact_leaf.get_typed_value_builtin() == descriptor.get_typed_value_builtin()
			and compact_leaf.is_read_only() == descriptor.is_read_only(),
			"native dictionary constraints and readonly preserved " + labels[index])
		_clear(node)
	_extra["typed"] = records


func _relation_controls(node: Node) -> void:
	var labels: Array[String] = ["absent", "false", "integer_zero", "positive_zero",
		"negative_zero", "string", "string_name", "null_removed", "synthetic_present_null"]
	var values: Array = [null, false, 0, _runtime_float("0000000000000000"),
		_runtime_float("0000000000000080"), "same", &"same", null, null]
	var compact_packets: Array[PackedByteArray] = []
	var legacy_packets: Array[PackedByteArray] = []
	var states: Array[Dictionary] = []
	for index: int in range(labels.size()):
		node.set_meta(&"surface_id", values[index])
		var compact: Array = _candidate.call("_metadata_compact", node)
		var legacy: Array = _oracle.call("_metadata", node)
		if index == 8:
			# Explicit mathematical normal form, not a claim about native Node metadata.
			compact[0] = true
			legacy[0][1] = true
		var expanded: Array = _candidate.call("_metadata_expand", compact)
		var compact_bytes: PackedByteArray = var_to_bytes(compact)
		var legacy_bytes: PackedByteArray = var_to_bytes(legacy)
		states.append({"label": labels[index], "synthetic": index == 8,
			"native_present": node.has_meta(&"surface_id"), "presence": compact[0],
			"type": typeof(compact[1]), "value_hex": var_to_bytes(compact[1]).hex_encode(),
			"compact_sha256": compact_bytes.hex_encode().sha256_text(),
			"legacy_sha256": legacy_bytes.hex_encode().sha256_text(),
			"compact_bytes": compact_bytes.size(), "legacy_bytes": legacy_bytes.size()})
		compact_packets.append(compact_bytes)
		legacy_packets.append(legacy_bytes)
		_check(var_to_bytes(expanded) == legacy_bytes, "finite relation expansion " + labels[index])
		_check(_compact_ok(compact, 16) and legacy_bytes.size() - compact_bytes.size() == 484,
			"finite relation native shape " + labels[index])
	var pairs: Array[Dictionary] = []
	for left: int in range(labels.size()):
		for right: int in range(labels.size()):
			var compact_equal: bool = compact_packets[left] == compact_packets[right]
			var legacy_equal: bool = legacy_packets[left] == legacy_packets[right]
			var expected: bool = left == right or (left in [0, 7] and right in [0, 7])
			pairs.append({"left": left, "right": right, "compact_equal": compact_equal,
				"legacy_equal": legacy_equal, "expected": expected})
			_check(compact_equal == legacy_equal, "equality relation iff %d %d" % [left, right])
			_check(compact_equal == expected, "equality relation exact %d %d" % [left, right])
	_extra["relations"] = {"states": states, "pairs": pairs}
	var first: Array = _candidate.call("_metadata_compact", node)
	var second: Array = _candidate.call("_metadata_compact", node)
	var second_before: PackedByteArray = var_to_bytes(second)
	first[0] = true
	first.append("mutable")
	_check(var_to_bytes(second) == second_before and second.size() == 32,
		"compact outer arrays are independently fresh and mutable")
	var expanded_first: Array = _candidate.call("_metadata_expand", second)
	var expanded_second: Array = _candidate.call("_metadata_expand", second)
	var before: PackedByteArray = var_to_bytes(second)
	expanded_first[0][1] = true
	_check(var_to_bytes(second) == before and not expanded_second[0][1]
		and not expanded_first[1][1], "finite inverse structures do not mutate source or sibling rows")
	_clear(node)


func _collector_controls() -> void:
	var default_candidate: RefCounted = _candidate.new()
	var default_legacy: RefCounted = _oracle.new()
	var default_receipt: Dictionary = default_candidate.call("audit_receipt")
	var default_receipt_bytes: PackedByteArray = var_to_bytes(default_receipt)
	var empty_hash: String = PackedByteArray().hex_encode().sha256_text()
	_check(default_receipt_bytes == var_to_bytes(default_legacy.call("audit_receipt")),
		"pre-capture default audit exact legacy receipt")
	_check(default_receipt.model_descriptor_sha256 == empty_hash
		and default_receipt.boundary_descriptor_sha256 == empty_hash
		and default_receipt.inventory_ids_sha256 == empty_hash and default_receipt.body_count == 0,
		"default audit hashes empty native hex rather than empty strings")
	var lab: Node3D = Node3D.new()
	var property: Node3D = Node3D.new()
	var model: Node3D = Node3D.new()
	var boundary: Node3D = Node3D.new()
	var ground: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var chair: Node3D = Node3D.new()
	var visual: Node3D = Node3D.new()
	_created += 8
	lab.name = "CompactSyntheticLab"
	property.name = "SyntheticProperty"
	model.name = "Model"
	boundary.name = "Boundary"
	ground.name = "Ground"
	shape.name = "Collision"
	chair.name = "Chair"
	visual.name = "Visual"
	shape.shape = BoxShape3D.new()
	ground.add_child(shape)
	chair.add_child(visual)
	for node: Node3D in [model, boundary, ground, chair]:
		property.add_child(node)
	lab.add_child(property)
	add_child(lab)
	ground.set_meta(&"geometry_version", 1)
	boundary.set_meta(&"surface_id", "boundary")
	chair.set_meta(&"owned_copy", "chair")
	model.set_meta(&"water_source_sha256", _runtime)
	model.set_meta(&"descriptor", Dictionary(_descriptor(), TYPE_STRING, "", null, TYPE_NIL, "", null))
	_check(lab.is_inside_tree() and visual.is_inside_tree() and shape.is_inside_tree()
		and ground.get_shape_owners().size() == 1,
		"finite synthetic collectors use actual live nodes and native shape owner")
	var current: RefCounted = _candidate.call("capture", lab, property, model, boundary, ground, chair)
	var legacy: RefCounted = _oracle.call("capture", lab, property, model, boundary, ground, chair)
	if not _check(current != null and legacy != null, "both actual capture implementations succeed"):
		lab.free()
		_freed += 8
		return
	var receipt: Dictionary = current.call("audit_receipt")
	var receipt_bytes: PackedByteArray = var_to_bytes(receipt)
	_check(current.get_script() == _candidate and current.get("_compact_audit_captured"),
		"capture returns actual exact base helper with capture-only audit provenance")
	_check(receipt_bytes == var_to_bytes(legacy.call("audit_receipt")),
		"captured model boundary and inventory legacy audit receipts are exact")
	var selector_rows: Array[Dictionary] = []
	var labels: Array[String] = ["property", "model", "boundary", "ground", "receiver"]
	var nodes: Array[Node] = [property, model, boundary, ground, chair]
	for index: int in range(nodes.size()):
		var compact_rows: Array = current.call("_tree", nodes[index])
		var old_rows: Array = legacy.call("_tree", nodes[index])
		var compact_bytes: PackedByteArray = var_to_bytes(compact_rows)
		var old_bytes: PackedByteArray = var_to_bytes(old_rows)
		var expanded_bytes: PackedByteArray = _candidate.call("_tree_legacy_bytes", compact_rows)
		var compact_shape: bool = true
		for row: Array in compact_rows:
			compact_shape = compact_shape and _compact_ok(row[1], 16)
		selector_rows.append({"label": labels[index], "rows": compact_rows.size(),
			"legacy_rows": old_rows.size(), "compact_shape": compact_shape,
			"compact_bytes": compact_bytes.size(), "legacy_bytes": old_bytes.size(),
			"expanded_bytes": expanded_bytes.size(),
			"compact_sha256": compact_bytes.hex_encode().sha256_text(),
			"legacy_sha256": old_bytes.hex_encode().sha256_text(),
			"expanded_sha256": expanded_bytes.hex_encode().sha256_text()})
		_check(not compact_rows.is_empty() and compact_shape
			and compact_rows.size() == old_rows.size(), "actual compact tree selector " + labels[index])
		_check(expanded_bytes == old_bytes
			and old_bytes.size() - compact_bytes.size() == 484 * compact_rows.size(),
			"finite captured-tree inverse exact legacy bytes " + labels[index])
		_check(var_to_bytes(compact_rows) == compact_bytes,
			"capture inverse leaves original compact rows untouched " + labels[index])
	var topology: Array = current.call("_topology", property)
	var old_topology: Array = legacy.call("_topology", property)
	var topology_before: PackedByteArray = var_to_bytes(topology)
	var expanded_topology: Array = []
	var receiver_slots: int = 0
	for source_row: Array in topology:
		var row: Array = source_row.duplicate()
		if row[0][0] == chair.get_instance_id():
			receiver_slots = row[2].size()
			row[2] = _candidate.call("_metadata_expand", row[2])
		expanded_topology.append(row)
	_check(receiver_slots == 32 and topology.size() == 7,
		"actual receiver topology uses compact metadata at its existing slot")
	_check(var_to_bytes(expanded_topology) == var_to_bytes(old_topology)
		and var_to_bytes(old_topology).size() - topology_before.size() == 484,
		"receiver topology finite inverse exact legacy bytes")
	_check(var_to_bytes(topology) == topology_before,
		"receiver topology inverse leaves captured source structure untouched")
	_check(current.get("_topology_bytes") == topology_before
		and current.get("_model_bytes") == var_to_bytes(current.call("_tree", model))
		and current.get("_boundary_bytes") == var_to_bytes(current.call("_tree", boundary))
		and current.get("_body_bytes")[ground.get_instance_id()]
			== var_to_bytes(current.call("_tree", ground)),
		"actual captured comparison seals use compact tree and topology bytes")
	var phases: Array[Dictionary] = []
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"initial", [true, true, true, true, true], receipt_bytes))
	ground.set_meta(&"geometry_version", 2)
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"ground_changed", [false, false, false, true, true], receipt_bytes))
	ground.set_meta(&"geometry_version", 1)
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"ground_restored", [true, true, true, true, true], receipt_bytes))
	var descriptor: Dictionary = model.get_meta(&"descriptor")
	descriptor["k00"] = "changed"
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"model_changed", [true, true, true, false, true], receipt_bytes))
	descriptor["k00"] = true
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"model_restored", [true, true, true, true, true], receipt_bytes))
	boundary.set_meta(&"surface_id", "changed")
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"boundary_changed", [true, true, true, true, false], receipt_bytes))
	boundary.set_meta(&"surface_id", "boundary")
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"boundary_restored", [true, true, true, true, true], receipt_bytes))
	chair.set_meta(&"owned_copy", "changed")
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"receiver_changed", [false, true, true, true, true], receipt_bytes))
	chair.set_meta(&"owned_copy", "chair")
	phases.append(_predicates(current, legacy, lab, model, boundary, ground,
		"receiver_restored", [true, true, true, true, true], receipt_bytes))
	_extra["subclasses"] = _subclass_controls(current, legacy, model, chair)
	var retained: Array = current.call("_tree", model)
	var retained_before: PackedByteArray = var_to_bytes(retained)
	var inverse_before: PackedByteArray = _candidate.call("_tree_legacy_bytes", retained)
	var retained_descriptor: Dictionary = retained[0][1][31]
	retained_descriptor["k00"] = "inverse_alias"
	var inverse_changed: PackedByteArray = _candidate.call("_tree_legacy_bytes", retained)
	_check(inverse_changed == var_to_bytes(legacy.call("_tree", model))
		and inverse_changed != inverse_before, "tree inverse retains descriptor aliases without copying")
	retained_descriptor["k00"] = true
	_check(var_to_bytes(retained) == retained_before
		and _candidate.call("_tree_legacy_bytes", retained) == inverse_before,
		"tree inverse aliases restore exact original captured bytes")
	model.set_meta(&"water_source_sha256", "changed_after_collection")
	_check(_candidate.call("_tree_legacy_bytes", retained) == inverse_before
		and var_to_bytes(legacy.call("_tree", model)) != inverse_before,
		"tree inverse uses retained values rather than a second live metadata read")
	model.set_meta(&"water_source_sha256", _runtime)
	_check(receipt_bytes == var_to_bytes(current.call("audit_receipt")),
		"capture audit never refreshes on later mutable alias changes")
	var ids: Array[int] = []
	for node: Node in [lab, property, model, boundary, ground, shape, chair, visual]:
		ids.append(node.get_instance_id())
	lab.free()
	_freed += 8
	var disposed: bool = true
	for id: int in ids:
		disposed = disposed and not is_instance_id_valid(id)
	_check(disposed, "all eight synthetic collector nodes synchronously disposed")
	_check(_candidate.call("_tree_legacy_bytes", retained) == inverse_before
		and var_to_bytes(retained) == retained_before,
		"finite inverse still exact after every source node has been freed")
	_extra["capture"] = {"scope": "SYNTHETIC_HELPER_CAPTURE_NOT_PAID_AUTHORITY",
		"default_receipt": default_receipt, "receipt": receipt,
		"default_receipt_native_hex": default_receipt_bytes.hex_encode(),
		"receipt_native_hex": receipt_bytes.hex_encode(), "selectors": selector_rows,
		"topology_rows": topology.size(), "receiver_slots": receiver_slots,
		"compact_topology_bytes": topology_before.size(),
		"legacy_topology_bytes": var_to_bytes(old_topology).size(),
		"compact_topology_sha256": topology_before.hex_encode().sha256_text(),
		"legacy_topology_sha256": var_to_bytes(old_topology).hex_encode().sha256_text(),
		"expanded_topology_sha256": var_to_bytes(expanded_topology).hex_encode().sha256_text(),
		"phases": phases, "disposed": disposed, "node_ids": ids,
		"retained_compact_sha256": retained_before.hex_encode().sha256_text(),
		"retained_legacy_sha256": inverse_before.hex_encode().sha256_text(),
		"post_disposal_inverse_sha256": String(_candidate.call("_tree_legacy_bytes", retained)
			.hex_encode()).sha256_text()}


func _predicates(current: RefCounted, legacy: RefCounted, lab: Node3D, model: Node3D,
	boundary: Node3D, ground: StaticBody3D, label: String, expected: Array,
	receipt: PackedByteArray) -> Dictionary:
	var actual: Array[bool] = [current.call("valid_inventory", lab),
		current.call("valid_body", ground),
		current.call("valid_ground", ground), current.call("valid_model", model),
		current.call("valid_boundary", boundary)]
	var original: Array[bool] = [legacy.call("valid_inventory", lab),
		legacy.call("valid_body", ground),
		legacy.call("valid_ground", ground), legacy.call("valid_model", model),
		legacy.call("valid_boundary", boundary)]
	var names: Array[String] = ["inventory", "body", "ground", "model", "boundary"]
	for index: int in range(names.size()):
		_check(actual[index] == original[index], "actual validator parity " + label + " " + names[index])
		_check(actual[index] == expected[index], "actual validator outcome " + label + " " + names[index])
	var current_audit: PackedByteArray = var_to_bytes(current.call("audit_receipt"))
	var legacy_audit: PackedByteArray = var_to_bytes(legacy.call("audit_receipt"))
	_check(current_audit == legacy_audit, "actual audit parity " + label)
	_check(current_audit == receipt, "actual capture-only audit remains fixed " + label)
	return {"label": label, "candidate": actual, "legacy": original, "expected": expected,
		"candidate_audit_sha256": current_audit.hex_encode().sha256_text(),
		"legacy_audit_sha256": legacy_audit.hex_encode().sha256_text(),
		"audit_fixed": current_audit == receipt}


func _subclass_controls(current: RefCounted, legacy: RefCounted, model: Node3D,
	chair: Node3D) -> Array[Dictionary]:
	var probe_script: GDScript = load("res://src/tests/stadium_pool_compact_metadata_v43_probe.gd")
	var super_script: GDScript = load(
		"res://src/tests/stadium_pool_compact_metadata_v43_super_probe.gd")
	var result: Array[Dictionary] = []
	for script: GDScript in [probe_script, super_script]:
		var probe: RefCounted = script.new()
		for key: String in ["_node_scripts", "_model_ref", "_receiver_id", "_receiver_visual_id"]:
			probe.set(key, current.get(key))
		probe_script.set("metadata_calls", 0)
		probe_script.set("compact_traps", 0)
		probe_script.set("expansion_traps", 0)
		var tree: Array = probe.call("_tree", model)
		var topology: Array = probe.call("_topology", chair)
		var is_super: bool = script == super_script
		var label: String = "super" if is_super else "inherited"
		var old_tree: PackedByteArray = var_to_bytes(legacy.call("_tree", model))
		var old_topology: PackedByteArray = var_to_bytes(legacy.call("_topology", chair))
		var calls: int = probe_script.get("metadata_calls")
		var traps: int = probe_script.get("compact_traps") + probe_script.get("expansion_traps")
		_check(var_to_bytes(tree) == old_tree and tree[0][1].size() == 16,
			"subclass original metadata tree shape " + label)
		_check(var_to_bytes(topology) == old_topology and topology[0][2].size() == 16,
			"subclass original receiver topology shape " + label)
		_check(calls == 2 and traps == 0, "subclass static override and new-name traps " + label)
		var recursive_calls: Array[int] = [0, 0]
		if is_super:
			recursive_calls[0] = probe.get("tree_calls")
			recursive_calls[1] = probe.get("topology_calls")
		_check(recursive_calls == ([1, 2] if is_super else [0, 0]),
			"subclass inherited and explicit super recursion " + label)
		probe.set("_model_bytes", legacy.get("_model_bytes"))
		probe.set("_boundary_bytes", legacy.get("_boundary_bytes"))
		probe.set("_inventory_ids", legacy.get("_inventory_ids"))
		probe.set("_source", legacy.get("_source"))
		probe.set("_body_bytes", legacy.get("_body_bytes"))
		probe.set("_compact_audit_captured", true)
		probe.set("_audit_model_bytes", PackedByteArray([255]))
		probe.set("_audit_boundary_bytes", PackedByteArray([254]))
		var receipt: Dictionary = probe.call("audit_receipt")
		_check(var_to_bytes(receipt) == var_to_bytes(legacy.call("audit_receipt")),
			"subclass audit retains legacy buffers even when compact marker is set " + label)
		result.append({"label": label, "metadata_calls": calls, "traps": traps,
			"tree_rows": tree.size(), "topology_rows": topology.size(),
			"tree_sha256": var_to_bytes(tree).hex_encode().sha256_text(),
			"legacy_tree_sha256": old_tree.hex_encode().sha256_text(),
			"topology_sha256": var_to_bytes(topology).hex_encode().sha256_text(),
			"legacy_topology_sha256": old_topology.hex_encode().sha256_text(),
			"recursive_calls": recursive_calls,
			"audit_sha256": var_to_bytes(receipt).hex_encode().sha256_text(),
			"legacy_audit_sha256": var_to_bytes(legacy.call("audit_receipt")).hex_encode().sha256_text()})
	return result


func _runtime_float(hex: String) -> float:
	var source: PackedByteArray = hex.hex_decode()
	var runtime: PackedByteArray = PackedByteArray()
	runtime.resize(8)
	runtime.fill(0)
	for index: int in range(8):
		runtime[index] = source[index]
	return runtime.decode_double(0)

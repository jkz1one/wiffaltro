extends RefCounted
## Optional complete numeric source/replay archive, independent of native-image evidence.

const MAX_COMPRESSED_BYTES: int = 2 * 1024 * 1024


static func directory() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mogul-one-history-report-dir="):
			return argument.trim_prefix("--mogul-one-history-report-dir=")
	return ""


static func save(folder: String, packet: Dictionary) -> Dictionary:
	if packet.sources.size() != 20 or packet.replays.size() != 60:
		return {"ok": false, "error": "complete archive requires20 sources and60 replays"}
	var rates: Dictionary = {}
	for replay: Dictionary in packet.replays:
		var index: int = replay.source_index
		if (
			index < 0
			or index >= packet.sources.size()
			or replay.source_sha256 != packet.sources[index].source_sha256
		):
			return {"ok": false, "error": "replay source identity/provenance mismatch"}
		var key: String = "%d:%d" % [index, replay.camera_fps]
		if rates.has(key) or replay.camera_fps not in [30, 60, 120]:
			return {"ok": false, "error": "duplicate or unsupported source replay rate"}
		rates[key] = true
	return _save(folder, packet, "mogul-one-complete-physics-history.json.gz")


static func save_controller(folder: String, packet: Dictionary) -> Dictionary:
	if (
		packet.kind != "BOUNDED_AM01_REAR_FOUL_CONTROLLER_REPRODUCTION"
		or packet.sources.size() != 4
		or not packet.replays.is_empty()
		or not packet.camera_rates.is_empty()
	):
		return {"ok": false, "error": "bounded controller archive requires4 sources and no replays"}
	var pairs: Dictionary = {}
	for source: Dictionary in packet.sources:
		var key: String = str(source.left) + ":" + str(source.defense)
		if pairs.has(key) or source.launch.id != "rear-net-foul":
			return {"ok": false, "error": "bounded controller source role/launch mismatch"}
		pairs[key] = true
	return _save(folder, packet, "mogul-one-bounded-controller-history.json.gz")


static func _save(folder: String, packet: Dictionary, filename: String) -> Dictionary:
	var errors: Array[String] = []
	var encoded: Variant = _numeric(packet, errors)
	if not errors.is_empty():
		return {"ok": false, "error": "unsupported or nonfinite archive value", "details": errors}
	var raw: PackedByteArray = JSON.stringify(encoded, "", true, true).to_utf8_buffer()
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_GZIP)
	if compressed.is_empty() or compressed.size() > MAX_COMPRESSED_BYTES:
		return {
			"ok": false,
			"error": "required raw history exceeds2MiB gzip limit",
			"raw_bytes": raw.size(),
			"gzip_bytes": compressed.size()
		}
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return {"ok": false, "error": "history archive directory cannot be created"}
	var path: String = folder.path_join(filename)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "history archive cannot be opened", "path": path}
	file.store_buffer(compressed)
	file.flush()
	var error: Error = file.get_error()
	var written: int = file.get_position()
	file.close()
	if error != OK or written != compressed.size():
		return {"ok": false, "error": "history archive write/flush failed", "path": path}
	var actual: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if actual != compressed or FileAccess.get_sha256(path) != _sha256(compressed):
		return {"ok": false, "error": "history archive byte/hash readback mismatch", "path": path}
	var restored: PackedByteArray = actual.decompress(raw.size(), FileAccess.COMPRESSION_GZIP)
	if restored != raw or _sha256(restored) != _sha256(raw):
		return {"ok": false, "error": "gzip roundtrip changed complete numeric JSON", "path": path}
	var parser: JSON = JSON.new()
	if parser.parse(restored.get_string_from_utf8()) != OK:
		return {"ok": false, "error": "readback is not inspectable complete JSON", "path": path}
	return {
		"ok": true,
		"path": path,
		"sources": packet.sources.size(),
		"replays": packet.replays.size(),
		"raw_bytes": raw.size(),
		"gzip_bytes": compressed.size(),
		"gzip_sha256": _sha256(actual),
		"json_sha256": _sha256(restored)
	}


static func _numeric(value: Variant, errors: Array[String]) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return value
		TYPE_FLOAT:
			if not is_finite(value):
				errors.append("nonfinite float")
			return value
		TYPE_STRING_NAME:
			return {"@type": "StringName", "value": String(value)}
		TYPE_VECTOR2:
			return _numeric({"@type": "Vector2", "value": [value.x, value.y]}, errors)
		TYPE_VECTOR3:
			return _numeric({"@type": "Vector3", "value": [value.x, value.y, value.z]}, errors)
		TYPE_TRANSFORM3D:
			var pose: Transform3D = value
			var numbers: Array[float] = []
			for vector: Vector3 in [pose.basis.x, pose.basis.y, pose.basis.z, pose.origin]:
				numbers.append_array([vector.x, vector.y, vector.z])
			return _numeric({"@type": "Transform3D", "basis_columns_then_origin": numbers}, errors)
		TYPE_ARRAY:
			var rows: Array = []
			for row: Variant in value:
				rows.append(_numeric(row, errors))
			return rows
		TYPE_DICTIONARY:
			var ordinary: bool = true
			for key: Variant in value:
				ordinary = ordinary and key is String
			var rows: Array = []
			var result: Dictionary = {}
			for key: Variant in value:
				if ordinary:
					result[key] = _numeric(value[key], errors)
				else:
					rows.append([_numeric(key, errors), _numeric(value[key], errors)])
			return result if ordinary else {"@type": "Dictionary", "entries": rows}
	errors.append("unsupported Variant type%d" % typeof(value))
	return null


static func _sha256(value: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value)
	return context.finish().hex_encode()

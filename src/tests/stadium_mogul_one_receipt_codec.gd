extends RefCounted
## Readable numeric JSON plus an object-free, lossless typed Variant companion.
## Frozen JSON parsing demonstrably changes two finite float64 values; never use tolerance.

const Archive = preload("res://src/tests/stadium_mogul_one_history_archive.gd")
const ENCODING: String = "AM01-NUMERIC-VARIANT-GZIP-HEX-v1"
const MAX_RAW_BYTES: int = 1024 * 1024
const FIELDS: Array[String] = [
	"context",
	"context_encoding",
	"context_raw_bytes",
	"context_raw_sha256",
	"context_payload_hex",
	"context_payload_sha256",
	"context_json_sha256"
]


static func seal(value: Dictionary) -> Dictionary:
	if not _numeric_only(value):
		return {}
	var raw: PackedByteArray = var_to_bytes(value)
	if raw.is_empty() or raw.size() > MAX_RAW_BYTES:
		return {}
	var payload: PackedByteArray = raw.compress(FileAccess.COMPRESSION_GZIP)
	return {
		"context": value,
		"context_encoding": ENCODING,
		"context_raw_bytes": raw.size(),
		"context_raw_sha256": Archive._sha256(raw),
		"context_payload_hex": payload.hex_encode(),
		"context_payload_sha256": Archive._sha256(payload),
		"context_json_sha256":
		Archive._sha256(JSON.stringify(value, "", true, true).to_utf8_buffer())
	}


static func restore(packet: Dictionary) -> Dictionary:
	var failed: Dictionary = {"ok": false, "value": {}}
	if (
		packet.get("context_encoding") != ENCODING
		or not packet.get("context") is Dictionary
		or not _integer(packet.get("context_raw_bytes"))
		or int(packet.context_raw_bytes) < 8
		or int(packet.context_raw_bytes) > MAX_RAW_BYTES
		or not _hex(packet.get("context_payload_hex"), MAX_RAW_BYTES * 2 + 1024)
		or not _hash(packet.get("context_payload_sha256"))
		or not _hash(packet.get("context_raw_sha256"))
		or not _hash(packet.get("context_json_sha256"))
	):
		return failed
	var payload: PackedByteArray = String(packet.context_payload_hex).hex_decode()
	if Archive._sha256(payload) != packet.context_payload_sha256:
		return failed
	var raw: PackedByteArray = payload.decompress(
		int(packet.context_raw_bytes), FileAccess.COMPRESSION_GZIP
	)
	if (
		raw.size() != int(packet.context_raw_bytes)
		or Archive._sha256(raw) != packet.context_raw_sha256
		or raw.decode_u32(0) != TYPE_DICTIONARY
	):
		return failed
	# bytes_to_var never enables object decoding; only recursively checked numeric data is admitted.
	var restored: Variant = bytes_to_var(raw)
	if not restored is Dictionary or not _numeric_only(restored) or var_to_bytes(restored) != raw:
		return failed
	var canonical: String = JSON.stringify(restored, "", true, true)
	if Archive._sha256(canonical.to_utf8_buffer()) != packet.context_json_sha256:
		return failed
	var parser: JSON = JSON.new()
	if parser.parse(canonical) != OK:
		return failed
	# The readable field may be the original in-memory value, or exactly what this
	# frozen JSON parser reads from its canonical decimal text. Neither is an oracle
	# for exact numerics: all acceptance and reconstruction use the typed bytes above.
	if packet.context != restored and packet.context != parser.data:
		return failed
	return {"ok": true, "value": restored, "raw_sha256": Archive._sha256(raw)}


static func same_packet(a: Dictionary, b: Dictionary) -> bool:
	for field: String in FIELDS:
		if not a.has(field) or not b.has(field) or a[field] != b[field]:
			return false
	return true


static func _numeric_only(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			for child: Variant in value:
				if not _numeric_only(child, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value:
				if not key is String or not _numeric_only(value[key], depth + 1):
					return false
			return true
	return false


static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _hash(value: Variant) -> bool:
	return value is String and value.length() == 64 and _hex(value, 64)


static func _hex(value: Variant, maximum: int) -> bool:
	if (
		not value is String
		or value.is_empty()
		or value.length() % 2 != 0
		or value.length() > maximum
	):
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

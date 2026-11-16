extends RefCounted
## Lossless native evidence with shared, all-file accounting and an append-only journal.
## A complete triplet is encoded and admitted before any of its PNG files are created.

const Archive = preload("res://src/tests/stadium_long_yard_history_archive.gd")
const ContextCodec = preload("res://src/tests/stadium_long_yard_receipt_codec.gd")
const MAX_BYTES: int = 384 * 1024 * 1024
const CONTROLLER_MAX_BYTES: int = 36 * 1024 * 1024
const RECEIPT_HEADROOM: int = 2 * 1024 * 1024
const CONTROLLER_RECEIPT_HEADROOM: int = 512 * 1024
const MAX_EVENT_BYTES: int = 256 * 1024
const JOURNAL_NAME: String = "long-yard-evidence-receipts.jsonl"
const FULL_PROFILE: String = "full-native-384MiB"
const CONTROLLER_PROFILE: String = "bounded-controller-36MiB"
const EXTENTS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(700, 393)]
const PNG_SIGNATURE: Array[int] = [137, 80, 78, 71, 13, 10, 26, 10]


static func save(value: Image, path: String) -> bool:
	return _save(value, path, false)


static func save_controller(value: Image, path: String) -> bool:
	return _save(value, path, true)


static func _save(value: Image, path: String, controller: bool) -> bool:
	var images: Array[Image] = [value]
	var paths: Array[String] = [path]
	return _run(images, paths, {}, path, "standalone", _policy(path, controller)).ok


static func save_triplet(
	images: Array[Image], stem: String, context: Dictionary, controller: bool = false
) -> Dictionary:
	var paths: Array[String] = []
	for suffix: String in ["-visible.png", "-hidden.png", "-hidden-control.png"]:
		paths.append(stem + suffix)
	return _run(images, paths, context, stem, "triplet", _policy(stem, controller))


static func record_readbacks(images: Array[Image], context: Dictionary, path: String) -> bool:
	var paths: Array[String] = []
	return _run(images, paths, context, path, "readbacks", _policy(path, false)).ok


static func record_receipt(context: Dictionary, path: String, controller: bool = false) -> bool:
	var images: Array[Image] = []
	var paths: Array[String] = []
	return _run(images, paths, context, path, "metadata", _policy(path, controller)).ok


static func budget_root(path: String) -> String:
	var root: String = path.get_base_dir()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--long-yard-evidence-budget-root="):
			root = argument.trim_prefix("--long-yard-evidence-budget-root=")
	return _absolute(root)


static func journal_path(path: String) -> String:
	return budget_root(path).path_join(JOURNAL_NAME)


static func fits_budget(used: int, incoming: int, limit: int) -> bool:
	return limit in [MAX_BYTES, CONTROLLER_MAX_BYTES] and _within(used, incoming, limit)


static func _within(used: int, incoming: int, limit: int) -> bool:
	# Subtraction avoids overflow, including in negative-control fixtures.
	return used >= 0 and incoming > 0 and limit > 0 and used <= limit - incoming


static func _policy(path: String, controller: bool) -> Dictionary:
	return {
		"root": budget_root(path),
		"limit": CONTROLLER_MAX_BYTES if controller else MAX_BYTES,
		"profile": CONTROLLER_PROFILE if controller else FULL_PROFILE,
		"native_only": true,
		"headroom": CONTROLLER_RECEIPT_HEADROOM if controller else RECEIPT_HEADROOM
	}


static func _run(
	images: Array[Image],
	paths: Array[String],
	context: Dictionary,
	logical_path: String,
	kind: String,
	policy: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var encoded: Variant = Archive._numeric(context, errors)
	var prepared: Dictionary = _prepare(images, paths, kind, policy.native_only)
	var receipt: Dictionary = {
		"version": 2,
		"event_index": -1,
		"attempt_id": -1,
		"receipt_key": kind + ":" + _absolute(logical_path),
		"profile": policy.profile,
		"limit_bytes": policy.limit,
		"kind": kind,
		"status": "refused",
		"ok": false,
		"images": prepared.images,
		"context": encoded,
		"error": "",
		"journaled": false
	}
	receipt.merge(ContextCodec.seal(encoded), true)
	var state: Dictionary = _read_journal(policy.root)
	if not state.ok:
		receipt.error = "unreadable_or_invalid_journal"
		return receipt
	receipt.event_index = state.events.size()
	receipt.attempt_id = state.events.size()
	var problem: String = _preflight(prepared, receipt, state, policy, logical_path)
	if not errors.is_empty() or not ContextCodec.restore(receipt).ok:
		problem = "unsupported_nonfinite_or_inexact_context"
		receipt.merge(
			ContextCodec.seal(
				{
					"rejected_numeric_context_sha256": Archive._sha256(var_to_bytes(encoded)),
					"numeric_error_count": errors.size(),
					"numeric_errors": errors.slice(0, 32),
					"reason": problem
				}
			),
			true
		)
	if not problem.is_empty():
		return _refuse(receipt, policy, problem)
	var begin: Dictionary = receipt.duplicate(true)
	begin.status = "admitted"
	begin.journaled = true
	var terminal: Dictionary = receipt.duplicate(true)
	terminal.status = "saved" if not paths.is_empty() else "recorded"
	terminal.ok = true
	terminal.journaled = true
	terminal.event_index += 1
	# Reserve both durable events and a longer failed completion before any PNG write.
	var receipt_bytes: int = _event_bytes(begin).size() + _event_bytes(terminal).size() + 1024
	var admission: Dictionary = _admission(
		_size(policy.root), prepared.png_bytes, receipt_bytes, policy.limit, policy.headroom
	)
	if not admission.ok:
		return _refuse(receipt, policy, admission.error)
	if not _append(begin, policy):
		receipt.error = "admission_journal_write_failed"
		return receipt
	for index: int in range(prepared.payloads.size()):
		var row: Dictionary = prepared.images[index]
		var png: PackedByteArray = prepared.payloads[index]
		# Never overwrite an output, even if it appeared after the group preflight.
		if _exists(row.path) or not _write_new(row.path, png):
			terminal.ok = false
			terminal.status = "failed"
			terminal.error = "png_create_or_flush_failed"
			break
		var actual: PackedByteArray = FileAccess.get_file_as_bytes(row.path)
		if actual != png or not _matches_png(actual, row, prepared.raw[index]):
			terminal.ok = false
			terminal.status = "failed"
			terminal.error = "png_or_raw_readback_mismatch"
			break
	if not _append(terminal, policy):
		terminal.ok = false
		terminal.status = "failed"
		terminal.error = "completion_journal_write_failed"
		terminal.journaled = false
	return terminal


static func _preflight(
	prepared: Dictionary,
	receipt: Dictionary,
	state: Dictionary,
	policy: Dictionary,
	logical_path: String
) -> String:
	if not prepared.ok:
		return prepared.error
	if not _inside(_absolute(logical_path), policy.root):
		return "receipt_path_outside_budget_root"
	for event: Dictionary in state.events:
		if event.profile != policy.profile or int(event.limit_bytes) != int(policy.limit):
			return "mixed_evidence_profiles"
	if state.claims.has(receipt.receipt_key):
		return "duplicate_receipt"
	var seen: Dictionary = {}
	for row: Dictionary in prepared.images:
		if not row.has("path"):
			continue
		if not _inside(row.path, policy.root):
			return "png_path_outside_budget_root"
		if seen.has(row.path) or state.paths.has(row.path) or _exists(row.path):
			return "existing_or_duplicate_output"
		seen[row.path] = true
	if _event_bytes(receipt).size() + 1024 > MAX_EVENT_BYTES:
		return "receipt_too_large"
	return ""


static func _admission(
	used: int, png_bytes: int, receipt_bytes: int, limit: int, headroom: int
) -> Dictionary:
	if used < 0 or png_bytes < 0 or receipt_bytes <= 0 or headroom < 0:
		return {"ok": false, "error": "invalid_or_unreadable_budget"}
	if not _within(used, png_bytes + receipt_bytes + headroom, limit):
		return {"ok": false, "error": "shared_budget_exceeded_before_png_write"}
	return {"ok": true, "error": ""}


static func _refuse(receipt: Dictionary, policy: Dictionary, reason: String) -> Dictionary:
	receipt.status = "refused"
	receipt.error = reason
	receipt.journaled = true
	if _event_bytes(receipt).size() > MAX_EVENT_BYTES:
		# An oversized caller context cannot consume the reserved refusal headroom.
		receipt.merge(
			ContextCodec.seal({"rejected_context_sha256": _sha256(_event_bytes(receipt))}), true
		)
		receipt.images = []
	if not _append(receipt, policy):
		receipt.journaled = false
		receipt["journal_error"] = "refusal_journal_unwritable_or_budget_exhausted"
	return receipt


static func _prepare(
	images: Array[Image], paths: Array[String], kind: String, native_only: bool
) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"error": "invalid_image_count",
		"images": [],
		"payloads": [],
		"raw": [],
		"png_bytes": 0
	}
	if (
		(kind == "triplet" and (images.size() != 3 or paths.size() != 3))
		or (kind == "standalone" and (images.size() != 1 or paths.size() != 1))
		or (kind == "readbacks" and (images.is_empty() or not paths.is_empty()))
		or (kind == "metadata" and (not images.is_empty() or not paths.is_empty()))
		or kind not in ["triplet", "standalone", "readbacks", "metadata"]
	):
		return result
	var extent: Vector2i = Vector2i.ZERO
	var format: int = -1
	for index: int in range(images.size()):
		var value: Image = images[index]
		if not _supported(value, native_only):
			result.error = "unknown_extent_format_or_empty_image"
			return result
		if index > 0 and (value.get_size() != extent or value.get_format() != format):
			result.error = "inconsistent_readback_extent_or_format"
			return result
		extent = value.get_size()
		format = value.get_format()
		var raw: PackedByteArray = value.get_data()
		var row: Dictionary = {
			"index": index,
			"raw_bytes": raw.size(),
			"raw_sha256": _sha256(raw),
			"format": format,
			"extent": [extent.x, extent.y]
		}
		if not paths.is_empty():
			var png: PackedByteArray = value.save_png_to_buffer()
			row["path"] = _absolute(paths[index])
			row["bytes"] = png.size()
			row["png_sha256"] = _sha256(png)
			if not _matches_png(png, row, raw):
				result.error = "encoded_png_not_lossless"
				return result
			result.payloads.append(png)
			result.raw.append(raw)
			result.png_bytes += png.size()
		result.images.append(row)
	result.ok = true
	result.error = ""
	return result


static func _supported(value: Image, native_only: bool) -> bool:
	if value == null or value.is_empty() or value.has_mipmaps():
		return false
	if value.get_format() not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		return false
	if native_only and value.get_size() not in EXTENTS:
		return false
	var channels: int = 3 if value.get_format() == Image.FORMAT_RGB8 else 4
	return value.get_data().size() == value.get_width() * value.get_height() * channels


static func _matches_png(
	png: PackedByteArray, row: Dictionary, original: PackedByteArray = PackedByteArray()
) -> bool:
	if (
		not _valid_image_row(row, true)
		or png.size() != int(row.bytes)
		or _sha256(png) != row.png_sha256
		or png.size() < 33
	):
		return false
	for index: int in range(PNG_SIGNATURE.size()):
		if png[index] != PNG_SIGNATURE[index]:
			return false
	if png.slice(12, 16).get_string_from_ascii() != "IHDR":
		return false
	var decoded: Image = Image.new()
	if decoded.load_png_from_buffer(png) != OK:
		return false
	var raw: PackedByteArray = decoded.get_data()
	return (
		decoded.get_size() == Vector2i(int(row.extent[0]), int(row.extent[1]))
		and decoded.get_format() == int(row.format)
		and raw.size() == int(row.raw_bytes)
		and _sha256(raw) == row.raw_sha256
		and (original.is_empty() or raw == original)
	)


static func _valid_image_row(row: Dictionary, retained: bool) -> bool:
	var extent: Variant = row.get("extent")
	if (
		not extent is Array
		or extent.size() != 2
		or not _integer(extent[0])
		or not _integer(extent[1])
		or not _integer(row.get("format"))
		or not _integer(row.get("raw_bytes"))
		or not _digest_valid(row.get("raw_sha256", ""))
	):
		return false
	var format: int = int(row.format)
	if format not in [Image.FORMAT_RGB8, Image.FORMAT_RGBA8]:
		return false
	var width: int = int(extent[0])
	var height: int = int(extent[1])
	var channels: int = 3 if format == Image.FORMAT_RGB8 else 4
	if (
		width <= 0
		or height <= 0
		or width > 16384
		or height > 16384
		or int(row.raw_bytes) != width * height * channels
	):
		return false
	return (
		not retained
		or (
			row.get("path") is String
			and _integer(row.get("bytes"))
			and int(row.bytes) > 0
			and _digest_valid(row.get("png_sha256", ""))
		)
	)


static func _integer(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value) and value == floor(value))


static func _digest_valid(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func _event_bytes(receipt: Dictionary) -> PackedByteArray:
	return (JSON.stringify(receipt, "", true, true) + "\n").to_utf8_buffer()


static func _append(receipt: Dictionary, policy: Dictionary) -> bool:
	var bytes: PackedByteArray = _event_bytes(receipt)
	if (
		bytes.size() > MAX_EVENT_BYTES
		or not _within(_size(policy.root), bytes.size(), policy.limit)
	):
		return false
	if DirAccess.make_dir_recursive_absolute(policy.root) != OK:
		return false
	var path: String = policy.root.path_join(JOURNAL_NAME)
	var mode: int = FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ
	var file: FileAccess = FileAccess.open(path, mode)
	if file == null:
		return false
	file.seek_end()
	var offset: int = file.get_position()
	file.store_buffer(bytes)
	file.flush()
	var succeeded: bool = file.get_error() == OK and file.get_position() == offset + bytes.size()
	file.seek(offset)
	var actual: PackedByteArray = file.get_buffer(bytes.size())
	file.close()
	return succeeded and actual == bytes


static func _write_new(path: String, bytes: PackedByteArray) -> bool:
	if _exists(path) or DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var succeeded: bool = file.get_error() == OK and file.get_position() == bytes.size()
	file.close()
	return succeeded


static func _read_journal(root: String) -> Dictionary:
	var result: Dictionary = {"ok": true, "events": [], "latest": {}, "claims": {}, "paths": {}}
	var path: String = root.path_join(JOURNAL_NAME)
	if not FileAccess.file_exists(path):
		result.ok = not DirAccess.dir_exists_absolute(path)
		return result
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		result.ok = false
		return result
	var text: String = file.get_as_text()
	file.close()
	if text.is_empty() or not text.ends_with("\n"):
		result.ok = false
		return result
	for line: String in text.trim_suffix("\n").split("\n"):
		var parser: JSON = JSON.new()
		if parser.parse(line) != OK or not parser.data is Dictionary:
			result.ok = false
			return result
		var row: Dictionary = parser.data
		if not _consume_event(result, row):
			result.ok = false
			return result
	return result


static func _consume_event(state: Dictionary, row: Dictionary) -> bool:
	if (
		row.get("version") != 2
		or row.get("event_index") != state.events.size()
		or not _integer(row.get("attempt_id"))
		or not row.get("receipt_key") is String
		or not row.get("profile") is String
		or not _integer(row.get("limit_bytes"))
		or not row.get("images") is Array
		or not row.get("context") is Dictionary
		or not row.get("ok") is bool
		or not row.get("error") is String
		or row.get("journaled") != true
		or row.get("kind") not in ["triplet", "standalone", "readbacks", "metadata"]
		or row.get("status") not in ["admitted", "saved", "recorded", "failed", "refused"]
	):
		return false
	if not ContextCodec.restore(row).ok:
		return false
	var attempt: int = int(row.attempt_id)
	if row.status in ["saved", "recorded", "failed"]:
		if not state.latest.has(attempt):
			return false
		var prior: Dictionary = state.latest[attempt]
		if (
			prior.status != "admitted"
			or row.receipt_key != prior.receipt_key
			or row.profile != prior.profile
			or row.kind != prior.kind
			or row.limit_bytes != prior.limit_bytes
			or row.images != prior.images
			or not ContextCodec.same_packet(row, prior)
			or row.ok != (row.status in ["saved", "recorded"])
		):
			return false
	else:
		if attempt != state.events.size() or state.latest.has(attempt) or row.ok:
			return false
		if row.status == "admitted" and state.claims.has(row.receipt_key):
			return false
		state.claims[row.receipt_key] = attempt
		if row.status == "admitted":
			for image_value: Variant in row.images:
				if not image_value is Dictionary:
					return false
				var image_row: Dictionary = image_value
				if image_row.has("path"):
					if state.paths.has(image_row.path):
						return false
					state.paths[image_row.path] = attempt
	state.events.append(row)
	state.latest[attempt] = row
	return true


static func verify_inventory(root: String, controller: bool = false) -> Dictionary:
	var policy: Dictionary = _policy(root.path_join("inventory"), controller)
	# The explicit root is authoritative here; verification never redirects to CLI output.
	policy.root = _absolute(root)
	return _verify_inventory(policy)


static func _verify_inventory(policy: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var result: Dictionary = {
		"ok": false,
		"errors": errors,
		"png_count": 0,
		"triplet_count": 0,
		"standalone_count": 0,
		"raw_readback_receipt_count": 0,
		"raw_readback_count": 0,
		"metadata_receipt_count": 0,
		"refused_count": 0,
		"failed_count": 0,
		"pending_count": 0,
		"used_bytes": _size(policy.root),
		"limit_bytes": policy.limit,
		"journal_path": policy.root.path_join(JOURNAL_NAME),
		"images": [],
		"standalone_paths": [],
		"triplet_keys": [],
		"readback_keys": []
	}
	var state: Dictionary = _read_journal(policy.root)
	if not state.ok:
		errors.append("invalid_or_unreadable_journal")
		return result
	if state.events.is_empty():
		errors.append("missing_receipt_journal")
	var expected: Dictionary = {}
	for event: Dictionary in state.events:
		if event.profile != policy.profile or int(event.limit_bytes) != int(policy.limit):
			errors.append("mixed_or_wrong_profile")
	for receipt: Dictionary in state.latest.values():
		if receipt.status not in ["saved", "recorded"]:
			var key: String = {
				"refused": "refused_count", "failed": "failed_count", "admitted": "pending_count"
			}[receipt.status]
			result[key] += 1
			errors.append("unsuccessful_attempt:" + receipt.receipt_key)
			continue
		_check_inventory_receipt(receipt, policy, expected, result, errors)
	var files: Array[String] = []
	if not _files(policy.root, files):
		errors.append("unreadable_or_linked_inventory")
	for path: String in files:
		if path.get_extension().to_lower() == "png" and not expected.has(path):
			errors.append("unlisted_png:" + path)
	if result.used_bytes < 0 or result.used_bytes > policy.limit:
		errors.append("all_file_budget_exceeded_or_unreadable")
	result.ok = errors.is_empty()
	return result


static func _check_inventory_receipt(
	receipt: Dictionary,
	policy: Dictionary,
	expected: Dictionary,
	result: Dictionary,
	errors: Array[String]
) -> void:
	var retained: bool = receipt.kind in ["triplet", "standalone"]
	var count: int = receipt.images.size()
	if (
		(receipt.kind == "triplet" and count != 3)
		or (receipt.kind == "standalone" and count != 1)
		or (receipt.kind == "readbacks" and count == 0)
		or (receipt.kind == "metadata" and count != 0)
		or receipt.status != ("saved" if retained else "recorded")
	):
		errors.append("receipt_image_count_or_status_mismatch")
		return
	var count_key: String = {
		"triplet": "triplet_count",
		"standalone": "standalone_count",
		"readbacks": "raw_readback_receipt_count",
		"metadata": "metadata_receipt_count"
	}[receipt.kind]
	result[count_key] += 1
	if receipt.kind == "triplet":
		result.triplet_keys.append(receipt.receipt_key)
	elif receipt.kind == "readbacks":
		result.readback_keys.append(receipt.receipt_key)
	for index: int in range(count):
		if not receipt.images[index] is Dictionary:
			errors.append("invalid_image_inventory_row")
			continue
		var row: Dictionary = receipt.images[index]
		if not _valid_image_row(row, retained) or int(row.get("index", -1)) != index:
			errors.append("invalid_image_inventory_row")
			continue
		var extent: Vector2i = Vector2i(int(row.extent[0]), int(row.extent[1]))
		if policy.native_only and extent not in EXTENTS:
			errors.append("unknown_native_extent")
		if not retained:
			result.raw_readback_count += 1
			continue
		if not _inside(row.path, policy.root) or expected.has(row.path):
			errors.append("duplicate_or_outside_png:" + row.path)
			continue
		expected[row.path] = row
		result.images.append(row)
		if receipt.kind == "standalone":
			result.standalone_paths.append(row.path)
		result.png_count += 1
		if not FileAccess.file_exists(row.path):
			errors.append("missing_png:" + row.path)
		elif not _matches_png(FileAccess.get_file_as_bytes(row.path), row):
			errors.append("png_or_raw_hash_mismatch:" + row.path)


static func capture(owner: Node, native: Node, directory: String, label: String) -> bool:
	for frame in range(8):
		await owner.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var value: Image = owner.get_viewport().get_texture().get_image()
	var window: Window = owner.get_window()
	var extent: Vector2i = window.size
	var expected: Vector2i = native._expected_content_size(extent)
	if (
		value == null
		or value.is_empty()
		or value.get_size() != expected
		or DisplayServer.window_get_size(window.get_window_id()) != extent
		or expected not in EXTENTS
	):
		return false
	return save(value, directory.path_join("%s-%dx%d.png" % [label, expected.x, expected.y]))


static func _absolute(path: String) -> String:
	var value: String = ProjectSettings.globalize_path(path)
	if not value.is_absolute_path():
		value = ProjectSettings.globalize_path("res://").path_join(value)
	return value.simplify_path().trim_suffix("/")


static func _inside(path: String, root: String) -> bool:
	return not root.is_empty() and path.begins_with(root.trim_suffix("/") + "/")


static func _exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


static func _files(path: String, result: Array[String]) -> bool:
	if not DirAccess.dir_exists_absolute(path):
		return not FileAccess.file_exists(path)
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return false
	directory.include_hidden = true
	for name_value: String in directory.get_files():
		if directory.is_link(name_value):
			return false
		result.append(path.path_join(name_value))
	for name_value: String in directory.get_directories():
		if directory.is_link(name_value) or not _files(path.path_join(name_value), result):
			return false
	return true


static func _size(path: String) -> int:
	var files: Array[String] = []
	if not _files(path, files):
		return -1
	var total: int = 0
	for item: String in files:
		var file: FileAccess = FileAccess.open(item, FileAccess.READ)
		if file == null:
			return -1
		total += file.get_length()
		file.close()
	return total


static func _sha256(value: PackedByteArray) -> String:
	return Archive._sha256(value)

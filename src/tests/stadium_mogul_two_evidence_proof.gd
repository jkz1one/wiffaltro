extends RefCounted
## Tiny, isolated retention controls. No render resources, shared-root writes or file deletion.

const Evidence = preload("res://src/tests/stadium_mogul_two_evidence.gd")
const Archive = preload("res://src/tests/stadium_mogul_two_history_archive.gd")
const Probe = preload("res://src/tests/stadium_mogul_two_receipt_probe.gd")
const ContextCodec = preload("res://src/tests/stadium_mogul_two_receipt_codec.gd")
const FIXTURE_LIMIT: int = 1024 * 1024
const FIXTURE_HEADROOM: int = 4096


static func run(owner: Node) -> void:
	_budget_controls(owner)
	var root: String = ProjectSettings.globalize_path("user://am01-evidence-proof").path_join(
		"%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	)
	var shared: String = Evidence.budget_root("res://project.godot")
	var isolated: bool = not Evidence._inside(root, shared) and root != shared
	owner._check(isolated and not Evidence._exists(root), "evidence proof has a fresh private root")
	if not isolated or Evidence._exists(root):
		return
	var images: Array[Image] = _images()
	owner._check(
		not Evidence._supported(images[0], true) and Evidence._supported(images[0], false),
		"tiny fixture dimensions can never pass the native public writer"
	)
	var unsupported: Image = Image.create(2, 2, false, Image.FORMAT_RF)
	owner._check(
		not Evidence._supported(unsupported, false), "unknown or lossy native formats fail closed"
	)
	_good_inventory(owner, root.path_join("complete"), images)
	_refused_triplet(owner, root.path_join("overflow"), images)
	_missing_inventory(owner, root.path_join("missing"), images)
	_hash_controls(owner, root.path_join("hashes"), images)
	_journal_controls(owner, root.path_join("journals"), images)
	_invalid_context_refusals(owner, root.path_join("invalid-context"), images)
	_context_controls(owner)
	print("MOGUL_TWO_EVIDENCE_PROOF isolated=true render_resources=false retained_fixture=", root)


static func _budget_controls(owner: Node) -> void:
	for limit: int in [Evidence.MAX_BYTES, Evidence.CONTROLLER_MAX_BYTES]:
		owner._check(
			Evidence.fits_budget(limit - 1, 1, limit), "evidence cap admits exact last byte"
		)
		owner._check(
			not Evidence.fits_budget(limit, 1, limit), "evidence cap rejects first overflow"
		)
		owner._check(not Evidence.fits_budget(-1, 1, limit), "unreadable byte count fails closed")
		owner._check(not Evidence.fits_budget(0, -1, limit), "negative evidence bytes fail closed")
		owner._check(not Evidence.fits_budget(0, 0, limit), "empty evidence bytes fail closed")
		var pending: int = 99
		var bookkeeping: int = 11
		var headroom: int = 7
		var remaining: int = pending + bookkeeping + headroom
		owner._check(
			Evidence._admission(limit - remaining, pending, bookkeeping, limit, headroom).ok,
			"whole-triplet accounting admits last byte including journal and refusal reserve"
		)
		owner._check(
			not (
				Evidence._admission(limit - remaining + 1, pending, bookkeeping, limit, headroom).ok
			),
			"whole-triplet accounting refuses first overflow before writing any image"
		)
	owner._check(
		not Evidence.fits_budget(0, 1, 10 * 1024 * 1024),
		"obsolete10MiB and unrecognized profiles cannot silently authorize writes"
	)


static func _images() -> Array[Image]:
	var result: Array[Image] = []
	for index: int in range(3):
		var value: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
		value.fill(Color(0.1 * index, 0.2, 0.3, 0.5))
		value.set_pixel(index % 2, index / 2, Color(0.9, 0.8, 0.7, 1))
		result.append(value)
	return result


static func _policy(root: String) -> Dictionary:
	return {
		"root": root,
		"limit": FIXTURE_LIMIT,
		"profile": "isolated-proof-only",
		"native_only": false,
		"headroom": FIXTURE_HEADROOM
	}


static func _paths(stem: String) -> Array[String]:
	return [stem + "-visible.png", stem + "-hidden.png", stem + "-hidden-control.png"]


static func _good_inventory(owner: Node, root: String, images: Array[Image]) -> void:
	var policy: Dictionary = _policy(root)
	var stem: String = root.path_join("triplet")
	var receipt: Dictionary = Evidence._run(
		images, _paths(stem), {"pose": Transform3D.IDENTITY}, stem, "triplet", policy
	)
	owner._check(receipt.ok and receipt.images.size() == 3, "fixture retains the complete triplet")
	if not receipt.ok:
		return
	var singleton: Array[Image] = [images[0]]
	var standalone_paths: Array[String] = [root.path_join("standalone.png")]
	owner._check(
		(
			Evidence
			. _run(singleton, standalone_paths, {}, standalone_paths[0], "standalone", policy)
			. ok
		),
		"standalone shares durable raw and PNG hash bookkeeping"
	)
	var readbacks: Array[Image] = [images[0], images[1], images[1], images[0]]
	var no_paths: Array[String] = []
	owner._check(
		(
			Evidence
			. _run(
				readbacks,
				no_paths,
				{"subject": "fixture"},
				root.path_join("raw"),
				"readbacks",
				policy
			)
			. ok
		),
		"readback-only witness records four exact raw hashes without retaining more PNGs"
	)
	var no_images: Array[Image] = []
	owner._check(
		(
			Evidence
			. _run(
				no_images,
				no_paths,
				{"expected_png_count": 4},
				root.path_join("manifest"),
				"metadata",
				policy
			)
			. ok
		),
		"final structured inventory appends instead of replacing earlier process receipts"
	)
	var verified: Dictionary = Evidence._verify_inventory(policy)
	owner._check(
		(
			verified.ok
			and verified.png_count == 4
			and verified.triplet_count == 1
			and verified.standalone_count == 1
			and verified.raw_readback_receipt_count == 1
			and verified.raw_readback_count == 4
			and verified.metadata_receipt_count == 1
			and verified.standalone_paths == standalone_paths
			and verified.triplet_keys == ["triplet:" + stem]
			and verified.readback_keys == ["readbacks:" + root.path_join("raw")]
		),
		"fresh journal scan reconciles exact retained images and raw-only witness receipts"
	)
	var before: int = Evidence._size(root)
	owner._check(
		Evidence._write_new(root.path_join("also-counted.bin"), PackedByteArray([1, 2, 3])),
		"fixture includes a non-PNG byte-accounting control"
	)
	owner._check(
		Evidence._size(root) == before + 3 and Evidence._verify_inventory(policy).ok,
		"shared cap counts every file byte, including journal and non-image files"
	)
	var duplicate: Dictionary = Evidence._run(images, _paths(stem), {}, stem, "triplet", policy)
	owner._check(
		(
			not duplicate.ok
			and duplicate.journaled
			and duplicate.status == "refused"
			and duplicate.error == "duplicate_receipt"
		),
		"duplicate logical receipt is durably refused rather than overwritten"
	)
	for row: Dictionary in receipt.images:
		owner._check(
			FileAccess.get_sha256(row.path) == row.png_sha256,
			"duplicate refusal leaves the original PNG bytes unchanged"
		)
	var collision: Dictionary = Evidence._run(
		images, _paths(stem), {}, root.path_join("new-receipt"), "triplet", policy
	)
	owner._check(
		(
			not collision.ok
			and collision.journaled
			and collision.error == "existing_or_duplicate_output"
		),
		"a new receipt cannot reuse any existing output path"
	)
	var rejected: Dictionary = Evidence._verify_inventory(policy)
	owner._check(
		not rejected.ok and rejected.refused_count == 2 and rejected.png_count == 4,
		"inventory preserves both refused attempts and cannot mislabel them as successful"
	)


static func _refused_triplet(owner: Node, root: String, images: Array[Image]) -> void:
	var policy: Dictionary = _policy(root)
	policy.limit = FIXTURE_HEADROOM
	var stem: String = root.path_join("never-written")
	var receipt: Dictionary = Evidence._run(images, _paths(stem), {}, stem, "triplet", policy)
	owner._check(
		(
			not receipt.ok
			and receipt.status == "refused"
			and receipt.journaled
			and receipt.error == "shared_budget_exceeded_before_png_write"
		),
		"whole-triplet overflow leaves a durable refused status"
	)
	for path: String in _paths(stem):
		owner._check(not Evidence._exists(path), "overflow writes none of the three triplet files")
	var journal: Dictionary = Evidence._read_journal(root)
	owner._check(
		(
			journal.ok
			and journal.events.size() == 1
			and journal.events[0].status == "refused"
			and Evidence._size(root) <= policy.limit
		),
		"refusal receipt itself remains inside the same all-file cap"
	)


static func _missing_inventory(owner: Node, root: String, images: Array[Image]) -> void:
	var policy: Dictionary = _policy(root)
	var stem: String = root.path_join("missing-member")
	var prepared: Dictionary = Evidence._prepare(images, _paths(stem), "triplet", false)
	owner._check(
		_claim(policy, prepared.images, stem), "missing-file control records expected inventory"
	)
	for index: int in range(2):
		owner._check(
			Evidence._write_new(prepared.images[index].path, prepared.payloads[index]),
			"missing-file fixture creates only its first two PNGs"
		)
	var verified: Dictionary = Evidence._verify_inventory(policy)
	owner._check(
		not verified.ok and _has_error(verified, "missing_png:"),
		"inventory rejects a missing required triplet member without deleting a fixture file"
	)
	var extra_policy: Dictionary = _policy(root.path_join("unlisted"))
	var extra_stem: String = extra_policy.root.path_join("listed")
	owner._check(
		Evidence._run(images, _paths(extra_stem), {}, extra_stem, "triplet", extra_policy).ok,
		"unlisted-file fixture starts from a complete valid triplet"
	)
	owner._check(
		Evidence._write_new(extra_policy.root.path_join("unlisted.png"), prepared.payloads[0]),
		"unlisted-file control adds one extra native-like PNG"
	)
	var extra: Dictionary = Evidence._verify_inventory(extra_policy)
	owner._check(
		not extra.ok and _has_error(extra, "unlisted_png:"),
		"unlisted retained PNG cannot disappear from exact inventory reconciliation"
	)


static func _hash_controls(owner: Node, root: String, images: Array[Image]) -> void:
	for scenario: String in ["corrupt_png", "png_hash", "raw_hash"]:
		var policy: Dictionary = _policy(root.path_join(scenario))
		var stem: String = policy.root.path_join("triplet")
		var prepared: Dictionary = Evidence._prepare(images, _paths(stem), "triplet", false)
		if scenario == "png_hash":
			prepared.images[0].png_sha256 = "0".repeat(64)
		elif scenario == "raw_hash":
			prepared.images[0].raw_sha256 = "0".repeat(64)
		owner._check(
			_claim(policy, prepared.images, stem), "hash control records its declared inventory"
		)
		for index: int in range(3):
			var bytes: PackedByteArray = prepared.payloads[index].duplicate()
			if scenario == "corrupt_png" and index == 0:
				# Hash/byte rejection precedes decoder invocation, so no expected engine error leaks.
				bytes[0] = 0
			owner._check(
				Evidence._write_new(prepared.images[index].path, bytes),
				"hash fixture stores new files without touching any genuine evidence"
			)
		var verified: Dictionary = Evidence._verify_inventory(policy)
		owner._check(
			not verified.ok and _has_error(verified, "png_or_raw_hash_mismatch:"),
			"exact inventory rejects " + scenario + " independently"
		)


static func _claim(policy: Dictionary, rows: Array, stem: String) -> bool:
	# Deliberately incomplete/corrupt fixtures are produced without deleting or overwriting files.
	var admission: Dictionary = {
		"version": 2,
		"event_index": 0,
		"attempt_id": 0,
		"receipt_key": "triplet:" + stem,
		"profile": policy.profile,
		"limit_bytes": policy.limit,
		"kind": "triplet",
		"status": "admitted",
		"ok": false,
		"images": rows,
		"context": {},
		"error": "",
		"journaled": true
	}
	admission.merge(ContextCodec.seal({}), true)
	var completion: Dictionary = admission.duplicate(true)
	completion.event_index = 1
	completion.status = "saved"
	completion.ok = true
	return Evidence._append(admission, policy) and Evidence._append(completion, policy)


static func _journal_controls(owner: Node, root: String, images: Array[Image]) -> void:
	var missing: Dictionary = Evidence._verify_inventory(_policy(root.path_join("absent")))
	owner._check(
		not missing.ok and _has_error(missing, "missing_receipt_journal"),
		"absent journal cannot certify an inventory"
	)
	var corrupt: Dictionary = _policy(root.path_join("corrupt"))
	owner._check(
		Evidence._write_new(corrupt.root.path_join(Evidence.JOURNAL_NAME), "{\n".to_utf8_buffer()),
		"journal corruption fixture is isolated"
	)
	owner._check(not Evidence._verify_inventory(corrupt).ok, "corrupt journal fails closed")
	var policy: Dictionary = _policy(root.path_join("duplicates"))
	var stem: String = policy.root.path_join("triplet")
	owner._check(
		Evidence._run(images, _paths(stem), {}, stem, "triplet", policy).ok,
		"journal duplicate control starts from verified evidence"
	)
	var state: Dictionary = Evidence._read_journal(policy.root)
	owner._check(
		state.ok and not Evidence._consume_event(state, state.events[0].duplicate(true)),
		"duplicate journal sequence and admission are rejected independently of filenames"
	)
	var mixed: Dictionary = policy.duplicate(true)
	mixed.profile = Evidence.CONTROLLER_PROFILE
	mixed.limit = Evidence.CONTROLLER_MAX_BYTES
	owner._check(
		not Evidence._verify_inventory(mixed).ok,
		"full and bounded profiles cannot be relabeled or mixed"
	)
	var pending_policy: Dictionary = _policy(root.path_join("pending"))
	var pending: Dictionary = state.events[0].duplicate(true)
	pending.receipt_key = "triplet:" + pending_policy.root.path_join("pending")
	owner._check(
		Evidence._append(pending, pending_policy), "interrupted-write fixture records admission"
	)
	var interrupted: Dictionary = Evidence._verify_inventory(pending_policy)
	owner._check(
		not interrupted.ok and interrupted.pending_count == 1,
		"an admitted group without completion cannot masquerade as a successful save"
	)


static func _invalid_context_refusals(owner: Node, root: String, images: Array[Image]) -> void:
	for scenario: String in ["nonfinite", "object", "oversized"]:
		var policy: Dictionary = _policy(root.path_join(scenario))
		var bad: Dictionary = {"bad": INF}
		if scenario == "object":
			bad = {"bad": owner}
		elif scenario == "oversized":
			bad = {"bad": "x".repeat(ContextCodec.MAX_RAW_BYTES)}
		var stem: String = policy.root.path_join("refused")
		var refused: Dictionary = Evidence._run(images, _paths(stem), bad, stem, "triplet", policy)
		owner._check(
			(
				not refused.ok
				and refused.journaled
				and refused.error == "unsupported_nonfinite_or_inexact_context"
			),
			"invalid context is durably refused with a freshly sealed safe diagnostic: " + scenario
		)
		for path: String in _paths(stem):
			owner._check(not Evidence._exists(path), "invalid context creates no PNG")
		var reread: Dictionary = Evidence._read_journal(policy.root)
		owner._check(
			(
				reread.ok
				and reread.events.size() == 1
				and ContextCodec.restore(reread.events[0]).ok
				and reread.events[0].status == "refused"
			),
			"refusal remains an exact readable journal event: " + scenario
		)
		var good_stem: String = policy.root.path_join("subsequent-valid")
		var good: Dictionary = Evidence._run(
			images, _paths(good_stem), {"valid": true}, good_stem, "triplet", policy
		)
		owner._check(good.ok, "prior context refusal does not poison a later valid journal append")
		var inventory: Dictionary = Evidence._verify_inventory(policy)
		owner._check(
			(
				not inventory.ok
				and inventory.refused_count == 1
				and inventory.triplet_count == 1
				and inventory.png_count == 3
			),
			"later valid evidence never erases the original refused attempt"
		)


static func _context_controls(owner: Node) -> void:
	var errors: Array[String] = []
	var pose: Transform3D = Transform3D(
		Basis(Vector3.UP, 0.123456789), Vector3(1.23456789, -9.87654321, 0.000123456789)
	)
	var encoded: Dictionary = Archive._numeric(
		{"camera": pose, "subject": Vector3(1, 2, 3)}, errors
	)
	var parser: JSON = JSON.new()
	var json_text: String = JSON.stringify(encoded, "", true, true)
	var parsed: Error = parser.parse(json_text)
	Probe.report(encoded, parser.data, json_text, parsed)
	var sealed: Dictionary = ContextCodec.seal(encoded)
	var transport: JSON = JSON.new()
	var transported: Error = transport.parse(JSON.stringify(sealed, "", true, true))
	var exact: Dictionary = ContextCodec.restore(transport.data if transported == OK else {})
	owner._check(
		(
			errors.is_empty()
			and parsed == OK
			and transported == OK
			and exact.ok
			and exact.value == encoded
			and var_to_bytes(exact.value) == var_to_bytes(encoded)
			and encoded.camera["@type"] == "Transform3D"
			and encoded.camera.basis_columns_then_origin.size() == 12
		),
		"receipt context preserves exact numeric vectors and all twelve camera transform components"
	)
	if transported == OK and transport.data is Dictionary:
		_codec_negatives(owner, encoded, transport.data)
	print(
		"MOGUL_TWO_RECEIPT_LOSSLESS_CONTEXT original_json_exact=",
		parser.data == encoded,
		" typed_reconstruction_exact=",
		exact.ok and var_to_bytes(exact.value) == var_to_bytes(encoded),
		" encoding=",
		ContextCodec.ENCODING
	)
	var invalid: Array[String] = []
	Archive._numeric({"bad": INF}, invalid)
	owner._check(not invalid.is_empty(), "nonfinite context cannot claim an exact numeric receipt")


static func _codec_negatives(owner: Node, encoded: Dictionary, transported: Dictionary) -> void:
	for field: String in ["context_raw_sha256", "context_payload_sha256", "context_json_sha256"]:
		var changed: Dictionary = transported.duplicate(true)
		changed[field] = "0".repeat(64)
		owner._check(
			not ContextCodec.restore(changed).ok, "lossless receipt rejects changed " + field
		)
	var wrong_type: Dictionary = transported.duplicate(true)
	wrong_type.context_encoding = "unqualified-encoding"
	owner._check(not ContextCodec.restore(wrong_type).ok, "unknown typed context encoding refused")
	var altered_readable: Dictionary = transported.duplicate(true)
	altered_readable.context.camera.basis_columns_then_origin[10] += 1.0
	owner._check(
		not ContextCodec.restore(altered_readable).ok,
		"readable context cannot contradict its exact typed data"
	)
	var altered: Dictionary = encoded.duplicate(true)
	altered.camera.basis_columns_then_origin[10] += 0.001
	var sealed: Dictionary = ContextCodec.seal(altered)
	var reconstructed: Dictionary = ContextCodec.restore(sealed)
	owner._check(
		reconstructed.ok and var_to_bytes(reconstructed.value) != var_to_bytes(encoded),
		"a changed valid component remains different from the original exact source"
	)
	owner._check(
		ContextCodec.seal({"infinite": INF}).is_empty(), "typed context refuses nonfinite values"
	)
	owner._check(
		ContextCodec.seal({"object": owner}).is_empty(), "typed context never serializes objects"
	)
	_codec_input_guards(owner, transported)
	var integer_context: Dictionary = {"large_integer": 9007199254740993, "float": 0.125}
	var integer_packet: Dictionary = ContextCodec.seal(integer_context)
	var parser: JSON = JSON.new()
	owner._check(
		parser.parse(JSON.stringify(integer_packet, "", true, true)) == OK,
		"typed integer fixture parses readable JSON"
	)
	var integer_exact: Dictionary = ContextCodec.restore(parser.data)
	owner._check(
		integer_exact.ok and var_to_bytes(integer_exact.value) == var_to_bytes(integer_context),
		"typed integer above2^53 and fractional float reconstruct bit-exactly without JSON coercion"
	)


static func _codec_input_guards(owner: Node, packet: Dictionary) -> void:
	for value: Variant in [0, -1, 1.5, ContextCodec.MAX_RAW_BYTES + 1]:
		var changed: Dictionary = packet.duplicate(true)
		changed.context_raw_bytes = value
		owner._check(
			not ContextCodec.restore(changed).ok, "typed context raw size is strictly bounded"
		)
	for value: String in ["", "a", "zz", "aa".repeat(ContextCodec.MAX_RAW_BYTES + 1024)]:
		var changed: Dictionary = packet.duplicate(true)
		changed.context_payload_hex = value
		owner._check(
			not ContextCodec.restore(changed).ok,
			"typed payload rejects empty odd nonhex and oversized input before decode"
		)
	for field: String in ContextCodec.FIELDS:
		var changed: Dictionary = packet.duplicate(true)
		changed.erase(field)
		owner._check(not ContextCodec.restore(changed).ok, "typed context requires field: " + field)
	var deep: Dictionary = {"leaf": 1}
	for _depth: int in range(34):
		deep = {"nested": deep}
	owner._check(
		ContextCodec.seal(deep).is_empty(), "typed context depth limit rejects unbounded nesting"
	)
	var array_bytes: PackedByteArray = var_to_bytes([1, 2, 3])
	var payload: PackedByteArray = array_bytes.compress(FileAccess.COMPRESSION_GZIP)
	var changed: Dictionary = packet.duplicate(true)
	changed.context_raw_bytes = array_bytes.size()
	changed.context_raw_sha256 = Archive._sha256(array_bytes)
	changed.context_payload_hex = payload.hex_encode()
	changed.context_payload_sha256 = Archive._sha256(payload)
	owner._check(
		not ContextCodec.restore(changed).ok,
		"valid hashes cannot admit a non-Dictionary typed payload; header rejects before decoder"
	)


static func _has_error(result: Dictionary, prefix: String) -> bool:
	for error: String in result.errors:
		if error.begins_with(prefix):
			return true
	return false

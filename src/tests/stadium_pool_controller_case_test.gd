extends "res://src/tests/stadium_pool_controller_history_test.gd"
## One independently initialized window. The parent driver and gameplay remain byte-frozen.
## Root runs complete A24+B24 first; S24 is a separately admitted observer-only stage.
# gdlint: disable=max-returns

const BASE_HISTORY_SHA: String = "487c9debab11e0efce43a15afd9799c33295ff8238546b8e144a136dc8abae31"
const CASE_SCHEMA: String = "POOL-CONTROLLER-ISOLATED-CASE-v2"
const BASE_DRIVER: String = "res://src/tests/stadium_pool_controller_history_test.gd"

var _selected_ordinal: int = -1
var _arm: String = ""
var _invocation: String = ""
var _selected_id: String = ""
var _process_identity: Dictionary = {}
var _finish_frame: int = -1
var _completed_once: bool = false
var _writer_packet: Dictionary = {}


func _ready() -> void:
	var options: Dictionary = {}
	var physical_flag_seen: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--physical-in-process":
			if physical_flag_seen:
				_abort("duplicate physical process flag")
				return
			physical_flag_seen = true
			continue
		var split_at: int = argument.find("=")
		if split_at < 0:
			_abort("explicit isolated-case key/value arguments required")
			return
		var key: String = argument.substr(0, split_at)
		if (
			options.has(key)
			or (
				key
				not in [
					"--pool-controller-mode",
					"--pool-controller-report-dir",
					"--pool-case-ordinal",
					"--pool-case-arm",
					"--pool-case-id",
					"--pool-case-invocation"
				]
			)
		):
			_abort("duplicate or unknown isolated-case argument")
			return
		options[key] = argument.substr(split_at + 1)
	if options.size() != 6 or options.get("--pool-controller-mode") not in ["baseline", "shadow"]:
		_abort("all explicit arguments and baseline/shadow mode required")
		return
	var ordinal_text: String = options["--pool-case-ordinal"]
	if not ordinal_text.is_valid_int() or str(int(ordinal_text)) != ordinal_text:
		_abort("canonical integer case ordinal required")
		return
	_selected_ordinal = int(ordinal_text)
	_arm = options["--pool-case-arm"]
	_invocation = options["--pool-case-invocation"]
	_selected_id = options["--pool-case-id"]
	if (
		_selected_ordinal < 0
		or _selected_ordinal >= 24
		or (
			_arm not in ["a", "b"]
			if options["--pool-controller-mode"] == "baseline"
			else _arm != "s"
		)
	):
		_abort("bounded ordinal and exact mode/arm pairing required")
		return
	if not _hex(_invocation, 32) or _selected_id != _manifest_id(_selected_ordinal):
		_abort("exact invocation nonce and manifest identity required")
		return
	if FileAccess.get_sha256(BASE_DRIVER) != BASE_HISTORY_SHA:
		_abort("inherited history driver changed")
		return
	_process_identity = _read_process_identity()
	if _process_identity.is_empty():
		_abort("Linux PID plus boot/start identity unavailable")
		return
	# Selection happens before the original two DRAIN ticks, never during live play.
	_ordinal = _selected_ordinal
	super._ready()
	if _phase == Phase.DONE:
		return
	_check(_phase == Phase.DRAIN and _wait_ticks == 2, "original initial drain preserved")
	_check(_mode == options["--pool-controller-mode"], "exact requested baseline or observer mode")
	_check(_ordinal == _selected_ordinal, "selection unchanged by original ready")


func _finish_window() -> void:
	_check(_ordinal == _selected_ordinal and _windows.is_empty(), "only selected window begins")
	_writer_packet = _shadow.writer.packet(_mode, _role, _source)
	_writer_packet["identity"] = {
		"id": _selected_id,
		"ordinal": _selected_ordinal,
		"arm": _arm,
		"invocation": _invocation,
		"process": _process_identity,
		"history_source_sha256": _history_source,
		"launch_frame": _launch_frame,
		"finish_frame": Engine.get_physics_frames()
	}
	super._finish_window()
	_finish_frame = Engine.get_physics_frames()
	_check(_windows.size() == 1 and _windows[0].id == _selected_id, "one complete selected window")
	_check(_phase == Phase.DRAIN and _wait_ticks == 2, "original final drain preserved")
	_check(_ordinal == _selected_ordinal + 1, "original completion increment preserved")
	_check(_finish_frame == _launch_frame + SAMPLES, "exact original sample interval")
	_check(_lab == null and _model == null and _ball == null, "original teardown executed")
	# The original state machine consumes both drain ticks and then calls _complete.
	# No early quit, altered tick, extra warm-up, or second selected window.
	_ordinal = ROLES.size() * cases().size()


func _complete() -> void:
	_check(not _completed_once, "one completion only")
	_completed_once = true
	_check(_phase == Phase.DONE and _wait_ticks == 0, "original drain reached completion")
	_check(Engine.get_physics_frames() == _finish_frame + 2, "two actual final drain ticks")
	_check(_windows.size() == 1 and _windows[0].id == _selected_id, "exact isolated window")
	_check(get_child_count() == 0, "queued lab and model have left driver")
	_check(_read_process_identity() == _process_identity, "same authenticated process lifetime")
	var identity: Dictionary = {
		"schema": CASE_SCHEMA,
		"arm": _arm,
		"mode": _mode,
		"ordinal": _selected_ordinal,
		"id": _selected_id,
		"invocation": _invocation,
		"process": _process_identity,
		"seed": 704716,
		"source": _source,
		"history_source_sha256": _history_source,
		"base_history_source_sha256": BASE_HISTORY_SHA,
		"launch_frame": _launch_frame,
		"finish_frame": _finish_frame,
		"complete_frame": Engine.get_physics_frames(),
		"same_session_qualified": false,
		"early_award_authority": false,
		"phase_closure_qualified": false,
		"production_qualified": false,
		"warning_cause_resolved": false,
		"active_awards_enabled": false,
	}
	_save(
		"trajectory",
		{
			"schema": "POOL-CONTROLLER-TRAJECTORY-v1",
			"source": _source,
			"history_source_sha256": _history_source,
			"windows": _windows,
		}
	)
	_save(
		"index",
		{
			"schema": "POOL-CONTROLLER-ISOLATED-INDEX-v2",
			"identity": identity,
			"mode": _mode,
			"checks": _checks,
			"failures": _failures,
			"windows": _windows.size(),
			"samples_per_window": SAMPLES,
			"artifacts": _artifacts.duplicate(true),
			"active_awards_enabled": false,
			"ordinary_controller_qualified": false,
			"dry_to_dry_completeness_qualified": false,
		}
	)
	_save_writer()
	print("POOL_ISOLATED_INDEX ", JSON.stringify(_artifacts[-1], "", true, true))
	print("POOL_ISOLATED_IDENTITY ", JSON.stringify(identity, "", true, true))
	print(
		(
			"POOL_ISOLATED_HISTORY checks=%d failures=%d windows=%d bytes=%d source=%s"
			% [_checks, _failures, _windows.size(), _total, _source]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _save_writer() -> void:
	# Extra evidence has its own bounded envelope; legacy packets/cap are unchanged.
	_writer_packet["window_typed_sha256"] = _artifacts[0].typed_sha256
	_writer_packet["index_typed_sha256"] = _artifacts[-1].typed_sha256
	var bytes: PackedByteArray = var_to_bytes(_writer_packet)
	var hashing: HashingContext = HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	var digest: String = hashing.finish().hex_encode()
	var envelope: Dictionary = {
		"schema": "POOL-CONTROLLER-WRITER-BASE64-v1",
		"source": _source,
		"id": _selected_id,
		"arm": _arm,
		"invocation": _invocation,
		"typed_bytes": bytes.size(),
		"typed_sha256": digest,
		"base64": Marshalls.raw_to_base64(bytes)
	}
	var json_bytes: PackedByteArray = JSON.stringify(envelope, "", true, true).to_utf8_buffer()
	var manifest: Dictionary = {
		"schema": "POOL-CONTROLLER-WRITER-FILES-v1",
		"id": _selected_id,
		"source": _source,
		"typed_bytes": bytes.size(),
		"typed_sha256": digest,
		"json_bytes": json_bytes.size(),
		"failure": _writer_packet.failure,
		"events": _writer_packet.events.size(),
		"complete": _writer_packet.failure == "",
		"authority": false
	}
	var typed_file: FileAccess = FileAccess.open(_folder.path_join("writer.var"), FileAccess.WRITE)
	typed_file.store_buffer(bytes)
	typed_file.close()
	var json_file: FileAccess = FileAccess.open(_folder.path_join("writer.json"), FileAccess.WRITE)
	json_file.store_buffer(json_bytes)
	json_file.close()
	manifest["json_sha256"] = FileAccess.get_sha256(_folder.path_join("writer.json"))
	var manifest_bytes: PackedByteArray = JSON.stringify(manifest, "", true, true).to_utf8_buffer()
	var manifest_file: FileAccess = FileAccess.open(
		_folder.path_join("writer.manifest.json"), FileAccess.WRITE
	)
	manifest_file.store_buffer(manifest_bytes)
	manifest_file.close()
	_check(bytes.size() <= PoolControllerWriterLedger.MAX_TYPED_BYTES, "writer typed quota")
	_check(
		json_bytes.size() <= 4 * ceili(float(bytes.size()) / 3.0) + 2048, "writer envelope quota"
	)
	_check(manifest_bytes.size() <= 2048, "writer manifest quota")
	_check(_writer_packet.failure == "", "complete writer ledger")
	_check(_writer_packet.armed == (_mode == "shadow"), "writer exact arm binding")
	_check(
		_writer_packet.events.size() > 0 if _mode == "shadow" else _writer_packet.events.is_empty(),
		"writer observed or explicit unobserved baseline"
	)
	print("POOL_WRITER_FILES ", JSON.stringify(manifest, "", true, true))


static func _manifest_id(ordinal: int) -> String:
	var prefixes: Array[String] = ["live", "scenery", "no_pool"]
	return prefixes[floori(float(ordinal) / 8.0)] + "-" + String(cases()[ordinal % 8].id)


static func _hex(value: String, length: int) -> bool:
	if value.length() != length:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func _read_line(path: String) -> String:
	# procfs reports zero file size; get_line reads the actual stream without get_length.
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var line: String = file.get_line().strip_edges()
	file.close()
	return line


static func _read_process_identity() -> Dictionary:
	var stat: String = _read_line("/proc/self/stat")
	var closing: int = stat.rfind(")")
	var opening: int = stat.find("(")
	if opening < 1 or closing <= opening:
		return {}
	var fields: PackedStringArray = stat.substr(closing + 2).split(" ", false)
	if fields.size() < 20 or not fields[1].is_valid_int() or not fields[19].is_valid_int():
		return {}
	var boot: String = _read_line("/proc/sys/kernel/random/boot_id")
	if not _hex(boot.replace("-", ""), 32):
		return {}
	if int(stat.substr(0, opening).strip_edges()) != OS.get_process_id():
		return {}
	return {
		"pid": OS.get_process_id(),
		"parent_pid": int(fields[1]),
		"start_ticks": int(fields[19]),
		"boot_id": boot,
	}


func _abort(reason: String) -> void:
	_check(false, reason)
	_phase = Phase.DONE
	get_tree().quit(1)

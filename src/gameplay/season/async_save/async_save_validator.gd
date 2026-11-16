extends Node
const Protocol = preload("async_save_protocol.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].begins_with("--save-job=") or DisplayServer.get_name() != "headless":
		get_tree().quit(1)
		return
	var token: String = args[0].trim_prefix("--save-job=")
	var folder: String = PhysicalJobFiles.directory(token)
	if folder.is_empty():
		get_tree().quit(1)
		return
	var request: Variant = PhysicalJobFiles.read(folder.path_join("request.json"))
	if not request is Dictionary or not SeasonOwnership._keys(request,
		["version", "token", "binding", "new_hash", "native_hash", "old_hash", "old_exists"]):
		get_tree().quit(1)
		return
	if request.version != 1 or request.token != token or not request.old_exists is bool \
		or not ClubCareer.same(request.binding, Protocol.binding()):
		get_tree().quit(1)
		return
	var bytes: Variant = Protocol.bytes_at(folder.path_join("new.json"))
	if bytes == null or Protocol.digest(bytes) != request.new_hash:
		get_tree().quit(1)
		return
	var native: Variant = Protocol.bytes_at(folder.path_join("new.variant"))
	if native == null or Protocol.digest(native) != request.native_hash:
		get_tree().quit(1)
		return
	# No Objects or executable Resources may be deserialized.
	var data: Variant = bytes_to_var(native)
	if not data is Dictionary or JSON.stringify(data, "", true, true).to_utf8_buffer() != bytes:
		get_tree().quit(1)
		return
	# Native Dictionary/array/integer transport, not JSON-normalized decoder input.
	var decoded: SeasonState = SeasonSave._decode(data)
	if not Protocol.standalone(decoded):
		get_tree().quit(1)
		return
	var old_valid: bool = false
	if request.old_exists:
		var old: Variant = Protocol.bytes_at(folder.path_join("old.json"))
		if old == null or Protocol.digest(old) != request.old_hash:
			get_tree().quit(1)
			return
		# EXACT ordinary old-primary read/decode; corrupt primary never replaces .bak.
		old_valid = SeasonSave._read(folder.path_join("old.json")) != null
	if not ClubCareer.same(request.binding, Protocol.binding()):
		get_tree().quit(1)
		return
	var response: Dictionary = request.duplicate(true)
	response["old_valid"] = old_valid
	get_tree().quit(0 if PhysicalJobFiles.write(folder.path_join("response.json"), response) else 1)

extends Node
## Synthetic file-transaction controls only; no SeasonState/game/worker is created.
const Journal = preload("res://src/tests/normal_league_proof_journal.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("NORMAL93_JOURNAL ", ok, " ", label)
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--journal-test-root="): root = arg.trim_prefix("--journal-test-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) or FileAccess.file_exists(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	for scenario: String in ["before_raw", "raw_write_failure", "human_save_failure", "ai_save_failure", "publish_save_failure", "save_without_receipt", "stale_receipt", "pointer_without_completion", "truncated_completion", "success"]:
		_case(root.path_join(scenario), scenario)
	for target: String in ["intent", "boundary"]:
		_malformed_case(root.path_join("truncated_" + target), target)
	print("NORMAL93_JOURNAL_RESULT checks=%d failures=%d synthetic_files=true games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
func _case(root: String, scenario: String) -> void:
	DirAccess.make_dir_recursive_absolute(root)
	check(Journal.write_new(root.path_join("season.json"), {"synthetic": "old-save"}), scenario + ": input created")
	var original: String = FileAccess.get_file_as_string(root.path_join("season.json"))
	var binding: Dictionary = {"input_save_sha256": FileAccess.get_sha256(root.path_join("season.json")), "scenario": scenario}
	var intent: String = Journal.begin(root, "one-step", binding)
	check(not intent.is_empty(), scenario + ": intent persisted before action")
	var intent_bytes: String = FileAccess.get_file_as_string(intent)
	if scenario == "raw_write_failure":
		DirAccess.make_dir_absolute(root.path_join("raw.json"))
		check(not Journal.write_new(root.path_join("raw.json"), {"synthetic": "completed"}), "failed raw write is checked")
	elif scenario != "before_raw":
		check(Journal.write_new(root.path_join("raw.json"), {"synthetic": "completed"}), scenario + ": raw retained")
		var raw: String = FileAccess.get_file_as_string(root.path_join("raw.json"))
		check(not Journal.write_new(root.path_join("raw.json"), {"synthetic": "replacement"})
			and FileAccess.get_file_as_string(root.path_join("raw.json")) == raw, scenario + ": raw cannot be overwritten")
	if scenario in ["save_without_receipt", "stale_receipt", "pointer_without_completion", "truncated_completion", "success"]:
		# Synthetic durable commit; no production SeasonSave or physical evidence.
		Journal.write_new(root.path_join("next-save.json"), {"synthetic": "new-save"})
		DirAccess.rename_absolute(root.path_join("next-save.json"), root.path_join("season.json"))
		var receipt: Dictionary = {"save_sha256": FileAccess.get_sha256(root.path_join("season.json"))}
		check(Journal.write_new(root.path_join("boundary.json"), receipt), scenario + ": immutable boundary created")
		if scenario in ["success", "pointer_without_completion", "truncated_completion"]:
			check(Journal.write_new(root.path_join("resume-boundary.json"), receipt), "matching pointer created")
		elif scenario == "stale_receipt":
			Journal.write_new(root.path_join("resume-boundary.json"), {"save_sha256": "old-save"})
		if scenario == "pointer_without_completion":
			check(not FileAccess.file_exists(intent.trim_suffix(".intent.json") + ".complete.json"), "published pointer with deliberately absent completion")
		elif scenario == "truncated_completion":
			var completion_path: String = intent.trim_suffix(".intent.json") + ".complete.json"
			var file: FileAccess = FileAccess.open(completion_path, FileAccess.WRITE)
			if file == null:
				check(false, "synthetic truncated-completion injection opens")
				return
			file.store_string("{\"intent_sha256\":")
			file.flush()
			file.close()
			check(FileAccess.get_file_as_string(completion_path) == "{\"intent_sha256\":", "synthetic truncated completion retained exactly")
			check(not Journal.complete(root, intent, "boundary.json"), "partial completion cannot be overwritten or silently repaired")
		else:
			var completed: bool = Journal.complete(root, intent, "boundary.json")
			check(completed == (scenario == "success"), scenario + ": completion requires current exact boundary pointer")
	if scenario == "success":
		check(Journal.ready(root, true), "fully completed transaction permits next distinct step")
		check(Journal.begin(root, "one-step", binding).is_empty(), "completed step identity still cannot replay")
		check(not Journal.begin(root, "next-step", binding).is_empty(), "next distinct step may begin")
	else:
		check(not Journal.ready(root, true) and Journal.begin(root, "replacement-game", binding).is_empty(), scenario + ": unresolved outcome refuses every new game")
	if scenario in ["before_raw", "raw_write_failure", "human_save_failure", "ai_save_failure", "publish_save_failure"]:
		check(FileAccess.get_file_as_string(root.path_join("season.json")) == original, scenario + ": unchanged save does not authorize rerun")
	check(FileAccess.get_file_as_string(intent) == intent_bytes, scenario + ": original intent immutable")

func _malformed_case(root: String, target: String) -> void:
	# Deliberately authored corrupt files; never mutate a real proof's evidence.
	DirAccess.make_dir_recursive_absolute(root.path_join("proof-journal"))
	check(Journal.write_new(root.path_join("season.json"), {"synthetic": "save"}), target + ": synthetic save created")
	var intent: String = root.path_join("proof-journal/one-step.intent.json")
	var boundary: String = root.path_join("boundary.json")
	var broken: String = intent if target == "intent" else boundary
	var bytes: String = "{\"synthetic\":"
	var file: FileAccess = FileAccess.open(broken, FileAccess.WRITE)
	if file == null:
		check(false, target + ": synthetic corruption injection opens")
		return
	file.store_string(bytes)
	file.flush()
	file.close()
	check(FileAccess.get_file_as_string(broken) == bytes, target + ": truncated JSON retained exactly")
	if target == "intent":
		check(Journal.write_new(boundary, {"save_sha256": FileAccess.get_sha256(root.path_join("season.json"))}), "malformed intent: valid boundary created")
		check(Journal.write_new(intent.trim_suffix(".intent.json") + ".complete.json", {
			"intent_sha256": FileAccess.get_sha256(intent), "boundary": "boundary.json",
			"boundary_sha256": FileAccess.get_sha256(boundary)}), "malformed intent: matching hash cannot bypass JSON validation")
	else:
		check(Journal.write_new(intent, {"synthetic": "intent"}), "malformed boundary: valid intent created")
		check(DirAccess.copy_absolute(boundary, root.path_join("resume-boundary.json")) == OK, "malformed boundary: identical pointer created")
		check(not Journal.complete(root, intent, "boundary.json"), "malformed boundary cannot complete despite matching pointer")
	check(not Journal.ready(root, true) and Journal.begin(root, "replacement-game", {}).is_empty(), target + ": malformed evidence refuses every new game")
	check(not Journal.write_new(broken, {"synthetic": "replacement"})
		and FileAccess.get_file_as_string(broken) == bytes, target + ": malformed evidence remains immutable")

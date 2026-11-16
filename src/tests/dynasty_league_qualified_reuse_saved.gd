extends Node
## Read-only differential of copies of retained isolated saves. Never restores or writes a store.
const Reuse = preload("res://src/tests/dynasty_league_qualified_reuse_controls.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	print("REUSE_SAVED_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var root: String = OS.get_environment("LEAGUE_REUSE_SAVED")
	if not root.is_absolute_path():
		get_tree().quit(2)
		return
	for name: String in ["played91", "pending91", "played92"]:
		var path: String = root.path_join(name)
		var owner: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("owner.json"))).owner
		var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path.path_join("snapshot.json")))
		var hashes: Array[String] = [FileAccess.get_sha256(path.path_join("owner.json")), FileAccess.get_sha256(path.path_join("snapshot.json"))]
		Reuse.positive(owner, snapshot, check, name)
		check(hashes == [FileAccess.get_sha256(path.path_join("owner.json")), FileAccess.get_sha256(path.path_join("snapshot.json"))], name + " copied files remain byte-identical")
	print("LEAGUE_REUSE_SAVED: %d checks, %d failures, new_physical_games=0, owner_writes=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

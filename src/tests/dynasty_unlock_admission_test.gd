extends Node
## Fresh policy denial versus deterministic historical replay. No physical games.

const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
var failures: int = 0
var checks: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var root: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--dynasty-unlock-test-root="):
			root = argument.trim_prefix("--dynasty-unlock-test-root=")
	if (
		not root.is_absolute_path() or root.length() < 2
		or root != root.simplify_path() or DirAccess.dir_exists_absolute(root)
	):
		push_error("Fresh absolute --dynasty-unlock-test-root= required; no tests ran.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	_run(root.path_join("owner.json"))
	print("Dynasty unlock admission: %d checks, %d failures, physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _run(path: String) -> void:
	var source: SeasonState = SeasonState.create(13002, false, true, true)
	source.career = ClubCareer.new()
	check(source.career.start(source), "initial Standard admission")
	for index in range(4):
		check(source.choose_player(source.offers()[0]), "ordinary origin draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "unlock-lineage", "unlock-owner")
	var season: SeasonState = Bridge.create(profile)
	check(season != null, "legacy source context remains constructible")
	if season == null:
		return
	var snapshot: Dictionary = Save.wrap_checkpoint(SeasonSave.snapshot(season), Save.binding_for(
		season, "unlock-owner", "unlock-lineage", 0, 1, "unlock-lineage:1"))
	var payload: Dictionary = {"lineage": Lineage.create(profile), "snapshot": snapshot,
		"session_id": "unlock-lineage:1", "origin": origin}
	var request: Dictionary = {"op": "create", "request_id": "locked-create",
		"expected_revision": 0, "payload": payload}
	var replay: Dictionary = Owner.project({}, request)
	check(not replay.is_empty(), "historical deterministic projection remains available")
	if replay.is_empty():
		return
	check(not Owner.new_request_admitted({}, request, replay.owner), "fresh Dynasty denied")
	check(Owner.validate_recovery({}, replay.owner, replay.receipt, {}, snapshot, origin),
		"exact historical intent retains full source-bound recovery")
	var altered: Dictionary = snapshot.duplicate(true)
	altered.session.access_sha256 = "0".repeat(64)
	check(not Owner.validate_recovery({}, replay.owner, replay.receipt, {}, altered, origin),
		"changed historical intent target cannot bypass admission")
	check(Store.commit(request, path).status == "blocked", "durable fresh enrollment denied")
	check(Store.inspect(path).status == "empty", "denial writes no owner or pending intent")
	check(DirAccess.get_files_at(path.get_base_dir()).is_empty(), "denial creates no durable files")
	check(Owner.new_request_admitted(replay.owner, {"op": "begin_next"}, replay.owner),
		"existing lineage continuation policy does not manufacture a global unlock")

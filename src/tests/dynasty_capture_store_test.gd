extends Node
## One source-replayed pristine save79 capture seeds compact typed-intent tests.
## The interruption matrix retries already-admitted targets, not full snapshots.

const Fixture = preload("res://src/tests/dynasty_foundation_test.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_lineage_store.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const STEPS: Array[String] = [
	"primary.open",
	"primary.write",
	"primary.flush",
	"primary.close",
	"primary.rename",
	"mirror.open",
	"mirror.write",
	"mirror.flush",
	"mirror.close",
	"mirror.rename",
	"intent.clear"
]
var checks: int = 0
var failures: int = 0
var path: String = ""


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	path = "user://dynasty-capture-store-%d.json" % OS.get_process_id()
	var active: String = SeasonSave.path
	var initial: Dictionary = Lineage.create(Fixture.base_profile())
	var season: SeasonState = Bridge.create(initial.start_profile)
	check(
		season != null,
		"controlled compact initial profile constructs pristine closed Dynasty season"
	)
	if season == null:
		_finish()
		return
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	check(snapshot.get("version") == 79, "capture source is a complete save79 snapshot")
	var snapshot_bytes: String = JSON.stringify(snapshot, "", true, true)
	check(
		Store.commit_capture(snapshot, path).status == "blocked" and _files().is_empty(),
		"capture cannot create a new lineage path"
	)
	check(
		Store.commit(initial, path).status == "committed", "initial active lineage commits normally"
	)
	Store._test_stop_after = "intent.rename"
	var outcome: Dictionary = Store.commit_capture(snapshot, path)
	Store._test_stop_after = ""
	check(
		outcome.status == "not_committed",
		"source replay admits an uncommitted typed capture intent"
	)
	var found: Dictionary = Store.inspect(path)
	check(
		found.status == "pending" and Store.restore(path).is_empty(),
		"pending capture does not open its old owner"
	)
	if found.status != "pending":
		_finish()
		return
	var target: Dictionary = found.pending
	check(
		(
			target.version == Lineage.CAPTURE_VERSION
			and Lineage.capture_transition_valid(initial, target)
		),
		"pending target is a bounded legal capture transition"
	)
	check(
		target.is_read_only() and target.current_profile.is_read_only(),
		"capture target and profile are immutable"
	)
	check(
		target.capture.revision == season.build.revision(),
		"capture records exact source Build revision"
	)
	check(
		(
			target.current_profile.players[Fixture.ALEX].stats
			== season.build.player(Fixture.ALEX).stats
		),
		"capture uses validated source profile, not caller cache"
	)
	check(
		JSON.stringify(snapshot, "", true, true) == snapshot_bytes,
		"capture never mutates caller source snapshot"
	)
	var intent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".intent"))
	check(
		intent.get("kind") == "capture" and intent.size() == 5,
		"typed capture intent is explicit without altering lifecycle schema"
	)
	check(
		not _contains_journal(intent) and not intent.has("snapshot"),
		"only bounded before/after checkpoints retained, no full source or journal"
	)
	var pending_files: Dictionary = _files()
	check(
		Store.commit_capture(snapshot, path).status == "blocked" and _files() == pending_files,
		"new capture call cannot replace pending source and does not replay it"
	)
	check(
		Store.commit(Lineage.pause(target), path).status == "blocked" and _files() == pending_files,
		"pending capture locks exact state, not merely current profile"
	)
	check(
		(
			Store.commit(target, path).status == "committed"
			and Profile.same(Store.restore(path), target)
		),
		"exact admitted target commits without a second source decode"
	)
	var stable: Dictionary = _files()
	check(
		Store.commit(target, path).status == "committed" and _files() == stable,
		"generic exact committed capture retry is idempotent"
	)
	check(
		Store.commit_capture({"version": 0}, path).status == "blocked" and _files() == stable,
		"invalid snapshot rejects before a full replay and preserves authority"
	)
	# Reinstall controlled source envelopes to test the public generic admission
	# route, not a malicious all-files replacement security claim.
	_install(pending_files, false)
	var original: Dictionary = _files()
	check(
		Store.commit(target, path).status == "blocked" and _files() == original,
		"generic commit cannot initially admit even a valid captured target"
	)
	var forged: Dictionary = Fixture.cold(target)
	forged.current_profile.players[Fixture.ALEX].trained.contact += 1
	forged.current_profile.players[Fixture.ALEX].stats.contact += 1
	forged.current_profile.players[Fixture.ALEX].ever_earned = true
	# JSON cold copies use integral floats; hash the same canonical normalized
	# profile that Lineage.normalize will validate, not its pre-normalized spelling.
	forged.current_profile = Profile.normalize(forged.current_profile)
	forged.capture.profile_hash = Lineage.fingerprint(forged.current_profile)
	check(
		not Lineage.normalize(forged).is_empty(),
		"forged-growth negative fixture is locally normalized, not a parser rejection"
	)
	check(
		Store.commit(forged, path).status == "blocked" and _files() == original,
		"generic commit cannot launder arbitrary normalized current growth"
	)
	_matrix(target, pending_files)
	_discriminator_negatives(target, pending_files)
	check(SeasonSave.path == active, "capture store never changes active SeasonSave path")
	_finish()


func _matrix(target: Dictionary, pending_files: Dictionary) -> void:
	for index: int in range(STEPS.size()):
		var step: String = STEPS[index]
		_install(pending_files)
		Store._test_stop_after = step
		var outcome: Dictionary = Store.commit(target, path)
		Store._test_stop_after = ""
		var interrupted: Dictionary = _files()
		var found: Dictionary = Store.inspect(path)
		if index < 4:
			check(
				(
					outcome.status == "not_committed"
					and found.status == "pending"
					and Store.restore(path).is_empty()
				),
				step + ": capture remains pending before primary commit"
			)
		else:
			check(
				outcome.status == "committed" and Profile.same(Store.restore(path), target),
				step + ": exact captured target remains committed"
			)
		check(_files() == interrupted, step + ": inspecting typed evidence is read-only")
		check(
			(
				Store.commit(target, path).status == "committed"
				and Store.inspect(path).status == "ready"
			),
			step + ": admitted typed capture retries without source decode"
		)
		check(
			Store.inspect(path).revision == 2 and Profile.same(Store.restore(path), target),
			step + ": capture adds exactly one store revision and exact profile"
		)


func _discriminator_negatives(target: Dictionary, pending_files: Dictionary) -> void:
	for mode: String in ["missing", "unknown"]:
		_install(pending_files)
		var intent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".intent"))
		if mode == "missing":
			intent.erase("kind")
		else:
			intent.kind = "unknown"
		_put(path + ".intent", JSON.stringify(intent, "", true, true))
		var invalid: Dictionary = _files()
		check(
			Store.inspect(path).status == "blocked" and Store.restore(path).is_empty(),
			mode + ": invalid capture discriminator cannot widen lifecycle admission"
		)
		check(
			(
				Store.commit(target, path).status == "blocked"
				and Store.repair(path).status == "blocked"
				and _files() == invalid
			),
			mode + ": typed conflicts preserve every artifact"
		)
	_install(pending_files)
	var intent: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path + ".intent"))
	intent.after.lineage = Lineage.pause(intent.before.lineage)
	_put(path + ".intent", JSON.stringify(intent, "", true, true))
	var wrong_type: Dictionary = _files()
	check(
		(
			Store.inspect(path).status == "blocked"
			and Store.repair(path).status == "blocked"
			and _files() == wrong_type
		),
		"lifecycle pause cannot masquerade as typed capture"
	)


func _contains_journal(value: Variant) -> bool:
	if value is Dictionary:
		if value.has("events"):
			return true
		for child: Variant in value.values():
			if _contains_journal(child):
				return true
	elif value is Array:
		for child: Variant in value:
			if _contains_journal(child):
				return true
	return false


func _install(files: Dictionary, include_intent: bool = true) -> void:
	_cleanup()
	for suffix: String in files:
		if suffix != ".intent" or include_intent:
			_put(path + suffix, files[suffix])


func _put(destination: String, encoded: String) -> void:
	var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		check(false, "compact test fixture write opens")
		return
	file.store_string(encoded)
	file.flush()
	file.close()


func _files() -> Dictionary:
	var result: Dictionary = {}
	for suffix: String in Store.SUFFIXES:
		if FileAccess.file_exists(path + suffix):
			result[suffix] = FileAccess.get_file_as_string(path + suffix)
	return result


func _cleanup() -> void:
	for suffix: String in Store.SUFFIXES:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)


func _finish() -> void:
	Store._test_stop_after = ""
	_cleanup()
	print("Dynasty capture store checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

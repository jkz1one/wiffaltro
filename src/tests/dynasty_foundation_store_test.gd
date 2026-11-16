extends Node
## Isolated filesystem atomicity and lifecycle admission; no active save writes.

const Fixture = preload("res://src/tests/dynasty_foundation_test.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_lineage_store.gd")
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var path: String = "user://dynasty-foundation-%d.json" % OS.get_process_id()
	var original_save: String = SeasonSave.path
	var initial: Dictionary = Lineage.create(Fixture.semantic_profile())
	check(not initial.is_empty(), "semantic-only source fixture")
	if initial.is_empty():
		get_tree().quit(1)
		return
	check(Store.save(initial, path), "new isolated checkpoint")
	check(Profile.same(Store.restore(path), initial), "cold initial checkpoint")
	var bytes: String = FileAccess.get_file_as_string(path)
	var initial_bytes: String = bytes
	check(not Store.save(initial, SeasonSave.path), "active season destination rejects")
	check(not Store.save(initial, path + "/unavailable/child.json"), "failed write rejects")
	check(
		FileAccess.get_file_as_string(path) == bytes,
		"failed write leaves authoritative bytes untouched"
	)
	var paused: Dictionary = Lineage.pause(initial)
	check(
		Store.save(paused, path) and Profile.same(Store.restore(path), paused),
		"pause persists exact same lineage"
	)
	check(Store.save(Lineage.resume(paused), path), "resume preserves generation")
	var closed: Dictionary = Lineage.close(initial, "abandon")
	check(Store.save(closed, path), "abandon closes without decay or entitlement")
	check(not Store.save(initial, path), "cannot reopen closed generation")
	var request: Dictionary = Lineage.request_for(
		closed, "transition:1", 200, Fixture.overflow_choice()
	)
	var advanced: Dictionary = Lineage.advance(closed, request)
	check(not advanced.is_empty(), "bounded once-only rollover projection")
	if advanced.is_empty():
		_cleanup(path)
		get_tree().quit(1)
		return
	check(Store.save(advanced.lineage, path), "commit one exact admitted successor")
	var restored: Dictionary = Store.restore(path)
	check(Profile.same(restored, advanced.lineage), "cold decay and transition record exact")
	check(
		Lineage.advance(restored, request).replayed,
		"cold duplicate rollover does not reapply decay"
	)
	bytes = FileAccess.get_file_as_string(path)
	check(
		not Store.save(initial, path) and not Store.save(closed, path),
		"old source checkpoint cannot overwrite new generation"
	)
	var foreign: Dictionary = Fixture.cold(initial.start_profile)
	foreign.owner_id = "other-owner"
	check(
		not Store.save(Lineage.create(foreign), path),
		"foreign identity cannot replace existing lineage"
	)
	var branch: Dictionary = Lineage.request_for(
		closed, "transition:other", 201, Fixture.overflow_choice()
	)
	check(
		not Store.save(Lineage.advance(closed, branch).lineage, path),
		"same-generation foreign branch rejects"
	)
	var later: Dictionary = Lineage.close(advanced.lineage, "loss")
	var later_request: Dictionary = Lineage.request_for(later, "transition:2", 300)
	var two: Dictionary = Lineage.advance(later, later_request)
	check(not two.is_empty(), "second generation pure projection")
	if not two.is_empty():
		var third_closed: Dictionary = Lineage.close(two.lineage, "win")
		var third: Dictionary = Lineage.advance(
			third_closed, Lineage.request_for(third_closed, "transition:3", 400)
		)
		check(
			not third.is_empty() and not Store.save(third.lineage, path),
			"skipped durable generations reject"
		)
	check(
		FileAccess.get_file_as_string(path) == bytes,
		"all rejected replacements preserve exact committed bytes"
	)
	var forged: Dictionary = Fixture.cold(advanced.lineage)
	forged.last_transition.changes[Fixture.ALEX].stats.pitching.removed.paid = 0
	check(
		Lineage.normalize(forged).is_empty() and not Store.save(forged, path),
		"inconsistent paid-first transition rejects"
	)
	var revision: int = Store.inspect(path).revision
	check(
		FileAccess.get_file_as_string(path + ".committed") == bytes,
		"mirror contains the same committed successor, never a pre-decay backup"
	)
	_put(path, "{corrupt-primary")
	check(
		(
			Store.inspect(path).status == "recoverable"
			and Profile.same(Store.restore(path), advanced.lineage)
		),
		"corrupt primary recovers only the exact committed successor"
	)
	check(
		(
			FileAccess.get_file_as_string(path) == "{corrupt-primary"
			and FileAccess.get_file_as_string(path + ".committed") == bytes
		),
		"inspection preserves corrupt primary and exact surviving witness"
	)
	check(
		not Store.save(initial, path) and FileAccess.get_file_as_string(path) == "{corrupt-primary",
		"recoverable primary cannot be overwritten by an old reset"
	)
	check(
		(
			Store.repair(path).status == "committed"
			and Store.inspect(path).status == "ready"
			and Store.inspect(path).revision == revision
			and JSON.parse_string(FileAccess.get_file_as_string(path)) == JSON.parse_string(bytes)
			and FileAccess.get_file_as_string(path + ".committed") == bytes
		),
		"repair preserves complete committed record and surviving witness without repeated decay"
	)
	var repaired_bytes: String = FileAccess.get_file_as_string(path)
	check(
		not FileAccess.file_exists(path + ".bak"),
		"current commits do not create an older-generation rollback backup"
	)
	_put(path + ".committed", initial_bytes)
	check(
		Store.inspect(path).status == "blocked" and Store.restore(path).is_empty(),
		"two different valid revisions without intent cannot choose a stale mirror"
	)
	check(
		(
			not Store.save(initial, path)
			and not Store.save(advanced.lineage, path)
			and Store.repair(path).status == "blocked"
			and FileAccess.get_file_as_string(path) == repaired_bytes
			and FileAccess.get_file_as_string(path + ".committed") == initial_bytes
		),
		"conflicting replicas reject reset, exact retry and repair without altering evidence"
	)
	_put(path + ".committed", bytes)
	DirAccess.remove_absolute(path)
	check(
		(
			Store.inspect(path).status == "recoverable"
			and Profile.same(Store.restore(path), advanced.lineage)
			and not Store.save(initial, path)
			and not FileAccess.file_exists(path)
		),
		"missing primary retains exact committed owner and cannot reset"
	)
	check(
		(
			Store.repair(path).status == "committed"
			and Store.inspect(path).revision == revision
			and FileAccess.get_file_as_string(path) == repaired_bytes
		),
		"missing primary repair preserves the committed revision"
	)
	_put(path + ".bak", initial_bytes)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".committed")
	check(
		(
			Store.inspect(path).status == "blocked"
			and Store.restore(path).is_empty()
			and not Store.save(initial, path)
			and Store.repair(path).status == "blocked"
			and not FileAccess.file_exists(path)
			and FileAccess.get_file_as_string(path + ".bak") == initial_bytes
		),
		"legacy-only backup cannot resurrect pre-decay owner or authorize a reset"
	)
	_put(path, "{corrupt-primary")
	check(
		(
			Store.restore(path).is_empty()
			and not Store.save(initial, path)
			and FileAccess.get_file_as_string(path) == "{corrupt-primary"
			and FileAccess.get_file_as_string(path + ".bak") == initial_bytes
		),
		"corrupt primary plus legacy backup fails closed with every byte preserved"
	)
	check(SeasonSave.path == original_save, "ordinary active save path never changed")
	check(
		bytes.to_utf8_buffer().size() < Store.MAX_BYTES,
		"compact bounded representation fits explicit byte ceiling"
	)
	_cleanup(path)
	for suffix: String in Store.SUFFIXES:
		check(
			not FileAccess.file_exists(path + suffix), "owned recovery artifact cleaned: " + suffix
		)
	print("Dynasty inert store checks: %d, failures: %d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _cleanup(path: String) -> void:
	for suffix: String in Store.SUFFIXES:
		DirAccess.remove_absolute(path + suffix)


func _put(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "isolated corruption probe opens its owned fixture path")
	if file != null:
		file.store_string(content)
		file.close()

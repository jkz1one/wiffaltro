extends Node
## Compact controlled-record process interruption matrix. Run one phase per
## engine slot using -- --recovery-phase=creation|pause|resume|close|advance|
## corruption|admission|repair. No SeasonSave decode or active-save writes.

const Fixture = preload("res://src/tests/dynasty_foundation_test.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_lineage_store.gd")
const STEPS: Array[String] = [
	"intent.open",
	"intent.write",
	"intent.flush",
	"intent.close",
	"intent.rename",
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
var initial: Dictionary = {}
var closed: Dictionary = {}
var successor: Dictionary = {}
var path: String = ""


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _ready() -> void:
	var phase: String = "creation"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--recovery-phase="):
			phase = argument.trim_prefix("--recovery-phase=")
	path = "user://dynasty-recovery-%s-%d.json" % [phase, OS.get_process_id()]
	var active_path: String = SeasonSave.path
	initial = Lineage.create(Fixture.semantic_profile())
	closed = Lineage.close(initial, "abandon")
	var advanced: Dictionary = Lineage.advance(
		closed, Lineage.request_for(closed, "recovery:advance", 200, Fixture.overflow_choice())
	)
	check(
		not initial.is_empty() and not closed.is_empty() and not advanced.is_empty(),
		"controlled recovery fixtures validate"
	)
	if advanced.is_empty():
		get_tree().quit(1)
		return
	successor = advanced.lineage
	match phase:
		"creation":
			_matrix({}, initial, 0)
		"pause":
			_matrix(initial, Lineage.pause(initial), 1)
		"resume":
			_matrix(Lineage.pause(initial), initial, 2)
		"close":
			_matrix(initial, closed, 3)
		"advance":
			_matrix(closed, successor, 4)
		"corruption":
			_corruption()
		"admission":
			_admission()
		"repair":
			_repair_matrix()
		_:
			check(false, "unknown recovery phase")
	Store._test_stop_after = ""
	Store._test_record = false
	_cleanup()
	check(SeasonSave.path == active_path, "ordinary active save path remains unchanged")
	print("Dynasty recovery %s checks: %d, failures: %d" % [phase, checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _matrix(before: Dictionary, after: Dictionary, revision: int) -> void:
	for index: int in range(STEPS.size()):
		var step: String = STEPS[index]
		_seed(before, revision)
		var live: String = JSON.stringify(before, "", true, true)
		Store._test_stop_after = step
		Store._test_record = true
		Store._test_steps = []
		var outcome: Dictionary = Store.commit(after, path)
		Store._test_stop_after = ""
		Store._test_record = false
		check(step in Store._test_steps, step + ": interrupted exactly the intended write boundary")
		check(
			JSON.stringify(before, "", true, true) == live, step + ": live source remains immutable"
		)
		var snapshot: Dictionary = _snapshot()
		var found: Dictionary = Store.inspect(path)
		var restored: Dictionary = Store.restore(path)
		check(
			_snapshot() == snapshot, step + ": cold inspection and restore do not mutate evidence"
		)
		if index < 4:
			check(outcome.status == "not_committed", step + ": pre-intent temporary is uncommitted")
			check(
				found.status == ("empty" if before.is_empty() else "ready"),
				step + ": temporary is not authority"
			)
			check(Profile.same(restored, before), step + ": exact prior authority retained")
		elif index < 9:
			check(
				outcome.status == "not_committed" and found.status == "pending",
				step + ": durable intent is pending, not committed"
			)
			check(
				restored.is_empty() and Profile.same(found.pending, after),
				step + ": pending source cannot open a playable owner"
			)
			check(found.pending.is_read_only(), step + ": exposed pending candidate is immutable")
			var incompatible: Dictionary = (
				Lineage.pause(after) if after.state != "paused" else Lineage.resume(after)
			)
			check(
				Store.commit(incompatible, path).status == "blocked",
				step + ": pending intent locks exact candidate"
			)
			check(
				Store.repair(path).status == "blocked" and _snapshot() == snapshot,
				step + ": repair cannot erase pending intent"
			)
		else:
			check(
				outcome.status == "committed",
				step + ": target witness reports committed despite later interruption"
			)
			check(
				found.status in ["ready", "recoverable"] and Profile.same(restored, after),
				step + ": cold restore selects exact target, never source"
			)
			check(outcome.needs_repair == (index < 15), step + ": precise remaining-repair status")
		var retried: Dictionary = Store.commit(after, path)
		check(
			retried.status == "committed" and not retried.needs_repair,
			step + ": exact retry completes without reapplying change"
		)
		var stable: Dictionary = Store.inspect(path)
		check(
			stable.status == "ready" and stable.revision == revision + 1,
			step + ": exactly one new storage revision"
		)
		check(Profile.same(Store.restore(path), after), step + ": final restored target exact")
		var settled: Dictionary = _snapshot()
		check(
			Store.commit(after, path).status == "committed" and _snapshot() == settled,
			step + ": idempotent retry performs no durable writes"
		)


func _corruption() -> void:
	for suffix: String in ["", ".committed"]:
		for damage: String in ["corrupt", "missing"]:
			_seed(successor, 8)
			if damage == "missing":
				DirAccess.remove_absolute(path + suffix)
			else:
				_put(path + suffix, "{corrupt")
			var damaged: Dictionary = _snapshot()
			check(
				(
					Store.inspect(path).status == "recoverable"
					and Profile.same(Store.restore(path), successor)
				),
				suffix + damage + ": same-revision committed copy recovers"
			)
			check(_snapshot() == damaged, suffix + damage + ": restore preserves damaged evidence")
			check(
				Store.repair(path).status == "committed" and Store.inspect(path).status == "ready",
				suffix + damage + ": explicit repair restores redundancy"
			)
			check(
				Store.inspect(path).revision == 8,
				suffix + damage + ": repair never increments revision"
			)
	_seed(successor, 8)
	_put(path, "{corrupt")
	_put(path + ".committed", "{corrupt")
	_blocked_unchanged("both committed copies corrupted")
	_seed(successor, 8)
	_put(path + ".committed", JSON.stringify(_record(closed, 7), "", true, true))
	_blocked_unchanged("different valid revisions without intent")
	_seed(successor, 8)
	var branch: Dictionary = (
		Lineage
		. advance(closed, Lineage.request_for(closed, "conflict", 201, Fixture.overflow_choice()))
		. lineage
	)
	_put(
		path + ".intent",
		JSON.stringify(
			{
				"version": Store.VERSION,
				"path": ProjectSettings.globalize_path(path).simplify_path(),
				"before": _record(closed, 7),
				"after": _record(branch, 8)
			},
			"",
			true,
			true
		)
	)
	_blocked_unchanged("valid intent contradicts surviving committed branch")
	_seed(successor, 8)
	_put(path + ".intent", "{corrupt")
	_blocked_unchanged("corrupt intent cannot be silently discarded")
	_seed(closed, 7)
	Store._test_stop_after = "intent.rename"
	Store.commit(successor, path)
	Store._test_stop_after = ""
	_put(path, "{corrupt")
	_blocked_unchanged("source mirror plus intent cannot roll back uncertain primary")
	_seed(closed, 7)
	Store._test_stop_after = "primary.rename"
	Store.commit(successor, path)
	Store._test_stop_after = ""
	# A surviving target mirror witnesses commit even if primary was restored to
	# the source. This is explicit conflicting-replica recovery, not timestamp order.
	_put(path + ".committed", FileAccess.get_file_as_string(path))
	_put(path, JSON.stringify(_record(closed, 7), "", true, true))
	check(
		Profile.same(Store.restore(path), successor),
		"target mirror beats source primary only with exact valid intent"
	)
	check(
		Store.repair(path).status == "committed" and Store.inspect(path).revision == 8,
		"target witness repairs source primary without reopening generation"
	)
	_cleanup()
	_put(path + ".bak", JSON.stringify(closed))
	_blocked_unchanged("legacy backup alone cannot reset or revive previous generation")
	_cleanup()
	_put(path, JSON.stringify(initial))
	_blocked_unchanged("legacy plain stage10 checkpoint is not silently adopted")


func _admission() -> void:
	_seed(successor, 8)
	var stable: Dictionary = _snapshot()
	check(
		(
			Store.commit(initial, path).status == "blocked"
			and Store.commit(closed, path).status == "blocked"
		),
		"earlier generation rejects"
	)
	var branch: Dictionary = (
		Lineage
		. advance(closed, Lineage.request_for(closed, "branch", 201, Fixture.overflow_choice()))
		. lineage
	)
	check(Store.commit(branch, path).status == "blocked", "same generation foreign branch rejects")
	var foreign: Dictionary = Fixture.cold(initial.start_profile)
	foreign.owner_id = "other-owner"
	check(Store.commit(Lineage.create(foreign), path).status == "blocked", "foreign owner rejects")
	var later: Dictionary = Lineage.close(successor, "loss")
	var second: Dictionary = (
		Lineage.advance(later, Lineage.request_for(later, "second", 300)).lineage
	)
	var third_closed: Dictionary = Lineage.close(second, "win")
	var third: Dictionary = (
		Lineage.advance(third_closed, Lineage.request_for(third_closed, "third", 400)).lineage
	)
	check(Store.commit(third, path).status == "blocked", "skipped durable generation rejects")
	check(_snapshot() == stable, "every rejected successor preserves exact durable bytes")
	check(
		(
			not Store.save(initial, SeasonSave.path)
			and not Store.save(initial, SeasonSave.path + ".tmp")
			and not Store.save(initial, SeasonSave.path + ".bak")
		),
		"active SeasonSave family rejects"
	)
	var saved_active: String = SeasonSave.path
	SeasonSave.path = path + ".intent"
	check(
		Store.commit(initial, path).status == "blocked",
		"derived sidecar collision rejects before touching active save"
	)
	SeasonSave.path = saved_active
	check(_snapshot() == stable, "sidecar isolation rejection is read-only")
	_cleanup()
	check(
		(
			Store.commit(successor, path).status == "blocked"
			and Store.commit(closed, path).status == "blocked"
		),
		"fresh path cannot install advanced or closed lineage"
	)
	_put(path + ".intent.tmp", "{orphan")
	var temporary: Dictionary = _snapshot()
	check(
		(
			Store.inspect(path).status == "empty"
			and Store.restore(path).is_empty()
			and _snapshot() == temporary
		),
		"orphan temporary is preserved and has no authority"
	)
	check(
		Store.commit(initial, path).status == "committed",
		"fresh creation may replace uncommitted orphan temporary"
	)
	var other_path: String = path + ".elsewhere"
	_put(other_path, FileAccess.get_file_as_string(path))
	check(
		Store.inspect(other_path).status == "blocked",
		"copied envelope cannot silently change bound canonical path"
	)
	DirAccess.remove_absolute(other_path)
	check(
		FileAccess.get_file_as_string(path).to_utf8_buffer().size() < Store.MAX_BYTES,
		"compact committed envelope fits explicit byte ceiling"
	)
	_put(path, "x".repeat(Store.MAX_BYTES + 1))
	check(
		Profile.same(Store.restore(path), initial),
		"oversized primary is bounded and same-revision mirror recovers"
	)
	_put(path + ".committed", "x".repeat(Store.MAX_BYTES + 1))
	_blocked_unchanged("both oversized copies fail closed")


func _repair_matrix() -> void:
	for suffix: String in ["", ".committed"]:
		var label: String = "repair_primary" if suffix == "" else "repair_mirror"
		for operation: String in ["open", "write", "flush", "close", "rename"]:
			_seed(successor, 8)
			_put(path + suffix, "{corrupt")
			Store._test_stop_after = label + "." + operation
			var outcome: Dictionary = Store.repair(path)
			Store._test_stop_after = ""
			check(
				outcome.status == "committed" and Profile.same(Store.restore(path), successor),
				label + operation + ": interrupted repair retains committed owner"
			)
			check(
				Store.inspect(path).revision == 8,
				label + operation + ": no revision or decay repeated"
			)
			check(
				Store.repair(path).status == "committed" and Store.inspect(path).status == "ready",
				label + operation + ": repair retry restores exact redundancy"
			)


func _blocked_unchanged(label: String) -> void:
	var before: Dictionary = _snapshot()
	check(
		Store.inspect(path).status == "blocked" and Store.restore(path).is_empty(),
		label + ": read fails closed"
	)
	check(
		(
			Store.commit(initial, path).status == "blocked"
			and Store.commit(successor, path).status == "blocked"
			and Store.repair(path).status == "blocked"
		),
		label + ": resets, exact target retries and repair reject"
	)
	check(_snapshot() == before, label + ": every artifact remains byte-for-byte unchanged")


func _record(value: Dictionary, revision: int) -> Dictionary:
	return {
		"version": Store.VERSION,
		"path": ProjectSettings.globalize_path(path).simplify_path(),
		"revision": revision,
		"lineage": value
	}


func _seed(value: Dictionary, revision: int) -> void:
	_cleanup()
	if not value.is_empty():
		var encoded: String = JSON.stringify(_record(value, revision), "", true, true)
		_put(path, encoded)
		_put(path + ".committed", encoded)


func _put(destination: String, bytes: String) -> void:
	var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		check(false, "test fixture write opens")
		return
	file.store_string(bytes)
	file.flush()
	file.close()


func _snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	for suffix: String in Store.SUFFIXES:
		if FileAccess.file_exists(path + suffix):
			snapshot[suffix] = FileAccess.get_file_as_string(path + suffix)
	return snapshot


func _cleanup() -> void:
	for suffix: String in Store.SUFFIXES:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

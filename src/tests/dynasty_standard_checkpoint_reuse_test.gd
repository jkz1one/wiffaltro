extends "res://src/tests/dynasty_standard_qualified_reuse_test.gd"
## Test-only old Standard89 checkpoint path, isolated Store lifecycle and counts.
func _step(op: String, operands: Dictionary) -> Dictionary:
	if op == "checkpoint":
		_checkpoint_controls(operands.snapshot, "draft-extension")
	elif op == "close":
		var owner: Dictionary = Store.inspect(path).owner
		_checkpoint_controls(Store.read_snapshot(path, owner.other.reference), "no-op")
	return super._step(op, operands)

func _checkpoint_controls(snapshot: Dictionary, label: String) -> void:
	var owner: Dictionary = Store.inspect(path).owner
	var source: Dictionary = Store.read_snapshot(path, owner.other.reference)
	var current: Dictionary = V2._qualified(owner, "other", source)
	var request: Dictionary = {"session_id": owner.other.session_id, "snapshot": snapshot}
	var original: String = JSON.stringify([owner, source, snapshot], "", true, true)
	var prior: Dictionary = owner.duplicate(true)
	var actual: Dictionary = owner.duplicate(true)
	var old_snapshots: Dictionary = {}
	var new_snapshots: Dictionary = {}
	Engine.set_meta("league_reuse_calls", 0)
	var old_ok: bool = _legacy_checkpoint(prior, owner, request, current, old_snapshots)
	var old_count: int = Engine.get_meta("league_reuse_calls", 0)
	Engine.set_meta("league_reuse_calls", 0)
	var new_ok: bool = V2._checkpoint(actual, owner, request, current, new_snapshots)
	var new_count: int = Engine.get_meta("league_reuse_calls", 0)
	check(old_ok and new_ok, label + " both checkpoints accept")
	check(old_count == 3 and new_count == 2, label + " full qualifier callbacks 3 -> 2, including unchanged install replay")
	print("STANDARD_CHECKPOINT_REUSE_COUNT ", label, " old=", old_count, " new=", new_count)
	check(Profile.same(prior, actual) and Profile.same(old_snapshots, new_snapshots), label + " exact owner/progress/references and prepared bytes")
	for field: String in ["raw", "grant", "session", "request_session", "frontier"]:
		var bad_owner: Dictionary = owner.duplicate(true)
		var bad: Dictionary = request.duplicate(true)
		match field:
			"raw": bad.snapshot.checkpoint.seed += 1
			"grant": bad.snapshot.grant.owner_id += "-forged"
			"session": bad.snapshot.session.session_id += "-forged"
			"request_session": bad.session_id += "-forged"
			"frontier": bad_owner.other.frontier.header_hash = "0".repeat(64)
		var old_next: Dictionary = bad_owner.duplicate(true)
		var new_next: Dictionary = bad_owner.duplicate(true)
		old_snapshots = {}
		new_snapshots = {}
		old_ok = _legacy_checkpoint(old_next, bad_owner, bad, current, old_snapshots)
		new_ok = V2._checkpoint(new_next, bad_owner, bad, current, new_snapshots)
		check(not old_ok and not new_ok, label + " checkpoint differential rejects " + field)
		check(Profile.same(old_next, new_next) and Profile.same(old_snapshots, new_snapshots), label + " identical rejection output " + field)
	check(original == JSON.stringify([owner, source, snapshot], "", true, true), label + " caller and source bytes unchanged")

func _legacy_checkpoint(next: Dictionary, owner: Dictionary, request: Dictionary,
	current: Dictionary, snapshots: Dictionary) -> bool:
	# Exact prior path restricted by this fixture to Standard89, selected other.
	assert(owner.selected == "other" and request.snapshot.version == 89)
	if request.session_id != owner[owner.selected].session_id: return false
	var checked: Dictionary = Authority._qualify_session(owner.career, request.session_id, request.snapshot)
	if checked.is_empty() or not Profile.same(checked.session, current.session): return false
	if not V2._extends(current, checked, owner[owner.selected].frontier): return false
	next.career = Authority.checkpoint_session(owner.career, request.session_id, request.snapshot)
	if next.career.is_empty() or V2._install(next, owner.selected, request.snapshot).is_empty(): return false
	if not V2._add_snapshot(snapshots, request.snapshot): return false
	return V2._settle_completed(next, owner.selected, checked, request.snapshot)

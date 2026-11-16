extends Node
## Actual production disk protocol + Journal/Pack replay, with explicitly synthetic funding.
## No Dynasty authority, earned-career, physical-game or power-loss durability claim.
const Store = preload("res://src/gameplay/season/durable_owner_store.gd")
const Domain = preload("res://src/tests/journal_pack_store_domain.gd")
const Journal = preload("res://src/gameplay/season/club_asset_journal.gd")
var domain: RefCounted = Domain.new()
var root: String = ""
var last_error: String = ""
var stop_at: String = ""
var stopped: bool = false
var active_override: String = ""
var callback_probe: bool = false
var observed_steps: Array[String] = []
var mode: String = "suite"
var checks: int = 0
var failures: int = 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _error_read() -> String:
	return last_error


func _error_write(message: String) -> void:
	last_error = message


func _active_path() -> String:
	return active_override if not active_override.is_empty() else \
		root.path_join("ordinary-save-protected.json")


func _fault(step: String) -> bool:
	if callback_probe:
		observed_steps.append(step + ":" + last_error)
		last_error = "fault-write"
	if step == stop_at:
		stopped = true
		return true
	return false


func _store() -> RefCounted:
	return Store.new(Domain.new(), _active_path, _fault, _error_read, _error_write)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--journal-store-test-root="):
			root = argument.trim_prefix("--journal-store-test-root=")
		if argument.begins_with("--journal-store-mode="):
			mode = argument.trim_prefix("--journal-store-mode=")
	if mode not in ["suite", "restart-write", "restart-read"]:
		get_tree().quit(2)
		return
	if not root.is_absolute_path() or root.length() < 2 or root != root.simplify_path() \
		or (DirAccess.dir_exists_absolute(root) != (mode == "restart-read")):
		push_error("Fresh absolute --journal-store-test-root= required; no tests ran.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	if mode == "restart-write":
		_restart_write()
	elif mode == "restart-read":
		_restart_read()
	else:
		_lifecycle()
		_fault_matrix()
		_tamper()
	stop_at = ""
	print("Journal pack disk mode: " + mode)
	print("Journal pack disk checks: %d, failures: %d, synthetic_credits=true, Dynasty=false"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _create(path: String) -> Dictionary:
	return _store().create({"seed": 17, "credits": [35, 65, 0]}, path)


func _open(owner: Dictionary, id: String = "open") -> Dictionary:
	return {"op": "checkpoint", "request_id": id, "expected_revision": owner.revision,
		"command": {"op": "player_pack_open", "id": id + ":event", "rev": owner.revision - 1,
			"through": 2, "price_version": 1}}


func _pick(owner: Dictionary, state: Dictionary) -> Dictionary:
	return {"op": "checkpoint", "request_id": "pick", "expected_revision": owner.revision,
		"command": {"op": "player_pack_pick", "id": "pick:event", "rev": owner.revision - 1,
			"pack": state.context.pending.id, "player": state.context.pending.choices[0]}}


func _lifecycle() -> void:
	var bridge: RefCounted = _store()
	bridge.last_error = "component-write"
	check(last_error == "component-write", "error setter updates caller immediately")
	last_error = "caller-write"
	check(bridge.last_error == "caller-write", "error getter reads live caller state")
	var protected: String = root.path_join("changed-active.json")
	check(bridge._isolated(protected), "initial active path permits unrelated target")
	active_override = protected
	check(not bridge._isolated(protected), "existing transport reads changed active path")
	active_override = ""
	callback_probe = true
	check(not bridge._interrupt("bridge-probe"), "real fault callback executes")
	callback_probe = false
	check(observed_steps == ["bridge-probe:caller-write"] \
		and bridge.last_error == "fault-write", "fault observes and mutates live error state")
	var path: String = root.path_join("lifecycle.json")
	var created: Dictionary = _create(path)
	check(created.status == "committed", "empty actual journal commits to both manifests")
	if created.status != "committed":
		return
	var projected: Dictionary = domain.project({}, created.owner.request)
	var encoded: String = projected.snapshots[projected.owner.reference.sha256]
	var cold_snapshot: Dictionary = JSON.parse_string(encoded)
	check(Journal.same(domain._snapshot_reference(cold_snapshot), projected.owner.reference),
		"actual projected blob preserves cold reference identity")
	check(domain.validate_selected(projected.owner, cold_snapshot) != null,
		"actual projected blob cold source qualification succeeds")
	check(encoded == domain._snapshot_encoded(cold_snapshot),
		"canonical snapshot encoding is stable after JSON parse")
	var request: Dictionary = _open(created.owner)
	var before: String = FileAccess.get_file_as_string(path)
	var stale: Dictionary = request.duplicate(true)
	stale.expected_revision += 1
	check(_store().commit(stale, path).status == "blocked", "stale disk revision refuses")
	check(FileAccess.get_file_as_string(path) == before, "stale request leaves bytes exact")
	var opened: Dictionary = _store().commit(request, path)
	check(opened.status == "committed", "actual paid event commits")
	if opened.status != "committed":
		return
	var cold: Dictionary = _store().restore(path)
	check(cold.status == "committed", "new transport/domain instance cold restores")
	if cold.status != "committed":
		return
	var state: Dictionary = cold.qualified_selected_season
	check(state.context.spent == 80 and state.context.opened == 1 \
		and state.context.pending.choices.size() == 3, "actual production paid reveal preserved")
	check(_store().commit(request, path).owner == opened.owner, "exact disk retry no second debit")
	var changed: Dictionary = request.duplicate(true)
	changed.command.through = 1
	check(_store().commit(changed, path).status == "blocked", "changed action ID refuses")
	var pick: Dictionary = _pick(opened.owner, state)
	var selected: Dictionary = _store().commit(pick, path)
	check(selected.status == "committed", "real paid choice commits")
	if selected.status != "committed":
		return
	cold = _store().restore(path)
	check(cold.status == "committed", "cold selection restore")
	if cold.status != "committed":
		return
	state = cold.qualified_selected_season
	check(state.context.pending.is_empty() and state.context.spent == 80 \
		and state.context.pack_owned == [pick.command.player] and state.events.size() == 2,
		"actual journal replay preserves exactly one owned player and debit")
	check(_store().commit(pick, path).owner == selected.owner, "choice retry exact")
	check(_store().read_snapshot(path, created.owner.reference).is_empty(),
		"unreachable old blob cannot be resolved through public API")
	check(_store().commit(_open(selected.owner, "poor"), path).status == "blocked",
		"actual pack service rejects remaining20CB without disk transition")


func _fault_matrix() -> void:
	var labels: Array[String] = ["intent.clear"]
	for stage: String in ["object0.a", "object0.b", "intent", "primary", "mirror"]:
		for step: String in ["open", "write", "flush", "close", "rename"]:
			labels.append(stage + "." + step)
	for index in range(labels.size()):
		_fault_case(root.path_join("fault-%02d.json" % index), labels[index])


func _fault_case(path: String, label: String) -> void:
	var initial: Dictionary = _create(path)
	check(initial.status == "committed", "fault fixture commits: " + label)
	if initial.status != "committed":
		return
	var before: String = FileAccess.get_file_as_string(path)
	var request: Dictionary = _open(initial.owner)
	stop_at = label
	stopped = false
	var interrupted: Dictionary = _store().commit(request, path)
	stop_at = ""
	check(stopped, "exact fault point reached: " + label)
	check(interrupted.status in ["not_committed", "committed"], "bounded fault outcome: " + label)
	if interrupted.status == "not_committed":
		check(FileAccess.get_file_as_string(path) == before, "no promotion before commit: " + label)
	var store: RefCounted = _store()
	var inspected: Dictionary = store.inspect(path)
	var recovered: Dictionary
	if inspected.status == "pending":
		var altered: Dictionary = request.duplicate(true)
		altered.command.price_version = 2
		check(store.commit(altered, path).status == "blocked", "pending quote remains bound")
		recovered = store.retry_pending(path)
	elif inspected.status == "recoverable":
		recovered = store.repair(path)
	else:
		recovered = store.commit(request, path)
	check(recovered.status == "committed", "exact recovery commits: " + label)
	var cold: Dictionary = _store().restore(path)
	check(cold.status == "committed", "recovered snapshot fully replays: " + label)
	if cold.status == "committed":
		var state: Dictionary = cold.qualified_selected_season
		check(state.events.size() == 1 and state.context.spent == 80 \
			and state.context.opened == 1, "fault retry never double-debits: " + label)


func _write(path: String, bytes: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(bytes)
	file.close()
	return true


func _tamper() -> void:
	for side: String in ["source", "target"]:
		_tamper_blob(side)
	var path: String = root.path_join("manifest-tamper.json")
	var created: Dictionary = _create(path)
	check(created.status == "committed", "manifest tamper fixture")
	if created.status != "committed":
		return
	var original: String = FileAccess.get_file_as_string(path)
	var changed: Dictionary = JSON.parse_string(original)
	changed.owner.request.payload.credits = [1000000]
	check(_write(path, JSON.stringify(changed)), "altered primary fixture written")
	check(_write(path + ".committed", JSON.stringify(changed)), "altered mirror fixture written")
	check(_store().restore(path).status != "committed", "synthetic funding cannot be inflated")
	check(FileAccess.get_file_as_string(path) == JSON.stringify(changed),
		"tamper refusal preserves evidence")


func _tamper_blob(side: String) -> void:
	var path: String = root.path_join("blob-" + side + ".json")
	var created: Dictionary = _create(path)
	if created.status != "committed":
		check(false, "blob tamper fixture")
		return
	stop_at = "intent.rename"
	var request: Dictionary = _open(created.owner)
	var interrupted: Dictionary = _store().commit(request, path)
	stop_at = ""
	check(interrupted.status == "not_committed", "tamper fixture has exact pending intent")
	var store: RefCounted = _store()
	var pending: Dictionary = store.inspect(path)
	if pending.status != "pending":
		check(false, "pending target is inspectable")
		return
	var ref: Dictionary = created.owner.reference if side == "source" else pending.pending.reference
	var first: String = store._object_path(path, ref, "a")
	var second: String = store._object_path(path, ref, "b")
	var exact: String = FileAccess.get_file_as_string(first)
	var intent: String = FileAccess.get_file_as_string(path + ".intent")
	check(_write(first, "{}") and _write(second, "{}"), "both exact replicas altered: " + side)
	check(_store().retry_pending(path).status == "blocked", "bound blob corruption refuses: " + side)
	check(FileAccess.get_file_as_string(path + ".intent") == intent, "refusal retains exact intent")
	check(_write(first, exact) and _write(second, exact), "restore exact fixture bytes: " + side)
	check(_store().retry_pending(path).status == "committed", "exact source recovery succeeds")
	var cold: Dictionary = _store().restore(path)
	check(cold.status == "committed", "recovered target journal replays")
	if cold.status == "committed":
		check(cold.qualified_selected_season.context.spent == 80, "recovery debit exactly once")


func _restart_write() -> void:
	var path: String = root.path_join("restart.json")
	var created: Dictionary = _create(path)
	check(created.status == "committed", "restart fixture commits")
	if created.status != "committed":
		return
	var request: Dictionary = _open(created.owner)
	stop_at = "intent.rename"
	stopped = false
	var interrupted: Dictionary = _store().commit(request, path)
	stop_at = ""
	check(stopped and interrupted.status == "not_committed", "restart stops after intent rename")
	var pending: Dictionary = _store().inspect(path)
	check(pending.status == "pending", "process one leaves real pending paid transition")
	if pending.status != "pending":
		return
	var snapshot: Dictionary = _store().read_snapshot(path, pending.pending.reference)
	var state: Variant = domain.validate_selected(pending.pending, snapshot)
	check(state != null, "pending target validates through actual journal replay")
	if state == null:
		return
	check(state.context.spent == 80 and state.context.pending.choices.size() == 3,
		"pending target binds paid choices before process exit")
	check(_write(root.path_join("restart-witness.json"), JSON.stringify({
		"pid": OS.get_process_id(), "request": request,
		"pending": pending.pending, "choices": state.context.pending.choices,
		"intent_sha": FileAccess.get_file_as_string(path + ".intent").sha256_text()})),
		"process one witness preserved")


func _restart_read() -> void:
	var path: String = root.path_join("restart.json")
	var witness: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(root.path_join("restart-witness.json")))
	if not witness is Dictionary or not witness.has_all(
		["pid", "request", "pending", "choices", "intent_sha"]):
		check(false, "process one witness required")
		return
	check(witness.pid != OS.get_process_id(), "recovery is a distinct native process")
	check(FileAccess.get_file_as_string(path + ".intent").sha256_text() == witness.intent_sha,
		"restart consumes exact prior intent bytes")
	var pending: Dictionary = _store().inspect(path)
	check(pending.status == "pending", "new process sees paid pending transition")
	if pending.status != "pending":
		return
	check(Journal.same(pending.pending, witness.pending), "pending owner matches prior process")
	var altered: Dictionary = witness.request.duplicate(true)
	altered.command.price_version = 2
	check(_store().commit(altered, path).status == "blocked", "restart rejects changed quote")
	var recovered: Dictionary = _store().retry_pending(path)
	check(recovered.status == "committed", "new process completes exact paid intent")
	if recovered.status != "committed":
		return
	var cold: Dictionary = _store().restore(path)
	check(cold.status == "committed", "recovered paid state fully replays")
	if cold.status != "committed":
		return
	var state: Dictionary = cold.qualified_selected_season
	check(state.context.spent == 80 and state.events.size() == 1 \
		and Journal.same(state.context.pending.choices, witness.choices),
		"cross-process balance and exact choices retained")
	var retry: Dictionary = _store().commit(witness.request, path)
	check(retry.status == "committed" and Journal.same(retry.owner, recovered.owner),
		"cross-process paid request retry is idempotent")
	var pick: Dictionary = _pick(recovered.owner, state)
	var selected: Dictionary = _store().commit(pick, path)
	check(selected.status == "committed", "new process commits actual choice")
	if selected.status != "committed":
		return
	cold = _store().restore(path)
	check(cold.status == "committed", "new choice fully replays")
	if cold.status != "committed":
		return
	state = cold.qualified_selected_season
	check(state.context.spent == 80 and state.events.size() == 2 \
		and state.context.pending.is_empty() and state.context.pack_owned == [pick.command.player],
		"cross-process choice preserves one debit and one owned player")
	retry = _store().commit(pick, path)
	check(retry.status == "committed" and Journal.same(retry.owner, selected.owner),
		"cross-process chosen request retry is idempotent")

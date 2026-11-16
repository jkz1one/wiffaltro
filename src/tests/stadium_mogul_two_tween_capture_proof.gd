extends RefCounted
## Isolated capture lifecycle controls; no game tween is killed, replaced or advanced here.

const Freeze = preload("res://src/tests/stadium_mogul_two_capture_freeze.gd")


static func run(owner: Node, lab: PitchBatLab) -> void:
	var control: Node = Node.new()
	control.name = "IsolatedCaptureTweenControls"
	# This new nonphysical control allows SceneTree to retire its dead entry while paused.
	control.process_mode = Node.PROCESS_MODE_ALWAYS
	lab.add_child(control)
	var dead: Tween = _new_tween(control)
	dead.custom_step(0.125)
	dead.kill()
	var live: Tween = _new_tween(control)
	var held: Dictionary = Freeze.lock(lab)
	var dead_row: Dictionary = _record(held, dead)
	var live_row: Dictionary = _record(held, live)
	owner._check(
		not dead_row.is_empty() and not live_row.is_empty(), "both control identities captured"
	)
	if not dead_row.is_empty() and not live_row.is_empty():
		_counterfactuals(owner, dead_row, live_row)
	owner._check(
		Freeze.intact(lab, held), "pre-existing invalid stopped handle is explicitly admitted"
	)
	await _drain(owner)
	owner._check(
		not lab.get_tree().get_processed_tweens().has(dead) and not dead.is_valid(),
		"initial invalid handle naturally retires without resurrection"
	)
	owner._check(
		Freeze.intact(lab, held), "natural initial tombstone retirement preserves strict live lock"
	)
	owner._check(
		Freeze.unlock(lab, held), "initial inert retirement restores every live tween and callback"
	)
	owner._check(
		live.is_running() and live.get_total_elapsed_time() == 0,
		"live tween resumes at exact acquired time"
	)
	live.kill()
	await _drain(owner)

	live = _new_tween(control)
	held = Freeze.lock(lab)
	live.kill()
	owner._check(
		not Freeze.intact(lab, held), "initially live tween killed during capture is rejected"
	)
	await _drain(owner)
	owner._check(
		not Freeze.intact(lab, held), "retirement cannot erase a captured live-tween violation"
	)
	owner._check(
		not Freeze.unlock(lab, held), "invalid live handle is never played or accepted on unlock"
	)
	_restored_callbacks(owner, lab, held)
	await _drain(owner)

	live = _new_tween(control)
	held = Freeze.lock(lab)
	var replacement: Tween = _new_tween(control)
	replacement.pause()
	owner._check(
		not Freeze.intact(lab, held), "new replacement identity during capture is rejected"
	)
	replacement.kill()
	await _drain(owner)
	owner._check(
		not Freeze.intact(lab, held), "replacement removal cannot clear the latched violation"
	)
	owner._check(not Freeze.unlock(lab, held), "replacement history prevents accepted unlock")
	owner._check(live.is_running(), "failed replacement control still restores owned live tween")
	_restored_callbacks(owner, lab, held)
	live.kill()
	await _drain(owner)

	live = _new_tween(control)
	held = Freeze.lock(lab)
	live.play()
	owner._check(not Freeze.intact(lab, held), "resuming a live tween inside capture is rejected")
	live.pause()
	owner._check(
		not Freeze.intact(lab, held), "re-pausing cannot conceal the running-state violation"
	)
	owner._check(
		not Freeze.unlock(lab, held), "observed tween violations fail permanently for this lock"
	)
	_restored_callbacks(owner, lab, held)
	live.kill()
	await _drain(owner)
	control.queue_free()
	await _drain(owner)
	owner._check(not is_instance_valid(control), "isolated tween controls release all ownership")
	owner._check(
		Freeze.physics_proof(lab), "tween controls retain actual bodies and positive queries"
	)
	print(
		"MOGUL_TWO_TWEEN_CAPTURE_CONTROLS initial_inert_retirement=true",
		" strict_live_identity=true latched_breaches=true"
	)


static func _new_tween(control: Node) -> Tween:
	var result: Tween = control.create_tween().bind_node(control)
	result.tween_interval(1.0)
	return result


static func _drain(owner: Node) -> void:
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame


static func _record(held: Dictionary, tween: Tween) -> Dictionary:
	for row: Dictionary in held.tweens:
		if row.tween == tween:
			return row
	return {}


static func _counterfactuals(owner: Node, dead: Dictionary, live: Dictionary) -> void:
	var actual: Dictionary = {
		"id": dead.id, "valid": false, "running": false, "elapsed": dead.elapsed, "present": false
	}
	owner._check(
		Freeze._tween_record_matches(dead, actual, true),
		"inert queue retirement is a bounded admission"
	)
	for field: String in ["valid", "running", "elapsed", "id"]:
		var changed: Dictionary = actual.duplicate()
		changed[field] = true if field in ["valid", "running"] else actual[field] + 1
		owner._check(
			not Freeze._tween_record_matches(dead, changed, true),
			(
				"initial inert handle cannot resurrect, run, change elapsed or change identity: "
				+ field
			)
		)
	for field: String in ["valid", "present", "running", "elapsed", "id"]:
		var changed: Dictionary = {
			"id": live.id, "valid": true, "running": false, "elapsed": live.elapsed, "present": true
		}
		changed[field] = (
			not changed[field] if field in ["valid", "present", "running"] else changed[field] + 1
		)
		owner._check(
			not Freeze._tween_record_matches(live, changed, true),
			"every live handle field is strict across capture: " + field
		)
	var malformed: Dictionary = dead.duplicate()
	malformed.running = true
	owner._check(
		not Freeze._tween_record_matches(malformed, actual, true),
		"invalid-but-running acquisition is refused"
	)


static func _restored_callbacks(owner: Node, lab: PitchBatLab, held: Dictionary) -> void:
	owner._check(
		Freeze._modes_intact(held), "negative control preserves every process/disable mode"
	)
	for row: Dictionary in held.nodes:
		owner._check(
			Freeze._flags(row.node) == row.flags, "negative control restores every callback flag"
		)
	owner._check(
		lab.get_tree().paused == held.paused, "negative control restores original tree pause"
	)

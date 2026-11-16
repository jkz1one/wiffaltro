extends RefCounted
## Diagnostic only: exact lock fields, no rendering/visibility acceptance or lifecycle repair.

const Freeze = preload("res://src/tests/stadium_long_yard_capture_freeze.gd")
const Archive = preload("res://src/tests/stadium_long_yard_history_archive.gd")
const CALLBACK_FIELDS: Array[String] = [
	"process",
	"physics_process",
	"process_internal",
	"physics_process_internal",
	"input",
	"shortcut_input",
	"unhandled_input",
	"unhandled_key_input"
]


static func run(owner: Node, lab: PitchBatLab, left: bool, defense: bool) -> void:
	var label: String = "%s-%s" % ["left" if left else "right", "defense" if defense else "offense"]
	var report: Dictionary = {
		"kind": "DIAGNOSTIC_LY_CAPTURE_LOCK_FIELDS_NO_PIXEL_QUALIFICATION",
		"label": label,
		"display": DisplayServer.get_name(),
		"before_tweens": _tweens(lab),
		"before_ball": _ball(lab),
		"before_physics_tick": Engine.get_physics_frames(),
		"before_process_tick": Engine.get_process_frames()
	}
	var held: Dictionary = Freeze.lock(lab)
	report["locked"] = _observe(lab, held, true)
	owner._check(report.locked.intact, "diagnostic initial source capture lock is intact: " + label)
	# Same explicit freeze as the archived-controller path; no pose or trajectory writes.
	lab._batted_ball.freeze = true
	report["after_explicit_freeze"] = _ball(lab)
	await owner.get_tree().process_frame
	await owner.get_tree().process_frame
	report["after_two_locked_process_frames"] = _observe(lab, held, true)
	owner._check(
		report.after_two_locked_process_frames.intact,
		"diagnostic capture lock survives two queued-work boundaries: " + label
	)
	report["unlock_return"] = Freeze.unlock(lab, held)
	report["released"] = _observe(lab, held, false)
	owner._check(report.unlock_return, "diagnostic exact source lock restoration: " + label)
	var errors: Array[String] = []
	var numeric: Variant = Archive._numeric(report, errors)
	owner._check(errors.is_empty(), "lock diagnostic contains only exact inspectable numeric state")
	var directory: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--long-yard-lock-diagnostic-dir="):
			directory = argument.trim_prefix("--long-yard-lock-diagnostic-dir=")
	owner._check(not directory.is_empty(), "diagnostic field archive destination is required")
	if directory.is_empty() or not errors.is_empty():
		return
	var bytes: PackedByteArray = JSON.stringify(numeric, "", true, true).to_utf8_buffer()
	var compressed: PackedByteArray = bytes.compress(FileAccess.COMPRESSION_GZIP)
	owner._check(
		not compressed.is_empty() and compressed.size() < 2 * 1024 * 1024,
		"complete lock field report is bounded by2MiB gzip"
	)
	if compressed.is_empty() or compressed.size() >= 2 * 1024 * 1024:
		return
	owner._check(DirAccess.make_dir_recursive_absolute(directory) == OK, "diagnostic directory")
	var path: String = directory.path_join(label + "-lock-fields.json.gz")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	owner._check(file != null, "diagnostic field archive opens")
	if file == null:
		return
	file.store_buffer(compressed)
	file.close()
	var actual: PackedByteArray = FileAccess.get_file_as_bytes(path)
	owner._check(actual == compressed, "diagnostic compressed fields roundtrip exactly")
	owner._check(
		actual.decompress(bytes.size(), FileAccess.COMPRESSION_GZIP) == bytes,
		"diagnostic gzip retains every full-precision field"
	)
	print(
		"LONG_YARD_LOCK_DIAGNOSTIC label=",
		label,
		" initial_differences=",
		report.locked.differences,
		" drained_differences=",
		report.after_two_locked_process_frames.differences,
		" released_differences=",
		report.released.differences,
		" archive=",
		path,
		" sha256=",
		FileAccess.get_sha256(path)
	)


static func _observe(lab: PitchBatLab, held: Dictionary, locked: bool) -> Dictionary:
	var differences: Array[Dictionary] = []
	var expected_pause: bool = true if locked else held.paused
	_difference(differences, "tree", "paused", expected_pause, lab.get_tree().paused)
	_difference(differences, "lab", "node_count", held.nodes.size(), Freeze._nodes(lab).size())
	_difference(differences, "physics", "before_positive_queries", true, held.physics_before)
	for row: Dictionary in held.ancestors:
		if not is_instance_valid(row.node):
			differences.append(
				{"owner": "ancestor", "field": "freed", "expected": false, "actual": true}
			)
			continue
		_difference(
			differences, str(row.node.get_path()), "process_mode", row.mode, row.node.process_mode
		)
	var nodes: Array = []
	var bodies: Array = []
	for row: Dictionary in held.nodes:
		var node: Node = row.node
		if not is_instance_valid(node):
			differences.append(
				{"owner": "node", "field": "freed", "expected": false, "actual": true}
			)
			continue
		var path: String = str(node.get_path())
		var flags: Array = Freeze._flags(node)
		var expected: Array = (
			[false, false, false, false, false, false, false, false] if locked else row.flags
		)
		nodes.append(
			{"id": node.get_instance_id(), "path": path, "mode": node.process_mode, "flags": flags}
		)
		_difference(differences, path, "process_mode", row.mode, node.process_mode)
		for index: int in range(flags.size()):
			_difference(differences, path, CALLBACK_FIELDS[index], expected[index], flags[index])
		if node is CollisionObject3D:
			_difference(differences, path, "disable_mode", row.disable, node.disable_mode)
		if node is PhysicsBody3D:
			var world: String = str(lab.get_world_3d().space)
			var actual: String = str(PhysicsServer3D.body_get_space(node.get_rid()))
			bodies.append(
				{
					"id": node.get_instance_id(),
					"path": path,
					"rid": str(node.get_rid()),
					"world": world,
					"server_space": actual
				}
			)
			_difference(differences, path, "world_space", world, str(node.get_world_3d().space))
			_difference(differences, path, "server_space", world, actual)
	var current: Array[Tween] = lab.get_tree().get_processed_tweens()
	_difference(differences, "tree", "tween_breach", false, held.tween_breach)
	var known: Dictionary = {}
	for row: Dictionary in held.tweens:
		known[row.id] = true
	for tween: Tween in current:
		_difference(
			differences,
			"Tween:%d" % tween.get_instance_id(),
			"known_at_acquisition",
			true,
			known.has(tween.get_instance_id())
		)
	for row: Dictionary in held.tweens:
		var label: String = "Tween:%d" % row.tween.get_instance_id()
		_difference(differences, label, "identity", row.id, row.tween.get_instance_id())
		if row.valid:
			_difference(differences, label, "present", true, current.has(row.tween))
		_difference(differences, label, "valid", row.valid, row.tween.is_valid())
		_difference(
			differences, label, "running", false if locked else row.running, row.tween.is_running()
		)
		_difference(differences, label, "elapsed", row.elapsed, row.tween.get_total_elapsed_time())
	var physics: bool = Freeze.physics_proof(lab)
	_difference(differences, "physics", "positive_queries_and_membership", true, physics)
	return {
		"intact": Freeze.intact(lab, held) if locked else differences.is_empty(),
		"differences": differences,
		"nodes": nodes,
		"bodies": bodies,
		"tweens": _tweens(lab),
		"ball": _ball(lab),
		"physics_tick": Engine.get_physics_frames(),
		"process_tick": Engine.get_process_frames()
	}


static func _difference(
	rows: Array[Dictionary], owner: String, field: String, expected: Variant, actual: Variant
) -> void:
	if expected != actual:
		rows.append({"owner": owner, "field": field, "expected": expected, "actual": actual})


static func _tweens(lab: PitchBatLab) -> Array:
	var rows: Array = []
	for tween: Tween in lab.get_tree().get_processed_tweens():
		rows.append(
			{
				"id": tween.get_instance_id(),
				"valid": tween.is_valid(),
				"running": tween.is_running(),
				"elapsed": tween.get_total_elapsed_time()
			}
		)
	return rows


static func _ball(lab: PitchBatLab) -> Dictionary:
	var ball: BattedBallBody = lab._batted_ball
	return {
		"id": ball.get_instance_id(),
		"parent_id": ball.get_parent().get_instance_id(),
		"transform": ball.global_transform,
		"freeze": ball.freeze,
		"sleeping": ball.sleeping,
		"linear_velocity": ball.linear_velocity,
		"angular_velocity": ball.angular_velocity,
		"dead": lab._ball_play_resolver.state.dead,
		"phase": int(lab._match_state.phase)
	}

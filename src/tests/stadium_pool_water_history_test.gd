extends Node3D
## Real fresh ordinary-body histories. Direct rule probes are labeled, never controller proof.

const ENCODER: Script = preload("res://src/tests/stadium_pool_chronology_test.gd")
const SAMPLES: int = 24
const ROLES: Array[String] = [StadiumPoolContract.LIVE, StadiumPoolContract.SCENERY, "NO_POOL"]
var _checks: int = 0
var _failures: int = 0
var _source: String
var _mode: String = ""
var _folder: String = ""
var _floor: StaticBody3D
var _ball: BattedBallBody
var _resolver: BallPlayResolver
var _guard: StadiumPoolWaterGuard
var _case: Dictionary
var _role: String
var _events: Array[Dictionary] = []
var _sample: int = 0
var _frame: int = 0
var _running: bool = false
var _previous: Vector3
var _prefix: int = -1
var _windows: Array[Dictionary] = []
var _artifacts: Array[Dictionary] = []
var _total: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool-water-mode="):
			_mode = arg.trim_prefix("--pool-water-mode=")
		if arg.begins_with("--pool-water-report-dir="):
			_folder = arg.trim_prefix("--pool-water-report-dir=")
	if (
		_mode not in ["shadow", "active"]
		or _folder.is_empty()
		or DirAccess.dir_exists_absolute(_folder)
	):
		push_error("Explicit mode and nonexistent fresh report directory required")
		get_tree().quit(1)
		return
	_check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "durable history directory")
	_check(Engine.physics_ticks_per_second == 60, "ordinary 60Hz step unchanged")
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	_floor = StadiumPoolWaterTestSupport.ground(self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for role: String in ROLES:
		var model: Node3D = StadiumPoolWaterTestSupport.model(self, role)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for case: Dictionary in cases():
			await _window(model, role, case)
		if model != null:
			model.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	_save(
		"trajectory",
		{
			"schema": "POOL-WATER-ORDINARY-TRAJECTORY-v1",
			"source": _source,
			"history_source_sha256": FileAccess.get_sha256(get_script().resource_path),
			"windows": _windows
		}
	)
	_check(_windows.size() == ROLES.size() * cases().size(), "complete expected window matrix")
	_save(
		"index",
		{
			"schema": "POOL-WATER-HISTORY-INDEX-v1",
			"source": _source,
			"history_source_sha256": FileAccess.get_sha256(get_script().resource_path),
			"mode": _mode,
			"checks": _checks,
			"failures": _failures,
			"windows": _windows.size(),
			"artifacts": _artifacts.duplicate(true),
			"ordinary_controller_qualified": false,
			"dry_to_dry_completeness_qualified": false
		}
	)
	print("POOL_WATER_INDEX ", JSON.stringify(_artifacts[-1], "", true, true))
	print(
		(
			"POOL_WATER_HISTORY checks=%d failures=%d windows=%d bytes=%d source=%s"
			% [_checks, _failures, _windows.size(), _total, _source]
		)
	)
	_floor.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)


func _window(model: Node3D, role: String, case: Dictionary) -> void:
	await get_tree().physics_frame
	_events.clear()
	_sample = 0
	_prefix = -1
	_frame = Engine.get_physics_frames()
	_case = case
	_role = role
	var position: Vector3 = StadiumPoolContract.placement() * case.position
	_ball = StadiumPoolWaterTestSupport.ball(self, position)
	_resolver = BallPlayResolver.new()
	_resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), case.get("foul", false))
	_resolver.play_resolved.connect(_on_outcome)
	if case.get("prior_ground", false):
		_resolver.record_ground_contact(Vector3(12, 0, 18))
	_guard = StadiumPoolWaterGuard.new()
	_ball.physics_contact_router = _contact
	_ball.surface_contact.connect(_surface)
	_ball.launch_started.connect(_launch_signal)
	_check(
		_guard.bind(
			_ball,
			_resolver,
			model,
			role,
			_source,
			StadiumPoolWaterTestSupport.registry(model, _floor),
			_mode == "active",
			_contact
		),
		"exact fresh guard binding"
	)
	_guard.observed.connect(_guard_event)
	_previous = position
	_running = true
	_append("public_launch.before", {"requested_velocity": case.velocity})
	StadiumPoolWaterTestSupport.launch(_ball, position, case.velocity)
	_append("public_launch.after", {"requested_velocity": case.velocity})
	while _sample < SAMPLES:
		await get_tree().physics_frame
	_running = false
	_check(_guard.valid(), "model/body/instance/source binding retained")
	_check(StadiumPoolPartyAssetIntegrity.source_sha256() == _source, "runtime source unchanged")
	_validate_window()
	var canonical: Dictionary = {"id": _id(role, case.id), "events": _canonical_events()}
	_windows.append(canonical)
	_save(
		_id(role, case.id),
		{
			"schema": "POOL-WATER-HISTORY-v1",
			"mode": _mode,
			"source": _source,
			"history_source_sha256": FileAccess.get_sha256(get_script().resource_path),
			"role": role,
			"case": case,
			"events": _events.duplicate(true),
			"guard_records": _guard.records.duplicate(true),
			"unsupported": _guard.unsupported.duplicate(true),
			"receipts": _guard.receipts.duplicate(true),
			"preterminal_prefix_count": _prefix,
			"actual_ball_script": _ball.get_script().resource_path,
			"strict_binding_retained": _guard.valid(),
			"canonical": canonical,
			"canonical_prefix_sha256": _prefix_hashes(canonical.events),
			"positioned_physics_control": true,
			"direct_rule_probe_not_controller": case.get("probe", false),
			"dry_to_dry_completeness_qualified": false
		}
	)
	_guard.detach()
	_ball.queue_free()
	_ball = null
	_guard = null
	_resolver = null
	await get_tree().physics_frame
	await get_tree().physics_frame


func _physics_process(delta: float) -> void:
	if not _running or _ball == null:
		return
	_append("process.before", {"delta": delta})
	if _sample == 1 and _case.get("probe", false):
		_append("manual_current_control.before", {"synthetic_direct_rule_probe": true})
		_resolver.record_clean_control(&"positioned_current_control", _ball.global_position, true)
		_append("manual_current_control.after", {"synthetic_direct_rule_probe": true})
	_resolver.observe_segment(_previous, _ball.global_position)
	_previous = _ball.global_position
	_resolver.advance_time(delta)
	_append("process.after", {"delta": delta})
	_sample += 1


func _contact(_value: BattedBallBody, batch: Array[Dictionary]) -> void:
	var contacts: Array[Dictionary] = []
	for row: Dictionary in batch:
		contacts.append(
			{
				"label": String(row.body.name),
				"position": row.position,
				"body_instance": row.body.get_instance_id()
			}
		)
	_append("contact_router", {"contacts": contacts})


func _surface(kind: StringName, position: Vector3) -> void:
	_append("surface", {"kind": String(kind), "position": position})
	if kind == &"ground":
		_append("ground.before", {"position": position})
		_resolver.record_ground_contact(position)
		_append("ground.after", {"position": position})


func _launch_signal(position: Vector3) -> void:
	_append("public_launch.signal", {"position": position})


func _on_outcome(outcome: BallPlayOutcome) -> void:
	if String(outcome.reason).begins_with("private_pool_water_"):
		_check(_prefix == -1, "exactly one water outcome prefix")
		_prefix = _events.size()
	_append(
		"outcome",
		{
			"result": int(outcome.result),
			"reason": String(outcome.reason),
			"position": outcome.resolution_position,
			"caught": outcome.caught
		}
	)


func _guard_event(event: String, _record: Dictionary) -> void:
	if event == "water_commit":
		_check(_prefix > 0, "outcome captured prefix before postterminal notification")
		_check(_resolver.state.dead, "terminal latch precedes reentrant notification")


func _append(event: String, detail: Dictionary) -> void:
	_events.append(
		{
			"seq": _events.size() + 1,
			"event": event,
			"frame": Engine.get_physics_frames(),
			"relative_frame": Engine.get_physics_frames() - _frame,
			"sample": _sample,
			"center": _ball.global_position,
			"velocity": _ball.linear_velocity,
			"angular_velocity": _ball.angular_velocity,
			"freeze": _ball.freeze,
			"sleeping": _ball.sleeping,
			"state": StadiumPoolWaterTestSupport.state_snapshot(_resolver.state),
			"detail": detail
		}
	)


func _canonical_events() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for event: Dictionary in _events:
		var row: Dictionary = event.duplicate(true)
		row.erase("seq")
		row.erase("frame")
		row.detail = ENCODER._canonical_detail(row.detail)
		rows.append(row)
	return rows


func _prefix_hashes(events: Array) -> Array[String]:
	var hashes: Array[String] = []
	for count: int in range(events.size() + 1):
		var digest: HashingContext = HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(var_to_bytes(events.slice(0, count)))
		hashes.append(digest.finish().hex_encode())
	return hashes


func _validate_window() -> void:
	var signal_row: Dictionary = {}
	var first: Dictionary = {}
	var before_samples: Array[int] = []
	var after_samples: Array[int] = []
	var results: Array[Dictionary] = []
	for row: Dictionary in _events:
		if row.event == "public_launch.signal":
			signal_row = row
		if row.event == "contact_router" and first.is_empty():
			first = row
		if row.event == "process.before":
			before_samples.append(row.sample)
		if row.event == "process.after":
			after_samples.append(row.sample)
		if row.event == "outcome":
			results.append(row)
	_check(not signal_row.is_empty() and not first.is_empty(), "real launch and router exercised")
	if signal_row.is_empty() or first.is_empty():
		return
	_check(
		_events[0].event == "public_launch.before" and _events[2].event == "public_launch.after",
		"consecutive ordinary public launch evidence"
	)
	_check(
		_events[0].frame == signal_row.frame and signal_row.frame == _events[2].frame,
		"fresh public launch in same prephysics phase"
	)
	_check(
		signal_row.velocity == _case.velocity and _events[2].velocity == _case.velocity,
		"requested velocity at signal and postlaunch"
	)
	_check(
		first.frame == signal_row.frame + 1 and first.sample == 1,
		"first actual router next tick retained"
	)
	var expected: Array[int] = []
	for index: int in range(SAMPLES):
		expected.append(index)
	_check(before_samples == expected and after_samples == expected, "complete 24 sample pairs")
	if _role == "NO_POOL":
		_check(
			ENCODER._launch_displacement_retained(first.center - signal_row.center, _case.velocity),
			"actual no-pool motion gate"
		)
		var collision_free: bool = (
			signal_row.center.y + minf(_case.velocity.y, 0) / 60 - 9.8 / 3600 > .0465
		)
		if collision_free:
			_check(
				(
					first.velocity.length() > _case.velocity.length() * .5
					and (
						first.velocity.distance_to(_case.velocity)
						< maxf(1, _case.velocity.length() * .2)
					)
				),
				"collision-free initial velocity retained"
			)
	var expected_water: bool = (
		_mode == "active" and _role == StadiumPoolContract.LIVE and _case.get("water", false)
	)
	_check(
		_guard.receipts.size() == (1 if expected_water else 0),
		"only declared supported positive-wet cases award"
	)
	_check(results.size() <= 1, "one terminal outcome at most")
	if expected_water:
		_check(
			_prefix > 0 and results.size() == 1, "water has exact preterminal prefix and outcome"
		)
		_check(
			(
				results[0].detail.result
				== (
					BallPlayOutcome.Result.FOUL
					if _case.get("foul", false)
					else BallPlayOutcome.Result.DOUBLE
				)
			),
			"approved water result"
		)
		_check(
			not results[0].state.caught and not results[0].state.touched,
			"water does not create catch or touch"
		)
		for row: Dictionary in _events.slice(_prefix):
			_check(row.state.dead, "postterminal samples remain dead")
	if _case.get("unsupported_ground", false) and _role == StadiumPoolContract.LIVE:
		_check(
			not _guard.unsupported.is_empty(), "ambiguous ground ordering explicitly unsupported"
		)
	_check(_guard.errors.is_empty(), "no runtime guard errors")


func _save(id: String, packet: Dictionary) -> void:
	var typed: PackedByteArray = var_to_bytes(packet)
	var readable: PackedByteArray = (
		(JSON.stringify(ENCODER._json_value(packet), "", true, true) + "\n").to_utf8_buffer()
	)
	_check(
		_total + typed.size() + readable.size() <= 48 * 1024 * 1024,
		"bounded complete packet budget"
	)
	if _total + typed.size() + readable.size() > 48 * 1024 * 1024:
		return
	var row: Dictionary = {"id": id}
	for kind: String in ["typed", "json"]:
		var extension: String = ".var" if kind == "typed" else ".json"
		var path: String = _folder.path_join(id + extension)
		if FileAccess.file_exists(path):
			_check(false, "never overwrite evidence")
			return
		var bytes: PackedByteArray = typed if kind == "typed" else readable
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_check(false, "packet opened")
			return
		file.store_buffer(bytes)
		file.close()
		_check(FileAccess.get_file_as_bytes(path) == bytes, "full packet bytes persisted")
		row[kind + "_file"] = id + extension
		row[kind + "_bytes"] = bytes.size()
		row[kind + "_sha256"] = FileAccess.get_sha256(path)
		_total += bytes.size()
	_check(var_to_bytes(bytes_to_var(typed)) == typed, "typed packet exact roundtrip")
	_artifacts.append(row)


static func _id(role: String, case: String) -> String:
	return (
		(
			"live"
			if role == StadiumPoolContract.LIVE
			else "scenery" if role == StadiumPoolContract.SCENERY else "no_pool"
		)
		+ "-"
		+ case
	)


static func cases() -> Array[Dictionary]:
	return [
		{
			"id": "clean_lob",
			"position": Vector3(0, 2.2, 0),
			"velocity": Vector3(0, -4, 0),
			"water": true
		},
		{
			"id": "inner_fast",
			"position": Vector3(0, 1.092, 1.9),
			"velocity": Vector3(0, -3, 10),
			"water": true
		},
		{
			"id": "ground_fast",
			"position": Vector3(0, 1.5, 0),
			"velocity": Vector3(0, -120, 0),
			"water": true
		},
		{"id": "dry_rim", "position": Vector3(0, 1.8, 2.3), "velocity": Vector3(0, -6, -4)},
		{"id": "outer_wall_low", "position": Vector3(0, .5, 3), "velocity": Vector3(0, 0, -12)},
		{
			"id": "foul_lob",
			"position": Vector3(0, 2.2, 0),
			"velocity": Vector3(0, -4, 0),
			"water": true,
			"foul": true
		},
		{
			"id": "prior_ground_water",
			"position": Vector3(0, 1.15, 0),
			"velocity": Vector3(0, -4, 0),
			"water": true,
			"prior_ground": true
		},
		{
			"id": "ambiguous_ground",
			"position": Vector3(0, 1.5, 0),
			"velocity": Vector3(3, -120, 0),
			"foul": true,
			"unsupported_ground": true
		},
		{
			"id": "inner_current_probe",
			"position": Vector3(0, 1.092, 1.9),
			"velocity": Vector3(0, -3, 10),
			"water": true,
			"probe": true
		},
		{
			"id": "ground_current_probe",
			"position": Vector3(0, 1.5, 0),
			"velocity": Vector3(0, -120, 0),
			"water": true,
			"probe": true
		}
	]


func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(label)

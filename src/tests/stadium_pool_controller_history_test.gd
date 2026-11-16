extends Node3D
## Source-only genuine-lab A/B versus certificate-shadow fixture. Never enables water.
## Live play uses a late physics state machine, with no physics_frame continuations.
# gdlint: disable=max-file-lines

enum Phase { DRAIN, PREPARE, SETTLE, LAUNCH, PLAY, DONE }

const ENCODER: Script = preload("res://src/tests/stadium_pool_chronology_test.gd")
const SHADOW_LAB: Script = preload("res://src/tests/helpers/pool_controller_shadow_lab.gd")
const SAMPLES: int = 180
const ROLES: Array[String] = [StadiumPoolContract.LIVE, StadiumPoolContract.SCENERY, "NO_POOL"]
const MAX_BYTES: int = 96 * 1024 * 1024
const SCHEMA: String = "POOL-CONTROLLER-HISTORY-v1"
const SETUP: String = "PLAIN_LAB_DEBUG_PLAY_PRIMARY_ENABLED_IDLE_PROCESS_DISABLED"

var _phase: Phase = Phase.DRAIN
var _wait_ticks: int = 2
var _mode: String = ""
var _folder: String = ""
var _source: String = ""
var _history_source: String = ""
var _checks: int = 0
var _failures: int = 0
var _ordinal: int = 0
var _sample: int = 0
var _launch_frame: int = 0
var _total: int = 0
var _lab: PitchBatLab
var _model: Node3D
var _shadow: StadiumPoolControllerShadow
var _ball: BattedBallBody
var _case: Dictionary
var _role: String
var _recording: bool = false
var _ready_count: int = 0
var _launch_count: int = 0
var _events: Array[Dictionary] = []
var _outcomes: Array[Dictionary] = []
var _windows: Array[Dictionary] = []
var _artifacts: Array[Dictionary] = []


func _ready() -> void:
	process_physics_priority = 1000
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pool-controller-mode="):
			_mode = arg.trim_prefix("--pool-controller-mode=")
		if arg.begins_with("--pool-controller-report-dir="):
			_folder = arg.trim_prefix("--pool-controller-report-dir=")
	if (
		_mode not in ["baseline", "shadow"]
		or _folder.is_empty()
		or DirAccess.dir_exists_absolute(_folder)
	):
		push_error("Explicit baseline/shadow mode and nonexistent fresh report directory required")
		_phase = Phase.DONE
		get_tree().quit(1)
		return
	_check(DirAccess.make_dir_recursive_absolute(_folder) == OK, "fresh report directory")
	_check(Engine.physics_ticks_per_second == 60, "unchanged ordinary 60Hz physics")
	_check(Engine.time_scale == 1.0, "unchanged ordinary time scale")
	_check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "Jolt")
	# Both modes load the same scripts and allocate one adapter and one ordinary lab tree.
	# Existing display preferences are outside this fixed, headless evidence fixture.
	PitchBatLabSettings.path = "user://pool-controller-unwritten-display-settings.cfg"
	_check(not FileAccess.file_exists(PitchBatLabSettings.path), "no persisted fixture settings")
	seed(704716)
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	_history_source = FileAccess.get_sha256(get_script().resource_path)


func _physics_process(delta: float) -> void:
	match _phase:
		Phase.DRAIN:
			_wait_ticks -= 1
			if _wait_ticks <= 0:
				_phase = Phase.PREPARE if _ordinal < ROLES.size() * cases().size() else Phase.DONE
				if _phase == Phase.DONE:
					_complete()
		Phase.PREPARE:
			_prepare()
		Phase.SETTLE:
			_wait_ticks -= 1
			if _wait_ticks <= 0:
				_phase = Phase.LAUNCH
		Phase.LAUNCH:
			_launch()
		Phase.PLAY:
			_sample += 1
			_append("tick.after", {"delta": delta})
			if _sample == SAMPLES:
				_finish_window()


func _prepare() -> void:
	var rows: Array[Dictionary] = cases()
	_role = ROLES[floori(float(_ordinal) / rows.size())]
	_case = rows[_ordinal % rows.size()]
	_sample = 0
	_ready_count = 0
	_launch_count = 0
	_events.clear()
	_outcomes.clear()
	_ball = null
	_shadow = StadiumPoolControllerShadow.new()
	# The baseline must stay the exact original class, not an observer subclass.
	_lab = PitchBatLab.new() if _mode == "baseline" else SHADOW_LAB.new()
	_lab.name = "OrdinaryPitchBatLab"
	_lab._match_mode = false
	add_child(_lab)
	_lab._match_mode = false
	_lab.set_process(false)
	# The genuine primary physics and all ordinary attempts remain enabled.
	_lab._base_state.set_debug_preset(2)
	_lab.child_entered_tree.connect(_on_lab_child)
	_model = StadiumPoolWaterTestSupport.model(self, _role)
	_check(_lab._primary_fielder.is_physics_processing(), "ordinary primary physics enabled")
	_check(_lab.is_physics_processing(), "ordinary controller physics enabled")
	_check(not _lab.has_meta("stadium_property"), "genuine plain lab, no property runtime")
	_check(_shadow.prepare(_lab, _model, _role, _source), "symmetric model preparation")
	if _mode == "shadow":
		_lab.set("pool_shadow", _shadow)
		_check(_shadow.install(_lab, _model, _role, _source), "shadow installed before launch")
	_wait_ticks = 2
	_phase = Phase.SETTLE


func _launch() -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = _case.position
	launch.velocity = _case.velocity
	launch.angular_velocity = Vector3.ZERO
	launch.orientation = Quaternion.IDENTITY
	_launch_frame = Engine.get_physics_frames()
	_recording = true
	_append("launch.call.before", {"requested_velocity": launch.velocity})
	_lab._start_ball_in_play(launch)
	_append("launch.call.after", {"requested_velocity": launch.velocity})
	_check(_ready_count == 1 and _launch_count == 1, "fresh body ready and ordinary launch once")
	_check(_ball == _lab._batted_ball, "watcher bound the genuine newly launched body")
	_phase = Phase.PLAY


func _on_lab_child(child: Node) -> void:
	if child is not BattedBallBody:
		return
	_check(_ball == null, "one fresh ordinary body per window")
	_ball = child as BattedBallBody
	_append("child.entered", {"started": _ball._started, "ready": _ball.is_node_ready()})
	_ball.ready.connect(_on_ball_ready, CONNECT_ONE_SHOT)


func _on_ball_ready() -> void:
	_ready_count += 1
	# _cleanup_batted_ball resets the pitcher. This is a declared initial-pose setup
	# after cleanup, before launch, common to both modes; never a live teleport.
	if _case.has("pitcher_start"):
		_lab._pitcher_marker.global_position = _case.pitcher_start
	_ball.launch_started.connect(_on_launch)
	_ball.surface_contact.connect(_on_surface)
	_lab._ball_play_resolver.play_resolved.connect(_on_outcome)
	_append("body.ready", {"started": _ball._started, "sphere_children": _sphere_count()})
	_check(not _ball._started and not _ball.freeze, "fresh unstarted unfrozen body at ready")
	_check(_sphere_count() == 1, "ordinary ready created the real sphere")


func _on_launch(position: Vector3) -> void:
	_launch_count += 1
	_append("launch.signal", {"position": position})


func _on_surface(surface: StringName, position: Vector3) -> void:
	_append("surface", {"kind": String(surface), "position": position})


func _on_outcome(outcome: BallPlayOutcome) -> void:
	var detail: Dictionary = {
		"result": int(outcome.result),
		"reason": String(outcome.reason),
		"position": outcome.resolution_position,
		"caught": outcome.caught
	}
	_outcomes.append(detail)
	_append("outcome", detail)


func _append(event: String, detail: Dictionary) -> void:
	if not _recording:
		return
	_events.append(
		{
			"seq": _events.size() + 1,
			"event": event,
			"tick": Engine.get_physics_frames() - _launch_frame,
			"sample": _sample,
			"body": _body_snapshot(),
			"pitcher": _pitcher_snapshot(),
			"primary": _primary_snapshot(),
			"controller": _controller_snapshot(),
			"state": _state_snapshot(),
			"bases": _base_snapshot(),
			"detail": detail
		}
	)


func _state_snapshot() -> Dictionary:
	if _lab._ball_play_resolver.state == null:
		return {}
	return StadiumPoolWaterTestSupport.state_snapshot(_lab._ball_play_resolver.state)


func _body_snapshot() -> Dictionary:
	if not is_instance_valid(_ball):
		return {"present": false}
	var pose: Transform3D = _ball.global_transform
	return {
		"present": true,
		"center": pose.origin,
		"basis": [pose.basis.x, pose.basis.y, pose.basis.z],
		"velocity": _ball.linear_velocity,
		"angular_velocity": _ball.angular_velocity,
		"freeze": _ball.freeze,
		"sleeping": _ball.sleeping,
		"started": _ball._started,
		"mass": _ball.mass,
		"radius": _physical_radius(),
		"authored_radius": _ball.radius_m,
		"sphere_count": _sphere_count(),
		"pool_witness":
		StadiumPoolInteriorV2.sample_local(pose.origin - Vector3(12, 0, 18), _physical_radius())
	}


func _pitcher_snapshot() -> Dictionary:
	return {
		"position": _lab._pitcher_marker.global_position,
		"rotation": _lab._pitcher_marker.rotation,
		"attempted": _lab._pitcher_attempted
	}


func _primary_snapshot() -> Dictionary:
	var primary: FielderController = _lab._primary_fielder
	return {
		"position": primary.global_position,
		"velocity": primary.velocity,
		"anchor": primary.anchor_position,
		"target": primary.target_position,
		"active": primary.active,
		"stationary": primary.stationary,
		"first_step": primary.first_step,
		"play_elapsed": primary._play_elapsed_seconds,
		"reaction_delay": primary.reaction_delay_seconds,
		"reaction_margin": primary.last_reaction_margin_seconds,
		"physics_enabled": primary.is_physics_processing(),
		"attempts": _lab._primary_attempts
	}


func _controller_snapshot() -> Dictionary:
	return {
		"previous": _lab._previous_batted_position,
		"cooldown": _lab._fielding_cooldown_seconds,
		"settled": _lab._settled_seconds,
		"fielding_text": _lab._last_fielding_text,
		"match_mode": _lab._match_mode,
		"paused": _lab._debug_paused,
		"physics_enabled": _lab.is_physics_processing(),
		"pitch_running": _lab._pitch_actor.running
	}


func _base_snapshot() -> Dictionary:
	return {
		"first": String(_lab._base_state.first),
		"second": String(_lab._base_state.second),
		"third": String(_lab._base_state.third)
	}


func _physical_radius() -> float:
	for child: Node in _ball.get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D:
			return child.shape.radius
	return 0.0


func _sphere_count() -> int:
	var count: int = 0
	for child: Node in _ball.get_children():
		if child is CollisionShape3D and child.shape is SphereShape3D:
			count += 1
	return count


func _coverage() -> Dictionary:
	var ticks: Array[Dictionary] = []
	var launch: Dictionary = {}
	var previous: Dictionary = {}
	var pursuit_ticks: Array[int] = []
	var actor_moved: bool = false
	var primary_moved: bool = false
	var wet_ticks: Array[int] = []
	var surface_kinds: Array[String] = []
	var fielding_texts: Array[String] = []
	for row: Dictionary in _events:
		if row.event == "launch.call.after":
			launch = row
			previous = row
		if row.event == "surface":
			surface_kinds.append(row.detail.kind)
		if row.event != "tick.after":
			continue
		ticks.append(row)
		actor_moved = actor_moved or row.pitcher.position != launch.pitcher.position
		primary_moved = primary_moved or row.primary.position != launch.primary.position
		# Excludes attempt-tick presentation movement; only still-live, pre-attempt
		# displacement is called observed ordinary pursuit here.
		if (
			not previous.pitcher.attempted
			and not row.pitcher.attempted
			and not previous.state.dead
			and not row.state.dead
			and row.pitcher.position != previous.pitcher.position
		):
			pursuit_ticks.append(row.tick)
		if row.body.pool_witness.positive_overlap:
			wet_ticks.append(row.tick)
		if row.controller.fielding_text not in fielding_texts:
			fielding_texts.append(row.controller.fielding_text)
		previous = row
	var first: Dictionary = ticks[0]
	var displacement: Vector3 = first.body.center - launch.body.center
	return {
		"sample_count": ticks.size(),
		"first_displacement": displacement,
		"nonzero_directional_launch": displacement.dot(_case.velocity) > 0.0,
		"actor_moved": actor_moved,
		"primary_moved": primary_moved,
		"pre_attempt_pursuit_ticks": pursuit_ticks,
		"current_wet_ticks": wet_ticks,
		"wet_observation_is_hypothetical_without_live_pool": _role != StadiumPoolContract.LIVE,
		"surface_kinds": surface_kinds,
		"fielding_texts": fielding_texts,
		"outcomes": _outcomes.duplicate(true),
		"terminal_observed": not _outcomes.is_empty(),
		"unresolved_at_budget": not previous.state.dead,
		"final_freeze": previous.body.freeze,
		"final_bases": previous.bases,
		"all_defense_enabled": true
	}


func _finish_window() -> void:
	# Stop observing at exactly the requested budget, before teardown.
	_recording = false
	var coverage: Dictionary = _coverage()
	_validate_window(coverage)
	var canonical: Dictionary = {"id": _id(), "events": _events.duplicate(true)}
	_windows.append(canonical)
	_save(
		_id(),
		{
			"schema": SCHEMA,
			"mode": _mode,
			"source": _source,
			"history_source_sha256": _history_source,
			"role": _role,
			"case": _case,
			"setup": SETUP,
			"events": _events.duplicate(true),
			"coverage": coverage,
			"canonical": canonical,
			"canonical_sha256": _digest(var_to_bytes(canonical)),
			"actual_lab_script": _lab.get_script().resource_path,
			"actual_ball_script": _ball.get_script().resource_path,
			"shadow_records": _shadow.records.duplicate(true),
			"guard_records": _shadow.guard.records.duplicate(true) if _shadow.guard != null else [],
			"guard_unsupported":
			_shadow.guard.unsupported.duplicate(true) if _shadow.guard != null else [],
			"guard_errors": _shadow.guard.errors.duplicate() if _shadow.guard != null else [],
			"guard_receipts":
			_shadow.guard.receipts.duplicate(true) if _shadow.guard != null else [],
			"unsupported": _shadow.unsupported.duplicate(true),
			"shadow_errors": _shadow.errors.duplicate(),
			"water_receipts": _shadow.receipts.duplicate(true),
			"active_awards_enabled": false,
			"ordinary_controller_qualified": false,
			"positioned_initial_pitcher": _case.has("pitcher_start"),
			"dry_to_dry_completeness_qualified": false
		}
	)
	_shadow.detach()
	if _lab.child_entered_tree.is_connected(_on_lab_child):
		_lab.child_entered_tree.disconnect(_on_lab_child)
	_lab.queue_free()
	if _model != null:
		_model.queue_free()
	_lab = null
	_model = null
	_ball = null
	_shadow = null
	_ordinal += 1
	_wait_ticks = 2
	_phase = Phase.DRAIN


func _validate_window(coverage: Dictionary) -> void:
	_check(_events.size() > SAMPLES, "callbacks plus full tick budget")
	var lifecycle: Array[String] = []
	var signal_row: Dictionary = {}
	var after_row: Dictionary = {}
	var samples: Array[int] = []
	for row: Dictionary in _events:
		if row.event != "tick.after" and row.tick == 0:
			lifecycle.append(row.event)
		if row.event == "launch.signal":
			signal_row = row
		if row.event == "launch.call.after":
			after_row = row
		if row.event == "tick.after":
			samples.append(row.sample)
			_check(row.tick == row.sample, "one complete late snapshot per physics tick")
		_check(
			row.primary.physics_enabled and row.controller.physics_enabled, "defense kept enabled"
		)
	_check(
		(
			lifecycle
			== [
				"launch.call.before",
				"child.entered",
				"body.ready",
				"launch.signal",
				"launch.call.after"
			]
		),
		"genuine child-ready-launch sequence"
	)
	_check(samples == range(1, SAMPLES + 1), "180 complete ordered physics snapshots")
	_check(signal_row.body.velocity == _case.velocity, "exact requested velocity at public signal")
	_check(after_row.body.velocity == _case.velocity, "exact requested velocity after launch")
	_check(after_row.controller.previous == _case.position, "ordinary launch seeds history")
	_check(after_row.primary.active, "ordinary launch begins primary play")
	_check(
		coverage.nonzero_directional_launch, "actual nonzero directional first-step displacement"
	)
	if _case.get("require_pursuit", false):
		_check(
			not coverage.pre_attempt_pursuit_ticks.is_empty(), "genuine nonzero pre-attempt pursuit"
		)
	if _case.get("require_wet", false):
		_check(not coverage.current_wet_ticks.is_empty(), "observed current wet geometric witness")
	if _case.get("require_dry", false):
		_check(coverage.current_wet_ticks.is_empty(), "full dry geometric witness")
	_check(_outcomes.size() <= 1, "at most one genuine terminal outcome")
	for outcome: Dictionary in _outcomes:
		_check(not outcome.reason.begins_with("private_pool_water_"), "no active water outcome")
	_check(_shadow.receipts.is_empty(), "no active water receipts")
	if _shadow.guard != null:
		_check(_shadow.guard.receipts.is_empty(), "no underlying guard water receipts")
		_check(_shadow.guard.errors.is_empty(), "no underlying guard integrity errors")
	_check(_shadow.errors.is_empty(), "no shadow integrity errors")
	_check(StadiumPoolPartyAssetIntegrity.source_sha256() == _source, "runtime source unchanged")


func _complete() -> void:
	_save(
		"trajectory",
		{
			"schema": "POOL-CONTROLLER-TRAJECTORY-v1",
			"source": _source,
			"history_source_sha256": _history_source,
			"windows": _windows
		}
	)
	_check(_windows.size() == ROLES.size() * cases().size(), "complete exact window matrix")
	_save(
		"index",
		{
			"schema": "POOL-CONTROLLER-HISTORY-INDEX-v1",
			"source": _source,
			"history_source_sha256": _history_source,
			"mode": _mode,
			"checks": _checks,
			"failures": _failures,
			"windows": _windows.size(),
			"samples_per_window": SAMPLES,
			"artifacts": _artifacts.duplicate(true),
			"active_awards_enabled": false,
			"ordinary_controller_qualified": false,
			"dry_to_dry_completeness_qualified": false
		}
	)
	print("POOL_CONTROLLER_INDEX ", JSON.stringify(_artifacts[-1], "", true, true))
	print(
		(
			"POOL_CONTROLLER_HISTORY checks=%d failures=%d windows=%d bytes=%d source=%s"
			% [_checks, _failures, _windows.size(), _total, _source]
		)
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _save(id: String, packet: Dictionary) -> void:
	var typed: PackedByteArray = var_to_bytes(packet)
	var readable: PackedByteArray = (
		(JSON.stringify(ENCODER._json_value(packet), "", true, true) + "\n").to_utf8_buffer()
	)
	_check(_total + typed.size() + readable.size() <= MAX_BYTES, "bounded complete report")
	if _total + typed.size() + readable.size() > MAX_BYTES:
		return
	var row: Dictionary = {"id": id}
	for kind: String in ["typed", "json"]:
		var extension: String = ".var" if kind == "typed" else ".json"
		var path: String = _folder.path_join(id + extension)
		_check(not FileAccess.file_exists(path), "never overwrite evidence")
		if FileAccess.file_exists(path):
			return
		var bytes: PackedByteArray = typed if kind == "typed" else readable
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			_check(false, "artifact file opened")
			return
		file.store_buffer(bytes)
		file.close()
		_check(FileAccess.get_file_as_bytes(path) == bytes, "complete bytes persisted")
		row[kind + "_file"] = id + extension
		row[kind + "_bytes"] = bytes.size()
		row[kind + "_sha256"] = FileAccess.get_sha256(path)
		_total += bytes.size()
	_check(var_to_bytes(bytes_to_var(typed)) == typed, "exact typed roundtrip")
	_artifacts.append(row)


func _id() -> String:
	var prefix: String = (
		"live"
		if _role == StadiumPoolContract.LIVE
		else ("scenery" if _role == StadiumPoolContract.SCENERY else "no_pool")
	)
	return prefix + "-" + _case.id


static func _digest(bytes: PackedByteArray) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


static func cases() -> Array[Dictionary]:
	return [
		{
			"id": "nearby_air_catch",
			"position": Vector3(2, 2.5, 12.5),
			"velocity": Vector3(-0.7, -0.2, 1),
			"require_pursuit": true,
			"scenario": "physical_ball_test nearby air catch; primary remains enabled"
		},
		{
			"id": "charging_grounder",
			"position": Vector3(0, 0.04, 9),
			"velocity": Vector3(0, 0, 1),
			"require_pursuit": true,
			"scenario": "physical_ball_test charge before Single; primary remains enabled"
		},
		{
			"id": "pitcher_bobble",
			"position": Vector3(0.45, 0.04, 9.8),
			"velocity": Vector3(0, 0, 16),
			"scenario": "physical_ball_test bobble input; actual ordinary outcome recorded"
		},
		{
			"id": "pitcher_miss",
			"position": Vector3(0.45, 0.04, 9.8),
			"velocity": Vector3(0, 0, 30),
			"scenario": "physical_ball_test miss input; actual ordinary outcome recorded"
		},
		{
			"id": "near_pool_wet",
			"position": Vector3(12, 2.2, 18),
			"velocity": Vector3(0, -4, 0),
			"require_wet": true,
			"scenario": "current wet witness at fixed approved pool site; awards disabled"
		},
		{
			"id": "near_pool_dry",
			"position": Vector3(9.3, 1.8, 18),
			"velocity": Vector3(0, -4, 0),
			"require_dry": true,
			"scenario": "outside full pool radius; no water or terminal assumption"
		},
		{
			"id": "terminal_wall",
			"position": Vector3(3, 2, 21),
			"velocity": Vector3(0, 0, 15),
			"scenario": "physical_ball_test wall-on-fly input; actual wall and result recorded"
		},
		{
			"id": "far_start_separation",
			"position": Vector3(12, 2.2, 18),
			"velocity": Vector3(0, -4, 0),
			"pitcher_start": Vector3(24, 0, 13.716),
			"require_wet": true,
			"scenario": "positioned finite actor outside mound radius; no live teleport"
		}
	]


func _check(value: bool, label: String) -> void:
	_checks += 1
	if not value:
		_failures += 1
		push_error(label)

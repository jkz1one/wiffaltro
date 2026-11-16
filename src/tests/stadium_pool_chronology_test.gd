extends Node3D
## Actual 60 Hz ordinary-hook observation. Positioned rig/direct-rule probes are not game proof.

const REPORT_SCHEMA: String = "POOL-CHRONOLOGY-RIG-v3-TELEMETRY"
const MAX_REPORT_BYTES: int = 64 * 1024 * 1024
const WINDOW_SAMPLES: int = 24
const MODES: Array[String] = ["live_geometry", "scenery", "no_pool"]
var _failures: int = 0
var _checks: int = 0
var _observer: StadiumPoolChronologyObserver
var _report_dir: String = ""
var _bytes_written: int = 0
var _artifacts: Array[Dictionary] = []
var _ground: StaticBody3D
var _active: bool = false
var _source: String = ""
var _observation_mode: String = "baseline"
var _trajectory: Array[Dictionary] = []


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--pool-observation-mode="):
			_observation_mode = argument.trim_prefix("--pool-observation-mode=")
		if argument.begins_with("--chronology-report-dir="):
			_report_dir = argument.trim_prefix("--chronology-report-dir=")
	if _observation_mode not in ["baseline", "telemetry"]:
		push_error("Explicit --pool-observation-mode=baseline or telemetry is required")
		get_tree().quit(1)
		return
	if _report_dir.is_empty():
		push_error(
			"Durable --chronology-report-dir is required; no observations discarded to a temp stage"
		)
		get_tree().quit(1)
		return
	if DirAccess.dir_exists_absolute(_report_dir):
		var existing: DirAccess = DirAccess.open(_report_dir)
		if (
			existing == null
			or not existing.get_files().is_empty()
			or not existing.get_directories().is_empty()
		):
			push_error(
				"Observation directory must be fresh/empty; existing evidence is never overwritten"
			)
			get_tree().quit(1)
			return
	_check(Engine.physics_ticks_per_second == 60, "unchanged ordinary 60 Hz physics")
	_check(
		DirAccess.make_dir_recursive_absolute(_report_dir) == OK, "durable observation directory"
	)
	for case: Dictionary in cases():
		_check(
			not _launch_displacement_retained(Vector3(0, -0.00272226333618164, 0), case.velocity),
			"archived gravity-only first step cannot pass launch motion gate " + case.id
		)
	_source = StadiumPoolPartyAssetIntegrity.source_sha256()
	_check(_source.length() == 64, "computed current src/project source identity")
	_make_ground()
	await get_tree().physics_frame
	await get_tree().physics_frame
	for mode: String in MODES:
		var model: Node3D = _make_model(mode)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if model != null:
			var setup: BallSetupDefinition = ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID)
			var geometry: Dictionary = StadiumPoolChronologyGeometry.measure(
				self, model, _ground, setup.aero_profile.radius_m
			)
			_check(geometry.errors.is_empty(), "actual facet/physical-sphere measurements " + mode)
			_check(geometry.rows.size() == 256, "all 128 facet vertices and midpoints " + mode)
			_save_packet(mode + "-facet-geometry", geometry)
		for case: Dictionary in cases():
			await _run_case(mode, model, case)
		if model != null:
			model.queue_free()
		await get_tree().physics_frame
		await get_tree().physics_frame
	_ground.queue_free()
	await get_tree().physics_frame
	await get_tree().process_frame
	_save_packet(
		"trajectory",
		{
			"schema": "POOL-CANONICAL-ORDINARY-TRAJECTORY-v1",
			"source_src_project_integrity": _source,
			"windows": _trajectory
		}
	)
	_check(
		_artifacts.size() == MODES.size() * cases().size() + 3,
		"every window and both geometry packets retained"
	)
	var index: Dictionary = {
		"schema": REPORT_SCHEMA,
		"observation_mode": _observation_mode,
		"direct_state_telemetry_requested": _observation_mode == "telemetry",
		"source_src_project_integrity": _source,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"modes": MODES,
		"cases_per_mode": cases().size(),
		"window_samples": WINDOW_SAMPLES,
		"artifacts": _artifacts.duplicate(true),
		"checks_at_index_snapshot": _checks,
		"failures": _failures,
		"observed_scope":
		(
			"POSITIONED_TELEMETRY_SUBCLASS_WITH_SINGLE_ORDINARY_SUPER_CALL_AND_DIRECT_RULE_PROBES"
			if _observation_mode == "telemetry"
			else "POSITIONED_UNMODIFIED_BATTEDBALLBODY_AND_DIRECT_RULE_TIMING_PROBES"
		),
		"ordinary_lab_or_game_qualified": false,
		"default_resolver_segment_logic_bypassed": true,
		"node_property_samples_not_direct_physics_state": true,
		"water_awards_implemented": false,
		"within_step_reflected_path_or_earliest_entry_qualified": false,
		"expected_limitation": "Ordinary callback payload has no TOI or reflected subsegment trace"
	}
	_save_packet("index", index)
	if not _artifacts.is_empty() and _artifacts[-1].id == "index":
		print("POOL_CHRONOLOGY_INDEX ", JSON.stringify(_artifacts[-1], "", true, true))
	print(
		(
			"POOL_CHRONOLOGY_OBSERVATION checks=%d failures=%d windows=%d bytes=%d source=%s"
			% [_checks, _failures, MODES.size() * cases().size(), _bytes_written, _source]
		)
	)
	print(
		"OBSERVATION ONLY: no water arbiter, ordinary-controller/game or within-step order qualification."
	)
	get_tree().quit(0 if _failures == 0 else 1)


func _physics_process(delta: float) -> void:
	if _active and _observer != null:
		_observer.tick(delta)


func _run_case(mode: String, model: Node3D, case: Dictionary) -> void:
	# Match the ordinary lab/history lifecycle: one fresh live body in a pre-physics phase.
	await get_tree().physics_frame
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	# Both scripts are parsed in every process; physical node creation order is identical.
	var ball: BattedBallBody = (
		StadiumPoolTelemetryBody.new() if _observation_mode == "telemetry" else BattedBallBody.new()
	)
	ball.name = "ActualUnmodifiedBattedBall"
	ball.configure_aero(ContentDB.get_ball_setup(PitchBatLab.BALL_SETUP_ID))
	ball.position = StadiumPoolContract.placement() * case.local_position
	add_child(ball)
	_check(not ball.freeze, "new body is live before public launch")
	_check(
		(
			ball.get_script()
			== (
				preload("res://src/tests/stadium_pool_telemetry_body.gd")
				if _observation_mode == "telemetry"
				else preload("res://src/presentation/ball/batted_ball_body.gd")
			)
		),
		"exact selected untouched or telemetry-only ball source"
	)
	_check(
		not ball.custom_integrator and ball.continuous_cd and ball.max_contacts_reported == 8,
		"ordinary Jolt integration and CCD"
	)
	_check(
		is_equal_approx(ball.radius_m, 0.0365) and is_equal_approx(ball.mass, 0.020),
		"unchanged configured physical radius and mass"
	)
	_check(
		(
			is_equal_approx(ball.physics_material_override.bounce, 0.52)
			and is_equal_approx(ball.physics_material_override.friction, 0.42)
		),
		"ordinary rigid response"
	)
	_observer = StadiumPoolChronologyObserver.new()
	var bound: bool = _observer.bind(ball, resolver, model, _ground, mode, case, _observation_mode)
	_check(bound, "strict source/model/instance binding " + mode + ":" + case.id)
	if not bound:
		ball.queue_free()
		_observer = null
		return
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = ball.global_position
	launch.velocity = case.velocity
	launch.angular_velocity = Vector3.ZERO
	launch.orientation = Quaternion.IDENTITY
	_active = true
	_observer.append(
		"rig.public_launch.before",
		{"requested_velocity": launch.velocity, "lifecycle": "FRESH_NEVER_FROZEN_SAME_PHASE"}
	)
	ball.launch(launch)
	_observer.append("rig.public_launch.after", {"requested_velocity": launch.velocity})
	while _observer.sample_index < WINDOW_SAMPLES:
		await get_tree().physics_frame
	_active = false
	var packet: Dictionary = _observer.finish()
	_check(packet.frozen_sources_intact, "frozen ball/model/resolver source remains exact")
	_check(packet.errors.is_empty(), "complete bound observation window " + mode + ":" + case.id)
	_check(packet.events.size() >= WINDOW_SAMPLES * 2, "all sample callbacks retained")
	_check(packet.source_src_project_integrity == _source, "source unchanged through observation")
	_validate_events(packet)
	_validate_launch(packet)
	_validate_telemetry(packet)
	_trajectory.append(_canonical_trajectory(packet))
	_save_packet(mode + "-" + String(case.id), packet)
	ball.queue_free()
	_observer = null
	await get_tree().physics_frame
	await get_tree().physics_frame


func _validate_events(packet: Dictionary) -> void:
	var sequence: int = 0
	var previous_frame: int = -1
	var router_calls: int = 0
	var observer_calls: int = 0
	var before_samples: Array[int] = []
	var after_samples: Array[int] = []
	var launch_calls: int = 0
	var probe_before: int = 0
	var probe_after: int = 0
	for row: Dictionary in packet.events:
		_check(row.seq == sequence + 1, "no lost/reordered callback sequence")
		_check(row.physics_frame >= previous_frame, "monotonic actual physics-frame observations")
		_check(
			row.center.is_finite() and row.velocity.is_finite(),
			"finite measured centers/velocities"
		)
		sequence = row.seq
		previous_frame = row.physics_frame
		if row.event == "BattedBallBody.launch_started":
			launch_calls += 1
		if row.event not in ["binding", "rig.public_launch.before"]:
			_check(row.launch_generation == 1, "one actual launch generation per window")
		if row.event == "rig.physics_process.before":
			before_samples.append(int(row.sample_index))
		if row.event == "rig.physics_process.after":
			after_samples.append(int(row.sample_index))
		if row.event == "direct_rule_control_probe.before":
			probe_before += 1
			_check(
				row.sample_index == 1 and row.detail.synthetic_probe,
				"explicitly scheduled direct-rule control probe"
			)
		if row.event == "direct_rule_control_probe.after":
			probe_after += 1
		if row.event == "BattedBallBody.physics_contact_router":
			router_calls += 1
		if row.event == "BallPlayResolver.segment_observer":
			observer_calls += 1
		if row.event == "BallPlayResolver.play_resolved":
			_check(
				row.detail.reason not in ["pool_water", "water_double"],
				"no water award implementation"
			)
	var expected_samples: Array[int] = []
	for index: int in range(WINDOW_SAMPLES):
		expected_samples.append(index)
	_check(
		before_samples == expected_samples and after_samples == expected_samples,
		"all exact 24 physics-process before/after sample pairs"
	)
	_check(launch_calls == 1, "one actual launch signal")
	var expected_probes: int = 0 if packet.case.probe_slot == "none" else 1
	_check(
		probe_before == expected_probes and probe_after == expected_probes,
		"exact expected direct-probe pair count"
	)
	var expected_observers: int = (
		WINDOW_SAMPLES
		if expected_probes == 0
		else (1 if packet.case.probe_slot == "before_observer" else 2)
	)
	_check(
		observer_calls == expected_observers, "resolver hook honors ordinary post-terminal guard"
	)
	_check(
		router_calls > 0 and observer_calls > 0, "real ordinary router and resolver hooks exercised"
	)


func _validate_launch(packet: Dictionary) -> void:
	var before: Dictionary = {}
	var launched: Dictionary = {}
	var after: Dictionary = {}
	var first: Dictionary = {}
	for row: Dictionary in packet.events:
		match row.event:
			"rig.public_launch.before":
				before = row
			"BattedBallBody.launch_started":
				launched = row
			"rig.public_launch.after":
				after = row
			"BattedBallBody.physics_contact_router":
				if first.is_empty():
					first = row
	if before.is_empty() or launched.is_empty() or after.is_empty() or first.is_empty():
		_check(false, "complete pre/public/post/first-physics launch evidence")
		return
	var requested: Vector3 = packet.case.velocity
	_check(
		(
			not before.freeze
			and before.velocity == Vector3.ZERO
			and before.seq + 1 == launched.seq
			and launched.seq + 1 == after.seq
			and before.physics_frame == launched.physics_frame
			and after.physics_frame == launched.physics_frame
			and launched.velocity == requested
			and after.velocity == requested
			and not after.freeze
		),
		"one fresh public launch preserves requested node velocity in its actual phase"
	)
	_check(
		first.physics_frame == launched.physics_frame + 1 and first.sample_index == 1,
		"first physics sample retained on the very next tick, never skipped or relabeled"
	)
	var displacement: Vector3 = first.center - launched.center
	var collision_free_first_step: bool = (
		packet.mode == "no_pool"
		and (
			launched.center.y + minf(requested.y, 0) / 60.0 - 9.8 / 3600.0
			> float(launched.physical_radius) + 0.01
		)
	)
	var motion_retained: bool = _launch_displacement_retained(displacement, requested)
	var velocity_retained: bool = (
		first.velocity.length() > requested.length() * 0.5
		and first.velocity.distance_to(requested) < maxf(1.0, requested.length() * 0.2)
	)
	packet.launch_assessment = {
		"requested_velocity": requested,
		"first_displacement": displacement,
		"first_router_velocity": first.velocity,
		"first_router_contact_count": first.detail.reported_contact_count,
		"collision_free_first_step": collision_free_first_step,
		"directional_motion_retained": motion_retained,
		"velocity_retained_with_gravity_aero_allowance": velocity_retained,
		"no_pool_motion_gate_applied": packet.mode == "no_pool",
		"postcollision_velocity_is_not_required_to_equal_launch": true
	}
	if packet.mode == "no_pool":
		_check(
			motion_retained,
			"no-pool first-step displacement proves launch motion " + packet.case.id
		)
	if collision_free_first_step:
		_check(velocity_retained, "collision-free first physics velocity retains public launch")


static func _launch_displacement_retained(displacement: Vector3, requested: Vector3) -> bool:
	# Authored instrumentation thresholds reject the recorded gravity-only launch defect.
	var step_distance: float = requested.length() / 60.0
	return (
		step_distance > 0
		and displacement.dot(requested.normalized()) > step_distance * 0.25
		and displacement.length() < step_distance * 1.25 + 0.01
	)


func _make_ground() -> void:
	_ground = StaticBody3D.new()
	_ground.name = "InstrumentationGround"
	_ground.position = Vector3(0, -0.08, 12)
	_ground.collision_layer = 1
	_ground.collision_mask = 2
	_ground.set_meta("ball_surface", &"ground")
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(64, 0.16, 54)
	shape.shape.margin = 0
	_ground.add_child(shape)
	add_child(_ground)


func _make_model(mode: String) -> Node3D:
	if mode == "no_pool":
		return null
	var role: String = (
		StadiumPoolContract.LIVE if mode == "live_geometry" else StadiumPoolContract.SCENERY
	)
	var model: Node3D = StadiumPoolModels.create(role)
	model.transform = StadiumPoolContract.placement()
	add_child(model)
	_check(
		StadiumPoolContract.valid_binding(
			model, role, StadiumPoolContract.placement(), StadiumPoolContract.geometry(role)
		),
		"unchanged exact qualified model " + mode
	)
	return model


func _save_packet(id: String, packet: Dictionary) -> void:
	var typed: PackedByteArray = var_to_bytes(packet)
	var json_text: String = JSON.stringify(_json_value(packet), "", true, true) + "\n"
	var readable: PackedByteArray = json_text.to_utf8_buffer()
	if _bytes_written + typed.size() + readable.size() > MAX_REPORT_BYTES:
		_check(false, "evidence cap exceeded; complete packets are never silently truncated")
		return
	var typed_path: String = _report_dir.path_join(id + ".var")
	var json_path: String = _report_dir.path_join(id + ".json")
	if FileAccess.file_exists(typed_path) or FileAccess.file_exists(json_path):
		_check(false, "existing observation artifacts are never overwritten")
		return
	var typed_file: FileAccess = FileAccess.open(typed_path, FileAccess.WRITE)
	var json_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	if typed_file == null or json_file == null:
		_check(false, "durable observation packet files opened")
		return
	typed_file.store_buffer(typed)
	json_file.store_buffer(readable)
	typed_file.close()
	json_file.close()
	var stored: PackedByteArray = FileAccess.get_file_as_bytes(typed_path)
	_check(
		stored == typed and var_to_bytes(bytes_to_var(stored)) == typed,
		"full typed observation packet round trips exactly"
	)
	_check(FileAccess.get_file_as_bytes(json_path) == readable, "readable packet bytes retained")
	_bytes_written += typed.size() + readable.size()
	_artifacts.append(
		{
			"id": id,
			"typed_file": id + ".var",
			"typed_bytes": typed.size(),
			"typed_sha256": FileAccess.get_sha256(typed_path),
			"json_file": id + ".json",
			"json_bytes": readable.size(),
			"json_sha256": FileAccess.get_sha256(json_path)
		}
	)


static func _json_value(value: Variant) -> Variant:
	if value is Vector3:
		return {"type": "Vector3", "value": [value.x, value.y, value.z]}
	if value is Vector2:
		return {"type": "Vector2", "value": [value.x, value.y]}
	if value is Transform3D:
		return {
			"type": "Transform3D",
			"origin": _json_value(value.origin),
			"basis":
			[_json_value(value.basis.x), _json_value(value.basis.y), _json_value(value.basis.z)]
		}
	if value is AABB:
		return {
			"type": "AABB", "position": _json_value(value.position), "size": _json_value(value.size)
		}
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[String(key)] = _json_value(value[key])
		return result
	if value is Array or value is PackedFloat32Array or value is PackedStringArray:
		var result: Array = []
		for element: Variant in value:
			result.append(_json_value(element))
		return result
	return value


static func cases() -> Array[Dictionary]:
	var rows: Array[Dictionary] = [
		{"id": "clean_lob", "local_position": Vector3(0, 2.2, 0), "velocity": Vector3(0, -4, 0)},
		{
			"id": "outer_wall_low",
			"local_position": Vector3(0, 0.5, 3),
			"velocity": Vector3(0, 0, -12)
		},
		{
			"id": "rim_outer_inward",
			"local_position": Vector3(0, 1.8, 2.3),
			"velocity": Vector3(0, -6, -4)
		},
		{
			"id": "rim_inner_outward",
			"local_position": Vector3(0, 1.65, 1.7),
			"velocity": Vector3(0, -4, 3)
		},
		{
			"id": "wall_at_surface",
			"local_position": Vector3(0, 1.05, 2.3),
			"velocity": Vector3(0, 0, -12)
		},
		{
			"id": "inner_wall_near_water_fast",
			"local_position": Vector3(0, 1.092, 1.90),
			"velocity": Vector3(0, -3, 10)
		},
		{
			"id": "inner_wall_near_water_slow",
			"local_position": Vector3(0, 1.12, 1.90),
			"velocity": Vector3(0, -0.3, 5)
		},
		{
			"id": "water_ground_fast",
			"local_position": Vector3(0, 1.5, 0),
			"velocity": Vector3(0, -120, 0)
		}
	]
	var direction: Vector3 = Vector3(cos(PI / 128), 0, sin(PI / 128))
	rows.append(
		{
			"id": "inner_facet_midpoint_fast",
			"local_position": direction * 1.90 + Vector3.UP * 1.092,
			"velocity": direction * 10 + Vector3.DOWN * 3
		}
	)
	for row: Dictionary in rows:
		row.probe_slot = "none"
		row.probe_sample = -1
	for source_id: String in ["inner_wall_near_water_fast", "water_ground_fast"]:
		for slot: String in ["before_observer", "after_observer"]:
			for source: Dictionary in rows.duplicate(true):
				if source.id == source_id:
					var row: Dictionary = source.duplicate(true)
					row.id = source_id + "_probe_" + slot
					row.probe_slot = slot
					row.probe_sample = 1
					rows.append(row)
	return rows


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _validate_telemetry(packet: Dictionary) -> void:
	var counts: Dictionary = {"before": 0, "after": 0, "router": 0, "query": 0}
	var phase: String = "before"
	for row: Dictionary in packet.events:
		match row.event:
			"telemetry.before_super":
				_check(phase == "before", "one telemetry pre-super per actual integration")
				phase = "router"
				counts.before += 1
				_check(
					is_equal_approx(row.detail.direct_state.step, 1.0 / 60), "direct actual step"
				)
			"BattedBallBody.physics_contact_router":
				counts.router += 1
				if _observation_mode == "telemetry":
					_check(phase == "router", "unchanged super provides the ordinary router")
					phase = "after"
			"telemetry.after_super":
				_check(phase == "after", "one telemetry post-super per actual integration")
				phase = "before"
				counts.after += 1
			"telemetry.prior_motion_query":
				counts.query += 1
	var expected: int = counts.router if _observation_mode == "telemetry" else 0
	_check(
		counts.before == expected and counts.after == expected and counts.query == expected,
		"exact requested telemetry pairs and diagnostic queries; baseline has none"
	)
	_check(phase == "before", "no incomplete integration telemetry phase")
	packet.telemetry_counts = counts


static func _canonical_trajectory(packet: Dictionary) -> Dictionary:
	var samples: Array[Dictionary] = []
	for row: Dictionary in packet.events:
		if row.event.begins_with("telemetry.") or row.event == "binding":
			continue
		var state: Dictionary = row.state.duplicate(true)
		state.erase("state_instance")
		samples.append(
			{
				"event": row.event,
				"relative_physics_frame": row.relative_physics_frame,
				"sample_index": row.sample_index,
				"launch_generation": row.launch_generation,
				"center": row.center,
				"velocity": row.velocity,
				"angular_velocity": row.angular_velocity,
				"sleeping": row.sleeping,
				"freeze": row.freeze,
				"physical_radius": row.physical_radius,
				"state": state,
				"geometry": row.geometry,
				"detail": _canonical_detail(row.detail)
			}
		)
	return {"mode": packet.mode, "case": packet.case, "ordinary_callback_trajectory": samples}


static func _canonical_detail(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			if key != "body_instance":
				result[key] = _canonical_detail(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_canonical_detail(item))
		return result
	return value

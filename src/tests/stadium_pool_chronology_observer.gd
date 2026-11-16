class_name StadiumPoolChronologyObserver
extends RefCounted
# gdlint: disable=max-returns
## Observation only: ordinary callbacks are recorded, never reordered into a water result.

const SCHEMA: String = "POOL-ORDINARY-HOOK-CHRONOLOGY-v3-TELEMETRY"
const MAX_EVENTS: int = 20000
const FROZEN_INPUTS: Dictionary = {
	"res://src/presentation/ball/batted_ball_body.gd":
	"e9a6f7a3096ecbc8d9109b32ab633503756f630559fc0d102c466585cc9fa9a5",
	"res://src/gameplay/ball_in_play/ball_play_resolver.gd":
	"4470909adec562bf7d278a0019cecbd960605b2e69eee19178532b77d626f621",
	"res://src/gameplay/ball_in_play/ball_play_state.gd":
	"8a31d563ea78bfa6637def55aeb83dcd036bb16a187773fece4e852676ad8c4c",
	"res://src/gameplay/stadium/stadium_pool_contract.gd":
	"94f06f487e3d020d5b26441a252e3e1c38d493ec588df69cda8735f40e8db9bd",
	"res://src/gameplay/stadium/stadium_pool_party_asset_integrity.gd":
	"5da71e546e50af6e69aaf1574655c463036ac72e6ab2043886c7828ce5be6a1e",
	"res://src/presentation/stadium/stadium_pool_models.gd":
	"f1a52e86332860738bf473fce8bfa4a503049e43528a0e28b24dcaed9d121b76",
	"res://src/presentation/stadium/stadium_starter_models.gd":
	"c9e92051b1627a3043ebf6cb802940a24570851676cd8718ae1c475bda964138"
}
var records: Array[Dictionary] = []
var errors: Array[String] = []
var case_record: Dictionary = {}
var mode: String = ""
var generation: int = 0
var sample_index: int = 0
var _ball: BattedBallBody
var _resolver: BallPlayResolver
var _model: Node3D
var _ground: StaticBody3D
var _state_ref: BallPlayState
var _model_parent: Node
var _ground_parent: Node
var _bodies: Dictionary = {}
var _initial_frame: int = 0
var _sequence: int = 0
var _active: bool = false
var _prior_point: Vector3
var _prior_sample: Dictionary = {}
var _observation_mode: String = "baseline"
var _telemetry_body: StadiumPoolTelemetryBody
var _last_direct_after: Dictionary = {}
var _pending_predictions: Array[Dictionary] = []
var _launch_seed: Dictionary = {}
# Allocate the same query object in baseline and telemetry to preserve Object allocation order.
var _prediction_query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()


func bind(
	ball: BattedBallBody,
	resolver: BallPlayResolver,
	model: Node3D,
	ground: StaticBody3D,
	selected_mode: String,
	selected_case: Dictionary,
	observation_mode: String = "baseline"
) -> bool:
	if (
		_active
		or ball == null
		or resolver == null
		or resolver.state == null
		or ball.physics_contact_router.is_valid()
		or resolver.segment_observer.is_valid()
	):
		return false
	if selected_mode not in ["live_geometry", "scenery", "no_pool"] or not frozen_sources_valid():
		return false
	if observation_mode not in ["baseline", "telemetry"]:
		return false
	_observation_mode = observation_mode
	if not ball_script_valid(ball) or ball.custom_integrator or not ball.continuous_cd:
		return false
	_ball = ball
	_resolver = resolver
	_model = model
	_ground = ground
	_state_ref = resolver.state
	_model_parent = model.get_parent() if model != null else null
	_ground_parent = ground.get_parent()
	mode = selected_mode
	case_record = selected_case.duplicate(true)
	if not model_intact():
		return false
	_register_body(ground, "RIG_GROUND")
	if model != null:
		for body: StaticBody3D in model.get_node("Collision").get_children():
			_register_body(body, String(body.name))
	_initial_frame = Engine.get_physics_frames()
	_prior_point = ball.global_position
	_active = true
	ball.physics_contact_router = contact_batch
	resolver.segment_observer = segment_observer
	ball.launch_started.connect(launch_started)
	ball.surface_contact.connect(surface_contact)
	resolver.play_resolved.connect(play_resolved)
	if observation_mode == "telemetry":
		_telemetry_body = ball as StadiumPoolTelemetryBody
		_telemetry_body.integration_observed.connect(direct_state_sample)
	append(
		"binding",
		{
			"ball_instance": ball.get_instance_id(),
			"model_instance": model.get_instance_id() if model != null else 0,
			"ground_instance": ground.get_instance_id(),
			"model_binding_intact": true,
			"water_carrier_present":
			model != null and model.has_node(StadiumPoolContract.WATER_VOLUME_ID),
			"router_is_observation_only": true,
			"observation_mode": observation_mode,
			"actual_ball_script": ball.get_script().resource_path
		}
	)
	return true


func launch_started(position: Vector3) -> void:
	generation += 1
	_prior_point = position
	_prior_sample.clear()
	sample_index = 0
	_launch_seed = {
		"physics_frame": Engine.get_physics_frames(),
		"transform": _ball.global_transform,
		"linear_velocity": _ball.linear_velocity,
		"angular_velocity": _ball.angular_velocity,
		"total_gravity": Vector3.DOWN * 9.8,
		"snapshot_kind": "PUBLIC_LAUNCH_REQUEST_NOT_DIRECT_PHYSICS_STATE"
	}
	append("BattedBallBody.launch_started", {"actual_launch_position": position})


func contact_batch(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
	if not _active or ball != _ball:
		return
	var contacts: Array[Dictionary] = []
	for entry: Dictionary in batch:
		var body: Node3D = entry.get("body") as Node3D
		var row: Dictionary = _bodies.get(body.get_instance_id(), {}) if body != null else {}
		var bound: bool = (
			not row.is_empty()
			and row.node == body
			and body.global_transform == row.global_transform
			and var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body)) == row.snapshot
		)
		if not bound:
			errors.append("Contact from an unregistered actual body")
		contacts.append(
			{
				"body_instance": body.get_instance_id() if body != null else 0,
				"bound_label": row.get("label", "UNREGISTERED"),
				"actual_body_bound": bound,
				"raw_contact_collider_position": entry.get("position"),
				"body_global_transform":
				body.global_transform if body is Node3D else Transform3D.IDENTITY
			}
		)
	# These positions are exactly the existing callback payload. It does not supply TOI,
	# normals, impulses, physics step or an ordered within-step reflected center trajectory.
	append(
		"BattedBallBody.physics_contact_router",
		{
			"contacts": contacts,
			"contact_order_is_engine_batch_order": true,
			"reported_contact_count": batch.size(),
			"configured_max_contacts_reported": ball.max_contacts_reported,
			"at_contact_capacity": batch.size() >= ball.max_contacts_reported,
			"complete_collision_manifold_is_not_guaranteed": true,
			"time_of_impact_provided": false,
			"reflected_subsegments_provided": false
		}
	)


func segment_observer(resolver: BallPlayResolver, from: Vector3, to: Vector3) -> void:
	if not _active or resolver != _resolver:
		return
	append(
		"BallPlayResolver.segment_observer",
		{
			"from": from,
			"to": to,
			"callback_is_observation_only": true,
			"default_resolver_segment_logic_bypassed": true,
			"reported_path_kind": "ENDPOINT_CHORD_ONLY",
			"from_geometry": geometry_sample(from, _ball.radius_m),
			"to_geometry": geometry_sample(to, _ball.radius_m)
		}
	)
	# No water rule, fake reflection, custom integrator, scoring observer or collider mutation.


func surface_contact(surface: StringName, position: Vector3) -> void:
	if not _active:
		return
	append(
		"BattedBallBody.surface_contact",
		{
			"surface": String(surface),
			"callback_position": position,
			"collider_identity_provided": false,
			"signal_position_is_ball_node_center": true
		}
	)
	if surface == &"ground":
		append("BallPlayResolver.record_ground_contact.before", {"callback_position": position})
		_resolver.record_ground_contact(position)
		append("BallPlayResolver.record_ground_contact.after", {"callback_position": position})


func play_resolved(outcome: BallPlayOutcome) -> void:
	append(
		"BallPlayResolver.play_resolved",
		{
			"result": int(outcome.result),
			"reason": String(outcome.reason),
			"caught": outcome.caught,
			"resolution_position": outcome.resolution_position
		}
	)
	# Mirrors the ordinary non-HR terminal stop. It is never called because of water geometry.
	_ball.global_position = outcome.resolution_position
	_ball.stop_and_freeze()


func tick(delta: float) -> void:
	if not _active:
		return
	flush_prediction_queries()
	append("rig.physics_process.before", {"observed_delta": delta})
	var geometry: Dictionary = geometry_sample(_ball.global_position, _ball.radius_m)
	if not _prior_sample.is_empty() and geometry.sphere_overlap != _prior_sample.sphere_overlap:
		append(
			"sampled_geometry_overlap_transition",
			{
				"prior": _prior_sample,
				"current": geometry,
				"from": _prior_point,
				"to": _ball.global_position,
				"earliest_entry_known": false,
				"no_reflected_path_inferred": true
			}
		)
	if (
		case_record.probe_slot == "before_observer"
		and sample_index == int(case_record.probe_sample)
	):
		control_probe()
	_resolver.observe_segment(_prior_point, _ball.global_position)
	_resolver.advance_time(delta)
	if case_record.probe_slot == "after_observer" and sample_index == int(case_record.probe_sample):
		control_probe()
	_prior_point = _ball.global_position
	_prior_sample = geometry
	append("rig.physics_process.after", {"observed_delta": delta})
	sample_index += 1


func control_probe() -> void:
	# Deliberately a direct-rule timing probe, not a legal defender position or controller catch.
	# It executes the normal resolver method even when water geometry is overlapped.
	append(
		"direct_rule_control_probe.before",
		{
			"synthetic_probe": true,
			"controller_or_game_catch": false,
			"probe_slot": case_record.probe_slot
		}
	)
	_resolver.record_clean_control(
		&"chronology_rule_probe",
		_ball.global_position,
		not _resolver.state.has_grounded,
		_ball.linear_velocity.length() > 0.35
	)
	append("direct_rule_control_probe.after", {"synthetic_probe": true})


func append(event: String, detail: Dictionary = {}) -> void:
	if not _active:
		return
	if records.size() >= MAX_EVENTS:
		if not errors.has("Event capacity exceeded; observation is incomplete"):
			errors.append("Event capacity exceeded; observation is incomplete")
		return
	_sequence += 1
	records.append(
		{
			"seq": _sequence,
			"event": event,
			"physics_frame": Engine.get_physics_frames(),
			"relative_physics_frame": Engine.get_physics_frames() - _initial_frame,
			"sample_index": sample_index,
			"launch_generation": generation,
			"center": _ball.global_position,
			"velocity": _ball.linear_velocity,
			"angular_velocity": _ball.angular_velocity,
			"sleeping": _ball.sleeping,
			"freeze": _ball.freeze,
			"physical_radius": _ball.radius_m,
			"sample_source": "BATTEDBALLBODY_NODE_PROPERTIES_AT_CALLBACK_INVOCATION",
			"physics_direct_body_state_available": false,
			"state": state_snapshot(),
			"geometry": geometry_sample(_ball.global_position, _ball.radius_m),
			"detail": detail
		}
	)


func state_snapshot() -> Dictionary:
	var state: BallPlayState = _resolver.state
	return {
		"state_instance": state.get_instance_id(),
		"elapsed_seconds": state.elapsed_seconds,
		"is_foul_play": state.is_foul_play,
		"is_fair": state.is_fair,
		"has_grounded": state.has_grounded,
		"defender_touched": state.defender_touched,
		"caught": state.caught,
		"dead": state.dead,
		"result_floor": int(state.result_floor)
	}


func model_intact() -> bool:
	if mode == "no_pool":
		return _model == null
	if not is_instance_valid(_model):
		return false
	var role: String = (
		StadiumPoolContract.LIVE if mode == "live_geometry" else StadiumPoolContract.SCENERY
	)
	return StadiumPoolContract.valid_binding(
		_model, role, StadiumPoolContract.placement(), StadiumPoolContract.geometry(role)
	)


func finish() -> Dictionary:
	flush_prediction_queries()
	var intact: bool = model_intact() and binding_intact()
	append("window_end", {"model_binding_intact": intact, "physics_samples": sample_index})
	if not intact:
		errors.append("Frozen model binding changed during observation")
	var packet: Dictionary = {
		"schema": SCHEMA,
		"mode": mode,
		"observation_mode": _observation_mode,
		"actual_ball_script": _ball.get_script().resource_path,
		"direct_state_snapshots_available": _observation_mode == "telemetry",
		"case": case_record,
		"explicitly_positioned_physics_control": true,
		"ordinary_lab_witness": false,
		"default_resolver_segment_logic_bypassed": true,
		"physics_direct_body_state_available": _observation_mode == "telemetry",
		"ordinary_router_exposes_direct_state": false,
		"node_samples_are_not_authoritative_integrated_state": true,
		"water_awards_implemented": false,
		"earliest_within_step_order_qualified": false,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"source_src_project_integrity": StadiumPoolPartyAssetIntegrity.source_sha256(),
		"actual_frozen_input_sha256": actual_source_hashes(),
		"frozen_sources_intact": frozen_sources_valid(),
		"model_geometry":
		(
			StadiumPoolContract.geometry(
				StadiumPoolContract.LIVE if mode == "live_geometry" else StadiumPoolContract.SCENERY
			)
			if mode != "no_pool"
			else {}
		),
		"model_instance": _model.get_instance_id() if _model != null else 0,
		"ball_instance": _ball.get_instance_id(),
		"events": records.duplicate(true),
		"errors": errors.duplicate()
	}
	if _telemetry_body != null:
		if _telemetry_body.integration_observed.is_connected(direct_state_sample):
			_telemetry_body.integration_observed.disconnect(direct_state_sample)
	_active = false
	if _ball.physics_contact_router == contact_batch:
		_ball.physics_contact_router = Callable()
	if _resolver.segment_observer == segment_observer:
		_resolver.segment_observer = Callable()
	for binding: Array in [
		[_ball.launch_started, launch_started],
		[_ball.surface_contact, surface_contact],
		[_resolver.play_resolved, play_resolved]
	]:
		var signal_value: Signal = binding[0]
		var callback: Callable = binding[1]
		if signal_value.is_connected(callback):
			signal_value.disconnect(callback)
	return packet


static func geometry_sample(world: Vector3, radius: float) -> Dictionary:
	var local: Vector3 = StadiumPoolContract.placement().affine_inverse() * world
	var radial: float = Vector2(local.x, local.z).length()
	var excess_r: float = maxf(radial - StadiumPoolContract.INNER_RADIUS, 0)
	var excess_y: float = maxf(maxf(-local.y, local.y - StadiumPoolContract.WATER_HEIGHT), 0)
	var separation: float = sqrt(excess_r * excess_r + excess_y * excess_y) - radius
	return {
		"local_center": local,
		"radial_distance": radial,
		"signed_sphere_separation": separation,
		"sphere_overlap": separation < 0,
		"center_inside":
		(
			radial < StadiumPoolContract.INNER_RADIUS
			and local.y > 0
			and local.y < StadiumPoolContract.WATER_HEIGHT
		),
		"interpretation": "DIAGNOSTIC_CYLINDER_COMPARISON_NOT_A_WATER_EVENT"
	}


func _register_body(body: StaticBody3D, label: String) -> void:
	_bodies[body.get_instance_id()] = {
		"node": body,
		"rid": body.get_rid().get_id(),
		"label": label,
		"global_transform": body.global_transform,
		"snapshot": var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body))
	}


static func actual_source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in FROZEN_INPUTS:
		result[path] = FileAccess.get_sha256(path)
	return result


static func frozen_sources_valid() -> bool:
	return actual_source_hashes() == FROZEN_INPUTS


func binding_intact() -> bool:
	if (
		not is_instance_valid(_ball)
		or not ball_script_valid(_ball)
		or _resolver.state != _state_ref
		or _ball.physics_contact_router != contact_batch
		or _resolver.segment_observer != segment_observer
	):
		return false
	if (
		not _ball.launch_started.is_connected(launch_started)
		or not _ball.surface_contact.is_connected(surface_contact)
		or not _resolver.play_resolved.is_connected(play_resolved)
	):
		return false
	if _observation_mode == "telemetry":
		if not _telemetry_body.integration_observed.is_connected(direct_state_sample):
			return false
	if not is_instance_valid(_ground) or _ground.get_parent() != _ground_parent:
		return false
	if (
		_model != null
		and (
			not is_instance_valid(_model)
			or not _model.is_inside_tree()
			or _model.get_parent() != _model_parent
		)
	):
		return false
	for row: Dictionary in _bodies.values():
		if not is_instance_valid(row.node) or row.node.global_transform != row.global_transform:
			return false
		if (
			row.label != "RIG_GROUND"
			and _model.get_node_or_null("Collision/" + row.label) != row.node
		):
			return false
		if var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(row.node)) != row.snapshot:
			return false
	return true


func ball_script_valid(ball: BattedBallBody) -> bool:
	if _observation_mode == "telemetry":
		return ball.get_script() == preload("res://src/tests/stadium_pool_telemetry_body.gd")
	return ball.get_script() == preload("res://src/presentation/ball/batted_ball_body.gd")


func direct_state_sample(phase: String, sample: Dictionary) -> void:
	if not _active or _observation_mode != "telemetry":
		return
	for contact: Dictionary in sample.contacts:
		var bound: Dictionary = _bodies.get(contact.collider_instance, {})
		contact.actual_body_bound = _body_binding_valid(
			bound, contact.collider_instance, contact.collider_rid
		)
		contact.bound_label = bound.get("label", "UNREGISTERED")
		if not contact.actual_body_bound:
			errors.append("Direct-state contact has no actual registered body")
	append("telemetry." + phase, {"direct_state": sample})
	if phase == "before_super":
		_pending_predictions.append(
			{
				"prior": _last_direct_after if not _last_direct_after.is_empty() else _launch_seed,
				"current": sample,
				"source_kind":
				(
					"PREVIOUS_DIRECT_AFTER_SUPER"
					if not _last_direct_after.is_empty()
					else "PUBLIC_LAUNCH_SEED"
				)
			}
		)
	elif phase == "after_super":
		_last_direct_after = sample
	else:
		errors.append("Unknown telemetry phase")


func flush_prediction_queries() -> void:
	for prediction: Dictionary in _pending_predictions:
		var result: Dictionary = StadiumPoolTelemetryQuery.measure(
			_ball,
			prediction.prior,
			prediction.current,
			prediction.source_kind,
			_prediction_query,
			geometry_sample
		)
		var hit_groups: Array = [result.get("initial_hits", [])]
		for probe: Dictionary in result.get("fraction_probes", []):
			hit_groups.append(probe.hits)
		for hits: Array in hit_groups:
			for hit: Dictionary in hits:
				var bound: Dictionary = _bodies.get(hit.collider_instance, {})
				hit.actual_body_bound = (
					_body_binding_valid(bound, hit.collider_instance, hit.rid)
					and hit.collider_id == hit.collider_instance
				)
				hit.bound_label = bound.get("label", "UNREGISTERED")
				if not hit.actual_body_bound:
					errors.append("Prediction query hit has no actual registered body")
		for error: String in result.errors:
			errors.append(error)
		append("telemetry.prior_motion_query", result)
	_pending_predictions.clear()


func _body_binding_valid(row: Dictionary, instance: int, rid: int) -> bool:
	if row.is_empty() or not is_instance_valid(row.node):
		return false
	var body: StaticBody3D = row.node
	return (
		body.is_inside_tree()
		and body.get_instance_id() == instance
		and body.get_rid().get_id() == rid
		and row.rid == rid
		and body.global_transform == row.global_transform
		and var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body)) == row.snapshot
		and (
			body == _ground
			if row.label == "RIG_GROUND"
			else _model != null and _model.get_node_or_null("Collision/" + row.label) == body
		)
	)

class_name StadiumPoolWaterGuard
extends RefCounted
## Private overlap-first subset. Unresolved history is reported, never silently qualified.
# gdlint: disable=max-returns,function-arguments-number

signal observed(event: String, record: Dictionary)

const SELF_SCRIPT_PATH: String = (
	"res://src/gameplay/stadium/stadium_pool_water_guard.gd"
)

const VERSION: String = "POOL-CURRENT-WET-GUARD-v1"
const EPS: float = StadiumRecipeBoundary.EPS
const BALL_SCRIPT: Script = preload("res://src/presentation/ball/batted_ball_body.gd")
var records: Array[Dictionary] = []
var errors: Array[String] = []
var unsupported: Array[Dictionary] = []
var receipts: Array[Dictionary] = []
var generation: int = 0
var _ball: BattedBallBody
var _resolver: BallPlayResolver
var _state: BallPlayState
var _model: Node3D
var _context: StadiumPoolInteriorV2
var _role: String
var _source: String
var _active_awards: bool
var _downstream: Callable
# Bound property only: ordinary manifold authority is always forwarded first.
var _ordinary_router: Callable
var _bodies: Dictionary = {}
var _ball_shape: CollisionShape3D
var _physical_radius: float
var _ball_resource: Shape3D
var _history_unproven: String = ""
var _earned_floor: int = 0
var _ball_shape_bytes: PackedByteArray
var _ball_parameters: Array = []
var _ball_parent: Node
var _model_parent: Node
var _model_bytes: PackedByteArray
var _previous: Vector3
var _launch_position: Vector3
var _launch_velocity: Vector3
var _launch_spin: Vector3
var _foul: bool
var _samples: int = 0
var _generation_invalid: bool = false
var _routing: bool = false
var _committing: bool = false
var _bound: bool = false
var _pitcher: Node3D
var _pitcher_parent: Node
var _pending_pitcher_travel: float = 0
# Guard-only cold eligibility/source plan; no successful result survives valid().
var _guard_body_plan: Dictionary = {}
# Non-null is one-way owned admission; never fall back after retirement.
var _owned_field_lease: StadiumPoolOwnedFieldLease


func bind(
	ball: BattedBallBody,
	resolver: BallPlayResolver,
	model: Node3D,
	role: String,
	source: String,
	bodies: Array[Dictionary],
	active_awards: bool,
	downstream: Callable = Callable(),
	pitcher: Node3D = null,
	pending_pitcher_travel: float = 0,
	prepared_model: StadiumPoolModelPreparation = null,
	ordinary_router: Callable = Callable(),
	ground_profile: Callable = Callable()
) -> bool:
	if ground_profile.is_valid() and not ordinary_router.is_valid():
		return false
	if ordinary_router.is_valid() and active_awards:
		return false
	if _bound or ball == null or resolver == null or resolver.state == null:
		return false
	if ball.get_script() != BALL_SCRIPT:
		return false
	if (
		ball.physics_material_override == null
		or ball.scale != Vector3.ONE
		or not StadiumPoolPartyAssetIntegrity.rigid(ball.global_transform)
	):
		return false
	if ball._started or ball.freeze or ball.custom_integrator or not ball.continuous_cd:
		return false
	if ball.physics_contact_router != downstream or not is_finite(pending_pitcher_travel):
		return false
	if (
		pending_pitcher_travel < 0
		or role not in [StadiumPoolContract.LIVE, StadiumPoolContract.SCENERY, "NO_POOL"]
	):
		return false
	if source != StadiumPoolPartyAssetIntegrity.source_sha256():
		return false
	if prepared_model != null and not prepared_model.valid(model, role, source):
		return false
	if role == StadiumPoolContract.LIVE:
		_context = (
			prepared_model.context
			if prepared_model != null
			else StadiumPoolInteriorV2.capture(model, source)
		)
		if _context == null:
			return false
	elif role == StadiumPoolContract.SCENERY:
		if (
			prepared_model == null
			and not StadiumPoolContract.valid_binding(
				model, role, StadiumPoolContract.placement(), StadiumPoolContract.geometry(role)
			)
		):
			return false
	elif model != null:
		return false
	for child: Node in ball.get_children():
		if child is CollisionShape3D:
			if _ball_shape != null:
				return false
			_ball_shape = child
	if _ball_shape == null or not _ball_shape.shape is SphereShape3D:
		return false
	if (
		_ball_shape.shape.radius != PackedFloat32Array([ball.radius_m])[0]
		or not is_finite(ball.radius_m)
		or ball.radius_m <= 0
		or not is_finite(_ball_shape.shape.radius)
		or _ball_shape.shape.radius <= 0
		or not _sphere_layout(ball, _ball_shape)
	):
		return false
	for entry: Dictionary in bodies:
		var body: StaticBody3D = entry.get("body") as StaticBody3D
		if (
			body == null
			or not body.is_inside_tree()
			or entry.get("kind") not in ["solid", "ground", "terminal"]
		):
			return false
		if not _static_layout(body):
			return false
		if entry.kind == "ground":
			var ground_valid: bool = (
				ground_profile.call(body) if ground_profile.is_valid() else _flat_pool_ground(body)
			)
			if not ground_valid:
				return false
		if _bodies.has(body.get_instance_id()):
			return false
		_bodies[body.get_instance_id()] = {
			"body": body,
			"rid": body.get_rid(),
			"parent": body.get_parent(),
			"pose": body.global_transform,
			"kind": entry.kind,
			"label": String(entry.get("label", body.name)),
			"bytes": var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body)),
			"owner_bytes": var_to_bytes(_body_owners(body))
		}
	if model != null:
		for body: StaticBody3D in model.get_node("Collision").get_children():
			if (
				not _bodies.has(body.get_instance_id())
				or _bodies[body.get_instance_id()].kind != "solid"
			):
				return false
	_ball = ball
	_resolver = resolver
	_state = resolver.state
	_model = model
	_role = role
	_source = source
	_active_awards = active_awards
	_downstream = downstream
	_ordinary_router = ordinary_router
	_ball_parent = ball.get_parent()
	_ball_parameters = _parameters(ball)
	_model_parent = model.get_parent() if model != null else null
	_model_bytes = (
		var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(model))
		if model != null
		else PackedByteArray()
	)
	_physical_radius = _ball_shape.shape.radius
	_ball_resource = _ball_shape.shape
	_ball_shape_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(_ball_shape))
	_pitcher = pitcher
	_pitcher_parent = pitcher.get_parent() if pitcher != null else null
	_pending_pitcher_travel = pending_pitcher_travel
	_guard_body_plan = StadiumPoolOwnedIntegrity.capture_guard_body_plan(self, _context)
	_bound = true
	ball.physics_contact_router = route
	ball.launch_started.connect(_on_launch)
	return true


func valid() -> bool:
	if not _bound or not is_instance_valid(_ball) or _ball.get_parent() != _ball_parent:
		return false
	if (
		_ball.physics_material_override == null
		or not StadiumPoolPartyAssetIntegrity.rigid(_ball.global_transform)
	):
		return false
	if _parameters(_ball) != _ball_parameters:
		return false
	if _ball.physics_contact_router != route or not _ball.launch_started.is_connected(_on_launch):
		return false
	if _ball.get_script() != BALL_SCRIPT or _resolver.state != _state:
		return false
	if not is_instance_valid(_ball_shape) or not _sphere_layout(_ball, _ball_shape):
		return false
	if _ball_shape.shape != _ball_resource:
		return false
	if var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(_ball_shape)) != _ball_shape_bytes:
		return false
	if (
		_physical_radius != _ball_shape.shape.radius
		or _physical_radius != PackedFloat32Array([_ball.radius_m])[0]
		or _ball.custom_integrator
	):
		return false
	var guard_request: Dictionary = {}
	if _model != null:
		if not is_instance_valid(_model) or _model.get_parent() != _model_parent:
			return false
		if _role == StadiumPoolContract.LIVE:
			guard_request = StadiumPoolOwnedIntegrity.guard_body_request(_guard_body_plan, self)
			if guard_request.get("source_breach", false):
				return false
			var context_valid: bool = (
				_context.valid(_model, _source)
				if guard_request.is_empty()
				else _context.valid_guard_body(_model, _source, guard_request)
			)
			if not context_valid or guard_request.get("source_breach", false):
				return false
		elif (
			_model.global_transform != StadiumPoolContract.placement()
			or var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(_model)) != _model_bytes
		):
			return false
	if (
		_pitcher != null
		and (not is_instance_valid(_pitcher) or _pitcher.get_parent() != _pitcher_parent)
	):
		return false
	for entry: Dictionary in _bodies.values():
		var body: StaticBody3D = entry.body
		if (
			not is_instance_valid(body)
			or body.get_parent() != entry.parent
			or body.get_rid() != entry.rid
		):
			return false
		if (
			body.global_transform != entry.pose
			or not (
				_guard_body_covered(guard_request, body)
				if guard_request.get("complete", false)
				else _body_snapshot_valid(body, entry.bytes)
			)
			or var_to_bytes(_body_owners(body)) != entry.owner_bytes
		):
			return false
	return true


func valid_owned_lease(lease: StadiumPoolOwnedFieldLease) -> bool:
	if get_script() != load(SELF_SCRIPT_PATH):
		return false
	if (
		lease == null
		or lease != _owned_field_lease
		or (
			lease.get_script()
			!= load("res://src/gameplay/stadium/stadium_pool_owned_field_lease.gd")
		)
	):
		return false
	var valid_owned: bool = _valid_owned_lease(lease)
	if not valid_owned:
		lease.revoke("LEASED_GUARD_CHANGED")
	return valid_owned


func _valid_owned_lease(lease: StadiumPoolOwnedFieldLease) -> bool:
	if (
		lease == null
		or lease != _owned_field_lease
		or lease._controller == null
		or not lease.valid_play(lease._controller.get_ref(), self)
	):
		return false
	if not _bound or not is_instance_valid(_ball) or _ball.get_parent() != _ball_parent:
		return false
	if (
		_ball.physics_material_override == null
		or not StadiumPoolPartyAssetIntegrity.rigid(_ball.global_transform)
	):
		return false
	if _parameters(_ball) != _ball_parameters:
		return false
	if _ball.physics_contact_router != route or not _ball.launch_started.is_connected(_on_launch):
		return false
	if _ball.get_script() != BALL_SCRIPT or _resolver.state != _state:
		return false
	if not is_instance_valid(_ball_shape) or not _sphere_layout(_ball, _ball_shape):
		return false
	if _ball_shape.shape != _ball_resource:
		return false
	if var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(_ball_shape)) != _ball_shape_bytes:
		return false
	if (
		_physical_radius != _ball_shape.shape.radius
		or _physical_radius != PackedFloat32Array([_ball.radius_m])[0]
		or _ball.custom_integrator
	):
		return false
	if (
		not is_instance_valid(_model)
		or _model.get_parent() != _model_parent
		or _role != StadiumPoolContract.LIVE
		or not _context.valid_owned_lease(_model, _source, lease)
	):
		return false
	if (
		_pitcher != null
		and (not is_instance_valid(_pitcher) or _pitcher.get_parent() != _pitcher_parent)
	):
		return false
	# Every registered body remains fresh, not only bodies in this contact batch.
	for entry: Dictionary in _bodies.values():
		var body: StaticBody3D = entry.body
		if (
			not is_instance_valid(body)
			or not body.is_inside_tree()
			or body.is_queued_for_deletion()
			or body.get_parent() != entry.parent
			or body.get_rid() != entry.rid
			or body.global_transform != entry.pose
		):
			return false
	return true


func sample_owned_lease(center: Vector3, radius: float) -> Dictionary:
	return (
		_context.sample(center, radius)
		if _owned_field_lease == null
		else (_context.sample_owned_lease(center, radius, _owned_field_lease))
	)


func _on_launch(position: Vector3) -> void:
	if _routing or _committing:
		_generation_invalid = true
		_reject("REENTRANT_LAUNCH_REJECTED")
		return
	if not _bound or _resolver.state == null:
		return
	if generation > 0 and _resolver.state == _state:
		_generation_invalid = true
		_reject("RELAUNCH_REQUIRES_NEW_RESOLVER_STATE")
		return
	_state = _resolver.state
	_generation_invalid = false
	generation += 1
	_samples = 0
	_history_unproven = ""
	_earned_floor = _state.result_floor
	_previous = position
	_launch_position = position
	_launch_velocity = _ball.linear_velocity
	_launch_spin = _ball.angular_velocity
	_foul = _state.is_foul_play
	_committing = false
	_emit(
		"launch",
		{
			"position": position,
			"requested_velocity": _launch_velocity,
			"authored_radius_m": _ball.radius_m,
			"physical_radius_m": _physical_radius
		}
	)


func route(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
	if _committing or _routing:
		return
	_routing = true
	# Even revoked Pool ownership must not swallow ordinary boundary contacts.
	if _ordinary_router.is_valid():
		_ordinary_router.call(ball, batch)
	_route_sample(ball, batch)
	_routing = false


func _route_sample(ball: BattedBallBody, batch: Array[Dictionary]) -> void:
	if (
		ball != _ball
		or generation < 1
		or _generation_invalid
		or not (
			valid_owned_lease(_owned_field_lease)
			if (
				get_script() == load(SELF_SCRIPT_PATH)
				and _owned_field_lease != null
			)
			else valid()
		)
	):
		_generation_invalid = true
		_reject("STALE_OR_MISBOUND_RUNTIME")
		return
	_samples += 1
	var current: Vector3 = ball.global_position
	var contacts: Array[Dictionary] = []
	var reason: String = _history_unproven
	for contact: Dictionary in batch:
		var body: Node = contact.get("body") as Node
		var entry: Dictionary = (
			_bodies.get(body.get_instance_id(), {}) if is_instance_valid(body) else {}
		)
		if (
			entry.is_empty()
			or not is_instance_valid(body)
			or entry.get("body") != body
			or (body is StaticBody3D and body.get_rid() != entry.rid)
		):
			reason = "UNREGISTERED_CONTACT"
		else:
			contacts.append(
				{
					"kind": entry.kind,
					"label": entry.label,
					"body_instance": body.get_instance_id(),
					"position": contact.get("position")
				}
			)
			if entry.kind == "terminal":
				reason = "EARLIER_TERMINAL_SOLID_ORDER_UNPROVEN"
	if batch.size() >= ball.max_contacts_reported:
		reason = "CONTACT_CAPACITY_ORDER_UNPROVEN"
	if not reason.is_empty():
		_history_unproven = reason
	# The ordinary router may finalize a home run and remove its surface listener
	# while the real ball carries on. Fresh owned validation above still applies;
	# a terminal play cannot sample/award Pool water or call live-play observers.
	if (
		get_script() == load(SELF_SCRIPT_PATH)
		and _owned_field_lease != null
		and _state.dead
	):
		_emit("prior_terminal", {"contacts": contacts}, false)
		_previous = current
		return
	# The owned downstream is observational only; it cannot win a ground/control race.
	var state_before_downstream: PackedByteArray = var_to_bytes(_state_parameters(_state))
	var motion_before: Array = [ball.global_transform, ball.linear_velocity, ball.angular_velocity]
	var generation_before: int = generation
	if _downstream.is_valid():
		_downstream.call(ball, batch)
	if (
		_resolver.state != _state
		or var_to_bytes(_state_parameters(_state)) != state_before_downstream
		or [ball.global_transform, ball.linear_velocity, ball.angular_velocity] != motion_before
		or generation != generation_before
		or _generation_invalid
		or not (
			valid_owned_lease(_owned_field_lease)
			if (
				get_script() == load(SELF_SCRIPT_PATH)
				and _owned_field_lease != null
			)
			else valid()
		)
	):
		_generation_invalid = true
		_reject("DOWNSTREAM_NOT_OBSERVATIONAL")
		return
	if _state.dead:
		_emit("prior_terminal", {"contacts": contacts})
		_previous = current
		return
	if _state.is_foul_play != _foul:
		reason = "IMMUTABLE_FAIR_FOUL_CHANGED"
		_generation_invalid = true
	if _state.result_floor < _earned_floor:
		reason = "EARNED_FLOOR_REGRESSED"
		_generation_invalid = true
	_earned_floor = maxi(_earned_floor, _state.result_floor)
	if _state.result_floor > BallPlayState.ResultFloor.DOUBLE:
		reason = "INVALID_LIVE_EARNED_FLOOR"
	if not current.is_finite():
		reason = "NONFINITE_CENTER"
	if _role != StadiumPoolContract.LIVE:
		_emit("decorative_or_no_pool", {"contacts": contacts})
		_previous = current
		return
	var sample: Dictionary = (
		_context.sample_owned_lease(current, _physical_radius, _owned_field_lease)
		if (
			get_script() == load(SELF_SCRIPT_PATH)
			and _owned_field_lease != null
		)
		else _context.sample(current, _physical_radius)
	)
	var pitcher: Dictionary = pitcher_exclusion(
		_previous, current, _pitcher, _pending_pitcher_travel, _physical_radius
	)
	if not sample.valid:
		reason = "INVALID_WATER_SAMPLE"
	elif sample.tangent_or_uncertain:
		reason = "WATER_BOUNDARY_UNCERTAIN"
	elif sample.positive_overlap and not pitcher.excluded:
		reason = "HISTORICAL_PITCHER_ORDER_UNPROVEN"
	if sample.get("positive_overlap", false) and not _ground_order_supported(contacts):
		reason = "SAME_STEP_GROUND_ORDER_UNPROVEN"
		_history_unproven = reason
	_emit(
		"considered",
		{
			"sample": sample,
			"contacts": contacts,
			"pitcher": pitcher,
			"previous": _previous,
			"unsupported": reason,
			"dry_to_dry_completeness_qualified": false
		},
		false
	)
	if not reason.is_empty():
		_reject(reason)
	elif sample.positive_overlap and _active_awards:
		_commit(current, sample, contacts, pitcher)
	_previous = current


func _ground_order_supported(contacts: Array[Dictionary]) -> bool:
	for contact: Dictionary in contacts:
		if contact.kind != "ground" or _state.has_grounded:
			continue
		# Explicitly bounded first-step vertical center-column control, not arbitrary ground history.
		var local: Vector3 = StadiumPoolContract.placement().affine_inverse() * _launch_position
		var point: Vector3 = StadiumPoolContract.placement().affine_inverse() * contact.position
		if _samples != 1 or Vector2(local.x, local.z).length() > EPS:
			return false
		if (
			_launch_velocity.x != 0
			or _launch_velocity.z != 0
			or _launch_velocity.y >= 0
			or _launch_spin != Vector3.ZERO
		):
			return false
		if (
			local.y <= StadiumPoolContract.WATER_HEIGHT + _physical_radius
			or Vector2(point.x, point.z).length() > EPS
			or absf(point.y) > EPS
		):
			return false
		for other: Dictionary in contacts:
			if other.kind != "ground":
				return false
	return true


func _commit(
	position: Vector3, sample: Dictionary, contacts: Array[Dictionary], pitcher: Dictionary
) -> void:
	if _committing or _state.dead:
		return
	_committing = true
	var before_floor: int = _state.result_floor
	var receipt: Dictionary = {
		"version": VERSION,
		"source": _source,
		"generation": generation,
		"state_instance": _state.get_instance_id(),
		"ball_instance": _ball.get_instance_id(),
		"authored_radius_m": _ball.radius_m,
		"physical_radius_m": _physical_radius,
		"physics_frame": Engine.get_physics_frames(),
		"sample_index": _samples,
		"position": position,
		"is_foul_play": _foul,
		"prior_floor": before_floor,
		"prior_grounded": _state.has_grounded,
		"prior_touched": _state.defender_touched,
		"water": sample,
		"contacts": contacts,
		"pitcher": pitcher,
		"entry_time_kind": "EXISTS_BY_CURRENT_INTEGRATED_SAMPLE_NO_TOI",
		"dry_to_dry_completeness_qualified": false
	}
	receipts.append(receipt)
	# No observer can run between the final decision and the ordinary atomic terminal latch.
	_emit("water_commit", receipt, false)
	var commit_record: Dictionary = records[-1]
	if _foul:
		_resolver._resolve_foul(&"private_pool_water_foul", position)
	else:
		_state.raise_result_floor(BallPlayState.ResultFloor.DOUBLE)
		_resolver._resolve_out(
			BallPlayOutcome.Result.DOUBLE, &"private_pool_water_double", position
		)
	observed.emit("water_commit", commit_record)
	_committing = false


func _reject(reason: String) -> void:
	var row: Dictionary = {
		"reason": reason,
		"generation": generation,
		"sample_index": _samples,
		"physics_frame": Engine.get_physics_frames()
	}
	unsupported.append(row)
	_emit("unsupported", row)


func _emit(event: String, detail: Dictionary, notify: bool = true) -> void:
	var row: Dictionary = {
		"event": event,
		"generation": generation,
		"sample_index": _samples,
		"physics_frame": Engine.get_physics_frames(),
		"detail": detail.duplicate(true)
	}
	records.append(row)
	if notify:
		observed.emit(event, row)


func detach() -> void:
	if is_instance_valid(_ball):
		if _ball.physics_contact_router == route:
			_ball.physics_contact_router = _downstream
		if _ball.launch_started.is_connected(_on_launch):
			_ball.launch_started.disconnect(_on_launch)
	_bound = false
	_downstream = Callable()
	_ordinary_router = Callable()


static func pitcher_exclusion(
	previous: Vector3, current: Vector3, actor: Node3D, pending_travel: float, radius: float
) -> Dictionary:
	if actor == null:
		return {"excluded": true, "kind": "NO_PITCHER_IN_ISOLATED_FIXTURE"}
	if (
		not is_instance_valid(actor)
		or not actor.is_inside_tree()
		or not actor.global_position.is_finite()
		or not is_finite(pending_travel)
		or pending_travel < 0
	):
		return {"excluded": false, "kind": "INVALID_ACTUAL_ACTOR_ENVELOPE"}
	var center: Vector3 = StadiumPoolContract.placement().origin
	var gap: float = (
		Vector2(center.x - actor.global_position.x, center.z - actor.global_position.z).length()
		- PitcherDefense.REACTION_RADIUS_M
		- StadiumPoolContract.INNER_RADIUS
		- radius
		- pending_travel
	)
	var chord: float = Vector2(current.x - previous.x, current.z - previous.z).length()
	return {
		"excluded": false,
		"conditional_chord_excluded": gap > EPS and chord + EPS < gap,
		"controller_segment_bound": false,
		"kind": "UNBOUND_CONTROLLER_SEGMENT_UNSUPPORTED",
		"actor_instance": actor.get_instance_id(),
		"actor_position": actor.global_position,
		"pending_m": pending_travel,
		"gap_m": gap,
		"horizontal_chord_m": chord,
		"five_metre_target_is_not_actor_bound": true
	}


static func _parameters(ball: BattedBallBody) -> Array:
	return [
		ball.mass,
		ball.radius_m,
		ball.collision_layer,
		ball.collision_mask,
		ball.continuous_cd,
		ball.contact_monitor,
		ball.max_contacts_reported,
		ball.custom_integrator,
		ball.gravity_scale,
		ball.linear_damp,
		ball.angular_damp,
		ball.physics_material_override,
		ball.physics_material_override.bounce,
		ball.physics_material_override.friction
	]


static func _state_parameters(state: BallPlayState) -> Array:
	return [
		state.is_foul_play,
		state.is_fair,
		state.has_grounded,
		state.defender_touched,
		state.caught,
		state.dead,
		state.result_floor,
		state.elapsed_seconds,
		state.last_obstacle_contact,
		state.last_defender_touch,
		state.bobbled,
		state.first_ground_position,
		state.catch_position,
		state.catch_time,
		state.stadium_contacts.duplicate(true)
	]


static func _flat_pool_ground(body: StaticBody3D) -> bool:
	if body.get_child_count() == 2:
		return StadiumPoolLabGroundProfile.matches(body)
	if body.global_basis != Basis.IDENTITY or body.get_child_count() != 1:
		return false
	var shape: CollisionShape3D = body.get_child(0) as CollisionShape3D
	if shape == null or not shape.shape is BoxShape3D or shape.transform != Transform3D.IDENTITY:
		return false
	var size: Vector3 = shape.shape.size
	var pose: Vector3 = body.global_position
	var center: Vector3 = StadiumPoolContract.placement().origin
	return (
		absf(pose.y + size.y / 2.0) <= EPS
		and absf(pose.x - center.x) + StadiumPoolContract.VISUAL_RADIUS < size.x / 2.0
		and absf(pose.z - center.z) + StadiumPoolContract.VISUAL_RADIUS < size.z / 2.0
	)


static func _sphere_layout(ball: BattedBallBody, shape: CollisionShape3D) -> bool:
	if shape.get_parent() != ball or shape.transform != Transform3D.IDENTITY or shape.disabled:
		return false
	if not shape.shape is SphereShape3D or shape.shape.get_script() != null:
		return false
	var owners: PackedInt32Array = ball.get_shape_owners()
	return (
		owners.size() == 1
		and ball.shape_owner_get_owner(owners[0]) == shape
		and ball.shape_owner_get_transform(owners[0]) == Transform3D.IDENTITY
		and not ball.is_shape_owner_disabled(owners[0])
		and ball.shape_owner_get_shape_count(owners[0]) == 1
		and ball.shape_owner_get_shape(owners[0], 0) == shape.shape
	)


static func _body_owners(body: CollisionObject3D) -> Array:
	var rows: Array = []
	for owner: int in body.get_shape_owners():
		var shapes: Array = []
		for index: int in range(body.shape_owner_get_shape_count(owner)):
			shapes.append(body.shape_owner_get_shape(owner, index).get_rid().get_id())
		rows.append(
			[
				owner,
				(
					body.shape_owner_get_owner(owner).get_instance_id()
					if is_instance_valid(body.shape_owner_get_owner(owner))
					else 0
				),
				body.shape_owner_get_transform(owner),
				body.is_shape_owner_disabled(owner),
				shapes
			]
		)
	return rows


static func _static_layout(body: StaticBody3D) -> bool:
	var shapes: Array[CollisionShape3D] = []
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			shapes.append(child)
	var owners: PackedInt32Array = body.get_shape_owners()
	if shapes.is_empty() or owners.size() != shapes.size():
		return false
	for owner: int in owners:
		var shape: CollisionShape3D = body.shape_owner_get_owner(owner) as CollisionShape3D
		if shape == null or not shapes.has(shape) or shape.disabled or shape.shape == null:
			return false
		if (
			body.shape_owner_get_transform(owner) != shape.transform
			or body.is_shape_owner_disabled(owner)
			or body.shape_owner_get_shape_count(owner) != 1
			or body.shape_owner_get_shape(owner, 0) != shape.shape
		):
			return false
		shapes.erase(shape)
	return shapes.is_empty()


static func _guard_body_refs(policy: StadiumPoolOwnedIntegrity, registry: Dictionary) -> Dictionary:
	var bodies: Dictionary = {}
	for key: Variant in registry:
		var entry: Variant = registry[key]
		if (
			not key is int
			or not entry is Dictionary
			or not entry.get("body") is StaticBody3D
			or not entry.get("rid") is RID
			or not entry.get("parent") is Node
			or not entry.get("pose") is Transform3D
			or not entry.get("bytes") is PackedByteArray
			or not entry.get("owner_bytes") is PackedByteArray
		):
			return {}
		var body: StaticBody3D = entry.body
		if (
			not is_instance_valid(body)
			or body.get_class() != "StaticBody3D"
			or body.get_script() != null
			or body.get_instance_id() != key
			or not policy._body_bytes.has(key)
			or not policy._owner_scene_bodies.has(key)
			or not policy._owner_scene_index.has(key)
		):
			return {}
		var role: Variant = policy._owner_scene_bodies[key]
		var index: Variant = policy._owner_scene_index[key]
		if (
			not role is PackedInt32Array
			or role.is_empty()
			or not index is int
			or index < 0
			or index >= policy._owner_scene_nodes.size()
			or role[0] != index
		):
			return {}
		var record: Variant = policy._owner_scene_nodes[index]
		if (
			not record is Dictionary
			or record.get("id") != key
			or not record.get("ref") is WeakRef
			or record.ref.get_ref() != body
			or record.get("tree") != true
			or not _guard_body_role_valid(policy, role)
		):
			return {}
		bodies[key] = body
	return bodies


static func _guard_body_role_valid(
	policy: StadiumPoolOwnedIntegrity, role: PackedInt32Array
) -> bool:
	var pending: Array[int] = [role[0]]
	var visited: Dictionary = {}
	var cursor: int = 0
	while not pending.is_empty():
		var index: int = pending.pop_back()
		if (
			cursor >= role.size()
			or role[cursor] != index
			or visited.has(index)
			or index < 0
			or index >= policy._owner_scene_nodes.size()
		):
			return false
		visited[index] = true
		cursor += 1
		var record: Variant = policy._owner_scene_nodes[index]
		if (
			not record is Dictionary
			or not record.get("id") is int
			or policy._owner_scene_index.get(record.id) != index
			or not record.get("children") is Array
			or record.get("tree") != true
		):
			return false
		for child_index: int in range(record.children.size() - 1, -1, -1):
			var child: Variant = policy._owner_scene_index.get(record.children[child_index])
			if not child is int:
				return false
			pending.append(child)
	return cursor == role.size()


func _guard_body_covered(request: Dictionary, body: StaticBody3D) -> bool:
	# Called only in the authenticated callback-free tail of this same valid().
	return (
		request.get("complete", false)
		and not request.get("source_breach", false)
		and request.guard == self
		and _context == request.interior
		and _model == request.model
		and _source == request.source
		and _context.owned_integrity_policy() == request.policy
		and request.bodies.get(body.get_instance_id()) == body
	)


func _body_snapshot_valid(body: StaticBody3D, original_bytes: PackedByteArray) -> bool:
	if _context != null:
		var policy: StadiumPoolOwnedIntegrity = _context.owned_integrity_policy()
		if policy != null:
			return policy.valid_body(body)
	return var_to_bytes(StadiumPoolPartyAssetIntegrity.snapshot(body)) == original_bytes

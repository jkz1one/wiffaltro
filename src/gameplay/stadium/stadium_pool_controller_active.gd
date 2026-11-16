class_name StadiumPoolControllerActive
extends RefCounted
## Private, default-disabled ordinary-controller bounded free-flight top-entry subset.
## Any uncertainty latches a decline for this launch; never repairs gameplay state.
# gdlint: disable=max-returns

const SELF_SCRIPT_PATH: String = (
	"res://src/gameplay/stadium/stadium_pool_controller_active.gd"
)
const FIELD_LEASE_SCRIPT_PATH: String = (
	"res://src/gameplay/stadium/stadium_pool_owned_field_lease.gd"
)
const WATER_GUARD_SCRIPT_PATH: String = (
	"res://src/gameplay/stadium/stadium_pool_water_guard.gd"
)

const LAB_PATH: String = "res://src/labs/pitch_bat_lab/pitch_bat_lab.gd"
const FIXTURE_PATH: String = "res://src/tests/stadium_pool_controller_active_test.gd"
const COLUMN: Vector2 = Vector2(12, 18)
var enabled: bool = false
# Explicit private opt-in; legacy vertical controls retain their original path.
var freeflight_enabled: bool = false
var commits: int = 0
var generation: int = 0
var decline: String = ""
var last_commit: Dictionary = {}
var _startup_frame: int = -1
var _startup_state: PackedByteArray
var _startup_waited: bool = false
var _freeflight_launch: bool = false
var _lab: PitchBatLab
var _model: Node3D
var _role: String
var _source: String
var _prepared: StadiumPoolModelPreparation
var _guard: StadiumPoolWaterGuard
var _ball: BattedBallBody
var _state: BallPlayState
var _field: FieldDefinition
var _field_bytes: PackedByteArray
var _tree: Array = []
var _signals: Array = []
var _early_state: PackedByteArray
var _early_position: Vector3
var _early_frame: int = -1
var _last_position: Vector3
var _busy: bool = false
var _foul: bool
var _floor: int
var _aero: Array = []
var _retired: Array[Dictionary] = []
var _bound_profile: StadiumPoolBoundProperty
var _owned_field_lease: StadiumPoolOwnedFieldLease
var _ordinary_router: Callable


func install(lab: PitchBatLab, model: Node3D, role: String, source: String) -> bool:
	if _lab != null or lab == null or lab._batted_ball != null:
		return false
	if lab.get_script() != load(LAB_PATH) or lab.pool_controller_active != null:
		return false
	if lab.get_parent().get_script() == null:
		return false
	if lab.get_parent().get_script().resource_path != FIXTURE_PATH:
		return false
	if lab._match_mode or lab._configured_match != null or lab.has_meta(&"stadium_property"):
		return false
	if (
		lab.global_transform != Transform3D.IDENTITY
		or not _plain_actors(lab)
		or lab.process_physics_priority != 0
		or lab._primary_fielder.process_physics_priority != 0
		or lab.get_parent().process_thread_group != Node.PROCESS_THREAD_GROUP_INHERIT
	):
		return false
	if source != StadiumPoolPartyAssetIntegrity.source_sha256():
		return false
	if not StadiumPoolLabGroundProfile.matches(
		lab.find_child("Ground", true, false) as StaticBody3D
	):
		return false
	_prepared = StadiumPoolModelPreparation.capture(model, role, source)
	if _prepared == null:
		return false
	_lab = lab
	_model = model
	_role = role
	_source = source
	lab.pool_controller_active = self
	return true


# Separate private profile; isolated fixture installation and guards stay intact.
func install_bound(lab: PitchBatLab, property: StadiumPoolBoundProperty) -> bool:
	if _lab != null or lab == null or property == null or lab._batted_ball != null:
		return false
	if lab.get_script() != load(LAB_PATH) or lab.pool_controller_active != null:
		return false
	if not property.valid_owner(lab) or not property.plain_actors(lab):
		return false
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	var prepared: StadiumPoolModelPreparation = StadiumPoolModelPreparation.capture(
		property.pool_model, StadiumPoolContract.LIVE, source
	)
	if prepared == null:
		return false
	_bound_profile = property
	_prepared = prepared
	_lab = lab
	_model = property.pool_model
	_role = StadiumPoolContract.LIVE
	_source = source
	lab.pool_controller_active = self
	return true


func install_owned(lab: PitchBatLab, property: StadiumPoolOwnedProperty) -> bool:
	if _lab != null or lab == null or property == null or lab._batted_ball != null:
		return false
	if lab.get_script() != load(LAB_PATH) or lab.pool_controller_active != null:
		return false
	if not property.valid_owner_full_ledger(lab) or not property.plain_actors(lab):
		return false
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	var prepared: StadiumPoolModelPreparation = StadiumPoolModelPreparation.capture_owned(
		property, lab, source
	)
	if prepared == null:
		return false
	_bound_profile = property
	_prepared = prepared
	_lab = lab
	_model = property.pool_model
	_role = StadiumPoolContract.LIVE
	_source = source
	lab.pool_controller_active = self
	return true


func is_bound_profile() -> bool:
	return _bound_profile != null


func _actors_valid(lab: PitchBatLab) -> bool:
	return (
		_plain_actors(lab)
		if _bound_profile == null
		else (is_instance_valid(_bound_profile) and _bound_profile.plain_actors(lab))
	)


func _profile_valid(full_fields: bool = false) -> bool:
	if (
		get_script() == load(SELF_SCRIPT_PATH)
		and _owned_field_lease != null
	):
		if (
			_owned_field_lease.get_script()
			!= load(FIELD_LEASE_SCRIPT_PATH)
		):
			return false
		if not _owned_field_lease.valid_installation(
			_bound_profile as StadiumPoolOwnedProperty, _lab
		):
			_owned_field_lease.revoke("CONTROLLER_PROFILE_BINDING_CHANGED")
			return false
		if not full_fields:
			return (_bound_profile as StadiumPoolOwnedProperty).valid_owner_leased(
				_lab, _owned_field_lease
			)
		var full_valid: bool = (_bound_profile as StadiumPoolOwnedProperty).valid_owner_full_fields(
			_lab
		)
		if not full_valid:
			_owned_field_lease.revoke("FULL_PROPERTY_BOUNDARY_CHANGED")
		return full_valid
	if _bound_profile == null:
		return not _lab._match_mode and not _lab.has_meta(&"stadium_property")
	if (
		full_fields
		and is_instance_valid(_bound_profile)
		and _bound_profile is StadiumPoolOwnedProperty
	):
		return (_bound_profile as StadiumPoolOwnedProperty).valid_owner_full_fields(_lab)
	return is_instance_valid(_bound_profile) and _bound_profile.valid_owner(_lab)


func bind_ball(lab: PitchBatLab, launch: BattedBallLaunch) -> void:
	if _busy:
		decline = "REENTRANT_LAUNCH"
		return
	if (
		get_script() == load(SELF_SCRIPT_PATH)
		and _owned_field_lease != null
	):
		if (
			_owned_field_lease.get_script()
			!= load(FIELD_LEASE_SCRIPT_PATH)
		):
			return
		if not _owned_field_lease.valid_installation(
			_bound_profile as StadiumPoolOwnedProperty, lab
		):
			decline = "LEASED_LAUNCH_OWNER"
			return
		if (
			not is_instance_valid(lab._batted_ball)
			or (
				lab._batted_ball.get_script()
				!= load("res://src/presentation/ball/batted_ball_body.gd")
			)
			or not is_instance_valid(lab._ball_play_resolver.state)
			or (
				lab._ball_play_resolver.state.get_script()
				!= load("res://src/gameplay/ball_in_play/ball_play_state.gd")
			)
		):
			_owned_field_lease.revoke("CUSTOM_LAUNCH_CHAIN")
			decline = "LEASED_LAUNCH_OWNER"
			return
	if lab != _lab or _ball != null or not _actors_valid(lab):
		decline = "LAUNCH_OWNER"
		return
	generation += 1
	decline = ""
	_early_frame = -1
	_startup_frame = Engine.get_physics_frames()
	_startup_waited = false
	_ball = lab._batted_ball
	_state = lab._ball_play_resolver.state
	_startup_state = var_to_bytes(StadiumPoolWaterGuard._state_parameters(_state))
	_field = lab._ball_play_resolver.field
	_aero = _aero_inputs(_ball)
	_field_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_field))
	_foul = _state.is_foul_play
	_floor = _state.result_floor
	_last_position = launch.position
	_freeflight_launch = freeflight_enabled
	if _freeflight_launch:
		if (
			not _freeflight_path_clear(launch.position, launch.position, _ball.radius_m)
			or not launch.velocity.is_finite()
			or not launch.angular_velocity.is_finite()
		):
			decline = "FREEFLIGHT_LAUNCH_DOMAIN_UNPROVEN"
	elif not column_step(
		launch.position, launch.position, launch.velocity, launch.angular_velocity
	):
		decline = "OUTSIDE_VERTICAL_COLUMN"
	if launch.position.y <= StadiumPoolContract.WATER_HEIGHT + _ball.radius_m:
		decline = "LAUNCH_NOT_ABOVE_WATER"
	if _bound_profile != null:
		if (
			not _profile_valid(true)
			or (
				_bound_profile is StadiumPoolOwnedProperty
				and not (_bound_profile as StadiumPoolOwnedProperty).ledger_boundary_valid(lab)
			)
		):
			decline = "BOUND_LAUNCH_OWNER"
			if (
				get_script() == load(SELF_SCRIPT_PATH)
				and _owned_field_lease != null
			):
				_owned_field_lease.revoke("FULL_LAUNCH_BOUNDARY_CHANGED")
			return
		_ordinary_router = _bound_profile.expected_boundary_router(lab._ball_play_resolver)
		if _ball.physics_contact_router != _ordinary_router or not _ordinary_router.is_valid():
			decline = "BOUND_ORDINARY_ROUTER_MISMATCH"
			return
	elif _ball.physics_contact_router.is_valid():
		decline = "PREEXISTING_ROUTER"
		return
	_ball.physics_contact_router = _sample
	_guard = StadiumPoolWaterGuard.new()
	if not _guard.bind(
		_ball,
		lab._ball_play_resolver,
		_model,
		_role,
		_source,
		_registry(),
		false,
		_sample,
		lab._pitcher_marker,
		0,
		_prepared,
		_ordinary_router,
		_bound_profile.ground_matches if _bound_profile != null else Callable()
	):
		decline = "GUARD_BINDING"
		if (
			get_script() == load(SELF_SCRIPT_PATH)
			and _owned_field_lease != null
		):
			_owned_field_lease.revoke("FULL_GUARD_BINDING_FAILED")
		if _bound_profile != null and _ball.physics_contact_router == _sample:
			_ball.physics_contact_router = _ordinary_router
		return
	_tree = _owned_tree()
	_signals = _signal_inventory()
	if (
		get_script() == load(SELF_SCRIPT_PATH)
		and _owned_field_lease != null
	):
		_guard._owned_field_lease = _owned_field_lease
		if not _owned_field_lease.bind_play(self, _guard):
			decline = "OWNED_FIELD_LAUNCH_LEASE"


func _sample(ball: BattedBallBody, contacts: Array[Dictionary]) -> void:
	if ball != _ball or _busy or not _owned() or not _guard._routing:
		decline = "EARLY_OWNER"
		return
	if _prior_defense_history():
		decline = "PRIOR_DEFENSE_HISTORY_UNSUPPORTED"
		return
	if not contacts.is_empty():
		decline = "CONTACT_HISTORY_UNSUPPORTED"
	if (
		not _freeflight_launch
		and ball.global_transform.basis * ball.hole_axis_ball_local != Vector3.UP
	):
		decline = "AERO_AXIS_LEFT_VERTICAL"
	var current: Vector3 = ball.global_position
	if _freeflight_launch:
		if not _freeflight_path_clear(_last_position, current, _guard._physical_radius):
			decline = "FREEFLIGHT_HISTORY_CLEARANCE_UNPROVEN"
	elif not column_step(_last_position, current, ball.linear_velocity, ball.angular_velocity):
		decline = "PATH_LEFT_VERTICAL_COLUMN"
	if _early_frame == Engine.get_physics_frames():
		decline = "DUPLICATE_EARLY_SAMPLE"
	_last_position = current
	_early_position = current
	_early_state = var_to_bytes(StadiumPoolWaterGuard._state_parameters(_state))
	_early_frame = Engine.get_physics_frames()


func try_resolve(lab: PitchBatLab, previous: Vector3, current: Vector3) -> bool:
	if not enabled or lab != _lab or _role != StadiumPoolContract.LIVE:
		return false
	if _busy or not decline.is_empty():
		return false
	if (
		not _owned()
		or _state.dead
		or _guard.generation != 1
		or _guard._routing
		or _guard._committing
	):
		decline = "STALE_OR_TERMINAL"
		return false
	if _guard._samples < 1:
		if (
			_bound_profile != null
			and not _prior_defense_history()
			and _wait_for_first_bound_sample(previous, current, Engine.get_physics_frames())
		):
			return false
		decline = "STALE_OR_TERMINAL"
		return false
	if _prior_defense_history():
		decline = "PRIOR_DEFENSE_HISTORY_UNSUPPORTED"
		return false
	if _early_frame != Engine.get_physics_frames() or _early_position != current:
		decline = "MISSING_CURRENT_SAMPLE"
		return false
	if var_to_bytes(StadiumPoolWaterGuard._state_parameters(_state)) != _early_state:
		decline = "INTERVENING_STATE_WRITER"
		return false
	if _freeflight_launch:
		if not _freeflight_path_clear(previous, current, _guard._physical_radius):
			decline = "FREEFLIGHT_CONTROLLER_CLEARANCE_UNPROVEN"
			return false
	elif not column_step(previous, current, _ball.linear_velocity, _ball.angular_velocity):
		decline = "CONTROLLER_COLUMN_MISMATCH"
		return false
	if (
		_bound_profile != null
		and (not StadiumBoundaryGraph.crossing(previous, current).is_empty() or current.y < -2.0)
	):
		decline = "ORDINARY_BOUNDARY_PRECEDENCE"
		return false
	if not terminal_planes_excluded(_field, previous, current):
		decline = "EARLIER_SEGMENT_TERMINAL_UNPROVEN"
		return false
	if _state.has_grounded or _state.is_foul_play != _foul or _state.result_floor < _floor:
		decline = "GROUND_FOUL_OR_FLOOR_CHANGED"
		return false
	_floor = _state.result_floor
	var commit_position: Vector3 = current
	var entry_fraction: float = -1.0
	if _freeflight_launch:
		var entry: Dictionary = _freeflight_entry(previous, current, _guard._physical_radius)
		if entry.status != "ENTRY":
			# Only dry no-crossing flight may remain eligible. Any unqualified
			# wet/uncertain crossing permanently closes this launch's authority.
			if entry.reason != "NO_TOP_FACE_CROSSING":
				decline = "FREEFLIGHT_ENTRY_UNPROVEN:" + String(entry.reason)
			return false
		commit_position = entry.position
		entry_fraction = entry.fraction
	else:
		var wet: Dictionary = (
			_guard.sample_owned_lease(current, _guard._physical_radius)
			if (
				get_script() == load(SELF_SCRIPT_PATH)
				and _owned_field_lease != null
			)
			else _guard._context.sample(current, _guard._physical_radius)
		)
		if not wet.valid or wet.tangent_or_uncertain:
			decline = "WATER_BOUNDARY_UNCERTAIN"
			return false
		if not wet.positive_overlap:
			return false
	# A non-null eligible historical helper retains the entire ordinary attempt.
	if not lab._pitcher_attempted and lab._fielding_cooldown_seconds <= 0.0:
		if (
			PitcherDefense.attempt_position(previous, current, lab._pitcher_marker.global_position)
			!= Vector3.INF
		):
			decline = "PITCHER_ATTEMPT_AUTHORITATIVE"
			return false
	if _floor > BallPlayState.ResultFloor.DOUBLE:
		decline = "HIGHER_EARNED_RESULT"
		return false
	# No external signal/callback between final ownership validation and terminal latch.
	if not _owned(true):
		decline = "COMMIT_OWNER_CHANGED"
		return false
	var owned_property: StadiumPoolOwnedProperty = _bound_profile as StadiumPoolOwnedProperty
	if owned_property != null and not owned_property.ledger_boundary_valid(lab):
		decline = "COMMIT_LEDGER_CHANGED"
		if (
			get_script() == load(SELF_SCRIPT_PATH)
			and _owned_field_lease != null
		):
			_owned_field_lease.revoke("COMMIT_LEDGER_CHANGED")
		return false
	var owned_token: StadiumPoolBoundEntitlement = (
		owned_property.entitlement if owned_property != null else null
	)
	_busy = true
	var committed: bool = (
		lab._ball_play_resolver.resolve_owned_pool_water(_state, commit_position, _foul)
		if _bound_profile is StadiumPoolOwnedProperty
		else lab._ball_play_resolver.resolve_pool_water(_state, commit_position, _foul)
	)
	if committed:
		commits += 1
		last_commit = {
			"generation": generation,
			"position": commit_position,
			"foul": _foul,
			"entry_fraction": entry_fraction
		}
	# Resolver signals may execute supported ledger mutations or tear down the owner.
	# Keep the actual ordinary result; never restore or refresh the issued authority.
	if (
		owned_property != null
		and (
			not is_instance_valid(owned_property)
			or _bound_profile != owned_property
			or not is_instance_valid(lab)
			or _lab != lab
			or owned_property.entitlement != owned_token
			or not owned_property.valid_owner_full_ledger(lab)
			or not owned_property.owned_field_boundary_valid(lab)
		)
	):
		decline = "POST_COMMIT_OWNER_CHANGED"
		if (
			get_script() == load(SELF_SCRIPT_PATH)
			and _owned_field_lease != null
		):
			_owned_field_lease.revoke("POST_COMMIT_OWNER_CHANGED")
	_busy = false
	return committed


func _freeflight_path_clear(previous: Vector3, current: Vector3, radius: float) -> bool:
	if _bound_profile is StadiumPoolOwnedProperty:
		var property: StadiumPoolOwnedProperty = _bound_profile as StadiumPoolOwnedProperty
		return StadiumPoolOwnedFreeflight.path_clear(
			property.admitted_pose(), previous, current, radius
		)
	return FreeflightEntry.path_clear(previous, current, radius)


func _freeflight_entry(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
	if _bound_profile is StadiumPoolOwnedProperty:
		var property: StadiumPoolOwnedProperty = _bound_profile as StadiumPoolOwnedProperty
		return StadiumPoolOwnedFreeflight.evaluate(
			property.admitted_pose(), previous, current, radius
		)
	return FreeflightEntry.evaluate(previous, current, radius)


func _prior_defense_history() -> bool:
	# Ordinary defender bobbles deflect motion without a rigid-body contact batch.
	# This contact-free subset cannot requalify that changed trajectory later.
	return _state.defender_touched or _state.bobbled or _state.caught


func is_committing() -> bool:
	return _busy


func _wait_for_first_bound_sample(previous: Vector3, current: Vector3, frame: int) -> bool:
	# Called only after normal ownership/dead/generation/reentrancy/defense checks.
	# One stationary first-frame wait is readiness, never a water or gameplay action.
	if (
		_bound_profile == null
		or not decline.is_empty()
		or _startup_waited
		or frame != _startup_frame + 1
		or _early_frame != -1
		or _guard._samples != 0
		or _guard.generation != 1
		or _guard._generation_invalid
		or _guard._routing
		or _guard._committing
		or not _guard.errors.is_empty()
		or not _guard._history_unproven.is_empty()
		or _state.dead
		or previous != _guard._launch_position
		or current != _guard._launch_position
		or _ball.global_position != _guard._launch_position
		or _ball.linear_velocity != _guard._launch_velocity
		or _ball.angular_velocity != _guard._launch_spin
		or var_to_bytes(StadiumPoolWaterGuard._state_parameters(_state)) != _startup_state
	):
		return false
	_startup_waited = true
	return true


func release_ball() -> bool:
	if _busy:
		decline = "REENTRANT_CLEANUP"
		return false
	if (
		get_script() == load(SELF_SCRIPT_PATH)
		and _owned_field_lease != null
	):
		_owned_field_lease.retire_play(self, _guard)
	if is_instance_valid(_ball):
		_retired.append(
			{"body": weakref(_ball), "rows": StadiumPoolControllerShadow._tree_inventory(_ball)}
		)
	if _guard != null:
		_guard.detach()
	if is_instance_valid(_ball) and _ball.physics_contact_router == _sample:
		_ball.physics_contact_router = _ordinary_router
	_ordinary_router = Callable()
	_guard = null
	_ball = null
	_state = null
	_early_frame = -1
	_startup_frame = -1
	_startup_state = PackedByteArray()
	_startup_waited = false
	_tree.clear()
	_signals.clear()
	return true


func detach() -> void:
	if not release_ball():
		return
	if is_instance_valid(_lab) and _lab.pool_controller_active == self:
		_lab.pool_controller_active = null
	_lab = null
	_bound_profile = null
	enabled = false


func _owned(full_fields: bool = false) -> bool:
	if (
		get_script() == load(SELF_SCRIPT_PATH)
		and _owned_field_lease != null
	):
		return _owned_leased(full_fields)
	return (
		is_instance_valid(_lab)
		and is_instance_valid(_ball)
		and _guard != null
		and freeflight_enabled == _freeflight_launch
		and _lab.pool_controller_active == self
		and _lab._batted_ball == _ball
		and is_instance_valid(_lab._ball_play_resolver)
		and _lab._ball_play_resolver.state == _state
		and _lab._ball_play_resolver.field == _field
		and not _guard._generation_invalid
		and _guard.valid()
		and _actors_valid(_lab)
		and _lab.global_transform == Transform3D.IDENTITY
		and _profile_valid(full_fields)
		and not _lab._debug_paused
		and _lab.is_physics_processing()
		and _lab._primary_fielder.is_physics_processing()
		and _field_bytes == var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_field))
		and not _tree.is_empty()
		and _tree == _owned_tree()
		and _aero == _aero_inputs(_ball)
		and _signals == _signal_inventory()
		and _connections_exact()
		and _guard.observed.get_connections().is_empty()
	)


func _owned_leased(full_fields: bool = false) -> bool:
	if (
		get_script() != load(SELF_SCRIPT_PATH)
		or _owned_field_lease == null
	):
		return false
	if (
		_owned_field_lease.get_script()
		!= load(FIELD_LEASE_SCRIPT_PATH)
	):
		return false
	if (
		not is_instance_valid(_lab)
		or _lab.get_script() != load(LAB_PATH)
		or not is_instance_valid(_bound_profile)
		or (
			_bound_profile.get_script()
			!= load("res://src/presentation/stadium/stadium_pool_owned_property.gd")
		)
		or _guard == null
		or _guard.get_script() != load(WATER_GUARD_SCRIPT_PATH)
		or not is_instance_valid(_lab._ball_play_resolver)
		or (
			_lab._ball_play_resolver.get_script()
			!= load("res://src/gameplay/ball_in_play/ball_play_resolver.gd")
		)
	):
		_owned_field_lease.revoke("CUSTOM_ACTIVE_CHAIN")
		return false
	var owned: bool = (
		is_instance_valid(_lab)
		and is_instance_valid(_ball)
		and _guard != null
		and freeflight_enabled == _freeflight_launch
		and _lab.pool_controller_active == self
		and _lab._batted_ball == _ball
		and is_instance_valid(_lab._ball_play_resolver)
		and _lab._ball_play_resolver.state == _state
		and _lab._ball_play_resolver.field == _field
		and not _guard._generation_invalid
		and _guard_valid(full_fields)
		and _actors_valid(_lab)
		and _lab.global_transform == Transform3D.IDENTITY
		and _profile_valid(full_fields)
		and not _lab._debug_paused
		and _lab.is_physics_processing()
		and _lab._primary_fielder.is_physics_processing()
		and (
			(_owned_field_lease != null and not full_fields)
			or _field_bytes == var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_field))
		)
		and not _tree.is_empty()
		and ((_owned_field_lease != null and not full_fields) or _tree == _owned_tree())
		and _aero == _aero_inputs(_ball)
		and _signals == _signal_inventory()
		and _connections_exact()
		and _guard.observed.get_connections().is_empty()
	)

	if not owned and _owned_field_lease != null:
		_owned_field_lease.revoke("CONTROLLER_OWNER_CHANGED")
	return owned


func _guard_valid(full: bool) -> bool:
	# Reached only by exact _owned_leased. Reject custom Guard dispatch before any
	# reduced entry is called; legacy _owned still calls its original virtual valid.
	if (
		_guard == null
		or _guard.get_script() != load(WATER_GUARD_SCRIPT_PATH)
	):
		return false
	if _owned_field_lease == null:
		return _guard.valid()
	if full:
		# Active Guard original shape-resource RID and owner-map seals are mandatory.
		return _owned_field_lease.valid_play(self, _guard) and _guard.valid()
	return _guard.valid_owned_lease(_owned_field_lease)


func _owned_tree() -> Array:
	var ignored: Dictionary = {}
	var remaining: Array[Dictionary] = []
	for retired: Dictionary in _retired:
		var body: Node = retired.body.get_ref()
		if body == null:
			continue
		remaining.append(retired)
		if (
			body.get_parent() != _lab
			or not body.is_queued_for_deletion()
			or StadiumPoolControllerShadow._tree_inventory(body) != retired.rows
		):
			return []
		for row: Array in retired.rows:
			ignored[row[0]] = true
	_retired = remaining
	var result: Array = []
	for row: Array in StadiumPoolControllerShadow._tree_inventory(_lab):
		if not ignored.has(row[0]):
			var node: Node = instance_from_id(row[0]) as Node
			if node == null or node.is_queued_for_deletion():
				return []
			result.append(row)
	return result


static func _aero_inputs(ball: BattedBallBody) -> Array:
	return [
		ball.aero_drag_coefficient,
		ball.aero_magnus_scale,
		ball.aero_perforation_force_scale,
		ball.hole_axis_ball_local
	]


func _signal_inventory() -> Array:
	var rows: Array = [
		_ball.get_signal_connection_list(&"launch_started"),
		_ball.get_signal_connection_list(&"surface_contact"),
		_lab._ball_play_resolver.get_signal_connection_list(&"play_resolved")
	]
	if _bound_profile != null:
		rows.append(_ball.get_signal_connection_list(&"body_entered"))
		rows.append(_ball.get_signal_connection_list(&"tree_exited"))
	return rows


func _connections_exact() -> bool:
	var rows: Array = _signal_inventory()
	if _bound_profile != null:
		if not _profile_valid() or _guard._ordinary_router != _ordinary_router:
			return false
		if rows[3].size() != 2 or rows[4].size() != 1:
			return false
		if (
			rows[3][0].flags != 0
			or rows[3][0].callable != _ball._on_body_entered
			or rows[3][1].flags != 0
			or (
				rows[3][1].callable
				!= _bound_profile.expected_body_callback(_ball, _lab._ball_play_resolver)
			)
			or rows[4][0].flags != CONNECT_ONE_SHOT
			or rows[4][0].callable != _bound_profile.expected_exit_callback(_ball)
		):
			return false
	return (
		rows[0].size() == 1
		and rows[0][0].flags == 0
		and rows[0][0].callable == _guard._on_launch
		and rows[1].size() == 1
		and rows[1][0].flags == 0
		and rows[1][0].callable == _lab._on_batted_surface_contact
		and rows[2].size() == 1
		and rows[2][0].flags == 0
		and rows[2][0].callable == _lab._on_ball_play_resolved
	)


func _registry() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for node: Node in _lab.find_children("*", "StaticBody3D", true, false):
		var surface: StringName = node.get_meta(&"ball_surface", &"")
		var kind: String = (
			"ground" if surface == &"ground" else "terminal" if surface == &"back_wall" else "solid"
		)
		rows.append({"body": node, "kind": kind, "label": String(node.name)})
	if _model != null and _bound_profile == null:
		for body: Node in _model.get_node("Collision").get_children():
			rows.append({"body": body, "kind": "solid", "label": String(body.name)})
	return rows


static func _plain_actors(lab: PitchBatLab) -> bool:
	return StadiumPoolControllerShadow._plain_actor_setup(lab)


static func column_step(
	previous: Vector3, current: Vector3, velocity: Vector3, spin: Vector3
) -> bool:
	return (
		previous.is_finite()
		and current.is_finite()
		and velocity.is_finite()
		and Vector2(previous.x, previous.z) == COLUMN
		and Vector2(current.x, current.z) == COLUMN
		and current.y <= previous.y
		and current.y > 0.0
		and velocity.x == 0.0
		and velocity.z == 0.0
		and velocity.y < 0.0
		and spin == Vector3.ZERO
	)


static func terminal_planes_excluded(
	field: FieldDefinition, previous: Vector3, current: Vector3
) -> bool:
	return (
		field != null
		and is_finite(field.back_wall_z_m)
		and is_finite(field.dead_ball_z_m)
		and previous.z < field.back_wall_z_m
		and current.z < field.back_wall_z_m
		and previous.z < field.dead_ball_z_m
		and current.z < field.dead_ball_z_m
		and previous.y > 0.0
		and current.y > 0.0
	)


class FreeflightEntry:
	extends RefCounted
	## A bounded, contact-free DISCRETE segment, not an arbitrary curved-path solver.
	## Caller owns the paired receipts, model binding, contact and terminal precedence.
	## No callbacks, body mutation, resolver call, tolerance-based trajectory comparison,
	## ideal-cylinder substitution, side entry, reflected path, or dry-to-dry award.

	const SCOPE: String = "CONTACT_FREE_DISCRETE_INTERIOR_TOP_FACE_ONLY"
	const MIN_RADIUS_M: float = 0.015625
	const MAX_RADIUS_M: float = 0.125
	const MAX_STEP_M: float = 4.0
	# Explicit conservative geometric exclusion, never a trajectory-comparison tolerance.
	# At |world x,z| <= 64 and |y| <= 16, a binary32 coordinate rounds by <= 2^-18.
	# Eight such units cover the final Vector3 construction and clipped-point rounding.
	const CLEARANCE_PAD_M: float = 0.000030517578125
	# Scalar half-plane products stay below 2^10 in this domain. This dyadic guard
	# exceeds accumulated binary64 arithmetic error; edge L1 norm avoids sqrt error.
	const SCALAR_GUARD: float = 0.00000000023283064365386962890625
	const WITNESS_DEPTH_M: float = 0.00004

	static func bounded_point(point: Vector3) -> bool:
		return (
			point.is_finite()
			and absf(point.x) <= 64.0
			and absf(point.y) <= 16.0
			and absf(point.z) <= 64.0
		)

	static func bounded_radius(radius: float) -> bool:
		return is_finite(radius) and radius >= MIN_RADIUS_M and radius <= MAX_RADIUS_M

	static func path_clear(previous: Vector3, current: Vector3, radius: float) -> bool:
		if not bounded_point(previous) or not bounded_point(current) or not bounded_radius(radius):
			return false
		for axis: int in range(3):
			if absf(float(current[axis]) - float(previous[axis])) > MAX_STEP_M:
				return false
		# Ground/underside paths are unsupported even if they later reach a wet endpoint.
		if minf(previous.y, current.y) <= radius + CLEARANCE_PAD_M:
			return false
		if not ladder_clear(previous, current, radius):
			return false
		var cutoff: float = StadiumPoolContract.WALL_HEIGHT + radius + CLEARANCE_PAD_M
		if minf(previous.y, current.y) > cutoff:
			return true
		var low_start: Vector3 = previous
		var low_end: Vector3 = current
		if previous.y > cutoff:
			low_start = point_at(
				previous, current, (previous.y - cutoff) / (previous.y - current.y)
			)
		elif current.y > cutoff:
			low_end = point_at(previous, current, (cutoff - previous.y) / (current.y - previous.y))
		# Every half-plane is affine along the chord. Endpoint clearance certifies
		# the entire below-wall-top portion, including both rising and falling steps.
		return interior_clear(low_start, radius) and interior_clear(low_end, radius)

	static func ladder_clear(previous: Vector3, current: Vector3, radius: float) -> bool:
		# Authored fixed-pose ladder AABB, expanded for the whole sphere and rounding.
		# Swept chord AABB disjointness is conservative: uncertain overlap declines.
		var lower: Vector3 = Vector3(14.1, 0.0, 17.65)
		var upper: Vector3 = Vector3(14.45, 1.45, 18.35)
		var grow: float = radius + CLEARANCE_PAD_M
		for axis: int in range(3):
			if (
				maxf(previous[axis], current[axis]) < float(lower[axis]) - grow
				or minf(previous[axis], current[axis]) > float(upper[axis]) + grow
			):
				return true
		return false

	static func interior_clear(world: Vector3, radius: float) -> bool:
		if not bounded_point(world) or not bounded_radius(radius):
			return false
		var polygon: PackedVector2Array = StadiumPoolInteriorV2.vertices()
		if polygon.size() != StadiumPoolContract.SEGMENTS:
			return false
		var point_x: float = float(world.x) - 12.0
		var point_z: float = float(world.z) - 18.0
		for index: int in range(polygon.size()):
			var start: Vector2 = polygon[index]
			var finish: Vector2 = polygon[(index + 1) % polygon.size()]
			# Component extraction promotes authored binary32 vertices to binary64.
			# Do not replace these scalar operations with Vector2 cross/dot/length.
			var edge_x: float = float(finish.x) - float(start.x)
			var edge_z: float = float(finish.y) - float(start.y)
			var cross: float = edge_x * (point_z - start.y) - edge_z * (point_x - start.x)
			var required: float = (radius + CLEARANCE_PAD_M) * (absf(edge_x) + absf(edge_z))
			if not is_finite(cross) or cross <= required + SCALAR_GUARD:
				return false
		return true

	static func point_at(previous: Vector3, current: Vector3, fraction: float) -> Vector3:
		# GDScript scalar float is binary64; Vector3's constructor rounds only once.
		# Vector3.lerp or vector * fraction would narrow intermediate values to real_t.
		return Vector3(
			float(previous.x) + (float(current.x) - float(previous.x)) * fraction,
			float(previous.y) + (float(current.y) - float(previous.y)) * fraction,
			float(previous.z) + (float(current.z) - float(previous.z)) * fraction
		)

	static func evaluate(previous: Vector3, current: Vector3, radius: float) -> Dictionary:
		if not path_clear(previous, current, radius):
			return declined("PATH_DOMAIN_OR_SOLID_CLEARANCE_UNPROVEN")
		var top: float = StadiumPoolContract.WATER_HEIGHT + radius
		if current.y >= top:
			return declined("NO_TOP_FACE_CROSSING")
		if previous.y <= top + StadiumPoolInteriorV2.EPSILON_M or current.y >= previous.y:
			return declined("NO_DRY_ABOVE_WATER_DESCENT")
		var endpoint: Dictionary = StadiumPoolInteriorV2.sample_local(to_local(current), radius)
		if not endpoint.valid or not endpoint.positive_overlap:
			return declined("ENDPOINT_NOT_POSITIVE_OVERLAP")
		var descent: float = float(previous.y) - float(current.y)
		var tangent_fraction: float = (float(previous.y) - top) / descent
		var fraction: float = (float(previous.y) - (top - WITNESS_DEPTH_M)) / descent
		if not (0.0 < tangent_fraction and tangent_fraction < fraction and fraction < 1.0):
			return declined("NO_INTERIOR_POSITIVE_WITNESS_BEFORE_ENDPOINT")
		var witness: Vector3 = point_at(previous, current, fraction)
		if not witness.is_finite() or witness.y <= current.y or witness.y >= top:
			return declined("WITNESS_ROUNDING_OR_RANGE")
		var sample: Dictionary = StadiumPoolInteriorV2.sample_local(to_local(witness), radius)
		if not interior_clear(witness, radius) or not sample.valid or not sample.positive_overlap:
			return declined("WITNESS_NOT_AUTHORED_POSITIVE_OVERLAP")
		return {
			"status": "ENTRY",
			"reason": "NORMALIZED_TOP_FACE_POSITIVE_WITNESS",
			"fraction": fraction,
			"tangent_fraction": tangent_fraction,
			"position": witness,
			"scope": SCOPE
		}

	static func to_local(world: Vector3) -> Vector3:
		return Vector3(float(world.x) - 12.0, world.y, float(world.z) - 18.0)

	static func declined(reason: String) -> Dictionary:
		return {
			"status": "DECLINED",
			"reason": reason,
			"fraction": -1.0,
			"tangent_fraction": -1.0,
			"position": Vector3.INF,
			"scope": SCOPE
		}

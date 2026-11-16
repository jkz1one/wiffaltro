class_name StadiumPoolControllerShadow
extends RefCounted
## Private authenticated lifecycle observation. It has no water award authority.
# gdlint: disable=max-public-methods,max-returns,max-file-lines

const VERSION: StringName = &"POOL-CONTROLLER-SHADOW-v1"
const FORWARDER: String = "res://src/tests/helpers/pool_controller_shadow_lab.gd"
const BALL: Script = preload("res://src/presentation/ball/batted_ball_body.gd")
const STATE_SCRIPT: Script = preload("res://src/gameplay/ball_in_play/ball_play_state.gd")
var records: Array[Dictionary] = []
var unsupported: Array[Dictionary] = []
var errors: Array[String] = []
var receipts: Array[Dictionary] = []
var generation: int = 0
var phase: StringName = &"UNBOUND"
var writer: PoolControllerWriterLedger = PoolControllerWriterLedger.new()
var guard: StadiumPoolWaterGuard
var _lab: PitchBatLab
var _model: Node3D
var _role: String
var _source: String
var _ball: BattedBallBody
var _state: BallPlayState
var _pitcher: Node3D
var _primary: FielderController
var _lab_parent: Node
var _ball_ready: Callable
var _launching: bool = false
var _in_controller: bool = false
var _in_pitcher: bool = false
var _routing: bool = false
var _revoked: bool = false
var _serial: int = 0
var _last_frame: int = -1
var _ticket: Dictionary = {}
var _entry: Dictionary = {}
var _certificate: Dictionary = {}
var _launch_data: BattedBallLaunch
var _inventory: Array = []
var _connections: Array = []
var _scene_connections: Array = []
var _foul: bool
var _guard_generation: int = 0
var _prepared_model: StadiumPoolModelPreparation
var _prepared_lab: PitchBatLab
var _resolver: BallPlayResolver
var _launch_values: Array = []
var _ready_pitcher_pose: Transform3D
var _pitcher_calls: int = 0
var _expected_pitcher_calls: int = 0
var _expected_history: Vector3
var _ready_state: PackedByteArray
var _primary_inputs: Array = []
var _field: FieldDefinition
var _field_bytes: PackedByteArray


func prepare(lab: PitchBatLab, model: Node3D, role: String, source: String) -> bool:
	if phase != &"UNBOUND" or _prepared_lab != null or lab == null:
		return false
	var ground: StaticBody3D = lab.find_child("Ground", true, false) as StaticBody3D
	if not StadiumPoolLabGroundProfile.matches(ground):
		return false
	_prepared_model = StadiumPoolModelPreparation.capture(model, role, source)
	if _prepared_model == null:
		return false
	_prepared_lab = lab
	return true


func install(lab: PitchBatLab, model: Node3D, role: String, source: String) -> bool:
	if phase != &"UNBOUND" or lab == null or not lab.is_inside_tree():
		return false
	if (
		_prepared_lab != lab
		or _prepared_model == null
		or not _prepared_model.valid(model, role, source)
	):
		return false
	if lab.get_script().resource_path != FORWARDER or lab._batted_ball != null:
		return false
	if lab._match_mode or lab._configured_match != null:
		return false
	if lab.has_meta(&"stadium_property") or lab.global_transform != Transform3D.IDENTITY:
		return false
	if source != StadiumPoolPartyAssetIntegrity.source_sha256() or not _sources_exact():
		return false
	if role not in [StadiumPoolContract.LIVE, StadiumPoolContract.SCENERY, "NO_POOL"]:
		return false
	if not _plain_actor_setup(lab):
		return false
	var ground: StaticBody3D = lab.find_child("Ground", true, false) as StaticBody3D
	if not StadiumPoolLabGroundProfile.matches(ground):
		return false
	_lab = lab
	_lab_parent = lab.get_parent()
	_model = model
	_role = role
	_source = source
	_pitcher = lab._pitcher_marker
	_primary = lab._primary_fielder
	lab.set("pool_shadow", self)
	lab.child_entered_tree.connect(_child_entered)
	phase = &"AWAITING_BIRTH"
	_record(
		"installed",
		{"active_awards": false, "ground_source": StadiumPoolLabGroundProfile.SOURCE_SHA}
	)
	return true


func launch_enter(lab: PitchBatLab, launch: BattedBallLaunch) -> void:
	if lab != _lab or phase != &"AWAITING_BIRTH" or _launching or _revoked:
		_reject("LAUNCH_OWNER_OR_PHASE_INVALID")
		return
	_launching = true
	_launch_data = launch
	_launch_values = _launch_snapshot(launch)
	_record("launch.enter", {"position": launch.position, "velocity": launch.velocity})


func _child_entered(child: Node) -> void:
	if not child is BattedBallBody:
		return
	if _revoked or not _launching or phase != &"AWAITING_BIRTH" or _ball != null:
		_reject("DUPLICATE_OR_UNOWNED_BIRTH")
		return
	var body: BattedBallBody = child as BattedBallBody
	if body != _lab._batted_ball or body.get_script() != BALL or body.is_node_ready():
		_reject("BODY_BIRTH_IDENTITY_INVALID")
		return
	_ball = body
	_ball_ready = _ready_body.bind(body)
	body.ready.connect(_ball_ready, CONNECT_ONE_SHOT)
	body.tree_exiting.connect(_body_exiting)
	_record("body.entered", {"ready": body.is_node_ready(), "started": body._started})


func _ready_body(body: BattedBallBody) -> void:
	if _revoked or body != _ball or not _launching or phase != &"AWAITING_BIRTH":
		_reject("READY_OWNER_OR_PHASE_INVALID")
		return
	if body.get_parent() != _lab or body._started or body.freeze or body.is_queued_for_deletion():
		_reject("READY_FRESH_LIFECYCLE_INVALID")
		return
	if body.physics_contact_router.is_valid():
		_reject("PREEXISTING_ROUTER_UNSUPPORTED")
		return
	body.physics_contact_router = _early_sample
	guard = StadiumPoolWaterGuard.new()
	var registry: Array[Dictionary] = _registry()
	if not guard.bind(
		body,
		_lab._ball_play_resolver,
		_model,
		_role,
		_source,
		registry,
		false,
		_early_sample,
		_pitcher,
		0,
		_prepared_model
	):
		if body.physics_contact_router == _early_sample:
			body.physics_contact_router = Callable()
		_reject("READY_GUARD_BINDING_REJECTED")
		return
	_resolver = _lab._ball_play_resolver
	_state = _resolver.state
	if _state == null or _state.get_script() != STATE_SCRIPT:
		_reject("RESOLVER_STATE_SCRIPT_INVALID")
		return
	_ready_state = var_to_bytes(StadiumPoolWaterGuard._state_parameters(_state))
	_primary_inputs = _primary_configuration(_primary)
	_field = _resolver.field
	_field_bytes = var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_field))
	body.launch_started.connect(_launch_signal)
	_ready_pitcher_pose = _pitcher.global_transform
	_inventory = _tree_inventory(_lab)
	_connections = _signal_inventory()
	phase = &"READY_BOUND"
	_record(
		"body.ready_bound",
		{"shape_count": body.get_shape_owners().size(), "started": body._started}
	)


func _launch_signal(position: Vector3) -> void:
	if _revoked or not _launching or phase != &"READY_BOUND" or _routing:
		_reject("LAUNCH_SIGNAL_OWNER_OR_PHASE_INVALID")
		return
	if position != _launch_data.position or not guard.valid() or guard.generation != 1:
		_reject("PUBLIC_LAUNCH_BINDING_INVALID")
		return
	generation += 1
	_guard_generation = guard.generation
	_foul = _state.is_foul_play
	phase = &"LAUNCHED_PENDING_HISTORY"
	_record(
		"launch.signal",
		{
			"position": position,
			"velocity": _ball.linear_velocity,
			"history_initialization_complete": false
		}
	)


func launch_return(lab: PitchBatLab, launch: BattedBallLaunch) -> void:
	if _revoked:
		return
	if (
		lab != _lab
		or launch != _launch_data
		or not _launching
		or phase != &"LAUNCHED_PENDING_HISTORY"
	):
		_reject("LAUNCH_RETURN_OWNER_OR_PHASE_INVALID")
		return
	if not is_instance_valid(_state) or _state.get_script() != STATE_SCRIPT:
		_reject("LAUNCH_STATE_SCRIPT_MUTATED")
		return
	if var_to_bytes(StadiumPoolWaterGuard._state_parameters(_state)) != _ready_state:
		_reject("LAUNCH_RESOLVER_STATE_MUTATED")
		return
	if not is_instance_valid(_primary) or _primary_configuration(_primary) != _primary_inputs:
		_reject("LAUNCH_PRIMARY_CONFIGURATION_MUTATED")
		return
	if _launch_snapshot(launch) != _launch_values or not _plain_actor_setup(lab):
		_reject("LAUNCH_REQUEST_OR_ACTOR_MUTATED")
		return
	if (
		_lab._pitcher_marker != _pitcher
		or _lab._primary_fielder != _primary
		or _lab._ball_play_resolver != _resolver
	):
		_reject("LAUNCH_OBJECT_IDENTITY_MUTATED")
		return
	if _inventory != _tree_inventory(_lab) or _connections != _signal_inventory():
		_reject("LAUNCH_CALLBACK_OR_TOPOLOGY_MUTATED")
		return
	if _pitcher.global_transform != _ready_pitcher_pose:
		_reject("LAUNCH_PITCHER_POSE_MUTATED")
		return
	if (
		_ball.global_position != launch.position
		or _ball.basis != Basis(launch.orientation)
		or not _ball._started
		or _ball.freeze
		or _ball.sleeping
		or _ball.is_queued_for_deletion()
	):
		_reject("LAUNCH_BODY_POSTCONDITION_INVALID")
		return
	if (
		not _primary.active
		or _primary.stationary
		or _primary.first_step != Vector3.ZERO
		or _primary._play_elapsed_seconds != 0
	):
		_reject("LAUNCH_PRIMARY_FLAGS_INVALID")
		return
	if (
		_primary.global_position != _primary.anchor_position
		or _primary.target_position != _primary.anchor_position
	):
		_reject("LAUNCH_PRIMARY_SEED_INVALID")
		return
	if not guard.valid() or _lab._previous_batted_position != launch.position:
		_reject("LAUNCH_RETURN_HISTORY_INVALID")
		return
	if (
		_ball.linear_velocity != launch.velocity
		or _ball.angular_velocity != launch.angular_velocity
	):
		_reject("PUBLIC_LAUNCH_VELOCITY_LOST")
		return
	if _state != _lab._ball_play_resolver.state or _state.is_foul_play != launch.is_foul:
		_reject("LAUNCH_STATE_INVALID")
		return
	if (
		_lab._primary_attempts != 0
		or _lab._pitcher_attempted
		or _lab._fielding_cooldown_seconds != 0
	):
		_reject("LAUNCH_CONTROLLER_SEED_INVALID")
		return
	_launching = false
	phase = &"LIVE_INITIALIZED"
	_expected_history = launch.position
	_inventory = _tree_inventory(_lab)
	_connections = _signal_inventory()
	_scene_connections = _lab.get_tree().get_signal_connection_list(&"physics_frame")
	_record(
		"launch.sealed",
		{
			"previous": _lab._previous_batted_position,
			"pitcher": _pitcher.global_position,
			"primary": _primary.global_position,
			"velocity": _ball.linear_velocity,
			"history_initialization_complete": true
		}
	)

	writer.bind(self)


func valid() -> bool:
	if _revoked or phase != &"LIVE_INITIALIZED" or not is_instance_valid(_lab):
		return false
	if _lab.get_parent() != _lab_parent or _lab.global_transform != Transform3D.IDENTITY:
		return false
	if _lab.get_script().resource_path != FORWARDER or _lab.get("pool_shadow") != self:
		return false
	if _lab._match_mode or _lab.has_meta(&"stadium_property") or not _plain_actor_setup(_lab):
		return false
	if _lab._pitcher_marker != _pitcher or _lab._primary_fielder != _primary:
		return false
	if (
		_lab._batted_ball != _ball
		or _lab._ball_play_resolver != _resolver
		or _resolver.state != _state
	):
		return false
	if (
		_resolver.field != _field
		or var_to_bytes(StadiumPoolPartyAssetIntegrity._value(_field)) != _field_bytes
	):
		return false
	if _primary_configuration(_primary) != _primary_inputs:
		return false
	if _state.get_script() != STATE_SCRIPT:
		return false
	if guard == null or not guard.valid() or guard.generation != _guard_generation:
		return false
	if _state.is_foul_play != _foul or _ball.is_queued_for_deletion():
		return false
	if _connections != _signal_inventory():
		return false
	if _scene_connections != _lab.get_tree().get_signal_connection_list(&"physics_frame"):
		return false
	return _state.dead or _inventory == _tree_inventory(_lab)


func _early_sample(body: BattedBallBody, contacts: Array[Dictionary]) -> void:
	if _routing or _in_controller or _revoked or body != _ball or not valid():
		_reject("EARLY_SAMPLE_OWNER_OR_REENTRANCY_INVALID")
		return
	if _lab._previous_batted_position != _expected_history:
		_unsupported(
			"EARLY_TO_CONTROLLER_CLOSURE_UNPROVEN", {"detail": "UNOWNED_HISTORY_BEFORE_SAMPLE"}
		)
		_reject("UNOWNED_HISTORY_BEFORE_SAMPLE")
		return
	if not _ticket.is_empty():
		_reject("DUPLICATE_EARLY_TICKET")
		return
	_routing = true
	_ticket = {
		"generation": generation,
		"serial": _serial + 1,
		"frame": Engine.get_physics_frames(),
		"previous": _lab._previous_batted_position,
		"current": body.global_position,
		"pitcher": _pitcher.global_position,
		"primary": _primary.global_position,
		"state_dead": _state.dead,
		"velocity_at_router_untrusted_for_future_controller": body.linear_velocity,
		"contacts": contacts.size()
	}
	_record("early.sample", _ticket)
	writer.early(contacts, records.size() - 1)
	_routing = false


func controller_enter(lab: PitchBatLab, delta: float) -> void:
	if phase != &"LIVE_INITIALIZED" and not _revoked:
		return
	if _revoked:
		return
	if lab != _lab or _in_controller or _in_pitcher or _routing or not valid():
		_reject("CONTROLLER_OWNER_OR_REENTRANCY_INVALID")
		return
	if lab._previous_batted_position != _expected_history:
		_unsupported(
			"EARLY_TO_CONTROLLER_CLOSURE_UNPROVEN", {"detail": "UNOWNED_HISTORY_BEFORE_CONTROLLER"}
		)
		_reject("UNOWNED_HISTORY_BEFORE_CONTROLLER")
		return
	if _last_frame == Engine.get_physics_frames():
		_reject("DUPLICATE_CONTROLLER_PASS")
		return
	_last_frame = Engine.get_physics_frames()
	_serial += 1
	_in_controller = true
	_pitcher_calls = 0
	_expected_pitcher_calls = 0 if _state.dead or lab._debug_paused else 1
	_entry = {
		"serial": _serial,
		"generation": generation,
		"previous": lab._previous_batted_position,
		"current": _ball.global_position,
		"pitcher": _pitcher.global_position,
		"primary": _primary.global_position,
		"delta": delta,
		"velocity": _ball.linear_velocity,
		"dead": _state.dead,
		"paused": lab._debug_paused,
		"pitcher_attempted": lab._pitcher_attempted,
		"cooldown_seconds": lab._fielding_cooldown_seconds
	}
	var ticket_matches: bool = not _ticket.is_empty()
	for key: String in ["generation", "serial", "previous", "current", "pitcher", "primary"]:
		ticket_matches = ticket_matches and _ticket.get(key) == _entry.get(key)
	ticket_matches = ticket_matches and _ticket.get("frame") == Engine.get_physics_frames()
	_entry["early_ticket_exact"] = ticket_matches
	if not ticket_matches:
		_unsupported("EARLY_TO_CONTROLLER_CLOSURE_UNPROVEN", {"ticket": _ticket.duplicate(true)})
	_ticket.clear()
	var inputs: Dictionary = {
		"pitcher_attempted": lab._pitcher_attempted,
		"defender_touched": _state.defender_touched,
		"cooldown_seconds": lab._fielding_cooldown_seconds,
		"elapsed_seconds": _state.elapsed_seconds,
		"delta": delta,
		"move_speed_mps":
		(
			lerpf(3.6, 4.6, float(MatchLabSupport.pitcher_fielding_rating(lab)) / 10.0)
			* PitchBatLabDefenseSupport.gear_factor(lab, "speed")
		),
		"velocity": _ball.linear_velocity,
		"velocity_provenance": "controller_entry_observed"
	}
	_entry["defender_touched"] = inputs.defender_touched
	_entry["elapsed_seconds"] = inputs.elapsed_seconds
	_entry["move_speed_mps"] = inputs.move_speed_mps
	_certificate = StadiumPoolPitcherCapV1.evaluate(
		_entry.previous, _entry.current, _entry.pitcher, _entry.primary, inputs
	)
	_certificate["early_ticket_exact"] = ticket_matches
	_certificate["phase_closure_qualified"] = false
	_certificate["active_awards"] = false
	_record("controller.enter", _entry)
	_record("controller.numeric_shadow", _certificate)
	if not _certificate.supported:
		_unsupported(String(_certificate.reason), {})


func pitcher_enter(lab: PitchBatLab, previous: Vector3, current: Vector3) -> void:
	if _revoked:
		return
	if lab != _lab or not _in_controller or _in_pitcher or _pitcher_calls != 0 or not valid():
		_reject("PITCHER_OWNER_OR_PHASE_INVALID")
		return
	if previous != _entry.previous or current != _entry.current or _entry.dead or _entry.paused:
		_reject("PITCHER_HISTORICAL_SEGMENT_CHANGED")
		return
	_in_pitcher = true
	_pitcher_calls += 1
	var mirror_pitcher: Vector3 = _pitcher.global_position
	var mirror_attempted: bool = lab._pitcher_attempted
	var mirror_cooldown: float = lab._fielding_cooldown_seconds
	var actual: Vector3 = PitcherDefense.attempt_position(previous, current, mirror_pitcher)
	writer.capture_mirror(
		previous, current, mirror_pitcher, actual, mirror_attempted, mirror_cooldown
	)
	var displacement: float = _pitcher.global_position.distance_to(_entry.pitcher)
	var bound_holds: bool = (
		not _certificate.has_displacement_bound
		or (displacement <= float(_certificate.displacement_upper_m))
	)
	var actual_excluded: bool = (
		_entry.pitcher_attempted or _entry.cooldown_seconds > 0 or actual == Vector3.INF
	)
	if (
		_certificate.numeric_proof
		and (not bound_holds or (_certificate.excluded and not actual_excluded))
	):
		_reject("NUMERICAL_CERTIFICATE_COUNTEREXAMPLE")
	_record(
		"pitcher.before_ordinary_attempt",
		{
			"previous": previous,
			"current": current,
			"pre_pursuit_pitcher": _entry.pitcher,
			"post_pursuit_pitcher": _pitcher.global_position,
			"measured_displacement": displacement,
			"bound_holds": bound_holds,
			"actual_attempt_position": actual if actual != Vector3.INF else null,
			"has_attempt_position": actual != Vector3.INF,
			"actual_attempt_excluded": actual_excluded,
			"numeric_certificate": _certificate.duplicate(true)
		}
	)


func pitcher_return(lab: PitchBatLab) -> void:
	if _revoked:
		return
	if lab != _lab or not _in_controller or not _in_pitcher:
		_reject("PITCHER_RETURN_OWNER_OR_PHASE_INVALID")
		return
	_in_pitcher = false
	_record(
		"pitcher.after_ordinary_attempt",
		{
			"attempted": lab._pitcher_attempted,
			"dead": _state.dead,
			"pitcher": _pitcher.global_position
		}
	)


func controller_return(lab: PitchBatLab) -> void:
	if _revoked or phase != &"LIVE_INITIALIZED":
		return
	if lab != _lab or not _in_controller or _in_pitcher or not valid():
		_reject("CONTROLLER_RETURN_OWNER_OR_PHASE_INVALID")
		return
	if _pitcher_calls != _expected_pitcher_calls:
		_reject("CONTROLLER_PITCHER_CALL_COUNT_INVALID")
		return
	if _expected_pitcher_calls == 1 and lab._previous_batted_position != _entry.current:
		_reject("CONTROLLER_HISTORY_ADVANCE_INVALID")
		return
	_expected_history = lab._previous_batted_position
	_in_controller = false
	_record(
		"controller.return",
		{
			"previous": lab._previous_batted_position,
			"dead": _state.dead,
			"pitcher": _pitcher.global_position
		}
	)


func detach() -> void:
	_revoked = true
	phase = &"DETACHED"
	_ticket.clear()
	if guard != null:
		guard.detach()
	if is_instance_valid(_ball):
		if _ball.physics_contact_router == _early_sample:
			_ball.physics_contact_router = Callable()
		if _ball.launch_started.is_connected(_launch_signal):
			_ball.launch_started.disconnect(_launch_signal)
		if _ball.tree_exiting.is_connected(_body_exiting):
			_ball.tree_exiting.disconnect(_body_exiting)
		if _ball_ready.is_valid() and _ball.ready.is_connected(_ball_ready):
			_ball.ready.disconnect(_ball_ready)
	if is_instance_valid(_lab):
		if _lab.child_entered_tree.is_connected(_child_entered):
			_lab.child_entered_tree.disconnect(_child_entered)
		if _lab.get("pool_shadow") == self:
			_lab.set("pool_shadow", null)


func _body_exiting() -> void:
	if not _revoked:
		_reject("BODY_EXITED_BOUND_GENERATION")


func _registry() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: Node in _lab.find_children("*", "StaticBody3D", true, false):
		var surface: StringName = node.get_meta(&"ball_surface", &"")
		var kind: String = (
			"ground" if surface == &"ground" else "terminal" if surface == &"back_wall" else "solid"
		)
		result.append({"body": node, "kind": kind, "label": String(node.name)})
	if _model != null and not _lab.is_ancestor_of(_model):
		for body: Node in _model.get_node("Collision").get_children():
			result.append({"body": body, "kind": "solid", "label": String(body.name)})
	return result


func _signal_inventory() -> Array:
	return [
		_ball.get_signal_connection_list(&"launch_started"),
		_ball.get_signal_connection_list(&"surface_contact"),
		_ball.get_signal_connection_list(&"tree_exiting"),
		_lab.get_signal_connection_list(&"child_entered_tree"),
		_resolver.get_signal_connection_list(&"play_resolved")
	]


static func _tree_inventory(node: Node) -> Array:
	var result: Array = [
		[
			node.get_instance_id(),
			node.get_parent().get_instance_id(),
			node.get_script(),
			node.process_mode,
			node.process_priority,
			node.process_physics_priority,
			node.process_thread_group
		]
	]
	for child: Node in node.get_children():
		result.append_array(_tree_inventory(child))
	return result


static func _plain_actor_setup(lab: PitchBatLab) -> bool:
	if (
		not is_instance_valid(lab._pitcher_marker)
		or not is_instance_valid(lab._primary_fielder)
		or not is_instance_valid(lab._pitch_actor)
	):
		return false
	return (
		lab._pitcher_marker.get_class() == "Node3D"
		and lab._pitcher_marker.get_script() == null
		and lab._pitcher_marker.get_parent() == lab
		and not lab._pitcher_marker.is_queued_for_deletion()
		and lab._pitcher_marker.scale == Vector3.ONE
		and (
			lab._primary_fielder.get_script()
			== preload("res://src/presentation/fielding/fielder_controller.gd")
		)
		and lab._primary_fielder.get_parent() == lab
		and not lab._primary_fielder.is_queued_for_deletion()
		and lab._primary_fielder.scale == Vector3.ONE
		and not lab._pitch_actor.running
		and lab._primary_fielder.stadium_obstacles.is_empty()
		and not lab._primary_fielder.stadium_boundary_clip.is_valid()
		and lab._primary_fielder.pitcher_defender == lab._pitcher_marker
		and is_instance_valid(lab._ball_play_resolver)
		and (
			lab._ball_play_resolver.get_script()
			== preload("res://src/gameplay/ball_in_play/ball_play_resolver.gd")
		)
		and not lab._ball_play_resolver.segment_observer.is_valid()
		and lab.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
	)


static func _sources_exact() -> bool:
	var hashes: Dictionary = {
		"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd":
		"fbf5cb3ce2d6502c93bf21d80510f02d1bedb083e8c70af85243cd4311fb03ac",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab_defense_support.gd":
		"3227e3358e432ced68d359e8578a8e37f05c1392a38e103185f807ade8a016a3",
		"res://src/presentation/ball/batted_ball_body.gd":
		"706bdcdb59030712ce4d90994e32ce8727e3806ddb45e584843e9b8d34f66b6e",
		"res://src/gameplay/fielding/defender_spacing.gd":
		"60a99a60e46f45863a35c319a1b9a3cf100263b6bb0a3454000f7924d7ff5040",
		"res://src/gameplay/fielding/pitcher_defense.gd":
		"0c6774f23b58d1456e95531c31ecf29e0f61b771aaa9b3476ac3d35d8417f9dd",
		"res://src/gameplay/fielding/fielder_planner.gd":
		"a722c7fd617352eeccc4764936ed6debdbb30afb541bac481a11e7a222e3e8eb",
		"res://src/labs/pitch_bat_lab/match_lab_support.gd":
		"0bc5a5b81eeb89acffb56843b92b65265892ff0069f1217f6eb1b7f54cb492a5",
		"res://src/presentation/stadium/stadium_property_runtime.gd":
		"bb8585e924d350c5230b4048ffdefc4f9ed928df1c8392dd87ede04cff3d72d7",
		"res://src/presentation/fielding/fielder_controller.gd":
		"1b982fec0971e212900bc183c97953865f6027abb71c76f56b213579f132fab6",
		"res://src/gameplay/ball_in_play/ball_play_resolver.gd":
		"371da37f8112eb6da3881aa07b3225ddc4c6cfd4160d29eb06fc55241dbdaa4a",
		"res://src/gameplay/ball_in_play/ball_play_state.gd":
		"8a31d563ea78bfa6637def55aeb83dcd036bb16a187773fece4e852676ad8c4c",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab_presentation.gd":
		"a522fb5099d54eee83ccaa77eef0d3e781a94bf4a332d9429e0de22a961925a6",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab_feel_support.gd":
		"bde3a22ae58a43c6e9f1b2f0e97386383e5b8736574375da3741c34526b3e1c3",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab_home_run.gd":
		"641e614cd2831166448b5d4fb266d96387c5cb65537fa9be56447614c25fd164",
		"res://src/labs/pitch_bat_lab/starter_field_lab_geometry.gd":
		"0be889d48a37c9e5d017fcd234b2289cc8928a386605352557a6c7631ceeb9e5",
		"res://src/tests/helpers/pool_controller_shadow_lab.gd":
		"c53119cc5a943bf96d6de9c77f16d84412cee2c4cb4331a7f6886fc1fb17bf47"
	}
	for path: String in hashes:
		if FileAccess.get_sha256(path) != hashes[path]:
			return false
	return true


func _record(event: String, data: Dictionary) -> void:
	var row: Dictionary = {
		"event": event,
		"sequence": records.size(),
		"generation": generation,
		"phase": phase,
		"serial": _serial,
		"shadow_only": true,
		"early_award_authority": false
	}
	row.merge(data.duplicate(true))
	if event == "early.sample":
		row.serial = _serial + 1
	records.append(row)


func _unsupported(reason: String, facts: Dictionary) -> void:
	var row: Dictionary = {"reason": reason, "generation": generation, "serial": _serial}
	row.merge(facts.duplicate(true))
	unsupported.append(row)


func _reject(reason: String) -> void:
	_revoked = true
	phase = &"REVOKED"
	_ticket.clear()
	errors.append(reason)
	_record("rejected", {"reason": reason})


static func _launch_snapshot(launch: BattedBallLaunch) -> Array:
	return [
		launch.position,
		launch.velocity,
		launch.angular_velocity,
		launch.orientation,
		launch.is_foul
	]


static func _primary_configuration(primary: FielderController) -> Array:
	return [
		primary.anchor_position,
		primary.move_speed_mps,
		primary.fielding_rating,
		primary.reach_m,
		primary.handling_scale,
		primary._base_reaction_delay,
		primary._sky_reader
	]

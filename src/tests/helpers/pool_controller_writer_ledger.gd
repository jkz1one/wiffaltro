class_name PoolControllerWriterLedger
extends RefCounted
## Private pass-through observation. No outcome/physics writes, callbacks, or authority.
# gdlint: disable=max-public-methods,max-returns,function-arguments-number

const SCHEMA: String = "POOL-CONTROLLER-WRITER-v1"
const MAX_SCRIPTS: int = 36
const MAX_EVENTS: int = 1600
const MAX_EVENT_BYTES: int = 2048
const MAX_TYPED_BYTES: int = 1600 * 2048 + 65536
const METADATA_RESERVE: int = 65536
const MAX_ARM_BYTES: int = 192 * 1024 * 1024
const MAX_DEPTH: int = 4
const MAX_CONTACTS: int = 8
const MAX_SURFACES: int = 64
const MAX_TEXT_BYTES: int = 64
const KINDS: Array[String] = ["controller", "pitcher", "primary", "surface", "fielding", "resolved"]
var events: Array[Array] = []
var failure: String = ""
var armed: bool = false
var _shadow_ref: WeakRef
var _shadow: StadiumPoolControllerShadow:
	get:
		return _shadow_ref.get_ref() as StadiumPoolControllerShadow if _shadow_ref != null else null
var _lab: PitchBatLab
var _generation: int = 0
var _frame: int = 0
var _next_call: int = 0
var _stack: Array[Array] = []
var _counts: Dictionary = {}
var _ancestors: Array = []
var _registry: Array = []
var _scope: Array = []
var _scope_rows: Array = []
var _scripts: Array[Script] = []
var _script_sources: Array[String] = []
var _script_rows: Array = []
var _ancestor_rows: Array = []
var _signal_rows: Array = []
var _body_connections: Array = []
var _ids: Dictionary = {}
var _mirror: Array = []
var _early: Array = []
var _early_frame: int = -1
var _ambiguity: String = ""
var _ambiguities: Array[String] = []
var _event_bytes: int = 0


func bind(shadow: StadiumPoolControllerShadow) -> void:
	if armed or _shadow != null:
		_fail("DUPLICATE_BIND")
		return
	_shadow_ref = weakref(shadow)
	_lab = shadow._lab
	_generation = shadow.generation
	_frame = Engine.get_physics_frames()
	_ancestors = ancestry(_lab)
	_capture_scope()
	_capture_callbacks()
	if failure != "":
		return
	var registry: Array[Dictionary] = shadow._registry()
	if registry.size() > 256:
		_fail("REGISTRY_COUNT_LIMIT")
		return
	for entry: Dictionary in registry:
		var body: StaticBody3D = entry.body
		var label: String = String(entry.label)
		if label.to_utf8_buffer().size() > MAX_TEXT_BYTES:
			_fail("REGISTRY_TEXT_LIMIT")
			return
		_ids[body.get_instance_id()] = _registry.size()
		_registry.append([body.get_instance_id(), String(entry.kind), label])
	armed = true
	if (
		var_to_bytes(packet(shadow._role, shadow._role, shadow._source)).size()
		> METADATA_RESERVE - 4096
	):
		_fail("METADATA_QUOTA")
		return
	if not ownership():
		_fail("BIND_OWNERSHIP")
	_emit("seal", 0, 0, -1, [], snapshot())


func ownership() -> bool:
	if not armed or _shadow == null or not is_instance_valid(_lab):
		return false
	if EngineDebugger.is_active() or _shadow.generation != _generation or not _shadow.valid():
		return false
	if ancestry(_lab) != _ancestors or not main_thread_ancestry(_lab):
		return false
	if _lab.process_physics_priority != 0 or not _lab.is_physics_processing():
		return false
	if _shadow._ball.get_signal_connection_list(&"body_entered") != _body_connections:
		return false
	if scene_scope(_lab.get_tree().root) != _scope:
		return false
	for index: int in range(_scripts.size()):
		if _scripts[index].source_code != _script_sources[index]:
			return false
	var primary: FielderController = _lab._primary_fielder
	return (
		primary.process_physics_priority == 0
		and primary.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
		and primary.is_physics_processing()
		and primary.get_parent() == _lab
		and not _lab.has_meta(&"stadium_property")
		and not _lab._ball_play_resolver.segment_observer.is_valid()
	)


static func scene_scope(root: Node) -> Array:
	var result: Array = []
	for child: Node in root.get_children():
		result.append_array(StadiumPoolControllerShadow._tree_inventory(child))
	return result


func _capture_scope() -> void:
	_scope = scene_scope(_lab.get_tree().root)
	if _scope.size() > 512:
		_fail("SCENE_SCOPE_LIMIT")
		return
	for row: Array in _scope:
		var script: Script = row[2] as Script
		var script_index: int = -1
		if script != null:
			script_index = _scripts.find(script)
			if script_index < 0:
				if _scripts.size() >= MAX_SCRIPTS or script.resource_path.length() > 192:
					_fail("SCRIPT_SCOPE_LIMIT")
					return
				var code: String = script.source_code
				if code.sha256_text() != FileAccess.get_sha256(script.resource_path):
					_fail("LOADED_SCRIPT_SOURCE_MISMATCH")
					return
				script_index = _scripts.size()
				_scripts.append(script)
				_script_sources.append(code)
				_script_rows.append([script.resource_path, code.sha256_text()])
		_scope_rows.append([row[0], row[1], script_index, row[3], row[4], row[5], row[6]])

	for path: String in [
		"res://src/labs/pitch_bat_lab/pitch_bat_lab.gd",
		"res://src/labs/pitch_bat_lab/pitch_bat_lab_defense_support.gd",
		"res://src/gameplay/fielding/pitcher_defense.gd",
		"res://src/presentation/stadium/stadium_property_runtime.gd",
		"res://src/gameplay/ball_in_play/ball_play_resolver.gd",
		"res://src/gameplay/ball_in_play/ball_play_state.gd",
		"res://src/gameplay/stadium/stadium_pool_controller_shadow.gd",
		"res://src/tests/helpers/pool_controller_writer_ledger.gd",
		"res://src/gameplay/stadium/stadium_pool_interior_v2.gd",
		"res://src/gameplay/stadium/stadium_pool_contract.gd",
		"res://src/labs/pitch_bat_lab/match_lab_support.gd",
		"res://src/gameplay/stadium/stadium_pool_water_guard.gd",
		"res://src/gameplay/stadium/stadium_pool_party_asset_integrity.gd"
	]:
		var script: Script = load(path) as Script
		if script in _scripts:
			continue
		if script == null or _scripts.size() >= MAX_SCRIPTS:
			_fail("STATIC_SCRIPT_SCOPE_LIMIT")
			return
		var code: String = script.source_code
		if code.sha256_text() != FileAccess.get_sha256(path):
			_fail("LOADED_STATIC_SOURCE_MISMATCH")
			return
		_scripts.append(script)
		_script_sources.append(code)
		_script_rows.append([path, code.sha256_text()])


func _capture_callbacks() -> void:
	var node: Node = _lab
	while node != null:
		if _ancestor_rows.size() >= 16:
			_fail("ANCESTRY_LIMIT")
			return
		_ancestor_rows.append(
			[
				node.get_instance_id(),
				node.get_parent().get_instance_id() if node.get_parent() != null else 0,
				node.process_mode,
				node.process_physics_priority,
				node.process_thread_group,
				node.is_physics_processing(),
				node.is_processing_internal(),
				node.is_physics_processing_internal()
			]
		)
		node = node.get_parent()
	_body_connections = _shadow._ball.get_signal_connection_list(&"body_entered")
	var signals: Array = [
		[_shadow._ball, &"launch_started"],
		[_shadow._ball, &"surface_contact"],
		[_shadow._ball, &"tree_exiting"],
		[_lab, &"child_entered_tree"],
		[_shadow._resolver, &"play_resolved"],
		[_shadow._ball, &"body_entered"],
		[_lab.get_tree(), &"physics_frame"]
	]
	for item: Array in signals:
		var connections: Array[Dictionary] = item[0].get_signal_connection_list(item[1])
		for connection: Dictionary in connections:
			var callback: Callable = connection.callable
			if (
				callback.get_bound_arguments_count() != 0
				or callback.get_unbound_arguments_count() != 0
				or _signal_rows.size() >= 32
				or String(callback.get_method()).length() > 64
			):
				_fail("CALLBACK_SCOPE_LIMIT")
				return
			_signal_rows.append(
				[
					item[0].get_instance_id(),
					String(item[1]),
					callback.get_object_id(),
					String(callback.get_method()),
					int(connection.flags)
				]
			)


static func ancestry(node: Node) -> Array:
	var result: Array = []
	while node != null:
		result.append(
			[
				node.get_instance_id(),
				node.get_script(),
				node.process_mode,
				node.process_physics_priority,
				node.process_thread_group,
				node.is_physics_processing(),
				node.is_processing_internal(),
				node.is_physics_processing_internal()
			]
		)
		node = node.get_parent()
	return result


static func main_thread_ancestry(node: Node) -> bool:
	while node != null:
		if node.process_thread_group == Node.PROCESS_THREAD_GROUP_SUB_THREAD:
			return false
		node = node.get_parent()
	return true


func begin(lab: PitchBatLab, kind: String, arguments: Array) -> int:
	if not armed:
		return 0
	if failure != "":
		return 0
	if lab != _lab or kind not in KINDS or not ownership():
		_fail("CALL_OWNERSHIP")
		return 0
	var parent: String = String(_stack[-1][1]) if not _stack.is_empty() else ""
	var allowed: Dictionary = {
		"controller": [""],
		"pitcher": ["controller"],
		"primary": ["controller"],
		"surface": [""],
		"fielding": ["pitcher", "primary"],
		"resolved": ["surface", "pitcher", "primary", "fielding", "controller"]
	}
	if parent not in allowed[kind] or _stack.size() >= MAX_DEPTH:
		_fail("CALL_NESTING_OR_REENTRANCY")
		return 0
	_counts[kind] = int(_counts.get(kind, 0)) + 1
	var limit: int = MAX_SURFACES if kind == "surface" else 180
	if kind == "resolved":
		limit = 1
	elif kind == "fielding":
		limit = 3
	if int(_counts[kind]) > limit:
		_fail("CALL_COUNT_LIMIT")
		return 0
	_next_call += 1
	var call_id: int = _next_call
	var parent_id: int = int(_stack[-1][0]) if not _stack.is_empty() else 0
	_stack.append([call_id, kind, parent_id])
	_emit(kind + ".enter", call_id, parent_id, -1, arguments, snapshot())
	return call_id


func end(lab: PitchBatLab, kind: String, call_id: int, arguments: Array = []) -> void:
	if call_id == 0 or failure != "":
		return
	if lab != _lab or not ownership() or _stack.is_empty():
		_fail("RETURN_OWNERSHIP")
		return
	var top: Array = _stack[-1]
	if top[0] != call_id or top[1] != kind:
		_fail("RETURN_ORDER")
		return
	var after: Array = snapshot()
	_emit(kind + ".return", call_id, int(top[2]), -1, arguments, after)
	if kind == "surface" and after[2]:
		_note_ambiguity("GROUND_HISTORY_CHRONOLOGY_UNPROVEN")
	_stack.pop_back()


func early(contacts: Array[Dictionary], reference: int) -> void:
	if not armed or failure != "":
		return
	if not ownership() or not _stack.is_empty() or contacts.size() > MAX_CONTACTS:
		_fail("EARLY_OWNER_OR_CAPACITY")
		return
	var rows: Array = []
	for contact: Dictionary in contacts:
		var body: Object = contact.get("body")
		if not is_instance_valid(body) or not contact.get("position") is Vector3:
			_fail("CONTACT_SHAPE")
			return
		var identity: int = body.get_instance_id()
		var registered: int = int(_ids.get(identity, -1))
		rows.append([identity, registered, contact.position])
		if registered < 0:
			_note_ambiguity("UNREGISTERED_ROUTER_CONTACT")
		elif _registry[registered][1] != "ground":
			_note_ambiguity("SOLID_PATH_CHRONOLOGY_UNPROVEN")
	if contacts.size() == MAX_CONTACTS:
		_note_ambiguity("ROUTER_CAPACITY_UNPROVEN")
	_early = snapshot()
	_early_frame = Engine.get_physics_frames()
	_emit("early", 0, 0, reference, rows, _early)


func capture_mirror(
	previous: Vector3,
	current: Vector3,
	pitcher: Vector3,
	result: Vector3,
	attempted: bool,
	cooldown: float
) -> void:
	if armed and failure == "":
		_mirror = [previous, current, pitcher, result, attempted, cooldown]


func pitcher_seal(lab: PitchBatLab, previous: Vector3, current: Vector3) -> void:
	if not armed or failure != "":
		return
	if lab != _lab or _stack.is_empty() or _stack[-1][1] != "pitcher" or not ownership():
		_fail("MIRROR_CALL_OWNER")
		return
	# These are fresh invocation-time inputs, not stale controller-entry gates.
	var seal: Array = [
		previous,
		current,
		lab._pitcher_marker.global_position,
		lab._pitcher_attempted,
		lab._fielding_cooldown_seconds
	]
	var same: bool = (
		_mirror.size() == 6
		and (
			var_to_bytes([_mirror[0], _mirror[1], _mirror[2], _mirror[4], _mirror[5]])
			== var_to_bytes(seal)
		)
	)
	var numeric: bool = numeric_domain(seal)
	var eligible: bool = not seal[3] and not (float(seal[4]) > 0.0)
	var current_snapshot: Array = snapshot()
	var wet: bool = false
	if _shadow._role == StadiumPoolContract.LIVE:
		wet = (
			_shadow
			. guard
			. _context
			. sample(current_snapshot[15], _shadow.guard._physical_radius)
			. positive_overlap
		)
	var reason: String = decision(
		same,
		numeric,
		eligible,
		_mirror[3] == Vector3.INF if _mirror.size() == 6 else false,
		wet,
		current_snapshot[9],
		_ambiguity,
		_early if _early_frame == Engine.get_physics_frames() else [],
		current_snapshot
	)
	_emit(
		"pitcher.seal",
		int(_stack[-1][0]),
		int(_stack[-1][2]),
		_shadow.records.size() - 1,
		[
			_mirror.duplicate(),
			seal,
			same,
			numeric,
			eligible,
			wet,
			reason,
			false,
			false,
			_ambiguities.duplicate()
		],
		current_snapshot
	)
	_mirror.clear()


static func numeric_domain(seal: Array) -> bool:
	if seal.size() != 5 or not seal[3] is bool or not seal[4] is float:
		return false
	if not is_finite(seal[4]) or absf(seal[4]) > 1048576.0:
		return false
	for index in range(3):
		if not seal[index] is Vector3:
			return false
		var point: Vector3 = seal[index]
		if not point.is_finite() or absf(point.x) > 64 or absf(point.y) > 16 or absf(point.z) > 64:
			return false
	return true


static func decision(
	same: bool,
	numeric: bool,
	eligible: bool,
	mirror_excluded: bool,
	wet: bool,
	dead: bool,
	ambiguity: String,
	early_state: Array,
	current: Array
) -> String:
	if not same:
		return "MIRROR_SEAL_CHANGED"
	if not numeric:
		return "NUMERIC_DOMAIN_UNPROVEN"
	if dead:
		return "PRIOR_TERMINAL"
	if not ambiguity.is_empty():
		return ambiguity
	if early_state.is_empty():
		return "EARLY_SAMPLE_MISSING"
	if early_state[9] or (not early_state[2] and current[2]):
		return "EARLIER_GROUND_OR_TERMINAL"
	if eligible and not mirror_excluded:
		return "HISTORICAL_PITCHER_ORDER_UNPROVEN"
	if not wet:
		return "CURRENT_DRY_NO_WATER_DECISION"
	# A useful conditional current sample, never an award or path-completeness proof.
	return "CURRENT_WET_HELPER_EXCLUDED_OBSERVED"


func snapshot() -> Array:
	var state: BallPlayState = _lab._ball_play_resolver.state
	var ball: BattedBallBody = _lab._batted_ball
	var primary: FielderController = _lab._primary_fielder
	return [
		state.is_fair,
		state.is_foul_play,
		state.has_grounded,
		int(state.result_floor),
		String(state.last_defender_touch),
		String(state.last_obstacle_contact),
		state.defender_touched,
		state.bobbled,
		state.caught,
		state.dead,
		state.first_ground_position,
		state.catch_position,
		state.catch_time,
		state.elapsed_seconds,
		state.stadium_contacts.size(),
		ball.global_position,
		[ball.global_basis.x, ball.global_basis.y, ball.global_basis.z],
		ball.linear_velocity,
		ball.angular_velocity,
		ball.freeze,
		ball.sleeping,
		ball._started,
		pose(_lab._pitcher_marker),
		pose(primary),
		primary.velocity,
		primary.target_position,
		primary.active,
		primary.stationary,
		primary.first_step,
		primary._play_elapsed_seconds,
		primary.last_reaction_margin_seconds,
		_lab._pitcher_attempted,
		_lab._primary_attempts,
		_lab._fielding_cooldown_seconds,
		_lab._previous_batted_position,
		String(_lab._base_state.first),
		String(_lab._base_state.second),
		String(_lab._base_state.third),
		_lab._debug_paused,
		_lab._settled_seconds,
		[
			primary.anchor_position,
			primary.reaction_delay_seconds,
			_lab._throw_number,
			_lab._last_fielding_text,
			MatchLabSupport.pitcher_fielding_rating(_lab),
			PitchBatLabDefenseSupport.reaction_delay(_lab),
			PitchBatLabDefenseSupport.gear_factor(_lab, "speed"),
			PitchBatLabDefenseSupport.gear_factor(_lab, "handling"),
			primary.move_speed_mps,
			primary.reach_m,
			primary.handling_scale,
			primary.fielding_rating,
			ball.mass,
			_shadow.guard._physical_radius,
			ball.radius_m,
			primary._base_reaction_delay,
			primary._sky_reader,
			primary.pitcher_lane_z
		],
		[
			primary.pitcher_defender.get_instance_id(),
			_shadow._field.get_instance_id(),
			state.get_instance_id(),
			ball.get_instance_id(),
			_lab._ball_play_resolver.get_instance_id(),
			_lab._pitcher_marker.get_instance_id(),
			primary.get_instance_id(),
			_lab.get_instance_id(),
			_generation
		],
		[
			ball.is_queued_for_deletion(),
			primary.is_physics_processing(),
			_lab._match_mode,
			_lab.is_physics_processing(),
			_lab._pitch_actor.running,
			EngineDebugger.is_active(),
			main_thread_ancestry(_lab)
		],
		[
			_shadow._field.safe_hit_z_m,
			_shadow._field.deep_air_z_m,
			_shadow._field.back_wall_z_m,
			_shadow._field.dead_ball_z_m,
			_shadow._field.home_run_height_m
		]
	]


static func pose(node: Node3D) -> Array:
	var transform: Transform3D = node.global_transform
	return [transform.origin, transform.basis.x, transform.basis.y, transform.basis.z]


func packet(mode: String, role: String, source: String) -> Dictionary:
	if armed and not _stack.is_empty():
		_fail("UNFINISHED_CALLBACK")
	return {
		"schema": SCHEMA,
		"source": source,
		"mode": mode,
		"role": role,
		"generation": _generation,
		"launch_frame": _frame,
		"armed": armed,
		"registry": _registry,
		"scene_nodes": _scope_rows,
		"ancestors": _ancestor_rows,
		"callbacks": _signal_rows,
		"owners":
		(
			[
				_shadow.get_instance_id(),
				_shadow.guard.get_instance_id(),
				_lab.get_parent().get_instance_id()
			]
			if armed
			else []
		),
		"loaded_scripts": _script_rows,
		"ownership_contract": "PINNED_HEADLESS_SCENE_MAIN_THREAD_NO_DEBUGGER_NO_EXTERNAL_WRITERS",
		"events": events,
		"counts": _counts,
		"failure": failure,
		"early_award_authority": false,
		"phase_closure_qualified": false,
		"active_awards_enabled": false,
		"production_qualified": false,
		"ordinary_controller_qualified": false,
		"persistent_session_qualified": false,
		"direct_internal_return_observed": false,
		"dry_to_dry_completeness_qualified": false,
		"reflected_path_reconstructed": false,
		"earlier_segment_terminal_exclusion_qualified": false,
		"mirror_provenance": "SEPARATE_CONTEMPORANEOUS_PURE_HELPER_CALL",
		"primary_order_provenance": "PINNED_PARENT_BEFORE_CHILD_SCHEDULER_SOURCE_NOT_CALLBACK_TAP"
	}


func _emit(
	kind: String, call_id: int, parent_id: int, reference: int, arguments: Array, state: Array
) -> void:
	if failure != "":
		return
	if not bounded_value(arguments) or not bounded_value(state):
		_fail("VALUE_GRAMMAR_LIMIT")
		return
	var event: Array = [
		events.size(),
		kind,
		Engine.get_physics_frames() - _frame,
		_shadow._serial,
		call_id,
		parent_id,
		_stack.size(),
		reference,
		arguments,
		state
	]
	var size: int = var_to_bytes(event).size()
	if (
		events.size() >= MAX_EVENTS
		or size > MAX_EVENT_BYTES
		or _event_bytes + size > MAX_TYPED_BYTES - METADATA_RESERVE
	):
		_fail("EVENT_BUDGET")
		return
	_event_bytes += size
	events.append(event)


static func bounded_value(value: Variant, depth: int = 0) -> bool:
	if depth > 4:
		return false
	if value is String:
		return value.length() <= MAX_TEXT_BYTES and value.to_utf8_buffer().size() <= MAX_TEXT_BYTES
	if value is Array:
		if value.size() > 64:
			return false
		for child: Variant in value:
			if not bounded_value(child, depth + 1):
				return false
		return true
	return value is int or value is float or value is bool or value is Vector3


func _note_ambiguity(reason: String) -> void:
	if reason not in _ambiguities:
		_ambiguities.append(reason)
	if _ambiguity == "":
		_ambiguity = reason


func _fail(reason: String) -> void:
	if failure == "":
		failure = reason

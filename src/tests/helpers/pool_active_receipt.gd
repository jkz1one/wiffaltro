class_name StadiumPoolActiveReceipt
extends RefCounted
## Fixed private diagnostic copies. No listener, callable, gameplay write or authority.

const PATH: String = "res://src/tests/helpers/pool_active_receipt.gd"
const FIXTURE: String = "res://src/tests/stadium_pool_controller_active_test.gd"
const MAX_ROWS: int = 360
const MAX_ROW_BYTES: int = 32768
var rows: Array = []
var outcomes: Array = []
var launch_frame: int = 0
var serial: int = 0
var failure: String = ""
var decision_count: int = 0
var _decision_tick: int = -1
var _lab: PitchBatLab
var _owners: Array = []
var _scripts: Array = []


func attach(lab: PitchBatLab) -> bool:
	if get_script() != load(PATH) or lab.get_parent().get_script() != load(FIXTURE):
		return false
	if lab.pool_active_receipt != null or _lab != null:
		return false
	_lab = lab
	lab.pool_active_receipt = self
	return true


func begin(frame: int) -> void:
	rows = []
	outcomes = []
	launch_frame = frame
	serial = 0
	decision_count = 0
	_decision_tick = -1
	failure = ""


func bind_owners() -> void:
	_owners = [
		_lab,
		_lab._batted_ball,
		_lab._primary_fielder,
		_lab._ball_play_resolver,
		_lab._ball_play_resolver.state,
		_lab._pitcher_marker,
		_lab.get_parent()
	]
	_scripts = []
	for owner: Object in _owners:
		_scripts.append(owner.get_script())


func owned() -> bool:
	if _owners.size() != 7 or _scripts.size() != 7:
		return false
	var expected: Array = [
		load("res://src/labs/pitch_bat_lab/pitch_bat_lab.gd"),
		load("res://src/presentation/ball/batted_ball_body.gd"),
		load("res://src/presentation/fielding/fielder_controller.gd"),
		load("res://src/gameplay/ball_in_play/ball_play_resolver.gd"),
		load("res://src/gameplay/ball_in_play/ball_play_state.gd"),
		null,
		load(FIXTURE),
	]
	if _scripts != expected:
		return false
	for index: int in range(7):
		if not is_instance_valid(_owners[index]) or _owners[index].get_script() != _scripts[index]:
			return false
	return (
		_lab == _owners[0]
		and _lab._batted_ball == _owners[1]
		and _lab._primary_fielder == _owners[2]
		and _lab._ball_play_resolver == _owners[3]
		and _lab._ball_play_resolver.state == _owners[4]
		and _lab._pitcher_marker == _owners[5]
		and _lab.get_parent() == _owners[6]
		and _owners[1].get_parent() == _lab
		and _owners[2].get_parent() == _lab
		and _owners[5].get_parent() == _lab
		and _lab.pool_active_receipt == self
		and get_script() == load(PATH)
		and _owners[6].get_script() == load(FIXTURE)
		and _lab.is_physics_processing()
		and _lab._primary_fielder.is_physics_processing()
		and _lab.process_physics_priority == 0
		and _lab._primary_fielder.process_physics_priority == 0
		and _owners[6].process_physics_priority == 1000
		and _owners[6].process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
		and _lab.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
		and _lab._primary_fielder.process_thread_group == Node.PROCESS_THREAD_GROUP_INHERIT
		and _lab._primary_fielder.pitcher_lane_z == PitchBatLab.MOUND_ORIGIN.z
	)


func capture_decision(lab: PitchBatLab, previous: Vector3, current: Vector3) -> void:
	if lab != _lab or launch_frame == 0:
		return
	var tick: int = Engine.get_physics_frames() - launch_frame
	if tick < 1 or tick > 180 or _decision_tick == tick:
		failure = "DECISION_TICK"
		return
	_decision_tick = tick
	decision_count += 1
	_append([tick, "decision", _next(), true, snapshot(lab, previous, current)])


func capture_late(lab: PitchBatLab) -> void:
	var tick: int = Engine.get_physics_frames() - launch_frame
	_append(
		[
			tick,
			"late",
			_next(),
			_decision_tick == tick,
			snapshot(lab, lab._previous_batted_position, lab._batted_ball.global_position)
		]
	)


func before_outcome(lab: PitchBatLab, outcome: BallPlayOutcome) -> Array:
	if not owned():
		failure = "OUTCOME_OWNER"
		return []
	if lab != _lab or launch_frame == 0:
		return []
	return [
		Engine.get_physics_frames() - launch_frame,
		_next(),
		int(outcome.result),
		String(outcome.reason),
		outcome.caught,
		outcome.resolution_position,
		bases(lab),
	]


func after_outcome(lab: PitchBatLab, before: Array) -> void:
	if before.is_empty():
		return
	if lab != _lab or outcomes.size() >= 1:
		failure = "OUTCOME_COUNT"
		return
	before.append(bases(lab))
	if var_to_bytes(before).size() > MAX_ROW_BYTES:
		failure = "OUTCOME_BYTES"
		return
	outcomes.append(before)


func _next() -> int:
	serial += 1
	return serial


func _append(row: Array) -> void:
	if rows.size() >= MAX_ROWS or var_to_bytes(row).size() > MAX_ROW_BYTES:
		failure = "ROW_CAPACITY"
		return
	rows.append(row)


static func bases(lab: PitchBatLab) -> Array:
	return [
		String(lab._base_state.first), String(lab._base_state.second), String(lab._base_state.third)
	]


static func pose(node: Node3D) -> Array:
	var value: Transform3D = node.global_transform
	return [value.basis.x, value.basis.y, value.basis.z, value.origin]


func snapshot(lab: PitchBatLab, previous: Vector3, current: Vector3) -> Array:
	if lab != _lab or not owned():
		failure = "SNAPSHOT_OWNER"
		return []
	var ball: BattedBallBody = lab._batted_ball
	var state: BallPlayState = lab._ball_play_resolver.state
	var primary: FielderController = lab._primary_fielder
	if not state.stadium_contacts.is_empty():
		failure = "UNSUPPORTED_STADIUM_CONTACTS"
	var state_values: Array = StadiumPoolWaterGuard._state_parameters(state)
	state_values[8] = String(state.last_obstacle_contact)
	state_values[9] = String(state.last_defender_touch)
	state_values[14] = []
	var eligible: bool = not lab._pitcher_attempted and lab._fielding_cooldown_seconds <= 0.0
	var attempt: Vector3 = Vector3.INF
	if eligible:
		attempt = PitcherDefense.attempt_position(
			previous, current, lab._pitcher_marker.global_position
		)
	var has_attempt: bool = attempt != Vector3.INF
	return [
		pose(ball),
		ball.linear_velocity,
		ball.angular_velocity,
		ball.sleeping,
		ball.freeze,
		state_values,
		previous,
		pose(lab._pitcher_marker),
		lab._pitcher_attempted,
		lab._fielding_cooldown_seconds,
		lab._primary_attempts,
		lab._settled_seconds,
		lab._throw_number,
		[
			pose(primary),
			primary.velocity,
			primary.anchor_position,
			primary.target_position,
			primary.active,
			primary.stationary,
			primary.first_step,
			primary.last_reaction_margin_seconds,
			primary._play_elapsed_seconds,
			primary.move_speed_mps,
			primary.fielding_rating,
			primary.reach_m,
			primary.handling_scale,
			primary.reaction_delay_seconds,
			primary._base_reaction_delay,
			primary._sky_reader,
			primary.pitcher_lane_z,
		],
		bases(lab),
		[eligible, has_attempt, attempt if has_attempt else Vector3.ZERO],
	]

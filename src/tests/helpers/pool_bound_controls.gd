class_name StadiumPoolBoundControls
extends RefCounted
## Source-authored bounded match/property controls. Native results require the separate gate.
## Presentation/cadence is manually paced during windows; ordinary physics/outcomes stay live.
# gdlint: disable=max-returns,max-file-lines

signal window_finished

const HISTORY_TICKS: int = 180
const CONTACT_TICKS: int = 60
const ROUTE_STEPS: int = 240
const LAUNCHES_PER_ARM: int = 2
const ARMS: Array[String] = ["a", "b", "s"]
const CASES: Array[String] = ["wet", "dry"]
const CONTACTS: Array[String] = ["ground", "receiver", "boundary"]
const EXPECTED_NATIVE_CHECKS: int = 1419
const MAX_NATIVE_CHECKS: int = 2048
const MAX_HISTORY_ROWS: int = HISTORY_TICKS * 2
const MAX_SUMMARY_BYTES: int = 1024
var _host: Node3D
var _lab: PitchBatLab
var _receipt: StadiumPoolActiveReceipt
var _capture: bool = false
var _remaining: int = 0
var _window_ticks: int = 0
var _checks: int = 0
var _history_count: int = 0
var _summary_count: int = 0
var _contact_count: int = 0
var _packets: Dictionary = {}
var _diagnostic: bool = false
var _first_decline: Dictionary = {}


func run(host: Node3D) -> void:
	_host = host
	var original_priority: int = host.process_physics_priority
	host.process_physics_priority = 1000
	_check(
		Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,
		"bound ordinary 60 Hz clock"
	)
	_check(
		ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics",
		"bound ordinary Jolt engine"
	)
	_entitlement_controls()
	await _transaction_controls()
	for case_name: String in CASES:
		for arm: String in ARMS:
			await _history_arm(case_name, arm)
		_check(
			(
				not _packets[case_name + ":a"].is_empty()
				and _packets[case_name + ":a"] == _packets[case_name + ":b"]
			),
			"bound disabled full receipt and match equality " + case_name
		)
	await _geometry_and_contacts()
	await _lifecycle_and_rematch()
	_check(
		(
			_history_count == CASES.size() * ARMS.size() * LAUNCHES_PER_ARM
			and _summary_count == _history_count
		),
		"bound exact twelve generated history windows"
	)
	_check(_contact_count == CONTACTS.size(), "bound exact three ordinary physical probes")
	_check(_checks < MAX_NATIVE_CHECKS, "bound source-derived finite assertion budget")
	_check(
		_checks + 1 == EXPECTED_NATIVE_CHECKS, "bound exact source-derived native assertion count"
	)
	print(
		(
			"POOL_BOUND_V26 checks=%d histories=%d contacts=%d native_budget=%d"
			% [_checks, _history_count, _contact_count, MAX_NATIVE_CHECKS]
		)
	)
	host.process_physics_priority = original_priority


func run_diagnostic(host: Node3D) -> void:
	_host = host
	_diagnostic = true
	var original_priority: int = host.process_physics_priority
	host.process_physics_priority = 1000
	_check(
		Engine.physics_ticks_per_second == 60 and Engine.time_scale == 1.0,
		"bound diagnostic ordinary 60 Hz clock"
	)
	await _history_arm("wet", "s")
	_check(
		_history_count == 2 and _summary_count == 2,
		"bound diagnostic exact two unchanged wet histories"
	)
	_check(_checks + 1 == 58, "bound diagnostic exact source-derived count")
	host.process_physics_priority = original_priority
	_diagnostic = false


func _capture_first_decline() -> void:
	# Existing late callback only; fixed copies, no new listeners or predicate calls.
	if not _first_decline.is_empty():
		return
	var adapter: StadiumPoolControllerActive = _lab.pool_controller_active
	if adapter == null or adapter.decline.is_empty():
		return
	var guard: StadiumPoolWaterGuard = adapter._guard
	if guard == null:
		_first_decline = {
			"frame": Engine.get_physics_frames() - _receipt.launch_frame,
			"decline": adapter.decline,
			"guard_present": false
		}
		return
	_first_decline = {
		"guard_present": true,
		"frame": Engine.get_physics_frames() - _receipt.launch_frame,
		"decline": adapter.decline,
		"samples": guard._samples,
		"generation_invalid": guard._generation_invalid,
		"history_reason": guard._history_unproven,
		"error_count": guard.errors.size(),
		"first_error": guard.errors[0] if not guard.errors.is_empty() else "",
		"early_frame": adapter._early_frame - _receipt.launch_frame,
		"previous": [guard._previous.x, guard._previous.y, guard._previous.z],
		"current":
		[_lab._batted_ball.position.x, _lab._batted_ball.position.y, _lab._batted_ball.position.z]
	}


func _diagnostic_summary(adapter: StadiumPoolControllerActive, ordinal: int) -> void:
	var text: String = JSON.stringify(
		{"ordinal": ordinal, "first_decline": _first_decline, "terminal_decline": adapter.decline},
		"",
		true,
		true
	)
	_check(text.to_utf8_buffer().size() <= 2048, "bound diagnostic finite record budget")
	if text.to_utf8_buffer().size() <= 2048:
		print("POOL_BOUND_V26_R2_DECLINE " + text)


# Invoked only by the unchanged host's late priority1000 physics callback.
func tick() -> void:
	if _remaining <= 0:
		return
	if _capture:
		_receipt.capture_late(_lab)
		if _diagnostic:
			_capture_first_decline()
	_window_ticks += 1
	_remaining -= 1
	if _remaining == 0:
		_capture = false
		window_finished.emit()


func _window(lab: PitchBatLab, ticks: int, capture: bool = false) -> void:
	_lab = lab
	_window_ticks = 0
	_remaining = ticks
	_capture = capture
	_first_decline = {}
	await window_finished
	_check(_window_ticks == ticks, "bound exact bounded late-physics window")


func _ledger() -> ClubAssetLedger:
	# ClubAssetLedger.new_club() would install the rough-surface v8 layout instead.
	var ledger: ClubAssetLedger = ClubAssetLedger.new(704716, [0])
	var layout: Dictionary = StadiumPoolBoundEntitlement.base_layout()
	var draft: Dictionary = ledger.commit(
		{"id": "bound:draft", "rev": ledger.revision(), "op": "stadium_draft", "layout": layout}
	)
	var applied: Dictionary = ledger.commit(
		{
			"id": "bound:apply",
			"rev": ledger.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumProperty.signature("backyard")
		}
	)
	_check(
		draft.ok and applied.ok and ledger.revision() == 2,
		"bound exact receiver-only real draft/apply journal"
	)
	return ledger


func _configured(ledger: ClubAssetLedger) -> Dictionary:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	_check(
		(
			StadiumLayoutSnapshot.valid(snapshot, ledger.construction())
			and StadiumLayoutSnapshot.matches(snapshot, ledger)
			and StadiumPoolBoundEntitlement.exact_base(snapshot, ledger)
		),
		"bound actual snapshot stock and ownership validators"
	)
	var state: MatchState = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME
	)
	state.stadium = snapshot.duplicate(true)
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = state
	lab._stadium_ledger = ledger
	return {"lab": lab, "state": state, "ledger": ledger, "snapshot": snapshot}


func _start(active: bool = false) -> Dictionary:
	seed(704716)
	var result: Dictionary = _configured(_ledger())
	var lab: PitchBatLab = result.lab
	var token: StadiumPoolBoundEntitlement = StadiumPoolBoundEntitlement.issue_private(
		lab, result.snapshot, result.ledger
	)
	result["token"] = token
	_check(token != null, "bound explicitly issued private token")
	_check(
		(
			StadiumPoolBoundExtension.configure(lab, token, true)
			if active
			else StadiumPoolBoundExtension.configure(lab, token)
		),
		"bound pre-tree private configuration"
	)
	_host.add_child(lab)
	# Deliberate bounded presentation pacing. Do not disable controller/fielder physics.
	lab.set_process(false)
	var property: StadiumPoolBoundProperty = StadiumPoolBoundExtension.current(lab)
	result["property"] = property
	_check(
		not lab.pool_bound_startup_failed and property != null,
		"bound genuine ordinary configured-match startup"
	)
	_check(
		(
			lab._match_mode
			and lab._match_state == result.state
			and lab._base_state == result.state.bases
			and lab._configured_match == null
		),
		"bound ordinary MatchState and base authority retained"
	)
	_check(property != null and property.valid_owner(lab), "bound exact installed ownership")
	_check(
		(
			lab.pool_controller_active != null
			and lab.pool_controller_active.enabled == active
			and lab.pool_controller_active.freeflight_enabled
		),
		"bound explicit enabled choice and default-disabled control"
	)
	_check(
		lab.is_physics_processing() and lab._primary_fielder.is_physics_processing(),
		"bound ordinary controller and fielder physics live"
	)
	return result


func _entitlement_controls() -> void:
	var setup: Dictionary = _configured(_ledger())
	var lab: PitchBatLab = setup.lab
	_check(not StadiumPoolBoundExtension.configure(lab, null), "bound absent token rejected")
	var token: StadiumPoolBoundEntitlement = StadiumPoolBoundEntitlement.issue_private(
		lab, setup.snapshot, setup.ledger
	)
	_check(token != null and token.descriptor().size() == 14, "bound exact finite token schema")
	_check(
		StadiumPoolBoundEntitlement.issue_private(lab, setup.snapshot, setup.ledger) == null,
		"bound duplicate private issue rejected"
	)
	var foreign: Dictionary = _configured(setup.ledger)
	_check(
		not StadiumPoolBoundExtension.configure(foreign.lab, token),
		"bound token cannot replay across lab or MatchState"
	)
	var copied: Dictionary = token.descriptor()
	copied.capacity = 99
	_check(token.descriptor().capacity == 4, "bound descriptor copy cannot mutate entitlement")
	var original: Dictionary = token._record.duplicate(true)
	for key: String in ["owner", "match", "capacity", "source_sha256", "base_key", "copy"]:
		token._record[key] = "tampered"
		_check(
			not StadiumPoolBoundExtension.configure(lab, token),
			"bound token field mutation rejected " + key
		)
		token._record = original.duplicate(true)
	_check(
		StadiumPoolBoundExtension.configure(lab, token), "bound restored original config accepted"
	)
	_check(not StadiumPoolBoundExtension.configure(lab, token), "bound duplicate config rejected")
	token.retire()
	_check(not token.valid_for(lab, setup.snapshot, "CONFIGURED"), "bound retired token rejected")
	lab.free()
	foreign.lab.free()
	var wrong: Dictionary = _configured(_ledger())
	wrong.state.stadium.layout.obstacles = [{"copy": "starter-v1:ST-003", "site": "O-R2", "yaw": 0}]
	_check(
		(
			StadiumPoolBoundEntitlement.issue_private(wrong.lab, wrong.state.stadium, wrong.ledger)
			== null
		),
		"bound nonexact base rejected"
	)
	wrong.lab.free()


# Negative-only transaction stage. Ordinary infrastructure is built with no property request;
# the exact same MatchState/snapshot/request is restored before calling the real installer.
# Positive histories never use this staging or change the configured snapshot.
func _transaction_stage() -> Dictionary:
	var setup: Dictionary = _configured(_ledger())
	var lab: PitchBatLab = setup.lab
	var token: StadiumPoolBoundEntitlement = StadiumPoolBoundEntitlement.issue_private(
		lab, setup.snapshot, setup.ledger
	)
	_check(StadiumPoolBoundExtension.configure(lab, token), "bound transaction token configured")
	var request: Variant = lab.get_meta(StadiumPoolBoundExtension.REQUEST)
	lab.remove_meta(StadiumPoolBoundExtension.REQUEST)
	setup.state.stadium = {}
	_host.add_child(lab)
	lab.set_process(false)
	setup.state.stadium = setup.snapshot.duplicate(true)
	lab.set_meta(StadiumPoolBoundExtension.REQUEST, request)
	setup["token"] = token
	_check(
		not lab.has_meta("stadium_property") and lab._match_state == setup.state,
		"bound negative transaction stage keeps ordinary infrastructure"
	)
	return setup


func _transaction_controls() -> void:
	var setup: Dictionary = _transaction_stage()
	var lab: PitchBatLab = setup.lab
	var original: Dictionary = setup.token._record.duplicate(true)
	setup.token._record.capacity = 5
	var before: Array = _transaction_snapshot(lab)
	_check(not StadiumPoolBoundExtension.install_bound(lab), "bound mutated token install rejected")
	_check(before == _transaction_snapshot(lab), "bound preflight rejection is complete no-op")
	setup.token._record = original
	lab._at_bat_cadence.begin_delivery(17)
	before = _transaction_snapshot(lab)
	_check(not StadiumPoolBoundExtension.install_bound(lab), "bound active delivery rejected")
	_check(before == _transaction_snapshot(lab), "bound delivery rejection is complete no-op")
	lab._at_bat_cadence.stop()
	# This fails the post-attachment plain_actors guard, exercising actual rollback.
	lab._primary_fielder.process_physics_priority = 1
	before = _transaction_snapshot(lab)
	_check(not StadiumPoolBoundExtension.install_bound(lab), "bound late actor failure rejected")
	_check(
		before == _transaction_snapshot(lab),
		"bound actual rollback restores children order callbacks metadata and visibility"
	)
	_check(
		(
			not setup.token.valid_for(lab, setup.snapshot, "CONFIGURED")
			and not setup.token.valid_for(lab, setup.snapshot, "INSTALLED")
		),
		"bound rolled-back token retired"
	)
	lab._primary_fielder.process_physics_priority = 0
	lab.queue_free()
	await _host.call("_ticks", 3)
	setup = _start()
	lab = setup.lab
	before = _transaction_snapshot(lab)
	_check(
		not StadiumPoolBoundExtension.install_bound(lab),
		"bound duplicate installed transaction rejected"
	)
	_check(
		before == _transaction_snapshot(lab), "bound duplicate rejection preserves current property"
	)
	var property: StadiumPoolBoundProperty = setup.property
	setup.token._record.capacity = 5
	_check(not property.valid_owner(lab), "bound installed token mutation rejected")
	setup.token._record.capacity = 4
	_check(property.valid_owner(lab), "bound exact installed token restored")
	var receiver_shape: CollisionShape3D = (
		property.receiver.chair.get_node("Collision/ST079_BACK").get_child(0)
	)
	var receiver_box: BoxShape3D = receiver_shape.shape as BoxShape3D
	var original_size: Vector3 = receiver_box.size
	receiver_box.size.x += 0.125
	_check(not property.valid_owner(lab), "bound between-launch receiver shape mutation rejected")
	receiver_box.size = original_size
	_check(property.valid_owner(lab), "bound original receiver shape restored")
	var extra_static: StaticBody3D = StaticBody3D.new()
	lab.add_child(extra_static)
	_check(not property.valid_owner(lab), "bound added static collider rejected")
	lab.remove_child(extra_static)
	extra_static.free()
	_check(property.valid_owner(lab), "bound original static collider inventory restored")
	var state: MatchState = lab._match_state
	lab._match_state = MatchLabSupport.create_match(
		PitchBatLab.DEBUG_PLAYER_ID, PitchBatLab.PLAYER_TEAM_NAME, PitchBatLab.RIVAL_TEAM_NAME
	)
	_check(not property.valid_owner(lab), "bound replacement MatchState owner rejected")
	lab._match_state = state
	property.pool_model.position.x += 0.125
	_check(not property.valid_owner(lab), "bound placement mutation rejected")
	property.pool_model.transform = StadiumPoolContract.placement()
	_check(property.valid_owner(lab), "bound restored profile original owner valid")
	lab.queue_free()
	await _host.call("_ticks", 3)


func _transaction_snapshot(lab: PitchBatLab) -> Array:
	var metadata: Array = []
	for key: StringName in StadiumPoolBoundExtension.META:
		metadata.append([key, lab.has_meta(key), lab.get_meta(key) if lab.has_meta(key) else null])
	var visibility: Array = []
	for key: StringName in StadiumPoolBoundExtension.VISIBILITY:
		var value: Variant = lab._camera_director.tracking_visibility.get(key)
		visibility.append(value.duplicate(true) if value is Array else value)
	return [
		StadiumPoolControllerShadow._tree_inventory(lab),
		metadata,
		visibility,
		lab._pitch_actor.receiver_router,
		lab._ball_play_resolver.segment_observer,
		lab._primary_fielder.stadium_boundary_clip,
		lab._primary_fielder.stadium_obstacles.duplicate(true),
		lab.pool_controller_active
	]


func _history_arm(case_name: String, arm: String) -> void:
	var setup: Dictionary = _start(arm == "s")
	var lab: PitchBatLab = setup.lab
	var property: StadiumPoolBoundProperty = setup.property
	if property == null or lab.pool_controller_active == null:
		_check(false, "bound history requires successfully installed property")
		lab.queue_free()
		await _host.call("_ticks", 3)
		_packets[case_name + ":" + arm] = PackedByteArray()
		return
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	if arm == "a":
		adapter.detach()
		_check(
			lab.pool_controller_active == null and property.valid_owner(lab),
			"bound A keeps exact property geometry with no adapter"
		)
	# Occupied bases are explicit fixture inputs using genuine roster identities.
	lab._base_state.first = lab._match_state.batting_team().roster[1].definition.id
	lab._base_state.second = lab._match_state.batting_team().roster[2].definition.id
	lab._base_state.third = lab._match_state.batting_team().roster[3].definition.id
	_check(
		(
			not lab._base_state.first.is_empty()
			and not lab._base_state.second.is_empty()
			and not lab._base_state.third.is_empty()
		),
		"bound occupied real-roster base inputs"
	)
	_receipt = StadiumPoolActiveReceipt.new()
	_check(_receipt.attach(lab), "bound unchanged fixed receipt attached to exact host")
	await _host.call("_ticks", 2)
	var histories: Array = []
	for ordinal: int in range(LAUNCHES_PER_ARM):
		var launch: BattedBallLaunch = _host.call("_pair_batted_launch", case_name == "dry")
		_check(launch != null and launch.is_foul, "bound fixed genuine bat-generated foul launch")
		if launch == null:
			break
		var commits: int = adapter.commits
		var bases: Array = StadiumPoolActiveReceipt.bases(lab)
		var strikes: int = lab._match_state.strikes
		_check(lab._match_state.begin_pitch(), "bound ordinary pitch state before generated ball")
		_receipt.begin(Engine.get_physics_frames())
		lab._start_ball_in_play(launch)
		_receipt.bind_owners()
		_check(_receipt.owned(), "bound unchanged receipt owner checks")
		_check(
			lab._batted_ball.body_entered.is_connected(
				property.expected_body_callback(lab._batted_ball, lab._ball_play_resolver)
			),
			"bound ordinary property body listener survives adapter bind"
		)
		_check(
			lab._batted_ball.tree_exited.is_connected(
				property.expected_exit_callback(lab._batted_ball)
			),
			"bound ordinary boundary retirement listener survives adapter bind"
		)
		_check(
			(
				lab._pitch_actor.receiver_router == property.receiver.route
				and lab._ball_play_resolver.segment_observer == StadiumBoundaryObserver.observe
			),
			"bound receiver and boundary authorities survive adapter bind"
		)
		if arm != "a":
			_check(
				(
					adapter.generation == ordinal + 1
					and (
						adapter._ordinary_router
						== property.expected_boundary_router(lab._ball_play_resolver)
					)
				),
				"bound one launch generation and preserved ordinary router"
			)
		if arm != "a" and ordinal == 0:
			# No simulation or callback executes while the owner pointer is absent.
			var resolver: BallPlayResolver = lab._ball_play_resolver
			lab._ball_play_resolver = null
			_check(
				not adapter._owned(), "bound missing resolver fails ownership without dereference"
			)
			lab._ball_play_resolver = resolver
			_check(adapter._owned(), "bound exact resolver owner restored before physics")
		await _window(lab, HISTORY_TICKS, true)
		_history_count += 1
		_check(_receipt.owned() and _receipt.failure.is_empty(), "bound complete unchanged receipt")
		_check(
			(
				_receipt.rows.size() >= HISTORY_TICKS
				and _receipt.rows.size() <= MAX_HISTORY_ROWS
				and _receipt.decision_count <= HISTORY_TICKS
			),
			"bound fixed receipt row and decision limits"
		)
		var late_count: int = 0
		for row: Array in _receipt.rows:
			if row[1] == "late":
				late_count += 1
		_check(late_count == HISTORY_TICKS, "bound all180 late frames retained")
		var expected: int = 1 if arm == "s" and case_name == "wet" else 0
		_check(adapter.commits == commits + expected, "bound exact active or negative commit count")
		_check(
			_receipt.outcomes.size() == 1 and lab._ball_play_resolver.state.dead,
			"bound ordinary terminal outcome exactly once"
		)
		_check(
			(
				StadiumPoolActiveReceipt.bases(lab) == bases
				and lab._match_state.strikes == mini(strikes + 1, 2)
			),
			"bound foul applies one strike and holds ordinary bases"
		)
		_check(
			(
				lab._batted_ball.freeze
				and lab._batted_ball.linear_velocity == Vector3.ZERO
				and lab._batted_ball.angular_velocity == Vector3.ZERO
			),
			"bound ordinary terminal physically stopped"
		)
		if expected == 1:
			_check(
				(
					_receipt.outcomes.size() == 1
					and _receipt.outcomes[0][2] == BallPlayOutcome.Result.FOUL
					and String(_receipt.outcomes[0][3]) == "private_pool_controller_water_foul"
				),
				"bound water uses ordinary foul authority"
			)
		histories.append(
			[
				_receipt.rows.duplicate(true),
				_receipt.outcomes.duplicate(true),
				_match_snapshot(lab),
				_receipt.decision_count
			]
		)
		_history_summary(lab, adapter, case_name, arm, ordinal + 1)
		var retired: BattedBallBody = lab._batted_ball
		lab._handle_match_advance()
		_check(
			lab._batted_ball == null and lab._match_state.phase == MatchState.Phase.PRE_PITCH,
			"bound ordinary advance retires ball and returns pre-pitch"
		)
		_check(
			(
				retired.physics_contact_router
				== property.expected_boundary_router(lab._ball_play_resolver)
			),
			"bound retirement removes only Pool router and retains ordinary boundary router"
		)
		_check(adapter.commits == commits + expected, "bound cleanup does not duplicate outcome")
		await _host.call("_ticks", 2)
	_packets[case_name + ":" + arm] = var_to_bytes(histories)
	lab.pool_active_receipt = null
	_receipt = null
	lab.queue_free()
	await _host.call("_ticks", 3)


func _history_summary(
	lab: PitchBatLab,
	adapter: StadiumPoolControllerActive,
	case_name: String,
	arm: String,
	ordinal: int
) -> void:
	var observed: Array = _receipt.outcomes[0] if _receipt.outcomes.size() == 1 else []
	var summary: String = JSON.stringify(
		{
			"arm": arm,
			"case": case_name,
			"ordinal": ordinal,
			"outcome_reason": String(observed[3]) if not observed.is_empty() else "",
			"outcome_tick": int(observed[0]) if not observed.is_empty() else -1,
			"outcome_count": _receipt.outcomes.size(),
			"adapter_commits": adapter.commits,
			"rows": _receipt.rows.size(),
			"decisions": _receipt.decision_count,
			"match_phase": int(lab._match_state.phase),
			"strikes": lab._match_state.strikes,
			"receipt_failure": _receipt.failure
		},
		"",
		true,
		true
	)
	_check(
		summary.to_utf8_buffer().size() <= MAX_SUMMARY_BYTES,
		"bound finite actual history diagnostic budget"
	)
	if summary.to_utf8_buffer().size() > MAX_SUMMARY_BYTES:
		return
	_summary_count += 1
	print("POOL_BOUND_V26_HISTORY " + summary)
	if _diagnostic:
		_diagnostic_summary(adapter, ordinal)


func _match_snapshot(lab: PitchBatLab) -> Array:
	var state: MatchState = lab._match_state
	return [
		state.phase,
		state.inning,
		state.top_half,
		state.outs,
		state.balls,
		state.strikes,
		state.plate_appearance_number,
		state.between_batters,
		state.last_event,
		state.away_team.runs,
		state.home_team.runs,
		StadiumPoolActiveReceipt.bases(lab)
	]


func _geometry_and_contacts() -> void:
	var setup: Dictionary = _start(true)
	var lab: PitchBatLab = setup.lab
	var property: StadiumPoolBoundProperty = setup.property
	if property == null:
		lab.queue_free()
		await _host.call("_ticks", 3)
		return
	await _host.call("_ticks", 2)
	var expanded: AABB = StadiumPoolBoundFootprint.reservation().grow(
		StadiumBoundaryGraph.DEFENDER_RADIUS
	)
	_check(
		StadiumProperty.contains("backyard", expanded), "bound full defender envelope within land"
	)
	for x: float in [expanded.position.x, expanded.end.x]:
		for z: float in [expanded.position.z, expanded.end.z]:
			_check(
				StadiumBoundaryGraph.contains(Vector2(x, z)),
				"bound full expanded corner within perimeter"
			)
	_check(
		(
			property.footprint.anchor_count == 16
			and property.footprint.anchor_routes_clear
			and property.footprint.receiver_clear
			and property.footprint.mound_charge_clear
		),
		"bound actual full spawn anchor route and receiver proof"
	)
	var obstacles: Array[Dictionary] = property.route_obstacles()
	_check(
		obstacles.size() == 2 and obstacles[1].radius == StadiumPoolBoundFootprint.ROUTE_RADIUS,
		"bound explicit conservative Pool route obstacle"
	)
	var center: Vector3 = StadiumPoolContract.placement().origin
	for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD]:
		var current: Vector3 = center - axis * 4.5
		var target: Vector3 = center + axis * 4.5
		for step: int in range(ROUTE_STEPS):
			var next: Vector3 = StadiumDefenderRoutes.step(current, target, 0.08, obstacles)
			_check(
				(
					StadiumDefenderRoutes.clear(current, next, obstacles)
					and StadiumBoundaryGraph.clip(current, next).is_equal_approx(next)
				),
				"bound swept route clears full reservation and defender perimeter"
			)
			_check(next.distance_to(current) <= 0.08001, "bound route preserves speed budget")
			current = next
		_check(current.distance_to(target) < 0.1, "bound finite route reaches opposite side")
	var hit: Dictionary = _ray(lab, center + Vector3(-4, 0.7, 0), center + Vector3(4, 0.7, 0))
	_check(
		not hit.is_empty() and property.pool_model.is_ancestor_of(hit.collider),
		"bound actual Pool wall ray obstruction"
	)
	_check(
		_ray(lab, center + Vector3(-4, 2.5, 0), center + Vector3(4, 2.5, 0)).is_empty(),
		"bound above-Pool control ray clear"
	)
	hit = _ray(lab, Vector3(0, 0.65, 0), Vector3(0, 0.65, -1.6))
	_check(
		not hit.is_empty() and property.receiver.chair.is_ancestor_of(hit.collider),
		"bound actual ordinary receiver ray survives"
	)
	hit = _ray(lab, Vector3(-10, 1, 22), Vector3(-10, 1, 25))
	_check(
		not hit.is_empty() and property.boundary.is_ancestor_of(hit.collider),
		"bound actual ordinary boundary ray survives"
	)
	# No receipt attaches here: its unchanged schema deliberately excludes stadium contacts.
	for contact_name: String in CONTACTS:
		await _ordinary_contact(lab, property, contact_name)
	lab.queue_free()
	await _host.call("_ticks", 3)


# Fixed positioned physical probes, never described as bat-generated trajectories.
# No signal emission, resolver contact injection, or fabricated contact batch/outcome.
func _ordinary_contact(lab: PitchBatLab, property: StadiumPoolBoundProperty, name: String) -> void:
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = Vector3(-10, 0.5, 10)
	launch.velocity = Vector3(0, -4, 0)
	launch.is_foul = true
	if name == "receiver":
		launch.position = Vector3(0, 0.65, -0.15)
		launch.velocity = Vector3(0, 0, -5)
	elif name == "boundary":
		launch.position = Vector3(-10, 1, 22.9)
		launch.velocity = Vector3(0, 0, 8)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	var commits: int = adapter.commits
	var before: Array = StadiumPoolActiveReceipt.bases(lab)
	_check(lab._match_state.begin_pitch(), "bound contact probe ordinary pitch transition")
	lab._start_ball_in_play(launch)
	_check(
		(
			adapter._guard != null
			and lab._batted_ball.physics_contact_router == adapter._guard.route
			and adapter._guard._ordinary_router == adapter._ordinary_router
			and (
				adapter._ordinary_router
				== property.expected_boundary_router(lab._ball_play_resolver)
			)
		),
		"bound one composed router before genuine contact"
	)
	await _window(lab, CONTACT_TICKS)
	_contact_count += 1
	var state: BallPlayState = lab._ball_play_resolver.state
	_check(
		adapter.commits == commits and not adapter.decline.is_empty(),
		"bound unsupported physical sequence permanently declines Pool"
	)
	_check(
		(
			state.dead
			and lab._match_state.phase == MatchState.Phase.PLAY_DEAD
			and StadiumPoolActiveReceipt.bases(lab) == before
		),
		"bound ordinary contact resolves after Pool decline"
	)
	if name == "ground":
		_check(state.has_grounded, "bound real ground history retained")
	elif name == "receiver":
		_check(
			not property.receiver.contacts.is_empty() and not state.stadium_contacts.is_empty(),
			"bound real receiver containment callback and history retained"
		)
	else:
		_check(not state.stadium_contacts.is_empty(), "bound real boundary history retained")
	_check(
		(
			lab._batted_ball.body_entered.is_connected(
				property.expected_body_callback(lab._batted_ball, lab._ball_play_resolver)
			)
			and lab._pitch_actor.receiver_router == property.receiver.route
		),
		"bound ordinary property and receiver remain connected after decline"
	)
	lab._handle_match_advance()
	_check(
		lab._batted_ball == null and lab._match_state.phase == MatchState.Phase.PRE_PITCH,
		"bound physical probe ordinary cleanup and advance"
	)
	await _host.call("_ticks", 2)


func _lifecycle_and_rematch() -> void:
	var setup: Dictionary = _start()
	var lab: PitchBatLab = setup.lab
	var property: StadiumPoolBoundProperty = setup.property
	if property == null:
		lab.queue_free()
		await _host.call("_ticks", 3)
		return
	var state: MatchState = lab._match_state
	var original_pa: int = state.plate_appearance_number
	# These are ordinary scoring/lifecycle method controls, not physical strikeout claims.
	for out_number: int in range(MatchState.OUTS_PER_HALF):
		for strike_number: int in range(MatchState.STRIKES_FOR_OUT):
			_check(state.begin_pitch(), "bound lifecycle ordinary pitch begins")
			state.record_called_pitch(true)
			lab._handle_match_advance()
			_check(
				state.phase == MatchState.Phase.PRE_PITCH and lab._base_state == state.bases,
				"bound ordinary at-bat or inning advance retains base authority"
			)
		_check(
			state.plate_appearance_number == original_pa + out_number + 1,
			"bound ordinary completed at-bat counter"
		)
	_check(
		not state.top_half and state.inning == 1 and state.outs == 0,
		"bound actual ordinary inning transition"
	)
	_check(
		property.valid_owner(lab) and setup.token.owns(lab, setup.snapshot, property),
		"bound same match token survives legal inning lifecycle"
	)
	var old_token: StadiumPoolBoundEntitlement = setup.token
	var fresh: Dictionary = _configured(_ledger())
	_check(
		not StadiumPoolBoundExtension.configure(fresh.lab, old_token),
		"bound old token rejected for fresh lab rematch"
	)
	fresh.lab.free()
	lab.remove_child(lab._primary_fielder)
	_check(not property.valid_owner(lab), "bound owner parent mutation rejected")
	lab.add_child(lab._primary_fielder)
	_check(property.valid_owner(lab), "bound exact owner parent restored")
	# Same-lab rematch intentionally fails closed before delivery; no warning waiver.
	lab._start_new_match()
	_check(
		lab.pool_bound_startup_failed and lab.pool_controller_active == null,
		"bound stale same-lab rematch revoked before delivery"
	)
	var before: Array = [
		_match_snapshot(lab),
		lab._throw_number,
		lab._pitch_actor.running,
		_transaction_snapshot(lab),
		lab._batted_ball
	]
	lab._throw_pitch()
	lab._start_ball_in_play(_host.call("_pair_batted_launch", false))
	lab._handle_match_advance()
	lab._process(1.0 / 60.0)
	lab._physics_process(1.0 / 60.0)
	_check(
		(
			before
			== [
				_match_snapshot(lab),
				lab._throw_number,
				lab._pitch_actor.running,
				_transaction_snapshot(lab),
				lab._batted_ball
			]
		),
		"bound rejected rematch pitch launch advance process and physics are no-op"
	)
	# Foreign replacements are never invoked. Teardown must clear only exact owned bindings.
	var foreign_callback: Callable = StadiumBoundaryGraph.crossing
	lab._pitch_actor.receiver_router = foreign_callback
	lab._ball_play_resolver.segment_observer = foreign_callback
	lab._primary_fielder.stadium_boundary_clip = foreign_callback
	var foreign_obstacles: Array[Dictionary] = [{"center": Vector3.ZERO, "radius": 0.25}]
	lab._primary_fielder.stadium_obstacles = foreign_obstacles
	lab.set_meta("boundary_signature", "foreign-owner")
	var weak_property: WeakRef = weakref(property)
	property.get_parent().remove_child(property)
	_check(
		(
			lab._pitch_actor.receiver_router == foreign_callback
			and lab._ball_play_resolver.segment_observer == foreign_callback
			and lab._primary_fielder.stadium_boundary_clip == foreign_callback
			and lab._primary_fielder.stadium_obstacles == foreign_obstacles
			and lab.get_meta("boundary_signature", "") == "foreign-owner"
		),
		"bound teardown preserves replaced foreign callbacks routes and metadata"
	)
	property.free()
	lab.queue_free()
	await _host.call("_ticks", 3)
	_check(weak_property.get_ref() == null, "bound teardown frees property and model ownership")
	var rematch: Dictionary = _start()
	_check(
		(
			rematch.token != old_token
			and rematch.property != null
			and rematch.property.valid_owner(rematch.lab)
		),
		"bound fresh lab and token rematch starts ordinarily"
	)
	_check(
		not old_token.valid_for(rematch.lab, rematch.snapshot, "INSTALLED"),
		"bound retired token cannot claim rematch"
	)
	rematch.lab.queue_free()
	await _host.call("_ticks", 3)


func _ray(lab: PitchBatLab, from: Vector3, to: Vector3) -> Dictionary:
	return lab.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from, to, 1)
	)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	_host.call("_check", ok, label)

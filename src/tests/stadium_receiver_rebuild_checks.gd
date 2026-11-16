extends "res://src/tests/equipment_visual_rebuild_checks.gd"
## One paid/cold/native receiver fixture. Six exact configurations; zero simulated games.

var _operands: Dictionary = {}
var _paid: ClubAssetLedger
var _credits: Array = []
var _progress: Array = []
var _copies: Dictionary = {}
var _configs: Array[Dictionary] = []
var _outcomes: Array = []
var _contact_cases: Array = []
var _report_provenance: Array = []
var _captures: Dictionary = {}
var _capture_item: String = ""
var _capture_checks: int = 0
var _geometry_checks: int = 0
var _visibility_checks: Array[int] = []


func _check(ok: bool, message: String) -> void:
	if not ok:
		print(
			(
				"RECEIVER_REBUILD_FAILURE "
				+ JSON.stringify(
					{"phase": _phase, "message": message, "operands": _operands}, "", true, true
				)
			)
		)
	super._check(ok, message)


func run(directory: String) -> Dictionary:
	_capture_dir = directory
	_check(
		DisplayServer.get_name() != "headless" and not directory.is_empty(),
		"one rendered receiver qualification with explicit output directory"
	)
	if _failures == 0:
		_check(DirAccess.make_dir_recursive_absolute(directory) == OK, "capture directory opens")
		_ownership()
		if _configs.size() == 6:
			_phase = "bounded-receiver-geometry"
			var root: Node3D = _world()
			var before: int = _checks
			await StadiumReceiverGeometryRebuildChecks.run(root, _check)
			_geometry_checks = _checks - before
			_check(
				_geometry_checks == StadiumReceiverGeometryRebuildChecks.EXPECTED_CHECKS,
				"all 145 bounded geometry assertions are reached"
			)
			await _close_view()
			for config: Dictionary in _configs:
				await _configuration(config)
			_montages()
	_phase = "completion"
	_check(
		_images == ["receiver-overview.png", "receiver-details.png"],
		"exactly two readable originals cover both field-facing catchers and real batting zoom extremes"
	)
	var payload: Dictionary = {
		"checks": _checks,
		"failures": _failures,
		"images": _images,
		"geometry_checks": _geometry_checks,
		"visibility_checks": _visibility_checks,
		"paid_copy_ids": _copies,
		"configurations": _configs,
		"contact_cases": _contact_cases,
		"report_provenance": _report_provenance,
		"games": 0,
		"synthetic_funding": true,
		"earned_career_claim": false,
		"live_game_claim": false,
		"final_art_acceptance_claim": false,
		"whole_game_acceptance_claim": false,
		"owner_correction":
		"should cage outer walls angle same as foul lines basically? not inwards?",
		"owner_correction_time": "2026-10-18 23:23:27",
		"measured_front_post_x": StadiumReceiverOwnedModels.CAGE_FRONT_X,
		"capture_layout":
		{
			"overview": "two native 1280x720 field views",
			"details": "four native 1280x720 batting zoom views"
		}
	}
	var file: FileAccess = FileAccess.open(
		directory.path_join("receiver-rebuild.json"), FileAccess.WRITE
	)
	_check(file != null, "bounded shared receiver evidence opens")
	if file != null:
		payload.checks = _checks
		payload.failures = _failures
		file.store_string(JSON.stringify(payload, "", true, true))
		file.flush()
		if file.get_error() != OK:
			_check(false, "receiver evidence fully writes")
		file.close()
	print(
		(
			"RECEIVER_REBUILD checks=%d failures=%d images=%d games=0 synthetic_funding=true"
			% [_checks, _failures, _images.size()]
		)
	)
	return {"checks": _checks, "failures": _failures}


func _buy(item: String, quantity: int, price_version: int) -> void:
	var revision: int = _paid.revision()
	var command: Dictionary = {
		"id": "receiver-buy:%d" % revision,
		"rev": revision,
		"op": "stadium_buy",
		"item": item,
		"quantity": quantity,
		"price_version": price_version,
		"through": _credits.size(),
		"progress_through": _progress.size()
	}
	var entry: Dictionary = StadiumCatalog.item(item)
	var expected: int = int(entry.blueprint_price) + int(entry.copy_price) * quantity
	var balance: int = _paid.balance()
	var result: Dictionary = _paid.commit(command)
	_operands = {"item": item, "error": result.get("error", ""), "expected_cost": expected}
	_check(
		result.ok and _paid.balance() == balance - expected,
		"ordinary unchanged blueprint and exact-copy purchase " + item
	)
	_check(
		_paid.commit(command).get("replayed", false) and _paid.balance() == balance - expected,
		"repeated purchase cannot double-charge or duplicate stock " + item
	)
	_copies[item] = []
	for index in range(quantity):
		_copies[item].append("purchase:receiver-buy:%d:%d" % [revision, index])


func _apply(layout: Dictionary) -> bool:
	var draft: Dictionary = _paid.commit(
		{
			"id": "receiver-draft:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_draft",
			"layout": layout
		}
	)
	if not draft.ok:
		_operands = {"error": draft.get("error", "")}
		return false
	var applied: Dictionary = _paid.commit(
		{
			"id": "receiver-apply:%d" % _paid.revision(),
			"rev": _paid.revision(),
			"op": "stadium_apply",
			"layout": layout,
			"geometry": StadiumOwnedLayout.geometry("club", layout)
		}
	)
	_operands = {"error": applied.get("error", "")}
	return applied.ok


func _ownership() -> void:
	_phase = "paid-stock-cold-replay-and-six-configurations"
	for index in range(40):
		_credits.append(1000)
		_progress.append({"seasons": 1, "wins": 5, "strikeouts": 5})
	_paid = ClubAssetLedger.new(91, _credits, _progress)
	var legacy: Dictionary = StadiumLayoutSnapshot.capture(_paid)
	_check(
		(
			_paid.construction().copies.size() == 3
			and StadiumCatalog.STARTERS == ["ST-001", "ST-003", "ST-079"]
		),
		"receiver work does not grant new starters or paid catchers"
	)
	for item: String in ["ST-072", "ST-073"]:
		var progress: Dictionary = (
			{"seasons": 4, "wins": 13} if item == "ST-072" else {"seasons": 10, "wins": 31}
		)
		_check(
			not (
				StadiumReceiverOwnedItems
				. quote(_paid.construction(), item, 1, "locked", progress)
				. ok
			),
			"unchanged career gate remains locked below its authored threshold " + item
		)
		_buy(item, 2, StadiumReceiverOwnedItems.PRICE_VERSION)
	_buy("ST-026", 1, StadiumPurchases.TARGET_VERSION)
	_copies["ST-079"] = ["starter-v1:ST-079"]
	_check(
		(
			_paid.construction().copies.size() == 8
			and _paid.to_data().version == ClubAssetLedger.RECEIVER_VERSION
		),
		"only five explicitly purchased copies are added under ledger32"
	)
	_check(
		StadiumLayoutSnapshot.matches(legacy, _paid),
		"old snapshot remains valid against its unchanged journal prefix"
	)
	for tier: String in ["expanded", "club"]:
		var land: Dictionary = _paid.commit(
			{
				"id": "receiver-land:" + tier,
				"rev": _paid.revision(),
				"op": "stadium_land",
				"tier": tier,
				"through": 40,
				"progress_through": 40,
				"price_version": StadiumLand.VERSION
			}
		)
		_check(land.ok, "ordinary purchased land prerequisite " + tier)
	var base: Dictionary = StadiumReceiverOwnedItems.upgrade(
		_paid.view().stadium_active, _paid.surface_owned()
	)
	_check(
		not base.is_empty() and base.version == 24 and base.catcher.is_empty(),
		"family24 upgrades inherited field state without selecting a paid assembly"
	)
	if base.is_empty():
		return
	var balance: int = _paid.balance()
	for item: String in ["ST-072", "ST-073"]:
		for primary: String in ["default", "ST-026", "ST-079"]:
			var layout: Dictionary = StadiumReceiverOwnedItems.select(
				base, _paid.construction(), _copies[item][0]
			)
			layout.receiver = _copies["ST-079"][0] if primary == "ST-079" else ""
			layout.target = _copies["ST-026"][0] if primary == "ST-026" else ""
			var checked: Dictionary = StadiumReceiverOwnedItems.validate(
				layout, _paid.construction(), "club"
			)
			_operands = {"catcher": item, "primary": primary, "error": checked.get("error", "")}
			_check(
				(
					checked.ok
					and checked.receiver_placements.size() == 1
					and checked.get("live_units", -1) == 0
				),
				"one exact catcher and legal primary validate without spending obstacle capacity"
			)
			_check(
				_apply(layout) and _paid.balance() == balance,
				"ordinary draft/apply changes the receiver configuration for free"
			)
			var snapshot: Dictionary = StadiumLayoutSnapshot.capture(_paid)
			_check(
				not snapshot.is_empty() and StadiumLayoutSnapshot.matches(snapshot, _paid),
				"exact receiver snapshot authenticates its purchased copies"
			)
			var cold: ClubAssetLedger = ClubAssetLedger.from_data(
				JSON.parse_string(JSON.stringify(_paid.to_data())), 91, _credits, _progress
			)
			_check(
				(
					cold != null
					and ClubCareer.same(cold.to_data(), _paid.to_data())
					and StadiumLayoutSnapshot.matches(snapshot, cold)
				),
				"cold JSON replay preserves this exact receiver configuration"
			)
			_configs.append(
				{"item": item, "primary": primary, "layout": layout, "snapshot": snapshot}
			)
		var swapped: Dictionary = StadiumReceiverOwnedItems.select(
			_configs[-1].layout, _paid.construction(), _copies[item][1]
		)
		var swapped_check: Dictionary = StadiumReceiverOwnedItems.validate(
			swapped, _paid.construction(), "club"
		)
		_check(
			(
				swapped_check.ok
				and swapped_check.stored.has(_copies[item][0])
				and _apply(swapped)
				and _paid.balance() == balance
			),
			"switching exact paid copies stores the old catcher without charging"
		)
		var removed: Dictionary = StadiumReceiverOwnedItems.select(
			swapped, _paid.construction(), ""
		)
		var removed_check: Dictionary = StadiumReceiverOwnedItems.validate(
			removed, _paid.construction(), "club"
		)
		_check(
			(
				removed_check.ok
				and removed_check.stored.has(_copies[item][1])
				and _apply(removed)
				and _apply(_configs[-1].layout)
				and _paid.balance() == balance
			),
			"storage and remount preserve purchased inventory and price"
		)
	var latest: Dictionary = _configs[-1].layout
	for mode: String in [
		"unowned",
		"wrong-item",
		"portable-conflict",
		"primary-conflict",
		"unknown-field",
		"wrong-family"
	]:
		var bad: Dictionary = latest.duplicate(true)
		match mode:
			"unowned":
				bad.catcher = "purchase:missing:0"
			"wrong-item":
				bad.catcher = _copies["ST-026"][0]
			"portable-conflict":
				bad.net = _copies["ST-073"][0]
			"primary-conflict":
				bad.target = _copies["ST-026"][0]
			"unknown-field":
				bad["phantom_receiver"] = true
			"wrong-family":
				bad.family = "reference-starter-v1"
		_check(
			not StadiumReceiverOwnedItems.validate(bad, _paid.construction(), "club").ok,
			"malformed or conflicting receiver selection fails closed " + mode
		)
	_check(
		not StadiumReceiverOwnedItems.validate(latest, _paid.construction(), "expanded").ok,
		"tall stadium net retains the existing Club-ground placement requirement"
	)
	_check(
		(
			_configs.size() == 6
			and _paid.balance() == balance
			and _paid.construction().copies.size() == 8
		),
		"six configurations and free storage transitions leave purchases and balance exact"
	)


func _configuration(config: Dictionary) -> void:
	_phase = "installed:" + config.item + ":" + config.primary
	var root: Node3D = _world()
	var lab: PitchBatLab = PitchBatLab.new()
	root.add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab._status_label.visible = false
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._batter_avatar.set_process(false)
	lab._pitcher_avatar.set_process(false)
	lab._bat_actor.set_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._match_state.stadium = config.snapshot.duplicate(true)
	lab._stadium_ledger = _paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	_operands = {"catcher": config.item, "primary": config.primary, "installed": installed}
	_check(
		installed, "ordinary frozen-snapshot startup installs complete owned receiver configuration"
	)
	if not installed:
		await _close_view()
		return
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var runtime: StadiumReceiverOwnedRuntime = (
		property.get_node_or_null("PitchReceiverPresentation") as StadiumReceiverOwnedRuntime
	)
	_check(
		runtime != null and runtime.intact() and property.props_intact(),
		"startup property guards accept every complete receiver and its query layer"
	)
	if runtime == null:
		await _close_view()
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(
		(
			runtime.net == property.objects[config.layout.catcher]
			and runtime.net.get_meta("owned_copy") == config.layout.catcher
		),
		"runtime catcher is the exact selected paid model"
	)
	_check(
		(
			(
				config.primary == "default"
				and runtime.primary == null
				and config.layout.receiver.is_empty()
				and config.layout.target.is_empty()
			)
			or (
				config.primary != "default"
				and is_instance_valid(runtime.primary)
				and runtime.primary.get_meta("stadium_item") == config.primary
			)
		),
		"empty primary creates no substitute while explicit target and chair remain exact"
	)
	var layers: bool = true
	var primary_copy: String = (
		"" if runtime.primary == null else str(runtime.primary.get_meta("owned_copy"))
	)
	for model: Node3D in [runtime.net, runtime.primary]:
		if model == null:
			continue
		var expected_mask: int = 0 if model.get_meta("stadium_item") == "ST-079" else 2
		for body: StaticBody3D in model.get_node("Collision").get_children():
			layers = layers and body.collision_layer == 17 and body.collision_mask == expected_mask
	_check(
		layers and property.props_intact(),
		"target chair and catcher enter physical startup with layer17 already guarded"
	)
	var obstacles: Array[Dictionary] = property.route_obstacles()
	_check(
		(
			obstacles.size() == (0 if primary_copy.is_empty() else 1)
			and obstacles.all(func(row: Dictionary) -> bool: return row.copy == primary_copy)
		),
		"catcher adds no live-route obstacle and preserves only the existing primary obstacle"
	)
	_check(
		(
			runtime.visibility != null
			and runtime.visibility.intact()
			and lab._pitch_actor.receiver_router == runtime.route
		),
		"actual pitch actor and owned visibility adapter are bound through ordinary startup"
	)
	_traces(runtime, config)
	await _actor_routes(lab, runtime, config)
	await _moving_ball(lab, runtime, config, false)
	if config.primary != "default":
		await _moving_ball(lab, runtime, config, true)
	else:
		await _above_top(lab, runtime, config)
	if config.item == "ST-072" and config.primary == "default":
		_same_flight_guards(lab, runtime)
	_check(
		property.props_intact() and runtime.intact(),
		"completed real pitch and ball responses preserve exact physical ownership"
	)
	if config.primary == "default":
		# Let the actual response settle before collecting still diagnostic views.
		await get_tree().create_timer(0.60).timeout
		_capture_item = config.item
		var before: int = _checks
		var captures_before: int = _capture_checks
		await StadiumReceiverVisibilityRebuildChecks.run(
			root, _check, lab, runtime.visibility, _collect_capture
		)
		var reached: int = _checks - before - (_capture_checks - captures_before)
		_visibility_checks.append(reached)
		_check(
			reached == StadiumReceiverVisibilityRebuildChecks.EXPECTED_CHECKS,
			"all 44 single-catcher visibility assertions are reached"
		)
	await _close_view()


func _traces(runtime: StadiumReceiverOwnedRuntime, config: Dictionary) -> void:
	var cage: bool = config.item == "ST-072"
	var center: String = "ST072_REAR_MESH" if cage else "ST073_CENTER_NET"
	var primary: String = (
		"ST026_PANEL"
		if config.primary == "ST-026"
		else "ST079_BACK" if config.primary == "ST-079" else center
	)
	var cases: Array = [
		[Vector3(0, 0.66, 0), primary],
		[Vector3(1.25, 1.4, 0), center],
		[Vector3(2.8, 1.4, 0), "ST072_WING_R" if cage else "ST073_NET_R"],
		[Vector3(-2.8, 1.4, 0), "ST072_WING_L" if cage else "ST073_NET_L"],
		[
			Vector3(0, 3.07, -2.65) if cage else Vector3(4.5, 6.7, -2.7),
			"ST072_FRAME" if cage else "ST073_POLE1"
		],
		[
			Vector3(2.2, 0.03, -3.0) if cage else Vector3(4.85, 0.10, -2.9),
			"ST072_SUPPORTS" if cage else "ST073_ANCHOR1"
		]
	]
	for row: Array in cases:
		var path: Dictionary = runtime.trace(row[0], Vector3(0, 0, -40), 0.0365)
		_operands = {
			"configuration": config.item + ":" + config.primary, "expected": row[1], "path": path
		}
		_check(
			(
				not path.is_empty()
				and path.hit.get("surface", "") == row[1]
				and path.reason == "receiver_contact"
			),
			"actual post-call sweep selects earliest named primary panel frame or support"
		)
		var observed: Dictionary = path.get("hit", {}).duplicate(true)
		if observed.get("position") is Vector3:
			var point: Vector3 = observed.position
			observed.position = [point.x, point.y, point.z]
		_contact_cases.append(
			{
				"configuration": config.item + ":" + config.primary,
				"query": "pitch",
				"expected": row[1],
				"hit": observed
			}
		)
	var miss: Dictionary = runtime.trace(
		Vector3(0, 4 if cage else 8, 0), Vector3(0, 0, -40), 0.0365
	)
	_check(
		(
			not miss.is_empty()
			and miss.hit.is_empty()
			and miss.reason == "receiver_cleanup"
			and absf(miss.points[-1].z - (-3.10 if cage else -5.20)) < 0.0002
		),
		"above-top pitch remains uncontained until the actual configuration cleanup plane"
	)
	var slow: Dictionary = runtime.trace(Vector3(6, 1.4, 0), Vector3(0, 0, -1), 0.0365)
	_check(
		(
			not slow.is_empty()
			and slow.hit.is_empty()
			and slow.reason == "receiver_presentation_timeout"
		),
		"complete slow miss times out without inventing a receiving contact"
	)
	_check(
		(
			runtime.trace(Vector3.ZERO, Vector3.FORWARD, 0).is_empty()
			and runtime.trace(Vector3(NAN, 0, 0), Vector3.FORWARD, 0.0365).is_empty()
		),
		"invalid pitch sphere or nonfinite start is rejected before querying physics"
	)
	_check(runtime.contacts.is_empty(), "read-only pitch traces do not emit presentation contacts")


func _actor_routes(
	lab: PitchBatLab, runtime: StadiumReceiverOwnedRuntime, config: Dictionary
) -> void:
	var actor: PitchFlightActor = lab._pitch_actor
	var state: MatchState = lab._match_state
	var logical: Array = [
		state.phase,
		state.balls,
		state.strikes,
		state.outs,
		state.inning,
		state.pitcher().pitch_count,
		state.pitch_ledger._pitchers.duplicate(true)
	]
	runtime.contacts.clear()
	actor.visible = true
	actor.global_position = Vector3(1.25, 1.4, 0)
	_check(
		actor.receiver_router.call(actor, actor.global_position, Vector3(0, 0, -40)),
		"actual bound pitch actor starts its post-call receiver route"
	)
	await get_tree().create_timer(0.45).timeout
	_check(
		(
			runtime.contacts.size() == 1
			and runtime.contacts[0].copy == config.layout.catcher
			and runtime.contacts[0].kind == "pitch"
			and runtime.last_reason == "receiver_contact"
			and not actor.visible
		),
		"actual routed actor produces one catcher response and then hides"
	)
	runtime.contacts.clear()
	actor.visible = true
	actor.global_position = Vector3(0, 4 if config.item == "ST-072" else 8, 0)
	_check(
		actor.receiver_router.call(actor, actor.global_position, Vector3(0, 0, -40)),
		"actual above-top actor starts its uncontained cleanup route"
	)
	await get_tree().create_timer(0.45).timeout
	_check(
		(
			runtime.contacts.is_empty()
			and runtime.last_reason == "receiver_cleanup"
			and not actor.visible
		),
		"actual missed actor cleans up without a fake impact or extra receiving event"
	)
	_check(
		(
			logical
			== [
				state.phase,
				state.balls,
				state.strikes,
				state.outs,
				state.inning,
				state.pitcher().pitch_count,
				state.pitch_ledger._pitchers
			]
		),
		"post-call routing leaves logical calls counts statistics and pitch ledger untouched"
	)


func _ball(lab: PitchBatLab, at: Vector3) -> Dictionary:
	_outcomes.clear()
	var resolver: BallPlayResolver = BallPlayResolver.new()
	resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID))
	resolver.segment_observer = lab._ball_play_resolver.segment_observer
	resolver.play_resolved.connect(
		func(outcome: BallPlayOutcome) -> void: _outcomes.append(outcome)
	)
	var ball: BattedBallBody = BattedBallBody.new()
	ball.gravity_scale = 0
	ball.aero_drag_coefficient = 0
	ball.aero_magnus_scale = 0
	ball.aero_perforation_force_scale = 0
	lab.add_child(ball)
	ball.position = at
	_check(
		(
			resolver.segment_observer.is_valid()
			and StadiumPropertyRuntime.bind_ball(lab, ball, resolver)
		),
		"ordinary property router binds the fresh dynamic ball with the installed report observer"
	)
	return {"ball": ball, "resolver": resolver}


func _moving_ball(
	lab: PitchBatLab, runtime: StadiumReceiverOwnedRuntime, config: Dictionary, primary: bool
) -> void:
	runtime.contacts.clear()
	var at: Vector3 = Vector3(0, 0.66, 0) if primary else Vector3(1.25, 1.4, 0)
	var context: Dictionary = _ball(lab, at)
	# Accepted dynamic-body registration path: allow two native frames before launch.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = at
	launch.velocity = Vector3(0, 0, -20)
	context.ball.launch(launch)
	for frame in range(50):
		await get_tree().physics_frame
		context.resolver.advance_time(1.0 / 60.0)
		if context.resolver.state.dead:
			break
	var expected: String = (
		str(runtime.primary.get_meta("owned_copy")) if primary else str(config.layout.catcher)
	)
	var events: Array = context.resolver.state.stadium_contacts
	_operands = {
		"configuration": config.item + ":" + config.primary,
		"primary_first": primary,
		"events": events,
		"position": str(context.ball.global_position),
		"velocity": str(context.ball.linear_velocity)
	}
	_check(
		(
			events.size() == 1
			and events[0].source == "item"
			and events[0].id == expected
			and events[0].role == "RECEIVER_CONTAINMENT_FOUL"
			and _outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.FOUL
		),
		"actual moving ball reaches one exact owned receiver and resolves terminal Foul"
	)
	context.resolver.record_clean_control(&"late_fielder", context.ball.global_position, true)
	_check(
		(
			_outcomes.size() == 1
			and _outcomes[0].result == BallPlayOutcome.Result.FOUL
			and context.resolver.state.dead
			and context.resolver.state.last_obstacle_contact == &""
		),
		"a later defensive catch cannot replace receiver Foul or spend obstacle authority"
	)
	_check(
		(
			runtime.contacts.size() == 1
			and runtime.contacts[0].kind == "batted"
			and runtime.contacts[0].copy == expected
		),
		"the physical contact produces exactly one matching batted receiving response"
	)
	_report(context.resolver, config, "primary" if primary else "catcher")
	context.ball.free()
	await get_tree().physics_frame


func _above_top(lab: PitchBatLab, runtime: StadiumReceiverOwnedRuntime, config: Dictionary) -> void:
	runtime.contacts.clear()
	var context: Dictionary = _ball(lab, Vector3(0, 4 if config.item == "ST-072" else 8, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	var launch: BattedBallLaunch = BattedBallLaunch.new()
	launch.position = context.ball.position
	launch.velocity = Vector3(0, 0, -20)
	context.ball.launch(launch)
	for frame in range(12):
		await get_tree().physics_frame
	_check(
		(
			not context.resolver.state.dead
			and context.resolver.state.stadium_contacts.is_empty()
			and runtime.contacts.is_empty()
		),
		"moving ball above actual top remains live before any later field boundary"
	)
	context.ball.free()
	await get_tree().physics_frame


func _same_flight_guards(lab: PitchBatLab, runtime: StadiumReceiverOwnedRuntime) -> void:
	var property: StadiumPropertyGeometry = lab.get_meta("stadium_property")
	var context: Dictionary = _ball(lab, Vector3(1.25, 1.4, 0))
	var replacement: BattedBallBody = BattedBallBody.new()
	replacement.freeze = true
	lab.add_child(replacement)
	replacement.position = Vector3(1.25, 1.4, 0)
	_check(
		StadiumPropertyRuntime.bind_ball(lab, replacement, context.resolver),
		"a fresh replacement ball becomes the one current physical contact owner"
	)
	var body: StaticBody3D = runtime.net.get_node("Collision/ST072_REAR_MESH")
	property._receiver_native_contact(body, context.ball, context.resolver, Vector3(0, 1.4, -2.65))
	_check(
		not context.resolver.state.dead and context.resolver.state.stadium_contacts.is_empty(),
		"an earlier ball cannot reuse the current resolver after a physical rebind"
	)
	var foreign: StaticBody3D = StaticBody3D.new()
	lab.add_child(foreign)
	for key: String in ["owned_copy", "stadium_item", "surface_id", "surface_role", "ball_surface"]:
		foreign.set_meta(key, body.get_meta(key))
	property._receiver_native_contact(
		foreign, replacement, context.resolver, Vector3(0, 1.4, -2.65)
	)
	_check(
		(
			not context.resolver.state.dead
			and context.resolver.state.stadium_contacts.is_empty()
			and (
				runtime
				. _owned_hit(
					{"collider_id": foreign.get_instance_id(), "point": Vector3(0, 1.4, -2.65)}, 0.0
				)
				. is_empty()
			)
		),
		"foreign collision claiming the exact current copy cannot impersonate an issued receiver body"
	)
	foreign.free()
	replacement.free()
	context.ball.free()


func _report(resolver: BallPlayResolver, config: Dictionary, part: String) -> void:
	var events: Array = resolver.state.stadium_contacts.duplicate(true)
	var reason: String = "" if _outcomes.is_empty() else str(_outcomes[0].reason)
	var rows: Array = [{"play": 0, "reason": reason, "events": events}]
	var plays: Array = [
		{"result": "foul", "contact": ContactResult.Outcome.CONTACT, "exit_speed": 20.0}
	]
	var exact: bool = (
		events.size() == 1
		and SeasonOwnership._keys(
			events[0], ["source", "id", "surface", "role", "position", "time", "kind"]
		)
	)
	var accepted: bool = exact and PhysicalStadiumContacts.valid(rows, plays, config.snapshot)
	_check(
		accepted, "existing report consumer accepts the seven-field actual item contact unchanged"
	)
	for field: String in ["id", "surface"]:
		var altered: Array = rows.duplicate(true)
		if not events.is_empty():
			altered[0].events[0][field] = "UNOWNED"
		_check(
			(
				not events.is_empty()
				and not PhysicalStadiumContacts.valid(altered, plays, config.snapshot)
			),
			"report rejects a forged exact receiver " + field
		)
	_report_provenance.append(
		{
			"configuration": config.item + ":" + config.primary,
			"part": part,
			"events": events,
			"reason": reason,
			"accepted": accepted
		}
	)


func _collect_capture(label: String) -> void:
	var title: Label = Label.new()
	title.text = _capture_item + " | " + label.replace("receiver_", "").replace("_", " ").to_upper()
	title.position = Vector2(22, 18)
	title.add_theme_font_size_override("font_size", 23)
	_view.add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _view.get_texture().get_image()
	_capture_checks += 1
	_check(
		not image.is_empty() and image.get_size() == SIZE,
		"actual installed native view captured " + _capture_item + ":" + label
	)
	if not image.is_empty():
		_captures[_capture_item + ":" + label] = image
	title.queue_free()
	await get_tree().process_frame


func _montages() -> void:
	_phase = "two-native-receiver-montages"
	var overview: Image = Image.create(SIZE.x * 2, SIZE.y, false, Image.FORMAT_RGBA8)
	var details: Image = Image.create(SIZE.x * 2, SIZE.y * 2, false, Image.FORMAT_RGBA8)
	var complete: bool = true
	for index in range(2):
		var item: String = "ST-072" if index == 0 else "ST-073"
		for row in range(3):
			var label: String = [
				"receiver_field_facing", "receiver_batting_zoom_in", "receiver_batting_zoom_out"
			][row]
			var key: String = item + ":" + label
			if not _captures.has(key):
				complete = false
				continue
			var image: Image = _captures[key]
			image.convert(Image.FORMAT_RGBA8)
			if row == 0:
				overview.blit_rect(image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(index * SIZE.x, 0))
			else:
				details.blit_rect(
					image, Rect2i(Vector2i.ZERO, SIZE), Vector2i(index * SIZE.x, (row - 1) * SIZE.y)
				)
	_check(
		complete and _captures.size() == 6,
		"six actual native views provide the two complete readable comparison originals"
	)
	if not complete:
		return
	for row: Array in [["receiver-overview.png", overview], ["receiver-details.png", details]]:
		_check(
			row[1].save_png(_capture_dir.path_join(row[0])) == OK,
			"combined original PNG saved " + str(row[0])
		)
		_images.append(row[0])

extends "res://src/tests/stadium_owned_waterfall_animation_test.gd"
## Focused current47/base45 issued lifecycle controls. Synthetic funding/progression,
## real paid journals and exact-copy installations. No completed games or native
## visual qualification. Run this scene with --animation-runtime after integration.
## The inherited paid/cold/base46 ownership checks remain; their old runtime body
## is deliberately not run. Base46 issued/runtime qualification has its own scene.

var lifecycle_installations: int = 0
var lifecycle_cases: Array[String] = []


func _runtime(source: ClubAssetLedger, live: bool) -> void:
	if not live:
		return
	var began_checks: int = checks
	for scenario: String in [
		"positive",
		"supported_write",
		"owner_replacement",
		"receipt_replacement",
		"required_delete",
		"hierarchy",
		"internal_child",
		"raw_history",
		"native_shape",
		"property_shape",
		"report_stripping",
		"current_reach",
		"route_callback",
		"current_route",
		"absence_metadata",
		"absence_objects"
	]:
		await _lifecycle_case(source, scenario)
	await _phase_write_guard_case(source, "phase_foreign_listener")
	await _phase_write_guard_case(source, "phase_foreign_resource")
	# Preserve the exact journal-buy/native-sweep structure of the prior active
	# absence controls, but use real47/base45 issued decorative installations.
	# A live waterfall already consumes all four units: explicitly store it first.
	await _active_feature(source, "ST-005")
	await _active_feature(source, "ST-002")
	print(
		(
			"WATERFALL_ANIMATION_LIFECYCLE_RESULT "
			+ JSON.stringify(
				{
					"checks": checks - began_checks,
					"failures": failures,
					"installations": lifecycle_installations,
					"cases": lifecycle_cases,
					"synthetic_funding": true,
					"synthetic_progression": true,
					"runtime_base": 45,
					"physical_games": 0,
					"matched_240_tick_probe": false,
					"native_visual_qualification": false
				}
			)
		)
	)


func _lifecycle_install(source: ClubAssetLedger, label: String) -> Dictionary:
	var paid: ClubAssetLedger = ClubAssetLedger.from_data(source.to_data(), 216, credits, progress)
	check(paid != null, "lifecycle cold paid source " + label)
	if paid == null:
		return {}
	var snapshot: Dictionary = StadiumWaterfallAnimationSnapshot.fixture(
		StadiumLayoutSnapshot.capture(paid), 216, 1
	)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._at_bat_cadence.stop()
	lab._match_state.stadium = snapshot
	lab._stadium_ledger = paid
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	lifecycle_installations += 1
	check(installed, "fresh exact47/base45 paid installation " + label)
	if not installed:
		lab.free()
		return {}
	var property: StadiumWaterfallAnimationProperty = lab.get_meta("stadium_property")
	var boundary: StadiumWaterfallAnimationBoundary = property.get_node("BoundaryGraph")
	var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(lab)
	check(owner != null, "exact47 motion owner exists " + label)
	if owner == null:
		lab.free()
		return {}
	owner.set_process(false)
	var receipt: Dictionary = lab._match_state.stadium
	check(
		(
			receipt.version == 35
			and receipt.layout.version == 47
			and receipt.layout.animation_base == 45
			and _recursive_read_only(receipt)
			and ClubCareer.same(receipt, snapshot)
		),
		"original47 receipt recursively frozen without projecting identity " + label
	)
	check(
		(
			property._issued_live
			and property.props_intact()
			and property.deep_props_intact()
			and boundary.intact()
			and boundary.deep_intact()
			and StadiumWaterfallAnimationInstall.installed_bound(lab, receipt)
		),
		"fresh hot and deep issued authority agree " + label
	)
	return {
		"lab": lab,
		"paid": paid,
		"property": property,
		"boundary": boundary,
		"owner": owner,
		"receipt": receipt
	}


func _recursive_read_only(value: Variant) -> bool:
	if value is Dictionary:
		if not value.is_read_only():
			return false
		for nested: Variant in value.values():
			if not _recursive_read_only(nested):
				return false
	elif value is Array:
		if not value.is_read_only():
			return false
		for nested: Variant in value:
			if not _recursive_read_only(nested):
				return false
	return true


func _lifecycle_case(source: ClubAssetLedger, scenario: String) -> void:
	var fixture: Dictionary = _lifecycle_install(source, scenario)
	if fixture.is_empty():
		return
	lifecycle_cases.append(scenario)
	var lab: PitchBatLab = fixture.lab
	var paid: ClubAssetLedger = fixture.paid
	var property: StadiumWaterfallAnimationProperty = fixture.property
	var boundary: StadiumWaterfallAnimationBoundary = fixture.boundary
	var owner: StadiumWaterfallAnimationRuntime = fixture.owner
	if scenario == "positive":
		_positive_lifecycle(fixture)
	elif scenario in ["absence_metadata", "absence_objects"]:
		check(
			(
				property.issued_feature_absent(&"live_furnishings")
				and property.issued_feature_absent(&"salvage_car")
			),
			"both empty features have real positive absence certificates " + scenario
		)
		if scenario == "absence_metadata":
			for key: String in ["live_furnishing_layout", "salvage_car_layout"]:
				check(property.has_meta(key), "issued empty metadata exists " + key)
				if property.has_meta(key):
					var original: Dictionary = property.get_meta(key)
					property.set_meta(key, original.duplicate(true))
		else:
			property.objects = property.objects.duplicate()
		check(
			(
				not property.issued_feature_absent(&"live_furnishings")
				and not property.issued_feature_absent(&"salvage_car")
			),
			"equal-valued replacement cannot retain an issued absence shortcut " + scenario
		)
	else:
		if scenario in ["raw_history", "native_shape", "property_shape", "report_stripping"]:
			_prepare_report_control(lab, scenario)
		match scenario:
			"supported_write":
				var generation: int = paid.mutation_generation()
				var result: Dictionary = paid.commit(
					{
						"id": "lifecycle-supported-draft",
						"rev": paid.revision(),
						"op": "stadium_draft",
						"layout": paid.view().stadium_draft
					}
				)
				check(
					result.ok and paid.mutation_generation() != generation,
					"actual supported paid writer advances generation"
				)
			"owner_replacement":
				# Equal content from a real cold journal is not the issued paid object.
				lab._stadium_ledger = ClubAssetLedger.from_data(
					paid.to_data(), 216, credits, progress
				)
				check(
					lab._stadium_ledger != null and lab._stadium_ledger != paid,
					"paid owner replacement is a valid distinct ledger"
				)
			"receipt_replacement":
				# Never attempt to mutate the installed read-only receipt in place.
				lab._match_state.stadium = fixture.receipt.duplicate(true)
				check(
					(
						ClubCareer.same(lab._match_state.stadium, fixture.receipt)
						and not is_same(lab._match_state.stadium, fixture.receipt)
					),
					"equal-value receipt replacement really changes container identity"
				)
			"required_delete":
				var shapes: Array[Node] = boundary.find_children(
					"*", "CollisionShape3D", true, false
				)
				check(
					not shapes.is_empty(), "required native node exists for queued-deletion control"
				)
				if not shapes.is_empty():
					shapes[0].queue_free()
			"hierarchy":
				boundary.add_child(Node3D.new())
			"internal_child":
				var water: Node = property.objects[LIVE].get_node("Visual/Pool")
				water.add_child(Node3D.new(), false, Node.INTERNAL_MODE_BACK)
				check(
					water.get_child_count(true) > water.get_child_count(),
					"hidden internal child was really attached"
				)
			"raw_history":
				var generation: int = paid.mutation_generation()
				check(not paid._events.is_empty(), "real paid history exists for deep control")
				if not paid._events.is_empty():
					paid._events[0]["id"] = "lifecycle-foreign-old-history"
				check(
					paid.mutation_generation() == generation,
					"old-history debugger change leaves supported generation untouched"
				)
			"native_shape":
				var shapes: Array[Node] = boundary.find_children(
					"*", "CollisionShape3D", true, false
				)
				check(
					not shapes.is_empty(), "issued native shape exists for deep admission control"
				)
				if not shapes.is_empty():
					(shapes[0] as CollisionShape3D).disabled = true
			"property_shape":
				var shapes: Array[Node] = property.objects[LIVE].find_children(
					"*", "CollisionShape3D", true, false
				)
				check(
					not shapes.is_empty(),
					"actual live waterfall native collider exists for direct transition control"
				)
				if not shapes.is_empty():
					(shapes[0] as CollisionShape3D).disabled = true
			"report_stripping":
				lab._match_state.stadium = {}
				lab.remove_meta(StadiumWaterfallAnimationInstall.BOUND)
				lab.remove_meta("stadium_property")
			"current_reach":
				lab._primary_fielder.reach_m = StadiumWaterfallLiveModels.MAX_DEFENDER_REACH + 0.01
			"route_callback":
				lab._primary_fielder.stadium_waterfall_step = Callable()
			"current_route":
				lab._primary_fielder.global_position = (
					StadiumWaterfallLiveRoutes.CENTER + Vector3(0, 0, -1.1)
				)
				check(
					not StadiumWaterfallLiveRoutes.legal(
						lab._primary_fielder.global_position, boundary.graph
					),
					"current defender really occupies the forbidden basin"
				)
		if (
			scenario
			in [
				"supported_write",
				"owner_replacement",
				"receipt_replacement",
				"required_delete",
				"hierarchy",
				"internal_child",
				"current_reach",
				"route_callback",
				"current_route"
			]
		):
			check(
				not property.props_intact() and not boundary.intact(),
				"supported/current lifetime guard refuses before any deep transition " + scenario
			)
		if scenario != "report_stripping":
			_assert_bind_refused(fixture, scenario)
		check(
			not property.deep_props_intact() and not boundary.deep_intact(),
			"deep transition refuses changed authority " + scenario
		)
		check(
			not property.props_intact() and not property._issued_live and not boundary.intact(),
			"failure is sticky across repeated issued action guards " + scenario
		)
		if scenario != "report_stripping":
			check(
				not StadiumWaterfallAnimationRuntime.before_pitch(lab),
				"before-pitch guard refuses the retired issued owner " + scenario
			)
		if scenario in ["raw_history", "native_shape", "property_shape", "report_stripping"]:
			check(
				(
					not StadiumWaterfallAnimationInstall.installed_bound(
						lab, lab._match_state.stadium
					)
					and PhysicalMatchReport.capture(lab).is_empty()
				),
				"deep failed47 report never falls back to ordinary baseball " + scenario
			)
		if scenario in ["current_reach", "route_callback", "current_route"]:
			var from: Vector3 = lab._pitcher_marker.global_position
			var target: Vector3 = from + Vector3(0.5, 0, 0)
			check(
				(
					property.waterfall_step(from, target, 0.1) == from
					and property.waterfall_clip(from, target) == from
					and StadiumPropertyRuntime.pitcher_step(lab, target, 0.1, target) == from
					and not StadiumPropertyRuntime.clear_control(lab, lab._primary_fielder, target)
				),
				"current reach/callback/route refusal blocks movement and pickup " + scenario
			)
		var phase: float = owner._lease.phase
		owner._process(0.1)
		check(
			owner.retired and owner._lease.phase == phase,
			"revoked owner retires without repairing phase " + scenario
		)
	lab.free()
	await get_tree().process_frame


func _positive_lifecycle(fixture: Dictionary) -> void:
	var lab: PitchBatLab = fixture.lab
	var property: StadiumWaterfallAnimationProperty = fixture.property
	var boundary: StadiumWaterfallAnimationBoundary = fixture.boundary
	var owner: StadiumWaterfallAnimationRuntime = fixture.owner
	var receipt: Dictionary = fixture.receipt
	check(
		(
			property.has_live_waterfall()
			and property.issued_feature_absent(&"live_furnishings")
			and property.issued_feature_absent(&"salvage_car")
		),
		"live waterfall does not erase the two separate empty-feature certificates"
	)
	for feature: StringName in [
		&"waterfall", &"live_waterfall", &"live_waterfalls", &"unknown", &""
	]:
		check(
			not property.issued_feature_absent(feature),
			"unknown and live-waterfall keys never authorize a shortcut " + String(feature)
		)
	lab._match_state.phase = MatchState.Phase.PLAY_DEAD
	lab._at_bat_cadence.state = AtBatCadenceController.State.IDLE
	owner._process(0.1)
	check(
		owner._lease.phase > 0 and _full_motion_proof(fixture),
		"quiet phase advance preserves the full native, resource and original receipt proof"
	)
	check(
		owner._lease.reset() and owner._lease.phase == 0 and _full_motion_proof(fixture),
		"quiet reset changes only owned uniforms and preserves deep proof"
	)
	owner._process(0.1)
	var phase: float = owner._lease.phase
	for action: MatchState.Phase in [
		MatchState.Phase.PRE_PITCH, MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY
	]:
		lab._match_state.phase = action
		owner._process(0.15)
		check(
			(
				owner._lease.advance(0.1, false, false)
				and owner._lease.reset()
				and owner._lease.phase == phase
				and _full_motion_proof(fixture)
			),
			"active phase and direct lease calls freeze without mutation " + str(action)
		)
	lab._match_state.phase = MatchState.Phase.PLAY_DEAD
	lab._debug_paused = true
	owner._process(0.15)
	check(
		owner._lease.phase == phase and _full_motion_proof(fixture),
		"actual pause freezes with deep proof"
	)
	lab._debug_paused = false
	owner._process(0.4)
	check(
		owner._lease.phase == phase and _full_motion_proof(fixture),
		"long frame freezes without catch-up"
	)
	# Explicit synthetic quiet fixture, not gameplay outcome or renderer timing.
	# Measure only routine CPU-owned uniform updates, excluding deep setup/proof.
	var quiet_samples: Array[int] = []
	var quiet_exact: bool = true
	var quiet_start: float = owner._lease.phase
	for index in range(30):
		var expected_phase: float = fposmod(
			owner._lease.phase + 0.1 * StadiumWaterfallAnimationLease.SPEED, 1.0
		)
		var started_us: int = Time.get_ticks_usec()
		owner._process(0.1)
		quiet_samples.append(Time.get_ticks_usec() - started_us)
		quiet_exact = (
			quiet_exact
			and not owner.retired
			and is_equal_approx(owner._lease.phase, expected_phase)
		)
	quiet_samples.sort()
	var quiet_total: int = 0
	for sample: int in quiet_samples:
		quiet_total += sample
	check(
		quiet_exact and _full_motion_proof(fixture),
		"thirty routine quiet phase updates preserve exact water phase and final full proof"
	)
	print(
		(
			"WATERFALL47_QUIET_UPDATES "
			+ JSON.stringify(
				{
					"updates": quiet_samples.size(),
					"input_delta": 0.1,
					"total_cpu_us": quiet_total,
					"median_update_us": quiet_samples[quiet_samples.size() / 2],
					"p95_update_us": quiet_samples[int(quiet_samples.size() * 0.95)],
					"max_update_us": quiet_samples.back(),
					"start_phase": quiet_start,
					"end_phase": owner._lease.phase,
					"exact_phase_updates": quiet_exact,
					"synthetic_quiet_fixture": true,
					"renderer_or_hardware_qualification": false
				}
			)
		)
	)
	phase = owner._lease.phase
	check(
		StadiumWaterfallAnimationRuntime.before_pitch(lab) and owner._lease.phase == phase,
		"before-pitch guard preserves the exact frozen phase"
	)
	var ball: BattedBallBody = _unbound_ball(lab)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	check(
		StadiumPropertyRuntime.bind_ball(lab, ball, resolver),
		"public47 bind accepts a real issued flight"
	)
	var flight: Dictionary = boundary._flights.get(resolver.get_instance_id(), {})
	check(
		(
			not flight.is_empty()
			and flight.ball.get_ref() == ball
			and flight.resolver == resolver
			and flight.state == resolver.state
			and flight.field == resolver.field
			and flight.parent == ball.get_parent()
			and int(flight.serial) > 0
			and ball.physics_contact_router == boundary._contact_batch.bind(resolver)
			and ball.body_entered.is_connected(property._ball_contact.bind(ball, resolver))
		),
		"successful public bind owns the exact flight, router and property listener"
	)
	check(
		is_same(lab._match_state.stadium, receipt) and _full_motion_proof(fixture),
		"phase and successful bind retain the exact original immutable47 receipt"
	)


func _full_motion_proof(fixture: Dictionary) -> bool:
	var owner: StadiumWaterfallAnimationRuntime = fixture.owner
	var property: StadiumWaterfallAnimationProperty = fixture.property
	return (
		not owner.retired
		and owner.intact()
		and owner._lease.presentation_intact()
		and property.props_intact()
		and property.deep_props_intact()
		and fixture.boundary.deep_intact()
		and is_same(fixture.lab._match_state.stadium, fixture.receipt)
	)


func _unbound_ball(lab: PitchBatLab) -> BattedBallBody:
	var ball: BattedBallBody = BattedBallBody.new()
	ball.freeze = true
	lab.add_child(ball)
	lab._ball_play_resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	return ball


func _assert_bind_refused(fixture: Dictionary, scenario: String) -> void:
	var lab: PitchBatLab = fixture.lab
	var boundary: StadiumWaterfallAnimationBoundary = fixture.boundary
	var ball: BattedBallBody = _unbound_ball(lab)
	var resolver: BallPlayResolver = lab._ball_play_resolver
	var body_listeners: int = ball.body_entered.get_connections().size()
	var launch_listeners: int = ball.launch_started.get_connections().size()
	var exit_listeners: int = ball.tree_exited.get_connections().size()
	check(
		(
			not boundary.bind_issued_ball(ball, resolver)
			and not StadiumPropertyRuntime.bind_ball(lab, ball, resolver)
		),
		"public and direct issued bind refuse before dispatch " + scenario
	)
	check(
		(
			boundary._flights.is_empty()
			and not ball.physics_contact_router.is_valid()
			and ball.body_entered.get_connections().size() == body_listeners
			and ball.launch_started.get_connections().size() == launch_listeners
			and ball.tree_exited.get_connections().size() == exit_listeners
		),
		"refused admission installs no flight, router or listeners " + scenario
	)


func _prepare_report_control(lab: PitchBatLab, scenario: String) -> void:
	lab._automation = MatchAutomation.new()
	# Ordinary real roster input only: this is report formation, not game completion.
	for team: TeamMatchState in [lab._match_state.away_team, lab._match_state.home_team]:
		for player: PlayerMatchState in team.roster:
			lab._automation.initial[String(player.definition.id)] = player.stamina_remaining
	check(
		not PhysicalMatchReport._capture_core(lab).is_empty(),
		"report negative has a real nonempty ordinary-core control " + scenario
	)


func _active_feature(source: ClubAssetLedger, item: String) -> void:
	var car: bool = item == "ST-005"
	var paid: ClubAssetLedger = ClubAssetLedger.from_data(source.to_data(), 216, credits, progress)
	check(paid != null, "active feature uses the inherited real paid journal " + item)
	if paid == null:
		return
	var request: String = "lifecycle-active-" + item
	var copy: String = "purchase:" + request + ":0"
	var balance: int = paid.balance()
	var purchased: Dictionary = paid.commit(
		{
			"id": request,
			"rev": paid.revision(),
			"op": "stadium_buy",
			"item": item,
			"quantity": 1,
			"price_version":
			(
				StadiumSalvageCarItems.PRICE_VERSION
				if car
				else StadiumLiveFurnishingItems.PRICE_VERSION
			),
			"through": credits.size(),
			"progress_through": progress.size()
		}
	)
	var stock: StadiumStock = paid.construction()
	var owned: Dictionary = stock.copies.get(copy, {})
	check(
		(
			purchased.get("ok", false)
			and paid.balance() == balance - (810 if car else 205)
			and owned.get("item") == item
			and owned.get("source") == "purchase-v1"
			and owned.get("paid", -1) == (190 if car else 45)
		),
		"one exact ST-005/ST-002 copy is journal-paid without inventory injection " + item
	)
	if not purchased.get("ok", false):
		return
	var layout: Dictionary = StadiumWaterfallAnimationLayout.store_copy(
		paid.view().stadium_active, LIVE
	)
	var retained: Dictionary = StadiumWaterfallAnimationLayout.base(layout)
	retained = (
		StadiumSalvageCarItems.place(
			retained, stock, copy, StadiumSalvageCarItems.SITE, paid.surface_owned()
		)
		if car
		else StadiumLiveFurnishingItems.place(retained, stock, copy, "O-R2")
	)
	layout = StadiumWaterfallAnimationLayout.with_base(layout, retained)
	var feature: StringName = &"salvage_car" if car else &"live_furnishings"
	var selected: Array = layout.get("salvage_cars" if car else "live_furnishings", [])
	check(
		(
			layout.get("version") == 47
			and layout.get("animation_base") == 45
			and layout.get("live_waterfalls", []).is_empty()
			and layout.get("waterfall_motion") == [PLAZA]
			and selected.size() == 1
			and selected[0].get("copy") == copy
			and _valid(paid, layout).ok
		),
		"legal decorative47 layout retains one paid active feature " + item
	)
	if not _apply(paid, layout, "lifecycle-active-" + item):
		return
	var fixture: Dictionary = _lifecycle_install(paid, "active-" + item)
	if fixture.is_empty():
		return
	lifecycle_cases.append("active-" + item)
	var property: StadiumWaterfallAnimationProperty = fixture.property
	var boundary: StadiumWaterfallAnimationBoundary = fixture.boundary
	check(
		not property.has_live_waterfall() and not property.issued_feature_absent(feature),
		"nonempty paid feature does not prevent issuance and never claims its own absence " + item
	)
	var ball: BattedBallBody = _unbound_ball(fixture.lab)
	check(
		StadiumPropertyRuntime.bind_ball(fixture.lab, ball, fixture.lab._ball_play_resolver),
		"real47 issued flight still binds with an active feature " + item
	)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var model: Node3D = property.objects.get(copy)
	var surface: String = StadiumJunkCarModels.SURFACE if car else "BEACH_BALL"
	var body: StaticBody3D = (
		model.get_node_or_null("Collision/" + surface) if is_instance_valid(model) else null
	)
	check(
		property.deep_props_intact() and boundary.deep_intact() and is_instance_valid(body),
		"active feature retains real issued native body " + item
	)
	if is_instance_valid(body):
		var previous: Vector3 = model.to_global(
			Vector3(-2, 0.55, 0) if car else Vector3(-1, 0.4, 0)
		)
		var current: Vector3 = model.to_global(Vector3(0, 0.55, 0) if car else Vector3(0, 0.4, 0))
		var hit: Dictionary = boundary.event(
			previous, current, 0.0365, fixture.lab._ball_play_resolver
		)
		check(
			(
				hit.get("kind") == ("junk_car_solid" if car else "furnishing_solid")
				and hit.get("swept_contact", false)
				and hit.get("surface") == surface
				and hit.get("role") == "LIVE_RICOCHET"
				and hit.get("owned_copy") == copy
				and hit.get("body_id", 0) == body.get_instance_id()
				and float(hit.get("fraction", -1.0)) > 0
				and float(hit.get("fraction", 1.0)) < 1
				and int(hit.get("issued", 0)) > 0
			),
			(
				"unchanged handler reaches an exact paid-body native sweep through boundary.event "
				+ item
			)
		)
	fixture.lab.free()
	await get_tree().process_frame


func _phase_write_guard_case(source: ClubAssetLedger, scenario: String) -> void:
	var fixture: Dictionary = _lifecycle_install(source, scenario)
	if fixture.is_empty():
		return
	lifecycle_cases.append(scenario)
	var lab: PitchBatLab = fixture.lab
	var property: StadiumWaterfallAnimationProperty = fixture.property
	var lease: StadiumWaterfallAnimationLease = fixture.owner._lease
	lab._match_state.phase = MatchState.Phase.PLAY_DEAD
	lab._at_bat_cadence.state = AtBatCadenceController.State.IDLE
	check(
		lease.advance(0.1, false, false) and lease.phase > 0,
		"fresh quiet issued lease advances before its isolated write guard " + scenario
	)
	var phase: float = lease.phase
	# Capture all water targets so a refusal cannot hide partial writes to an
	# earlier material. This is test observation, not a production deep scan.
	var water_phases: Array[Dictionary] = []
	for copy: String in property._waterfall_animation_copies:
		var visual: Node3D = StadiumWaterfallAnimatedModels.visual(property.objects[copy])
		for part: String in StadiumWaterfallMotionModels.WATER:
			var material: ShaderMaterial = visual.get_node(part).material_override
			water_phases.append(
				{"material": material, "phase": material.get_shader_parameter("phase")}
			)
	var water: MeshInstance3D = property.objects[LIVE].get_node("Visual/LowerRillB")
	var original: ShaderMaterial = water.material_override
	var probe: Dictionary = {"calls": 0}
	var foreign_listener: Callable = func() -> void: probe.calls += 1
	var foreign_material: ShaderMaterial = null
	var foreign_shader: Shader = null
	var foreign_material_fields: Dictionary = {}
	var foreign_shader_fields: Dictionary = {}
	if scenario == "phase_foreign_listener":
		check(
			(
				original.changed.connect(foreign_listener) == OK
				and original.changed.is_connected(foreign_listener)
				and probe.calls == 0
			),
			"unexpected listener is attached to an exact live-water target without firing"
		)
	else:
		foreign_material = original.duplicate(true) as ShaderMaterial
		foreign_shader = original.shader.duplicate(true) as Shader
		foreign_material.shader = foreign_shader
		foreign_material.set_shader_parameter("phase", fposmod(phase + 0.37, 1.0))
		foreign_material_fields = StadiumWaterfallMotionOwner._resource_fields(foreign_material)
		foreign_shader_fields = StadiumWaterfallMotionOwner._resource_fields(foreign_shader)
		water.material_override = foreign_material
		check(
			(
				foreign_material != original
				and foreign_shader != original.shader
				and water.material_override == foreign_material
			),
			"water target really has distinct material and shader resources"
		)
	# No deep proof, report, props check or before-pitch call intervenes: the
	# routine write gate itself must refuse before touching any water uniform.
	var accepted: bool = lease.advance(0.1, false, false)
	var unchanged: bool = lease.phase == phase
	for row: Dictionary in water_phases:
		unchanged = unchanged and row.material.get_shader_parameter("phase") == row.phase
	check(
		not accepted and lease.retired and unchanged and probe.calls == 0,
		"routine advance refuses before any phase write or foreign callback " + scenario
	)
	if foreign_material != null:
		check(
			(
				water.material_override == foreign_material
				and foreign_material.shader == foreign_shader
				and StadiumWaterfallMotionOwner._fields_equal(
					foreign_material, foreign_material_fields
				)
				and StadiumWaterfallMotionOwner._fields_equal(foreign_shader, foreign_shader_fields)
			),
			"refusal neither repairs nor mutates the distinct foreign water resources"
		)
	lab.free()
	await get_tree().process_frame

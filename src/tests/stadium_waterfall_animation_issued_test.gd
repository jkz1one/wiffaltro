extends "res://src/tests/stadium_owned_waterfall_animation_test.gd"


## Exact47/base46 adapter controls. Synthetic funding, no completed-game claim.
func _runtime(source: ClubAssetLedger, live: bool) -> void:
	if live:
		return
	if "--animation-attach-only" in OS.get_cmdline_user_args():
		await _attach_callback_control(source)
		return
	for scenario: String in ["decorative", "empty", "history", "shape", "snapshot", "hierarchy"]:
		var paid: ClubAssetLedger = ClubAssetLedger.from_data(
			source.to_data(), 216, credits, progress
		)
		if scenario == "empty":
			var layout: Dictionary = paid.view().stadium_active.duplicate(true)
			layout.waterfall_motion = []
			if not _apply(paid, layout, "empty47-issued-control"):
				continue
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
		lab._match_state.stadium = snapshot
		lab._stadium_ledger = paid
		var installed: bool = StadiumPropertyRuntime.install_bound(lab)
		check(installed, "explicit47/base46 issued install " + scenario)
		if not installed:
			lab.free()
			continue
		var property: StadiumWaterfallAnimationProperty = lab.get_meta("stadium_property")
		var boundary: StadiumWaterfallAnimationLowBoundary = property.get_node("BoundaryGraph")
		var owner: StadiumWaterfallAnimationRuntime = StadiumWaterfallAnimationRuntime.current(lab)
		if owner != null:
			owner.set_process(false)
		check(
			(
				lab._match_state.stadium.is_read_only()
				and lab._match_state.stadium.layout.is_read_only()
				and ClubCareer.same(lab._match_state.stadium, snapshot)
			),
			"original47 receipt is recursively readonly without projecting identity " + scenario
		)
		check(
			(
				property._issued_live
				and property.issued_props_intact(lab)
				and boundary.deep_intact()
				and StadiumWaterfallAnimationInstall.installed_bound(lab, snapshot)
			),
			"exact issued action plus deep report authority " + scenario
		)
		check(
			(owner == null) == (scenario == "empty"),
			"empty motion has no owner; decorative owns its exact lease " + scenario
		)
		check(
			(
				not property.has_live_waterfall()
				and not StadiumPropertyGeometry.construction_target_allowed(property)
				and not StadiumPropertyGeometry.construction_target_allowed(boundary)
			),
			"46 composition never grants live trap or rebuilding authority " + scenario
		)
		lab._automation = MatchAutomation.new()
		for team: TeamMatchState in [lab._match_state.away_team, lab._match_state.home_team]:
			for player: PlayerMatchState in team.roster:
				lab._automation.initial[String(player.definition.id)] = player.stamina_remaining
		check(
			not PhysicalMatchReport._capture_core(lab).is_empty(),
			"deep report refusal has real ordinary core content " + scenario
		)
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		var resolver: BallPlayResolver = lab._ball_play_resolver
		resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
		var connections: int = ball.body_entered.get_connections().size()
		match scenario:
			"history":
				paid._events[0]["id"] = "foreign-unissued-history"
			"shape":
				var shapes: Array[Node] = boundary.find_children(
					"*", "CollisionShape3D", true, false
				)
				(shapes[0] as CollisionShape3D).disabled = true
			"snapshot":
				lab._match_state.stadium = {}
			"hierarchy":
				boundary.add_child(Node3D.new())
		if scenario in ["history", "shape"]:
			check(
				boundary.intact(),
				"unsupported debugger edit is only claimed at deep transitions " + scenario
			)
		var accepted: bool = StadiumPropertyRuntime.bind_ball(lab, ball, resolver)
		if scenario in ["decorative", "empty"]:
			check(accepted, "outer47 bind succeeds only with a real issued flight " + scenario)
			var flight: Dictionary = boundary._flights.get(resolver.get_instance_id(), {})
			check(
				(
					not flight.is_empty()
					and flight.ball.get_ref() == ball
					and flight.state == resolver.state
					and ball.physics_contact_router == boundary._contact_batch.bind(resolver)
				),
				"true bind preserves current47 exact native flight/router " + scenario
			)
		else:
			check(
				(
					not accepted
					and boundary._flights.is_empty()
					and not ball.physics_contact_router.is_valid()
					and ball.body_entered.get_connections().size() == connections
				),
				"failed47 deep preflight adds no flight/router/listener " + scenario
			)
			check(
				(
					not StadiumWaterfallAnimationInstall.installed_bound(
						lab, lab._match_state.stadium
					)
					and PhysicalMatchReport.capture(lab).is_empty()
				),
				"failed47 deep report cannot fall back " + scenario
			)
		if scenario == "empty":
			check(
				StadiumWaterfallAnimationRuntime.before_pitch(lab),
				"empty47 pre-pitch accepts exact issued context without clock owner"
			)
			paid._events[0]["id"] = "empty47-old-history-deep-control"
			check(
				(
					not StadiumWaterfallAnimationRuntime.before_pitch(lab)
					and not property._issued_live
				),
				"empty47 pre-pitch performs deep history refusal without clock owner"
			)
		lab.free()
		await get_tree().process_frame

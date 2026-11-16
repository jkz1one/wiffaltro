extends "res://src/tests/stadium_low_wall_guard_test.gd"


## Deep admission happens before listeners, and success means a newly issued flight.
func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	for scenario: String in ["valid", "history", "shape", "stale"]:
		var paid: ClubAssetLedger = ClubAssetLedger.from_data(
			ledger.to_data(), 194, credits, progress
		)
		var lab: PitchBatLab = _install(paid)
		if not lab.has_meta("stadium_property"):
			lab.free()
			continue
		var property: StadiumLowWallProperty = lab.get_meta("stadium_property")
		var boundary: StadiumLowWallBoundaryRuntime = property.get_node("BoundaryGraph")
		var ball: BattedBallBody = BattedBallBody.new()
		ball.freeze = true
		lab.add_child(ball)
		var resolver: BallPlayResolver = lab._ball_play_resolver
		resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
		var before_connections: int = ball.body_entered.get_connections().size()
		match scenario:
			"history":
				paid._events[0]["id"] = "foreign-history"
			"shape":
				var shapes: Array[Node] = boundary.find_children(
					"*", "CollisionShape3D", true, false
				)
				(shapes[0] as CollisionShape3D).disabled = true
			"stale":
				lab._match_state.stadium = {}
		if scenario in ["history", "shape"]:
			check(
				boundary.intact(),
				profile + " deep-only change remains outside hot debugger contract " + scenario
			)
		var accepted: bool = StadiumPropertyRuntime.bind_ball(lab, ball, resolver)
		if scenario == "valid":
			check(accepted, profile + " unchanged outer bind accepts")
			var flight: Dictionary = boundary._flights.get(resolver.get_instance_id(), {})
			check(
				(
					not flight.is_empty()
					and flight.ball.get_ref() == ball
					and flight.state == resolver.state
				),
				profile + " true means exact current issued flight"
			)
			check(
				ball.physics_contact_router == boundary._contact_batch.bind(resolver),
				profile + " single inherited native router installed"
			)
		else:
			check(not accepted, profile + " outer bind refuses " + scenario)
			check(
				boundary._flights.is_empty(), profile + " refused bind issues no flight " + scenario
			)
			check(
				ball.body_entered.get_connections().size() == before_connections,
				profile + " refused preflight adds no property listeners " + scenario
			)
			check(
				not ball.physics_contact_router.is_valid(),
				profile + " refused preflight installs no router " + scenario
			)
			check(
				not boundary.bind_issued_ball(ball, resolver),
				profile + " explicit issued result also refuses " + scenario
			)
		lab.free()
		await get_tree().process_frame

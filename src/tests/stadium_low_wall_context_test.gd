extends "res://src/tests/stadium_owned_low_wall_test.gd"


func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = snapshot
	lab._stadium_ledger = ledger
	check(StadiumPropertyRuntime.install_bound(lab), profile + " review actual paid installation")
	await get_tree().physics_frame
	var property: StadiumLowWallProperty = lab.get_meta("stadium_property")
	var boundary: StadiumLowWallBoundaryRuntime = property.get_node("BoundaryGraph")
	check(StadiumLowWallRuntime.installed_bound(lab, snapshot), profile + " baseline installed")
	var live_ball: BattedBallBody = BattedBallBody.new()
	live_ball.freeze = true
	lab.add_child(live_ball)
	lab._ball_play_resolver.start_play(ContentDB.get_field(PitchBatLab.FIELD_ID), false)
	check(
		StadiumPropertyRuntime.bind_ball(lab, live_ball, lab._ball_play_resolver),
		profile + " valid live binding"
	)
	var old_state: MatchState = lab._match_state
	var foreign_state: MatchState = MatchState.new()
	foreign_state.stadium = snapshot.duplicate(true)
	var prior_field: String = lab._field_id
	for change: String in [
		"snapshot", "field", "state_identity", "ledger_identity", "property_claim"
	]:
		var issued: Dictionary = boundary.event(
			Vector3(17, 2, 23), Vector3(17, 2, 24), live_ball.radius_m, lab._ball_play_resolver
		)
		match change:
			"snapshot":
				lab._match_state.stadium = {}
			"field":
				lab._field_id = "foreign-field"
			"state_identity":
				lab._match_state = foreign_state
			"ledger_identity":
				lab._stadium_ledger = ledger.prefix(ledger.revision())
			"property_claim":
				lab.set_meta("stadium_property", null)
			"installed_snapshot":
				lab.set_meta("stadium_snapshot", {})
		check(
			not StadiumLowWallRuntime.installed_bound(lab, snapshot),
			profile + " " + change + " rejects installed status"
		)
		check(not property.props_intact(), profile + " " + change + " rejects property context")
		check(not boundary.intact(), profile + " " + change + " rejects contact owner context")
		check(
			not boundary.apply_event(lab._ball_play_resolver, issued),
			profile + " " + change + " cannot consume prior issued event"
		)
		lab._match_state = old_state
		lab._match_state.stadium = snapshot
		lab._field_id = prior_field
		lab._stadium_ledger = ledger
		lab.set_meta("stadium_property", property)
		lab.set_meta("stadium_snapshot", snapshot)
		check(
			StadiumLowWallRuntime.installed_bound(lab, snapshot),
			profile + " " + change + " restoration intact"
		)
	live_ball.free()
	lab.queue_free()
	await get_tree().process_frame

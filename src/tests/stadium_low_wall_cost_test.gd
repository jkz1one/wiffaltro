extends "res://src/tests/stadium_owned_low_wall_test.gd"


func _runtime(ledger: ClubAssetLedger, profile: String) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = StadiumLayoutSnapshot.capture(ledger)
	lab._stadium_ledger = ledger
	if not check_install(lab):
		lab.free()
		return
	var property: StadiumLowWallProperty = lab.get_meta("stadium_property")
	var boundary: StadiumLowWallBoundaryRuntime = property.get_node("BoundaryGraph")
	print(
		(
			"LOW_GUARD_COUNTS "
			+ JSON.stringify(
				{
					"profile": profile,
					"nodes": boundary._low_nodes.size(),
					"resources": boundary._low_resources.size(),
					"pool": boundary._low_pool_evidence
				}
			)
		)
	)
	for probe: String in ["context", "boundary", "property", "installed"]:
		var start: int = Time.get_ticks_usec()
		for i in range(10):
			var ok: bool = false
			match probe:
				"context":
					ok = property.low_context_intact()
				"boundary":
					ok = boundary.intact()
				"property":
					ok = property.props_intact()
				"installed":
					ok = StadiumLowWallRuntime.installed_bound(lab, lab._match_state.stadium)
			check(ok, "unchanged cost probe " + probe)
		print(
			(
				"LOW_COST "
				+ JSON.stringify(
					{
						"profile": profile,
						"probe": probe,
						"calls": 10,
						"elapsed_us": Time.get_ticks_usec() - start
					}
				)
			)
		)
	lab.free()
	await get_tree().process_frame


func check_install(lab: PitchBatLab) -> bool:
	var ok: bool = StadiumPropertyRuntime.install_bound(lab)
	check(ok, "cost probe real paid installation")
	return ok

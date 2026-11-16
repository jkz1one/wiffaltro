extends "res://src/tests/stadium_owned_low_wall_test.gd"


## Paid low-wall clock adapter, synthetic presentation transition only; zero games.
func _runtime(source: ClubAssetLedger, profile: String) -> void:
	var ledger: ClubAssetLedger = ClubAssetLedger.from_data(
		source.to_data(), 194, credits, progress
	)
	for tier: String in ["expanded", "club", "mogul"]:
		check(
			(
				ledger
				. commit(
					{
						"id": "clock-land-" + tier,
						"rev": ledger.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": 40,
						"progress_through": 40,
						"price_version": StadiumLand.VERSION
					}
				)
				. ok
			),
			"owned clock land"
		)
	for item: Array in [["ST-035", "clock-gate", 12], ["ST-069", "clock-mount", 29]]:
		var bought: Dictionary = ledger.commit(
			{
				"id": item[1],
				"rev": ledger.revision(),
				"op": "stadium_buy",
				"item": item[0],
				"quantity": 1,
				"price_version": item[2],
				"through": 40,
				"progress_through": 40
			}
		)
		check(bought.ok, "exact clock purchase: " + bought.error)
	var layout: Dictionary = ledger.view().stadium_active.duplicate(true)
	var base: Dictionary = StadiumLowWallLayout.base(layout)
	base = StadiumStraightItemsUI.select(
		base,
		ledger.construction(),
		"purchase:clock-gate:0",
		{"copy": "", "site": "ENTRY-GATE", "lower": "", "concourse": ""}
	)
	base = StadiumMountedDisplayItems.place(
		base,
		ledger.construction(),
		"purchase:clock-mount:0",
		"purchase:clock-gate:0",
		"CLOCK-GATE-CENTER",
		ledger.surface_owned()
	)
	layout = StadiumLowWallLayout.with_base(layout, base)
	var valid: Dictionary = StadiumLowWallLayout.validate(
		layout, ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), "mogul"
	)
	check(
		valid.ok and layout.mounted_displays.size() == 1,
		"full owned clock/low composition: " + valid.error
	)
	if not valid.ok:
		return
	check(
		(
			ledger
			. commit(
				{
					"id": "clock-draft",
					"rev": ledger.revision(),
					"op": "stadium_draft",
					"layout": layout
				}
			)
			. ok
		),
		"clock paid draft"
	)
	check(
		(
			ledger
			. commit(
				{
					"id": "clock-apply",
					"rev": ledger.revision(),
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumLowWallLayout.geometry("mogul", layout)
				}
			)
			. ok
		),
		"clock paid apply"
	)
	var lab: PitchBatLab = PitchBatLab.new()
	add_child(lab)
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	PitchBatLabPresentation.hide_match_presentation(lab)
	lab.set_process(false)
	lab.set_physics_process(false)
	lab._pitch_actor.set_physics_process(false)
	lab._primary_fielder.set_physics_process(false)
	lab._match_state.stadium = StadiumLayoutSnapshot.capture(ledger)
	lab._stadium_ledger = ledger
	check(StadiumPropertyRuntime.install_bound(lab), "actual clock low install " + profile)
	var owner: StadiumMountedClockRuntime = StadiumMountedClockRuntime.current(lab)
	check(owner != null and owner.intact(), "exact versioned adapter owner")
	if owner != null and owner.intact():
		check(owner.clock_value().seconds_of_day == 47400, "initial authoritative clock")
		lab._match_state.phase = MatchState.Phase.PRE_PITCH
		lab._match_state.top_half = false
		lab._pitch_actor.running = false
		check(
			(
				StadiumMountedClockRuntime.before_pitch(lab)
				and owner.clock_value().seconds_of_day == 47520
			),
			"safe synthetic half transition advances120s"
		)
		var model: Node3D = lab.get_meta("stadium_property").objects["purchase:clock-mount:0"]
		var hand: Node3D = model.get_node("MinuteHandPivot")
		var pose: Transform3D = hand.transform
		hand.position.x += 0.01
		check(not owner.intact(), "foreign hand pose refused")
		hand.transform = pose
		check(owner.intact(), "exact leased hand restored")
		lab._match_state.stadium = {}
		check(
			not owner.intact() and not StadiumMountedClockRuntime.before_pitch(lab),
			"mutated complete context retires clock"
		)
	check(lab._play_records.is_empty(), "clock probe invents no plays")
	lab.queue_free()
	await get_tree().process_frame

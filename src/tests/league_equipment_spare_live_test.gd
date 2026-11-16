extends "res://src/tests/league_equipment_proof_test.gd"
## One actual detached physical game: paid active/spare Gear and zero-capacity Budget.
## Funding and sponsors are synthetic paid journals, not naturally earned season progress.
## report27 stays unchanged; actual first-release receipt evidence is retained beside it.


func _ready() -> void:
	var human_bank: SeasonOwnership = paid_bank(
		[], ["BAT-CON-01", "BALL-MOV-01", "MISC-PIT-03"], "BAT-POW-01"
	)
	var ai_bank: SeasonOwnership = zero_budget_bank()
	var state: MatchState = detached_request(human_bank, ai_bank)
	var active: Array[String] = SeasonReclamation.receipts(human_bank.view())
	var spare: Dictionary = human_bank.view().spare.duplicate(true)
	var before: Array = [human_bank.to_data(), ai_bank.to_data()]
	check(
		active.size() == 3 and not active.has(spare.id),
		"live fixture has three active paid receipts and one inactive paid spare"
	)
	check(
		(
			state.away_team.ai_budget.outcome == "full"
			and state.away_team.ai_tactical_initial.is_empty()
		),
		"live Equipment F09/E08 request has zero carry and no grant"
	)
	check(
		PhysicalMatchRequest.capture(state) != null,
		"paid spare/zero-Budget immutable request admitted"
	)
	var runner: PhysicalMatchRunner = PhysicalMatchRunner.new()
	add_child(runner)
	var report: Dictionary = {}
	var errors: Array[String] = []
	runner.finished.connect(func(value: Dictionary) -> void: report.merge(value, true))
	runner.failed.connect(func(reason: String) -> void: errors.append(reason))
	var started_ms: int = Time.get_ticks_msec()
	var frames: int = 0
	var observed_swings: Dictionary = {}
	var first_release: Array[String] = []
	var played: MatchState
	var started: bool = runner.start(state, 443)
	check(started, "real detached Equipment game starts")
	if started:
		played = runner._lab._match_state
		for frame: int in range(300000):
			await get_tree().physics_frame
			frames += 1
			if not report.is_empty() or not errors.is_empty():
				break
			if played.gear_usage.started and first_release.is_empty():
				first_release.assign(played.gear_usage.first_pitch)
				check(
					first_release == active and not first_release.has(spare.id),
					"actual first physical release uses only active paid receipts"
				)
			if (
				played.batting_team() == played.home_team
				and runner._lab._swing_tracker != null
				and runner._lab._swing_tracker.active
			):
				var profile: SwingProfileDefinition = runner._lab._swing_tracker.profile
				check(
					is_equal_approx(profile.gear_fair_exit_scale, 0.96),
					"actual human swing uses active Wide Barrel, never spare Taped Bat or product of both"
				)
				observed_swings[played.plate_appearance_number] = true
			if frame % 7200 == 0:
				print(
					"EQUIPMENT_SPARE_LIVE inning=",
					played.inning,
					" pa=",
					played.plate_appearance_number
				)
	check(
		errors.is_empty() and not report.is_empty(),
		"actual detached Equipment game completes: " + str(errors)
	)
	if not report.is_empty():
		check(
			(
				report.get("version") == 27
				and PhysicalMatchReport.valid(report)
				and PhysicalLeagueReport.matches(report, state)
			),
			"real report27 validates and matches original paid request"
		)
		check(
			PhysicalMatchReport.valid(JSON.parse_string(JSON.stringify(report))),
			"real report27 cold JSON replay"
		)
		check(
			(
				first_release == active
				and played.gear_usage.first_pitch == active
				and observed_swings.size() > 0
			),
			"completed actual game retains active first-release evidence and exercises real modified swings"
		)
		check(
			ClubCareer.same(report.ownership, [before[1], before[0]]),
			"report27 retains complete active/spare paid bank histories in away/home order"
		)
		var wallet: Dictionary = PhysicalLeagueReport.wallet(
			report.league_rules, report.ownership[1]
		)
		check(
			wallet.spare == spare and wallet.gear == human_bank.view().gear,
			"report cold wallet distinguishes inactive spare from exactly Bat/Ball/Misc"
		)
		var ai: Dictionary = report.physical.tactics.teams[0]
		check(
			(
				ai.budget.active
				and ai.budget.cash == 4
				and ai.budget.outcome == "full"
				and ai.initial.is_empty()
				and ai.consumed.is_empty()
				and ai.remaining.is_empty()
			),
			"real zero-capacity E08 report has no initial, consumed, remaining or deferred grant"
		)
		var forged: Dictionary = report.duplicate(true)
		forged.physical.tactics.teams[0].budget.outcome = "granted"
		forged.physical.tactics.teams[0].initial.append(
			{"id": "budget:8", "item": "C03", "paid": 0, "kind": "held"}
		)
		check(
			not PhysicalMatchReport.valid(forged),
			"actual report rejects invented zero-capacity grant"
		)
		forged = report.duplicate(true)
		for event: Dictionary in forged.ownership[1].events:
			if event.op == "spare_buy":
				event.offer = "foreign-spare-offer"
		check(
			not PhysicalMatchReport.valid(forged),
			"actual report rejects edited inactive-spare purchase history"
		)
		forged = report.duplicate(true)
		forged.ownership[1].events.pop_back()
		check(
			not PhysicalLeagueReport.matches(forged, state),
			"stripped spare purchase cannot match original immutable request"
		)
		var changed_bank: SeasonOwnership = human_bank.fork()
		check(
			(
				changed_bank
				. commit(
					OwnershipFixtures.request(
						changed_bank,
						"spare_swap",
						{"spare": spare.id, "active": human_bank.view().gear.bat.id}
					)
				)
				. ok
			),
			"postgame candidate exchanges the existing paid bat receipts"
		)
		var changed_request: MatchState = detached_request(changed_bank, ai_bank)
		check(
			PhysicalMatchRequest.capture(changed_request) != null,
			"post-swap candidate active-only request remains valid"
		)
		check(
			not PhysicalLeagueReport.matches(report, changed_request),
			"old pre-swap report rejects against the changed exact receipt context"
		)
		var evidence: Dictionary = {
			"scope":
			"detached actual physical game; synthetic paid preparation, not natural season progression",
			"report": report,
			"first_release_active_receipts": first_release,
			"inactive_spare_receipt": spare,
			"physics_frames": frames,
			"wall_ms": Time.get_ticks_msec() - started_ms,
			"observed_swing_pas": observed_swings.keys()
		}
		var output: FileAccess = FileAccess.open(
			"user://league-equipment-spare-live-evidence.json", FileAccess.WRITE
		)
		check(output != null, "isolated live evidence file opens")
		if output != null:
			output.store_string(JSON.stringify(evidence, "", true, true))
			output.close()
			var cold: Dictionary = JSON.parse_string(
				FileAccess.get_file_as_string("user://league-equipment-spare-live-evidence.json")
			)
			check(
				(
					PhysicalMatchReport.valid(cold.report)
					and cold.first_release_active_receipts == active
					and not cold.first_release_active_receipts.has(cold.inactive_spare_receipt.id)
				),
				"disk-cold live evidence preserves exact active-only use beside paid spare report"
			)
		print(
			"EQUIPMENT_SPARE_DONE wall_ms=",
			evidence.wall_ms,
			" physics_frames=",
			frames,
			" releases=",
			report.physical.releases.size(),
			" score=",
			report.physical.away_runs,
			"-",
			report.physical.home_runs,
			" active_first_release=",
			first_release,
			" inactive_spare=",
			spare,
			" zero_budget=",
			ai.budget,
			" observed_swing_pas=",
			observed_swings.keys()
		)
	check(
		before == [human_bank.to_data(), ai_bank.to_data()],
		"actual play never mutates detached paid journals"
	)
	check(
		not state.gear_usage.started and state.gear_usage.first_pitch.is_empty(),
		"runner never mutates original request's use evidence"
	)
	runner.queue_free()
	await get_tree().process_frame
	print("Equipment spare live checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

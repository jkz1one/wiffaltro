extends Node
var checks: int = 0
var failures: Array[String] = []
var credits: Array = []
var progress: Array = []


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)


func _ready() -> void:
	for index in range(40):
		credits.append(10000)
		progress.append({"seasons": 1, "wins": 5, "homers": 5})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(194, credits, progress)
	for item: Array in [
		["ST-024", "standard", 23, "stadium_buy", 8],
		["ST-024-L", "low", 23, "stadium_wall_piece", 1]
	]:
		var bought: Dictionary = ledger.commit(
			{
				"id": item[1],
				"rev": ledger.revision(),
				"op": item[3],
				"item": item[0],
				"quantity": item[2],
				"price_version": item[4],
				"through": 40,
				"progress_through": 40
			}
		)
		check(bought.ok, "paid distinct panel purchase " + str(item[0]) + ": " + bought.error)
	var prior: Dictionary = ledger.to_data()
	var prior_revision: int = ledger.revision()
	for profile: String in StadiumLowWallRecipes.PROFILES:
		var layout: Dictionary = StadiumLowWallLayout.upgrade(
			ledger.view().stadium_draft, ledger.surface_owned()
		)
		var suggested: Dictionary = StadiumLowWallManifest.suggest(
			profile, "ST-024", ledger.construction(), ledger.wall_pieces().stock
		)
		check(suggested.ok, "exact profile suggestion")
		if not suggested.ok:
			continue
		layout.low_wall = suggested.manifest
		var valid: Dictionary = StadiumLowWallLayout.validate(
			layout, ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), "backyard"
		)
		check(valid.ok, "complete validation " + profile + ": " + valid.error)
		check(
			not StadiumHomeLayout.validate(layout, ledger.construction(), "backyard").ok,
			"stock-only validator does not grant low pieces"
		)
		var bad: Dictionary = layout.duplicate(true)
		bad.low_wall.copies[0] = bad.low_wall.copies[1]
		check(
			not (
				StadiumLowWallLayout
				. validate(
					bad,
					ledger.construction(),
					ledger.wall_pieces(),
					ledger.surface_owned(),
					"backyard"
				)
				. ok
			),
			"duplicate copy fails closed"
		)
		bad = layout.duplicate(true)
		bad.low_wall.copies[0] = "purchase:standard:0"
		check(
			not (
				StadiumLowWallLayout
				. validate(
					bad,
					ledger.construction(),
					ledger.wall_pieces(),
					ledger.surface_owned(),
					"backyard"
				)
				. ok
			),
			"standard cannot become low"
		)
		var draft: Dictionary = ledger.commit(
			{
				"id": profile + "draft",
				"rev": ledger.revision(),
				"op": "stadium_draft",
				"layout": layout
			}
		)
		check(draft.ok, "paid draft " + draft.error)
		if not draft.ok:
			continue
		var applied: Dictionary = ledger.commit(
			{
				"id": profile + "apply",
				"rev": ledger.revision(),
				"op": "stadium_apply",
				"layout": layout,
				"geometry": StadiumLowWallLayout.geometry("backyard", layout)
			}
		)
		check(applied.ok, "paid apply " + applied.error)
		if "--low-runtime-tests" in OS.get_cmdline_user_args():
			await _runtime(ledger, profile)
		var cold: ClubAssetLedger = ClubAssetLedger.from_data(
			JSON.parse_string(JSON.stringify(ledger.to_data())), 194, credits, progress
		)
		check(cold != null, "cold ledger55 parses")
		var snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
		check(not snapshot.is_empty() and snapshot.version == 32, "complete ownership snapshot32")
		if not snapshot.is_empty():
			check(
				(
					StadiumLayoutSnapshot.valid(snapshot)
					and StadiumLayoutSnapshot.matches(snapshot, ledger)
				),
				"exact prefix snapshot"
			)
			var json: Dictionary = JSON.parse_string(JSON.stringify(snapshot))
			check(
				(
					StadiumLayoutSnapshot.valid(json)
					and StadiumLayoutSnapshot.key(json) == StadiumLayoutSnapshot.key(snapshot)
				),
				"cold snapshot stable"
			)
			var fixture: Dictionary = StadiumLowWallSnapshot.fixture(snapshot, 194, 1)
			check(
				StadiumLayoutSnapshot.valid(fixture) and fixture.environment.mode == "day",
				"fixture33 daylight only"
			)
			var missing: Dictionary = snapshot.duplicate(true)
			missing.wall_piece_inventory.stock.copies.erase(layout.low_wall.copies[0])
			check(not StadiumLayoutSnapshot.valid(missing), "missing declared low copy rejected")
	var prior_ledger: ClubAssetLedger = ledger.prefix(prior_revision)
	check(
		prior_ledger != null and ClubCareer.same(prior_ledger.to_data(), prior),
		"historical exact ledger prefix preserved"
	)
	print(
		(
			"OWNED_LOW_WALL_RESULT "
			+ JSON.stringify({"checks": checks, "failures": failures, "runtime_qualified": false})
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


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
	var installed: bool = StadiumPropertyRuntime.install_bound(lab)
	check(installed, profile + " complete paid ordinary runtime installs")
	if installed:
		await get_tree().physics_frame
		check(
			StadiumBoundaryRuntime.installed(lab, snapshot),
			profile + " installed full snapshot and observer intact"
		)
		lab.set_process(true)
		lab.set_physics_process(true)
		var outcomes: Array[BallPlayOutcome] = []
		lab._ball_play_resolver.play_resolved.connect(
			func(value: BallPlayOutcome) -> void: outcomes.append(value)
		)
		var before: int = lab._match_state.away_team.runs + lab._match_state.home_team.runs
		lab._active_play_record = PlayRecord.new()
		check(lab._match_state.begin_pitch(), "ordinary low-wall pitch begins")
		await get_tree().process_frame
		var launch: BattedBallLaunch = BattedBallLaunch.new()
		launch.position = Vector3(0, 1, 0.28)
		launch.velocity = Vector3(-4, 18, 30)
		launch.orientation = Quaternion.IDENTITY
		launch.angular_velocity = Vector3.ZERO
		lab._start_ball_in_play(launch)
		for frame in range(480):
			await get_tree().physics_frame
			if not outcomes.is_empty():
				break
		check(
			outcomes.size() == 1 and outcomes[0].result == BallPlayOutcome.Result.HOME_RUN,
			"above selected cap gives exactly one actual HR"
		)
		check(
			(
				lab._play_records.size() == 1
				and lab._match_state.away_team.runs + lab._match_state.home_team.runs == before + 1
			),
			"one record and score increment"
		)
	lab.queue_free()
	await get_tree().process_frame

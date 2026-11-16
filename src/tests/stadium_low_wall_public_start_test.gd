extends "res://src/tests/stadium_low_wall_save_test.gd"


## Public SeasonApp startup, genuine pending home fixtures, no injected Lab ledger.
func _ready() -> void:
	_run()
	if completed_season != null:
		for profile: String in StadiumLowWallRecipes.PROFILES:
			await _start_profile(profile)
	await TestAudioDrain.finish(get_tree())
	print(
		(
			"LOW_WALL_PUBLIC_START "
			+ JSON.stringify(
				{
					"checks": checks,
					"failures": failures,
					"completed_games": 0,
					"synthetic_funding": true
				}
			)
		)
	)
	get_tree().quit(0 if failures.is_empty() else 1)


func _start_profile(profile: String) -> void:
	var completed: SeasonState = SeasonSave._decode(SeasonSave.snapshot(completed_season))
	var paid: ClubAssetLedger = ClubPlayers.assets(completed.career)
	var layout: Dictionary = paid.view().stadium_active.duplicate(true)
	layout.low_wall = (
		StadiumLowWallManifest
		. suggest(profile, "ST-024", paid.construction(), paid.wall_pieces().stock)
		. manifest
	)
	check(
		ClubConstruction.save_draft(completed, layout, paid.revision()).ok,
		"public next profile draft"
	)
	check(
		(
			ClubConstruction
			. apply_draft(completed, layout, ClubPlayers.assets(completed.career).revision())
			. ok
		),
		"public next profile apply"
	)
	var career: ClubCareer = completed.career.fork()
	check(career.close(completed), "close genuine funded completed season")
	var next: SeasonState = StadiumPennantRewardRebuildChecks._new(career)
	check(next != null, "new drafted career season starts")
	if next == null:
		return
	next.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(career))
	for index in range(6):
		var pending: Dictionary = next.pending_fixture()
		if not pending.is_empty() and pending.home == 0:
			break
		check(
			not pending.is_empty() and next.record_player_result(pending.id, 0, 1),
			"authored score-only advance to actual pending home"
		)
	check(
		not next.pending_fixture().is_empty() and next.pending_fixture().home == 0,
		"naturally scheduled home fixture"
	)
	if next.pending_fixture().is_empty() or next.pending_fixture().home != 0:
		return
	SeasonSave.path = "user://low-wall-public-start.json"
	check(SeasonSave.save(next), "real new-season save")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	check(app.season != null, "ordinary app restores season")
	app.play_season_game()
	await get_tree().process_frame
	await get_tree().process_frame
	var installed: bool = (
		is_instance_valid(app.lab)
		and StadiumLowWallRuntime.installed_bound(app.lab, app.lab._match_state.stadium)
	)
	check(installed, "public app installed exact paid low boundary " + profile + ": " + app.notice)
	if installed:
		check(
			(
				app.lab._stadium_ledger != null
				and StadiumLayoutSnapshot.matches(
					app.lab._match_state.stadium, app.lab._stadium_ledger
				)
			),
			"public route supplies exact real paid prefix"
		)
		check(
			app.lab._throw_number == 0 and app.lab._play_records.is_empty(),
			"startup invents no play evidence"
		)
		app.lab.set_process(false)
		app.lab.set_physics_process(false)
	app._close_match()
	app.free()
	await get_tree().process_frame

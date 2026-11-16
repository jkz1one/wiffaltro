extends "res://src/tests/stadium_seating_ui_test.gd"
## Actual completed/pre-draft activation, immutable entry identity and save failure rollback.


func _ready() -> void:
	SeasonSave.path = "user://scoreboard-staging-%d.json" % OS.get_process_id()
	var completed: SeasonState = _fund_seating()
	var layout: Dictionary = _layout(ClubPlayers.assets(completed.career))
	_check(
		completed.phase == SeasonState.Phase.COMPLETE and ClubConstruction.can_apply(completed),
		"completed season reaches exact public construction flow"
	)
	_fail_save(completed, layout)
	_save(completed, layout)
	_fail_apply(completed, layout)
	_apply(completed, layout)
	_check(
		ClubPlayers.assets(completed.career).view().stadium_active.version == 14,
		"completed season stores exact active14 without inventing a live fixture"
	)
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(88, true)
	var season: SeasonState = app.season
	_check(
		season != completed and season.home_property.version == 12,
		"owned season start freezes exact entry12"
	)
	var frozen: Dictionary = season.home_property.duplicate(true)
	layout = layout.duplicate(true)
	layout.receiver = "starter-v1:ST-079"
	_fail_save(season, layout)
	_save(season, layout)
	_fail_apply(season, layout)
	_apply(season, layout)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(
		(
			season.home_property.version == 12
			and season.home_property.layout.receiver == layout.receiver
			and StadiumLayoutSnapshot.matches(season.home_property, ledger)
			and StadiumScoreboardSnapshot.matches(frozen, ledger)
		),
		"pre-draft activation recaptures while older frozen prefix remains unchanged"
	)
	_expand(season)
	ledger = ClubPlayers.assets(season.career)
	_check(
		(
			ledger.view().land == "expanded"
			and season.home_property.tier == "expanded"
			and StadiumLayoutSnapshot.matches(season.home_property, ledger)
		),
		"paid expansion preserves complete owned field and changes only its property tier"
	)
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		(
			loaded != null
			and ClubCareer.same(SeasonSave.snapshot(loaded), SeasonSave.snapshot(season))
		),
		"new entry and exact journal restore under current save envelope"
	)
	var bad: Dictionary = SeasonSave.snapshot(season)
	bad.home_property = StadiumScoreboardSnapshot.fixture(season.home_property, 51, 0)
	_check(SeasonSave._decode(bad) == null, "fixture13 cannot masquerade as a season entry")
	var before: Dictionary = SeasonSave.snapshot(season)
	var invalid: Dictionary = layout.duplicate(true)
	invalid.version = 13
	_check(
		(
			not ClubConstruction.save_draft(season, invalid, ledger.revision()).ok
			and not ClubConstruction.apply_draft(season, invalid, ledger.revision()).ok
			and ClubCareer.same(before, SeasonSave.snapshot(season))
		),
		"standalone advanced13 remains closed without mutating the current field"
	)
	app.begin_season(89, true)
	_check(
		app.season != season and app.season.home_property.version == 12,
		"next owned season preserves supported complete family"
	)
	app.begin_season(90, true, true, false)
	_check(
		(
			app.season.home_property.is_empty()
			and ClubPlayers.assets(app.season.career).view().stadium_active.version == 14
		),
		"explicit historical no-home mode retains exact owned assets"
	)
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard staging passed: completed and draft activation stays atomic.")
	get_tree().quit(0 if _failures == 0 else 1)


func _save(season: SeasonState, layout: Dictionary) -> void:
	_check(
		(
			ClubConstruction
			. save_draft(season, layout, ClubPlayers.assets(season.career).revision())
			. ok
		),
		"exact public draft saves"
	)


func _apply(season: SeasonState, layout: Dictionary) -> void:
	_check(
		(
			ClubConstruction
			. apply_draft(season, layout, ClubPlayers.assets(season.career).revision())
			. ok
		),
		"exact saved public draft applies"
	)


func _fail_save(season: SeasonState, layout: Dictionary) -> void:
	var path: String = SeasonSave.path
	var before: Dictionary = _held(season)
	SeasonSave.path = path + "/missing/file.json"
	_check(
		not (
			ClubConstruction
			. save_draft(season, layout, ClubPlayers.assets(season.career).revision())
			. ok
		),
		"failed draft write refuses"
	)
	SeasonSave.path = path
	_check(ClubCareer.same(before, _held(season)), "failed draft preserves career and both saves")


func _fail_apply(season: SeasonState, layout: Dictionary) -> void:
	var path: String = SeasonSave.path
	var before: Dictionary = _held(season)
	SeasonSave.path = path + "/missing/file.json"
	_check(
		not (
			ClubConstruction
			. apply_draft(season, layout, ClubPlayers.assets(season.career).revision())
			. ok
		),
		"failed exact apply write refuses"
	)
	SeasonSave.path = path
	_check(
		ClubCareer.same(before, _held(season)),
		"failed apply preserves field, wallet and both saves"
	)


func _expand(season: SeasonState) -> void:
	var path: String = SeasonSave.path
	var before: Dictionary = _held(season)
	var revision: int = ClubPlayers.assets(season.career).revision()
	SeasonSave.path = path + "/missing/file.json"
	_check(
		not ClubConstruction.buy_land(season, "expanded", revision).ok,
		"failed expanded field save refuses"
	)
	SeasonSave.path = path
	_check(
		ClubCareer.same(before, _held(season)),
		"failed expansion preserves field and paid ownership"
	)
	_check(
		ClubConstruction.buy_land(season, "expanded", revision).ok,
		"same expansion can retry after failed persistence"
	)


func _held(season: SeasonState) -> Dictionary:
	return {
		"state": SeasonSave.snapshot(season),
		"primary": FileAccess.get_file_as_string(SeasonSave.path),
		"backup": FileAccess.get_file_as_string(SeasonSave.path + ".bak")
	}


func _layout(ledger: ClubAssetLedger) -> Dictionary:
	return StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned(), true)
		)
	)

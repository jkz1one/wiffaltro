extends "res://src/tests/stadium_seating_ui_test.gd"
## Real save/controller staging fences. Pure ledger data must never downgrade owned home profiles.


func _ready() -> void:
	SeasonSave.path = "user://advanced-staging-%d.json" % OS.get_process_id()
	var completed: SeasonState = _fund_seating()
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(88, true)
	var season: SeasonState = app.season
	var frozen: Dictionary = season.home_property.duplicate(true)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned(), true)
	)
	var revision: int = ledger.revision()
	_check(
		(
			ClubPlayers
			. command(
				season.career,
				{"id": "staged-draft", "rev": revision, "op": "stadium_draft", "layout": layout}
			)
			. ok
		),
		"explicit data-only draft storage"
	)
	_check(
		(
			ClubPlayers
			. command(
				season.career,
				{
					"id": "staged-apply",
					"rev": revision + 1,
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumOwnedLayout.geometry("backyard", layout)
				}
			)
			. ok
		),
		"data-only active declaration"
	)
	_check(
		SeasonSave.save(season), "existing old frozen season remains valid with staged future data"
	)
	var before: Dictionary = SeasonSave.snapshot(season)
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var backup: String = FileAccess.get_file_as_string(SeasonSave.path + ".bak")
	ledger = ClubPlayers.assets(season.career)
	var declared: Dictionary = StadiumAdvancedSnapshot.capture(ledger)
	_check(
		(
			StadiumAdvancedSnapshot.matches(declared, ledger)
			and not StadiumLayoutSnapshot.valid(declared)
		),
		"paid declaration is not production activation"
	)
	_check(
		(
			not ClubConstruction.save_draft(season, layout, ledger.revision()).ok
			and not ClubConstruction.apply_draft(season, layout, ledger.revision()).ok
		),
		"public draft/apply gates remain closed"
	)
	var balance: int = ledger.balance()
	var expansion: Dictionary = ClubConstruction.buy_land(season, "expanded", ledger.revision())
	_check(
		(
			balance >= 600
			and not expansion.ok
			and expansion.error.contains("Expanded field unavailable")
		),
		"funded land expansion reaches the recapture guard without dropping the owned field"
	)
	_check(
		(
			ClubCareer.same(before, SeasonSave.snapshot(season))
			and ClubPlayers.assets(season.career).balance() == balance
			and ClubCareer.same(season.home_property, frozen)
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
			and FileAccess.get_file_as_string(SeasonSave.path + ".bak") == backup
		),
		"rejected recapture preserves journal, field, primary bytes and backup"
	)
	for record: Dictionary in [declared, StadiumAdvancedSnapshot.fixture(declared, 51, 0)]:
		var forged: Dictionary = before.duplicate(true)
		forged.home_property = record
		_check(
			SeasonSave._decode(forged) == null,
			"production save rejects staged snapshot and fixture"
		)
	app.begin_season(89, true)
	_check(
		(
			app.season == season
			and app.notice.contains("owned home layout")
			and ClubCareer.same(before, SeasonSave.snapshot(season))
			and FileAccess.get_file_as_string(SeasonSave.path) == bytes
			and FileAccess.get_file_as_string(SeasonSave.path + ".bak") == backup
		),
		"owned season start aborts before publishing or saving unsupported field"
	)
	app.begin_season(90, true, true, false)
	_check(
		(
			app.season != season
			and app.season.home_property.is_empty()
			and ClubPlayers.assets(app.season.career).view().stadium_active.version == 13
		),
		"explicit historical no-home mode preserves assets without inventing a home snapshot"
	)
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro advanced staging passed: owned start, expansion and save gates stay atomic."
		)
	get_tree().quit(0 if _failures == 0 else 1)

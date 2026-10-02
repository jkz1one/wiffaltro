extends "res://src/tests/season_gear_progress_test.gd"

const Calibration = preload("res://src/tests/alley_calibration_test.gd")
const GAP: String = "BAT-ALY-02"


func _ready() -> void:
	SeasonSave.path = "user://gap-driver-%d.json" % OS.get_process_id()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_contract()
	_migration()
	var season: SeasonState = paid_gap(false)
	if season != null:
		await _purchase_ui(season)
		_replacement(season)
	await TestAudioDrain.finish(get_tree())
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	if _failures == 0:
		print(
			"Wiffaltro Gap Driver checks passed: calibration, paid progression, migration and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _contract() -> void:
	var signatures: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/fixtures/alley_legacy_signatures.json")
	)
	for version: String in signatures:
		_check(
			SeasonBuild._signature(int(version)) == signatures[version],
			"frozen catalog signature " + version
		)
	_check(
		SeasonGearCatalog.ownership_catalog().has(GAP), "Gap Driver has real ownership definition"
	)
	_check(not SeasonGearProgress.access({"A02": 9}).has(GAP), "nine uses never unlock")
	_check(
		SeasonGearProgress.access({"A02": 10}).has(GAP), "ten uses unlock prospective Gap Driver"
	)
	_check(SeasonGearProgress.access({"A02": 10, GAP: 20}) == [GAP], "Frozen Rope remains gated")
	for bad: Dictionary in [{GAP: 1}, {"A02": 9, GAP: 1}, {"A02": 0.5}, {"BAT-ALY-01": 10}]:
		_check(not SeasonGearProgress.valid_counts(bad), "reject impossible Alley count")
	_check(
		not SeasonGearProgress.valid_counts({"A02": 1}, false), "old format cannot claim Alley use"
	)
	_check(
		not SeasonGearProgress.valid_games(
			[{"game": 0, "items": ["A02", "BAT-CON-01"]}], [[0, 0, 1, 1, 0]], {}
		),
		"A02 cannot evade one-Bat-per-game validation"
	)
	var fixture: Node = Calibration.new()
	for id: String in ["A02", GAP]:
		var player: PlayerDefinition = SeasonGearCatalog.equip(
			_fixture().batter().definition, {"bat": {"item": id}}
		)
		for swing: StringName in [&"swing.contact", &"swing.power"]:
			var source: SwingProfileDefinition = ContentDB.get_swing(swing)
			var modified: SwingProfileDefinition = SeasonGearCatalog.swing(source, player)
			for left: bool in [false, true]:
				for error: float in [0.0, 0.25, 0.30, 0.347, 0.50, 0.95, 1.1]:
					var base: ContactResult = fixture._contact(
						source, Vector3(0, error, 0), 5, left
					)
					var actual: ContactResult = fixture._contact(
						modified, Vector3(0, error, 0), 5, left
					)
					_check(
						(
							base.quality == actual.quality
							and base.spray_degrees == actual.spray_degrees
							and base.backspin_rad_s == actual.backspin_rad_s
							and base.outcome == actual.outcome
						),
						"both stances retain actual quality, spray, spin and classification"
					)
					var fair: bool = fixture._fair(base)
					var scale: float = (
						SeasonAlleyGear.ITEMS[id].power_exit
						if fair and swing == &"swing.power"
						else 1.0
					)
					_check(
						is_equal_approx(
							actual.exit_velocity.length(), base.exit_velocity.length() * scale
						),
						"only fair Power pays exact penalty; Contact adds no speed"
					)
					var applies: bool = swing == &"swing.contact" and error in [0.25, 0.30, 0.347]
					_check(
						(actual.launch_angle_degrees < base.launch_angle_degrees) == applies,
						"new flattening reaches clean elevated Contact only"
					)
			_check(
				source.gear_line_drive_strength == 0 and not source.gear_line_drive_calibrated,
				"authored source remains neutral"
			)
	var combined: PlayerDefinition = SeasonGearCatalog.equip(
		_fixture().batter().definition, {"bat": {"item": GAP}, "misc": {"item": "MISC-BAT-01"}}
	)
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing)
		var profile: SwingProfileDefinition = SeasonGearCatalog.swing(source, combined)
		profile.tactical_quality_exit_scale = 1.1
		var base: ContactResult = fixture._contact(source, Vector3(0, 0.25, 0))
		var actual: ContactResult = fixture._contact(profile, Vector3(0, 0.25, 0))
		var factor: float = 0.96 * 1.1 * (0.88 if swing == &"swing.power" else 1.0)
		_check(
			is_equal_approx(actual.exit_velocity.length(), base.exit_velocity.length() * factor),
			"Gloves, tactical speed and fair Power penalty compose exactly once"
		)
		_check(
			is_equal_approx(profile.gear_timing_scale, 1.08),
			"calibration leaves Gloves timing alone"
		)
	fixture.free()


func earned_club() -> ClubCareer:
	var season: SeasonState = _paid_pair(["A02", "BALL-MOV-01"])
	if season == null:
		return null
	for use in range(9):
		_used(season)
	_check(
		season.build._gear_progress.counts().get("A02") == 9, "nine actual completed owned games"
	)
	_check(not season.build._gear_progress.eligible().has(GAP), "no early unlock")
	var revision: int = season.build.revision()
	_used(season, false)
	_check(
		season.build.revision() == revision + 1 and not season.build._visit.open,
		"threshold only settles normal result; no added stock or reroll event"
	)
	_check(season.build._gear_progress.counts().get("A02") == 10, "tenth loss also counts")
	_check(SeasonSave.save(season), "persist completed Alley progression")
	season = SeasonSave.restore()
	_check(season != null, "Alley career replays")
	if season == null:
		return null
	_check(season.career.gear_counts().get("A02") == 10, "ten persists across save")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "close paid completed run")
	return club


func paid_gap(purchase: bool = true) -> SeasonState:
	var club: ClubCareer = earned_club()
	if club == null:
		return null
	var season: SeasonState = _paid_pair([GAP, "BALL-MOV-01"], club, purchase)
	if season == null:
		return null
	_check(season.build._gear_progress.start.A02 == 10, "new season retains access, not Alley copy")
	_check(
		not season.build.view().wallet.gear.bat.get("item", "") == "A02",
		"no predecessor copy granted"
	)
	return season


func _migration() -> void:
	var original: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/fixtures/alley_v39.json")
	)
	var season: SeasonState = SeasonSave._decode(original)
	_check(season != null, "actual parent-commit save migrates")
	if season == null:
		return
	var restored: SeasonBuild = SeasonBuild.from_data(
		original.build,
		int(original.seed),
		season.picks,
		season.draft_pool,
		season.recruit_blocked()
	)
	_check(restored != null and restored._format == 39, "legacy build separately reconstructs")
	if restored == null:
		return
	_check(
		ClubCareer.same(season.build.view(), restored.view()),
		"migration preserves wallet/stock/receipts"
	)
	_check(
		season.build._gear_progress.alley_from == original.build.events.size(),
		"capture prospective event boundary"
	)
	_check(
		not season.career.gear_counts().has("A02"), "two old completed games grant no Alley credit"
	)
	var source: SwingProfileDefinition = ContentDB.get_swing(&"swing.contact")
	_check(
		not (
			SeasonGearCatalog
			. swing(source, restored.definition(season.picks[0]))
			. gear_line_drive_calibrated
		),
		"old replay can still reconstruct legacy mapping"
	)
	_check(
		(
			SeasonGearCatalog
			. swing(source, season.build.definition(season.picks[0]))
			. gear_line_drive_calibrated
		),
		"next playable match uses selected Working calibration"
	)
	_used(season)
	_check(season.build._gear_progress.counts().A02 == 1, "only future completed use counts")
	_check(SeasonSave.save(season), "save migrated future use")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var loaded: SeasonState = SeasonSave.restore()
	_check(
		loaded != null and loaded.career.gear_counts().A02 == 1, "replay cannot backfill old use"
	)
	for bad: Variant in [-1, 0.5, 999, null]:
		var forged: Dictionary = data.duplicate(true)
		forged.build.alley_from = bad
		_check(SeasonSave._decode(forged) == null, "invalid progression boundary rejected")
	var retroactive: Dictionary = data.duplicate(true)
	retroactive.build.alley_from = 0
	_check(SeasonSave._decode(retroactive) == null, "backdated credit disagrees with career")
	var missing: Dictionary = data.duplicate(true)
	missing.build.erase("alley_from")
	_check(SeasonSave._decode(missing) == null, "current boundary required")
	var legacy_career: Dictionary = season.career.to_data()
	legacy_career.version = 19
	_check(
		ClubCareer.from_data(legacy_career) == null, "pre20 career cannot contain Alley progress"
	)


func _purchase_ui(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "save before purchase review")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.show_season()
	var center: Vector2 = app.loadout.entry.position
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	var offer: String = _offer(season.build, GAP)
	await _click(_gear_button(window, "gear_offer", offer))
	_check(
		(
			window._review_text.text.contains("50% toward 10°")
			and window._review_text.text.contains("−12%")
		),
		"review discloses calibrated effect and penalty"
	)
	var before: Dictionary = season.build.to_data()
	await _click(window._confirm.get_cancel_button())
	_check(season.build.to_data() == before, "cancel leaves purchase untouched")
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/file.json"
	await _click(_gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	_check(season.build.to_data() == before, "failed save rolls back Gap purchase")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "failed save retains old bytes")
	var cash: int = season.cash()
	await _click(_gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	_check(
		season.cash() == cash - 16 and season.build.view().wallet.gear.bat.item == GAP,
		"real confirmation pays sixteen and equips"
	)
	await _shop_bounds(window, "gap-driver-shop")
	await _click(window._back)
	_check(app.loadout.entry.position == center, "central Equipped position stays fixed")
	await _click(app.loadout.entry)
	_check(app.loadout.panel.visible, "Gap Driver inspectable in shared lightbox")
	app.loadout.close()
	ClubGearProgressUI.show(app.menu)
	await _menu_bounds(app, "gap-driver-progress")
	_check(ClubCollection.discoveries(season.career).has(GAP), "paid purchase reveals collection")
	_check(SeasonSave.restore() != null, "UI purchase replays")
	var copy: Dictionary = season.build.view().wallet.gear.bat
	_check(
		app.commit_shop(_command(season.build, "sell_gear", {"receipt": copy.id})),
		"saved paid sale"
	)
	_check(
		season.cash() == cash - 8 and season.build.view().wallet.gear.bat.is_empty(),
		"half actual paid refund"
	)
	_check(ClubCollection.discoveries(season.career).has(GAP), "sold Gear stays discovered")
	_check(SeasonSave.restore() != null, "sold purchase history replays")
	app.queue_free()
	await _frames()


func _replacement(previous: SeasonState) -> void:
	var club: ClubCareer = previous.career.fork()
	_check(club.close(previous), "abandon retains earned Alley access")
	var season: SeasonState = _paid_pair(["A02", GAP], club, false)
	_check(season != null, "generated paid two-Bat replacement offer")
	if season == null:
		return
	var build: SeasonBuild = season.build
	_check(SeasonSpecialOrder.pool(build, "gear").has(GAP), "earned Gap supports focused Gear pool")
	_check(
		SeasonRaincheck.quote(build, GAP).price == 16,
		"reservation quotes full undiscounted Gap price"
	)
	var locked: SeasonBuild = SeasonBuild.new(0, ROSTER)
	_check(
		(
			not SeasonSpecialOrder.pool(locked, "gear").has(GAP)
			and SeasonRaincheck.quote(locked, GAP).is_empty()
		),
		"sponsor adapters cannot bypass access"
	)
	var before_cash: int = build.cash()
	_check(
		build.commit(_command(build, "equip", {"offer": _offer(build, "A02"), "replace": ""})).ok,
		"buy paid Alley predecessor in same visit"
	)
	var receipt: Dictionary = build.view().wallet.gear.bat
	var request: Dictionary = _command(build, "equip", {"offer": _offer(build, GAP), "replace": ""})
	var before: Dictionary = build.to_data()
	_check(
		not build.commit(request).ok and build.to_data() == before,
		"full Bat slot requires explicit replacement"
	)
	request.replace = receipt.id
	_check(
		build.preview(request).ok and build.to_data() == before,
		"replacement preview leaves all ownership untouched"
	)
	_check(
		build.commit(request).ok and build.cash() == before_cash - 22,
		"atomic twelve-paid sale refunds six toward sixteen"
	)
	_check(
		build.view().wallet.gear.bat.paid == 16,
		"new receipt records full price rather than net ten"
	)
	var result: Dictionary = build.commit(request)
	_check(
		result.ok and result.replayed and build.cash() == before_cash - 22,
		"duplicate purchase does not refund again"
	)
	_check(
		SeasonSave.save(season) and SeasonSave.restore() != null,
		"replacement journal and career replay"
	)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	saved.build.events[-1].replace = "foreign"
	_check(SeasonSave._decode(saved) == null, "forged replacement receipt rejects save")

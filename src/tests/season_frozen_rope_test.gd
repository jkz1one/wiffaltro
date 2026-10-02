extends "res://src/tests/season_gap_driver_test.gd"

const FROPE: String = "BAT-ALY-03"


func _ready() -> void:
	SeasonSave.path = "user://frozen-rope-%d.json" % OS.get_process_id()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	_frozen_contract()
	_frozen_migration()
	var season: SeasonState = paid_frozen(false)
	if season != null:
		await _frozen_purchase_ui(season)
		_frozen_replacement(season)
	await TestAudioDrain.finish(get_tree())
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	if _failures == 0:
		print(
			"Wiffaltro Frozen Rope checks passed: paid career progression, migration, snapshots and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func earned_frozen_club() -> ClubCareer:
	var club: ClubCareer = earned_club()
	if club == null:
		return null
	for stage in range(2):
		var season: SeasonState = _paid_pair([GAP, "BALL-MOV-01"], club)
		if season == null:
			return null
		for index in range(10):
			var before: Dictionary = season.build.to_data()
			_used(season, index != 9)
			_check(
				season.build.revision() == before.events.size() + 1,
				"settle only actual completed use"
			)
			_check(not season.build._visit.open, "unlock never regenerates stock")
		var count: int = int(season.build._gear_progress.counts().get(GAP, 0))
		_check(
			count == (stage + 1) * 10, "paid Gap use accumulates across completed and losing games"
		)
		_check(
			season.build._gear_progress.eligible().has(FROPE) == (stage == 1),
			"twentieth use is exact access boundary"
		)
		_check(SeasonSave.save(season), "save real completed Gap uses")
		season = SeasonSave.restore()
		_check(season != null, "completed paid career rebuilds")
		if season == null:
			return null
		club = season.career.fork()
		_check(club.close(season), "close run without losing earned access")
	return club


func paid_frozen(purchase: bool = true) -> SeasonState:
	var club: ClubCareer = earned_frozen_club()
	if club == null:
		return null
	var season: SeasonState = _paid_pair([FROPE, "BALL-MOV-01"], club, purchase)
	if season != null:
		_check(
			season.build._gear_progress.start.get(GAP) == 20,
			"new season has twenty uses and no inherited copy"
		)
	return season


func _frozen_contract() -> void:
	super._contract()
	var signatures: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/fixtures/frozen_signature40.json")
	)
	_check(SeasonBuild._signature(40) == signatures["40"], "Build40 catalog bytes remain frozen")
	_check(
		SeasonAlleyGear.ITEMS.size() == 2, "do not extend the frozen Build40 signature dictionary"
	)
	_check(SeasonGearCatalog.ownership_catalog().has(FROPE), "one actual final Gear identity")
	_check(
		not SeasonGearProgress.access({"A02": 10, GAP: 19}).has(FROPE),
		"nineteen uses remain locked"
	)
	_check(
		not SeasonGearProgress.access({"A02": 10, GAP: 20}, false).has(FROPE),
		"old format cannot regenerate new stock"
	)
	_check(
		not SeasonGearProgress.valid_counts({FROPE: 1}),
		"final tier is not invented new use counter"
	)
	var fixture: Node = Calibration.new()
	var player: PlayerDefinition = SeasonGearCatalog.equip(
		_fixture().batter().definition, {"bat": {"item": FROPE}}
	)
	for swing: StringName in [&"swing.contact", &"swing.power"]:
		var source: SwingProfileDefinition = ContentDB.get_swing(swing)
		var profile: SwingProfileDefinition = SeasonGearCatalog.swing(source, player)
		_check(
			profile.gear_gap_bias == (swing == &"swing.contact"), "only Contact gets gap resolver"
		)
		for left: bool in [false, true]:
			for error: float in [0.0, 0.1, 0.25, 0.3, 0.95, 1.1]:
				var base: ContactResult = fixture._contact(source, Vector3(0, error, 0), 5, left)
				var actual: ContactResult = fixture._contact(profile, Vector3(0, error, 0), 5, left)
				_check(
					(
						actual.quality == base.quality
						and actual.backspin_rad_s == base.backspin_rad_s
						and actual.outcome == base.outcome
					),
					"quality, spin and classification unchanged"
				)
				var penalty: float = (
					0.84 if fixture._fair(base) and swing == &"swing.power" else 1.0
				)
				_check(
					is_equal_approx(
						actual.exit_velocity.length(), base.exit_velocity.length() * penalty
					),
					"sixteen percent fair Power penalty, no added Contact speed"
				)
				if fixture._fair(base) and swing == &"swing.contact":
					_check(
						is_equal_approx(
							actual.launch_angle_degrees,
							SeasonAlleyGear.angle(base.launch_angle_degrees, base.quality, 0.75)
						),
						"strongest selected flattening executes once"
					)
	fixture.free()


func _frozen_migration() -> void:
	var old: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://src/tests/fixtures/frozen_v40.json")
	)
	var season: SeasonState = SeasonSave._decode(old)
	_check(season != null, "actual parent Build40 paid Gap fixture migrates")
	if season == null:
		return
	var build: SeasonBuild = SeasonBuild.from_data(
		old.build, int(old.seed), season.picks, season.draft_pool, season.recruit_blocked()
	)
	_check(build != null and build._format == 40, "old format reconstructs independently")
	if build == null:
		return
	_check(
		ClubCareer.same(build.view(), season.build.view()),
		"stock, wallet and original receipts preserved"
	)
	_check(
		season.career.gear_counts().get(GAP) == 2,
		"already supported prospective Gap credit remains exact"
	)
	_check(
		not season.build._gear_progress.eligible().has(FROPE),
		"migration does not invent twenty uses"
	)
	_check(
		SeasonSave.save(season) and SeasonSave.restore() != null, "migrated parent saves repeatedly"
	)
	var forged: Dictionary = old.duplicate(true)
	forged.career.runs[-1].collection.append(FROPE)
	forged.career.runs[-1].collection.sort()
	_check(SeasonSave._decode(forged) == null, "pre21 career cannot discover a future item")


func _native_adapter(season: SeasonState) -> void:
	var lab: PitchBatLab = PitchBatLab.new()
	lab._configured_match = season.make_match()
	lab._player_home = season.pending_fixture().home == 0
	add_child(lab)
	await _frames()
	PitchBatLabFeelSupport.skip_match_presentation(lab)
	var state: MatchState = lab._match_state
	# Select the owning club's legal batting half, then use its actual paid definition.
	state.top_half = not lab._player_home
	lab._apply_defensive_assignment()
	var intent: SwingIntent = SwingIntent.new()
	intent.profile_id = &"swing.contact"
	intent.handedness_left = state.batter().bats_left()
	var profile: SwingProfileDefinition = SeasonGearCatalog.swing(
		ContentDB.get_swing(intent.profile_id), state.batter().definition
	)
	lab._swing_tracker.begin(intent, profile, 5, 5)
	lab._throw_number = 100
	var contact: ContactResult = ContactResult.new()
	contact.outcome = ContactResult.Outcome.PERFECT
	contact.quality = 1.0
	contact.contact_position = Vector3(0, 1, 0.28)
	contact.spray_degrees = 3.0
	contact.exit_velocity = Vector3(sin(deg_to_rad(3.0)), 0.1, cos(deg_to_rad(3.0))) * 25
	var data: Dictionary = PitchBatLabGapSupport.capture(lab, contact.contact_position)
	_check(data.valid and data.defenders.size() == 2, "capture both actual fieldable defenders")
	_check(
		(
			data.defenders[0]
			== Vector2(lab._pitcher_marker.global_position.x, lab._pitcher_marker.global_position.z)
		),
		"actual pitcher marker, not planned anchor"
	)
	_check(data.obstacles.size() == 1, "capture actual backyard box pole")
	var pole: StaticBody3D = lab.get_node("StarterFieldGeometry/LiveObjectPole")
	var box: Rect2 = data.obstacles[0]
	_check(
		box.has_point(Vector2(pole.global_position.x, pole.global_position.z)),
		"expanded native collision footprint"
	)
	PitchBatLabGapSupport.resolve(lab, contact)
	_check(
		not contact.frozen_launch.is_empty() and SeasonGapCommit.valid(contact.frozen_launch),
		"shared live hook commits valid actual snapshot"
	)
	var frozen: Dictionary = contact.frozen_launch.duplicate(true)
	var vector: Vector3 = contact.exit_velocity
	lab._primary_fielder.global_position += Vector3(-15, 0, 0)
	lab._pitcher_marker.global_position += Vector3(10, 0, 0)
	pole.global_position += Vector3(-5, 0, 0)
	PitchBatLabGapSupport.resolve(lab, contact)
	_check(
		contact.frozen_launch == frozen and contact.exit_velocity == vector,
		"moved defense cannot reselect a committed result"
	)
	_check(state.frozen_contacts.size() == 1, "repeated callback records exactly one launch")
	lab._active_play_record = PlayRecord.new()
	PitchBatLabFeelSupport.note_swing(lab, intent.profile_id, Vector2.ZERO, contact)
	_check(
		SeasonGapCommit.same(lab._active_play_record.to_dict().frozen_launch, frozen),
		"QC export contains selected vector and snapshot"
	)
	var restored: Dictionary = JSON.parse_string(JSON.stringify(frozen))
	_check(SeasonGapCommit.valid(restored), "snapshot validates after JSON round-trip")
	var forged: Dictionary = restored.duplicate(true)
	forged.choice.selected += 0.5
	_check(not SeasonGapCommit.valid(forged), "modified selection cannot fish for another gap")
	forged = restored.duplicate(true)
	forged.choice.velocity[0] += 1.0
	_check(not SeasonGapCommit.valid(forged), "forged added energy rejected")
	var replay: ContactResult = ContactResult.new()
	replay.outcome = contact.outcome
	replay.quality = contact.quality
	replay.spray_degrees = frozen.original
	replay.exit_velocity = Vector3(
		frozen.before_velocity[0], frozen.before_velocity[1], frozen.before_velocity[2]
	)
	_check(
		SeasonGapCommit.apply(replay, restored) and SeasonGapCommit.apply(replay, restored),
		"committed replay applies once, idempotently"
	)
	_check(
		replay.exit_velocity == vector, "replay retains exact selected launch after defense moved"
	)
	var unknown: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	unknown.add_child(shape)
	lab.add_child(unknown)
	_check(
		not PitchBatLabGapSupport.capture(lab, Vector3.ZERO).valid, "unknown collider fails closed"
	)
	lab.queue_free()
	await _frames()


func _frozen_purchase_ui(season: SeasonState) -> void:
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
	var offer: String = _offer(season.build, FROPE)
	await _click(_gear_button(window, "gear_offer", offer))
	_check(
		(
			window._review_text.text.contains("75% toward 10°")
			and window._review_text.text.contains("−16%")
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
		season.cash() == cash - 20 and season.build.view().wallet.gear.bat.item == FROPE,
		"real confirmation pays twenty and equips"
	)
	await _shop_bounds(window, "frozen-rope-shop")
	await _native_adapter(season)
	await _click(window._back)
	_check(app.loadout.entry.position == center, "central Equipped position stays fixed")
	await _click(app.loadout.entry)
	_check(app.loadout.panel.visible, "Frozen Rope inspectable in shared lightbox")
	app.loadout.close()
	ClubGearProgressUI.show(app.menu)
	await _menu_bounds(app, "frozen-rope-progress")
	_check(ClubCollection.discoveries(season.career).has(FROPE), "paid purchase reveals collection")
	_check(SeasonSave.restore() != null, "UI purchase replays")
	var copy: Dictionary = season.build.view().wallet.gear.bat
	_check(
		app.commit_shop(_command(season.build, "sell_gear", {"receipt": copy.id})),
		"saved paid sale"
	)
	_check(
		season.cash() == cash - 10 and season.build.view().wallet.gear.bat.is_empty(),
		"half actual paid refund"
	)
	_check(ClubCollection.discoveries(season.career).has(FROPE), "sold Gear stays discovered")
	_check(SeasonSave.restore() != null, "sold purchase history replays")
	app.queue_free()
	await _frames()


func _frozen_replacement(previous: SeasonState) -> void:
	var club: ClubCareer = previous.career.fork()
	_check(club.close(previous), "abandon retains earned Alley access")
	var season: SeasonState = _paid_pair(["A02", FROPE], club, false)
	_check(season != null, "generated paid two-Bat replacement offer")
	if season == null:
		return
	var build: SeasonBuild = season.build
	_check(
		SeasonSpecialOrder.pool(build, "gear").has(FROPE),
		"earned Frozen supports focused Gear pool"
	)
	_check(
		SeasonRaincheck.quote(build, FROPE).price == 20,
		"reservation quotes full undiscounted Frozen price"
	)
	var locked: SeasonBuild = SeasonBuild.new(0, ROSTER)
	_check(
		(
			not SeasonSpecialOrder.pool(locked, "gear").has(FROPE)
			and SeasonRaincheck.quote(locked, FROPE).is_empty()
		),
		"sponsor adapters cannot bypass access"
	)
	var before_cash: int = build.cash()
	_check(
		build.commit(_command(build, "equip", {"offer": _offer(build, "A02"), "replace": ""})).ok,
		"buy paid Alley predecessor in same visit"
	)
	var receipt: Dictionary = build.view().wallet.gear.bat
	var request: Dictionary = _command(
		build, "equip", {"offer": _offer(build, FROPE), "replace": ""}
	)
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
		build.commit(request).ok and build.cash() == before_cash - 26,
		"atomic twelve-paid sale refunds six toward twenty"
	)
	_check(
		build.view().wallet.gear.bat.paid == 20,
		"new receipt records full price rather than net fourteen"
	)
	var result: Dictionary = build.commit(request)
	_check(
		result.ok and result.replayed and build.cash() == before_cash - 26,
		"duplicate purchase does not refund again"
	)
	_check(
		SeasonSave.save(season) and SeasonSave.restore() != null,
		"replacement journal and career replay"
	)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	saved.build.events[-1].replace = "foreign"
	_check(SeasonSave._decode(saved) == null, "forged replacement receipt rejects save")

extends "res://src/tests/season_sponsor_test.gd"

const BASE_PAIR: Array[String] = ["BAT-CON-01", "BALL-MOV-01"]
const NEXT_PAIR: Array[String] = ["BAT-CON-02", "BALL-MOV-02"]


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--ui-capture-dir="):
			_capture_dir = argument.trim_prefix("--ui-capture-dir=")
	SeasonSave.path = "user://gear-progress-%d.json" % OS.get_process_id()
	_thresholds()
	var season: SeasonState = _chain()
	if season != null:
		_persistence(season)
		await _progress_ui(season)
		await _earned_replacement_ui(season)
	_migration_progress()
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro earned Gear checks passed: thresholds, paid chains, history, retries and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _thresholds() -> void:
	_check(SeasonEarnedGear.ITEMS.size() == 10, "five supported chains; Alley remains gated")
	for family: String in SeasonGearProgress.FAMILIES:
		var counts: Dictionary = {family + "-01": 9}
		_check(SeasonGearProgress.access(counts).is_empty(), "nine never unlocks")
		counts[family + "-01"] = 10
		_check(SeasonGearProgress.access(counts) == [family + "-02"], "ten earns only second tier")
		counts[family + "-02"] = 19
		_check(not SeasonGearProgress.access(counts).has(family + "-03"), "nineteen stays locked")
		counts[family + "-02"] = 20
		_check(SeasonGearProgress.access(counts).has(family + "-03"), "twenty earns third tier")
		var eligible: Dictionary = SeasonGearCatalog.eligible(
			{}, 3, SeasonGearProgress.access(counts)
		)
		_check(
			eligible["bat" if family.begins_with("BAT") else "ball"].has(family + "-03"),
			"eligible without owning predecessor"
		)
	for bad: Dictionary in [{"BAT-CON-03": 1}, {"BAT-CON-01": 9.5}, {"BAT-CON-02": 1}, {"A02": 10}]:
		_check(not SeasonGearProgress.valid_counts(bad), "reject unsupported or impossible counts")
	var scores: Array = [[0, 0, 1, 1, 0], [1, 2, 3, 1, 0]]
	for bad: Array in [
		[{"game": 0, "items": ["BAT-CON-01", "BAT-CON-01"]}],
		[{"game": 1, "items": ["BAT-CON-01"]}],
		[{"game": 0, "items": ["BAT-CON-02"]}],
		[{"game": 0, "items": ["BAT-CON-01"]}, {"game": 0, "items": ["BALL-MOV-01"]}]
	]:
		_check(
			not SeasonGearProgress.valid_games(bad, scores, {}),
			"reject duplicate, rival, premature or repeated game"
		)


func _paid_pair(pair: Array[String], club: ClubCareer = null, purchase: bool = true) -> SeasonState:
	var baseline: Dictionary = {} if club == null else club.gear_counts()
	var probe: SeasonBuild = SeasonBuild.new(0, ROSTER)
	var funding: int = (
		2
		if SeasonGearCatalog.item(pair[0]).price + SeasonGearCatalog.item(pair[1]).price <= 36
		else 3
	)
	probe._visit.number = funding
	probe._gear_progress.enabled = true
	probe._gear_progress.start = baseline
	for seed_value in range(30000):
		probe._seed = seed_value
		var stock: Array = probe._offers(0).values()
		if not stock.has(pair[0]) or not stock.has(pair[1]):
			continue
		var season: SeasonState = SeasonState.create(seed_value, false, true, true)
		season.career = ClubCareer.new() if club == null else club.fork()
		if not season.career.start(season):
			_check(false, "start tracked season")
			return null
		for pick in range(4):
			season.choose_player(season.offers()[0])
		for game in range(funding):
			_record(season)
		season.build.commit(_command(season.build, "open"))
		if _offer(season.build, pair[0]).is_empty() or _offer(season.build, pair[1]).is_empty():
			continue
		if not purchase:
			return season
		for id: String in pair:
			_check(
				(
					season
					. build
					. commit(
						_command(
							season.build,
							"equip",
							{"offer": _offer(season.build, id), "replace": ""}
						)
					)
					. ok
				),
				"buy generated earned Gear with actual income"
			)
		_check(season.build.commit(_command(season.build, "leave_shop")).ok, "close paid shop")
		_check(season.build._gear_progress.games.is_empty(), "purchase is not completed use")
		print("GEAR_CHAIN tier=", pair, " season=", season.career.current, " seed=", seed_value)
		return season
	_check(false, "reachable paired paid Gear")
	return null


func _used(season: SeasonState, win: bool = true) -> void:
	var state: MatchState = season.make_match()
	state.begin_pitch()
	state.note_pitch_released(&"pitch.overhand_four_seam", 6.0)
	var game: Dictionary = season.pending_fixture()
	var rival: int = game.away if game.home == 0 else game.home
	var home_wins: bool = (game.home == 0) == win
	_check(
		season.record_player_result(
			game.id,
			0 if home_wins else 1,
			1 if home_wins else 0,
			_sample(season.teams[0].roster, season.teams[rival].roster),
			state.gear_usage.first_pitch
		),
		"controlled completed game earns use"
	)


func _chain() -> SeasonState:
	var club: ClubCareer
	var season: SeasonState
	for stage in range(3):
		season = _paid_pair(BASE_PAIR if stage == 0 else NEXT_PAIR, club)
		if season == null:
			return null
		while season.phase != SeasonState.Phase.FINAL:
			_used(season)
		if stage == 2:
			_check(
				season.build._gear_progress.counts()[NEXT_PAIR[0]] == 19,
				"nineteen across two paid tier-two seasons"
			)
			return season
		_used(season)
		_check(SeasonSave.save(season), "atomic completed season and progression")
		season = SeasonSave.restore()
		if season == null:
			_check(false, "earned chain reloads")
			return null
		club = season.career.fork()
		_check(club.close(season), "close completed run for next paid season")
		_check(club.gear_counts()[BASE_PAIR[0]] == 10, "ten base uses persisted exactly once")
	return season


func _persistence(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "persist nineteen before actual final")
	var abandoned: ClubCareer = season.career.fork()
	_check(
		abandoned.close(season) and abandoned.gear_counts()[NEXT_PAIR[0]] == 19,
		"partial counters survive abandonment"
	)
	_check(ClubCareer.from_data(abandoned.to_data()) != null, "abandoned partial progress reloads")
	var before: Dictionary = season.career.to_data()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var state: MatchState = season.make_match()
	state.begin_pitch()
	state.note_pitch_released(&"pitch.overhand_four_seam", 6.0)
	_check(
		SeasonSave.restore().build._gear_progress.counts()[NEXT_PAIR[0]] == 19,
		"unfinished release has no persistent credit"
	)
	_used(season, false)
	_check(
		season.build._gear_progress.counts()[NEXT_PAIR[0]] == 20,
		"loss counts, parallel Bat and Ball"
	)
	_check(season.build._gear_progress.counts()[NEXT_PAIR[1]] == 20, "Ball also reaches twenty")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/file.json"
	_check(
		not SeasonSave.save(season) and ClubCareer.same(before, season.career.to_data()),
		"failed save publishes no career change"
	)
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == bytes, "failure preserves old bytes")
	_check(SeasonSave.save(season), "retry commits exact twenty once")
	_check(
		SeasonSave.save(season) and SeasonSave.restore().career.gear_counts()[NEXT_PAIR[0]] == 20,
		"duplicate save cannot add use"
	)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for field: String in ["baseline", "use", "duplicate", "missing", "untracked", "catalog"]:
		var bad: Dictionary = saved.duplicate(true)
		match field:
			"baseline":
				bad.build.gear_start[BASE_PAIR[0]] += 1
			"use":
				bad.career.runs[-1].gear[0].items = ["BAT-POW-01"]
			"duplicate":
				bad.career.runs[-1].gear.append(bad.career.runs[-1].gear[-1])
			"missing":
				bad.career.runs[-1].gear.clear()
			"untracked":
				bad.build.gear_start = null
			"catalog":
				bad.build.catalog = "changed"
		_check(SeasonSave._decode(bad) == null, "reject inconsistent earned " + field)
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "finish preserves earned access")
	var third: SeasonState = _paid_pair(["BAT-CON-03", "BALL-MOV-03"], club)
	_check(third != null, "third tiers purchasable without same-season predecessor")
	if third != null:
		_check(third.build.view().wallet.gear.bat.paid == 20, "third tier is paid, never granted")
		_check(third.career.close(third), "abandon unfinished third-tier season")
		_check(
			third.career.gear_counts()[NEXT_PAIR[0]] == 20,
			"abandonment retains prior earned progress"
		)


func _progress_ui(season: SeasonState) -> void:
	_check(SeasonSave.save(season), "UI uses settled real history")
	var app: SeasonApp = SeasonApp.new()
	app.season = season
	add_child(app)
	await _frames()
	app.menu.show_home()
	await _click(_button(app.menu, "CLUB RECORD"))
	await _click(_button(app.menu, "GEAR PROGRESSION"))
	await _menu_bounds(app, "earned-gear-progress")
	_check(app.menu.page == "gear_progress", "actual navigation opens progression")
	await _click(_button(app.menu, "BACK TO CLUB RECORD"))
	_check(
		SeasonSave.restore().career.gear_counts()[NEXT_PAIR[0]] == 20,
		"read-only inspection never pays again"
	)
	app.queue_free()
	await _frames()


func _migration_progress() -> void:
	var season: SeasonState = _paid_pair(BASE_PAIR)
	if season == null:
		return
	season.build._format = 19
	season.build._order_start = null
	season.career.runs[-1].order_rerolls = null
	season.build._sponsor_progress = SeasonSponsorProgress.new()
	season.career.runs[-1].sponsors = null
	season.build._gear_progress = SeasonGearProgress.new()
	season.career.runs[-1].gear = null
	_check(SeasonSave.save(season), "old build saves without tracking")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	old.career.version = 1
	for run: Dictionary in old.career.runs:
		run.erase("gear")
		run.erase("sponsors")
		run.erase("order_rerolls")
	var restored: SeasonState = SeasonSave._decode(old)
	_check(restored != null, "version-one career migrates")
	if restored != null:
		_check(
			not restored.build._gear_progress.enabled and restored.career.gear_counts().is_empty(),
			"legacy use never invented"
		)
		_check(
			restored.build.view() == season.build.view(),
			"migration preserves current stock, money and ownership"
		)
		_used(restored)
		_check(
			SeasonSave.save(restored) and SeasonSave.restore().career.gear_counts().is_empty(),
			"old active run remains untracked"
		)


func _earned_replacement_ui(completed: SeasonState) -> void:
	var club: ClubCareer = completed.career.fork()
	_check(club.close(completed), "close history for replacement fixture")
	var season: SeasonState = _paid_pair(["BAT-CON-01", "BAT-CON-03"], club, false)
	if season == null:
		return
	_check(
		(
			season
			. build
			. commit(
				_command(
					season.build,
					"equip",
					{"offer": _offer(season.build, "BAT-CON-01"), "replace": ""}
				)
			)
			. ok
		),
		"buy predecessor to explicitly replace"
	)
	_check(SeasonSave.save(season), "paid replacement starts from durable current loadout")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.open_shop()
	await _frames()
	var window: SeasonShopWindow = _shop(app)
	window.size = Vector2i(700, 400)
	await _shop_bounds(window, "earned-replacement-narrow")
	var offer: String = _offer(app.season.build, "BAT-CON-03")
	var before: Dictionary = app.season.build.to_data()
	var path: String = SeasonSave.path
	var bytes: String = FileAccess.get_file_as_string(path)
	await _click(_gear_button(window, "gear_offer", offer))
	_check(
		window._review_text.text.contains("Cash: 26 → 11"),
		"earned replacement quotes sale and full new price"
	)
	await _click(window._confirm.get_cancel_button())
	_check(
		app.season.build.to_data() == before, "cancel leaves both exact copies and stock untouched"
	)
	SeasonSave.path = path + "/missing/save.json"
	await _click(_gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	SeasonSave.path = path
	_check(
		app.season.build.to_data() == before and FileAccess.get_file_as_string(path) == bytes,
		"earned replacement rollback preserves money, access and ownership"
	)
	await _click(_gear_button(window, "gear_offer", offer))
	await _click(window._confirm.get_ok_button())
	var receipt: Dictionary = app.season.build.view().wallet.gear.bat
	_check(
		receipt.item == "BAT-CON-03" and receipt.paid == 20 and app.season.cash() == 11,
		"paid higher tier replaces, never stacks with predecessor"
	)
	_check(
		SeasonSave.restore().build.view() == app.season.build.view(),
		"earned replacement replays exactly"
	)
	await _shop_bounds(window, "earned-replacement-equipped")
	app.queue_free()
	await _frames()

extends "res://src/tests/season_abilities_test.gd"

var _major_fixture: SeasonState
var _major_offer: String


func _ready() -> void:
	SeasonSave.path = "user://double-major-%d.json" % OS.get_process_id()
	_progress_major()
	var season: SeasonState = _paid_major()
	if season != null:
		_major_transactions(season)
		_major_capacity(season)
		_major_wholesale()
		_major_migration()
		await _major_ui(season)
	for suffix: String in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(SeasonSave.path + suffix)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro Double Major checks passed: paid dual learning, capacity, forgetting, saves and UI."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _progress_major() -> void:
	var season: SeasonState = _new_club(67)
	_check(_jump_result(season, false, false), "different fielders complete a loss")
	_check(not season.build._major.earned, "different fielders cannot combine styles")
	_check(_jump_result(season, true, false), "same Primary completes both styles in loss")
	_check(season.build._major.earned, "loss earns paid future eligibility")
	_check(SeasonSchoolSponsors.active(season.build, "F09").is_empty(), "no free sponsor")
	var rows: Array = (
		season
		. build
		. to_data()
		. events
		. filter(func(e: Dictionary) -> bool: return e.op == "reward")[-1]
		. fielding
	)
	for mode: String in ["bobble", "pitcher", "ground", "air"]:
		var bad: Array = rows.duplicate(true)
		for row: Dictionary in bad:
			if mode == "bobble":
				row.clean = false
			elif mode == "pitcher":
				row.primary = false
			else:
				row.air = mode == "air"
		_check(not SeasonDoubleMajor.qualifies(bad), "exclude " + mode)
	_check(season.career.sync(season), "sync earned feat")
	var club: ClubCareer = season.career.fork()
	_check(club.close(season), "earned access survives abandonment")
	var next: SeasonState = _new_club(67, club)
	_check(
		next.build._major.start == true and next.build._major.player == "",
		"new season inherits access only"
	)


func _paid_major() -> SeasonState:
	var probe: SeasonState = _new_club(0)
	for game in range(6):
		_check(_jump_result(probe), "prepare paid fixture rewards")
	for seed_value in range(100000):
		probe.build._seed = seed_value
		var offers: Array = probe.build._offers(0).values()
		if (
			not offers.has("F09")
			or not offers.has(SeasonAbilities.HANDS)
			or not offers.has(SeasonAbilities.SKY)
		):
			continue
		var season: SeasonState = _new_club(seed_value)
		for game in range(6):
			_jump_result(season)
		var build: SeasonBuild = season.build
		_check(build.commit(_command(build, "open")).ok, "actual generated paid shop")
		_major_offer = _offer(build, "F09")
		_check(SeasonSave.save(season), "save pre-purchase fixture")
		_major_fixture = SeasonSave.restore()
		var target: String = build.roster()[1]
		var purchase: Dictionary = _command(
			build, "sponsor_buy", {"offer": _major_offer, "replace": ""}
		)
		var before: Dictionary = build.to_data()
		_check(
			not build.commit(purchase).ok and before == build.to_data(),
			"nomination required atomically"
		)
		purchase["major"] = {"player": target, "forget": ""}
		_check(build.commit(purchase).ok, "pay 18 and nominate exact player")
		_check(build.view().wallet.capacity.held == 1, "shared bag loses one slot")
		for item: String in [SeasonAbilities.HANDS, SeasonAbilities.SKY]:
			_check(
				(
					build
					. commit(
						_command(
							build,
							"ability_buy",
							{"offer": _offer(build, item), "player": target, "replace": ""}
						)
					)
					. ok
				),
				"pay for separate " + item
			)
		_check(
			build._abilities.ids(target).size() == 2, "nominated player retains both paid abilities"
		)
		_check(SeasonSave.save(season), "dual learning saves")
		print("DOUBLE_MAJOR_FIXTURE seed=", seed_value, " cash=", build.cash())
		return season
	_check(false, "reachable F09 and both Fielding offers")
	return null


func _major_transactions(season: SeasonState) -> void:
	var original: SeasonBuild = season.build
	var target: String = original._major.player
	var rows: Array = original._abilities.in_slot(target, "Fielding")
	var active: Dictionary = SeasonSchoolSponsors.active(original, "F09")
	for op: String in ["sponsor_sell", "major_assign"]:
		var build: SeasonBuild = original._fork()
		var command: Dictionary = _command(
			build, op, {"receipt": active.id} if op == "sponsor_sell" else {}
		)
		var before: Dictionary = build.to_data()
		_check(
			not build.commit(command).ok and build.to_data() == before,
			"explicit forgetting required " + op
		)
		command["major"] = {
			"player": "" if op == "sponsor_sell" else build.roster()[2], "forget": "foreign"
		}
		_check(
			not build.commit(command).ok and build.to_data() == before, "foreign receipt rejected"
		)
		command.major.forget = rows[0].id
		_check(build.commit(command).ok, "reviewed " + op)
		_check(
			build._abilities.ids(target) == [SeasonAbilities.SKY], "forget only selected ability"
		)
		_check(
			build.cash() == original.cash() + (9 if op == "sponsor_sell" else 0),
			"no learning refund"
		)
		_check(build.commit(command).replayed, "idempotent explicit forgetting")
		_check(original._abilities.ids(target).size() == 2, "deep fork isolation")
		if op == "major_assign":
			_check(
				build._abilities.ids(build.roster()[2]).is_empty(),
				"nomination transfers no learning"
			)
	_check(SeasonSave.save(season), "paid dual fixture save")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	var loaded: SeasonState = SeasonSave._decode(data.duplicate(true))
	_check(loaded != null and loaded.build._major.player == target, "replay nomination")
	for mode: String in ["career", "inherited", "nominee"]:
		var bad: Dictionary = data.duplicate(true)
		if mode == "career":
			bad.career.runs[-1].major_earned = false
		elif mode == "inherited":
			bad.build.major_start = true
		else:
			for event: Dictionary in bad.build.events:
				if event.has("major"):
					event.major.player = "foreign"
		_check(SeasonSave._decode(bad) == null, "reject forged " + mode)
	# Controlled offer isolates departure, using actual paid learned receipts.
	var departing: SeasonBuild = original._fork()
	departing._visit.number = 6
	var incoming: String = ""
	for id: String in departing._pool:
		if not departing.roster().has(id) and not departing._blocked.has(id):
			incoming = id
			break
	departing._visit.recruit = {
		"id": "departure-test",
		"player": incoming,
		"signed": false,
		"price": 0,
		"returning": false,
		"stage": "late"
	}
	var release: Dictionary = _command(
		departing, "sign", {"offer": "departure-test", "replace": target}
	)
	_check(not departing.commit(release).ok, "departure cannot hide excess learning")
	release["major"] = {"player": "", "forget": rows[1].id}
	_check(departing.commit(release).ok, "departure explicitly forgets one")
	_check(
		(
			departing._major.player == ""
			and departing._abilities.ids(target) == [SeasonAbilities.HANDS]
		),
		"released instance retains ordinary slot"
	)
	_check(departing._abilities.ids(incoming).is_empty(), "replacement inherits no learning")


func _major_capacity(season: SeasonState) -> void:
	# Isolated ownership primitive checks all capacity combinations and rollback.
	var bank: SeasonOwnership = SeasonOwnership.new(SeasonSponsorCatalog.ownership_catalog())
	_check(
		bank.commit({"id": "cash", "rev": 0, "op": "reward", "game": 0, "win": true}).ok,
		"capacity test bank"
	)
	for game in range(1, 6):
		bank.commit(
			{
				"id": "cash%d" % game,
				"rev": bank.revision(),
				"op": "reward",
				"game": game,
				"win": true
			}
		)
	bank.commit(
		{
			"id": "stock",
			"rev": bank.revision(),
			"op": "stock",
			"offers":
			{"major": "F09", "batch": "G02", "association": "J05", "one": "A10", "two": "C02"}
		}
	)
	for offer: String in ["one", "two"]:
		_check(
			(
				bank
				. commit(
					{
						"id": offer,
						"rev": bank.revision(),
						"op": "buy",
						"offer": offer,
						"replace": "",
						"discard": []
					}
				)
				. ok
			),
			"fill shared bag"
		)
	var request: Dictionary = {
		"id": "major",
		"rev": bank.revision(),
		"op": "buy",
		"offer": "major",
		"replace": "",
		"discard": []
	}
	var before: Dictionary = bank.to_data()
	_check(
		not bank.commit(request).ok and bank.to_data() == before,
		"F09 never silently deletes supply"
	)
	request.discard = ["one"]
	_check(
		bank.commit(request).ok and bank.view().held.size() == 1,
		"explicit discard makes exact room"
	)
	_check(
		(
			bank
			. commit(
				{
					"id": "batch",
					"rev": bank.revision(),
					"op": "buy",
					"offer": "batch",
					"replace": "",
					"discard": []
				}
			)
			. ok
		),
		"Small Batch plus Double Major"
	)
	_check(
		bank.view().capacity.held == 2 and bank.view().capacity.sponsors == 3,
		"combined capacities two and three"
	)
	_check(
		not (
			bank
			. commit(
				{
					"id": "association",
					"rev": bank.revision(),
					"op": "buy",
					"offer": "association",
					"replace": "",
					"discard": []
				}
			)
			. ok
		),
		"Association cannot coexist with Rare F09"
	)
	var build: SeasonBuild = season.build._fork()
	var selected: String = build._major.player
	build._major.player = build.roster()[2]
	_check(
		not build._abilities.targets(build, SeasonAbilities.HANDS).has(
			{"player": selected, "replace": ""}
		),
		"ordinary players never gain extra slot"
	)


func _major_wholesale() -> void:
	# Controlled quotes isolate the shared-set adapter; F09's underlying paid offer is real.
	var build: SeasonBuild = _major_fixture.build._fork()
	build._batch_start = SeasonSmallBatch.TYPES.duplicate()
	build._visit.offers["batch-test"] = "G02"
	var bank: SeasonOwnership = build._bank
	bank.commit(
		{
			"id": "pair-stock",
			"rev": bank.revision(),
			"op": "stock",
			"offers": {"pair-club": "J02", "pair-one": "A10", "pair-two": "C02"}
		}
	)
	for offer: String in ["pair-club", "pair-one", "pair-two"]:
		_check(
			(
				bank
				. commit(
					{
						"id": offer,
						"rev": bank.revision(),
						"op": "buy",
						"offer": offer,
						"replace": "",
						"discard": []
					}
				)
				. ok
			),
			"controlled Wholesale prerequisite"
		)
	var cash_before: int = build.cash()
	var command: Dictionary = _command(
		build,
		"wholesale",
		{
			"first": {"offer": _major_offer, "replace": ""},
			"second": {"offer": "batch-test", "replace": ""},
			"discounted": "batch-test",
			"major": {"player": build.roster()[1], "forget": ""}
		}
	)
	_check(build.commit(command).ok, "paired F09 + Small Batch evaluates final capacity")
	_check(build.cash() == cash_before - 27, "exact Wholesale cheaper-item discount")
	_check(
		build.view().wallet.held.size() == 2 and build.view().wallet.capacity.held == 2,
		"pair retains both held copies"
	)
	var batch: Dictionary = SeasonSchoolSponsors.active(build, "G02")
	var removal: Dictionary = _command(build, "sponsor_sell", {"receipt": batch.id})
	var before: Dictionary = build.to_data()
	_check(
		not build.commit(removal).ok and build.to_data() == before,
		"Small Batch removal must resolve bag beside F09"
	)
	removal["discard"] = ["pair-one"]
	_check(
		build.commit(removal).ok and build.view().wallet.held.size() == 1,
		"explicit paired-capacity resolution"
	)


func _major_migration() -> void:
	var old: SeasonState = _new_club(67)
	old.build._format = 36
	old.build._major.start = null
	old.career.runs[-1].major_earned = null
	_jump_result(old)
	old.build.commit(_command(old.build, "open"))
	var stock: Dictionary = old.build.view().shop
	_check(SeasonSave.save(old), "save actual Build36 journal")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SeasonSave.path))
	data.career.version = 17
	data.career.runs[-1].erase("major_earned")
	var loaded: SeasonState = SeasonSave._decode(data)
	_check(loaded != null, "Build36 migration")
	if loaded == null:
		return
	_check(
		loaded.build._major.start == null and loaded.build.view().shop == stock,
		"no retrospective unlock or stock replacement"
	)
	_check(
		not SeasonEarnedSponsors.eligible(loaded.build).has("F09"),
		"older active season remains prospective"
	)
	_check(SeasonSave.save(loaded) and SeasonSave.restore() != null, "migrated roundtrip")


func _major_ui(season: SeasonState) -> void:
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	var window: SeasonShopWindow = SeasonShopWindow.new()
	window.app = app
	app.add_child(window)
	window.popup_centered()
	await _frames()
	app.season = _major_fixture
	window._refresh()
	var buying: Dictionary = window._request("sponsor_buy", {"offer": _major_offer, "replace": ""})
	window._preview(buying, "Buy Double Major")
	await _frames()
	var nomination: SeasonMajorResolution
	for child: Node in window.get_children():
		if child is SeasonMajorResolution:
			nomination = child
	_check(
		nomination != null and nomination.get_ok_button().disabled,
		"purchase needs explicit nominee"
	)
	if nomination != null:
		nomination._player.select(2)
		nomination._refresh()
		nomination._accept()
	await _frames()
	_check(
		window._confirm.visible and window._review_text.text.contains("beneficiary"),
		"exact nomination final review"
	)
	var purchase_before: Dictionary = app.season.build.to_data()
	var purchase_path: String = SeasonSave.path
	SeasonSave.path = "user://missing-major-buy/season.json"
	window._confirm.hide()
	window._commit()
	_check(
		app.season.build.to_data() == purchase_before, "failed purchase save retains Cash and stock"
	)
	SeasonSave.path = purchase_path
	app.season = season
	window._refresh()
	var active: Dictionary = SeasonSchoolSponsors.active(season.build, "F09")
	window._preview(window._request("sponsor_sell", {"receipt": active.id}), "Sell Double Major")
	await _frames()
	var picker: SeasonMajorResolution
	for child: Node in window.get_children():
		if child is SeasonMajorResolution:
			picker = child
	_check(
		picker != null and picker.get_ok_button().disabled,
		"sale requires intentional ability choice"
	)
	if picker != null:
		picker._forget.select(1)
		picker._enabled()
		picker._accept()
	await _frames()
	_check(
		window._confirm.visible and window._review_text.text.contains("No refund"),
		"final review names forgotten learning"
	)
	var before: Dictionary = season.build.to_data()
	var path: String = SeasonSave.path
	SeasonSave.path = "user://missing-major-dir/season.json"
	window._confirm.hide()
	window._commit()
	_check(season.build.to_data() == before, "failed save rolls back sponsor and both abilities")
	SeasonSave.path = path
	var assign: Dictionary = window._request("major_assign")
	window._preview(assign, "Change beneficiary")
	await _frames()
	for child: Node in window.get_children():
		if child is SeasonMajorResolution:
			child.canceled.emit()
	_check(season.build.to_data() == before, "cancel keeps paid specialist")
	await _shop_bounds(window, "double-major-shop")
	window.queue_free()
	app.queue_free()
	await _frames()

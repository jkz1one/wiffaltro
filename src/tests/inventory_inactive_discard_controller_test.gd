extends "res://src/tests/inventory_live_build_test.gd"
## Controlled runtime seam. Paid Build is genuinely replayed and saved by a test checkpoint,
## but the season and pre-existing full-delivery latch are synthetic, NOT save78 qualification.


class BuildCheckpointApp:
	extends SeasonApp
	var build_path: String
	var refuse: bool = false

	func _checkpoint() -> bool:
		if refuse:
			notice = "Controlled checkpoint refusal"
			return false
		var build: SeasonBuild = season.build
		var data: Dictionary = build.to_data()
		var cold: SeasonBuild = SeasonBuild.from_data(
			JSON.parse_string(JSON.stringify(data, "", true, true)), build._seed, build.roster()
		)
		if cold == null or not ClubCareer.same(cold.to_data(), data):
			notice = "Controlled Build cold replay failed"
			return false
		var file: FileAccess = FileAccess.open(build_path, FileAccess.WRITE)
		if file == null:
			return false
		file.store_string(JSON.stringify(data, "", true, true))
		file.close()
		return ClubCareer.same(JSON.parse_string(FileAccess.get_file_as_string(build_path)), data)


func _ready() -> void:
	SeasonSave.path = "user://inactive-discard-controller-%d.json" % OS.get_process_id()
	PitchBatLabSettings.path = "user://inactive-discard-controller-%d.cfg" % OS.get_process_id()
	var build: SeasonBuild = _paid_capacity_build()
	if build == null:
		get_tree().quit(1)
		return
	check(
		build.commit(SeasonOpponentPolicy.command(build, "match_inventory", {"game": 8})).ok,
		"real current attempt for grouped sale"
	)
	var own: TeamMatchState = _build_team(build)
	var state: MatchState = MatchState.create(
		_team(SeasonPlayerCatalog.ids().slice(4, 8), build._bank), own
	)
	state.league_rules = build._league_rules.duplicate(true)
	_out(state)
	state.phase = MatchState.Phase.PRE_PITCH
	state.between_batters = true
	state.base_flow.prepare(state)
	var pitch: PitchDefinition = state.pitcher().definition.starting_pitches[0]
	state.between_batters = false
	state.phase = MatchState.Phase.PITCH_IN_FLIGHT
	state.pitcher().spend_stamina(pitch.stamina_cost)
	state.note_pitch_released(pitch.id, pitch.stamina_cost)
	state.record_ball()
	state.phase = MatchState.Phase.PRE_PITCH
	# Explicit synthetic pre-existing latch: this diagnostic tests preservation, not earning it.
	own.field_supply._delivery = {"after_pa": 1, "outcome": "full"}
	var app: BuildCheckpointApp = BuildCheckpointApp.new()
	add_child(app)
	await get_tree().process_frame
	app.season = SeasonState.new()
	app.season.build = build
	app.build_path = "user://inactive-discard-build-%d.json" % OS.get_process_id()
	app.lab = PitchBatLab.new()
	app.lab._match_state = state
	app.lab._player_home = true
	app.lab._debug_paused = true
	app.lab._release_controller = PitchReleaseController.new()
	app._season_game = true
	app._fixture_id = 8
	app.loadout.match_snapshot = build._bank.view().duplicate(true)
	var sponsor: String = ""
	var inactive: String = ""
	for copy: Dictionary in build._bank.view().sponsors:
		if copy.item == "G02":
			sponsor = copy.id
	for copy: Dictionary in build._bank.view().held:
		if DevelopmentShopCatalog.CARDS.has(copy.item):
			inactive = copy.id
	check(
		(
			not sponsor.is_empty()
			and not inactive.is_empty()
			and own.field_supply.reserved == 1
			and own.field_supply.capacity == 4
		),
		"paid shared bag has one inactive and three tactical slots"
	)
	var request: Dictionary = SeasonMatchSales.command(app, sponsor)
	request["discard"] = [inactive]
	request["discarded_use"] = []
	check(
		build.candidate(request) != null,
		"grouped capacity sponsor sale previews explicit inactive discard"
	)
	check(app._checkpoint(), "controlled original Build cold checkpoint")
	var bytes: String = FileAccess.get_file_as_string(app.build_path)
	var before: Dictionary = build.to_data()
	app.refuse = true
	check(not app.sales.sell(app, request), "failed durable checkpoint rejects grouped sale")
	check(
		(
			app.season.build == build
			and ClubCareer.same(before, build.to_data())
			and FileAccess.get_file_as_string(app.build_path) == bytes
			and own.field_supply.reserved == 1
			and own.field_supply.capacity == 4
			and app.sales.pending.is_empty()
		),
		"rollback preserves Build, bytes and runtime occupancy/effects"
	)
	app.refuse = false
	check(
		app.sales.sell(app, request),
		"grouped controller sale commits through genuine cold Build checkpoint"
	)
	check(
		(
			own.field_supply.reserved == 0
			and own.field_supply.capacity == 4
			and int(app.season.build._bank.view().capacity.held) == 3
		),
		"inactive discard frees reserved occupancy immediately but active-PA capacity stays deferred"
	)
	check(
		(
			own.field_supply.evidence() == {"after_pa": 1, "outcome": "full"}
			and not app.sales.pending.is_empty()
		),
		"forfeiture latch stays fixed while sponsor retirement is pending"
	)
	_out(state)
	app.sales.apply_pending(app)
	check(
		(
			own.field_supply.capacity == 3
			and own.field_supply.reserved == 0
			and app.sales.pending.is_empty()
		),
		"next batter applies deferred sponsor capacity"
	)
	check(
		own.field_supply.evidence() == {"after_pa": 1, "outcome": "full"},
		"later space cannot revive forfeited delivery"
	)
	app.lab.free()
	app.lab = null
	app.queue_free()
	await get_tree().process_frame
	print("Inactive discard controller checks: %d, failures: %d" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)


func _paid_capacity_build() -> SeasonBuild:
	var ids: Array[String] = []
	ids.assign(SeasonPlayerCatalog.ids().slice(0, 4))
	var probe: SeasonBuild = SeasonBuild.new(0, ids)
	probe.enable_league_rules(LeagueRules.capture("dugout"))
	probe._batch_start = SeasonSmallBatch.TYPES.duplicate()
	probe._supply_start = 3
	probe._visit.number = 8
	var seed_value: int = -1
	for candidate in range(20000):
		probe._seed = candidate
		var offers: Array = probe._offers(0).values()
		if (
			offers.has("G02")
			and offers.any(func(id: String) -> bool: return DevelopmentShopCatalog.CARDS.has(id))
			and offers.any(func(id: String) -> bool: return SeasonTacticalCatalog.catalog().has(id))
		):
			seed_value = candidate
			break
	check(seed_value >= 0, "controlled eligible real seeded capacity/development stock")
	if seed_value < 0:
		return null
	var build: SeasonBuild = SeasonBuild.new(seed_value, ids)
	build.enable_league_rules(LeagueRules.capture("dugout"))
	build._batch_start = SeasonSmallBatch.TYPES.duplicate()
	build._supply_start = 3
	var enabled: Dictionary = build.commit(
		{"id": "inventory-rules-v1", "rev": 0, "op": SeasonInventoryResale.ENABLE_OP}
	)
	check(enabled.ok, "explicit inventory capability: " + str(enabled.get("error")))
	if not enabled.ok:
		return null
	for game in range(8):
		check(
			(
				build
				. commit(SeasonOpponentPolicy.command(build, "reward", {"game": game, "win": true}))
				. ok
			),
			"synthetic replayable funding"
		)
	check(
		build.commit(SeasonOpponentPolicy.command(build, "open")).ok, "seeded eligible shop opens"
	)
	for key: String in build._visit.offers.keys():
		if build._visit.offers[key] == "G02":
			check(
				(
					build
					. commit(
						SeasonOpponentPolicy.command(
							build, "sponsor_buy", {"offer": key, "replace": ""}
						)
					)
					. ok
				),
				"paid capacity sponsor"
			)
	var inactive: bool = false
	for roll in range(12):
		for key: String in build._visit.offers.keys():
			var item: String = build._visit.offers[key]
			if not inactive and DevelopmentShopCatalog.CARDS.has(item):
				var result: Dictionary = build.commit(
					SeasonOpponentPolicy.command(
						build,
						"buy",
						{"offer": key, "mode": "hold", "player": "", "pitch": "", "replace": ""}
					)
				)
				inactive = result.ok
			elif SeasonTacticalCatalog.catalog().has(item) and build._bank.view().held.size() < 4:
				check(
					(
						build
						. commit(
							SeasonOpponentPolicy.command(build, "tactical_buy", {"offer": key})
						)
						. ok
					),
					"actual paid tactical occupancy"
				)
		if inactive and build._bank.view().held.size() == 4:
			break
		if not build.commit(SeasonOpponentPolicy.command(build, "reroll")).ok:
			break
	check(inactive and build._bank.view().held.size() == 4, "paid full shared bag assembled")
	print("INACTIVE_DISCARD_SETUP seed=", seed_value, " cash=", build.cash())
	return build if inactive and build._bank.view().held.size() == 4 else null

extends Node
## Bounded draft-rule contracts only. No earned title or physical-game claim.
## Exact20/10-arm synthetic seam is untested; production catalog stays immutable.

const SEEDS: Array[int] = [0, 42, -42, 2147483647]
const LEGACY_GOLDEN: Array[Dictionary] = [
	{
		"label": "base",
		"seed": 7,
		"picks": [
			"player.mika_reed",
			"player.val_morgan",
			"player.ash_cole",
			"player.casey_rivers"
		],
		"pool": [
			"player.indy_shaw",
			"player.jo_lane",
			"player.mika_reed",
			"player.jules_moss",
			"player.emery_lane",
			"player.val_morgan",
			"player.ash_cole",
			"player.cal_mercer",
			"player.frankie_bell",
			"player.casey_rivers",
			"player.dakota_wells",
			"player.finley_brooks"
		],
		"access": [
			"player.ash_cole",
			"player.cal_mercer",
			"player.casey_rivers",
			"player.dakota_wells",
			"player.emery_lane",
			"player.finley_brooks",
			"player.frankie_bell",
			"player.indy_shaw",
			"player.jo_lane",
			"player.jules_moss",
			"player.mika_reed",
			"player.val_morgan"
		],
		"order": [
			5,
			3,
			4,
			1,
			2
		],
		"rosters": {
			"1": [
				"player.morgan_pike",
				"player.quinn_riley",
				"player.riley_grant",
				"player.finley_brooks"
			],
			"2": [
				"player.ari_banks",
				"player.parker_hayes",
				"player.lee_stone",
				"player.skyler_woods"
			],
			"3": [
				"player.reese_hart",
				"player.robin_sage",
				"player.jo_lane",
				"player.jamie_nash"
			],
			"4": [
				"player.alex_finch",
				"player.marley_quinn",
				"player.nico_vega",
				"player.drew_sato"
			],
			"5": [
				"player.kendall_reed",
				"player.dev_lin",
				"player.sam_park",
				"player.tess_vale"
			]
		}
	},
	{
		"label": "d1",
		"seed": 7,
		"picks": [
			"player.skyler_woods",
			"player.quinn_riley",
			"player.val_morgan",
			"player.kit_rowan"
		],
		"pool": [
			"player.indy_shaw",
			"player.skyler_woods",
			"player.jo_lane",
			"player.rowan_chase",
			"player.quinn_riley",
			"player.mika_reed",
			"player.jules_moss",
			"player.emery_lane",
			"player.val_morgan",
			"player.ash_cole",
			"player.cal_mercer",
			"player.kit_rowan",
			"player.frankie_bell",
			"player.casey_rivers",
			"player.dakota_wells",
			"player.sam_park",
			"player.finley_brooks"
		],
		"access": [
			"player.ash_cole",
			"player.cal_mercer",
			"player.casey_rivers",
			"player.dakota_wells",
			"player.emery_lane",
			"player.finley_brooks",
			"player.frankie_bell",
			"player.indy_shaw",
			"player.jo_lane",
			"player.jules_moss",
			"player.kit_rowan",
			"player.mika_reed",
			"player.quinn_riley",
			"player.rowan_chase",
			"player.sam_park",
			"player.skyler_woods",
			"player.val_morgan"
		],
		"order": [
			5,
			3,
			4,
			1,
			2
		],
		"rosters": {
			"1": [
				"player.marley_quinn",
				"player.noel_hart",
				"player.ren_ellis",
				"player.eli_frost"
			],
			"2": [
				"player.ari_banks",
				"player.morgan_pike",
				"player.kendall_reed",
				"player.shiloh_dean"
			],
			"3": [
				"player.parker_hayes",
				"player.river_blake",
				"player.indy_shaw",
				"player.hayden_cole"
			],
			"4": [
				"player.alex_finch",
				"player.logan_ames",
				"player.mika_reed",
				"player.dakota_wells"
			],
			"5": [
				"player.jules_moss",
				"player.casey_rivers",
				"player.sage_avery",
				"player.tess_vale"
			]
		}
	}
]
var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_legacy_golden_cases()
	_allocation_contracts()
	_minimum_pools()
	_invalid_inputs()
	_context_contracts()
	_rule_refusals()
	_check(_checks == 472, "exact bounded native assertion count")
	await TestAudioDrain.finish(get_tree())
	print("STANDARD_D2_DRAFT checks=%d failures=%d seeds=4 physical_games=0" %
		[_checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("STANDARD_D2_DRAFT: " + label)


func _legacy_golden_cases() -> void:
	# Expected identities come from hash-pinned accepted Base/d1 saves, not this allocator.
	for fixture: Dictionary in LEGACY_GOLDEN:
		var available: Array[String] = SeasonPlayerCatalog.ids()
		for id: String in fixture.picks:
			available.erase(id)
		var allocation: Dictionary = SeasonOpponentDraft.allocate(int(fixture.seed), available)
		_check(not allocation.is_empty(), "golden legacy pool remains feasible: " + fixture.label)
		if allocation.is_empty():
			continue
		var season: SeasonState = SeasonState.create(int(fixture.seed), false, true, true)
		season.opponents._format = 13
		if fixture.label == "d1":
			_check(season.build.enable_d1_pricing(), "golden d1 pricing context")
		season.draft_pool.assign(fixture.pool)
		season.player_access.assign(fixture.access)
		for id: String in fixture.picks:
			_check(season.choose_player(id), "golden ordinary human pick: " + fixture.label)
		_check(allocation.order == fixture.order and season.opponents.draft_order == fixture.order,
			"independent frozen legacy club order: " + fixture.label)
		for team: int in range(1, 6):
			_check(allocation.rosters[team] == fixture.rosters[str(team)]
				and season.teams[team].roster == fixture.rosters[str(team)],
				"independent frozen legacy roster: " + fixture.label + " club" + str(team))
		_check(not season.opponents.to_data().has("draft_rule"), "golden legacy representation")


func _allocation_contracts() -> void:
	_check(SeasonOpponentDraft.D2_RULE == "standard-d2-fit-draft-v1", "frozen rule identity")
	for seed_value: int in SEEDS:
		var available: Array[String] = SeasonPlayerCatalog.ids()
		var excluded: Array[String] = available.slice(0, 4)
		for id: String in excluded:
			available.erase(id)
		var original: Array[String] = available.duplicate()
		var allocation: Dictionary = SeasonOpponentDraft.allocate_d2(seed_value, available)
		var expected: Dictionary = _reference(seed_value, available)
		_check(not allocation.is_empty(), "feasible authored allocation")
		if allocation.is_empty():
			continue
		_check(available == original, "caller pool unchanged")
		available.reverse()
		_check(allocation == SeasonOpponentDraft.allocate_d2(seed_value, available),
			"repeat and shuffled caller input preserve exact result")
		_check(allocation.order == SeasonOpponentDraft.allocate(seed_value, available).order,
			"legacy club-order stream stays exact")
		_check(allocation.order == expected.order and allocation.rosters == expected.rosters,
			"independent trace uses frozen salts, snake, candidates and role preference")
		_check(expected.ties > 0, "authored trace exercises stable-ID ties")
		_audit(allocation, original)
		for turn: Dictionary in expected.turns:
			_check(turn.candidates.size() == 2 and turn.candidates[0] != turn.candidates[1],
				"two distinct candidates when available")
			_check(turn.pool_after.has(turn.loser), "loser remains in the next pool")


func _audit(allocation: Dictionary, available: Array[String]) -> void:
	var used: Array[String] = []
	var order: Array = allocation.order.duplicate()
	order.sort()
	_check(order == [1, 2, 3, 4, 5], "five unique opponent turns")
	for team: int in range(1, 6):
		var roster: Array = allocation.rosters[team]
		_check(roster.size() == 4, "four identities per opponent")
		for slot: int in range(4):
			var id: String = roster[slot]
			_check(available.has(id) and not used.has(id), "distinct eligible non-human card")
			used.append(id)
			if slot < 2:
				_check(SeasonPlayerCatalog.profile(id).stats.pitching >= 2, "first two are usable arms")
	_check(used.size() == 20, "exactly twenty selected identities")


func _minimum_pools() -> void:
	var available: Array[String] = SeasonPlayerCatalog.ids().slice(0, 20)
	var actual: Dictionary = SeasonOpponentDraft.allocate_d2(42, available)
	var reference: Dictionary = _reference(42, available)
	_check(not actual.is_empty() and actual.rosters == reference.rosters,
		"actual authored20-card pool completes with sole final candidate")
	_check(reference.turns[-1].candidates.size() == 1, "actual final turn needs no pair")


func _invalid_inputs() -> void:
	var available: Array[String] = SeasonPlayerCatalog.ids().slice(0, 20)
	var short_pool: Array[String] = available.slice(0, 19)
	_check(SeasonOpponentDraft.allocate_d2(42, short_pool).is_empty(), "nineteen cards refused")
	var duplicate: Array[String] = available.duplicate()
	duplicate[1] = duplicate[0]
	_check(SeasonOpponentDraft.allocate_d2(42, duplicate).is_empty(), "duplicate identity refused")
	var unknown: Array[String] = available.duplicate()
	unknown[1] = "player.missing"
	_check(SeasonOpponentDraft.allocate_d2(42, unknown).is_empty(), "unknown identity refused")
	var empty: Array[String] = []
	_check(SeasonOpponentDraft.allocate_d2(42, empty).is_empty(), "empty pool refused")


func _fresh(priced: bool, rule: String = "") -> SeasonState:
	var season: SeasonState = SeasonState.create(42, false, true, true)
	season.opponents._format = 13
	if priced:
		_check(season.build.enable_d1_pricing(), "shared d1 pricing installed")
	season.opponents.draft_rule = rule
	return season


func _context_contracts() -> void:
	var base: SeasonState = _fresh(false)
	var d1: SeasonState = _fresh(true)
	var d2: SeasonState = _fresh(true, SeasonOpponentDraft.D2_RULE)
	_check(not base.opponents.to_data().has("draft_rule")
		and not d1.opponents.to_data().has("draft_rule"), "Base/d1 omit additive field")
	_check(d2.opponents.to_data().draft_rule == SeasonOpponentDraft.D2_RULE,
		"partial draft retains exact d2 identity")
	for pick: int in range(4):
		_check(base.offers() == d1.offers() and base.offers() == d2.offers(),
			"all human offer batches unchanged")
		var id: String = base.offers()[pick % 3]
		_check(base.choose_player(id) and d1.choose_player(id) and d2.choose_player(id),
			"all selected human picks admitted")
	_check(base.picks == d1.picks and base.picks == d2.picks, "same human roster")
	_check(base.schedule == d1.schedule and base.schedule == d2.schedule,
		"schedule unchanged")
	var available: Array[String] = base.draft_pool.duplicate()
	for id: String in base.picks:
		available.erase(id)
	var legacy: Dictionary = SeasonOpponentDraft.allocate(base.season_seed, available)
	var fitting: Dictionary = SeasonOpponentDraft.allocate_d2(d2.season_seed, available)
	for team: int in range(6):
		_check(base.teams[team].draw == d1.teams[team].draw
			and base.teams[team].draw == d2.teams[team].draw, "standings draws unchanged")
		if team > 0:
			_check(base.teams[team].roster == legacy.rosters[team]
				and d1.teams[team].roster == legacy.rosters[team], "Base/d1 retain legacy allocation")
			_check(d2.teams[team].roster == fitting.rosters[team], "D2 selects exact new allocator")
			var club: Dictionary = d2.opponents.clubs[str(team)]
			var build: SeasonBuild = club.build
			_check(build._format == 42 and build._market == 12 and build.d1_pricing_valid(),
				"AI preserves shared build42 and market12 pricing")
			_check(build.cash() == 0 and build.revision() == 0, "no extra grant or hidden growth")
			_check(club.roles == SeasonOpponentPolicy.roles(build), "ordinary final role assignment")
			for id: String in build.roster():
				_check(build.player(id).stats == SeasonPlayerCatalog.profile(id).stats,
					"authored card stats unchanged")
	_check(d2.build._format == 42 and d2.build._market == 0 and d2.build.d1_pricing_valid()
		and d2.opponents._format == 13, "human build42 and opponent policy13 unchanged")
	_check(not base.opponents.to_data().has("draft_rule")
		and not d1.opponents.to_data().has("draft_rule"), "allocated Base/d1 field shape unchanged")


func _draft_view(season: SeasonState) -> Dictionary:
	return {"picks": season.picks.duplicate(), "teams": season.teams.duplicate(true),
		"phase": season.phase, "pool": season.draft_pool.duplicate(),
		"build": {} if season.build == null else season.build.to_data(),
		"opponents": season.opponents.to_data(), "schedule": season.schedule.duplicate(true)}


func _rule_refusals() -> void:
	for mode: String in ["unknown", "policy", "pricing", "market", "missing_build"]:
		var season: SeasonState = _fresh(true, SeasonOpponentDraft.D2_RULE)
		for pick: int in range(3):
			_check(season.choose_player(season.offers()[0]), "partial d2 draft setup")
		match mode:
			"unknown":
				season.opponents.draft_rule = "standard-d2-fit-draft-v999"
			"policy":
				season.opponents._format = 12
			"pricing":
				season.build = SeasonBuild.new(season.season_seed)
			"market":
				season.build._market = 12
			"missing_build":
				season.build = null
		var before: Dictionary = _draft_view(season)
		_check(not season.choose_player(season.offers()[0]), "mismatched rule context refused: " + mode)
		_check(_draft_view(season) == before, "refused fourth pick is atomic: " + mode)
		season.opponents.initialize(season)
		_check(_draft_view(season) == before, "refused initialization is atomic: " + mode)
	var short_pool: SeasonState = _fresh(true, SeasonOpponentDraft.D2_RULE)
	short_pool.draft_pool.resize(23)
	for pick: int in range(3):
		_check(short_pool.choose_player(short_pool.offers()[0]), "short pool initial picks")
	var before: Dictionary = _draft_view(short_pool)
	_check(not short_pool.choose_player(short_pool.offers()[0]), "infeasible d2 fourth pick refused")
	_check(_draft_view(short_pool) == before, "infeasible d2 fourth pick leaves state unchanged")


func _reference(seed_value: int, available: Array[String]) -> Dictionary:
	# Independent selection form: second index skips the first rather than removing a candidate.
	var remaining: Array[String] = available.duplicate()
	remaining.sort()
	var order: Array[int] = [1, 2, 3, 4, 5]
	var order_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	order_rng.seed = (seed_value + 15485863) & 0x7fffffff
	for index: int in range(4, 0, -1):
		var second: int = order_rng.randi_range(0, index)
		var saved: int = order[second]
		order[second] = order[index]
		order[index] = saved
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = (seed_value + 32452843) & 0x7fffffff
	var rosters: Dictionary = {1: [], 2: [], 3: [], 4: [], 5: []}
	var turns: Array[Dictionary] = []
	var ties: int = 0
	for turn_index: int in range(20):
		var round_number: int = floori(float(turn_index) / 5.0)
		var team: int = order[turn_index % 5 if round_number % 2 == 0 else 4 - turn_index % 5]
		var eligible: Array[String] = []
		for id: String in remaining:
			if round_number > 1 or SeasonPlayerCatalog.profile(id).stats.pitching >= 2:
				eligible.append(id)
		var candidates: Array[String] = [eligible[0]]
		if eligible.size() > 1:
			var first: int = rng.randi_range(0, eligible.size() - 1)
			var second: int = rng.randi_range(0, eligible.size() - 2)
			if second >= first:
				second += 1
			candidates = [eligible[first], eligible[second]]
		var selected: String = candidates[0]
		var loser: String = ""
		if candidates.size() == 2:
			var stat: String = ["pitching", "fielding", "power", "contact"][round_number]
			var first_stat: int = SeasonPlayerCatalog.profile(candidates[0]).stats[stat]
			var second_stat: int = SeasonPlayerCatalog.profile(candidates[1]).stats[stat]
			ties += int(first_stat == second_stat)
			var sorted: Array[String] = candidates.duplicate()
			sorted.sort()
			selected = sorted[0] if first_stat == second_stat else candidates[int(second_stat > first_stat)]
			loser = candidates[1] if selected == candidates[0] else candidates[0]
		rosters[team].append(selected)
		remaining.erase(selected)
		turns.append({"candidates": candidates, "selected": selected, "loser": loser,
			"pool_after": remaining.duplicate()})
	return {"order": order, "rosters": rosters, "turns": turns, "ties": ties}

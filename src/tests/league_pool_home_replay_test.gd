extends "res://src/tests/league_separate_home_replay_test.gd"
## Synthetic title funding; real paid Pool entry and frozen JSON transport, no games.
func _ready() -> void:
	var source: SeasonState = SeasonState.create(97361, false, true, true)
	var wins: Array = []
	for repeat in range(6): wins.append({"league": "standard", "tier": 0})
	wins.append_array([{"league": "sponsorship", "tier": 0}, {"league": "sponsorship", "tier": 1}])
	source.career = Fixture.prefix(wins)
	if not check(source.career != null and source.career.start(source), "synthetic Pool eligibility source"):
		get_tree().quit(1)
		return
	for pick in range(4): check(source.choose_player(source.offers()[0]), "source draft")
	var original: Dictionary = Authority.create(SeasonSave.snapshot(source), "pool-league-owner")
	var authority: Dictionary = original.duplicate(true)
	for item: String in ["ST-079", "ST-006"]:
		authority = _command(authority, {"op": "stadium_buy", "item": item, "quantity": 1,
			"price_version": ClubConstruction.copy_catalog(item).price_version})
		if authority.is_empty():
			get_tree().quit(1)
			return
	var paid: ClubAssetLedger = _paid(authority)
	var base: Dictionary = StadiumSurfaceLayout.upgrade(paid.view().stadium_active, paid.surface_owned())
	base.receiver = _copy(paid, "ST-079")
	var layout: Dictionary = StadiumPoolOwnedLayout.upgrade(base, paid.construction(), paid.surface_owned(), "backyard", _copy(paid, "ST-006"))
	authority = _command(authority, {"op": "stadium_draft", "layout": layout})
	if not authority.is_empty():
		authority = _command(authority, {"op": "stadium_apply", "layout": layout, "geometry": StadiumOwnedLayout.geometry("backyard", layout)})
	if authority.is_empty():
		get_tree().quit(1)
		return
	paid = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true)
	check(home.get("version") == 16 and Live.separate_shared_home(home) and StadiumPoolOwnedSnapshot.matches(home, paid), "exact paid Pool16 complete entry")
	for league: String in ["dugout", "doubleheader"]:
		var session: Dictionary = _session(authority, league, 0)
		var staged: Dictionary = Live.prepare(authority, session)
		if not check(not staged.is_empty(), league + " explicit Pool home admission"): continue
		var season: SeasonState = Live.qualify(staged, authority).season
		for pick in range(4): check(season.choose_player(season.offers()[0]), league + " owned draft")
		check(SeasonInventoryRules.enable(season), league + " inventory enabled")
		var saved: Dictionary = Live.capture(season)
		var cold: Dictionary = Live.qualify(JSON.parse_string(JSON.stringify(saved, "", true, true)), authority)
		if not check(not cold.is_empty(), league + " full JSON replay"): continue
		check(ClubCareer.same(Save.snapshot_reference(saved), Save.snapshot_reference(Live.capture(cold.season)))
			and ClubCareer.same(cold.season.home_property, home) and ClubCareer.same(cold.season._pool_replay_ledger.to_data(), paid.to_data()), league + " frozen exact paid journal and reference")
		check(Runtime.paid_ledger(cold.season) == null, league + " staged paid evidence is not selected runtime")
		var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
		var field: Dictionary = StadiumLayoutSnapshot.for_fixture(cold.season, fixture)
		check(field.get("version") == 17 and field.environment.mode == "day" and StadiumPoolOwnedSnapshot.matches(field, paid), league + " exact Pool17 day fixture")
		check(SeasonPhysicalFixtures.match_for(cold.season, cold.season.pending_fixture()) != null, league + " actual pending match reconstructs")
		var bad: Dictionary = saved.duplicate(true)
		bad.home_property.layout.pool.copy = "foreign"
		check(Live.qualify(bad, authority).is_empty(), league + " foreign Pool copy")
		bad = saved.duplicate(true)
		bad.home_property.layout.pool.position[0] += 0.5
		check(Live.qualify(bad, authority).is_empty(), league + " changed paid pose")
		for key: String in ["wall_piece_inventory", "scoreboard_inventory", "surface_access", "boundary"]:
			bad = saved.duplicate(true)
			bad.home_property.erase(key)
			check(Live.qualify(bad, authority).is_empty(), league + " complete " + key)
		var unpaid: Dictionary = Live.prepare(original, _session(original, league, 0))
		unpaid.home_property = home
		check(Live.qualify(unpaid, original).is_empty(), league + " complete shape cannot borrow unpaid grant")
		check(not Live.supported(field, session), league + " fixture cannot impersonate entry")
		bad = home.duplicate(true)
		bad.version = 8
		check(not Live.flat_shared_home(bad) and not Live.separate_shared_home(bad), league + " no flat renumbering")
		var unbound: Dictionary = Live.unbound(saved.checkpoint.duplicate(true), session)
		Save.core(unbound)["home_property"] = home
		check(Save.Owned.decode_setup(unbound) == null, league + " old closed decoder remains unchanged")
		season.owned_surface_night = {"version": 1}
		check(not Live.matches(season), league + " no Night policy")
		# Missing/foreign Pool evidence is rejected before any season write.
		var human: Array = [int(fixture.id), 1, 0, {}, [], [], {}, [], [], {}, {}, [], {}]
		if league == "doubleheader": human.append([{}, {}])
		human.append_array([[], StadiumLayoutSnapshot.key(field)])
		check(not LeagueHomeResult.shape(human, [], league == "doubleheader", true), league + " expected home Pool evidence cannot be omitted")
		human.append({"version": 1})
		check(not LeagueHomeResult.shape(human, [], league == "doubleheader", true), league + " malformed Pool evidence cannot pass")
		var before: Dictionary = Live.capture(cold.season)
		check(not LeagueHomeResult.record(cold.season, human) and ClubCareer.same(Live.capture(cold.season), before), league + " failed Pool record leaves season exact")
	print("LEAGUE_POOL_HOME_REPLAY checks=", checks, " failures=", failures, " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)

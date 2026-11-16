extends "res://src/tests/league_legacy_home_contracts_test.gd"
## Original Yard Night composition, not modern surface Night. No games or reward claims.
var observed_modes: Dictionary = {}
var night_cases: Array[String] = []

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-night-output="):
			output = arg.trim_prefix("--legacy-night-output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var backyard: Dictionary = _legacy_authority()
	if check(not backyard.is_empty(), "original paid four-light owner"):
		var expanded: Dictionary = _command(backyard, {"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION})
		for original: Dictionary in [backyard, expanded]:
			if original.is_empty(): continue
			for row: Array in [[9, "dugout", 0], [10, "doubleheader", 0], [11, "scramble", 4]]:
				_night_replay(original, row[0], row[1], row[2])
	check(night_cases.size() == 6, "three exact legacy light families on both qualified land tiers")
	check(observed_modes.has("day") and observed_modes.has("night"), "unchanged schedules retain natural Day and Night fixtures")
	_write("summary.json", {"checks": checks, "failures": failures, "cases": night_cases,
		"modes": observed_modes.keys(), "paid_commands": commands,
		"physical_games": 0, "synthetic_titles": true,
		"synthetic_strikeout_prerequisites": synthetic_strikeout_prerequisites,
		"authored_strikeouts": 40 if synthetic_strikeout_prerequisites else 0,
		"earned_gameplay_acceptance": false})
	print("LEGACY_NIGHT_CONTRACTS checks=", checks, " failures=", failures, " cases=", night_cases.size(), " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)

func _night_replay(original: Dictionary, version: int, league: String, tier: int) -> void:
	var before: int = failures
	var authority: Dictionary = _apply_legacy(original, version, 4)
	if authority.is_empty(): return
	var ledger: ClubAssetLedger = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	var label: String = "%d-%s-%s-D%d" % [version, home.get("tier"), league, tier]
	if not check(not Live.legacy_shared_home(home) and Live.legacy_night_shared_home(home), label + " separate exact Night-qualified entry"): return
	var saved: Dictionary = Live.prepare(authority, _session(authority, league, tier))
	if not check(not saved.is_empty(), label + " unchanged paid grant admission"): return
	var season: SeasonState = Live.qualify(saved, authority).season
	for pick in range(4): check(season.choose_player(season.offers()[0]), label + " exact draft")
	check(SeasonInventoryRules.enable(season), label + " exact inventory composition")
	saved = Live.capture(season)
	var cold: Dictionary = Live.qualify(JSON.parse_string(JSON.stringify(saved, "", true, true)), authority)
	if not check(not cold.is_empty(), label + " complete JSON cold replay"): return
	check(ClubCareer.same(cold.season.home_property, home)
		and ClubCareer.same(cold.season._pool_replay_ledger.to_data(), ledger.to_data())
		and ClubCareer.same(Save.snapshot_reference(saved), Save.snapshot_reference(Live.capture(cold.season))), label + " frozen ledger and complete reference retained")
	check(cold.season.owned_surface_night.is_empty() and Runtime.paid_ledger(cold.season) == null,
		label + " no modern policy or unsaved runtime authority")
	check(SeasonPhysicalFixtures.match_for(cold.season, cold.season.pending_fixture()) != null,
		label + " actual next match reconstructs without choosing a seed")
	var fixture_count: int = 0
	for fixture: Dictionary in cold.season.schedule:
		if fixture.home != 0 or fixture.get("neutral", false): continue
		fixture_count += 1
		# Future fields are inspected as snapshots only; no future MatchState is
		# reconstructed across a Doubleheader workload boundary.
		var field: Dictionary = StadiumLayoutSnapshot.for_fixture(cold.season, fixture)
		var seed: int = SeasonPhysicalFixtures.seed_for(cold.season, fixture)
		if not check(field.get("version") == (7 if version == 11 else 5)
			and StadiumLayoutSnapshot.matches(field, ledger)
			and ClubCareer.same(field.environment, StadiumFixtureEnvironment.capture(home, seed, int(fixture.id))), label + " exact scheduled fixture"): continue
		observed_modes[field.environment.mode] = true
		check(field.environment.profile == StadiumLightItems.PROFILE
			and not StadiumSurfaceNightHumanEvidence.expected(cold.season, fixture), label + " original Yard profile and human grammar")
		check(not Live.legacy_night_shared_home(field), label + " fixture cannot impersonate entry")
		_environment_negatives(field, label)
		_continuation_key(field, fixture, LeagueRules.doubleheader(season.league_rules), label)
	check(fixture_count > 0, label + " real schedule contains owned homes")
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property.layout.lights.pop_back()
	check(StadiumLayoutSnapshot.valid(bad.home_property) and Live.legacy_shared_home(bad.home_property)
		and not Live.legacy_night_shared_home(bad.home_property)
		and Live.qualify(bad, authority).is_empty(), label + " valid daytime field cannot replace paid Night grant")
	bad = saved.duplicate(true)
	bad.home_property.inventory.copies.erase(home.layout.lights[0].copy)
	check(Live.qualify(bad, authority).is_empty(), label + " exact installed paid light required")
	for wrapper: int in [26, 27, 32, 34, 36]:
		bad = home.duplicate(true)
		bad.version = wrapper
		check(not Live.legacy_night_shared_home(bad), label + " no modern Night or closed-wrapper alias")
	season.owned_surface_night = {"version": 1}
	check(not Live.matches(season) and Live.capture(season).is_empty(), label + " invented modern policy refused")
	_write(label + ".json", {"authority": authority, "snapshot": saved})
	if failures == before: night_cases.append(label)

func _environment_negatives(field: Dictionary, label: String) -> void:
	var bad: Dictionary = field.duplicate(true)
	bad.environment.mode = "day" if field.environment.mode == "night" else "night"
	check(not StadiumLayoutSnapshot.valid(bad), label + " forged mode refused")
	bad = field.duplicate(true)
	bad.environment.profile = ""
	check(not StadiumLayoutSnapshot.valid(bad), label + " missing qualified profile refused even during Day")
	bad = field.duplicate(true)
	bad.environment.fixture += 1
	check(StadiumLayoutSnapshot.valid(bad) and StadiumLayoutSnapshot.key(bad) != StadiumLayoutSnapshot.key(field), label + " another valid fixture has a distinct bound identity")
	bad = field.duplicate(true)
	bad.environment = StadiumFixtureEnvironment.capture(field, int(field.environment.seed) + 1, int(field.environment.fixture))
	check(StadiumLayoutSnapshot.valid(bad) and StadiumLayoutSnapshot.key(bad) != StadiumLayoutSnapshot.key(field), label + " another authentic seed cannot reuse property identity")

func _continuation_key(field: Dictionary, fixture: Dictionary, doubleheader: bool, label: String) -> void:
	# Comparator structure only. This is not a completed game, payout or proof.
	var human: Array = [fixture.id, 1, 0, {}, [], [], {}, [], [], {}, {}, [], {}]
	var result: Dictionary = {"id": fixture.id, "away": fixture.away, "home": fixture.home,
		"away_runs": 1, "home_runs": 0, "property": StadiumLayoutSnapshot.key(field)}
	if doubleheader:
		human.append([{}, {}])
		result.doubleheader_evidence = [{}, {}]
	human.append({"structural_only": true})
	result.inventory_final = {"structural_only": true}
	human.append_array([[], result.property])
	check(LeagueHomeResult.shape(human, [], doubleheader) and Live._human_matches(human, result), label + " original inventory and workload positions plus exact property")
	var changed: Dictionary = result.duplicate(true)
	changed.property = "foreign-environment-key"
	check(not Live._human_matches(human, changed), label + " owner continuation retains complete environment identity")
	changed = result.duplicate(true)
	changed.night_evidence = {}
	check(not Live._human_matches(human, changed), label + " modern Night tail cannot enter legacy result")

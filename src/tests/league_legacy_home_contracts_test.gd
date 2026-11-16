extends "res://src/tests/league_flat_home_replay_test.gd"
## Historical public entries, actual paid commands, synthetic title funding. No games.
const ADAPTERS: Dictionary = {
	1: preload("res://src/gameplay/stadium/stadium_starter_layout.gd"),
	2: preload("res://src/gameplay/stadium/stadium_home_layout.gd"),
	3: preload("res://src/gameplay/stadium/stadium_field_styles.gd"),
	4: preload("res://src/gameplay/stadium/stadium_club_items.gd"),
	5: preload("res://src/gameplay/stadium/stadium_ground_styles.gd"),
	6: preload("res://src/gameplay/stadium/stadium_bleacher_items.gd"),
	7: preload("res://src/gameplay/stadium/stadium_target_items.gd"),
	8: preload("res://src/gameplay/stadium/stadium_net_items.gd"),
	9: preload("res://src/gameplay/stadium/stadium_light_items.gd"),
	10: preload("res://src/gameplay/stadium/stadium_infield_styles.gd"),
	11: preload("res://src/gameplay/stadium/stadium_wall_items.gd")
}
var legacy_cases: Array[String] = []
var synthetic_strikeout_prerequisites: bool = false

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-home-output="):
			output = arg.trim_prefix("--legacy-home-output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var backyard: Dictionary = _legacy_authority()
	if check(not backyard.is_empty(), "funded historical paid authority"):
		var expanded: Dictionary = _command(backyard, {"op": "stadium_land", "tier": "expanded", "price_version": StadiumLand.VERSION})
		for authority: Dictionary in [backyard, expanded]:
			if authority.is_empty(): continue
			for version: int in ADAPTERS:
				_contract(authority, version)
			for version: int in [9, 10, 11]:
				_night_boundary(authority, version)
		for row: Array in [[1, "dugout", 0], [2, "dugout", 0], [8, "dugout", 4], [9, "doubleheader", 0], [10, "scramble", 4], [11, "doubleheader", 0]]:
			_replay(expanded if row[0] in [1, 8, 11] else backyard, backyard, row[0], row[1], row[2])
	check(legacy_cases.size() == 22, "all eleven named legacy families on both entry lands")
	_write("summary.json", {"checks": checks, "failures": failures, "cases": legacy_cases,
		"paid_commands": commands, "physical_games": 0, "synthetic_titles": true,
		"synthetic_strikeout_prerequisites": synthetic_strikeout_prerequisites,
		"authored_strikeouts": 40 if synthetic_strikeout_prerequisites else 0,
		"earned_gameplay_acceptance": false})
	print("LEGACY_HOME_CONTRACTS checks=", checks, " failures=", failures, " cases=", legacy_cases.size(), " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)

func _legacy_authority() -> Dictionary:
	var authority: Dictionary = {}
	var retained: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-retained-input="): retained = arg.trim_prefix("--legacy-retained-input=")
		if arg == "--legacy-synthetic-strikeout-prerequisites": synthetic_strikeout_prerequisites = true
	if synthetic_strikeout_prerequisites:
		if not check(retained.is_empty(), "synthetic prerequisites cannot be combined with retained input"): return {}
		authority = _synthetic_legacy_authority()
	elif retained.is_empty():
		authority = _seed_authority(false, "legacy-contract-owner")
	elif check(retained.is_absolute_path() and FileAccess.file_exists(retained), "retained legacy prerequisite path"):
		authority = _retained_ordinary_authority(FileAccess.get_file_as_string(retained), "legacy-contract-owner")
	if authority.is_empty(): return {}
	for item: String in ["ST-001", "ST-026", "ST-025", "ST-037"]:
		authority = _command(authority, {"op": "stadium_buy", "item": item,
			"quantity": 4 if item == "ST-037" else 1,
			"price_version": ClubConstruction.copy_catalog(item).price_version})
		if authority.is_empty(): return {}
	return authority

func _synthetic_legacy_authority() -> Dictionary:
	var source: SeasonState = SeasonState.create(97311, false, true, true)
	source.career = preload("res://src/tests/league_legacy_synthetic_prerequisites.gd").career()
	if not check(source.career != null, "independent synthetic history validates exactly40 authored strikeouts"): return {}
	if not check(source.career.start(source), "synthetic prerequisite source starts"): return {}
	for pick in range(4):
		if not check(source.choose_player(source.offers()[0]), "synthetic prerequisite draft"): return {}
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "synthetic-legacy-contract-owner")
	check(not authority.is_empty(), "synthetic prerequisite authority validates before actual paid commands")
	return authority

func _retained_ordinary_authority(bytes: String, owner_id: String) -> Dictionary:
	var input: Variant = JSON.parse_string(bytes)
	if not check(input is Dictionary and input.get("authority") is Dictionary, "retained authority exists"): return {}
	var qualified: Dictionary = Authority.normalize(input.authority)
	if not check(not qualified.is_empty() and qualified.origin.career.version == 27, "retained ordinary origin27 independently validates"): return {}
	var club: ClubCareer = ClubCareer.from_data(qualified.origin.career)
	if not check(club != null and club.current == 0
		and ClubPlayers.assets(club).view().stadium_active.version == 1, "original pre-owner legacy source, no metadata removal"): return {}
	var source: SeasonState = SeasonState.create(99801, false, true, true)
	source.career = club
	if not check(club.start(source), "retained source starts ordinary season without altering prerequisites"): return {}
	for pick in range(4):
		if not check(source.choose_player(source.offers()[0]), "source draft"): return {}
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), owner_id)
	check(not authority.is_empty(), "retained ordinary source creates exact authority")
	return authority

func _legacy_layout(ledger: ClubAssetLedger, version: int, lights: int = 1) -> Dictionary:
	var layout: Dictionary = (ledger.view().stadium_active.duplicate(true) if version == 1
		else ADAPTERS[version].upgrade(ledger.view().stadium_active))
	layout.obstacles = [{"copy": _copy(ledger, "ST-001"), "site": "O-R1", "yaw": 0}]
	if version >= 7:
		layout.receiver = ""
		layout.target = _copy(ledger, "ST-026")
	if version >= 8: layout.net = _copy(ledger, "ST-025")
	if version >= 9:
		var copies: Array[String] = []
		for copy: String in ledger.construction().copies:
			if ledger.construction().copies[copy].item == "ST-037": copies.append(copy)
		copies.sort()
		var sites: Array = StadiumYardLightModels.SITES.keys()
		sites.sort()
		layout.lights = []
		for index in range(lights): layout.lights.append({"copy": copies[index], "site": sites[index]})
	return layout

func _apply_legacy(original: Dictionary, version: int, lights: int = 1) -> Dictionary:
	var ledger: ClubAssetLedger = _paid(original)
	var layout: Dictionary = _legacy_layout(ledger, version, lights)
	if not check(StadiumHomeLayout.validate(layout, ledger.construction(), ledger.view().land).ok,
		"original public layout validator " + str(version)): return {}
	var authority: Dictionary = _command(original, {"op": "stadium_draft", "layout": layout})
	if authority.is_empty(): return {}
	check(ClubCareer.same(_paid(authority).view().stadium_active, ledger.view().stadium_active), "draft preserves active " + str(version))
	return _command(authority, {"op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)})

func _contract(original: Dictionary, version: int) -> void:
	var before: int = failures
	var authority: Dictionary = _apply_legacy(original, version)
	if authority.is_empty(): return
	var ledger: ClubAssetLedger = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	var label: String = str(version) + "-" + ledger.view().land
	var entry: int = 6 if version == 11 else (3 if home.get("tier") == "backyard" else 4)
	if not check(home.get("version") == entry and Live.legacy_shared_home(home)
		and StadiumLayoutSnapshot.matches(home, ledger), label + " exact complete historical entry"): return
	check(Live.legacy_shared_home(JSON.parse_string(JSON.stringify(home, "", true, true))), label + " JSON numeric transport")
	check(not Live.flat_shared_home(home) and not Live.separate_shared_home(home), label + " no different contract alias")
	var season: SeasonState = SeasonState.create(97400)
	season.home_property = home.duplicate(true)
	var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var field: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
	var expected: int = 7 if version == 11 else (5 if version in [9, 10] else entry)
	check(field.get("version") == expected and StadiumLayoutSnapshot.matches(field, ledger), label + " exact fixture discriminator")
	if version in [9, 10, 11]:
		check(field.environment.mode == "day" and field.environment.profile == "", label + " unqualified lights retain authentic day environment")
	else:
		check(not field.has("environment") and ClubCareer.same(home, field), label + " unchanged historical environment-free fixture")
	for key: String in ["inventory", "boundary", "geometry", "revision"]:
		var bad: Dictionary = home.duplicate(true)
		bad.erase(key)
		check(not Live.legacy_shared_home(bad), label + " missing " + key)
	var bad: Dictionary = home.duplicate(true)
	bad.layout.family += "-foreign"
	check(not Live.legacy_shared_home(bad), label + " family cannot be replaced by version membership")
	bad = home.duplicate(true)
	bad.layout.obstacles[0].copy = "unpaid"
	check(not Live.legacy_shared_home(bad), label + " unpaid copy refused")
	bad = home.duplicate(true)
	bad.version = 8
	check(not Live.legacy_shared_home(bad), label + " no snapshot8 conversion")
	bad = home.duplicate(true)
	bad.layout.version = 13
	check(not Live.supported(bad, {"league": "dugout", "tier": 0}), label + " closed13 remains closed")
	bad.layout.version = 46
	check(not Live.supported(bad, {"league": "dugout", "tier": 0}), label + " closed46 remains closed")
	check(not Live.supported(home, {"league": "dynasty", "tier": 0})
		and not Live.supported(home, {"league": "dugout", "tier": 5}), label + " separate League and tier gates")
	if before == failures: legacy_cases.append(label)

func _night_boundary(original: Dictionary, version: int) -> void:
	var authority: Dictionary = _apply_legacy(original, version, 4)
	if authority.is_empty(): return
	var ledger: ClubAssetLedger = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	var checked: Dictionary = StadiumHomeLayout.validate(home.layout, ledger.construction(), home.tier)
	if not check(StadiumLayoutSnapshot.valid(home) and checked.get("night_qualified", false), "complete paid legacy Night recipe " + str(version)): return
	check(not Live.legacy_shared_home(home), "day adapter rejects complete Night configuration " + str(version))
	var modes: Dictionary = {}
	var exact: bool = true
	for seed in range(20):
		var environment: Dictionary = StadiumFixtureEnvironment.capture(home, seed, 0)
		modes[environment.mode] = true
		exact = exact and environment.profile == StadiumLightItems.PROFILE
		exact = exact and StadiumFixtureEnvironment.valid(environment, home)
	check(exact and modes.has("day") and modes.has("night"), "Night-qualified layout also has natural day seeds; neither bypasses boundary")

func _replay(original: Dictionary, unpaid: Dictionary, version: int, league: String, tier: int) -> void:
	var authority: Dictionary = _apply_legacy(original, version)
	if authority.is_empty(): return
	var ledger: ClubAssetLedger = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	var label: String = "%d-%s-D%d" % [version, league, tier]
	var saved: Dictionary = Live.prepare(authority, _session(authority, league, tier))
	if not check(not saved.is_empty(), label + " paid entry91"): return
	var season: SeasonState = Live.qualify(saved, authority).season
	for pick in range(4): check(season.choose_player(season.offers()[0]), label + " draft")
	check(SeasonInventoryRules.enable(season), label + " inventory rules")
	saved = Live.capture(season)
	var cold: Dictionary = Live.qualify(JSON.parse_string(JSON.stringify(saved, "", true, true)), authority)
	if not check(not cold.is_empty(), label + " complete cold JSON replay"): return
	check(ClubCareer.same(cold.season.home_property, home)
		and ClubCareer.same(cold.season._pool_replay_ledger.to_data(), ledger.to_data())
		and ClubCareer.same(Save.snapshot_reference(saved), Save.snapshot_reference(Live.capture(cold.season))), label + " exact frozen paid ledger and reference")
	var state: MatchState = SeasonPhysicalFixtures.match_for(cold.season, cold.season.pending_fixture())
	check(state != null and ClubCareer.same(state.league_rules, season.league_rules), label + " actual pending match reconstructs")
	check(Runtime.paid_ledger(cold.season) == null, label + " replay-only claim grants no runtime")
	var prior: Dictionary = Live.prepare(unpaid, _session(unpaid, league, tier))
	if not check(not prior.is_empty(), label + " earlier grant exists"): return
	prior.home_property = home.duplicate(true)
	check(Live.qualify(prior, unpaid).is_empty(), label + " valid home cannot borrow a different paid grant")
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property.layout.obstacles = []
	bad.home_property.boundary = StadiumOwnedLayout.boundary_signature(bad.home_property.layout)
	check(StadiumLayoutSnapshot.valid(bad.home_property) and Live.qualify(bad, authority).is_empty(), label + " valid changed frozen field refused")
	bad = saved.duplicate(true)
	bad.session.owner_id += "-foreign"
	check(Live.qualify(bad, authority).is_empty(), label + " cross-owner refused")
	var raw: Dictionary = Live.unbound(saved.checkpoint.duplicate(true), saved.session)
	Save.core(raw)["home_property"] = home
	check(Save.Owned.decode_setup(raw) == null, label + " historical closed decoder unchanged")
	season.owned_surface_night = {"version": 1}
	check(not Live.matches(season) and Live.capture(season).is_empty(), label + " modern Night policy remains closed")
	_write(label + ".json", {"authority": authority, "snapshot": saved})

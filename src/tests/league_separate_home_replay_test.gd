extends "res://src/tests/league_flat_home_replay_test.gd"
## Separately versioned public fields. Synthetic titles, genuine paid journal, no games.
var cases: Array[String] = []

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--special-home-output="): output = arg.trim_prefix("--special-home-output=")
	if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var legacy: Dictionary = _funded(false)
	var modern: Dictionary = _funded(true)
	if check(not legacy.is_empty() and not modern.is_empty(), "separate-contract authorities"):
		_special(legacy, modern, 14, "dugout", 0, false)
		_special(legacy, modern, 15, "doubleheader", 0, false)
		_special(legacy, modern, 17, "scramble", 4, false)
		_special(legacy, modern, 17, "dugout", 4, true)
		_special(modern, legacy, 47, "doubleheader", 0, false)
	check(cases.size() == 5, "all five complete contract cases")
	_write("summary.json", {"checks": checks, "failures": failures, "cases": cases,
		"paid_commands": commands, "physical_games": 0, "synthetic_titles": true})
	print("SEPARATE_HOME_REPLAY checks=", checks, " failures=", failures, " cases=", cases.size(), " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)

func _funded(modern: bool) -> Dictionary:
	var wins: Array = []
	for repeat in range(32 if modern else 12): wins.append({"league": "standard", "tier": 0})
	for tier in range(3): wins.append({"league": "sponsorship", "tier": tier})
	for league: String in ["dugout", "scramble"]:
		for tier in range(4): wins.append({"league": league, "tier": tier})
	var source: SeasonState = SeasonState.create(97341, false, true, true)
	source.career = Fixture.prefix(wins)
	if source.career == null: return {}
	if modern:
		var paid: ClubAssetLedger = ClubPlayers.assets(source.career)
		source.career._assets = ClubAssetLedger.new_club(paid._seed, paid._credits, paid._progress, paid._championships).to_data()
	if not source.career.start(source): return {}
	for pick in range(4):
		if not source.choose_player(source.offers()[0]): return {}
	return Authority.create(SeasonSave.snapshot(source), "special-modern" if modern else "special-legacy")

func _command(authority: Dictionary, operands: Dictionary) -> Dictionary:
	var command: Dictionary = operands.duplicate(true)
	var ledger: ClubAssetLedger = _paid(authority)
	commands += 1
	command.id = "special-command:" + str(commands)
	command.rev = ledger.revision()
	if command.op not in ["stadium_draft", "stadium_apply"]:
		command.through = ClubPlayers.income_through(Authority._history(authority))
	if command.op in ["stadium_land", "stadium_scoreboard"] or (command.op == "stadium_buy" and ClubConstruction.copy_catalog(command.item).progress):
		command.progress_through = ledger._progress.size()
	var result: Dictionary = Assets.command(authority, command)
	if not check(not result.authority.is_empty() and result.applied.ok, "paid " + command.op + ": " + str(result.applied.get("error", ""))): return {}
	return result.authority

func _special(original: Dictionary, foreign: Dictionary, version: int, league: String, tier: int, prepared: bool) -> void:
	var label: String = "%d-%s-D%d-%s" % [version, league, tier, "prepared" if prepared else "original"]
	var initial_failures: int = failures
	var authority: Dictionary = original.duplicate(true)
	var original_bytes: String = JSON.stringify(original, "", true, true)
	var prior: Dictionary = Live.prepare(original, _session(original, league, tier))
	if version == 47:
		authority = _command(authority, {"op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY, "price_version": 1})
		if authority.is_empty(): return
	if version in [14, 15, 47]:
		for land: String in (["expanded", "club", "mogul"] if version == 47 else ["expanded", "club"]):
			authority = _command(authority, {"op": "stadium_land", "tier": land, "price_version": StadiumLand.VERSION})
			if authority.is_empty(): return
		var item: String = "ST-046" if version == 47 else "ST-090"
		authority = _command(authority, {"op": "stadium_buy" if version == 47 else "stadium_scoreboard",
			"item": item, "quantity": 1, "price_version": ClubConstruction.copy_catalog(item).price_version if version == 47 else StadiumScoreboardPurchases.VERSION})
		if authority.is_empty(): return
	var ledger: ClubAssetLedger = _paid(authority)
	var layout: Dictionary = field_for(ledger, version, prepared)
	if not check(not layout.is_empty() and StadiumOwnedLayout.validate(layout, ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards()).ok,
		label + " exact paid layout valid"): return
	authority = _command(authority, {"op": "stadium_draft", "layout": layout})
	if authority.is_empty(): return
	check(ClubCareer.same(_paid(authority).view().stadium_active, ledger.view().stadium_active), label + " Save does not Apply")
	authority = _command(authority, {"op": "stadium_apply", "layout": layout, "geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)})
	if authority.is_empty(): return
	ledger = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	if not check(Live.separate_shared_home(home) and not Live.flat_shared_home(home) and StadiumLayoutSnapshot.matches(home, ledger), label + " distinct complete paid snapshot"): return
	var saved: Dictionary = Live.prepare(authority, _session(authority, league, tier))
	if not check(not saved.is_empty(), label + " complete League entry"): return
	var season: SeasonState = Live.qualify(saved, authority).season
	for pick in range(4): check(season.choose_player(season.offers()[0]), label + " owned draft")
	check(SeasonInventoryRules.enable(season), label + " inventory composition")
	saved = Live.capture(season)
	var cold: Dictionary = Live.qualify(JSON.parse_string(JSON.stringify(saved, "", true, true)), authority)
	if not check(not cold.is_empty(), label + " JSON complete replay"): return
	check(ClubCareer.same(Save.snapshot_reference(saved), Save.snapshot_reference(Live.capture(cold.season)))
		and ClubCareer.same(cold.season.home_property, home) and ClubCareer.same(cold.season._pool_replay_ledger.to_data(), ledger.to_data()), label + " entire frozen capture ledger and reference")
	var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var state: MatchState = SeasonPhysicalFixtures.match_for(cold.season, cold.season.pending_fixture())
	check(state != null, label + " actual pending match reconstructs")
	var field: Dictionary = StadiumLayoutSnapshot.for_fixture(cold.season, fixture)
	var expected: int = {14: 13, 15: 15, 17: 29, 47: 35}[version]
	check(field.get("version") == expected and StadiumLayoutSnapshot.matches(field, ledger)
		and field.environment.mode == "day" and field.environment.profile == "", label + " exact day fixture " + str(expected))
	check(Runtime.paid_ledger(cold.season) == null, label + " staged claim grants no runtime")
	check(not Live.qualify_bound(prior, prior.session, prior.grant, prior.home_property).is_empty()
		and Live.qualify(prior, authority).is_empty(), label + " old frozen grant remains exact and cannot refresh")
	check(Live.qualify(saved, foreign).is_empty(), label + " foreign owner")
	for key: String in ["session_id", "owner_id", "lineage_id", "access_sha256"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.session[key] += "-foreign"
		check(Live.qualify(bad, authority).is_empty(), label + " changed " + key)
	for key: String in ["inventory", "geometry", "boundary", "surface_access", "revision"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.home_property.erase(key)
		check(Live.qualify(bad, authority).is_empty(), label + " missing " + key)
	for wrong: int in [8, expected, 26, 27, 32, 36]:
		var bad: Dictionary = home.duplicate(true)
		bad.version = wrong
		check(not Live.separate_shared_home(bad), label + " no renumbered or Night entry " + str(wrong))
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property = prior.home_property
	check(Live.qualify(bad, authority).is_empty(), label + " valid changed complete field")
	bad = saved.duplicate(true)
	bad.home_property.layout.family += "-foreign"
	check(Live.qualify(bad, authority).is_empty(), label + " exact named family")
	if version in [14, 15]:
		for key: String in ["scoreboard_inventory", "wall_piece_inventory"]:
			bad = saved.duplicate(true)
			bad.home_property.erase(key)
			check(Live.qualify(bad, authority).is_empty(), label + " complete " + key)
		bad = saved.duplicate(true)
		bad.home_property.layout.scoreboards[0].copy = "unpaid"
		check(Live.qualify(bad, authority).is_empty(), label + " exact purchased board")
		if version == 15:
			bad = saved.duplicate(true)
			bad.home_property.layout.scoreboards[0].mount_profile = "foreign"
			check(Live.qualify(bad, authority).is_empty(), label + " original mount contract")
	elif version == 17:
		bad = saved.duplicate(true)
		bad.home_property.terrain = {}
		check(Live.qualify(bad, authority).is_empty(), label + " terrain recipe mandatory")
		bad = home.duplicate(true)
		bad.layout = StadiumFlagItems.upgrade(layout, ledger.surface_owned())
		check(not Live.separate_shared_home(bad), label + " inherited terrain not implicitly admitted")
	else:
		bad = saved.duplicate(true)
		bad.home_property.layout.animation_base = 46
		check(Live.qualify(bad, authority).is_empty(), label + " closed low-wall base")
		bad = saved.duplicate(true)
		bad.home_property.layout.waterfall_motion = ["foreign"]
		check(Live.qualify(bad, authority).is_empty(), label + " exact installed moving copy")
		bad = home.duplicate(true)
		bad.layout.base_version = 17
		check(not Live.separate_shared_home(bad), label + " flat45 base only")
		check(ClubCareer.same(home.inventory.copies[StadiumStock.SALVAGE_COPY], prior.home_property.inventory.copies[StadiumStock.SALVAGE_COPY]), label + " original salvage copy retained")
	var raw: Dictionary = Live.unbound(saved.checkpoint.duplicate(true), saved.session)
	Save.core(raw)["home_property"] = home
	check(Save.Owned.decode_setup(raw) == null, label + " historical decoder remains closed")
	season.owned_surface_night = {"version": 1}
	check(not Live.matches(season) and Live.capture(season).is_empty(), label + " no Night policy")
	check(JSON.stringify(original, "", true, true) == original_bytes, label + " original authority unchanged")
	_write(label + ".json", {"authority": authority, "snapshot": saved})
	if failures == initial_failures: cases.append(label)
	print("SEPARATE_HOME_CASE ", label, " complete=", failures == initial_failures, " checks=", checks, " failures=", failures)

static func field_for(ledger: ClubAssetLedger, version: int, prepared: bool = false) -> Dictionary:
	var access: Array[String] = ledger.surface_owned()
	var base: Dictionary = StadiumSurfaceLayout.upgrade(ledger.view().stadium_active, access, false)
	if version == 17:
		base.surface.condition = "prepared" if prepared else "rough"
		return StadiumSurfaceLayout.terrain_upgrade(base, access)
	if version in [14, 15]:
		var layout: Dictionary = StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(base))
		var copy: String = ""
		for key: String in ledger.scoreboards().copies:
			if ledger.scoreboards().copies[key].item == "ST-090": copy = key
		layout.scoreboards = [{"copy": copy, "item": "ST-090", "model": "electronic-v2", "site": "BOARD-LEFT-v2"}]
		if version == 15:
			layout = StadiumMountedScoreboardLayout.upgrade(layout, ledger.construction(), ledger.wall_pieces(), access, ledger.view().land, ledger.scoreboards())
			if layout.is_empty(): return {}
			layout.scoreboards = [{"copy": copy, "item": "ST-090", "model": "electronic-v2", "site": StadiumScoreboardMountCatalog.CENTER_SITE, "mount_profile": StadiumScoreboardMountCatalog.CENTER_PROFILE}]
		return layout
	var copy: String = ""
	for key: String in ledger.construction().copies:
		if ledger.construction().copies[key].item == "ST-046": copy = key
	var live: Dictionary = StadiumWaterfallItems.place(ledger.view().stadium_active, ledger.construction(), copy, "LANDMARK-A", 0.0, access) if prepared else StadiumWaterfallLiveItems.place(ledger.view().stadium_active, ledger.construction(), copy, StadiumWaterfallLiveSites.SITE, 0.0, access)
	return StadiumWaterfallAnimationLayout.select(live, copy, true, access)

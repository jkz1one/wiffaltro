extends "res://src/tests/league_home_modern_tiers_test.gd"
## Representative flat compositions. Synthetic title income, actual paid journal commands.
const Assets = preload("res://src/gameplay/season/dynasty_stadium_assets.gd")
const Flat = preload("res://src/tests/league_flat_home_fixture.gd")
var commands: int = 0
var exercised: Array[String] = []

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flat-replay-output="):
			output = arg.trim_prefix("--flat-replay-output=")
	if not output.is_empty():
		if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(output)
	var modern: Dictionary = _seed_authority(true, "flat-modern-owner")
	var legacy: Dictionary = _seed_authority(false, "flat-legacy-owner")
	if check(not modern.is_empty() and not legacy.is_empty(), "synthetic earned authorities validate"):
		_case(legacy, modern, "surface12-dugout-base", "dugout", 0, 12, "obstacle")
		_case(modern, legacy, "paid-display-dugout-d4", "dugout", 4, 40, "display")
		_case(modern, legacy, "paid-stands-doubleheader", "doubleheader", 0, 41, "stands")
		_case(modern, legacy, "inherited45-scramble-d4", "scramble", 4, 45, "stands")
	check(exercised.size() == 4, "four independent exact flat League compositions finish")
	_write("summary.json", {"checks": checks, "failures": failures, "cases": exercised,
		"paid_commands": commands, "physical_games": 0, "owner_writes": 0, "synthetic_titles": true})
	print("FLAT_HOME_REPLAY checks=", checks, " failures=", failures, " cases=", exercised.size(), " physical_games=0")
	get_tree().quit(0 if failures == 0 else 1)

func _seed_authority(modern: bool, owner_id: String) -> Dictionary:
	var wins: Array = []
	for repeat in range(12): wins.append({"league": "standard", "tier": 0})
	for tier in range(3): wins.append({"league": "sponsorship", "tier": tier})
	for tier in range(4): wins.append({"league": "dugout", "tier": tier})
	for tier in range(4): wins.append({"league": "scramble", "tier": tier})
	var source: SeasonState = SeasonState.create(97311, false, true, true)
	source.career = Fixture.prefix(wins)
	if not check(source.career != null, owner_id + " prefix"): return {}
	var ledger: ClubAssetLedger = ClubPlayers.assets(source.career)
	if modern:
		source.career._assets = ClubAssetLedger.new_club(ledger._seed, ledger._credits, ledger._progress, ledger._championships).to_data()
	if not check(source.career.start(source), owner_id + " start"): return {}
	for pick in range(4):
		if not check(source.choose_player(source.offers()[0]), owner_id + " draft"): return {}
	var result: Dictionary = Authority.create(SeasonSave.snapshot(source), owner_id)
	check(not result.is_empty(), owner_id + " authority")
	return result

func _session(authority: Dictionary, league: String, tier: int) -> Dictionary:
	var context: Dictionary = super._session(authority, league, tier)
	context.owner_id = authority.owner_id
	return context

func _paid(authority: Dictionary) -> ClubAssetLedger:
	return ClubPlayers.assets(Authority._history(authority))

func _command(authority: Dictionary, operands: Dictionary) -> Dictionary:
	var command: Dictionary = operands.duplicate(true)
	var ledger: ClubAssetLedger = _paid(authority)
	commands += 1
	command.id = "flat-command:" + str(commands)
	command.rev = ledger.revision()
	if command.op in ["stadium_buy", "stadium_land", "stadium_salvage_clear"]:
		command.through = ClubPlayers.income_through(Authority._history(authority))
	if command.op == "stadium_land" or (command.op == "stadium_buy" and ClubConstruction.copy_catalog(command.item).progress):
		command.progress_through = ledger._progress.size()
	var result: Dictionary = Assets.command(authority, command)
	if not check(not result.authority.is_empty() and result.applied.ok,
		"actual shared journal " + command.op + ": " + str(result.applied.get("error", ""))): return {}
	return result.authority

func _copy(ledger: ClubAssetLedger, item: String) -> String:
	for copy: String in ledger.construction().copies:
		if copy.begins_with("purchase:") and ledger.construction().copies[copy].item == item: return copy
	return ""

func _case(original: Dictionary, foreign: Dictionary, label: String, league: String, tier: int, version: int, feature: String) -> void:
	var before: int = failures
	var authority: Dictionary = original.duplicate(true)
	var original_bytes: String = JSON.stringify(original, "", true, true)
	var initial: ClubAssetLedger = _paid(original)
	var initial_balance: int = initial.balance()
	var admitted: Dictionary = Live.prepare(original, _session(original, league, tier)) if Live.flat_shared_home(StadiumLayoutSnapshot.capture(initial, true)) else {}
	if not initial.view().get("salvage_origin", {}).is_empty():
		authority = _command(authority, {"op": "stadium_salvage_clear", "copy": StadiumStock.SALVAGE_COPY, "price_version": 1})
		if authority.is_empty(): return
	if feature != "obstacle":
		for land: String in ["expanded", "club"]:
			authority = _command(authority, {"op": "stadium_land", "tier": land, "price_version": StadiumLand.VERSION})
			if authority.is_empty(): return
	var items: Array = ["ST-001"] if feature == "obstacle" else (["ST-039", "ST-069"] if feature == "display" else ["ST-029"])
	for item: String in items:
		authority = _command(authority, {"op": "stadium_buy", "item": item, "quantity": 1,
			"price_version": ClubConstruction.copy_catalog(item).price_version})
		if authority.is_empty(): return
	if feature == "banner":
		var awards: Dictionary = _paid(authority)._championships
		var key: String = StadiumPennantRewards.mastery_key()
		if not check(awards.has(key), label + " exact earned D4 banner authority"): return
		if not check(_paid(authority).construction().copies.has(key), label + " prospective reward already delivered by career"): return
	var ledger: ClubAssetLedger = _paid(authority)
	var layout: Dictionary = Flat.ADAPTERS[version].upgrade(ledger.view().stadium_active, ledger.surface_owned())
	if feature == "obstacle":
		layout.obstacles = [{"copy": _copy(ledger, "ST-001"), "site": "O-R1", "yaw": 0}]
	elif feature == "display":
		layout.displays = [{"copy": _copy(ledger, "ST-039"), "site": "SCORE-SMALL"}]
		var candidates: Array = StadiumMountedDisplayItems.candidates(layout, ledger.construction(), "ST-069")
		if not check(not candidates.is_empty(), label + " actual named paid host socket"): return
		layout = StadiumMountedDisplayItems.place(layout, ledger.construction(), _copy(ledger, "ST-069"),
			candidates[0].host, candidates[0].socket, ledger.surface_owned())
	else:
		layout = StadiumStraightItemsUI.select(layout, ledger.construction(), _copy(ledger, "ST-029"),
			{"site": "BASE-L1", "lower": "", "concourse": ""})
		if feature == "banner":
			layout = StadiumMasteryBannerItems.place(layout, ledger.construction(), StadiumPennantRewards.mastery_key(), _copy(ledger, "ST-029"))
	var validated: Dictionary = StadiumOwnedLayout.validate(layout, ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards())
	if not check(validated.ok, label + " complete paid layout validates before draft: " + str(validated.get("error", ""))): return
	authority = _command(authority, {"op": "stadium_draft", "layout": layout})
	if authority.is_empty(): return
	check(ClubCareer.same(_paid(authority).view().stadium_active, ledger.view().stadium_active), label + " draft cannot refresh active field")
	authority = _command(authority, {"op": "stadium_apply", "layout": layout, "geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)})
	if authority.is_empty(): return
	ledger = _paid(authority)
	var home: Dictionary = StadiumLayoutSnapshot.capture(ledger, true)
	if not check(Live.flat_shared_home(home) and home.layout.version == version and StadiumLayoutSnapshot.matches(home, ledger), label + " applied complete family admission"): return
	check(ledger.balance() < initial_balance and ClubCareer.same(home.inventory, ledger.construction().to_data()), label + " full paid stock and real debit retained")
	var session: Dictionary = _session(authority, league, tier)
	var staged: Dictionary = Live.prepare(authority, session)
	if not check(not staged.is_empty(), label + " exact League/tier admission"): return
	var season: SeasonState = Live.qualify(staged, authority).season
	for pick in range(4): check(season.choose_player(season.offers()[0]), label + " owned draft")
	check(SeasonInventoryRules.enable(season), label + " exact inventory grammar")
	var saved: Dictionary = Live.capture(season)
	var cold: Dictionary = Live.qualify(JSON.parse_string(JSON.stringify(saved, "", true, true)), authority)
	if not check(not cold.is_empty(), label + " full JSON save replay"): return
	check(ClubCareer.same(Save.snapshot_reference(saved), Save.snapshot_reference(Live.capture(cold.season)))
		and ClubCareer.same(cold.season.home_property, home) and ClubCareer.same(cold.season._pool_replay_ledger.to_data(), ledger.to_data()),
		label + " exact session draft inventory home grant ledger reference")
	var next: MatchState = SeasonPhysicalFixtures.match_for(cold.season, cold.season.pending_fixture())
	check(next != null and ClubCareer.same(next.league_rules, season.league_rules), label + " natural next League match reconstructs")
	var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var field: Dictionary = StadiumLayoutSnapshot.for_fixture(cold.season, fixture)
	check(field.version == 9 and field.environment.mode == "day" and StadiumLayoutSnapshot.matches(field, ledger), label + " complete day fixture9")
	check(Runtime.paid_ledger(cold.season) == null, label + " staged paid claim never grants live runtime")
	_negatives(saved, authority, foreign, original, label, feature)
	if not admitted.is_empty():
		check(not Live.qualify_bound(admitted, admitted.session, admitted.grant, admitted.home_property).is_empty()
			and Live.qualify(admitted, authority).is_empty(), label + " existing frozen grant survives; current authority cannot refresh it")
	check(JSON.stringify(original, "", true, true) == original_bytes, label + " source authority unchanged")
	_write(label + ".json", saved)
	if before == failures: exercised.append(label)
	print("FLAT_REPLAY_CASE ", label, " complete=", before == failures, " checks=", checks, " failures=", failures)

func _negatives(saved: Dictionary, authority: Dictionary, foreign: Dictionary, unpaid: Dictionary, label: String, feature: String) -> void:
	check(Live.qualify(saved, foreign).is_empty(), label + " cross-owner authority refused")
	var old: Dictionary = Live.prepare(unpaid, _session(unpaid, saved.session.league, saved.session.tier))
	if not old.is_empty():
		old.home_property = saved.home_property.duplicate(true)
		check(Live.qualify(old, unpaid).is_empty(), label + " valid paid field cannot borrow unpaid grant")
	for field: String in ["session_id", "owner_id", "lineage_id", "access_sha256"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.session[field] += "-foreign"
		check(Live.qualify(bad, authority).is_empty(), label + " substituted " + field)
	for field: String in ["inventory", "geometry", "boundary", "surface_access", "revision"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.home_property.erase(field)
		check(Live.qualify(bad, authority).is_empty(), label + " missing complete " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property.layout.family += "-foreign"
	check(Live.qualify(bad, authority).is_empty(), label + " forged family identity")
	bad = saved.duplicate(true)
	bad.home_property.layout["base_version"] = 17
	check(Live.qualify(bad, authority).is_empty(), label + " terrain base cannot enter flat grammar")
	bad = saved.duplicate(true)
	bad.home_property = StadiumLayoutSnapshot.capture(_paid(unpaid), true)
	check(StadiumLayoutSnapshot.valid(bad.home_property) and Live.qualify(bad, authority).is_empty(), label + " complete valid changed frozen field refused")
	bad = saved.duplicate(true)
	bad.checkpoint.checkpoint.version = 83 if saved.session.tier > 0 else 85
	check(Live.qualify(bad, authority).is_empty(), label + " wrong exact binding grammar")
	bad = saved.duplicate(true)
	bad.checkpoint.player_access.reverse()
	check(Live.qualify(bad, authority).is_empty(), label + " changed owned draft pool")
	for version: int in [28, 29, 46, 47, 51]:
		bad = saved.duplicate(true)
		bad.home_property.version = version
		check(Live.qualify(bad, authority).is_empty(), label + " different snapshot contract " + str(version))
	if feature == "display":
		bad = saved.duplicate(true)
		bad.home_property.layout.mounted_displays[0].host = "foreign-host"
		check(Live.qualify(bad, authority).is_empty(), label + " foreign display host refused")
		bad = saved.duplicate(true)
		bad.home_property.layout.mounted_displays[0].socket = "foreign-socket"
		check(Live.qualify(bad, authority).is_empty(), label + " foreign display socket refused")
	if feature == "banner":
		bad = saved.duplicate(true)
		bad.home_property.inventory.copies[StadiumPennantRewards.mastery_key()].earned.season_id = 999
		check(Live.qualify(bad, authority).is_empty(), label + " forged earned banner provenance refused")
	var changed: SeasonState = Live.qualify(saved, authority).season
	changed.owned_surface_night = {"version": 1}
	check(not Live.matches(changed) and Live.capture(changed).is_empty(), label + " Night policy remains closed")
	var raw: Dictionary = Live.unbound(saved.checkpoint.duplicate(true), saved.session)
	Save.core(raw)["home_property"] = saved.home_property.duplicate(true)
	check(Save.Owned.decode_setup(raw) == null, label + " historical closed decoder remains closed")

extends Node
## Exact synthetic title prefixes qualify each scope independently. No games or owner writes.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Runtime = preload("res://src/gameplay/season/dynasty_league_home_runtime.gd")
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
var checks: int = 0
var failures: int = 0
var completed: Array[String] = []
var output: String = ""


func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	return ok


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--modern-tier-output="):
			output = arg.trim_prefix("--modern-tier-output=")
	if not output.is_empty():
		if not output.is_absolute_path() or DirAccess.dir_exists_absolute(output):
			push_error("Modern tier evidence output must be fresh and absolute")
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(output)
	for league: String in Live.BASE_LEAGUES:
		for tier in range(5):
			_run(league, tier)
		_foreign_titles(league)
	check(completed.size() == 35, "all 35 exact modern League/tier cases complete")
	_write("summary.json", {"checks": checks, "failures": failures, "completed": completed,
		"physical_games": 0, "owner_writes": 0, "synthetic_titles": true})
	print("MODERN_TIER_MATRIX: %d checks, %d failures, cases=%d, physical_games=0" % [checks, failures, completed.size()])
	get_tree().quit(0 if failures == 0 else 1)


func _prerequisites(league: String) -> Array:
	match league:
		"sponsorship": return [{"league": "standard", "tier": 0}]
		"academy": return [{"league": "standard", "tier": 0}, {"league": "sponsorship", "tier": 0}]
		"equipment": return [{"league": "dugout", "tier": 0}]
		"earnings": return [{"league": "dugout", "tier": 0}, {"league": "equipment", "tier": 0}]
		"doubleheader", "scramble":
			var rows: Array = [{"league": "standard", "tier": 0}]
			for tier in range(2 if league == "doubleheader" else 3):
				rows.append({"league": "sponsorship", "tier": tier})
			return rows
	return []


func _authority(wins: Array) -> Dictionary:
	var source: SeasonState = SeasonState.create(97301, false, true, true)
	source.career = Fixture.prefix(wins)
	if source.career == null:
		return {}
	var paid: ClubAssetLedger = ClubPlayers.assets(source.career)
	source.career._assets = ClubAssetLedger.new_club(paid._seed, paid._credits,
		paid._progress, paid._championships).to_data()
	if not source.career.start(source):
		return {}
	if wins.is_empty():
		# The first career start initializes its seed/ledger. Apply the production
		# new-club origin after that initialization, as the ordinary new-club flow does.
		paid = ClubPlayers.assets(source.career)
		source.career._assets = ClubAssetLedger.new_club(paid._seed, paid._credits,
			paid._progress, paid._championships).to_data()
	for pick in range(4):
		if not source.choose_player(source.offers()[0]):
			return {}
	return Authority.create(SeasonSave.snapshot(source), "modern-tier-owner")


func _session(authority: Dictionary, league: String, tier: int) -> Dictionary:
	return Save.binding({"owner_id": "modern-tier-owner", "lineage_id": "modern-tier-lineage",
		"generation": 0, "ordinal": 1, "session_id": "modern-%s-%d" % [league, tier],
		"seed": 97400 + Live.BASE_LEAGUES.find(league) * 10 + tier,
		"tier": tier, "league": league,
		"access_sha256": ClosedContentAccess.digest(Authority.access(authority))})


func _expected_home(home: Dictionary) -> bool:
	return Live.modern_origin(home)


func _run(league: String, tier: int) -> void:
	var label: String = "%s-D%d" % [league, tier]
	var before_failures: int = failures
	var wins: Array = _prerequisites(league)
	for preceding in range(tier):
		wins.append({"league": league, "tier": preceding})
	var authority: Dictionary = _authority(wins)
	if not check(not authority.is_empty(), label + " exact-prefix authority"):
		return
	var original: Dictionary = authority.duplicate(true)
	check(Authority.available_tiers(authority, league) == range(tier + 1),
		label + " own prior titles grant exactly this tier frontier")
	var session: Dictionary = _session(authority, league, tier)
	var prepared: Dictionary = Live.prepare(authority, session)
	if not check(not prepared.is_empty(), label + " qualified modern home proposal"):
		return
	var home: Dictionary = prepared.home_property.duplicate(true)
	check(_expected_home(home) and home.version == 8 and home.layout.version == 40
		and home.layout.base_version == 12, label + " complete exact flat origin")
	var live: SeasonState = Live.qualify(prepared, authority).get("season")
	if not check(live != null, label + " qualified replay"):
		return
	check(live.career == null and live.npc_venues.is_empty() and live.final_venue.is_empty()
		and live.owned_surface_night.is_empty(), label + " no second wallet or borrowed venue policy")
	check(ClubCareer.same(live.league_rules, LeagueRules.capture_tier(league, tier,
		session.seed if league == "scramble" else null)), label + " exact selected League tier rules")
	for pick in range(4):
		check(live.choose_player(live.offers()[0]), label + " normal owned draft")
	check(SeasonInventoryRules.enable(live), label + " owned inventory enabled")
	var saved: Dictionary = Live.capture(live)
	if not check(not saved.is_empty(), label + " exact composed capture"):
		return
	check(saved.checkpoint.version == 87
		and saved.checkpoint.checkpoint.version == (85 if tier > 0 else 83)
		and saved.checkpoint.checkpoint.checkpoint.version == (84 if tier > 0 else 80)
		and saved.checkpoint.checkpoint.checkpoint.checkpoint.version == (86 if tier > 0 else (77 if league == "doubleheader" else 76)),
		label + " exact 91/87/binding/access/closed discriminators")
	var cold: Dictionary = JSON.parse_string(JSON.stringify(saved, "", true, true))
	var checked: Dictionary = Live.qualify(cold, authority)
	if not check(not checked.is_empty(), label + " full JSON replay"):
		return
	var restored: SeasonState = checked.season
	check(ClubCareer.same(Save.snapshot_reference(saved), Save.snapshot_reference(Live.capture(restored)))
		and restored.picks == live.picks and restored.player_access == live.player_access,
		label + " full reference draft and session identity survives JSON")
	check(ClubCareer.same(restored.home_property, home)
		and ClubCareer.same(restored._pool_replay_ledger.to_data(), live._pool_replay_ledger.to_data())
		and ClubCareer.same(restored._league_home_context.grant, saved.grant),
		label + " exact frozen home grant and paid ledger")
	check(Runtime.paid_ledger(restored) == null, label + " staged context has no selected-owner authority")
	var next: MatchState = SeasonPhysicalFixtures.match_for(restored, restored.pending_fixture())
	check(next != null and ClubCareer.same(next.league_rules, live.league_rules),
		label + " actual next match retains selected tier")
	var fixture: Dictionary = restored.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var home_fixture: Dictionary = StadiumLayoutSnapshot.for_fixture(restored, fixture)
	check(home_fixture.get("version") == 9 and StadiumLayoutSnapshot.valid(home_fixture)
		and home_fixture.environment.mode == "day", label + " full day fixture9 remains bound")
	_negative(saved, authority, label)
	if tier < 4:
		check(Live.prepare(authority, _session(authority, league, tier + 1)).is_empty(),
			label + " next unearned same-League tier refused")
	check(ClubCareer.same(authority, original), label + " all replay leaves authority unchanged")
	_write(label + ".json", saved)
	if failures == before_failures:
		completed.append(label)
	print("MODERN_TIER_CASE ", label, " completed=", failures == before_failures, " checks=", checks, " failures=", failures)


func _negative(saved: Dictionary, authority: Dictionary, label: String) -> void:
	var tier: int = int(saved.session.tier)
	for field: String in ["session_id", "owner_id", "lineage_id", "access_sha256"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.session[field] += "-changed"
		check(Live.qualify(bad, authority).is_empty(), label + " rejects substituted " + field)
	for field: String in ["tier", "seed"]:
		var bad: Dictionary = saved.duplicate(true)
		bad.session[field] = (tier + 1) % 5 if field == "tier" else bad.session.seed + 1
		check(Live.qualify(bad, authority).is_empty(), label + " rejects substituted " + field)
	var bad: Dictionary = saved.duplicate(true)
	bad.session.league = "sponsorship" if saved.session.league != "sponsorship" else "dugout"
	check(Live.qualify(bad, authority).is_empty(), label + " rejects other League session")
	bad = saved.duplicate(true)
	bad.checkpoint.checkpoint.version = 83 if tier > 0 else 85
	check(Live.qualify(bad, authority).is_empty(), label + " refuses wrong binding grammar")
	bad = saved.duplicate(true)
	bad.checkpoint.checkpoint.checkpoint.version = 80 if tier > 0 else 84
	check(Live.qualify(bad, authority).is_empty(), label + " refuses wrong access grammar")
	for wrong: int in ([75, 76, 77] if tier > 0 else [75, 86]):
		bad = saved.duplicate(true)
		bad.checkpoint.checkpoint.checkpoint.checkpoint.version = wrong
		check(Live.qualify(bad, authority).is_empty(), label + " refuses wrong closed grammar " + str(wrong))
	bad = saved.duplicate(true)
	bad.checkpoint.checkpoint.checkpoint.checkpoint.league_rules = LeagueRules.capture_tier(
		saved.session.league, (tier + 1) % 5, saved.session.seed if saved.session.league == "scramble" else null)
	check(Live.qualify(bad, authority).is_empty(), label + " refuses transplanted tier rules")
	bad = saved.duplicate(true)
	bad.checkpoint.checkpoint.checkpoint.inventory_rules.version += 1
	check(Live.qualify(bad, authority).is_empty(), label + " refuses altered inventory grammar")
	bad = saved.duplicate(true)
	bad.checkpoint.player_access.reverse()
	check(Live.qualify(bad, authority).is_empty(), label + " refuses changed frozen player access")
	bad = saved.duplicate(true)
	bad.home_property.layout.salvage_cars = [] if not saved.home_property.layout.salvage_cars.is_empty() else [{"copy": StadiumStock.SALVAGE_COPY, "site": StadiumSalvageCarItems.SITE}]
	check(Live.qualify(bad, authority).is_empty(), label + " refuses replaced frozen salvage placement")
	for version: int in [28, 29]:
		bad = saved.duplicate(true)
		bad.home_property.version = version
		check(Live.qualify(bad, authority).is_empty(), label + " refuses terrain grammar")
	bad = saved.duplicate(true)
	bad.home_property.layout.version = 41
	check(Live.qualify(bad, authority).is_empty(), label + " refuses later family")
	var live: SeasonState = Live.qualify(saved, authority).season
	live.owned_surface_night = {"version": 1}
	check(not Live.matches(live) and Live.capture(live).is_empty(), label + " refuses Night policy")
	live = Live.qualify(saved, authority).season
	live._dynasty_career_session.session_id += "-changed"
	check(not Live.matches(live) and Live.capture(live).is_empty(), label + " refuses mutated live session")
	var raw: Dictionary = Live.unbound(saved.checkpoint.duplicate(true), saved.session)
	Save.core(raw)["home_property"] = saved.home_property.duplicate(true)
	check(Save.Owned.decode_setup(raw) == null, label + " old closed decoder still refuses venue data")


func _foreign_titles(league: String) -> void:
	var wins: Array = _prerequisites(league)
	var foreign: String = "dugout" if league == "sponsorship" else "sponsorship"
	if foreign == "sponsorship" and {"league": "standard", "tier": 0} not in wins:
		wins.push_front({"league": "standard", "tier": 0})
	for tier in range(4):
		var row: Dictionary = {"league": foreign, "tier": tier}
		if row not in wins:
			wins.append(row)
	var authority: Dictionary = _authority(wins)
	if not check(not authority.is_empty(), league + " foreign-title authority"):
		return
	check(Authority.available_tiers(authority, league) == [0], league + " foreign titles grant no higher tier")
	for tier in range(1, 5):
		check(Live.prepare(authority, _session(authority, league, tier)).is_empty(),
			league + " foreign title cannot admit D" + str(tier))


func _write(name: String, value: Dictionary) -> void:
	if output.is_empty():
		return
	var file: FileAccess = FileAccess.open(output.path_join(name), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(value, "", true, true))

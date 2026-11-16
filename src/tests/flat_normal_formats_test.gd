extends Node
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("NORMAL_HOME_FORMAT ", ok, " ", label)
	return ok
func _ready() -> void:
	for item: Dictionary in [{"league": "dugout", "tier": 1}, {"league": "doubleheader", "tier": 0}, {"league": "scramble", "tier": 2}]:
		_case(item)
	print("FLAT_NORMAL_FORMAT_RESULT %d checks, %d failures; synthetic_titles=true; physical_games=0" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _case(item: Dictionary) -> void:
	var club: ClubCareer = Fixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1}, {"league": "dugout", "tier": 2},
		{"league": "scramble", "tier": 0}, {"league": "scramble", "tier": 1}])
	var prior: ClubAssetLedger = ClubPlayers.assets(club)
	club._assets = ClubAssetLedger.new_club(prior._seed, prior._credits, prior._progress, prior._championships).to_data()
	if not check(preload("res://src/tests/flat_route_fixture.gd").apply(club), "real paid flat45 journal fixture"): return
	var seed_value: int = 99300 + int(item.tier)
	var rules: Dictionary = LeagueRules.capture_tier(item.league, item.tier, seed_value if item.league == "scramble" else null)
	var season: SeasonState = SeasonState.create_closed_league(seed_value, rules, true)
	if not check(ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) and club.start_league(season), "own prerequisites start " + item.league): return
	if not check(preload("res://src/gameplay/season/normal_league_home.gd").prepare(season), "normal owned-home flat45 admission"): return
	for pick in range(4): season.choose_player(season.offers()[0])
	check(SeasonInventoryRules.enable(season), "explicit inventory admission")
	var saved: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave._decode(JSON.parse_string(JSON.stringify(saved, "", true, true)))
	if not check(cold != null, "exact cold " + item.league + " tier" + str(item.tier)): return
	check(ClubCareer.same(cold.league_rules, rules) and cold.picks == season.picks
		and ClubCareer.same(cold.inventory_rules, season.inventory_rules) and cold.home_property.layout.version == 45, "rules roster inventory retained")
	var closed: Dictionary = SeasonSave.OwnedDraftSave.closed(saved.checkpoint.checkpoint)
	check(closed.version == (82 if item.tier > 0 else 77), "exact ordinary tier/Doubleheader grammar")
	check(SeasonSave._decode(saved.checkpoint) == null, "historical decoder refuses home marker")
	var bad: Dictionary = saved.duplicate(true)
	SeasonSave.OwnedDraftSave.closed(bad.checkpoint.checkpoint).version = 86
	check(SeasonSave._decode(bad) == null, "owner-tier86 cannot replace ordinary grammar")
	bad = saved.duplicate(true)
	SeasonSave.OwnedDraftSave.closed(bad.checkpoint.checkpoint).league_rules.tier = 0 if item.tier > 0 else 1
	check(SeasonSave._decode(bad) == null, "changed exact tier refused")
	if item.league == "doubleheader":
		var home: Dictionary = cold.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
		check(SeasonPhysicalFixtures.match_for(cold, home) == null, "second leg cannot precede genuine first-leg workload")
	if item.league == "scramble":
		bad = saved.duplicate(true)
		SeasonSave.OwnedDraftSave.closed(bad.checkpoint.checkpoint).checkpoint.seed += 1
		check(SeasonSave._decode(bad) == null, "Scramble rules remain seed-bound")

extends "res://src/tests/league_career_test.gd"
## Structural title prefixes only, never earned promotion or physical-game evidence.
## Exercises actual candidate start, fourth-pick allocation and save replay APIs.


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--league-tier-test-root="):
			root = argument.trim_prefix("--league-tier-test-root=")
	if (
		not root.is_absolute_path() or root.length() < 2
		or root != root.simplify_path() or DirAccess.dir_exists_absolute(root)
	):
		push_error("A fresh absolute --league-tier-test-root= is required; no test ran.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	for id: String in ClubLeagueCareer.IDS:
		for tier in range(1, 5):
			_tier_roundtrip(id, tier)
	_unlock_boundaries()
	_standard_mastery_after_league()
	print("League tier career checks: %d, failures: %d, synthetic_history=true, physical_games=0"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _prefix(id: String, through: int) -> ClubCareer:
	# Explicit compact-history operands include the now-required public League gate.
	var initial: ClubCareer = UnlockFixture.for_league(id)
	if initial == null:
		return null
	var wins: Array = []
	for row: Dictionary in initial.runs:
		wins.append({"league": row.league, "tier": row.tier})
	for tier in range(through + 1):
		wins.append({"league": id, "tier": tier})
	return UnlockFixture.prefix(wins)


func _tier_roundtrip(id: String, tier: int) -> void:
	var prefix: ClubCareer = _prefix(id, tier - 1)
	check(prefix != null, "validated synthetic title prefix " + id + str(tier))
	if prefix == null:
		return
	check(tier in prefix.available_tiers(id), "preceding own-League title unlocks tier")
	var rules: Dictionary = LeagueRules.capture_tier(id, tier, 8107 if id == "scramble" else null)
	check(rules.version == 3 and LeagueRules.normalized(rules) == rules, "strict composed rules")
	check(LeagueRules.capture(id, tier).is_empty(), "old Base capture does not change")
	var season: SeasonState = SeasonState.create_closed_league(8107, rules, true)
	check(season != null and prefix.start_league(season), "start exact selected tier")
	if season == null or season.career == null:
		return
	check(season.career.active_tier() == tier and season.build._format == 46,
		"career and build retain composed tier")
	var initial: Dictionary = SeasonSave.snapshot(season)
	check(initial.get("version") == 81 and initial.checkpoint.get("version") == 82,
		"new tier checkpoint requires career envelope")
	var restored: SeasonState = SeasonSave._decode(initial)
	check(restored != null, "initial tier snapshot decodes before any picks")
	if restored == null:
		return
	check(ClubCareer.same(SeasonSave.snapshot(restored), initial), "exact initial tier roundtrip")
	for pick in range(4):
		check(restored.choose_player(restored.offers()[0]), "real tier draft pick")
	check(restored.opponents.clubs.size() == 5, "fourth pick creates five composed AI clubs")
	for club: Dictionary in restored.opponents.clubs.values():
		check(club.build._format == 46 and club.build._league_rules == rules
			and club.build._bank._term_seed == club.build._seed,
			"AI inherits same tier with its own sponsor-marking seed")
	if id == "scramble" and tier == 2:
		_scramble_allocation(restored)
	check(SeasonInventoryRules.enable(restored), "tier inventory enabled")
	var ready: Dictionary = SeasonSave.snapshot(restored)
	check(not SeasonRoundSettlement._physical_payload(ready).is_empty(),
		"round projection locates actual Save81 inventory82 physical payload")
	var loaded: SeasonState = SeasonSave._decode(ready)
	check(loaded != null, "fourth-pick inventory snapshot decodes")
	if loaded == null:
		return
	check(ClubCareer.same(SeasonSave.snapshot(loaded), ready), "exact ready tier roundtrip")
	check(SeasonSave._decode(ready.checkpoint) == null, "raw tier envelope cannot bypass career")
	var bad: Dictionary = ready.duplicate(true)
	bad.career.runs[-1].tier = 0
	check(SeasonSave._decode(bad) == null, "row cannot disagree with captured tier")
	bad = ready.duplicate(true)
	bad.checkpoint.checkpoint.league_rules.difficulty_profile = "unrecognized"
	check(SeasonSave._decode(bad) == null, "unknown cumulative profile refused")
	if tier == 4 or (id == "scramble" and tier == 2):
		SeasonSave.path = root.path_join("%s-d%d.json" % [id, tier])
		var balance: int = loaded.career.balance()
		check(SeasonSave.save(loaded), "durable tier checkpoint")
		var cold: SeasonState = SeasonSave.restore()
		check(cold != null and cold.career.balance() == balance, "cold read keeps exact earned CB")
		if cold != null:
			check(ClubCareer.same(SeasonSave.snapshot(cold), ready), "cold read keeps exact replay")
			check(SeasonSave.save(cold) and cold.career.balance() == balance, "repeat save no reward")


func _scramble_allocation(season: SeasonState) -> void:
	var remaining: Array[String] = []
	for id: String in season.draft_pool:
		if id not in season.picks:
			remaining.append(id)
	var expected: Dictionary = SeasonOpponentDraft.allocate_d2(
		season.season_seed, remaining, season.league_rules
	)
	check(season.league_rules.version == 3 and season.league_rules.tier == 2
		and season.opponents.draft_rule == SeasonOpponentDraft.D2_RULE,
		"production caller uses composed Scramble d2")
	check(not expected.is_empty(), "captured-profile d2 allocation exists")
	if expected.is_empty():
		return
	for team in range(1, 6):
		check(season.teams[team].roster == expected.rosters[team],
			"actual fourth-pick allocation matches captured-profile allocator")
		for index in range(2):
			check(SeasonScramble.profile(season.teams[team].roster[index],
				season.league_rules).stats.pitching >= 2, "first two AI picks use resolved arms")


func _unlock_boundaries() -> void:
	var club: ClubCareer = _prefix("dugout", 3)
	check(club != null, "full structural ladder prefix")
	if club == null:
		return
	check(club.available_tiers("dugout") == [0, 1, 2, 3, 4], "lower tiers remain replayable")
	check(club.available_tiers("sponsorship") == [0]
		and club.available_tiers("standard") == [0], "no cross-League title promotion")
	var before: Dictionary = club.to_data()
	var other: SeasonState = SeasonState.create_closed_league(
		8107, LeagueRules.capture_tier("sponsorship", 1), true)
	check(not club.start_league(other) and ClubCareer.same(club.to_data(), before),
		"foreign title cannot start locked tier or mutate ledger")
	var replay: SeasonState = SeasonState.create_closed_league(
		8107, LeagueRules.capture("dugout"), true)
	check(club.start_league(replay), "Base replay remains available after d3 title")
	var titles: Dictionary = {"0": false, "1": false, "2": false, "3": false, "4": false}
	for tier in range(4):
		var proof: Dictionary = _proof("dugout", tier)
		var row: Dictionary = {"seed": 8107, "league": "dugout", "tier": tier,
			"status": "completed", "proof": proof, "league_rules": proof.league_rules,
			"receipt": ClubSeasonRecord.receipt(proof, true, tier)}
		check(not ClubCareer._progression_record(row, titles).is_empty(), "own-tier first title")
		row.receipt = ClubSeasonRecord.receipt(proof, false, tier)
		check(row.receipt.first_bonus == 0
			and not ClubCareer._progression_record(row, titles).is_empty(), "repeat title ordinary pay")


func _standard_mastery_after_league() -> void:
	# Direct reward-unit operands, not a minted asset journal or played title.
	var club: ClubCareer = _prefix("dugout", 4)
	check(club != null, "alternate d4 structural prefix for mastery regression")
	if club == null:
		return
	club._pennants = {"version": StadiumPennantRewards.MASTERY_VERSION,
		"from_season": 1, "mastery_from": 1,
		"mastery_contract": StadiumPennantRewards.MASTERY_CONTRACT, "eras": {}}
	for index in range(club.runs.size()):
		club._pennants.eras[str(index + 1)] = StadiumClubIdentity.current()
	var alternate: Variant = StadiumPennantRewards.awards(club)
	check(alternate is Dictionary and alternate.is_empty(),
		"alternate titles grant no Standard banner")
	for tier in range(5):
		var proof: Dictionary = _proof("standard")
		club.runs.append({"id": club.runs.size() + 1, "seed": 8107, "league": "standard",
			"tier": tier, "status": "completed", "proof": proof,
			"receipt": ClubSeasonRecord.receipt(proof, true, tier)})
		club._pennants.eras[str(club.runs.size())] = StadiumClubIdentity.current()
	var awards: Variant = StadiumPennantRewards.awards(club)
	var key: String = StadiumPennantRewards.mastery_key()
	check(awards is Dictionary and awards.has(key)
		and awards[key].season_id == 10 and awards[key].league_id == "standard",
		"alternate d4 cannot consume later Standard d4 mastery")
	var repeat: Dictionary = club.runs[-1].duplicate(true)
	repeat.id = 11
	repeat.receipt = ClubSeasonRecord.receipt(repeat.proof, false, 4)
	club.runs.append(repeat)
	club._pennants.eras["11"] = StadiumClubIdentity.current()
	awards = StadiumPennantRewards.awards(club)
	check(awards is Dictionary and awards.has(key) and awards[key].season_id == 10,
		"repeat Standard d4 does not replace first mastery identity")

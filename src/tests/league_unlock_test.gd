extends "res://src/tests/league_career_test.gd"
## Focused policy and save-contract checks. Compact historic titles are synthetic;
## score-only result APIs below are not physical gameplay qualification.

const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")


func _ready() -> void:
	_matrix()
	_fresh_admission()
	_history_and_tiers()
	_result_credit(true)
	_result_credit(false)
	_owner_import()
	print("League unlock checks: %d, failures: %d, synthetic_history=true, physical_games=0"
		% [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _matrix() -> void:
	check(Unlocks.from_titles({}) == ["standard", "dugout"], "exact two starter Leagues")
	var by_league: Dictionary = {"standard": "sponsorship", "sponsorship": "academy",
		"dugout": "equipment", "equipment": "earnings"}
	var by_tier: Dictionary = {1: "doubleheader", 2: "scramble", 3: "dynasty"}
	for league: String in Unlocks.IDS:
		for tier in range(5):
			# Pure mapping operands only, not an admitted history or minted reward.
			var key: String = ClubLeagueCareer.title_key(league, tier)
			var titles: Dictionary = {key: true}
			var expected: Array[String] = ["standard", "dugout"]
			if by_league.has(league):
				expected.append(by_league[league])
			if by_tier.has(tier):
				expected.append(by_tier[tier])
			var actual: Array[String] = Unlocks.from_titles(titles)
			actual.sort()
			expected.sort()
			check(actual == expected, "exact edge, no free chain cascade: %s d%d" % [league, tier])
			titles[key] = false
			check(Unlocks.from_titles(titles) == ["standard", "dugout"], "false title is not a win")
	check(Unlocks.from_titles({"unknown:1": true}) == ["standard", "dugout"],
		"unknown League cannot grant a tier unlock")


func _fresh_admission() -> void:
	var club: ClubCareer = ClubCareer.new()
	check(club.available_leagues() == ["standard", "dugout"], "fresh validated career starters")
	for league: String in ClubLeagueCareer.IDS:
		var fresh: ClubCareer = ClubCareer.new()
		var season: SeasonState = SeasonState.create_closed_league(8107,
			LeagueRules.capture(league, 0, 8107 if league == "scramble" else null), true)
		var before: Dictionary = fresh.to_data()
		var build_before: Dictionary = season.build.to_data()
		var started: bool = fresh.start_league(season)
		check(started == (league == "dugout"), "public fresh core admission: " + league)
		if not started:
			check(ClubCareer.same(fresh.to_data(), before)
				and ClubCareer.same(season.build.to_data(), build_before)
				and season.career == null and not season.league_career,
				"locked entry leaves career and season unchanged")
	var standard: SeasonState = SeasonState.create(8107, false, true, true)
	check(club.start(standard), "ordinary Standard remains a starter")
	check(club.available_leagues() == ["standard", "dugout"], "active start is not a title")


func _history_and_tiers() -> void:
	for league: String in ClubLeagueCareer.IDS:
		var prefix: ClubCareer = UnlockFixture.for_league(league)
		check(prefix != null and league in prefix.available_leagues(), "validated prerequisite " + league)
		if prefix == null:
			continue
		check(prefix.available_tiers(league) == [0], "new League begins at Base: " + league)
		var before: Dictionary = prefix.to_data()
		var rules: Dictionary = LeagueRules.capture_tier(league, 1,
			8107 if league == "scramble" else null)
		var skipped: SeasonState = SeasonState.create_closed_league(8107, rules, true)
		check(not prefix.start_league(skipped) and ClubCareer.same(prefix.to_data(), before),
			"public League unlock never skips its own Base title")
		var season: SeasonState = _new(league, prefix)
		if season == null:
			continue
		var snapshot: Dictionary = SeasonSave.snapshot(season)
		var restored: SeasonState = SeasonSave._decode(snapshot)
		check(restored != null, "unlocked fresh season cold restore")
		if restored == null:
			continue
		var unlocked: Array[String] = restored.career.available_leagues()
		var next: ClubCareer = restored.career.fork()
		check(next.close(restored) and next.available_leagues() == unlocked,
			"abandon never revokes a prior earned League")
	# Existing pre-policy League history is still valid but is not an implicit unlock.
	var legacy: ClubCareer = UnlockFixture.prefix([{"league": "sponsorship", "tier": 0}])
	check(legacy != null, "legacy pre-policy history remains readable")
	if legacy != null:
		check(legacy.available_leagues() == ["standard", "dugout", "academy"],
			"legacy actual win counts, mere prior admission grants no unrelated League")
		var saved: Dictionary = legacy.to_data()
		check(ClubCareer.same(ClubCareer.from_data(saved).to_data(), saved),
			"history bytes and receipts do not migrate")
		legacy.runs[0].receipt.total += 1
		check(legacy.available_leagues().is_empty(), "forged receipt cannot grant unlocks")
	var ladder: ClubCareer = UnlockFixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1}])
	check(ladder != null and ladder.available_tiers("dugout") == [0, 1, 2]
		and ladder.available_tiers("doubleheader") == [0],
		"same-League progression stays independent of public unlock")


func _result_credit(win: bool) -> void:
	var season: SeasonState = SeasonState.create(8107, false, true, true)
	season.career = ClubCareer.new()
	check(season.career.start(season), "score-only result source starts")
	for pick in range(4):
		check(season.choose_player(season.offers()[0]), "score-only source draft")
	for game in range(12):
		if season.phase == SeasonState.Phase.COMPLETE:
			break
		var fixture: Dictionary = season.pending_fixture()
		var home_wins: bool = (fixture.home == 0) == win
		check(season.record_player_result(fixture.id, 0 if home_wins else 1,
			1 if home_wins else 0), "existing score-only result settlement")
	check(season.phase == SeasonState.Phase.COMPLETE and season.career.sync(season),
		"completed source history validates")
	check(("sponsorship" in season.career.available_leagues()) == win,
		"only championship grants Sponsorship, not participation or completed loss")
	var before: Dictionary = season.career.to_data()
	check(season.career.sync(season) and ClubCareer.same(season.career.to_data(), before),
		"repeated completion sync cannot add unlock credit or CB")


func _owner_import() -> void:
	var season: SeasonState = SeasonState.create(8107, false, true, true)
	season.career = UnlockFixture.for_league("dynasty")
	check(season.career != null and season.career.start(season), "explicit synthetic imported ladder")
	if season.career == null:
		return
	var expected: Array[String] = season.career.available_leagues()
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(season), "unlock-owner")
	check(not authority.is_empty(), "ordinary source replays into shared authority")
	check(Authority.available_leagues(authority) == expected,
		"owner and sequential career derive same imported settled unlocks")
	check(Authority.available_leagues({}).is_empty(), "invalid authority grants no starters")
	if not authority.is_empty():
		var bad: Dictionary = authority.duplicate(true)
		bad.origin.career.runs[-1].receipt = {"finish": "champion"}
		check(Authority.available_leagues(bad).is_empty(), "forged owner history grants nothing")

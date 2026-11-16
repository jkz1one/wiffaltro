extends RefCounted
## Synthetic legacy compact championship histories for source-contract tests.
## These are not physically played wins or native/visual qualification evidence.


static func for_league(league: String) -> ClubCareer:
	var wins: Array = []
	match league:
		"standard", "dugout":
			pass
		"sponsorship":
			wins = [{"league": "standard", "tier": 0}]
		"academy":
			wins = [{"league": "standard", "tier": 0}, {"league": "sponsorship", "tier": 0}]
		"equipment":
			wins = [{"league": "dugout", "tier": 0}]
		"earnings":
			wins = [{"league": "dugout", "tier": 0}, {"league": "equipment", "tier": 0}]
		"doubleheader", "scramble", "dynasty":
			var through: int = {"doubleheader": 1, "scramble": 2, "dynasty": 3}[league]
			for tier in range(through + 1):
				wins.append({"league": "standard", "tier": tier})
		_:
			return null
	return prefix(wins)


static func nonphysical_dynasty_source() -> ClubCareer:
	# Alternate-league wins unlock Dynasty without requiring the full physical
	# stadium envelope carried by historical Standard difficulty saves.
	return prefix([
		{"league": "standard", "tier": 0},
		{"league": "sponsorship", "tier": 0}, {"league": "sponsorship", "tier": 1},
		{"league": "sponsorship", "tier": 2}, {"league": "sponsorship", "tier": 3}
	])


static func prefix(wins: Array) -> ClubCareer:
	var sample: SeasonState = SeasonState.create(8107, false, true, true)
	var seed_club: ClubCareer = ClubCareer.new()
	if not seed_club.start(sample):
		return null
	var template: Dictionary = seed_club.runs[0].duplicate(true)
	for key: String in template:
		if key not in ["id", "seed", "league", "tier", "status", "proof", "receipt"]:
			template[key] = null  # Explicitly unknown historical ancillary evidence.
	var club: ClubCareer = ClubCareer.new()
	for win: Dictionary in wins:
		var row: Dictionary = template.duplicate(true)
		row.id = club.runs.size() + 1
		row.league = win.league
		row.tier = win.tier
		row.status = "completed"
		row.proof = proof(win.league, int(win.tier))
		if row.proof.is_empty():
			return null
		if win.league != "standard":
			row["league_rules"] = row.proof.league_rules.duplicate(true)
		row.receipt = ClubSeasonRecord.receipt(row.proof, not club.cleared(win.tier, win.league),
			int(win.tier))
		club.runs.append(row)
	return ClubCareer.from_data(club.to_data())


static func proof(league: String, tier: int = 0) -> Dictionary:
	var season: SeasonState = SeasonState.create(8107)
	if league != "standard":
		season.league_rules = LeagueRules.capture_tier(league, tier,
			8107 if league == "scramble" else null)
		if season.league_rules.is_empty() or league == "dynasty":
			return {}  # Dynasty requires the separate owner-session proof grammar.
		SeasonDoubleheader.install_schedule(season)
	var scores: Array = []
	for game in range(30):
		var fixture: Dictionary = season.schedule.filter(func(row: Dictionary) -> bool:
			return row.id == game)[0]
		var home_wins: bool = fixture.away != 0
		var result: Dictionary = {"id": game, "away": fixture.away, "home": fixture.home,
			"away_runs": 0 if home_wins else 1, "home_runs": 1 if home_wins else 0}
		season.results.append(result)
		scores.append([game, fixture.away, fixture.home, result.away_runs, result.home_runs])
	var seeds: Array = season.standings().slice(0, 4).map(func(row: Dictionary) -> int:
		return row.team)
	for index in range(2):
		scores.append([30 + index, seeds[3 - index], seeds[index], 0, 1])
	scores.append([32, seeds[1], seeds[0], 0, 1])
	var result: Dictionary = {"draws": season.teams.map(func(team: Dictionary) -> float:
		return team.draw), "scores": scores}
	if league != "standard":
		result["version"] = ClubSeasonRecord.LEAGUE_VERSION
		result["league_rules"] = season.league_rules
	return result

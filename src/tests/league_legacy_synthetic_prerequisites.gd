extends RefCounted
## Independently authored contract-only history, never earned gameplay or retained input.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const STRIKEOUTS: int = 40

static func career() -> ClubCareer:
	# Same separately authored title funding as the existing flat/legacy test seed.
	var wins: Array = []
	for repeat in range(12): wins.append({"league": "standard", "tier": 0})
	for tier in range(3): wins.append({"league": "sponsorship", "tier": tier})
	for tier in range(4): wins.append({"league": "dugout", "tier": tier})
	for tier in range(4): wins.append({"league": "scramble", "tier": tier})
	var club: ClubCareer = Fixture.prefix(wins)
	if club == null: return null
	# Author four Ks in each of ten regular-season games of this NEW synthetic
	# history. All playoff stats remain unknown. No genuine result is an input.
	var details: Dictionary = {"version": ClubPlayerProgress.VERSION, "games": [],
		"development": {"mastery": 0, "known": 0, "lessons": []}}
	var authored: int = 0
	for score: Array in club.runs[0].proof.scores:
		if 0 not in [int(score[1]), int(score[2])]: continue
		var stats: Variant = null
		if int(score[0]) < 30:
			stats = {"homers": 0, "hitters": 0, "strikeouts": 4, "three_k": 0}
			authored += 4
		details.games.append({"game": int(score[0]), "stats": stats,
			"sponsors": 0, "end_half": 9, "deficit": 0})
	if authored != STRIKEOUTS or not ClubPlayerProgress.valid(details, club.runs[0].proof.scores):
		return null
	club.runs[0].player_progress = details
	var checked: ClubCareer = ClubCareer.from_data(club.to_data())
	if checked == null: return null
	var rows: Array = StadiumCareerProgress.capture(checked)
	var metrics: Dictionary = StadiumCareerProgress.metrics(rows, rows.size())
	if metrics.get("strikeouts") != STRIKEOUTS or not StadiumCatalog.eligible("ST-026", metrics):
		return null
	return checked

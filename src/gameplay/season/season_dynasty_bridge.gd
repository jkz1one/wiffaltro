extends RefCounted
## Closed offline start checkpoint bridge. No career/public switch or replacement entitlement.
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")


static func install_roster(season: SeasonState, value: Variant) -> bool:
	var start: Dictionary = Profile.normalize(value)
	if (
		season == null
		or start.is_empty()
		or not LeagueRules.dynasty(season.league_rules)
		or start.seed != season.season_seed
		or not season.picks.is_empty()
		or season.phase != SeasonState.Phase.DRAFT
		or not season.results.is_empty()
		or season.build == null
		or season.build.revision() != 0
		or season.opponents == null
		or not season.opponents.clubs.is_empty()
	):
		return false
	var roster: Array[String] = []
	roster.assign(start.roster)
	var remaining: Array[String] = []
	for id: String in season.draft_pool:
		if not roster.has(id):
			remaining.append(id)
	for id: String in roster:
		if not season.draft_pool.has(id):
			return false
	var tier: int = int(season.league_rules.tier)
	var allocation: Dictionary = (
		SeasonOpponentDraft.allocate_d2(season.season_seed, remaining)
		if tier >= 2 else SeasonOpponentDraft.allocate(season.season_seed, remaining)
	)
	if allocation.is_empty():
		return false
	# Construct detached replacements before assigning the carried owner.
	var blocked: Array[String] = []
	for team in range(1, 6):
		blocked.append_array(allocation.rosters[team])
	var build: SeasonBuild = SeasonBuild.new(season.season_seed, roster, season.draft_pool, blocked)
	if start.has("pitch_catalog") and not build.enable_pitch_catalog():
		return false
	if not build.enable_league_rules(season.league_rules):
		return false
	if not ClubCareer.same(start.get("access", {}), season._closed_access):
		return false
	if (
		not season._closed_access.is_empty()
		and not ClosedContentAccess.install(build, season._closed_access)
	):
		return false
	if not build.enable_dynasty_start(start):
		return false
	season.picks.assign(roster)
	season.teams[0].roster = roster.duplicate()
	season.opponents.draft_order.assign(allocation.order)
	season.opponents.draft_rule = SeasonOpponentDraft.D2_RULE if tier >= 2 else ""
	for team in range(1, 6):
		season.teams[team].roster = allocation.rosters[team].duplicate()
	season.build = build
	season._dynasty_start = start
	season.opponents.initialize(season)
	if season.opponents.clubs.size() != 5:
		return false
	for team in range(6):
		season.teams[team].strength = season._strength(team)
	season.phase = SeasonState.Phase.REGULAR
	return season.league_context_consistent()


static func create(value: Variant, live: bool = true, tier: int = 0) -> SeasonState:
	var start: Dictionary = Profile.normalize(value)
	if start.is_empty():
		return null
	var season: SeasonState = SeasonState.create_closed_league(
		start.seed, LeagueRules.capture_tier("dynasty", tier), live, start.get("access", {})
	)
	if (
		season == null
		or not install_roster(season, start)
		or not SeasonInventoryRules.enable(season)
	):
		return null
	return season

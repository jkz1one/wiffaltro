extends Node
## Detached admission tests only. Synthetic title history is not played evidence.
const Proposal = preload("res://src/gameplay/season/dynasty_league_home_proposal.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var source: SeasonState = SeasonState.create(93001, false, true, true)
	var club: ClubCareer = Fixture.nonphysical_dynasty_source()
	check(club.start(source), "synthetic source starts")
	source.career = club
	for index in range(4):
		source.choose_player(source.offers()[0])
	var authority: Dictionary = Authority.create(SeasonSave.snapshot(source), "league-home-owner")
	check(not authority.is_empty(), "source authority qualifies")
	var original: Dictionary = authority.duplicate(true)
	var proposal: Dictionary = Proposal.prepare(authority, "dugout", 93002)
	check(not proposal.is_empty(), "Dugout freezes owned home and draft")
	if not proposal.is_empty():
		check(Proposal.current(authority, proposal), "exact authority accepts proposal")
		check(Proposal.current(authority, JSON.parse_string(JSON.stringify(proposal, "", true, true))),
			"JSON round trip preserves admission")
		var season: SeasonState = Proposal.Save.Owned.decode_setup(proposal.checkpoint)
		check(season != null and season.league_rules.league == "dugout"
			and season.career == null and season.home_property.is_empty(),
			"historical checkpoint stays venue-free and has no second wallet")
		check(season != null and season.player_access == proposal.grant.player_access,
			"owned draft pool freezes with grant")
		check(SeasonSave._decode(proposal) == null, "proposal is not a playable save")
		check(not Proposal.current({}, proposal), "proposal cannot self-authorize")
		for field: String in ["home_property", "grant", "checkpoint"]:
			var bad: Dictionary = proposal.duplicate(true)
			bad[field] = {}
			check(not Proposal.current(authority, bad), "tampered " + field + " denied")
		var bad: Dictionary = proposal.duplicate(true)
		bad.tier = 1
		check(not Proposal.current(authority, bad), "other League title does not unlock Dugout tier")
	check(Proposal.prepare(authority, "dugout", 93002, 1).is_empty(), "same-League tier gate preserved")
	check(Proposal.prepare(authority, "equipment", 93002).is_empty(), "Dugout title still required for Equipment")
	check(Proposal.prepare(authority, "standard", 93002).is_empty(), "Standard uses existing route")
	check(Proposal.prepare(authority, "dynasty", 93002).is_empty(), "Dynasty uses carried-roster route")
	check(Proposal.prepare(authority, "dugout", -1).is_empty(), "invalid seed denied")
	for league: String in ["sponsorship", "academy", "doubleheader", "scramble"]:
		var alternate: Dictionary = Proposal.prepare(authority, league, 93003)
		check(not alternate.is_empty(), league + " preserves unlocked entry")
		if not alternate.is_empty():
			var season: SeasonState = Proposal.Save.Owned.decode_setup(alternate.checkpoint)
			check(season != null and season.league_rules == LeagueRules.capture_tier(league, 0,
				93003 if league == "scramble" else null), league + " retains exact rules")
	var higher: Dictionary = Proposal.prepare(authority, "sponsorship", 93004, 4)
	check(not higher.is_empty(), "same-League title admits its next tier")
	check(ClubCareer.same(original, authority), "all proposal work leaves authority unchanged")
	print("DYNASTY_LEAGUE_HOME_PROPOSAL: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

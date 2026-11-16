extends Node
## Synthetic legacy titles; full native Standard construction/decoding, no games.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Proposal = preload("res://src/gameplay/season/dynasty_standard_proposal.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var club: ClubCareer = Fixture.prefix([
		{"league": "standard", "tier": 0}, {"league": "standard", "tier": 1},
		{"league": "standard", "tier": 2}, {"league": "standard", "tier": 3}])
	var source: SeasonState = SeasonState.create(39102, false, true, true)
	source.physical = SeasonPhysicalFixtures.new()
	source.opponents._format = 13
	check(club != null and ClubPlayerDraft.apply(source, ClubPlayers.owned(club)), "synthetic title source owned players")
	check(club.start(source, 0), "real Standard Base starts against legacy titles")
	club._assets = ClubPlayers.assets(club).to_data()
	source.career = club
	source.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(club), true)
	source.npc_venues = SeasonVenues.capture_five(source.season_seed, club.current, 0)
	source.final_venue = SeasonFinalVenue.capture_standard_base(source)
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "owned Standard source draft")
	var origin: Dictionary = SeasonSave.snapshot(source)
	check(not origin.is_empty() and SeasonSave._decode(origin) != null, "full Standard source owned venue context")
	var authority: Dictionary = Authority.create(origin, "tiers-owner")
	check(not authority.is_empty(), "tier source authority qualifies")
	if authority.is_empty():
		_finish()
		return
	check(Authority.available_tiers(authority, "standard") == [0, 1, 2, 3, 4], "all Standard tiers derived")
	for tier in range(5):
		if "--live-controller" in OS.get_cmdline_user_args():
			_live_controller(authority, tier)
			continue
		var proposal: Dictionary = Proposal.prepare(authority, 39200 + tier, tier)
		check(not proposal.is_empty(), "tier%d proposal" % tier)
		if proposal.is_empty():
			continue
		var season: SeasonState = SeasonSave._decode(proposal.snapshot)
		var grant: Dictionary = Grant.capture(authority)
		var context: Dictionary = Bound.binding_for(season, grant, "tiers-owner", "tiers-lineage", 0, 1, "tier:%d" % tier)
		var snapshot: Dictionary = Bound.capture(season, context, grant, authority)
		check(not snapshot.is_empty(), "tier%d bound capture" % tier)
		if snapshot.is_empty():
			continue
		var cold: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(snapshot, "", true, true)), authority)
		check(not cold.is_empty(), "tier%d cold restore" % tier)
		check(season.career.active_tier() == tier and season.npc_venues.venue_ordinal == tier, "tier%d real venue quota" % tier)
		check((tier == 0) == season.build._pricing_rule.is_empty(), "tier%d Standard pricing" % tier)
		check(season.opponents.draft_rule == (SeasonOpponentDraft.D2_RULE if tier >= 2 else ""), "tier%d Standard opponent drafting" % tier)
		var opened: Dictionary = Authority.open_session(authority, snapshot)
		check(not opened.is_empty(), "tier%d owner authority admission" % tier)
	_finish()
func _finish() -> void:
	print("DYNASTY_STANDARD_TIERS: %d checks, %d failures, physical_games=0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _live_controller(authority: Dictionary, tier: int) -> void:
	var controller: RefCounted = preload("res://src/presentation/season/dynasty_career_controller.gd").new(null)
	var owner: Dictionary = {"owner_id": "tiers-owner", "career": authority,
		"lineage": {"id": "tiers-lineage", "generation": 0, "ordinal": 1}}
	var snapshot: Dictionary = controller._standard_candidate(owner, 39200 + tier, tier, "live-tier:%d" % tier)
	check(not snapshot.is_empty(), "tier%d controller candidate" % tier)
	if snapshot.is_empty():
		return
	var cold: Dictionary = Bound.qualify(JSON.parse_string(JSON.stringify(snapshot, "", true, true)), authority)
	check(not cold.is_empty(), "tier%d controller cold restore" % tier)
	if cold.is_empty():
		return
	var season: SeasonState = cold.season
	check(season.career == null and snapshot.version == 89 and cold.session.tier == tier,
		"tier%d explicit89 no duplicate career" % tier)
	check(not season.home_property.is_empty() and season.npc_venues.venue_ordinal == tier,
		"tier%d controller owned/away venue context" % tier)
	check((tier == 0) == season.build._pricing_rule.is_empty(), "tier%d controller pricing" % tier)
	check(season.opponents.draft_rule == (SeasonOpponentDraft.D2_RULE if tier >= 2 else ""),
		"tier%d controller draft rules" % tier)
	var admitted: Dictionary = Authority.open_session(authority, snapshot)
	check(not admitted.is_empty(), "tier%d controller admission" % tier)
	var transported: Dictionary = JSON.parse_string(JSON.stringify(admitted, "", true, true))
	check(not Authority.normalize(transported).is_empty(), "tier%d cold shared authority preserves Standard title key" % tier)
	transported.sessions["live-tier:%d" % tier].session.tier = 1.5
	check(Authority.normalize(transported).is_empty(), "fractional Standard tier remains refused")

extends RefCounted
## Detached owned-home alternate admission. NOT a playable/saved owner session.
## The closed checkpoint keeps its historical venue-free grammar. A future explicit
## replay envelope must install the qualified home before physical replay begins.
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const VERSION: int = 1
const LEAGUES: Array[String] = ["dugout", "sponsorship", "academy", "doubleheader",
	"equipment", "earnings", "scramble"]
const FIELDS: Array[String] = ["version", "league", "seed", "tier", "grant",
	"home_property", "checkpoint"]


static func prepare(value: Dictionary, league: String, seed_value: int, tier: int = 0) -> Dictionary:
	var authority: Dictionary = Authority.normalize(value)
	if authority.is_empty() or league not in LEAGUES \
		or not Profile.whole(seed_value, 0, 2147483647) \
		or league not in Authority.available_leagues(authority) \
		or tier not in Authority.available_tiers(authority, league):
		return {}
	# Reuse the exact authority/assets/access witness, not Standard's tier rules,
	# sequential career start, or venue/final assignments.
	var grant: Dictionary = Grant.capture(authority)
	if grant.is_empty():
		return {}
	var club: ClubCareer = preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(grant.history)
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	if paid == null:
		return {}
	var home: Dictionary = StadiumLayoutSnapshot.capture(paid, true)
	if home.is_empty() or not StadiumLayoutSnapshot.matches(home, paid):
		return {}
	var rules: Dictionary = LeagueRules.capture_tier(league, tier,
		seed_value if league == "scramble" else null)
	var season: SeasonState = SeasonState.create_closed_league(seed_value, rules, true, grant.access)
	if season == null or not ClubPlayerDraft.apply(season, grant.player_access):
		return {}
	var checkpoint: Dictionary = SeasonSave.snapshot(season)
	if checkpoint.is_empty() or Save.Owned.decode_setup(checkpoint) == null:
		return {}
	return {"version": VERSION, "league": league, "seed": seed_value, "tier": tier,
		"grant": grant.duplicate(true), "home_property": home.duplicate(true),
		"checkpoint": checkpoint}


static func current(value: Dictionary, proposal: Variant) -> bool:
	if not Profile.keys(proposal, FIELDS) \
		or not Profile.whole(proposal.version, VERSION, VERSION) \
		or not proposal.league is String or proposal.league not in LEAGUES \
		or not Profile.whole(proposal.seed, 0, 2147483647) \
		or not Profile.whole(proposal.tier, 0, 4):
		return false
	# Rebuild from authority, never accept a self-consistent file claim as a grant.
	var expected: Dictionary = prepare(value, proposal.league, int(proposal.seed), int(proposal.tier))
	return not expected.is_empty() and ClubCareer.same(
		Save.snapshot_reference(expected), Save.snapshot_reference(proposal))

extends RefCounted
## Detached Standard venue/tier proposal. NOT an admitted owner session.
## No disk writes, owner mutation, or authority replacement occur here.
## Activation must remain gated until an owner transaction binds this proposal.
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")


static func prepare(value: Dictionary, seed_value: int, tier: int) -> Dictionary:
	var authority: Dictionary = Authority.normalize(value)
	if authority.is_empty() or not Profile.whole(seed_value, 0, 2147483647) \
		or tier not in [0, 1, 2, 3, 4]:
		return {}
	# This projection contains settled history only. Never turn a paused Dynasty
	# session into a fabricated sequential/abandoned ClubCareer row.
	var club: ClubCareer = Authority._history(authority)
	if ClubCareer.from_data(club.to_data()) == null or tier not in club.available_tiers():
		return {}
	# While live sessions contain new earned eligibility, ordinary Standard's
	# embedded career cannot represent it. Fail closed rather than drop access.
	var settled_access: Dictionary = ClosedContentAccess._capture_checked(club, {}, authority.owner_id)
	if not ClubCareer.same(settled_access.progress, Authority.access(authority).progress):
		return {}
	var season: SeasonState = SeasonState.create(seed_value, false, true, true)
	season.difficulty = 1
	season.physical = SeasonPhysicalFixtures.new()
	season.opponents._format = 13
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)):
		return {}
	if not club.start(season, tier):
		return {}
	season.career = club
	season.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(club), true)
	if season.home_property.is_empty() or not SeasonVenues.readiness(tier).get("ok", false):
		return {}
	season.npc_venues = SeasonVenues.capture_five(seed_value, club.current, tier)
	if season.npc_venues.is_empty():
		return {}
	match tier:
		0: season.final_venue = SeasonFinalVenue.capture_standard_base(season)
		1: season.final_venue = SeasonFinalVenue.capture_standard_d1(season)
		2: season.final_venue = SeasonFinalVenue.capture_standard_d2(season)
		3: season.final_venue = SeasonFinalVenue.capture_standard_d3(season)
		4: season.final_venue = SeasonFinalVenue.capture_standard_d4(season)
	if season.final_venue.is_empty():
		return {}
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	if snapshot.is_empty() or SeasonSave._decode(snapshot) == null:
		return {}
	return {"version": 1, "authority_reference": Save.snapshot_reference(authority),
		"tier": tier, "seed": seed_value, "snapshot": snapshot}


static func current(value: Dictionary, proposal: Dictionary) -> bool:
	var authority: Dictionary = Authority.normalize(value)
	if authority.is_empty() or not Profile.keys(proposal,
		["version", "authority_reference", "tier", "seed", "snapshot"]) \
		or not Profile.whole(proposal.version, 1, 1) \
		or not Profile.whole(proposal.seed, 0, 2147483647) \
		or not Profile.whole(proposal.tier, 0, 4) \
		or not ClubCareer.same(proposal.authority_reference, Save.snapshot_reference(authority)):
		return false
	var expected: Dictionary = prepare(authority, int(proposal.seed), int(proposal.tier))
	return not expected.is_empty() and ClubCareer.same(
		Save.snapshot_reference(expected), Save.snapshot_reference(proposal))

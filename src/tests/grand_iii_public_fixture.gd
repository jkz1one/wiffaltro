extends RefCounted
## Explicit qualification plumbing only; no published League selection or fabricated game.
## The fixed record is captured before draft, independently of eventual final participants.

const SEED: int = 6
const PREFIX: String = "npc:GRAND-III:r1:"


static func ready() -> bool:
	return not SeasonFinalVenue.capture_explicit(SEED, 1, "standard", "GRAND-III").is_empty()


static func season() -> SeasonState:
	return _season_profile("")


static func season_time(mode: String) -> SeasonState:
	if mode not in ["day", "sunset", "night"]:
		return null
	return _season_profile(mode)


static func _season_profile(mode: String) -> SeasonState:
	var result: SeasonState = SeasonState.create(SEED, false, true, true)
	result.physical = SeasonPhysicalFixtures.new()
	result.opponents._format = 13
	result.career = ClubCareer.new()
	if not ClubPlayerDraft.apply(result, ClubPlayers.owned(result.career)) \
		or not result.career.start(result):
		return null
	result.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(result.career))
	result.npc_venues = SeasonVenues.capture_five(SEED, result.career.current, 0)
	if mode.is_empty():
		result.final_venue = SeasonFinalVenue.capture_grand_iii(SEED, result.career.current)
	else:
		result.final_venue = SeasonFinalVenue.capture_grand_iii_time(SEED, result.career.current, mode)
	if result.npc_venues.is_empty() or result.final_venue.is_empty():
		return null
	for pick in range(4):
		if not result.choose_player(result.offers()[0]):
			return null
	return result


static func fixture(season_value: SeasonState, player_home: bool = false) -> Dictionary:
	# This is a bounded installation fixture, not completed progression or a saved final.
	if season_value == null:
		return {}
	season_value.final_fixture = {"id": 32, "round": 11, "home": 0 if player_home else 1,
		"away": 1 if player_home else 0, "neutral": true}
	return season_value.final_fixture.duplicate(true)

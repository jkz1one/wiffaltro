extends RefCounted
## Test-only explicit ordinal2 assignment; production new-season UI remains ordinal0.
## Reuses actual allocator, saved owners, independent day environments and scheduled fixtures.

static func season(seed_value: int = 10) -> SeasonState:
	var result: SeasonState = SeasonState.create(seed_value, false, true, true)
	result.physical = SeasonPhysicalFixtures.new()
	result.opponents._format = 13
	result.career = ClubCareer.new()
	if not ClubPlayerDraft.apply(result, ClubPlayers.owned(result.career)) \
		or not result.career.start(result):
		return null
	result.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(result.career))
	result.npc_venues = SeasonVenues.capture_five(seed_value, result.career.current, 2)
	if result.npc_venues.is_empty():
		return null
	for pick in range(4):
		if not result.choose_player(result.offers()[0]):
			return null
	return result


static func fixture(season_value: SeasonState, id: String = "AM-01") -> Dictionary:
	if season_value == null:
		return {}
	for row: Dictionary in season_value.schedule:
		if row.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season_value, row)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return row.duplicate(true)
	return {}

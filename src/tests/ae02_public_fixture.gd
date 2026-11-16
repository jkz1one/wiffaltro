extends RefCounted
## Source-derived fixed Base opening. Uses the real allocator, draft, schedule and saved owners.

const SEED: int = 3
const HOSTS: Array[String] = ["AC-01", "AY-01", "AE-01", "AY-02", "AE-02"]
const STREAMS: Dictionary = {"layout": 169751845, "owner": 1272751476,
	"environment": 1558738264}
const ENVIRONMENT_SEEDS: Array[int] = [1007237410, 50137695, 1917846786, 1673703776,
	587619850, 1750203904, 306653505, 2046209792, 1303720881, 5146308, 494553881,
	1626550384, 1409400329, 1254202206, 1645317176, 131686174, 174344775, 253114947,
	1873246730, 1563088581, 395222203, 1154384202, 917302677, 62816990, 1705380868,
	1715626971, 1939590345, 1765053092, 1886243998, 1306121129, 1823968132, 2053613072]


static func season(seed_value: int = 3) -> SeasonState:
	var result: SeasonState = SeasonState.create(seed_value, false, true, true)
	result.physical = SeasonPhysicalFixtures.new()
	result.opponents._format = 13
	result.career = ClubCareer.new()
	if not ClubPlayerDraft.apply(result, ClubPlayers.owned(result.career)) \
		or not result.career.start(result):
		return null
	result.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(result.career))
	result.npc_venues = SeasonVenues.capture_five(seed_value, result.career.current, 0)
	if result.npc_venues.is_empty():
		return null
	for pick in range(4):
		if not result.choose_player(result.offers()[0]):
			return null
	return result


static func fixture(season_value: SeasonState, id: String = "AE-02") -> Dictionary:
	if season_value == null:
		return {}
	for row: Dictionary in season_value.schedule:
		if row.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season_value, row)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return row.duplicate(true)
	return {}

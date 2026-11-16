extends RefCounted
## Test-only explicit ordinal2 assignment; production new-season UI remains ordinal0.
## Reuses actual allocator, saved owners, independent day environments and scheduled fixtures.

const SEED: int = 3
const HOSTS: Array[String] = ["AC-01", "AY-03", "AC-01", "AM-02", "AE-01"]
const STREAMS: Dictionary = {"layout": 759349901, "owner": 1627083556,
	"environment": 502166493}
const ENVIRONMENT_SEEDS: Array[int] = [2075833080, 1615834252, 642884249, 1786253807,
	702254153, 483879404, 630731748, 2012230395, 1158501613, 1220961206, 1334236891,
	1570673758, 1346577954, 436744834, 542333251, 170529209, 1071902394, 4893602,
	1473822101, 417054755, 1823736022, 1322498094, 1558910949, 778285916, 207115218,
	1811809390, 1911922617, 323262975, 947409911, 1418708979, 564801298, 1851797856]


static func season(seed_value: int = 3) -> SeasonState:
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


static func fixture(season_value: SeasonState, id: String = "AM-02") -> Dictionary:
	if season_value == null:
		return {}
	for row: Dictionary in season_value.schedule:
		if row.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season_value, row)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return row.duplicate(true)
	return {}

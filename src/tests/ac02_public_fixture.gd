extends RefCounted
## Exact joined-source Base opening; source-model goldens await engine verification.
## Source-model seed6 uses the real allocator, draft, schedule and saved owners.

const SEED: int = 6
const ORDINAL: int = 0
const HOSTS: Array[String] = ["AE-02", "AY-03", "AY-02", "AE-01", "AC-02"]
const STREAMS: Dictionary = {"layout": 622598292, "owner": 380739901,
	"environment": 668002606}
const ENVIRONMENT_SEEDS: Array[int] = [167682854, 1472964427, 385973368, 1616208981, 1989529512,
	1024669896, 568878035, 1825586120, 1186116968, 509352470,
	753907971, 204469833, 1810224896, 74627443, 1769393043,
	1324654577, 203323230, 239283125, 1762388798, 1176173526,
	800477321, 2038631031, 392483822, 601088923, 1056451302,
	815291740, 1247594726, 1960128226, 919442111, 1601012711,
	653569729, 614915661]


static func ready() -> bool:
	return SEED >= 0 and ORDINAL >= 0 and HOSTS.size() == 5 \
		and HOSTS.has("AC-02") and STREAMS.size() == 3 and ENVIRONMENT_SEEDS.size() == 32


static func season() -> SeasonState:
	if not ready():
		return null
	var result: SeasonState = SeasonState.create(SEED, false, true, true)
	result.physical = SeasonPhysicalFixtures.new()
	result.opponents._format = 13
	result.career = ClubCareer.new()
	if not ClubPlayerDraft.apply(result, ClubPlayers.owned(result.career)) \
		or not result.career.start(result):
		return null
	result.home_property = StadiumLayoutSnapshot.capture(ClubPlayers.assets(result.career))
	result.npc_venues = SeasonVenues.capture_five(SEED, result.career.current, ORDINAL)
	if result.npc_venues.is_empty():
		return null
	for pick in range(4):
		if not result.choose_player(result.offers()[0]):
			return null
	return result


static func fixture(season_value: SeasonState, id: String = "AC-02") -> Dictionary:
	if season_value == null:
		return {}
	for row: Dictionary in season_value.schedule:
		if row.away != 0:
			continue
		var snapshot: Dictionary = SeasonVenues.for_fixture(season_value, row)
		if not snapshot.is_empty() and snapshot.manifest.id == id:
			return row.duplicate(true)
	return {}

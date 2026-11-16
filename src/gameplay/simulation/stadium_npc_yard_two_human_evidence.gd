class_name StadiumNpcYardTwoHumanEvidence
extends RefCounted
## Human terminal evidence uses actual PlayRecords and base flow, never AI automation.
# gdlint: disable=max-returns

const VERSION: int = 1
const NEUTRAL_FINAL_VERSION: int = 2
const GRAND_FINAL_VERSION: int = 3
const GRAND_II_FINAL_VERSION: int = 4
const GRAND_III_FINAL_VERSION: int = 5
const POOL_PARTY_FINAL_VERSION: int = 6
const HILLSIDE_FINAL_VERSION: int = 7


static func expected(season: SeasonState, fixture: Dictionary) -> bool:
	return season != null and not fixture.is_empty() \
		and StadiumNpcSnapshot.is_fixture(SeasonVenues.for_fixture(season, fixture))


static func request_key(season: SeasonState, fixture: Dictionary) -> String:
	return StadiumPoolOwnedHumanEvidence.request_key(season, fixture)


static func capture(lab: PitchBatLab, season: SeasonState) -> Dictionary:
	if season == null:
		return {}
	var fixture: Dictionary = season.pending_fixture()
	if lab == null or not lab.is_inside_tree() or lab._match_state == null \
		or lab._npc_season != season or not expected(season, fixture) \
		or lab._match_state.phase != MatchState.Phase.GAME_END \
		or not StadiumPropertyRuntime.npc_installed_bound(lab, lab._match_state.stadium):
		return {}
	var state: MatchState = lab._match_state
	var hillside_final: bool = state.stadium.get("version") \
		== StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION
	var pool_party_final: bool = state.stadium.get("version") \
		== StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION
	var grand_iii_final: bool = state.stadium.get("version") \
		== StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION
	var grand_ii_final: bool = state.stadium.get("version") \
		== StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION
	var grand_final: bool = state.stadium.get("version") \
		== StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION
	var neutral_final: bool = hillside_final or pool_party_final or grand_iii_final \
		or grand_ii_final or grand_final \
		or state.stadium.get("version") \
		== StadiumNpcSnapshot.FINAL_FIXTURE_VERSION
	if (lab._player_home and not neutral_final) or lab._player_home != (fixture.home == 0) \
		or (fixture.away != 0 and fixture.home != 0):
		return {}
	var teams: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		teams.append(team.roster.map(func(player: PlayerMatchState) -> String:
			return String(player.definition.id)))
	var plays: Array = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		plays.append({"play": index,
			"half": (play.inning - 1) * 2 + (0 if play.top_half else 1),
			"batter": String(play.batter_id), "pitcher": String(play.pitcher_id),
			"recipe": String(play.pitch_id), "contact": play.contact_outcome,
			"exit_speed": play.exit_speed_mps, "result": String(play.result),
			"balls": play.balls_before, "strikes": play.strikes_before,
			"outs": play.outs_before, "runs": play.runs_scored})
	var evidence: Dictionary = {"version": HILLSIDE_FINAL_VERSION if hillside_final else (
		POOL_PARTY_FINAL_VERSION if pool_party_final else (
		GRAND_III_FINAL_VERSION if grand_iii_final else (
		GRAND_II_FINAL_VERSION if grand_ii_final else (
		GRAND_FINAL_VERSION if grand_final else NEUTRAL_FINAL_VERSION if neutral_final else VERSION)))),
		"fixture": fixture.id,
		"request": request_key(season, fixture),
		"property": StadiumNpcSnapshot.normalized(state.stadium),
		"away_runs": state.away_team.runs, "home_runs": state.home_team.runs,
		"performance": state.performance.snapshot(state), "teams": teams,
		"plays": plays, "base": state.base_flow.evidence(state),
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records),
		"yard": _yard(lab)}
	if pool_party_final:
		if not StadiumPoolPartyRuntime.installed_bound(lab, state.stadium):
			return {}
		evidence["pool"] = StadiumPoolPartyRuntime.capture_evidence(lab)
	if not accepts(season, fixture, evidence, state.away_team.runs, state.home_team.runs,
		evidence.performance, SeasonOpponentTactics.evidence(
			state, state.away_team if lab._player_home else state.home_team)):
		return {}
	var decoded: Variant = JSON.parse_string(JSON.stringify(evidence, "", true, true))
	return evidence if valid(decoded) and ClubCareer.same(evidence, decoded) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if SeasonOwnership._whole(value.get("version"), HILLSIDE_FINAL_VERSION, HILLSIDE_FINAL_VERSION) \
		and not StadiumNpcSnapshot._json_types(value):
		return false
	var keys: Array = ["version", "fixture", "request", "property", "away_runs", "home_runs",
		"performance", "teams", "plays", "base", "surfaces", "yard"]
	if SeasonOwnership._whole(value.get("version"),
		POOL_PARTY_FINAL_VERSION, POOL_PARTY_FINAL_VERSION):
		if not StadiumNpcSnapshot._json_types(value):
			return false
		keys.append("pool")
	if not SeasonOwnership._keys(value, keys) or not _envelope(value) \
		or not StadiumPoolOwnedReport._digest_shape(value.request) \
		or not StadiumNpcSnapshot.valid(value.property) \
		or value.property.binding.fixture != value.fixture \
		or not SeasonOwnership._whole(value.away_runs, 0, 9999) \
		or not SeasonOwnership._whole(value.home_runs, 0, 9999) or value.away_runs == value.home_runs \
		or not value.teams is Array or not value.performance is Dictionary \
		or not value.plays is Array or value.plays.is_empty() or value.plays.size() > 9999 \
		or not PhysicalBaseFlow.valid(value.base, value.teams, value.performance):
		return false
	return value.base.final.away == value.away_runs and value.base.final.home == value.home_runs \
		and StadiumPoolOwnedHumanEvidence._plays(value) \
		and _contacts(value) \
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= 8 * 1024 * 1024


static func accepts(season: SeasonState, fixture: Dictionary, value: Variant,
	away: int, home: int, performance: Dictionary, ai_tactics: Dictionary) -> bool:
	if not expected(season, fixture):
		return value == null
	if not valid(value) or not StadiumNpcSnapshot.matches_fixture(value.property, season, fixture) \
		or value.fixture != fixture.id or value.request != request_key(season, fixture) \
		or value.away_runs != away or value.home_runs != home \
		or not ClubCareer.same(value.performance, performance) \
		or not ClubCareer.same(value.base, ai_tactics.get("base")):
		return false
	for index in range(2):
		var actual: Array = value.teams[index].duplicate()
		var club: int = fixture.away if index == 0 else fixture.home
		var required: Array = season.teams[club].roster.duplicate()
		actual.sort()
		required.sort()
		if not ClubCareer.same(actual, required):
			return false
	return true


static func pending_valid(season: SeasonState, human: Array) -> bool:
	var fixture: Dictionary = season.pending_fixture()
	return SeasonRoundSettlement._shape({"human": human, "reports": []}, true, true, false, true) \
		and human[0] == fixture.get("id") \
		and human[14] == StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture)) \
		and accepts(season, fixture, human[16], int(human[1]), int(human[2]), human[3], human[12])


static func replay_result(season: SeasonState, result: Dictionary, performance: Dictionary,
	ai_tactics: Dictionary, replayed_tactics: Array, property_key: String) -> bool:
	if not expected(season, season.pending_fixture()):
		return not result.has("yard_evidence") and StadiumPoolOwnedHumanEvidence.replay_result(
			season, result, performance, ai_tactics, replayed_tactics, property_key)
	var allowed: Array = season.pending_fixture().keys() + ["away_runs", "home_runs", "property",
		"performance", "club_roster", "used_gear", "tactics", "batting", "stances", "fielding",
		"pitching", "field_supply", "frozen", "ai_tactics", "yard_evidence"]
	for key: Variant in result:
		if not key is String or not allowed.has(key):
			return false
	if not result.get("yard_evidence") is Dictionary:
		return false
	return season.record_player_result(int(result.id), int(result.away_runs), int(result.home_runs),
		performance, [], [], {}, [], [], {}, {}, [], ai_tactics, replayed_tactics,
		property_key, null, result.yard_evidence)


# The old ordinary evidence remains exactly v1/fixture0..31/snapshot19.
# Neutral evidence is a distinct v2/fixture32/snapshot20 envelope; no version fallback.
static func _envelope(value: Dictionary) -> bool:
	if SeasonOwnership._whole(value.get("version"),
		HILLSIDE_FINAL_VERSION, HILLSIDE_FINAL_VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 32, 32) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.HILLSIDE_FINAL_FIXTURE_VERSION)
	if SeasonOwnership._whole(value.get("version"),
		POOL_PARTY_FINAL_VERSION, POOL_PARTY_FINAL_VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 32, 32) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.POOL_PARTY_FINAL_FIXTURE_VERSION)
	if SeasonOwnership._whole(value.get("version"),
		GRAND_III_FINAL_VERSION, GRAND_III_FINAL_VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 32, 32) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.GRAND_III_FINAL_FIXTURE_VERSION)
	if SeasonOwnership._whole(value.get("version"), GRAND_II_FINAL_VERSION, GRAND_II_FINAL_VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 32, 32) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION,
				StadiumNpcSnapshot.GRAND_II_FINAL_FIXTURE_VERSION)
	if SeasonOwnership._whole(value.get("version"), GRAND_FINAL_VERSION, GRAND_FINAL_VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 32, 32) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION, StadiumNpcSnapshot.GRAND_FINAL_FIXTURE_VERSION)
	if SeasonOwnership._whole(value.get("version"), VERSION, VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 0, 31) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION, StadiumNpcSnapshot.PUBLIC_FIXTURE_VERSION)
	if SeasonOwnership._whole(value.get("version"), NEUTRAL_FINAL_VERSION, NEUTRAL_FINAL_VERSION):
		return SeasonOwnership._whole(value.get("fixture"), 32, 32) \
			and value.get("property") is Dictionary \
			and SeasonOwnership._whole(value.property.get("version"),
				StadiumNpcSnapshot.FINAL_FIXTURE_VERSION, StadiumNpcSnapshot.FINAL_FIXTURE_VERSION)
	return false


# Capture already requires the matching installed public runtime before reading provenance.
static func _yard(lab: PitchBatLab) -> Array:
	var resolver: String = PhysicalStadiumReport.npc_resolver(lab._match_state.stadium)
	if resolver in [StadiumNpcPublicReport.RESOLVER, StadiumLongYardPublicReport.RESOLVER,
		StadiumGrandIPublicReport.RESOLVER, StadiumGrandIIPublicReport.RESOLVER,
		StadiumGrandIIIPublicReport.RESOLVER, StadiumPoolPartyPublicReport.RESOLVER,
		StadiumHillsidePublicReport.RESOLVER]:
		return StadiumNpcPublicRuntime._property(lab).provenance.duplicate(true)
	if resolver == StadiumNpcYardTwoReport.RESOLVER:
		return StadiumNpcYardTwoRuntimeV1._property(lab).provenance.duplicate(true)
	if resolver == StadiumNpcYardThreeReport.RESOLVER:
		return StadiumNpcYardThreeRuntimeV1._property(lab).provenance.duplicate(true)
	return []


static func _contacts(value: Dictionary) -> bool:
	var resolver: String = PhysicalStadiumReport.npc_resolver(value.property)
	if resolver == StadiumHillsidePublicReport.RESOLVER:
		return StadiumHillsidePublicContacts.evidence(
			value.surfaces, value.plays, value.yard, value.property)
	if resolver == StadiumPoolPartyPublicReport.RESOLVER:
		return StadiumPoolPartyPublicContacts.evidence_human6(
			value.surfaces, value.plays, value.yard, value.property, value.get("pool"))
	if resolver in [StadiumNpcPublicReport.RESOLVER, StadiumLongYardPublicReport.RESOLVER,
		StadiumGrandIPublicReport.RESOLVER, StadiumGrandIIPublicReport.RESOLVER,
		StadiumGrandIIIPublicReport.RESOLVER]:
		return StadiumNpcPublicContacts.evidence(
			value.surfaces, value.plays, value.yard, value.property)
	if resolver == StadiumNpcYardTwoReport.RESOLVER:
		return StadiumNpcYardTwoContacts.valid(value.surfaces, value.plays, value.property) \
			and StadiumNpcYardTwoContacts.provenance(value.yard, value.property)
	if resolver == StadiumNpcYardThreeReport.RESOLVER:
		return StadiumNpcYardThreeContacts.valid(value.surfaces, value.plays, value.property) \
			and StadiumNpcYardThreeContacts.provenance(value.yard, value.property)
	return false

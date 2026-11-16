class_name StadiumSurfaceNightHumanEvidence
extends RefCounted
## Actual managed PlayRecords and ordinary base flow; no synthetic AI releases.

const TIME_VERSION: int = 2
const VERSION: int = 1


static func expected(season: SeasonState, scheduled: Dictionary) -> bool:
	return StadiumSurfaceNightSnapshot.expected(season, scheduled)


static func ledger(season: SeasonState) -> ClubAssetLedger:
	return StadiumSurfaceNightSnapshot.ledger(season)


static func request_key(season: SeasonState, scheduled: Dictionary) -> String:
	if season.owned_surface_night.get("version") == StadiumSurfaceNightSnapshot.TIME_VERSION:
		return (
			JSON
			. stringify(
				{
					"family": "owned-surface-time-season-v2",
					"request": StadiumPoolOwnedHumanEvidence.request_key(season, scheduled),
					"policy": season.owned_surface_night
				},
				"",
				true,
				true
			)
			. sha256_text()
		)
	return (
		JSON
		. stringify(
			{
				"family": StadiumSurfaceNightSnapshot.FAMILY,
				"request": StadiumPoolOwnedHumanEvidence.request_key(season, scheduled),
				"policy": season.owned_surface_night
			},
			"",
			true,
			true
		)
		. sha256_text()
	)


static func capture(lab: PitchBatLab, season: SeasonState) -> Dictionary:
	if (
		season != null
		and season.owned_surface_night.get("version") == StadiumSurfaceNightSnapshot.TIME_VERSION
	):
		return _capture_time(lab, season)
	if (
		not is_instance_valid(lab)
		or season == null
		or lab._npc_season != season
		or not lab._managed_match
		or not lab._player_home
		or lab._match_state == null
	):
		return {}
	var scheduled: Dictionary = season.pending_fixture()
	var proof: Dictionary = StadiumSurfaceNightRuntime.capture_proof(lab)
	if proof.is_empty() or not expected(season, scheduled):
		return {}
	var state: MatchState = lab._match_state
	var teams: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		teams.append(
			team.roster.map(
				func(player: PlayerMatchState) -> String: return String(player.definition.id)
			)
		)
	var plays: Array = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		plays.append(
			{
				"play": index,
				"half": (play.inning - 1) * 2 + (0 if play.top_half else 1),
				"batter": String(play.batter_id),
				"pitcher": String(play.pitcher_id),
				"recipe": String(play.pitch_id),
				"contact": play.contact_outcome,
				"exit_speed": play.exit_speed_mps,
				"result": String(play.result),
				"balls": play.balls_before,
				"strikes": play.strikes_before,
				"outs": play.outs_before,
				"runs": play.runs_scored
			}
		)
	var result: Dictionary = {
		"version": VERSION,
		"fixture": scheduled.id,
		"request": request_key(season, scheduled),
		"property": StadiumSurfaceNightSnapshot.normalized(state.stadium),
		"away_runs": state.away_team.runs,
		"home_runs": state.home_team.runs,
		"performance": state.performance.snapshot(state),
		"teams": teams,
		"plays": plays,
		"base": state.base_flow.evidence(state),
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records),
		"night": proof
	}
	if not accepts(
		season,
		scheduled,
		result,
		state.away_team.runs,
		state.home_team.runs,
		result.performance,
		SeasonOpponentTactics.evidence(state, state.away_team)
	):
		return {}
	var decoded: Variant = JSON.parse_string(JSON.stringify(result, "", true, true))
	return result if valid(decoded) and ClubCareer.same(result, decoded) else {}


static func valid(value: Variant) -> bool:
	if (
		value is Dictionary
		and SeasonOwnership._whole(value.get("version"), TIME_VERSION, TIME_VERSION)
	):
		return _valid_time(value)
	if value is Dictionary and not StadiumSurfaceNightSnapshot.is_fixed(value.get("property")):
		return false
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value,
			[
				"version",
				"fixture",
				"request",
				"property",
				"away_runs",
				"home_runs",
				"performance",
				"teams",
				"plays",
				"base",
				"surfaces",
				"night"
			]
		)
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not SeasonOwnership._whole(value.fixture, 0, 31)
		or not StadiumSurfaceNightSnapshot._digest(value.request)
		or not value.property is Dictionary
		or not StadiumSurfaceNightSnapshot.valid(value.property)
		or value.property.binding.fixture != value.fixture
		or not StadiumSurfaceNightSnapshot.proof_valid(value.night, value.property)
		or not SeasonOwnership._whole(value.away_runs, 0, 9999)
		or not SeasonOwnership._whole(value.home_runs, 0, 9999)
		or value.away_runs == value.home_runs
		or not value.teams is Array
		or not value.performance is Dictionary
		or not value.plays is Array
		or value.plays.is_empty()
		or value.plays.size() > 9999
		or not PhysicalBaseFlow.valid(value.base, value.teams, value.performance)
	):
		return false
	return (
		value.base.final.away == value.away_runs
		and value.base.final.home == value.home_runs
		and StadiumPoolOwnedHumanEvidence._plays(value)
		and PhysicalStadiumContacts.valid(value.surfaces, value.plays, value.property)
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= 8 * 1024 * 1024
	)


static func accepts(
	season: SeasonState,
	scheduled: Dictionary,
	value: Variant,
	away: int,
	home: int,
	performance: Dictionary,
	ai_tactics: Dictionary
) -> bool:
	if not expected(season, scheduled):
		return value == null
	if (
		value is Dictionary
		and StadiumSurfaceNightSnapshot.is_wrapped(value.get("property"))
		and StadiumSurfaceNightSnapshot._wrapped_acceptance_owner(season)
	):
		return _accepts_wrapped(season, scheduled, value, away, home, performance, ai_tactics)
	if (
		not valid(value)
		or not StadiumSurfaceNightSnapshot.matches_fixture(
			value.property, season, scheduled, ledger(season)
		)
		or not ClubCareer.same(
			value.night,
			StadiumSurfaceNightSnapshot.proof(
				value.property, season.owned_surface_night, ledger(season)
			)
		)
		or value.fixture != scheduled.id
		or value.request != request_key(season, scheduled)
		or value.away_runs != away
		or value.home_runs != home
		or not ClubCareer.same(value.performance, performance)
		or not ClubCareer.same(value.base, ai_tactics.get("base"))
	):
		return false
	for index in range(2):
		var actual: Array = value.teams[index].duplicate()
		var required: Array = (
			season.teams[scheduled.away if index == 0 else scheduled.home].roster.duplicate()
		)
		actual.sort()
		required.sort()
		if not ClubCareer.same(actual, required):
			return false
	return true


static func pending_valid(season: SeasonState, human: Array) -> bool:
	if season != null and season._league_home_context.get("format") in [94, 95, 96]:
		return load("res://src/gameplay/season/league_home_result.gd").pending_valid(season, human)
	var scheduled: Dictionary = season.pending_fixture()
	return (
		SeasonRoundSettlement._night_shape({"human": human, "reports": []})
		and human[0] == scheduled.get("id")
		and (
			human[14]
			== StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, scheduled))
		)
		and accepts(season, scheduled, human[17], int(human[1]), int(human[2]), human[3], human[12])
	)


static func replay_result(
	season: SeasonState,
	result: Dictionary,
	performance: Dictionary,
	ai_tactics: Dictionary,
	replayed_tactics: Array,
	property_key: String
) -> bool:
	if not expected(season, season.pending_fixture()):
		return (
			not result.has("night_evidence")
			and StadiumNpcYardTwoHumanEvidence.replay_result(
				season, result, performance, ai_tactics, replayed_tactics, property_key
			)
		)
	var allowed: Array = (
		season.pending_fixture().keys()
		+ [
			"away_runs",
			"home_runs",
			"property",
			"performance",
			"club_roster",
			"used_gear",
			"tactics",
			"batting",
			"stances",
			"fielding",
			"pitching",
			"field_supply",
			"frozen",
			"ai_tactics",
			"night_evidence"
		]
	)
	for field: Variant in result:
		if not field is String or not allowed.has(field):
			return false
	if not result.get("night_evidence") is Dictionary:
		return false
	return season.record_surface_night_result(
		[
			int(result.id),
			int(result.away_runs),
			int(result.home_runs),
			performance,
			[],
			[],
			{},
			[],
			[],
			{},
			{},
			[],
			ai_tactics,
			replayed_tactics,
			property_key,
			null,
			null,
			result.night_evidence
		]
	)


static func _capture_time(lab: PitchBatLab, season: SeasonState) -> Dictionary:
	if (
		not is_instance_valid(lab)
		or season == null
		or lab._npc_season != season
		or not lab._managed_match
		or not lab._player_home
		or lab._match_state == null
	):
		return {}
	var scheduled: Dictionary = season.pending_fixture()
	var proof: Dictionary = StadiumSurfaceNightRuntime.capture_proof(lab)
	if proof.is_empty() or not expected(season, scheduled):
		return {}
	var state: MatchState = lab._match_state
	var teams: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		teams.append(
			team.roster.map(
				func(player: PlayerMatchState) -> String: return String(player.definition.id)
			)
		)
	var plays: Array = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		plays.append(
			{
				"play": index,
				"half": (play.inning - 1) * 2 + (0 if play.top_half else 1),
				"batter": String(play.batter_id),
				"pitcher": String(play.pitcher_id),
				"recipe": String(play.pitch_id),
				"contact": play.contact_outcome,
				"exit_speed": play.exit_speed_mps,
				"result": String(play.result),
				"balls": play.balls_before,
				"strikes": play.strikes_before,
				"outs": play.outs_before,
				"runs": play.runs_scored
			}
		)
	var result: Dictionary = {
		"version": TIME_VERSION,
		"fixture": scheduled.id,
		"request": request_key(season, scheduled),
		"property": StadiumSurfaceNightSnapshot.normalized(state.stadium),
		"away_runs": state.away_team.runs,
		"home_runs": state.home_team.runs,
		"performance": state.performance.snapshot(state),
		"teams": teams,
		"plays": plays,
		"base": state.base_flow.evidence(state),
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records),
		"night": proof
	}
	result["clock"] = StadiumSurfaceNightSnapshot.clock_evidence(
		result.property,
		result.plays,
		int(result.base.final.half) + (1 if int(result.base.final.outs) == 3 else 0)
	)
	if not accepts(
		season,
		scheduled,
		result,
		state.away_team.runs,
		state.home_team.runs,
		result.performance,
		SeasonOpponentTactics.evidence(state, state.away_team)
	):
		return {}
	var decoded: Variant = JSON.parse_string(JSON.stringify(result, "", true, true))
	return result if valid(decoded) and ClubCareer.same(result, decoded) else {}


static func _valid_time(value: Variant) -> bool:
	if (
		not value is Dictionary
		or not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value,
			[
				"version",
				"fixture",
				"request",
				"property",
				"away_runs",
				"home_runs",
				"performance",
				"teams",
				"plays",
				"base",
				"surfaces",
				"night",
				"clock"
			]
		)
		or not SeasonOwnership._whole(value.version, TIME_VERSION, TIME_VERSION)
		or not SeasonOwnership._whole(value.fixture, 0, 31)
		or not StadiumSurfaceNightSnapshot._digest(value.request)
		or not value.property is Dictionary
		or not SeasonOwnership._whole(
			value.property.get("version"),
			StadiumSurfaceNightSnapshot.TIME_FIXTURE_VERSION,
			StadiumSurfaceNightSnapshot.TIME_FIXTURE_VERSION
		)
		or not StadiumSurfaceNightSnapshot.valid(value.property)
		or value.property.binding.fixture != value.fixture
		or not StadiumSurfaceNightSnapshot.proof_valid(value.night, value.property)
		or not SeasonOwnership._whole(value.away_runs, 0, 9999)
		or not SeasonOwnership._whole(value.home_runs, 0, 9999)
		or value.away_runs == value.home_runs
		or not value.teams is Array
		or not value.performance is Dictionary
		or not value.plays is Array
		or value.plays.is_empty()
		or value.plays.size() > 9999
		or not PhysicalBaseFlow.valid(value.base, value.teams, value.performance)
	):
		return false
	return (
		value.base.final.away == value.away_runs
		and value.base.final.home == value.home_runs
		and StadiumSurfaceNightSnapshot.clock_valid(
			value.clock,
			value.property,
			value.plays,
			int(value.base.final.half) + (1 if int(value.base.final.outs) == 3 else 0)
		)
		and StadiumPoolOwnedHumanEvidence._plays(value)
		and PhysicalStadiumContacts.valid(value.surfaces, value.plays, value.property)
		and JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= 8 * 1024 * 1024
	)


# One fixed fixture36 acceptance. Contact and request validation deliberately stay
# cold and finish before the private snapshot admission exists. No context is
# returned here or retained on the season; each later acceptance starts over.
static func _accepts_wrapped(
	season: SeasonState,
	scheduled: Dictionary,
	value: Dictionary,
	away: int,
	home: int,
	performance: Dictionary,
	ai_tactics: Dictionary
) -> bool:
	# The same raw human/base/play predicates as valid(). Snapshot/proof predicates
	# are owned by the final private raw-input call, not caller-supplied permission.
	if (
		not StadiumNpcSnapshot._json_types(value)
		or not SeasonOwnership._keys(
			value,
			[
				"version",
				"fixture",
				"request",
				"property",
				"away_runs",
				"home_runs",
				"performance",
				"teams",
				"plays",
				"base",
				"surfaces",
				"night"
			]
		)
		or not SeasonOwnership._whole(value.version, VERSION, VERSION)
		or not SeasonOwnership._whole(value.fixture, 0, 31)
		or not StadiumSurfaceNightSnapshot._digest(value.request)
		or not StadiumSurfaceNightSnapshot.is_wrapped(value.property)
		or not value.property.get("binding") is Dictionary
		or value.property.binding.get("fixture") != value.fixture
		or not SeasonOwnership._whole(value.away_runs, 0, 9999)
		or not SeasonOwnership._whole(value.home_runs, 0, 9999)
		or value.away_runs == value.home_runs
		or not value.teams is Array
		or not value.performance is Dictionary
		or not value.plays is Array
		or value.plays.is_empty()
		or value.plays.size() > 9999
		or not PhysicalBaseFlow.valid(value.base, value.teams, value.performance)
	):
		return false
	if (
		value.base.final.away != value.away_runs
		or value.base.final.home != value.home_runs
		or not StadiumPoolOwnedHumanEvidence._plays(value)
		or not PhysicalStadiumContacts.valid(value.surfaces, value.plays, value.property)
		or JSON.stringify(value, "", true, true).to_utf8_buffer().size() > 8 * 1024 * 1024
	):
		return false
	# Validate the schedule before cold request_key() dereferences its team fields.
	# The private admission repeats this binding against its own expected snapshot.
	if (
		not SeasonOwnership._whole(scheduled.get("id"), 0, 32)
		or not ClubCareer.same(SeasonVenues.fixture_for_id(season, int(scheduled.id)), scheduled)
		or value.fixture != scheduled.id
		or value.away_runs != away
		or value.home_runs != home
		or not ClubCareer.same(value.performance, performance)
		or not ClubCareer.same(value.base, ai_tactics.get("base"))
	):
		return false
	# Proof refusal now follows the cold request. Guard every request/roster read
	# even when malformed proof and malformed season data arrive together.
	if (
		not SeasonOwnership._whole(scheduled.get("away"), 0, season.teams.size() - 1)
		or not SeasonOwnership._whole(scheduled.get("home"), 0, season.teams.size() - 1)
	):
		return false
	for club: int in [int(scheduled.away), int(scheduled.home)]:
		var roster: Variant = season.teams[club].get("roster")
		if not roster is Array:
			return false
		for player: Variant in roster:
			if not player is String:
				return false
	if value.request != request_key(season, scheduled):
		return false
	for index in range(2):
		var actual: Array = value.teams[index].duplicate()
		var required: Array = (
			season.teams[scheduled.away if index == 0 else scheduled.home].roster.duplicate()
		)
		actual.sort()
		required.sort()
		if not ClubCareer.same(actual, required):
			return false
	return StadiumSurfaceNightSnapshot._wrapped_accepts_human(
		value.property, value.night, season, scheduled
	)

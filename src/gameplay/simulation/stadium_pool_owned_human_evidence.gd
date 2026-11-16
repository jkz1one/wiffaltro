class_name StadiumPoolOwnedHumanEvidence
extends RefCounted
## Actual human PlayRecords and the existing base flow, without synthetic AI releases.
## Source hashes record provenance; expected fixture and paid journal grant authority.
# gdlint: disable=max-returns

const VERSION: int = 1
const MAX_JSON_BYTES: int = 8 * 1024 * 1024


static func expected(season: SeasonState, fixture: Dictionary) -> bool:
	return not fixture.is_empty() and fixture.get("home") == 0 \
		and not fixture.get("neutral", false) \
		and season.home_property.get("version") == StadiumPoolOwnedSnapshot.VERSION


static func ledger(season: SeasonState) -> ClubAssetLedger:
	if season._pool_replay_ledger == null and season.career == null:
		return null
	return season._pool_replay_ledger if season._pool_replay_ledger != null \
		else ClubPlayers.assets(season.career)


static func request_key(season: SeasonState, fixture: Dictionary) -> String:
	var teams: Array = []
	for index: int in [fixture.away, fixture.home]:
		var roster: Array = season.teams[index].roster.duplicate()
		roster.sort()
		teams.append(roster)
	return JSON.stringify({"version": VERSION, "fixture": fixture,
		"seed": SeasonPhysicalFixtures.seed_for(season, fixture), "teams": teams,
		"property": StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture))},
		"", true, true).sha256_text()


static func capture(lab: PitchBatLab, season: SeasonState,
	pitch_catalog: String = ""
) -> Dictionary:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return {}
	var fixture: Dictionary = season.pending_fixture()
	if lab == null or not lab.is_inside_tree() or lab._match_state == null \
		or not lab._player_home or not expected(season, fixture) \
		or lab._match_state.phase != MatchState.Phase.GAME_END:
		return {}
	var state: MatchState = lab._match_state
	var property: StadiumPoolOwnedProperty = StadiumPoolOwnedExtension.current(lab)
	var adapter: StadiumPoolControllerActive = lab.pool_controller_active
	if property == null or not property.valid_owner_full_ledger(lab) or adapter == null \
		or not property.owned_field_boundary_valid(lab) \
		or adapter._bound_profile != property or not adapter.enabled \
		or not adapter.freeflight_enabled or adapter.is_committing() \
		or not StadiumPoolOwnedSnapshot.matches(state.stadium, lab._stadium_ledger) \
		or not StadiumBoundaryRuntime.installed(lab, state.stadium):
		if property != null and property._owned_field_lease != null:
			property.revoke_owned_field("CAPTURE_OWNER_BOUNDARY_CHANGED")
		return {}
	var source: String = StadiumPoolPartyAssetIntegrity.source_sha256()
	if adapter._source != source or adapter._model != property.pool_model \
		or adapter._prepared == null or not adapter._prepared.valid(
			property.pool_model, StadiumPoolContract.LIVE, source):
		if property._owned_field_lease != null:
			property.revoke_owned_field("CAPTURE_PREPARATION_BOUNDARY_CHANGED")
		return {}
	var teams: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		teams.append(team.roster.map(func(player: PlayerMatchState) -> String:
			return String(player.definition.id)))
	var plays: Array = []
	var outcomes: Array = []
	for index in range(lab._play_records.size()):
		var play: PlayRecord = lab._play_records[index]
		plays.append({"play": index,
			"half": (play.inning - 1) * 2 + (0 if play.top_half else 1),
			"batter": String(play.batter_id), "pitcher": String(play.pitcher_id),
			"recipe": String(play.pitch_id), "contact": play.contact_outcome,
			"exit_speed": play.exit_speed_mps, "result": String(play.result),
			"balls": play.balls_before, "strikes": play.strikes_before,
			"outs": play.outs_before, "runs": play.runs_scored})
		if String(play.resolution_reason) in [
			StadiumPoolOwnedReport.WATER_DOUBLE, StadiumPoolOwnedReport.WATER_FOUL]:
			outcomes.append({"play": index, "reason": String(play.resolution_reason),
				"resolution_position": [play.resolution_position.x,
					play.resolution_position.y, play.resolution_position.z],
				"result_floor": play.result_floor,
				"last_defender_touch": String(play.last_defender_touch),
				"has_first_ground": play.has_first_ground, "result": String(play.result)})
	var evidence: Dictionary = {"version": VERSION, "fixture": fixture.id,
		"request": request_key(season, fixture),
		"property": StadiumPoolOwnedSnapshot.normalized(state.stadium),
		"away_runs": state.away_team.runs, "home_runs": state.home_team.runs,
		"performance": state.performance.snapshot(state), "teams": teams,
		"plays": plays, "base": state.base_flow.evidence(state),
		"surfaces": PhysicalStadiumContacts.capture(lab._play_records),
		"pool": {"version": VERSION, "copy": state.stadium.layout.pool.copy,
			"pose": StadiumPoolMatchReport._pose(property.admitted_pose()),
			"geometry": StadiumPoolOwnedLayout.signature(), "source_sha256": source,
			"water_commits": adapter.commits, "water_outcomes": outcomes}}
	var ai_tactics: Dictionary = SeasonOpponentTactics.evidence(state, state.away_team)
	if not accepts(season, fixture, evidence, state.away_team.runs,
		state.home_team.runs, evidence.performance, ai_tactics, pitch_catalog):
		return {}
	var decoded: Variant = JSON.parse_string(JSON.stringify(evidence, "", true, true))
	return evidence if valid(decoded, pitch_catalog) and ClubCareer.same(evidence, decoded) else {}


static func accepts(season: SeasonState, fixture: Dictionary, value: Variant,
	away: int, home: int, performance: Dictionary, ai_tactics: Dictionary,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	if not expected(season, fixture):
		return value == null
	if not valid(value, pitch_catalog) or not StadiumPoolOwnedSnapshot.matches(value.property, ledger(season)):
		return false
	var snapshot: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
	if value.fixture != fixture.id or value.request != request_key(season, fixture) \
		or StadiumPoolOwnedSnapshot.key(value.property) != StadiumPoolOwnedSnapshot.key(snapshot) \
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
	if season != null and season._league_home_context.get("format") in [91, 92, 93, 94]:
		return load("res://src/gameplay/season/league_home_result.gd").pending_valid(season, human)
	var fixture: Dictionary = season.pending_fixture()
	if not SeasonRoundSettlement._shape({"human": human, "reports": []}, true, true,
		expected(season, fixture)) or human[0] != fixture.get("id") \
		or human[14] != StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.for_fixture(season, fixture)):
		return false
	return accepts(season, fixture, human[15] if human.size() == 16 else null,
		int(human[1]), int(human[2]), human[3], human[12])


static func replay_result(season: SeasonState, result: Dictionary, performance: Dictionary,
	ai_tactics: Dictionary, replayed_tactics: Array, property_key: String) -> bool:
	var allowed: Array = season.pending_fixture().keys() + ["away_runs", "home_runs", "property",
		"performance", "club_roster", "used_gear", "tactics", "batting", "stances", "fielding",
		"pitching", "field_supply", "frozen", "ai_tactics", "pool_evidence"]
	for key: Variant in result:
		if not key is String or not allowed.has(key):
			return false
	var args: Array = [int(result.id), int(result.away_runs), int(result.home_runs), performance,
		[], [], {}, [], [], {}, {}, [], ai_tactics, replayed_tactics, property_key]
	if expected(season, season.pending_fixture()):
		if not result.get("pool_evidence") is Dictionary:
			return false
		args.append(result.pool_evidence)
	elif result.has("pool_evidence"):
		return false
	return season.callv("record_player_result", args)


static func valid(value: Variant,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "fixture",
		"request", "property", "away_runs", "home_runs", "performance", "teams", "plays",
		"base", "surfaces", "pool"]) or not SeasonOwnership._whole(value.version, VERSION, VERSION) \
		or not SeasonOwnership._whole(value.fixture, 0, 32) \
		or not StadiumPoolOwnedReport._digest_shape(value.request) \
		or not StadiumPoolOwnedSnapshot.valid(value.property) \
		or value.property.version != StadiumPoolOwnedSnapshot.FIXTURE_VERSION \
		or value.property.environment.fixture != value.fixture \
		or not SeasonOwnership._whole(value.away_runs, 0, 9999) \
		or not SeasonOwnership._whole(value.home_runs, 0, 9999) or value.away_runs == value.home_runs \
		or not value.teams is Array or not value.performance is Dictionary \
		or not value.plays is Array or value.plays.is_empty() or value.plays.size() > 9999 \
		or not value.surfaces is Array or value.surfaces.size() != value.plays.size() \
		or not PhysicalBaseFlow.valid(value.base, value.teams, value.performance):
		return false
	if value.base.final.away != value.away_runs or value.base.final.home != value.home_runs \
		or not _plays(value, pitch_catalog) or not _pool(value):
		return false
	return JSON.stringify(value, "", true, true).to_utf8_buffer().size() <= MAX_JSON_BYTES


static func _pool(value: Dictionary) -> bool:
	var pool: Variant = value.pool
	if not pool is Dictionary or not SeasonOwnership._keys(pool,
		["version", "copy", "pose", "geometry", "source_sha256", "water_commits", "water_outcomes"]) \
		or not SeasonOwnership._whole(pool.version, VERSION, VERSION) \
		or not pool.copy is String or pool.copy != value.property.layout.pool.copy \
		or pool.geometry != StadiumPoolOwnedLayout.signature() \
		or not StadiumPoolOwnedReport._source_hash(pool.source_sha256) \
		or not pool.water_outcomes is Array \
		or not SeasonOwnership._whole(pool.water_commits, 0, value.plays.size()) \
		or pool.water_commits != pool.water_outcomes.size():
		return false
	var pose: Transform3D = StadiumPoolOwnedLayout.pose(value.property.layout)
	if not ClubCareer.same(pool.pose, StadiumPoolMatchReport._pose(pose)):
		return false
	return StadiumPoolOwnedReport._rows(value.surfaces, value.plays, value.property,
		pool.copy, pool.water_outcomes, pose)


static func _plays(value: Dictionary,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	var counts: Dictionary = {}
	var completed: int = 0
	var balls: int = 0
	var strikes: int = 0
	for index in range(value.plays.size()):
		var row: Variant = value.plays[index]
		if not _play_shape_bound(row, index, pitch_catalog) or completed >= value.base.results.size():
			return false
		var ready: Dictionary = value.base.ready[completed]
		var result: Dictionary = value.base.results[completed]
		if row.half != ready.half or row.batter != ready.player \
			or not value.teams[1 - int(row.half) % 2].has(row.pitcher) \
			or row.balls != balls or row.strikes != strikes or row.outs != ready.outs:
			return false
		counts[row.pitcher] = counts.get(row.pitcher, 0) + 1
		var step: Dictionary = _step(row)
		if step.is_empty():
			return false
		if not step.outcome.is_empty():
			if step.outcome != result.outcome or row.pitcher != result.pitcher \
				or row.runs != (0 if step.outcome == "walk" else int(result.rbi)):
				return false
			completed += 1
		else:
			if row.runs != 0:
				return false
		balls = int(step.balls)
		strikes = int(step.strikes)
	if completed != value.base.results.size() or balls != 0 or strikes != 0:
		return false
	for id: String in value.performance:
		if value.performance[id].pitches != counts.get(id, 0):
			return false
	return true


static func _play_shape(row: Variant, index: int,
	pitch_catalog: String = ""
) -> bool:
	if not PhysicalPitchEvidence.context_valid(pitch_catalog):
		return false
	return _play_shape_bound(row, index, pitch_catalog)


## Context already checked once before iterating all recorded plays.
static func _play_shape_bound(row: Variant, index: int, pitch_catalog: String) -> bool:
	if not row is Dictionary or not SeasonOwnership._keys(row, ["play", "half", "batter",
		"pitcher", "recipe", "contact", "exit_speed", "result", "balls", "strikes", "outs", "runs"]):
		return false
	return SeasonOwnership._whole(row.play, index, index) \
		and SeasonOwnership._whole(row.half, 0, 19997) \
		and row.batter is String and row.pitcher is String and row.recipe is String \
		and PhysicalPitchEvidence._recipe(row.recipe, pitch_catalog) != null \
		and row.result is String and SeasonOwnership._whole(row.contact, -1, 3) \
		and PhysicalMatchReport.number(row.exit_speed, 0, 1000) \
		and SeasonOwnership._whole(row.balls, 0, MatchState.BALLS_FOR_WALK - 1) \
		and SeasonOwnership._whole(row.strikes, 0, MatchState.STRIKES_FOR_OUT - 1) \
		and SeasonOwnership._whole(row.outs, 0, MatchState.OUTS_PER_HALF - 1) \
		and SeasonOwnership._whole(row.runs, 0, 4)


static func _step(row: Dictionary) -> Dictionary:
	var balls: int = int(row.balls)
	var strikes: int = int(row.strikes)
	var outcome: String = ""
	if row.result in ["single", "double", "triple", "home_run", "out", "foul"]:
		if row.contact < ContactResult.Outcome.FOUL or row.exit_speed <= 0:
			return {}
		if row.result == "foul":
			strikes = mini(strikes + 1, MatchState.STRIKES_FOR_OUT - 1)
		else:
			outcome = "hr" if row.result == "home_run" else row.result
	elif row.result in ["strike", "strikeout", "swinging_strike"]:
		if row.contact > ContactResult.Outcome.MISS:
			return {}
		strikes += 1
		if strikes >= MatchState.STRIKES_FOR_OUT:
			outcome = "strikeout"
		if (row.result == "strikeout" and outcome.is_empty()) \
			or (row.result == "strike" and not outcome.is_empty()):
			return {}
	elif row.result in ["ball", "walk", "ball_no_crossing"]:
		if row.contact != -1:
			return {}
		balls += 1
		if balls >= MatchState.BALLS_FOR_WALK:
			outcome = "walk"
		if (row.result == "walk" and outcome.is_empty()) \
			or (row.result == "ball" and not outcome.is_empty()):
			return {}
	else:
		return {}
	return {"balls": balls if outcome.is_empty() else 0,
		"strikes": strikes if outcome.is_empty() else 0, "outcome": outcome}

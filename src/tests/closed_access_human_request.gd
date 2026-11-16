extends RefCounted
## Test-only ordinary, unowned human fixture adapter. Never changes production
## AI fixture keys, actors, outcomes, saved history, or validator behavior.
const AUTHORITY: String = "collector-playable-human-request-v1"


static func prepare(
	season: SeasonState, fixture: Dictionary, manifest: String, source_bytes: String
) -> Dictionary:
	if manifest.length() != 64 or not manifest.is_valid_hex_number(false):
		return {}
	if (
		season == null
		or season.career == null
		or season.build == null
		or season.physical == null
		or not season.physical.pending.is_empty()
		or season.pending_fixture() != fixture
		or not season.league_rules.is_empty()
		or not season.inventory_rules.is_empty()
		or not season.home_property.is_empty()
		or not season.npc_venues.is_empty()
		or not season.final_venue.is_empty()
		or not season.owned_surface_night.is_empty()
		or season.opponents == null
		or season.opponents._format != 13
		or (fixture.away != 0 and fixture.home != 0)
	):
		return {}
	if (
		season.build._freezer_start == null
		or season.build._sides_start == null
		or season.build._jump_start == null
		or season.build._sure_start == null
	):
		return {}
	var wallet: Dictionary = season.build._bank.view()
	if (
		not wallet.held.is_empty()
		or not wallet.sponsors.is_empty()
		or wallet.gear.values().any(func(value: Dictionary) -> bool: return not value.is_empty())
		or season.build._abilities.learned.values().any(
			func(value: Array) -> bool: return not value.is_empty()
		)
	):
		return {}  # This fixture does not certify inventory-rich human handoff.
	var before: Dictionary = SeasonSave.snapshot(season)
	var parsed: Variant = JSON.parse_string(source_bytes)
	if (
		before.is_empty()
		or not parsed is Dictionary
		or ClosedContentAccess.digest(parsed) != ClosedContentAccess.digest(before)
	):
		return {}
	var state: MatchState = season.make_match()
	if not roles_match(state, season, fixture):
		return {}
	var captured: MatchState = PhysicalMatchRequest.capture(state)
	if (
		not roles_match(captured, season, fixture)
		or not captured.stadium.is_empty()
		or not captured.league_rules.is_empty()
		or (
			ClosedContentAccess.digest(before)
			!= ClosedContentAccess.digest(SeasonSave.snapshot(season))
		)
	):
		return {}
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, season)
	if field == null:
		return {}
	var binding: Dictionary = {
		"version": 1,
		"authority": AUTHORITY,
		"source_manifest": manifest,
		"source_bytes_sha256": source_bytes.sha256_text(),
		"source_sha256": ClosedContentAccess.digest(before),
		"fixture": fixture.duplicate(true),
		"seed": SeasonPhysicalFixtures.seed_for(season, fixture),
		"field": String(field.id),
		"saved_roles": [season.starter_index, season.fielder_index],
		"output_contract":
		{"payload": "collector-human-terminal-v1", "diagnostics": "passive-playrecord-v1"},
		"request": describe(captured)
	}
	return {"state": captured, "binding": binding, "key": ClosedContentAccess.digest(binding)}


static func roles_match(state: MatchState, season: SeasonState, fixture: Dictionary) -> bool:
	if state == null or season == null or (fixture.away != 0 and fixture.home != 0):
		return false
	var human: TeamMatchState = state.home_team if fixture.home == 0 else state.away_team
	return (
		human != null
		and human.pitcher_index == season.starter_index
		and human.fielder_index == season.fielder_index
		and (
			human.roster.map(
				func(player: PlayerMatchState) -> String: return String(player.definition.id)
			)
			== season.teams[0].roster
		)
	)


static func describe(state: MatchState) -> Dictionary:
	var teams: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var players: Array = []
		for player: PlayerMatchState in team.roster:
			players.append(
				{
					"definition": SeasonPhysicalFixtures._resource(player.definition),
					"capacity": player.stamina_max,
					"initial": player.stamina_remaining,
					"batting_hand_override": player.batting_hand_override
				}
			)
		teams.append(
			{
				"name": team.display_name,
				"pitcher": team.pitcher_index,
				"fielder": team.fielder_index,
				"players": players,
				"ai_sponsor_choices": team.ai_sponsor_choices,
				"track_bases": team.track_bases,
				"ai_base": team.ai_base,
				"ai_budget": team.ai_budget.duplicate(true),
				"ai_heat": team.ai_heat,
				"ai_recovery_pitcher": team.ai_recovery_pitcher,
				"ai_tactical_hitter": team.ai_tactical_hitter,
				"ai_tactical_initial": team.ai_tactical_initial.duplicate(true),
				"copy_source": team.copy_source,
				"scouted_recipe": team.scouted_recipe,
				"tactics":
				{
					"held": team.tactics.held.duplicate(true),
					"insured_receipt": team.tactics.insured_receipt,
					"track_walks": team.tactics.track_walks
				},
				"field_supply":
				{
					"receipt": team.field_supply.receipt,
					"retired": team.field_supply.retired,
					"capacity": team.field_supply.capacity,
					"reserved": team.field_supply.reserved
				}
			}
		)
	return {
		"teams": teams,
		"stadium": state.stadium.duplicate(true),
		"league_rules": state.league_rules.duplicate(true),
		"equipped": state.gear_usage.equipped.duplicate(),
		"ai_tactical_quality": state.ai_tactical_quality,
		"optics_mode": state.optics_mode,
		"jumpstart_mode": state.jumpstart_mode,
		"cornerstone_anchored": state.cornerstone_anchored
	}


static func consistent(prepared: Dictionary) -> bool:
	if (
		not SeasonOwnership._keys(prepared, ["state", "binding", "key"])
		or not prepared.state is MatchState
		or not prepared.binding is Dictionary
		or not prepared.key is String
		or not prepared.binding.get("request") is Dictionary
		or prepared.binding.get("authority") != AUTHORITY
		or prepared.binding.get("version") != 1
		or prepared.key != ClosedContentAccess.digest(prepared.binding)
	):
		return false
	var captured: MatchState = PhysicalMatchRequest.capture(prepared.state)
	return (
		captured != null
		and (
			ClosedContentAccess.digest(describe(prepared.state))
			== ClosedContentAccess.digest(prepared.binding.request)
		)
		and (
			ClosedContentAccess.digest(describe(captured))
			== ClosedContentAccess.digest(prepared.binding.request)
		)
	)


static func anchor_matches(prepared: Dictionary, record: Dictionary, source_bytes: String) -> bool:
	if (
		not consistent(prepared)
		or not SeasonOwnership._keys(record, ["version", "authority", "source_file", "binding"])
		or record.version != 1
		or record.authority != AUTHORITY
		or not record.source_file is String
		or not record.source_file.begins_with("source-step-")
		or not record.source_file.ends_with(".json")
		or record.source_file.contains("/")
		or not record.binding is Dictionary
		or ClosedContentAccess.digest(record.binding) != prepared.key
		or source_bytes.to_utf8_buffer().size() > 8 * 1024 * 1024
		or source_bytes.sha256_text() != prepared.binding.source_bytes_sha256
	):
		return false
	var source: Variant = JSON.parse_string(source_bytes)
	return (
		source is Dictionary
		and ClosedContentAccess.digest(source) == prepared.binding.source_sha256
	)


static func matches(prepared: Dictionary, envelope: Dictionary) -> bool:
	if (
		not consistent(prepared)
		or not SeasonOwnership._keys(envelope, ["fixture", "request", "report"])
		or envelope.fixture != prepared.binding.fixture.id
		or envelope.request != prepared.key
		or not PhysicalMatchReport.valid(envelope.report)
	):
		return false
	var state: MatchState = prepared.state
	var report: Dictionary = envelope.report
	if (
		report.seed != prepared.binding.seed
		or report.field != prepared.binding.field
		or not PhysicalStadiumReport.matches(report, state.stadium)
		or not PhysicalChoiceEvidence.matches(report, state)
		or not PhysicalTacticalEvidence.report_matches(report, state)
		or not role_evidence_matches(state, prepared.binding.fixture, report)
	):
		return false
	var core: Dictionary = PhysicalStadiumReport.core(report)
	if core.is_empty():
		return false
	# Same ordered club/definition/workload admission as ordinary resolve; no
	# replacement of its AI resolver or use of its default-role request hash.
	for index in range(2):
		var team: TeamMatchState = state.away_team if index == 0 else state.home_team
		var evidence: Dictionary = core.teams[index]
		if evidence.name != team.display_name:
			return false
		for slot in range(4):
			var player: PlayerMatchState = team.roster[slot]
			var id: String = String(player.definition.id)
			if (
				evidence.roster[slot] != id
				or not ClubCareer.same(
					evidence.recipes[id],
					player.definition.starting_pitches.map(
						func(pitch: PitchDefinition) -> String: return String(pitch.id)
					)
				)
				or not ClubCareer.same(
					[evidence.workload[id].capacity, evidence.workload[id].initial],
					[player.stamina_max, player.stamina_remaining]
				)
			):
				return false
	return true


static func role_evidence_matches(
	state: MatchState, fixture: Dictionary, report: Dictionary
) -> bool:
	# This automated test request has full initial stamina and no manual role
	# inputs. Its first defensive release must use the captured starter.
	var side: int = 1 if fixture.home == 0 else 0
	var human: TeamMatchState = state.home_team if side == 1 else state.away_team
	for player: PlayerMatchState in human.roster:
		if not is_equal_approx(player.stamina_remaining, player.stamina_max):
			return false
	var pitcher: int = human.pitcher_index
	var primary: int = human.fielder_index
	var first: bool = true
	var roles_by_pa: Dictionary = {}
	for release: Dictionary in report.releases:
		if 1 - int(release.half) % 2 != side:
			continue
		var incoming: int = report.teams[side].roster.find(release.player)
		if incoming < 0 or (first and incoming != pitcher):
			return false
		first = false
		if incoming != pitcher:
			pitcher = incoming
			if primary == pitcher:
				primary = (primary + 1) % 4  # TeamMatchState.select_pitcher/cycle_fielder.
		var key: String = str(int(release.pa))
		var row: Array = [
			String(human.roster[pitcher].definition.id), String(human.roster[primary].definition.id)
		]
		if roles_by_pa.has(key) and roles_by_pa[key] != row:
			return false
		roles_by_pa[key] = row
	if first:
		return false
	for fielding: Dictionary in report.teams[side].fielding:
		var row: Array = roles_by_pa.get(str(int(fielding.pa)), [])
		if (
			row.size() != 2
			or fielding.pitcher != row[0]
			or fielding.player != (row[1] if fielding.primary else row[0])
		):
			return false
	return true


static func post_start_identity(prepared: Dictionary, lab: PitchBatLab) -> bool:
	# Startup may legitimately consume AI supplies and initialize state. Check
	# only immutable identity plus selected human roles, never reset live state.
	if (
		not consistent(prepared)
		or not is_instance_valid(lab)
		or lab._match_state == null
		or lab._automation == null
		or lab._automation.seed != prepared.binding.seed
		or String(lab._field_id) != prepared.binding.field
	):
		return false
	var live: MatchState = lab._match_state
	var original: MatchState = prepared.state
	for index in range(2):
		var actual: TeamMatchState = live.away_team if index == 0 else live.home_team
		var expected: TeamMatchState = original.away_team if index == 0 else original.home_team
		if (
			actual.display_name != expected.display_name
			or (
				actual.roster.map(
					func(player: PlayerMatchState) -> String: return String(player.definition.id)
				)
				!= expected.roster.map(
					func(player: PlayerMatchState) -> String: return String(player.definition.id)
				)
			)
		):
			return false
	var human: TeamMatchState = (
		live.home_team if prepared.binding.fixture.home == 0 else live.away_team
	)
	return (
		human.pitcher_index == prepared.binding.saved_roles[0]
		and human.fielder_index == prepared.binding.saved_roles[1]
	)


static func terminal_payload(season: SeasonState, fixture: Dictionary, lab: PitchBatLab) -> Array:
	if (
		not is_instance_valid(lab)
		or lab._match_state == null
		or lab._match_state.phase != MatchState.Phase.GAME_END
		or lab._automation == null
		or lab._automation.seed != SeasonPhysicalFixtures.seed_for(season, fixture)
	):
		return []
	var state: MatchState = lab._match_state
	var human: TeamMatchState = state.home_team if fixture.home == 0 else state.away_team
	var rival: TeamMatchState = state.away_team if fixture.home == 0 else state.home_team
	# Exact ordinary SeasonApp result fields. Never use the automated lab's
	# default _player_home, or infer missing terminal-only fields from a report.
	return (
		[
			fixture.id,
			state.away_team.runs,
			state.home_team.runs,
			state.performance.snapshot(state),
			state.gear_usage.first_pitch.duplicate(true),
			human.tactics.consumed.duplicate(true),
			state.cold.evidence(human) if season.build._freezer_start != null else {},
			state.sides.evidence(human) if season.build._sides_start != null else [],
			state.clean_outs.evidence(human) if season.build._jump_start != null else [],
			state.sure_shot.evidence(human) if season.build._sure_start != null else {},
			human.field_supply.evidence(),
			(
				state
				. frozen_contacts
				. filter(
					func(row: Dictionary) -> bool: return season.teams[0].roster.has(row.player)
				)
				. duplicate(true)
			),
			SeasonOpponentTactics.evidence(state, rival)
		]
		. duplicate(true)
	)


static func payload_matches(prepared: Dictionary, envelope: Dictionary, value: Dictionary) -> bool:
	if (
		not matches(prepared, envelope)
		or not SeasonOwnership._keys(
			value, ["version", "authority", "fixture", "request", "report_sha256", "human"]
		)
		or value.version != 1
		or value.authority != "collector-human-terminal-v1"
		or value.fixture != envelope.fixture
		or value.request != prepared.key
		or value.report_sha256 != ClosedContentAccess.digest(envelope.report)
		or not SeasonRoundSettlement._shape({"human": value.human, "reports": []}, true)
	):
		return false
	var report: Dictionary = envelope.report
	var side: int = 1 if prepared.binding.fixture.home == 0 else 0
	var team: Dictionary = report.teams[side]
	var payload: Array = value.human
	# Captured terminal-only fields are checked, not silently replaced with
	# empties. This narrow helper rejects any owned-content use outside scope.
	if (
		not payload[4].is_empty()
		or not payload[5].is_empty()
		or not payload[10].is_empty()
		or not payload[11].is_empty()
	):
		return false
	var fields: Dictionary = {
		0: envelope.fixture,
		1: report.away_runs,
		2: report.home_runs,
		3: report.performance,
		6: team.batting,
		7: team.stances,
		8: team.fielding,
		9: team.pitching,
		12: PhysicalBaseEvidence.enriched(report.tactics.teams[1 - side], report.tactics.base)
	}
	for index: int in fields:
		if not ClubCareer.same(payload[index], fields[index]):
			return false
	return true


static func artifacts_valid(
	prepared: Dictionary,
	marker: Dictionary,
	report: Dictionary,
	payload: Dictionary,
	diagnostics: Dictionary
) -> bool:
	if (
		not payload_matches(prepared, report, payload)
		or not SeasonOwnership._keys(
			marker, ["version", "fixture", "request", "seed", "attempt", "policy"]
		)
		or marker.version != 1
		or marker.fixture != prepared.binding.fixture.id
		or marker.request != prepared.key
		or marker.seed != prepared.binding.seed
		or marker.attempt != "started-or-uncertain"
		or marker.policy != AUTHORITY
		or not SeasonOwnership._keys(
			diagnostics, ["fixture", "request", "report_sha256", "diagnostics"]
		)
		or diagnostics.fixture != marker.fixture
		or diagnostics.request != prepared.key
		or diagnostics.report_sha256 != ClosedContentAccess.digest(report.report)
		or not diagnostics.diagnostics is Dictionary
	):
		return false
	var data: Dictionary = diagnostics.diagnostics
	return (
		SeasonOwnership._keys(
			data,
			["version", "authority", "limit", "truncated", "completed_records_seen", "records"]
		)
		and data.version == 1
		and data.authority == "passive-test-diagnostics-not-earnings"
		and data.limit == 512
		and data.truncated is bool
		and not data.truncated
		and data.records is Array
		and data.records.size() < 512
		and data.completed_records_seen == data.records.size()
		and data.records.size() == report.report.plays.size()
		and diagnostic_rows_match(data.records, report.report)
	)


static func diagnostic_rows_match(rows: Array, report: Dictionary) -> bool:
	# Passive data is not earnings authority, but require a complete well-shaped
	# ordered record set with every shared physical-report field matching.
	for index in range(rows.size()):
		var row: Variant = rows[index]
		var play: Dictionary = report.plays[index]
		if (
			not row is Dictionary
			or not SeasonOwnership._keys(
				row,
				[
					"play",
					"inning",
					"top_half",
					"batter",
					"pitcher",
					"role_observation",
					"contact",
					"launch_degrees",
					"exit_speed",
					"spray_degrees",
					"grounded",
					"last_touch",
					"result",
					"reason",
					"motion_samples"
				]
			)
			or not SeasonOwnership._whole(row.play, 0, 2147483647000)
			or not SeasonOwnership._whole(row.inning, 1, 9999)
			or not row.top_half is bool
			or not row.grounded is bool
			or not row.last_touch is String
			or not row.reason is String
			or not row.role_observation is Dictionary
			or not row.motion_samples is Dictionary
		):
			return false
		for field: String in ["launch_degrees", "exit_speed", "spray_degrees"]:
			if not (row[field] is int or row[field] is float) or not is_finite(row[field]):
				return false
		if (
			row.play != report.seed * 1000 + index + 1
			or (row.inning - 1) * 2 + (0 if row.top_half else 1) != play.half
		):
			return false
		for field: String in ["batter", "pitcher", "contact", "exit_speed", "result"]:
			if not ClubCareer.same(row[field], play[field]):
				return false
		var role: Dictionary = row.role_observation
		if (
			not SeasonOwnership._keys(role, ["primary", "anchor"])
			or not report.teams[1 - int(play.half) % 2].roster.has(role.primary)
			or not SeasonOwnership._whole(role.anchor, 0, 8)
		):
			return false
		var motion: Dictionary = row.motion_samples
		if not motion.is_empty():
			if (
				not SeasonOwnership._keys(
					motion,
					[
						"air_samples",
						"ground_samples",
						"min_air_distance",
						"max_air_height",
						"bobble_seen",
						"primary_attempts_max"
					]
				)
				or not motion.bobble_seen is bool
			):
				return false
			for field: String in ["air_samples", "ground_samples", "primary_attempts_max"]:
				if not SeasonOwnership._whole(motion[field], 0, 300000):
					return false
			for field: String in ["min_air_distance", "max_air_height"]:
				if (
					not (motion[field] is int or motion[field] is float)
					or not is_finite(motion[field])
					or motion[field] < 0.0
					or motion[field] > 1000000.0
				):
					return false
	return true

class_name SeasonPhysicalFixtures
extends RefCounted
## Versioned evidence archive. Historical score-only seasons never instantiate this.
# gdlint: disable=max-returns

var reports: Array[Dictionary] = []
var pending: Dictionary = {}
var cursor: int = 0
var needed: Dictionary = {}
var error: String = ""
var projecting: bool = false


func to_data() -> Dictionary:
	return {"version": 1, "reports": reports.duplicate(true), "pending": pending.duplicate(true)}


static func from_data(value: Variant) -> SeasonPhysicalFixtures:
	if not value is Dictionary or not SeasonOwnership._keys(value, ["version", "reports", "pending"]):
		return null
	if (value.version != 1 or not value.reports is Array or value.reports.size() > 23
		or not value.pending is Dictionary):
		return null
	var result: SeasonPhysicalFixtures = SeasonPhysicalFixtures.new()
	var ids: Array = []
	for row: Variant in value.reports:
		if not envelope(row) or ids.has(row.fixture):
			return null
		ids.append(row.fixture)
		result.reports.append(row.duplicate(true))
	result.pending = value.pending.duplicate(true)
	result.projecting = true
	return result


static func envelope(value: Variant) -> bool:
	return (value is Dictionary and SeasonOwnership._keys(value, ["fixture", "request", "report"])
		and SeasonOwnership._whole(value.fixture, 0, 32) and value.request is String
		and value.request.length() == 64 and PhysicalMatchReport.valid(value.report))


static func seed_for(season: SeasonState, fixture: Dictionary) -> int:
	return (season.season_seed + int(fixture.id) * 104729) & 0x7fffffff


static func match_for(season: SeasonState, fixture: Dictionary) -> MatchState:
	var state: MatchState = MatchState.create(
		season._make_team(int(fixture.away)), season._make_team(int(fixture.home)))
	state.ai_tactical_quality = clampf(
		0.15 + season.difficulty * 0.25 + minf(int(fixture.round), 9) * 0.025, 0.0, 1.0)
	return state


static func request_key(season: SeasonState, fixture: Dictionary) -> String:
	var state: MatchState = match_for(season, fixture)
	var rows: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var players: Array = []
		for player: PlayerMatchState in team.roster:
			players.append({"definition": _resource(player.definition),
				"capacity": player.stamina_max, "initial": player.stamina_remaining})
		var row: Dictionary = {"name": team.display_name, "pitcher": team.pitcher_index,
			"fielder": team.fielder_index, "players": players}
		if team.ai_sponsor_choices:
			row["choice_policy"] = 1
		if not team.ai_tactical_hitter.is_empty():
			row["batting_supplies"] = {"featured": team.ai_tactical_hitter,
				"held": team.ai_tactical_initial.duplicate(true)}
		if team.ai_heat:
			row["heat_policy"] = 1
		if not team.ai_recovery_pitcher.is_empty():
			row["recovery_policy"] = {"version": 1, "pitcher": team.ai_recovery_pitcher}
		rows.append(row)
	var resolver: String = PhysicalMatchReport.RECOVERY_RESOLVER if (
		not state.away_team.ai_recovery_pitcher.is_empty()
		or not state.home_team.ai_recovery_pitcher.is_empty()
	) else PhysicalMatchReport.HEAT_RESOLVER if (
		state.away_team.ai_heat or state.home_team.ai_heat
	) else PhysicalMatchReport.TACTICAL_RESOLVER if (
		not state.away_team.ai_tactical_hitter.is_empty()
		or not state.home_team.ai_tactical_hitter.is_empty()
	) else PhysicalMatchReport.CHOICE_RESOLVER if (
		state.away_team.ai_sponsor_choices or state.home_team.ai_sponsor_choices
	) else PhysicalMatchReport.RESOLVER
	return JSON.stringify({"resolver": resolver,
		"seed": seed_for(season, fixture), "field": String(SeasonState.field_for_fixture(fixture).id),
		"quality": state.ai_tactical_quality, "fixture": fixture, "teams": rows}, "", true, true
	).sha256_text()


func resolve(season: SeasonState, fixture: Dictionary) -> Dictionary:
	needed = {}
	if cursor >= reports.size():
		needed = fixture.duplicate(true)
		return {}
	var row: Dictionary = reports[cursor]
	if (row.fixture != fixture.id or row.request != request_key(season, fixture)
		or row.report.seed != seed_for(season, fixture)
		or row.report.field != String(SeasonState.field_for_fixture(fixture).id)):
		error = "Saved physical fixture does not match its scheduled clubs and committed build."
		return {}
	var state: MatchState = match_for(season, fixture)
	if not PhysicalChoiceEvidence.matches(row.report, state) \
		or not PhysicalTacticalEvidence.report_matches(row.report, state):
		error = "Saved physical choices do not match the committed sponsor policy."
		return {}
	for index in range(2):
		var team: TeamMatchState = state.away_team if index == 0 else state.home_team
		var evidence: Dictionary = row.report.teams[index]
		if evidence.name != team.display_name:
			return {}
		for slot in range(4):
			var player: PlayerMatchState = team.roster[slot]
			var id: String = String(player.definition.id)
			if (evidence.roster[slot] != id
				or not ClubCareer.same(evidence.recipes[id], player.definition.starting_pitches.map(
					func(pitch: PitchDefinition) -> String: return String(pitch.id)))
				or not ClubCareer.same([evidence.workload[id].capacity, evidence.workload[id].initial],
					[player.stamina_max, player.stamina_remaining])):
				return {}
	cursor += 1
	var result: Dictionary = fixture.duplicate(true)
	result["away_runs"] = int(row.report.away_runs)
	result["home_runs"] = int(row.report.home_runs)
	if season.opponents != null and season.opponents._format >= 7:
		result["performance"] = row.report.performance.duplicate(true)
	if season.opponents != null and season.opponents._format >= 9:
		result["ai_tactics"] = {}
		for index in range(2):
			result.ai_tactics[str(int(fixture.away if index == 0 else fixture.home))] = (
				row.report.tactics.teams[index].duplicate(true))
	return result


static func _resource(value: Variant) -> Variant:
	if value is Resource:
		var data: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE
				and int(property.usage) & PROPERTY_USAGE_STORAGE):
				data[property.name] = _resource(value.get(property.name))
		return data
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return _resource(item))
	if value is Dictionary:
		var data: Dictionary = {}
		for key: Variant in value:
			data[key] = _resource(value[key])
		return data
	if value is Vector3:
		return [value.x, value.y, value.z]
	return value

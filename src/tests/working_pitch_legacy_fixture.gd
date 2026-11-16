extends RefCounted
## Frozen60651b3 request shape; new PitchDefinition properties are absent in that source.
const OLD_PITCH_FIELDS: Array = [
	"id",
	"display_name",
	"tactical_description",
	"category",
	"rarity",
	"delivery_profile",
	"nominal_velocity_mps",
	"nominal_spin_rpm",
	"nominal_spin_axis_pitcher_frame",
	"nominal_hole_axis_ball_local",
	"perforation_influence",
	"instability_strength",
	"instability_frequency_hz",
	"control_difficulty",
	"execution_difficulty",
	"stamina_cost",
	"recognition_difficulty",
	"timing_difficulty",
	"mistake_punish",
	"tags",
	"mastery_level",
	"mastery_movement_scale",
	"mastery_late_bias",
	"mastery_noise_scale",
	"command_only_quality",
	"gear_command_scale",
]

static func request_key(season: SeasonState, fixture: Dictionary) -> String:
	var field: FieldDefinition = SeasonState.field_for_fixture(fixture, season)
	if field == null:
		return ""
	var state: MatchState = SeasonPhysicalFixtures.match_for(season, fixture)
	if state == null:
		return ""
	var rows: Array = []
	for team: TeamMatchState in [state.away_team, state.home_team]:
		var players: Array = []
		for player: PlayerMatchState in team.roster:
			players.append(
				{
					"definition": resource(player.definition),
					"capacity": player.stamina_max,
					"initial": player.stamina_remaining
				}
			)
		var row: Dictionary = {
			"name": team.display_name,
			"pitcher": team.pitcher_index,
			"fielder": team.fielder_index,
			"players": players
		}
		if team.ai_sponsor_choices:
			row["choice_policy"] = 1
		if not team.ai_tactical_hitter.is_empty():
			row["batting_supplies"] = {
				"featured": team.ai_tactical_hitter,
				"held": team.ai_tactical_initial.duplicate(true)
			}
		if team.ai_heat:
			row["heat_policy"] = 1
		if not team.ai_recovery_pitcher.is_empty():
			row["recovery_policy"] = {"version": 1, "pitcher": team.ai_recovery_pitcher}
		if team.ai_base:
			row["base_policy"] = 1
		if not team.ai_budget.is_empty():
			row["budget_policy"] = team.ai_budget.duplicate(true)
		if not state.league_rules.is_empty():
			row["league_ownership"] = team.league_ownership.duplicate(true)
			if LeagueRules.dynasty(state.league_rules):
				row["dynasty_start"] = team.dynasty_start.duplicate(true)
			if LeagueRules.doubleheader(state.league_rules):
				row["league_pair"] = team.league_pair.duplicate(true)
		rows.append(row)
	var resolver: String = (
		PhysicalMatchReport.BASE_RESOLVER
		if (state.away_team.ai_base or state.home_team.ai_base)
		else (
			PhysicalMatchReport.BUDGET_RESOLVER
			if (
				not state.away_team.ai_budget.is_empty() or not state.home_team.ai_budget.is_empty()
			)
			else (
				PhysicalMatchReport.RECOVERY_RESOLVER
				if (
					not state.away_team.ai_recovery_pitcher.is_empty()
					or not state.home_team.ai_recovery_pitcher.is_empty()
				)
				else (
					PhysicalMatchReport.HEAT_RESOLVER
					if (state.away_team.ai_heat or state.home_team.ai_heat)
					else (
						PhysicalMatchReport.TACTICAL_RESOLVER
						if (
							not state.away_team.ai_tactical_hitter.is_empty()
							or not state.home_team.ai_tactical_hitter.is_empty()
						)
						else (
							PhysicalMatchReport.CHOICE_RESOLVER
							if (
								state.away_team.ai_sponsor_choices
								or state.home_team.ai_sponsor_choices
							)
							else PhysicalMatchReport.RESOLVER
						)
					)
				)
			)
		)
	)
	var request: Dictionary = {
		"resolver": resolver,
		"seed": SeasonPhysicalFixtures.seed_for(season, fixture),
		"field": String(field.id),
		"quality": state.ai_tactical_quality,
		"fixture": fixture,
		"teams": rows
	}
	if not state.league_rules.is_empty():
		request["league_rules"] = state.league_rules.duplicate(true)
		request.resolver = (
			PhysicalDoubleheaderReport.RESOLVER
			if LeagueRules.doubleheader(state.league_rules)
			else PhysicalLeagueReport.RESOLVER
		)
	if not state.stadium.is_empty():
		if StadiumLayoutSnapshot.is_terrain(state.stadium):
			if (
				not StadiumLayoutSnapshot.terrain_valid(state.stadium)
				or state.stadium.version != StadiumLayoutSnapshot.TERRAIN_FIXTURE_VERSION
			):
				return ""
			request.resolver = PhysicalStadiumReport.TERRAIN_RESOLVER
		elif StadiumSurfaceNightSnapshot.is_family(state.stadium):
			request.resolver = StadiumSurfaceNightReport.RESOLVER
			if state.stadium.get("version") == StadiumSurfaceNightSnapshot.TIME_FIXTURE_VERSION:
				request.resolver = StadiumSurfaceNightReport.TIME_RESOLVER
			var proof: Dictionary = StadiumSurfaceNightSnapshot.proof(
				state.stadium,
				season.owned_surface_night,
				StadiumSurfaceNightSnapshot.ledger(season)
			)
			if proof.is_empty():
				return ""
			request["night"] = proof
		elif StadiumNpcSnapshot.is_public(state.stadium):
			request.resolver = PhysicalStadiumReport.npc_resolver(state.stadium)
			if request.resolver.is_empty():
				return ""
		else:
			request.resolver = (
				StadiumPoolOwnedReport.RESOLVER
				if (state.stadium.get("version") == StadiumPoolOwnedSnapshot.FIXTURE_VERSION)
				else PhysicalStadiumReport.RESOLVER
			)
		request["property"] = StadiumLayoutSnapshot.normalized(state.stadium)
	return JSON.stringify(request, "", true, true).sha256_text()


static func resource(value: Variant) -> Variant:
	if value is Resource:
		var data: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if value is PitchDefinition and property.name not in OLD_PITCH_FIELDS:
				continue
			if (
				int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE
				and int(property.usage) & PROPERTY_USAGE_STORAGE
			):
				data[property.name] = resource(value.get(property.name))
		return data
	if value is Array:
		return value.map(func(item: Variant) -> Variant: return resource(item))
	if value is Dictionary:
		var data: Dictionary = {}
		for key: Variant in value:
			data[key] = resource(value[key])
		return data
	if value is Vector3:
		return [value.x, value.y, value.z]
	return value

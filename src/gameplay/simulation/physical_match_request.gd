class_name PhysicalMatchRequest
extends RefCounted
## Snapshot only fresh matches; callers retain all original resources and state.
# gdlint: disable=max-returns


static func capture(source: MatchState) -> MatchState:
	if source == null or source.phase != MatchState.Phase.PRE_PITCH:
		return null
	if not is_finite(source.ai_tactical_quality) or source.ai_tactical_quality < 0.0 \
		or source.ai_tactical_quality > 1.0:
		return null
	if (source.inning != 1 or not source.top_half or source.plate_appearance_number != 1
		or source.balls != 0 or source.strikes != 0 or source.outs != 0
		or not source.between_batters or source.elapsed_seconds != 0.0
		or not source.performance.players.is_empty() or not source.sides.rows.is_empty()
		or not source.sure_shot.releases.is_empty() or not source.sure_shot.calls.is_empty()
		or not source.cold.appearances.is_empty() or not source.clean_outs.rows.is_empty()
		or not source.frozen_contacts.is_empty() or source.bases.occupied_count() != 0
		or source.gear_usage.started or not source.gear_usage.first_pitch.is_empty()):
		return null
	var away: TeamMatchState = _team(source.away_team)
	var home: TeamMatchState = _team(source.home_team)
	if away == null or home == null:
		return null
	var ids: Array = []
	for team: TeamMatchState in [away, home]:
		for player: PlayerMatchState in team.roster:
			if ids.has(player.definition.id):
				return null
			ids.append(player.definition.id)
	var result: MatchState = MatchState.create(away, home)
	result.away_team.field_supply.receipt = source.away_team.field_supply.receipt
	result.home_team.field_supply.receipt = source.home_team.field_supply.receipt
	result.gear_usage.equipped.assign(source.gear_usage.equipped.duplicate())
	result.ai_tactical_quality = source.ai_tactical_quality
	result.optics_mode = source.optics_mode
	result.jumpstart_mode = source.jumpstart_mode
	result.cornerstone_anchored = source.cornerstone_anchored
	return result


static func _team(source: TeamMatchState) -> TeamMatchState:
	if source == null or not source.is_valid_roster() or source.runs != 0:
		return null
	if (source.batting_index != 0 or source.pitcher_index not in range(4)
		or source.fielder_index not in range(4) or source.fielder_index == source.pitcher_index
		or not source.tactics.consumed.is_empty() or not source.field_supply.evidence().is_empty()
		or source.field_supply.clean != 0 or source.sure_shot_locked or source.encore_used
		or source.strikecraft_uses != 0 or source.strikecraft_refunded != 0.0):
		return null
	var definitions: Array[PlayerDefinition] = []
	for player: PlayerMatchState in source.roster:
		if (player == null or player.definition == null or player.definition.id.is_empty()
			or player.definition.starting_pitches.is_empty() or player.pitch_count != 0
			or player.pitching_finished or player.first_batter_completed
			or not is_finite(player.stamina_max) or player.stamina_max <= 0.0
			or not is_finite(player.stamina_remaining) or player.stamina_remaining < 0.0
			or player.stamina_remaining > player.stamina_max):
			return null
		definitions.append(player.definition.duplicate(true) as PlayerDefinition)
	var result: TeamMatchState = TeamMatchState.create(source.display_name, definitions)
	result.pitcher_index = source.pitcher_index
	result.fielder_index = source.fielder_index
	result.copy_source = source.copy_source
	result.scouted_recipe = source.scouted_recipe
	result.tactics.held.assign(source.tactics.held.duplicate(true))
	result.tactics.insured_receipt = source.tactics.insured_receipt
	result.tactics.track_walks = source.tactics.track_walks
	result.field_supply.capacity = source.field_supply.capacity
	result.field_supply.reserved = source.field_supply.reserved
	result.field_supply.receipt = source.field_supply.receipt
	for index in range(4):
		result.roster[index].stamina_max = source.roster[index].stamina_max
		result.roster[index].stamina_remaining = source.roster[index].stamina_remaining
		result.roster[index].batting_hand_override = source.roster[index].batting_hand_override
	return result

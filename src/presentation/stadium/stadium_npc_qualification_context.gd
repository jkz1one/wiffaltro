class_name StadiumNpcQualificationContext
extends RefCounted
## Explicit standalone qualification input. This is NOT saved-season assignment authority.
## The harness supplies these expectations independently of the envelope under test.

const FIELD: FieldDefinition = preload("res://src/content/fields/npc_venue_field.tres")
var _match: MatchState
var _field: FieldDefinition
var _seed: int
var _snapshot: Dictionary = {}
var _snapshot_key: String
var _state_bytes: PackedByteArray
var _field_bytes: PackedByteArray


static func create(state: MatchState, expected_binding: Dictionary,
	expected_environment: Dictionary, field: FieldDefinition,
	match_seed: int) -> StadiumNpcQualificationContext:
	if state == null or not exact_field(field) \
		or not expected_binding.get("venue_id") is String \
		or not SeasonOwnership._whole(expected_binding.get("venue_revision"), 2, 2) \
		or match_seed < 0 or match_seed > 2147483647 \
		or expected_binding.get("match_seed") != match_seed:
		return null
	var expected: Dictionary = StadiumNpcSnapshot.raw_fixture(
		StadiumNpcSnapshot.raw_entry(expected_binding.venue_id, 2),
		expected_binding, expected_environment)
	var key: String = StadiumNpcSnapshot.raw_envelope_key(expected)
	if key.is_empty() or StadiumNpcSnapshot.raw_envelope_key(state.stadium) != key:
		return null
	var result: StadiumNpcQualificationContext = StadiumNpcQualificationContext.new()
	result._match = state
	result._field = field
	result._seed = match_seed
	result._snapshot = expected.duplicate(true)
	result._snapshot_key = key
	result._state_bytes = var_to_bytes(state.stadium)
	result._field_bytes = var_to_bytes(_field_values(field))
	return result


static func exact_field(field: FieldDefinition) -> bool:
	var expected: Dictionary = StadiumNpcYardV1.FIELD.duplicate(true)
	expected.id = "field.npc_venue"
	expected.display_name = "NPC Venue"
	return field != null and field != FIELD and field.get_script() == FieldDefinition \
		and _field_values(field) == expected


static func _field_values(field: FieldDefinition) -> Dictionary:
	var result: Dictionary = {}
	for key: String in StadiumNpcYardV1.FIELD:
		var value: Variant = field.get(key)
		result[key] = String(value) if value is StringName else value
	return result


func matches(lab: PitchBatLab) -> bool:
	# Cheap exact per-frame guard, pinned only after full independent raw validation.
	return is_instance_valid(lab) and _match != null and lab._match_state == _match \
		and not _snapshot_key.is_empty() \
		and JSON.stringify(_snapshot, "", true, true).sha256_text() == _snapshot_key \
		and var_to_bytes(_match.stadium) == _state_bytes \
		and exact_field(_field) and var_to_bytes(_field_values(_field)) == _field_bytes \
		and _snapshot.get("binding") is Dictionary \
		and _snapshot.binding.get("match_seed") == _seed \
		and (lab._automation == null or lab._automation.seed == _seed)


func validated(lab: PitchBatLab) -> bool:
	# Hash fields only pin data; every trust boundary still requires complete public authority.
	if get_script() != StadiumNpcQualificationContext:
		return false
	var key: String = StadiumNpcSnapshot.raw_envelope_key(_snapshot)
	return not key.is_empty() and key == _snapshot_key and matches(lab) \
		and StadiumNpcSnapshot.raw_envelope_key(_match.stadium) == key


func same_fixture(other: StadiumNpcQualificationContext) -> bool:
	return other != null and get_script() == StadiumNpcQualificationContext \
		and other.get_script() == StadiumNpcQualificationContext \
		and StadiumNpcSnapshot.raw_envelope_key(_snapshot) == _snapshot_key \
		and not _snapshot_key.is_empty() \
		and other._snapshot_key == _snapshot_key and other._field == _field \
		and other._seed == _seed and other._field_bytes == _field_bytes


func fresh() -> bool:
	var state: MatchState = _match
	return state != null and state.phase == MatchState.Phase.PRE_PITCH \
		and state.inning == 1 and state.top_half and state.plate_appearance_number == 1 \
		and state.balls == 0 and state.strikes == 0 and state.outs == 0 \
		and state.between_batters and state.elapsed_seconds == 0.0 \
		and is_finite(state.ai_tactical_quality) and state.ai_tactical_quality >= 0.0 \
		and state.ai_tactical_quality <= 1.0 \
		and state.performance.players.is_empty() and state.sides.rows.is_empty() \
		and state.sure_shot.releases.is_empty() and state.sure_shot.calls.is_empty() \
		and state.cold.appearances.is_empty() and state.clean_outs.rows.is_empty() \
		and state.ai_choice_events.is_empty() and state._ai_choice_prepared.is_empty() \
		and state.base_flow.ready.is_empty() and state.base_flow.results.is_empty() \
		and state.base_flow.tags.is_empty() and state.base_flow.advances.is_empty() \
		and state.frozen_contacts.is_empty() and state.bases.occupied_count() == 0 \
		and not state.gear_usage.started and state.gear_usage.first_pitch.is_empty() \
		and _fresh_teams(state)


static func _fresh_teams(state: MatchState) -> bool:
	var away: TeamMatchState = PhysicalMatchRequest._team(state.away_team)
	var home: TeamMatchState = PhysicalMatchRequest._team(state.home_team)
	if away == null or home == null:
		return false
	var ids: Dictionary = {}
	for team: TeamMatchState in [away, home]:
		for player: PlayerMatchState in team.roster:
			if ids.has(player.definition.id):
				return false
			ids[player.definition.id] = true
	return true

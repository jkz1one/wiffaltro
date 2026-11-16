class_name SeasonState
extends RefCounted

# gdlint: disable=function-arguments-number
# Preserve positional result evidence for historical callers.

enum Phase { DRAFT, REGULAR, SEMIFINAL, FINAL, COMPLETE }

const SOURCE_OPERATIONS_1: GDScript = preload(
	"res://src/gameplay/season/season_state_operations_1.gd"
)

const SOURCE_OPERATIONS_2: GDScript = preload(
	"res://src/gameplay/season/season_state_operations_2.gd"
)

const TEAM_NAMES: Array[String] = ["Yard Club", "Rivets", "Kites", "Lanterns", "Comets", "Switches"]
const AWAY_FIELD_ID: StringName = &"field.commons_park"
const LEGACY_IDS: Array[String] = [
	"player.alex_finch",
	"player.ari_banks",
	"player.ash_cole",
	"player.cal_mercer",
	"player.dev_lin",
	"player.drew_sato",
	"player.eli_frost",
	"player.frankie_bell",
	"player.gray_west",
	"player.harper_fox",
	"player.indy_shaw",
	"player.jo_lane",
	"player.jules_moss",
	"player.kai_soto",
	"player.kit_rowan",
	"player.lee_stone",
	"player.mika_reed",
	"player.morgan_pike",
	"player.nico_vega",
	"player.noel_hart",
	"player.remy_cruz",
	"player.ren_ellis",
	"player.sam_park",
	"player.tess_vale"
]
var league_rules: Dictionary = {}
var inventory_rules: Dictionary = {}
var league_live: bool = false
var season_seed: int = 0
var phase: Phase = Phase.DRAFT
var round_index: int = 0
var draft_pool: Array[String] = []
var player_access: Array[String] = []
var home_property: Dictionary = {}
# Empty preserves the exact historical day path. New seasons opt in before checkpoint.
var owned_surface_night: Dictionary = {}
var npc_venues: Dictionary = {}
# Explicit qualification only; absence preserves the historical Commons final.
var final_venue: Dictionary = {}
var picks: Array[String] = []
var teams: Array[Dictionary] = []
var schedule: Array[Dictionary] = []
var results: Array[Dictionary] = []
var player_results: Array[Dictionary] = []
var playoff_seeds: Array[int] = []
var semifinals: Array[Dictionary] = []
var final_fixture: Dictionary = {}
var champion: int = -1
var starter_index: int = 0
var fielder_index: int = 1
var difficulty: int = 1
var ownership: SeasonOwnership = SeasonOwnership.new()
var build: SeasonBuild
var opponents: SeasonOpponents
var league_career: bool = false
var career: ClubCareer
var physical: SeasonPhysicalFixtures

var _dynasty_start: Dictionary = {}
var _closed_access: Dictionary = {}
# Runtime-only writer identity; never serialized into historical season payloads.
var _dynasty_owner_binding: Dictionary = {}
# Save83 binds a local closed session; shared Career28 stays in OwnerV2 only.
var _league_home_context: Dictionary = {}
var _standard_live_context: Dictionary = {}
var _standard_bound_grant: Dictionary = {}
var _dynasty_career_session: Dictionary = {}
var _heat_replay_team: TeamMatchState
var _doubleheader_replay_build: SeasonBuild
# Validated v60 paid journal available while disposable result replay precedes career restore.
var _pool_replay_ledger: ClubAssetLedger
# Saved real career run while disposable result replay precedes career restoration.
var _npc_replay_run: int = -1


static func field_for_fixture(fixture: Dictionary, season: SeasonState = null) -> FieldDefinition:
	return SOURCE_OPERATIONS_1._source_public_field_for_fixture(fixture, season)


static func create(
	seed_value: int,
	legacy: bool = false,
	working_progression: bool = false,
	paid_opponents: bool = false
) -> SeasonState:
	return SOURCE_OPERATIONS_1._source_public_create(seed_value, legacy, working_progression, \
		paid_opponents)


func league_context_consistent() -> bool:
	if _league_home_context.get("format") in [91, 92, 93, 94, 95, 96]:
		return load("res://src/gameplay/season/dynasty_league_home_live.gd").matches(self)
	if not _league_home_context.is_empty():
		return not load("res://src/gameplay/season/dynasty_league_home_save.gd").capture(self).is_empty()
	return SOURCE_OPERATIONS_1._source_public_league_context_consistent(self)


func _league_inventory_context_consistent() -> bool:
	return SOURCE_OPERATIONS_1._source_private_league_inventory_context_consistent(self)


func _league_opponent_context_consistent() -> bool:
	return SOURCE_OPERATIONS_1._source_private_league_opponent_context_consistent(self)


static func create_closed_league(
	seed_value: int, rules: Variant, live: bool = false, access_value: Dictionary = {}
) -> SeasonState:
	return SOURCE_OPERATIONS_1._source_public_create_closed_league(seed_value, rules, live, \
		access_value)


func _limit_specialist_offers() -> void:
	SOURCE_OPERATIONS_1._source_private_limit_specialist_offers(self)


func offers() -> Array[String]:
	return SOURCE_OPERATIONS_1._source_public_offers(self)


func choose_player(id: String) -> bool:
	return SOURCE_OPERATIONS_1._source_public_choose_player(self, id)


func _choose_player_remaining_checks(id: String) -> bool:
	return SOURCE_OPERATIONS_1._source_private_choose_player_remaining_checks(self, id)


func pending_fixture() -> Dictionary:
	return SOURCE_OPERATIONS_1._source_public_pending_fixture(self)


func academy_fixture_ready(fixture: Dictionary) -> bool:
	return SOURCE_OPERATIONS_1._source_public_academy_fixture_ready(self, fixture)


func make_match() -> MatchState:
	if not _league_home_context.is_empty() and _league_home_context.get("format") not in [91, 92, 93, 94, 95, 96]:
		return null
	return SOURCE_OPERATIONS_1._source_public_make_match(self)


func record_player_result(
	fixture_id: int,
	away_runs: int,
	home_runs: int,
	performance: Dictionary = {},
	used_gear: Array = [],
	tactics: Array = [],
	batting: Dictionary = {},
	stances: Array = [],
	fielding: Array = [],
	pitching: Dictionary = {},
	field_supply: Dictionary = {},
	frozen: Array = [],
	ai_tactics: Dictionary = {},
	replayed_tactics: Array = [],
	property_key: String = "",
	pool_evidence: Variant = null,
	yard_evidence: Variant = null
) -> bool:
	return SOURCE_OPERATIONS_1._source_public_record_player_result(self, fixture_id, away_runs, \
		home_runs, performance, used_gear, tactics, batting, stances, fielding, pitching, field_supply, \
		frozen, ai_tactics, replayed_tactics, property_key, pool_evidence, yard_evidence)


func record_inventory_result(human: Array) -> bool:
	return SOURCE_OPERATIONS_1._source_public_record_inventory_result(self, human)


func record_doubleheader_result(human: Array) -> bool:
	return SOURCE_OPERATIONS_1._source_public_record_doubleheader_result(self, human)


func record_surface_night_result(human: Array) -> bool:
	return SOURCE_OPERATIONS_1._source_public_record_surface_night_result(self, human)


func _record_player_result(
	fixture_id: int,
	away_runs: int,
	home_runs: int,
	performance: Dictionary = {},
	used_gear: Array = [],
	tactics: Array = [],
	batting: Dictionary = {},
	stances: Array = [],
	fielding: Array = [],
	pitching: Dictionary = {},
	field_supply: Dictionary = {},
	frozen: Array = [],
	ai_tactics: Dictionary = {},
	replayed_tactics: Array = [],
	property_key: String = "",
	pool_evidence: Variant = null,
	yard_evidence: Variant = null,
	night_evidence: Variant = null,
	doubleheader_evidence: Variant = null,
	replay_pitching: Dictionary = {},
	inventory_final: Variant = null,
	replay_doubleheader: bool = false
) -> bool:
	return SOURCE_OPERATIONS_1._source_private_record_player_result(self, fixture_id, away_runs, \
		home_runs, performance, used_gear, tactics, batting, stances, fielding, pitching, field_supply, \
		frozen, ai_tactics, replayed_tactics, property_key, pool_evidence, yard_evidence, \
		night_evidence, doubleheader_evidence, replay_pitching, inventory_final, replay_doubleheader)


func _validate_player_result(
	fixture_id: int,
	away_runs: int,
	home_runs: int,
	performance: Dictionary,
	used_gear: Array,
	tactics: Array,
	batting: Dictionary,
	stances: Array,
	fielding: Array,
	pitching: Dictionary,
	field_supply: Dictionary,
	frozen: Array,
	ai_tactics: Dictionary,
	replayed_tactics: Array,
	property_key: String,
	pool_evidence: Variant,
	yard_evidence: Variant,
	night_evidence: Variant,
	doubleheader_evidence: Variant,
	replay_pitching: Dictionary,
	inventory_final: Variant,
	doubleheader_replayed_prefix: SeasonBuild,
	fixture: Dictionary
) -> bool:
	return SOURCE_OPERATIONS_1._source_private_validate_player_result(self, fixture_id, away_runs, \
		home_runs, performance, used_gear, tactics, batting, stances, fielding, pitching, field_supply, \
		frozen, ai_tactics, replayed_tactics, property_key, pool_evidence, yard_evidence, \
		night_evidence, doubleheader_evidence, replay_pitching, inventory_final, \
		doubleheader_replayed_prefix, fixture)


func _commit_player_result(
	fixture_id: int,
	away_runs: int,
	home_runs: int,
	performance: Dictionary,
	used_gear: Array,
	tactics: Array,
	batting: Dictionary,
	stances: Array,
	fielding: Array,
	pitching: Dictionary,
	field_supply: Dictionary,
	frozen: Array,
	ai_tactics: Dictionary,
	replayed_tactics: Array,
	property_key: String,
	pool_evidence: Variant,
	yard_evidence: Variant,
	night_evidence: Variant,
	doubleheader_evidence: Variant,
	replay_pitching: Dictionary,
	inventory_final: Variant,
	fixture: Dictionary,
	pitching_current: Dictionary = {}
) -> bool:
	return SOURCE_OPERATIONS_2._source_private_commit_player_result(self, fixture_id, away_runs, \
		home_runs, performance, used_gear, tactics, batting, stances, fielding, pitching, field_supply, \
		frozen, ai_tactics, replayed_tactics, property_key, pool_evidence, yard_evidence, \
		night_evidence, doubleheader_evidence, replay_pitching, inventory_final, fixture, pitching_current)


func _finish_round(fixture_id: int, result: Dictionary) -> bool:
	if phase == Phase.REGULAR:
		for game in schedule:
			if game["round"] == round_index and game["id"] != fixture_id:
				var other: Dictionary = _simulate(game)
				if other.is_empty():
					return false
				results.append(other)
		if opponents != null:
			var played: Array = results.filter(
				func(row: Dictionary) -> bool: return row["round"] == round_index
			)
			var survivors: Array = [1, 2, 3, 4, 5]
			if round_index == 9:
				survivors = standings().slice(0, 4).map(
					func(row: Dictionary) -> int: return row.team
				)
			opponents.settle(played, survivors)
		round_index += 1
		if round_index == 10:
			if not _begin_playoffs():
				return false
	elif phase == Phase.SEMIFINAL:
		for game in semifinals:
			if game["id"] != fixture_id:
				var other: Dictionary = _simulate(game)
				if other.is_empty():
					return false
				results.append(other)
		_settle_semifinals()
		if not _prepare_final():
			return false
	else:
		if opponents != null:
			opponents.settle([result], [])
		champion = _winner(result)
		phase = Phase.COMPLETE
	return true


func standings() -> Array[Dictionary]:
	return SOURCE_OPERATIONS_2._source_public_standings(self)


func swap_batters(first: int, second: int) -> void:
	SOURCE_OPERATIONS_2._source_public_swap_batters(self, first, second)


func select_starter(index: int) -> void:
	SOURCE_OPERATIONS_2._source_public_select_starter(self, index)


func _build_schedule() -> void:
	SOURCE_OPERATIONS_2._source_private_build_schedule(self)


func _make_team(index: int, fixture_id: int = -1) -> TeamMatchState:
	return SOURCE_OPERATIONS_2._source_private_make_team(self, index, fixture_id)


func opposing_starter(fixture: Dictionary) -> String:
	return SOURCE_OPERATIONS_2._source_public_opposing_starter(self, fixture)


func player_definition(id: String) -> PlayerDefinition:
	return SOURCE_OPERATIONS_2._source_public_player_definition(self, id)


func cash() -> int:
	return SOURCE_OPERATIONS_2._source_public_cash(self)


func shop_available() -> bool:
	return SOURCE_OPERATIONS_2._source_public_shop_available(self)


func recruit_blocked() -> Array[String]:
	return SOURCE_OPERATIONS_2._source_public_recruit_blocked(self)


func adopt_build(next: SeasonBuild) -> void:
	SOURCE_OPERATIONS_2._source_public_adopt_build(self, next)


func _rank_before(a: Dictionary, b: Dictionary) -> bool:
	return SOURCE_OPERATIONS_2._source_private_rank_before(self, a, b)


func _begin_playoffs() -> bool:
	return SOURCE_OPERATIONS_2._source_private_begin_playoffs(self)


func _prepare_final() -> bool:
	var winners: Array[int] = []
	for game in results:
		if game["id"] in [30, 31]:
			winners.append(_winner(game))
	winners.sort_custom(
		func(a: int, b: int) -> bool: return playoff_seeds.find(a) < playoff_seeds.find(b)
	)
	final_fixture = {"id": 32, "round": 11, "home": winners[0], "away": winners[1], "neutral": true}
	phase = Phase.FINAL
	if not winners.has(0):
		var final_result: Dictionary = _simulate(final_fixture)
		if final_result.is_empty():
			return false
		results.append(final_result)
		if opponents != null:
			opponents.settle([final_result], [])
		champion = _winner(final_result)
		phase = Phase.COMPLETE
	return true


func _simulate(fixture: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_2._source_private_simulate(self, fixture)


func _strength(team: int) -> float:
	return SOURCE_OPERATIONS_2._source_private_strength(self, team)


static func _poisson(rng: RandomNumberGenerator, mean: float) -> int:
	return SOURCE_OPERATIONS_2._source_private_poisson(rng, mean)


static func _winner(result: Dictionary) -> int:
	return SOURCE_OPERATIONS_2._source_private_winner(result)


func _settle_semifinals() -> void:
	if opponents == null:
		return
	var played: Array = results.filter(func(row: Dictionary) -> bool: return row.id in [30, 31])
	var survivors: Array = played.map(func(row: Dictionary) -> int: return _winner(row))
	opponents.settle(played, survivors)

class_name ClubAssetLedger
extends RefCounted

const Journal = preload("res://src/gameplay/season/club_asset_journal.gd")

const PlayerPack = preload("res://src/gameplay/season/club_player_pack.gd")

const SOURCE_OPERATIONS_1: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_1.gd"
)

const SOURCE_OPERATIONS_2: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_2.gd"
)

const SOURCE_OPERATIONS_3: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_3.gd"
)

const SOURCE_OPERATIONS_4: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_4.gd"
)

const SOURCE_OPERATIONS_5: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_5.gd"
)

const SOURCE_OPERATIONS_6: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_6.gd"
)

const SOURCE_OPERATIONS_7: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_7.gd"
)

const SOURCE_OPERATIONS_8: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_8.gd"
)

const SOURCE_OPERATIONS_9: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_9.gd"
)

const SOURCE_OPERATIONS_10: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_10.gd"
)

const SOURCE_OPERATIONS_11: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_11.gd"
)

const SOURCE_OPERATIONS_12: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_12.gd"
)

const SOURCE_OPERATIONS_13: GDScript = preload(
	"res://src/gameplay/season/club_asset_ledger_operations_13.gd"
)

const AC02_PASSIVE_13 = preload("res://src/diagnostics/ac02_passive_attribution.gd")
## Permanent spending journal. Income is supplied by the validated career, never saved twice.
# gdlint: disable=max-returns

const VERSION: int = 23
const TERRAIN_VERSION: int = 24
const FLAG_VERSION: int = 25
const GROUND_PROPS_VERSION: int = 26
const PENNANT_VERSION: int = 28
const ROOF_VERSION: int = 29
const FACILITY_VERSION: int = 30
const BOUNDARY_VERSION: int = 31
const RECEIVER_VERSION: int = 32
const FLOODLIGHT_VERSION: int = 33
const LANDSCAPE_VERSION: int = 34
const LIVE_FURNISHING_VERSION: int = 35
const SMALL_YARD_SCENERY_VERSION: int = 36
const MOLDED_SEAT_VERSION: int = 37
const GROUND_BOX_VERSION: int = 38
const PRACTICE_FACILITY_VERSION: int = 39
const TREEHOUSE_VERSION: int = 40
const LANDMARK_VERSION: int = 41
const OUTFIELD_BLEACHER_VERSION: int = 42
const RISING_APPLE_VERSION: int = 43
const WALL_TOP_TERRACE_VERSION: int = 44
const PLAYER_TUNNEL_VERSION: int = 45
const MOUNTED_DISPLAY_VERSION: int = 46
const STRING_LIGHT_VERSION: int = 47
const SALVAGE_VERSION: int = 48
const MASTERY_VERSION: int = 49
const PLAQUE_VERSION: int = 50
const WATERFALL_VERSION: int = 51
const LIGHTING_KIT_VERSION: int = 52
const OUTFIELD_PLAZA_VERSION: int = 53
const LIVE_WATERFALL_VERSION: int = 54
const LOW_WALL_VERSION: int = 55
const WATERFALL_ANIMATION_VERSION: int = 56
const SALVAGE_ORIGIN_VERSION: int = 1
const SALVAGE_CLEAR_PRICE: int = 190
const STRAIGHT_VERSION: int = 27
const MAX_EVENTS: int = 4096
# Transient supported-writer generation. Never serialized or refreshed by an owner.
var _mutation_generation: int = 0
var _seed: int
var _credits: Array[int] = []
# Validated career reward authority, never serialized as a second achievement ledger.
var _championships: Dictionary = {}
var _progress: Array = []
var _land: String = "backyard"
var _valid: bool = false
var _loading: bool = false
var _events: Array[Dictionary] = []
var _requests: Dictionary = {}
var _pack_owned: Array[String] = []
var _pending: Dictionary = {}
var _spent: int = 0
var _opened: int = 0
var _through: int = 0
var _surface_origin: String = StadiumSurfaceProgression.LEGACY_ORIGIN
var _surface_owned: Array[String] = StadiumSurfaceProgression.initial(_surface_origin)
var _scoreboards: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
var _wall_pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
var _salvage_origin: Dictionary = {}
var _salvage_cleared: bool = false
var _stock: StadiumStock = StadiumStock.new_club()
var _stadium_draft: Dictionary = StadiumStarterLayout.empty()
var _stadium_active: Dictionary = StadiumStarterLayout.empty()


func _init(
	seed_value: int = 0, credits: Array = [], progress: Array = [], championships: Dictionary = {}
) -> void:
	_advance_mutation_generation()
	_seed = seed_value
	_valid = (
		seed_value >= 0
		and seed_value <= 2147483647
		and valid_credits(credits)
		and StadiumCareerProgress.valid(progress, credits)
		and StadiumPennantRewards.valid_awards(championships, credits)
	)
	if _valid:
		_championships = championships.duplicate(true)
		_progress = progress.duplicate(true)
		for credit: Variant in credits:
			_credits.append(int(credit))


static func new_club(
	seed_value: int = 0, credits: Array = [], progress: Array = [], championships: Dictionary = {}
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_1._source_public_new_club(seed_value, credits, progress, championships)


static func salvage_origin_record() -> Dictionary:
	return SOURCE_OPERATIONS_1._source_public_salvage_origin_record()


static func valid_salvage_origin(value: Variant) -> bool:
	return SOURCE_OPERATIONS_1._source_public_valid_salvage_origin(value)


static func salvage_origin_signature() -> String:
	return SOURCE_OPERATIONS_1._source_public_salvage_origin_signature()


func _initialize_salvage_origin() -> void:
	SOURCE_OPERATIONS_1._source_private_initialize_salvage_origin(self)


func _initialize_surface_origin(origin: String) -> void:
	SOURCE_OPERATIONS_1._source_private_initialize_surface_origin(self, origin)


func mutation_generation() -> int:
	return SOURCE_OPERATIONS_1._source_public_mutation_generation(self)


func _advance_mutation_generation() -> void:
	SOURCE_OPERATIONS_1._source_private_advance_mutation_generation(self)


func surface_owned() -> Array[String]:
	return SOURCE_OPERATIONS_1._source_public_surface_owned(self)


static func valid_credits(value: Variant) -> bool:
	return SOURCE_OPERATIONS_1._source_public_valid_credits(value)


func owned(earned: Array = []) -> Array[String]:
	return SOURCE_OPERATIONS_1._source_public_owned(self, earned)


func construction() -> StadiumStock:
	return SOURCE_OPERATIONS_1._source_public_construction(self)


func wall_pieces() -> StadiumWallPieceOwnership:
	return SOURCE_OPERATIONS_1._source_public_wall_pieces(self)


func scoreboards() -> StadiumScoreboardOwnership:
	return SOURCE_OPERATIONS_1._source_public_scoreboards(self)


func balance() -> int:
	return SOURCE_OPERATIONS_1._source_public_balance(self)


func revision() -> int:
	return SOURCE_OPERATIONS_1._source_public_revision(self)


func view() -> Dictionary:
	return SOURCE_OPERATIONS_1._source_public_view(self)


func to_data() -> Dictionary:
	return SOURCE_OPERATIONS_1._source_public_to_data(self)


static func from_data(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array = [],
	championships: Dictionary = {}
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_1._source_public_from_data(value, seed_value, credits, progress, \
		championships)


static func _ac02_passive_13_from_data(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array = [],
	championships: Dictionary = {}
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_2._source_private_ac02_passive_13_from_data(value, seed_value, credits, \
		progress, championships)


static func _restore_data_stage_2(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary,
	keys: Array
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_3._source_private_restore_data_stage_2(value, seed_value, credits, \
		progress, championships, keys)


static func _restore_data_stage_3(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary,
	keys: Array
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_4._source_private_restore_data_stage_3(value, seed_value, credits, \
		progress, championships, keys)


static func _restore_data_stage_4(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_5._source_private_restore_data_stage_4(value, seed_value, credits, \
		progress, championships)


static func _restore_data_stage_5(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_6._source_private_restore_data_stage_5(value, seed_value, credits, \
		progress, championships)


static func _restore_data_stage_6(
	value: Variant,
	seed_value: int,
	credits: Array,
	progress: Array,
	championships: Dictionary
) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_7._source_private_restore_data_stage_6(value, seed_value, credits, \
		progress, championships)


func fork() -> ClubAssetLedger:
	return SOURCE_OPERATIONS_7._source_public_fork(self)


func _ac02_passive_13_fork() -> ClubAssetLedger:
	return SOURCE_OPERATIONS_7._source_private_ac02_passive_13_fork(self)


func with_credits(credits: Array) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_7._source_public_with_credits(self, credits)


func preview(command: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_7._source_public_preview(self, command)


func commit(command: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_7._source_public_commit(self, command)


func _prepare(command: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_prepare(self, command)


# Owned Pool layout16 uses its own stock-bound validator; legacy layout gates stay exact.
# Layout15 remains admitted only to this pure journal; shared/runtime dispatch stays closed.
func _validate_layout(layout: Variant) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_validate_layout(self, layout)


func _layout_geometry(layout: Dictionary) -> String:
	return SOURCE_OPERATIONS_8._source_private_layout_geometry(self, layout)


func _open(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_open(self, event)


func _buy(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_buy(self, event)


func _buy_wall_piece(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_buy_wall_piece(self, event)


func _buy_scoreboard(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_buy_scoreboard(self, event)


func _buy_land(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_buy_land(self, event)


func _buy_style(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_buy_style(self, event)


func _buy_surface(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_8._source_private_buy_surface(self, event)


func prefix(length: int) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_8._source_public_prefix(self, length)


func _ac02_passive_13_prefix(length: int) -> ClubAssetLedger:
	return SOURCE_OPERATIONS_9._source_private_ac02_passive_13_prefix(self, length)


func _income(through: int) -> int:
	return SOURCE_OPERATIONS_9._source_private_income(self, through)


static func _error(message: String) -> Dictionary:
	return SOURCE_OPERATIONS_9._source_private_error(message)


static func _has_flag_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_9._source_private_has_flag_events(events)


static func _has_terrain_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_9._source_private_has_terrain_events(events)


static func _has_ground_props_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_10._source_private_has_ground_props_events(events)


static func _has_straight_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_10._source_private_has_straight_events(events)


func _award_pennant(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_10._source_private_award_pennant(self, event)


static func _has_pennant_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_10._source_private_has_pennant_events(events)


static func _has_roof_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_10._source_private_has_roof_events(events)


static func _has_facility_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_10._source_private_has_facility_events(events)


static func _has_boundary_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_11._source_private_has_boundary_events(events)


static func _has_receiver_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_11._source_private_has_receiver_events(events)


static func _has_floodlight_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_11._source_private_has_floodlight_events(events)


static func _has_landscape_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_11._source_private_has_landscape_events(events)


static func _has_live_furnishing_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_11._source_private_has_live_furnishing_events(events)


static func _has_small_yard_scenery_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_11._source_private_has_small_yard_scenery_events(events)


static func _has_molded_seat_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_molded_seat_events(events)


static func _has_ground_box_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_ground_box_events(events)


static func _has_practice_facility_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_practice_facility_events(events)


static func _has_treehouse_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_treehouse_events(events)


static func _has_landmark_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_landmark_events(events)


static func _has_outfield_bleacher_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_outfield_bleacher_events(events)


static func _has_rising_apple_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_rising_apple_events(events)


static func _has_wall_top_terrace_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_wall_top_terrace_events(events)


static func _has_player_tunnel_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_player_tunnel_events(events)


static func _has_mounted_display_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_mounted_display_events(events)


static func _has_string_light_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_string_light_events(events)


static func _has_salvage_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_salvage_events(events)


static func _fixed_salvage_present(layout: Dictionary) -> bool:
	return SOURCE_OPERATIONS_12._source_private_fixed_salvage_present(layout)


static func _without_salvage(layout: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_12._source_private_without_salvage(layout)


func _clear_salvage(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_12._source_private_clear_salvage(self, event)


static func _has_mastery_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_mastery_events(events)


static func _has_mastery_layout_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_12._source_private_has_mastery_layout_events(events)


func _award_plaque(event: Dictionary) -> Dictionary:
	return SOURCE_OPERATIONS_13._source_private_award_plaque(self, event)


static func _has_plaque_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_plaque_events(events)


static func _has_waterfall_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_waterfall_events(events)


static func _has_lighting_kit_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_lighting_kit_events(events)


static func _has_outfield_plaza_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_outfield_plaza_events(events)


static func _has_live_waterfall_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_live_waterfall_events(events)


static func _has_low_wall_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_low_wall_events(events)


static func _has_waterfall_animation_events(events: Variant) -> bool:
	return SOURCE_OPERATIONS_13._source_private_has_waterfall_animation_events(events)


func _pack_context() -> Dictionary:
	return {"seed": _seed, "credits": _credits, "spent": _spent, "through": _through,
		"opened": _opened, "pack_owned": _pack_owned, "pending": _pending, "loading": _loading}


func _apply_player_pack(prepared: Dictionary) -> void:
	var context: Dictionary = _pack_context()
	PlayerPack._apply_prepared(context, prepared)
	_spent = context.spent
	_through = context.through
	_opened = context.opened
	_pending = context.pending

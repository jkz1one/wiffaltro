class_name StadiumWaterfallAnimationIssuedInputs
extends RefCounted
## Exact47 post-admission adapter for retained45 or46. Original47 receipt is authority.
## Uses reviewed46 current-owner records; no family widening or projected receipt.
const VERSION: int = 1
var _rows: Array[Dictionary] = []
var _hot_rows: Array[Dictionary] = []
var _pending_fixture: Dictionary = {}
var _snapshot_ref: Dictionary = {}
var _career_assets: Dictionary = {}
var _career_runs: int = -1
var _lab: WeakRef
var _state: MatchState
var _paid: ClubAssetLedger
var _season: SeasonState
var _career: ClubCareer
var _replay: ClubAssetLedger
var _paid_resources: Array = []
var _replay_resources: Array = []
var _field: FieldDefinition
var _app: WeakRef
var _current: StadiumLowWallCurrentAuthority


func capture(lab: PitchBatLab, property: StadiumWaterfallAnimationProperty) -> bool:
	if (
		_lab != null
		or not is_instance_valid(lab)
		or lab.get_script() != PitchBatLab
		or property.get_script() != StadiumWaterfallAnimationProperty
		or property.animation_layout.get("animation_base") not in [45, 46]
		or not StadiumWaterfallAnimationSnapshot.matches(
			lab._match_state.stadium, lab._stadium_ledger
		)
	):
		return false
	_lab = weakref(lab)
	_state = lab._match_state
	_paid = lab._stadium_ledger
	_season = lab._npc_season
	if not is_instance_valid(_state) or not is_instance_valid(_paid):
		return false
	_snapshot_ref = _frozen_copy(_state.stadium)
	_state.stadium = _snapshot_ref
	_career = _season.career if _season != null else null
	_replay = _season._pool_replay_ledger if _season != null else null
	if _season != null:
		_pending_fixture = _frozen_copy(_season.pending_fixture())
	if _career != null:
		_career_assets = _career._assets
		_career_runs = _career.runs.size()
	_field = ContentDB.get_field(PitchBatLab.FIELD_ID)
	if _field == null or _field.get_script() != FieldDefinition:
		return false
	var specs: Array = []
	if lab.get_parent() is SeasonApp:
		var app: SeasonApp = lab.get_parent()
		if (
			app.get_script() != SeasonApp
			or _season == null
			or app.season != _season
			or not app._season_game
		):
			return false
		_app = weakref(app)
		specs.append([app, [&"season", &"_fixture_id", &"_season_game"]])
	return _capture_remaining_checks(property, specs)


func _capture_remaining_checks(property: StadiumWaterfallAnimationProperty, specs: Array) -> bool:
	for paid: ClubAssetLedger in [_paid, _replay]:
		if paid == null:
			continue
		var resources: Array = [
			paid._stock, paid._wall_pieces, paid._wall_pieces.stock, paid._scoreboards
		]
		resources.make_read_only()
		if not _ledger_identity(paid, resources):
			return false
		if paid == _paid:
			_paid_resources = resources
		else:
			_replay_resources = resources
		specs.append(
			[
				paid,
				[
					&"_mutation_generation",
					&"_seed",
					&"_credits",
					&"_championships",
					&"_progress",
					&"_land",
					&"_valid",
					&"_loading",
					&"_events",
					&"_requests",
					&"_pack_owned",
					&"_pending",
					&"_spent",
					&"_opened",
					&"_through",
					&"_surface_origin",
					&"_surface_owned",
					&"_salvage_origin",
					&"_salvage_cleared",
					&"_stadium_draft",
					&"_stadium_active"
				]
			]
		)
		specs.append([paid._stock, [&"starter", &"blueprints", &"styles", &"copies"]])
		specs.append([paid._scoreboards, [&"blueprints", &"copies"]])
		specs.append([paid._wall_pieces, [&"blueprints"]])
		specs.append([paid._wall_pieces.stock, [&"copies"]])
	if _season != null:
		if _season.get_script() != SeasonState:
			return false
		specs.append(
			[
				_season,
				[
					&"season_seed",
					&"_npc_replay_run",
					&"home_property",
					&"phase",
					&"round_index",
					&"schedule",
					&"semifinals",
					&"final_fixture",
					&"owned_surface_night"
				]
			]
		)
	if _career != null:
		if _career.get_script() != ClubCareer:
			return false
		specs.append([_career, [&"current", &"runs", &"_assets", &"_pennants", &"_plaques"]])
	specs.append([_state, [&"stadium"]])
	specs.append(
		[
			property,
			[&"animation_layout", &"base_layout", &"base_checked", &"_waterfall_animation_copies"]
		]
	)
	specs.append(
		[
			_field,
			[
				&"fair_half_angle_degrees",
				&"safe_hit_z_m",
				&"deep_air_z_m",
				&"back_wall_z_m",
				&"home_run_height_m",
				&"dead_ball_z_m",
				&"shallow_anchor_z_m",
				&"middle_anchor_z_m",
				&"middle_center_anchor_z_m",
				&"deep_anchor_z_m",
				&"side_anchor_x_m"
			]
		]
	)
	for spec: Array in specs:
		var object: Object = spec[0]
		if not is_instance_valid(object):
			return false
		var fields: Array = spec[1].duplicate()
		fields.make_read_only()
		var values: Array = []
		for field: StringName in fields:
			values.append(_frozen_copy(object.get(field)))
		values.make_read_only()
		var row: Dictionary = {
			"object": weakref(object),
			"script": object.get_script(),
			"fields": fields,
			"values": values
		}
		row.make_read_only()
		_rows.append(row)
		var hot_fields: Array = _hot_fields(object)
		var hot_values: Array = []
		for key: StringName in hot_fields:
			hot_values.append(_frozen_copy(object.get(key)))
		hot_fields.make_read_only()
		hot_values.make_read_only()
		var hot_row: Dictionary = {
			"object": weakref(object),
			"script": object.get_script(),
			"fields": hot_fields,
			"values": hot_values
		}
		hot_row.make_read_only()
		_hot_rows.append(hot_row)
	_rows.make_read_only()
	_hot_rows.make_read_only()
	_current = StadiumLowWallCurrentAuthority.capture(
		_paid, _replay, _season, _state, _snapshot_ref
	)
	return _current != null and intact(true)


func intact(deep: bool = false) -> bool:
	if _lab == null or _rows.is_empty():
		return false
	var lab: PitchBatLab = _lab.get_ref()
	if (
		not is_instance_valid(lab)
		or lab.get_script() != PitchBatLab
		or lab._match_state != _state
		or lab._stadium_ledger != _paid
		or lab._npc_season != _season
		or not _ledger_identity(_paid, _paid_resources)
		or ContentDB.get_field(PitchBatLab.FIELD_ID) != _field
	):
		return false
	if _current == null or not _current.intact() or not is_same(_state.stadium, _snapshot_ref):
		return false
	if _app != null:
		var app: SeasonApp = _app.get_ref()
		if not is_instance_valid(app) or lab.get_parent() != app or app.lab != lab:
			return false
	if (
		_season != null
		and (
			not is_instance_valid(_season)
			or _season.career != _career
			or _season._pool_replay_ledger != _replay
		)
	):
		return false
	return _intact_remaining_checks(deep)


func _intact_remaining_checks(deep: bool) -> bool:
	if _replay != null and not _ledger_identity(_replay, _replay_resources):
		return false
	if _season != null and _season.pending_fixture() != _pending_fixture:
		return false
	if (
		_career != null
		and (_career.runs.size() != _career_runs or not is_same(_career._assets, _career_assets))
	):
		return false
	for row: Dictionary in _rows if deep else _hot_rows:
		var object: Object = row.object.get_ref()
		if not is_instance_valid(object) or not is_same(object.get_script(), row.script):
			return false
		for index in range(row.fields.size()):
			var value: Variant = object.get(row.fields[index])
			var expected: Variant = row.values[index]
			if (
				typeof(value) != typeof(expected)
				or (not is_same(value, expected) if value is Object else value != expected)
			):
				return false
	return true


static func _frozen_copy(value: Variant) -> Variant:
	if value is Array:
		var result: Array = value.duplicate(true)
		for index in range(result.size()):
			result[index] = _frozen_copy(result[index])
		result.make_read_only()
		return result
	if value is Dictionary:
		var result: Dictionary = value.duplicate(true)
		for key: Variant in result:
			result[key] = _frozen_copy(result[key])
		result.make_read_only()
		return result
	return value


static func _ledger_identity(ledger: ClubAssetLedger, resources: Array) -> bool:
	return (
		is_instance_valid(ledger)
		and ledger.get_script() == ClubAssetLedger
		and resources.size() == 4
		and is_instance_valid(ledger._stock)
		and ledger._stock == resources[0]
		and ledger._stock.get_script() == StadiumStock
		and is_instance_valid(ledger._wall_pieces)
		and ledger._wall_pieces == resources[1]
		and ledger._wall_pieces.get_script() == StadiumWallPieceOwnership
		and is_instance_valid(ledger._wall_pieces.stock)
		and ledger._wall_pieces.stock == resources[2]
		and ledger._wall_pieces.stock.get_script() == StadiumWallPieceStock
		and is_instance_valid(ledger._scoreboards)
		and ledger._scoreboards == resources[3]
		and ledger._scoreboards.get_script() == StadiumScoreboardOwnership
	)


static func _hot_fields(object: Object) -> Array:
	# Dedicated current-authority helper handles paid/current career ownership.
	if object is SeasonApp:
		return [&"season", &"_fixture_id", &"_season_game"]
	if object is FieldDefinition:
		return [
			&"fair_half_angle_degrees",
			&"safe_hit_z_m",
			&"deep_air_z_m",
			&"back_wall_z_m",
			&"home_run_height_m",
			&"dead_ball_z_m",
			&"shallow_anchor_z_m",
			&"middle_anchor_z_m",
			&"middle_center_anchor_z_m",
			&"deep_anchor_z_m",
			&"side_anchor_x_m"
		]
	return []

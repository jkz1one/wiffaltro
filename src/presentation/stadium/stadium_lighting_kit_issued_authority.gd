class_name StadiumLightingKitIssuedAuthority
extends RefCounted
## Candidate3-only, post-admission authority seal. This does not grant admission.
## HOT: exact owners/scripts, supported-writer generations, current ledger scalars,
## flat credits/entitlements, current copy ownership, and current binding references.
## DEEP: callers still validate historical runs/events/reward proofs at transitions.
## Source containers remain mutable. Frozen rows are comparison records, not a claim
## that source aliases are immutable. In-place historical nested edits are not a hot
## guarantee; replacing their bound container or using a supported writer is detected.
## Policy/home/layout sources are shallow-bound; the independently deep-read-only
## issued receipt is the live presentation authority, with deep source reconciliation
## retained at transitions. Runtime still owns retirement/revocation and lab binding.

var _objects: Array[Dictionary] = []
var _containers: Array[Dictionary] = []
var _native_rows: Array[Dictionary] = []
var _flat_arrays: Array[Dictionary] = []
var _state: WeakRef
var _season: WeakRef
var _receipt: Dictionary = {}
var _pending: Dictionary = {}
var _pending_empty: bool = true
var _ready: bool = false


static func capture(
	paid: ClubAssetLedger,
	replay: ClubAssetLedger,
	season: SeasonState,
	state: MatchState,
	issued_receipt: Dictionary
) -> StadiumLightingKitIssuedAuthority:
	if (
		not _exact(season, SeasonState)
		or not _exact(state, MatchState)
		or issued_receipt.is_empty()
		or not is_same(state.stadium, issued_receipt)
		or not _deep_read_only(issued_receipt)
		or not is_same(season._pool_replay_ledger, replay)
	):
		return null
	var binding: Variant = issued_receipt.get("binding")
	if (
		not binding is Dictionary
		or typeof(binding.get("fixture")) != TYPE_INT
		or binding.get("season_seed") != season.season_seed
	):
		return null
	var result: StadiumLightingKitIssuedAuthority = StadiumLightingKitIssuedAuthority.new()
	result._state = weakref(state)
	result._season = weakref(season)
	result._receipt = issued_receipt
	if (
		not result._capture_ledger(paid)
		or (replay != null and not is_same(replay, paid) and not result._capture_ledger(replay))
		or not result._capture_season(season, int(binding.fixture))
	):
		return null
	result._add_object(state, [&"stadium"])
	result._objects.make_read_only()
	result._containers.make_read_only()
	result._native_rows.make_read_only()
	result._flat_arrays.make_read_only()
	result._ready = true
	return result if result.intact() else null


func intact() -> bool:
	# No replay, serialization, catalog reconstruction, or historical deep equality.
	if not _ready or get_script() != StadiumLightingKitIssuedAuthority:
		return false
	var state: Variant = _state.get_ref()
	var season: Variant = _season.get_ref()
	if (
		not _exact(state, MatchState)
		or not _exact(season, SeasonState)
		or not is_same(state.stadium, _receipt)
		or not _receipt.is_read_only()
	):
		return false
	for row: Dictionary in _objects:
		var source: Variant = row.source.get_ref()
		if not _exact(source, row.script):
			return false
		for index in range(row.fields.size()):
			if not _same_value(source.get(row.fields[index]), row.values[index], row.types[index]):
				return false
	return _intact_remaining_checks(season)


func _intact_remaining_checks(season: Variant) -> bool:
	for row: Dictionary in _flat_arrays:
		if row.source != row.expected:
			return false
	if not _container_rows_intact():
		return false
	# pending_fixture reads at most the finite schedule/semifinal rows and returns
	# the current source dictionary; it never reconstructs career or paid history.
	var pending: Dictionary = season.pending_fixture()
	return pending.is_empty() if _pending_empty else is_same(pending, _pending)


func _container_rows_intact() -> bool:
	# Native equality is shallow in this issued scope: every immediate nested
	# Array/Dictionary is checked by identity FIRST. Identical backing containers
	# return immediately in Godot recursive_equal, so historical contents are not
	# traversed. Current scalar values/types and all keys remain exact checks.
	for row: Dictionary in _native_rows:
		var source: Variant = row.source
		if source.size() != row.expected.size():
			return false
		for key: Variant in row.references:
			if row.dictionary and not source.has(key):
				return false
			if not is_same(source[key], row.references[key]):
				return false
		if row.expected != source:
			return false
	return _container_rows_intact_remaining_checks()


func _container_rows_intact_remaining_checks() -> bool:
	for row: Dictionary in _containers:
		var source: Variant = row.source
		if source.size() != row.count:
			return false
		for index in range(row.indices.size()):
			var key: Variant = row.indices[index]
			if source is Dictionary:
				if source.has(key) != row.present[index]:
					return false
				if not row.present[index]:
					continue
			if not _same_value(source[key], row.values[index], row.types[index]):
				return false
	return true


func _capture_ledger(paid: ClubAssetLedger) -> bool:
	if (
		not _exact(paid, ClubAssetLedger)
		or paid.mutation_generation() <= 0
		or not _exact(paid._stock, StadiumStock)
		or not _exact(paid._scoreboards, StadiumScoreboardOwnership)
		or not _exact(paid._wall_pieces, StadiumWallPieceOwnership)
		or not _exact(paid._wall_pieces.stock, StadiumWallPieceStock)
	):
		return false
	_add_object(
		paid,
		[
			&"_mutation_generation",
			&"_seed",
			&"_credits",
			&"_land",
			&"_valid",
			&"_loading",
			&"_spent",
			&"_opened",
			&"_through",
			&"_surface_origin",
			&"_surface_owned",
			&"_salvage_origin",
			&"_salvage_cleared",
			&"_pack_owned",
			&"_pending",
			&"_stock",
			&"_scoreboards",
			&"_wall_pieces",
			&"_stadium_draft",
			&"_stadium_active",
			&"_events",
			&"_requests",
			&"_progress",
			&"_championships"
		]
	)
	_add_flat_array(paid._credits)
	_add_flat_array(paid._surface_owned)
	_add_flat_array(paid._pack_owned)
	_add_dictionary(paid._pending)
	_add_dictionary(paid._salvage_origin)
	_add_dictionary(paid._stadium_draft)
	_add_dictionary(paid._stadium_active)
	_add_count(paid._events)
	_add_count(paid._requests)
	_add_count(paid._progress)
	_add_count(paid._championships)
	_add_object(paid._stock, [&"starter", &"blueprints", &"styles", &"copies"])
	_add_flat_array(paid._stock.blueprints)
	_add_flat_array(paid._stock.styles)
	if not _capture_copies(paid._stock.copies):
		return false
	_add_object(paid._scoreboards, [&"blueprints", &"copies"])
	_add_flat_array(paid._scoreboards.blueprints)
	if not _capture_copies(paid._scoreboards.copies):
		return false
	_add_object(paid._wall_pieces, [&"blueprints", &"stock"])
	_add_flat_array(paid._wall_pieces.blueprints)
	_add_object(paid._wall_pieces.stock, [&"copies"])
	return _capture_copies(paid._wall_pieces.stock.copies)


func _capture_copies(copies: Dictionary) -> bool:
	# Every current copy key, receipt identity and scalar ownership field is checked.
	# Nested earned/history payloads are reference-bound, not recursively replayed.
	_add_dictionary(copies)
	for key: Variant in copies:
		if not key is String or not copies[key] is Dictionary:
			return false
		_add_dictionary(copies[key])
	return true


func _capture_season(season: SeasonState, fixture_id: int) -> bool:
	_add_object(
		season,
		[
			&"season_seed",
			&"phase",
			&"round_index",
			&"_npc_replay_run",
			&"career",
			&"_pool_replay_ledger",
			&"home_property",
			&"owned_surface_night",
			&"schedule",
			&"semifinals",
			&"final_fixture"
		]
	)
	_add_dictionary(season.home_property)
	_add_dictionary(season.owned_surface_night)
	var candidate: Variant = season.owned_surface_night.get("candidate")
	if not candidate is Dictionary or not candidate.get("entry") is Dictionary:
		return false
	_add_dictionary(candidate)
	_add_dictionary(candidate.entry)
	# These arrays contain at most one season's fixtures, not career history.
	_add_array(season.schedule)
	_add_array(season.semifinals)
	_add_dictionary(season.final_fixture)
	var fixture: Dictionary = _fixture_source(season, fixture_id)
	if fixture.is_empty():
		return false
	_add_dictionary(fixture)
	_pending = season.pending_fixture()
	_pending_empty = _pending.is_empty()
	if not _pending_empty and not is_same(_pending, fixture):
		_add_dictionary(_pending)
	return season.career == null or _capture_career(season.career)


func _capture_career(career: ClubCareer) -> bool:
	if (
		not _exact(career, ClubCareer)
		or career.current < 0
		or (career.current > 0 and career.current != career.runs.size())
	):
		return false
	_add_object(career, [&"current", &"runs", &"_assets", &"_pennants", &"_plaques"])
	_add_count(career.runs)
	# command(), reward delivery and sync rollback replace this dictionary. Its
	# headers stay hot; the event array is only identity-bound here.
	_add_dictionary(career._assets)
	if career.current > 0:
		_add_selected(career.runs, [career.current - 1])
		# Current row scalar state and receipt/proof/progress identities remain hot.
		# No completed historical row or nested current proof is traversed.
		_add_dictionary(career.runs[career.current - 1])
	_add_dictionary(career._pennants)
	if not career._pennants.is_empty():
		var eras: Variant = career._pennants.get("eras")
		if not eras is Dictionary:
			return false
		var current_key: String = str(career.current)
		_add_selected(eras, [current_key])
		if eras.has(current_key):
			if not eras[current_key] is Dictionary:
				return false
			_add_dictionary(eras[current_key])
	_add_dictionary(career._plaques)
	if not career._plaques.is_empty():
		var records: Variant = career._plaques.get("records")
		if not records is Dictionary:
			return false
		# capture() only inserts new stable keys; deliver() replaces _assets.
		_add_count(records)
	return true


func _add_object(source: Object, fields: Array) -> void:
	var values: Array = []
	var types: Array = []
	for field: StringName in fields:
		var value: Variant = source.get(field)
		types.append(typeof(value))
		values.append(_pin(value))
	var names: Array = fields.duplicate()
	names.make_read_only()
	values.make_read_only()
	types.make_read_only()
	var row: Dictionary = {
		"source": weakref(source),
		"script": source.get_script(),
		"fields": names,
		"values": values,
		"types": types
	}
	row.make_read_only()
	_objects.append(row)


func _add_dictionary(source: Dictionary) -> void:
	if not _add_native_row(source):
		_add_selected(source, source.keys())


func _add_flat_array(source: Array) -> void:
	# Typed credit/entitlement arrays contain only primitive scalar values. Native
	# flat equality avoids a GDScript call per historical credit on each action.
	var expected: Array = source.duplicate()
	expected.make_read_only()
	var row: Dictionary = {"source": source, "expected": expected}
	row.make_read_only()
	_flat_arrays.append(row)


func _add_array(source: Array) -> void:
	if not _add_native_row(source):
		_add_selected(source, range(source.size()))


func _add_native_row(source: Variant) -> bool:
	# Only full rows with proven scalar semantics use native equality. Sparse
	# selected/history-count rows and Object/Callable/Signal/math/packed variants
	# retain the original comparator and WeakRef behavior. Source stays mutable.
	var dictionary: bool = source is Dictionary
	var keys: Array = source.keys() if dictionary else range(source.size())
	var references: Dictionary = {}
	for key: Variant in keys:
		if (
			dictionary
			and typeof(key) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING, TYPE_STRING_NAME]
		):
			return false
		var value: Variant = source[key]
		var kind: int = typeof(value)
		if kind == TYPE_ARRAY or kind == TYPE_DICTIONARY:
			references[key] = value
		elif kind not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]:
			return false
		elif kind == TYPE_FLOAT and is_nan(value):
			return false
	var expected: Variant = source.duplicate(false)
	expected.make_read_only()
	references.make_read_only()
	var row: Dictionary = {
		"source": source, "expected": expected, "dictionary": dictionary, "references": references
	}
	row.make_read_only()
	_native_rows.append(row)
	return true


func _add_count(source: Variant) -> void:
	_add_selected(source, [])


func _add_selected(source: Variant, keys: Array) -> void:
	var names: Array = keys.duplicate()
	var values: Array = []
	var types: Array = []
	var present: Array = []
	for key: Variant in names:
		var exists: bool = source.has(key) if source is Dictionary else true
		var value: Variant = source[key] if exists else null
		present.append(exists)
		types.append(typeof(value))
		values.append(_pin(value))
	names.make_read_only()
	values.make_read_only()
	types.make_read_only()
	present.make_read_only()
	var row: Dictionary = {
		"source": source,
		"count": source.size(),
		"indices": names,
		"values": values,
		"types": types,
		"present": present
	}
	row.make_read_only()
	_containers.append(row)


static func _pin(value: Variant) -> Variant:
	return weakref(value) if value is Object and is_instance_valid(value) else value


static func _same_value(value: Variant, pinned: Variant, kind: int) -> bool:
	if typeof(value) != kind:
		return false
	if kind == TYPE_OBJECT:
		return pinned is WeakRef and is_instance_valid(value) and is_same(value, pinned.get_ref())
	if kind == TYPE_ARRAY or kind == TYPE_DICTIONARY:
		return is_same(value, pinned)
	return value == pinned


static func _exact(value: Variant, script: Script) -> bool:
	return is_instance_valid(value) and value is Object and value.get_script() == script


static func _deep_read_only(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value is Dictionary:
		if not value.is_read_only():
			return false
		for key: Variant in value:
			if not _deep_read_only(key, depth + 1) or not _deep_read_only(value[key], depth + 1):
				return false
	elif value is Array:
		if not value.is_read_only():
			return false
		for child: Variant in value:
			if not _deep_read_only(child, depth + 1):
				return false
	elif typeof(value) in [TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL]:
		return false
	return true


static func _fixture_source(season: SeasonState, id: int) -> Dictionary:
	if id >= 0 and id < 30:
		for row: Dictionary in season.schedule:
			if row.get("id", -1) == id:
				return row
	elif id >= 30 and id < 32:
		for row: Dictionary in season.semifinals:
			if row.get("id", -1) == id:
				return row
	elif id == 32 and season.final_fixture.get("id", -1) == id:
		return season.final_fixture
	return {}

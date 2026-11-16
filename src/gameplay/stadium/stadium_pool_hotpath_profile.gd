class_name StadiumPoolHotpathProfile
extends RefCounted
## Opt-in diagnostic only. Default absent; no listeners, caches or gameplay predicates.
## Inclusive spans overlap; exclusive time subtracts immediate measured children.
## Probe overhead is present. Phase is sampled at entry, never reevaluated at exit.
# gdlint: disable=max-public-methods

const SCHEMA: String = "POOL-OWNED-HOTPATH-v29"
const MAX_ENTRIES: int = 8000000
const MAX_DEPTH: int = 64
const MAX_SPAN_USEC: int = 3600000000
const MAX_CHECKPOINT_REASON_CHARS: int = 128
const PHASES: Array[String] = ["pre_pitch", "live", "dead"]
const SITES: Array[String] = [
	"property.valid_owner", "authority.valid_for", "authority._ledger_state",
	"property.ground_matches", "property._boundary_geometry", "property._static_inventory",
	"guard.route", "guard._route_sample", "guard.valid", "adapter._sample",
	"controller.try_resolve", "adapter._owned", "adapter._profile_valid",
	"adapter._connections_exact", "adapter._owned_tree", "interior.valid",
	"interior._node_identities", "preparation.valid", "asset.snapshot", "var_to_bytes"
]
const PROPERTY_OWNER: int = 0
const AUTHORITY_VALID: int = 1
const LEDGER_STATE: int = 2
const GROUND_MATCHES: int = 3
const BOUNDARY_GEOMETRY: int = 4
const STATIC_INVENTORY: int = 5
const GUARD_ROUTE: int = 6
const GUARD_SAMPLE: int = 7
const GUARD_VALID: int = 8
const ADAPTER_SAMPLE: int = 9
const CONTROLLER_RESOLVE: int = 10
const ADAPTER_OWNED: int = 11
const PROFILE_VALID: int = 12
const CONNECTIONS_EXACT: int = 13
const OWNED_TREE: int = 14
const INTERIOR_VALID: int = 15
const NODE_IDENTITIES: int = 16
const PREPARATION_VALID: int = 17
const ASSET_SNAPSHOT: int = 18
const SERIALIZE: int = 19

static var active: StadiumPoolHotpathProfile = null
static var _session_started: bool = false
var _state: MatchState
var _rows: Array[Dictionary] = []
var _stack: Array[Dictionary] = []
var _errors: Array[String] = []
var _collecting: bool = true
var _started_usec: int = 0
var _entries: int = 0
var _completed: int = 0
var _max_depth: int = 0
var _root_spans: int = 0
var _root_usec: int = 0


static func start_session(state: MatchState) -> bool:
	# One explicit session per process. Ordinary gameplay never calls this API.
	if active != null or _session_started or state == null:
		return false
	var profile: StadiumPoolHotpathProfile = StadiumPoolHotpathProfile.new()
	profile._state = state
	for phase: String in PHASES:
		for site: String in SITES:
			profile._rows.append({
				"phase": phase, "site": site, "calls": 0, "completed": 0,
				"inclusive_usec": 0, "exclusive_usec": 0, "min_usec": 0, "max_usec": 0,
				"owner_checks": 0, "owner_checks_after_first": 0, "returned_false": 0
			})
	profile._started_usec = Time.get_ticks_usec()
	_session_started = true
	active = profile
	return true


static func checkpoint(reason: String) -> Dictionary:
	# No counter, collection, active-session or stack mutation, even on rejection.
	if active == null or reason.length() > MAX_CHECKPOINT_REASON_CHARS:
		return {}
	return active._checkpoint(reason)


static func finish_session(reason: String) -> Dictionary:
	if active == null:
		return {}
	var profile: StadiumPoolHotpathProfile = active
	active = null
	return profile._finish(reason)


static func serialize(value: Variant) -> PackedByteArray:
	# Arguments are evaluated by the original caller before entering serialization.
	if active == null:
		return var_to_bytes(value)
	var profile: StadiumPoolHotpathProfile = active
	var token: int = profile.enter(SERIALIZE)
	var result: PackedByteArray = var_to_bytes(value)
	profile.leave(token)
	return result


func enter(site: int) -> int:
	if not _collecting:
		return -1
	var started: int = Time.get_ticks_usec()
	if site < 0 or site >= SITES.size():
		_fault("UNKNOWN_SITE")
		return -1
	if _entries >= MAX_ENTRIES:
		_fault("ENTRY_LIMIT")
		return -1
	if _stack.size() >= MAX_DEPTH:
		_fault("DEPTH_LIMIT")
		return -1
	var phase: int = _phase_index()
	if phase < 0:
		_fault("UNKNOWN_PHASE")
		return -1
	_entries += 1
	var row_index: int = phase * SITES.size() + site
	_rows[row_index].calls += 1
	if site == PROPERTY_OWNER:
		for frame: Dictionary in _stack:
			frame.owner_checks += 1
	_stack.append({
		"token": _entries, "row": row_index, "start": started, "child_usec": 0,
		"owner_checks": 1 if site == PROPERTY_OWNER else 0
	})
	_max_depth = maxi(_max_depth, _stack.size())
	return _entries


func leave(token: int, result: Variant = null) -> void:
	if token < 0:
		return
	var stopped: int = Time.get_ticks_usec()
	if _stack.is_empty() or _stack.back().token != token:
		_fault("UNBALANCED_STACK")
		return
	var frame: Dictionary = _stack.pop_back()
	var elapsed: int = stopped - int(frame.start)
	if elapsed < 0 or elapsed > MAX_SPAN_USEC or int(frame.child_usec) > elapsed:
		_fault("CLOCK_RANGE")
		elapsed = 0
		frame.child_usec = 0
	var row: Dictionary = _rows[int(frame.row)]
	row.completed += 1
	row.inclusive_usec += elapsed
	row.exclusive_usec += elapsed - int(frame.child_usec)
	row.min_usec = elapsed if int(row.completed) == 1 else mini(int(row.min_usec), elapsed)
	row.max_usec = maxi(int(row.max_usec), elapsed)
	row.owner_checks += int(frame.owner_checks)
	row.owner_checks_after_first += maxi(0, int(frame.owner_checks) - 1)
	if result is bool and not result:
		row.returned_false += 1
	_completed += 1
	if _stack.is_empty():
		_root_spans += 1
		_root_usec += elapsed
	else:
		_stack.back().child_usec += elapsed


func _phase_index() -> int:
	# This read labels observations only. It does not validate or change match state.
	match _state.phase:
		MatchState.Phase.PRE_PITCH:
			return 0
		MatchState.Phase.PITCH_IN_FLIGHT, MatchState.Phase.BALL_IN_PLAY:
			return 1
		MatchState.Phase.PLAY_DEAD, MatchState.Phase.INNING_TRANSITION, MatchState.Phase.GAME_END:
			return 2
	return -1


func _fault(code: String) -> void:
	_collecting = false
	if code not in _errors:
		_errors.append(code)


func _checkpoint(reason: String) -> Dictionary:
	var elapsed: int = Time.get_ticks_usec() - _started_usec
	var errors: Array[String] = _errors.duplicate()
	if not _stack.is_empty() or _completed != _entries:
		if "UNBALANCED_STACK" not in errors:
			errors.append("UNBALANCED_STACK")
	if elapsed < 0 or elapsed > MAX_SPAN_USEC:
		if "CLOCK_RANGE" not in errors:
			errors.append("CLOCK_RANGE")
	return _record(reason, elapsed, errors)


func _finish(reason: String) -> Dictionary:
	var elapsed: int = Time.get_ticks_usec() - _started_usec
	if not _stack.is_empty() or _completed != _entries:
		_fault("UNBALANCED_STACK")
	if elapsed < 0 or elapsed > MAX_SPAN_USEC:
		_fault("CLOCK_RANGE")
	_collecting = false
	return _record(reason, elapsed, _errors)


func _record(reason: String, elapsed: int, errors: Array[String]) -> Dictionary:
	return {
		"schema": SCHEMA, "reason": reason, "bounded_ok": errors.is_empty(),
		"limits": {
			"max_entries": MAX_ENTRIES, "max_depth": MAX_DEPTH,
			"max_span_usec": MAX_SPAN_USEC, "row_count": PHASES.size() * SITES.size()
		},
		"entries": _entries, "completed_entries": _completed, "max_depth": _max_depth,
		"root_spans": _root_spans, "root_inclusive_usec": _root_usec,
		"elapsed_usec": elapsed, "open_depth": _stack.size(),
		"rows": _rows.duplicate(true), "errors": errors.duplicate()
	}

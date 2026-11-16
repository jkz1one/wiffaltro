extends RefCounted
## One durable owner transaction; all day/base projections remain detached.
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Authority = preload("res://src/gameplay/season/dynasty_shared_time_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")

static func prepare_create(payload: Dictionary, selected: String) -> Dictionary:
	if selected not in TimeHome.PROFILES or payload.get("snapshot", {}).get("version") != 92: return {}
	var request: Dictionary = {"op": "create", "request_id": "create:" + Owner.Legacy.fingerprint(payload),
		"expected_revision": 0, "payload": payload.duplicate(true)}
	var projected: Dictionary = Owner.project({}, request)
	if projected.is_empty(): return {}
	var snapshot: Dictionary = TimeHome.from_base(payload.snapshot, projected.owner.career.sessions.size(), selected)
	if snapshot.is_empty(): return {}
	var result: Dictionary = payload.duplicate(true)
	result.snapshot = snapshot
	return result

static func create(request: Dictionary) -> Dictionary:
	var snapshot: Dictionary = request.payload.snapshot
	var base: Dictionary = TimeHome.original(snapshot)
	if base.is_empty() or base.get("version") != 92: return {}
	var original: Dictionary = request.payload.duplicate(true)
	original.snapshot = base
	var projected: Dictionary = Owner.project({}, {"op": "create",
		"request_id": "create:" + Owner.Legacy.fingerprint(original), "expected_revision": 0, "payload": original})
	return _convert(projected, {}, request, snapshot)

static func next_generation(projected: Dictionary, before: Dictionary, request: Dictionary) -> Dictionary:
	if projected.is_empty() or not projected.owner.pending_next.is_empty(): return projected
	var selected: String = request.get("starting_profile", "") if request.op == "begin_next" \
		else before.get("pending_time_profile", "")
	if selected.is_empty(): return projected
	var bytes: Variant = projected.snapshots.get(projected.owner.dynasty.reference.sha256)
	var base: Variant = JSON.parse_string(bytes) if bytes is String else null
	if not base is Dictionary or base.get("version") != 92: return {}
	var snapshot: Dictionary = TimeHome.from_base(base, projected.owner.career.sessions.size(), selected)
	return {} if snapshot.is_empty() else _convert(projected, before, request, snapshot)

static func _convert(projected: Dictionary, before: Dictionary, request: Dictionary, snapshot: Dictionary) -> Dictionary:
	if projected.is_empty(): return {}
	var source: Dictionary = projected.owner
	var next: Dictionary = source.duplicate(true)
	next.career = Authority.bind_carried(source.career, source, snapshot)
	if next.career.is_empty() or Owner._install(next, "dynasty", snapshot).is_empty(): return {}
	var snapshots: Dictionary = projected.snapshots.duplicate(true)
	snapshots.erase(source.dynasty.reference.sha256)
	if not Owner._add_snapshot(snapshots, snapshot): return {}
	var result: Dictionary = Owner._finish(before, next, request, snapshots)
	if not result.is_empty() and projected.has("origin"): result["origin"] = projected.origin
	return result

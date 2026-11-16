extends RefCounted
## Deterministic detached conversion before the single durable owner commit.
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Proposal = preload("res://src/gameplay/season/dynasty_carried_home_proposal.gd")

static func create(request: Dictionary) -> Dictionary:
	var snapshot: Dictionary = request.payload.snapshot
	if not snapshot.get("checkpoint") is Dictionary: return {}
	var original: Dictionary = request.payload.duplicate(true)
	original.snapshot = snapshot.checkpoint
	var source_request: Dictionary = {"op": "create", "request_id": "create:" + Owner.Legacy.fingerprint(original),
		"expected_revision": 0, "payload": original}
	var projected: Dictionary = Owner.project({}, source_request)
	if projected.is_empty() or Proposal.qualify(snapshot, projected.owner).is_empty(): return {}
	return _convert(projected, {}, request, snapshot)

static func next_generation(projected: Dictionary, before: Dictionary, request: Dictionary) -> Dictionary:
	if projected.is_empty() or not projected.owner.pending_next.is_empty(): return projected
	var bytes: Variant = projected.snapshots.get(projected.owner.dynasty.reference.sha256)
	var source: Variant = JSON.parse_string(bytes) if bytes is String else null
	if not source is Dictionary: return {}
	var snapshot: Dictionary = Proposal.prepare(projected.owner, source)
	return {} if snapshot.is_empty() else _convert(projected, before, request, snapshot)

static func _convert(projected: Dictionary, before: Dictionary, request: Dictionary, snapshot: Dictionary) -> Dictionary:
	var source: Dictionary = projected.owner
	var next: Dictionary = source.duplicate(true)
	next.career = Authority.bind_dynasty_home(source.career, source, snapshot)
	if next.career.is_empty() or Owner._install(next, "dynasty", snapshot).is_empty(): return {}
	var snapshots: Dictionary = projected.snapshots.duplicate(true)
	snapshots.erase(source.dynasty.reference.sha256)
	if not Owner._add_snapshot(snapshots, snapshot): return {}
	var result: Dictionary = Owner._finish(before, next, request, snapshots)
	if not result.is_empty() and projected.has("origin"):
		result["origin"] = projected.origin
	return result

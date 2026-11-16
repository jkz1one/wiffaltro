extends RefCounted
## Closed, single-owner lifecycle projection. Manifests are bounded metadata;
## immutable Save79/closed-league objects remain separately byte-bounded.
## This is offline checkpoint consistency, not proof of omitted historical play.

const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const VERSION: int = 1
const MAX_REVISION: int = 2147483647
const MAX_SNAPSHOT_BYTES: int = 8 * 1024 * 1024
const OPS: Array[String] = ["create", "checkpoint", "switch", "close", "begin_next", "choose_next"]

const Operations1: GDScript = preload("res://src/gameplay/season/dynasty_owner_operations_1.gd")


static func fingerprint(value: Variant) -> String:
	# JSON transport may spell integral values differently; never round decimals.
	return Lineage._json_identity(value)


static func reference_valid(value: Variant) -> bool:
	return (
		Profile.keys(value, ["sha256", "bytes"])
		and Lineage._digest(value.sha256)
		and Profile.whole(value.bytes, 1, MAX_SNAPSHOT_BYTES)
	)


static func normalize(value: Variant) -> Dictionary:
	if (
		not Profile.keys(
			value,
			[
				"version",
				"owner_id",
				"revision",
				"lineage",
				"dynasty",
				"other",
				"selected",
				"pending_next",
				"last_action"
			]
		)
		or not Profile.whole(value.version, VERSION, VERSION)
		or not Profile.token(value.owner_id)
		or not Profile.whole(value.revision, 1, MAX_REVISION)
		or value.selected not in ["dynasty", "other"]
		or not value.other is Dictionary
		or not value.pending_next is Dictionary
	):
		return {}
	var lineage: Dictionary = Lineage.normalize(value.lineage)
	if (
		lineage.is_empty()
		or lineage.owner_id != value.owner_id
		or not _slot_valid(value.dynasty, true)
		or (not value.other.is_empty() and not _slot_valid(value.other, false))
		or (value.selected == "other" and value.other.is_empty())
	):
		return {}
	if (
		value.dynasty.session_id != "%s:%d" % [lineage.id, int(lineage.ordinal)]
		or value.dynasty.seed != lineage.start_profile.seed
		or value.dynasty.start_hash != fingerprint(lineage.start_profile)
		or not Profile.same(value.dynasty.frontier.draft_picks, lineage.start_profile.roster)
		or (not value.other.is_empty() and value.other.session_id == value.dynasty.session_id)
		or (value.selected == "other" and lineage.state != "paused")
		or (value.selected == "dynasty" and lineage.state == "paused")
	):
		return {}
	# Every accepted Dynasty source is captured, including the initial source.
	if (
		lineage.version != Lineage.CAPTURE_VERSION
		or lineage.capture.revision != value.dynasty.checkpoint_revision
		or lineage.capture.header_hash != value.dynasty.frontier.builds["0"].header_hash
		or lineage.capture.prefix_hash != value.dynasty.frontier.builds["0"].prefix_hash
	):
		return {}
	if not value.pending_next.is_empty():
		if (
			not _pending_valid(value.pending_next, lineage)
			or (lineage.resume_state if lineage.state == "paused" else lineage.state) != "closed"
			or not value.pending_next.overflow_choices.is_empty()
			or not Profile.decay(lineage.current_profile).is_empty()
		):
			return {}
	var action: Variant = value.last_action
	if (
		not Profile.keys(action, ["id", "kind", "expected_revision", "fingerprint"])
		or not Profile.token(action.id)
		or action.kind not in OPS
		or not Lineage._digest(action.fingerprint)
		or not Profile.whole(action.expected_revision, 0, MAX_REVISION - 1)
		or action.expected_revision != value.revision - 1
		or ((value.revision == 1) != (action.kind == "create"))
	):
		return {}
	if action.kind in ["begin_next", "choose_next"]:
		var typed: Dictionary = _latest_next_request(value)
		if typed.is_empty() or fingerprint(typed) != action.fingerprint:
			return {}
	var result: Dictionary = value.duplicate(true)
	result.version = VERSION
	result.revision = int(value.revision)
	result.lineage = lineage
	result.last_action.expected_revision = int(action.expected_revision)
	for name: String in ["dynasty", "other"]:
		if not result[name].is_empty():
			result[name] = _canonical_slot(result[name])
	if not result.pending_next.is_empty():
		for field: String in [
			"source_generation", "source_ordinal", "target_ordinal", "target_seed"
		]:
			result.pending_next[field] = int(result.pending_next[field])
	Profile.freeze(result)
	return result


static func required_references(before: Variant, request: Variant) -> Array:
	var owner: Dictionary = normalize(before)
	if owner.is_empty() or not request is Dictionary:
		return []
	var result: Array = []
	if request.get("op") in ["checkpoint", "switch", "close"]:
		result.append(owner[owner.selected].reference)
	if request.get("op") in ["begin_next", "choose_next"]:
		result.append(owner.dynasty.reference)
	if request.get("op") == "switch" and request.get("target") in ["dynasty", "other"]:
		var target: Dictionary = owner[request.target]
		if not target.is_empty() and not result.has(target.reference):
			result.append(target.reference)
	return result


static func project(before: Variant, request: Variant, sources: Dictionary = {}) -> Dictionary:
	if not _request_valid(request):
		return {}
	var owner: Dictionary = {} if before is Dictionary and before.is_empty() else normalize(before)
	if request.op == "create":
		return (
			_create(request)
			if owner.is_empty() and before is Dictionary and before.is_empty()
			else {}
		)
	if owner.is_empty():
		return {}
	# Immediate identical retries only. Store can return this committed owner
	# without replaying a source; a later action invalidates the old revision.
	if (
		request.request_id == owner.last_action.id
		and request.expected_revision == owner.last_action.expected_revision
	):
		return (
			{"owner": owner, "receipt": {}, "snapshots": {}, "replayed": true}
			if fingerprint(request) == owner.last_action.fingerprint
			else {}
		)
	if (
		request.expected_revision != owner.revision
		or owner.revision >= MAX_REVISION
		or request.request_id == owner.last_action.id
	):
		return {}
	for reference: Dictionary in required_references(owner, request):
		if not sources.get(reference.sha256) is Dictionary:
			return {}
	match request.op:
		"checkpoint":
			return _checkpoint(owner, request, sources)
		"switch":
			return _switch(owner, request, sources)
		"close":
			return _close(owner, request, sources)
		"begin_next":
			if (
				owner.selected != "dynasty"
				or owner.lineage.state != "closed"
				or not owner.pending_next.is_empty()
				or not _next_source_valid(owner, sources)
			):
				return {}
			return _next(
				owner,
				request,
				Lineage.request_for(owner.lineage, request.request_id, int(request.seed))
			)
		"choose_next":
			if (
				owner.pending_next.is_empty()
				or request.pending_id != owner.pending_next.id
				or not _next_source_valid(owner, sources)
			):
				return {}
			var pending: Dictionary = owner.pending_next.duplicate(true)
			pending.overflow_choices = request.choices.duplicate(true)
			return _next(owner, request, pending)
	return {}


static func validate_selected(value: Variant, snapshot: Variant) -> SeasonState:
	var owner: Dictionary = normalize(value)
	if owner.is_empty() or not snapshot is Dictionary:
		return null
	return _validate_slot(
		owner[owner.selected], snapshot, owner.lineage if owner.selected == "dynasty" else {}
	)


static func request_binding_valid(
	before_value: Variant,
	after_value: Variant,
	after_snapshot: Variant = null,
	origin: Dictionary = {},
	origin_snapshot: Variant = null
) -> bool:
	# Recover only the current action's uniquely represented typed operands.
	# This is exact retry consistency, not authentication or an omitted-history
	# proof. Create's original pre-capture lineage is not uniquely recoverable.
	var before: Dictionary = (
		{} if before_value is Dictionary and before_value.is_empty() else normalize(before_value)
	)
	var after: Dictionary = normalize(after_value)
	if (
		after.is_empty()
		or not before_value is Dictionary
		or (not before_value.is_empty() and before.is_empty())
	):
		return false
	var action: Dictionary = after.last_action
	if before.is_empty():
		if action.kind != "create" or action.expected_revision != 0 or after.revision != 1:
			return false
		if not after.lineage.start_profile.has("access"):
			return origin.is_empty()
		if (
			not origin_intent_valid(after, origin)
			or not origin_snapshot is Dictionary
			or not after_snapshot is Dictionary
		):
			return false
		var original: Dictionary = {
			"op": "create",
			"request_id": action.id,
			"expected_revision": 0,
			"payload":
			{
				"lineage": origin.lineage,
				"session_id": after.dynasty.session_id,
				"snapshot": after_snapshot,
				"origin": origin_snapshot
			}
		}
		return fingerprint(original) == action.fingerprint
	if (
		action.kind == "create"
		or after.revision != before.revision + 1
		or after.owner_id != before.owner_id
		or after.lineage.id != before.lineage.id
	):
		return false
	var request: Dictionary = {
		"op": action.kind, "request_id": action.id, "expected_revision": before.revision
	}
	match action.kind:
		"checkpoint":
			if before.selected != after.selected or not after_snapshot is Dictionary:
				return false
			request["session_id"] = before[before.selected].session_id
			request["snapshot"] = after_snapshot
		"switch":
			if before.selected == after.selected:
				return false
			request["target"] = after.selected
			if before[after.selected].is_empty():
				if not after_snapshot is Dictionary:
					return false
				if (
					after_snapshot.get("version") == 80
					and not Profile.same(
						after_snapshot.get("access"),
						before.lineage.current_profile.get("access", {})
					)
				):
					return false
				request["session_id"] = after[after.selected].session_id
				request["snapshot"] = after_snapshot
		"close":
			if before.selected != "dynasty" or after.selected != "dynasty":
				return false
			request["session_id"] = before.dynasty.session_id
			request["reason"] = (
				"complete"
				if before.dynasty.frontier.phase == SeasonState.Phase.COMPLETE
				else "abandon"
			)
		"begin_next", "choose_next":
			request = _latest_next_request(after)
			if (
				request.is_empty()
				or (
					action.kind == "choose_next"
					and (
						before.pending_next.is_empty()
						or request.pending_id != before.pending_next.id
					)
				)
			):
				return false
		_:
			return false
	return fingerprint(request) == action.fingerprint


static func _latest_next_request(owner: Dictionary) -> Dictionary:
	var action: Dictionary = owner.last_action
	if owner.selected != "dynasty":
		return {}
	var request: Dictionary = {
		"op": action.kind, "request_id": action.id, "expected_revision": action.expected_revision
	}
	if action.kind == "begin_next" and not owner.pending_next.is_empty():
		if owner.lineage.state != "closed" or owner.pending_next.id != action.id:
			return {}
		request["seed"] = owner.pending_next.target_seed
		return request
	if (
		owner.lineage.state != "active"
		or owner.lineage.last_transition.is_empty()
		or not owner.pending_next.is_empty()
	):
		return {}
	var next: Dictionary = owner.lineage.last_transition.request
	if action.kind == "begin_next":
		if next.id != action.id or not next.overflow_choices.is_empty():
			return {}
		request["seed"] = next.target_seed
	elif action.kind == "choose_next":
		request["pending_id"] = next.id
		request["choices"] = next.overflow_choices
	else:
		return {}
	return request


static func validate_checkpoint_extension(
	before_value: Variant, after_value: Variant, before_snapshot: Variant, after_snapshot: Variant
) -> bool:
	# Cold intent retry only. Store already qualified the exact before object
	# and bound both immutable refs; do not replay the before season twice.
	var before: Dictionary = normalize(before_value)
	var after: Dictionary = normalize(after_value)
	if (
		before.is_empty()
		or after.is_empty()
		or not before_snapshot is Dictionary
		or not after_snapshot is Dictionary
		or before.owner_id != after.owner_id
		or before.lineage.id != after.lineage.id
		or after.revision != before.revision + 1
		or after.last_action.kind != "checkpoint"
		or before.selected != after.selected
		or not Profile.same(before.pending_next, after.pending_next)
	):
		return false
	var selected: String = before.selected
	var other: String = "other" if selected == "dynasty" else "dynasty"
	if (
		not Profile.same(before[other], after[other])
		or not _same_session(before[selected], after[selected])
		or not _frontier_advances(before[selected].frontier, after[selected].frontier)
	):
		return false
	var target: SeasonState = _validate_slot(
		after[selected], after_snapshot, after.lineage if selected == "dynasty" else {}
	)
	if target == null or not _extends(before_snapshot, after_snapshot, before[selected].frontier):
		return false
	if selected != "dynasty":
		return Profile.same(before.lineage, after.lineage)
	if before.lineage.state == "closed":
		return (
			Profile.same(before_snapshot, after_snapshot)
			and Profile.same(before.lineage, after.lineage)
		)
	var captured: Dictionary = _capture(before.lineage, target, after_snapshot)
	return not captured.is_empty() and Profile.same(captured, after.lineage)


static func _create(request: Dictionary) -> Dictionary:
	var payload: Dictionary = request.payload
	var lineage: Dictionary = Lineage.normalize(payload.lineage)
	if (
		lineage.is_empty()
		or lineage.state != "active"
		or payload.session_id != "%s:%d" % [lineage.id, int(lineage.ordinal)]
	):
		return {}
	var origin: Dictionary = {}
	var origin_material: Dictionary = {}
	if lineage.start_profile.has("access"):
		# One exact full origin replay precedes target replay; compact flags alone
		# cannot create an access-bearing owner. The original source stays separate.
		if not payload.get("origin") is Dictionary:
			return {}
		origin_material = _origin_material(payload.origin)
		if origin_material.is_empty():
			return {}
		if not _origin_start_matches(payload.origin, lineage.start_profile):
			return {}
		origin = {
			"reference": origin_material.reference, "lineage": payload.lineage.duplicate(true)
		}
	elif payload.has("origin"):
		return {}
	var source: Variant = payload.snapshot
	var season: SeasonState = _decode(source, true)
	if season == null or not Profile.same(season._dynasty_start, lineage.start_profile):
		return {}
	var captured: Dictionary = _capture(lineage, season, source)
	if captured.is_empty():
		return {}
	var material: Dictionary = _material(source)
	if material.is_empty():
		return {}
	var next: Dictionary = {
		"version": VERSION,
		"owner_id": lineage.owner_id,
		"revision": 0,
		"lineage": captured,
		"dynasty": _slot(payload.session_id, material.reference, source, season),
		"other": {},
		"selected": "dynasty",
		"pending_next": {},
		"last_action": {}
	}
	var result: Dictionary = _finish({}, next, request, material.snapshots, season)
	if not result.is_empty() and not origin.is_empty():
		result["origin"] = origin
		result.snapshots.merge(origin_material.snapshots)
	return result


static func origin_intent_valid(after: Dictionary, origin: Variant) -> bool:
	if (
		not Profile.keys(origin, ["reference", "lineage"])
		or not reference_valid(origin.reference)
		or not after.lineage.start_profile.has("access")
		or after.revision != 1
		or after.last_action.kind != "create"
		or after.selected != "dynasty"
	):
		return false
	var lineage: Dictionary = Lineage.normalize(origin.lineage)
	return (
		not lineage.is_empty()
		and lineage.state == "active"
		and lineage.id == after.lineage.id
		and lineage.owner_id == after.owner_id
		and Profile.same(lineage.start_profile, after.lineage.start_profile)
		and origin.reference.sha256 == after.lineage.start_profile.access.source.sha256
	)


static func qualify_origin(after: Dictionary, origin: Dictionary, snapshot: Variant) -> bool:
	if (
		not origin_intent_valid(after, origin)
		or not snapshot is Dictionary
		or ClosedContentAccess.digest(snapshot) != origin.reference.sha256
	):
		return false
	return _origin_start_matches(snapshot, after.lineage.start_profile)


static func _origin_start_matches(snapshot: Dictionary, start: Dictionary) -> bool:
	# Exact first capture binds roster, original development/receipts and ordinary
	# capacity too. Choosing a fresh target seed does not rewrite source evidence.
	var captured: Dictionary = Profile.capture_access_season(
		snapshot, start.lineage_id, start.owner_id
	)
	if captured.is_empty():
		return false
	var expected: Dictionary = captured.duplicate(true)
	expected.seed = start.seed
	return Profile.same(expected, start)


static func _checkpoint(owner: Dictionary, request: Dictionary, sources: Dictionary) -> Dictionary:
	var prior: Dictionary = owner[owner.selected]
	if request.session_id != prior.session_id:
		return {}
	var snapshot: Dictionary = request.snapshot
	var closed: bool = owner.selected == "dynasty" and owner.lineage.state == "closed"
	if closed and not Profile.same(snapshot, sources[prior.reference.sha256]):
		return {}
	var season: SeasonState = _decode(snapshot, owner.selected == "dynasty")
	if season == null:
		return {}
	if closed and not _current_matches(owner.lineage, season):
		return {}
	var material: Dictionary = _material(snapshot)
	if material.is_empty():
		return {}
	var slot: Dictionary = _slot(prior.session_id, material.reference, snapshot, season)
	if (
		not _same_session(prior, slot)
		or not _extends(sources[prior.reference.sha256], snapshot, prior.frontier)
	):
		return {}
	var next: Dictionary = owner.duplicate(true)
	next[owner.selected] = slot
	if owner.selected == "dynasty" and not closed:
		next.lineage = _capture(owner.lineage, season, snapshot)
		if next.lineage.is_empty():
			return {}
	return _finish(owner, next, request, material.snapshots, season)


static func _switch(owner: Dictionary, request: Dictionary, sources: Dictionary) -> Dictionary:
	if request.target == owner.selected:
		return {}
	var source: SeasonState = _validate_slot(
		owner[owner.selected],
		sources[owner[owner.selected].reference.sha256],
		owner.lineage if owner.selected == "dynasty" else {}
	)
	if source == null or not _exit_ready(source):
		return {}
	# The app may still own its live source, but this detached qualification
	# need not remain alive while the selected target is fully replayed.
	source = null
	var next: Dictionary = owner.duplicate(true)
	var selected: SeasonState
	var snapshots: Dictionary = {}
	if owner[request.target].is_empty():
		if (
			request.target != "other"
			or not request.has("snapshot")
			or not request.has("session_id")
			or request.session_id == owner.dynasty.session_id
		):
			return {}
		selected = _decode(request.snapshot, false)
		if (
			selected == null
			or (
				not selected._closed_access.is_empty()
				and not Profile.same(
					selected._closed_access, owner.lineage.current_profile.get("access", {})
				)
			)
		):
			return {}
		var material: Dictionary = _material(request.snapshot)
		if material.is_empty():
			return {}
		next.other = _slot(request.session_id, material.reference, request.snapshot, selected)
		snapshots = material.snapshots
	else:
		# A resume never replaces an existing session, even with a valid source.
		if request.has("snapshot") or request.has("session_id"):
			return {}
		selected = _validate_slot(
			owner[request.target],
			sources[owner[request.target].reference.sha256],
			owner.lineage if request.target == "dynasty" else {}
		)
		if selected == null:
			return {}
	next.lineage = (
		Lineage.pause(owner.lineage) if request.target == "other" else Lineage.resume(owner.lineage)
	)
	next.selected = request.target
	return _finish(owner, next, request, snapshots, selected)


static func _close(owner: Dictionary, request: Dictionary, sources: Dictionary) -> Dictionary:
	if (
		owner.selected != "dynasty"
		or owner.lineage.state != "active"
		or request.session_id != owner.dynasty.session_id
		or not owner.pending_next.is_empty()
	):
		return {}
	var snapshot: Dictionary = sources[owner.dynasty.reference.sha256]
	var season: SeasonState = _validate_slot(owner.dynasty, snapshot, owner.lineage)
	if season == null or not _exit_ready(season):
		return {}
	var outcome: String = "abandon"
	if request.reason == "complete":
		if season.phase != SeasonState.Phase.COMPLETE or season.champion < 0 or season.champion > 5:
			return {}
		outcome = "win" if season.champion == 0 else "loss"
	elif season.phase == SeasonState.Phase.COMPLETE:
		return {}  # A completed result cannot be relabeled abandon.
	var captured: Dictionary = _capture(owner.lineage, season, snapshot)
	if captured.is_empty():
		return {}
	var next: Dictionary = owner.duplicate(true)
	next.lineage = Lineage.close(captured, outcome)
	return _finish(owner, next, request, {}, season)


static func _next_source_valid(owner: Dictionary, sources: Dictionary) -> bool:
	if owner.selected != "dynasty" or owner.lineage.state != "closed":
		return false
	var source: Variant = sources.get(owner.dynasty.reference.sha256)
	if not source is Dictionary:
		return false
	# Compact normalization is not source authority. Rebind current growth to
	# the exact committed object before it can become a new valid start. The
	# detached source qualification expires before constructing the successor.
	return _validate_slot(owner.dynasty, source, owner.lineage) != null


# Private projector after public source qualification; tests may exercise its
# compact arithmetic only, never advertise that as public owner admission.
static func _next(owner: Dictionary, request: Dictionary, pending: Dictionary) -> Dictionary:
	if (
		owner.selected != "dynasty"
		or owner.lineage.state != "closed"
		or not _pending_valid(pending, owner.lineage)
	):
		return {}
	var advanced: Dictionary = Lineage.advance(owner.lineage, pending)
	if advanced.is_empty():
		# Only a missing F09 choice may create pending state. Wrong/extra/stale
		# choices do not mutate the source or replace its immutable target.
		if (
			request.op != "begin_next"
			or not pending.overflow_choices.is_empty()
			or not _has_overflow(owner.lineage.current_profile)
		):
			return {}
		var waiting: Dictionary = owner.duplicate(true)
		waiting.pending_next = pending
		return _finish(owner, waiting, request)
	var season: SeasonState = Bridge.create(advanced.lineage.start_profile)
	if season == null:
		return {}
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	# The constructor is not validation. Every newly selected season replays
	# the exact complete Save79 once before its immutable object is admitted.
	var checked: SeasonState = _decode(snapshot, true)
	if checked == null:
		return {}
	var captured: Dictionary = _capture(advanced.lineage, checked, snapshot)
	var material: Dictionary = _material(snapshot)
	if captured.is_empty() or material.is_empty():
		return {}
	var next: Dictionary = owner.duplicate(true)
	next.lineage = captured
	next.dynasty = _slot(pending.target_id, material.reference, snapshot, checked)
	next.pending_next = {}
	return _finish(owner, next, request, material.snapshots, checked)


static func _finish(
	before: Dictionary,
	candidate: Dictionary,
	request: Dictionary,
	snapshots: Dictionary = {},
	selected: SeasonState = null
) -> Dictionary:
	candidate.revision = int(before.get("revision", 0)) + 1
	candidate.last_action = {
		"id": request.request_id,
		"kind": request.op,
		"expected_revision": int(request.expected_revision),
		"fingerprint": fingerprint(request)
	}
	var after: Dictionary = normalize(candidate)
	if after.is_empty():
		return {}
	var added: Array = []
	for slot: String in ["dynasty", "other"]:
		if not after[slot].is_empty() and snapshots.has(after[slot].reference.sha256):
			added.append(after[slot].reference)
	var receipt: Dictionary = {
		"version": VERSION,
		"kind": request.op,
		"request_id": request.request_id,
		"expected_revision": int(request.expected_revision),
		"fingerprint": fingerprint(request),
		"before_hash": fingerprint(before),
		"after_hash": fingerprint(after),
		"source_references": required_references(before, request),
		"new_references": added
	}
	if not transition_valid(before, after, receipt):
		return {}
	Profile.freeze(receipt)
	var result: Dictionary = {"owner": after, "receipt": receipt, "snapshots": snapshots}
	if selected != null:
		result["qualified_selected_season"] = selected
	return result


static func transition_valid(before_value: Variant, after_value: Variant, receipt: Variant) -> bool:
	var before: Dictionary = (
		{} if before_value is Dictionary and before_value.is_empty() else normalize(before_value)
	)
	var after: Dictionary = normalize(after_value)
	if (
		after.is_empty()
		or not before_value is Dictionary
		or (not before_value.is_empty() and before.is_empty())
		or not Profile.keys(
			receipt,
			[
				"version",
				"kind",
				"request_id",
				"expected_revision",
				"fingerprint",
				"before_hash",
				"after_hash",
				"source_references",
				"new_references"
			]
		)
		or not Profile.whole(receipt.version, VERSION, VERSION)
		or not receipt.source_references is Array
		or receipt.source_references.size() > 2
		or not receipt.new_references is Array
		or receipt.new_references.size() > 2
		or receipt.before_hash != fingerprint(before)
		or receipt.after_hash != fingerprint(after)
		or not Profile.same(
			after.last_action,
			{
				"id": receipt.request_id,
				"kind": receipt.kind,
				"expected_revision": receipt.expected_revision,
				"fingerprint": receipt.fingerprint
			}
		)
		or after.revision != int(before.get("revision", 0)) + 1
	):
		return false
	for reference: Variant in receipt.source_references:
		if not reference_valid(reference) or not _has_reference(before, reference):
			return false
	for reference: Variant in receipt.new_references:
		if not reference_valid(reference) or not _has_reference(after, reference):
			return false
	if before.is_empty():
		return (
			receipt.kind == "create"
			and after.selected == "dynasty"
			and after.other.is_empty()
			and after.pending_next.is_empty()
			and after.lineage.state == "active"
			and receipt.source_references.is_empty()
			and receipt.new_references.size() == 1
			and Profile.same(receipt.new_references[0], after.dynasty.reference)
		)
	if (
		receipt.kind == "create"
		or before.owner_id != after.owner_id
		or before.lineage.id != after.lineage.id
	):
		return false
	if (
		receipt.kind in ["begin_next", "choose_next"]
		and (
			not Profile.same(receipt.source_references, [before.dynasty.reference])
			or not request_binding_valid(before, after)
		)
	):
		return false
	match receipt.kind:
		"checkpoint":
			var selected: String = before.selected
			var other: String = "other" if selected == "dynasty" else "dynasty"
			return (
				after.selected == selected
				and Profile.same(before[other], after[other])
				and Profile.same(before.pending_next, after.pending_next)
				and _same_session(before[selected], after[selected])
				and _frontier_advances(before[selected].frontier, after[selected].frontier)
				and (
					_capture_successor(before.lineage, after.lineage)
					if selected == "dynasty"
					else Profile.same(before.lineage, after.lineage)
				)
			)
		"switch":
			if (
				before.selected == after.selected
				or not Profile.same(before.pending_next, after.pending_next)
				or not before[before.selected].frontier.exit_ready
				or not Profile.same(before.dynasty, after.dynasty)
			):
				return false
			if not before.other.is_empty() and not Profile.same(before.other, after.other):
				return false
			if (
				before.other.is_empty()
				and after.other.get("snapshot_version") == 80
				and (
					not before.lineage.current_profile.has("access")
					or after.other.start_hash != fingerprint(before.lineage.current_profile.access)
				)
			):
				return false
			return Profile.same(
				after.lineage,
				(
					Lineage.pause(before.lineage)
					if after.selected == "other"
					else Lineage.resume(before.lineage)
				)
			)
		"close":
			if (
				before.selected != "dynasty"
				or after.selected != "dynasty"
				or before.lineage.state != "active"
				or not before.dynasty.frontier.exit_ready
				or not Profile.same(before.dynasty, after.dynasty)
				or not Profile.same(before.other, after.other)
				or not before.pending_next.is_empty()
				or not after.pending_next.is_empty()
			):
				return false
			var reason: String = (
				"abandon"
				if before.dynasty.frontier.phase != SeasonState.Phase.COMPLETE
				else ("win" if before.dynasty.frontier.champion == 0 else "loss")
			)
			return Profile.same(after.lineage, Lineage.close(before.lineage, reason))
		"begin_next", "choose_next":
			return _next_transition(before, after, receipt.kind)
	return false


static func _next_transition(before: Dictionary, after: Dictionary, kind: String) -> bool:
	if (
		before.selected != "dynasty"
		or after.selected != "dynasty"
		or before.lineage.state != "closed"
		or not Profile.same(before.other, after.other)
	):
		return false
	if not after.pending_next.is_empty():
		return (
			kind == "begin_next"
			and before.pending_next.is_empty()
			and Profile.same(before.lineage, after.lineage)
			and Profile.same(before.dynasty, after.dynasty)
		)
	if after.lineage.state != "active" or after.lineage.ordinal != before.lineage.ordinal + 1:
		return false
	var request: Dictionary = after.lineage.last_transition.request
	if kind == "choose_next":
		if before.pending_next.is_empty():
			return false
		var exact: Dictionary = request.duplicate(true)
		exact.overflow_choices = {}
		if not Profile.same(exact, before.pending_next):
			return false
	elif (
		not before.pending_next.is_empty()
		or request.id != after.last_action.id
		or not request.overflow_choices.is_empty()
	):
		return false
	var advanced: Dictionary = Lineage.advance(before.lineage, request)
	return (
		not advanced.is_empty()
		and _capture_successor(advanced.lineage, after.lineage)
		and after.dynasty.session_id == request.target_id
		and after.dynasty.seed == request.target_seed
		and after.dynasty.frontier.result_count == 0
		and after.dynasty.frontier.report_count == 0
		and after.dynasty.frontier.phase == SeasonState.Phase.REGULAR
	)


static func _request_valid(request: Variant) -> bool:
	return Operations1._request_valid(OPS, Profile, MAX_REVISION, request)


static func _decode(snapshot: Variant, dynasty: bool) -> SeasonState:
	return Operations1._decode(Profile, MAX_SNAPSHOT_BYTES, snapshot, dynasty)


static func _validate_slot(
	slot: Dictionary, snapshot: Dictionary, lineage: Dictionary
) -> SeasonState:
	return Operations1._validate_slot(
		_decode, _slot, Profile, _current_matches, slot, snapshot, lineage
	)


static func _current_matches(lineage: Dictionary, season: SeasonState) -> bool:
	return Operations1._current_matches(Profile, lineage, season)


static func _material(snapshot: Dictionary) -> Dictionary:
	return Operations1._material(MAX_SNAPSHOT_BYTES, snapshot)


static func _origin_material(snapshot: Dictionary) -> Dictionary:
	return Operations1._origin_material(_material, snapshot)


static func _slot(
	session_id: String, reference: Dictionary, snapshot: Dictionary, season: SeasonState
) -> Dictionary:
	return Operations1._slot(fingerprint, _frontier, session_id, reference, snapshot, season)


static func _slot_valid(slot: Variant, dynasty: bool) -> bool:
	return Operations1._slot_valid(
		Profile, reference_valid, _frontier_valid, Lineage, slot, dynasty
	)


static func _canonical_slot(slot: Dictionary) -> Dictionary:
	return Operations1._canonical_slot(slot)


static func _core(snapshot: Dictionary) -> Dictionary:
	return Operations1._core(snapshot)


static func _frontier(snapshot: Dictionary, season: SeasonState) -> Dictionary:
	return Operations1._frontier(_core, Lineage, fingerprint, _exit_ready, snapshot, season)


static func _frontier_valid(value: Variant) -> bool:
	return Operations1._frontier_valid(Profile, Lineage, fingerprint, value)


static func _exit_ready(season: SeasonState) -> bool:
	return Operations1._exit_ready(season)


static func _capture(lineage: Dictionary, season: SeasonState, snapshot: Dictionary) -> Dictionary:
	return Operations1._capture(Profile, _core, Lineage, lineage, season, snapshot)


static func _same_session(before: Dictionary, after: Dictionary) -> bool:
	return Operations1._same_session(Profile, before, after)


static func _capture_successor(before: Dictionary, after: Dictionary) -> bool:
	return Operations1._capture_successor(Profile, Lineage, before, after)


static func _frontier_advances(before: Dictionary, after: Dictionary) -> bool:
	return Operations1._frontier_advances(_prefix, before, after)


static func _extends(before: Dictionary, after: Dictionary, frontier: Dictionary) -> bool:
	return Operations1._extends(_core, _prefix, Lineage, _pending_extends, before, after, frontier)


static func _prefix(before: Array, after: Array) -> bool:
	return Operations1._prefix(Profile, before, after)


static func _pending_extends(before: Dictionary, after: Dictionary) -> bool:
	return Operations1._pending_extends(Profile, _prefix, _human_matches, before, after)


static func _human_matches(human: Array, result: Dictionary) -> bool:
	return Operations1._human_matches(Profile, human, result)


static func _has_reference(owner: Dictionary, reference: Dictionary) -> bool:
	return Operations1._has_reference(Profile, owner, reference)


static func _pending_valid(request: Variant, lineage: Dictionary) -> bool:
	return Operations1._pending_valid(Lineage, request, lineage)


static func _has_overflow(profile: Dictionary) -> bool:
	return Operations1._has_overflow(profile)

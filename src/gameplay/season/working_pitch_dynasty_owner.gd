extends RefCounted
## Joint shared-career/owner projection. Raw replay and outer object identities
## are separately recorded; neither a wrapper nor a compact receipt grants CB.

const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")
const OldLineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_career_lineage.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Save = preload("res://src/gameplay/season/working_pitch_dynasty_save.gd")
const Authority = preload("res://src/gameplay/season/working_pitch_dynasty_authority.gd")
const Replay = preload("res://src/gameplay/season/working_pitch_dynasty_replay.gd")
const Ops = preload("res://src/gameplay/season/dynasty_owner_operations_1.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const VERSION: int = 3


static func normalize(value: Variant) -> Dictionary:
	if (
		not value is Dictionary
		or value.get("version") != VERSION
		or value.get("pitch_catalog") != WorkingPitchCatalog.signature()
		or value.get("selected") != "dynasty"
		or value.get("other") != {}
		or not value.get("raw_references") is Dictionary
		or not Profile.keys(value.raw_references, ["dynasty", "other"])
		or not value.raw_references.dynasty is Dictionary
		or not value.raw_references.other is Dictionary
	):
		return {}
	var lineage: Dictionary = Lineage.normalize(value.get("lineage"))
	var career: Dictionary = Authority.normalize(value.get("career"))
	if lineage.is_empty() or career.is_empty() or career.owner_id != value.get("owner_id"):
		return {}
	var shadow: Dictionary = value.duplicate(true)
	shadow.erase("career")
	shadow.erase("pitch_catalog")
	shadow.erase("raw_references")
	shadow.erase("operands")
	shadow.erase("pending_tier")
	shadow.erase("pending_rules")
	shadow.erase("pending_time_profile")
	shadow.erase("asset_receipt")
	shadow.version = 1
	shadow.lineage = Lineage.legacy_view(lineage)
	for slot: String in ["dynasty", "other"]:
		if not shadow.get(slot) is Dictionary:
			return {}
		if shadow[slot].is_empty():
			if not value.raw_references[slot].is_empty():
				return {}
			continue
		if not Legacy.reference_valid(value.raw_references[slot]):
			return {}
		shadow[slot].reference = value.raw_references[slot]
		shadow[slot].snapshot_version = 80
		if slot == "dynasty":
			shadow[slot].start_hash = Legacy.fingerprint(shadow.lineage.start_profile)
	if (
		not _pending_rules_valid(value)
		or not shadow.get("pending_next") is Dictionary
		or not Profile.keys(
			shadow.get("last_action"), ["id", "kind", "expected_revision", "fingerprint"]
		)
	):
		return {}
	if (
		not shadow.pending_next.is_empty()
		and not Legacy._pending_valid(shadow.pending_next, shadow.lineage)
	):
		return {}
	if value.last_action.kind in ["begin_next", "choose_next"]:
		# Validate old lifecycle metadata without pretending its old fingerprint
		# includes the new tier choice. Actual operands are independently bound.
		var legacy_request: Dictionary = Legacy._latest_next_request(shadow)
		if legacy_request.is_empty():
			return {}
		shadow.last_action.fingerprint = Legacy.fingerprint(legacy_request)
	if (
		Legacy.normalize(shadow).is_empty()
		or not _operands_valid(value)
		or not _asset_receipt_valid(value, career)
	):
		return {}
	var result: Dictionary = value.duplicate(true)
	result.lineage = lineage
	result.career = career
	for slot: String in ["dynasty", "other"]:
		if result[slot].is_empty():
			continue
		var entry: Dictionary = career.sessions.get(result[slot].session_id, {})
		if result[slot].snapshot_version != Save.BOUND_VERSION or slot != "dynasty" \
			or entry.is_empty() or not Legacy.reference_valid(result[slot].reference) \
			or entry.session.lineage_id != lineage.id \
			or not Profile.same(entry.reference, result[slot].reference) \
			or entry.session.seed != result[slot].seed \
			or entry.session.league != result[slot].profile.league \
			or entry.session.tier != result[slot].profile.tier:
			return {}
		if (
			slot == "dynasty"
			and (
				entry.session.generation != lineage.generation
				or entry.session.ordinal != lineage.ordinal
				or not Profile.same(entry.baseline, lineage.start_profile.get("access", {}))
			)
		):
			return {}
	Profile.freeze(result)
	return result


static func _request_valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("op") not in ["create", "checkpoint", "close", "begin_next", "choose_next"] \
		or value.has("starting_profile"):
		return false
	if not value.has("tier"):
		return Legacy._request_valid(value)
	if value.op != "begin_next" or not Profile.whole(value.tier, 0, 4):
		return false
	var request: Dictionary = value.duplicate(true)
	request.erase("tier")
	return Legacy._request_valid(request)


static func _pending_rules_valid(owner: Dictionary) -> bool:
	var operands: Variant = owner.get("operands", {})
	if not operands is Dictionary: return false
	var timed: bool = operands.get("op") == "begin_next" and operands.has("starting_profile")
	if owner.has("pending_time_profile") or timed:
		if not owner.get("pending_next") is Dictionary: return false
		if owner.pending_next.is_empty():
			if owner.has("pending_time_profile"): return false
		elif not timed or not owner.has("pending_time_profile") \
			or owner.pending_time_profile not in load("res://src/gameplay/season/dynasty_shared_time.gd").PROFILES \
			or operands.starting_profile != owner.pending_time_profile: return false
	if not owner.has("pending_tier") and not owner.has("pending_rules"):
		return true
	return (
		owner.get("pending_next") is Dictionary
		and not owner.pending_next.is_empty()
		and Profile.whole(owner.get("pending_tier"), 1, 4)
		and Profile.same(
			owner.get("pending_rules"), LeagueRules.capture_tier("dynasty", int(owner.pending_tier))
		)
	)


static func _operands_valid(owner: Dictionary) -> bool:
	var request: Variant = owner.get("operands")
	if not _request_valid(request):
		return false
	if (
		request.op != owner.last_action.kind
		or request.request_id != owner.last_action.id
		or request.expected_revision != owner.last_action.expected_revision
	):
		return false
	if request.op in ["begin_next", "choose_next"]:
		if Legacy.fingerprint(request) != owner.last_action.fingerprint:
			return false
		var original: Dictionary = request.duplicate(true)
		original.erase("tier")
		original.erase("starting_profile")
		if not Profile.same(original, Legacy._latest_next_request(owner)):
			return false
	if request.op == "begin_next":
		var tier: int = int(request.get("tier", 0))
		if not owner.pending_next.is_empty():
			if int(owner.get("pending_tier", 0)) != tier:
				return false
		elif owner.dynasty.profile.tier != tier:
			return false
	if request.has("snapshot") and not Legacy.reference_valid(request.snapshot):
		return false
	if request.op == "create":
		return (
			request.payload.has("origin")
			and Legacy.reference_valid(request.payload.snapshot)
			and Legacy.reference_valid(request.payload.origin)
		)
	return true


static func _asset_receipt_valid(owner: Dictionary, _career: Dictionary) -> bool:
	return not owner.has("asset_receipt")


static func required_references(before: Variant, request: Variant) -> Array:
	var owner: Dictionary = normalize(before)
	if owner.is_empty() or not request is Dictionary:
		return []
	var result: Array = [owner[owner.selected].reference]
	if request.get("op") == "switch" and request.get("target") in ["dynasty", "other"]:
		var target: Dictionary = owner[request.target]
		if not target.is_empty() and not result.has(target.reference):
			result.append(target.reference)
	return result


static func _qualified(owner: Dictionary, slot: String, snapshot: Variant) -> Dictionary:
	if not snapshot is Dictionary:
		return {}
	var checked: Dictionary = Authority._qualify_session(owner.career, owner[slot].session_id, snapshot)
	if checked.is_empty():
		return {}
	var session: Dictionary = checked.session
	if (
		session.owner_id != owner.owner_id
		or session.lineage_id != owner.lineage.id
		or session.session_id != owner[slot].session_id
		or not Profile.same(checked.reference, owner[slot].reference)
		or not Profile.same(checked.raw_reference, owner.raw_references[slot])
	):
		return {}
	var expected: Dictionary = _slot(checked)
	expected.snapshot_version = int(snapshot.version)
	if not Profile.same(expected, owner[slot]):
		return {}
	if (
		slot == "dynasty"
		and (
			not Profile.same(checked.season._dynasty_start, owner.lineage.start_profile)
			or not Legacy._current_matches(owner.lineage, checked.season)
		)
	):
		return {}
	var rebound: Dictionary = Authority.checkpoint_session(owner.career, session.session_id, snapshot)
	if rebound.is_empty() or not Profile.same(rebound, owner.career):
		return {}
	return checked


static func validate_selected(value: Variant, snapshot: Variant) -> SeasonState:
	var owner: Dictionary = normalize(value)
	return null if owner.is_empty() else _qualified(owner, owner.selected, snapshot).get("season")


static func _capture(lineage: Dictionary, checked: Dictionary) -> Dictionary:
	return Ops._capture(Profile, Save.core, Lineage, lineage, checked.season, checked.inner)


static func _install(owner: Dictionary, slot: String, snapshot: Dictionary) -> Dictionary:
	var checked: Dictionary = Authority._qualify_session(owner.career, str(snapshot.get("session", {}).get("session_id", "")), snapshot)
	if checked.is_empty():
		return {}
	owner[slot] = _slot(checked)
	owner[slot].snapshot_version = int(snapshot.version)
	owner.raw_references[slot] = checked.raw_reference
	return checked


# Only _checkpoint supplies these two direct local products of its full target
# qualification, with no yield or external callback. The frozen slot captures
# derived phase/frontier values before authority progression; it is not a saved
# witness or a public admission route. Do not use for cold restore or recovery.
static func _add_snapshot(snapshots: Dictionary, snapshot: Dictionary) -> bool:
	# Match Save.snapshot_reference's canonical bytes for new owner-v2 objects.
	var canonical: Dictionary = JSON.parse_string(JSON.stringify(snapshot, "", true, true))
	var material: Dictionary = Legacy._material(canonical)
	if material.is_empty():
		return false
	snapshots.merge(material.snapshots)
	return true


static func _compact(request: Dictionary) -> Dictionary:
	var result: Dictionary = request.duplicate(true)
	if result.has("snapshot"):
		result.snapshot = Save.snapshot_reference(result.snapshot)
	if result.has("payload"):
		result.payload.snapshot = Save.snapshot_reference(result.payload.snapshot)
		if result.payload.has("origin"):
			result.payload.origin = Legacy._origin_material(result.payload.origin).get(
				"reference", {}
			)
	return result


static func _request(owner: Dictionary, snapshot: Variant, origin: Variant) -> Dictionary:
	var result: Dictionary = owner.operands.duplicate(true)
	if result.has("snapshot"):
		if (
			not snapshot is Dictionary
			or not Profile.same(result.snapshot, Save.snapshot_reference(snapshot))
		):
			return {}
		result.snapshot = snapshot
	if result.has("payload"):
		if (
			not snapshot is Dictionary
			or not origin is Dictionary
			or not Profile.same(result.payload.snapshot, Save.snapshot_reference(snapshot))
			or not Profile.same(
				result.payload.origin, Legacy._origin_material(origin).get("reference", {})
			)
		):
			return {}
		result.payload.snapshot = snapshot
		result.payload.origin = origin
	return result


static func project(before: Variant, request: Variant, sources: Dictionary = {}) -> Dictionary:
	if not _request_valid(request):
		return {}
	if before is Dictionary and before.is_empty():
		return _create(request) if request.op == "create" else {}
	var owner: Dictionary = normalize(before)
	if (
		owner.is_empty()
		or request.op == "create"
		or request.expected_revision != owner.revision
		or request.request_id == owner.last_action.id
	):
		return {}
	for reference: Dictionary in required_references(owner, request):
		if not sources.get(reference.sha256) is Dictionary:
			return {}
	var current: Dictionary = _qualified(
		owner, owner.selected, sources[owner[owner.selected].reference.sha256]
	)
	if current.is_empty():
		return {}
	var next: Dictionary = owner.duplicate(true)
	var snapshots: Dictionary = {}
	match request.op:
		"checkpoint":
			if not _checkpoint(next, owner, request, current, snapshots):
				return {}
		"close":
			if not _close(next, owner, request, current, sources):
				return {}
		"begin_next", "choose_next":
			if not _next(next, owner, request, snapshots):
				return {}
		_:
			return {}
	var result: Dictionary = _finish(owner, next, request, snapshots)
	return result


static func _create(request: Dictionary) -> Dictionary:
	var payload: Dictionary = request.payload
	if not payload.get("origin") is Dictionary:
		return {}
	var checked: Dictionary = Save.qualify(payload.snapshot)
	var lineage: Dictionary = Lineage.normalize(payload.lineage)
	if checked.is_empty() or lineage.is_empty() or checked.session.tier != 0 \
		or lineage.state != "active" or lineage.ordinal != 1 \
		or checked.session.session_id != payload.session_id \
		or not Profile.same(checked.season._dynasty_start, lineage.start_profile) \
		or not Legacy._origin_start_matches(payload.origin, lineage.start_profile):
		return {}
	var career: Dictionary = Authority.create(payload.origin, lineage.owner_id)
	career = Authority.open_session(career, payload.snapshot)
	if career.is_empty():
		return {}
	var captured: Dictionary = _capture(lineage, checked)
	if captured.is_empty():
		return {}
	var owner: Dictionary = {"version": VERSION, "pitch_catalog": WorkingPitchCatalog.signature(),
		"owner_id": lineage.owner_id, "revision": 0, "lineage": captured,
		"dynasty": {}, "other": {}, "selected": "dynasty", "pending_next": {},
		"last_action": {}, "raw_references": {"dynasty": {}, "other": {}}, "career": career}
	if _install(owner, "dynasty", payload.snapshot).is_empty():
		return {}
	var snapshots: Dictionary = {}
	if not _add_snapshot(snapshots, payload.snapshot):
		return {}
	var origin: Dictionary = Legacy._origin_material(payload.origin)
	if origin.is_empty():
		return {}
	snapshots.merge(origin.snapshots)
	var result: Dictionary = _finish({}, owner, request, snapshots)
	if not result.is_empty():
		result["origin"] = {"reference": origin.reference, "lineage": payload.lineage.duplicate(true)}
	return result


static func _checkpoint(next: Dictionary, owner: Dictionary, request: Dictionary,
	current: Dictionary, snapshots: Dictionary) -> bool:
	if request.session_id != owner.dynasty.session_id:
		return false
	var checked: Dictionary = Save.qualify(request.snapshot)
	if checked.is_empty() or not Profile.same(current.session, checked.session) \
		or not _extends(current, checked, owner.dynasty.frontier):
		return false
	next.career = Authority.checkpoint_session(owner.career, request.session_id, request.snapshot)
	if next.career.is_empty() or _install(next, "dynasty", request.snapshot).is_empty():
		return false
	if owner.lineage.state == "closed":
		return Profile.same(checked.inner, current.inner)
	next.lineage = _capture(owner.lineage, checked)
	return not next.lineage.is_empty() and _add_snapshot(snapshots, request.snapshot) \
		and _settle_completed(next, "dynasty", checked, request.snapshot)


static func _settle_completed(
	next: Dictionary, slot: String, checked: Dictionary, snapshot: Dictionary
) -> bool:
	if checked.season.phase != SeasonState.Phase.COMPLETE:
		return true
	if checked.season.champion < 0 or checked.season.champion > 5:
		return false
	next.career = Authority.settle_session(
		next.career, checked.session.session_id, "complete", snapshot
	)
	if next.career.is_empty():
		return false
	if slot == "dynasty":
		next.lineage = Lineage.close(
			next.lineage, "win" if checked.season.champion == 0 else "loss"
		)
	return not next.lineage.is_empty()


static func _close(
	next: Dictionary,
	owner: Dictionary,
	request: Dictionary,
	current: Dictionary,
	sources: Dictionary
) -> bool:
	if (
		request.session_id != owner[owner.selected].session_id
		or not Legacy._exit_ready(current.season)
		or not owner.pending_next.is_empty()
	):
		return false
	var complete: bool = current.season.phase == SeasonState.Phase.COMPLETE
	if (request.reason == "complete") != complete:
		return false
	next.career = Authority.settle_session(
		owner.career,
		request.session_id,
		request.reason,
		sources[owner[owner.selected].reference.sha256]
	)
	if next.career.is_empty():
		return false
	if owner.selected == "dynasty":
		var outcome: String = "abandon"
		if complete:
			outcome = "win" if current.season.champion == 0 else "loss"
		next.lineage = Lineage.close(owner.lineage, outcome)
	return not next.lineage.is_empty()


static func _next(
	next: Dictionary, owner: Dictionary, request: Dictionary, snapshots: Dictionary
) -> bool:
	if owner.selected != "dynasty" or owner.lineage.state != "closed":
		return false
	var tier: int = (
		int(request.get("tier", 0))
		if request.op == "begin_next"
		else int(owner.get("pending_tier", 0))
	)
	if tier not in Authority.available_tiers(owner.career, "dynasty"):
		return false
	var rules: Dictionary = LeagueRules.capture_tier("dynasty", tier)
	if request.op == "choose_next" and owner.has("pending_rules"):
		if not Profile.same(rules, owner.pending_rules):
			return false
	var pending: Dictionary
	if request.op == "begin_next":
		if not owner.pending_next.is_empty():
			return false
		pending = OldLineage.request_for(owner.lineage, request.request_id, int(request.seed))
	else:
		if owner.pending_next.is_empty() or request.pending_id != owner.pending_next.id:
			return false
		pending = owner.pending_next.duplicate(true)
		pending.overflow_choices = request.choices.duplicate(true)
	if not Legacy._pending_valid(pending, owner.lineage):
		return false
	var advanced: Dictionary = Lineage.advance(owner.lineage, pending)
	if advanced.is_empty():
		if request.op != "begin_next" or not Legacy._has_overflow(owner.lineage.current_profile):
			return false
		next.pending_next = pending
		if request.has("starting_profile"): next["pending_time_profile"] = request.starting_profile
		if tier > 0:
			next["pending_tier"] = tier
			next["pending_rules"] = rules.duplicate(true)
		return true
	var lineage: Dictionary = Lineage.rebase(advanced.lineage, Authority.access(owner.career))
	if lineage.is_empty():
		return false
	var season: SeasonState = Bridge.create(lineage.start_profile, true, tier)
	if season == null or not Profile.same(season.league_rules, rules) \
		or not Authority.install_start(owner.career, season):
		return false
	var inner: Dictionary = SeasonSave.snapshot(season)
	var snapshot: Dictionary = Save.wrap_checkpoint(
		inner,
		Save.binding_for(
			season,
			owner.owner_id,
			lineage.id,
			int(lineage.generation),
			int(lineage.ordinal),
			pending.target_id
		)
	)
	var checked: Dictionary = Save.qualify(snapshot)
	if checked.is_empty():
		return false
	next.career = Authority.open_session(owner.career, snapshot)
	if next.career.is_empty() or _install(next, "dynasty", snapshot).is_empty():
		return false
	next.lineage = _capture(lineage, checked)
	next.pending_next = {}
	next.erase("pending_tier")
	next.erase("pending_rules")
	next.erase("pending_time_profile")
	return not next.lineage.is_empty() and _add_snapshot(snapshots, snapshot)


static func _finish(
	before: Dictionary, candidate: Dictionary, request: Dictionary, snapshots: Dictionary
) -> Dictionary:
	candidate.erase("asset_receipt")
	candidate.revision = int(before.get("revision", 0)) + 1
	candidate.last_action = {
		"id": request.request_id,
		"kind": request.op,
		"expected_revision": int(request.expected_revision),
		"fingerprint": Legacy.fingerprint(request)
	}
	candidate["operands"] = _compact(request)
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
		"expected_revision": request.expected_revision,
		"fingerprint": Legacy.fingerprint(request),
		"before_hash": Legacy.fingerprint(before),
		"after_hash": Legacy.fingerprint(after),
		"source_references": required_references(before, request),
		"new_references": added
	}
	return {"owner": after, "receipt": receipt, "snapshots": snapshots}


static func transition_valid(before_value: Variant, after_value: Variant, receipt: Variant) -> bool:
	if not before_value is Dictionary:
		return false
	var before: Dictionary = {} if before_value.is_empty() else normalize(before_value)
	var after: Dictionary = normalize(after_value)
	if (
		after.is_empty()
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
		or receipt.version != VERSION
		or receipt.before_hash != Legacy.fingerprint(before)
		or receipt.after_hash != Legacy.fingerprint(after)
		or after.revision != int(before.get("revision", 0)) + 1
		or not Profile.same(
			after.last_action,
			{
				"id": receipt.request_id,
				"kind": receipt.kind,
				"expected_revision": receipt.expected_revision,
				"fingerprint": receipt.fingerprint
			}
		)
		or not receipt.source_references is Array
		or not receipt.new_references is Array
		or receipt.source_references.size() > 2
		or receipt.new_references.size() > 2
		or not Profile.same(receipt.source_references, required_references(before, after.operands))
	):
		return false
	for reference: Variant in receipt.new_references:
		if not Legacy.reference_valid(reference) or not Legacy._has_reference(after, reference):
			return false
	if before.is_empty():
		return receipt.kind == "create" and after.selected == "dynasty" and after.other.is_empty()
	if (
		receipt.kind == "create"
		or before.owner_id != after.owner_id
		or before.lineage.id != after.lineage.id
	):
		return false
	# Full source-dependent career arithmetic is projected before writing and
	# independently replayed by validate_recovery for a cold uncommitted intent.
	if receipt.kind in ["checkpoint", "close"]:
		var inactive: String = "other" if before.selected == "dynasty" else "dynasty"
		return after.selected == before.selected and Profile.same(before[inactive], after[inactive])
	if receipt.kind == "switch":
		return before.selected != after.selected and Profile.same(before.dynasty, after.dynasty)
	return (
		receipt.kind in ["begin_next", "choose_next"]
		and before.selected == "dynasty"
		and after.selected == "dynasty"
		and Profile.same(before.other, after.other)
	)


static func request_binding_valid(
	before_value: Variant,
	after_value: Variant,
	snapshot: Variant = null,
	_origin: Dictionary = {},
	origin_snapshot: Variant = null
) -> bool:
	var after: Dictionary = normalize(after_value)
	if after.is_empty() or not before_value is Dictionary:
		return false
	var request: Dictionary = _request(after, snapshot, origin_snapshot)
	return (
		not request.is_empty()
		and _request_valid(request)
		and request.expected_revision == before_value.get("revision", 0)
		and request.request_id == after.last_action.id
		and request.op == after.last_action.kind
		and Legacy.fingerprint(request) == after.last_action.fingerprint
	)


static func validate_checkpoint_extension(
	before: Variant, after: Variant, source: Variant, target: Variant
) -> bool:
	var owner: Dictionary = normalize(before)
	var candidate: Dictionary = normalize(after)
	if owner.is_empty() or candidate.is_empty() or candidate.last_action.kind != "checkpoint":
		return false
	var current: Dictionary = _qualified(owner, owner.selected, source)
	var checked: Dictionary = _qualified(candidate, candidate.selected, target)
	return (
		not current.is_empty()
		and not checked.is_empty()
		and Profile.same(current.session, checked.session)
		and _extends(current, checked, owner[owner.selected].frontier)
	)


static func origin_intent_valid(after: Dictionary, origin: Variant) -> bool:
	return Legacy.origin_intent_valid(after, origin)


static func qualify_origin(after: Dictionary, origin: Dictionary, snapshot: Variant) -> bool:
	return Legacy.qualify_origin(after, origin, snapshot)


static func validate_recovery(
	before: Dictionary,
	after: Dictionary,
	receipt: Dictionary,
	sources: Dictionary,
	target: Dictionary,
	origin: Variant
) -> bool:
	if not transition_valid(before, after, receipt):
		return false
	var request: Dictionary = _request(after, target, origin)
	if request.is_empty() or Legacy.fingerprint(request) != after.last_action.fingerprint:
		return false
	var replay: Dictionary = project(before, request, sources)
	return (
		not replay.is_empty()
		and Profile.same(replay.owner, after)
		and Profile.same(replay.receipt, receipt)
	)


static func _slot(checked: Dictionary) -> Dictionary:
	return Replay.slot(checked.session.session_id, checked.reference, checked.inner, checked.season)


static func _extends(before: Dictionary, after: Dictionary, frontier: Dictionary) -> bool:
	return Profile.same(before.session, after.session) \
		and Replay.extends_checkpoint(before.inner, after.inner, frontier)



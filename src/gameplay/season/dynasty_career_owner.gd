extends RefCounted
## Explicit owner-v2 dispatch. Historical owner-v1 is never upgraded implicitly.

const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")
const V3 = preload("res://src/gameplay/season/working_pitch_dynasty_owner.gd")
const V2 = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")


static func _new(value: Variant) -> bool:
	return value is Dictionary and value.get("version") == 2


static func normalize(value: Variant) -> Dictionary:
	if value is Dictionary and value.get("version") == V3.VERSION:
		return V3.normalize(value)
	return V2.normalize(value) if _new(value) else Legacy.normalize(value)


static func project(before: Variant, request: Variant, sources: Dictionary = {}) -> Dictionary:
	if before is Dictionary and (before.get("version") == V3.VERSION or (before.is_empty()
		and request is Dictionary and request.get("payload", {}).get("snapshot", {}).get("version") == V3.Save.BOUND_VERSION)):
		return V3.project(before, request, sources)
	var creating: bool = (
		before is Dictionary
		and before.is_empty()
		and request is Dictionary
		and request.get("op") == "create"
		and request.get("payload") is Dictionary
		and request.payload.get("snapshot") is Dictionary
		and V2.Save.Owned.version_in(request.payload.snapshot.get("version"), [83, 92, 96])
	)
	return (
		V2.project(before, request, sources)
		if _new(before) or creating
		else Legacy.project(before, request, sources)
	)


static func new_request_admitted(
	before: Dictionary, request: Dictionary, projected: Dictionary
) -> bool:
	if projected.get("version") == V3.VERSION:
		var current: Dictionary = V3.normalize(projected)
		return not current.is_empty() and (request.get("op") != "create" or (
			before.is_empty() and "dynasty" in V3.Authority.available_leagues(current.career)))
	# Only the durable Store's fresh-request path calls this policy boundary.
	# Historical deterministic projection and exact admitted intent replay remain unchanged.
	if not _new(projected):
		return true
	var after: Dictionary = V2.normalize(projected)
	if after.is_empty():
		return false
	if request.get("op") == "create":
		return before.is_empty() and "dynasty" in V2.Authority.available_leagues(after.career)
	var owner: Dictionary = V2.normalize(before)
	if owner.is_empty():
		return false
	if request.get("op") == "switch" and request.has("snapshot"):
		return (
			after.selected == "other"
			and after.other.profile.league in V2.Authority.available_leagues(owner.career)
		)
	# An exact existing lineage retains continuation rights, not a global unlock.
	# Resume, checkpoint, close, frozen pending choice and packs do not enroll a league.
	return true


static func required_references(before: Variant, request: Variant) -> Array:
	if before is Dictionary and before.get("version") == V3.VERSION:
		return V3.required_references(before, request)
	return (
		V2.required_references(before, request)
		if _new(before)
		else Legacy.required_references(before, request)
	)


static func validate_selected(value: Variant, snapshot: Variant) -> SeasonState:
	if value is Dictionary and value.get("version") == V3.VERSION:
		return V3.validate_selected(value, snapshot)
	return (
		V2.validate_selected(value, snapshot)
		if _new(value)
		else Legacy.validate_selected(value, snapshot)
	)


static func transition_valid(before: Variant, after: Variant, receipt: Variant) -> bool:
	if after is Dictionary and after.get("version") == V3.VERSION:
		return V3.transition_valid(before, after, receipt)
	return (
		V2.transition_valid(before, after, receipt)
		if _new(after)
		else (not _new(before) and Legacy.transition_valid(before, after, receipt))
	)


static func request_binding_valid(
	before: Variant,
	after: Variant,
	snapshot: Variant = null,
	origin: Dictionary = {},
	origin_snapshot: Variant = null
) -> bool:
	if after is Dictionary and after.get("version") == V3.VERSION:
		return V3.request_binding_valid(before, after, snapshot, origin, origin_snapshot)
	return (
		V2.request_binding_valid(before, after, snapshot, origin, origin_snapshot)
		if _new(after)
		else Legacy.request_binding_valid(before, after, snapshot, origin, origin_snapshot)
	)


static func validate_checkpoint_extension(
	before: Variant, after: Variant, source: Variant, target: Variant
) -> bool:
	if after is Dictionary and after.get("version") == V3.VERSION:
		return V3.validate_checkpoint_extension(before, after, source, target)
	return (
		V2.validate_checkpoint_extension(before, after, source, target)
		if _new(after)
		else (
			not _new(before) and Legacy.validate_checkpoint_extension(before, after, source, target)
		)
	)


static func origin_intent_valid(after: Dictionary, origin: Variant) -> bool:
	if after is Dictionary and after.get("version") == V3.VERSION:
		return V3.origin_intent_valid(after, origin)
	return (
		V2.origin_intent_valid(after, origin)
		if _new(after)
		else Legacy.origin_intent_valid(after, origin)
	)


static func qualify_origin(after: Dictionary, origin: Dictionary, snapshot: Variant) -> bool:
	if after is Dictionary and after.get("version") == V3.VERSION:
		return V3.qualify_origin(after, origin, snapshot)
	return (
		V2.qualify_origin(after, origin, snapshot)
		if _new(after)
		else Legacy.qualify_origin(after, origin, snapshot)
	)


static func validate_recovery(
	before: Dictionary,
	after: Dictionary,
	receipt: Dictionary,
	sources: Dictionary,
	target: Dictionary,
	origin: Variant
) -> bool:
	if after is Dictionary and after.get("version") == V3.VERSION:
		return V3.validate_recovery(before, after, receipt, sources, target, origin)
	return not _new(after) or V2.validate_recovery(before, after, receipt, sources, target, origin)


# Storage policy is bound by DynastyOwnerStore, never by serialized input.
static func storage_references(owner: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: String in ["dynasty", "other"]:
		var value: Variant = owner.get(slot, {})
		if value is Dictionary and Legacy.reference_valid(value.get("reference")):
			var duplicate: bool = false
			for reference: Dictionary in result:
				if Legacy.fingerprint(reference) == Legacy.fingerprint(value.reference):
					duplicate = true
					break
			if not duplicate:
				result.append(value.reference)
	return result


static func storage_selected_reference(owner: Dictionary) -> Dictionary:
	return owner.get(owner.get("selected", ""), {}).get("reference", {})


static func storage_pending_source(before: Dictionary, receipt: Dictionary) -> Dictionary:
	var reference: Dictionary = storage_selected_reference(before)
	if receipt.kind in ["begin_next", "choose_next"]:
		if before.selected != "dynasty":
			return {"error": "Pending rollover must bind its exact Dynasty source."}
		reference = before.dynasty.reference
	return {"reference": reference}


static func storage_requires_origin(owner: Dictionary) -> bool:
	return owner.lineage.start_profile.has("access")


static func storage_requires_recovery(owner: Dictionary) -> bool:
	return owner.get("version") in [2, V3.VERSION]

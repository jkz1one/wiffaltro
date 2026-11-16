extends RefCounted
## Owner-v2 access boundary. The original decay receipt is never rewritten.
## Its legacy validation view restores only the pre-rebase start access.

const Legacy = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const CAPTURE_VERSION: int = 2


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	if not value.has("access_rebase"):
		return Legacy.normalize(value)
	var proof: Variant = value.access_rebase
	if (
		not Profile.keys(proof, ["source_access", "target_sha256"])
		or not value.get("start_profile") is Dictionary
		or not value.get("current_profile") is Dictionary
	):
		return {}
	var source: Dictionary = ClosedContentAccess.normalize(proof.source_access)
	var target: Dictionary = ClosedContentAccess.normalize(value.start_profile.get("access"))
	if (
		source.is_empty()
		or target.is_empty()
		or not ClosedContentAccess.same_origin(source, target)
		or proof.target_sha256 != ClosedContentAccess.digest(target)
	):
		return {}
	var shadow: Dictionary = value.duplicate(true)
	shadow.erase("access_rebase")
	shadow.start_profile.access = source
	if value.get("version") == Legacy.VERSION:
		if not Profile.same(value.current_profile, value.start_profile):
			return {}
		shadow.current_profile.access = source
	if Legacy.normalize(shadow).is_empty():
		return {}
	var result: Dictionary = value.duplicate(true)
	result.start_profile = Profile.normalize(value.start_profile)
	result.current_profile = Profile.normalize(value.current_profile)
	if result.start_profile.is_empty() or result.current_profile.is_empty():
		return {}
	Profile.freeze(result)
	return result


static func rebase(value: Variant, access: Variant) -> Dictionary:
	var lineage: Dictionary = normalize(value)
	var target: Dictionary = ClosedContentAccess.normalize(access)
	if (
		lineage.is_empty()
		or target.is_empty()
		or lineage.state != "active"
		or lineage.version != Legacy.VERSION
		or not lineage.start_profile.has("access")
		or not ClosedContentAccess.same_origin(lineage.start_profile.access, target)
	):
		return {}
	var result: Dictionary = lineage.duplicate(true)
	var source: Dictionary = lineage.get("access_rebase", {}).get(
		"source_access", lineage.start_profile.access
	)
	result["access_rebase"] = {
		"source_access": source.duplicate(true), "target_sha256": ClosedContentAccess.digest(target)
	}
	result.start_profile.access = target.duplicate(true)
	result.current_profile.access = target.duplicate(true)
	return normalize(result)


static func legacy_view(value: Variant) -> Dictionary:
	var lineage: Dictionary = normalize(value)
	if lineage.is_empty() or not lineage.has("access_rebase"):
		return lineage
	var result: Dictionary = lineage.duplicate(true)
	result.start_profile.access = result.access_rebase.source_access.duplicate(true)
	if result.version == Legacy.VERSION:
		result.current_profile.access = result.start_profile.access.duplicate(true)
	result.erase("access_rebase")
	return Legacy.normalize(result)


static func advance(value: Variant, request: Dictionary) -> Dictionary:
	# Current captured profile, including its earned access, remains unchanged
	# in the legacy view. Only historical start access differs.
	var source: Dictionary = normalize(value)
	if source.is_empty() or source.version != CAPTURE_VERSION:
		return {}
	return Legacy.advance(legacy_view(source), request)


static func close(value: Variant, outcome: String) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or outcome not in ["win", "loss", "abandon"]:
		return {}
	if source.state == "closed" and source.closed_reason == outcome:
		return source
	if source.state != "active":
		return {}
	var result: Dictionary = source.duplicate(true)
	result.state = "closed"
	result.closed_reason = outcome
	return normalize(result)


static func pause(value: Variant) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or source.state not in ["active", "closed"]:
		return {}
	var result: Dictionary = source.duplicate(true)
	result.resume_state = source.state
	result.state = "paused"
	return normalize(result)


static func resume(value: Variant) -> Dictionary:
	var source: Dictionary = normalize(value)
	if source.is_empty() or source.state != "paused":
		return {}
	var result: Dictionary = source.duplicate(true)
	result.state = source.resume_state
	result.resume_state = ""
	return normalize(result)


static func fingerprint(value: Dictionary) -> String:
	return Legacy.fingerprint(value)


static func _capture_header(data: Dictionary) -> String:
	return Legacy._capture_header(data)


static func _capture_prefix(data: Dictionary, count: int) -> String:
	return Legacy._capture_prefix(data, count)

extends RefCounted
## Standard-specific frozen slot/frontier. Does not reinterpret ordinary saves
## as closed-league sources. Call only after StandardSave full qualification.
const Legacy = preload("res://src/gameplay/season/dynasty_owner.gd")
const Ops = preload("res://src/gameplay/season/dynasty_owner_operations_1.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")


static func profile(tier: int) -> Dictionary:
	return {"version": 1, "league": "standard", "tier": tier,
		"profile": "standard-owner-owned-venues-v1"} if tier in [0, 1, 2, 3, 4] else {}


static func core(raw: Dictionary) -> Dictionary:
	if SeasonOwnership._whole(raw.get("version"), 81, 81) and raw.get("checkpoint") is Dictionary:
		raw = raw.checkpoint
	return raw if raw.get("build") is Dictionary and raw.get("opponents") is Dictionary \
		and raw.get("physical") is Dictionary else {}


static func header(raw: Dictionary) -> Dictionary:
	var outer_version: Variant = raw.get("version")
	raw = core(raw)
	var result: Dictionary = {"outer_version": outer_version}
	for field: String in ["version", "terrain_save_version", "legacy_save_version", "seed", "pool",
		"draws", "home_property", "npc_venues", "final_venue", "owned_surface_night", "player_access",
		"draft_rule", "sponsor_rule"]:
		if raw.has(field):
			result[field] = raw[field]
	var opponents: Dictionary = raw.opponents.duplicate(true)
	opponents.erase("clubs")
	opponents.erase("draft_order")
	result["opponents"] = opponents
	return result


static func frontier(raw: Dictionary, season: SeasonState) -> Dictionary:
	var result: Dictionary = Ops._frontier(core, Lineage, Legacy.fingerprint, Legacy._exit_ready, raw, season)
	result.header_hash = Legacy.fingerprint(header(raw))
	return result


static func slot(checked: Dictionary) -> Dictionary:
	return {"session_id": checked.session.session_id, "reference": checked.reference,
		"snapshot_version": checked.session.get("format", Bound.VERSION), "profile": profile(int(checked.session.tier)),
		"seed": checked.session.seed, "start_hash": checked.session.grant_sha256,
		"checkpoint_revision": checked.season.build.revision(),
		"frontier": frontier(checked.inner, checked.season)}


static func extends_checkpoint(before: Dictionary, after: Dictionary, prior_frontier: Dictionary) -> bool:
	if core(before).is_empty() or core(after).is_empty() \
		or Legacy.fingerprint(header(before)) != prior_frontier.header_hash \
		or Legacy.fingerprint(header(after)) != prior_frontier.header_hash:
		return false
	return Ops._extends(core, Legacy._prefix, Lineage, _pending_extends,
		before, after, prior_frontier)


static func _pending_extends(before: Dictionary, after: Dictionary) -> bool:
	return Ops._pending_extends(Legacy.Profile, Legacy._prefix, _human_matches, before, after)


static func _human_matches(human: Array, result: Dictionary) -> bool:
	# Both snapshots already passed StandardSave qualification. This is exact
	# continuation identity, not admission of standalone human evidence.
	# Standard slot13 is reserved replayed-tactics, NOT doubleheader evidence.
	if human.size() not in [15, 16, 17, 18] or not human[13] is Array \
		or not human[13].is_empty() or not human[14] is String \
		or result.get("id") != human[0] or result.get("property") != human[14] \
		or result.has("doubleheader_evidence") or result.has("inventory_final") \
		or (human.size() != 18 and result.has("night_evidence")):
		return false
	if human.size() == 15:
		if result.has("pool_evidence") or result.has("yard_evidence"):
			return false
	elif human.size() == 16:
		if not human[15] is Dictionary or result.has("yard_evidence") \
			or not Legacy.Profile.same(result.get("pool_evidence"), human[15]):
			return false
	elif human.size() == 17:
		if human[15] != null or not human[16] is Dictionary or result.has("pool_evidence") \
			or not Legacy.Profile.same(result.get("yard_evidence"), human[16]):
			return false
	else:
		if human[15] != null or human[16] != null or not human[17] is Dictionary \
			or result.has("pool_evidence") or result.has("yard_evidence") \
			or not Legacy.Profile.same(result.get("night_evidence"), human[17]):
			return false
	return Legacy._human_matches(human.slice(0, 13), result)

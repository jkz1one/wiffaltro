extends RefCounted
## Runtime-only adapter for the selected, saved Standard89 owner. A live grant
## or transient replay ledger alone never admits a paid stadium or collector.
const Live = preload("res://src/gameplay/season/dynasty_standard_live.gd")
const Bound = preload("res://src/gameplay/season/dynasty_standard_save.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")


static func paid_ledger(season: SeasonState) -> ClubAssetLedger:
	if season == null or not Live.matches(season) or season._pool_replay_ledger == null \
		or not SeasonSave.dynasty_owner_bound():
		return null
	var session: Dictionary = Bound.binding(season._dynasty_career_session)
	var binding: Dictionary = season._dynasty_owner_binding
	if session.is_empty() or session.get("format") != Bound.LIVE_VERSION \
		or not ClubCareer.same(session, season._standard_live_context.session) \
		or not ClubCareer.same(season._standard_bound_grant, season._standard_live_context.grant) \
		or binding.get("path") != SeasonSave._dynasty_owner_path \
		or binding.get("session_id") != session.session_id:
		return null
	var found: Dictionary = Store.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	if found.get("status") != "ready" or owner.get("version") != 2 \
		or owner.get("selected") != "other" or binding.get("revision") != found.get("revision"):
		return null
	var slot: Dictionary = owner.get("other", {})
	var entry: Dictionary = owner.get("career", {}).get("sessions", {}).get(session.session_id, {})
	if slot.get("session_id") != session.session_id or entry.is_empty() \
		or not ClubCareer.same(entry.session, session) \
		or not ClubCareer.same(entry.get("standard_grant"), season._standard_bound_grant):
		return null
	# Snapshot validates the entire current/replayed season, not just its mutable
	# in-memory context. The grant above is pinned to the authoritative owner.
	if SeasonSave.snapshot(season).is_empty():
		return null
	var history: ClubCareer = preload("res://src/gameplay/season/dynasty_standard_grant.gd").history_club(entry.standard_grant.history)
	var paid: ClubAssetLedger = ClubPlayers.assets(history)
	if paid == null or not ClubCareer.same(paid.to_data(), season._pool_replay_ledger.to_data()) \
		or not StadiumLayoutSnapshot.matches(season.home_property, paid):
		return null
	return paid.fork()


static func projected_ledger(source: SeasonState, candidate: SeasonState, fixture: Dictionary) -> ClubAssetLedger:
	# A partial round candidate deliberately is not independently serializable:
	# accepted AI games may precede the round's atomic publication. Qualify the
	# saved source, then reproduce and compare the entire disposable projection.
	var paid: ClubAssetLedger = paid_ledger(source)
	if paid == null or candidate == null or candidate.get_script() != SeasonState \
		or not Live.matches(candidate):
		return null
	var projected: Dictionary = SeasonRoundSettlement.project(source)
	if not projected.has("fixture") or not projected.has("candidate") \
		or not ClubCareer.same(fixture, projected.fixture) \
		or not _same_projection(candidate, projected.candidate):
		return null
	return paid


static func _same_projection(candidate: SeasonState, expected: SeasonState) -> bool:
	for property: Dictionary in expected.get_property_list():
		if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
			continue
		var key: String = property.name
		var left: Variant = candidate.get(key)
		var right: Variant = expected.get(key)
		if (left is Object or right is Object) \
			and key not in ["ownership", "build", "opponents", "physical", "_pool_replay_ledger"]:
			return false
		if not _same_value(left, right):
			return false
	return true


static func _same_value(left: Variant, right: Variant, depth: int = 0) -> bool:
	# Include derived runtime state, not just serialized journals: a changed cash
	# cache or transient needed/error state must not borrow a validated report.
	# These reviewed state graphs are acyclic; unexpected cycles/depth fail shut.
	if depth > 64:
		return false
	if left is Object or right is Object:
		if not left is RefCounted or not right is RefCounted \
			or left is Resource or right is Resource \
			or left.get_script() == null or left.get_script() != right.get_script():
			return false
		for property: Dictionary in right.get_property_list():
			if (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0 \
				and not _same_value(left.get(property.name), right.get(property.name), depth + 1):
				return false
		return true
	if left is Dictionary or right is Dictionary:
		if not left is Dictionary or not right is Dictionary or left.size() != right.size():
			return false
		for key: Variant in right:
			if not left.has(key) or not _same_value(left[key], right[key], depth + 1):
				return false
		return true
	if left is Array or right is Array:
		if not left is Array or not right is Array or left.size() != right.size():
			return false
		for index in range(right.size()):
			if not _same_value(left[index], right[index], depth + 1):
				return false
		return true
	return ClubCareer.same(left, right)

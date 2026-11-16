extends RefCounted
## Versioned shared authority additions. Old91/92 entries never infer time.
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const ALTERNATE_AUTHORITY: int = 35
const CARRIED_AUTHORITY: int = 36

static func entry_valid(entry: Dictionary) -> bool:
	var value: Variant = entry.get("time_home")
	if not TimeHome.header_valid(value) or not ClubCareer.same(value.session, entry.get("session")) \
		or not entry.get("admission_frontier") is Dictionary \
		or value.time_run != entry.admission_frontier.size() + 1: return false
	var base: Dictionary = value.base_header
	if value.version == TimeHome.CARRIED:
		return not entry.has("league_home_grant") and not entry.has("standard_grant") \
			and ClubCareer.same(entry.get("dynasty_home"), base)
	return not entry.has("dynasty_home") and not entry.has("standard_grant") \
		and entry.get("home_format") == TimeHome.ALTERNATE \
		and ClubCareer.same(entry.get("league_home_grant"), base.grant) \
		and ClubCareer.same(entry.get("home_property"), base.home_property)

static func open_alternate(value: Dictionary, snapshot: Dictionary) -> Dictionary:
	var authority: Dictionary = Authority.normalize(value)
	if authority.is_empty() or snapshot.get("version") != TimeHome.ALTERNATE \
		or not TimeHome.header_valid(TimeHome.header(snapshot)): return {}
	var expected: Dictionary = TimeHome.prepare_alternate(authority, snapshot.session, snapshot.starting_profile)
	if expected.is_empty() or not ClubCareer.same(expected, snapshot): return {}
	var base: Dictionary = TimeHome.original(snapshot)
	var opened: Dictionary = Authority.open_session(authority, base) if not base.is_empty() else {}
	if opened.is_empty(): return {}
	var entry: Dictionary = opened.sessions[snapshot.session.session_id]
	entry["time_home"] = TimeHome.header(snapshot)
	entry.home_format = TimeHome.ALTERNATE
	opened.version = maxi(int(opened.version), ALTERNATE_AUTHORITY)
	return Authority._checkpoint_checked(Authority.normalize(opened), snapshot.session.session_id,
		TimeHome.qualify(snapshot, entry.time_home))

static func bind_carried(value: Dictionary, owner: Dictionary, snapshot: Dictionary) -> Dictionary:
	var authority: Dictionary = Authority.normalize(value)
	if authority.is_empty() or not ClubCareer.same(authority, owner.get("career")) \
		or snapshot.get("version") != TimeHome.CARRIED or not TimeHome.header_valid(TimeHome.header(snapshot)) \
		or snapshot.time_run != authority.sessions.size(): return {}
	var base: Dictionary = TimeHome.original(snapshot)
	if base.is_empty() or not ClubCareer.same(Save.snapshot_reference(base), owner.get("dynasty", {}).get("reference")): return {}
	var id: String = snapshot.session.session_id
	var entry: Dictionary = authority.sessions.get(id, {})
	if entry.is_empty() or entry.get("settled") != 0 or entry.has("time_home") \
		or not ClubCareer.same(entry.get("dynasty_home"), snapshot.base_header): return {}
	entry["time_home"] = TimeHome.header(snapshot)
	authority.version = CARRIED_AUTHORITY
	return Authority._checkpoint_checked(Authority.normalize(authority), id, TimeHome.qualify(snapshot, entry.time_home))

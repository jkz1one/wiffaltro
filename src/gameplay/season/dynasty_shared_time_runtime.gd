extends RefCounted
## Selected committed95/96 authority, never a file-supplied grant or second wallet.
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")

static func paid_ledger(season: SeasonState) -> ClubAssetLedger:
	if not TimeHome.matches(season) or not SeasonSave.dynasty_owner_bound(): return null
	var value: Dictionary = season._league_home_context.header
	var binding: Dictionary = season._dynasty_owner_binding
	if binding.get("path") != SeasonSave._dynasty_owner_path \
		or binding.get("session_id") != value.session.session_id: return null
	var found: Dictionary = Store.inspect(SeasonSave._dynasty_owner_path)
	var owner: Dictionary = found.get("owner", {})
	var selected: String = "dynasty" if value.version == TimeHome.CARRIED else "other"
	if found.get("status") != "ready" or owner.get("version") != 2 \
		or owner.get("selected") != selected or binding.get("revision") != found.get("revision"): return null
	var slot: Dictionary = owner.get(selected, {})
	var entry: Dictionary = owner.get("career", {}).get("sessions", {}).get(value.session.session_id, {})
	if slot.get("session_id") != value.session.session_id or slot.get("snapshot_version") != value.version \
		or not ClubCareer.same(entry.get("time_home"), value) \
		or not ClubCareer.same(entry.get("session"), value.session): return null
	var snapshot: Dictionary = TimeHome.capture(season)
	if snapshot.is_empty() or not ClubCareer.same(Save.snapshot_reference(snapshot), slot.get("reference")): return null
	var paid: ClubAssetLedger = TimeHome._paid(value.base_header)
	return paid.fork() if paid != null and ClubCareer.same(paid.to_data(), season._pool_replay_ledger.to_data()) else null

static func projected_ledger(source: SeasonState, candidate: SeasonState, fixture: Dictionary) -> ClubAssetLedger:
	var paid: ClubAssetLedger = paid_ledger(source)
	if paid == null or candidate == null or candidate.get_script() != SeasonState or not TimeHome.matches(candidate): return null
	var expected: Dictionary = SeasonRoundSettlement.project(source)
	if not expected.has("fixture") or not expected.has("candidate") \
		or not ClubCareer.same(fixture, expected.fixture) \
		or not load("res://src/gameplay/season/dynasty_league_home_runtime.gd")._same_projection(candidate, expected.candidate): return null
	return paid

static func future_editable(season: SeasonState) -> bool:
	# Authority edits can affect only future admissions. Never recapture this slot.
	return season != null and season._league_home_context.get("format") == TimeHome.ALTERNATE \
		and season.phase == SeasonState.Phase.DRAFT and season.picks.is_empty() \
		and season.results.is_empty() and season.player_results.is_empty() and season.physical != null \
		and season.physical.cursor == 0 and season.physical.pending.is_empty() \
		and season.physical.reports.is_empty() and TimeHome.matches(season)

extends RefCounted
## Explicit, detached enrollment. No implicit source import or owner-v1 migration.

const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Unlocks = preload("res://src/gameplay/season/league_unlocks.gd")

var app: SeasonApp
var path: String
var error: String = ""
var _payload: Dictionary = {}
var _base_payload: Dictionary = {}
var _profile_choice: Variant = null  # Empty Day is an explicit choice, not unset.
var _profile_source: String = ""
var _source: SeasonState
var _source_hash: String = ""
var _source_disk: String = ""
var _source_path: String = ""
var _ticket: int = 0
var _attempted: bool = false


func _init(owner_app: SeasonApp, owner_path: String) -> void:
	app = owner_app
	path = owner_path


func _fail(message: String) -> bool:
	error = message
	app.notice = message
	return false


func pending() -> bool:
	return not _payload.is_empty()


func attempted() -> bool:
	return _attempted


func token() -> int:
	return _ticket if pending() else -1


func preview() -> Dictionary:
	return _payload.get("lineage", {}).get("start_profile", {}).duplicate(true)


func prepare(seed_value: int) -> bool:
	# A new review replaces an unattempted choice, even when the new request fails.
	# An attempted handoff is different: its exact payload must remain retryable.
	if pending() and not _attempted:
		cancel(token())
	if (
		_attempted or SeasonSave.dynasty_owner_bound() or app._unsaved_draft != null
		or not app.dynasty_owner._safe_hub() or Store.inspect(path).get("status") != "empty"
	):
		return _fail("Finish the current action or recover the saved owner before starting Dynasty.")
	if not _entry_ready(seed_value):
		return false
	var current_catalog: bool = app.season.build != null and app.season.build.pitch_catalog_current()
	if current_catalog and (not app.season.home_property.is_empty() or not app.season._league_home_context.is_empty()
		or not app.season._standard_live_context.is_empty()):
		return _fail("Current-pitch Dynasty does not yet support this home context. Your saved career is unchanged.")
	var origin: Dictionary = SeasonSave.snapshot(app.season)
	if not _saved_source_matches(origin):
		return _fail("Save or recover the current season before reviewing Dynasty enrollment. Your current season is unchanged.")
	var suffix: String = "%d:%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var profile: Dictionary = Profile.capture_access_season(
		origin, "dynasty:" + suffix, "career:" + suffix
	)
	if profile.is_empty():
		return _fail(
			"This roster cannot start Dynasty. Scramble sources and unsupported first-entry "
			+ "ability overflow are not converted. Your current season is unchanged."
		)
	profile = profile.duplicate(true)
	profile.seed = seed_value
	var next: SeasonState = Bridge.create(profile)
	if next == null:
		return _fail("The carried roster could not be validated. Your current season is unchanged.")
	if current_catalog:
		var authority_script: GDScript = load("res://src/gameplay/season/working_pitch_dynasty_authority.gd")
		var authority: Dictionary = authority_script.create(origin, profile.owner_id)
		if not authority_script.install_start(authority, next):
			return _fail("The earned pitch history could not be bound to this fresh Dynasty season.")
	var session_id: String = profile.lineage_id + ":1"
	var save_contract: GDScript = WorkingPitchDynastySave if current_catalog else Save
	var snapshot: Dictionary = save_contract.wrap_checkpoint(SeasonSave.snapshot(next), Save.binding_for(
		next, profile.owner_id, profile.lineage_id, 0, 1, session_id
	))
	if snapshot.is_empty():
		return _fail("The Dynasty checkpoint could not be prepared. Your current season is unchanged.")
	_payload = {
		"lineage": Lineage.create(profile), "snapshot": snapshot,
		"session_id": session_id, "origin": origin
	}
	if not current_catalog:
		_payload = load("res://src/gameplay/season/dynasty_carried_home_proposal.gd").prepare_create(_payload)
	if _payload.is_empty():
		return _fail("This paid home is not ready for carried Dynasty play. Your current season is unchanged.")
	_base_payload = _payload.duplicate(true)
	var source_key: String = Store.fingerprint(origin)
	if _profile_source != source_key:
		_profile_source = source_key
		_profile_choice = null
	var selected: String = load("res://src/gameplay/season/dynasty_shared_time.gd").preference(app.season) \
		if _profile_choice == null else str(_profile_choice)
	if not selected.is_empty():
		if current_catalog:
			return _fail("Current-pitch Dynasty does not yet support this home-time choice. Your saved career is unchanged.")
		_payload = load("res://src/gameplay/season/dynasty_shared_time_transactions.gd").prepare_create(_base_payload, selected)
		if _payload.is_empty():
			_base_payload = {}
			return _fail("This home-time profile cannot carry into Dynasty. Your source is unchanged; no Day fallback was made.")
	_source = app.season
	_source_hash = Store.fingerprint(origin)
	_source_path = SeasonSave.path
	_source_disk = FileAccess.get_file_as_string(_source_path).sha256_text()
	_ticket += 1
	error = ""
	app.notice = ""
	return true


func _saved_source_matches(origin: Dictionary) -> bool:
	# Read only the primary source. Restore could silently fall back to a backup,
	# leaving a different file archived after enrollment.
	if origin.is_empty() or not FileAccess.file_exists(SeasonSave.path):
		return false
	var parser: JSON = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SeasonSave.path)) != OK:
		return false
	var data: Variant = parser.data
	if not data is Dictionary:
		return false
	var saved: SeasonState = SeasonSave._decode(data)
	if saved == null:
		return false
	# Compare canonical snapshots so harmless JSON formatting and supported legacy
	# decoding do not prevent a matching saved roster from being reviewed.
	return Store.fingerprint(SeasonSave.snapshot(saved)) == Store.fingerprint(origin)


func _entry_ready(seed_value: int) -> bool:
	if not SeasonOwnership._whole(seed_value, 0, 2147483647) or app.season.picks.size() != 4:
		return _fail("Finish all four draft picks before enrolling this roster in Dynasty.")
	if app.season.career == null or "dynasty" not in app.season.career.available_leagues():
		return _fail(Unlocks.requirement("dynasty") + " Your current season is unchanged.")
	return true


func cancel(ticket: int) -> bool:
	if ticket < 0 or ticket != token() or _attempted:
		return false
	_payload = {}
	_base_payload = {}
	_source = null
	_ticket += 1
	return true


func commit(ticket: int) -> bool:
	if not _attempted and _payload.get("snapshot", {}).get("version") == 96 \
		and not load("res://src/gameplay/season/dynasty_shared_time.gd").ENTRY_ENABLED:
		return _fail("Modern home-time Dynasty entry is not enabled yet. Your current season is unchanged.")
	if ticket < 0 or ticket != token():
		return _fail("This Dynasty start choice is out of date.")
	if not _attempted and (
		SeasonSave.dynasty_owner_bound() or app.season != _source or not app.dynasty_owner._safe_hub()
		or SeasonSave.path != _source_path
		or Store.fingerprint(SeasonSave.snapshot(app.season)) != _source_hash
		or FileAccess.get_file_as_string(_source_path).sha256_text() != _source_disk
	):
		return _fail("The source season changed. Cancel and review Dynasty enrollment again.")
	if not _attempted and (
		app.season.career == null or "dynasty" not in app.season.career.available_leagues()
	):
		return _fail(Unlocks.requirement("dynasty") + " Your current season is unchanged.")
	_attempted = true
	var outcome: Dictionary = Store.create(_payload, path)
	# After a write attempt, never silently fall back to the old sequential candidate.
	SeasonSave.bind_dynasty_owner(path)
	if outcome.get("status") != "committed":
		SeasonSave._dynasty_owner_content_blocked = true
		app.season = null
		return _fail(str(outcome.get("reason", "Retry this exact Dynasty start or recover its save.")))
	if not app.dynasty_owner._promote(Store.restore(path)):
		app.season = null
		return false
	_payload = {}
	_base_payload = {}
	_source = null
	_ticket += 1
	error = ""
	app.menu.show_home()
	return true


func time_profile() -> String:
	return str(_payload.get("snapshot", {}).get("starting_profile", ""))

func starting_profile(ticket: int, selected: String) -> bool:
	if ticket < 0 or ticket != token() or _attempted or _base_payload.is_empty() \
		or (not selected.is_empty() and selected not in load("res://src/gameplay/season/dynasty_shared_time.gd").PROFILES):
		return false
	if _base_payload.get("snapshot", {}).get("version") == WorkingPitchDynastySave.BOUND_VERSION and not selected.is_empty():
		return _fail("Current-pitch Dynasty does not support home-time choices. The existing review is unchanged.")
	var candidate: Dictionary = _base_payload.duplicate(true) if selected.is_empty() else \
		load("res://src/gameplay/season/dynasty_shared_time_transactions.gd").prepare_create(_base_payload, selected)
	if candidate.is_empty(): return _fail("This selected time requires a qualified paid home. Your prior review remains unchanged.")
	_payload = candidate
	_profile_choice = selected
	_ticket += 1
	error = ""
	app.notice = ""
	return true

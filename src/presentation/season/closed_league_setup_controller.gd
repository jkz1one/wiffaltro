extends RefCounted
## Development-only first alternate. No enrollment authority or public unlocks.
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Owner = preload("res://src/gameplay/season/dynasty_owner.gd")
var app: Node
var error: String = ""
var selection: String = ""
var _candidate: SeasonState
var _token: String = ""
var _path: String = ""
var _revision: int = -1
var _owner_id: String = ""
var _source_reference: Dictionary = {}
var _request: Dictionary = {}
var _serial: int = 0
var _busy: bool = false


func _init(owner_app: Node) -> void:
	app = owner_app


func token() -> String:
	return _token


func candidate() -> SeasonState:
	return _candidate


func has_attempt() -> bool:
	return not _request.is_empty()


func _fail(message: String) -> bool:
	error = message
	return false


func _safe() -> bool:
	return app != null and app.dynasty_owner != null and app.dynasty_owner._safe_hub()


func _source_matches(owner: Dictionary) -> bool:
	if app.season == null or owner.is_empty() or owner.selected != "dynasty":
		return false
	var binding: Dictionary = app.season._dynasty_owner_binding
	if (
		binding.get("path") != _path
		or binding.get("revision") != _revision
		or binding.get("session_id") != owner.dynasty.session_id
	):
		return false
	var snapshot: Dictionary = SeasonSave.snapshot(app.season)
	var saved: Dictionary = Store.read_snapshot(_path, owner.dynasty.reference)
	return (
		not snapshot.is_empty()
		and not saved.is_empty()
		and Owner.fingerprint(snapshot) == Owner.fingerprint(saved)
	)


func prepare_alternate(league_id: String, seed_value: int, expected_revision: int) -> bool:
	if _busy or not _token.is_empty():
		return _fail("Finish or cancel the current setup first.")
	if not _safe() or not SeasonSave.dynasty_owner_bound():
		return _fail("Open a saved closed owner at a safe hub first.")
	if league_id == "dynasty" or league_id not in LeagueRules.IDS:
		return _fail("This setup only creates the owner's first non-Dynasty alternate.")
	var rules: Dictionary = LeagueRules.capture(
		league_id, 0, seed_value if league_id == "scramble" else null
	)
	if rules.is_empty():
		return _fail("That Base profile is unavailable.")
	_path = SeasonSave._dynasty_owner_path
	var found: Dictionary = Store.inspect(_path)
	var owner: Dictionary = found.get("owner", {})
	if found.get("status") != "ready" or owner.is_empty():
		return _fail("Recover the saved owner before preparing a new alternate.")
	return _prepare_alternate_remaining_checks(seed_value, expected_revision, rules, found, owner)


func _prepare_alternate_remaining_checks(
	seed_value: int,
	expected_revision: int,
	rules: Dictionary,
	found: Dictionary,
	owner: Dictionary
) -> bool:
	if found.get("revision") != expected_revision:
		return _fail("This choice is out of date. Reopen the catalog.")
	if owner.selected != "dynasty" or not owner.other.is_empty():
		return _fail("An existing alternate must resume unchanged; it cannot be replaced here.")
	_revision = expected_revision
	if not _source_matches(owner):
		return _fail("The live source differs from its saved checkpoint. Save or recover it first.")
	var next: SeasonState = SeasonState.create_closed_league(
		seed_value, rules, true, owner.lineage.current_profile.get("access", {})
	)
	if next == null:
		return _fail("The requested closed season could not be prepared.")
	_serial += 1
	_token = (
		"alternate:%d:%d:%d:%d" % [OS.get_process_id(), Time.get_ticks_usec(), _serial, _revision]
	)
	_owner_id = owner.owner_id
	_source_reference = owner.dynasty.reference.duplicate(true)
	_candidate = next
	selection = ""
	error = ""
	return true


func choose_player(ticket: String, pick_index: int, player_id: String) -> bool:
	if (
		_busy
		or ticket.is_empty()
		or ticket != _token
		or _candidate == null
		or not _request.is_empty()
		or pick_index != _candidate.picks.size()
	):
		return _fail("This draft choice is out of date.")
	if not _fresh_owner():
		return false
	# Draft failures never partially alter the retained setup, including pick four.
	var next: SeasonState = SeasonSave._decode(SeasonSave.snapshot(_candidate))
	if next == null or not next.choose_player(player_id):
		return _fail("Choose one of the current three offers.")
	if next.picks.size() == 4 and not SeasonInventoryRules.enable(next):
		return _fail("The fresh inventory contract could not be admitted; your setup is unchanged.")
	if SeasonSave.snapshot(next).is_empty():
		return _fail("The prepared roster failed validation; your setup is unchanged.")
	_candidate = next
	selection = ""
	error = ""
	return true


func _fresh_owner() -> bool:
	if not _safe() or SeasonSave._dynasty_owner_path != _path:
		return _fail("The saved owner binding changed. Reopen setup.")
	var found: Dictionary = Store.inspect(_path)
	var owner: Dictionary = found.get("owner", {})
	if (
		found.get("status") != "ready"
		or found.get("revision") != _revision
		or owner.get("owner_id") != _owner_id
		or owner.get("selected") != "dynasty"
		or not owner.get("other", {}).is_empty()
		or owner.get("dynasty", {}).get("reference") != _source_reference
	):
		return _fail("The saved owner changed or needs recovery. This setup cannot replace it.")
	if not _source_matches(owner):
		return _fail("The live source changed. Save or recover it before continuing.")
	return true


func commit_alternate(ticket: String) -> bool:
	if _busy or ticket.is_empty() or ticket != _token or _candidate == null:
		return _fail("This enrollment choice is out of date.")
	if not _safe() or SeasonSave._dynasty_owner_path != _path:
		return _fail("Return to the original saved owner at a safe hub first.")
	return _commit_alternate_remaining_checks()


func _commit_alternate_remaining_checks() -> bool:
	if _request.is_empty():
		if not _fresh_owner():
			return false
		if (
			_candidate.picks.size() != 4
			or not SeasonInventoryRules.valid(_candidate.inventory_rules)
		):
			return _fail("Choose all four players before enrolling.")
		var snapshot: Dictionary = SeasonSave.snapshot(_candidate)
		if snapshot.is_empty():
			return _fail("The completed setup could not be validated.")
		_request = {
			"op": "switch",
			"request_id": _token,
			"expected_revision": _revision,
			"target": "other",
			"session_id": _token,
			"snapshot": snapshot
		}
		preload("res://src/gameplay/season/dynasty_start_profile.gd").freeze(_request)
	# Preserve exactly the first request through interruption. Store distinguishes
	# precommit retry, committed repair, stale intent and unrelated newer actions.
	_busy = true
	var outcome: Dictionary = Store.commit(_request, _path)
	var ok: bool = outcome.get("status") == "committed" and app.dynasty_owner._promote(outcome)
	_busy = false
	if not ok:
		var reason: String = (
			app.notice if outcome.get("status") == "committed" else str(outcome.get("reason", ""))
		)
		return _fail(
			reason if not reason.is_empty() else "Enrollment needs its exact retry or recovery."
		)
	_clear()
	app.show_season()
	return true


func cancel(ticket: String) -> bool:
	if _busy or ticket.is_empty() or ticket != _token:
		return _fail("This setup is no longer current.")
	if not _request.is_empty():
		var found: Dictionary = Store.inspect(_path)
		if found.get("status") != "ready" or found.get("revision") != _revision:
			return _fail(
				"An enrollment may already be committed or pending. Retry or recover it; do not reset it."
			)
	_clear()
	return true


func recover() -> bool:
	if (
		_busy
		or app == null
		or app.dynasty_owner == null
		or app.lab != null
		or app._busy
		or (_path != "" and SeasonSave._dynasty_owner_path != _path)
		or (
			app.season != null
			and app.season.physical != null
			and not app.season.physical.pending.is_empty()
		)
	):
		return _fail("Return to the saved owner at a safe hub before recovery.")
	if not app.dynasty_owner.recover():
		return _fail(app.notice)
	if not _request.is_empty():
		var owner: Dictionary = Store.inspect(_path).get("owner", {})
		if owner.get("other", {}).get("session_id") == _token:
			_clear()
	error = ""
	return true


func _clear() -> void:
	_candidate = null
	_token = ""
	_path = ""
	_revision = -1
	_owner_id = ""
	_source_reference = {}
	_request = {}
	selection = ""
	error = ""

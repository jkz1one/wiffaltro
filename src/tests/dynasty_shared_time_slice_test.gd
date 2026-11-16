extends "res://src/tests/dynasty_shared_time_test.gd"
## Test-only independent slices. No old owner/checkpoint is an input.
## Inherited _source, _contracts, _live and authority APIs stay unchanged.
## A slice result is NOT the original332-check acceptance seal.
const SLICE_CASES: Dictionary = {
  "contract96-day": {
    "kind": "contract",
    "version": 96,
    "profile": "day",
    "league": "dynasty",
    "tier": 0,
    "expected_checks": 21,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract96-sunset": {
    "kind": "contract",
    "version": 96,
    "profile": "sunset",
    "league": "dynasty",
    "tier": 0,
    "expected_checks": 21,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract96-night": {
    "kind": "contract",
    "version": 96,
    "profile": "night",
    "league": "dynasty",
    "tier": 0,
    "expected_checks": 32,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract96-fixed_night": {
    "kind": "contract",
    "version": 96,
    "profile": "fixed_night",
    "league": "dynasty",
    "tier": 0,
    "expected_checks": 21,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract95-day": {
    "kind": "contract",
    "version": 95,
    "profile": "day",
    "league": "dugout",
    "tier": 0,
    "expected_checks": 23,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract95-sunset": {
    "kind": "contract",
    "version": 95,
    "profile": "sunset",
    "league": "dugout",
    "tier": 0,
    "expected_checks": 23,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract95-night": {
    "kind": "contract",
    "version": 95,
    "profile": "night",
    "league": "dugout",
    "tier": 0,
    "expected_checks": 34,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract95-fixed_night": {
    "kind": "contract",
    "version": 95,
    "profile": "fixed_night",
    "league": "dugout",
    "tier": 0,
    "expected_checks": 23,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract95-doubleheader-tier0": {
    "kind": "contract",
    "version": 95,
    "profile": "night",
    "league": "doubleheader",
    "tier": 0,
    "expected_checks": 23,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "contract95-dugout-tier1": {
    "kind": "contract",
    "version": 95,
    "profile": "night",
    "league": "dugout",
    "tier": 1,
    "expected_checks": 24,
    "cap_seconds": 900,
    "aggregate_required": true
  },
  "metadata": {
    "kind": "metadata",
    "expected_checks": 8,
    "cap_seconds": 180,
    "aggregate_required": false
  },
  "enrollment-create": {
    "kind": "enrollment",
    "expected_checks": 23,
    "cap_seconds": 900,
    "aggregate_required": false
  },
  "worker96-fresh": {
    "kind": "worker96",
    "expected_checks": 30,
    "cap_seconds": 900,
    "aggregate_required": false
  },
  "worker95-fresh": {
    "kind": "worker95",
    "expected_checks": 33,
    "cap_seconds": 900,
    "aggregate_required": false
  },
  "resumed96-fresh-chain": {
    "kind": "resume",
    "expected_checks": 62,
    "cap_seconds": 1800,
    "aggregate_required": false
  },
  "next96-fresh-chain": {
    "kind": "next",
    "expected_checks": 78,
    "cap_seconds": 1800,
    "aggregate_required": false
  },
  "lifecycle": {
    "kind": "lifecycle",
    "expected_checks": 159,
    "cap_seconds": 1800,
    "aggregate_required": true
  }
}
var _slice_id: String = ""
var _slice_completed: bool = false

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("SHARED_SLICE_CHECK ", checks, " ", ok, " ", label)
	print("SHARED_SLICE_PROGRESS case=", _slice_id, " check=", checks,
		" ticks_msec=", Time.get_ticks_msec(), " static_memory=", OS.get_static_memory_usage())
	if not ok: failures += 1
	return ok

func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(2)
		return
	var root: String = ""
	var input: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-slice-root="): root = arg.trim_prefix("--shared-slice-root=")
		if arg.begins_with("--funding-input="): input = arg.trim_prefix("--funding-input=")
		if arg.begins_with("--shared-slice="): _slice_id = arg.trim_prefix("--shared-slice=")
	if not SLICE_CASES.has(_slice_id) or not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) \
		or not input.is_absolute_path() or not FileAccess.file_exists(input):
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var original: String = FileAccess.get_sha256(input)
	var specification: Dictionary = SLICE_CASES[_slice_id]
	print("SHARED_SLICE_BEGIN case=", _slice_id, " input_sha256=", original,
		" expected=", specification.expected_checks, " source_acceptance=false")
	if specification.kind == "metadata":
		_pending_binding_units()
		_slice_completed = true
	else:
		if specification.kind == "lifecycle": _pending_binding_units()
		_run_fresh(input, specification)
	check(FileAccess.get_sha256(input) == original, "retained source bytes never changed")
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	if checks != int(specification.expected_checks) or not _slice_completed:
		print("SHARED_SLICE_INCOMPLETE expected=", specification.expected_checks,
			" actual=", checks, " reached_terminal=", _slice_completed)
		failures += 1
	await TestAudioDrain.finish(get_tree())
	print("SHARED_SLICE_RESULT case=%s checks=%d expected=%d failures=%d completed=%s authored_prerequisites=true physical_games=0 runtime_acceptance=false" % [
		_slice_id, checks, specification.expected_checks, failures, str(_slice_completed)])
	get_tree().quit(0 if failures == 0 else 1)

func _run_fresh(input: String, specification: Dictionary) -> void:
	var source: SeasonState = _source(input)
	if not check(source != null, "retained paid input plus separately authored unlock history validates"): return
	if not check(SeasonSave.save(source), "new authored94 source durably saved"): return
	# Drop the setup reference before the main scene and its cold restoration.
	source = null
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	add_child(app)
	match specification.kind:
		"contract": _detached_case(app, specification)
		"enrollment": _enrollment_case(app)
		"worker96": _worker_case(app, 96)
		"worker95": _worker_case(app, 95)
		"resume": _resume_case(app)
		"next": _next_case(app)
		"lifecycle": _lifecycle_case(app)
	app.free()

func _prepare_review(app: SeasonApp) -> bool:
	if not check(app.season != null and app.season._league_home_context.get("format") == 94, "actual main restores authored94"): return false
	if not check(app.dynasty_enrollment.prepare(959602), "actual94 enrollment prepares new96 without importing results: " + app.notice): return false
	return check(app.dynasty_enrollment.time_profile() == "night" and app.dynasty_enrollment._payload.snapshot.version == 96,
		"explicit review retains existing Night preference")

func _fresh_owner(app: SeasonApp) -> Dictionary:
	if not _prepare_review(app): return {}
	path = app.dynasty_enrollment.path
	var made: Dictionary = Store.create(app.dynasty_enrollment._payload.duplicate(true), path)
	if not check(made.status == "committed", "slice setup creates fresh independent96 owner"): return {}
	if not check(SeasonSave.bind_dynasty_owner(path) and app.dynasty_owner._promote(Store.restore(path)),
		"slice setup cold restores fresh independent96 owner"): return {}
	return app.dynasty_owner.found().owner

func _detached_case(app: SeasonApp, specification: Dictionary) -> void:
	var value: Dictionary = {}
	var label: String = ""
	if specification.version == 96:
		if not _prepare_review(app): return
		var prepared: Dictionary = TimeTransactions.prepare_create(app.dynasty_enrollment._base_payload.duplicate(true), specification.profile)
		value = prepared.get("snapshot", {})
		label = "detached96 prepares " + str(specification.profile)
	else:
		var current: Dictionary = _fresh_owner(app)
		if current.is_empty(): return
		var shaped: bool = specification.league != "dugout" or specification.tier != 0
		var route: Array = [specification.league, int(specification.tier)]
		var identity: String = "shape:" + str(route) if shaped else "mode:" + str(specification.profile)
		value = _alternate(current, identity, specification.profile, specification.league, int(specification.tier))
		label = "exact Doubleheader/tiered95 prepares " + str(route) if shaped else "detached95 prepares " + str(specification.profile)
	if not check(not value.is_empty(), label): return
	_contracts(value, specification.profile)
	_slice_completed = true

func _worker_case(app: SeasonApp, version: int) -> void:
	var current: Dictionary = _fresh_owner(app)
	if current.is_empty(): return
	if version == 95:
		var alternate: Dictionary = _alternate(current, "time95:1", "night")
		if not check(not alternate.is_empty(), "slice setup prepares fresh95"): return
		var request: Dictionary = _request(current, "switch", {"target": "other", "session_id": alternate.session.session_id, "snapshot": alternate})
		if not check(Store.transact(request, path).status == "committed" and app.dynasty_owner._promote(Store.restore(path)),
			"slice setup commits and cold restores fresh95"): return
		for index in range(4): app.choose_player(app.season.offers()[0])
		if not check(app.season.picks.size() == 4, "slice setup reaches four actual95 draft picks"): return
	if not _live(app.season, version): return
	_slice_completed = true

func _enrollment_case(app: SeasonApp) -> void:
	if not check(app.season != null and app.season._league_home_context.get("format") == 94, "actual main restores authored94"):
		return
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array = app.season.picks.duplicate()
	if not check(app.dynasty_enrollment.prepare(959602), "actual94 enrollment prepares new96 without importing results: " + app.notice): return
	var setup: RefCounted = app.dynasty_enrollment
	var old_ticket: int = setup.token()
	var base: Dictionary = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "night" and setup._payload.snapshot.version == 96, "explicit review retains existing Night preference")
	check(setup.starting_profile(old_ticket, ""), "explicit daylight selection keeps original92 route")
	check(ClubCareer.same(setup._payload, base), "daylight review preserves full original92 payload")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "actual enrollment review visibly shows explicit Day")
	check(setup.cancel(setup.token()) and setup.prepare(959602), "cancel and rebuild unattempted quote")
	base = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "" and setup._payload.snapshot.version == 92
		and ClubCareer.same(setup._payload, base), "rebuilt Day quote submits original92, not source Night")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "rebuilt enrollment remains visibly Day")
	check(setup.starting_profile(setup.token(), "fixed_night"), "review supports explicit fixed Night")
	check(not setup.commit(old_ticket), "stale enrollment ticket cannot publish")
	check(setup.starting_profile(setup.token(), "night"), "review restores explicit clocked Night")
	var payload: Dictionary = setup._payload.duplicate(true)
	path = setup.path
	if not TimeHome.ENTRY_ENABLED:
		check(not setup.commit(setup.token()) and not setup.attempted() and Store.inspect(path).status == "empty",
			"disabled public96 commit makes no attempt or owner")
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = Store.create(payload, path)
	Store._test_stop_after = ""
	if not check(stopped.status == "not_committed" and Store.inspect(path).status == "pending", "candidate96 creation retains interrupted immutable intent"): return
	var changed: Dictionary = TimeTransactions.prepare_create(base, "fixed_night")
	check(Store.create(changed, path).status == "blocked", "different selected time cannot replace interrupted96")
	var created: Dictionary = Store.create(payload, path)
	if not check(created.status == "committed", "same96 creation retries atomically: " + str(created.get("reason", ""))): return
	check(ClubCareer.same(Store.create(payload, path).owner, created.owner), "same96 create does not duplicate wallet/session")
	if not check(SeasonSave.bind_dynasty_owner(path) and app.dynasty_owner._promote(Store.restore(path)), "actual owner recovery selects96 despite disabled fresh gate"): return
	check(app.season.picks == roster and app.season.career == null and not app.season.league_career, "carried roster with one shared wallet")
	check(FileAccess.get_file_as_string(SeasonSave.path) == original, "archived94 source remains byte-identical")
	_slice_completed = true

func _resume_case(app: SeasonApp) -> void:
	if not check(app.season != null and app.season._league_home_context.get("format") == 94, "actual main restores authored94"):
		return
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array = app.season.picks.duplicate()
	if not check(app.dynasty_enrollment.prepare(959602), "actual94 enrollment prepares new96 without importing results: " + app.notice): return
	var setup: RefCounted = app.dynasty_enrollment
	var old_ticket: int = setup.token()
	var base: Dictionary = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "night" and setup._payload.snapshot.version == 96, "explicit review retains existing Night preference")
	check(setup.starting_profile(old_ticket, ""), "explicit daylight selection keeps original92 route")
	check(ClubCareer.same(setup._payload, base), "daylight review preserves full original92 payload")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "actual enrollment review visibly shows explicit Day")
	check(setup.cancel(setup.token()) and setup.prepare(959602), "cancel and rebuild unattempted quote")
	base = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "" and setup._payload.snapshot.version == 92
		and ClubCareer.same(setup._payload, base), "rebuilt Day quote submits original92, not source Night")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "rebuilt enrollment remains visibly Day")
	check(setup.starting_profile(setup.token(), "fixed_night"), "review supports explicit fixed Night")
	check(not setup.commit(old_ticket), "stale enrollment ticket cannot publish")
	check(setup.starting_profile(setup.token(), "night"), "review restores explicit clocked Night")
	var payload: Dictionary = setup._payload.duplicate(true)
	path = setup.path
	if not TimeHome.ENTRY_ENABLED:
		check(not setup.commit(setup.token()) and not setup.attempted() and Store.inspect(path).status == "empty",
			"disabled public96 commit makes no attempt or owner")
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = Store.create(payload, path)
	Store._test_stop_after = ""
	if not check(stopped.status == "not_committed" and Store.inspect(path).status == "pending", "candidate96 creation retains interrupted immutable intent"): return
	var changed: Dictionary = TimeTransactions.prepare_create(base, "fixed_night")
	check(Store.create(changed, path).status == "blocked", "different selected time cannot replace interrupted96")
	var created: Dictionary = Store.create(payload, path)
	if not check(created.status == "committed", "same96 creation retries atomically: " + str(created.get("reason", ""))): return
	check(ClubCareer.same(Store.create(payload, path).owner, created.owner), "same96 create does not duplicate wallet/session")
	if not check(SeasonSave.bind_dynasty_owner(path) and app.dynasty_owner._promote(Store.restore(path)), "actual owner recovery selects96 despite disabled fresh gate"): return
	check(app.season.picks == roster and app.season.career == null and not app.season.league_career, "carried roster with one shared wallet")
	check(FileAccess.get_file_as_string(SeasonSave.path) == original, "archived94 source remains byte-identical")
	var frozen_dynasty: Dictionary = SeasonSave.snapshot(app.season)
	var current: Dictionary = app.dynasty_owner.found().owner
	if not TimeHome.ENTRY_ENABLED:
		check(not app.dynasty_owner.start_other("dugout", current.revision, 959603, 0, "night"), "disabled public95 cannot start")
	var alternate: Dictionary = _alternate(current, "time95:1", "night")
	if not check(not alternate.is_empty(), "supported95 ready for owner admission"): return
	check(alternate.session.seed == frozen_dynasty.session.seed and alternate.time_run == frozen_dynasty.time_run + 1
		and not ClubCareer.same(alternate.owned_surface_night, frozen_dynasty.owned_surface_night), "same seed uses unique next owner admission index")
	var wrong_run: Dictionary = TimeHome.from_base(TimeHome.original(alternate), alternate.time_run + 1, "night")
	check(not wrong_run.is_empty() and Authority.open_session(current.career, wrong_run).is_empty(),
		"shape-valid policy with wrong owner admission index cannot be admitted")
	var request: Dictionary = _request(current, "switch", {"target": "other", "session_id": alternate.session.session_id, "snapshot": alternate})
	Store._test_stop_after = "intent.rename"
	var interrupted: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	if not check(interrupted.status == "not_committed" and Store.inspect(path).status == "pending", "95 switch failed write retains exact intent"): return
	var wrong: Dictionary = request.duplicate(true)
	wrong.snapshot.starting_profile = "fixed_night"
	check(Store.transact(wrong, path).status == "blocked", "95 intent cannot change policy")
	if not check(Store.transact(request, path).status == "committed" and app.dynasty_owner._promote(Store.restore(path)), "same95 switch retry and cold replay"): return
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var owner_before: Dictionary = app.dynasty_owner.found().owner
	var layout: Dictionary = app.season.home_property.layout.duplicate(true)
	var light_key: String = "lights" if layout.version == 12 else "floodlights"
	if not check(layout.get(light_key) is Array and layout[light_key].size() >= 2, "two paid light copies available for future-only exchange"): return
	var copy: String = layout[light_key][0].copy
	layout[light_key][0].copy = layout[light_key][1].copy
	layout[light_key][1].copy = copy
	if not _asset(app, {"op": "stadium_draft", "layout": layout}): return
	if not _asset(app, {"op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry(app.season.home_property.tier, layout)}): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen), "shared edits never recapture admitted95 policy/home/grant")
	current = app.dynasty_owner.found().owner
	check(ClubCareer.same(current.dynasty, owner_before.dynasty), "paused96 full slot remains unchanged")
	check(not ClubCareer.same(Authority._history(current.career)._assets, Authority._history(owner_before.career)._assets), "future authority journal really changed")
	var future: Dictionary = _alternate(current, "time95:future", "night")
	check(not future.is_empty() and ClubCareer.same(future.base_header.home_property.layout, layout)
		and not ClubCareer.same(future.owned_surface_night, frozen.owned_surface_night), "only future95 admits changed paid lighting")
	app.choose_player(app.season.offers()[0])
	check(not TimeRuntime.future_editable(app.season), "first pick closes future-edit exception")
	for index in range(3): app.choose_player(app.season.offers()[0])
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "actual controller resumes paused96"): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen_dynasty), "paused96 resumes exact old field and policy after shared edits")
	if not _live(app.season, 96): return
	_slice_completed = true

func _next_case(app: SeasonApp) -> void:
	if not check(app.season != null and app.season._league_home_context.get("format") == 94, "actual main restores authored94"):
		return
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array = app.season.picks.duplicate()
	if not check(app.dynasty_enrollment.prepare(959602), "actual94 enrollment prepares new96 without importing results: " + app.notice): return
	var setup: RefCounted = app.dynasty_enrollment
	var old_ticket: int = setup.token()
	var base: Dictionary = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "night" and setup._payload.snapshot.version == 96, "explicit review retains existing Night preference")
	check(setup.starting_profile(old_ticket, ""), "explicit daylight selection keeps original92 route")
	check(ClubCareer.same(setup._payload, base), "daylight review preserves full original92 payload")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "actual enrollment review visibly shows explicit Day")
	check(setup.cancel(setup.token()) and setup.prepare(959602), "cancel and rebuild unattempted quote")
	base = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "" and setup._payload.snapshot.version == 92
		and ClubCareer.same(setup._payload, base), "rebuilt Day quote submits original92, not source Night")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "rebuilt enrollment remains visibly Day")
	check(setup.starting_profile(setup.token(), "fixed_night"), "review supports explicit fixed Night")
	check(not setup.commit(old_ticket), "stale enrollment ticket cannot publish")
	check(setup.starting_profile(setup.token(), "night"), "review restores explicit clocked Night")
	var payload: Dictionary = setup._payload.duplicate(true)
	path = setup.path
	if not TimeHome.ENTRY_ENABLED:
		check(not setup.commit(setup.token()) and not setup.attempted() and Store.inspect(path).status == "empty",
			"disabled public96 commit makes no attempt or owner")
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = Store.create(payload, path)
	Store._test_stop_after = ""
	if not check(stopped.status == "not_committed" and Store.inspect(path).status == "pending", "candidate96 creation retains interrupted immutable intent"): return
	var changed: Dictionary = TimeTransactions.prepare_create(base, "fixed_night")
	check(Store.create(changed, path).status == "blocked", "different selected time cannot replace interrupted96")
	var created: Dictionary = Store.create(payload, path)
	if not check(created.status == "committed", "same96 creation retries atomically: " + str(created.get("reason", ""))): return
	check(ClubCareer.same(Store.create(payload, path).owner, created.owner), "same96 create does not duplicate wallet/session")
	if not check(SeasonSave.bind_dynasty_owner(path) and app.dynasty_owner._promote(Store.restore(path)), "actual owner recovery selects96 despite disabled fresh gate"): return
	check(app.season.picks == roster and app.season.career == null and not app.season.league_career, "carried roster with one shared wallet")
	check(FileAccess.get_file_as_string(SeasonSave.path) == original, "archived94 source remains byte-identical")
	var frozen_dynasty: Dictionary = SeasonSave.snapshot(app.season)
	var current: Dictionary = app.dynasty_owner.found().owner
	if not TimeHome.ENTRY_ENABLED:
		check(not app.dynasty_owner.start_other("dugout", current.revision, 959603, 0, "night"), "disabled public95 cannot start")
	var alternate: Dictionary = _alternate(current, "time95:1", "night")
	if not check(not alternate.is_empty(), "supported95 ready for owner admission"): return
	check(alternate.session.seed == frozen_dynasty.session.seed and alternate.time_run == frozen_dynasty.time_run + 1
		and not ClubCareer.same(alternate.owned_surface_night, frozen_dynasty.owned_surface_night), "same seed uses unique next owner admission index")
	var wrong_run: Dictionary = TimeHome.from_base(TimeHome.original(alternate), alternate.time_run + 1, "night")
	check(not wrong_run.is_empty() and Authority.open_session(current.career, wrong_run).is_empty(),
		"shape-valid policy with wrong owner admission index cannot be admitted")
	var request: Dictionary = _request(current, "switch", {"target": "other", "session_id": alternate.session.session_id, "snapshot": alternate})
	Store._test_stop_after = "intent.rename"
	var interrupted: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	if not check(interrupted.status == "not_committed" and Store.inspect(path).status == "pending", "95 switch failed write retains exact intent"): return
	var wrong: Dictionary = request.duplicate(true)
	wrong.snapshot.starting_profile = "fixed_night"
	check(Store.transact(wrong, path).status == "blocked", "95 intent cannot change policy")
	if not check(Store.transact(request, path).status == "committed" and app.dynasty_owner._promote(Store.restore(path)), "same95 switch retry and cold replay"): return
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var owner_before: Dictionary = app.dynasty_owner.found().owner
	var layout: Dictionary = app.season.home_property.layout.duplicate(true)
	var light_key: String = "lights" if layout.version == 12 else "floodlights"
	if not check(layout.get(light_key) is Array and layout[light_key].size() >= 2, "two paid light copies available for future-only exchange"): return
	var copy: String = layout[light_key][0].copy
	layout[light_key][0].copy = layout[light_key][1].copy
	layout[light_key][1].copy = copy
	if not _asset(app, {"op": "stadium_draft", "layout": layout}): return
	if not _asset(app, {"op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry(app.season.home_property.tier, layout)}): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen), "shared edits never recapture admitted95 policy/home/grant")
	current = app.dynasty_owner.found().owner
	check(ClubCareer.same(current.dynasty, owner_before.dynasty), "paused96 full slot remains unchanged")
	check(not ClubCareer.same(Authority._history(current.career)._assets, Authority._history(owner_before.career)._assets), "future authority journal really changed")
	var future: Dictionary = _alternate(current, "time95:future", "night")
	check(not future.is_empty() and ClubCareer.same(future.base_header.home_property.layout, layout)
		and not ClubCareer.same(future.owned_surface_night, frozen.owned_surface_night), "only future95 admits changed paid lighting")
	app.choose_player(app.season.offers()[0])
	check(not TimeRuntime.future_editable(app.season), "first pick closes future-edit exception")
	for index in range(3): app.choose_player(app.season.offers()[0])
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "actual controller resumes paused96"): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen_dynasty), "paused96 resumes exact old field and policy after shared edits")
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.close_current("abandon", current.revision), "explicit abandonment closes first Dynasty without invented progress"): return
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.prepare_next(0, 959602, current.revision), "actual next review retains preference"): return
	check(app.dynasty_owner._next_choice.starting_profile == "night", "next review carries preference, never old bound policy")
	check(app.dynasty_owner.next_starting_profile(app.dynasty_owner._next_choice.ticket, ""), "explicit next Day choice is distinct from unset")
	app.dynasty_owner.cancel_next(app.dynasty_owner._next_choice.ticket)
	check(app.dynasty_owner.prepare_next(0, 959602, current.revision)
		and app.dynasty_owner._next_choice.starting_profile == "", "next Day survives Cancel/back quote rebuild")
	load("res://src/presentation/season/dynasty_career_tier_ui.gd").review(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "next rebuilt review visibly stays Day")
	check(app.dynasty_owner.next_starting_profile(app.dynasty_owner._next_choice.ticket, "night"), "explicitly choose Night again for next96 test")
	if not TimeHome.ENTRY_ENABLED:
		check(not app.dynasty_owner.commit_next(app.dynasty_owner._next_choice.ticket), "disabled fresh next96 does not write")
	var next_request: Dictionary = _request(current, "begin_next", {"seed": 959602, "tier": 0, "starting_profile": "night"})
	Store._test_stop_after = "intent.rename"
	interrupted = Store.transact(next_request, path)
	Store._test_stop_after = ""
	if not check(interrupted.status == "not_committed" and Store.inspect(path).status == "pending", "next96 retains failed-write intent"): return
	var frozen_ticket: Dictionary = app.dynasty_owner._next_choice.duplicate(true)
	check(not app.dynasty_owner.next_starting_profile(app.dynasty_owner._next_choice.ticket, "fixed_night"), "uncertain next attempt cannot change review policy")
	app.dynasty_owner.cancel_next(app.dynasty_owner._next_choice.ticket)
	check(ClubCareer.same(frozen_ticket, app.dynasty_owner._next_choice), "uncertain attempt freezes exact choice and ticket even across Cancel")
	wrong = next_request.duplicate(true)
	wrong.starting_profile = "fixed_night"
	check(Store.transact(wrong, path).status == "blocked", "next-generation pending intent rejects other time")
	if not check(Store.transact(next_request, path).status == "committed" and app.dynasty_owner._promote(Store.restore(path)), "exact next96 retry cold promotes"): return
	check(app.season.picks == roster and app.season._dynasty_start.season_ordinal == 2, "next96 carried roster and generation exact")
	check(ClubCareer.same(app.season.home_property.layout, layout) and not ClubCareer.same(app.season.owned_surface_night, frozen_dynasty.owned_surface_night), "next96 derives fresh policy from current paid future home")
	check(app.season._league_home_context.header.time_run == 3
		and app.season.season_seed == frozen_dynasty.session.seed, "repeated seed never reuses Dynasty ordinal as Night run")
	if not _live(app.season, 96): return
	_slice_completed = true

func _lifecycle_case(app: SeasonApp) -> void:
	if not check(app.season != null and app.season._league_home_context.get("format") == 94, "actual main restores authored94"):
		return
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array = app.season.picks.duplicate()
	if not check(app.dynasty_enrollment.prepare(959602), "actual94 enrollment prepares new96 without importing results: " + app.notice): return
	var setup: RefCounted = app.dynasty_enrollment
	var old_ticket: int = setup.token()
	var base: Dictionary = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "night" and setup._payload.snapshot.version == 96, "explicit review retains existing Night preference")
	check(setup.starting_profile(old_ticket, ""), "explicit daylight selection keeps original92 route")
	check(ClubCareer.same(setup._payload, base), "daylight review preserves full original92 payload")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "actual enrollment review visibly shows explicit Day")
	check(setup.cancel(setup.token()) and setup.prepare(959602), "cancel and rebuild unattempted quote")
	base = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "" and setup._payload.snapshot.version == 92
		and ClubCareer.same(setup._payload, base), "rebuilt Day quote submits original92, not source Night")
	load("res://src/presentation/season/dynasty_career_ui.gd").enrollment(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "rebuilt enrollment remains visibly Day")
	check(setup.starting_profile(setup.token(), "fixed_night"), "review supports explicit fixed Night")
	check(not setup.commit(old_ticket), "stale enrollment ticket cannot publish")
	check(setup.starting_profile(setup.token(), "night"), "review restores explicit clocked Night")
	var payload: Dictionary = setup._payload.duplicate(true)
	path = setup.path
	if not TimeHome.ENTRY_ENABLED:
		check(not setup.commit(setup.token()) and not setup.attempted() and Store.inspect(path).status == "empty",
			"disabled public96 commit makes no attempt or owner")
	Store._test_stop_after = "intent.rename"
	var stopped: Dictionary = Store.create(payload, path)
	Store._test_stop_after = ""
	if not check(stopped.status == "not_committed" and Store.inspect(path).status == "pending", "candidate96 creation retains interrupted immutable intent"): return
	var changed: Dictionary = TimeTransactions.prepare_create(base, "fixed_night")
	check(Store.create(changed, path).status == "blocked", "different selected time cannot replace interrupted96")
	var created: Dictionary = Store.create(payload, path)
	if not check(created.status == "committed", "same96 creation retries atomically: " + str(created.get("reason", ""))): return
	check(ClubCareer.same(Store.create(payload, path).owner, created.owner), "same96 create does not duplicate wallet/session")
	if not check(SeasonSave.bind_dynasty_owner(path) and app.dynasty_owner._promote(Store.restore(path)), "actual owner recovery selects96 despite disabled fresh gate"): return
	check(app.season.picks == roster and app.season.career == null and not app.season.league_career, "carried roster with one shared wallet")
	check(FileAccess.get_file_as_string(SeasonSave.path) == original, "archived94 source remains byte-identical")
	if not _live(app.season, 96): return
	var frozen_dynasty: Dictionary = SeasonSave.snapshot(app.season)
	var current: Dictionary = app.dynasty_owner.found().owner
	if not TimeHome.ENTRY_ENABLED:
		check(not app.dynasty_owner.start_other("dugout", current.revision, 959603, 0, "night"), "disabled public95 cannot start")
	var alternate: Dictionary = _alternate(current, "time95:1", "night")
	if not check(not alternate.is_empty(), "supported95 ready for owner admission"): return
	check(alternate.session.seed == frozen_dynasty.session.seed and alternate.time_run == frozen_dynasty.time_run + 1
		and not ClubCareer.same(alternate.owned_surface_night, frozen_dynasty.owned_surface_night), "same seed uses unique next owner admission index")
	var wrong_run: Dictionary = TimeHome.from_base(TimeHome.original(alternate), alternate.time_run + 1, "night")
	check(not wrong_run.is_empty() and Authority.open_session(current.career, wrong_run).is_empty(),
		"shape-valid policy with wrong owner admission index cannot be admitted")
	var request: Dictionary = _request(current, "switch", {"target": "other", "session_id": alternate.session.session_id, "snapshot": alternate})
	Store._test_stop_after = "intent.rename"
	var interrupted: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	if not check(interrupted.status == "not_committed" and Store.inspect(path).status == "pending", "95 switch failed write retains exact intent"): return
	var wrong: Dictionary = request.duplicate(true)
	wrong.snapshot.starting_profile = "fixed_night"
	check(Store.transact(wrong, path).status == "blocked", "95 intent cannot change policy")
	if not check(Store.transact(request, path).status == "committed" and app.dynasty_owner._promote(Store.restore(path)), "same95 switch retry and cold replay"): return
	if not _live(app.season, 95): return
	var frozen: Dictionary = SeasonSave.snapshot(app.season)
	var owner_before: Dictionary = app.dynasty_owner.found().owner
	var layout: Dictionary = app.season.home_property.layout.duplicate(true)
	var light_key: String = "lights" if layout.version == 12 else "floodlights"
	if not check(layout.get(light_key) is Array and layout[light_key].size() >= 2, "two paid light copies available for future-only exchange"): return
	var copy: String = layout[light_key][0].copy
	layout[light_key][0].copy = layout[light_key][1].copy
	layout[light_key][1].copy = copy
	if not _asset(app, {"op": "stadium_draft", "layout": layout}): return
	if not _asset(app, {"op": "stadium_apply", "layout": layout,
		"geometry": StadiumOwnedLayout.geometry(app.season.home_property.tier, layout)}): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen), "shared edits never recapture admitted95 policy/home/grant")
	current = app.dynasty_owner.found().owner
	check(ClubCareer.same(current.dynasty, owner_before.dynasty), "paused96 full slot remains unchanged")
	check(not ClubCareer.same(Authority._history(current.career)._assets, Authority._history(owner_before.career)._assets), "future authority journal really changed")
	if not _live(app.season, 95): return
	var future: Dictionary = _alternate(current, "time95:future", "night")
	check(not future.is_empty() and ClubCareer.same(future.base_header.home_property.layout, layout)
		and not ClubCareer.same(future.owned_surface_night, frozen.owned_surface_night), "only future95 admits changed paid lighting")
	app.choose_player(app.season.offers()[0])
	check(not TimeRuntime.future_editable(app.season), "first pick closes future-edit exception")
	for index in range(3): app.choose_player(app.season.offers()[0])
	if not _live(app.season, 95): return
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "actual controller resumes paused96"): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen_dynasty), "paused96 resumes exact old field and policy after shared edits")
	if not _live(app.season, 96): return
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.close_current("abandon", current.revision), "explicit abandonment closes first Dynasty without invented progress"): return
	current = app.dynasty_owner.found().owner
	if not check(app.dynasty_owner.prepare_next(0, 959602, current.revision), "actual next review retains preference"): return
	check(app.dynasty_owner._next_choice.starting_profile == "night", "next review carries preference, never old bound policy")
	check(app.dynasty_owner.next_starting_profile(app.dynasty_owner._next_choice.ticket, ""), "explicit next Day choice is distinct from unset")
	app.dynasty_owner.cancel_next(app.dynasty_owner._next_choice.ticket)
	check(app.dynasty_owner.prepare_next(0, 959602, current.revision)
		and app.dynasty_owner._next_choice.starting_profile == "", "next Day survives Cancel/back quote rebuild")
	load("res://src/presentation/season/dynasty_career_tier_ui.gd").review(app)
	check(_text_contains(app.menu, "Day (existing daylight field)"), "next rebuilt review visibly stays Day")
	check(app.dynasty_owner.next_starting_profile(app.dynasty_owner._next_choice.ticket, "night"), "explicitly choose Night again for next96 test")
	if not TimeHome.ENTRY_ENABLED:
		check(not app.dynasty_owner.commit_next(app.dynasty_owner._next_choice.ticket), "disabled fresh next96 does not write")
	var next_request: Dictionary = _request(current, "begin_next", {"seed": 959602, "tier": 0, "starting_profile": "night"})
	Store._test_stop_after = "intent.rename"
	interrupted = Store.transact(next_request, path)
	Store._test_stop_after = ""
	if not check(interrupted.status == "not_committed" and Store.inspect(path).status == "pending", "next96 retains failed-write intent"): return
	var frozen_ticket: Dictionary = app.dynasty_owner._next_choice.duplicate(true)
	check(not app.dynasty_owner.next_starting_profile(app.dynasty_owner._next_choice.ticket, "fixed_night"), "uncertain next attempt cannot change review policy")
	app.dynasty_owner.cancel_next(app.dynasty_owner._next_choice.ticket)
	check(ClubCareer.same(frozen_ticket, app.dynasty_owner._next_choice), "uncertain attempt freezes exact choice and ticket even across Cancel")
	wrong = next_request.duplicate(true)
	wrong.starting_profile = "fixed_night"
	check(Store.transact(wrong, path).status == "blocked", "next-generation pending intent rejects other time")
	if not check(Store.transact(next_request, path).status == "committed" and app.dynasty_owner._promote(Store.restore(path)), "exact next96 retry cold promotes"): return
	check(app.season.picks == roster and app.season._dynasty_start.season_ordinal == 2, "next96 carried roster and generation exact")
	check(ClubCareer.same(app.season.home_property.layout, layout) and not ClubCareer.same(app.season.owned_surface_night, frozen_dynasty.owned_surface_night), "next96 derives fresh policy from current paid future home")
	check(app.season._league_home_context.header.time_run == 3
		and app.season.season_seed == frozen_dynasty.session.seed, "repeated seed never reuses Dynasty ordinal as Night run")
	if not _live(app.season, 96): return
	_slice_completed = true

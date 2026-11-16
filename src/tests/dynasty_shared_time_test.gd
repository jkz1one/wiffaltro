extends Node
## Source-qualified candidate contracts. Authored prerequisites are never game proof.
## No physical simulation, result fabrication, grant replacement, or public activation.
const TimeHome = preload("res://src/gameplay/season/dynasty_shared_time.gd")
const TimeRuntime = preload("res://src/gameplay/season/dynasty_shared_time_runtime.gd")
const TimeTransactions = preload("res://src/gameplay/season/dynasty_shared_time_transactions.gd")
const Save = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner_v2.gd")
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Normal = preload("res://src/gameplay/season/normal_league_time_candidate.gd")
var checks: int = 0
var failures: int = 0
var path: String = ""

func check(ok: bool, label: String) -> bool:
	checks += 1
	print("SHARED_TIME_CHECK ", checks, " ", ok, " ", label)
	if not ok: failures += 1
	return ok

func _ready() -> void:
	if OS.get_environment("WIFFALTRO_BOUNDED_LOCKED") != "1" or not StadiumNpcPublicRuntime.source_qualified():
		get_tree().quit(2)
		return
	var root: String = ""
	var input: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shared-time-root="): root = arg.trim_prefix("--shared-time-root=")
		if arg.begins_with("--funding-input="): input = arg.trim_prefix("--funding-input=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) or not input.is_absolute_path() \
		or not FileAccess.file_exists(input):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	_pending_binding_units()
	var original: String = FileAccess.get_sha256(input)
	var source: SeasonState = _source(input)
	if check(source != null, "retained paid input plus separately authored unlock history validates"):
		if check(SeasonSave.save(source), "new authored94 source durably saved"):
			var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
			add_child(app)
			_run(app)
			app.free()
	check(FileAccess.get_sha256(input) == original, "retained source bytes never changed")
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("SHARED_TIME9596_RESULT checks=%d failures=%d authored_prerequisites=true physical_games=0" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

func _source(input: String) -> SeasonState:
	var source: SeasonState = SeasonSave._decode(JSON.parse_string(FileAccess.get_file_as_string(input)))
	if source == null or source.career == null: return null
	var club: ClubCareer = source.career.fork()
	if not club.close(source): return null
	var journal: Dictionary = club._assets.duplicate(true)
	if "dynasty" not in club.available_leagues():
		# Four compact, explicitly synthetic Dugout title prerequisites. Preserve
		# every retained funding row and every already-paid journal event unchanged.
		var titles: ClubCareer = Fixture.prefix([{"league": "dugout", "tier": 0},
			{"league": "dugout", "tier": 1}, {"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
		if titles == null: return null
		for row: Dictionary in titles.runs:
			var copy: Dictionary = row.duplicate(true)
			copy.id = club.runs.size() + 1
			club.runs.append(copy)
	club = ClubCareer.from_data(club.to_data())
	if club == null or ClubPlayers.assets(club) == null or not ClubCareer.same(journal, club._assets): return null
	var season: SeasonState = SeasonState.create_closed_league(959601, LeagueRules.capture("dugout"), true)
	if not ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) or not club.start_league(season) \
		or not load("res://src/gameplay/season/normal_league_home.gd").prepare(season): return null
	var value: Dictionary = Normal.prepare(season, "night")
	var night: SeasonState = SeasonSave._decode(value) if not value.is_empty() else null
	if night == null: return null
	for index in range(4):
		if not night.choose_player(night.offers()[0]): return null
	return night

func _run(app: SeasonApp) -> void:
	if not check(app.season != null and app.season._league_home_context.get("format") == 94, "actual main restores authored94"):
		return
	var original: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array = app.season.picks.duplicate()
	if not check(app.dynasty_enrollment.prepare(959602), "actual94 enrollment prepares new96 without importing results: " + app.notice): return
	var setup: RefCounted = app.dynasty_enrollment
	var old_ticket: int = setup.token()
	var base: Dictionary = setup._base_payload.duplicate(true)
	check(setup.time_profile() == "night" and setup._payload.snapshot.version == 96, "explicit review retains existing Night preference")
	for selected: String in TimeHome.PROFILES:
		var prepared: Dictionary = TimeTransactions.prepare_create(base, selected)
		if check(not prepared.is_empty(), "detached96 prepares " + selected):
			_contracts(prepared.snapshot, selected)
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
	for selected: String in TimeHome.PROFILES:
		var candidate: Dictionary = _alternate(current, "mode:" + selected, selected)
		if check(not candidate.is_empty(), "detached95 prepares " + selected): _contracts(candidate, selected)
	for route: Array in [["doubleheader", 0], ["dugout", 1]]:
		var candidate: Dictionary = _alternate(current, "shape:" + str(route), "night", route[0], route[1])
		if check(not candidate.is_empty(), "exact Doubleheader/tiered95 prepares " + str(route)): _contracts(candidate, "night")
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

func _alternate(owner: Dictionary, id: String, selected: String, league: String = "dugout", tier: int = 0) -> Dictionary:
	var session: Dictionary = Save.binding({"owner_id": owner.owner_id, "lineage_id": owner.lineage.id,
		"generation": owner.lineage.generation, "ordinal": owner.lineage.ordinal, "session_id": id,
		"seed": 959602, "tier": tier, "league": league, "access_sha256": ClosedContentAccess.digest(Authority.access(owner.career))})
	return TimeHome.prepare_alternate(owner.career, session, selected)

func _request(owner: Dictionary, operation: String, operands: Dictionary) -> Dictionary:
	var request: Dictionary = {"op": operation, "request_id": "time-test:%d:%s" % [owner.revision, operation], "expected_revision": owner.revision}
	request.merge(operands)
	return request

func _asset(app: SeasonApp, operands: Dictionary) -> bool:
	var owner: Dictionary = app.dynasty_owner.found().owner
	var paid: ClubAssetLedger = ClubPlayers.assets(Authority._history(owner.career))
	var command: Dictionary = operands.duplicate(true)
	command.merge({"id": "time-assets:%d" % paid.revision(), "rev": paid.revision()})
	var outcome: Dictionary = Store.transact(_request(owner, "stadium_assets", {"command": command}), path)
	return check(outcome.status == "committed" and app.dynasty_owner._promote(Store.restore(path)), "actual shared future-only " + str(command.op) + ": " + str(outcome.get("reason", "")))

func _contracts(value: Dictionary, selected: String) -> void:
	var expected: Dictionary = TimeHome.header(value)
	var checked: Dictionary = TimeHome.qualify(value, expected)
	if not check(not checked.is_empty(), "full policy replay qualifies " + str(value.version) + " " + selected): return
	check(ClubCareer.same(TimeHome.capture(checked.season), value), "exact detached capture")
	if selected == "night" and value.session.tier == 0 and value.session.league in ["dugout", "dynasty"]:
		# Real JSON transport, not a second in-memory qualification of the same value.
		var persisted: Dictionary = JSON.parse_string(JSON.stringify(value, "", true, true))
		check(typeof(persisted.version) == TYPE_FLOAT, "JSON carries the exact95/96 version as float")
		for malformed: Variant in [float(value.version) + 0.5, str(int(value.version)), true]:
			var bad_version: Dictionary = persisted.duplicate(true)
			bad_version.version = malformed
			check(TimeHome.qualify(bad_version, TimeHome.header(bad_version)).is_empty(),
				"fractional/String/bool95/96 version refuses before local conversion")
		var cold: Dictionary = TimeHome.qualify(persisted, TimeHome.header(persisted))
		if check(not cold.is_empty(), "actual JSON cold95/96 replay qualifies"):
			check(typeof(cold.season._league_home_context.format) == TYPE_INT
				and ClubCareer.same(cold.time_home, TimeHome.header(persisted))
				and ClubCareer.same(Save.snapshot_reference(TimeHome.capture(cold.season)), Save.snapshot_reference(persisted)),
				"only local route type changes; exact saved header and snapshot identity remain")
		var cold_base: Dictionary = TimeHome.original(persisted)
		if check(not cold_base.is_empty() and typeof(cold_base.version) == TYPE_FLOAT, "validated cold original retains JSON91/92 discriminator"):
			for malformed: Variant in [float(cold_base.version) + 0.5, str(int(cold_base.version)), true]:
				var bad_version: Dictionary = cold_base.duplicate(true)
				bad_version.version = malformed
				check(TimeHome.from_base(bad_version, int(value.time_run), selected).is_empty(),
					"fractional/String/bool91/92 base refuses without deriving a time policy")
			var rebound: Dictionary = TimeHome.from_base(cold_base, int(value.time_run), selected)
			check(not rebound.is_empty() and ClubCareer.same(Save.snapshot_reference(rebound), Save.snapshot_reference(persisted)),
				"JSON91/92 source derives exact same95/96 without rewriting stored operands")
	check(SeasonSave._decode(value.checkpoint) == null, "stripped modern time envelope cannot replay as historical")
	for field: String in ["family", "time_run", "base_header", "owned_surface_night", "source_reference"]:
		var bad: Dictionary = value.duplicate(true)
		bad.erase(field)
		check(TimeHome.qualify(bad, expected).is_empty(), "missing immutable " + field + " refuses")
	var bad: Dictionary = value.duplicate(true)
	bad.extra = true
	check(TimeHome.qualify(bad, expected).is_empty(), "unknown envelope field refuses")
	bad = value.duplicate(true)
	bad.session.session_id = "foreign"
	check(TimeHome.qualify(bad, TimeHome.header(bad)).is_empty(), "cross-session substitution refuses")
	for marker in [75, 76, 77, 82]:
		var raw: Dictionary = TimeHome._unbound(value)
		var closed: Dictionary = TimeHome._closed(raw)
		if marker == closed.version: continue
		closed.version = marker
		bad = value.duplicate(true)
		bad.checkpoint = TimeHome._bind(raw, value.session, value.version)
		check(TimeHome.qualify(bad, expected).is_empty(), "swapped closed marker " + str(marker) + " refuses")
	var fixture: Dictionary = checked.season.schedule.filter(func(row: Dictionary) -> bool: return row.home == 0)[0]
	var home: Dictionary = StadiumLayoutSnapshot.for_fixture(checked.season, fixture)
	check(home.get("version") == (26 if selected == "fixed_night" else 27)
		and home.get("binding", {}).get("run_id") == value.time_run, "exact26/27 full session run binding")

func _live(season: SeasonState, version: int) -> bool:
	if not check(season != null and season._league_home_context.get("format") == version, "selected live " + str(version)): return false
	var snapshot: Dictionary = SeasonSave.snapshot(season)
	var cold: SeasonState = SeasonSave.restore()
	if not check(not snapshot.is_empty() and cold != null and ClubCareer.same(SeasonSave.snapshot(cold), snapshot), "selected full cold replay exact"): return false
	if not check(TimeRuntime.paid_ledger(season) != null, "committed current owner grants frozen paid runtime"): return false
	var original_binding: Dictionary = season._dynasty_owner_binding
	season._dynasty_owner_binding = original_binding.duplicate(true)
	season._dynasty_owner_binding.revision += 1
	var stale_refused: bool = check(TimeRuntime.paid_ledger(season) == null, "wrong writer revision refuses runtime")
	season._dynasty_owner_binding = original_binding
	if not stale_refused: return false
	if season.picks.size() != 4: return failures == 0
	var build_before: Dictionary = season.build.to_data()
	for extra: Variant in ["unknown_result_key", 123]:
		var malformed: Dictionary = season.pending_fixture().duplicate(true)
		malformed.property = ""
		malformed[extra] = true
		check(not load("res://src/gameplay/season/league_home_result.gd").replay(season, season.build, malformed, {}, {}, []),
			"unknown String/non-String result key rejected before replay")
	check(ClubCareer.same(build_before, season.build.to_data()), "unknown-result rejection never changes build")
	var transport: Dictionary = PhysicalRoundProcess.request_for(season, "time9596", "time9596-key", 1)
	if not check(transport.get("version") == (6 if version == 96 else 5), "exact5/6 worker request captures selected owner"): return false
	if not check(PhysicalRoundProcess.decode_request(transport, "time9596") != null, "exact5/6 worker transport replays selected owner"): return false
	var wire: Dictionary = JSON.parse_string(JSON.stringify(transport, "", true, true))
	check(typeof(wire.version) == TYPE_FLOAT and typeof(wire.season.version) == TYPE_FLOAT,
		"real worker JSON carries both transport and session versions as floats")
	if not check(PhysicalRoundProcess.decode_request(wire, "time9596") != null, "exact cold5/6 worker transport replays selected owner"): return false
	for field: String in ["transport", "season"]:
		var exact: int = int(wire.version if field == "transport" else wire.season.version)
		for malformed: Variant in [float(exact) + 0.5, str(exact), true]:
			var wrong_type: Dictionary = wire.duplicate(true)
			if field == "transport": wrong_type.version = malformed
			else: wrong_type.season.version = malformed
			check(PhysicalRoundProcess.decode_request(wrong_type, "time9596") == null,
				"fractional/String/bool worker " + field + " discriminator refuses")
	var cross: Dictionary = wire.duplicate(true)
	cross.version = 5.0 if version == 96 else 6.0
	check(PhysicalRoundProcess.decode_request(cross, "time9596") == null, "cross95/96 wire family refuses")
	for old in [1, 2, 3, 4]:
		var bad: Dictionary = transport.duplicate(true)
		bad.version = old
		check(PhysicalRoundProcess.decode_request(bad, "time9596") == null, "historical transport " + str(old) + " rejects modern time")
	return failures == 0

func _pending_binding_units() -> void:
	# Compact metadata negatives only, not a fabricated owner or earned overflow.
	var pending: Dictionary = {"pending_next": {"id": "shape-only"}, "pending_time_profile": "night",
		"operands": {"op": "begin_next", "starting_profile": "night"}}
	check(Owner._pending_rules_valid(pending), "compact saved forgetting choice binds selected time")
	var bad: Dictionary = pending.duplicate(true)
	bad.erase("pending_time_profile")
	check(not Owner._pending_rules_valid(bad), "forgetting step cannot drop requested time")
	bad = pending.duplicate(true)
	bad.pending_time_profile = "fixed_night"
	check(not Owner._pending_rules_valid(bad), "forgetting step cannot substitute time")
	bad = pending.duplicate(true)
	bad.pending_next = {}
	check(not Owner._pending_rules_valid(bad), "time choice cannot outlive pending forgetting step")
	bad = pending.duplicate(true)
	bad.pending_next = null
	check(not Owner._pending_rules_valid(bad), "malformed pending time refuses")
	bad = pending.duplicate(true)
	bad.operands = []
	check(not Owner._pending_rules_valid(bad), "non-dictionary pending operands refuse without type assignment")
	check(not Owner._request_valid({"op": "choose_next", "request_id": "shape-only", "expected_revision": 1,
		"pending_id": "shape-only", "choices": {}, "starting_profile": "fixed_night"}),
		"forgetting continuation cannot resubmit a different time preference")

func _text_contains(node: Node, text: String) -> bool:
	if node is Label and text in node.text: return true
	for child: Node in node.get_children():
		if _text_contains(child, text): return true
	return false

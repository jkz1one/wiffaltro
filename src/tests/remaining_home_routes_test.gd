extends Node
## One retained paid operand per isolated run. Authored prerequisites, zero games.
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Carried = preload("res://src/gameplay/season/dynasty_carried_home_live.gd")
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const Runtime = preload("res://src/gameplay/season/dynasty_carried_home_runtime.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
var checks: int = 0
var failures: int = 0
var root: String = ""
var input_path: String = ""
var input_bytes: String = ""
var source_home: Dictionary = {}
var future_layout: Dictionary = {}

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("REMAINING_HOME_ROUTE ", ok, " ", label)
	return ok

func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--home-routes-root="): root = arg.trim_prefix("--home-routes-root=")
		if arg.begins_with("--home-routes-input="): input_path = arg.trim_prefix("--home-routes-input=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) \
		or not input_path.is_absolute_path() or not FileAccess.file_exists(input_path):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	input_bytes = FileAccess.get_file_as_string(input_path)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var season: SeasonState = _ordinary()
	if season != null:
		var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
		add_child(app)
		if _recapture(app): _owner_route(app)
		app.free()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	check(FileAccess.get_file_as_string(input_path) == input_bytes, "retained input is byte-identical")
	var file: FileAccess = FileAccess.open(root.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "physical_games": 0,
		"authored_prerequisites": true, "input": input_path, "input_sha256": input_bytes.sha256_text(),
		"entry": source_home.get("version"), "layout": source_home.get("layout", {}).get("version")}, "\t"))
	print("REMAINING_HOME_ROUTE_RESULT checks=", checks, " failures=", failures, " physical_games=0 authored_prerequisites=true")
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)

func _ordinary() -> SeasonState:
	var input: Variant = JSON.parse_string(input_bytes)
	if not check(input is Dictionary and input.get("authority") is Dictionary
		and input.get("snapshot") is Dictionary, "retained paid authority and snapshot operand"): return null
	var authority: Dictionary = Authority.normalize(input.authority)
	var qualified: Dictionary = Live.qualify(input.snapshot, authority)
	if not check(not authority.is_empty() and not qualified.is_empty(), "retained91 operand independently replays"): return null
	var grant: Dictionary = Grant.qualify(input.snapshot.grant, authority)
	# Do not normalize owner history28 into ordinary27, erase a session marker or
	# synthesize a title. This route consumes an already ordinary exact history27.
	if not check(not grant.is_empty() and grant.history.version == 27,
		"ordinary source requires exact Career27; owner history28 is not converted"): return null
	if not check(grant.history.runs.all(func(row: Dictionary) -> bool: return not row.has("dynasty_session")),
		"retained ordinary rows have no owner metadata"): return null
	var club: ClubCareer = ClubCareer.from_data(grant.history)
	if not check(club != null and club.current == 0, "unchanged retained ordinary history reconstructs"): return null
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	source_home = input.snapshot.home_property.duplicate(true)
	var session: Dictionary = input.snapshot.session
	var seed_value: int = int(session.seed)
	var rules: Dictionary = LeagueRules.capture_tier(session.league, int(session.tier),
		seed_value if session.league == "scramble" else null)
	if not check(StadiumLayoutSnapshot.matches(source_home, paid)
		and Normal._supported(source_home, rules)
		and Carried.supported_home(source_home, {"league": "dynasty", "tier": 0}),
		"exact distinct entry is independently pinned in93 and92"): return null
	var season: SeasonState = SeasonState.create_closed_league(seed_value, rules, true)
	if not check(ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) and club.start_league(season)
		and Normal.prepare(season) and SeasonSave.save(season), "actual ordinary start/save admits paid93"): return null
	check(ClubCareer.same(season.home_property, source_home), "initial93 captures exact retained paid field")
	_scope_controls(source_home, rules)
	return season

func _scope_controls(home: Dictionary, rules: Dictionary) -> void:
	var carried_session: Dictionary = {"league": "dynasty", "tier": 0}
	for version: int in [13, 46, 48]:
		var bad: Dictionary = home.duplicate(true)
		bad.layout.version = version
		check(not Normal._supported(bad, rules) and not Carried.supported_home(bad, carried_session), "unlisted layout remains closed " + str(version))
	for key: String in ["inventory", "geometry", "boundary", "revision"]:
		var bad: Dictionary = home.duplicate(true)
		bad.erase(key)
		check(not Normal._supported(bad, rules) and not Carried.supported_home(bad, carried_session), "complete entry requires " + key)
	var bad: Dictionary = home.duplicate(true)
	bad.layout.family += "-foreign"
	check(not Normal._supported(bad, rules) and not Carried.supported_home(bad, carried_session), "version alone cannot authorize a foreign family")
	bad = home.duplicate(true)
	bad.version = 36
	check(not Normal._supported(bad, rules) and not Carried.supported_home(bad, carried_session), "modern time wrapper is not this contract")
	if home.layout.version == 47:
		bad = home.duplicate(true)
		bad.layout.animation_base = 46
		check(not Normal._supported(bad, rules) and not Carried.supported_home(bad, carried_session), "motion cannot borrow closed46 base")
	check(not Normal._supported(home, carried_session) and not Carried.supported_home(home, rules), "ordinary and carried League gates remain separate")

func _recapture(app: SeasonApp) -> bool:
	if not check(app.season != null and Normal.matches(app.season), "actual main cold restores93"): return false
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	future_layout = app.season.home_property.layout.duplicate(true)
	var layout: Dictionary = _changed_layout(paid)
	if not check(not layout.is_empty() and not ClubCareer.same(layout, future_layout), "valid paid physical placement change exists"): return false
	if not check(ClubConstruction.save_draft(app.season, layout, paid.revision()).get("ok", false), "actual workshop Save stages changed layout"): return false
	check(ClubCareer.same(app.season.home_property, source_home), "Save alone preserves admitted field")
	paid = ClubPlayers.assets(app.season.career)
	var revision: int = paid.revision()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var before: Dictionary = SeasonSave.snapshot(app.season)
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not ClubConstruction.apply_draft(app.season, layout, revision).get("ok", false), "unwritable publication fails actual Apply")
	check(FileAccess.get_file_as_string(SeasonSave.path) == bytes
		and ClubCareer.same(SeasonSave.snapshot(app.season), before), "failed Apply preserves disk field context and paid journal")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	if not check(ClubConstruction.apply_draft(app.season, layout, revision).get("ok", false), "same Apply retry recaptures exact changed contract"): return false
	check(ClubCareer.same(app.season.home_property.layout, layout)
		and ClubCareer.same(app.season.home_property, app.season._league_home_context.home_property), "actual physical edit reaches both frozen93 pins")
	check(app.season._pool_replay_ledger != null and ClubCareer.same(app.season._pool_replay_ledger.to_data(),
		ClubPlayers.assets(app.season.career).to_data())
		and StadiumLayoutSnapshot.matches(app.season.home_property, StadiumPoolOwnedHumanEvidence.ledger(app.season)),
		"same live93 instance publishes refreshed exact replay ledger for every consumer before reload")
	var committed: Dictionary = SeasonSave.snapshot(app.season)
	check(ClubConstruction.apply_draft(app.season, layout, revision).get("replayed", false)
		and ClubCareer.same(SeasonSave.snapshot(app.season), committed), "replayed Apply cannot advance or charge again")
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), committed), "changed93 exact disk cold replay"): return false
	app.choose_player(app.season.offers()[0])
	bytes = FileAccess.get_file_as_string(SeasonSave.path)
	var locked: Dictionary = SeasonSave.snapshot(app.season)
	check(app.season.picks.size() == 1 and not ClubConstruction.editable(app.season), "first saved pick closes structural edits")
	check(not ClubConstruction.save_draft(app.season, future_layout, ClubPlayers.assets(app.season.career).revision()).get("ok", false)
		and not ClubConstruction.apply_draft(app.season, future_layout, ClubPlayers.assets(app.season.career).revision()).get("ok", false)
		and ClubCareer.same(SeasonSave.snapshot(app.season), locked)
		and FileAccess.get_file_as_string(SeasonSave.path) == bytes, "first-pick refusal leaves exact live and disk state")
	for pick in range(3): app.choose_player(app.season.offers()[0])
	if not check(app.season.picks.size() == 4, "actual four-pick ordinary draft"): return false
	var transport: Dictionary = PhysicalRoundProcess.request_for(app.season, "remaining93", "remaining93-key", 0)
	check(transport.get("version") == 1 and not transport.has("owner")
		and PhysicalRoundProcess.decode_request(transport, "remaining93") != null, "ordinary worker transport1 reconstructs paid93 without owner metadata")
	check(app.season.career.to_data().version == 27 and not SeasonSave.dynasty_owner_bound()
		and app.season._dynasty_career_session.is_empty(), "ordinary history27 is not owner history28")
	_fixture_helpers(app.season)
	var bad: Dictionary = SeasonSave.snapshot(app.season)
	bad.home_property = source_home.duplicate(true)
	check(SeasonSave._decode(bad) == null, "valid old field cannot replace93 frozen marker and current paid ledger")
	check(SeasonSave._decode(SeasonSave.snapshot(app.season).checkpoint) == null, "stripping93 cannot enter historical closed decoder")
	return true

func _changed_layout(paid: ClubAssetLedger) -> Dictionary:
	var layout: Dictionary = paid.view().stadium_active.duplicate(true)
	# Pool's original public contract is receiver-only. Change the owned Pool
	# pose through its public validator instead of inventing a forbidden obstacle.
	if int(layout.version) == StadiumPoolOwnedLayout.VERSION:
		var position: Vector2 = Vector2(layout.pool.position[0], layout.pool.position[1])
		for offset: Vector2 in [Vector2(0.5, 0), Vector2(-0.5, 0), Vector2(0, 0.5), Vector2(0, -0.5)]:
			var moved: Dictionary = StadiumPoolOwnedLayout.relocated(layout, paid.construction(),
				paid.surface_owned(), paid.view().land, position + offset, int(layout.pool.yaw))
			if not moved.is_empty() and _layout_valid(paid, moved):
				check(moved.pool.copy == layout.pool.copy and moved.receiver == layout.receiver
					and moved.obstacles.is_empty() and not ClubCareer.same(moved.pool.position, layout.pool.position),
					"Pool edit preserves exact paid copy and receiver-only grammar while changing pose")
				return moved
		return {}
	# The live waterfall consumes all four live units and permits no companions.
	# Use the actual public Store action, preserving47 and its paid45 base; the
	# later shared Apply restores the original installed moving copy for next92.
	if StadiumWaterfallAnimationLayout.is_family(layout) and not layout.live_waterfalls.is_empty():
		var copy: String = layout.live_waterfalls[0].copy
		var stored: Dictionary = StadiumWaterfallAnimationLayout.store_copy(layout, copy)
		if not stored.is_empty() and _layout_valid(paid, stored):
			check(stored.version == layout.version and stored.animation_base == layout.animation_base
				and stored.live_waterfalls.is_empty() and not stored.waterfall_motion.has(copy)
				and not StadiumWaterfallAnimationLayout.placed_copies(stored).has(copy)
				and paid.construction().copies.has(copy) and paid.construction().copies[copy].item == "ST-046"
				and ClubCareer.same(layout, paid.view().stadium_active),
				"public Store changes physical47 placement, retains paid copy/base and leaves original field untouched")
			return stored
		return {}
	if not layout.get("obstacles", []).is_empty():
		layout.obstacles = []
		return layout if _layout_valid(paid, layout) else {}
	for copy: String in paid.construction().copies:
		if paid.construction().copies[copy].item not in ["ST-001", "ST-003"]: continue
		for site: String in ["O-R1", "O-L1"]:
			layout.obstacles = [{"copy": copy, "site": site, "yaw": 90}]
			if _layout_valid(paid, layout): return layout
	return {}

func _layout_valid(paid: ClubAssetLedger, layout: Dictionary) -> bool:
	return StadiumOwnedLayout.validate(layout, paid.construction(), paid.wall_pieces(),
		paid.surface_owned(), paid.view().land, paid.scoreboards()).get("ok", false)

func _fixture_helpers(season: SeasonState) -> void:
	check(SeasonPhysicalFixtures.match_for(season, season.pending_fixture()) != null,
		"actual next match reconstructs without crossing future workload boundary")
	var modes: Dictionary = {}
	var fixtures: int = 0
	for fixture: Dictionary in season.schedule:
		if fixture.home != 0 or fixture.get("neutral", false): continue
		fixtures += 1
		var field: Dictionary = StadiumLayoutSnapshot.for_fixture(season, fixture)
		check(not field.is_empty() and StadiumLayoutSnapshot.valid(field)
			and StadiumLayoutSnapshot.matches(field, ClubPlayers.assets(season.career) if season.career != null else season._pool_replay_ledger),
			"scheduled field preserves full independent stock and environment grammar")
		if field.has("environment"): modes[field.environment.mode] = true
		check(not Normal._supported(field, season.league_rules) if field.has("environment") else true,
			"environment-bearing fixture cannot impersonate complete entry")
		if field.has("environment"):
			var changed: Dictionary = field.duplicate(true)
			changed.environment.fixture += 1
			check(StadiumLayoutSnapshot.key(changed) != StadiumLayoutSnapshot.key(field), "full property identity binds fixture environment")
	check(fixtures > 0 and season.owned_surface_night.is_empty(), "natural schedule has owned homes and no modern Night policy")
	if season.home_property.layout.version in [9, 10, 11]:
		var recipe: Dictionary = StadiumHomeLayout.validate(season.home_property.layout,
			StadiumLayoutSnapshot.ownership(season.home_property), season.home_property.tier)
		if recipe.get("night_qualified", false):
			check(not modes.is_empty() and modes.keys().all(func(mode: String) -> bool: return mode in ["day", "night"]),
				"original Yard recipe retains naturally scheduled modes without choosing a seed")

func _owner_route(app: SeasonApp) -> void:
	var ordinary_bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var roster: Array = app.season.picks.duplicate()
	var admitted_home: Dictionary = app.season.home_property.duplicate(true)
	if not check(app.dynasty_enrollment.prepare(99802), "actual93 enrollment prepares92"): return
	var ticket: int = app.dynasty_enrollment.token()
	Store._test_stop_after = "intent.rename"
	check(not app.dynasty_enrollment.commit(ticket), "92 enrollment interruption is not promoted")
	Store._test_stop_after = ""
	check(Store.inspect(app.dynasty_enrollment.path).get("status") == "pending", "exact92 create intent persists")
	if not check(app.dynasty_enrollment.commit(ticket), "same enrollment ticket recovers92"): return
	check(app.season._league_home_context.get("format") == 92 and app.season.picks == roster
		and ClubCareer.same(app.season.home_property, admitted_home), "92 retains roster and exact recaptured paid field")
	check(FileAccess.get_file_as_string(SeasonSave.path) == ordinary_bytes, "ordinary93 source is archived byte-identically")
	var carried_start: Dictionary = app.season._dynasty_start.duplicate(true)
	var carried_access: Dictionary = app.season._closed_access.duplicate(true)
	var current: Dictionary = app.dynasty_owner.found()
	var original_snapshot: Dictionary = SeasonSave.snapshot(app.season)
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed"
		and Runtime.paid_ledger(app.season) != null, "selected92 cold replay grants exact frozen runtime ledger")
	var transport: Dictionary = PhysicalRoundProcess.request_for(app.season, "remaining92", "remaining92-key", 0)
	check(transport.get("version") == 4, "restored92 produces explicit owner transport4")
	check(PhysicalRoundProcess.decode_request(transport, "remaining92") != null,
		"owner92 transport4 retains exact current authority")
	var wire: Dictionary = JSON.parse_string(JSON.stringify(transport, "", true, true))
	check(typeof(wire.get("version")) == TYPE_FLOAT and typeof(wire.get("season", {}).get("version")) == TYPE_FLOAT,
		"owner92 actual wire carries float4 and float92 discriminators")
	check(PhysicalRoundProcess.decode_request(wire, "remaining92") != null,
		"owner92 JSON worker transport retains exact current authority")
	var wrong: Dictionary = transport.duplicate(true)
	wrong.version = 1
	check(PhysicalRoundProcess.decode_request(wrong, "remaining92") == null, "owner92 cannot masquerade as ordinary transport1")
	_fixture_helpers(app.season)
	if not check(app.dynasty_owner.start_other("dugout", current.revision, 99803), "actual owner opens separate91 and pauses92"): return
	current = app.dynasty_owner.found()
	var frozen_owner: Dictionary = current.owner.duplicate(true)
	var frozen_other: Dictionary = SeasonSave.snapshot(app.season)
	if not _asset(app, {"op": "stadium_draft", "layout": future_layout}): return
	var draft_paid: ClubAssetLedger = ClubPlayers.assets(Authority._history(app.dynasty_owner.found().owner.career))
	check(ClubCareer.same(draft_paid.view().stadium_active, admitted_home.layout), "shared Save keeps future active layout unchanged")
	if not _asset(app, {"op": "stadium_apply", "layout": future_layout,
		"geometry": StadiumOwnedLayout.geometry(draft_paid.view().land, future_layout)}, true): return
	current = app.dynasty_owner.found()
	check(ClubCareer.same(current.owner.dynasty, frozen_owner.dynasty)
		and ClubCareer.same(current.owner.other, frozen_owner.other)
		and ClubCareer.same(current.owner.career.sessions, frozen_owner.career.sessions), "shared Apply preserves both slots and all frozen session grants")
	check(ClubCareer.same(SeasonSave.snapshot(app.season), frozen_other), "selected91 remains immutable after future edit")
	if not check(app.dynasty_owner.switch_to("dynasty", current.revision), "actual owner resumes existing92"): return
	check(ClubCareer.same(SeasonSave.snapshot(app.season), original_snapshot)
		and ClubCareer.same(app.season._dynasty_start, carried_start)
		and ClubCareer.same(app.season._closed_access, carried_access), "paused92 preserves exact carried source, access and admitted field")
	current = app.dynasty_owner.found()
	if not check(app.dynasty_owner.close_current("abandon", current.revision), "explicit test abandonment, not a championship claim"): return
	current = app.dynasty_owner.found()
	var other: Dictionary = current.owner.other.duplicate(true)
	if not check(app.dynasty_owner.begin_next_tier(99804, current.revision, 0), "actual next generation admits current paid field as92"): return
	current = app.dynasty_owner.found()
	var latest_paid: ClubAssetLedger = ClubPlayers.assets(Authority._history(current.owner.career))
	check(app.season.picks == roster and app.season._league_home_context.get("format") == 92
		and ClubCareer.same(app.season.home_property, StadiumLayoutSnapshot.capture(latest_paid, true))
		and ClubCareer.same(app.season.home_property.layout, future_layout), "next92 uses current paid assets while carrying exact roster")
	check(ClubCareer.same(current.owner.other, other), "next92 preserves paused91")
	check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "final owner path cold replay")
	check(Grant.history_data(Authority._history(current.owner.career)).version == 28,
		"actual Dynasty history remains owner28, never stripped to ordinary27")

func _asset(app: SeasonApp, operands: Dictionary, interrupt: bool = false) -> bool:
	var current: Dictionary = app.dynasty_owner.found()
	var paid: ClubAssetLedger = ClubPlayers.assets(Authority._history(current.owner.career))
	var command: Dictionary = operands.duplicate(true)
	command.id = "remaining-route:" + str(current.revision)
	command.rev = paid.revision()
	var request: Dictionary = {"op": "stadium_assets", "request_id": command.id,
		"expected_revision": current.revision, "command": command}
	if interrupt:
		Store._test_stop_after = "intent.rename"
		check(Store.transact(request, app.dynasty_enrollment.path).get("status") == "not_committed", "future Apply interruption does not publish")
		Store._test_stop_after = ""
	var result: Dictionary = Store.transact(request, app.dynasty_enrollment.path)
	if not check(result.get("status") == "committed", "public owner " + str(command.op) + " commits"): return false
	check(ClubCareer.same(Store.transact(request, app.dynasty_enrollment.path).get("owner"), result.owner), "owner command exact retry is idempotent")
	return check(app.dynasty_owner.recover(), "selected owner reloads unchanged frozen field")

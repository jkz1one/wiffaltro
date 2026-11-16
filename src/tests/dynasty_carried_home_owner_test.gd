extends Node
## Staged carried-roster home proof, no physical games or public activation.
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Bound = preload("res://src/gameplay/season/dynasty_carried_home_proposal.gd")
const Authority = preload("res://src/gameplay/season/dynasty_career_authority.gd")
const Closed = preload("res://src/gameplay/season/dynasty_career_save.gd")
const Profile = preload("res://src/gameplay/season/dynasty_start_profile.gd")
const Bridge = preload("res://src/gameplay/season/season_dynasty_bridge.gd")
const Lineage = preload("res://src/gameplay/season/dynasty_lineage.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const Owner = preload("res://src/gameplay/season/dynasty_career_owner.gd")
var checks: int = 0
var failures: int = 0
var path: String = ""
var physical_games: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("PHYSICAL_CHECK ", checks, " ", ok, " ", label)
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--league-home-physical-root="):
			path = argument.trim_prefix("--league-home-physical-root=")
	if not path.is_absolute_path() or DirAccess.dir_exists_absolute(path):
		push_error("Fresh isolated --standard-owner-root required")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(path)
	SeasonSave.path = path.path_join("season.json")
	path = SeasonSave.path + ".dynasty-owner"
	await _run()
	Store._test_stop_after = ""
	SeasonSave._dynasty_owner_path = ""
	print("DYNASTY_CARRIED_HOME_OWNER: %d checks, %d failures, physical_human_games=%d" % [checks, failures, physical_games])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run() -> void:
	var source: SeasonState = SeasonState.create(38102, false, true, true)
	source.career = Fixture.prefix([
		{"league": "dugout", "tier": 0}, {"league": "dugout", "tier": 1},
		{"league": "dugout", "tier": 2}, {"league": "dugout", "tier": 3}])
	check(source.career != null and source.career.start(source), "synthetic title prefix normal source")
	for pick in range(4):
		check(source.choose_player(source.offers()[0]), "origin draft")
	check(SeasonSave.save(source), "isolated ordinary source saves")
	var origin: Dictionary = SeasonSave.snapshot(source)
	var profile: Dictionary = Profile.capture_access_season(origin, "disk-standard-lineage", "disk-standard-owner")
	var dynasty: SeasonState = Bridge.create(profile)
	check(dynasty != null, "Dynasty source")
	if dynasty == null:
		return
	var dynasty_context: Dictionary = Closed.binding_for(dynasty, profile.owner_id, profile.lineage_id, 0, 1, "disk-standard-lineage:1")
	var dynasty_snapshot: Dictionary = Closed.wrap_checkpoint(SeasonSave.snapshot(dynasty), dynasty_context)
	var created: Dictionary = Store.create({"lineage": Lineage.create(profile), "snapshot": dynasty_snapshot,
		"session_id": dynasty_context.session_id, "origin": origin}, path)
	check(created.status == "committed", "owner created: " + str(created.get("reason", "")))
	if created.status != "committed":
		return
	var owner: Dictionary = created.owner
	var proposal: Dictionary = Bound.prepare(owner, dynasty_snapshot)
	check(not proposal.is_empty(), "current selected Dynasty admits carried envelope")
	if proposal.is_empty(): return
	var checked: Dictionary = Bound.qualify(proposal, owner)
	check(not checked.is_empty(), "exact staged source qualifies")
	check(ClubCareer.same(proposal.checkpoint, dynasty_snapshot), "carried source bytes unchanged")
	check(ClubCareer.same(checked.season._dynasty_start, dynasty._dynasty_start), "start profile unchanged")
	check(ClubCareer.same(checked.season.picks, dynasty.picks), "carried roster unchanged")
	check(ClubCareer.same(checked.season.build.to_data(), dynasty.build.to_data()), "carried build unchanged")
	check(ClubCareer.same(checked.season.opponents.to_data(), dynasty.opponents.to_data()), "opponent allocation unchanged")
	check(checked.season.career == null and not checked.season.home_property.is_empty(), "frozen home without fake career")
	check(SeasonPhysicalFixtures.match_for(checked.season, checked.season.pending_fixture()) == null, "staged physical path refused")
	check(SeasonSave._decode(proposal) == null, "public save does not decode staged envelope")
	check(not Bound.qualify(JSON.parse_string(JSON.stringify(proposal, "", true, true)), owner).is_empty(), "JSON preserves carried envelope")
	for field: String in ["lineage", "session", "grant", "home_property", "source_reference"]:
		var bad: Dictionary = proposal.duplicate(true)
		bad[field] = {}
		check(Bound.qualify(bad, owner).is_empty(), "changed " + field + " refused")
	var bad: Dictionary = proposal.duplicate(true)
	bad.owner_revision += 1
	check(Bound.qualify(bad, owner).is_empty(), "wrong owner revision refused")
	bad = proposal.duplicate(true)
	bad.checkpoint.session.generation += 1
	check(Bound.qualify(bad, owner).is_empty(), "changed lineage generation refused")
	check(ClubCareer.same(Store.inspect(path).owner, owner), "proposal leaves durable owner unchanged")
	var request: Dictionary = {"op": "checkpoint", "request_id": "bind-carried-home",
		"expected_revision": owner.revision, "session_id": owner.dynasty.session_id, "snapshot": proposal}
	Store._test_stop_after = "intent.rename"
	var interrupted: Dictionary = Store.transact(request, path)
	Store._test_stop_after = ""
	check(interrupted.get("status") == "not_committed", "conversion interrupted before publication")
	check(Store.inspect(path).get("status") == "pending", "exact conversion intent retained")
	var admitted: Dictionary = Store.transact(request, path)
	check(admitted.get("status") == "committed", "owner admits92: " + str(admitted.get("reason", "")))
	if admitted.get("status") != "committed": return
	check(admitted.owner.selected == "dynasty" and admitted.owner.dynasty.session_id == owner.dynasty.session_id,
		"same Dynasty slot and session")
	check(ClubCareer.same(admitted.owner.lineage, owner.lineage), "lineage unchanged on binding")
	check(ClubCareer.same(Store.transact(request, path).owner, admitted.owner), "exact admission retry")
	check(Store.restore(path).get("status") == "committed", "cold92 owner restore")
	check(SeasonSave.bind_dynasty_owner(path), "bind selected Dynasty owner")
	var live: SeasonState = SeasonSave.restore()
	check(live != null, "current92 season restored")
	if live == null: return
	check(live._league_home_context.get("format") == 92, "dedicated92 replay installed")
	check(ClubCareer.same(live.build.to_data(), dynasty.build.to_data()), "owned binding retains carried build")
	check(SeasonSave.snapshot(live).get("version") == 92, "snapshot preserves92")
	check(SeasonPhysicalFixtures.match_for(live, live.pending_fixture()) != null, "natural carried fixture reconstructs")
	check(load("res://src/gameplay/season/dynasty_carried_home_runtime.gd").paid_ledger(live) != null,
		"current Dynasty owner grants frozen ledger")
	var old_session: Dictionary = live._dynasty_career_session.duplicate(true)
	live._dynasty_career_session.session_id = "foreign"
	check(SeasonSave.snapshot(live).is_empty(), "changed live Dynasty session refuses capture")
	live._dynasty_career_session = old_session
	check(SeasonSave.save(live), "no-op current92 checkpoint")
	check(typeof(SeasonSave.snapshot(live).get("version")) == TYPE_FLOAT,
		"restored92 header retains its JSON numeric discriminator before request construction")
	var transport: Dictionary = PhysicalRoundProcess.request_for(live, "carried-token", "carried-key", 0)
	check(transport.get("version") == 4, "explicit92 transport4")
	check(PhysicalRoundProcess.decode_request(transport, "carried-token") != null, "read-only current Dynasty worker restore")
	var wire: Dictionary = JSON.parse_string(JSON.stringify(transport, "", true, true))
	check(typeof(wire.get("version")) == TYPE_FLOAT and typeof(wire.get("season", {}).get("version")) == TYPE_FLOAT,
		"real92 worker JSON carries both version discriminators as floats")
	check(PhysicalRoundProcess.decode_request(wire, "carried-token") != null, "actual cold4/92 worker restore")
	for field: String in ["transport", "season"]:
		var exact: int = 4 if field == "transport" else 92
		for malformed: Variant in [float(exact) + 0.5, str(exact), true, NAN, INF, -INF]:
			var bad_type: Dictionary = wire.duplicate(true)
			if field == "transport": bad_type.version = malformed
			else: bad_type.season.version = malformed
			check(PhysicalRoundProcess.decode_request(bad_type, "carried-token") == null,
				"fractional/String/bool/nonfinite92 worker " + field + " discriminator refuses")
	var cross_time: Dictionary = wire.duplicate(true)
	cross_time.version = 6.0
	check(PhysicalRoundProcess.decode_request(cross_time, "carried-token") == null, "modern6 transport cannot carry Day92")
	var wrong: Dictionary = transport.duplicate(true)
	wrong.version = 3
	check(PhysicalRoundProcess.decode_request(wrong, "carried-token") == null, "historical transport3 refuses92")
	wrong = transport.duplicate(true)
	wrong.owner.session_id = "foreign"
	check(PhysicalRoundProcess.decode_request(wrong, "carried-token") == null, "worker session substitution refused")

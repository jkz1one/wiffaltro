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
	print("DYNASTY_CARRIED_HOME: %d checks, %d failures, physical_human_games=%d" % [checks, failures, physical_games])
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

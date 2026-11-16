extends Node
## Test-only ordinary authority composition reuses unchanged genuine91 human evidence.
## Not recovery of failed2335; zero new games and no modification of retained inputs.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("NORMAL93_PENDING_REUSE ", ok, " ", label)
	return ok
func _ready() -> void:
	var input: String = ""
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--retained-pending="): input = arg.trim_prefix("--retained-pending=")
		if arg.begins_with("--pending-test-root="): root = arg.trim_prefix("--pending-test-root=")
	if not input.is_absolute_path() or not FileAccess.file_exists(input) or not root.is_absolute_path() \
		or DirAccess.dir_exists_absolute(root) or FileAccess.file_exists(root):
		get_tree().quit(2)
		return
	var bytes: String = FileAccess.get_file_as_string(input)
	var value: Variant = JSON.parse_string(bytes)
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("synthetic-authority-real-evidence93.json")
	SeasonSave._dynasty_owner_path = ""
	if value is Dictionary: _run(value)
	else: check(false, "retained input dictionary")
	check(FileAccess.get_file_as_string(input) == bytes, "retained physical input byte-identical")
	print("NORMAL93_PENDING_REUSE_RESULT %d checks %d failures; new_games=0 authored_authority=true unchanged_real_human=true" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(value: Dictionary) -> void:
	var qualified: Dictionary = Live.qualify_bound(value, value.get("session", {}), value.get("grant", {}), value.get("home_property", {}))
	if not check(not qualified.is_empty(), "retained original91 fully replay-validates with pinned header"): return
	var source: SeasonState = qualified.season
	if not check(source.player_results.is_empty() and source.physical.pending.reports.is_empty()
		and source.physical.pending.human[0] == 0 and source.league_rules.league == "dugout", "retained first genuine human only"): return
	var human: Array = source.physical.pending.human.duplicate(true)
	var fixture: Dictionary = source.pending_fixture()
	var original_key: String = SeasonPhysicalFixtures.request_key(source, fixture)
	var club: ClubCareer = Grant.history_club(value.grant.history)
	var admitted: SeasonState = SeasonState.create_closed_league(source.season_seed, source.league_rules, true)
	if not check(club != null and club.current == 0 and ClubPlayerDraft.apply(admitted, source.player_access)
		and club.start_league(admitted), "test-only ordinary Career27 admits identical seed rules and frozen players"): return
	for player: String in source.picks:
		if not check(admitted.choose_player(player), "same owned roster pick is legal in authored ordinary draft"): return
	if not check(admitted.picks == source.picks and ClubCareer.same(admitted.teams[0].roster, source.teams[0].roster), "exact ordinary and retained human roster identity"): return
	# Reuse validated physical state verbatim; change only the explicit career authority.
	source._closed_access = {}
	source._dynasty_career_session = {}
	source._dynasty_owner_binding = {}
	source._league_home_context = {}
	source.home_property = {}
	source._pool_replay_ledger = null
	source.career = club
	source.league_career = true
	if not check(Normal.prepare(source), "explicit normal93 composition qualifies same paid home"): return
	if not check(SeasonPhysicalFixtures.request_key(source, fixture) == original_key
		and ClubCareer.same(source.physical.pending.human, human) and ClubCareer.same(source.home_property, value.home_property),
		"unchanged actual request human evidence and paid field"): return
	var snapshot: Dictionary = SeasonSave.snapshot(source)
	if not check(not snapshot.is_empty() and SeasonSave._decode(snapshot) != null, "full genuine pending93 envelope replay validates"): return
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not SeasonSave.save(source) and not FileAccess.file_exists(SeasonSave.path), "failed pending publication does not create accepted save")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	if not check(SeasonSave.save(source), "same genuine pending93 saves on exact retry"): return
	var cold: SeasonState = SeasonSave.restore()
	if not check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(source)), "durable pending cold replay exact"): return
	var projection: Dictionary = SeasonRoundSettlement.project(cold)
	if not check(not projection.has("error") and projection.has("fixture") and projection.fixture.id == 1, "normal resume constructs next natural AI1 without replaying human"): return
	var key: String = SeasonPhysicalFixtures.request_key(projection.candidate, projection.fixture)
	var request: Dictionary = PhysicalRoundProcess.request_for(cold, "pending-reuse-unit", key, 1)
	var worker: SeasonState = PhysicalRoundProcess.decode_request(JSON.parse_string(JSON.stringify(request, "", true, true)), "pending-reuse-unit")
	if not check(request.get("version") == 1 and not request.has("owner") and worker != null, "actual ordinary transport1 cold request decodes pending93"): return
	var next: Dictionary = SeasonRoundSettlement.project(worker)
	check(next.has("fixture") and next.fixture.id == 1 and SeasonPhysicalFixtures.request_key(next.candidate, next.fixture) == key,
		"transport1 preserves exact next AI fixture request")
	var bad: Dictionary = SeasonSave.snapshot(cold).duplicate(true)
	SeasonRoundSettlement._physical_payload(bad).physical.pending["extra"] = true
	check(SeasonSave._decode(bad) == null, "extra pending envelope key remains rejected")
	bad = SeasonSave.snapshot(cold).duplicate(true)
	SeasonRoundSettlement._physical_payload(bad).physical.pending.human[-1] = "foreign-home"
	check(SeasonSave._decode(bad) == null, "changed genuine venue identity refused")
	check(SeasonSave._decode(SeasonSave.snapshot(cold).checkpoint) == null, "historical grammar still rejects stripped93")

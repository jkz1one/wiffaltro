extends Node
const Fixture = preload("res://src/tests/league_unlock_fixture.gd")
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("NORMAL_HOME_PAID ", ok, " ", label)
	return ok
func _ready() -> void:
	var root: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--normal-paid-root="): root = arg.trim_prefix("--normal-paid-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var club: ClubCareer = Fixture.nonphysical_dynasty_source()
	var prior: ClubAssetLedger = ClubPlayers.assets(club)
	club._assets = ClubAssetLedger.new_club(prior._seed, prior._credits, prior._progress, prior._championships).to_data()
	var season: SeasonState = SeasonState.create_closed_league(99501, LeagueRules.capture("dugout"), true)
	ClubPlayerDraft.apply(season, ClubPlayers.owned(club))
	if check(club.start_league(season) and Normal.prepare(season) and SeasonSave.save(season), "funded synthetic prefix saves normal93"):
		var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
		add_child(app)
		_run(app)
		app.free()
	_legacy_placement(root)
	print("NORMAL_HOME_PAID_RESULT %d checks, %d failures; synthetic_income=true" % [checks, failures])
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(app: SeasonApp) -> void:
	var frozen: Dictionary = app.season.home_property.duplicate(true)
	var paid: ClubAssetLedger = ClubPlayers.assets(app.season.career)
	var balance: int = paid.balance()
	var revision: int = paid.revision()
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	var original: Dictionary = SeasonSave.snapshot(app.season)
	var old_replay: ClubAssetLedger = app.season._pool_replay_ledger
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not ClubConstruction.clear_salvage(app.season, revision).get("ok", false)
		and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		and ClubCareer.same(SeasonSave.snapshot(app.season), original)
		and app.season._pool_replay_ledger == old_replay, "failed clearance preserves exact live replay-ledger identity too")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	var cleared: Dictionary = ClubConstruction.clear_salvage(app.season, revision)
	check(cleared.get("ok", false), "qualified pre-draft clearance commits")
	check(_ledger_matches(app.season), "clearance refreshes every same-live-instance ledger consumer before reload")
	check(ClubPlayers.assets(app.season.career).balance() == balance - 190 and ClubPlayers.assets(app.season.career).revision() == revision + 1,
		"clearance charges exactly190 and advances paid assets once")
	check(FileAccess.get_file_as_string(SeasonSave.path) != bytes and app.season.home_property.layout.salvage_cars.is_empty()
		and ClubCareer.same(app.season.home_property, app.season._league_home_context.home_property), "clearance atomically recaptures disk and both admitted home pins")
	check(ClubConstruction.clear_salvage(app.season, revision).get("replayed", false)
		and ClubPlayers.assets(app.season.career).balance() == balance - 190, "same paid clearance retry cannot charge twice")
	frozen = app.season.home_property.duplicate(true)
	revision = ClubPlayers.assets(app.season.career).revision()
	if not check(ClubConstruction.save_draft(app.season, frozen.layout, revision).get("ok", false), "stage supported owned layout before drafting"): return
	paid = ClubPlayers.assets(app.season.career)
	var apply_revision: int = paid.revision()
	bytes = FileAccess.get_file_as_string(SeasonSave.path)
	old_replay = app.season._pool_replay_ledger
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not ClubConstruction.apply_draft(app.season, frozen.layout, apply_revision).get("ok", false), "recapture publication fails atomically on unwritable temp")
	check(FileAccess.get_file_as_string(SeasonSave.path) == bytes and ClubCareer.same(app.season.home_property, frozen)
		and ClubCareer.same(app.season._league_home_context.home_property, frozen)
		and ClubPlayers.assets(app.season.career).revision() == apply_revision
		and app.season._pool_replay_ledger == old_replay, "failed publication preserves home context assets replay-ledger identity and disk")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	if not check(ClubConstruction.apply_draft(app.season, frozen.layout, apply_revision).get("ok", false), "apply supported layout atomically recaptures home"): return
	check(_ledger_matches(app.season), "Apply refreshes every same-live-instance ledger consumer before reload")
	check(app.season.home_property.revision > frozen.revision and ClubCareer.same(app.season.home_property, app.season._league_home_context.home_property), "home and context advance together")
	check(ClubCareer.same(app.season.home_property, StadiumLayoutSnapshot.capture(ClubPlayers.assets(app.season.career))), "recaptured field is exact current paid snapshot")
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(app.season)), "recaptured pre-draft save exact cold replay")
	check(ClubConstruction.apply_draft(app.season, frozen.layout, apply_revision).get("replayed", false), "same apply retry preserves transaction identity")
	var locked: Dictionary = app.season.home_property.duplicate(true)
	app.choose_player(app.season.offers()[0])
	check(app.season.picks.size() == 1, "first saved draft pick locks structure")
	bytes = FileAccess.get_file_as_string(SeasonSave.path)
	paid = ClubPlayers.assets(app.season.career)
	check(not ClubConstruction.apply_draft(app.season, frozen.layout, paid.revision()).get("ok", false)
		and not ClubConstruction.clear_salvage(app.season, paid.revision()).get("ok", false), "drafted field edits refused")
	check(FileAccess.get_file_as_string(SeasonSave.path) == bytes and ClubCareer.same(app.season.home_property, locked), "first-pick lock preserves home and save")

func _legacy_placement(root: String) -> void:
	SeasonSave.path = root.path_join("legacy-placement.json")
	var club: ClubCareer = Fixture.nonphysical_dynasty_source()
	var season: SeasonState = SeasonState.create_closed_league(99511, LeagueRules.capture("dugout"), true)
	ClubPlayerDraft.apply(season, ClubPlayers.owned(club))
	if not check(club.start_league(season) and Normal.prepare(season) and SeasonSave.save(season), "legacy owned93 pre-draft placement source"): return
	var before: Dictionary = season.home_property.duplicate(true)
	if not check(before.version == 3 and before.layout.version == 1, "actual legacy3 layout1 fixture"): return
	var layout: Dictionary = before.layout.duplicate(true)
	layout.receiver = "starter-v1:ST-079"
	layout.obstacles = [{"copy": "starter-v1:ST-003", "site": "O-L1", "yaw": 90}]
	check(not ClubCareer.same(layout, before.layout), "positive edit changes physical placement geometry")
	if not check(ClubConstruction.save_draft(season, layout, ClubPlayers.assets(season.career).revision()).get("ok", false), "stage actual legacy placement"): return
	if not check(ClubConstruction.apply_draft(season, layout, ClubPlayers.assets(season.career).revision()).get("ok", false), "apply actual legacy placement"): return
	check(ClubCareer.same(season.home_property.layout, layout) and ClubCareer.same(season._league_home_context.home_property, season.home_property), "changed physical placement appears in both frozen home and context")
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(cold.home_property.layout, layout) and ClubCareer.same(SeasonSave.snapshot(cold), SeasonSave.snapshot(season)), "actual changed placement survives exact cold replay")

	if cold == null: return
	var revision: int = ClubPlayers.assets(cold.career).revision()
	var before_land: Dictionary = SeasonSave.snapshot(cold)
	var prior_replay: ClubAssetLedger = cold._pool_replay_ledger
	var bytes: String = FileAccess.get_file_as_string(SeasonSave.path)
	DirAccess.make_dir_absolute(SeasonSave.path + ".tmp")
	check(not ClubConstruction.buy_land(cold, "expanded", revision).get("ok", false)
		and FileAccess.get_file_as_string(SeasonSave.path) == bytes
		and ClubCareer.same(SeasonSave.snapshot(cold), before_land)
		and cold._pool_replay_ledger == prior_replay, "failed land recapture preserves exact replay ledger and ordinary save")
	DirAccess.remove_absolute(SeasonSave.path + ".tmp")
	if not check(ClubConstruction.buy_land(cold, "expanded", revision).get("ok", false), "paid ordinary land expansion recaptures legacy entry4"): return
	check(cold.home_property.version == 4 and cold.home_property.tier == "expanded"
		and _ledger_matches(cold), "land expansion refreshes exact same-live-instance ledger before reload")
	var expanded: Dictionary = SeasonSave.snapshot(cold)
	check(ClubConstruction.buy_land(cold, "expanded", revision).get("replayed", false)
		and ClubCareer.same(SeasonSave.snapshot(cold), expanded) and _ledger_matches(cold), "land retry retains exact ledger and entry without another charge")
	var restored: SeasonState = SeasonSave.restore()
	check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored), expanded), "expanded entry4 exact cold replay")

func _ledger_matches(season: SeasonState) -> bool:
	return season._pool_replay_ledger != null \
		and ClubCareer.same(season._pool_replay_ledger.to_data(), ClubPlayers.assets(season.career).to_data()) \
		and StadiumLayoutSnapshot.matches(season.home_property, StadiumPoolOwnedHumanEvidence.ledger(season))

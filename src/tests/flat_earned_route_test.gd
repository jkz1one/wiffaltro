extends Node
## Reuses the hashed authored prospective-reward fixture; not naturally earned titles.
const Live = preload("res://src/gameplay/season/dynasty_league_home_live.gd")
const Grant = preload("res://src/gameplay/season/dynasty_standard_grant.gd")
const Normal = preload("res://src/gameplay/season/normal_league_home.gd")
const Runtime = preload("res://src/gameplay/season/dynasty_carried_home_runtime.gd")
const Store = preload("res://src/gameplay/season/dynasty_owner_store.gd")
const FIXTURE_SHA: String = "318dd96f01e0fa973b13e552b5fa6b1bd878f384c3857c279abfa0456ab7d6e2"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> bool:
	checks += 1
	print("FLAT_EARNED_ROUTE ", ok, " ", label)
	if not ok: failures += 1
	return ok
func _ready() -> void:
	var root: String = ""
	var input: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--flat-earned-input="): input = arg.trim_prefix("--flat-earned-input=")
		if arg.begins_with("--flat-earned-route-root="): root = arg.trim_prefix("--flat-earned-route-root=")
	if not root.is_absolute_path() or DirAccess.dir_exists_absolute(root) or not input.is_absolute_path() or not FileAccess.file_exists(input):
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(root)
	SeasonSave.path = root.path_join("season.json")
	SeasonSave._dynasty_owner_path = ""
	var bytes: String = FileAccess.get_file_as_string(input)
	if check(bytes.sha256_text() == FIXTURE_SHA, "exact prior authored earned fixture, not a user save"):
		var value: Dictionary = JSON.parse_string(bytes)
		var verified: Dictionary = Live.qualify_bound(value, value.session, value.grant, value.home_property)
		if check(not verified.is_empty(), "retained prospective-earned grant fully replays"):
			_run(Grant.history_club(verified.home_grant.history))
	SeasonSave._dynasty_owner_path = ""
	check(FileAccess.get_file_as_string(input).sha256_text() == FIXTURE_SHA, "input source remains untouched")
	print("FLAT_EARNED_ROUTES checks=", checks, " failures=", failures, " synthetic_titles=true physical_games=0")
	await TestAudioDrain.finish(get_tree())
	get_tree().quit(0 if failures == 0 else 1)
func _run(club: ClubCareer) -> void:
	var key: String = StadiumPennantRewards.mastery_key()
	var paid: ClubAssetLedger = ClubPlayers.assets(club)
	var earned: Dictionary = paid.construction().copies[key].duplicate(true)
	if not check(club.current == 0 and paid.view().stadium_active.version == 41
		and paid.view().stadium_active.mastery_banners.size() == 1 and StadiumPennantRewards.delivered(club, paid), "exact prospective title provenance and paid hosted banner"): return
	var season: SeasonState = SeasonState.create_closed_league(99621, LeagueRules.capture_tier("dugout", 1), true)
	if not check(ClubPlayerDraft.apply(season, ClubPlayers.owned(club)) and club.start_league(season)
		and Normal.prepare(season) and SeasonSave.save(season), "normal93 tier1 accepts own-title fixture and exact paid banner"): return
	var app: SeasonApp = preload("res://src/presentation/season/season_app.tscn").instantiate()
	add_child(app)
	for pick in range(4): app.choose_player(app.season.offers()[0])
	var saved: Dictionary = SeasonSave.snapshot(app.season)
	var cold: SeasonState = SeasonSave.restore()
	check(cold != null and ClubCareer.same(SeasonSave.snapshot(cold), saved)
		and ClubCareer.same(cold.home_property.inventory.copies[key], earned), "actual normal draft Save Reload preserves exact earned copy")
	var bad: Dictionary = saved.duplicate(true)
	bad.home_property.inventory.copies[key].earned.season_id += 1
	check(SeasonSave._decode(bad) == null, "ordinary93 forged earned provenance refused")
	var source: String = FileAccess.get_file_as_string(SeasonSave.path)
	if check(app.dynasty_enrollment.prepare(99622), "legitimate nonscramble source prepares earned carried92: " + app.notice) \
		and check(app.dynasty_enrollment.commit(app.dynasty_enrollment.token()), "actual earned-source enrollment commits92: " + app.notice):
		var ledger: ClubAssetLedger = Runtime.paid_ledger(app.season)
		check(ledger != null and ClubCareer.same(ledger.construction().copies[key], earned)
			and ClubCareer.same(app.season.home_property.inventory.copies[key], earned), "carried92 retains exact prospective reward and paid host")
		check(Store.restore(app.dynasty_enrollment.path).get("status") == "committed", "earned92 durable owner cold replay")
		check(FileAccess.get_file_as_string(SeasonSave.path) == source, "normal earned source archive unchanged")
	app.free()

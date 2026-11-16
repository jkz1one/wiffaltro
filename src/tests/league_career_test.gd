extends Node
## Focused candidate career/save contracts. Synthetic score proofs below are
## record-unit fixtures, not claims of physically played championship games.

const ClubLeagueCareer = preload("res://src/gameplay/season/club_league_career.gd")
const LeagueCareerSave = preload("res://src/gameplay/season/league_career_save.gd")
const UnlockFixture = preload("res://src/tests/league_unlock_fixture.gd")

var failures: int = 0
var checks: int = 0
var root: String = ""


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--league-career-test-root="):
			root = argument.trim_prefix("--league-career-test-root=")
	if (
		not root.is_absolute_path() or root.length() < 2
		or root != root.simplify_path() or DirAccess.dir_exists_absolute(root)
	):
		push_error("A fresh absolute --league-career-test-root= is required; no test ran.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		get_tree().quit(2)
		return
	SeasonSave.path = root.path_join("candidate.json")
	for id: String in ClubLeagueCareer.IDS:
		_roundtrip(id)
	_mixed_history()
	_record_units()
	print("League career checks: %d, failures: %d, physical games: 0" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _new(id: String, club: ClubCareer = null) -> SeasonState:
	var rules: Dictionary = LeagueRules.capture(id, 0, 8107 if id == "scramble" else null)
	var season: SeasonState = SeasonState.create_closed_league(8107, rules, true)
	var career: ClubCareer = UnlockFixture.for_league(id) if club == null else club
	if season == null or career == null or not career.start_league(season):
		check(false, "start candidate " + id)
		return null
	return season


func _roundtrip(id: String) -> void:
	var season: SeasonState = _new(id)
	if season == null:
		return
	check(not ClubCareer.new().start(season), "ordinary start remains Standard only")
	check(season.career.active_tier() == 0, "candidate Base tier")
	var starting_balance: int = season.career.balance()
	var before: Dictionary = SeasonSave.snapshot(season)
	check(before.get("version") == LeagueCareerSave.VERSION, "new explicit Save81")
	var restored: SeasonState = SeasonSave._decode(before)
	check(restored != null, "fresh League checkpoint restores: " + id)
	if restored == null:
		return
	check(ClubCareer.same(SeasonSave.snapshot(restored), before), "exact initial round trip")
	for pick in range(4):
		check(restored.choose_player(restored.offers()[0]), "draft " + id)
	check(SeasonInventoryRules.enable(restored), "inventory admission " + id)
	check(SeasonSave.save(restored), "durable League draft " + id)
	var saved: Dictionary = restored.career.to_data()
	var loaded: SeasonState = SeasonSave.restore()
	check(loaded != null, "cold saved League read " + id)
	if loaded == null:
		return
	check(ClubCareer.same(loaded.career.to_data(), saved), "career exact after cold read")
	check(loaded.league_rules == season.league_rules, "rules and Scramble seed retained")
	check(loaded.career.balance() == starting_balance, "unfinished season earns no Club Bucks")
	var raw: Dictionary = SeasonSave.snapshot(loaded)
	check(not SeasonRoundSettlement._physical_payload(raw).is_empty(),
		"round projection locates physical payload through actual Save81 inventory layers")
	var downgrade: Dictionary = raw.checkpoint.duplicate(true)
	var payload: Dictionary = downgrade
	while payload.get("checkpoint") is Dictionary:
		payload = payload.checkpoint
	payload["career"] = raw.career
	check(SeasonSave._decode(downgrade) == null, "old envelope refuses Career27")
	var bad: Dictionary = raw.duplicate(true)
	bad.career.runs[-1].league_rules.profile += "-changed"
	check(SeasonSave._decode(bad) == null, "changed saved rule profile rejected")
	check(SeasonSave.save(loaded), "repeat save")
	check(ClubCareer.same(loaded.career.to_data(), saved), "repeat save does not credit")
	var corrupt: FileAccess = FileAccess.open(SeasonSave.path, FileAccess.WRITE)
	corrupt.store_string("not a checkpoint")
	corrupt.close()
	var recovered: SeasonState = SeasonSave.restore()
	check(recovered != null, "valid backup recovers corrupted candidate primary")
	check(FileAccess.get_file_as_string(SeasonSave.path) == "not a checkpoint",
		"recovery leaves corrupt primary untouched")


func _mixed_history() -> void:
	var first: SeasonState = _new("dugout")
	var other: SeasonState = _new("sponsorship")
	if first == null or other == null:
		return
	var unchanged: Dictionary = first.career.to_data()
	check(not first.career.sync(other), "same-seed cross-League receiver refused")
	check(ClubCareer.same(first.career.to_data(), unchanged), "wrong receiver unchanged")
	var club: ClubCareer = first.career.fork()
	check(club.close(first), "abandon League through fork")
	check(not club.cleared(0, "dugout") and club.balance() == 0, "abandon no clear or pay")
	var standard: SeasonState = SeasonState.create(8107, false, true, true)
	standard.career = club
	check(club.start(standard), "return to ordinary Standard with mixed history")
	var snap: Dictionary = SeasonSave.snapshot(standard)
	check(snap.get("version") == LeagueCareerSave.VERSION, "Standard retains new wrapper")
	var restored: SeasonState = SeasonSave._decode(snap)
	check(restored != null, "Standard after League restores")
	if restored == null:
		return
	var next_club: ClubCareer = restored.career.fork()
	check(next_club.close(restored), "close Standard fork")
	var next: SeasonState = _new("dugout", next_club)
	check(next != null and next.career.current == 3, "shared run identity across Leagues")
	check(not first.career.sync(standard), "League receiver refuses Standard context")
	var legacy: SeasonState = SeasonState.create(8107, false, true, true)
	legacy.career = ClubCareer.new()
	check(legacy.career.start(legacy), "legacy Standard start")
	check(SeasonSave.snapshot(legacy).get("version") != LeagueCareerSave.VERSION,
		"Standard-only career keeps legacy envelope")
	var dynasty: SeasonState = SeasonState.create_closed_league(8107,
		LeagueRules.capture("dynasty"), true)
	check(not ClubCareer.new().start_league(dynasty), "Dynasty persistence cannot be reset here")


func _proof(id: String, tier: int = 0) -> Dictionary:
	return UnlockFixture.proof(id, tier)


func _record_units() -> void:
	var titles: Dictionary = {"0": false, "1": false, "2": false, "3": false, "4": false}
	for id: String in ["standard", "dugout", "sponsorship", "doubleheader", "dugout"]:
		var proof: Dictionary = _proof(id)
		var key: String = ClubLeagueCareer.title_key(id, 0)
		var first: bool = not titles.get(key, false)
		var receipt: Dictionary = ClubSeasonRecord.receipt(proof, first)
		var row: Dictionary = {"seed": 8107, "league": id, "tier": 0,
			"status": "completed", "proof": proof, "receipt": receipt}
		if id != "standard":
			row["league_rules"] = proof.league_rules
		check(not ClubCareer._progression_record(row, titles).is_empty(),
			"League-specific title unit " + id)
		check(receipt.get("first_bonus") == (25 if first else 0), "first title once per League")
		check(titles.get(key, false), "championship credit in its own League")
	var paired: Dictionary = _proof("doubleheader")
	paired.league_rules = LeagueRules.capture("dugout")
	check(ClubSeasonRecord.analyze(paired).is_empty(), "paired proof rejects ordinary schedule")
	var loss: Dictionary = _proof("academy")
	loss.scores[-1][3] = 1
	loss.scores[-1][4] = 0
	var receipt: Dictionary = ClubSeasonRecord.receipt(loss, true)
	var row: Dictionary = {"seed": 8107, "league": "academy", "tier": 0,
		"status": "completed", "proof": loss, "receipt": receipt,
		"league_rules": loss.league_rules}
	check(not ClubCareer._progression_record(row, titles).is_empty(), "completed loss record")
	check(not titles.get("academy:0", false) and receipt.first_bonus == 0,
		"loss earns ordinary finish payout without a clear or first-title bonus")

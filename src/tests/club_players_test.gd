extends "res://src/tests/club_career_test.gd"
## Synthetic scored career fixtures verify atomic spending, not balance or physical play.


func _ready() -> void:
	SeasonSave.path = "user://permanent-players-%d.json" % OS.get_process_id()
	var season: SeasonState = _new()
	_check(ClubPlayers.owned(season.career) == ClubPlayerCatalog.initial_owned(), "twelve starters")
	_finish(season, "champion")
	_check(SeasonSave.save(season), "save real career receipt from synthetic scored season")
	var before: int = season.career.balance()
	_check(before == 220, "same existing first-title earnings")
	var earned: Array[String] = ClubPlayers.owned(season.career)
	_check(earned.has("player.quinn_riley") and earned.has("player.rowan_chase"),
		"first completion and championship award earned-only players")
	_check(not earned.has("player.tess_vale"), "no missing performance inference")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var start_revision: int = ledger.revision()
	var award_prefix: Array = ledger.to_data().events.duplicate(true)
	_check(start_revision == 1 and award_prefix[0].op == "stadium_pennant"
		and award_prefix[0].id == "championship-v1:1" and award_prefix[0].rev == 0,
		"first championship journals exactly one earned pennant before paid packs")
	_check(StadiumPennantRewards.delivered(season.career, ledger)
		and ledger.view().spent == 0 and ledger.view().pack_price == 80,
		"earned award retains authority, adds no spending and does not change pack price")
	var open: Dictionary = {"id": "pack:0", "rev": start_revision, "op": "player_pack_open",
		"through": 1, "price_version": ClubPlayerCatalog.PRICE_VERSION}
	var path: String = SeasonSave.path
	var old: Dictionary = season.career.to_data()
	var saved_bytes: String = FileAccess.get_file_as_string(path)
	var stale: Dictionary = open.duplicate(true)
	stale.rev = 0
	_check(not ClubPlayers.transact(season, stale).ok
		and ClubCareer.same(season.career.to_data(), old)
		and FileAccess.get_file_as_string(path) == saved_bytes,
		"stale pre-award revision rejects without spending, reveal or disk mutation")
	SeasonSave.path = path + "/missing/profile.json"
	_check(not ClubPlayers.transact(season, open).ok and season.career.to_data() == old,
		"failed payment save preserves balance and unopened pack")
	SeasonSave.path = path
	_check(FileAccess.get_file_as_string(path) == saved_bytes,
		"failed payment save preserves original primary bytes")
	_check(ClubPlayers.transact(season, open).ok, "paid pack saved atomically")
	_check(season.career.balance() == before - 80, "shared career wallet charged exactly once")
	_check(ClubPlayers.transact(season, open).ok and season.career.balance() == before - 80,
		"duplicate payment request idempotent")
	var revealed: Dictionary = ClubPlayers.assets(season.career).view().pending
	_check(ClubPlayers.assets(season.career).revision() == start_revision + 1
		and revealed.get("paid") == 80 and revealed.get("id") == open.id,
		"one paid reveal appends exactly one event after earned award")
	season = SeasonSave.restore()
	_check(season != null, "paid unresolved pack restores")
	if season == null:
		_cleanup()
		get_tree().quit(1)
		return
	var pending: Dictionary = ClubPlayers.assets(season.career).view().pending
	_check(ClubCareer.same(pending, revealed) and pending.get("choices", []).size() == 3,
		"same saved three-choice reveal")
	if not pending.has("choices") or pending.choices.size() != 3:
		_cleanup()
		get_tree().quit(1)
		return
	var other: Dictionary = open.duplicate(true)
	other.id = "pack:1"
	other.rev = start_revision + 1
	_check(not ClubPlayers.transact(season, other).ok, "pending reveal blocks second purchase")
	var choose: Dictionary = {"id": "pick:0", "rev": start_revision + 1, "op": "player_pack_pick",
		"pack": pending.id, "player": pending.choices[0]}
	SeasonSave.path = path + "/missing/profile.json"
	_check(not ClubPlayers.transact(season, choose).ok and not ClubPlayers.owned(
		season.career).has(choose.player), "failed selection save preserves paid reveal")
	SeasonSave.path = path
	_check(ClubPlayers.transact(season, choose).ok, "selected ownership saved")
	season = SeasonSave.restore()
	_check(ClubPlayers.owned(season.career).has(choose.player)
		and ClubPlayers.assets(season.career).view().pending.is_empty(), "owned after restart")
	_check(ClubPlayers.transact(season, choose).ok and season.career.balance() == before - 80,
		"selection replay cannot duplicate or repay")
	ledger = ClubPlayers.assets(season.career)
	_check(ledger.revision() == start_revision + 2 and ledger.view().spent == 80
		and ClubCareer.same(ledger.to_data().events.slice(0, start_revision), award_prefix)
		and StadiumPennantRewards.delivered(season.career, ledger),
		"selection appends once while preserving exact earned prefix and total spend")
	var bad: Dictionary = SeasonSave.snapshot(season)
	bad.career.runs[-1].player_progress.development.mastery = 5
	_check(SeasonSave._decode(bad) == null, "current unlock detail binds actual development journal")
	bad = SeasonSave.snapshot(season)
	_check(bad.career.assets.events[start_revision].op == "player_pack_open",
		"income tamper targets actual paid event, not the preceding earned pennant")
	bad.career.assets.events[start_revision].through = 0
	_check(SeasonSave._decode(bad) == null, "no spending with unearned income epoch")
	_migration()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro permanent player checks passed: career proof, atomic packs and migration.")
	get_tree().quit(0 if _failures == 0 else 1)


func _migration() -> void:
	var season: SeasonState = _new(39)
	_record(season)
	var saved: Dictionary = SeasonSave.snapshot(season)
	var current_career: Dictionary = saved.career.duplicate(true)
	saved.career.version = 21
	ClubPlayerTestFixture.before_ownership(saved.career)
	_check(SeasonOwnership._keys(saved.career, ["version", "current", "runs"]),
		"legacy21 contains exact pre-ownership header without later award metadata")
	for key: String in ["assets", "pennants", "plaques"]:
		var smuggled: Dictionary = saved.duplicate(true)
		smuggled.career[key] = current_career[key]
		_check(SeasonSave._decode(smuggled) == null,
			"legacy21 rejects later metadata smuggling: " + key)
	var old: SeasonState = SeasonSave._decode(saved)
	_check(old != null, "legacy career migrates without spending or invented history")
	if old == null:
		return
	_check(old.career._pennants.is_empty() and old.career._plaques.is_empty()
		and ClubPlayers.assets(old.career).revision() == 0,
		"legacy migration creates no retrospective award or spending journal")
	_check(SeasonSave._decode(JSON.parse_string(JSON.stringify(saved, "", true, true))) != null,
		"exact legacy21 fixture also admits after full-precision JSON cold roundtrip")
	_check(not old.career.runs[-1].player_progress.is_empty(),
		"current legacy run recovered only from its actual replayed proof")
	_check(SeasonSave.save(old) and SeasonSave.restore() != null, "migrated career resaves")
	var empty: ClubCareer = ClubCareer.from_data(ClubCareer.new().to_data())
	_check(empty != null, "empty career roundtrip")
	var next: SeasonState = _new(29, empty)
	_check(SeasonSave.save(next), "restored empty profile can start its first seeded career")

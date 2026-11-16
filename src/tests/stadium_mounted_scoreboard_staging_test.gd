extends "res://src/tests/stadium_scoreboard_save_test.gd"
## Real earned career and atomic persistence across closed staging and normal mounted admission.


func _ready() -> void:
	if StadiumMountedScoreboardLayout.RUNTIME_READY:
		SeasonSave.path = "user://mounted-scoreboard-staging-%d.json" % OS.get_process_id()
		await _admitted()
		_cleanup()
		await TestAudioDrain.finish(get_tree())
		if _failures == 0:
			print("Wiffaltro mounted scoreboard staging passed: paid normal admission remains atomic.")
		get_tree().quit(0 if _failures == 0 else 1)
		return
	SeasonSave.path = "user://mounted-scoreboard-staging-%d.json" % OS.get_process_id()
	var completed: SeasonState = _fund_boards()
	_check(completed.phase == SeasonState.Phase.COMPLETE
		and completed.career.runs.size() == 22 and completed.career.balance() == 4315,
		"twenty-two scheduled seasons fund only the existing earned receipts")
	var history: Array = completed.career.runs.duplicate(true)
	_purchase_existing(completed)
	var ledger: ClubAssetLedger = ClubPlayers.assets(completed.career)
	var old_layout: Dictionary = _old_layout(ledger)
	_check(ClubConstruction.save_draft(completed, old_layout, ledger.revision()).ok,
		"supported complete14 draft follows the ordinary public workflow")
	_check(ClubConstruction.apply_draft(completed, old_layout,
		ClubPlayers.assets(completed.career).revision()).ok,
		"supported completed-season field applies before future data is staged")
	ledger = ClubPlayers.assets(completed.career)
	var mounted: Dictionary = _mounted_layout(old_layout, ledger)
	_check(not mounted.is_empty() and not StadiumMountedScoreboardLayout.RUNTIME_READY,
		"exact mounted15 data exists while production readiness remains false")
	_public_gates(completed, mounted)
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = completed
	app.begin_season(88, true)
	var season: SeasonState = app.season
	_check(season != completed and season.phase == SeasonState.Phase.DRAFT
		and season.home_property.get("version") == 12 and season.picks.is_empty(),
		"normal owned season starts with the supported frozen entry12")
	var frozen: Dictionary = season.home_property.duplicate(true)
	var frozen_key: String = StadiumScoreboardSnapshot.key(frozen)
	_public_gates(season, mounted)
	_stage_raw(season, mounted)
	ledger = ClubPlayers.assets(season.career)
	_check(SeasonSave.snapshot(season).version == 59 and SeasonSave.save(season),
		"unchanged outer schema59 persists old frozen home plus exact ledger22 staged assets")
	_check(ClubCareer.same(season.home_property, frozen)
		and StadiumScoreboardSnapshot.key(season.home_property) == frozen_key
		and StadiumScoreboardSnapshot.matches(frozen, ledger),
		"raw staging leaves the old frozen field and its historical paid prefix unchanged")
	var loaded: SeasonState = SeasonSave.restore()
	_check(loaded != null
		and ClubCareer.same(SeasonSave.snapshot(loaded), SeasonSave.snapshot(season)),
		"actual primary save restores staged assets and the prior frozen field together")
	var declared: Dictionary = StadiumMountedScoreboardSnapshot.capture(ledger)
	_check(StadiumMountedScoreboardSnapshot.matches(declared, ledger)
		and not StadiumLayoutSnapshot.valid(declared),
		"paid mounted declaration remains pure data rather than public home admission")
	_public_gates(season, mounted)
	_reject_home_profiles(season, declared)
	_failed_purchase(season)
	_rejected_expansion(season)
	var before: Dictionary = _held_mounted(season)
	for complete_boundary: bool in [true, false]:
		app.begin_season(89, true, true, true, complete_boundary)
		_check(app.season == season and app.notice.contains("owned home layout")
			and ClubCareer.same(before, _held_mounted(season)),
			"owned-home season start refuses15 without changing field, wallet or either save")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/file.json"
	app.begin_season(90, true, true, false)
	SeasonSave.path = path
	_check(app.season == season and app.notice.contains("Could not save season")
		and ClubCareer.same(before, _held_mounted(season)),
		"failed no-home start write restores live season, journal, wallet, primary and backup")
	app.begin_season(90, true, true, false)
	var no_home: SeasonState = app.season
	var no_home_ledger: ClubAssetLedger = ClubPlayers.assets(no_home.career)
	_check(no_home != season and no_home.home_property.is_empty()
		and SeasonSave.snapshot(no_home).version == 58
		and no_home_ledger.view().stadium_active.version == 15
		and ClubCareer.same(no_home_ledger.to_data(), before.journal)
		and no_home_ledger.balance() == before.view.balance,
		"explicit historical no-home mode retains staged assets without granting a usable field")
	_check(ClubCareer.same(history, no_home.career.runs.slice(0, history.size()))
		and StadiumScoreboardSnapshot.matches(frozen, no_home_ledger)
		and StadiumMountedScoreboardSnapshot.matches(declared, no_home_ledger),
		"no-home transition preserves all earned funding archives and both frozen paid prefixes")
	loaded = SeasonSave.restore()
	_check(loaded != null and loaded.home_property.is_empty()
		and ClubCareer.same(SeasonSave.snapshot(loaded), SeasonSave.snapshot(no_home)),
		"explicit no-home save restores exact staged15 data with no invented home profile")
	app.queue_free()
	await _frames()
	_cleanup()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard staging passed: real paid saves and admission stay atomic.")
	get_tree().quit(0 if _failures == 0 else 1)


func _purchase_existing(season: SeasonState) -> void:
	var before: int = season.career.balance()
	var original: StadiumStock = ClubPlayers.assets(season.career).construction()
	_check(original.paid_count() == 3 and original.pennant_count() == 22
		and original.copies.size() == 25, "funding owns three starters and 22 earned pennants")
	var original_copies: Dictionary = original.copies.duplicate(true)
	_check(ClubConstruction.buy_copy(season, "ST-001",
		ClubPlayers.assets(season.career).revision()).ok, "original paid standard spare")
	_check(ClubConstruction.buy_wall_pieces(season, "ST-024-L", 1,
		ClubPlayers.assets(season.career).revision()).ok, "original exact paid wall-piece spare")
	_check(ClubConstruction.buy_scoreboard(season, "ST-090", 2,
		ClubPlayers.assets(season.career).revision()).ok, "original paid electronic and unused copy")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var expected: int = int(StadiumCatalog.item("ST-001").copy_price) \
		+ StadiumWallPieceOwnership.BLUEPRINT_PRICES["ST-024"] \
		+ int(StadiumWallPieceCatalog.item("ST-024-L").copy_price) \
		+ int(StadiumScoreboardCatalog.MIDDLE.blueprint_price) \
		+ 2 * int(StadiumScoreboardCatalog.MIDDLE.copy_price)
	_check(ledger.balance() == before - expected and ledger.construction().paid_count() == 4
		and ledger.construction().pennant_count() == 22
		and ledger.construction().copies.size() == original_copies.size() + 1
		and ledger.wall_pieces().stock.copies.size() == 1 and ledger.scoreboards().copies.size() == 2,
		"only unchanged original blueprint/copy prices debit the actual earned wallet")
	for key: String in original_copies:
		_check(ClubCareer.same(original_copies[key], ledger.construction().copies.get(key)),
			"purchase preserves each exact starter and earned pennant: " + key)


func _old_layout(ledger: ClubAssetLedger) -> Dictionary:
	var layout: Dictionary = StadiumStarterLayout.empty()
	layout.receiver = "starter-v1:ST-079"
	return StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(layout, ledger.surface_owned(), true)))


func _mounted_layout(old: Dictionary, ledger: ClubAssetLedger) -> Dictionary:
	var result: Dictionary = StadiumMountedScoreboardLayout.upgrade(old, ledger.construction(),
		ledger.wall_pieces(), ledger.surface_owned(), ledger.view().land, ledger.scoreboards())
	if result.is_empty():
		return {}
	var keys: Array = ledger.scoreboards().copies.keys()
	keys.sort()
	result.scoreboards = [{"copy": keys[0], "item": "ST-090", "model": "electronic-v2",
		"site": StadiumScoreboardMountCatalog.CENTER_SITE,
		"mount_profile": StadiumScoreboardMountCatalog.CENTER_PROFILE}]
	return result


func _public_gates(season: SeasonState, layout: Dictionary) -> void:
	var before: Dictionary = _held_mounted(season)
	var revision: int = ClubPlayers.assets(season.career).revision()
	_check(not ClubConstruction.save_draft(season, layout, revision).ok,
		"normal Save Draft cannot admit mounted15 while its runtime gate is false")
	_check(not ClubConstruction.apply_draft(season, layout, revision).ok,
		"normal Apply cannot admit mounted15 while its runtime gate is false")
	_check(ClubCareer.same(before, _held_mounted(season)),
		"closed public draft/apply preserve journal, paid copies, wallet, home and both files")


func _stage_raw(season: SeasonState, layout: Dictionary) -> void:
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var before: Dictionary = _held_mounted(season)
	var commands: Array[Dictionary] = [{"id": "staged-mounted-draft", "rev": ledger.revision(),
		"op": "stadium_draft", "layout": layout},
		{"id": "staged-mounted-apply", "rev": ledger.revision() + 1,
			"op": "stadium_apply", "layout": layout,
			"geometry": StadiumMountedScoreboardLayout.geometry(ledger.view().land, layout)}]
	for command: Dictionary in commands:
		var held: Dictionary = _held_mounted(season)
		var path: String = SeasonSave.path
		SeasonSave.path = path + "/missing/file.json"
		var failed: Dictionary = ClubPlayers.transact(season, command)
		_check(not failed.ok and failed.error.contains("Could not save season"),
			"failed raw data-only journal write reaches persistence without publishing")
		SeasonSave.path = path
		_check(ClubCareer.same(held, _held_mounted(season)),
			"failed staged write leaves all owned data and primary/backup bytes exact")
		_check(ClubPlayers.transact(season, command).ok,
			"same exact raw data-only request succeeds after failed persistence")
		var committed: Dictionary = SeasonSave.snapshot(season)
		_check(ClubPlayers.transact(season, command).replayed
			and ClubCareer.same(committed, SeasonSave.snapshot(season)),
			"replayed staging never duplicates events, costs or ownership")
	ledger = ClubPlayers.assets(season.career)
	_check(ledger.view().stadium_active.version == 15
		and ledger.revision() == before.journal.events.size() + 2
		and ledger.balance() == before.view.balance
		and ClubCareer.same(ledger.construction().to_data(), before.stock)
		and ClubCareer.same(ledger.wall_pieces().to_data(), before.pieces)
		and ClubCareer.same(ledger.scoreboards().to_data(), before.boards)
		and ClubCareer.same(ledger.to_data().events.slice(0, before.journal.events.size()),
			before.journal.events),
		"raw mount configuration adds precisely two free events and no grant or changed history")


func _reject_home_profiles(season: SeasonState, declared: Dictionary) -> void:
	var before: Dictionary = _held_mounted(season)
	for profile: Dictionary in [declared, StadiumMountedScoreboardSnapshot.fixture(declared, 51, 0)]:
		var forged: Dictionary = before.snapshot.duplicate(true)
		forged.home_property = profile
		_check(SeasonSave._decode(forged) == null,
			"outer schema59 rejects entry14 and fixture15 as public home profiles")
		var candidate: SeasonState = SeasonSave._decode(before.snapshot)
		_check(candidate != null, "untampered staged season remains a valid save candidate")
		if candidate == null:
			continue
		candidate.home_property = profile.duplicate(true)
		_check(not SeasonSave.save(candidate) and ClubCareer.same(before, _held_mounted(season)),
			"rejected profile save cannot overwrite primary, backup, wallet or live season")


func _failed_purchase(season: SeasonState) -> void:
	var before: Dictionary = _held_mounted(season)
	var path: String = SeasonSave.path
	var revision: int = ClubPlayers.assets(season.career).revision()
	SeasonSave.path = path + "/missing/file.json"
	var failed: Dictionary = ClubConstruction.buy_scoreboard(season, "ST-090", 1, revision)
	_check(not failed.ok and failed.error.contains("Could not save season"),
		"existing paid purchase reaches the failed write with mounted data staged")
	SeasonSave.path = path
	_check(ClubCareer.same(before, _held_mounted(season)),
		"failed paid write never charges or grants an unused copy and preserves both files")


func _rejected_expansion(season: SeasonState) -> void:
	var before: Dictionary = _held_mounted(season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var quote: Dictionary = StadiumLand.quote(ledger.view().land, "expanded",
		StadiumCareerProgress.metrics(StadiumCareerProgress.capture(season.career),
			StadiumCareerProgress.capture(season.career).size()))
	_check(quote.ok and ledger.balance() >= quote.cost,
		"actual earned progress and remaining wallet qualify unchanged paid expansion")
	var expanded: Dictionary = ClubConstruction.buy_land(season, "expanded", ledger.revision())
	_check(not expanded.ok and expanded.error.contains("Expanded field unavailable")
		and ClubCareer.same(before, _held_mounted(season)),
		"paid land recapture guard preserves staged journal, frozen home, wallet and both files")


func _held_mounted(season: SeasonState) -> Dictionary:
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	return {"snapshot": SeasonSave.snapshot(season), "career": season.career.to_data(),
		"journal": ledger.to_data(), "view": ledger.view(), "stock": ledger.construction().to_data(),
		"pieces": ledger.wall_pieces().to_data(), "boards": ledger.scoreboards().to_data(),
		"home": season.home_property.duplicate(true),
		"primary": FileAccess.get_file_as_string(SeasonSave.path),
		"backup": FileAccess.get_file_as_string(SeasonSave.path + ".bak")}


func _admitted() -> void:
	var season: SeasonState = _fund_boards()
	var history: Array = season.career.runs.duplicate(true)
	_purchase_existing(season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var old: Dictionary = _old_layout(ledger)
	_check(ClubConstruction.save_draft(season, old, ledger.revision()).ok,
		"historical14 draft uses its original public workflow")
	_check(ClubConstruction.apply_draft(season, old,
		ClubPlayers.assets(season.career).revision()).ok, "historical14 Apply is unchanged")
	var app: SeasonApp = SeasonApp.new()
	add_child(app)
	await _frames()
	app.season = season
	app.begin_season(88, true, true, true)
	season = app.season
	_check(season.phase == SeasonState.Phase.DRAFT and season.home_property.get("version") == 12,
		"normal pre-draft owned season freezes the historical14 field before mounted replacement")
	var legacy: Dictionary = season.home_property.duplicate(true)
	ledger = ClubPlayers.assets(season.career)
	var layout: Dictionary = _mounted_layout(old, ledger)
	var held: Dictionary = _held_mounted(season)
	var revision: int = ledger.revision()
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/file.json"
	_check(not ClubConstruction.save_draft(season, layout, revision).ok,
		"mounted draft failure cannot publish its free configuration")
	SeasonSave.path = path
	_check(ClubCareer.same(held, _held_mounted(season)), "failed draft preserves both save files")
	_check(ClubConstruction.save_draft(season, layout, revision).ok,
		"normal mounted Save Draft succeeds after failed persistence")
	held = _held_mounted(season)
	SeasonSave.path = path + "/missing/file.json"
	_check(not ClubConstruction.apply_draft(season, layout, revision + 1).ok,
		"mounted Apply failure cannot replace the historical frozen home")
	SeasonSave.path = path
	_check(ClubCareer.same(held, _held_mounted(season)),
		"failed Apply preserves draft, wallet, all copies, old home and both files")
	_check(ClubConstruction.apply_draft(season, layout, revision + 1).ok,
		"normal mounted Apply succeeds after failed persistence")
	ledger = ClubPlayers.assets(season.career)
	var entry: Dictionary = season.home_property.duplicate(true)
	_check(entry.get("version") == 14 and entry.layout.version == 15
		and entry.layout.mount_catalog == 1 and StadiumLayoutSnapshot.matches(entry, ledger)
		and StadiumLayoutSnapshot.matches(legacy, ledger),
		"new entry14 and historical entry12 retain their exact paid-prefix identities")
	_check(ledger.revision() == revision + 2 and ledger.balance() == held.view.balance
		and ClubCareer.same(held.stock, ledger.construction().to_data())
		and ClubCareer.same(held.pieces, ledger.wall_pieces().to_data())
		and ClubCareer.same(held.boards, ledger.scoreboards().to_data()),
		"mount selection adds only two free events and leaves all three inventories exact")
	_check(SeasonSave.snapshot(season).version == 63 and SeasonSave.save(season),
		"current mounted entry retains NPC and neutral-final schema63")
	var restored: SeasonState = SeasonSave.restore()
	_check(restored != null and ClubCareer.same(SeasonSave.snapshot(restored),
		SeasonSave.snapshot(season)), "normal mounted field and unused copies reopen exactly")
	_legacy_mounted_save(season)
	_admitted_rejections(season, entry)
	_failed_purchase(season)
	_admitted_expansion(season)
	_check(ClubCareer.same(history, season.career.runs.slice(0, history.size())),
		"configuration and land recapture do not edit earned funding archives")
	app.season = season
	held = _held_mounted(season)
	for complete_boundary: bool in [true, false]:
		SeasonSave.path = path + "/missing/file.json"
		app.begin_season(89, true, true, true, complete_boundary)
		SeasonSave.path = path
		_check(app.season == season and ClubCareer.same(held, _held_mounted(season)),
			"failed or incomplete mounted season start preserves the complete saved career")
	app.begin_season(89, true, true, true, false)
	_check(app.season == season and ClubCareer.same(held, _held_mounted(season)),
		"incomplete-boundary startup rejects mounted15 even with a writable save destination")
	app.begin_season(89, true, true, true)
	_check(app.season != season and app.season.phase == SeasonState.Phase.DRAFT
		and app.season.home_property.get("version") == 14
		and StadiumLayoutSnapshot.matches(app.season.home_property,
			ClubPlayers.assets(app.season.career)),
		"ordinary owned-season start recaptures the paid mounted entry before drafting")
	var mounted_season: SeasonState = app.season
	held = _held_mounted(mounted_season)
	app.begin_season(90, true, true, false)
	_check(app.season != mounted_season and app.season.home_property.is_empty()
		and SeasonSave.snapshot(app.season).version == 58
		and ClubCareer.same(ClubPlayers.assets(app.season.career).to_data(), held.journal),
		"explicit historical no-home mode preserves mounted assets without a home declaration")
	app.queue_free()
	await _frames()


func _admitted_rejections(season: SeasonState, entry: Dictionary) -> void:
	var held: Dictionary = _held_mounted(season)
	var fixture: Dictionary = StadiumMountedScoreboardSnapshot.fixture(entry, 51, 0)
	var profiles: Array[Dictionary] = [fixture]
	for field: String in ["mount_catalog", "version", "geometry", "inventory",
		"wall_piece_inventory", "scoreboard_inventory"]:
		var bad: Dictionary = entry.duplicate(true)
		if field == "mount_catalog":
			bad.layout.mount_catalog = 2
		elif field == "version":
			bad.version = 12
		elif field == "geometry":
			bad.geometry = "forged"
		else:
			bad.erase(field)
		profiles.append(bad)
	for profile: Dictionary in profiles:
		var bad: Dictionary = held.snapshot.duplicate(true)
		bad.home_property = profile
		_check(SeasonSave._decode(bad) == null,
			"save59 refuses fixture-as-entry, future catalog, downgrade and missing paid inventory")
		var candidate: SeasonState = SeasonSave._decode(held.snapshot)
		_check(candidate != null, "untampered mounted save remains decodable")
		if candidate != null:
			candidate.home_property = profile.duplicate(true)
			_check(not SeasonSave.save(candidate) and ClubCareer.same(held, _held_mounted(season)),
				"invalid mounted profile preserves live season, primary and backup")
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var replay: Dictionary = ClubConstruction.save_draft(
		season, entry.layout, ledger.revision() - 2)
	_check(replay.ok and replay.replayed and ClubCareer.same(held, _held_mounted(season)),
		"identical committed draft replays without changing journal, field, wallet or either file")
	replay = ClubConstruction.apply_draft(season, entry.layout, ledger.revision() - 1)
	_check(replay.ok and replay.replayed and ClubCareer.same(held, _held_mounted(season)),
		"identical committed Apply replays without changing journal, field, wallet or either file")
	for change: String in ["revision", "future", "site", "copy"]:
		var layout: Dictionary = entry.layout.duplicate(true)
		var revision: int = ledger.revision()
		match change:
			"revision":
				revision -= 1
				# A valid changed proposal cannot use the previous Apply's idempotent replay.
				layout.scoreboards.clear()
			"future": layout.mount_catalog = 2
			"site": layout.scoreboards[0].site = "BOARD-FUTURE"
			"copy": layout.scoreboards[0].copy = "scoreboard:unpaid:0"
		_check(not ClubConstruction.save_draft(season, layout, revision).ok
			and ClubCareer.same(held, _held_mounted(season)),
			"invalid public mounted draft remains atomic: " + change)
		_check(not ClubConstruction.apply_draft(season, layout, revision).ok
			and ClubCareer.same(held, _held_mounted(season)),
			"invalid public mounted Apply remains atomic: " + change)


func _admitted_expansion(season: SeasonState) -> void:
	var held: Dictionary = _held_mounted(season)
	var ledger: ClubAssetLedger = ClubPlayers.assets(season.career)
	var progress: Array = StadiumCareerProgress.capture(season.career)
	var quote: Dictionary = StadiumLand.quote(ledger.view().land, "expanded",
		StadiumCareerProgress.metrics(progress, progress.size()))
	_check(quote.ok and ledger.balance() >= quote.cost, "earned paid land expansion remains eligible")
	var path: String = SeasonSave.path
	SeasonSave.path = path + "/missing/file.json"
	_check(not ClubConstruction.buy_land(season, "expanded", ledger.revision()).ok,
		"mounted land recapture can fail persistence safely")
	SeasonSave.path = path
	_check(ClubCareer.same(held, _held_mounted(season)),
		"failed mounted land recapture preserves paid assets and both save files")
	_check(ClubConstruction.buy_land(season, "expanded", ledger.revision()).ok,
		"normal Buy Land recaptures an admitted mounted field")
	var current: ClubAssetLedger = ClubPlayers.assets(season.career)
	_check(current.balance() == ledger.balance() - int(quote.cost)
		and season.home_property.tier == "expanded"
		and StadiumLayoutSnapshot.matches(season.home_property, current)
		and ClubCareer.same(held.stock, current.construction().to_data())
		and ClubCareer.same(held.pieces, current.wall_pieces().to_data())
		and ClubCareer.same(held.boards, current.scoreboards().to_data()),
		"land uses the unchanged paid cost and preserves every placed and stored copy")


func _legacy_mounted_save(season: SeasonState) -> void:
	var current: Dictionary = SeasonSave.snapshot(season)
	var legacy: Dictionary = current.duplicate(true)
	legacy.version = 59
	legacy.erase("npc_venues")
	legacy.erase("final_venue")
	var restored: SeasonState = SeasonSave._decode(
		JSON.parse_string(JSON.stringify(legacy, "", true, true)))
	_check(restored != null, "exact historical save59 mounted field remains readable")
	if restored != null:
		_check(ClubCareer.same(restored.home_property, season.home_property)
			and restored.npc_venues.is_empty() and restored.final_venue.is_empty()
			and ClubCareer.same(ClubPlayers.assets(restored.career).to_data(),
				ClubPlayers.assets(season.career).to_data()),
			"legacy59 preserves all paid and earned ownership without inventing venues")
	for field: String in ["npc_venues", "final_venue"]:
		var missing: Dictionary = current.duplicate(true)
		missing.erase(field)
		_check(SeasonSave._decode(missing) == null,
			"current mounted63 cannot omit frozen venue authority: " + field)
		var smuggled: Dictionary = legacy.duplicate(true)
		smuggled[field] = current[field].duplicate(true)
		_check(SeasonSave._decode(smuggled) == null,
			"historical mounted59 rejects later venue authority: " + field)

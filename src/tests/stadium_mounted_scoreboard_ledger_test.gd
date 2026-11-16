extends Node
## Ledger22 is a data envelope only; old journal and runtime identities remain frozen.

const Data = preload("res://src/tests/stadium_mounted_scoreboard_test_data.gd")
var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_historical_headers()
	_mount_journal()
	_rough_origin()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard ledger passed: ", _checks, " checks; immutable history.")
	get_tree().quit(0 if _failures == 0 else 1)


func _historical_headers() -> void:
	for version in range(1, 22):
		var ledger: ClubAssetLedger = ClubAssetLedger.new(Data.SEED, Data.credits(), Data.progress())
		var open: Dictionary = {"id": "old-pack", "rev": 0, "op": "player_pack_open",
			"through": 22, "price_version": ClubPlayerCatalog.PRICE_VERSION}
		_check(ledger.commit(open).ok, "paid history exists for every old header")
		if version >= 5:
			_check(ledger.commit(Data.buy(ledger, "stadium_buy", "ST-001", 1)).ok,
				"old paid standard copy")
		if version >= 18:
			_check(ledger.commit(Data.buy(ledger, "stadium_wall_piece", "ST-024-L", 1)).ok,
				"old paid exact wall copy")
		if version >= 20:
			_check(ledger.commit(Data.buy(ledger, "stadium_scoreboard", "ST-090", 1)).ok,
				"old paid electronic copy")
		if version == 21:
			var layout: Dictionary = StadiumScoreboardLayout.upgrade(
				StadiumAdvancedWallLayout.upgrade(StadiumSurfaceLayout.upgrade(
					StadiumStarterLayout.empty(), ledger.surface_owned())))
			_check(Data.apply(ledger, layout), "old layout14 remains exact")
		var frozen: Dictionary = StadiumLayoutSnapshot.capture(ledger)
		var frozen_key: String = StadiumLayoutSnapshot.key(frozen)
		var old: Dictionary = Data.historical(ledger.to_data(), version)
		var expected: Array = ["version", "seed", "catalog", "events"]
		for field: String in Data.HEADER_VERSIONS:
			if Data.HEADER_VERSIONS[field] <= version:
				expected.append(field)
		_check(SeasonOwnership._keys(old, expected), "exact old header field set %d" % version)
		var old_bytes: String = JSON.stringify(old, "", true, true)
		var loaded: ClubAssetLedger = Data.restore(old)
		_check(loaded != null, "old header loads %d" % version)
		if loaded == null:
			continue
		_check(ClubCareer.same(Data.state(loaded), Data.state(ledger))
			and ClubCareer.same(loaded.to_data().events, old.events),
			"migration only changes envelope, never paid history or state %d" % version)
		_check(ClubCareer.same(Data.historical(loaded.to_data(), version), old)
			and JSON.stringify(old, "", true, true) == old_bytes,
			"every historical catalog identity and input byte survives %d" % version)
		_check(StadiumLayoutSnapshot.matches(frozen, loaded)
			and StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.capture(loaded)) == frozen_key,
			"frozen old snapshot capture and prefix unchanged %d" % version)
		for field: String in expected:
			if field in ["version", "seed", "events", "surface_origin"]:
				continue
			var missing: Dictionary = old.duplicate(true)
			missing.erase(field)
			_check(Data.restore(missing) == null, "old required header never becomes optional")
		for field: String in ["pool_catalog", "pool_layout_catalog"]:
			var later: Dictionary = old.duplicate(true)
			later[field] = ledger.to_data()[field]
			_check(Data.restore(later) == null, "old envelope rejects later pool header " + field)
		var future: Dictionary = old.duplicate(true)
		future["mounted_scoreboard_layout_catalog"] = StadiumMountedScoreboardLayout.signature()
		_check(Data.restore(future) == null, "old envelope rejects the future mount header")
		var mounted: Dictionary = StadiumMountedScoreboardLayout.upgrade(
			StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
				StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned()))),
			ledger.construction(), ledger.wall_pieces(), ledger.surface_owned(), "backyard",
			ledger.scoreboards())
		for op: String in ["stadium_draft", "stadium_apply"]:
			var smuggled: Dictionary = old.duplicate(true)
			var event: Dictionary = {"id": "future-layout", "rev": ledger.revision(),
				"op": op, "layout": mounted}
			if op == "stadium_apply":
				event["geometry"] = StadiumMountedScoreboardLayout.geometry("backyard", mounted)
			smuggled.events.append(event)
			_check(Data.restore(smuggled) == null, "old1-21 reject layout15 draft/apply events")


func _mount_journal() -> void:
	var ledger: ClubAssetLedger = Data.fund()
	_check(ledger != null, "fund original inventories")
	if ledger == null:
		return
	var old_layout: Dictionary = Data.layout14(ledger)
	_check(Data.apply(ledger, old_layout), "apply old14 first")
	var frozen: Dictionary = StadiumScoreboardSnapshot.capture(ledger)
	var frozen_key: String = StadiumScoreboardSnapshot.key(frozen)
	var before: Dictionary = Data.state(ledger)
	var layout: Dictionary = Data.mounted(ledger)
	var command: Dictionary = {"id": "mounted-draft", "rev": ledger.revision(),
		"op": "stadium_draft", "layout": layout}
	var preview: Dictionary = ledger.preview(command)
	_check(preview.ok and preview.cost == 0 and ClubCareer.same(before, Data.state(ledger)),
		"mount draft preview is detached and free")
	if not preview.ok:
		return
	preview.event.layout.scoreboards.clear()
	_check(not layout.scoreboards.is_empty() and ClubCareer.same(before, Data.state(ledger)),
		"mutating preview cannot mutate command or ledger")
	_check(ledger.commit(command).ok and ledger.commit(command).replayed,
		"mount draft commits once and replay grants nothing")
	var apply: Dictionary = {"id": "mounted-apply", "rev": ledger.revision(),
		"op": "stadium_apply", "layout": layout,
		"geometry": StadiumMountedScoreboardLayout.geometry(ledger.view().land, layout)}
	var wrong: Dictionary = apply.duplicate(true)
	wrong.geometry = StadiumOwnedLayout.geometry(ledger.view().land, old_layout)
	var draft_state: Dictionary = Data.state(ledger)
	_check(not ledger.commit(wrong).ok and ClubCareer.same(draft_state, Data.state(ledger)),
		"apply rejects the old geometry without changing saved draft")
	_check(ledger.commit(apply).ok and ledger.commit(apply).replayed,
		"exact mounted draft applies idempotently")
	var after: Dictionary = Data.state(ledger)
	_check(after.view.balance == before.view.balance and after.view.spent == before.view.spent
		and ClubCareer.same(after.stock, before.stock) and ClubCareer.same(after.pieces, before.pieces)
		and ClubCareer.same(after.boards, before.boards),
		"mount selection adds no SKU, blueprint, grant, price or wallet change")
	_check(ClubCareer.same(ledger.to_data().events.slice(0, before.data.events.size()),
		before.data.events), "existing event bytes remain exact")
	_check(StadiumScoreboardSnapshot.key(frozen) == frozen_key
		and StadiumScoreboardSnapshot.matches(frozen, ledger),
		"old12 entry retains immutable original paid prefix")
	_check(StadiumLayoutSnapshot.capture(ledger).is_empty()
		== (not StadiumMountedScoreboardLayout.RUNTIME_READY)
		and StadiumScoreboardSnapshot.capture(ledger).is_empty(),
		"public capture follows explicit mounted readiness; prior snapshot family stays exact")
	var mounted_data: Dictionary = Data.historical(ledger.to_data(), 22)
	var loaded: ClubAssetLedger = Data.restore(mounted_data)
	_check(loaded != null and ClubCareer.same(Data.state(loaded), after),
		"ledger22 canonical JSON replay is exact")
	for value: Variant in [null, true, 1, "future", StadiumScoreboardLayout.signature()]:
		var bad: Dictionary = mounted_data.duplicate(true)
		bad.mounted_scoreboard_layout_catalog = value
		_check(Data.restore(bad) == null, "new mounted header requires exact string signature")
	var missing: Dictionary = mounted_data.duplicate(true)
	missing.erase("mounted_scoreboard_layout_catalog")
	_check(Data.restore(missing) == null, "ledger22 mounted header is mandatory")
	var future: Dictionary = ledger.to_data()
	future.version = ClubAssetLedger.WATERFALL_ANIMATION_VERSION + 1
	_check(Data.restore(future) == null, "unsupported future journal version stays closed")
	var incomplete_terrain: Dictionary = ledger.to_data()
	incomplete_terrain.version = 24
	_check(Data.restore(incomplete_terrain) == null,
		"ordinary23 cannot claim terrain24 without required header and history")
	_check(Data.restore(ledger.to_data()) != null, "current pool23 envelope remains valid")
	for field: String in ["pool_catalog", "pool_layout_catalog"]:
		var later: Dictionary = mounted_data.duplicate(true)
		later[field] = ledger.to_data()[field]
		_check(Data.restore(later) == null, "historical22 rejects later pool header " + field)
	for field: String in ["revision", "profile", "catalog", "extra", "id"]:
		var bad: Dictionary = {"id": "bad-" + field, "rev": ledger.revision(),
			"op": "stadium_draft", "layout": layout.duplicate(true)}
		match field:
			"revision": bad.rev -= 1
			"profile": bad.layout.scoreboards[0].mount_profile = "future"
			"catalog": bad.layout.mount_catalog = 2
			"extra": bad.layout["extra"] = 1
			"id": bad.id = command.id
		_check(not ledger.commit(bad).ok and ClubCareer.same(after, Data.state(ledger)),
			"bad draft rejects atomically: " + field)


func _rough_origin() -> void:
	# Historical pre-salvage rough family; never downgrade a current new club.
	var prior: Dictionary = Data.historical(
		ClubAssetLedger.new(Data.SEED, Data.credits(), Data.progress()).to_data(), 22)
	prior.surface_origin = StadiumSurfaceProgression.ROUGH_ORIGIN
	var ledger: ClubAssetLedger = Data.restore(prior)
	_check(ledger != null, "historical rough-origin ledger22 restores")
	if ledger == null:
		return
	_check(ledger.view().stadium_active.version == 12 and ledger.surface_owned().is_empty()
		and not ledger.to_data().has("salvage_origin"), "historical rough surface12 has no grants")
	var modern: ClubAssetLedger = ClubAssetLedger.new_club(
		Data.SEED, Data.credits(), Data.progress())
	var modern_before: Dictionary = modern.to_data()
	_check(modern.view().stadium_active.version == StadiumSalvageCarItems.LAYOUT_VERSION
		and StadiumAdvancedWallLayout.upgrade(modern.view().stadium_active).is_empty()
		and ClubCareer.same(modern_before, modern.to_data()),
		"current salvage remains unchanged and cannot be silently downgraded")
	var layout: Dictionary = StadiumMountedScoreboardLayout.upgrade(
		StadiumScoreboardLayout.upgrade(StadiumAdvancedWallLayout.upgrade(
			ledger.view().stadium_active)), ledger.construction(), ledger.wall_pieces(),
		ledger.surface_owned(), ledger.view().land, ledger.scoreboards())
	_check(Data.apply(ledger, layout), "rough-origin ledger15 retains explicit dirt")
	var frozen: Dictionary = StadiumMountedScoreboardSnapshot.capture(ledger)
	_check(not frozen.is_empty() and frozen.surface_access.is_empty(),
		"rough-origin pure snapshot never grants grass")
	var bad: Dictionary = layout.duplicate(true)
	bad.surface.foundation = "grass"
	bad.surface.height = "short"
	var before: Dictionary = Data.state(ledger)
	_check(not ledger.commit({"id": "free-grass", "rev": ledger.revision(),
		"op": "stadium_draft", "layout": bad}).ok
		and ClubCareer.same(before, Data.state(ledger)), "mounted grammar cannot bypass surface payment")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)

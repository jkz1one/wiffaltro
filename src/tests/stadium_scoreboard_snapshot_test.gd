extends Node
## Pure paid-prefix declarations and explicit production-family dispatch.

var _failures: int = 0
var _checks: int = 0
var _credits: Array = []
var _progress: Array = []


func _ready() -> void:
	for index in range(22):
		_credits.append(100000)
		_progress.append({"seasons": 1, "wins": 4})
	for shape: String in ["straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"]:
		_case(shape)
	_rough()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro scoreboard snapshot data passed: exact ownership and explicit dispatch."
		)
	print("SCOREBOARD_SNAPSHOT_RESULT ", JSON.stringify({"checks": _checks,
		"failures": _failures, "synthetic_fixtures": true}))
	get_tree().quit(0 if _failures == 0 else 1)


func _fund() -> ClubAssetLedger:
	var ledger: ClubAssetLedger = ClubAssetLedger.new(31, _credits, _progress)
	for tier: String in ["expanded", "club", "mogul"]:
		_check(
			(
				ledger
				. commit(
					{
						"id": "land-" + tier,
						"rev": ledger.revision(),
						"op": "stadium_land",
						"tier": tier,
						"through": 22,
						"progress_through": 22,
						"price_version": StadiumLand.VERSION
					}
				)
				. ok
			),
			"exact paid property upgrade"
		)
	_check(
		ledger.commit(_buy(ledger, "stadium_buy", "ST-024", 27, 8)).ok, "paid standard wall stock"
	)
	for item: String in ["ST-024-L", "ST-024-T"]:
		_check(
			ledger.commit(_buy(ledger, "stadium_wall_piece", item, 12)).ok,
			"paid exact wall variants"
		)
	for item: String in StadiumScoreboardCatalog.IDS:
		_check(
			ledger.commit(_buy(ledger, "stadium_scoreboard", item, 2)).ok,
			"paid board and unused copy"
		)
	return ledger


func _case(shape: String) -> void:
	var ledger: ClubAssetLedger = _fund()
	var old_snapshot: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var old_key: String = StadiumLayoutSnapshot.key(old_snapshot)
	var prior: Dictionary = _historical20(ledger)
	for field: String in ["pool_catalog", "pool_layout_catalog"]:
		var polluted: Dictionary = prior.duplicate(true)
		polluted[field] = ledger.to_data()[field]
		_check(_restore(polluted) == null, "ledger20 rejects later pool header: " + field)
	var migrated: ClubAssetLedger = _restore(prior)
	_check(
		(
			migrated != null
			and ClubCareer.same(migrated.view(), ledger.view())
			and ClubCareer.same(migrated.construction().to_data(), ledger.construction().to_data())
			and ClubCareer.same(migrated.wall_pieces().to_data(), ledger.wall_pieces().to_data())
			and ClubCareer.same(migrated.scoreboards().to_data(), ledger.scoreboards().to_data())
		),
		"populated ledger20 migrates without grants, charges or changed ownership/layout"
	)
	_check(
		StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.capture(migrated)) == old_key,
		"old frozen geometry/ownership keys survive migration"
	)
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned(), true)
		)
	)
	if shape in ["straight", "deeper_center"]:
		layout.walls = (
			StadiumWallLayout
			. propose(layout.walls, ledger.construction(), "back", "ST-024", shape)
			. walls
		)
	else:
		layout.advanced_back = (
			StadiumAdvancedWallManifest
			. suggest(shape, "ST-024", ledger.construction(), ledger.wall_pieces().stock)
			. manifest
		)
	layout.receiver = "starter-v1:ST-079"
	var stock: StadiumStock = ledger.construction()
	var manual: String = _copy(stock.copies, "ST-039")
	var video: String = _copy(stock.copies, "ST-040")
	var electronic: String = _copy(ledger.scoreboards().copies, "ST-090")
	layout.scoreboards = [
		{"copy": video, "item": "ST-040", "model": "video-v2", "site": "BOARD-LARGE-v2"}
	]
	if shape != "left_loft":
		layout.scoreboards.append(
			{"copy": manual, "item": "ST-039", "model": "manual-v2", "site": "BOARD-LEFT-v2"}
		)
	layout.scoreboards.append(
		{
			"copy": manual if shape == "left_loft" else electronic,
			"item": "ST-039" if shape == "left_loft" else "ST-090",
			"model": "manual-v2" if shape == "left_loft" else "electronic-v2",
			"site": "BOARD-RIGHT-v2"
		}
	)
	_apply(ledger, layout)
	var entry: Dictionary = StadiumScoreboardSnapshot.capture(ledger)
	var key: String = StadiumScoreboardSnapshot.key(entry)
	_check(
		not entry.is_empty() and StadiumScoreboardSnapshot.matches(entry, ledger),
		"all three inventories bind the exact active paid prefix"
	)
	var fixture: Dictionary = StadiumScoreboardSnapshot.fixture(entry, 47, 0)
	_check(
		(
			fixture.version == 13
			and fixture.environment.mode == "day"
			and StadiumScoreboardSnapshot.matches(fixture, ledger)
		),
		"bounded daylight fixture binds exact ownership"
	)
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(entry))
	_check(
		(
			StadiumScoreboardSnapshot.key(roundtrip) == key
			and StadiumScoreboardSnapshot.matches(roundtrip, ledger)
		),
		"JSON round-trip preserves canonical identity"
	)
	_check(
		(
			StadiumLayoutSnapshot.key(StadiumLayoutSnapshot.capture(ledger)) == key
			and StadiumAdvancedSnapshot.capture(ledger).is_empty()
			and StadiumLayoutSnapshot.valid(entry)
			and StadiumLayoutSnapshot.valid(fixture)
			and not StadiumAdvancedSnapshot.valid(entry)
		),
		"explicit production dispatch retains boards without admitting the older authoring family"
	)
	prior.events = ledger.to_data().events
	_check(_restore(prior) == null, "valid ledger20 header rejects newer layout14 events")
	var loaded: ClubAssetLedger = _restore(ledger.to_data())
	_check(
		loaded != null and StadiumScoreboardSnapshot.matches(entry, loaded),
		"ledger21 JSON replay is exact"
	)
	_check(
		ledger.commit(_buy(ledger, "stadium_scoreboard", "ST-090", 1)).ok,
		"later electronic purchase remains independently owned"
	)
	_check(
		(
			StadiumScoreboardSnapshot.matches(entry, ledger)
			and StadiumScoreboardSnapshot.key(entry) == key
			and StadiumLayoutSnapshot.matches(old_snapshot, ledger)
		),
		"later ownership never rewrites older prefixes"
	)
	_prefix_edges(entry, fixture, ledger)
	_tamper(entry, fixture, ledger)
	if shape == "straight":
		_capacity(entry)
		_canonical_boundaries(entry, fixture)


func _tamper(entry: Dictionary, fixture: Dictionary, ledger: ClubAssetLedger) -> void:
	for field: String in [
		"version",
		"revision",
		"geometry",
		"boundary",
		"tier",
		"extra",
		"missing",
		"model",
		"layout",
		"price",
		"blueprint"
	]:
		var bad: Dictionary = entry.duplicate(true)
		match field:
			"version":
				bad.version = true
			"revision":
				bad.revision = -1
			"geometry":
				bad.geometry = "forged"
			"boundary":
				bad.boundary = "forged"
			"tier":
				bad.tier = "club"
			"extra":
				bad["extra"] = 0
			"missing":
				bad.erase("scoreboard_inventory")
			"model":
				bad.layout.scoreboards[0].model = "manual-v2"
			"layout":
				bad.layout.version = 13
			"price":
				bad.scoreboard_inventory.copies[bad.scoreboard_inventory.copies.keys()[0]].paid = 0
			"blueprint":
				bad.scoreboard_inventory.blueprints = []
		_check(
			(
				not StadiumScoreboardSnapshot.valid(bad)
				and StadiumScoreboardSnapshot.normalized(bad).is_empty()
				and StadiumScoreboardSnapshot.fixture(bad, 47, 0).is_empty()
				and StadiumScoreboardSnapshot.key(bad).is_empty()
			),
			"every public snapshot boundary rejects: " + field
		)
	var forged: Dictionary = entry.duplicate(true)
	forged.scoreboard_inventory.copies["scoreboard:invented:0"] = {
		"item": "ST-090", "paid": 160, "source": "purchase-scoreboard-v1"
	}
	_check(
		(
			StadiumScoreboardSnapshot.valid(forged)
			and not StadiumScoreboardSnapshot.matches(forged, ledger)
		),
		"self-consistent unused electronic surplus is not paid ownership"
	)
	var detached: Dictionary = StadiumScoreboardSnapshot.normalized(entry)
	detached.scoreboard_inventory.copies.clear()
	_check(
		not entry.scoreboard_inventory.copies.is_empty(), "normalization returns detached ownership"
	)
	for field: String in ["mode", "profile", "seed", "fixture", "extra"]:
		var bad: Dictionary = fixture.duplicate(true)
		match field:
			"mode":
				bad.environment.mode = "night"
			"profile":
				bad.environment.profile = "unowned-lights"
			"seed":
				bad.environment.seed = -1
			"fixture":
				bad.environment.fixture = 33
			"extra":
				bad.environment["extra"] = 0
		_check(
			(
				not StadiumScoreboardSnapshot.valid(bad)
				and StadiumScoreboardSnapshot.normalized(bad).is_empty()
				and StadiumScoreboardSnapshot.key(bad).is_empty()
			),
			"invalid fixture environment rejects at public boundaries: " + field
		)
	_check(
		(
			StadiumScoreboardSnapshot.fixture(fixture, 47, 0).is_empty()
			and StadiumScoreboardSnapshot.fixture(entry, -1, 0).is_empty()
			and StadiumScoreboardSnapshot.fixture(entry, 2147483648, 0).is_empty()
			and StadiumScoreboardSnapshot.fixture(entry, 47, 33).is_empty()
		),
		"fixture conversion is bounded and entry-only"
	)
	for missing: bool in [true, false]:
		var bad: Dictionary = ledger.to_data()
		if missing:
			bad.erase("scoreboard_layout_catalog")
		else:
			bad.scoreboard_layout_catalog = "forged"
		_check(_restore(bad) == null, "current journal requires exact new layout contract")


func _canonical_boundaries(entry: Dictionary, fixture: Dictionary) -> void:
	var fields: Array = [
		"version", "tier", "revision", "geometry", "layout", "inventory",
		"wall_piece_inventory", "scoreboard_inventory", "surface_access", "boundary"
	]
	_check(SeasonOwnership._keys(entry, fields), "entry output keeps its exact public schema")
	fields.append("environment")
	_check(SeasonOwnership._keys(fixture, fields), "fixture output keeps its exact public schema")
	for value: Dictionary in [entry, fixture]:
		var canonical: String = JSON.stringify(value, "", true, true)
		var roundtrip: Dictionary = JSON.parse_string(canonical)
		_check(
			(
				JSON.stringify(StadiumScoreboardSnapshot.normalized(roundtrip), "", true, true)
				== canonical
				and StadiumScoreboardSnapshot.key(roundtrip) == canonical.sha256_text()
			),
			"JSON normalization retains exact canonical bytes and hash"
		)
	var roundtrip_entry: Dictionary = JSON.parse_string(JSON.stringify(entry))
	_check(
		JSON.stringify(StadiumScoreboardSnapshot.fixture(roundtrip_entry, 47, 0), "", true, true)
		== JSON.stringify(fixture, "", true, true),
		"fixture conversion preserves canonical output after JSON input"
	)
	var entry_before: String = JSON.stringify(entry, "", true, true)
	var fixture_before: String = JSON.stringify(fixture, "", true, true)
	var detached: Dictionary = StadiumScoreboardSnapshot.fixture(entry, 47, 0)
	detached.layout.scoreboards.clear()
	detached.inventory.copies.clear()
	detached.wall_piece_inventory.stock.copies.clear()
	detached.scoreboard_inventory.copies.clear()
	_check(
		(
			JSON.stringify(entry, "", true, true) == entry_before
			and JSON.stringify(fixture, "", true, true) == fixture_before
		),
		"fixture conversion does not alias source layout or any ownership inventory"
	)
	for bad: Variant in [null, true, [], 12]:
		_check(
			(
				not StadiumScoreboardSnapshot.valid(bad)
				and StadiumScoreboardSnapshot.normalized(bad).is_empty()
				and StadiumScoreboardSnapshot.fixture(bad, 47, 0).is_empty()
				and StadiumScoreboardSnapshot.key(bad).is_empty()
			),
			"public snapshot boundaries reject non-dictionaries without unchecked access"
		)


func _capacity(entry: Dictionary) -> void:
	var large: Dictionary = entry.duplicate(true)
	var count: int = (
		StadiumStock.MAX_COPIES
		- large.inventory.copies.size()
		- large.wall_piece_inventory.stock.copies.size()
		- large.scoreboard_inventory.copies.size()
	)
	for index in range(count):
		large.inventory.copies["purchase:synthetic:%d" % index] = {
			"item": "ST-001", "paid": 40, "source": "purchase-v1"
		}
	_check(StadiumScoreboardSnapshot.valid(large), "all inventories can total exactly4096 copies")
	large.inventory.copies["purchase:overflow:0"] = {
		"item": "ST-001", "paid": 40, "source": "purchase-v1"
	}
	_check(
		not StadiumScoreboardSnapshot.valid(large),
		"combined4097 cannot hide in unused stored copies"
	)


func _rough() -> void:
	# This scene tests the pre-salvage rough-origin family, not a new layout40 club.
	var prior: Dictionary = _historical20(ClubAssetLedger.new(31, _credits, _progress))
	prior.surface_origin = StadiumSurfaceProgression.ROUGH_ORIGIN
	var ledger: ClubAssetLedger = _restore(prior)
	_check(ledger != null, "exact historical rough-origin journal restores")
	if ledger == null:
		return
	_check(ledger.view().stadium_active.version == 12 and ledger.surface_owned().is_empty()
		and not ledger.to_data().has("salvage_origin"),
		"legacy rough fixture is surface12 without invented salvage origin")
	var modern: ClubAssetLedger = ClubAssetLedger.new_club(31, _credits, _progress)
	var modern_before: Dictionary = modern.to_data()
	_check(modern.view().stadium_active.version == StadiumSalvageCarItems.LAYOUT_VERSION
		and StadiumAdvancedWallLayout.upgrade(modern.view().stadium_active).is_empty()
		and ClubCareer.same(modern.to_data(), modern_before),
		"modern starter salvage cannot be implicitly downgraded by the old upgrade adapter")
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(
		StadiumAdvancedWallLayout.upgrade(ledger.view().stadium_active)
	)
	_apply(ledger, layout)
	var entry: Dictionary = StadiumScoreboardSnapshot.capture(ledger)
	_check(
		(
			StadiumScoreboardSnapshot.matches(entry, ledger)
			and entry.surface_access.is_empty()
			and entry.layout.surface.foundation == "dirt"
		),
		"rough-origin entry keeps explicit unowned grass state"
	)
	var bad: Dictionary = layout.duplicate(true)
	bad.surface.foundation = "grass"
	bad.surface.height = "short"
	var before: Dictionary = ledger.to_data()
	_check(
		(
			not (
				ledger
				. commit(
					{
						"id": "free-grass",
						"rev": ledger.revision(),
						"op": "stadium_draft",
						"layout": bad
					}
				)
				. ok
			)
			and ClubCareer.same(before, ledger.to_data())
		),
		"new family cannot grant unpaid grass"
	)
	_check(
		not (
			ledger
			. commit(
				{
					"id": "downgrade",
					"rev": ledger.revision(),
					"op": "stadium_draft",
					"layout": StadiumStarterLayout.empty()
				}
			)
			. ok
		),
		"rough-origin field cannot silently fall back to legacy grass"
	)
	for item: String in ["ground_prep", "grass"]:
		_check(
			(
				ledger
				. commit(
					{
						"id": item,
						"rev": ledger.revision(),
						"op": "stadium_surface",
						"through": 22,
						"price_version": 1,
						"item": item
					}
				)
				. ok
			),
			"explicit paid surface upgrade"
		)
	_check(
		StadiumScoreboardSnapshot.matches(entry, ledger),
		"later grass ownership preserves old dirt entry"
	)


func _apply(ledger: ClubAssetLedger, layout: Dictionary) -> void:
	var revision: int = ledger.revision()
	var draft: Dictionary = {
		"id": "draft%d" % revision, "rev": revision, "op": "stadium_draft", "layout": layout
	}
	_check(
		ledger.commit(draft).ok and ledger.commit(draft).replayed, "data-only draft is idempotent"
	)
	var apply: Dictionary = {
		"id": "apply%d" % revision,
		"rev": ledger.revision(),
		"op": "stadium_apply",
		"layout": layout,
		"geometry": StadiumOwnedLayout.geometry(ledger.view().land, layout)
	}
	_check(
		ledger.commit(apply).ok and ledger.commit(apply).replayed, "exact saved draft applies once"
	)


func _buy(
	ledger: ClubAssetLedger, op: String, item: String, quantity: int, price: int = 1
) -> Dictionary:
	return {
		"id": "buy%d" % ledger.revision(),
		"rev": ledger.revision(),
		"op": op,
		"item": item,
		"quantity": quantity,
		"through": 22,
		"progress_through": 22,
		"price_version": price
	}


func _copy(copies: Dictionary, item: String) -> String:
	for key: String in copies:
		if copies[key].item == item:
			return key
	return ""


func _restore(data: Dictionary) -> ClubAssetLedger:
	return ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(data)), 31, _credits, _progress
	)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error(message)


func _prefix_edges(entry: Dictionary, fixture: Dictionary, ledger: ClubAssetLedger) -> void:
	var stale: Dictionary = entry.duplicate(true)
	stale.revision -= 1
	_check(
		(
			StadiumScoreboardSnapshot.valid(stale)
			and not StadiumScoreboardSnapshot.matches(stale, ledger)
		),
		"identical owned inventories cannot authenticate the pre-apply active layout"
	)
	var future: Dictionary = entry.duplicate(true)
	future.revision = ledger.revision() + 1
	_check(
		(
			StadiumScoreboardSnapshot.valid(future)
			and not StadiumScoreboardSnapshot.matches(future, ledger)
		),
		"structurally valid future revision has no paid prefix"
	)
	for kind: String in ["standard", "pieces"]:
		var forged: Dictionary = entry.duplicate(true)
		if kind == "standard":
			forged.inventory.copies["purchase:invented:0"] = (
				forged.inventory.copies[_copy(forged.inventory.copies, "ST-039")].duplicate(true)
			)
		else:
			forged.wall_piece_inventory.stock.copies["wall-piece:invented:0"] = (
				forged.wall_piece_inventory.stock.copies.values()[0].duplicate(true)
			)
		_check(
			(
				StadiumScoreboardSnapshot.valid(forged)
				and not StadiumScoreboardSnapshot.matches(forged, ledger)
			),
			"unused surplus still requires its exact paid prefix: " + kind
		)
	for field: String in entry.keys():
		var missing: Dictionary = entry.duplicate(true)
		missing.erase(field)
		_rejected(missing, "required field missing: " + field)
	for field: String in ["inventory", "wall_piece_inventory", "scoreboard_inventory"]:
		for invalid: Variant in [null, [], {}, "invalid"]:
			var bad: Dictionary = entry.duplicate(true)
			bad[field] = invalid
			_rejected(bad, "invalid complete ownership: " + field)
	var overflow: Dictionary = entry.duplicate(true)
	overflow.revision = ClubAssetLedger.MAX_EVENTS + 1
	_rejected(overflow, "revision beyond journal capacity")
	var roundtrip: Dictionary = JSON.parse_string(JSON.stringify(fixture))
	_check(
		(
			StadiumScoreboardSnapshot.key(roundtrip) == StadiumScoreboardSnapshot.key(fixture)
			and StadiumScoreboardSnapshot.matches(roundtrip, ledger)
		),
		"fixture JSON canonicalizes numeric environment and exact ownership"
	)
	var normalized: Dictionary = StadiumScoreboardSnapshot.normalized(roundtrip)
	for field: String in ["version", "seed", "fixture"]:
		_check(normalized.environment[field] is int, "fixture environment integers normalize")


func _rejected(value: Variant, label: String) -> void:
	_check(
		(
			not StadiumScoreboardSnapshot.valid(value)
			and StadiumScoreboardSnapshot.normalized(value).is_empty()
			and StadiumScoreboardSnapshot.key(value).is_empty()
		),
		label
	)


func _historical20(ledger: ClubAssetLedger) -> Dictionary:
	# Explicit historical header; keep all paid events and pre-21 catalog seals.
	var result: Dictionary = ledger.to_data()
	result.version = 20
	for field: String in ["scoreboard_layout_catalog", "mounted_scoreboard_layout_catalog",
		"pool_catalog", "pool_layout_catalog"]:
		result.erase(field)
	return result

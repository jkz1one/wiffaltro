extends Node
## Pure entry14/fixture15 adapters bind all owned copies to the immutable paid prefix.

const Data = preload("res://src/tests/stadium_mounted_scoreboard_test_data.gd")
var _failures: int = 0


func _ready() -> void:
	for shape: String in ["straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"]:
		_case(shape)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro mounted scoreboard snapshots passed: exact entry14/fixture15 paid prefixes.")
	get_tree().quit(0 if _failures == 0 else 1)


func _case(shape: String) -> void:
	var ledger: ClubAssetLedger = Data.fund()
	_check(ledger != null, "fund all three existing inventory types")
	if ledger == null:
		return
	var old_layout: Dictionary = Data.layout14(ledger, shape)
	_check(Data.apply(ledger, old_layout), "old layout14 applies before mount: " + shape)
	var old_entry: Dictionary = StadiumScoreboardSnapshot.capture(ledger)
	var old_key: String = StadiumScoreboardSnapshot.key(old_entry)
	var layout: Dictionary = Data.mounted(ledger, shape)
	_check(Data.apply(ledger, layout), "exact mounted layout15 applies: " + shape)
	var entry: Dictionary = StadiumMountedScoreboardSnapshot.capture(ledger)
	_check(not entry.is_empty(), "mounted capture requires exact active15: " + shape)
	if entry.is_empty():
		return
	var fixture: Dictionary = StadiumMountedScoreboardSnapshot.fixture(entry, 47, 0)
	var key: String = StadiumMountedScoreboardSnapshot.key(entry)
	_check(entry.version == 14 and entry.layout.version == 15 and entry.layout.mount_catalog == 1
		and StadiumMountedScoreboardSnapshot.matches(entry, ledger),
		"entry14 binds mount catalog1 and complete paid ownership")
	_check(fixture.version == 15 and fixture.environment == {"version": 1,
		"seed": 47, "fixture": 0, "mode": "day", "profile": ""}
		and StadiumMountedScoreboardSnapshot.matches(fixture, ledger),
		"fixture15 adds only exact day-only environment1")
	_check(StadiumScoreboardSnapshot.key(old_entry) == old_key
		and StadiumScoreboardSnapshot.matches(old_entry, ledger),
		"mount activation preserves older entry12 bytes and prefix")
	_check(not StadiumScoreboardSnapshot.valid(entry) and not StadiumScoreboardSnapshot.valid(fixture)
		and not StadiumMountedScoreboardSnapshot.valid(old_entry)
		and not StadiumMountedScoreboardSnapshot.valid(
			StadiumScoreboardSnapshot.fixture(old_entry, 47, 0))
		and StadiumScoreboardSnapshot.capture(ledger).is_empty(),
		"old12/13 and new14/15 snapshot helpers remain exact and disjoint")
	_check(StadiumMountedScoreboardLayout.RUNTIME_READY
		and ClubCareer.same(StadiumLayoutSnapshot.capture(ledger), entry)
		and StadiumLayoutSnapshot.valid(entry, ledger.construction())
		and StadiumLayoutSnapshot.valid(fixture, ledger.construction())
		and StadiumLayoutSnapshot.matches(entry, ledger)
		and StadiumLayoutSnapshot.matches(fixture, ledger)
		and StadiumLayoutSnapshot.key(entry) == key
		and StadiumLayoutSnapshot.capture(ledger, false).is_empty(),
		"public entry14/fixture15 dispatch binds complete paid production ownership")
	_check(StadiumLayoutSnapshot.key(old_entry) == old_key
		and StadiumLayoutSnapshot.matches(old_entry, ledger),
		"public production dispatch preserves historical12 canonical bytes and paid prefix")
	var loaded: ClubAssetLedger = Data.restore(ledger.to_data())
	_check(loaded != null and StadiumMountedScoreboardSnapshot.matches(entry, loaded)
		and StadiumMountedScoreboardSnapshot.key(StadiumMountedScoreboardSnapshot.capture(loaded)) == key,
		"ledger22 and new snapshot JSON replay preserve canonical identities")
	_check(ledger.commit(Data.buy(ledger, "stadium_scoreboard", "ST-090", 1)).ok,
		"later unused electronic copy is independently paid")
	_check(StadiumMountedScoreboardSnapshot.matches(entry, ledger)
		and StadiumMountedScoreboardSnapshot.matches(fixture, ledger)
		and StadiumMountedScoreboardSnapshot.key(entry) == key,
		"later purchases cannot rewrite frozen full ownership prefixes")
	_prefix_edges(entry, ledger)
	_canonical(entry, fixture)
	if shape == "straight":
		_rejections(entry, fixture, ledger)
		_unused_copies(entry, ledger)
		_capacity(entry, ledger)


func _canonical(entry: Dictionary, fixture: Dictionary) -> void:
	var fields: Array = ["version", "tier", "revision", "geometry", "layout", "inventory",
		"wall_piece_inventory", "scoreboard_inventory", "surface_access", "boundary"]
	_check(SeasonOwnership._keys(entry, fields), "entry output exact field set")
	fields.append("environment")
	_check(SeasonOwnership._keys(fixture, fields), "fixture output exact field set")
	for value: Dictionary in [entry, fixture]:
		var bytes: String = JSON.stringify(value, "", true, true)
		var parsed: Dictionary = JSON.parse_string(bytes)
		var normalized: Dictionary = StadiumMountedScoreboardSnapshot.normalized(parsed)
		_check(JSON.stringify(normalized, "", true, true) == bytes
			and ClubCareer.same(StadiumLayoutSnapshot.normalized(parsed), normalized)
			and StadiumLayoutSnapshot.key(parsed) == bytes.sha256_text()
			and StadiumMountedScoreboardSnapshot.key(parsed) == bytes.sha256_text(),
			"canonical JSON bytes and sha256 survive numeric JSON normalization")
		_check(normalized.version is int and normalized.revision is int
			and normalized.layout.version is int and normalized.layout.mount_catalog is int,
			"all schema counters normalize to exact integers")
		for inventory: Dictionary in [normalized.inventory, normalized.wall_piece_inventory.stock,
			normalized.scoreboard_inventory]:
			_check(inventory.version is int, "inventory version normalizes to integer")
			for copy: Dictionary in inventory.copies.values():
				_check(copy.paid is int, "every paid receipt normalizes to integer")
		var reversed: Dictionary = {}
		var keys: Array = parsed.keys()
		keys.reverse()
		for field: String in keys:
			reversed[field] = parsed[field]
		_check(StadiumMountedScoreboardSnapshot.key(reversed) == bytes.sha256_text(),
			"dictionary insertion order does not alter canonical hash")
	var original: String = JSON.stringify(entry, "", true, true)
	var detached: Dictionary = StadiumMountedScoreboardSnapshot.normalized(entry)
	var converted: Dictionary = StadiumMountedScoreboardSnapshot.fixture(entry, 47, 0)
	for value: Dictionary in [detached, converted]:
		value.layout.scoreboards.clear()
		value.inventory.copies.clear()
		value.wall_piece_inventory.stock.copies.clear()
		value.scoreboard_inventory.copies.clear()
		value.surface_access.clear()
	_check(JSON.stringify(entry, "", true, true) == original,
		"normalization and fixture outputs never alias input or one another")
	_check(JSON.stringify(StadiumMountedScoreboardSnapshot.fixture(
		JSON.parse_string(original), 47, 0), "", true, true) == JSON.stringify(fixture, "", true, true),
		"fixture conversion reuses same-call validated context and canonicalizes JSON input")
	var owners: Dictionary = StadiumMountedScoreboardSnapshot.ownership(entry)
	owners.stock.copies.clear()
	owners.pieces.stock.copies.clear()
	owners.boards.copies.clear()
	_check(JSON.stringify(entry, "", true, true) == original, "returned owner objects are detached")


func _rejections(entry: Dictionary, fixture: Dictionary, ledger: ClubAssetLedger) -> void:
	for field: String in ["version", "future", "revision", "geometry", "boundary", "tier",
		"missing", "extra", "layout_version", "family", "catalog", "catalog_type", "layout_extra",
		"profile", "profile_type", "site", "model", "copy", "item", "row_extra", "duplicate_site",
		"duplicate_copy", "surface", "inventory", "piece_inventory", "scoreboard_inventory",
		"price", "blueprint", "old_pair"]:
		var bad: Dictionary = entry.duplicate(true)
		match field:
			"version": bad.version = true
			"future": bad.version = 16
			"revision": bad.revision = 1.5
			"geometry": bad.geometry = "forged"
			"boundary": bad.boundary = "forged"
			"tier": bad.tier = "club"
			"missing": bad.erase("scoreboard_inventory")
			"extra": bad["extra"] = 1
			"layout_version": bad.layout.version = 14
			"family": bad.layout.family = StadiumScoreboardLayout.FAMILY
			"catalog": bad.layout.mount_catalog = 2
			"catalog_type": bad.layout.mount_catalog = true
			"layout_extra": bad.layout["extra"] = 1
			"profile": bad.layout.scoreboards[0].mount_profile = ""
			"profile_type": bad.layout.scoreboards[0].mount_profile = 1
			"site": bad.layout.scoreboards[0].site = "BOARD-RIGHT-v2"
			"model": bad.layout.scoreboards[0].model = "manual-v2"
			"copy": bad.layout.scoreboards[0].copy = "scoreboard:invented:0"
			"item": bad.layout.scoreboards[0].item = "ST-039"
			"row_extra": bad.layout.scoreboards[0]["lift"] = 2.0
			"duplicate_site": bad.layout.scoreboards.append(bad.layout.scoreboards[0].duplicate(true))
			"duplicate_copy":
				var duplicate: Dictionary = bad.layout.scoreboards[0].duplicate(true)
				duplicate.site = "BOARD-RIGHT-v2"
				duplicate.mount_profile = ""
				bad.layout.scoreboards.append(duplicate)
			"surface": bad.surface_access = []
			"inventory": bad.inventory.version = true
			"piece_inventory": bad.wall_piece_inventory["extra"] = 0
			"scoreboard_inventory": bad.scoreboard_inventory.version = 2
			"price": bad.scoreboard_inventory.copies.values()[0].paid = 0
			"blueprint": bad.scoreboard_inventory.blueprints = []
			"old_pair": bad.version = 12
		_reject(bad, ledger, "invalid entry rejects at every pure public boundary: " + field)
	for value: Variant in [null, true, [], "14", 14, 14.5]:
		_reject(value, ledger, "non-dictionary snapshot rejects without unchecked access")
	for field: String in ["version", "mode", "profile", "seed", "seed_type", "fixture", "extra",
		"missing", "entry_pair", "layout_pair"]:
		var bad: Dictionary = fixture.duplicate(true)
		match field:
			"version": bad.environment.version = 2
			"mode": bad.environment.mode = "night"
			"profile": bad.environment.profile = "CENTER-ELECTRONIC-RAISED-v1"
			"seed": bad.environment.seed = 2147483648
			"seed_type": bad.environment.seed = true
			"fixture": bad.environment.fixture = 33
			"extra": bad.environment["extra"] = 0
			"missing": bad.erase("environment")
			"entry_pair": bad.version = 14
			"layout_pair": bad.layout.version = 14
		_reject(bad, ledger, "invalid fixture rejects at every pure public boundary: " + field)
	_check(StadiumMountedScoreboardSnapshot.fixture(fixture, 47, 0).is_empty()
		and StadiumMountedScoreboardSnapshot.fixture(entry, -1, 0).is_empty()
		and StadiumMountedScoreboardSnapshot.fixture(entry, 2147483648, 0).is_empty()
		and StadiumMountedScoreboardSnapshot.fixture(entry, 47, -1).is_empty()
		and StadiumMountedScoreboardSnapshot.fixture(entry, 47, 33).is_empty(),
		"entry-only fixture conversion rejects out-of-range context")
	_check(StadiumMountedScoreboardSnapshot.valid(StadiumMountedScoreboardSnapshot.fixture(
		entry, 2147483647, 32)), "maximum fixture context remains valid")
	var valid_again: Dictionary = entry.duplicate(true)
	_check(StadiumMountedScoreboardSnapshot.valid(valid_again), "initial value valid")
	valid_again.layout.mount_catalog = 2
	_reject(valid_again, ledger, "no mutable cross-call validation cache can hide later edits")


func _unused_copies(entry: Dictionary, ledger: ClubAssetLedger) -> void:
	var inventories: Array = ["inventory", "wall_piece_inventory", "scoreboard_inventory"]
	for kind: String in inventories:
		var bad: Dictionary = entry.duplicate(true)
		var copies: Dictionary = bad[kind].stock.copies if kind == "wall_piece_inventory" \
			else bad[kind].copies
		var key: String = Data.copy_id(copies, "ST-039") if kind == "inventory" \
			else copies.keys()[-1]
		var unused: Dictionary = copies[key].duplicate(true)
		copies.erase(key)
		_check(StadiumMountedScoreboardSnapshot.valid(bad)
			and not StadiumMountedScoreboardSnapshot.matches(bad, ledger)
			and not StadiumLayoutSnapshot.matches(bad, ledger),
			"missing unused copy still fails full paid prefix: " + kind)
		bad = entry.duplicate(true)
		copies = bad[kind].stock.copies if kind == "wall_piece_inventory" else bad[kind].copies
		var invented: String = "wall-piece:invented:0" if kind == "wall_piece_inventory" \
			else "purchase:invented:0" if kind == "inventory" else "scoreboard:invented:0"
		copies[invented] = unused
		_check(StadiumMountedScoreboardSnapshot.valid(bad)
			and not StadiumMountedScoreboardSnapshot.matches(bad, ledger)
			and not StadiumLayoutSnapshot.matches(bad, ledger),
			"invented unused copy is not paid ownership: " + kind)
		bad = entry.duplicate(true)
		copies = bad[kind].stock.copies if kind == "wall_piece_inventory" else bad[kind].copies
		var receipt: Dictionary = copies[key].duplicate(true)
		copies.erase(key)
		copies[invented] = receipt
		_check(StadiumMountedScoreboardSnapshot.valid(bad)
			and not StadiumMountedScoreboardSnapshot.matches(bad, ledger)
			and not StadiumLayoutSnapshot.matches(bad, ledger),
			"changed unused copy ID fails paid prefix despite same count/price: " + kind)


func _prefix_edges(entry: Dictionary, ledger: ClubAssetLedger) -> void:
	var stale: Dictionary = entry.duplicate(true)
	stale.revision -= 1
	_check(StadiumMountedScoreboardSnapshot.valid(stale)
		and not StadiumMountedScoreboardSnapshot.matches(stale, ledger)
		and not StadiumLayoutSnapshot.matches(stale, ledger),
		"draft revision cannot authenticate the later active mount")
	var future: Dictionary = entry.duplicate(true)
	future.revision = ledger.revision() + 1
	_check(StadiumMountedScoreboardSnapshot.valid(future)
		and not StadiumMountedScoreboardSnapshot.matches(future, ledger)
		and not StadiumLayoutSnapshot.matches(future, ledger),
		"future revision has no paid ledger prefix")
	var later: Dictionary = entry.duplicate(true)
	later.revision = ledger.revision()
	_check(StadiumMountedScoreboardSnapshot.valid(later)
		and not StadiumMountedScoreboardSnapshot.matches(later, ledger)
		and not StadiumLayoutSnapshot.matches(later, ledger),
		"same geometry at later revision cannot omit later unused copies")
	_check(not StadiumMountedScoreboardSnapshot.matches(entry, null),
		"null ledger cannot authenticate")


func _capacity(entry: Dictionary, ledger: ClubAssetLedger) -> void:
	var full: Dictionary = entry.duplicate(true)
	var count: int = StadiumStock.MAX_COPIES - full.inventory.copies.size() \
		- full.wall_piece_inventory.stock.copies.size() - full.scoreboard_inventory.copies.size()
	for index in range(count):
		full.inventory.copies["purchase:capacity:%d" % index] = {
			"item": "ST-001", "paid": 40, "source": "purchase-v1"}
	_check(StadiumMountedScoreboardSnapshot.valid(full)
		and not StadiumMountedScoreboardSnapshot.matches(full, ledger),
		"all three inventories can total4096 but still need exact paid receipts")
	for kind: String in ["standard", "pieces", "boards"]:
		var overflow: Dictionary = full.duplicate(true)
		if kind == "standard":
			overflow.inventory.copies["purchase:overflow:0"] = {
				"item": "ST-001", "paid": 40, "source": "purchase-v1"}
		elif kind == "pieces":
			overflow.wall_piece_inventory.stock.copies["wall-piece:overflow:0"] = \
				overflow.wall_piece_inventory.stock.copies.values()[0].duplicate(true)
		else:
			overflow.scoreboard_inventory.copies["scoreboard:overflow:0"] = \
				overflow.scoreboard_inventory.copies.values()[0].duplicate(true)
		_reject(overflow, ledger, "combined4097 rejects in every inventory direction: " + kind)


func _reject(value: Variant, ledger: ClubAssetLedger, message: String) -> void:
	_check(not StadiumMountedScoreboardSnapshot.valid(value)
		and StadiumMountedScoreboardSnapshot.normalized(value).is_empty()
		and StadiumMountedScoreboardSnapshot.fixture(value, 47, 0).is_empty()
		and StadiumMountedScoreboardSnapshot.key(value).is_empty()
		and not StadiumMountedScoreboardSnapshot.matches(value, ledger)
		and not StadiumLayoutSnapshot.valid(value), message)
	if value is Dictionary:
		_check(StadiumLayoutSnapshot.normalized(value).is_empty()
			and StadiumLayoutSnapshot.key(value).is_empty()
			and not StadiumLayoutSnapshot.matches(value, ledger),
			"public snapshot boundary also rejects: " + message)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

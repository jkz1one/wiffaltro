extends Node
## Exact journal-prefix qualification. Production fixture activation remains gated.

var _failures: int = 0


func _ready() -> void:
	_rough_origin()
	for material: String in StadiumWallRecipes.BACK_IDS:
		_material(material)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro advanced snapshot data passed: bounded declarations, canonical keys and closed gates."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _material(material: String) -> void:
	var credits: Array = []
	var progress: Array = []
	for index in range(20):
		credits.append(1000)
		progress.append({"seasons": 1, "wins": 4})
	var ledger: ClubAssetLedger = ClubAssetLedger.new(17, credits, progress)
	_check(
		(
			ledger
			. commit(
				{
					"id": "back",
					"rev": 0,
					"op": "stadium_buy",
					"through": 20,
					"progress_through": 20,
					"price_version": 8,
					"item": material,
					"quantity": 27
				}
			)
			. ok
		),
		"standard owned back purchases from real journal"
	)
	for height: String in ["low", "tall"]:
		_check(
			(
				ledger
				. commit(
					{
						"id": height,
						"rev": ledger.revision(),
						"op": "stadium_wall_piece",
						"through": 20,
						"progress_through": 20,
						"price_version": 1,
						"item": StadiumWallPieceCatalog.identity(material, height),
						"quantity": 12
					}
				)
				. ok
			),
			"exact variant ownership comes from same journal"
		)
	_headers(ledger, credits, progress)
	var old: Dictionary = StadiumLayoutSnapshot.capture(ledger)
	var old_key: String = StadiumLayoutSnapshot.key(old)
	var stock: StadiumStock = ledger.construction()
	var pieces: StadiumWallPieceOwnership = ledger.wall_pieces()
	for shape: String in ["", "left_loft", "right_shelf", "offset_gables", "deeper_center"]:
		stock = ledger.construction()
		pieces = ledger.wall_pieces()
		var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
			StadiumSurfaceLayout.upgrade(StadiumStarterLayout.empty(), ledger.surface_owned(), true)
		)
		if shape == "deeper_center":
			layout.walls = (
				StadiumWallLayout.propose(layout.walls, stock, "back", material, shape).walls
			)
		elif not shape.is_empty():
			layout.advanced_back = (
				StadiumAdvancedWallManifest.suggest(shape, material, stock, pieces.stock).manifest
			)
		var proposed: Dictionary = {
			"version": 10,
			"tier": "backyard",
			"revision": ledger.revision(),
			"geometry": StadiumOwnedLayout.geometry("backyard", layout),
			"layout": layout,
			"inventory": stock.to_data(),
			"wall_piece_inventory": pieces.to_data(),
			"surface_access": ledger.surface_owned(),
			"boundary": StadiumOwnedLayout.boundary_signature(layout)
		}
		_check(StadiumAdvancedSnapshot.valid(proposed), "bounded exact proposal declaration")
		var key: String = StadiumAdvancedSnapshot.key(proposed)
		var decoded: Variant = JSON.parse_string(JSON.stringify(proposed))
		_check(
			StadiumAdvancedSnapshot.valid(decoded) and StadiumAdvancedSnapshot.key(decoded) == key,
			"JSON numeric conversion preserves canonical data identity"
		)
		_check(
			not StadiumAdvancedSnapshot.matches(proposed, ledger),
			"owned proposed geometry is not a saved active field"
		)
		_check(
			not StadiumLayoutSnapshot.valid(proposed) and not StadiumLayoutSnapshot.valid(decoded),
			"production snapshot dispatcher stays closed to staged family"
		)
		var fixture: Dictionary = StadiumAdvancedSnapshot.fixture(proposed, 51, 0)
		_check(
			(
				fixture.version == 11
				and fixture.environment.mode == "day"
				and fixture.environment.profile.is_empty()
				and StadiumAdvancedSnapshot.valid(fixture)
			),
			"explicit candidate fixture freezes only verified daylight"
		)
		_check(
			(
				StadiumAdvancedSnapshot.key(proposed) == key
				and StadiumAdvancedSnapshot.key(fixture) != key
			),
			"fixture conversion is detached"
		)
		_check(
			(
				StadiumAdvancedSnapshot.fixture(proposed, -1, 0).is_empty()
				and StadiumAdvancedSnapshot.fixture(proposed, 1, 33).is_empty()
				and StadiumAdvancedSnapshot.fixture(fixture, 2, 0).is_empty()
			),
			"bad seed/index and double fixture conversion reject"
		)
		_tampering(proposed, fixture)
		var normalized: Dictionary = StadiumAdvancedSnapshot.normalized(decoded)
		normalized.wall_piece_inventory.stock.copies.clear()
		_check(
			(
				StadiumAdvancedSnapshot.key(proposed) == key
				and ClubCareer.same(pieces.to_data(), ledger.wall_pieces().to_data())
			),
			"returned data is detached from proposal and original ownership"
		)
		_paid_prefix(proposed, ledger, credits, progress)
	_check(
		StadiumLayoutSnapshot.matches(old, ledger) and StadiumLayoutSnapshot.key(old) == old_key,
		"older field identity and paid-prefix matching remain unchanged"
	)


func _tampering(proposed: Dictionary, fixture: Dictionary) -> void:
	for row: Array in [
		["version", true],
		["version", 9],
		["revision", -1],
		["revision", 4097],
		["geometry", "invented"],
		["boundary", "invented"],
		["tier", "unknown"],
		["surface_access", []],
		["wall_piece_inventory", {}],
		["inventory", {}]
	]:
		var bad: Dictionary = proposed.duplicate(true)
		bad[row[0]] = row[1]
		_check(
			not StadiumAdvancedSnapshot.valid(bad) and StadiumAdvancedSnapshot.key(bad).is_empty(),
			"malformed or inconsistent declaration rejected: " + row[0]
		)
	for field: String in proposed.keys():
		var bad: Dictionary = proposed.duplicate(true)
		bad.erase(field)
		_check(not StadiumAdvancedSnapshot.valid(bad), "missing exact field rejects")
	var bad: Dictionary = proposed.duplicate(true)
	bad["unknown"] = true
	_check(not StadiumAdvancedSnapshot.valid(bad), "extra field rejects")
	for row: Array in [
		["mode", "night"], ["profile", "yard-four"], ["seed", true], ["fixture", -1]
	]:
		bad = fixture.duplicate(true)
		bad.environment[row[0]] = row[1]
		_check(not StadiumAdvancedSnapshot.valid(bad), "invalid fixture environment rejects")
	bad = proposed.duplicate(true)
	var copy: String = bad.wall_piece_inventory.stock.copies.keys()[0]
	bad.wall_piece_inventory.stock.copies[copy].paid = 0
	_check(not StadiumAdvancedSnapshot.valid(bad), "piece price provenance rejects")
	bad = proposed.duplicate(true)
	bad.wall_piece_inventory.blueprints.clear()
	_check(not StadiumAdvancedSnapshot.valid(bad), "owned pieces cannot lose their exact blueprint")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _paid_prefix(
	proposed: Dictionary, ledger: ClubAssetLedger, credits: Array, progress: Array
) -> void:
	var revision: int = ledger.revision()
	var draft: Dictionary = {
		"id": "draft%d" % revision,
		"rev": revision,
		"op": "stadium_draft",
		"layout": proposed.layout
	}
	_check(ledger.commit(draft).ok, "exact owned advanced declaration can be journaled")
	var apply: Dictionary = {
		"id": "apply%d" % revision,
		"rev": revision + 1,
		"op": "stadium_apply",
		"layout": proposed.layout,
		"geometry": proposed.geometry
	}
	_check(
		ledger.commit(apply).ok and ledger.commit(apply).replayed,
		"exact saved draft applies once to the data journal"
	)
	var held: Dictionary = StadiumAdvancedSnapshot.capture(ledger)
	var held_key: String = StadiumAdvancedSnapshot.key(held)
	_check(
		not held.is_empty() and StadiumAdvancedSnapshot.matches(held, ledger),
		"frozen declarations bind all inventories to actual active paid prefix"
	)
	var decoded: Variant = JSON.parse_string(JSON.stringify(held))
	_check(
		(
			StadiumAdvancedSnapshot.matches(decoded, ledger)
			and StadiumAdvancedSnapshot.key(decoded) == held_key
		),
		"paid prefix accepts canonical JSON round trip"
	)
	_check(
		StadiumLayoutSnapshot.capture(ledger).is_empty() and not StadiumLayoutSnapshot.valid(held),
		"data journal does not activate production capture"
	)
	var old: Dictionary = ledger.to_data()
	old.version = 18
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	for key: String in ["pool_catalog", "pool_layout_catalog"]:
		var smuggled: Dictionary = old.duplicate(true)
		smuggled[key] = ledger.to_data()[key]
		_check(ClubAssetLedger.from_data(smuggled, 17, credits, progress) == null,
			"ledger18 refuses later pool declarations")
	_check(
		ClubAssetLedger.from_data(old, 17, credits, progress) == null,
		"old ledger header cannot smuggle advanced layouts"
	)
	var loaded: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(ledger.to_data())), 17, credits, progress
	)
	_check(
		loaded != null and StadiumAdvancedSnapshot.matches(held, loaded),
		"ledger19 replays exact active layout and frozen ownership"
	)
	var forged: Dictionary = held.duplicate(true)
	var item: Dictionary = forged.wall_piece_inventory.stock.copies.values()[0]
	forged.wall_piece_inventory.stock.copies["wall-piece:forged:0"] = item.duplicate(true)
	_check(
		(
			StadiumAdvancedSnapshot.valid(forged)
			and not StadiumAdvancedSnapshot.matches(forged, ledger)
		),
		"self-consistent unused surplus still requires exact journal provenance"
	)
	var before: Dictionary = ledger.to_data()
	var bad: Dictionary = {
		"id": "bad",
		"rev": ledger.revision(),
		"op": "stadium_apply",
		"layout": proposed.layout,
		"geometry": "wrong"
	}
	_check(
		not ledger.commit(bad).ok and ClubCareer.same(before, ledger.to_data()),
		"bad apply leaves journal and active layout untouched"
	)
	_check(
		(
			ledger
			. commit(
				{
					"id": "extra%d" % ledger.revision(),
					"rev": ledger.revision(),
					"op": "stadium_wall_piece",
					"through": 20,
					"progress_through": 20,
					"price_version": 1,
					"item": item.item,
					"quantity": 1
				}
			)
			. ok
		),
		"later exact copy purchase"
	)
	_check(
		(
			StadiumAdvancedSnapshot.matches(held, ledger)
			and StadiumAdvancedSnapshot.key(held) == held_key
		),
		"later inventory cannot rewrite the frozen earlier field"
	)


func _headers(ledger: ClubAssetLedger, credits: Array, progress: Array) -> void:
	var old: Dictionary = ledger.to_data()
	old.version = 18
	old.erase("advanced_layout_catalog")
	old.erase("scoreboard_catalog")
	old.erase("scoreboard_layout_catalog")
	old.erase("mounted_scoreboard_layout_catalog")
	old.erase("pool_catalog")
	old.erase("pool_layout_catalog")
	for key: String in ["pool_catalog", "pool_layout_catalog"]:
		var smuggled: Dictionary = old.duplicate(true)
		smuggled[key] = ledger.to_data()[key]
		_check(ClubAssetLedger.from_data(smuggled, 17, credits, progress) == null,
			"ledger18 refuses later pool declarations")
	var loaded: ClubAssetLedger = ClubAssetLedger.from_data(old, 17, credits, progress)
	_check(
		(
			loaded != null
			and ClubCareer.same(loaded.wall_pieces().to_data(), ledger.wall_pieces().to_data())
			and loaded.balance() == ledger.balance()
		),
		"populated ledger18 retains exact pieces and balance"
	)
	for value: Variant in ["unknown", false, null]:
		var bad: Dictionary = ledger.to_data()
		bad.advanced_layout_catalog = value
		_check(
			ClubAssetLedger.from_data(bad, 17, credits, progress) == null,
			"ledger19 binds its exact advanced catalog"
		)
	var missing: Dictionary = ledger.to_data()
	missing.erase("advanced_layout_catalog")
	_check(
		ClubAssetLedger.from_data(missing, 17, credits, progress) == null,
		"ledger19 cannot omit the family signature"
	)


func _rough_origin() -> void:
	var current: ClubAssetLedger = ClubAssetLedger.new_club(17)
	var source: Dictionary = current.to_data()
	_check(current.construction().copies.has(StadiumStock.SALVAGE_COPY)
		and StadiumAdvancedWallLayout.upgrade(current.view().stadium_active).is_empty(),
		"current salvage start cannot silently downgrade to isolated advanced walls")
	var historical: Dictionary = source.duplicate(true)
	historical.version = 19
	for key: String in ["scoreboard_catalog", "scoreboard_layout_catalog",
		"mounted_scoreboard_layout_catalog", "pool_catalog", "pool_layout_catalog",
		"salvage_origin", "salvage_origin_catalog", "salvage_catalog", "salvage_layout_catalog"]:
		historical.erase(key)
	var ledger: ClubAssetLedger = ClubAssetLedger.from_data(
		JSON.parse_string(JSON.stringify(historical, "", true, true)), 17, [])
	_check(ledger != null and ledger.view().stadium_active.version == 12
		and ledger.surface_owned().is_empty() and ledger.revision() == 0
		and ledger.balance() == current.balance()
		and ledger.construction().copies.size() == 3,
		"exact historical rough19 starts with three starters, no grass or invented credits")
	for key: String in ["salvage_origin", "salvage_origin_catalog",
		"salvage_catalog", "salvage_layout_catalog"]:
		var smuggled: Dictionary = historical.duplicate(true)
		smuggled[key] = source[key]
		_check(ClubAssetLedger.from_data(smuggled, 17, []) == null,
			"historical rough19 rejects later salvage declarations")
	_check(ClubCareer.same(current.to_data(), source),
		"historical fixture projection never changes the current club")
	if ledger == null:
		return
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(ledger.view().stadium_active)
	_check(
		ledger.commit({"id": "rough-draft", "rev": 0, "op": "stadium_draft", "layout": layout}).ok,
		"rough origin admits explicit owned dirt v13 draft"
	)
	_check(
		(
			ledger
			. commit(
				{
					"id": "rough-apply",
					"rev": 1,
					"op": "stadium_apply",
					"layout": layout,
					"geometry": StadiumOwnedLayout.geometry("backyard", layout)
				}
			)
			. ok
		),
		"rough dirt may apply in data storage without buying grass"
	)
	var frozen: Dictionary = StadiumAdvancedSnapshot.capture(ledger)
	_check(
		StadiumAdvancedSnapshot.matches(frozen, ledger) and frozen.surface_access.is_empty(),
		"rough declaration freezes absence of grass access"
	)
	var before: Dictionary = ledger.to_data()
	var grass: Dictionary = layout.duplicate(true)
	grass.surface = StadiumSurfaceProgression.selection(
		StadiumSurfaceProgression.INITIAL_LEGACY, true
	)
	for bad: Dictionary in [grass, StadiumStarterLayout.empty()]:
		_check(
			not ledger.commit({"id": "blocked", "rev": 2, "op": "stadium_draft", "layout": bad}).ok,
			"unowned grass and legacy downgrade cannot bypass explicit dirt progression"
		)
	_check(
		ClubCareer.same(before, ledger.to_data()),
		"rough-origin failures preserve the whole journal"
	)

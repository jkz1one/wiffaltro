extends Node
## Explicit synthetic unlocks qualify the container only; no production access policy is inferred.

var _failures: int = 0


func _ready() -> void:
	var original_catalog: String = StadiumCatalog.signature()
	for material: String in StadiumWallRecipes.BACK_IDS:
		_material(material)
	_check(StadiumCatalog.signature() == original_catalog and StadiumCatalog.ROWS.size() == 101,
		"the original catalog and starter contract are unchanged")
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro wall piece stock checks passed: exact separate copies and complete manifests.")
	get_tree().quit(0 if _failures == 0 else 1)


func _material(material: String) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var bought: Dictionary = stock.quote(material, 23, {"seasons": 50, "wins": 200}, "standard")
	_check(bought.ok, "synthetic original material entitlement and standard copies")
	stock = StadiumStock.from_data(bought.state)
	var before: Dictionary = stock.to_data()
	var pieces: StadiumWallPieceStock = StadiumWallPieceStock.new()
	var low: String = StadiumWallPieceCatalog.identity(material, "low")
	var tall: String = StadiumWallPieceCatalog.identity(material, "tall")
	var unlocked: Array[String] = [low, tall]
	_check(not pieces.quote(tall, 1, "locked", [low], stock.copies.size()).ok,
		"material similarity does not silently grant another height unlock")
	for row: Array in [[low, 7, "low"], [tall, 12, "tall"]]:
		var quote: Dictionary = pieces.quote(row[0], row[1], row[2], unlocked, stock.copies.size())
		_check(quote.ok and not quote.placement_verified
			and quote.cost == StadiumWallPieceCatalog.item(row[0]).copy_price * row[1],
			"exact Working copy arithmetic without placement or a second wallet")
		pieces = StadiumWallPieceStock.from_data(quote.state, stock.copies.size())
	_check(ClubCareer.same(stock.to_data(), before), "extra-piece quotes do not rewrite old stock")
	_check(not stock.quote(low, 1, {"seasons": 50, "wins": 200}, "wrong-catalog").ok,
		"old catalog cannot buy new component identities")
	_check(not pieces.quote(low, 1, "low", unlocked).ok, "duplicate receipts cannot mint copies")
	_check(not pieces.quote(low, 0, "zero", unlocked).ok
		and not pieces.quote(low, 1, "", unlocked).ok
		and not pieces.quote(low, 1, "capacity", unlocked, StadiumStock.MAX_COPIES).ok,
		"bad requests and combined inventory capacity fail atomically")
	_check(StadiumWallPieceStock.from_data(JSON.parse_string(JSON.stringify(pieces.to_data())),
		stock.copies.size()) != null, "JSON number decoding preserves exact component ownership")
	_manifests(stock, pieces, material)
	_assembly(stock, pieces, material)
	_paid_side(stock, pieces, material)
	_tampering(pieces)


func _manifests(stock: StadiumStock, pieces: StadiumWallPieceStock, material: String) -> void:
	for shape: String in StadiumHeightWallRecipes.SHAPES:
		var chosen: Dictionary = StadiumHeightWallManifest.suggest(shape, material, stock, pieces)
		_check(chosen.ok, "complete recipe can use separate owned height inventories")
		var valid: Dictionary = StadiumHeightWallManifest.validate(chosen.manifest, stock, pieces)
		_check(valid.ok and valid.standard_used.size() == (13 if shape == "left_loft" else 19)
			and valid.pieces_used.size() == (12 if shape == "left_loft" else 7),
			"recipe never substitutes two standard copies or creates fractional credit")
		_check(ClubCareer.same(chosen, StadiumHeightWallManifest.suggest(shape, material, stock, pieces)),
			"deterministic exact-copy socket selection")
		var bad: Dictionary = chosen.manifest.duplicate(true)
		bad.copies[1] = bad.copies[0]
		_check(not StadiumHeightWallManifest.validate(bad, stock, pieces).ok, "no double-used copy")
		bad = chosen.manifest.duplicate(true)
		bad.copies.pop_back()
		_check(not StadiumHeightWallManifest.validate(bad, stock, pieces).ok, "no incomplete assembly")
		bad = chosen.manifest.duplicate(true)
		bad["height"] = 6.0
		_check(not StadiumHeightWallManifest.validate(bad, stock, pieces).ok, "no arbitrary stretching")
		bad = chosen.manifest.duplicate(true)
		bad.material = "ST-022"
		_check(not StadiumHeightWallManifest.validate(bad, stock, pieces).ok, "side roles stay distinct")
		var first_extra: int = 13 if shape == "left_loft" else 0
		bad = chosen.manifest.duplicate(true)
		for key: String in stock.copies:
			if stock.copies[key].item == material and not valid.standard_used.has(key):
				bad.copies[first_extra] = key
				break
		_check(not StadiumHeightWallManifest.validate(bad, stock, pieces).ok,
			"old standard copies cannot impersonate a low or tall piece")
		bad = chosen.manifest.duplicate(true)
		for key: String in pieces.copies:
			if not valid.pieces_used.has(key):
				bad.copies[first_extra] = key
				break
		_check(not StadiumHeightWallManifest.validate(bad, stock, pieces).ok,
			"a distinct unused wrong-height piece cannot fit the requested socket")
	_check(not StadiumHeightWallManifest.suggest("offset_gables", material, stock, pieces).ok,
		"this exact manifest family does not silently enable another candidate")


func _assembly(stock: StadiumStock, pieces: StadiumWallPieceStock, material: String) -> void:
	var before: Dictionary = stock.to_data()
	var extra_before: Dictionary = pieces.to_data()
	for shape: String in StadiumHeightWallRecipes.SHAPES:
		var manifest: Dictionary = StadiumHeightWallManifest.suggest(
			shape, material, stock, pieces).manifest
		var boundary: StadiumHeightBoundaryBody = StadiumHeightBoundaryBody.new()
		var walls: Dictionary = StadiumWallLayout.empty()
		_check(StadiumHeightOwnedAssembly.build(boundary, manifest, walls, stock, pieces),
			"complete candidate assembly uses its exact owned manifest")
		var used: Array[String] = []
		for panel: Node in boundary.get_node("PanelVisuals").get_children():
			var copy: String = panel.get_meta("owned_copy")
			_check(manifest.copies.has(copy) and not used.has(copy), "one rendered instance per paid piece")
			used.append(copy)
			_check(panel.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"joined physics is not duplicated by individual panel colliders")
		_check(used.size() == manifest.copies.size(), "no free side panels appear in the owned assembly")
		_check(boundary.get_node("SIDE-L-01/TemplateWallVisual").visible
			and boundary.get_node("SIDE-R-01/TemplateWallVisual").visible,
			"unowned sides retain functional template scenery, not catalog grants")
		_check(not StadiumHeightOwnedAssembly.build(boundary, manifest, walls, stock, pieces),
			"repeated assembly cannot duplicate paid models")
		boundary.free()
		boundary = StadiumHeightBoundaryBody.new()
		var incomplete: Dictionary = manifest.duplicate(true)
		incomplete.copies.pop_back()
		_check(not StadiumHeightOwnedAssembly.build(boundary, incomplete, walls, stock, pieces)
			and boundary.get_child_count() == 0,
			"invalid manifest creates no partial construction")
		boundary.free()
	_check(ClubCareer.same(stock.to_data(), before)
		and ClubCareer.same(pieces.to_data(), extra_before),
		"previewing alternate recipes never consumes, converts or deletes owned copies")


func _paid_side(stock: StadiumStock, pieces: StadiumWallPieceStock, material: String) -> void:
	var quote: Dictionary = stock.quote("ST-022", 19, {"seasons": 50, "wins": 200}, "left")
	_check(quote.ok, "synthetic handed-side purchase")
	var expanded: StadiumStock = StadiumStock.from_data(quote.state)
	var proposed: Dictionary = StadiumWallLayout.propose(
		StadiumWallLayout.empty(), expanded, "left", "ST-022")
	var manifest: Dictionary = StadiumHeightWallManifest.suggest(
		"left_loft", material, expanded, pieces).manifest
	var boundary: StadiumHeightBoundaryBody = StadiumHeightBoundaryBody.new()
	_check(StadiumHeightOwnedAssembly.build(boundary, manifest, proposed.walls, expanded, pieces),
		"mixed-height back combines with a separately owned complete handed side")
	_check(boundary.get_node("PanelVisuals").get_child_count() == 44
		and not boundary.get_node("SIDE-L-01/TemplateWallVisual").visible
		and boundary.get_node("SIDE-R-01/TemplateWallVisual").visible,
		"exactly nineteen paid side models replace only their matching template")
	boundary.free()
	boundary = StadiumHeightBoundaryBody.new()
	var double_back: Dictionary = StadiumWallLayout.propose(
		proposed.walls, expanded, "back", material).walls
	_check(not StadiumHeightOwnedAssembly.build(boundary, manifest, double_back, expanded, pieces)
		and boundary.get_child_count() == 0, "two complete backs cannot overlap or share copies")
	boundary.free()


func _tampering(pieces: StadiumWallPieceStock) -> void:
	var original: Dictionary = pieces.to_data()
	var key: String = original.copies.keys()[0]
	for field: String in ["paid", "item", "source"]:
		var bad: Dictionary = original.duplicate(true)
		bad.copies[key][field] = false if field == "paid" else (
			"ST-024" if field == "item" else "starter-v1")
		_check(StadiumWallPieceStock.from_data(bad) == null, "invalid component receipt rejected")
	var bad: Dictionary = original.duplicate(true)
	bad.catalog = "invented"
	_check(StadiumWallPieceStock.from_data(bad) == null, "exact component catalog is bound")
	bad = original.duplicate(true)
	bad.version = true
	_check(StadiumWallPieceStock.from_data(bad) == null, "boolean cannot impersonate a schema version")
	bad = original.duplicate(true)
	bad.copies[key]["free"] = true
	_check(StadiumWallPieceStock.from_data(bad) == null, "unknown receipt fields fail closed")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

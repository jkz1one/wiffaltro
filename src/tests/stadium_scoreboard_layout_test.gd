extends Node
## Isolated complete-owner placement qualification, not production layout admission.

const ACCESS: Array[String] = StadiumSurfaceProgression.INITIAL_LEGACY
const PROGRESS: Dictionary = {"seasons": 50, "wins": 200}
var _failures: int = 0
var _stock: StadiumStock
var _pieces: StadiumWallPieceOwnership
var _boards: StadiumScoreboardOwnership


func _ready() -> void:
	_fund()
	_matrix()
	_complete_matrix()
	_ownership_guards()
	_legacy_signs()
	var original: Dictionary = _base()
	var copy: Dictionary = original.duplicate(true)
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(original)
	_check(ClubCareer.same(original, copy)
		and ClubCareer.same(StadiumScoreboardLayout.base(layout), original),
		"upgrade is a detached exact wrapper without automatic model or site changes")
	_check(_validate(layout).ok, "template-only field accepts an explicitly empty board extension")
	_check(not StadiumHomeLayout.validate(layout, _stock).ok
		and not StadiumOwnedLayout.validate(layout, _stock, _pieces, ACCESS, "mogul").ok,
		"legacy callers without complete ownership stay closed")
	_check(StadiumOwnedLayout.validate(layout, _stock, _pieces, ACCESS, "mogul", _boards).ok,
		"explicit complete ownership admits data-only layout14")
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		_advanced(shape)
	_legacy_cross_use()
	_wall_storage()
	_malformed(layout)
	_models()
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print("Wiffaltro scoreboard layouts passed: exact versioned sites, storage and visibility.")
	get_tree().quit(0 if _failures == 0 else 1)


func _fund() -> void:
	_stock = StadiumStock.new_club()
	for id: String in ["ST-039", "ST-040", "ST-024"]:
		_stock = StadiumStock.from_data(_stock.quote(id, 27 if id == "ST-024" else 2,
			PROGRESS, id).state)
	_pieces = StadiumWallPieceOwnership.new()
	for id: String in ["ST-024-L", "ST-024-T"]:
		_pieces = StadiumWallPieceOwnership.from_data(
			_pieces.quote(id, 12, id, PROGRESS, _stock.copies.size()).state, _stock.copies.size())
	_boards = StadiumScoreboardOwnership.new()
	_boards = StadiumScoreboardOwnership.from_data(_boards.quote(2, "electronic", PROGRESS,
		_stock.copies.size() + _pieces.stock.copies.size()).state,
		_stock.copies.size() + _pieces.stock.copies.size())


func _base() -> Dictionary:
	return StadiumAdvancedWallLayout.upgrade(StadiumSurfaceLayout.upgrade(
		StadiumStarterLayout.empty(), ACCESS, true))


func _matrix() -> void:
	for shape: String in ["straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"]:
		var graph: StadiumRecipeBoundary = StadiumRecipeBoundary.create(shape) \
			if shape in ["straight", "deeper_center"] else StadiumAdvancedWallManifest.graph(shape)
		for item: String in StadiumScoreboardCatalog.IDS:
			for site: String in StadiumScoreboardSites.SITES:
				for land: String in StadiumLand.TIERS:
					var compatible: bool = StadiumScoreboardSites.SITES[site].items.has(item)
					var expected: bool = compatible and (land == "mogul" if item == "ST-040" else
						not (site == "BOARD-LEFT-v2" and shape == "left_loft"))
					_check(StadiumScoreboardSites.inspect(item, site, land, graph).ok == expected,
						"full model/site/shape/land matrix: %s/%s/%s/%s" % [item, site, shape, land])
	_check(not StadiumScoreboardTierSites.inspect("manual", "BOARD-RIGHT-v1", "backyard",
		StadiumRecipeBoundary.create("straight")).ok,
		"original diagnostic z30 site retains its honest straight-field manual rejection")
	_check(StadiumScoreboardTierSites.SITES["BOARD-RIGHT-v1"].position.z == 30
		and StadiumScoreboardSites.SITES["BOARD-RIGHT-v2"].position.z == 29,
		"new reservation is explicit; no saved site moved")


func _advanced(shape: String) -> void:
	var before: Dictionary = _base()
	before.advanced_back = StadiumAdvancedWallManifest.suggest(shape, "ST-024", _stock,
		_pieces.stock).manifest
	before.displays = [{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"}]
	_check(StadiumAdvancedWallLayout.validate(before, _stock, _pieces, "mogul", ACCESS).ok,
		"historic advanced grammar remains frozen even for its obscured legacy board")
	var after: Dictionary = StadiumScoreboardLayout.upgrade(before)
	_check(not _validate(after).ok, "new family requires an explicit hidden-board repair: " + shape)
	after.displays = []
	after.scoreboards = [_row("ST-039", "BOARD-RIGHT-v2")]
	var preview: Dictionary = StadiumScoreboardLayout.preview(before, after,
		_stock, _pieces, _boards, ACCESS, "mogul")
	_check(preview.ok and preview.cost == 0 and preview.displaced.is_empty()
		and preview.moved == ["purchase:ST-039:0"], "same copy can be explicitly moved to its new model")
	var checked: Dictionary = _validate(after)
	_check(checked.ok and checked.board_placements.size() == 1,
		"owned manual has its separate model-aware placement channel")
	_partition(checked)
	_check(_validate(JSON.parse_string(JSON.stringify(after))).ok, "JSON layout preserves identity")
	after.scoreboards = [_row("ST-090", "BOARD-RIGHT-v2")]
	preview = StadiumScoreboardLayout.preview(before, after, _stock, _pieces, _boards, ACCESS, "mogul")
	_check(preview.ok and preview.displaced == ["purchase:ST-039:0"]
		and preview.stored.has("purchase:ST-039:0")
		and not preview.scoreboards_stored.has("scoreboard:electronic:0"),
		"electronic replacement stores the exact old manual and consumes the exact electronic")
	_partition(preview.placement)
	var empty: Dictionary = after.duplicate(true)
	empty.scoreboards = []
	preview = StadiumScoreboardLayout.preview(after, empty, _stock, _pieces, _boards, ACCESS, "mogul")
	_check(preview.ok and preview.displaced == ["scoreboard:electronic:0"]
		and preview.scoreboards_stored.size() == 2, "removal returns the original electronic copy")
	preview.placement.stored.clear()
	_check(_stock.copies.size() == 34 and _boards.copies.size() == 2,
		"preview mutation never changes input ownership")


func _legacy_cross_use() -> void:
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(_base())
	layout.displays = [{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"}]
	layout.scoreboards = [_row("ST-039", "BOARD-RIGHT-v2")]
	_check(not _validate(layout).ok, "same copy cannot occupy old LEFT and new RIGHT")
	layout.scoreboards[0].copy = "purchase:ST-039:1"
	_check(_validate(layout).ok, "distinct copies may use genuinely separate visible sites")
	layout.scoreboards[0].site = "BOARD-LEFT-v2"
	_check(not _validate(layout).ok,
		"distinct copies still cannot overlap old and new LEFT footprints")
	layout.displays = []
	layout.scoreboards = [_row("ST-040", "BOARD-LARGE-v2"), _row("ST-039", "BOARD-LEFT-v2"),
		_row("ST-090", "BOARD-RIGHT-v2")]
	var result: Dictionary = _validate(layout)
	_check(result.ok and result.board_placements.size() == 3,
		"three exact non-overlapping reservations")
	_partition(result)
	var box: AABB = StadiumScoreboardLayout.bounds(result.board_placements[1])
	_check(is_equal_approx(box.size.x, 6.2) and is_equal_approx(box.size.y, 5.8),
		"new manual bounds never fall through to old5x4 envelope")
	_check(StadiumScoreboardLayout._overlaps(AABB(Vector3.ZERO, Vector3.ONE),
		AABB(Vector3(1, 0, 0), Vector3.ONE)), "touching furniture reservations reject")
	_check(not StadiumScoreboardLayout._walls_clear(AABB(Vector3(-1, 0, 23.3),
		Vector3(2, 4, 1)), result, StadiumRecipeBoundary.create("straight")),
		"literal template boundary overlap rejects")


func _wall_storage() -> void:
	for advanced: bool in [false, true]:
		var before: Dictionary = _base()
		if advanced:
			before.advanced_back = StadiumAdvancedWallManifest.suggest(
				"left_loft", "ST-024", _stock, _pieces.stock).manifest
		else:
			before.walls = StadiumWallLayout.propose(
				before.walls, _stock, "back", "ST-024", "straight").walls
		var old: Dictionary = StadiumAdvancedWallLayout.validate(before, _stock, _pieces, "mogul", ACCESS)
		var expected: Array[String] = []
		for row: Dictionary in old.wall_panels + old.advanced_panels:
			expected.append(row.copy)
		expected.sort()
		var after: Dictionary = StadiumScoreboardLayout.upgrade(before)
		after.walls.back = {}
		after.advanced_back = StadiumAdvancedWallManifest.empty()
		var preview: Dictionary = StadiumScoreboardLayout.preview(
			before, after, _stock, _pieces, _boards, ACCESS, "mogul")
		_check(preview.ok and preview.displaced == expected
			and expected.size() == (25 if advanced else 23),
			"wall removal reports every exact standard/advanced copy")
		_partition(preview.placement)
		for key: String in expected:
			_check(preview.stored.has(key) if _stock.copies.has(key) else preview.pieces_stored.has(key),
				"removed wall copy returns to its original storage channel")
	var empty: Dictionary = _validate(StadiumScoreboardLayout.upgrade(_base()))
	_check(not StadiumScoreboardLayout._walls_clear(
		AABB(Vector3(24.577, 0.2, 23.743), Vector3(0.005, 0.2, 0.005)), empty,
		StadiumRecipeBoundary.create("straight")), "acute boundary miter is inside reserved volume")


func _malformed(source: Dictionary) -> void:
	for field: String in ["family", "extra", "rows", "copy", "item", "model", "site", "position"]:
		var bad: Dictionary = source.duplicate(true)
		bad.scoreboards = [_row("ST-090", "BOARD-RIGHT-v2")]
		match field:
			"family": bad.family = "other"
			"extra": bad["unknown"] = true
			"rows": bad.scoreboards = {}
			"copy": bad.scoreboards[0].copy = "not-owned"
			"item": bad.scoreboards[0].item = "ST-039"
			"model": bad.scoreboards[0].model = "electronic-v1"
			"site": bad.scoreboards[0].site = "BOARD-RIGHT-v1"
			"position": bad.scoreboards[0]["position"] = [20, 0, 29]
		_check(not _validate(bad).ok, "strict row and family rejection: " + field)
	var duplicate: Dictionary = source.duplicate(true)
	duplicate.scoreboards = [_row("ST-090", "BOARD-LEFT-v2"), _row("ST-090", "BOARD-RIGHT-v2")]
	_check(not _validate(duplicate).ok, "one electronic copy cannot be used twice")
	duplicate.scoreboards[1].copy = "scoreboard:electronic:1"
	duplicate.scoreboards.reverse()
	_check(not _validate(duplicate).ok, "site order must be canonical")
	_check(not StadiumScoreboardLayout.validate(source, _stock, _pieces, null, ACCESS, "mogul").ok,
		"missing extension context never means free ownership")
	var no_copy: StadiumScoreboardOwnership = StadiumScoreboardOwnership.new()
	no_copy.blueprints = ["ST-090"]
	duplicate.scoreboards = [_row("ST-090", "BOARD-RIGHT-v2")]
	_check(not StadiumScoreboardLayout.validate(duplicate, _stock, _pieces,
		no_copy, ACCESS, "mogul").ok, "blueprint alone is not a physical copy")


func _models() -> void:
	for item: String in StadiumScoreboardCatalog.IDS:
		var node: Node3D = StadiumScoreboardModels.create(item, StadiumScoreboardModels.MODELS[item])
		_check(node != null and node.get_meta("stadium_item") == item
			and node.find_children("*", "CollisionObject3D", true, false).is_empty(),
			"exact owned model adapter preserves collision-free candidate role")
		node.free()
	_check(StadiumScoreboardModels.bounds({"item": "unknown", "model": "invalid",
		"site": "BOARD-RIGHT-v2"}) == AABB()
		and StadiumScoreboardModels.bounds({"item": "ST-040", "model": "video-v2",
		"site": "BOARD-RIGHT-v2"}) == AABB(), "bounds reject unknown and incompatible identities")
	_check(StadiumScoreboardModels.create("ST-039", "video-v2") == null
		and StadiumScoreboardModels.create("unknown", "") == null, "mismatched models fail closed")


func _partition(checked: Dictionary) -> void:
	_check(checked.placements.size() + checked.board_placements.size() + checked.wall_panels.size()
		+ checked.advanced_panels.size() + checked.stored.size() + checked.pieces_stored.size()
		+ checked.scoreboards_stored.size() == _stock.copies.size()
		+ _pieces.stock.copies.size() + _boards.copies.size(),
		"every physical copy is exactly placed or stored in its original inventory")


func _row(item: String, site: String) -> Dictionary:
	return {"copy": "scoreboard:electronic:0" if item == "ST-090" else "purchase:" + item + ":0",
		"item": item, "model": StadiumScoreboardModels.MODELS[item], "site": site}


func _validate(layout: Variant) -> Dictionary:
	return StadiumScoreboardLayout.validate(layout, _stock, _pieces, _boards, ACCESS, "mogul")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _complete_matrix() -> void:
	for shape: String in ["straight", "deeper_center", "offset_gables", "left_loft", "right_shelf"]:
		var layout: Dictionary = _base()
		if shape in ["straight", "deeper_center"]:
			layout.walls = StadiumWallLayout.propose(layout.walls, _stock, "back", "ST-024", shape).walls
		else:
			layout.advanced_back = StadiumAdvancedWallManifest.suggest(
				shape, "ST-024", _stock, _pieces.stock).manifest
		layout = StadiumScoreboardLayout.upgrade(layout)
		for site: String in StadiumScoreboardSites.SITES:
			for item: String in StadiumScoreboardSites.SITES[site].items:
				layout.scoreboards = [_row(item, site)]
				var expected: bool = not (shape == "left_loft" and site == "BOARD-LEFT-v2")
				var checked: Dictionary = _validate(layout)
				_check(checked.ok == expected, "complete owned shape/model/site validation")
				if checked.ok:
					_partition(checked)
				if item == "ST-040":
					_check(not StadiumScoreboardLayout.validate(layout, _stock, _pieces,
						_boards, ACCESS, "club").ok, "complete video layout exceeds Club land")
	_check(not StadiumScoreboardTierSites.inspect("manual", "BOARD-RIGHT-v1", "backyard",
		StadiumAdvancedWallManifest.graph("offset_gables")).ok,
		"old diagnostic Offset Gables right-site rejection remains explicit")


func _ownership_guards() -> void:
	var layout: Dictionary = StadiumScoreboardLayout.upgrade(_base())
	var count: int = StadiumStock.MAX_COPIES - _stock.copies.size() \
		- _pieces.stock.copies.size() - _boards.copies.size()
	var filled: StadiumStock = StadiumStock.from_data(
		_stock.quote("ST-001", count, PROGRESS, "capacity").state)
	_check(StadiumScoreboardLayout.validate(layout, filled, _pieces, _boards, ACCESS, "mogul").ok,
		"empty-board layout still validates all4096 owned physical copies")
	filled = StadiumStock.from_data(filled.quote("ST-001", 1, PROGRESS, "overflow").state)
	_check(not StadiumScoreboardLayout.validate(layout, filled, _pieces, _boards, ACCESS, "mogul").ok,
		"empty-board layout cannot hide combined4097 copies")
	var bad_stock: StadiumStock = StadiumStock.from_data(_stock.to_data())
	bad_stock.copies["purchase:ST-039:0"].paid = 0
	_check(not StadiumScoreboardLayout.validate(layout, bad_stock, _pieces, _boards,
		ACCESS, "mogul").ok, "corrupted standard ownership fails closed")
	var bad_pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.from_data(_pieces.to_data())
	bad_pieces.stock.copies[bad_pieces.stock.copies.keys()[0]].paid = 0
	_check(not StadiumScoreboardLayout.validate(layout, _stock, bad_pieces, _boards,
		ACCESS, "mogul").ok, "corrupted piece ownership fails closed")
	bad_pieces.stock = null
	_check(not StadiumScoreboardLayout.validate(layout, _stock, bad_pieces, _boards,
		ACCESS, "mogul").ok, "missing nested piece stock fails without script errors")


func _legacy_signs() -> void:
	var stock: StadiumStock = StadiumStock.from_data(_stock.quote("ST-041", 1, PROGRESS, "sign").state)
	var before: Dictionary = _base()
	before.advanced_back = StadiumAdvancedWallManifest.suggest(
		"left_loft", "ST-024", stock, _pieces.stock).manifest
	var sign: Dictionary = {"copy": "purchase:sign:0", "site": "SIGN-GROUND-R"}
	before.displays = [{"copy": "purchase:ST-039:0", "site": "SCORE-SMALL"}, sign]
	var after: Dictionary = StadiumScoreboardLayout.upgrade(before)
	after.displays = [sign.duplicate(true)]
	after.scoreboards = [_row("ST-039", "BOARD-RIGHT-v2")]
	var preview: Dictionary = StadiumScoreboardLayout.preview(
		before, after, stock, _pieces, _boards, ACCESS, "mogul")
	_check(preview.ok and preview.displaced.is_empty()
		and preview.moved == ["purchase:ST-039:0"] and after.displays == [sign],
		"explicit board migration does not move or replace a legacy club sign")

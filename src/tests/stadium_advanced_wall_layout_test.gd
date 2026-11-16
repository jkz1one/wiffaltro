extends Node

var _failures: int = 0


func _ready() -> void:
	_malformed_ownership()
	var old_signature: String = StadiumWallItems.signature()
	var surface_signature: String = StadiumSurfaceLayout.signature()
	for material: String in StadiumWallRecipes.BACK_IDS:
		_material(material)
	_check(
		(
			old_signature == StadiumWallItems.signature()
			and surface_signature == StadiumSurfaceLayout.signature()
		),
		"old geometry signatures preserved"
	)
	_check(
		not StadiumAdvancedWallLayout.RUNTIME_READY,
		"isolated grammar is not production fixture or shop eligibility"
	)
	await TestAudioDrain.finish(get_tree())
	if _failures == 0:
		print(
			"Wiffaltro advanced wall layouts passed: exact manifests, surfaces and bounded storage."
		)
	get_tree().quit(0 if _failures == 0 else 1)


func _material(material: String) -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var metrics: Dictionary = {"seasons": 50, "wins": 200}
	for id: String in [material, "ST-022", "ST-023"]:
		var quote: Dictionary = stock.quote(id, 27 if id == material else 19, metrics, id)
		_check(quote.ok, "synthetic standard manifest stock")
		stock = StadiumStock.from_data(quote.state)
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	for height: String in ["low", "tall"]:
		var quote: Dictionary = pieces.quote(
			StadiumWallPieceCatalog.identity(material, height),
			12,
			height,
			metrics,
			stock.copies.size()
		)
		_check(quote.ok, "synthetic explicit variant ownership")
		pieces = StadiumWallPieceOwnership.from_data(quote.state, stock.copies.size())
	var surface: Dictionary = StadiumSurfaceLayout.upgrade(
		StadiumStarterLayout.empty(), StadiumSurfaceProgression.INITIAL_LEGACY, true
	)
	surface.surface.height = "long"
	for side: String in ["left", "right"]:
		surface.walls = (
			StadiumWallLayout
			. propose(surface.walls, stock, side, "ST-022" if side == "left" else "ST-023")
			. walls
		)
	var original: Dictionary = surface.duplicate(true)
	var advanced: Dictionary = StadiumAdvancedWallLayout.upgrade(surface)
	_check(
		(
			ClubCareer.same(original, StadiumAdvancedWallLayout.base(advanced))
			and ClubCareer.same(original, surface)
		),
		"upgrade preserves independent surfaces and sides"
	)
	_check(
		not StadiumHomeLayout.validate(advanced, stock).ok,
		"old production dispatcher never accepts isolated v13 by fallback"
	)
	for shape: String in StadiumAdvancedWallManifest.SHAPES:
		var proposed: Dictionary = StadiumAdvancedWallManifest.suggest(
			shape, material, stock, pieces.stock
		)
		_check(proposed.ok, "complete exact recipe can be suggested")
		advanced.advanced_back = proposed.manifest
		for tier: String in StadiumLand.TIERS:
			var result: Dictionary = StadiumAdvancedWallLayout.validate(
				advanced, stock, pieces, tier, StadiumSurfaceProgression.INITIAL_LEGACY
			)
			_check(result.ok and not result.night_qualified, "exact recipe fits authored property")
			if result.ok:
				var count: int = (
					27 if shape == "offset_gables" else 25 if shape == "left_loft" else 26
				)
				_check(
					result.advanced_panels.size() == count and result.wall_panels.size() == 38,
					"exact back and independently paid side counts"
				)
				_check(
					(
						result.stored.size() + result.pieces_stored.size()
						== stock.copies.size() + pieces.stock.copies.size() - count - 38
					),
					"every surplus copy remains stored with no conversion"
				)
		_tampering(advanced, stock, pieces)
	_check(ClubCareer.same(surface, original), "preview preserves original active layout")
	var outline: StadiumRecipeBoundary = StadiumAdvancedWallManifest.graph("offset_gables")
	_check(
		not StadiumAdvancedWallLayout.outside_play(
			outline, AABB(Vector3(-1, 0, 25), Vector3(2, 3, 2))
		),
		"deeper center is not outside old wall"
	)
	_check(
		StadiumAdvancedWallLayout.outside_play(outline, AABB(Vector3(-2, 0, 32), Vector3(2, 3, 2))),
		"clear outside-play placement retained"
	)


func _tampering(layout: Dictionary, stock: StadiumStock, pieces: StadiumWallPieceOwnership) -> void:
	_check(
		not (
			StadiumAdvancedWallLayout
			. validate(layout, stock, null, "club", StadiumSurfaceProgression.INITIAL_LEGACY)
			. ok
		),
		"missing piece ownership cannot fall back"
	)
	_check(
		not StadiumAdvancedWallLayout.validate(layout, stock, pieces, "club", []).ok,
		"grass access remains required"
	)
	for mode: String in ["duplicate", "short", "material", "shape", "double", "unknown"]:
		var bad: Dictionary = layout.duplicate(true)
		match mode:
			"duplicate":
				bad.advanced_back.copies[0] = bad.advanced_back.copies[1]
			"short":
				bad.advanced_back.copies.pop_back()
			"material":
				bad.advanced_back.material = "ST-022"
			"shape":
				bad.advanced_back.shape = "invented"
			"double":
				bad.walls = (
					StadiumWallLayout
					. propose(bad.walls, stock, "back", layout.advanced_back.material)
					. walls
				)
			"unknown":
				bad["free_poles"] = true
		_check(
			not (
				StadiumAdvancedWallLayout
				. validate(bad, stock, pieces, "club", StadiumSurfaceProgression.INITIAL_LEGACY)
				. ok
			),
			"malformed proposal rejected: " + mode
		)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _malformed_ownership() -> void:
	var stock: StadiumStock = StadiumStock.new_club()
	var pieces: StadiumWallPieceOwnership = StadiumWallPieceOwnership.new()
	var layout: Dictionary = StadiumAdvancedWallLayout.upgrade(
		StadiumSurfaceLayout.upgrade(
			StadiumStarterLayout.empty(), StadiumSurfaceProgression.INITIAL_LEGACY, true
		)
	)
	pieces.stock = null
	_check(
		not (
			StadiumAdvancedWallLayout
			. validate(layout, stock, pieces, "club", StadiumSurfaceProgression.INITIAL_LEGACY)
			. ok
		),
		"null nested stock fails without script error"
	)
	_check(
		not pieces.quote("ST-024-L", 1, "broken", {"seasons": 50, "wins": 200}).ok,
		"corrupt ownership quote fails closed"
	)
	pieces = StadiumWallPieceOwnership.new()
	for bad: Variant in [{}, false, {"item": "ST-024"}]:
		stock.copies["bad"] = bad
		for shape: String in StadiumAdvancedWallManifest.SHAPES:
			_check(
				not StadiumAdvancedWallManifest.suggest(shape, "ST-024", stock, pieces.stock).ok,
				"malformed stock cannot reach typed suggestion loops"
			)
